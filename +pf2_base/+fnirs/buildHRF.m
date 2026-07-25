function hrf = buildHRF(fs, t, varargin)
% BUILDHRF Build hemodynamic response function for fNIRS/fMRI GLM analysis
%
% Generates a hemodynamic response function (HRF) at a specified sampling
% frequency. Two variants: the double-gamma difference-of-gammas model
% (Lindquist et al. 2009, default 'canonical') and a simpler single-gamma
% response with no undershoot ('singlegamma'). Output is normalised to
% peak = 1 for both. NOTE: 'singlegamma' is NOT Glover's (1999) HRF -- Glover's
% published model is itself a difference of two gamma terms (like the canonical
% double-gamma); the single-gamma here is a no-undershoot approximation.
%
% References:
%   Lindquist, M. A., Meng Loh, J., Atlas, L. Y., & Wager, T. D. (2009).
%   Modeling the hemodynamic response function in fMRI: efficiency, bias and
%   mis-modeling. NeuroImage, 45(1 Suppl), S187-S198.
%   DOI: 10.1016/j.neuroimage.2008.10.065
%   Glover, G. H. (1999). Deconvolution of Impulse Response in Event-Related
%   BOLD fMRI. NeuroImage, 9(4), 416-429. DOI: 10.1006/nimg.1998.0419
%   (Glover's two-gamma model corresponds to the 'canonical' double-gamma basis,
%   not the 'singlegamma' variant.)
%
% Syntax:
%   hrf = buildHRF()
%   hrf = buildHRF(fs)
%   hrf = buildHRF(fs, t)
%   hrf = buildHRF(fs, t, alpha1, alpha2, beta1, beta2, c)
%   hrf = buildHRF(fs, t, 'Basis', 'singlegamma')
%   hrf = buildHRF(fs, t, 'Basis', 'singlegamma', 'Peak', 6, 'Width', 1)
%
% Inputs:
%   fs  - Sampling frequency in Hz (default: 20)
%         Higher values produce smoother HRF curves.
%   t   - Duration of HRF in seconds (default: 32)
%         Should be long enough to capture the full undershoot.
%
% For the double-gamma (default) variant, positional parameters 3-7 are:
%   alpha1 - Shape parameter for primary gamma (default: 6)
%   alpha2 - Shape parameter for undershoot gamma (default: 16)
%   beta1  - Scale parameter for primary gamma (default: 1)
%   beta2  - Scale parameter for undershoot gamma (default: beta1)
%   c      - Ratio of undershoot to main response (default: 1/6)
%            Controls the depth of the post-stimulus undershoot.
%
% For the single-gamma variant, pass name-value pairs:
%   'Basis'       - HRF model: 'canonical' (default) or 'singlegamma'
%                   ('glover' is accepted as a deprecated alias of
%                   'singlegamma'). 'canonical' uses the double-gamma
%                   difference-of-gammas (the two-gamma form of Glover/SPM);
%                   'singlegamma' uses a single gamma with NO undershoot term.
%   'Peak'        - Time-to-peak in seconds for the single-gamma (default: 6).
%                   ('GloverPeak' accepted as a deprecated alias.)
%   'Width'       - Width (standard-deviation-like scale) for the single-gamma
%                   (default: 1); larger values broaden the response.
%                   ('GloverWidth' accepted as a deprecated alias.)
%
% Outputs:
%   hrf - Hemodynamic response function [N x 2]
%         Column 1: Time in seconds
%         Column 2: HRF amplitude (normalised to peak = 1)
%
% Algorithm (double-gamma, Lindquist et al. 2009 eq. A1):
%   1. primary   = (t.^(a1-1) .* b1.^a1 .* exp(-b1.*t)) / gamma(a1)
%   2. undershoot= (t.^(a2-1) .* b2.^a2 .* exp(-b2.*t)) / gamma(a2)
%   3. hrf_raw   = primary - c * undershoot
%   4. hrf       = hrf_raw / max(hrf_raw)   [normalised]
%
% Algorithm (single-gamma, no undershoot):
%   The single-gamma HRF is a scaled gamma PDF parameterised by a time-to-peak
%   (peak) and a width factor (w). Let shape a = (peak/w)^2 and scale
%   b = w^2/peak. Then:
%   1. hrf_raw = (t.^(a-1) .* exp(-t./b)) / (b.^a .* gamma(a))
%   2. hrf     = hrf_raw / max(hrf_raw)   [normalised]
%
% Example:
%   % Default double-gamma HRF at 10 Hz
%   hrf = buildHRF(10);
%   plot(hrf(:,1), hrf(:,2));
%   xlabel('Time (s)'); ylabel('Amplitude');
%   title('Canonical HRF');
%
%   % Single-gamma (no undershoot) variant
%   hrf_g = buildHRF(10, 32, 'Basis', 'singlegamma');
%   hold on; plot(hrf_g(:,1), hrf_g(:,2), '--');
%   legend('Double-gamma', 'Single-gamma');
%
%   % Custom fNIRS (slower response) double-gamma
%   hrf_slow = buildHRF(10, 40, 5, 15, 0.8, 0.8, 1/7);
%
%   % Use for stimulus convolution
%   data = pf2.import.sampleData.fNIR2000();
%   stim = zeros(size(data.time));
%   stim(round(data.markers.Time * data.fs)) = 1;
%   expected = conv(stim, hrf(:,2), 'same');
%
% Notes:
%   - Both variants are normalised to peak = 1.
%   - The double-gamma canonical matches SPM, MNE-NIRS, NIRS Toolbox, and
%     Cedalion conventions (Lindquist et al. 2009 parameters).
%   - The single-gamma has no undershoot term; it is simpler but less
%     physiologically complete, and it is NOT Glover's two-gamma model (use
%     'canonical' for that). Useful for comparing HRF shape assumptions.
%   - Name-value parameters ('Basis', 'Peak', 'Width'; the 'Glover*' aliases)
%     are only parsed when the fourth argument is a char or when fewer than 7
%     positional arguments are provided with none of them being a char.
%   - For backward compatibility, calling buildHRF with 5-7 positional
%     numeric arguments always invokes the double-gamma model.
%
% See also: pf2_base.fnirs.buildDesignMatrix, pf2_base.fnirs.fitGLM, conv

