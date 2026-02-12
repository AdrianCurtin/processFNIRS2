function result = transferEntropy(x, y, fs, varargin)
% TRANSFERENTROPY Transfer entropy from x to y
%
% Estimates the information transferred from time series x to time series y
% using histogram-based probability estimation. Statistical significance is
% determined via block-shuffle surrogates.
%
% Syntax:
%   result = exploreFNIRS.coupling.transferEntropy(x, y, fs)
%   result = exploreFNIRS.coupling.transferEntropy(x, y, fs, 'NBins', 8)
%   result = exploreFNIRS.coupling.transferEntropy(x, y, fs, 'WindowSize', 30)
%
% Inputs:
%   x  - [T x 1] time series (source)
%   y  - [T x 1] time series (target)
%   fs - Sampling frequency (Hz)
%
% Name-Value Parameters:
%   EmbeddingDim  - Embedding dimension (default: 3)
%   Delay         - Embedding delay in samples (default: 1)
%   NBins         - Number of histogram bins per dimension (default: 10)
%   NumSurrogates - Number of block-shuffle surrogates for p-value (default: 100)
%   WindowSize    - Sliding window duration in seconds (default: 0, full signal)
%   WindowStep    - Step size in seconds (default: WindowSize/2, 50% overlap)
%
% Outputs:
%   result - Struct with fields:
%     .value       - Transfer entropy in nats (scalar, or [W x 1] for windowed)
%     .pvalue      - Surrogate-based p-value
%     .direction   - 'x->y'
%     .method      - 'transferEntropy'
%     .windowed    - true if sliding window was used
%     .windowTimes - [W x 1] center times (windowed only)
%
% Algorithm:
%   TE(x->y) = H(y_future | y_past) - H(y_future | y_past, x_past)
%   Computed via histogram-based joint/conditional entropy estimation.
%   p-value from block-shuffle surrogates of x.
%
% References:
%   Schreiber, T. (2000). Measuring information transfer. Physical Review
%   Letters, 85(2), 461-464. DOI: 10.1103/PhysRevLett.85.461
%
%   Theiler, J., Eubank, S., Longtin, A., Galdrikian, B. & Farmer, J. D.
%   (1992). Testing for nonlinearity in time series: the method of surrogate
%   data. Physica D, 58(1-4), 77-94. DOI: 10.1016/0167-2789(92)90102-S
%
% See also: exploreFNIRS.coupling.granger, exploreFNIRS.coupling.pearson

    p = inputParser;
    addRequired(p, 'x', @(v) isnumeric(v) && isvector(v));
    addRequired(p, 'y', @(v) isnumeric(v) && isvector(v));
    addRequired(p, 'fs', @(v) isnumeric(v) && isscalar(v) && v > 0);
    addParameter(p, 'EmbeddingDim', 3, @(v) isnumeric(v) && isscalar(v) && v >= 1);
    addParameter(p, 'Delay', 1, @(v) isnumeric(v) && isscalar(v) && v >= 1);
    addParameter(p, 'NBins', 10, @(v) isnumeric(v) && isscalar(v) && v >= 2);
    addParameter(p, 'NumSurrogates', 100, @(v) isnumeric(v) && isscalar(v) && v >= 0);
    addParameter(p, 'WindowSize', 0, @(v) isnumeric(v) && isscalar(v) && v >= 0);
    addParameter(p, 'WindowStep', 0, @(v) isnumeric(v) && isscalar(v) && v >= 0);
    parse(p, x, y, fs, varargin{:});
    opts = p.Results;

    % Memory safety check for histogram binning
    totalBins = opts.NBins ^ (opts.EmbeddingDim + 1);
    if totalBins > 1e7
        error('exploreFNIRS:coupling:transferEntropy', ...
            'NBins=%d with EmbeddingDim=%d creates %.0e histogram bins. Reduce NBins or EmbeddingDim.', ...
            opts.NBins, opts.EmbeddingDim, totalBins);
    end

    x = x(:);
    y = y(:);
    if length(x) ~= length(y)
        error('exploreFNIRS:coupling:transferEntropy', 'x and y must have equal length');
    end

    winSamples = round(opts.WindowSize * fs);

    if winSamples <= 0 || winSamples >= length(x)
        % Full-signal mode
        [teVal, pval] = computeTE(x, y, opts);

        result.value = teVal;
        result.pvalue = pval;
        result.direction = 'x->y';
        result.method = 'transferEntropy';
        result.windowed = false;
    else
        % Sliding window mode
        stepSamples = round(opts.WindowStep * fs);
        if stepSamples <= 0
            stepSamples = max(1, round(winSamples / 2));
        end

        T = length(x);
        starts = 1:stepSamples:(T - winSamples + 1);
        nWin = length(starts);

        teVals = nan(nWin, 1);
        pVals = nan(nWin, 1);
        winTimes = nan(nWin, 1);

        for w = 1:nWin
            idx = starts(w):(starts(w) + winSamples - 1);
            xw = x(idx);
            yw = y(idx);
            [teVals(w), pVals(w)] = computeTE(xw, yw, opts);
            winTimes(w) = (starts(w) + winSamples/2 - 1) / fs;
        end

        result.value = teVals;
        result.pvalue = pVals;
        result.direction = 'x->y';
        result.method = 'transferEntropy';
        result.windowed = true;
        result.windowTimes = winTimes;
    end
end


