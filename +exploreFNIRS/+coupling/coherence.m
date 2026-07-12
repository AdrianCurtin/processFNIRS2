function result = coherence(x, y, fs, varargin)
% COHERENCE Magnitude-squared coherence between two time series
%
% Computes magnitude-squared coherence using MATLAB's mscohere, with
% optional frequency-range filtering to focus on hemodynamic frequencies.
%
% Syntax:
%   result = exploreFNIRS.coupling.coherence(x, y, fs)
%   result = exploreFNIRS.coupling.coherence(x, y, fs, 'FreqRange', [0.01 0.1])
%
% Inputs:
%   x  - [T x 1] time series
%   y  - [T x 1] time series
%   fs - Sampling frequency (Hz)
%
% Name-Value Parameters:
%   FreqRange   - [fLow fHigh] frequency band in Hz (default: [0.01, fs/2])
%                 Typical fNIRS: [0.01, 0.1] for hemodynamic, [0.1, 0.5] for Mayer waves
%   WindowLength - Welch segment length in seconds (default: auto, ~8 segments)
%   Overlap      - Fraction of overlap between segments (default: 0.5)
%   NFFT         - FFT length (default: next power of 2 of window length)
%
% Outputs:
%   result - Struct with fields:
%     .value    - Mean coherence in FreqRange (scalar)
%     .pvalue   - Approximate p-value (threshold-based)
%     .spectrum - [F x 1] full coherence spectrum
%     .freqs    - [F x 1] frequency vector (Hz)
%     .method   - 'coherence'
%     .windowed - false (spectral method, not time-windowed)
%     .freqRange - Frequency band used
%
% Notes:
%   Significance threshold approximation: C_thresh = 1 - alpha^(1/(L-1))
%   where L = number of segments. Values above this are significant at alpha.
%
% References:
%   Welch, P. D. (1967). The use of fast Fourier transform for the
%   estimation of power spectra: a method based on time averaging over
%   short, modified periodograms. IEEE Transactions on Audio and
%   Electroacoustics, 15(2), 70-73. DOI: 10.1109/TAU.1967.1161901
%
%   Carter, G. C., Knapp, C. H. & Nuttall, A. H. (1973). Estimation of
%   the magnitude-squared coherence function via overlapped fast Fourier
%   transform processing. IEEE Transactions on Audio and Electroacoustics,
%   21(4), 337-344.
%
% See also: exploreFNIRS.coupling.pearson, exploreFNIRS.coupling.xcorr, mscohere

    p = inputParser;
    addRequired(p, 'x', @(v) isnumeric(v) && isvector(v));
    addRequired(p, 'y', @(v) isnumeric(v) && isvector(v));
    addRequired(p, 'fs', @(v) isnumeric(v) && isscalar(v) && v > 0);
    addParameter(p, 'FreqRange', [0.01, 0], @(v) isnumeric(v) && length(v) == 2);
    addParameter(p, 'WindowLength', 0, @(v) isnumeric(v) && isscalar(v) && v >= 0);
    addParameter(p, 'Overlap', 0.5, @(v) isnumeric(v) && isscalar(v) && v >= 0 && v < 1);
    addParameter(p, 'NFFT', 0, @(v) isnumeric(v) && isscalar(v) && v >= 0);
    parse(p, x, y, fs, varargin{:});
    opts = p.Results;

    x = x(:);
    y = y(:);
    if length(x) ~= length(y)
        error('exploreFNIRS:coupling:coherence', 'x and y must have equal length');
    end

    % Fill NaNs for spectral analysis
    x = fillNaN(x);
    y = fillNaN(y);

    T = length(x);

    % Set frequency range
    freqRange = opts.FreqRange;
    if freqRange(2) <= 0
        freqRange(2) = fs / 2;
    end

    % Auto window length: aim for ~8 segments
    if opts.WindowLength <= 0
        winLen = round(T / 8);
        winLen = max(winLen, round(fs * 4));  % at least 4 seconds
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

    % Compute coherence
    [cxy, f] = mscohere(x, y, hanning(winLen), overlapSamp, nfft, fs);

    % Filter to frequency range
    freqMask = f >= freqRange(1) & f <= freqRange(2);
    meanCoherence = mean(cxy(freqMask), 'omitnan');

    % Approximate significance threshold
    % Number of segments (Welch method)
    nSegments = floor((T - overlapSamp) / (winLen - overlapSamp));
    nSegments = max(nSegments, 2);
    alpha = 0.05;
    coherenceThreshold = 1 - alpha^(1 / (nSegments - 1));

    % P-value from coherence null distribution: P(C >= c) = (1 - c)^(L - 1)
    % Note: this formula is exact for single-frequency-bin coherence.
    % For band-averaged coherence it is an approximation (anti-conservative).
    pval = (1 - min(meanCoherence, 1 - eps))^(nSegments - 1);

    result.value = meanCoherence;
    result.pvalue = pval;
    result.spectrum = cxy;
    result.freqs = f;
    result.method = 'coherence';
    result.windowed = false;
    result.freqRange = freqRange;
    result.coherenceThreshold = coherenceThreshold;
    result.nSegments = nSegments;
end


function v = fillNaN(v)
% Linear interpolation of NaN values
    nanIdx = isnan(v);
    if ~any(nanIdx), return; end
    if all(nanIdx), v(:) = 0; return; end
    t = (1:length(v))';
    v(nanIdx) = interp1(t(~nanIdx), v(~nanIdx), t(nanIdx), 'linear', 'extrap');
end
