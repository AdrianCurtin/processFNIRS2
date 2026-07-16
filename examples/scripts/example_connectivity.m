%% example_connectivity.m - Functional connectivity analysis
%
% Demonstrates within-subject functional connectivity using the
% exploreFNIRS connectivity module. All analysis uses ROIs, which are
% defined before processing so that processStageFilterHb auto-builds
% ROI signals during reprocessing (no manual pf2_build_nanmean_ROI call).
%
% Covers:
%   1. Data preparation: define ROIs, process with named methods
%   2. Group-level inter-ROI connectivity (condition comparison)
%   3. Within-ROI (intra-ROI) coupling
%   4. Block-wise connectivity comparison (Easy vs Hard vs Rest)
%   5. Single-subject connectivity matrix + chord diagram
%   6. Directed connectivity (Granger causality)
%   7. Dynamic functional connectivity + state detection
%   8. Export summary table
%
% Requirements:
%   - processFNIRS2 on path
%   - Sample data available via pf2.import.sampleData.fNIR2000()

% Uncomment to save figures instead of displaying them:
% outDir = '/tmp/connectivity_examples';
% if ~exist(outDir, 'dir'), mkdir(outDir); end

%% Step 0: Generate data, define ROIs, process

fprintf('=== Step 0: Generate data, define ROIs, process ===\n');

[subjects, blockDefs] = pf2.import.sampleData.experiment('blocks');
[rawMethod, oxyMethod] = pf2_base.examples.addDemoPipelines();

% ROI definitions: 3 prefrontal regions
nCh = size(subjects{1}.HbO, 2);
roiSize = floor(nCh / 3);
roiDef = {1:roiSize; roiSize+1:2*roiSize; 2*roiSize+1:nCh};
roiNames = {'Left_PFC', 'Center_PFC', 'Right_PFC'};

subjects = pf2.probe.roi.defineROI(subjects, roiDef, roiNames);
subjects = processFNIRS2(subjects, rawMethod, oxyMethod);

fprintf('  ROI fields on subject 1: ');
if isfield(subjects{1}.ROI, 'HbO')
    fprintf('HbO [%d x %d]\n', size(subjects{1}.ROI.HbO));
else
    fprintf('(missing - check processing)\n');
end

%% Step 1: Inter-ROI connectivity by group (Young vs Older)

fprintf('\n=== Step 1: Inter-ROI connectivity by group ===\n');

ex = exploreFNIRS.core.Experiment(subjects);
ex.groupby({'Group'});

interResult = ex.interROI('Method', 'pearson', 'Biomarker', 'HbO');

for g = 1:length(interResult)
    fprintf('  %s (N=%d): mean ROI coupling = %.3f\n', ...
        interResult(g).label, interResult(g).N, interResult(g).globalMean);
end

% Chord diagram per group
for g = 1:length(interResult)
    fig = exploreFNIRS.connectivity.plotInterROI(interResult(g), ...
        'PlotType', 'chord', ...
        'Title', sprintf('Inter-ROI: %s', interResult(g).label));
    % fig = exploreFNIRS.connectivity.plotInterROI(interResult(g), ...
    %     'PlotType', 'chord', ...
    %     'Title', sprintf('Inter-ROI: %s', interResult(g).label), ...
    %     'Visible', 'off', ...
    %     'SavePath', fullfile(outDir, sprintf('step1_interROI_chord_%s.png', interResult(g).label)));
    % close(fig);
end

% Matrix view of first group
fig = exploreFNIRS.connectivity.plotInterROI(interResult(1), ...
    'PlotType', 'matrix', ...
    'Title', sprintf('Inter-ROI Matrix: %s', interResult(1).label));
% fig = exploreFNIRS.connectivity.plotInterROI(interResult(1), ...
%     'PlotType', 'matrix', ...
%     'Title', sprintf('Inter-ROI Matrix: %s', interResult(1).label), ...
%     'Visible', 'off', ...
%     'SavePath', fullfile(outDir, 'step1_interROI_matrix.png'));
% close(fig);

%% Step 2: Intra-ROI connectivity

fprintf('\n=== Step 2: Intra-ROI connectivity ===\n');

intraResult = ex.intraROI('Method', 'pearson', 'Biomarker', 'HbO');

for g = 1:length(intraResult)
    fprintf('  %s:\n', intraResult(g).label);
    for r = 1:length(intraResult(g).roiMetrics)
        rm = intraResult(g).roiMetrics(r);
        fprintf('    %s: mean coupling = %.3f (SEM=%.3f)\n', ...
            rm.roiName, rm.groupMean, rm.groupSEM);
    end
end

fig = exploreFNIRS.connectivity.plotIntraROI(intraResult(1), ...
    'SortBy', 'coupling', ...
    'Title', sprintf('Intra-ROI Coupling: %s', intraResult(1).label));
% fig = exploreFNIRS.connectivity.plotIntraROI(intraResult(1), ...
%     'SortBy', 'coupling', ...
%     'Title', sprintf('Intra-ROI Coupling: %s', intraResult(1).label), ...
%     'Visible', 'off', ...
%     'SavePath', fullfile(outDir, 'step2_intraROI_bar.png'));
% close(fig);

%% Step 3: Block-wise connectivity comparison

fprintf('\n=== Step 3: Block-wise connectivity ===\n');

blocks = blockDefs{1};

blockConn = ex.connectivity('Blocks', blocks, 'UseROI', true, ...
    'Method', 'pearson', 'Biomarker', 'HbO');

for b = 1:length(blockConn)
    fprintf('  Block %d (%s): mean connectivity = %.3f\n', ...
        b, blockConn(b).blockInfo.Condition, blockConn(b).groups(1).globalMean);
