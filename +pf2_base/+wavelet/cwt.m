function result = cwt(X, fs, varargin)
% CWT Batch continuous wavelet transform using Morlet wavelet
%
% Computes the CWT for one or more signals simultaneously using an
% FFT-based Morlet wavelet. Multi-channel signals share the frequency
% axis computation, so batch processing is significantly faster than
% per-signal calls. GPU-aware: if input is a gpuArray, all FFTs and
% arithmetic run on the GPU.
%
% Based on the FFT convolution approach from WaveLab850 (Clerc & Kalifa,
% 1997) with additions for proper frequency axis, cone of influence, and
% multi-channel batch support.
%
% Syntax:
%   result = pf2_base.wavelet.cwt(X, fs)
%   result = pf2_base.wavelet.cwt(X, fs, 'VoicesPerOctave', 12)
%   result = pf2_base.wavelet.cwt(X, fs, 'FreqRange', [0.01 0.5])
%   result = pf2_base.wavelet.cwt(X, fs, 'Precision', 'single')
%
% Inputs:
%   X  - [T x C] signal matrix (T time samples, C channels)
%        Also accepts [T x 1] column vector for single-channel.
%   fs - Sampling frequency in Hz (positive scalar)
%
% Name-Value Parameters:
%   VoicesPerOctave - Frequency resolution (default: 10, range 1-48)
%   FreqRange       - [fLow fHigh] restrict output frequencies (default: auto)
%   Omega0          - Morlet center frequency parameter (default: 6)
%                     Higher values give better frequency resolution,
%                     lower values give better time resolution.
%   Precision       - 'single' (default) or 'double'. Single-precision
%                     FFTs are ~2x faster on CPU, much faster on GPU.
%
% Outputs:
%   result - Struct with fields:
%     .coeffs  - [F x T x C] complex CWT coefficients
%     .freqs   - [F x 1] frequency vector in Hz (descending: high to low)
%     .scales  - [F x 1] wavelet scales used
%     .coi     - [T x 1] cone of influence boundary in Hz
%     .fs      - sampling frequency
%     .omega0  - Morlet parameter used
%
% Notes:
%   No Wavelet Toolbox required. Uses only fft/ifft from base MATLAB.
%
% References:
%   Torrence, C. & Compo, G.P. (1998). A practical guide to wavelet
%   analysis. Bulletin of the American Meteorological Society, 79(1),
%   61-78. DOI: 10.1175/1520-0477(1998)079<0061:APGTWA>2.0.CO;2
%
%   Grinsted, A., Moore, J.C. & Jevrejeva, S. (2004). Application of the
%   cross wavelet transform and wavelet coherence to geophysical time
%   series. Nonlinear Processes in Geophysics, 11, 561-566.
%
% See also: pf2_base.wavelet.wcoherence, CWT_Wavelab

    % --- Fast argument parsing (no inputParser overhead) ---
    nv = 10;          % VoicesPerOctave
    freqRange = [];   % FreqRange
    omega0 = 6;       % Omega0
    precision = 'single';  % Precision

    for k = 1:2:length(varargin)
        key = varargin{k};
        val = varargin{k+1};
        switch lower(key)
            case 'voicesperoctave'
                nv = val;
            case 'freqrange'
                freqRange = val;
            case 'omega0'
                omega0 = val;
            case 'precision'
                precision = val;
        end
    end

    % Ensure column-oriented matrix
    if isvector(X)
        X = X(:);
    end
    [T, nCh] = size(X);

    % Cast to requested precision
    if strcmp(precision, 'single')
        X = single(X);
    end

    dt = 1 / fs;

    % --- Build scale array ---
    s0 = 2 * dt;
    maxScale = T * dt / sqrt(2);
    nOctaves = max(floor(log2(maxScale / s0)), 1);
    nScales = nv * nOctaves;
    scales = s0 * 2 .^ ((0:nScales-1)' / nv);  % [nScales x 1] double

    % Corresponding frequencies
    freqsFull = (omega0 + sqrt(2 + omega0^2)) ./ (4 * pi * scales);

    % Remove scales below minimum resolvable frequency
    fMin = 1 / (T * dt);
    validMask = freqsFull >= fMin;
    scales = scales(validMask);
    freqsFull = freqsFull(validMask);
    nScales = length(scales);

    % Apply frequency range filter
    if ~isempty(freqRange)
        fLow = max(freqRange(1), fMin);
        fHigh = min(freqRange(2), fs / 2);
        keepMask = freqsFull >= fLow & freqsFull <= fHigh;
        scales = scales(keepMask);
        freqsFull = freqsFull(keepMask);
        nScales = length(scales);
    end

    if nScales == 0
        error('pf2_base:wavelet:cwt', 'No scales within the requested frequency range.');
    end

    % --- FFT of all channels at once (power-of-2 padded) ---
    nfft = 2^nextpow2(T);
    Xhat = fft(X, nfft, 1);  % [nfft x nCh]

    % Angular frequency vector [nfft x 1]
    omega = cast((2 * pi * fs / nfft) * [0:floor(nfft/2), -ceil(nfft/2)+1:-1]', 'like', X(1));

    % --- Build all wavelet kernels at once (vectorized) ---
    % scales: [nScales x 1] double, omega: [nfft x 1]
    % sOmega: [nfft x nScales] = omega * scales'
    scalesRow = cast(scales(:)', 'like', X(1));  % [1 x nScales]
    sOmega = omega * scalesRow;  % [nfft x nScales]

    normConst = cast(pi^(-1/4), 'like', X(1));
    normFactors = sqrt(2 * pi * scalesRow / dt) * normConst;  % [1 x nScales]

    % Heaviside mask: only positive frequencies [nfft x 1]
    posIdx = omega > 0;

    % Build all Morlet kernels: [nfft x nScales]
    psiHat = zeros(nfft, nScales, 'like', X(1));
    psiHat(posIdx, :) = normFactors .* exp(-0.5 * (sOmega(posIdx, :) - cast(omega0, 'like', X(1))).^2);

    % --- Batch convolution: all scales x all channels in one go ---
    % Xhat: [nfft x nCh], psiHat: [nfft x nScales]
    % We need coeffs(si, t, ch) = ifft(Xhat(:,ch) .* psiHat(:,si))
    %
    % Reshape for batch multiply:
    %   Xhat3 = [nfft x 1 x nCh], psiHat3 = [nfft x nScales x 1]
    %   product = [nfft x nScales x nCh] via implicit expansion
    Xhat3 = reshape(Xhat, nfft, 1, nCh);         % [nfft x 1 x nCh]
    product = Xhat3 .* psiHat;                     % [nfft x nScales x nCh] (implicit expansion)
    W = ifft(product, nfft, 1);                    % [nfft x nScales x nCh]

    % Crop to original length and permute to [nScales x T x nCh]
    coeffs = permute(W(1:T, :, :), [2 1 3]);      % [nScales x T x nCh]

    % --- Cone of influence ---
    tVec = (0:T-1)' * dt;
    distFromEdge = min(tVec, tVec(end) - tVec);
    coiScale = distFromEdge / sqrt(2);
    coiFreq = (omega0 + sqrt(2 + omega0^2)) ./ (4 * pi * max(coiScale, eps));
    coiFreq = min(coiFreq, fs/2);

    % --- Output ---
    result.coeffs = coeffs;
    result.freqs = freqsFull;
    result.scales = scales;
    result.coi = coiFreq;
    result.fs = fs;
    result.omega0 = omega0;
end