% --- Default positional arguments ---
if nargin < 1 || isempty(fs)
    fs = 20;
end
if nargin < 2 || isempty(t)
    t = 32;
end

% --- Detect calling convention ---
% If any argument beyond fs/t is a char/string, treat everything as name-value.
% If 3-7 numeric positional args are given, use the legacy double-gamma path.
useNameValue = false;
if nargin > 2
    % varargin{1} is the third argument
    if ischar(varargin{1}) || isstring(varargin{1})
        useNameValue = true;
    end
end

if useNameValue
    % --- Name-value interface ---
    p = inputParser;
    % 'singlegamma' is the honest name for the no-undershoot single-gamma
    % response; 'glover' is kept as a deprecated ALIAS. Note this is NOT
    % Glover's published difference-of-two-gammas model (that is the default
    % 'canonical' double-gamma) -- it is a simpler single-gamma approximation.
    p.addParameter('Basis', 'canonical', ...
        @(x) ismember(lower(char(x)), {'canonical', 'singlegamma', 'glover'}));
    p.addParameter('Peak', 6, ...
        @(x) isnumeric(x) && isscalar(x) && x > 0);
    p.addParameter('Width', 1, ...
        @(x) isnumeric(x) && isscalar(x) && x > 0);
    p.addParameter('GloverPeak', [], ...   % deprecated alias for 'Peak'
        @(x) isempty(x) || (isnumeric(x) && isscalar(x) && x > 0));
    p.addParameter('GloverWidth', [], ...  % deprecated alias for 'Width'
        @(x) isempty(x) || (isnumeric(x) && isscalar(x) && x > 0));
    p.parse(varargin{:});
    basis = lower(p.Results.Basis);
    gammaPeak = p.Results.Peak;
    gammaWidth = p.Results.Width;
    if ~isempty(p.Results.GloverPeak),  gammaPeak  = p.Results.GloverPeak;  end
    if ~isempty(p.Results.GloverWidth), gammaWidth = p.Results.GloverWidth; end

    time = (0 : 1/fs : t)';

    switch basis
        case {'singlegamma', 'glover'}
            hrf = buildSingleGamma(time, gammaPeak, gammaWidth);
        otherwise
            % Default canonical double-gamma with standard parameters
            hrf = buildDoubleGamma(time, 6, 16, 1, 1, 1/6);
    end