end

fig = exploreFNIRS.connectivity.plotBlockComparison(blockConn, ...
    'GroupIndex', 1, ...
    'Metric', 'mean', ...
    'Title', 'ROI Connectivity Across Blocks');
% fig = exploreFNIRS.connectivity.plotBlockComparison(blockConn, ...
%     'GroupIndex', 1, ...
%     'Metric', 'mean', ...
%     'Title', 'ROI Connectivity Across Blocks', ...
%     'Visible', 'off', ...
%     'SavePath', fullfile(outDir, 'step3_block_comparison.png'));
% close(fig);

%% Step 4: Channel-level connectivity + chord diagram (single subject)

fprintf('\n=== Step 4: Channel-level connectivity (single subject) ===\n');

singleConn = exploreFNIRS.connectivity.computeMatrix(subjects{1}, ...
    'Method', 'pearson', 'Biomarker', 'HbO');
mask = triu(true(size(singleConn.matrix)), 1);
fprintf('  Matrix size: %d x %d\n', size(singleConn.matrix));
fprintf('  Mean coupling: %.3f\n', mean(singleConn.matrix(mask), 'omitnan'));

fig = exploreFNIRS.connectivity.plotMatrix(singleConn, ...
    'ShowValues', false, ...
    'Title', 'Channel Connectivity: Sub01');
% fig = exploreFNIRS.connectivity.plotMatrix(singleConn, ...
%     'ShowValues', false, ...
%     'Title', 'Channel Connectivity: Sub01', ...
%     'Visible', 'off', ...
%     'SavePath', fullfile(outDir, 'step4_channel_matrix.png'));
% close(fig);

fig = exploreFNIRS.connectivity.plotChord(singleConn, ...
    'MinThreshold', 0.3, ...
    'SignificanceMask', true, ...
    'Title', 'Channel Chord: Sub01 (|r| > 0.3, p < .05)');
% fig = exploreFNIRS.connectivity.plotChord(singleConn, ...
%     'MinThreshold', 0.3, ...
%     'SignificanceMask', true, ...
%     'Title', 'Channel Chord: Sub01 (|r| > 0.3, p < .05)', ...
%     'Visible', 'off', ...
%     'SavePath', fullfile(outDir, 'step4_channel_chord.png'));
% close(fig);

%% Step 5: Directed connectivity (Granger causality)

fprintf('\n=== Step 5: Directed connectivity (Granger) ===\n');

grangerConn = exploreFNIRS.connectivity.computeMatrix(subjects{1}, ...
    'Method', 'granger', 'Biomarker', 'HbO', 'UseROI', true);

fprintf('  ROI-level Granger matrix:\n');
for r = 1:length(grangerConn.labels)
    fprintf('    %s -> others: mean F = %.3f\n', ...
        grangerConn.labels{r}, mean(grangerConn.matrix(r, :), 'omitnan'));
end

fig = exploreFNIRS.connectivity.plotDirected(grangerConn, ...
    'Layout', 'circular', ...
    'SignificanceMask', true, ...
    'Title', 'Granger Causality (ROI-level)');
% fig = exploreFNIRS.connectivity.plotDirected(grangerConn, ...
%     'Layout', 'circular', ...
%     'SignificanceMask', true, ...
%     'Title', 'Granger Causality (ROI-level)', ...
%     'Visible', 'off', ...
%     'SavePath', fullfile(outDir, 'step5_granger_circular.png'));
% close(fig);

fig = exploreFNIRS.connectivity.plotDirected(grangerConn, ...
    'Layout', 'matrix', ...
    'Title', 'Granger Causality Matrix');
% fig = exploreFNIRS.connectivity.plotDirected(grangerConn, ...
%     'Layout', 'matrix', ...
%     'Title', 'Granger Causality Matrix', ...
%     'Visible', 'off', ...
%     'SavePath', fullfile(outDir, 'step5_granger_matrix.png'));
% close(fig);

%% Step 6: Dynamic functional connectivity + state detection

fprintf('\n=== Step 6: Dynamic FC + state detection ===\n');

dynFC = exploreFNIRS.connectivity.computeDynamicFC(subjects{1}, ...
    'Method', 'pearson', 'Biomarker', 'HbO', ...
    'WindowSize', 30, 'WindowStep', 10, ...
    'Channels', 1:min(nCh, 10));
fprintf('  Windows: %d (%.0fs each, %.0fs step)\n', ...
    length(dynFC.windowTimes), dynFC.windowSize, dynFC.windowStep);

states = exploreFNIRS.connectivity.detectStates(dynFC, 'K', 3);
fprintf('  States found: %d\n', states.K);
for k = 1:states.K
    fprintf('  S%d occupancy: %.0f%%\n', k, 100 * mean(states.assignments == k));
end

fig = exploreFNIRS.connectivity.plotDynamicFC(dynFC, ...
    'States', states, ...
    'Title', 'Dynamic FC: Sub01');
% fig = exploreFNIRS.connectivity.plotDynamicFC(dynFC, ...
%     'States', states, ...
%     'Title', 'Dynamic FC: Sub01', ...
%     'Visible', 'off', ...
%     'SavePath', fullfile(outDir, 'step6_dynamic_fc.png'));
% close(fig);

%% Step 7: Export connectivity summary

fprintf('\n=== Step 7: Export ===\n');

T = exploreFNIRS.report.connectivitySummary(interResult, 'Metric', 'global');
fprintf('  Inter-ROI summary:\n');
disp(T);
% writetable(T, fullfile(outDir, 'step7_connectivity_summary.csv'));

%% Summary
fprintf('\n=== Connectivity tutorial complete ===\n');