function [teVal, pval] = computeTE(x, y, opts)
% Compute transfer entropy TE(x->y) with surrogate p-value

    dim = opts.EmbeddingDim;
    delay = opts.Delay;
    nBins = opts.NBins;
    nSurr = opts.NumSurrogates;

    % Handle NaN: use longest contiguous valid segment (preserves temporal order)
    valid = ~isnan(x) & ~isnan(y);
    [segStart, segLen] = longestRun(valid);
    if segLen == 0
        teVal = NaN;
        pval = NaN;
        return;
    end
    x = x(segStart:segStart + segLen - 1);
    y = y(segStart:segStart + segLen - 1);

    T = length(x);
    minLen = (dim + 1) * delay + 1;

    if T < minLen
        teVal = NaN;
        pval = NaN;
        return;
    end

    % Compute observed TE
    teVal = estimateTE(x, y, dim, delay, nBins);

    % Surrogate p-value via block-shuffle of x
    if nSurr > 0
        surrTE = zeros(nSurr, 1);
        blockLen = max(round(T / 10), dim * delay + 1);
        for s = 1:nSurr
            xShuff = blockShuffle(x, blockLen);
            surrTE(s) = estimateTE(xShuff, y, dim, delay, nBins);
        end
        pval = (sum(surrTE >= teVal) + 1) / (nSurr + 1);
    else
        pval = NaN;
    end
end


function te = estimateTE(x, y, dim, delay, nBins)
% Histogram-based transfer entropy estimation
%
% TE(x->y) = H(y_future, y_past) + H(y_past, x_past) - H(y_past) - H(y_future, y_past, x_past)

    T = length(x);
    maxLag = dim * delay;
    nObs = T - maxLag;

    if nObs < 10
        te = NaN;
        return;
    end

    % Build state vectors
    yFuture = y((maxLag + 1):T);

    % y_past: embedding of y
    yPast = zeros(nObs, dim);
    for d = 1:dim
        lag = d * delay;
        yPast(:, d) = y((maxLag + 1 - lag):(T - lag));
    end

    % x_past: embedding of x
    xPast = zeros(nObs, dim);
    for d = 1:dim
        lag = d * delay;
        xPast(:, d) = x((maxLag + 1 - lag):(T - lag));
    end

    % Bin all variables to integers 1..nBins
    yFutureBin = binData(yFuture, nBins);
    yPastBin = combineBins(yPast, nBins);
    xPastBin = combineBins(xPast, nBins);

    % Compute entropies
    % TE = H(yFuture, yPast) + H(yPast, xPast) - H(yPast) - H(yFuture, yPast, xPast)
    H_yf_yp = jointEntropy(yFutureBin, yPastBin);
    H_yp_xp = jointEntropy(yPastBin, xPastBin);
    H_yp = entropy1d(yPastBin);
    H_yf_yp_xp = jointEntropy3(yFutureBin, yPastBin, xPastBin);

    te = H_yf_yp + H_yp_xp - H_yp - H_yf_yp_xp;
    te = max(te, 0);  % TE should be non-negative
end


function binned = binData(v, nBins)
% Bin a 1D vector into integer bins 1..nBins
    vMin = min(v);
    vMax = max(v);
    if vMax == vMin
        binned = ones(size(v));
    else
        binned = floor((v - vMin) / (vMax - vMin) * (nBins - 1)) + 1;
        binned = min(binned, nBins);
    end
end


function combined = combineBins(M, nBins)
% Combine multi-column binned data into single integer index
    [nObs, nDim] = size(M);
    combined = zeros(nObs, 1);
    for d = 1:nDim
        col = binData(M(:, d), nBins);
        combined = combined * nBins + (col - 1);
    end
    combined = combined + 1;
end


function H = entropy1d(v)
% Shannon entropy of discrete vector (in nats)
    counts = accumarray(v(:), 1);
    counts = counts(counts > 0);
    p = counts / sum(counts);
    H = -sum(p .* log(p));
end


function H = jointEntropy(a, b)
% Joint entropy of two discrete vectors
    combined = (a(:) - 1) * max(b) + b(:);
    H = entropy1d(combined);
end


function H = jointEntropy3(a, b, c)
% Joint entropy of three discrete vectors
    combined = ((a(:) - 1) * max(b) + (b(:) - 1)) * max(c) + c(:);
    H = entropy1d(combined);
end


function xShuff = blockShuffle(x, blockLen)
% Block-shuffle a time series preserving local autocorrelation
    T = length(x);
    nBlocks = ceil(T / blockLen);
    blockStarts = 1:blockLen:T;
    perm = randperm(length(blockStarts));
    xShuff = zeros(T, 1);
    pos = 1;
    for i = 1:length(perm)
        bStart = blockStarts(perm(i));
        bEnd = min(bStart + blockLen - 1, T);
        bLen = bEnd - bStart + 1;
        endPos = min(pos + bLen - 1, T);
        actualLen = endPos - pos + 1;
        xShuff(pos:endPos) = x(bStart:(bStart + actualLen - 1));
        pos = endPos + 1;
        if pos > T
            break;
        end
    end
end


function [start, len] = longestRun(mask)
% Find the start index and length of the longest contiguous run of true values
    d = diff([0; mask(:); 0]);
    starts = find(d == 1);
    ends = find(d == -1) - 1;
    if isempty(starts)
        start = 1;
        len = 0;
        return;
    end
    lengths = ends - starts + 1;
    [len, idx] = max(lengths);
    start = starts(idx);
end
