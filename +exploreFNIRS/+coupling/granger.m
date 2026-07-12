function result = granger(x, y, fs, varargin)
% GRANGER Bivariate Granger causality between two time series
%
% Tests whether past values of x improve the prediction of y beyond
% what past values of y alone provide. Uses autoregressive modeling
% with an F-test on residual variance reduction.
%
% Syntax:
%   result = exploreFNIRS.coupling.granger(x, y, fs)
%   result = exploreFNIRS.coupling.granger(x, y, fs, 'ModelOrder', 10)
%   result = exploreFNIRS.coupling.granger(x, y, fs, 'WindowSize', 30)
%
% Inputs:
%   x  - [T x 1] time series (candidate cause)
%   y  - [T x 1] time series (candidate effect)
%   fs - Sampling frequency (Hz)
%
% Name-Value Parameters:
%   ModelOrder - Number of lags for AR model (default: 5)
%   WindowSize - Sliding window duration in seconds (default: 0, full signal)
%   WindowStep - Step size in seconds (default: WindowSize/2, 50% overlap)
%
% Outputs:
%   result - Struct with fields:
%     .value       - F-statistic (scalar, or [W x 1] for windowed)
%     .pvalue      - p-value from F-distribution
%     .direction   - 'x->y'
%     .method      - 'granger'
%     .windowed    - true if sliding window was used
%     .windowTimes - [W x 1] center times (windowed only)
%
% Algorithm:
%   Restricted model:  y(t) = sum_k a_k * y(t-k) + e_r
%   Unrestricted model: y(t) = sum_k a_k * y(t-k) + sum_k b_k * x(t-k) + e_u
%   F = ((RSS_r - RSS_u) / p) / (RSS_u / (T - 2p - 1))
%
% References:
%   Granger, C. W. J. (1969). Investigating causal relations by econometric
%   models and cross-spectral methods. Econometrica, 37(3), 424-438.
%
%   Geweke, J. (1982). Measurement of linear dependence and feedback between
%   multiple time series. Journal of the American Statistical Association,
%   77(378), 304-313.
%
% See also: exploreFNIRS.coupling.transferEntropy, exploreFNIRS.coupling.pearson

    p = inputParser;
    addRequired(p, 'x', @(v) isnumeric(v) && isvector(v));
    addRequired(p, 'y', @(v) isnumeric(v) && isvector(v));
    addRequired(p, 'fs', @(v) isnumeric(v) && isscalar(v) && v > 0);
    addParameter(p, 'ModelOrder', 5, @(v) isnumeric(v) && isscalar(v) && v >= 1);
    addParameter(p, 'WindowSize', 0, @(v) isnumeric(v) && isscalar(v) && v >= 0);
    addParameter(p, 'WindowStep', 0, @(v) isnumeric(v) && isscalar(v) && v >= 0);
    parse(p, x, y, fs, varargin{:});
    opts = p.Results;

    x = x(:);
    y = y(:);
    if length(x) ~= length(y)
        error('exploreFNIRS:coupling:granger', 'x and y must have equal length');
    end

    winSamples = round(opts.WindowSize * fs);

    if winSamples <= 0 || winSamples >= length(x)
        % Full-signal mode
        [fStat, pval] = computeGranger(x, y, opts.ModelOrder);

        result.value = fStat;
        result.pvalue = pval;
        result.direction = 'x->y';
        result.method = 'granger';
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

        fVals = nan(nWin, 1);
        pVals = nan(nWin, 1);
        winTimes = nan(nWin, 1);

        for w = 1:nWin
            idx = starts(w):(starts(w) + winSamples - 1);
            xw = x(idx);
            yw = y(idx);
            [fVals(w), pVals(w)] = computeGranger(xw, yw, opts.ModelOrder);
            winTimes(w) = (starts(w) + winSamples/2 - 1) / fs;
        end

        result.value = fVals;
        result.pvalue = pVals;
        result.direction = 'x->y';
        result.method = 'granger';
        result.windowed = true;
        result.windowTimes = winTimes;
    end
end


function [fStat, pval] = computeGranger(x, y, order)
% Compute Granger F-statistic for x -> y

    T = length(y);
    if T <= 2 * order + 1
        fStat = NaN;
        pval = NaN;
        return;
    end

    % Handle NaN: use longest contiguous valid segment (preserves temporal order)
    valid = ~isnan(x) & ~isnan(y);
    [segStart, segLen] = longestRun(valid);
    if segLen == 0
        fStat = NaN;
        pval = NaN;
        return;
    end
    x = x(segStart:segStart + segLen - 1);
    y = y(segStart:segStart + segLen - 1);
    T = length(y);

    if T <= 2 * order + 1
        fStat = NaN;
        pval = NaN;
        return;
    end

    nObs = T - order;

    % Build lag matrices
    Y = y((order + 1):T);

    % Restricted model: y lags only
    Xr = zeros(nObs, order);
    for k = 1:order
        Xr(:, k) = y((order + 1 - k):(T - k));
    end

    % Unrestricted model: y lags + x lags
    Xu = zeros(nObs, 2 * order);
    Xu(:, 1:order) = Xr;
    for k = 1:order
        Xu(:, order + k) = x((order + 1 - k):(T - k));
    end

    % Solve via backslash
    betaR = Xr \ Y;
    betaU = Xu \ Y;

    residR = Y - Xr * betaR;
    residU = Y - Xu * betaU;

    rssR = sum(residR .^ 2);
    rssU = sum(residU .^ 2);

    % F-statistic
    dfNum = order;
    dfDen = nObs - 2 * order - 1;

    if dfDen <= 0 || rssU <= 0
        fStat = NaN;
        pval = NaN;
        return;
    end

    fStat = ((rssR - rssU) / dfNum) / (rssU / dfDen);
    fStat = max(fStat, 0);

    % p-value from F-distribution
    pval = 1 - fcdf(fStat, dfNum, dfDen);
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
