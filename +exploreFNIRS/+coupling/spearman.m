function result = spearman(x, y, fs, varargin)
% SPEARMAN Spearman rank correlation between two time series
%
% Computes Spearman's rho between two equal-length time series, with an
% optional sliding-window mode for time-resolved coupling.
%
% Syntax:
%   result = exploreFNIRS.coupling.spearman(x, y, fs)
%   result = exploreFNIRS.coupling.spearman(x, y, fs, 'WindowSize', 10)
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
%     .value    - Spearman rho (scalar, or [W x 1] for windowed)
%     .pvalue   - Two-tailed p-value(s)
%     .method   - 'spearman'
%     .windowed - true if sliding window was used
%     .windowTimes - [W x 1] center times (windowed only)
%
% Reference:
%   Standard Spearman rank-order correlation. Rank-based coupling is robust
%   to outliers and nonlinear monotonic relationships in neuroimaging; see:
%   Scholkmann, F., Holper, L., Wolf, U. & Wolf, M. (2013). A new
%   methodical approach in neuroscience: assessing inter-personal brain
%   coupling using functional near-infrared imaging (fNIRI) hyperscanning.
%   Frontiers in Human Neuroscience, 7, 813.
%   DOI: 10.3389/fnhum.2013.00813
%
% See also: exploreFNIRS.coupling.pearson, exploreFNIRS.coupling.xcorr

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
        error('exploreFNIRS:coupling:spearman', 'x and y must have equal length');
    end

    winSamples = round(opts.WindowSize * fs);

    if winSamples <= 0 || winSamples >= length(x)
        % Full-signal mode
        valid = ~isnan(x) & ~isnan(y);
        if sum(valid) < 3
            result.value = NaN;
            result.pvalue = NaN;
            result.method = 'spearman';
            result.windowed = false;
            return;
        end
        [r, pval] = pf2_base.compat.corr(x(valid), y(valid), 'Type', 'Spearman');

        result.value = r;
        result.pvalue = pval;
        result.method = 'spearman';
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
                [rVals(w), pVals(w)] = pf2_base.compat.corr(xw(valid), yw(valid), 'Type', 'Spearman');
            end
            winTimes(w) = (starts(w) + winSamples/2 - 1) / fs;
        end

        result.value = rVals;
        result.pvalue = pVals;
        result.method = 'spearman';
        result.windowed = true;
        result.windowTimes = winTimes;
    end
end
