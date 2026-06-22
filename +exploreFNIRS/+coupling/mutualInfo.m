function result = mutualInfo(x, y, fs, varargin)
% MUTUALINFO Mutual information between two time series
%
% Estimates mutual information (MI) between two equal-length time series
% using histogram-based probability estimation. MI captures both linear and
% nonlinear statistical dependencies. Statistical significance is assessed
% via block-shuffle surrogates.
%
% Syntax:
%   result = exploreFNIRS.coupling.mutualInfo(x, y, fs)
%   result = exploreFNIRS.coupling.mutualInfo(x, y, fs, 'NBins', 'auto')
%   result = exploreFNIRS.coupling.mutualInfo(x, y, fs, 'WindowSize', 30)
%
% Inputs:
%   x  - [T x 1] time series
%   y  - [T x 1] time series
%   fs - Sampling frequency (Hz)
%
% Name-Value Parameters:
%   NBins         - Number of histogram bins per dimension, or 'auto'
%                   (default: 'auto', uses Freedman-Diaconis rule)
%   NumSurrogates - Number of block-shuffle surrogates for p-value
%                   (default: 100; set 0 to skip)
%   Normalize     - Normalize MI to [0, 1] range (default: true)
%                   Uses NMI = MI / sqrt(H(x) * H(y))
%   WindowSize    - Sliding window duration in seconds (default: 0, full)
%   WindowStep    - Step size in seconds (default: WindowSize/2, 50% overlap)
%
% Outputs:
%   result - Struct with fields:
%     .value       - Mutual information (scalar, or [W x 1] for windowed)
%                    In nats if Normalize=false, [0,1] if Normalize=true
%     .pvalue      - Surrogate-based p-value(s)
%     .method      - 'mutualInfo'
%     .windowed    - true if sliding window was used
%     .windowTimes - [W x 1] center times (windowed only)
%     .normalized  - true if NMI was computed
%     .nBinsUsed   - Actual number of bins used
%
% Algorithm:
%   1. Bin x and y into NBins equal-width histogram bins
%   2. Estimate joint probability p(x,y) and marginals p(x), p(y)
%   3. MI = sum(p(x,y) * log(p(x,y) / (p(x)*p(y))))
%   4. Optionally normalize: NMI = MI / sqrt(H(x) * H(y))
%   5. p-value from block-shuffle surrogates of x
%
% References:
%   Cover, T. M. & Thomas, J. A. (2006). Elements of Information Theory
%   (2nd ed.). Wiley-Interscience. ISBN: 978-0471241959
%
%   Freedman, D. & Diaconis, P. (1981). On the histogram as a density
%   estimator: L2 theory. Zeitschrift fur Wahrscheinlichkeitstheorie und
%   verwandte Gebiete, 57(4), 453-476. DOI: 10.1007/BF01025868
%
% See also: exploreFNIRS.coupling.pearson, exploreFNIRS.coupling.transferEntropy

    p = inputParser;
    addRequired(p, 'x', @(v) isnumeric(v) && isvector(v));
    addRequired(p, 'y', @(v) isnumeric(v) && isvector(v));
    addRequired(p, 'fs', @(v) isnumeric(v) && isscalar(v) && v > 0);
    addParameter(p, 'NBins', 'auto', @(v) (isnumeric(v) && isscalar(v) && v >= 2) || ...
        (ischar(v) && strcmpi(v, 'auto')) || (isstring(v) && strcmpi(v, 'auto')));
    addParameter(p, 'NumSurrogates', 100, @(v) isnumeric(v) && isscalar(v) && v >= 0);
    addParameter(p, 'Normalize', true, @(v) islogical(v) || (isnumeric(v) && isscalar(v)));
    addParameter(p, 'WindowSize', 0, @(v) isnumeric(v) && isscalar(v) && v >= 0);
    addParameter(p, 'WindowStep', 0, @(v) isnumeric(v) && isscalar(v) && v >= 0);
    parse(p, x, y, fs, varargin{:});
    opts = p.Results;

    x = x(:);
    y = y(:);
    if length(x) ~= length(y)
        error('exploreFNIRS:coupling:mutualInfo', 'x and y must have equal length');
    end

    winSamples = round(opts.WindowSize * fs);

    if winSamples <= 0 || winSamples >= length(x)
        % Full-signal mode
        [miVal, pval, nBinsUsed] = computeMI(x, y, opts);

        result.value = miVal;
        result.pvalue = pval;
        result.method = 'mutualInfo';
        result.windowed = false;
        result.normalized = logical(opts.Normalize);
        result.nBinsUsed = nBinsUsed;
    else
        % Sliding window mode
        stepSamples = round(opts.WindowStep * fs);
        if stepSamples <= 0
            stepSamples = max(1, round(winSamples / 2));
        end

        T = length(x);
        starts = 1:stepSamples:(T - winSamples + 1);
        nWin = length(starts);

        miVals = nan(nWin, 1);
        pVals = nan(nWin, 1);
        winTimes = nan(nWin, 1);
        nBinsUsed = 0;

        for w = 1:nWin
            idx = starts(w):(starts(w) + winSamples - 1);
            xw = x(idx);
            yw = y(idx);
            [miVals(w), pVals(w), nb] = computeMI(xw, yw, opts);
            if w == 1, nBinsUsed = nb; end
            winTimes(w) = (starts(w) + winSamples/2 - 1) / fs;
        end

        result.value = miVals;
        result.pvalue = pVals;
        result.method = 'mutualInfo';
        result.windowed = true;
        result.windowTimes = winTimes;
        result.normalized = logical(opts.Normalize);
        result.nBinsUsed = nBinsUsed;
    end
