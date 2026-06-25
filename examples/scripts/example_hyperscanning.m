%% example_hyperscanning.m - Inter-brain synchrony analysis
%
% Demonstrates hyperscanning (inter-brain coupling) analysis for paired
% participants. Uses ROIs defined before processing so that
% processStageFilterHb auto-builds ROI signals during reprocessing.
%
% Covers:
%   1. Data preparation: assign dyad metadata, define ROIs, process
%   2. ROI-level inter-brain coupling
%   3. Permutation testing for significance
%   4. Block-wise hyperscanning (coupling per task condition)
%   5. Dyad-level visualization (heatmap + inter-brain topo)
%   6. Channel-level hyperscanning (full cross-brain matrix)
%   7. Within-subject connectivity for comparison
%   8. Multiple coupling methods
%   9. Connectogram of a condition contrast (node-colored Delta-r)
%
% Requirements:
%   - processFNIRS2 on path
%   - Sample data available via pf2.import.sampleData.fNIR2000()

% Uncomment to save figures instead of displaying them:
% outDir = '/tmp/hyperscanning_examples';
% if ~exist(outDir, 'dir'), mkdir(outDir); end

%% Step 0: Generate paired data, define ROIs, process

fprintf('=== Step 0: Generate paired data, define ROIs, process ===\n');

[subjects, blockDefs] = pf2.import.sampleData.experiment('blocks');
[rawMethod, oxyMethod] = pf2.import.sampleData.addDemoPipelines();

% Assign dyad metadata
dyadIDs = {'D1', 'D1', 'D2', 'D2'};
roles   = {'Speaker', 'Listener', 'Speaker', 'Listener'};
for s = 1:length(subjects)
    subjects{s}.info.DyadID = dyadIDs{s};
    subjects{s}.info.Role   = roles{s};
end

% ROI definitions
nCh = size(subjects{1}.HbO, 2);
roiSize = floor(nCh / 3);
roiDef = {1:roiSize; roiSize+1:2*roiSize; 2*roiSize+1:nCh};
roiNames = {'Left_PFC', 'Center_PFC', 'Right_PFC'};

subjects = pf2.probe.roi.defineROI(subjects, roiDef, roiNames);
subjects = processFNIRS2(subjects, rawMethod, oxyMethod);

fprintf('  %d subjects in %d dyads\n', length(subjects), length(unique(dyadIDs)));
fprintf('  ROI channels: %s\n', strjoin(roiNames, ', '));

%% Step 1: ROI-level inter-brain coupling

fprintf('\n=== Step 1: ROI-level inter-brain coupling ===\n');

ex = exploreFNIRS.core.Experiment(subjects);

result = ex.hyperscanning( ...
    'Method', 'pearson', ...
    'Biomarker', 'HbO', ...
    'UseROI', true, ...
    'ChannelPairing', 'same');

fprintf('  Mean inter-brain coupling per ROI:\n');
for r = 1:length(result.channels)
    fprintf('    ROI %d: r = %.3f (p = %.4f)\n', ...
        r, result.Mean(r), result.pvalue(r));
end

fig = exploreFNIRS.hyperscanning.plotGroup(result, ...
    'ShowSignificance', true, ...
    'ChannelLabels', roiNames, ...
    'Title', 'Inter-Brain Coupling (ROI-level, Pearson)');
% fig = exploreFNIRS.hyperscanning.plotGroup(result, ...
%     'ShowSignificance', true, ...
%     'ChannelLabels', roiNames, ...
%     'Title', 'Inter-Brain Coupling (ROI-level, Pearson)', ...
%     'Visible', 'off', ...
%     'SavePath', fullfile(outDir, 'step1_group_bar.png'));
% close(fig);

%% Step 2: Permutation testing

fprintf('\n=== Step 2: Permutation testing ===\n');

permResult = ex.hyperscanning( ...
    'Method', 'pearson', ...
    'Biomarker', 'HbO', ...
    'UseROI', true, ...
    'ChannelPairing', 'same', ...
    'Permutations', 500, ...
    'PThreshold', 0.05);

if isfield(permResult, 'permutation') && ~isempty(permResult.permutation)
    perm = permResult.permutation;
    fprintf('  Significant ROIs (permutation p < .05): %d / %d\n', ...
        sum(perm.significant), length(perm.significant));
    for r = 1:length(perm.significant)
        sigStr = '';
        if perm.significant(r), sigStr = '*'; end
        fprintf('    ROI %d: observed=%.3f, null mean=%.3f, p=%.4f %s\n', ...
            r, perm.observed(r), perm.nullMean(r), perm.pvalue(r), sigStr);
    end
