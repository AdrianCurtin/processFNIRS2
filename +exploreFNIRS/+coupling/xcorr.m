function result = xcorr(x, y, fs, varargin)
% XCORR Lagged cross-correlation between two time series
%
% Computes cross-correlation using MATLAB's xcorr, returning the peak
% correlation value and its lag. Optionally constrains the maximum lag.
%
% Syntax:
%   result = exploreFNIRS.coupling.xcorr(x, y, fs)
%   result = exploreFNIRS.coupling.xcorr(x, y, fs, 'MaxLag', 5)
%
% Inputs:
%   x  - [T x 1] time series
%   y  - [T x 1] time series
%   fs - Sampling frequency (Hz)
%
% Name-Value Parameters:
%   MaxLag     - Maximum lag in seconds (default: length(x)/fs/4)
%   Normalize  - Normalization mode: 'coeff' (default), 'none', 'biased', 'unbiased'
%   WindowSize - Sliding window duration in seconds (default: 0, full signal)
%   WindowStep - Step size in seconds (default: WindowSize/2, 50% overlap)
%
% Outputs:
%   result - Struct with fields:
%     .value      - Peak cross-correlation value
%     .pvalue     - Approximate p-value (based on Fisher z-transform)
%     .lag        - Lag in seconds at peak correlation
%     .lagSamples - Lag in samples at peak correlation
%     .xcorrFull  - Full cross-correlation vector
%     .lags       - Full lag vector in seconds
%     .method     - 'xcorr'
%     .windowed   - true if sliding window was used
%
% Reference:
%   Standard lagged cross-correlation. For its use in fNIRS hyperscanning
%   to estimate inter-brain temporal delays see: Cui, X., Bryant, D. M. &
%   Reiss, A. L. (2012). NIRS-based hyperscanning reveals increased
%   interpersonal coherence in superior frontal cortex during cooperation.
%   NeuroImage, 59(3), 2430-2437. DOI: 10.1016/j.neuroimage.2011.09.003
%
% See also: exploreFNIRS.coupling.pearson, exploreFNIRS.coupling.coherence

    p = inputParser;
    addRequired(p, 'x', @(v) isnumeric(v) && isvector(v));
    addRequired(p, 'y', @(v) isnumeric(v) && isvector(v));
    addRequired(p, 'fs', @(v) isnumeric(v) && isscalar(v) && v > 0);
    addParameter(p, 'MaxLag', 0, @(v) isnumeric(v) && isscalar(v) && v >= 0);
    addParameter(p, 'Normalize', 'coeff', @ischar);
    addParameter(p, 'WindowSize', 0, @(v) isnumeric(v) && isscalar(v) && v >= 0);
    addParameter(p, 'WindowStep', 0, @(v) isnumeric(v) && isscalar(v) && v >= 0);
    parse(p, x, y, fs, varargin{:});
    opts = p.Results;

    x = x(:);
    y = y(:);
    if length(x) ~= length(y)
        error('exploreFNIRS:coupling:xcorr', 'x and y must have equal length');
    end

    % Remove NaN by interpolation for xcorr (requires continuous signal)
    x = fillNaN(x);
    y = fillNaN(y);

    T = length(x);
    maxLagSec = opts.MaxLag;
    if maxLagSec <= 0
        maxLagSec = T / fs / 4;
    end
    maxLagSamp = round(maxLagSec * fs);

    winSamples = round(opts.WindowSize * fs);

    if winSamples <= 0 || winSamples >= T
        % Full-signal mode
        result = computeXcorr(x, y, fs, maxLagSamp, opts.Normalize);
        result.windowed = false;
    else
        % Sliding window mode
        stepSamples = round(opts.WindowStep * fs);
        if stepSamples <= 0
            stepSamples = max(1, round(winSamples / 2));
        end

        starts = 1:stepSamples:(T - winSamples + 1);
        nWin = length(starts);

        rVals = nan(nWin, 1);
        pVals = nan(nWin, 1);
        lagVals = nan(nWin, 1);
        winTimes = nan(nWin, 1);

        for w = 1:nWin
            idx = starts(w):(starts(w) + winSamples - 1);
            res = computeXcorr(x(idx), y(idx), fs, ...
                min(maxLagSamp, floor(winSamples/2)), opts.Normalize);
            rVals(w) = res.value;
            pVals(w) = res.pvalue;
            lagVals(w) = res.lag;
            winTimes(w) = (starts(w) + winSamples/2 - 1) / fs;
        end

        result.value = rVals;
        result.pvalue = pVals;
        result.lag = lagVals;
        result.method = 'xcorr';
        result.windowed = true;
        result.windowTimes = winTimes;
    end
end


function res = computeXcorr(x, y, fs, maxLagSamp, normMode)
% Compute cross-correlation for a single segment
    % Use function handle to avoid shadowing by our package function name
    xcorrFn = str2func('xcorr');
    [c, lags] = xcorrFn(x - mean(x), y - mean(y), maxLagSamp, normMode);

    [peakVal, peakIdx] = max(abs(c));
    peakLagSamp = lags(peakIdx);

    % Preserve sign at peak
    peakVal = c(peakIdx);

    % Approximate p-value using Fisher z-transform (only valid for 'coeff' normalization)
    if strcmp(normMode, 'coeff')
        n = length(x);
        peakVal = max(min(peakVal, 0.9999), -0.9999);
        z = atanh(peakVal) * sqrt(n - 3);
        pval = 2 * (1 - normcdf(abs(z)));
        nLags = 2 * maxLagSamp + 1;
        pval = min(pval * nLags, 1);
    else
        pval = NaN;
    end

    res.value = peakVal;
    res.pvalue = pval;
    res.lag = peakLagSamp / fs;
    res.lagSamples = peakLagSamp;
    res.xcorrFull = c;
    res.lags = lags / fs;
    res.method = 'xcorr';
end


function v = fillNaN(v)
% Linear interpolation of NaN values
    nanIdx = isnan(v);
    if ~any(nanIdx), return; end
    if all(nanIdx), v(:) = 0; return; end
    t = (1:length(v))';
    v(nanIdx) = interp1(t(~nanIdx), v(~nanIdx), t(nanIdx), 'linear', 'extrap');
end
