% INSPECTDATASETII Quick summary of Dataset II benchmark results
%
% Loads all per-subject results and prints:
%   1. Result struct fields per pipeline (to understand what was saved)
%   2. Per-session data availability
%   3. Block-avg pipelines: mean HbO activation per session
%   4. GLM pipelines: beta weights, t-stats, R-squared, significant channels
%   5. QC pipelines: channel retention rates

fprintf('\n=== Dataset II Results Inspection ===\n\n');

scriptDir = fileparts(mfilename('fullpath'));
resultsDir = fullfile(fileparts(scriptDir), 'results', 'datasetII');

pipeDirs = dir(resultsDir);
pipeDirs = pipeDirs([pipeDirs.isdir] & ~startsWith({pipeDirs.name}, '.'));

sessions = {'ses_left2s', 'ses_left3s', 'ses_right2s', 'ses_right3s'};
sesLabels = {'L-2s', 'L-3s', 'R-2s', 'R-3s'};

%% 1. Inspect structure of first result per pipeline
fprintf('--- Result Structure by Pipeline ---\n\n');
for p = 1:length(pipeDirs)
    pipeName = pipeDirs(p).name;
    subFiles = dir(fullfile(resultsDir, pipeName, 'sub-*.mat'));
    if isempty(subFiles), continue; end

    loaded = load(fullfile(resultsDir, pipeName, subFiles(1).name), 'result');
    r = loaded.result;

    fprintf('[%s] Top fields: %s\n', pipeName, strjoin(fieldnames(r), ', '));

    % Check first available session
    if isfield(r, 'sessions')
        sesFields = fieldnames(r.sessions);
        if ~isempty(sesFields)
            sesData = r.sessions.(sesFields{1});
            fprintf('  Session fields: %s\n', strjoin(fieldnames(sesData), ', '));

            if isfield(sesData, 'glm')
                glm = sesData.glm;
                fprintf('  GLM fields: %s\n', strjoin(fieldnames(glm), ', '));
                if isfield(glm, 'beta')
                    fprintf('  Beta size: [%s]\n', num2str(size(glm.beta)));
                end
            end
            if isfield(sesData, 'meanHbO')
                fprintf('  meanHbO size: [1 x %d]\n', length(sesData.meanHbO));
            end
            if isfield(sesData, 'error')
                fprintf('  ERROR: %s\n', sesData.error);
            end
        end
    end
    fprintf('\n');
end

%% 2. Block-averaging pipelines: mean activation per session
fprintf('\n--- Block-Averaging Pipelines: Mean HbO (channel-averaged) ---\n\n');
fprintf('%-25s %6s ', 'Pipeline', 'nSub');
for si = 1:4
    fprintf('%8s ', sesLabels{si});
end
fprintf('\n%s\n', repmat('-', 1, 70));

for p = 1:length(pipeDirs)
    pipeName = pipeDirs(p).name;
    subFiles = dir(fullfile(resultsDir, pipeName, 'sub-*.mat'));

    % Check if this is a blockavg pipeline
    loaded = load(fullfile(resultsDir, pipeName, subFiles(1).name), 'result');
    r = loaded.result;
    if ~isfield(r, 'sessions'), continue; end
    sesFields = fieldnames(r.sessions);
    if isempty(sesFields), continue; end
    firstSes = r.sessions.(sesFields{1});
    if ~isfield(firstSes, 'meanHbO'), continue; end

    % Collect data across subjects
    nSub = length(subFiles);
    sesMeans = nan(nSub, 4);

    for s = 1:nSub
        loaded = load(fullfile(resultsDir, pipeName, subFiles(s).name), 'result');
        r = loaded.result;
        for si = 1:4
            if isfield(r.sessions, sessions{si})
                sesData = r.sessions.(sessions{si});
                if isfield(sesData, 'meanHbO') && ~isfield(sesData, 'error')
                    sesMeans(s, si) = mean(sesData.meanHbO, 'omitnan');
                end
            end
        end
    end

    fprintf('%-25s %6d ', pipeName, nSub);
    for si = 1:4
        vals = sesMeans(:, si);
        vals = vals(~isnan(vals));
        if ~isempty(vals)
            fprintf('%+7.4f ', mean(vals));
        else
            fprintf('%8s ', 'N/A');
        end
    end
    fprintf('\n');
