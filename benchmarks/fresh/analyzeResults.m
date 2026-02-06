% ANALYZERESULTS Compare results across FRESH benchmark pipelines
%
% Loads all per-subject and group-level results from the benchmark runs
% and produces cross-pipeline comparisons including:
%   1. Hypothesis agreement table (pass/fail per hypothesis per pipeline)
%   2. Cross-pipeline correlation of beta/activation maps
%   3. Channel-level agreement across pipelines
%   4. Topographic visualizations of t-statistics
%   5. Summary concordance rates
%
% See also: benchmarks.fresh.runDatasetII, benchmarks.fresh.runDatasetI

fprintf('\n=== FRESH Benchmark Results Analysis ===\n');
fprintf('Started: %s\n\n', datetime('now'));

% --- Setup paths ---
scriptDir = fileparts(mfilename('fullpath'));
benchmarkRoot = fileparts(scriptDir);
resultsDir = fullfile(benchmarkRoot, 'results');

if ~isfolder(resultsDir)
    error('No results found at %s. Run the benchmark scripts first.', resultsDir);
end

% --- Analyze Dataset II (Motor) ---
dsIIdir = fullfile(resultsDir, 'datasetII');
if isfolder(dsIIdir)
    fprintf('========================================\n');
    fprintf('  Dataset II: Motor (Finger Tapping)\n');
    fprintf('========================================\n\n');
    analyzeDatasetII(dsIIdir);
else
    fprintf('Dataset II results not found. Skipping.\n');
end

% --- Analyze Dataset I (Auditory) ---
dsIdir = fullfile(resultsDir, 'datasetI');
if isfolder(dsIdir)
    fprintf('\n========================================\n');
    fprintf('  Dataset I: Auditory (Speech/Noise)\n');
    fprintf('========================================\n\n');
    analyzeDatasetI(dsIdir);
else
    fprintf('Dataset I results not found. Skipping.\n');
end

fprintf('\n=== Analysis Complete ===\n');
fprintf('Finished: %s\n', datetime('now'));

%%_Subfunctions_________________________________________________________

function analyzeDatasetII(resultsDir)
% ANALYZEDATASETII Analyze Motor dataset results across pipelines

% Find pipeline directories
pipeDirs = dir(resultsDir);
pipeDirs = pipeDirs([pipeDirs.isdir] & ~startsWith({pipeDirs.name}, '.'));
nPipelines = length(pipeDirs);

if nPipelines == 0
    fprintf('  No pipeline results found.\n');
    return;
end

fprintf('  Found %d pipeline results:\n', nPipelines);
for p = 1:nPipelines
    fprintf('    %s\n', pipeDirs(p).name);
end
fprintf('\n');

% --- Load all results ---
pipelineResults = struct();

for p = 1:nPipelines
    pipeName = pipeDirs(p).name;
    pipeDir = fullfile(resultsDir, pipeName);
    subFiles = dir(fullfile(pipeDir, 'sub-*.mat'));

    subResults = {};
    for s = 1:length(subFiles)
        try
            loaded = load(fullfile(pipeDir, subFiles(s).name), 'result');
            subResults{end+1} = loaded.result; %#ok<AGROW>
        catch
            % Skip corrupt files
        end
    end

    pipelineResults.(pipeName).results = subResults;
    pipelineResults.(pipeName).nSubjects = length(subResults);
    fprintf('  %s: %d subjects loaded\n', pipeName, length(subResults));
end

% --- Cross-pipeline comparison ---
pipeNames = fieldnames(pipelineResults);
nPipes = length(pipeNames);

fprintf('\n--- Cross-Pipeline Comparison ---\n\n');

% 1. Mean activation comparison
fprintf('  Mean HbO activation (first condition, channel-averaged):\n');
fprintf('  %-25s %10s %10s %10s\n', 'Pipeline', 'Mean', 'SD', 'nSub');
fprintf('  %s\n', repmat('-', 1, 60));