end

fig = exploreFNIRS.hyperscanning.plotGroup(permResult, ...
    'ShowSignificance', true, ...
    'ChannelLabels', roiNames, ...
    'Title', 'Inter-Brain Coupling (with permutation test)');
% fig = exploreFNIRS.hyperscanning.plotGroup(permResult, ...
%     'ShowSignificance', true, ...
%     'ChannelLabels', roiNames, ...
%     'Title', 'Inter-Brain Coupling (with permutation test)', ...
%     'Visible', 'off', ...
%     'SavePath', fullfile(outDir, 'step2_permutation.png'));
% close(fig);

%% Step 3: Block-wise hyperscanning

fprintf('\n=== Step 3: Block-wise hyperscanning ===\n');

blocks = blockDefs{1};
blockResult = ex.hyperscanning( ...
    'Method', 'pearson', ...
    'Biomarker', 'HbO', ...
    'UseROI', true, ...
    'ChannelPairing', 'same', ...
    'Blocks', blocks);

for b = 1:length(blockResult)
    fprintf('  Block %d (%s, %.0f-%.0fs): mean r = %.3f\n', ...
        b, blockResult(b).blockInfo.Condition, ...
        blockResult(b).startTime, blockResult(b).endTime, ...
        mean(blockResult(b).coupling.Mean, 'omitnan'));
end

fig = exploreFNIRS.hyperscanning.plotGroup(blockResult, ...
    'ChannelLabels', roiNames, ...
    'Title', 'Inter-Brain Coupling per Block');
% fig = exploreFNIRS.hyperscanning.plotGroup(blockResult, ...
%     'ChannelLabels', roiNames, ...
%     'Title', 'Inter-Brain Coupling per Block', ...
%     'Visible', 'off', ...
%     'SavePath', fullfile(outDir, 'step3_block_wise.png'));
% close(fig);

%% Step 4: Dyad-level visualization

fprintf('\n=== Step 4: Dyad-level visualization ===\n');

fig = exploreFNIRS.hyperscanning.plotDyadMatrix(result, ...
    'SortDyads', 'mean', ...
    'Title', 'Dyad x ROI Coupling');
% fig = exploreFNIRS.hyperscanning.plotDyadMatrix(result, ...
%     'SortDyads', 'mean', ...
%     'Title', 'Dyad x ROI Coupling', ...
%     'Visible', 'off', ...
%     'SavePath', fullfile(outDir, 'step4_dyad_matrix.png'));
% close(fig);

fig = exploreFNIRS.hyperscanning.plotInterBrainTopo(result, ...
    'BrainLabels', {'Speaker', 'Listener'}, ...
    'LineThreshold', 0.1, ...
    'Title', 'Inter-Brain Topology');
% fig = exploreFNIRS.hyperscanning.plotInterBrainTopo(result, ...
%     'BrainLabels', {'Speaker', 'Listener'}, ...
%     'LineThreshold', 0.1, ...
%     'Title', 'Inter-Brain Topology', ...
%     'Visible', 'off', ...
%     'SavePath', fullfile(outDir, 'step4_inter_brain_topo.png'));
% close(fig);

%% Step 5: Channel-level hyperscanning (full cross-brain matrix)

fprintf('\n=== Step 5: Channel-level cross-brain matrix ===\n');

chResult = ex.hyperscanning( ...
    'Method', 'pearson', ...
    'Biomarker', 'HbO', ...
    'ChannelPairing', 'all');

fprintf('  Cross-brain matrix: %d x %d\n', size(chResult.Mean));
fprintf('  Mean coupling: %.3f\n', mean(chResult.Mean(:), 'omitnan'));

fig = exploreFNIRS.connectivity.plotMatrix(chResult, ...
    'Title', 'Cross-Brain Matrix (all channel pairs)');
% fig = exploreFNIRS.connectivity.plotMatrix(chResult, ...
%     'Title', 'Cross-Brain Matrix (all channel pairs)', ...
%     'Visible', 'off', ...
%     'SavePath', fullfile(outDir, 'step5_cross_brain_matrix.png'));
% close(fig);

%% Step 6: Within-subject connectivity for comparison

fprintf('\n=== Step 6: Within-subject connectivity ===\n');

ex.groupby({'Group'});

withinResult = ex.interROI('Method', 'pearson', 'Biomarker', 'HbO');

