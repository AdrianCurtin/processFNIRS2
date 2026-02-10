%% Longitudinal fNIRS Analysis
% Template for multi-session pre/post intervention designs.
%
% This notebook covers:
%   1. Import multi-session data
%   2. Session as a groupby variable
%   3. Pre-post temporal and bar visualization
%   4. LME with Session as fixed effect
%   5. Connectivity change across sessions
%   6. Publication-ready output

%% Configuration

dataDir    = 'path/to/processed/data';
outputDir  = 'results/longitudinal';
groupVar   = 'Group';
sessionVar = 'Session';        % e.g., 'Pre', 'Post', or 'T1', 'T2', 'T3'
channels   = 1:16;
biomarkers = {'HbO'};
baseline   = [-5, 0];
taskStart  = 0;

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
ex.settings.baseline = baseline;
ex.settings.taskStart = taskStart;
ex.settings.resampleRate = 0.5;
ex.summary();

%% 3. Group by Session (and optionally Group)
% Group x Session design for intervention studies.

ex.groupby({groupVar, sessionVar});

%% 4. Aggregate

ex.aggregate('hierarchy');

%% 5. Temporal Plots
% Compare time-series across sessions.

fig_temporal = ex.plotTemporal( ...
    'Biomarkers', biomarkers, ...
    'Channels', channels(1:min(4, end)), ...
    'ErrorType', 'SEM', ...
    'Visible', 'off');

%% 6. Bar Charts
% Pre vs Post activation comparison.

fig_bar = ex.plotBar( ...
    'Biomarker', biomarkers{1}, ...
    'Channels', channels, ...
    'ErrorType', 'SEM', ...
    'Visible', 'off');

%% 7. LME Analysis
% Session as a fixed effect allows testing for pre-post changes.

[fig_lme, results] = ex.plotLME( ...
    'Biomarkers', biomarkers, ...
    'Channels', channels, ...
    'AllInteractions', true, ...
    'Visible', 'off');

%% 8. Formatted Results

% ANOVA table
T_anova = exploreFNIRS.report.anovaTable(results, 'AllChannels', true);
disp(T_anova);

% Print key stats
terms = results.anova_pval.Properties.VariableNames;
for t = 1:length(terms)
    str = exploreFNIRS.report.formatStats(results, 'Term', terms{t});
    fprintf('%s: %s\n', terms{t}, str);
end

%% 9. Contrast Table
% Pairwise comparisons between sessions.

T_contrast = exploreFNIRS.report.contrastTable(results, 'Channel', 1, 'CI', true);
disp(T_contrast);

%% 10. Connectivity Change Across Sessions
% Compare functional connectivity pre vs post.

% Reset and re-group by session only for connectivity
ex.reset();
ex.groupby({sessionVar});

connResult = ex.connectivity( ...
    'Method', 'pearson', ...
    'Biomarker', biomarkers{1}, ...
    'Channels', channels);

T_conn = exploreFNIRS.report.connectivitySummary(connResult);
disp(T_conn);

%% 11. Demographics

ex.reset();
ex.groupby({groupVar});
T_demo = exploreFNIRS.report.demographicsTable(ex, ...
    'Variables', {'Age', 'Sex'});
disp(T_demo);

%% 12. Save Everything

if ~isfolder(outputDir), mkdir(outputDir); end

figs = struct('temporal', fig_temporal, 'bar', fig_bar, 'lme', fig_lme);
paths = exploreFNIRS.report.saveFigureSet(figs, fullfile(outputDir, 'fig'), ...
    'DPI', 300, 'Style', 'publication');

% LaTeX
latex_anova = exploreFNIRS.report.toLatex(T_anova, ...
    'Caption', 'Longitudinal ANOVA Results', 'Label', 'tab:long_anova');
fprintf('%s\n', latex_anova);

fprintf('Analysis complete. Results in: %s\n', outputDir);