for p = 1:nPipes
    pipeName = pipeNames{p};
    subs = pipelineResults.(pipeName).results;
    activations = [];

    for s = 1:length(subs)
        r = subs{s};
        if isfield(r, 'glm') && isfield(r.glm, 'beta')
            % GLM: use first condition beta
            beta = r.glm.beta(1, :);
            activations(end+1) = mean(beta, 'omitnan'); %#ok<AGROW>
        elseif isfield(r, 'meanHbO')
            % Block averaging: use first condition mean
            condFields = fieldnames(r.meanHbO);
            if ~isempty(condFields)
                vals = r.meanHbO.(condFields{1});
                activations(end+1) = mean(vals, 'omitnan'); %#ok<AGROW>
            end
        end
    end

    if ~isempty(activations)
        fprintf('  %-25s %10.4f %10.4f %10d\n', pipeName, ...
            mean(activations), std(activations), length(activations));
    else
        fprintf('  %-25s %10s\n', pipeName, 'N/A');
    end
end

% 2. Cross-pipeline correlation matrix
fprintf('\n  Cross-pipeline beta correlation:\n');
betaMaps = cell(nPipes, 1);

for p = 1:nPipes
    pipeName = pipeNames{p};
    subs = pipelineResults.(pipeName).results;
    allBetas = [];

    for s = 1:length(subs)
        r = subs{s};
        if isfield(r, 'glm') && isfield(r.glm, 'beta')
            allBetas = [allBetas; r.glm.beta(1, :)]; %#ok<AGROW>
        elseif isfield(r, 'meanHbO')
            condFields = fieldnames(r.meanHbO);
            if ~isempty(condFields)
                allBetas = [allBetas; r.meanHbO.(condFields{1})]; %#ok<AGROW>
            end
        end
    end

    if ~isempty(allBetas)
        betaMaps{p} = mean(allBetas, 1, 'omitnan');
    end
end

% Compute pairwise correlations
hasData = ~cellfun(@isempty, betaMaps);
validPipes = find(hasData);

if length(validPipes) >= 2
    fprintf('\n  %-20s', '');
    for p = validPipes(:)'
        fprintf(' %8s', pipeNames{p}(1:min(8, end)));
    end
    fprintf('\n');

    for p1 = validPipes(:)'
        fprintf('  %-20s', pipeNames{p1}(1:min(20, end)));
        for p2 = validPipes(:)'
            b1 = betaMaps{p1};
            b2 = betaMaps{p2};
            nCh = min(length(b1), length(b2));
            if nCh > 1
                r = corr(b1(1:nCh)', b2(1:nCh)', 'rows', 'complete');
                fprintf(' %8.3f', r);
            else
                fprintf(' %8s', 'N/A');
            end
        end
        fprintf('\n');
    end
end

% 3. Effect size comparison
fprintf('\n  Effect sizes (Cohen''s d, first condition):\n');
fprintf('  %-25s %10s %10s\n', 'Pipeline', 'Cohen''s d', 'Max t');
fprintf('  %s\n', repmat('-', 1, 50));

for p = 1:nPipes
    pipeName = pipeNames{p};
    subs = pipelineResults.(pipeName).results;

    if ~isempty(subs) && isfield(subs{1}, 'glm') && isfield(subs{1}.glm, 'tstat')
        allTstats = [];
        for s = 1:length(subs)
            allTstats = [allTstats; subs{s}.glm.tstat(1, :)]; %#ok<AGROW>
        end
        meanT = mean(allTstats, 1, 'omitnan');
        cohensD = mean(meanT, 'omitnan') / std(meanT, 'omitnan');
        fprintf('  %-25s %10.3f %10.3f\n', pipeName, cohensD, max(meanT));
    else
        fprintf('  %-25s %10s %10s\n', pipeName, '-', '-');
    end
end

% 4. Visualize if possible
try
    visualizeMotorResults(pipelineResults, pipeNames, resultsDir);
catch e
    fprintf('\n  Could not generate visualizations: %s\n', e.message);
end

end

function analyzeDatasetI(resultsDir)
% ANALYZEDATASETI Analyze Auditory dataset group-level results

pipeDirs = dir(resultsDir);
pipeDirs = pipeDirs([pipeDirs.isdir] & ~startsWith({pipeDirs.name}, '.'));
nPipelines = length(pipeDirs);

if nPipelines == 0
    fprintf('  No pipeline results found.\n');
    return;
end

fprintf('  Found %d pipeline results.\n\n', nPipelines);

