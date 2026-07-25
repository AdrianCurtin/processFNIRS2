function result = granger(x, y, fs, varargin)
% GRANGER Bivariate Granger causality between two fNIRS time series
%
% Tests whether past values of x improve the prediction of y beyond what
% past values of y alone provide. Uses OLS lag-regression with an F-test on
% residual variance reduction (Granger 1969, Geweke 1982).
%
% IMPORTANT CAVEAT: Granger causality on fNIRS signals does NOT establish
% neural causality. Direction inferred from the F-statistic can be manufactured
% by (1) differences in hemodynamic response latency between brain regions
% (the region with the faster HRF appears to "cause" the slower one even with
% simultaneous neural activity), (2) a common systemic or physiological driver
% (cardiac pulsation, Mayer waves, respiration, global signal) that reaches
% different channels with different temporal profiles, and (3) spatially
% structured shared noise (motion artifacts, superficial physiology). Interpret
% results as directed temporal predictability within the measured haemodynamic
% signal, not as directional neural influence.
%
% AR model order selection: by default ModelOrder=5 (fixed). Set
% ModelOrder='auto' to select the order by BIC over 1..round(fs/2), matching
% the approach in fitGLM. BIC is preferred over AIC at fNIRS run lengths to
% avoid overfitting (Schwarz 1978). In sliding-window mode with 'auto', the
% order is selected on the full signal first and then applied uniformly to
% all windows so that windowed F-statistics are comparable. The selected order
% is stored in result.modelOrder.
%
% References:
%   Granger, C. W. J. (1969). Investigating causal relations by econometric
%   models and cross-spectral methods. Econometrica, 37(3), 424-438.
%
%   Geweke, J. (1982). Measurement of linear dependence and feedback between
%   multiple time series. Journal of the American Statistical Association,
%   77(378), 304-313.
%
%   Schwarz, G. (1978). Estimating the Dimension of a Model. The Annals of
%   Statistics, 6(2), 461-464. DOI: 10.1214/aos/1176344136
%
%   Akaike, H. (1974). A new look at the statistical model identification.
%   IEEE Transactions on Automatic Control, 19(6), 716-723.
%   DOI: 10.1109/tac.1974.1100705
%
% Syntax:
%   result = exploreFNIRS.coupling.granger(x, y, fs)
%   result = exploreFNIRS.coupling.granger(x, y, fs, 'ModelOrder', 10)
%   result = exploreFNIRS.coupling.granger(x, y, fs, 'ModelOrder', 'auto')
%   result = exploreFNIRS.coupling.granger(x, y, fs, 'WindowSize', 30)
%
% Inputs:
%   x  - [T x 1] time series (candidate cause)
%   y  - [T x 1] time series (candidate effect)
%   fs - Sampling frequency in Hz [scalar]
%
% Name-Value Parameters:
%   'ModelOrder' - Number of lags for the AR model (default: 5)
%                  May also be the string 'auto', in which case BIC is
%                  minimised over candidate orders 1..round(fs/2). In
%                  sliding-window mode, order selection is done on the full
%                  signal and the selected order is applied to all windows.
%   'WindowSize' - Sliding window duration in seconds (default: 0, full signal)
%                  Set to 0 to use the full signal.
%   'WindowStep' - Step size in seconds (default: WindowSize/2, 50% overlap)
%
% Outputs:
%   result - Struct with fields:
%     .value       - F-statistic (scalar, or [W x 1] for windowed)
%     .pvalue      - p-value from F-distribution
%     .direction   - 'x->y'
%     .method      - 'granger'
%     .windowed    - true if sliding window was used
%     .modelOrder  - AR model order used (scalar; always present)
%     .windowTimes - [W x 1] center times (windowed only)
%
% Algorithm:
%   Restricted model:   y(t) = sum_k a_k * y(t-k) + e_r              (p params)
%   Unrestricted model: y(t) = sum_k a_k * y(t-k) + sum_k b_k * x(t-k) + e_u
%                                                                    (2p params)
%   Neither model fits an intercept, so the F-test denominator dof is
%   nObs - 2p (nObs minus the unrestricted model's parameter count only --
%   NOT nObs - 2p - 1, which would double-subtract a constant term that is
%   never estimated):
%   F = ((RSS_r - RSS_u) / p) / (RSS_u / (nObs - 2p)),  nObs = T - p
%
%   OLS lag regression is used (backslash solve). BIC for order selection:
%   BIC(p) = T_eff*log(sigma2_u) + 2*p*log(T_eff)
%   where sigma2_u = RSS_u / T_eff from the unrestricted model, and the penalty
%   counts the 2*p parameters of that model (p lags each of y and x).
%
% Example:
%   data = pf2.import.sampleData();
%   proc = processFNIRS2(data);
%   result = exploreFNIRS.coupling.granger(proc.HbO(:,1), proc.HbO(:,2), proc.fs);
%   fprintf('F = %.3f, p = %.4f\n', result.value, result.pvalue);
%
%   % Automatic order selection
%   result = exploreFNIRS.coupling.granger(proc.HbO(:,1), proc.HbO(:,2), proc.fs, ...
%       'ModelOrder', 'auto');
%   fprintf('Selected order: %d\n', result.modelOrder);
%
% Notes:
%   - Direction of apparent causality on fNIRS is NOT neural causality; see
%     the caveat in the extended description above.
%   - When T_valid <= 3*maxOrder (T is too short relative to the candidate
%     range), 'auto' order selection is skipped and order 1 is used with a
%     warning.
%
% See also: exploreFNIRS.coupling.wcoherence, exploreFNIRS.coupling.pearson,
%           exploreFNIRS.coupling.transferEntropy

    p = inputParser;
    addRequired(p, 'x', @(v) isnumeric(v) && isvector(v));
    addRequired(p, 'y', @(v) isnumeric(v) && isvector(v));
    addRequired(p, 'fs', @(v) isnumeric(v) && isscalar(v) && v > 0);
    addParameter(p, 'ModelOrder', 5, @(v) (isnumeric(v) && isscalar(v) && v >= 1) || ...
        (ischar(v) && strcmpi(v, 'auto')));
    addParameter(p, 'WindowSize', 0, @(v) isnumeric(v) && isscalar(v) && v >= 0);
    addParameter(p, 'WindowStep', 0, @(v) isnumeric(v) && isscalar(v) && v >= 0);
    parse(p, x, y, fs, varargin{:});
    opts = p.Results;

    x = x(:);
    y = y(:);
    if length(x) ~= length(y)
        error('exploreFNIRS:coupling:granger', 'x and y must have equal length');
    end

    % Resolve 'auto' model order on the full signal (before windowing)
    autoOrder = ischar(opts.ModelOrder) && strcmpi(opts.ModelOrder, 'auto');
    if autoOrder
        maxCand = min(round(fs / 2), floor(length(x) / 4));
        maxCand = max(maxCand, 1);

        % Guard: need at least 3*maxCand valid samples to run order selection
        validMask = ~isnan(x) & ~isnan(y);
        [~, segLen] = longestRun(validMask);
        if segLen <= 3 * maxCand
            warning('exploreFNIRS:coupling:granger:autoOrderShortSignal', ...
                ['Signal is too short (valid=%d samples) for BIC order ' ...
                 'selection up to order %d (need > %d). Using order 1.'], ...
                segLen, maxCand, 3 * maxCand);
            modelOrder = 1;
        else
            modelOrder = selectOrderBIC(x, y, maxCand);
        end
    else
        modelOrder = opts.ModelOrder;
    end

    winSamples = round(opts.WindowSize * fs);

    if winSamples <= 0 || winSamples >= length(x)
        % Full-signal mode
        [fStat, pval] = computeGranger(x, y, modelOrder);

        result.value = fStat;
        result.pvalue = pval;
        result.direction = 'x->y';
        result.method = 'granger';
        result.windowed = false;
        result.modelOrder = modelOrder;
    else
        % Sliding window mode: order is fixed (selected on full signal above)
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
            [fVals(w), pVals(w)] = computeGranger(xw, yw, modelOrder);
            winTimes(w) = (starts(w) + winSamples/2 - 1) / fs;
        end

        result.value = fVals;
        result.pvalue = pVals;
        result.direction = 'x->y';
        result.method = 'granger';
        result.windowed = true;
        result.modelOrder = modelOrder;
        result.windowTimes = winTimes;
    end
