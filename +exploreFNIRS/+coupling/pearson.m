function result = pearson(x, y, fs, varargin)
% PEARSON Pearson correlation between two time series
%
% Computes Pearson's r between two equal-length time series, with an
% optional sliding-window mode for time-resolved coupling.
%
% Syntax:
%   result = exploreFNIRS.coupling.pearson(x, y, fs)
%   result = exploreFNIRS.coupling.pearson(x, y, fs, 'WindowSize', 10)
%
% Inputs:
%   x  - [T x 1] time series
%   y  - [T x 1] time series
%   fs - Sampling frequency (Hz)
%
% Name-Value Parameters:
%   WindowSize - Sliding window duration in seconds (default: 0, full signal)
%   WindowStep - Step size in seconds (default: WindowSize/2, 50% overlap)
%
% Outputs:
%   result - Struct with fields:
%     .value    - Pearson r (scalar, or [W x 1] for windowed)
%     .pvalue   - Two-tailed p-value(s)
%     .method   - 'pearson'
%     .windowed - true if sliding window was used
%     .windowTimes - [W x 1] center times (windowed only)
%
% See also: exploreFNIRS.coupling.spearman, exploreFNIRS.coupling.xcorr

    p = inputParser;
    addRequired(p, 'x', @(v) isnumeric(v) && isvector(v));
    addRequired(p, 'y', @(v) isnumeric(v) && isvector(v));
    addRequired(p, 'fs', @(v) isnumeric(v) && isscalar(v) && v > 0);
    addParameter(p, 'WindowSize', 0, @(v) isnumeric(v) && isscalar(v) && v >= 0);
    addParameter(p, 'WindowStep', 0, @(v) isnumeric(v) && isscalar(v) && v >= 0);
    parse(p, x, y, fs, varargin{:});
    opts = p.Results;

    x = x(:);
    y = y(:);
    if length(x) ~= length(y)
        error('exploreFNIRS:coupling:pearson', 'x and y must have equal length');
    end

    winSamples = round(opts.WindowSize * fs);

    if winSamples <= 0 || winSamples >= length(x)
        % Full-signal mode
        valid = ~isnan(x) & ~isnan(y);
        if sum(valid) < 3
            result.value = NaN;
            result.pvalue = NaN;
            result.method = 'pearson';
            result.windowed = false;
            return;
        end
        [r, pval] = corr(x(valid), y(valid), 'Type', 'Pearson');

        result.value = r;
        result.pvalue = pval;
        result.method = 'pearson';
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

        rVals = nan(nWin, 1);
        pVals = nan(nWin, 1);
        winTimes = nan(nWin, 1);

        for w = 1:nWin
            idx = starts(w):(starts(w) + winSamples - 1);
            xw = x(idx);
            yw = y(idx);
            valid = ~isnan(xw) & ~isnan(yw);
            if sum(valid) >= 3
                [rVals(w), pVals(w)] = corr(xw(valid), yw(valid), 'Type', 'Pearson');
            end
            winTimes(w) = (starts(w) + winSamples/2 - 1) / fs;
        end

        result.value = rVals;
        result.pvalue = pVals;
        result.method = 'pearson';
        result.windowed = true;
        result.windowTimes = winTimes;
    end
end