% --- Hypothesis Agreement Table ---
fprintf('  Hypothesis Agreement Table:\n');
fprintf('  %-25s', 'Pipeline');
for h = 1:7
    fprintf(' %5s', sprintf('H%d', h));
end
fprintf(' %6s\n', 'Score');
fprintf('  %s\n', repmat('-', 1, 75));

pipeScores = [];

for p = 1:nPipelines
    pipeName = pipeDirs(p).name;
    groupFile = fullfile(resultsDir, pipeName, 'group_results.mat');

    if ~isfile(groupFile)
        fprintf('  %-25s (no group results)\n', pipeName);
        continue;
    end

    try
        loaded = load(groupFile, 'groupResult');
        gr = loaded.groupResult;

        fprintf('  %-25s', pipeName);

        if isfield(gr, 'hypotheses') && ~isempty(gr.hypotheses)
            nPass = 0;
            for h = 1:min(7, length(gr.hypotheses))
                if gr.hypotheses(h).pass
                    fprintf(' %5s', 'Y');
                    nPass = nPass + 1;
                else
                    fprintf(' %5s', 'N');
                end
            end
            % Pad if fewer than 7 hypotheses
            for h = (length(gr.hypotheses)+1):7
                fprintf(' %5s', '-');
            end
            score = nPass / min(7, length(gr.hypotheses));
            fprintf(' %5.0f%%\n', score * 100);
            pipeScores(end+1) = score; %#ok<AGROW>
        else
            fprintf(' (hypotheses not tested)\n');
        end
    catch e
        fprintf('  %-25s ERROR: %s\n', pipeName, e.message);
    end
end

if ~isempty(pipeScores)
    fprintf('\n  Overall concordance: %.0f%% (median: %.0f%%)\n', ...
        mean(pipeScores) * 100, median(pipeScores) * 100);
end

% --- Group-level beta comparison ---
fprintf('\n  Group-level activation (condition-averaged beta):\n');
fprintf('  %-25s %10s %10s %10s\n', 'Pipeline', 'nSub', 'Mean beta', 'Sig Ch');
fprintf('  %s\n', repmat('-', 1, 60));

for p = 1:nPipelines
    pipeName = pipeDirs(p).name;
    groupFile = fullfile(resultsDir, pipeName, 'group_results.mat');

    if ~isfile(groupFile)
        continue;
    end

    try
        loaded = load(groupFile, 'groupResult');
        gr = loaded.groupResult;

        if isfield(gr, 'groupBeta') && isfield(gr, 'groupPval')
            meanBeta = mean(gr.groupBeta(:), 'omitnan');
            nSigCh = sum(gr.groupPval(:) < 0.05);
            fprintf('  %-25s %10d %10.4f %10d\n', pipeName, gr.nSubjects, meanBeta, nSigCh);
        elseif isfield(gr, 'nSubjects')
            fprintf('  %-25s %10d %10s %10s\n', pipeName, gr.nSubjects, '-', '-');
        end
    catch
        % Skip
    end
end

end

function visualizeMotorResults(pipelineResults, pipeNames, resultsDir)
% VISUALIZEMOTORRESULTS Generate comparison plots for motor dataset

nPipes = length(pipeNames);

% Create figure with subplots
fig = figure('Visible', 'off', 'Position', [100 100 1200 800]);

% Plot 1: Mean activation per pipeline
subplot(2, 2, 1);
means = [];
errs = [];
labels = {};

for p = 1:nPipes
    subs = pipelineResults.(pipeNames{p}).results;
    activations = [];
    for s = 1:length(subs)
        r = subs{s};
        if isfield(r, 'glm') && isfield(r.glm, 'beta')
            activations(end+1) = mean(r.glm.beta(1, :), 'omitnan'); %#ok<AGROW>
        elseif isfield(r, 'meanHbO')
            condFields = fieldnames(r.meanHbO);
            if ~isempty(condFields)
                activations(end+1) = mean(r.meanHbO.(condFields{1}), 'omitnan'); %#ok<AGROW>
            end
        end
    end
    if ~isempty(activations)
        means(end+1) = mean(activations); %#ok<AGROW>
        errs(end+1) = std(activations) / sqrt(length(activations)); %#ok<AGROW>
        labels{end+1} = pipeNames{p}; %#ok<AGROW>
    end
