function result = wcoherence(x, y, fs, varargin)
% WCOHERENCE Wavelet coherence (WCT) between two time series
%
% Computes wavelet coherence using the continuous wavelet transform,
% providing time-frequency resolved coupling between two signals.
% Returns mean coherence in a frequency band as the scalar coupling
% value, plus the full time-frequency coherence matrix for visualization.
%
% Syntax:
%   result = exploreFNIRS.coupling.wcoherence(x, y, fs)
%   result = exploreFNIRS.coupling.wcoherence(x, y, fs, 'FreqRange', [0.01 0.1])
%   result = exploreFNIRS.coupling.wcoherence(x, y, fs, 'PhaseOutput', true)
%
% Inputs:
%   x  - [T x 1] First time series (column vector)
%   y  - [T x 1] Second time series (column vector)
%   fs - Sampling frequency (Hz), positive scalar
%
% Name-Value Parameters:
%   FreqRange       - [fLow fHigh] frequency band in Hz (default: [0.01, fs/2])
%                     Typical fNIRS: [0.01, 0.1] for hemodynamic
%   VoicesPerOctave - Frequency resolution (default: 10, range 1-48)
%   ApplyCOI        - Exclude cone-of-influence region from scalar value
%                     (default: true)
%   PhaseOutput     - Return phase angles from cross-spectrum (default: false)
%
% Outputs:
%   result - Struct with fields:
%     .value     - Mean WCT magnitude in FreqRange (scalar, COI-masked if enabled)
%     .pvalue    - NaN (use permutation test for significance)
%     .method    - 'wcoherence'
%     .windowed  - false
%     .wcoh      - [F x T] wavelet coherence matrix (0 to 1)
%     .freqs     - [F x 1] frequency vector (Hz)
%     .times     - [T x 1] time vector (seconds)
%     .coi       - [T x 1] cone of influence boundary (Hz)
%     .freqRange - [fLow fHigh] band used for scalar value
%     .phase     - [F x T] phase angles in radians (if PhaseOutput=true)
%
% Notes:
%   Requires MATLAB Wavelet Toolbox. Uses str2func('wcoherence') to avoid
%   shadowing the builtin function.
%
%   The cone of influence marks the region where edge effects are
%   significant. By default, these regions are excluded from the scalar
%   .value computation.
%
% References:
%   Grinsted, A., Moore, J.C. & Jevrejeva, S. (2004). Application of the
%   cross wavelet transform and wavelet coherence to geophysical time
%   series. Nonlinear Processes in Geophysics, 11, 561-566.
%
% See also: exploreFNIRS.coupling.coherence, exploreFNIRS.coupling.pearson,
%   exploreFNIRS.coupling.plotWcoherence

    p = inputParser;
    addRequired(p, 'x', @(v) isnumeric(v) && isvector(v));
    addRequired(p, 'y', @(v) isnumeric(v) && isvector(v));
    addRequired(p, 'fs', @(v) isnumeric(v) && isscalar(v) && v > 0);
    addParameter(p, 'FreqRange', [], @(v) isempty(v) || (isnumeric(v) && numel(v) == 2));
    addParameter(p, 'VoicesPerOctave', 10, @(v) isnumeric(v) && isscalar(v) && v >= 1 && v <= 48);
    addParameter(p, 'ApplyCOI', true, @islogical);
    addParameter(p, 'PhaseOutput', false, @islogical);
    parse(p, x, y, fs, varargin{:});
    opts = p.Results;

    x = x(:);
    y = y(:);
    if length(x) ~= length(y)
        error('exploreFNIRS:coupling:wcoherence', 'x and y must have equal length');
    end

    T = length(x);

    % Default frequency range
    if isempty(opts.FreqRange)
        freqRange = [0.01, fs / 2];
    else
        freqRange = opts.FreqRange;
    end
    fLow = max(freqRange(1), 1 / (T / fs));
    fHigh = min(freqRange(2), fs / 2);

    % NaN handling: linear interpolation
    x = fillNaN(x);
    y = fillNaN(y);

    % Call MATLAB's wcoherence via str2func to avoid shadowing
    wcoherenceFn = str2func('wcoherence');
    [wcoh, wcs, freqs, coi] = wcoherenceFn(x, y, fs, ...
        'VoicesPerOctave', opts.VoicesPerOctave);

    % Build time vector
    times = (0:T-1)' / fs;

    % Ensure coi is a row vector for broadcasting
    coi = coi(:)';

    % Frequency band mask
    freqMask = freqs >= fLow & freqs <= fHigh;

    % Build validity mask: freq in range AND inside cone of influence
    % COI convention: freqs < coi(t) are edge-affected (outside cone)
    if opts.ApplyCOI
        coiMask = bsxfun(@ge, freqs(:), coi);  % freqs >= coi(t) → valid
    else
        coiMask = true(size(wcoh));
    end

    validMask = bsxfun(@and, freqMask(:), true(1, T)) & coiMask;

    % Scalar value: mean coherence in valid region
    if any(validMask(:))
        result.value = mean(wcoh(validMask), 'omitnan');
    else
        result.value = NaN;
    end

    % No analytic p-value for WCT
    result.pvalue = NaN;
    result.method = 'wcoherence';
    result.windowed = false;
    result.wcoh = wcoh;
    result.freqs = freqs;
    result.times = times;
    result.coi = coi(:);
    result.freqRange = [fLow, fHigh];

    if opts.PhaseOutput
        result.phase = angle(wcs);
    end

end


function v = fillNaN(v)
% Linear interpolation of NaN values
    nanIdx = isnan(v);
    if ~any(nanIdx), return; end
    if all(nanIdx), v(:) = 0; return; end
    t = (1:length(v))';
    v(nanIdx) = interp1(t(~nanIdx), v(~nanIdx), t(nanIdx), 'linear', 'extrap');
end
