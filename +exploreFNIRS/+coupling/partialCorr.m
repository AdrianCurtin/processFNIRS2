function result = partialCorr(x, y, fs, varargin)
% PARTIALCORR Partial correlation between two time series
%
% Computes partial Pearson correlation between two time series after
% controlling for confounding signals. When confounds are provided, both
% signals are residualized (ordinary least-squares regression) before
% correlation. Without confounds, returns the standard Pearson correlation.
%
% For connectivity matrices, partial correlation is more commonly computed
% via the precision matrix (inverse covariance). When called through
% computeMatrix with Method='partialcorr', a batch precision-matrix path
% is used automatically for efficiency.
%
% Syntax:
%   result = exploreFNIRS.coupling.partialCorr(x, y, fs)
%   result = exploreFNIRS.coupling.partialCorr(x, y, fs, ...
%       'Confounds', Z)
%   result = exploreFNIRS.coupling.partialCorr(x, y, fs, ...
%       'WindowSize', 10)
%
% Inputs:
%   x  - [T x 1] time series
%   y  - [T x 1] time series
%   fs - Sampling frequency (Hz)
%
% Name-Value Parameters:
%   Confounds  - [T x K] matrix of confound signals to regress out
%                (default: [], no confounds)
%   WindowSize - Sliding window duration in seconds (default: 0, full signal)
%   WindowStep - Step size in seconds (default: WindowSize/2, 50% overlap)
%
% Outputs:
%   result - Struct with fields:
%     .value       - Partial correlation coefficient (scalar, or [W x 1])
%     .pvalue      - Two-tailed p-value(s)
%     .method      - 'partialCorr'
%     .windowed    - true if sliding window was used
%     .windowTimes - [W x 1] center times (windowed only)
%     .nConfounds  - Number of confound signals used
%
% Algorithm:
%   1. Regress confounds Z from both x and y: x_res = x - Z*(Z\x)
%   2. Compute Pearson correlation between residuals
%   3. p-value uses t-distribution with df = T - K - 2
%
% Reference:
%   Marrelec, G., Krainik, A., Duffau, H., Pelegrini-Issac, M.,
%   Lehericy, S., Doyon, J. & Benali, H. (2006). Partial correlation
%   for functional brain interactivity investigation in functional MRI.
%   NeuroImage, 32(1), 228-237. DOI: 10.1016/j.neuroimage.2005.12.057
%
% See also: exploreFNIRS.coupling.pearson, exploreFNIRS.coupling.spearman

    p = inputParser;
    addRequired(p, 'x', @(v) isnumeric(v) && isvector(v));
    addRequired(p, 'y', @(v) isnumeric(v) && isvector(v));
    addRequired(p, 'fs', @(v) isnumeric(v) && isscalar(v) && v > 0);
    addParameter(p, 'Confounds', [], @(v) isnumeric(v));
    addParameter(p, 'WindowSize', 0, @(v) isnumeric(v) && isscalar(v) && v >= 0);
    addParameter(p, 'WindowStep', 0, @(v) isnumeric(v) && isscalar(v) && v >= 0);
    parse(p, x, y, fs, varargin{:});
    opts = p.Results;

    x = x(:);
    y = y(:);
    if length(x) ~= length(y)
        error('exploreFNIRS:coupling:partialCorr', 'x and y must have equal length');
    end

    Z = opts.Confounds;
    if ~isempty(Z) && size(Z, 1) ~= length(x)
        error('exploreFNIRS:coupling:partialCorr', ...
            'Confounds must have the same number of rows as x (%d), got %d', ...
            length(x), size(Z, 1));
    end
    nConf = size(Z, 2);

    winSamples = round(opts.WindowSize * fs);

    if winSamples <= 0 || winSamples >= length(x)
        % Full-signal mode
        [r, pval] = computePartialCorr(x, y, Z);

        result.value = r;
        result.pvalue = pval;
        result.method = 'partialCorr';
        result.windowed = false;
        result.nConfounds = nConf;
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
            if isempty(Z)
                Zw = [];
            else
                Zw = Z(idx, :);
            end
            [rVals(w), pVals(w)] = computePartialCorr(xw, yw, Zw);
            winTimes(w) = (starts(w) + winSamples/2 - 1) / fs;
        end

        result.value = rVals;
        result.pvalue = pVals;
        result.method = 'partialCorr';
        result.windowed = true;
        result.windowTimes = winTimes;
        result.nConfounds = nConf;
    end
end


function [r, pval] = computePartialCorr(x, y, Z)
% Compute partial correlation between x and y controlling for Z

    % Remove NaN observations
    valid = ~isnan(x) & ~isnan(y);
    if ~isempty(Z)
        valid = valid & ~any(isnan(Z), 2);
    end

    if sum(valid) < 3
        r = NaN;
        pval = NaN;
        return;
    end

    xv = x(valid);
    yv = y(valid);
    n = length(xv);

    if isempty(Z)
        % No confounds: standard Pearson
        [r, pval] = corr(xv, yv, 'Type', 'Pearson');
        return;
    end

    Zv = Z(valid, :);
    nConf = size(Zv, 2);

    % Need at least nConf + 3 observations for meaningful partial corr
    if n < nConf + 3
        r = NaN;
        pval = NaN;
        return;
    end

    % Residualize x and y by regressing out Z
    % Add intercept column
    Zint = [ones(n, 1), Zv];

    % Use QR decomposition for numerical stability
    [Q, ~] = qr(Zint, 0);
    xRes = xv - Q * (Q' * xv);
    yRes = yv - Q * (Q' * yv);

    % Pearson correlation of residuals
    r = corr(xRes, yRes, 'Type', 'Pearson');

    % p-value via t-distribution with df = n - nConf - 2
    df = n - nConf - 2;
    if df < 1
        pval = NaN;
    else
        tStat = r * sqrt(df / (1 - r^2 + eps));
        pval = 2 * (1 - tcdf(abs(tStat), df));
    end
end