end

%% 3. GLM pipelines: beta, t-stat, R2, significant channels
fprintf('\n\n--- GLM Pipelines: First-Condition Statistics ---\n\n');
fprintf('%-25s %6s %10s %10s %10s %8s\n', 'Pipeline', 'nSub', 'Mean beta', 'Mean t', 'Mean R2', 'Sig Ch');
fprintf('%s\n', repmat('-', 1, 75));

for p = 1:length(pipeDirs)
    pipeName = pipeDirs(p).name;
    subFiles = dir(fullfile(resultsDir, pipeName, 'sub-*.mat'));

    % Check if this is a GLM pipeline
    loaded = load(fullfile(resultsDir, pipeName, subFiles(1).name), 'result');
    r = loaded.result;
    if ~isfield(r, 'sessions'), continue; end
    sesFields = fieldnames(r.sessions);
    if isempty(sesFields), continue; end
    firstSes = r.sessions.(sesFields{1});
    if ~isfield(firstSes, 'glm'), continue; end

    % Collect across subjects x sessions
    allBeta = [];
    allTstat = [];
    allR2 = [];
    allSigCh = [];
    nSub = length(subFiles);

    for s = 1:nSub
        loaded = load(fullfile(resultsDir, pipeName, subFiles(s).name), 'result');
        r = loaded.result;
        for si = 1:4
            if isfield(r.sessions, sessions{si})
                sesData = r.sessions.(sessions{si});
                if isfield(sesData, 'glm') && isfield(sesData.glm, 'beta')
                    glm = sesData.glm;
                    allBeta(end+1) = mean(glm.beta(1,:), 'omitnan'); %#ok<AGROW>
                    if isfield(glm, 'tstat')
                        allTstat(end+1) = mean(glm.tstat(1,:), 'omitnan'); %#ok<AGROW>
                    end
                    if isfield(glm, 'R2')
                        allR2(end+1) = mean(glm.R2, 'omitnan'); %#ok<AGROW>
                    end
                    if isfield(glm, 'pval')
                        allSigCh(end+1) = sum(glm.pval(1,:) < 0.05); %#ok<AGROW>
                    end
                end
            end
        end
    end

    if isempty(allBeta), continue; end

    fprintf('%-25s %6d %+10.4f %10.3f', pipeName, nSub, mean(allBeta), ...
        ternary(~isempty(allTstat), mean(allTstat), NaN));
    if ~isempty(allR2)
        fprintf(' %10.4f', mean(allR2));
    else
        fprintf(' %10s', '-');
    end
    if ~isempty(allSigCh)
        fprintf(' %8.1f', mean(allSigCh));
    else
        fprintf(' %8s', '-');
    end
    fprintf('\n');
end

%% 4. Laterality check: contralateral vs ipsilateral
fprintf('\n\n--- Laterality Check (Contralateral vs Ipsilateral HbO) ---\n');
fprintf('Expected: Left tapping → Right cortex activation, Right tapping → Left cortex activation\n\n');
fprintf('%-25s %10s %10s %10s %10s\n', 'Pipeline', 'L-tap mean', 'R-tap mean', 'Diff', 'Consistent');
fprintf('%s\n', repmat('-', 1, 70));

