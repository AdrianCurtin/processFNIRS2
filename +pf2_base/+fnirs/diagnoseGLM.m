function report = diagnoseGLM(Y, X, regressorNames, varargin)
% DIAGNOSEGLM Run fitGLM and produce a diagnostic report
%
% Fits a GLM and computes diagnostics to pinpoint causes of beta
% attenuation: collinearity, data scale, task-data correlation, residual
% autocorrelation, and partial R-squared. Prints a human-readable summary.
%
% Syntax:
%   report = pf2_base.fnirs.diagnoseGLM(Y, X, regressorNames)
%   report = pf2_base.fnirs.diagnoseGLM(Y, X, regressorNames, 'Name', Value)
%
% Inputs:
%   Y              - Channel data [T x C]
%   X              - Design matrix [T x P]
%   regressorNames - Cell array {1 x P} of regressor labels
%
% Name-Value Parameters:
%   All fitGLM parameters are forwarded, plus:
%   'Verbose'           - Print human-readable report (default: true)
%   'BlockAvgAmplitude' - Expected amplitude [K x C] for comparison (default: [])
%   'StimRegressorIdx'  - Indices of stimulus regressors (default: auto-detect)
%
% Outputs:
%   report - Struct with diagnostic fields:
%     .conditionNumber     - cond(X) [scalar]
%     .VIF                 - Variance inflation factor [1 x P]
%     .regressorScale      - max(abs(X(:,j))) per column [1 x P]
%     .correlationMatrix   - corrcoef(X) [P x P]
%     .betaStats           - Per-regressor stats struct array
%     .R2                  - From fitGLM [1 x C]
%     .R2stats             - mean, median, min, max of R2
%     .partialR2           - Per stimulus regressor [K x C]
%     .residualACF         - Autocorrelation at lags 1-5 [5 x C]
%     .meanResidualACF     - Mean ACF across channels [5 x 1]
%     .predictedAmplitude  - beta * regressor scale [K x C]
%     .taskDataCorrelation - corr(X(:,stimIdx), Y) [K x C]
%     .dataStats           - .std [1xC], .range [1xC]
%     .stimRegressorIdx    - Indices of stimulus regressors [1 x K]
%     .flags               - Cell array of warning/note strings
%     .glmResults          - Full fitGLM output
%
% Example:
%   events(1) = struct('name', 'Task', 'onsets', [10 40 70], 'duration', 20);
%   [X, names] = pf2_base.fnirs.buildDesignMatrix(data.time, data.fs, events);
%   report = pf2_base.fnirs.diagnoseGLM(data.HbO, X, names);
%
% See also: pf2_base.fnirs.fitGLM, pf2_base.fnirs.buildDesignMatrix

% --- Parse inputs ---
p = inputParser;
p.KeepUnmatched = true;
p.addRequired('Y', @isnumeric);
p.addRequired('X', @isnumeric);
p.addRequired('regressorNames', @iscell);
p.addParameter('Verbose', true, @islogical);
p.addParameter('BlockAvgAmplitude', [], @isnumeric);
p.addParameter('StimRegressorIdx', [], @isnumeric);
p.parse(Y, X, regressorNames, varargin{:});

verbose = p.Results.Verbose;
blockAvgAmp = p.Results.BlockAvgAmplitude;
stimIdx = p.Results.StimRegressorIdx;

% Forward unmatched params to fitGLM
glmArgs = [fieldnames(p.Unmatched), struct2cell(p.Unmatched)]';
glmArgs = glmArgs(:)';

[T, nCh] = size(Y);
P = size(X, 2);

% Auto-detect stimulus regressors (not drift, constant, short channel)
if isempty(stimIdx)
    driftPattern = '^(constant|drift_|dct_|short_ch)';
    isStim = cellfun(@(n) isempty(regexp(n, driftPattern, 'once')), regressorNames);
    % Also exclude derivative/dispersion regressors
    isDeriv = contains(regressorNames, '_deriv') | contains(regressorNames, '_disp');
    isStim = isStim & ~isDeriv;
    stimIdx = find(isStim);
end
K = length(stimIdx);

flags = {};

% --- Fit GLM ---
glmResults = pf2_base.fnirs.fitGLM(Y, X, regressorNames, glmArgs{:});

% --- Design matrix diagnostics ---

% Condition number
condNum = cond(X);
if condNum > 1000
    flags{end+1} = sprintf('WARNING: High condition number (%.0f > 1000)', condNum);
end

% Regressor scale
regressorScale = max(abs(X), [], 1);

% Correlation matrix
corrMat = corrcoef(X);

