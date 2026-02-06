%% example_experiment_cli.m - Experiment class CLI usage examples
%
% Demonstrates how to use exploreFNIRS.core.Experiment for group-level
% fNIRS analysis from the command line (no GUI required).
%
% Covers:
%   1. Hard vs Easy task comparison (standard fNIRS group analysis)
%   2. Subject-level temporal plots
%   3. Behavioral / info variable analysis (plotInfoVar)
%   4. Multi-factor grouping and export
%
% Requirements:
%   - processFNIRS2 on path
%   - Sample data available via pf2.import.sampleData.fNIR2000()

cd('/Users/adriancurtin/Documents/GitHub/processFNIRS2');
outDir = '/tmp/experiment_examples';
if ~exist(outDir, 'dir'), mkdir(outDir); end

%% Step 0: Process sample data once (shared across all examples)
fprintf('=== Processing sample data ===\n');
raw = pf2.import.sampleData.fNIR2000();
processed = processFNIRS2(raw, 'ShowGUI', false);

%% Build a realistic multi-subject dataset
%
% Simulate 12 segments: 4 subjects x {Easy, Hard, Rest} conditions
% Each subject gets behavioral metrics in .info

rng(42);  % reproducible
nSubjects = 4;
conditions = {'Easy', 'Hard', 'Rest'};
groups = {'Young', 'Young', 'Older', 'Older'};
ages = [22, 25, 55, 60];

allData = {};
idx = 0;
for s = 1:nSubjects
    for c = 1:length(conditions)
        idx = idx + 1;
        d = processed;
        d.info.SubjectID = sprintf('Sub%02d', s);
        d.info.Group = groups{s};
        d.info.Age = ages(s);
        d.info.Condition = conditions{c};
        d.info.Trial = 1;

        % Add behavioral measures
        baseRT = 300 + (s-1)*20;  % baseline RT varies by subject
        if strcmp(conditions{c}, 'Hard')
            d.info.reactionTime = baseRT + 150 + randn*30;
            d.info.accuracy = 0.70 + randn*0.05;
            d.info.taskLoad = 3;
        elseif strcmp(conditions{c}, 'Easy')
            d.info.reactionTime = baseRT + randn*20;
            d.info.accuracy = 0.95 + randn*0.02;
            d.info.taskLoad = 1;
        else  % Rest
            d.info.reactionTime = NaN;
            d.info.accuracy = NaN;
            d.info.taskLoad = 0;
        end

        % Add synthetic Aux data (accelerometer + heart rate)
        nSamples = length(d.time);
        t = d.time;

        % Simulated 3-axis accelerometer
        d.Aux.accelerometer.data = 0.01*randn(nSamples, 3);
        if strcmp(conditions{c}, 'Hard')
            % More motion during hard task
            d.Aux.accelerometer.data = d.Aux.accelerometer.data + 0.05*randn(nSamples, 3);
        end
        d.Aux.accelerometer.time = t;
        d.Aux.accelerometer.unit = 'g';

        % Simulated heart rate (single channel)
        baseHR = 70 + (s-1)*3;
        taskEffect = 10 * strcmp(conditions{c}, 'Hard') + 5 * strcmp(conditions{c}, 'Easy');
        d.Aux.heartRate.data = baseHR + taskEffect + 2*randn(nSamples, 1);
        d.Aux.heartRate.time = t;
        d.Aux.heartRate.unit = 'bpm';

        allData{idx} = d; %#ok<SAGROW>
    end
end

fprintf('Created %d segments across %d subjects\n\n', idx, nSubjects);

%% Example 1: Hard vs Easy task comparison
%
% The most common use case: compare hemodynamic response between conditions

fprintf('=== Example 1: Hard vs Easy HbO comparison ===\n');

ex = exploreFNIRS.core.Experiment(allData);

% Filter out Rest - only keep task conditions
ex.select('Condition', {'Easy', 'Hard'});

% Group by condition
ex.groupby({'Condition'});

% Configure preprocessing
ex.settings.baseline = [-5, 0];
ex.settings.taskStart = 0;
ex.settings.resampleRate = 1;
ex.settings.useBaseline = true;

% Aggregate (computes grand averages with preprocessing)
ex.aggregate();
ex.summary();

