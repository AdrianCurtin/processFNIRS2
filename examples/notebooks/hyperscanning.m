%% Hyperscanning fNIRS Analysis
% Template for analyzing inter-brain synchrony in dyadic experiments.
%
% This notebook covers:
%   1. Import paired participant data
%   2. Compute inter-brain coupling (dyad-level)
%   3. Group-level statistics with permutation tests
%   4. Block-wise comparison of synchrony
%   5. Publication-ready visualization and tables
%
% Prerequisites:
%   - Processed fNIRS data with .info.DyadID and .info.Role fields
%   - At least 2 dyads per condition

%% Configuration

dataDir    = 'path/to/processed/data';
outputDir  = 'results/hyperscanning';
groupVar   = 'Condition';
biomarker  = 'HbO';
channels   = 1:16;
method     = 'pearson';          % 'pearson', 'spearman', 'wcoherence'
nPerms     = 1000;               % Permutation iterations (0 = skip)
dyadField  = 'DyadID';           % Info field for dyad ID
roleField  = 'Role';             % Info field for role (e.g., 'Speaker', 'Listener')

%% 1. Load Data

files = dir(fullfile(dataDir, '*.mat'));
data = cell(length(files), 1);

for i = 1:length(files)
    tmp = load(fullfile(files(i).folder, files(i).name));
    data{i} = tmp.processed;
end

fprintf('Loaded %d datasets\n', length(data));

%% 2. Create Experiment

ex = exploreFNIRS.core.Experiment(data);
ex.summary();

%% 3. Group by Condition

ex.groupby({groupVar});

%% 4. Compute Inter-Brain Synchrony
% Pairs subjects by DyadID, computes cross-brain coupling per channel,
% and runs permutation test for significance.

result = ex.hyperscanning( ...
    'Method', method, ...
    'Biomarker', biomarker, ...
    'Channels', channels, ...
    'ChannelPairing', 'same', ...
    'DyadField', dyadField, ...
    'RoleField', roleField, ...
    'Permutations', nPerms, ...
    'PThreshold', 0.05);

%% 5. Visualize Group Results
% Bar chart with SEM and significance stars.

fig_group = exploreFNIRS.hyperscanning.plotGroup(result, ...
    'ShowSignificance', true, ...
    'Visible', 'off');

%% 6. Block-Wise Hyperscanning (Optional)
% If your experiment has task blocks defined by markers.

% Define blocks from marker codes
% blocks = pf2.data.defineBlocks(data{1}, [49, 50], 30);
%
% blockResult = ex.hyperscanning( ...
%     'Method', method, ...
%     'Biomarker', biomarker, ...
%     'Channels', channels, ...
%     'Blocks', blocks);
%
% fig_blocks = exploreFNIRS.connectivity.plotBlockComparison(blockResult, ...
%     'Visible', 'off');

%% 7. Within-Subject Connectivity
% Compare intra-brain connectivity alongside inter-brain coupling.

ex.aggregate();
connResult = ex.connectivity( ...
    'Method', method, ...
    'Biomarker', biomarker, ...
    'Channels', channels);

%% 8. Connectivity Summary Table

T_conn = exploreFNIRS.report.connectivitySummary(connResult);
disp(T_conn);

%% 9. Save Figures and Generate Report

if ~isfolder(outputDir), mkdir(outputDir); end

figs = struct('group_coupling', fig_group);
paths = exploreFNIRS.report.saveFigureSet(figs, fullfile(outputDir, 'fig'), ...
    'DPI', 300, 'Style', 'publication');

%% 10. Demographics Table

T_demo = exploreFNIRS.report.demographicsTable(ex, ...
    'Variables', {'Age', 'Sex'});
disp(T_demo);

fprintf('Analysis complete. Results in: %s\n', outputDir);