% VIF: VIF_j = 1 / (1 - R2_j) where R2_j is from regressing X_j on all other columns
VIF = ones(1, P);
for j = 1:P
    otherIdx = setdiff(1:P, j);
    Xother = X(:, otherIdx);
    Xj = X(:, j);
    betaJ = pinv(Xother) * Xj;
    predJ = Xother * betaJ;
    SSres = sum((Xj - predJ).^2);
    SStot = sum((Xj - mean(Xj)).^2);
    if SStot > 0
        R2j = 1 - SSres / SStot;
        if R2j < 1
            VIF(j) = 1 / (1 - R2j);
        else
            VIF(j) = Inf;
        end
    end
end

% Flag high VIF for stimulus regressors
for k = 1:K
    idx = stimIdx(k);
    if VIF(idx) > 5
        flags{end+1} = sprintf('WARNING: VIF=%.1f for "%s" (> 5)', ...
            VIF(idx), regressorNames{idx}); %#ok<AGROW>
    end
end

% --- Beta statistics ---
betaStats = struct();
for j = 1:P
    b = glmResults.beta(j, :);
    betaStats(j).name = regressorNames{j};
    betaStats(j).mean = mean(b);
    betaStats(j).median = median(b);
    betaStats(j).min = min(b);
    betaStats(j).max = max(b);
    betaStats(j).absMax = max(abs(b));
end

% --- R2 statistics ---
R2stats.mean = mean(glmResults.R2);
R2stats.median = median(glmResults.R2);
R2stats.min = min(glmResults.R2);
R2stats.max = max(glmResults.R2);

if R2stats.median < 0.05
    flags{end+1} = sprintf('WARNING: Low median R2=%.4f (< 0.05)', R2stats.median);
end

% --- Task-data correlation ---
taskDataCorr = zeros(K, nCh);
for k = 1:K
    for ch = 1:nCh
        r = corrcoef(X(:, stimIdx(k)), Y(:, ch));
        taskDataCorr(k, ch) = r(1, 2);
    end
end

for k = 1:K
    medAbsCorr = median(abs(taskDataCorr(k, :)));
    if medAbsCorr < 0.05
        flags{end+1} = sprintf(['WARNING: Near-zero task-data correlation ' ...
            '(median |r|=%.4f) for "%s" -- task regressor does not match data. ' ...
            'Check: (1) data may be over-filtered, (2) HRF shape mismatch, ' ...
            '(3) event timing error'], medAbsCorr, regressorNames{stimIdx(k)}); %#ok<AGROW>
    end
end

% --- Predicted amplitude ---
predictedAmp = zeros(K, nCh);
for k = 1:K
    idx = stimIdx(k);
    predictedAmp(k, :) = glmResults.beta(idx, :) * regressorScale(idx);
end

% Flag small betas with explanatory note
for k = 1:K
    idx = stimIdx(k);
    meanBeta = mean(glmResults.beta(idx, :));
    meanPredAmp = mean(predictedAmp(k, :));
    if abs(meanBeta) < 0.1 && abs(meanPredAmp) > abs(meanBeta) * 2
        flags{end+1} = sprintf(['NOTE: Beta for "%s" is small (mean=%.4f) but ' ...
            'predicted amplitude is %.4f (regressor peak=%.1f from HRF convolution)'], ...
            regressorNames{idx}, meanBeta, meanPredAmp, regressorScale(idx)); %#ok<AGROW>
    end
end

% --- Block average comparison ---
if ~isempty(blockAvgAmp)
    for k = 1:K
        ratio = predictedAmp(k, :) ./ blockAvgAmp(k, :);
        medRatio = median(ratio(isfinite(ratio)));
        flags{end+1} = sprintf('COMPARISON: "%s" predicted/blockAvg ratio = %.2f (should be ~1.0)', ...
            regressorNames{stimIdx(k)}, medRatio); %#ok<AGROW>
    end
end

% --- Partial R2 ---
driftIdx = setdiff(1:P, stimIdx);
partialR2 = zeros(K, nCh);

if ~isempty(driftIdx)
    Xdrift = X(:, driftIdx);
    betaDrift = pinv(Xdrift) * Y;
    resDrift = Y - Xdrift * betaDrift;
    SSres_drift = sum(resDrift.^2, 1);
    SSres_full = sum(glmResults.residuals.^2, 1);

    for k = 1:K
        % Partial R2 for each stimulus regressor: fit drift + this stim only
        Xpartial = X(:, [driftIdx, stimIdx(k)]);
        betaPartial = pinv(Xpartial) * Y;
        resPartial = Y - Xpartial * betaPartial;
        SSres_partial = sum(resPartial.^2, 1);
        partialR2(k, :) = (SSres_drift - SSres_partial) ./ SSres_drift;
    end

    for k = 1:K
        medPR2 = median(partialR2(k, :));
        if medPR2 < 0.01
            flags{end+1} = sprintf(['WARNING: Low partial R2=%.4f for "%s" ' ...
                '-- task regressor adds no unique variance beyond drift'], ...
                medPR2, regressorNames{stimIdx(k)}); %#ok<AGROW>
        end
    end
