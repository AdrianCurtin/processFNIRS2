%% example_experiment_cli.m - Experiment class CLI usage examples
%
% Demonstrates how to use exploreFNIRS.core.Experiment for group-level
% fNIRS analysis from the command line (no GUI required).
%
% Covers:
%   1. Hard vs Easy task comparison (standard fNIRS group analysis)
%   2. Subject-level temporal plots
%   3. Behavioral / info variable analysis (plotInfoBar)
%   4. Multi-factor grouping and export
%   5-8. Scatter plots, aux data, fNIRS scatter
%   9. fNIRS LME with full stats pipeline (statsFitLME → contrasts → summarize)
%  10. Behavioral LME (statsInfoLME - no aggregate needed)
%  11. Auxiliary signal LME (statsAuxLME - heart rate, accelerometer)
%  13. ROI-level analysis (define, aggregate, plot, LME, export)
%  15. Non-parametric permutation test (statsPermTest - small-N)
%  16. Effect size with bootstrap CIs (statsEffectSize)
%  17. Custom contrast matrices (buildContrasts, manual spec)
%  18. Declarative pipeline (Experiment.fromConfig)
%  19. Stats formatting (console, LaTeX, APA for all result types)
%
% Requirements:
%   - processFNIRS2 on path
%   - Sample data available via pf2.import.sampleData.fNIR2000()

% Uncomment to save figures instead of displaying them:
% outDir = '/tmp/experiment_examples';
% if ~exist(outDir, 'dir'), mkdir(outDir); end

%% Step 0: Generate synthetic experiment data
%
% pf2.import.sampleData.experiment() builds a multi-subject dataset from
% the fNIR2000 sample recording. It adds event markers for 6 task blocks
% (2 Easy + 2 Hard + 2 Rest, interleaved), auxiliary signals (heart rate,
% accelerometer), and behavioral metadata (reaction time, accuracy).
%
% The 'aligned' stage extracts blocks with 10s pre-time and centers each
% segment so t=0 = block onset. This gives a [-10, 0]s baseline period
% and ~30s of task data per segment.
%
% See also the other stages:
%   subjects = pf2.import.sampleData.experiment('raw');       % full recordings
%   [subjects, blocks] = pf2.import.sampleData.experiment('blocks');  % + block defs
%   segments = pf2.import.sampleData.experiment('extracted');  % cut but not aligned

fprintf('=== Generating synthetic experiment ===\n');
allData = pf2.import.sampleData.experiment('aligned');
fprintf('Created %d segments\n\n', length(allData));

%% Example 1: Hard vs Easy task comparison
%
% The most common use case: compare hemodynamic response between conditions.
%
% Averaging mode controls how segments are combined:
%   'hierarchy' (default) - bottom-up averaging through hierarchy levels
%       (Trial → Condition → Session → Subject) to prevent pseudoreplication
%   'flat'  - average within-subject only (one value per subject per group)
%   'none'  - each observation treated independently (no within-subject avg)
%
% The hierarchy order can be customized:
%   ex.hierarchy = {'SubjectID', 'Session', 'Condition'};
%
% Or set the mode via settings:
%   ex.settings.avgMode = 'flat';

fprintf('=== Example 1: Hard vs Easy HbO comparison ===\n');

ex = exploreFNIRS.core.Experiment(allData);
ex.select('Condition', {'Easy', 'Hard'});  % exclude Rest
ex.groupby({'Condition'});

% Configure preprocessing
ex.settings.baseline = [-5, 0];
ex.settings.taskStart = 0;
ex.settings.taskEnd = 30;
ex.settings.resampleRate = 1;
ex.settings.useBaseline = true;

% Set processing methods - data is reprocessed on first aggregate() call,
% then cached. Changing the method triggers reprocessing on next aggregate().
% Use pf2.methods.raw.list() / pf2.methods.oxy.list() to see available names.
[rawM, oxyM] = pf2.import.sampleData.addDemoPipelines();
ex.settings.rawMethod = rawM;
ex.settings.oxyMethod = oxyM;

% Visualize time settings before aggregating
fig = ex.plotExperimentTimeline();
% fig = ex.plotExperimentTimeline('Visible', 'off', ...
%     'SavePath', fullfile(outDir, 'ex1_timeline.png'));
% close(fig);

% Aggregate with hierarchical averaging (default)
% Equivalent: ex.aggregate('hierarchy')
ex.aggregate();
ex.summary();

% Temporal plot: HbO and HbR time courses for channels 1-5 with SEM bands
fig = ex.plotTemporal('Biomarkers', {'HbO', 'HbR'}, 'Channels', 1:2, ...
    'ErrorType', 'SEM', ...
    'Title', 'Easy vs Hard: HbO & HbR (Ch 1-5 avg)');
% fig = ex.plotTemporal('Biomarkers', {'HbO', 'HbR'}, 'Channels', 1:2, ...
%     'ErrorType', 'SEM', ...
%     'Title', 'Easy vs Hard: HbO & HbR (Ch 1-5 avg)', ...
%     'Visible', 'off', 'SavePath', fullfile(outDir, 'ex1_temporal.png'));
% close(fig);

% Bar chart: HbO averaged over full task window
fig = ex.plotBar('Biomarker', 'HbO', 'Channels', 1:2, ...
    'ShowIndividual', true, ...
    'Title', 'Easy vs Hard: Mean HbO');
% fig = ex.plotBar('Biomarker', 'HbO', 'Channels', 1:2, ...
%     'ShowIndividual', true, ...
%     'Title', 'Easy vs Hard: Mean HbO', ...
%     'Visible', 'off', 'SavePath', fullfile(outDir, 'ex1_bar.png'));
% close(fig);

% Re-aggregate with flat averaging for comparison
% (averages within-subject only, no Trial/Condition hierarchy)
ex.aggregate('flat');

% Or use 'none' to treat every segment independently (no within-subject avg)
% ex.aggregate('none');

% Custom hierarchy order (e.g., only SubjectID and Session levels)
% ex.hierarchy = {'SubjectID', 'Session'};
% ex.aggregate();

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