% Temporal plot: HbO and HbR time courses for channels 1-5
fig = ex.plotTemporal('Biomarkers', {'HbO', 'HbR'}, 'Channels', 1:5, ...
    'Title', 'Easy vs Hard: HbO & HbR (Ch 1-5 avg)', ...
    'Visible', 'off', 'SavePath', fullfile(outDir, 'ex1_temporal.png'));
close(fig);

% Bar chart: HbO averaged over 5-20s window
fig = ex.plotBar('Biomarker', 'HbO', 'Channels', 1:5, ...
    'TimeWindow', [5, 20], 'ShowIndividual', true, ...
    'Title', 'Easy vs Hard: Mean HbO (5-20s)', ...
    'Visible', 'off', 'SavePath', fullfile(outDir, 'ex1_bar.png'));
close(fig);

fprintf('\n');

%% Example 2: Subject-level analysis
%
% Group by SubjectID to see individual hemodynamic responses

fprintf('=== Example 2: Per-subject temporal plots ===\n');

ex2 = exploreFNIRS.core.Experiment(allData);
ex2.select('Condition', 'Hard');  % just Hard trials
ex2.groupby({'SubjectID'});

ex2.settings.baseline = [-5, 0];
ex2.settings.resampleRate = 1;
ex2.settings.useBaseline = true;

ex2.aggregate();

% Grid layout shows each subject in its own subplot
fig = ex2.plotTemporal('Biomarkers', {'HbO'}, 'Channels', 1:3, ...
    'Layout', 'grid', ...
    'Title', 'Per-Subject HbO (Hard condition)', ...
    'Visible', 'off', 'SavePath', fullfile(outDir, 'ex2_subject_grid.png'));
close(fig);

fprintf('\n');

%% Example 3: Behavioral variable analysis (no aggregate needed)
%
% Plot reaction time and accuracy by condition using plotInfoVar.
% This works directly from the metadata - no fNIRS aggregation required.

fprintf('=== Example 3: Behavioral variables by condition ===\n');

ex3 = exploreFNIRS.core.Experiment(allData);
ex3.select('Condition', {'Easy', 'Hard'});  % exclude Rest (NaN RT)
ex3.groupby({'Condition'});

% Reaction time by condition
fig = ex3.plotInfoVar('reactionTime', ...
    'YLabel', 'Reaction Time (ms)', ...
    'Title', 'RT: Easy vs Hard', ...
    'Visible', 'off', 'SavePath', fullfile(outDir, 'ex3_rt_by_condition.png'));
close(fig);

% Accuracy by condition
fig = ex3.plotInfoVar('accuracy', ...
    'YLabel', 'Proportion Correct', ...
    'Title', 'Accuracy: Easy vs Hard', ...
    'ErrorType', 'SD', ...
    'Visible', 'off', 'SavePath', fullfile(outDir, 'ex3_acc_by_condition.png'));
close(fig);

% Scatter: RT vs accuracy, colored by condition
fig = ex3.plotScatter('reactionTime', 'accuracy', ...
    'FitLine', true, ...
    'XLabel', 'Reaction Time (ms)', ...
    'YLabel', 'Accuracy', ...
    'Title', 'RT vs Accuracy by Condition', ...
    'Visible', 'off', 'SavePath', fullfile(outDir, 'ex3_rt_vs_acc_scatter.png'));
close(fig);

fprintf('\n');

%% Example 4: Multi-factor grouping (Group x Condition)
%
% Cross Group (Young/Older) with Condition (Easy/Hard) for a 2x2 design

fprintf('=== Example 4: Group x Condition (2x2 design) ===\n');

ex4 = exploreFNIRS.core.Experiment(allData);
ex4.select('Condition', {'Easy', 'Hard'});
ex4.groupby({'Group', 'Condition'});

% RT by Group x Condition (behavioral only - no aggregate needed)
fig = ex4.plotInfoVar('reactionTime', ...
    'YLabel', 'Reaction Time (ms)', ...
    'Title', 'RT by Group x Condition', ...
    'Visible', 'off', 'SavePath', fullfile(outDir, 'ex4_rt_group_x_cond.png'));
close(fig);

% Also aggregate for fNIRS comparison
ex4.settings.baseline = [-5, 0];
ex4.settings.resampleRate = 1;
ex4.settings.useBaseline = true;
ex4.aggregate();

