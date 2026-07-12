%% example_glm_connectivity.m - GLM-Based Connectivity Tutorial
%
% Demonstrates two GLM-based connectivity methods:
%   1. Beta-Series Correlation: trial-by-trial co-activation patterns
%   2. PPI (Psychophysiological Interaction): task-modulated coupling
%
% Both methods work on continuous fNIRS recordings with block/event markers.
% Results are compatible with existing plotMatrix/plotChord visualizations.
%
% Covers:
%   0. Data preparation: define ROIs, register processing methods
%   1. Single-subject beta-series correlation (LSA) + visualization
%   2. LSA vs LSS comparison
%   3. Condition-specific connectivity comparison (Easy vs Hard)
%   4. ROI-level beta-series correlation
%   5. Single-subject PPI analysis
%   6. Multi-subject analysis via GLMExperiment
%   7. Export results
%
% Requirements:
%   - processFNIRS2 on path
%   - Sample data available via pf2.import.sampleData.experiment()
%
% See also: example_glm_analysis.m, example_connectivity.m

% Uncomment to save figures instead of displaying them:
% outDir = '/tmp/glm_connectivity_examples';
% if ~exist(outDir, 'dir'), mkdir(outDir); end

%% Step 0: Generate data, define ROIs, process
%
% Same setup pattern as example_connectivity.m: generate continuous
% recordings, define ROIs, and register named processing pipelines.

fprintf('=== Step 0: Generate data, define ROIs, process ===\n');

[subjects, blockDefs] = pf2.import.sampleData.experiment('blocks');
[rawMethod, oxyMethod] = pf2.import.sampleData.addDemoPipelines();

% ROI definitions: 3 prefrontal regions
nCh = size(subjects{1}.HbO, 2);
roiSize = floor(nCh / 3);
roiDef = {1:roiSize; roiSize+1:2*roiSize; 2*roiSize+1:nCh};
roiNames = {'Left_PFC', 'Center_PFC', 'Right_PFC'};

subjects = pf2.probe.roi.defineROI(subjects, roiDef, roiNames);
subjects = processFNIRS2(subjects, rawMethod, oxyMethod);

fprintf('  %d subjects, %d blocks each\n', ...
    length(subjects), length(blockDefs{1}));
fprintf('  ROIs: %s\n', strjoin(roiNames, ', '));

% Shorthand for single-subject demos
d = subjects{1};
blk = blockDefs{1};

%% Step 1: Beta-Series Correlation (Single Subject)
%
% Beta-series correlation asks: "Do these channels co-activate across
% trials?" It fits a GLM with one regressor per trial, extracts the
% trial-level beta weights, and correlates them across channels.

fprintf('\n=== Step 1: Beta-Series Correlation (LSA) ===\n');

rLSA = exploreFNIRS.connectivity.computeBetaSeries(d, blk);
fprintf('  %d trials, %dx%d matrix, method=%s\n', ...
    rLSA.nTrials, size(rLSA.matrix, 1), size(rLSA.matrix, 2), rLSA.method);

% Matrix view
fig = exploreFNIRS.connectivity.plotMatrix(rLSA, ...
    'Title', 'Beta-Series Correlation (LSA)');
% fig = exploreFNIRS.connectivity.plotMatrix(rLSA, ...
%     'Title', 'Beta-Series Correlation (LSA)', ...
%     'Visible', 'off', ...
%     'SavePath', fullfile(outDir, 'step1_betaseries_matrix.png'));
% close(fig);

% Chord diagram (show strong connections)
fig = exploreFNIRS.connectivity.plotChord(rLSA, ...
    'MinThreshold', 0.3, ...
    'SignificanceMask', true, ...
    'Title', 'Beta-Series Chord (|r| > 0.3, p < .05)');
% fig = exploreFNIRS.connectivity.plotChord(rLSA, ...
%     'MinThreshold', 0.3, ...
%     'SignificanceMask', true, ...
%     'Title', 'Beta-Series Chord (|r| > 0.3, p < .05)', ...
%     'Visible', 'off', ...
%     'SavePath', fullfile(outDir, 'step1_betaseries_chord.png'));
% close(fig);