% Grid layout shows each subject in its own subplot with SEM error bands
fig = ex2.plotTemporal('Biomarkers', {'HbO'}, 'Channels', 1:3, ...
    'ErrorType', 'SEM', ...
    'Title', 'Per-Subject HbO (Hard condition)');
% fig = ex2.plotTemporal('Biomarkers', {'HbO'}, 'Channels', 1:3, ...
%     'ErrorType', 'SEM', ...
%     'Title', 'Per-Subject HbO (Hard condition)', ...
%     'Visible', 'off', 'SavePath', fullfile(outDir, 'ex2_subject_grid.png'));
% close(fig);

fprintf('\n');

%% Example 3: Behavioral variable analysis (no aggregate needed)
%
% Plot reaction time and accuracy by condition using plotInfoBar.
% This works directly from the metadata - no fNIRS aggregation required.

fprintf('=== Example 3: Behavioral variables by condition ===\n');

ex3 = exploreFNIRS.core.Experiment(allData);
ex3.select('Condition', {'Easy', 'Hard'});  % exclude Rest (NaN RT)
ex3.groupby({'Condition'});

% Reaction time by condition (default: 'hierarchy' averages within SubjectID)
fig = ex3.plotInfoBar('reactionTime', ...
    'YLabel', 'Reaction Time (ms)', ...
    'Title', 'RT: Easy vs Hard');
% fig = ex3.plotInfoBar('reactionTime', ...
%     'YLabel', 'Reaction Time (ms)', ...
%     'Title', 'RT: Easy vs Hard', ...
%     'Visible', 'off', 'SavePath', fullfile(outDir, 'ex3_rt_by_condition.png'));
% close(fig);

% Compare: 'none' shows raw block-level data (higher N, one point per trial)
% fig = ex3.plotInfoBar('reactionTime', 'Averaging', 'none', ...
%     'YLabel', 'Reaction Time (ms)', ...
%     'Title', 'RT: Easy vs Hard (block-level)');

% Accuracy by condition
fig = ex3.plotInfoBar('accuracy', ...
    'YLabel', 'Proportion Correct', ...
    'Title', 'Accuracy: Easy vs Hard', ...
    'ErrorType', 'SD');
% fig = ex3.plotInfoBar('accuracy', ...
%     'YLabel', 'Proportion Correct', ...
%     'Title', 'Accuracy: Easy vs Hard', ...
%     'ErrorType', 'SD', ...
%     'Visible', 'off', 'SavePath', fullfile(outDir, 'ex3_acc_by_condition.png'));
% close(fig);

% Scatter: RT vs accuracy, colored by condition, with error bands
fig = ex3.plotInfoScatter('reactionTime', 'accuracy', ...
    'FitLine', true, 'ErrorBand', true, ...
    'XLabel', 'Reaction Time (ms)', ...
    'YLabel', 'Accuracy', ...
    'Title', 'RT vs Accuracy by Condition');
% fig = ex3.plotInfoScatter('reactionTime', 'accuracy', ...
%     'FitLine', true, 'ErrorBand', true, ...
%     'XLabel', 'Reaction Time (ms)', ...
%     'YLabel', 'Accuracy', ...
%     'Title', 'RT vs Accuracy by Condition', ...
%     'Visible', 'off', 'SavePath', fullfile(outDir, 'ex3_rt_vs_acc_scatter.png'));
% close(fig);

fprintf('\n');

%% Example 4: Multi-factor grouping (Group x Condition)
%
% Cross Group (Young/Older) with Condition (Easy/Hard) for a 2x2 design

fprintf('=== Example 4: Group x Condition (2x2 design) ===\n');

ex4 = exploreFNIRS.core.Experiment(allData);
ex4.select('Condition', {'Easy', 'Hard'});
ex4.groupby({'Group', 'Condition'});

% RT by Group x Condition (behavioral only - no aggregate needed)
fig = ex4.plotInfoBar('reactionTime', ...
    'YLabel', 'Reaction Time (ms)', ...
    'Title', 'RT by Group x Condition');
% fig = ex4.plotInfoBar('reactionTime', ...
%     'YLabel', 'Reaction Time (ms)', ...
%     'Title', 'RT by Group x Condition', ...
%     'Visible', 'off', 'SavePath', fullfile(outDir, 'ex4_rt_group_x_cond.png'));
% close(fig);

% Also aggregate for fNIRS comparison
ex4.settings.baseline = [-5, 0];
ex4.settings.resampleRate = 1;
ex4.settings.useBaseline = true;
ex4.aggregate();

% Flat bars: each Group x Condition combination is a separate bar
fig = ex4.plotBar('Biomarker', 'HbO', 'Channels', 1:4, ...
    'ShowIndividual', true);
% fig = ex4.plotBar('Biomarker', 'HbO', 'Channels', 1:4, ...
%     'ShowIndividual', true, ...
%     'Visible', 'off', 'SavePath', fullfile(outDir, 'ex4_hbo_group_x_cond.png'));
% close(fig);

% Clustered bars: PlotBy groups Easy/Hard bars within each Group
%   X-axis categories = Group (Young, Older)
%   Bar colors/legend  = Condition (Easy, Hard)
fig = ex4.plotBar('Biomarker', 'HbO', 'Channels', 1:4, ...
    'PlotBy', 'Condition', 'ShowIndividual', true, ...
    'Title', 'HbO: Group x Condition (clustered)');
% fig = ex4.plotBar('Biomarker', 'HbO', 'Channels', 1:4, ...
%     'PlotBy', 'Condition', 'ShowIndividual', true, ...
%     'Title', 'HbO: Group x Condition (clustered)', ...
%     'Visible', 'off', 'SavePath', fullfile(outDir, 'ex4_hbo_clustered.png'));
% close(fig);

fprintf('\n');

%% Example 5: Continuous covariate scatter plots
%
% Scatter plots for continuous variables - no binning needed

fprintf('=== Example 5: Age as continuous variable ===\n');

ex5 = exploreFNIRS.core.Experiment(allData);
ex5.groupby({'Group'});  % Young vs Older