end


function [miVal, pval, nBins] = computeMI(x, y, opts)
% Compute mutual information with surrogate p-value

    % Handle NaN: use longest contiguous valid segment
    valid = ~isnan(x) & ~isnan(y);
    [segStart, segLen] = longestRun(valid);
    if segLen < 10
        miVal = NaN;
        pval = NaN;
        nBins = 0;
        return;
    end
    x = x(segStart:segStart + segLen - 1);
    y = y(segStart:segStart + segLen - 1);

    T = length(x);

    % Determine number of bins
    if ischar(opts.NBins) || isstring(opts.NBins)
        % Freedman-Diaconis rule: bin width = 2 * IQR * n^(-1/3)
        iqrX = pf2_base.compat.iqr(x);
        iqrY = pf2_base.compat.iqr(y);
        avgIQR = (iqrX + iqrY) / 2;
        if avgIQR > 0
            binWidth = 2 * avgIQR * T^(-1/3);
            rangeXY = max(max(x) - min(x), max(y) - min(y));
            nBins = max(3, min(round(rangeXY / binWidth), 100));
        else
            nBins = round(sqrt(T));
        end
    else
        nBins = opts.NBins;
    end

    % Compute observed MI
    miVal = estimateMI(x, y, nBins, logical(opts.Normalize));

    % Surrogate p-value via block-shuffle of x
    nSurr = opts.NumSurrogates;
    if nSurr > 0
        surrMI = zeros(nSurr, 1);
        blockLen = max(round(T / 10), 5);
        for s = 1:nSurr
            xShuff = blockShuffle(x, blockLen);
            surrMI(s) = estimateMI(xShuff, y, nBins, logical(opts.Normalize));
        end
        pval = (sum(surrMI >= miVal) + 1) / (nSurr + 1);
    else
        pval = NaN;
    end
end


function mi = estimateMI(x, y, nBins, doNormalize)
% Histogram-based mutual information estimation
%
% MI(X;Y) = H(X) + H(Y) - H(X,Y)

    T = length(x);

    % Bin each variable to integers 1..nBins
    xBin = binData(x, nBins);
    yBin = binData(y, nBins);

    % Marginal entropies
    Hx = entropy1d(xBin, nBins);
    Hy = entropy1d(yBin, nBins);

    % Joint entropy via 2D histogram
    jointIdx = (xBin - 1) * nBins + yBin;
    Hxy = entropy1d(jointIdx, nBins * nBins);

    % MI = H(X) + H(Y) - H(X,Y)
    mi = Hx + Hy - Hxy;
    mi = max(mi, 0);  % MI is non-negative by definition

    % Normalize to [0, 1]
    if doNormalize && Hx > 0 && Hy > 0
        mi = mi / sqrt(Hx * Hy);
        mi = min(mi, 1);
    end
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


function H = entropy1d(v, maxVal)
% Shannon entropy of discrete vector (in nats)
    counts = accumarray(v(:), 1, [maxVal, 1]);
    counts = counts(counts > 0);
    p = counts / sum(counts);
    H = -sum(p .* log(p));
end


function xShuff = blockShuffle(x, blockLen)
% Block-shuffle a time series preserving local autocorrelation
    T = length(x);
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
% Find the start index and length of the longest contiguous run of true
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