else
    % No drift regressors: partial R2 equals full R2
    for k = 1:K
        partialR2(k, :) = glmResults.R2;
    end
end

% --- Residual autocorrelation ---
maxLag = 5;
residualACF = zeros(maxLag, nCh);
res = glmResults.residuals;
for lag = 1:maxLag
    r1 = res(1:end-lag, :);
    r2 = res(lag+1:end, :);
    % Normalized autocorrelation
    denom = sum(res.^2, 1);
    denom(denom == 0) = 1;
    residualACF(lag, :) = sum(r1 .* r2, 1) ./ denom;
end
meanResidualACF = mean(residualACF, 2);

% Only flag for OLS
method = 'OLS';
if isfield(glmResults, 'method')
    method = glmResults.method;
end
if strcmp(method, 'OLS') && abs(meanResidualACF(1)) > 0.3
    flags{end+1} = sprintf('WARNING: High residual lag-1 ACF=%.2f (consider AR-IRLS)', ...
        meanResidualACF(1));
end

% --- Data statistics ---
dataStats.std = std(Y, 0, 1);
dataStats.range = range(Y, 1);
medStd = median(dataStats.std);
if medStd > 10
    flags{end+1} = sprintf(['WARNING: Abnormal data scale (median std=%.1f) ' ...
        '-- check preprocessing pipeline for filter gain issues'], medStd);
end

% --- Pack report ---
report.conditionNumber = condNum;
report.VIF = VIF;
report.regressorScale = regressorScale;
report.correlationMatrix = corrMat;
report.betaStats = betaStats;
report.R2 = glmResults.R2;
report.R2stats = R2stats;
report.partialR2 = partialR2;
report.residualACF = residualACF;
report.meanResidualACF = meanResidualACF;
report.predictedAmplitude = predictedAmp;
report.taskDataCorrelation = taskDataCorr;
report.dataStats = dataStats;
report.stimRegressorIdx = stimIdx;
report.flags = flags;
report.glmResults = glmResults;

% --- Verbose output ---
if verbose
    printReport(report, regressorNames, stimIdx);
end

end

%%_Subfunctions_________________________________________________________

function printReport(report, regressorNames, stimIdx)
% PRINTREPORT Print human-readable diagnostic summary

P = length(regressorNames);
nCh = size(report.R2, 2);
T = size(report.glmResults.residuals, 1);

fprintf('\n=== GLM Diagnostics ===\n');
fprintf('Design Matrix: T=%d, P=%d, cond(X)=%.1f\n', T, P, report.conditionNumber);
fprintf('Data: %d channels, std range [%.4f, %.4f]\n', ...
    nCh, min(report.dataStats.std), max(report.dataStats.std));

fprintf('\nRegressor Summary:\n');
fprintf('  %-20s %8s %8s %10s %12s %12s\n', ...
    'Name', 'Scale', 'VIF', 'corr(X,Y)', 'Beta(mean)', 'PredAmp');
fprintf('  %-20s %8s %8s %10s %12s %12s\n', ...
    '----', '-----', '---', '---------', '----------', '-------');

for j = 1:P
    isStim = ismember(j, stimIdx);
    if isStim
        k = find(stimIdx == j);
        medCorr = median(report.taskDataCorrelation(k, :));
        meanPredAmp = mean(report.predictedAmplitude(k, :));
        fprintf('  %-20s %8.1f %8.1f %10.4f %12.4f %12.4f\n', ...
            regressorNames{j}, report.regressorScale(j), report.VIF(j), ...
            medCorr, report.betaStats(j).mean, meanPredAmp);
    else
        fprintf('  %-20s %8.1f %8.1f %10s %12.4f %12s\n', ...
            regressorNames{j}, report.regressorScale(j), report.VIF(j), ...
            '-', report.betaStats(j).mean, '-');
    end
end

fprintf('\nModel Fit: R2 median=%.4f [%.4f, %.4f]\n', ...
    report.R2stats.median, report.R2stats.min, report.R2stats.max);

if ~isempty(stimIdx)
    for k = 1:length(stimIdx)
        medPR2 = median(report.partialR2(k, :));
        minPR2 = min(report.partialR2(k, :));
        maxPR2 = max(report.partialR2(k, :));
        fprintf('Partial R2 ("%s"): median=%.4f [%.4f, %.4f]\n', ...
            regressorNames{stimIdx(k)}, medPR2, minPR2, maxPR2);
    end
end

fprintf('Residual ACF(1): %.2f\n', report.meanResidualACF(1));

if ~isempty(report.flags)
    fprintf('\nFlags:\n');
    for i = 1:length(report.flags)
        fprintf('  %s\n', report.flags{i});
    end
end

fprintf('\n');

end