% Age by group (bar + individual points)
fig = ex5.plotInfoBar('Age', ...
    'YLabel', 'Age (years)', ...
    'Title', 'Age Distribution by Group');
% fig = ex5.plotInfoBar('Age', ...
%     'YLabel', 'Age (years)', ...
%     'Title', 'Age Distribution by Group', ...
%     'Visible', 'off', 'SavePath', fullfile(outDir, 'ex5_age_by_group.png'));
% close(fig);

% Scatter: Age vs RT with fit line and error bands, colored by group
% Default 'Averaging','hierarchy' averages trials within each subject first,
% so each point = one subject. Use 'none' to see raw block-level data.
ex5.select('Condition', {'Easy', 'Hard'});  % exclude Rest (NaN RT)
ex5.groupby({'Group'});
fig = ex5.plotInfoScatter('Age', 'reactionTime', ...
    'FitLine', true, 'ErrorBand', true, ...
    'XLabel', 'Age (years)', ...
    'YLabel', 'Reaction Time (ms)', ...
    'Title', 'Age vs RT by Group');
% fig = ex5.plotInfoScatter('Age', 'reactionTime', ...
%     'FitLine', true, 'ErrorBand', true, ...
%     'XLabel', 'Age (years)', ...
%     'YLabel', 'Reaction Time (ms)', ...
%     'Title', 'Age vs RT by Group', ...
%     'Visible', 'off', 'SavePath', fullfile(outDir, 'ex5_age_vs_rt.png'));
% close(fig);

% Scatter without grouping, with error band
ex5.reset();
ex5.select('Condition', {'Easy', 'Hard'});
fig = ex5.plotInfoScatter('reactionTime', 'accuracy', ...
    'FitLine', true, 'ErrorBand', true, ...
    'XLabel', 'RT (ms)', ...
    'YLabel', 'Accuracy', ...
    'Title', 'Speed-Accuracy Tradeoff (all subjects)');
% fig = ex5.plotInfoScatter('reactionTime', 'accuracy', ...
%     'FitLine', true, 'ErrorBand', true, ...
%     'XLabel', 'RT (ms)', ...
%     'YLabel', 'Accuracy', ...
%     'Title', 'Speed-Accuracy Tradeoff (all subjects)', ...
%     'Visible', 'off', 'SavePath', fullfile(outDir, 'ex5_speed_accuracy.png'));
% close(fig);

% Export the full info table for external analysis (R, Python, etc.)
T = ex5.infoTable();
% writetable(T, fullfile(outDir, 'ex5_metadata.csv'));
fprintf('Info table: %d rows x %d cols\n', height(T), width(T));

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
% writetable(longT, fullfile(outDir, 'ex6_long.csv'));
fprintf('Long table: %d rows x %d cols\n', height(longT), width(longT));

% Wide format (for SPSS, Excel)
wideT = ex6.toWideTable({'HbO'}, 1:5);
% writetable(wideT, fullfile(outDir, 'ex6_wide.csv'));
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
    'Title', 'Accelerometer: Easy vs Hard');
% fig = ex7.plotAux('accelerometer', ...
%     'Layout', 'grid', ...
%     'Title', 'Accelerometer: Easy vs Hard', ...
%     'Visible', 'off', 'SavePath', fullfile(outDir, 'ex7_accel_grid.png'));
% close(fig);

% Heart rate (single channel) with error bands
fig = ex7.plotAux('heartRate', ...
    'ErrorType', 'SEM', ...
    'Title', 'Heart Rate: Easy vs Hard');
% fig = ex7.plotAux('heartRate', ...
%     'ErrorType', 'SEM', ...
%     'Title', 'Heart Rate: Easy vs Hard', ...
%     'Visible', 'off', 'SavePath', fullfile(outDir, 'ex7_heartrate.png'));
% close(fig);

% Bar chart: mean heart rate in 5-20s window
fig = ex7.plotAuxBar('heartRate', ...
    'TimeWindow', [5, 20], 'ShowIndividual', true, ...
    'Title', 'Mean Heart Rate: Easy vs Hard (5-20s)');
% fig = ex7.plotAuxBar('heartRate', ...
%     'TimeWindow', [5, 20], 'ShowIndividual', true, ...
%     'Title', 'Mean Heart Rate: Easy vs Hard (5-20s)', ...
%     'Visible', 'off', 'SavePath', fullfile(outDir, 'ex7_heartrate_bar.png'));
% close(fig);

% Accelerometer bar chart (all axes)
fig = ex7.plotAuxBar('accelerometer', ...
    'TimeWindow', [5, 20], ...
    'Title', 'Mean Accelerometer: Easy vs Hard (5-20s)');
% fig = ex7.plotAuxBar('accelerometer', ...
%     'TimeWindow', [5, 20], ...
%     'Title', 'Mean Accelerometer: Easy vs Hard (5-20s)', ...
%     'Visible', 'off', 'SavePath', fullfile(outDir, 'ex7_accel_bar.png'));
% close(fig);

% Export with Aux columns included
longAux = ex7.toLongTable({'HbO'}, 1:3, [], 'IncludeAux', true);
fprintf('Long table with Aux: %d rows x %d cols\n', height(longAux), width(longAux));
fprintf('Columns: %s\n', strjoin(longAux.Properties.VariableNames(1:min(12,width(longAux))), ', '));

fprintf('\n');

%% Example 8: fNIRS Scatter (info variable vs biomarker)
%
% Scatter plot correlating a behavioral variable with fNIRS channel data.
% This is different from plotInfoScatter (which plots two info vars against
% each other) - plotScatter correlates an info var vs actual fNIRS data.

fprintf('=== Example 8: fNIRS scatter (behavior vs HbO) ===\n');

ex8 = exploreFNIRS.core.Experiment(allData);
ex8.select('Condition', {'Easy', 'Hard'});
ex8.groupby({'Condition'});
ex8.settings.resampleRate = 1;
ex8.settings.barBinSize = 10;
ex8.settings.taskEnd = 10;
ex8.settings.useBaseline = false;
ex8.aggregate();

