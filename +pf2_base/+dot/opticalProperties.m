function props = opticalProperties(wavelengths, varargin)
% OPTICALPROPERTIES Bulk adult-head optical properties for DOT forward modelling
%
% Returns the absorption (mu_a) and reduced scattering (mu_s') coefficients of
% adult head tissue at the requested wavelength(s), plus the HbO/HbR molar
% extinction coefficients used for spectral reconstruction. Values are bulk
% single-layer defaults intended for an atlas (template) forward model; they
% set the penetration depth of the photon-sensitivity "banana" and the
% wavelength weighting of spectral unmixing. They are deliberately overridable
% — for a specific study, substitute measured or layered-model values.
%
% Syntax:
%   props = pf2_base.dot.opticalProperties(wavelengths)
%   props = pf2_base.dot.opticalProperties(wavelengths, 'mua', mua, 'musp', musp)
%
% Inputs:
%   wavelengths - [1 x W] wavelengths in nm (e.g. [730 850]).
%
% Inputs (name-value):
%   'mua'  - Override absorption per wavelength [1 x W] (mm^-1). Default:
%            interpolated from the built-in bulk adult-head table.
%   'musp' - Override reduced scattering per wavelength [1 x W] (mm^-1).
%
% Outputs:
%   props - struct with fields (each [1 x W], aligned to `wavelengths`):
%           .wavelengths - echo of input (nm)
%           .mua         - absorption coefficient (mm^-1)
%           .musp        - reduced scattering coefficient (mm^-1)
%           .D           - diffusion coefficient 1/(3*(mua+musp)) (mm)
%           .mueff       - effective attenuation sqrt(3*mua*(mua+musp)) (mm^-1)
%           .extHbO      - HbO molar extinction (mm^-1 / (mol/L)) per wavelength
%           .extHbR      - HbR molar extinction (mm^-1 / (mol/L)) per wavelength
%
% Algorithm:
%   mu_a / mu_s' are linearly interpolated (nearest-clamped outside range) from
%   a small adult-head reference table. Extinction coefficients are linearly
%   interpolated from the Wray et al. (1988) near-infrared haemoglobin spectra
%   (converted from cm^-1/M to mm^-1/(mol/L)). The diffusion approximation then
%   gives D and the effective attenuation mu_eff.
%
% References:
%   Custo, A., Wells, W. M., Barnett, A. H., Hillman, E. M. C. & Boas, D. A.
%     (2006). Effective scattering coefficient of the cerebral spinal fluid in
%     adult head models for diffuse optical imaging. Applied Optics, 45(19),
%     4747-4755. DOI: 10.1364/AO.45.004747
%   Wray, S., Cope, M., Delpy, D. T., Wyatt, J. S. & Reynolds, E. O. R. (1988).
%     Characterization of the near infrared absorption spectra of cytochrome
%     aa3 and haemoglobin for the non-invasive monitoring of cerebral
%     oxygenation. Biochimica et Biophysica Acta, 933(1), 184-192.
%     DOI: 10.1016/0005-2728(88)90069-2
%
% Example:
%   props = pf2_base.dot.opticalProperties([730 850]);
%   penetrationScale = 1 ./ props.mueff;   % ~mm
%
% See also: pf2_base.dot.greensFunction, pf2_base.dot.sensitivityMatrix

p = inputParser;
addRequired(p, 'wavelengths', @(x) isnumeric(x) && isvector(x) && all(x > 0));
addParameter(p, 'mua', [], @(x) isempty(x) || isnumeric(x));
addParameter(p, 'musp', [], @(x) isempty(x) || isnumeric(x));
parse(p, wavelengths, varargin{:});

wl = wavelengths(:)';
W = numel(wl);

% --- Bulk adult-head reference table (mm^-1) -------------------------------
% Representative single-layer adult values across the NIRS window. Sources:
% adult head models in Custo et al. (2006) and the broader DOT literature.
refWL   = [690,   750,   780,   808,   830,   850];
refMua  = [0.0178 0.0165 0.0185 0.0200 0.0205 0.0192];
refMusp = [1.05   0.96   0.92   0.88   0.85   0.83];

mua  = p.Results.mua;
musp = p.Results.musp;
if isempty(mua)
    mua = interp1(refWL, refMua, wl, 'linear', NaN);
    mua = fillClamp(mua, wl, refWL, refMua);
else
    mua = checkOverride(mua, W, 'mua');
end
if isempty(musp)
    musp = interp1(refWL, refMusp, wl, 'linear', NaN);
    musp = fillClamp(musp, wl, refWL, refMusp);
else
    musp = checkOverride(musp, W, 'musp');
end

% --- HbO/HbR molar extinction (Wray et al. 1988), mm^-1/(mol/L) ------------
% Tabulated extinction in cm^-1/(mol/L); divide by 10 to mm^-1, used by
% spectral reconstruction to map per-wavelength absorption to chromophores.
extWL  = [690,   730,   750,   780,   808,   830,   850];
extHbO = [276,   390,   518,   735,   880,   974,   1058];   % cm^-1/M
extHbR = [2051,  1102,  1011,  812,   703,   693,   691];    % cm^-1/M
eHbO = interp1(extWL, extHbO, wl, 'linear', NaN) / 10;
eHbR = interp1(extWL, extHbR, wl, 'linear', NaN) / 10;
eHbO = fillClamp(eHbO, wl, extWL, extHbO/10);
eHbR = fillClamp(eHbR, wl, extWL, extHbR/10);

D = 1 ./ (3 * (mua + musp));
mueff = sqrt(3 * mua .* (mua + musp));

props = struct('wavelengths', wl, 'mua', mua, 'musp', musp, ...
    'D', D, 'mueff', mueff, 'extHbO', eHbO, 'extHbR', eHbR);
end

function v = fillClamp(v, wl, refWL, refVals)
% Nearest-edge clamp for wavelengths outside the reference table.
bad = isnan(v);
if any(bad)
    below = wl < min(refWL);
    above = wl > max(refWL);
    v(below) = refVals(1);
    v(above) = refVals(end);
    v(isnan(v)) = refVals(1);
end
end

function v = checkOverride(v, W, name)
v = v(:)';
if numel(v) == 1
    v = repmat(v, 1, W);
elseif numel(v) ~= W
    error('pf2:dot:opticalProperties:overrideSize', ...
        '%s override must be scalar or have one value per wavelength (got %d, expected %d).', ...
        name, numel(v), W);
end
end