fig = ex4.plotBar('Biomarker', 'HbO', 'Channels', 1:5, ...
    'ShowIndividual', true, ...
    'Visible', 'off', 'SavePath', fullfile(outDir, 'ex4_hbo_group_x_cond.png'));
close(fig);

fprintf('\n');

%% Example 5: Continuous covariate scatter plots
%
% Scatter plots for continuous variables - no binning needed

fprintf('=== Example 5: Age as continuous variable ===\n');

ex5 = exploreFNIRS.core.Experiment(allData);
ex5.groupby({'Group'});  % Young vs Older

% Age by group (bar + individual points)
fig = ex5.plotInfoVar('Age', ...
    'YLabel', 'Age (years)', ...
    'Title', 'Age Distribution by Group', ...
    'Visible', 'off', 'SavePath', fullfile(outDir, 'ex5_age_by_group.png'));
close(fig);

% Scatter: Age vs RT with fit line, colored by group
ex5.select('Condition', {'Easy', 'Hard'});  % exclude Rest (NaN RT)
ex5.groupby({'Group'});
fig = ex5.plotScatter('Age', 'reactionTime', ...
    'FitLine', true, ...
    'XLabel', 'Age (years)', ...
    'YLabel', 'Reaction Time (ms)', ...
    'Title', 'Age vs RT by Group', ...
    'Visible', 'off', 'SavePath', fullfile(outDir, 'ex5_age_vs_rt.png'));
close(fig);

% Scatter without grouping
ex5.reset();
ex5.select('Condition', {'Easy', 'Hard'});
fig = ex5.plotScatter('reactionTime', 'accuracy', ...
    'FitLine', true, ...
    'XLabel', 'RT (ms)', ...
    'YLabel', 'Accuracy', ...
    'Title', 'Speed-Accuracy Tradeoff (all subjects)', ...
    'Visible', 'off', 'SavePath', fullfile(outDir, 'ex5_speed_accuracy.png'));
close(fig);

% Export the full info table for external analysis (R, Python, etc.)
T = ex5.infoTable();
writetable(T, fullfile(outDir, 'ex5_metadata.csv'));
fprintf('Exported metadata: %d rows x %d cols to ex5_metadata.csv\n', height(T), width(T));

fprintf('\n');

%% Example 6: Export to long/wide format for statistical software
%
% After aggregation, export binned data for LME/ANOVA

fprintf('=== Example 6: Export for statistics ===\n');

ex6 = exploreFNIRS.core.Experiment(allData);
ex6.select('Condition', {'Easy', 'Hard'});
ex6.groupby({'Group', 'Condition'});
ex6.settings.baseline = [-5, 0];
ex6.settings.resampleRate = 1;
ex6.settings.barBinSize = 10;  % 10s bins for export
ex6.settings.useBaseline = true;
ex6.aggregate();

% Long format (for R lme4, tidyverse)
longT = ex6.toLongTable({'HbO', 'HbR'}, 1:5);
writetable(longT, fullfile(outDir, 'ex6_long.csv'));
fprintf('Long table: %d rows x %d cols\n', height(longT), width(longT));

% Wide format (for SPSS, Excel)
wideT = ex6.toWideTable({'HbO'}, 1:5);
writetable(wideT, fullfile(outDir, 'ex6_wide.csv'));
fprintf('Wide table: %d rows x %d cols\n', height(wideT), width(wideT));

%% Example 7: Auxiliary signal analysis
%
% Plot multichannel Aux timeseries (accelerometer, heart rate) by group.
% Aux data flows through the same preprocessing + grand averaging pipeline.

fprintf('=== Example 7: Auxiliary signal plots ===\n');

ex7 = exploreFNIRS.core.Experiment(allData);
ex7.select('Condition', {'Easy', 'Hard'});
ex7.groupby({'Condition'});
ex7.settings.resampleRate = 2;
ex7.settings.useBaseline = false;
ex7.aggregate();

% List available Aux fields
ex7.auxFields();

% 3-axis accelerometer in grid layout (one subplot per axis)
fig = ex7.plotAux('accelerometer', ...
    'Layout', 'grid', ...
    'Title', 'Accelerometer: Easy vs Hard', ...
    'Visible', 'off', 'SavePath', fullfile(outDir, 'ex7_accel_grid.png'));