% Single channel scatter: reaction time vs HbO
% 'Averaging','hierarchy' (default) averages within each subject first
[fig, stats] = ex8.plotScatter('reactionTime', ...
    'Biomarkers', {'HbO'}, 'Channels', 1, ...
    'FitLine', true, 'ErrorBand', true, ...
    'Title', 'RT vs HbO (Channel 1)');
% [fig, stats] = ex8.plotScatter('reactionTime', ...
%     'Biomarkers', {'HbO'}, 'Channels', 1, ...
%     'FitLine', true, 'ErrorBand', true, ...
%     'Title', 'RT vs HbO (Channel 1)', ...
%     'Visible', 'off', 'SavePath', fullfile(outDir, 'ex8_scatter_fnirs.png'));
% close(fig);

% Multi-channel scatter with error bands
[fig, ~] = ex8.plotScatter('reactionTime', ...
    'Biomarkers', {'HbO'}, 'Channels', [1, 3, 5], ...
    'FitLine', true, 'ErrorBand', true, 'CorrType', 'Spearman', ...
    'Title', 'RT vs HbO (Spearman)');
% [fig, ~] = ex8.plotScatter('reactionTime', ...
%     'Biomarkers', {'HbO'}, 'Channels', [1, 3, 5], ...
%     'FitLine', true, 'ErrorBand', true, 'CorrType', 'Spearman', ...
%     'Title', 'RT vs HbO (Spearman)', ...
%     'Visible', 'off', 'SavePath', fullfile(outDir, 'ex8_scatter_multi.png'));
% close(fig);

fprintf('  Scatter stats (Ch1): r=%.3f, p=%.4f, N=%d\n', ...
    stats(1,1,1).r, stats(1,1,1).p, stats(1,1,1).N);

fprintf('\n');

%% Example 9: LME analysis with full stats pipeline
%
% Linear Mixed Effects model on fNIRS channel data.
% Demonstrates: plotLME for visualization, then the pure stats pipeline
% (statsFitLME → statsRunContrasts → statsSummarize) for publication tables.

fprintf('=== Example 9: fNIRS LME analysis ===\n');

ex9 = exploreFNIRS.core.Experiment(allData);
ex9.select('Condition', {'Easy', 'Hard'});
ex9.groupby({'Condition'});
ex9.settings.resampleRate = 1;
ex9.settings.barBinSize = 10;
ex9.settings.taskEnd = 10;
ex9.settings.useBaseline = false;
ex9.aggregate();

% 9a. Visual LME (bar chart + model)
[fig, results] = ex9.plotLME('Biomarkers', {'HbO'}, 'Channels', [1, 2, 3]);
% [fig, results] = ex9.plotLME('Biomarkers', {'HbO'}, 'Channels', [1, 2, 3], ...
%     'Visible', 'off', 'SavePath', fullfile(outDir, 'ex9_lme_bar.png'));
% if ~isempty(fig), close(fig); end

fprintf('  Formula: %s\n', results.formula);
fprintf('  ANOVA p-values:\n');
disp(results.anova_pval);

% 9b. Pure stats path (no plot)
lmeResults = ex9.statsFitLME('Biomarkers', {'HbO'}, 'Channels', 1:3);
fprintf('  statsFitLME: %d models fitted\n', numel(lmeResults.models));

% Post-hoc contrasts with FDR correction
contrastResults = ex9.statsRunContrasts(lmeResults);
fprintf('  statsRunContrasts: FDR-corrected across channels\n');

% Publication-ready summary tables
anovaT = ex9.statsSummarize(lmeResults, 'Type', 'anova');
fprintf('  ANOVA summary (%d rows):\n', height(anovaT));
disp(anovaT);

contrastT = ex9.statsSummarize(contrastResults, 'Type', 'contrasts');
fprintf('  Contrast summary (%d rows):\n', height(contrastT));
disp(contrastT);

fprintf('\n');

%% Example 10: LME on behavioral / info variables
%
% statsInfoLME fits a single LME model using a behavioral variable as the
% response. Unlike statsFitLME (which iterates over fNIRS channels), this
% fits one model. Only requires groupby() - no aggregate() needed.

fprintf('=== Example 10: Info variable LME (behavioral stats) ===\n');

ex10 = exploreFNIRS.core.Experiment(allData);
ex10.select('Condition', {'Easy', 'Hard'});  % exclude Rest (NaN RT)
ex10.groupby({'Condition'});

% Reaction time ~ Condition + (1|SubjectID)
rtResults = ex10.statsInfoLME('reactionTime');
fprintf('  RT formula: %s\n', rtResults.formula);
fprintf('  RT AIC: %.1f\n', rtResults.AIC);
fprintf('  RT ANOVA p-values:\n');
disp(rtResults.anova_pval);

% Accuracy with interaction model (Group x Condition)
ex10.groupby({'Group', 'Condition'});
accResults = ex10.statsInfoLME('accuracy', 'AllInteractions', true);
fprintf('  Accuracy formula: %s\n', accResults.formula);
fprintf('  Accuracy ANOVA p-values:\n');
disp(accResults.anova_pval);

% Summarize for publication
anovaT = ex10.statsSummarize(rtResults, 'Type', 'anova');
fprintf('  RT ANOVA summary:\n');
disp(anovaT);

fprintf('\n');

%% Example 11: LME on auxiliary signals (heart rate, accelerometer)
%
% statsAuxLME runs channel-wise LME on auxiliary data (same pattern as
% statsFitLME but on Aux fields instead of fNIRS biomarkers).
% Requires aggregate() since Aux data flows through the grand average pipeline.

fprintf('=== Example 11: Auxiliary signal LME ===\n');

ex11 = exploreFNIRS.core.Experiment(allData);
ex11.select('Condition', {'Easy', 'Hard'});
ex11.groupby({'Condition'});
ex11.settings.resampleRate = 2;
ex11.settings.barBinSize = 10;
ex11.settings.useBaseline = false;
ex11.aggregate();

% Heart rate LME (single channel)
hrResults = ex11.statsAuxLME('heartRate');
fprintf('  Heart rate formula: %s\n', hrResults.formula);
fprintf('  Heart rate ANOVA p-values:\n');
disp(hrResults.anova_pval);

