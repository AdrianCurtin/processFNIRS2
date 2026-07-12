%% Task Block Design fNIRS Analysis
% Template for analyzing task-based fNIRS experiments with block designs.
%
% This notebook walks through a standard workflow:
%   1. Import and process raw data
%   2. Create Experiment, group, and aggregate
%   3. Visualize temporal and bar-chart summaries
%   4. Run LME statistics
%   5. Generate publication-ready tables and figures
%
% Modify the configuration section below for your study.

%% Configuration
% Adjust these parameters for your experiment.

dataDir    = 'path/to/processed/data';   % Folder with processed .mat files
outputDir  = 'results/task_block';        % Output folder
groupVar   = 'Group';                     % Grouping variable (e.g., 'Group')
condVar    = 'Condition';                 % Condition variable
channels   = 1:16;                        % Channels to analyze
biomarkers = {'HbO'};                     % Biomarkers of interest
baseline   = [-5, 0];                     % Baseline window [start, end] seconds
taskStart  = 0;                           % Task onset time

%% 1. Load Processed Data
% Load all processed .mat files from the data directory.

files = dir(fullfile(dataDir, '*.mat'));
data = cell(length(files), 1);

for i = 1:length(files)
    tmp = load(fullfile(files(i).folder, files(i).name));
    % Assumes each file has a 'processed' variable
    data{i} = tmp.processed;
end

fprintf('Loaded %d datasets\n', length(data));

%% 2. Create Experiment and Configure
% Build the Experiment object and set preprocessing parameters.

ex = exploreFNIRS.core.Experiment(data);
ex.settings.baseline = baseline;
ex.settings.taskStart = taskStart;
ex.settings.resampleRate = 0.5;       % 500ms temporal bins
ex.settings.barBinSize = 5;           % 5s bar bins

% View available metadata
ex.summary();

%% 3. Select and Group Data
% Filter and group by experimental conditions.

ex.groupby({groupVar, condVar});

%% 4. Aggregate (Compute Grand Averages)
% Hierarchical averaging prevents pseudoreplication.

ex.aggregate('hierarchy');

%% 5. Temporal Visualization
% Time-series plots with SEM error bands.

fig_temporal = ex.plotTemporal( ...
    'Biomarkers', biomarkers, ...
    'Channels', channels, ...
    'ErrorType', 'SEM', ...
    'Visible', 'off');

%% 6. Bar Chart Visualization
% Mean activation per group/condition.

fig_bar = ex.plotBar( ...
    'Biomarker', biomarkers{1}, ...
    'Channels', channels, ...
    'ErrorType', 'SEM', ...
    'Visible', 'off');

%% 7. LME Statistical Analysis
% Fit linear mixed-effects models per channel.

[fig_lme, results] = ex.plotLME( ...
    'Biomarkers', biomarkers, ...
    'Channels', channels, ...
    'ShowBar', true, ...
    'Visible', 'off');

%% 8. Format Results for Publication
% Create APA-formatted tables and statistics.

% ANOVA table
T_anova = exploreFNIRS.report.anovaTable(results, 'AllChannels', true);
disp(T_anova);

% Contrasts for channel 1
T_contrast = exploreFNIRS.report.contrastTable(results, 'Channel', 1, 'CI', true);
disp(T_contrast);

% Formatted stat strings
for ch = 1:min(5, length(channels))
    str = exploreFNIRS.report.formatStats(results, 'Channel', ch);
    fprintf('Ch %d: %s\n', channels(ch), str);
end

%% 9. Demographics Table
% Table 1 for the manuscript.

T_demo = exploreFNIRS.report.demographicsTable(ex, ...
    'Variables', {'Age', 'Sex'});
disp(T_demo);

%% 10. LaTeX Export
% Generate LaTeX tables for the manuscript.

latex_anova = exploreFNIRS.report.toLatex(T_anova, ...
    'Caption', 'ANOVA Results', 'Label', 'tab:anova');
fprintf('%s\n', latex_anova);

%% 11. Save Figures
% Save all figures with publication formatting.

if ~isfolder(outputDir), mkdir(outputDir); end

figs = struct('temporal', fig_temporal, 'bar', fig_bar, 'lme', fig_lme);
paths = exploreFNIRS.report.saveFigureSet(figs, fullfile(outputDir, 'fig'), ...
    'DPI', 300, 'Style', 'publication');

%% 12. Generate HTML Report
% Create a complete HTML report.

pipe = exploreFNIRS.report.Pipeline(ex, 'Title', 'Task Block Design Analysis');
pipe.addStep('demographics', 'Variables', {'Age', 'Sex'});
pipe.addStep('temporal', 'Biomarkers', biomarkers, 'Channels', channels);
pipe.addStep('bar', 'Biomarker', biomarkers{1}, 'Channels', channels);
pipe.addStep('lme', 'Biomarkers', biomarkers, 'Channels', channels);
pipe.addStep('anova', 'AllChannels', true);
pipe.addStep('contrast', 'Channel', 1, 'CI', true);
pipe.run();

reportPath = exploreFNIRS.report.generate(pipe, ...
    fullfile(outputDir, 'report'), 'DPI', 300);
fprintf('Report: %s\n', reportPath);