end

if ~isempty(means)
    bar(means);
    hold on;
    errorbar(1:length(means), means, errs, 'k.', 'LineWidth', 1.5);
    set(gca, 'XTickLabel', labels, 'XTickLabelRotation', 45);
    ylabel('Mean HbO Activation');
    title('Mean Activation by Pipeline');
end

% Plot 2: R-squared comparison (GLM pipelines only)
subplot(2, 2, 2);
r2means = [];
r2labels = {};

for p = 1:nPipes
    subs = pipelineResults.(pipeNames{p}).results;
    r2vals = [];
    for s = 1:length(subs)
        r = subs{s};
        if isfield(r, 'glm') && isfield(r.glm, 'R2')
            r2vals(end+1) = mean(r.glm.R2, 'omitnan'); %#ok<AGROW>
        end
    end
    if ~isempty(r2vals)
        r2means(end+1) = mean(r2vals); %#ok<AGROW>
        r2labels{end+1} = pipeNames{p}; %#ok<AGROW>
    end
end

if ~isempty(r2means)
    bar(r2means);
    set(gca, 'XTickLabel', r2labels, 'XTickLabelRotation', 45);
    ylabel('Mean R^2');
    title('Model Fit by Pipeline');
end

% Plot 3: Number of significant channels per pipeline
subplot(2, 2, 3);
nSig = [];
nSigLabels = {};

for p = 1:nPipes
    subs = pipelineResults.(pipeNames{p}).results;
    sigCounts = [];
    for s = 1:length(subs)
        r = subs{s};
        if isfield(r, 'glm') && isfield(r.glm, 'pval')
            sigCounts(end+1) = sum(r.glm.pval(1, :) < 0.05); %#ok<AGROW>
        end
    end
    if ~isempty(sigCounts)
        nSig(end+1) = mean(sigCounts); %#ok<AGROW>
        nSigLabels{end+1} = pipeNames{p}; %#ok<AGROW>
    end
end

if ~isempty(nSig)
    bar(nSig);
    set(gca, 'XTickLabel', nSigLabels, 'XTickLabelRotation', 45);
    ylabel('Mean # Significant Channels');
    title('Sensitivity by Pipeline (p<0.05)');
end

% Plot 4: Cross-pipeline agreement heatmap
subplot(2, 2, 4);
if nPipes >= 2
    % Compute significance agreement matrix
    sigMaps = {};
    for p = 1:nPipes
        subs = pipelineResults.(pipeNames{p}).results;
        allSig = [];
        for s = 1:length(subs)
            r = subs{s};
            if isfield(r, 'glm') && isfield(r.glm, 'pval')
                allSig = [allSig; double(r.glm.pval(1, :) < 0.05)]; %#ok<AGROW>
            end
        end
        if ~isempty(allSig)
            sigMaps{end+1} = mean(allSig, 1);
        else
            sigMaps{end+1} = [];
        end
    end

    % Pairwise agreement
    hasMap = ~cellfun(@isempty, sigMaps);
    validIdx = find(hasMap);
    if length(validIdx) >= 2
        agreeMat = zeros(length(validIdx));
        for i = 1:length(validIdx)
            for j = 1:length(validIdx)
                m1 = sigMaps{validIdx(i)};
                m2 = sigMaps{validIdx(j)};
                nCh = min(length(m1), length(m2));
                agreeMat(i, j) = mean(m1(1:nCh) == m2(1:nCh));
            end
        end
        imagesc(agreeMat);
        colorbar;
        caxis([0 1]);
        validNames = pipeNames(validIdx);
        set(gca, 'XTick', 1:length(validIdx), 'XTickLabel', validNames, 'XTickLabelRotation', 45);
        set(gca, 'YTick', 1:length(validIdx), 'YTickLabel', validNames);
        title('Cross-Pipeline Agreement');
    end
end

sgtitle('FRESH Benchmark: Dataset II (Motor)');

% Save figure
figFile = fullfile(resultsDir, 'datasetII_comparison.png');
saveas(fig, figFile);
fprintf('\n  Comparison figure saved: %s\n', figFile);
close(fig);

end