% Accelerometer LME (multi-channel: x, y, z axes)
accelResults = ex11.statsAuxLME('accelerometer');
fprintf('  Accelerometer: %d channel models\n', size(accelResults.models, 2));
fprintf('  Accelerometer ANOVA p-values:\n');
disp(accelResults.anova_pval);

% Full pipeline: contrasts + summary
contrastResults = ex11.statsRunContrasts(hrResults);
summaryT = ex11.statsSummarize(hrResults, 'Type', 'anova');
fprintf('  Heart rate ANOVA summary:\n');
disp(summaryT);

fprintf('\n');

%% Example 12: Topographic LME (3D brain surface)
%
% plotTopoLME projects LME F-statistics onto the 3D brain surface using
% interpolateValues3D. All channels are shown with a continuous colormap.
% Each biomarker gets its own row; ANOVA terms are columns.

fprintf('=== Example 12: Topographic LME (3D brain projection) ===\n');

ex12 = exploreFNIRS.core.Experiment(allData);
ex12.select('Condition', {'Easy', 'Hard'});
ex12.groupby({'Condition'});
ex12.settings.resampleRate = 1;
ex12.settings.taskEnd = 10;
ex12.settings.barBinSize = 0;
ex12.settings.useBaseline = false;
ex12.aggregate();

% 12a. Single biomarker topo (HbO only)
[fig, topoResults] = ex12.plotTopoLME('Biomarkers', {'HbO'});
% [fig, topoResults] = ex12.plotTopoLME('Biomarkers', {'HbO'}, ...
%     'Visible', 'off', 'SavePath', fullfile(outDir, 'ex12_topo_hbo.png'));
% close(fig);
fprintf('  HbO topo: %d sig channels\n', sum(topoResults.sigMasks{1}(:)));

% 12b. Multi-biomarker topo (HbO + HbR rows)
[fig, ~] = ex12.plotTopoLME('Biomarkers', {'HbO', 'HbR'});
% [fig, ~] = ex12.plotTopoLME('Biomarkers', {'HbO', 'HbR'}, ...
%     'Visible', 'off', 'SavePath', fullfile(outDir, 'ex12_topo_multi.png'));
% close(fig);

% 12c. With FDR correction
[fig, ~] = ex12.plotTopoLME('Biomarkers', {'HbO'}, ...
    'SigType', 'q', 'SigThreshold', 0.05);
% [fig, ~] = ex12.plotTopoLME('Biomarkers', {'HbO'}, ...
%     'SigType', 'q', 'SigThreshold', 0.05, ...
%     'Visible', 'off', 'SavePath', fullfile(outDir, 'ex12_topo_fdr.png'));
% close(fig);

% 12d. P-value topo (-log10 scale)
[fig, ~] = ex12.plotTopoLME('Biomarkers', {'HbO'}, ...
    'PlotMetric', 'p');
% [fig, ~] = ex12.plotTopoLME('Biomarkers', {'HbO'}, ...
%     'PlotMetric', 'p', ...
%     'Visible', 'off', 'SavePath', fullfile(outDir, 'ex12_topo_pval.png'));
% close(fig);

fprintf('\n');

%% Example 13: ROI-level analysis
%
% Define ROIs (regions of interest), aggregate channels within ROIs, then
% run the full analysis pipeline at the ROI level instead of per-channel.

fprintf('=== Example 13: ROI-level analysis ===\n');

% Add ROI definitions to each segment (3 ROIs of ~6 channels each)
% optodeList must be a column cell array
nCh = size(allData{1}.HbO, 2);
roiSize = floor(nCh / 3);
roiDef = {1:roiSize; roiSize+1:2*roiSize; 2*roiSize+1:nCh};
roiNames = {'Left_PFC', 'Center_PFC', 'Right_PFC'};
for i = 1:length(allData)
    allData{i} = pf2.probe.roi.defineROI(allData{i}, roiDef, roiNames);
    allData{i} = pf2_build_nanmean_ROI(allData{i});
end

ex13 = exploreFNIRS.core.Experiment(allData);
ex13.select('Condition', {'Easy', 'Hard'});
ex13.groupby({'Condition'});
ex13.settings.resampleRate = 1;
ex13.settings.taskEnd = 30;
ex13.settings.barBinSize = 0;   % single bar (full task window)
ex13.settings.useBaseline = true;
ex13.settings.baseline = [-5, 0];
ex13.aggregate();

% ROI temporal plot
fig = ex13.plotTemporal('Biomarkers', {'HbO'}, 'ROIs', 'all', ...
    'Title', 'ROI HbO: Easy vs Hard');
% fig = ex13.plotTemporal('Biomarkers', {'HbO'}, 'ROIs', 'all', ...
%     'Title', 'ROI HbO: Easy vs Hard', ...
%     'Visible', 'off', 'SavePath', fullfile(outDir, 'ex13_roi_temporal.png'));
% close(fig);

% ROI bar chart
fig = ex13.plotBar('Biomarker', 'HbO', 'ROIs', 'all', ...
    'ShowIndividual', true, ...
    'Title', 'ROI Mean HbO: Easy vs Hard');
% fig = ex13.plotBar('Biomarker', 'HbO', 'ROIs', 'all', ...
%     'ShowIndividual', true, ...
%     'Title', 'ROI Mean HbO: Easy vs Hard', ...
%     'Visible', 'off', 'SavePath', fullfile(outDir, 'ex13_roi_bar.png'));
% close(fig);

% ROI heatmap
fig = ex13.plotHeatmap('Biomarker', 'HbO', 'ROIs', 'all', ...
    'Title', 'ROI HbO Heatmap');
% fig = ex13.plotHeatmap('Biomarker', 'HbO', 'ROIs', 'all', ...
%     'Title', 'ROI HbO Heatmap', ...
%     'Visible', 'off', 'SavePath', fullfile(outDir, 'ex13_roi_heatmap.png'));
% close(fig);

