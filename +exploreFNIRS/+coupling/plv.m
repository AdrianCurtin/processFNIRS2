function result = plv(x, y, fs, varargin)
% PLV Phase-Locking Value between two time series
%
% Computes the Phase-Locking Value (PLV) between two band-limited signals
% by extracting the instantaneous phase via the Hilbert transform and
% measuring the consistency of the phase difference across time. PLV = 1
% when the phase difference is perfectly constant (locked); PLV near 0
% indicates no phase coupling.
%
% IMPORTANT CONFOUND NOTE: PLV does not distinguish zero-lag coupling from
% lagged coupling. It is therefore sensitive to volume-conduction, shared
% recording artifacts, and simultaneous systemic physiology that appears at
% zero lag in both signals. For fNIRS hyperscanning, where such confounds
% are expected, use imaginary coherence (exploreFNIRS.coupling.imagCoherence)
% or wPLI (exploreFNIRS.coupling.wpli) instead -- both are insensitive to
% zero-lag common sources. PLV is a useful complementary measure when the
% confound is known to be absent or has been regressed out.
%
% References:
%   Lachaux, J.-P., Rodriguez, E., Martinerie, J., & Varela, F. J. (1999).
%   Measuring phase synchrony in brain signals. Human Brain Mapping, 8(4),
%   194-208. DOI: 10.1002/(sici)1097-0193(1999)8:4<194::aid-hbm4>3.0.co;2-c
%
% Syntax:
%   result = exploreFNIRS.coupling.plv(x, y, fs)
%   result = exploreFNIRS.coupling.plv(x, y, fs, 'FreqRange', [0.01 0.1])
%
% Inputs:
%   x  - [T x 1] first time series (column vector)
%   y  - [T x 1] second time series (column vector)
%   fs - Sampling frequency (Hz), positive scalar
%
% Name-Value Parameters:
%   FreqRange    - [fLow fHigh] frequency band in Hz for bandpass filtering
%                  before Hilbert phase extraction (default: [0.01, fs/2]).
%                  Filtering to a narrow band is strongly recommended before
%                  computing PLV; broadband Hilbert phase is not meaningful.
%                  Typical fNIRS hemodynamic band: [0.01, 0.1]
%   FilterOrder  - Butterworth bandpass filter order (default: 4)
%                  Higher orders give sharper roll-off but may cause ringing.
%
% Outputs:
%   result - Struct with fields:
%     .value    - PLV scalar in [0, 1]. 1 = perfect phase lock; 0 = no coupling.
%     .pvalue   - NaN (use exploreFNIRS.coupling.surrogateTest for significance)
%     .method   - 'plv'
%     .windowed - false
%     .freqRange - [fLow fHigh] band used for bandpass filtering
%
% Algorithm:
%   1. Fill NaN values via linear interpolation.
%   2. Bandpass-filter x and y to FreqRange using a zero-phase Butterworth filter.
%   3. Extract instantaneous phase phi_x(t) and phi_y(t) via the Hilbert transform.
%   4. Compute PLV = |mean(exp(1i * (phi_x - phi_y)))| over time.
%
% Example:
%   data = pf2.import.sampleData.fNIR2000();
%   proc = processFNIRS2(data);
%   x = proc.HbO(:, 1);
%
%   % Two identical signals -> PLV should be 1
%   r_same = exploreFNIRS.coupling.plv(x, x, proc.fs, 'FreqRange', [0.01 0.1]);
%   fprintf('Identical signals: PLV = %.4f\n', r_same.value);
%
%   % Independent noise -> PLV near 0
%   y = randn(size(x));
%   r_rand = exploreFNIRS.coupling.plv(x, y, proc.fs, 'FreqRange', [0.01 0.1]);
%   fprintf('Random signals:    PLV = %.4f\n', r_rand.value);
%
%   % Cross-channel PLV
%   r_ch = exploreFNIRS.coupling.plv(proc.HbO(:,1), proc.HbO(:,2), proc.fs, ...
%       'FreqRange', [0.01 0.1]);
%   fprintf('Channel 1 vs 2:    PLV = %.4f\n', r_ch.value);
%
% Notes:
%   - PLV requires band-limiting before Hilbert phase extraction. The
%     FreqRange parameter controls the bandpass filter applied before the
%     Hilbert transform. For broadband analysis, use the Pearson or coherence
%     measures instead.
%   - Uses MATLAB's filtfilt for zero-phase filtering (no phase distortion).
%   - PLV does NOT suppress zero-lag confounds. For confound-robust measures
%     see exploreFNIRS.coupling.imagCoherence and exploreFNIRS.coupling.wpli.
%   - For within-subject significance testing, use exploreFNIRS.coupling.surrogateTest.
%   - For inter-brain permutation testing, use
%     exploreFNIRS.hyperscanning.permutationTest.
%
% See also: exploreFNIRS.coupling.imagCoherence, exploreFNIRS.coupling.wpli,
%   exploreFNIRS.coupling.coherence, exploreFNIRS.coupling.surrogateTest

    p = inputParser;
    addRequired(p, 'x',  @(v) isnumeric(v) && isvector(v));
    addRequired(p, 'y',  @(v) isnumeric(v) && isvector(v));
    addRequired(p, 'fs', @(v) isnumeric(v) && isscalar(v) && v > 0);
    addParameter(p, 'FreqRange',   [0.01, 0], @(v) isnumeric(v) && numel(v) == 2);
    addParameter(p, 'FilterOrder', 4,         @(v) isnumeric(v) && isscalar(v) && v > 0);
    parse(p, x, y, fs, varargin{:});
    opts = p.Results;

    x = x(:);
    y = y(:);
    if length(x) ~= length(y)
        error('exploreFNIRS:coupling:plv', 'x and y must have equal length.');
    end

    % NaN handling: linear interpolation (matches coherence.m / partialCoherence.m)
    valid = ~isnan(x) & ~isnan(y);
    if sum(valid) < 3
        result.value    = NaN;
        result.pvalue   = NaN;
        result.method   = 'plv';
        result.windowed = false;
        result.freqRange = opts.FreqRange;
        return;
    end
    x = fillNaN(x);
    y = fillNaN(y);

    % Frequency band
    freqRange = opts.FreqRange;
    if freqRange(2) <= 0
        freqRange(2) = fs / 2;
    end
    % Clamp upper bound to Nyquist
    freqRange(2) = min(freqRange(2), fs / 2 - eps);

    % Bandpass filter before Hilbert: signals must be band-limited for PLV to
    % be meaningful. Design a Butterworth bandpass filter.
    nyq = fs / 2;
    Wn = freqRange / nyq;
    Wn = max(Wn, 1e-6);
    Wn = min(Wn, 1 - 1e-6);

    if Wn(1) >= Wn(2)
        % Degenerate band: skip filtering (pass-through)
        xFilt = x;
        yFilt = y;
    else
        try
            [b, a] = butter(opts.FilterOrder, Wn, 'bandpass');
            xFilt = filtfilt(b, a, x);
            yFilt = filtfilt(b, a, y);
        catch
            % filtfilt may fail for very short signals or extreme filter orders;
            % fall back to unfiltered signals with a warning.
            warning('exploreFNIRS:coupling:plv:filterFailed', ...
                'Bandpass filter failed (signal too short or filter order too high). PLV computed on unfiltered signals.');
            xFilt = x;
            yFilt = y;
        end
    end

    % Instantaneous phase via Hilbert transform
    phiX = angle(hilbert(xFilt));
    phiY = angle(hilbert(yFilt));

    % PLV = |<exp(i * (phi_x - phi_y))>|
    phaseDiff = phiX - phiY;
    plvVal = abs(mean(exp(1i * phaseDiff)));

    result.value    = plvVal;
    result.pvalue   = NaN;  % use surrogateTest or permutationTest for significance
    result.method   = 'plv';
    result.windowed = false;
    result.freqRange = freqRange;
end


%%_Subfunctions_________________________________________________________

function v = fillNaN(v)
% FILLNAN Linear interpolation of NaN values
%
% Inputs:
%   v - [T x 1] signal possibly containing NaN values
%
% Outputs:
%   v - [T x 1] signal with NaNs replaced by linear interpolation
    nanIdx = isnan(v);
    if ~any(nanIdx), return; end
    if all(nanIdx), v(:) = 0; return; end
    t = (1:length(v))';
    v(nanIdx) = interp1(t(~nanIdx), v(~nanIdx), t(nanIdx), 'linear', 'extrap');
end