fprintf('  Within-subject ROI connectivity vs inter-brain coupling:\n');
for g = 1:length(withinResult)
    fprintf('    %s within-subject: mean r = %.3f\n', ...
        withinResult(g).label, withinResult(g).globalMean);
end
fprintf('    Inter-brain (all dyads): mean r = %.3f\n', ...
    mean(result.Mean, 'omitnan'));

withinT = exploreFNIRS.report.connectivitySummary(withinResult);
fprintf('\n  Within-subject connectivity summary:\n');
disp(withinT);

%% Step 7: Multiple coupling methods

fprintf('\n=== Step 7: Multiple coupling methods ===\n');

methods = {'pearson', 'spearman', 'coherence'};
for m = 1:length(methods)
    methodResult = ex.hyperscanning( ...
        'Method', methods{m}, ...
        'Biomarker', 'HbO', ...
        'UseROI', true, ...
        'ChannelPairing', 'same');

    fprintf('  %s: mean inter-brain coupling = %.3f\n', ...
        methods{m}, mean(methodResult.Mean, 'omitnan'));
end

%% Step 8: Connectogram of a condition contrast (node-colored Delta-r)
%
% Reproduce the publication-style circular connectogram: channel nodes on a
% ring, coupled pairs joined by arcs, and each NODE colored by a per-node
% contrast (here Delta-r between the two task conditions) with its own
% colorbar. Region anchors (ROI names) label the ring; edges are drawn in a
% single subtle color so the node contrast reads cleanly.

fprintf('\n=== Step 8: Connectogram (condition contrast, Delta-r) ===\n');

subj = subjects{1};

% The two task conditions are encoded by marker code. Build a within-brain
% channel connectivity matrix for each condition by averaging that
% condition's block windows, then take the per-node strength difference.
codes = unique([blocks.markerCode]);
codes = codes(1:min(2, numel(codes)));

% Per-node strength = mean off-diagonal coupling (autocorrelation excluded).
nodeStrength = @(M) (sum(M, 2, 'omitnan') - diag(M)) ./ max(size(M, 1) - 1, 1);

condMat = cell(1, numel(codes));
lastR = [];
for ci = 1:numel(codes)
    bsel = blocks([blocks.markerCode] == codes(ci));
    accum = []; cnt = 0;
    for k = 1:numel(bsel)
        w = [bsel(k).startTime, bsel(k).endTime];
        if diff(w) <= 0, continue; end
        r = exploreFNIRS.connectivity.computeMatrix(subj, ...
            'Method', 'pearson', 'Biomarker', 'HbO', 'TimeWindow', w);
        if isempty(accum), accum = zeros(size(r.matrix)); end
        accum = accum + r.matrix; cnt = cnt + 1; lastR = r;
    end
    condMat{ci} = accum ./ max(cnt, 1);
end

% Node Delta-r contrast = node strength in condition A minus condition B.
dr = nodeStrength(condMat{1}) - nodeStrength(condMat{2});

% Edges: the condition-A matrix. Nodes grouped under their ROI region.
connResult = lastR;
connResult.matrix = condMat{1};
connResult.pmatrix = [];

grp = repmat({''}, 1, nCh);
for rr = 1:numel(roiDef)
    grp(roiDef{rr}) = roiNames(rr);
end

fprintf('  Node Delta-r range: [%.3f, %.3f] across %d channels\n', ...
    min(dr), max(dr), nCh);

fig = exploreFNIRS.connectivity.plotChord(connResult, ...
    'NodeValues', dr, 'NodeColormap', 'rdbu', ...
    'ColorbarLabel', '\Deltar (Task A - Task B)', ...
    'EdgeColor', [0.55 0.75 0.88], 'ArcAlpha', 0.5, ...
    'GroupLabels', grp, 'MinThreshold', 0.5, ...
    'Title', 'Within-Brain Connectogram (condition contrast)');
% fig = exploreFNIRS.connectivity.plotChord(connResult, ...
%     'NodeValues', dr, 'NodeColormap', 'rdbu', ...
%     'ColorbarLabel', '\Deltar (Task A - Task B)', ...
%     'EdgeColor', [0.55 0.75 0.88], 'ArcAlpha', 0.5, ...
%     'GroupLabels', grp, 'MinThreshold', 0.5, ...
%     'Title', 'Within-Brain Connectogram (condition contrast)', ...
%     'Visible', 'off', ...
%     'SavePath', fullfile(outDir, 'step8_connectogram.png'));
% close(fig);

%% Summary
fprintf('\n=== Hyperscanning tutorial complete ===\n');