% ROI LME
[fig, results] = ex13.plotLME('Biomarkers', {'HbO'}, 'DataType', 'ROI');
% [fig, results] = ex13.plotLME('Biomarkers', {'HbO'}, 'DataType', 'ROI', ...
%     'Visible', 'off', 'SavePath', fullfile(outDir, 'ex13_roi_lme.png'));
% if ~isempty(fig), close(fig); end
fprintf('ROI LME ANOVA:\n');
disp(results.anova_pval);

% ROI topo LME (3D brain surface with ROI-level F-statistics)
[fig, ~] = ex13.plotTopoROILME('Biomarkers', {'HbO'});
% [fig, ~] = ex13.plotTopoROILME('Biomarkers', {'HbO'}, ...
%     'Visible', 'off', 'SavePath', fullfile(outDir, 'ex13_roi_topo.png'));
% close(fig);

% ROI scatter
[fig, ~] = ex13.plotScatter('reactionTime', ...
    'Biomarkers', {'HbO'}, 'ROIs', 'all', ...
    'FitLine', true, 'ErrorBand', true, ...
    'Title', 'RT vs ROI HbO');
% [fig, ~] = ex13.plotScatter('reactionTime', ...
%     'Biomarkers', {'HbO'}, 'ROIs', 'all', ...
%     'FitLine', true, 'ErrorBand', true, ...
%     'Title', 'RT vs ROI HbO', ...
%     'Visible', 'off', 'SavePath', fullfile(outDir, 'ex13_roi_scatter.png'));
% close(fig);

% ROI stats (no plot)
roiResults = ex13.statsROILME('Biomarkers', {'HbO'});
fprintf('ROI statsROILME: %d models fitted\n', numel(roiResults.models));

% Export with ROIs
T = ex13.toLongTable({'HbO'}, [], [], 'IncludeROI', true);
% writetable(T, fullfile(outDir, 'ex13_roi_long.csv'));
fprintf('ROI export: %d rows x %d cols\n', height(T), width(T));

fprintf('\n');

%% Example 14: Hierarchical ColorScheme with Named Presets
%
% ColorScheme assigns base colors to one factor and modifier effects to
% another, giving every factor combination a distinct, meaningful color.
%
% Named presets let you store multiple schemes on the Experiment and
% switch between them per-plot via the 'ColorScheme' parameter.

fprintf('=== Example 14: Hierarchical ColorScheme with Named Presets ===\n');

ex14 = exploreFNIRS.core.Experiment(allData);
ex14.select('Condition', {'Easy','Hard'});
ex14.groupby({'Group','Condition'});
ex14.aggregate();

% Define two color perspectives:

% "byGroup": Group = base colors, Condition = modifiers
csGroup = exploreFNIRS.core.ColorScheme();
csGroup = csGroup.set('Group', 'Patient', [0.85, 0.2, 0.2]);
csGroup = csGroup.set('Group', 'Healthy', [0.2, 0.65, 0.3]);
csGroup = csGroup.set('Condition', 'Easy', 'lighten', 0.25);
csGroup = csGroup.set('Condition', 'Hard', 'darken', 0.15);

% "byCondition": Condition = base colors, Group = modifiers
csCond = exploreFNIRS.core.ColorScheme();
csCond = csCond.set('Condition', 'Easy', [0.3, 0.6, 0.9]);
csCond = csCond.set('Condition', 'Hard', [0.85, 0.2, 0.2]);
csCond = csCond.set('Group', 'Patient', 'darken', 0.15);
csCond = csCond.set('Group', 'Healthy', 'lighten', 0.15);

% Register named presets on the Experiment
ex14.addColorScheme('byGroup', csGroup);
ex14.addColorScheme('byCondition', csCond);

% Set default active scheme
ex14.useColorScheme('byGroup');

% Bar chart with default scheme (byGroup)
fig = ex14.plotBar('Biomarker', 'HbO', 'Channels', 1:4, ...
    'TimeWindow', [5, 20]);
% fig = ex14.plotBar('Biomarker', 'HbO', 'Channels', 1:4, ...
%     'TimeWindow', [5, 20], ...
%     'Visible', 'off', 'SavePath', fullfile(outDir, 'ex14_bygroup_bar.png'));
% close(fig);
fprintf('  Bar chart with byGroup scheme (default)\n');

% Temporal plot with default scheme
fig = ex14.plotTemporal('Biomarkers', {'HbO'}, 'Channels', 1:4);
% fig = ex14.plotTemporal('Biomarkers', {'HbO'}, 'Channels', 1:4, ...
%     'Visible', 'off', 'SavePath', fullfile(outDir, 'ex14_bygroup_temporal.png'));
% close(fig);
fprintf('  Temporal plot with byGroup scheme\n');

% Per-plot switch to byCondition (default remains byGroup)
fig = ex14.plotBar('Biomarker', 'HbO', 'Channels', 1:4, ...
    'TimeWindow', [5, 20], 'ColorScheme', 'byCondition');
% fig = ex14.plotBar('Biomarker', 'HbO', 'Channels', 1:4, ...
%     'TimeWindow', [5, 20], 'ColorScheme', 'byCondition', ...
%     'Visible', 'off', 'SavePath', fullfile(outDir, 'ex14_bycondition_bar.png'));
% close(fig);
fprintf('  Bar chart with byCondition scheme (per-plot)\n');

% PlotProxy also supports 'ColorScheme' parameter
fig = ex14.plot.bar('X', 'Condition', 'Color', 'Group', ...
    'Channels', 1:4, 'ColorScheme', 'byCondition');
% fig = ex14.plot.bar('X', 'Condition', 'Color', 'Group', ...
%     'Channels', 1:4, 'ColorScheme', 'byCondition', ...
%     'SavePath', fullfile(outDir, 'ex14_proxy_bycondition.png'));
% close(fig);
fprintf('  PlotProxy bar with byCondition scheme\n');

% PlotProxy with default scheme (auto-injected from Experiment)
fig = ex14.plot.bar('X', 'Condition', 'Color', 'Group', ...
    'Channels', 1:4);
