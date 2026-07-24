function result = wpli(x, y, fs, varargin)
% WPLI Weighted Phase-Lag Index between two time series
%
% Computes the debiased Weighted Phase-Lag Index (wPLI) between two signals,
% using Welch cross-spectral estimates. wPLI measures the consistency of the
% imaginary part of the cross-spectrum: it is large when the imaginary
% component is consistently positive or negative across epochs (indicating
% lagged coupling) and near zero when the imaginary component has no preferred
% sign (indicating no lagged coupling or pure zero-lag coupling).
%
% Like imaginary coherence (Nolte 2004), wPLI is insensitive to zero-lag
% coupling from volume conduction, shared recording artifacts, and common
% physiological sources. wPLI additionally down-weights weak cross-spectral
% contributions (low |Im(Sxy)|) relative to strong ones, giving it better
% signal-to-noise properties and reduced sample-size bias compared to the
% plain Phase-Lag Index (PLI). The debiased estimator (Vinck et al. 2011)
% further corrects for the positive bias that arises with finite sample sizes.
%
% References:
%   Vinck, M., Oostenveld, R., van Wingerden, M., Battaglia, F., &
%   Pennartz, C. M. A. (2011). An improved index of phase-synchronization for
%   electrophysiological data in the presence of volume-conduction, noise and
%   sample-size bias. NeuroImage, 55(4), 1548-1565.
%   DOI: 10.1016/j.neuroimage.2011.01.055
%
% Syntax:
%   result = exploreFNIRS.coupling.wpli(x, y, fs)
%   result = exploreFNIRS.coupling.wpli(x, y, fs, 'FreqRange', [0.01 0.1])
%   result = exploreFNIRS.coupling.wpli(x, y, fs, 'FreqRange', [0.01 0.1], ...
%       'WindowLength', 60, 'Overlap', 0.5)
%
% Inputs:
%   x  - [T x 1] first time series (column vector)
%   y  - [T x 1] second time series (column vector)
%   fs - Sampling frequency (Hz), positive scalar
%
% Name-Value Parameters:
%   FreqRange    - [fLow fHigh] frequency band in Hz (default: [0.01, fs/2])
%                  Typical fNIRS hemodynamic band: [0.01, 0.1]
%   WindowLength - Welch segment length in seconds (default: auto, ~8 segments)
%                  Must be long enough to resolve the low frequency of interest
%                  (at least 3 cycles: e.g. 60 s for 0.05 Hz LFO).
%   Overlap      - Fraction of overlap between Welch segments (default: 0.5)
%   NFFT         - FFT length (default: next power of 2 of window length)
%   Debiased     - Which estimator to compute (default: true):
%                    true  - Vinck et al. (2011) Eq. 9 debiased estimator of
%                            SQUARED wPLI: a cross-term (jackknife-style) sum
%                            over segment pairs that removes the positive
%                            sample-size bias incurred by naively squaring
%                            wPLI. Sets result.estimator =
%                            'debiased-squared-wpli'. Because it estimates a
%                            SQUARED quantity it can come out negative
%                            (true value indistinguishable from zero); do not
%                            take its square root or treat it as bounded to
%                            [0, 1] / [-1, 1].
%                    false - standard (biased) MAGNITUDE wPLI = |E[Im(Sxy)]| /
%                            E[|Im(Sxy)|], range [0, 1]. Sets result.estimator
%                            = 'wpli'.
%
% Outputs:
%   result - Struct with fields:
%     .value     - Band-averaged wPLI (scalar). Its scale depends on
%                  .estimator (see above and the Debiased parameter): the
%                  default is the DEBIASED SQUARED-wPLI estimator (unbounded
%                  below, can be negative), not ordinary [0, 1] wPLI. Neither
%                  form distinguishes "x leads y" from "x lags y" -- read
%                  magnitude only as coupling strength (~0 = no lagged
%                  coupling).
%     .pvalue    - NaN (use exploreFNIRS.coupling.surrogateTest for significance)
%     .spectrum  - [F x 1] wPLI spectrum across all frequencies
%     .freqs     - [F x 1] frequency vector (Hz)
%     .method    - 'wpli'
%     .estimator - 'debiased-squared-wpli' (Debiased=true, default) or
%                  'wpli' (Debiased=false) -- names the scale of .value.
%     .windowed  - false
%     .freqRange - [fLow fHigh] band used
%
% Algorithm:
%   1. Fill NaN values via linear interpolation.
%   2. Compute per-segment cross-spectra via Welch short-time DFT epochs.
%   3. At each frequency bin, collect imag(Sxy_k) across epochs k.
%   4. Debiased (default; estimates SQUARED wPLI, Vinck 2011 Eq. 9):
%        wPLI^2_db(f) = (sum_k sum_{j~=k} imag(Sxy_k)*imag(Sxy_j)) /
%                       (sum_k sum_{j~=k} |imag(Sxy_k)*imag(Sxy_j)|)
%      Non-debiased (standard magnitude wPLI):
%        wPLI(f) = |sum_k imag(Sxy_k)| / sum_k |imag(Sxy_k)|
%   5. Average the wPLI spectrum over the requested frequency band.
%
% Example:
%   data = pf2.import.sampleData.fNIR2000();
%   proc = processFNIRS2(data);
%   x = proc.HbO(:, 1);
%
%   % Two identical signals -> wPLI should be near 0 (zero-lag, no imag component)
%   r_same = exploreFNIRS.coupling.wpli(x, x, proc.fs, 'FreqRange', [0.01 0.1]);
%   fprintf('Identical signals: wPLI = %.4f\n', r_same.value);
%
%   % A lag-shifted copy -> wPLI > 0 (consistent imaginary cross-spectrum)
%   lag = round(2 * proc.fs);
%   y = [zeros(lag, 1); x(1:end-lag)];
%   r_lag = exploreFNIRS.coupling.wpli(x, y, proc.fs, 'FreqRange', [0.01 0.1]);
%   fprintf('Lagged copy:       wPLI = %.4f\n', r_lag.value);
%
%   % Cross-channel wPLI
%   r_ch = exploreFNIRS.coupling.wpli(proc.HbO(:,1), proc.HbO(:,2), proc.fs, ...
%       'FreqRange', [0.01 0.1]);
%   fprintf('Channel 1 vs 2:    wPLI = %.4f\n', r_ch.value);
%
% Notes:
%   - wPLI and imaginary coherence (exploreFNIRS.coupling.imagCoherence) are the
%     recommended confound-robust measures for fNIRS hyperscanning. PLV
%     (exploreFNIRS.coupling.plv) does NOT suppress zero-lag confounds.
%   - The debiased estimator (Vinck 2011, Eq. 9) requires at least 2 Welch
%     segments. With very short recordings, increase WindowLength overlap or
%     use a shorter window. The function warns when fewer than 4 segments
%     are available (results may be unreliable).
%   - Requires the Signal Processing Toolbox (cpsd). An error is raised if it
%     is not available.
%   - For within-subject significance, use exploreFNIRS.coupling.surrogateTest.
%   - For inter-brain permutation testing, use
%     exploreFNIRS.hyperscanning.permutationTest.
%
% See also: exploreFNIRS.coupling.imagCoherence, exploreFNIRS.coupling.plv,
%   exploreFNIRS.coupling.coherence, exploreFNIRS.coupling.surrogateTest,
%   exploreFNIRS.hyperscanning.permutationTest, cpsd

    p = inputParser;
    addRequired(p, 'x',  @(v) isnumeric(v) && isvector(v));
    addRequired(p, 'y',  @(v) isnumeric(v) && isvector(v));
    addRequired(p, 'fs', @(v) isnumeric(v) && isscalar(v) && v > 0);
    addParameter(p, 'FreqRange',    [0.01, 0], @(v) isnumeric(v) && numel(v) == 2);
    addParameter(p, 'WindowLength', 0,         @(v) isnumeric(v) && isscalar(v) && v >= 0);
    addParameter(p, 'Overlap',      0.5,       @(v) isnumeric(v) && isscalar(v) && v >= 0 && v < 1);
    addParameter(p, 'NFFT',        0,          @(v) isnumeric(v) && isscalar(v) && v >= 0);
    addParameter(p, 'Debiased',    true,       @(v) islogical(v) || (isnumeric(v) && isscalar(v)));
    parse(p, x, y, fs, varargin{:});
    opts = p.Results;

    % Name the estimator scale up front so it is reported consistently on
    % every return path (including the short-circuit NaN paths below).
    if opts.Debiased
        estimatorLabel = 'debiased-squared-wpli';
    else
        estimatorLabel = 'wpli';
    end

    if ~exist('cpsd', 'file')
        error('exploreFNIRS:coupling:wpli:noToolbox', ...
            ['wpli requires the Signal Processing Toolbox (cpsd). ' ...
             'Install the toolbox or use exploreFNIRS.coupling.plv as ' ...
             'a toolbox-free alternative (note: PLV does not suppress ' ...
             'zero-lag confounds).']);
    end

    x = x(:);
    y = y(:);
    if length(x) ~= length(y)
        error('exploreFNIRS:coupling:wpli', 'x and y must have equal length.');
    end

    % NaN handling: linear interpolation (matches coherence.m / partialCoherence.m)
    valid = ~isnan(x) & ~isnan(y);
    if sum(valid) < 3
        result.value    = NaN;
        result.pvalue   = NaN;
        result.spectrum = NaN;
        result.freqs    = NaN;
        result.method   = 'wpli';
        result.estimator = estimatorLabel;
        result.windowed = false;
        result.freqRange = opts.FreqRange;
        return;
    end
    x = fillNaN(x);
    y = fillNaN(y);

    T = length(x);

    % Frequency band
    freqRange = opts.FreqRange;
    if freqRange(2) <= 0
        freqRange(2) = fs / 2;
    end

    % Window length: auto targets ~8 Welch segments. The 3-cycle low-frequency
    % constraint is applied only when it does not consume more than half the
    % recording (which would leave fewer than 2 segments). When the constraint
    % exceeds T/2 the window is capped at T/4 so at least 3 segments remain.
    if opts.WindowLength <= 0
        winLen = round(T / 8);
        winLen = max(winLen, round(fs * 4));
        if freqRange(1) > 0
            proposed = round(3 / freqRange(1) * fs);
            if proposed > round(T / 2)
                winLen = min(max(winLen, proposed), round(T / 4));
            else
                winLen = max(winLen, proposed);
            end
        end
        winLen = min(winLen, T);
    else
        winLen = round(opts.WindowLength * fs);
    end

    overlapSamp = round(winLen * opts.Overlap);
    stepSamp    = winLen - overlapSamp;

    if opts.NFFT <= 0
        nfft = 2^nextpow2(winLen);
    else
        nfft = opts.NFFT;
    end

    win = hanning(winLen);

    % Collect per-segment imaginary cross-spectra (needed for debiased wPLI)
    starts = 1:stepSamp:(T - winLen + 1);
    nSeg   = length(starts);

    if nSeg < 2
        warning('exploreFNIRS:coupling:wpli:tooFewSegments', ...
            'Only %d Welch segment(s) available; wPLI requires at least 2. Consider a shorter WindowLength.', nSeg);
        result.value    = NaN;
        result.pvalue   = NaN;
        result.spectrum = NaN;
        result.freqs    = (0:nfft/2)' * fs / nfft;
        result.method   = 'wpli';
        result.estimator = estimatorLabel;
        result.windowed = false;
        result.freqRange = freqRange;
        return;
    end

    if nSeg < 4
        warning('exploreFNIRS:coupling:wpli:fewSegments', ...
            'Only %d Welch segments; debiased wPLI may be unreliable. Consider a shorter WindowLength or longer recording.', nSeg);
    end

    % Build matrix of per-segment imaginary cross-spectra [F x nSeg]
    F = nfft / 2 + 1;
    imagSxy = zeros(F, nSeg);
    f = (0:F-1)' * fs / nfft;

    for k = 1:nSeg
        idx = starts(k):(starts(k) + winLen - 1);
        xw  = x(idx) .* win;
        yw  = y(idx) .* win;
        Xw  = fft(xw, nfft);
        Yw  = fft(yw, nfft);
        Sxy_k = Xw(1:F) .* conj(Yw(1:F));
        imagSxy(:, k) = imag(Sxy_k);
    end

    % Debiased SQUARED-wPLI per frequency bin (Vinck 2011, Eq. 9):
    %   wPLI^2_db(f) = (sum_k sum_{j<k} Im(k)*Im(j)) /
    %                  (sum_k sum_{j<k} |Im(k)*Im(j)|)
    % The cross-sum over all ordered pairs (k,j), k ~= j, equals:
    %   numerator   = (sum_k Im(k))^2 - sum_k Im(k)^2
    %   denominator = (sum_k |Im(k)|)^2 - sum_k Im(k)^2
    % (both divided by 2, but cancels in ratio). NOTE: this is an estimator of
    % SQUARED wPLI, not of wPLI itself -- it can be negative and must not be
    % interpreted on the [0, 1] / [-1, 1] scale.
    sumIm   = sum(imagSxy,   2);          % [F x 1]
    sumIm2  = sum(imagSxy.^2, 2);         % [F x 1]  sum of squares
    sumAbsIm  = sum(abs(imagSxy), 2);     % [F x 1]

    if opts.Debiased
        numer = sumIm.^2 - sumIm2;
        denom = sumAbsIm.^2 - sumIm2;
    else
        % Standard (biased) MAGNITUDE wPLI: |E[Im(Sxy)]| / E[|Im(Sxy)|].
        % Absolute value in the numerator is required -- omitting it (as a
        % prior version of this code did) returns a signed ratio in
        % [-1, 1] rather than the [0, 1] magnitude wPLI defined by Vinck 2011.
        numer = abs(sumIm);
        denom = sumAbsIm;
    end

    % Avoid division by zero
    wPLISpec = zeros(F, 1);
    valid_f = denom > eps;
    wPLISpec(valid_f) = numer(valid_f) ./ denom(valid_f);

    % Band-average
    freqMask = f >= freqRange(1) & f <= freqRange(2);
    bandValue = mean(wPLISpec(freqMask), 'omitnan');

    result.value    = bandValue;
    result.pvalue   = NaN;  % use surrogateTest or permutationTest for significance
    result.spectrum = wPLISpec;
    result.freqs    = f;
    result.method   = 'wpli';
    result.estimator = estimatorLabel;
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