for p = 1:length(pipeDirs)
    pipeName = pipeDirs(p).name;
    subFiles = dir(fullfile(resultsDir, pipeName, 'sub-*.mat'));

    % Only blockavg pipelines for simplicity
    loaded = load(fullfile(resultsDir, pipeName, subFiles(1).name), 'result');
    r = loaded.result;
    if ~isfield(r, 'sessions'), continue; end
    sesFields = fieldnames(r.sessions);
    if isempty(sesFields), continue; end
    firstSes = r.sessions.(sesFields{1});
    if ~isfield(firstSes, 'meanHbO'), continue; end

    leftVals = [];
    rightVals = [];

    for s = 1:length(subFiles)
        loaded = load(fullfile(resultsDir, pipeName, subFiles(s).name), 'result');
        r = loaded.result;

        % Average left sessions
        for si = [1, 2]  % left2s, left3s
            if isfield(r.sessions, sessions{si})
                sesData = r.sessions.(sessions{si});
                if isfield(sesData, 'meanHbO') && ~isfield(sesData, 'error')
                    leftVals(end+1) = mean(sesData.meanHbO, 'omitnan'); %#ok<AGROW>
                end
            end
        end
        % Average right sessions
        for si = [3, 4]  % right2s, right3s
            if isfield(r.sessions, sessions{si})
                sesData = r.sessions.(sessions{si});
                if isfield(sesData, 'meanHbO') && ~isfield(sesData, 'error')
                    rightVals(end+1) = mean(sesData.meanHbO, 'omitnan'); %#ok<AGROW>
                end
            end
        end
    end

    if isempty(leftVals) || isempty(rightVals), continue; end

    mL = mean(leftVals);
    mR = mean(rightVals);
    diff = mL - mR;
    % Both should be positive (HbO increase during tapping)
    bothPos = mL > 0 && mR > 0;

    fprintf('%-25s %+10.4f %+10.4f %+10.4f %10s\n', pipeName, mL, mR, diff, ...
        ternary(bothPos, 'Yes', 'No'));
end

%% 5. Duration effect: 3s > 2s
fprintf('\n\n--- Duration Effect (3s vs 2s blocks) ---\n');
fprintf('Expected: 3s blocks produce larger HbO responses than 2s blocks\n\n');
fprintf('%-25s %10s %10s %10s %10s\n', 'Pipeline', '2s mean', '3s mean', 'Diff', '3s > 2s');
fprintf('%s\n', repmat('-', 1, 70));

for p = 1:length(pipeDirs)
    pipeName = pipeDirs(p).name;
    subFiles = dir(fullfile(resultsDir, pipeName, 'sub-*.mat'));

    loaded = load(fullfile(resultsDir, pipeName, subFiles(1).name), 'result');
    r = loaded.result;
    if ~isfield(r, 'sessions'), continue; end
    sesFields = fieldnames(r.sessions);
    if isempty(sesFields), continue; end
    firstSes = r.sessions.(sesFields{1});
    if ~isfield(firstSes, 'meanHbO'), continue; end

    vals2s = [];
    vals3s = [];

    for s = 1:length(subFiles)
        loaded = load(fullfile(resultsDir, pipeName, subFiles(s).name), 'result');
        r = loaded.result;

        for si = [1, 3]  % 2s sessions (left2s, right2s)
            if isfield(r.sessions, sessions{si})
                sesData = r.sessions.(sessions{si});
                if isfield(sesData, 'meanHbO') && ~isfield(sesData, 'error')
                    vals2s(end+1) = mean(sesData.meanHbO, 'omitnan'); %#ok<AGROW>
                end
            end
        end
        for si = [2, 4]  % 3s sessions (left3s, right3s)
            if isfield(r.sessions, sessions{si})
                sesData = r.sessions.(sessions{si});
                if isfield(sesData, 'meanHbO') && ~isfield(sesData, 'error')
                    vals3s(end+1) = mean(sesData.meanHbO, 'omitnan'); %#ok<AGROW>
                end
            end
        end
    end

    if isempty(vals2s) || isempty(vals3s), continue; end

    m2 = mean(vals2s);
    m3 = mean(vals3s);

    fprintf('%-25s %+10.4f %+10.4f %+10.4f %10s\n', pipeName, m2, m3, m3-m2, ...
        ternary(m3 > m2, 'Yes', 'No'));
end

fprintf('\n=== Inspection Complete ===\n');

%% Helper
function val = ternary(cond, trueVal, falseVal)
    if cond
        val = trueVal;
    else
        val = falseVal;
    end
end