% fig = ex14.plot.bar('X', 'Condition', 'Color', 'Group', ...
%     'Channels', 1:4, 'SavePath', fullfile(outDir, 'ex14_proxy_default.png'));
% close(fig);
fprintf('  PlotProxy bar with default scheme\n');

% Explicit Colors override takes precedence over both
fig = ex14.plotBar('Biomarker', 'HbO', 'Channels', 1:4, ...
    'Colors', [1 0 0; 0 0 1; 0.5 0 0; 0 0 0.5]);
% fig = ex14.plotBar('Biomarker', 'HbO', 'Channels', 1:4, ...
%     'Colors', [1 0 0; 0 0 1; 0.5 0 0; 0 0 0.5], ...
%     'Visible', 'off', 'SavePath', fullfile(outDir, 'ex14_override.png'));
% close(fig);
fprintf('  Bar with explicit Colors override\n');

fprintf('\n');

%% Example 15: Non-parametric permutation test (small-N)
%
% For small sample sizes (N=5-7), LME assumptions may not hold.
% statsPermTest provides a sign-flip permutation test for paired
% 2-condition comparisons with exact or Monte Carlo enumeration.

fprintf('=== Example 15: Permutation Test ===\n');

ex15 = exploreFNIRS.core.Experiment(allData);
ex15.select('Condition', {'Easy', 'Hard'});
ex15.groupby({'Condition'});
ex15.settings.barBinSize = 0;
ex15.settings.taskEnd = 30;
ex15.aggregate();

% Permutation test with 1000 random sign-flips
permResults = ex15.statsPermTest('Biomarkers', {'HbO'}, ...
    'NumPerm', 1000, 'Statistic', 'tstat');

fprintf('  Channels tested: %d\n', length(permResults.channels));
fprintf('  Exact enumeration: %s\n', string(permResults.isExact));
fprintf('  Significant channels (FDR < 0.05): %d\n', ...
    sum(permResults.significant(1,:)));

% One-tailed test (Easy > Hard)
permRight = ex15.statsPermTest('Biomarkers', {'HbO'}, ...
    'NumPerm', 1000, 'Tail', 'right');
fprintf('  Right-tail significant: %d\n', sum(permRight.significant(1,:)));

fprintf('\n');

%% Example 16: Effect size with bootstrap CIs
%
% Hedges' g (bias-corrected Cohen's d) with bootstrap confidence
% intervals. Essential for reporting effect magnitudes alongside
% p-values in small-N studies.

fprintf('=== Example 16: Effect Size + Bootstrap CIs ===\n');

% Reuse ex15 (already aggregated with 2 conditions)
esResults = ex15.statsEffectSize('Biomarkers', {'HbO'}, ...
    'Method', 'hedges_g', 'NumBoot', 2000);

fprintf('  Method: %s\n', esResults.method);
fprintf('  Channel 1: g = %.2f [%.2f, %.2f]\n', ...
    esResults.observed(1,1), esResults.ci_lower(1,1), esResults.ci_upper(1,1));

% Cohen's d (without bias correction)
esCohen = ex15.statsEffectSize('Biomarkers', {'HbO'}, ...
    'Method', 'cohens_d', 'NumBoot', 1000);
fprintf('  Cohen''s d ch1: %.2f\n', esCohen.observed(1,1));

fprintf('\n');

%% Example 17: Custom contrast matrices
%
% Instead of auto-generated pairwise contrasts, specify planned
% comparisons using buildContrasts() or manual contrast matrices.

fprintf('=== Example 17: Custom Contrast Matrices ===\n');

ex17 = exploreFNIRS.core.Experiment(allData);
ex17.select('Condition', {'Easy', 'Hard'});
ex17.groupby({'Condition'});
ex17.settings.barBinSize = 0;
ex17.settings.taskEnd = 30;
ex17.aggregate();

lmeResults = ex17.statsFitLME('Biomarkers', {'HbO'}, 'Channels', 1:3);

% Build standard contrast types from fitted model
mdl = lmeResults.models{1,1};
specPairwise = exploreFNIRS.stats.buildContrasts(mdl, 'pairwise');
fprintf('  Pairwise contrasts: %d\n', size(specPairwise.matrix, 1));

% Run the contrasts with FDR correction across channels
cr = ex17.statsRunContrasts(lmeResults, 'Contrasts', specPairwise);
fprintf('  Contrast names: %s\n', strjoin(cr.contrastNames, ', '));

% Manual contrast matrix: test Condition_Hard effect directly
spec.matrix = [0, 1];
spec.labels = {'Hard vs Easy'};
crManual = ex17.statsRunContrasts(lmeResults, 'Contrasts', spec);
fprintf('  Manual contrast p-value (ch1): %.4f\n', crManual.pvalueMatrix(1,1,1));

fprintf('\n');

%% Example 18: Experiment.fromConfig (declarative pipeline)
%
% fromConfig collapses import → process → blocks → Experiment into
% a single call using a config struct. This eliminates boilerplate
% and makes analysis scripts reproducible and shareable.

fprintf('=== Example 18: Experiment.fromConfig ===\n');

% Using pre-loaded data (simplest case)
cfg.data = allData;
cfg.experiment.baseline = [-5, 0];
cfg.experiment.taskEnd = 30;
cfg.experiment.barBinSize = 5;
cfg.experiment.avgMode = 'hierarchy';
cfg.experiment.statWindow = [5, 25];
cfg.experiment.hierarchy = {'SubjectID', 'Condition'};

ex18 = exploreFNIRS.core.Experiment.fromConfig(cfg);
fprintf('  Created experiment with %d segments\n', length(ex18.data));
fprintf('  StatWindow: [%.0f, %.0f]\n', ex18.settings.statWindow);

% For file-based import (uncomment and adjust paths):
% cfg2.import.dir = 'data/experiment1';
% cfg2.import.pattern = '*.snirf';
% cfg2.import.dirMapping = {'Dir1', 'Group', 'Dir2', 'SubjectID'};
% cfg2.metadata.file = 'demographics.csv';
% cfg2.metadata.key = 'SubjectID';
% cfg2.process = struct();           % use default processing
% cfg2.blocks.markerCodes = [10, 20];
% cfg2.blocks.duration = 30;
% cfg2.blocks.conditionMap = {'Easy', 'Hard'};
% cfg2.experiment.baseline = [-5, 0];
% cfg2.experiment.taskEnd = 30;
% ex = exploreFNIRS.core.Experiment.fromConfig(cfg2);