else
    % --- Legacy positional interface (double-gamma) ---
    % Unpack up to 5 extra positional args: alpha1 alpha2 beta1 beta2 c
    alpha1 = 6;  alpha2 = 16;  beta1 = 1;  beta2 = 1;  c = 1/6;
    if numel(varargin) >= 5
        alpha1 = varargin{1};
        alpha2 = varargin{2};
        beta1  = varargin{3};
        beta2  = varargin{4};
        c      = varargin{5};
    end

    time = (0 : 1/fs : t)';
    hrf = buildDoubleGamma(time, alpha1, alpha2, beta1, beta2, c);
end

end

%%_Subfunctions_________________________________________________________

function hrf = buildDoubleGamma(time, alpha1, alpha2, beta1, beta2, c)
% BUILDDOUBLEGAMMA Double-gamma (difference-of-gammas) HRF
%
% Implements Lindquist et al. (2009) equation A1.
%
% Inputs:
%   time   - Time vector [N x 1] in seconds (starting at 0)
%   alpha1 - Shape of primary gamma
%   alpha2 - Shape of undershoot gamma
%   beta1  - Rate of primary gamma
%   beta2  - Rate of undershoot gamma
%   c      - Undershoot scaling factor
%
% Outputs:
%   hrf - [N x 2]: column 1 = time, column 2 = normalised amplitude

t = time(:)';

primary    = (t .^ (alpha1-1) .* beta1.^alpha1 .* exp(-beta1 .* t)) / gamma(alpha1);
undershoot = (t .^ (alpha2-1) .* beta2.^alpha2 .* exp(-beta2 .* t)) / gamma(alpha2);
raw = primary - c * undershoot;

pk = max(raw);
if pk > 0
    raw = raw / pk;
end

hrf = [time(:), raw(:)];

end


function hrf = buildSingleGamma(time, peak, width)
% BUILDSINGLEGAMMA Single-gamma HRF (no undershoot)
%
% A unimodal gamma-PDF response parameterised by time-to-peak and a width
% factor, with NO undershoot term. Output is normalised to peak = 1. This is a
% simplification, NOT Glover's (1999) published HRF, which is a DIFFERENCE of
% two gamma terms (positive response + undershoot); for that two-gamma model
% use the default 'canonical' double-gamma basis.
%
% The gamma PDF with shape a = (peak/width)^2 and scale b = width^2/peak gives a
% unimodal response whose mode is at (a-1)*b = peak - width^2/peak, converging
% to 'peak' as width->0.
%
% Inputs:
%   time  - Time vector [N x 1] in seconds
%   peak  - Approximate time-to-peak in seconds (default: 6)
%   width - Width parameter in seconds (default: 1)
%
% Outputs:
%   hrf - [N x 2]: column 1 = time, column 2 = normalised amplitude

t = time(:)';

a = (peak / width)^2;
b = (width^2) / peak;

% Gamma PDF: t^(a-1) * exp(-t/b) / (b^a * Gamma(a))
% Avoid t=0 issues (0^(a-1) is 0 when a>1, but log path is safer)
raw = zeros(size(t));
pos = t > 0;
if any(pos)
    raw(pos) = (t(pos) .^ (a - 1)) .* exp(-t(pos) ./ b) / (b^a * gamma(a));
end

pk = max(raw);
if pk > 0
    raw = raw / pk;
end

hrf = [time(:), raw(:)];

end
