function result = imagCoherence(x, y, fs, varargin)
% IMAGCOHERENCE Imaginary coherence between two time series
%
% Computes the band-averaged absolute imaginary part of the complex coherency
% between two signals, using Welch cross-spectral estimates (cpsd). The
% imaginary part of coherency is zero for any coupling at exactly zero lag;
% it is therefore insensitive to volume conduction, shared recording artifacts,
% and other instantaneous common sources that inflate ordinary coherence and
% PLV. This makes imaginary coherence the recommended measure for fNIRS
% hyperscanning where simultaneous physiological noise (respiration, Mayer
% waves) appears at zero lag in both brain signals.
%
% IMPORTANT: This function band-averages abs(imag(coherency)), NOT
% imag(coherency). Signed imaginary coherency alternates sign across a
% frequency band and sums to near zero; taking the absolute value before
% averaging gives the correct band-averaged measure of non-zero-lag coupling.
%
% Note on toolbox dependency: this implementation uses MATLAB's cpsd (Signal
% Processing Toolbox). If cpsd is unavailable, use the wavelet-based path
% via exploreFNIRS.coupling.wcoherence with 'PhaseOutput', true.
%
% References:
%   Nolte, G., Bai, O., Wheaton, L., Mari, Z., Vorbach, S., & Hallett, M.
%   (2004). Identifying true brain interaction from EEG data using the
%   imaginary part of coherency. Clinical Neurophysiology, 115(10),
%   2292-2307. DOI: 10.1016/j.clinph.2004.04.029
%
% Syntax:
%   result = exploreFNIRS.coupling.imagCoherence(x, y, fs)
%   result = exploreFNIRS.coupling.imagCoherence(x, y, fs, 'FreqRange', [0.01 0.1])
%   result = exploreFNIRS.coupling.imagCoherence(x, y, fs, 'FreqRange', [0.01 0.1], ...
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
%                  Mayer wave / VLFO: [0.04, 0.15]
%   WindowLength - Welch segment length in seconds (default: auto, ~8 segments)
%                  Longer windows give finer frequency resolution. Should span
%                  at least 3 cycles of the lowest frequency of interest.
%   Overlap      - Fraction of overlap between Welch segments (default: 0.5)
%   NFFT         - FFT length (default: next power of 2 of window length)
%
% Outputs:
%   result - Struct with fields:
%     .value     - Band-averaged |imag(coherency)| (scalar, range [0, 1])
%                  Zero for pure zero-lag coupling; >0 for lagged coupling.
%     .pvalue    - NaN (use exploreFNIRS.coupling.surrogateTest for significance)
%     .spectrum  - [F x 1] |imag(coherency)| spectrum across all frequencies
%     .freqs     - [F x 1] frequency vector (Hz)
%     .method    - 'imagCoherence'
%     .windowed  - false
%     .freqRange - [fLow fHigh] band used
%
% Algorithm:
%   1. Fill NaN values via linear interpolation.
%   2. Compute cross-spectral density Sxy(f) and auto-spectra Sxx(f), Syy(f)
%      via Welch's method (cpsd with Hann window).
%   3. Form complex coherency: C(f) = Sxy(f) / sqrt(Sxx(f) * Syy(f)).
%   4. Compute absolute imaginary part: |imag(C(f))|.
%   5. Average over the requested frequency band.
%
% Example:
%   % Two identical signals -> imagCoherence should be near zero
%   data = pf2.import.sampleData.fNIR2000();
%   proc = processFNIRS2(data);
%   x = proc.HbO(:, 1);
%   result_same = exploreFNIRS.coupling.imagCoherence(x, x, proc.fs, ...
%       'FreqRange', [0.01 0.1]);
%   fprintf('Identical signals: imagCoh = %.4f\n', result_same.value);
%
%   % A lag-shifted copy -> imagCoherence should be > 0
%   lag = round(2 * proc.fs);
%   y = [zeros(lag, 1); x(1:end-lag)];
%   result_lag = exploreFNIRS.coupling.imagCoherence(x, y, proc.fs, ...
%       'FreqRange', [0.01 0.1]);
%   fprintf('Lagged copy:        imagCoh = %.4f\n', result_lag.value);
%
%   % Cross-channel imaginary coherence
%   result_ch = exploreFNIRS.coupling.imagCoherence( ...
%       proc.HbO(:,1), proc.HbO(:,2), proc.fs, 'FreqRange', [0.01 0.1]);
%   fprintf('Channel 1 vs 2:     imagCoh = %.4f\n', result_ch.value);
%
% Notes:
%   - imagCoherence and wPLI (exploreFNIRS.coupling.wpli) are the confound-robust
%     measures for fNIRS hyperscanning; PLV (exploreFNIRS.coupling.plv) does NOT
%     suppress zero-lag/shared-signal confounds.
%   - Requires the Signal Processing Toolbox (cpsd). An error is raised if it
%     is not available.
%   - For within-subject significance testing, use exploreFNIRS.coupling.surrogateTest.
%   - For inter-brain permutation testing, use
%     exploreFNIRS.hyperscanning.permutationTest.
%
% See also: exploreFNIRS.coupling.wpli, exploreFNIRS.coupling.plv,
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
    parse(p, x, y, fs, varargin{:});
    opts = p.Results;

    if ~exist('cpsd', 'file')
        error('exploreFNIRS:coupling:imagCoherence:noToolbox', ...
            ['imagCoherence requires the Signal Processing Toolbox (cpsd). ' ...
             'Install the toolbox or use exploreFNIRS.coupling.wcoherence ' ...
             'with ''PhaseOutput'', true as a toolbox-free alternative.']);
    end

    x = x(:);
    y = y(:);
    if length(x) ~= length(y)
        error('exploreFNIRS:coupling:imagCoherence', ...
            'x and y must have equal length.');
    end

    % NaN handling: linear interpolation (matches coherence.m / partialCoherence.m)
    valid = ~isnan(x) & ~isnan(y);
    if sum(valid) < 3
        result.value    = NaN;
        result.pvalue   = NaN;
        result.spectrum = NaN;
        result.freqs    = NaN;
        result.method   = 'imagCoherence';
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

    if opts.NFFT <= 0
        nfft = 2^nextpow2(winLen);
    else
        nfft = opts.NFFT;
    end

    win = hanning(winLen);

    % Cross-spectrum and auto-spectra via Welch
    [Sxy, f] = cpsd(x, y, win, overlapSamp, nfft, fs);
    [Sxx, ~] = cpsd(x, x, win, overlapSamp, nfft, fs);
    [Syy, ~] = cpsd(y, y, win, overlapSamp, nfft, fs);

    % Complex coherency; auto-spectra are real (imaginary part is numerical noise)
    coherency = Sxy ./ sqrt(real(Sxx) .* real(Syy) + eps);

    % Absolute imaginary part -- signed imag coherency cancels across a band
    imagCoh = abs(imag(coherency));

    % Band-average
    freqMask = f >= freqRange(1) & f <= freqRange(2);
    bandValue = mean(imagCoh(freqMask), 'omitnan');

    result.value    = bandValue;
    result.pvalue   = NaN;  % use surrogateTest or permutationTest for significance
    result.spectrum = imagCoh;
    result.freqs    = f;
    result.method   = 'imagCoherence';
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
