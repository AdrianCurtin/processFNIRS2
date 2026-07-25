function [pvc, sensitivity, pplGM] = strangmanPVC(separation, varargin)
% STRANGMANPVC Separation- and region-specific partial-volume correction (PVC)
%
% Returns a principled partial-volume correction factor for the modified
% Beer-Lambert law from the Monte Carlo sensitivity model of Strangman, Zhang
% & Li (2014), who ran 3555 photon simulations on the segmented Colin27 brain
% template. "Sensitivity" is the relative gray-matter partial pathlength,
% PPL_GM / TPL (gray-matter path divided by total photon path); the
% partial-volume correction is its reciprocal, PVC = TPL / PPL_GM. Feed the
% returned PVC to bvoxy / processFNIRS2 ('PartialVolumeCorrection') so the
% effective pathlength becomes L = SD .* DPF ./ PVC.
%
% Sensitivity is strongly separation- and region-dependent (it spans an order
% of magnitude across the head at a fixed separation), so a single guessed
% scalar is a poor approximation; this function looks it up by source-detector
% separation and either a 10-20 scalp location or measured scalp/skull
% thicknesses.
%
% IMPORTANT (denominator convention): this sensitivity counts path in ALL gray
% matter the channel samples, giving PVC ~ 10 at a 30 mm channel. The focal
% partial-volume-error literature (Strangman 2003; Boas 2001) instead counts
% only the FOCALLY ACTIVATED patch, a smaller denominator that yields a larger
% PVC (~20-60). Same physics, different denominators - pick the one that
% matches your inference.
%
% References:
%   Strangman, G. E., Zhang, Q., & Li, Z. (2014). Scalp and skull influence on
%   near infrared photon propagation in the Colin27 brain template.
%   NeuroImage, 85, 136-149. DOI: 10.1016/j.neuroimage.2013.04.090
%   Strangman, G., Franceschini, M. A., & Boas, D. A. (2003). Factors affecting
%   the accuracy of near-infrared spectroscopy concentration calculations for
%   focal changes in oxygenation parameters. NeuroImage, 18(4), 865-879.
%   DOI: 10.1016/s1053-8119(03)00021-1
%
% Syntax:
%   pvc = pf2_base.fnirs.strangmanPVC(separation)
%   pvc = pf2_base.fnirs.strangmanPVC(separation, 'Location', 'C3')
%   pvc = pf2_base.fnirs.strangmanPVC(separation, 'Scalp', s, 'Skull', k)
%   [pvc, sensitivity, pplGM] = pf2_base.fnirs.strangmanPVC(...)
%
% Inputs:
%   separation - Source-detector separation in mm. Scalar OR a vector (one per
%                channel), resolved in a single vectorized interp1 so a whole
%                montage costs microseconds. The model is defined for 20-50 mm;
%                values outside are clamped with a single warning. Outputs match
%                the input shape.
%
% Name-Value Parameters:
%   'Location' - A 10-20 System scalp label whose region-specific sensitivity
%                is taken from Strangman 2014 Table 2. One of: Fp1 Fp2 Fz F3 F4
%                F7 F8 C3 C4 Cz P3 P4 Pz O1 O2 T3 T4 T5 T6. (default: '')
%   'Scalp'    - Local scalp thickness in mm. With 'Skull', drives the
%                regression models (Table 4 for sensitivity, Table 5 for the
%                absolute PPL_GM). (default: [])
%   'Skull'    - Local skull thickness in mm (see 'Scalp'). (default: [])
%
% Resolution order: an explicit 'Location' wins; else 'Scalp'+'Skull' use the
% regressions; else the head-wide average sensitivity across the 19 locations
% is returned (a generic, montage-agnostic default).
%
% Outputs:
%   pvc         - Partial-volume correction, PVC = 1 / sensitivity (>= 1).
%   sensitivity - Relative sensitivity PPL_GM / TPL (in (0, 1)).
%   pplGM       - Absolute gray-matter partial pathlength in mm (Table 5
%                 regression). NaN unless 'Scalp'+'Skull' are supplied.
%
% Example:
%   % Conventional 30 mm channel over motor cortex (C3):
%   pvc = pf2_base.fnirs.strangmanPVC(30, 'Location', 'C3');   % ~7.4
%   proc = processFNIRS2(data, 'DPFmode', 'Calc', 'PVC', pvc);
%
%   % From a segmented MRI (local scalp 4 mm, skull 5 mm) at 30 mm:
%   [pvc, s, L] = pf2_base.fnirs.strangmanPVC(30, 'Scalp', 4, 'Skull', 5);
%
% Notes:
%   - Head-wide sensitivity ranges (Table 3) grow with separation while their
%     max/min ratio shrinks: 20 mm -> 0.004-0.114 (31.6x); 30 mm ->
%     0.014-0.162 (12x); 50 mm -> 0.060-0.205 (3.4x). Wider separations are
%     both more sensitive and more spatially uniform.
%   - Colin27 tissue optical properties used by Strangman 2014 (mm^-1) are
%     available via the OpticalProperties subfunction data below: gray
%     mua=0.0195 mus'=1.10; white 0.0169/1.35; CSF 0.0025/0.01; skull
%     0.011925/0.92; scalp 0.017275/0.72.
%
% See also: pf2_base.fnirs.bvoxy, processFNIRS2, pf2.probe.forward.sensitivity