%% Step 2: LSA vs LSS Comparison
%
% LSA: Single GLM with N trial regressors. Fast but can be biased when
%   trials are closely spaced or collinear.
% LSS: N separate GLMs, each isolating one trial. More robust to
%   collinearity at the cost of N model fits.

fprintf('\n=== Step 2: LSA vs LSS Comparison ===\n');

rLSS = exploreFNIRS.connectivity.computeBetaSeries(d, blk, 'Method', 'LSS');

% Compare upper-triangle values
mask = triu(true(size(rLSA.matrix)), 1);
rLSA_vals = rLSA.matrix(mask);
rLSS_vals = rLSS.matrix(mask);

corrLSAvsLSS = corr(rLSA_vals, rLSS_vals);
fprintf('  LSA mean r: %.3f, LSS mean r: %.3f\n', ...
    mean(rLSA_vals, 'omitnan'), mean(rLSS_vals, 'omitnan'));
fprintf('  Correlation between LSA and LSS matrices: %.3f\n', corrLSAvsLSS);

% Also compare Pearson vs Spearman correlation on betas
rSpear = exploreFNIRS.connectivity.computeBetaSeries(d, blk, ...
    'Correlation', 'spearman');
corrPvsS = corr(rLSA.matrix(mask), rSpear.matrix(mask));
fprintf('  Pearson vs Spearman matrix correlation: %.3f\n', corrPvsS);

%% Step 3: Condition-Specific Connectivity Comparison
%
% Compute separate beta-series matrices for each condition to see how
% connectivity patterns differ across task demands.

fprintf('\n=== Step 3: Condition-Specific Connectivity ===\n');

rEasy = exploreFNIRS.connectivity.computeBetaSeries(d, blk, ...
    'Condition', 'Easy');
rHard = exploreFNIRS.connectivity.computeBetaSeries(d, blk, ...
    'Condition', 'Hard');

maskCond = triu(true(size(rEasy.matrix)), 1);
fprintf('  Easy: %d trials, mean coupling = %.3f\n', ...
    rEasy.nTrials, mean(rEasy.matrix(maskCond), 'omitnan'));
fprintf('  Hard: %d trials, mean coupling = %.3f\n', ...
    rHard.nTrials, mean(rHard.matrix(maskCond), 'omitnan'));

% Side-by-side matrices
fig = exploreFNIRS.connectivity.plotMatrix(rEasy, ...
    'Title', 'Beta-Series: Easy');
% fig = exploreFNIRS.connectivity.plotMatrix(rEasy, ...
%     'Title', 'Beta-Series: Easy', ...
%     'Visible', 'off', ...
%     'SavePath', fullfile(outDir, 'step3_betaseries_easy.png'));
% close(fig);

fig = exploreFNIRS.connectivity.plotMatrix(rHard, ...
    'Title', 'Beta-Series: Hard');
% fig = exploreFNIRS.connectivity.plotMatrix(rHard, ...
%     'Title', 'Beta-Series: Hard', ...
%     'Visible', 'off', ...
%     'SavePath', fullfile(outDir, 'step3_betaseries_hard.png'));
% close(fig);

%% Step 4: ROI-Level Beta-Series Correlation
%
% Same approach at the ROI level — produces a compact 3x3 matrix that
% summarizes prefrontal co-activation patterns across trials.

fprintf('\n=== Step 4: ROI-Level Beta-Series ===\n');

rROI = exploreFNIRS.connectivity.computeBetaSeries(d, blk, ...
    'UseROI', true);
fprintf('  ROI matrix (%dx%d):\n', size(rROI.matrix));
disp(array2table(rROI.matrix, ...
    'VariableNames', rROI.labels, 'RowNames', rROI.labels));

fig = exploreFNIRS.connectivity.plotMatrix(rROI, ...
    'ShowValues', true, ...
    'Title', 'Beta-Series: ROI-Level');
% fig = exploreFNIRS.connectivity.plotMatrix(rROI, ...
%     'ShowValues', true, ...
%     'Title', 'Beta-Series: ROI-Level', ...
%     'Visible', 'off', ...
%     'SavePath', fullfile(outDir, 'step4_betaseries_roi.png'));
% close(fig);