fprintf('\n');

%% Example 19: Stats formatting for publication
%
% statsSummarize formats LME, contrast, and correlation results into
% publication-ready tables. Four output formats are available:
%   'table'   - Standard MATLAB table (default, for programmatic use)
%   'console' - Clean aligned text printed to command window
%   'latex'   - LaTeX tabular environment with booktabs (copy into paper)
%   'apa'     - Adds APA-formatted string column (e.g., "F(1, 22) = 5.67, p = .012")
%
% All five Type options work with all four Format options:
%   'anova', 'contrasts', 'coefficients', 'fit', 'correlations'

fprintf('=== Example 19: Stats formatting for publication ===\n');

% Reuse ex9 from Example 9 (LME on Easy vs Hard)
lmeResults = ex9.statsFitLME('Biomarkers', {'HbO'}, 'Channels', 1:3);
contrastResults = ex9.statsRunContrasts(lmeResults);

% 19a. ANOVA — four output formats
fprintf('--- 19a. ANOVA: console format ---\n');
ex9.statsSummarize(lmeResults, 'Type', 'anova', 'Format', 'console');

fprintf('--- 19a. ANOVA: APA format ---\n');
T = ex9.statsSummarize(lmeResults, 'Type', 'anova', 'Format', 'apa');
disp(T(:, {'Channel','Term','APA'}));

fprintf('--- 19a. ANOVA: LaTeX format ---\n');
ex9.statsSummarize(lmeResults, 'Type', 'anova', 'Format', 'latex');

% 19b. Contrasts — console and LaTeX
fprintf('--- 19b. Contrasts: console format ---\n');
ex9.statsSummarize(contrastResults, 'Type', 'contrasts', 'Format', 'console');

fprintf('--- 19b. Contrasts: LaTeX format ---\n');
ex9.statsSummarize(contrastResults, 'Type', 'contrasts', 'Format', 'latex');

% 19c. Fixed-effect coefficients
fprintf('--- 19c. Coefficients: console format ---\n');
ex9.statsSummarize(lmeResults, 'Type', 'coefficients', 'Format', 'console');

% 19d. Model fit statistics
fprintf('--- 19d. Model fit: console format ---\n');
ex9.statsSummarize(lmeResults, 'Type', 'fit', 'Format', 'console');

% 19e. Correlation stats (from plotScatter)
fprintf('--- 19e. Correlations: console format ---\n');
[~, corrStats] = ex9.plotScatter('reactionTime', ...
    'Biomarkers', {'HbO'}, 'Channels', 1:3, 'Visible', 'off');
ex9.statsSummarize(corrStats, 'Type', 'correlations', ...
    'Format', 'console', ...
    'Channels', 1:3, 'Biomarkers', {'HbO'});

fprintf('--- 19e. Correlations: APA format (Spearman) ---\n');
T = ex9.statsSummarize(corrStats, 'Type', 'correlations', ...
    'Format', 'apa', 'CorrType', 'Spearman', ...
    'Channels', 1:3, 'Biomarkers', {'HbO'});
disp(T(:, {'Channel','APA'}));

fprintf('--- 19e. Correlations: LaTeX format ---\n');
ex9.statsSummarize(corrStats, 'Type', 'correlations', ...
    'Format', 'latex', ...
    'Channels', 1:3, 'Biomarkers', {'HbO'});

% 19f. Export to file
% Any table-format result can be saved to CSV or Excel:
%   T = ex9.statsSummarize(lmeResults, 'Type', 'anova');
%   writetable(T, 'anova_results.csv');
%   writetable(T, 'anova_results.xlsx');

fprintf('\n');

%% Example 20: Demographics table (Table 1)
%
% Publication-style "Table 1" summarizing participant characteristics at the
% subject level. Automatically deduplicates segments to count each subject
% once. Between-subject grouping adds a statistics column; within-subject
% grouping (e.g., Condition) omits it.
%
fprintf('=== Example 20: Demographics Table ===\n');

% Use the full experiment data (all 24 segments, 4 subjects)
ex20 = exploreFNIRS.core.Experiment(allData);

% 20a. No grouping - simple summary
fprintf('--- 20a. Overall demographics ---\n');
T = ex20.demographicsTable('Variables', {'Age', 'Group'});
disp(T);

% 20b. Between-subject grouping with stats (Group is constant within subject)
fprintf('--- 20b. By Group (between-subject, with stats) ---\n');
ex20.demographicsTable('Variables', {'Age'}, ...
    'GroupBy', 'Group', 'Format', 'console');

% 20c. Within-subject grouping (Condition varies within subject, no stats)
fprintf('--- 20c. By Condition (within-subject, no stats) ---\n');
ex20.demographicsTable('Variables', {'Age', 'Group'}, ...
    'GroupBy', 'Condition', 'Format', 'console');

% 20d. Percentage-only format for categorical variables
fprintf('--- 20d. Percent-only categorical display ---\n');
ex20.demographicsTable('Variables', {'Age', 'Group'}, ...
    'GroupBy', 'Condition', 'Format', 'console', ...
    'CategoricalFormat', 'percent');

% 20e. Custom display labels
fprintf('--- 20e. Custom labels ---\n');
ex20.demographicsTable('Variables', {'Age', 'Group'}, ...
    'GroupBy', 'Group', 'Format', 'console', ...
    'Labels', struct('Age', 'Age (years)', 'Group', 'Cohort'));

% 20f. LaTeX output
fprintf('--- 20f. LaTeX format ---\n');
ex20.demographicsTable('Variables', {'Age', 'Group'}, ...
    'GroupBy', 'Group', 'Format', 'latex');

fprintf('\n');

%% Summary
fprintf('\n=== All examples complete ===\n');


%% Open explore fnirs

exploreFNIRS(ex11)