p = inputParser;
p.addRequired('separation', @(x) isnumeric(x) && ~isempty(x) && isvector(x) && all(x(:) > 0));
p.addParameter('Location', '', @(x) ischar(x) || (isstring(x) && isscalar(x)));
p.addParameter('Scalp', [], @(x) isempty(x) || (isnumeric(x) && isscalar(x) && x >= 0));
p.addParameter('Skull', [], @(x) isempty(x) || (isnumeric(x) && isscalar(x) && x >= 0));
p.parse(separation, varargin{:});

location = char(p.Results.Location);
scalp = p.Results.Scalp;
skull = p.Results.Skull;

seps = [20 25 30 35 40 45 50];

% Vectorized over separation: sep may be a scalar or a per-channel vector, so a
% whole montage resolves in a single interp1 rather than one inputParser +
% interp1 per channel (measured: ~microseconds vs ~33 ms for an 18-channel
% arrayfun). Output shape matches the input separation.
outShape = size(separation);
sep = separation(:);                       % column for computation
if any(sep < seps(1) | sep > seps(end))
    warning('pf2_base:fnirs:strangmanPVC:extrapolate', ...
        ['%d separation value(s) are outside the Strangman 2014 model range ' ...
         '(20-50 mm); clamping to the nearest bound.'], nnz(sep < seps(1) | sep > seps(end)));
    sep = min(max(sep, seps(1)), seps(end));
end

pplGM = nan(outShape);

if ~isempty(location)
    [locNames, locSens] = table2Data();
    idx = find(strcmpi(locNames, location), 1);
    if isempty(idx)
        error('pf2_base:fnirs:strangmanPVC:unknownLocation', ...
            'Unknown 10-20 location ''%s''. Valid: %s.', location, strjoin(locNames, ' '));
    end
    row = locSens(idx, :);
    good = ~isnan(row);
    sensitivity = interp1(seps(good), row(good), sep, 'linear', 'extrap');

elseif ~isempty(scalp) && ~isempty(skull)
    w = [1; scalp; skull; scalp*skull];
    B = interp1(seps, table4Coef(), sep, 'linear', 'extrap');   % [nSep x 4]
    sensitivity = B * w;                                        % [nSep x 1]
    C = interp1(seps, table5Coef(), sep, 'linear', 'extrap');   % absolute PPL_GM (mm)
    pplGM = reshape(C * w, outShape);