fig = exploreFNIRS.connectivity.plotChord(rROI, ...
    'MinThreshold', 0.0, ...
    'Title', 'Beta-Series Chord: ROI-Level');
% fig = exploreFNIRS.connectivity.plotChord(rROI, ...
%     'MinThreshold', 0.0, ...
%     'Title', 'Beta-Series Chord: ROI-Level', ...
%     'Visible', 'off', ...
%     'SavePath', fullfile(outDir, 'step4_betaseries_roi_chord.png'));
% close(fig);

%% Step 5: PPI Analysis (Single Subject)
%
% PPI asks: "Does the coupling between this seed region and other regions
% change depending on task condition?" It extends the standard GLM design
% matrix with an interaction term: seed_activity x task_context.

fprintf('\n=== Step 5: PPI Analysis ===\n');

% 5a. PPI with contrast pair (Hard > Easy), seed = Left_PFC ROI
seedCh = 1:roiSize;
rPPI = exploreFNIRS.connectivity.computePPI(d, blk, seedCh, ...
    'Contrast', {'Hard', 'Easy'});
fprintf('  Seed: channels [%d-%d] (Left_PFC)\n', seedCh(1), seedCh(end));
fprintf('  PPI beta range: [%.4f, %.4f]\n', ...
    min(rPPI.ppi_beta), max(rPPI.ppi_beta));
fprintf('  Significant targets (p<0.05): %d/%d\n', ...
    sum(rPPI.ppi_pval < 0.05), length(rPPI.ppi_pval));
fprintf('  Regressors: %s\n', strjoin(rPPI.regressorNames, ', '));

% 5b. Single condition vs baseline
rPPI_hard = exploreFNIRS.connectivity.computePPI(d, blk, seedCh, ...
    'Contrast', 'Hard');
fprintf('  Hard vs baseline: beta range [%.4f, %.4f]\n', ...
    min(rPPI_hard.ppi_beta), max(rPPI_hard.ppi_beta));

% 5c. With Wiener deconvolution of seed signal
rPPI_deconv = exploreFNIRS.connectivity.computePPI(d, blk, seedCh, ...
    'Contrast', {'Hard', 'Easy'}, 'Deconvolve', true);
fprintf('  Deconvolved PPI beta range: [%.4f, %.4f]\n', ...
    min(rPPI_deconv.ppi_beta), max(rPPI_deconv.ppi_beta));

% PPI bar chart with significance markers
fig = figure();
bar(rPPI.ppi_beta);
xlabel('Target Channel');
ylabel('PPI Beta Weight');
title('PPI: Hard > Easy (seed = Left PFC)');
hold on;
sigIdx = find(rPPI.ppi_pval < 0.05);
if ~isempty(sigIdx)
    plot(sigIdx, rPPI.ppi_beta(sigIdx), 'r*', 'MarkerSize', 10);
    legend('PPI \beta', 'p < .05', 'Location', 'best');
end
hold off;
% saveas(fig, fullfile(outDir, 'step5_ppi_bar.png'));
% close(fig);

%% Step 6: Multi-Subject Analysis via GLMExperiment
%
% GLMExperiment provides betaSeriesConnectivity() and ppi() methods that
% loop over subjects and aggregate. Set rawMethod/oxyMethod to apply
% the same processing pipeline before computing connectivity.

fprintf('\n=== Step 6: Multi-Subject Analysis ===\n');

gx = exploreFNIRS.core.GLMExperiment(subjects, blockDefs);
gx.settings.rawMethod = rawMethod;
gx.settings.oxyMethod = oxyMethod;

% 6a. Group beta-series connectivity (excluding Rest)
fprintf('  Computing group beta-series...\n');
groupBS = gx.betaSeriesConnectivity('Condition', {'Easy', 'Hard'});
fprintf('  N=%d subjects, %dx%d matrix\n', ...
    groupBS.N, size(groupBS.Mean, 1), size(groupBS.Mean, 2));

offDiag = groupBS.Mean(~eye(size(groupBS.Mean), 'logical'));
fprintf('  Mean off-diagonal r: %.3f (SD=%.3f)\n', ...
    mean(offDiag, 'omitnan'), std(offDiag, 'omitnan'));

fig = exploreFNIRS.connectivity.plotMatrix(groupBS, ...
    'Title', 'Group Beta-Series Correlation (N=4)');
