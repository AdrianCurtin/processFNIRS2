%% example_hbica.m - Hyper-Brain ICA for inter-brain network detection
%
% Demonstrates HB-ICA analysis for hyperscanning data. HB-ICA uses TDSEP
% ICA to decompose concatenated dual-subject fNIRS data and classify
% components as inter-brain (shared across subjects) or intra-brain.
%
% Covers:
%   1. Data preparation: generate paired subjects, assign dyad metadata
%   2. Standalone HB-ICA on a single dyad
%   3. Interpreting GOF scores and inter-brain classification
%   4. Visualizing HB-ICA results (plotHBICA)
%   5. Group-level HB-ICA via Experiment.hbica()
%   6. Block-wise HB-ICA
%   7. Comparing HB-ICA with pairwise coupling
%
% Requirements:
%   - processFNIRS2 on path
%   - Sample data available via pf2.import.sampleData.experiment()
%
% References:
%   Luo et al. (2024). Biomedical Optics Express, 16(1). DOI: 10.1364/BOE.542554

outDir = '/tmp/hbica_examples';
if ~exist(outDir, 'dir'), mkdir(outDir); end

%% Step 1: Prepare paired data

fprintf('=== Step 1: Prepare paired data ===\n');

[subjects, blockDefs] = pf2.import.sampleData.experiment('blocks');
[rawMethod, oxyMethod] = pf2.import.sampleData.addDemoPipelines();

% Assign dyad metadata (2 dyads, 4 subjects)
dyadIDs = {'D1', 'D1', 'D2', 'D2'};
roles   = {'Speaker', 'Listener', 'Speaker', 'Listener'};
for s = 1:length(subjects)
    subjects{s}.info.DyadID = dyadIDs{s};
    subjects{s}.info.Role   = roles{s};
end

subjects = processFNIRS2(subjects, rawMethod, oxyMethod);
fprintf('  %d subjects in %d dyads, processed\n', ...
    length(subjects), length(unique(dyadIDs)));

%% Step 2: Standalone HB-ICA on a single dyad

fprintf('\n=== Step 2: Standalone HB-ICA on Dyad 1 ===\n');

dataA = subjects{1};
dataB = subjects{2};

result = exploreFNIRS.hyperscanning.hbica(dataA, dataB, ...
    'Biomarker', 'HbO', ...
    'GOFThreshold', 0);

fprintf('  Components extracted: %d\n', result.nComponents);
fprintf('  Inter-brain components: %d\n', sum(result.isInterBrain));
fprintf('  Intra-brain components: %d\n', sum(~result.isInterBrain));

%% Step 3: Interpreting GOF scores

fprintf('\n=== Step 3: GOF scores ===\n');
fprintf('  GOF near 0 = inter-brain (equal loading across both subjects)\n');
fprintf('  GOF near 1 = intra-brain (loading concentrated in one subject)\n\n');

for k = 1:result.nComponents
    if result.isInterBrain(k)
        label = 'INTER';
    else
        label = 'intra';
    end
    fprintf('  IC%d: GOF = %+.3f  GOF_A = %+.3f  GOF_B = %+.3f  [%s]\n', ...
        k, result.GOF(k), result.GOF_A(k), result.GOF_B(k), label);
end

%% Step 4: Visualize HB-ICA results

fprintf('\n=== Step 4: Visualization ===\n');

% Show all components
fig = exploreFNIRS.hyperscanning.plotHBICA(result, ...
    'ShowIntraBrain', true, ...
    'MaxComponents', 4, ...
    'Title', 'HB-ICA: Dyad 1 (all components)', ...
    'Visible', 'off', ...
    'SavePath', fullfile(outDir, 'step4_hbica_all.png'));
close(fig);

% Show only inter-brain components
if any(result.isInterBrain)
    fig = exploreFNIRS.hyperscanning.plotHBICA(result, ...
        'Title', 'HB-ICA: Dyad 1 (inter-brain only)', ...
        'Visible', 'off', ...
        'SavePath', fullfile(outDir, 'step4_hbica_inter.png'));
    close(fig);
end

fprintf('  Saved plots to %s\n', outDir);

%% Step 5: Group-level HB-ICA via Experiment

fprintf('\n=== Step 5: Group-level HB-ICA ===\n');

ex = exploreFNIRS.core.Experiment(subjects);

groupResult = ex.hbica( ...
    'Biomarker', 'HbO', ...
    'GOFThreshold', 0);

fprintf('  Dyads analyzed: %d\n', groupResult.summary.nDyads);
for d = 1:groupResult.summary.nDyads
    fprintf('  %s: %d components, %d inter-brain, mean GOF = %.3f\n', ...
        groupResult.dyadIDs{d}, ...
        groupResult.dyads{d}.nComponents, ...
        groupResult.summary.nInterBrain(d), ...
        groupResult.summary.meanGOF(d));
end

%% Step 6: Block-wise HB-ICA

fprintf('\n=== Step 6: Block-wise HB-ICA ===\n');

blocks = blockDefs{1};
blockResult = ex.hbica( ...
    'Biomarker', 'HbO', ...
    'Blocks', blocks);

for b = 1:length(blockResult)
    nIB = mean(blockResult(b).hbica.summary.nInterBrain);
    fprintf('  Block %d (%s, %.0f-%.0fs): mean inter-brain components = %.1f\n', ...
        b, blockResult(b).blockInfo.Condition, ...
        blockResult(b).startTime, blockResult(b).endTime, nIB);
end

%% Step 7: Compare with pairwise coupling

fprintf('\n=== Step 7: HB-ICA vs pairwise Pearson ===\n');

% Pairwise Pearson coupling for the same dyad
pearsonResult = exploreFNIRS.hyperscanning.computeDyad(dataA, dataB, ...
    'Method', 'pearson', ...
    'Biomarker', 'HbO', ...
    'ChannelPairing', 'same');

fprintf('  Pearson (channel-paired): mean r = %.3f\n', ...
    mean(pearsonResult.values, 'omitnan'));
fprintf('  HB-ICA: %d inter-brain components (data-driven, no pairing needed)\n', ...
    sum(result.isInterBrain));
fprintf('\n  HB-ICA advantages:\n');
fprintf('    - No frequency band specification needed\n');
fprintf('    - Uses all channels simultaneously\n');
fprintf('    - Separates inter-brain from intra-brain activity\n');
fprintf('    - Subject-specific spatial maps via dual regression\n');

%% Summary

fprintf('\n=== HB-ICA tutorial complete ===\n');
fprintf('Output files in: %s\n', outDir);
d = dir(fullfile(outDir, 'step*'));
for i = 1:length(d)
    fprintf('  %s (%.1f KB)\n', d(i).name, d(i).bytes/1024);
end