end

%%_Subfunctions_________________________________________________________

function [fStat, pval] = computeGranger(x, y, order)
% COMPUTEGRANGER Compute Granger F-statistic for x -> y
%
% Inputs:
%   x     - [T x 1] candidate cause
%   y     - [T x 1] candidate effect
%   order - AR model order [scalar]
%
% Outputs:
%   fStat - F-statistic [scalar]
%   pval  - p-value [scalar]

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

    % Solve via backslash (OLS)
    betaR = Xr \ Y;
    betaU = Xu \ Y;

    residR = Y - Xr * betaR;
    residU = Y - Xu * betaU;

    rssR = sum(residR .^ 2);
    rssU = sum(residU .^ 2);

    % F-statistic. dfDen = nObs - (# unrestricted-model parameters). Neither
    % the restricted model (order params: y-lags) nor the unrestricted model
    % (2*order params: y-lags + x-lags) fits an intercept, so no additional
    % "-1" is subtracted for a constant term that was never estimated.
    dfNum = order;
    dfDen = nObs - 2 * order;

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


function order = selectOrderBIC(x, y, maxOrder)
% SELECTORDERBIC Select Granger model order by BIC on OLS residuals
%
% For each candidate order p = 1..maxOrder, fits the unrestricted OLS model
% (y lags + x lags) and computes:
%   BIC(p) = T_eff * log(RSS_u / T_eff) + 2*p * log(T_eff)
% (the 2*p penalty counts the unrestricted model's 2*p parameters). The order
% minimising BIC is returned.
%
% BIC is derived from OLS residual variance (not Yule-Walker), matching the
% OLS backslash inference used in computeGranger. T_eff = nObs - 2*p.
%
% Inputs:
%   x        - [T x 1] candidate cause
%   y        - [T x 1] candidate effect
%   maxOrder - Maximum candidate order [scalar]
%
% Outputs:
%   order - Selected AR order [scalar]

    % Use longest valid segment for order selection
    valid = ~isnan(x) & ~isnan(y);
    [segStart, segLen] = longestRun(valid);
    if segLen == 0
        order = 1;
        return;
    end
    x = x(segStart:segStart + segLen - 1);
    y = y(segStart:segStart + segLen - 1);
    T = length(y);

    bicVals = nan(maxOrder, 1);

    for q = 1:maxOrder
        nObs = T - q;
        dfDen = nObs - 2 * q - 1;
        if dfDen <= 0
            break;
        end

        Y = y((q + 1):T);

        % Unrestricted model lag matrix
        Xu = zeros(nObs, 2 * q);
        for k = 1:q
            Xu(:, k)     = y((q + 1 - k):(T - k));
            Xu(:, q + k) = x((q + 1 - k):(T - k));
        end

        betaU  = Xu \ Y;
        residU = Y - Xu * betaU;
        rssU   = sum(residU .^ 2);

        if rssU <= 0 || ~isfinite(rssU)
            continue;
        end

        sigma2 = rssU / nObs;
        % The unrestricted model has 2*q parameters (q lags each of y and x), so
        % the BIC complexity penalty must count 2*q, not q; using q biased
        % selection toward larger lag orders.
        bicVals(q) = nObs * log(sigma2) + 2 * q * log(nObs);
    end

    if all(isnan(bicVals))
        warning('exploreFNIRS:coupling:granger:autoOrderFallback', ...
            'BIC order selection produced all NaN; falling back to order 1.');
        order = 1;
        return;
    end

    [~, order] = min(bicVals);
end


function [start, len] = longestRun(mask)
% LONGESTRUN Find the start index and length of the longest true run
%
% Inputs:
%   mask - Logical vector [T x 1]
%
% Outputs:
%   start - Start index of longest run [scalar]
%   len   - Length of longest run [scalar]

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