else
    % Head-wide average sensitivity across the 19 tabulated locations, in one
    % interp1 over all separations (columns of locSens' are per-location).
    [~, locSens] = table2Data();
    P = interp1(seps, locSens', sep, 'linear', 'extrap');       % [nSep x nLoc]
    sensitivity = mean(P, 2, 'omitnan');                        % [nSep x 1]
end

% Sensitivity is a fraction in (0,1); guard degenerate model output.
sensitivity = reshape(max(sensitivity, eps), outShape);
pvc = 1 ./ sensitivity;

end

%%_Data_(Strangman,_Zhang_&_Li_2014)____________________________________

function [names, sens] = table2Data()
% TABLE2DATA Relative sensitivity PPL_GM/TPL per 10-20 location x separation
% Columns are separations [20 25 30 35 40 45 50] mm (Table 2).
names = {'Fp1','Fp2','Fz','F3','F4','F7','F8','C3','C4','Cz', ...
         'P3','P4','Pz','O1','O2','T3','T4','T5','T6'};
sens = [ ...
    0.074 0.093 0.110 0.124 0.135 0.144 0.148;   % Fp1
    0.073 0.094 0.110 0.123 0.133 0.140 0.151;   % Fp2
    0.073 0.086 0.093 0.096 0.097 0.099 0.094;   % Fz
    0.111 0.136 0.156 0.169 0.177 0.188 0.202;   % F3
    0.104 0.125 0.142 0.156 0.163 0.174 0.185;   % F4
    0.066 0.085 0.102 0.118 0.131 0.141 0.156;   % F7
    0.049 0.069 0.089 0.102 0.120 0.135 0.145;   % F8
    0.102 0.122 0.136 0.145 0.151 0.156 0.159;   % C3
    0.076 0.095 0.111 0.121 0.128 0.135 0.145;   % C4
    0.092 0.105 0.113 0.117 0.122 0.125 0.133;   % Cz
    0.111 0.134 0.147 0.156 0.162 0.162 0.162;   % P3
    0.118 0.134 0.145 0.152 0.157 0.160 0.161;   % P4
    0.072 0.099 0.112 0.122 0.127   NaN   NaN;   % Pz
    0.139 0.156 0.167 0.175 0.179 0.182 0.179;   % O1
    0.139 0.156 0.168 0.177 0.185 0.189 0.188;   % O2
    0.096 0.114 0.126 0.135 0.142 0.145 0.150;   % T3
    0.090 0.111 0.127 0.135 0.144 0.147 0.146;   % T4
    0.090 0.112 0.132 0.150 0.162 0.171 0.178;   % T5
    0.080 0.101 0.123 0.142 0.157 0.173 0.186];  % T6
end

function C = table4Coef()
% TABLE4COEF Regression for RELATIVE sensitivity (PPL_GM/TPL) from scalp & skull
% thickness (mm), per separation. Rows [20 25 30 35 40 45 50], columns
% [intercept scalp skull scalp:skull] (Table 4).
C = [ ...
    0.128 -0.007 -0.008  0.0005;   % 20 mm
    0.165 -0.009 -0.009  0.0005;   % 25 mm
    0.197 -0.010 -0.009  0.0005;   % 30 mm
    0.210 -0.009 -0.008  0.0004;   % 35 mm
    0.209 -0.007 -0.006  0.0001;   % 40 mm
    0.203 -0.006 -0.004  0.0000;   % 45 mm
    0.195 -0.004 -0.002 -0.0001];  % 50 mm
end

function C = table5Coef()
% TABLE5COEF Regression for ABSOLUTE gray-matter partial pathlength PPL_GM (mm)
% from scalp & skull thickness (mm), per separation. Rows [20 25 30 35 40 45
% 50], columns [intercept scalp skull scalp:skull] (Table SD1 / Table 5).
C = [ ...
    13.349 -0.802 -0.725  0.0472;   % 20 mm
    21.116 -1.230 -1.029  0.0688;   % 25 mm
    29.870 -1.520 -1.167  0.0670;   % 30 mm
    35.599 -1.512 -0.957  0.0434;   % 35 mm
    37.672 -1.155 -0.468 -0.0067;   % 40 mm
    38.304 -0.737  0.033 -0.0513;   % 45 mm
    37.753 -0.230  0.501 -0.0925];  % 50 mm
end