% fig = exploreFNIRS.connectivity.plotMatrix(groupBS, ...
%     'Title', 'Group Beta-Series Correlation (N=4)', ...
%     'Visible', 'off', ...
%     'SavePath', fullfile(outDir, 'step6a_group_betaseries.png'));
% close(fig);

% 6b. Group beta-series at ROI level
fprintf('  Computing group ROI beta-series...\n');
groupROI = gx.betaSeriesConnectivity('Condition', {'Easy', 'Hard'}, ...
    'UseROI', true);
fprintf('  ROI group matrix:\n');
disp(array2table(groupROI.Mean, ...
    'VariableNames', groupROI.labels, 'RowNames', groupROI.labels));

fig = exploreFNIRS.connectivity.plotMatrix(groupROI, ...
    'ShowValues', true, ...
    'Title', 'Group ROI Beta-Series (N=4)');
% fig = exploreFNIRS.connectivity.plotMatrix(groupROI, ...
%     'ShowValues', true, ...
%     'Title', 'Group ROI Beta-Series (N=4)', ...
%     'Visible', 'off', ...
%     'SavePath', fullfile(outDir, 'step6b_group_roi_betaseries.png'));
% close(fig);

% 6c. Group PPI
fprintf('  Computing group PPI...\n');
groupPPI = gx.ppi(seedCh, 'Contrast', {'Hard', 'Easy'});
fprintf('  Mean PPI beta range: [%.4f, %.4f]\n', ...
    min(groupPPI.Mean_beta), max(groupPPI.Mean_beta));
fprintf('  Group-significant targets (p<0.05): %d/%d\n', ...
    sum(groupPPI.pmatrix < 0.05), length(groupPPI.pmatrix));

fig = figure();
bar(groupPPI.Mean_beta);
hold on;
errorbar(1:length(groupPPI.Mean_beta), groupPPI.Mean_beta, ...
    groupPPI.SEM_beta, '.k');
sigGrp = find(groupPPI.pmatrix < 0.05);
if ~isempty(sigGrp)
    plot(sigGrp, groupPPI.Mean_beta(sigGrp), 'r*', 'MarkerSize', 10);
end
hold off;
xlabel('Target Channel');
ylabel('PPI Beta (Mean +/- SEM)');
title(sprintf('Group PPI: Hard > Easy (N=%d)', groupPPI.N));
% saveas(fig, fullfile(outDir, 'step6c_group_ppi.png'));
% close(fig);

%% Step 7: Export Results
%
% Export beta-series and PPI results to CSV for further analysis in R/Python.

fprintf('\n=== Step 7: Export ===\n');

% 7a. Beta-series matrices to CSV (upper triangle, long format)
nChBS = size(rLSA.matrix, 1);
rows = {};
for i = 1:nChBS
    for j = (i+1):nChBS
        rows{end+1} = struct( ...
            'Ch_i', rLSA.channels(i), ...
            'Ch_j', rLSA.channels(j), ...
            'r_LSA', rLSA.matrix(i,j), ...
            'p_LSA', rLSA.pmatrix(i,j), ...
            'r_LSS', rLSS.matrix(i,j), ...
            'p_LSS', rLSS.pmatrix(i,j)); %#ok<SAGROW>
    end
end
T_bs = struct2table([rows{:}]);
fprintf('  Beta-series edges: %d rows\n', height(T_bs));
% writetable(T_bs, fullfile(outDir, 'step7a_betaseries_edges.csv'));

% 7b. PPI betas per subject to CSV
T_ppi = table( ...
    groupPPI.Mean_beta', groupPPI.SD_beta', ...
    groupPPI.SEM_beta', groupPPI.pmatrix', ...
    'VariableNames', {'Mean_beta', 'SD_beta', 'SEM_beta', 'pvalue'});
T_ppi.Channel = groupPPI.channels(:);
T_ppi = movevars(T_ppi, 'Channel', 'Before', 1);
fprintf('  PPI group results: %d rows\n', height(T_ppi));
% writetable(T_ppi, fullfile(outDir, 'step7b_ppi_group.csv'));

%% Summary

fprintf('\n=== GLM Connectivity tutorial complete ===\n');