close(fig);

% Heart rate (single channel) with error bands
fig = ex7.plotAux('heartRate', ...
    'ErrorType', 'SEM', ...
    'Title', 'Heart Rate: Easy vs Hard', ...
    'Visible', 'off', 'SavePath', fullfile(outDir, 'ex7_heartrate.png'));
close(fig);

% Export with Aux columns included
longAux = ex7.toLongTable({'HbO'}, 1:3, [], 'IncludeAux', true);
fprintf('Long table with Aux: %d rows x %d cols\n', height(longAux), width(longAux));
fprintf('Columns: %s\n', strjoin(longAux.Properties.VariableNames(1:min(12,width(longAux))), ', '));

fprintf('\n');

%% Example 8: fNIRS Scatter (info variable vs biomarker)
%
% Scatter plot correlating a behavioral variable with fNIRS channel data.
% This is different from plotScatter (which plots two info vars against
% each other) - plotScatterFNIRS correlates an info var vs actual fNIRS data.

fprintf('=== Example 8: fNIRS scatter (behavior vs HbO) ===\n');

ex8 = exploreFNIRS.core.Experiment(allData);
ex8.select('Condition', {'Easy', 'Hard'});
ex8.groupby({'Condition'});
ex8.settings.resampleRate = 1;
ex8.settings.barBinSize = 10;
ex8.settings.useBaseline = false;
ex8.aggregate();

% Single channel scatter: reaction time vs HbO
[fig, stats] = ex8.plotScatterFNIRS('reactionTime', ...
    'Biomarkers', {'HbO'}, 'Channels', 1, ...
    'FitLine', true, 'ErrorBand', true, ...
    'Title', 'RT vs HbO (Channel 1)', ...
    'Visible', 'off', 'SavePath', fullfile(outDir, 'ex8_scatter_fnirs.png'));
close(fig);

% Multi-channel scatter
[fig, ~] = ex8.plotScatterFNIRS('reactionTime', ...
    'Biomarkers', {'HbO'}, 'Channels', [1, 3, 5], ...
    'FitLine', true, 'CorrType', 'Spearman', ...
    'Title', 'RT vs HbO (Spearman)', ...
    'Visible', 'off', 'SavePath', fullfile(outDir, 'ex8_scatter_multi.png'));
close(fig);

fprintf('  Scatter stats (Ch1): r=%.3f, p=%.4f, N=%d\n', ...
    stats(1,1,1).r, stats(1,1,1).p, stats(1,1,1).N);

fprintf('\n');

%% Example 9: LME analysis
%
% Linear Mixed Effects model using groupby variables as fixed effects.
% Fits per-channel models and returns ANOVA tables, contrasts, etc.

fprintf('=== Example 9: LME analysis ===\n');

ex9 = exploreFNIRS.core.Experiment(allData);
ex9.select('Condition', {'Easy', 'Hard'});
ex9.groupby({'Condition'});
ex9.settings.resampleRate = 1;
ex9.settings.barBinSize = 10;
ex9.settings.useBaseline = false;
ex9.aggregate();

% Basic LME: Condition as fixed effect
[fig, results] = ex9.plotLME('Biomarkers', {'HbO'}, 'Channels', [1, 2, 3], ...
    'Visible', 'off', 'SavePath', fullfile(outDir, 'ex9_lme_bar.png'));
if ~isempty(fig), close(fig); end

fprintf('  Formula: %s\n', results.formula);
fprintf('  ANOVA p-values:\n');
disp(results.anova_pval);

% LME with custom formula
[~, results2] = ex9.plotLME('Biomarkers', {'HbO'}, 'Channels', 1, ...
    'CustomFormula', 'Opt1_HbO ~ Condition + (1|SubjectID)', ...
    'ShowBar', false, 'Visible', 'off');
if ~isempty(results2.models{1})
    fprintf('  Custom formula AIC: %.1f\n', results2.AIC(1));
end

fprintf('\n');

%% Summary
fprintf('\n=== All examples complete ===\n');
fprintf('Output files in: %s\n', outDir);
d = dir(fullfile(outDir, '*'));
d = d(~[d.isdir]);
for i = 1:length(d)
    fprintf('  %s (%.1f KB)\n', d(i).name, d(i).bytes/1024);
end
