function result = partialCoherence(x, y, z, fs, varargin)
% PARTIALCOHERENCE Partial magnitude-squared coherence controlling for signal(s)
%
% Computes the coherence between x and y after removing the linear influence of
% one or more conditioning signals z. In hyperscanning this controls for shared
% physiology (respiration, ~0.1 Hz Mayer waves, heart rate) that can inflate
% apparent inter-brain coherence in the LFO/VLFO band. Both the ordinary and
% partial coherence are returned so the confound's contribution is visible.
%
% Syntax:
%   result = exploreFNIRS.coupling.partialCoherence(x, y, z, fs)
%   result = exploreFNIRS.coupling.partialCoherence(x, y, z, fs, 'FreqRange', [0.04 0.15])
%
% Inputs:
%   x  - [T x 1] time series (e.g. brain A channel)
%   y  - [T x 1] time series (e.g. brain B channel)
%   z  - [T x K] conditioning signal(s) to partial out (shared physiology)
%   fs - Sampling frequency (Hz)
%
% Name-Value Parameters:
%   FreqRange    - [fLow fHigh] band in Hz (default: [0.01, fs/2])
%   WindowLength - Welch segment length in seconds (default: auto, ~8 segments)
%   Overlap      - Fraction of overlap between segments (default: 0.5)
%   NFFT         - FFT length (default: next power of 2 of window length)
%
% Outputs:
%   result - Struct with fields:
%     .value            - Mean PARTIAL coherence in FreqRange (scalar)
%     .ordinary         - Mean ORDINARY coherence in FreqRange (scalar)
%     .reduction        - ordinary - value (drop attributable to z)
%     .spectrum         - [F x 1] partial coherence spectrum
%     .ordinarySpectrum - [F x 1] ordinary coherence spectrum
%     .freqs            - [F x 1] frequency vector (Hz)
%     .freqRange        - Frequency band used
%     .method           - 'partialCoherence'
%
% Algorithm:
%   Assembles the cross-spectral density matrix S(f) over [x, y, z...] via
%   Welch cross-spectra (cpsd). The partial coherence between x and y given the
%   remaining variables is |P_12|^2 / (P_11 P_22) where P = inv(S(f)); the
%   ordinary coherence is |S_12|^2 / (S_11 S_22).
%
% References:
%   Bendat, J. S. & Piersol, A. G. (2010). Random Data: Analysis and
%   Measurement Procedures (4th ed.). Wiley. (partial coherence)
%
% See also: exploreFNIRS.coupling.coherence, exploreFNIRS.coupling.wcoherence,
%           exploreFNIRS.hyperscanning.physioConfoundQC, cpsd

    p = inputParser;
    addRequired(p, 'x', @(v) isnumeric(v) && isvector(v));
    addRequired(p, 'y', @(v) isnumeric(v) && isvector(v));
    addRequired(p, 'z', @(v) isnumeric(v) && ~isempty(v));
    addRequired(p, 'fs', @(v) isnumeric(v) && isscalar(v) && v > 0);
    addParameter(p, 'FreqRange', [0.01, 0], @(v) isnumeric(v) && length(v) == 2);
    addParameter(p, 'WindowLength', 0, @(v) isnumeric(v) && isscalar(v) && v >= 0);
    addParameter(p, 'Overlap', 0.5, @(v) isnumeric(v) && isscalar(v) && v >= 0 && v < 1);
    addParameter(p, 'NFFT', 0, @(v) isnumeric(v) && isscalar(v) && v >= 0);
    parse(p, x, y, z, fs, varargin{:});
    opts = p.Results;

    if ~exist('cpsd', 'file')
        error('exploreFNIRS:coupling:partialCoherence:noToolbox', ...
            'partialCoherence requires the Signal Processing Toolbox (cpsd).');
    end

    x = fillNaN(x(:));
    y = fillNaN(y(:));
    if isrow(z), z = z(:); end
    for k = 1:size(z, 2)
        z(:, k) = fillNaN(z(:, k));
    end
    T = length(x);
    if length(y) ~= T || size(z, 1) ~= T
        error('exploreFNIRS:coupling:partialCoherence', ...
            'x, y, and z must share the same number of samples.');
    end

    freqRange = opts.FreqRange;
    if freqRange(2) <= 0
        freqRange(2) = fs / 2;
    end

    if opts.WindowLength <= 0
        winLen = round(T / 8);
        winLen = max(winLen, round(fs * 4));
        % The window must be long enough to resolve the low edge of the band:
        % aim for >= 3 cycles of freqRange(1) (e.g. ~60 s at 0.05 Hz). Without
        % this, an LFO/VLFO band [0.04 0.15] cannot be estimated.
        if freqRange(1) > 0
            winLen = max(winLen, round(3 / freqRange(1) * fs));
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

    % Channel matrix: [x, y, z1..zK]
    chans = [x, y, z];
    m = size(chans, 2);
    win = hanning(winLen);

    % Pairwise cross-spectra
    S = cell(m, m);
    f = [];
    for i = 1:m
        for j = i:m
            [Sij, f] = cpsd(chans(:, i), chans(:, j), win, overlapSamp, nfft, fs);
            S{i, j} = Sij;
            if i ~= j
                S{j, i} = conj(Sij);
            end
        end
    end

    F = numel(f);
    partialSpec = nan(F, 1);
    ordinarySpec = nan(F, 1);
    for fi = 1:F
        M = zeros(m, m);
        for i = 1:m
            for j = 1:m
                M(i, j) = S{i, j}(fi);
            end
        end
        % Ordinary coherence x-y
        ordinarySpec(fi) = clamp01(abs(M(1, 2))^2 / (real(M(1, 1)) * real(M(2, 2)) + eps));
        % Partial coherence x-y | rest, via the precision matrix. Use a
        % diagonal-scaled Tikhonov ridge (not eps-scale) so near-singular
        % cross-spectral matrices at low-SNR frequencies invert stably.
        reg = 1e-6 * max(real(diag(M)));
        P = pinv(M + reg * eye(m));
        partialSpec(fi) = clamp01(abs(P(1, 2))^2 / (real(P(1, 1)) * real(P(2, 2)) + eps));
    end

    freqMask = f >= freqRange(1) & f <= freqRange(2);
    result.value = mean(partialSpec(freqMask), 'omitnan');
    result.ordinary = mean(ordinarySpec(freqMask), 'omitnan');
    result.reduction = result.ordinary - result.value;
    result.spectrum = partialSpec;
    result.ordinarySpectrum = ordinarySpec;
    result.freqs = f;
    result.freqRange = freqRange;
    result.method = 'partialCoherence';
end


function v = fillNaN(v)
% Linear interpolation of NaN values
    nanIdx = isnan(v);
    if ~any(nanIdx), return; end
    if all(nanIdx), v(:) = 0; return; end
    t = (1:length(v))';
    v(nanIdx) = interp1(t(~nanIdx), v(~nanIdx), t(nanIdx), 'linear', 'extrap');
end


function c = clamp01(c)
    c = max(0, min(1, c));
end
