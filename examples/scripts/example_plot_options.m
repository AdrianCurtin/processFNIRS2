%% example_plot_options.m - Configuring exploreFNIRS plot options
%
% This script demonstrates the configurable options for each plot type
% in the exploreFNIRS group analysis workflow:
%
%   1. Setup: build a synthetic multi-subject dataset
%   2. plotTemporal: error bands, biomarker selection, PlotBy, layout
%   3. plotBar: error types, individual data points, clustered bars
%   4. plotScatter: correlation types, error bands, topo maps, stats
%   5. plotHeatmap: colormaps, sorting, color limits
%   6. plotTopo: time snapshots, interpolation, per-group layout
%   7. plotLME: F-statistics, significance thresholds, topo overlay
%   8. plotComposite: multi-panel publication figures
%   9. Color customization: ColorScheme, palettes, manual RGB
%  10. Saving and headless mode
%
% All examples use the Experiment class wrapper. The underlying
% standalone functions (exploreFNIRS.core.plotTemporal, etc.) accept
% the same name-value parameters.
%
% Requirements:
%   - processFNIRS2 on the MATLAB path
%   - Sample data: pf2.import.sampleData.fNIR2000()

outDir = fullfile(tempdir, 'pf2_plot_options');
if ~exist(outDir, 'dir'), mkdir(outDir); end


%% ========================================================================
%  1. SETUP: BUILD SYNTHETIC DATASET
%  ========================================================================
%
%  We need a multi-subject dataset with group/condition labels and a
%  numeric info variable to demonstrate all plot types. This section
%  builds one from sample data -- skip ahead to Section 2 if you're
%  interested in the plot options themselves.

fprintf('=== 1. Setup ===\n');

raw = pf2.import.sampleData.fNIR2000();
processed = processFNIRS2(raw, ...
    'DPFmode', 'Calc', 'defaultSubjectAge', 25, ...
    'blLength', 10, 'blStartTime', 0);

% Inject synthetic markers: alternating Task (10) and Rest (20)
processed.markers = [
     60, 10, 0, 1;   % Task at 60s
    120, 20, 0, 1;   % Rest at 120s
    180, 10, 0, 1;   % Task at 180s
    240, 20, 0, 1;   % Rest at 240s
    300, 10, 0, 1;   % Task at 300s
    360, 20, 0, 1;   % Rest at 360s
];

blocks = pf2.data.defineBlocks(processed, ...
    'MarkerCode', [10, 20], 'Duration', 30, ...
    'ConditionMap', {10, 'Task'; 20, 'Rest'}, ...
    'Embed', false);
segments = pf2.data.extractBlocks(processed, blocks, ...
    'PreTime', 120, 'PostTime', 120, 'BaselineWindow', [-5, 0], 'SetT0', true);

% Build 6 synthetic subjects (3 Young, 3 Older)
rng(42);
allSegments = {};
subjects = {'S01','S02','S03','S04','S05','S06'};
groups   = {'Young','Young','Young','Older','Older','Older'};
ages     = [22, 24, 21, 55, 60, 58];
scores   = [85, 92, 78, 70, 65, 72];

for s = 1:length(subjects)
    for i = 1:length(segments)
        seg = segments{i};
        seg.info.SubjectID = subjects{s};
        seg.info.Group     = groups{s};
        seg.info.Age       = ages(s);
        seg.info.Score     = scores(s) + randn * 5;

        % Add subject/group-specific noise so groups differ
        noise = 0.05 * randn(size(seg.HbO));
        if strcmp(groups{s}, 'Older')
            seg.HbO = seg.HbO * 0.7 + noise;
            seg.HbR = seg.HbR * 0.8 - noise * 0.5;
        else
            seg.HbO = seg.HbO + noise;
            seg.HbR = seg.HbR - noise * 0.5;
        end
        allSegments{end+1} = seg; %#ok<SAGROW>
    end
end

% Create Experiment
ex = exploreFNIRS.core.Experiment(allSegments, ...
    'Hierarchy', {'SubjectID', 'Condition'});
ex.settings.baseline     = [-5, 0];
ex.settings.taskStart    = 0;
ex.settings.taskEnd      = 30;
ex.settings.resampleRate = 1;
ex.settings.barBinSize   = 0;
ex.settings.useBaseline  = true;
ex.settings.avgMode      = 'hierarchy';

fprintf('  Built dataset: %d subjects, %d segments\n', ...
    length(subjects), length(allSegments));


%% ========================================================================
%  2. TEMPORAL PLOTS
%  ========================================================================
%
%  plotTemporal shows group-averaged hemodynamic time courses with error
%  bands. Key options:
%
%    ErrorType   - 'SEM' (default), 'SD', or 'none'
%    Biomarkers  - which biomarkers to show
%    Channels    - which channels to plot (default: all)
%    ROIs        - plot ROI data instead of channels
%    PlotBy      - split plots by a groupby variable
%    ShowN       - show n=X in legend labels
%    Legend      - 'last', 'first', 'all', 'none'
%    YLim, XLim  - fix axis limits across subplots

fprintf('\n=== 2. Temporal Plots ===\n');

% Group by Condition first
ex.select('Condition', {'Task', 'Rest'});
ex.groupby({'Condition'});
ex.aggregate();

% --- 2a: Default temporal plot (SEM error bands, HbO + HbR) ---
fig = ex.plotTemporal('Channels', 1:4, ...
    'Title', '2a: Default (SEM, HbO+HbR)');

% --- 2b: Standard deviation instead of SEM ---
% SD shows the spread of individual subjects, SEM shows the precision
% of the group mean estimate.
fig = ex.plotTemporal('Channels', 1:4, ...
    'ErrorType', 'SD', ...
    'Title', '2b: SD Error Bands');

% --- 2c: No error bands ---
fig = ex.plotTemporal('Channels', 1:4, ...
    'ErrorType', 'none', ...
    'Title', '2c: No Error Bands');

% --- 2d: Single biomarker ---
% With only one biomarker, channels are arranged in a square grid
% instead of in a single row.
fig = ex.plotTemporal('Channels', 1:6, ...
    'Biomarkers', {'HbO'}, ...
    'Title', '2d: HbO Only (Grid Layout)');

% --- 2e: All biomarkers on one channel ---
fig = ex.plotTemporal('Channels', 5, ...
    'Biomarkers', {'HbO', 'HbR', 'HbTotal', 'CBSI'}, ...
    'Title', '2e: All Biomarkers, Channel 5');

% --- 2f: PlotBy splits conditions into separate subplot rows ---
% Reset and regroup with two factors to demonstrate PlotBy
ex.reset();
ex.select('Condition', {'Task', 'Rest'});
ex.groupby({'Group', 'Condition'});
ex.aggregate();

fig = ex.plotTemporal('Channels', 1:3, ...
    'Biomarkers', {'HbO'}, ...
    'PlotBy', 'Condition', ...
    'Title', '2f: PlotBy Condition (Groups Overlaid)');
% Result: two rows (Task, Rest), each with 3 channel columns.
% Within each subplot, Young and Older traces are overlaid.

% --- 2g: Fixed axis limits and legend control ---
fig = ex.plotTemporal('Channels', 1:3, ...
    'Biomarkers', {'HbO'}, ...
    'YLim', [-3, 3], ...
    'XLim', [-5, 30], ...
    'Legend', 'first', ...
    'ShowN', false, ...
    'Title', '2g: Fixed Axes, Legend on First');

% --- 2h: Vertical annotation lines ---
% VLines draws vertical lines on all subplots. Pass a numeric vector for
% simple markers at default style (dashed gray):
fig = ex.plotTemporal('Channels', 1:3, ...
    'Biomarkers', {'HbO'}, ...
    'VLines', [0, 30], ...
    'Title', '2h: VLines (Task Onset/Offset)');

% --- 2i: VLines with labels and colors ---
% For full control, pass a struct array with .time, .label, .color, .style:
vl = struct( ...
    'time',  {0,       30}, ...
    'label', {'Onset', 'Offset'}, ...
    'color', {'r',     'b'}, ...
    'style', {'-',     '--'});
fig = ex.plotTemporal('Channels', 1:3, ...
    'Biomarkers', {'HbO'}, ...
    'VLines', vl, ...
    'Title', '2i: Labeled VLines');

fprintf('  Created 9 temporal plots\n');


%% ========================================================================
%  3. BAR CHARTS
%  ========================================================================
%
%  plotBar shows group means as bar charts with error bars. Each channel
%  gets its own subplot. Key options:
%
%    ErrorType      - 'SEM' (default), 'SD', or 'none'
%    ShowIndividual - overlay individual data points
%    ShowN          - show n=X above bars
%    TimeWindow     - average over a specific time range
%    PlotBy         - split bars by a second groupby variable

fprintf('\n=== 3. Bar Charts ===\n');

% --- 3a: Default bar chart (SEM error bars) ---
fig = ex.plotBar('Biomarker', 'HbO', 'Channels', 1:4, ...
    'Title', '3a: Default Bars (SEM)');

% --- 3b: SD error bars ---
fig = ex.plotBar('Biomarker', 'HbO', 'Channels', 1:4, ...
    'ErrorType', 'SD', ...
    'Title', '3b: SD Error Bars');

% --- 3c: No error bars ---
fig = ex.plotBar('Biomarker', 'HbO', 'Channels', 1:4, ...
    'ErrorType', 'none', ...
    'Title', '3c: No Error Bars');

% --- 3d: Show individual data points ---
% Overlays each subject's mean as a colored dot on the bars.
fig = ex.plotBar('Biomarker', 'HbO', 'Channels', 1:4, ...
    'ShowIndividual', true, ...
    'Title', '3d: With Individual Points');

% --- 3e: Average over a specific time window ---
% Instead of using the full block duration, average only 10-25 seconds.
fig = ex.plotBar('Biomarker', 'HbO', 'Channels', 1:4, ...
    'TimeWindow', [10, 25], ...
    'ShowIndividual', true, ...
    'Title', '3e: TimeWindow [10, 25]s');

% --- 3f: Clustered bars with PlotBy ---
% PlotBy creates a clustered bar chart: the specified variable becomes
% the series (legend), and the remaining groupby variables become the
% x-axis categories.
fig = ex.plotBar('Biomarker', 'HbO', 'Channels', 1:4, ...
    'PlotBy', 'Condition', ...
    'ShowIndividual', true, ...
    'Title', '3f: Clustered by Condition');
% Result: x-axis = Group (Young, Older), legend = Condition (Task, Rest)

% --- 3g: Hide n-labels and legend ---
fig = ex.plotBar('Biomarker', 'HbO', 'Channels', 1:4, ...
    'ShowN', false, 'Legend', 'none', ...
    'Title', '3g: Clean (No N, No Legend)');

fprintf('  Created 7 bar charts\n');


%% ========================================================================
%  4. SCATTER PLOTS
%  ========================================================================
%
%  plotScatter correlates a numeric info variable (X-axis) with fNIRS
%  channel data (Y-axis). Key options:
%
%    CorrType       - 'Pearson' or 'Spearman'
%    FitLine        - show regression line (default: true)
%    ErrorBand      - show uncertainty region around regression
%    ErrorBandType  - '95%PI', '95%CI', 'SEM', 'SD'
%    ErrorBandStyle - 'Shaded', 'Dashed', 'Fine'
%    FlipXY         - swap axes
%    PlotTopo       - topographic correlation map

fprintf('\n=== 4. Scatter Plots ===\n');

% Simple groupby for scatter
ex.reset();
ex.groupby({'Group'});
ex.aggregate();

% --- 4a: Default scatter (Pearson, fit line, no error band) ---
[fig, stats] = ex.plotScatter('Score', ...
    'Biomarkers', {'HbO'}, 'Channels', 1:4, ...
    'Title', '4a: Score vs HbO (Pearson)');
fprintf('  Channel 1 stats: r=%.3f, p=%.4f\n', ...
    stats(1).r(1), stats(1).p(1));

% --- 4b: Spearman rank correlation ---
[fig, stats] = ex.plotScatter('Score', ...
    'Biomarkers', {'HbO'}, 'Channels', 1:4, ...
    'CorrType', 'Spearman', ...
    'Title', '4b: Score vs HbO (Spearman)');
fprintf('  Channel 1 Spearman: rho=%.3f, p=%.4f\n', ...
    stats(1).rho(1), stats(1).pval(1));

% --- 4c: With shaded 95%% prediction interval ---
fig = ex.plotScatter('Score', ...
    'Biomarkers', {'HbO'}, 'Channels', 1:4, ...
    'ErrorBand', true, ...
    'ErrorBandType', '95%PI', ...
    'ErrorBandStyle', 'Shaded', ...
    'Title', '4c: 95% Prediction Interval (Shaded)');

% --- 4d: With 95%% confidence interval (dashed lines) ---
fig = ex.plotScatter('Score', ...
    'Biomarkers', {'HbO'}, 'Channels', 1:4, ...
    'ErrorBand', true, ...
    'ErrorBandType', '95%CI', ...
    'ErrorBandStyle', 'Dashed', ...
    'Title', '4d: 95% CI (Dashed)');

% --- 4e: SEM error band ---
fig = ex.plotScatter('Score', ...
    'Biomarkers', {'HbO'}, 'Channels', 1:4, ...
    'ErrorBand', true, ...
    'ErrorBandType', 'SEM', ...
    'Title', '4e: SEM Error Band');

% --- 4f: No fit line ---
fig = ex.plotScatter('Score', ...
    'Biomarkers', {'HbO'}, 'Channels', 1:4, ...
    'FitLine', false, ...
    'Title', '4f: Points Only (No Fit Line)');

% --- 4g: Flipped axes ---
fig = ex.plotScatter('Score', ...
    'Biomarkers', {'HbO'}, 'Channels', 1:4, ...
    'FlipXY', true, ...
    'Title', '4g: Flipped (HbO on X)');

% --- 4h: Topographic correlation map ---
% Instead of per-channel subplots, renders r-values on a 2D probe map.
% Only channels reaching significance are shown.
[fig, stats] = ex.plotScatter('Score', ...
    'PlotTopo', true, ...
    'SigThreshold', 0.5, ...   % relaxed threshold for demo
    'Title', '4h: Topo Correlation Map');

% --- 4i: PlotBy splits by condition ---
ex.reset();
ex.groupby({'Group', 'Condition'});
ex.aggregate();

fig = ex.plotScatter('Score', ...
    'Biomarkers', {'HbO'}, 'Channels', 1:3, ...
    'PlotBy', 'Condition', ...
    'ErrorBand', true, ...
    'Title', '4i: PlotBy Condition');

fprintf('  Created 9 scatter plots\n');


%% ========================================================================
%  5. HEATMAPS
%  ========================================================================
%
%  plotHeatmap shows a channel-by-time color matrix. Key options:
%
%    Biomarker     - which biomarker to show (single)
%    GroupIndex    - which group to plot (1-based)
%    SortChannels  - 'index' (default) or 'amplitude'
%    Colormap      - colormap name or [N x 3] matrix
%    CLim          - [min, max] color limits

fprintf('\n=== 5. Heatmaps ===\n');

ex.reset();
ex.groupby({'Condition'});
ex.aggregate();

% --- 5a: Default heatmap (group 1, sorted by index) ---
fig = ex.plotHeatmap('Biomarker', 'HbO', ...
    'Title', '5a: Default Heatmap');

% --- 5b: Sort channels by amplitude ---
% Channels with the highest mean HbO appear at the top.
fig = ex.plotHeatmap('Biomarker', 'HbO', ...
    'SortChannels', 'amplitude', ...
    'Title', '5b: Sorted by Amplitude');

% --- 5c: Custom colormap ---
% Supports MATLAB builtins ('jet', 'parula'), Brewer palettes
% ('RdBu', 'Spectral', 'YlOrRd'), and matplotlib-style
% ('viridis', 'plasma', 'inferno').
fig = ex.plotHeatmap('Biomarker', 'HbO', ...
    'Colormap', 'RdBu', ...
    'Title', '5c: RdBu Colormap');

% --- 5d: Fixed color limits ---
fig = ex.plotHeatmap('Biomarker', 'HbO', ...
    'CLim', [-2, 2], ...
    'Title', '5d: CLim [-2, 2]');

% --- 5e: Second group ---
fig = ex.plotHeatmap('Biomarker', 'HbO', ...
    'GroupIndex', 2, ...
    'Title', '5e: Group 2 (Rest)');

fprintf('  Created 5 heatmaps\n');


%% ========================================================================
%  6. TOPOGRAPHIC MAPS
%  ========================================================================
%
%  plotTopo shows spatial patterns of activation on a 2D probe layout.
%  When called through the Experiment wrapper, the Device is auto-injected
%  so channels are positioned according to the probe geometry and
%  short-separation channels are excluded.
%
%  Key options:
%
%    Device        - pf2.Device for probe layout (auto-injected by Experiment)
%    Time          - single time-point snapshot
%    TimeWindow    - [start, end] to average over
%    Layout        - 'single' (average all groups) or 'pergroup'
%    Colormap      - colormap name or matrix
%    CLim          - [min, max] color limits
%    Interpolation - 'none' or 'natural'

fprintf('\n=== 6. Topographic Maps ===\n');

% --- 6a: Mean activation across full block ---
fig = ex.plotTopo('Biomarker', 'HbO', ...
    'Title', '6a: Mean HbO (Full Block)');

% --- 6b: Snapshot at a specific timepoint ---
fig = ex.plotTopo('Biomarker', 'HbO', ...
    'Time', 15, ...
    'Title', '6b: HbO at t=15s');

% --- 6c: Average over a time window ---
fig = ex.plotTopo('Biomarker', 'HbO', ...
    'TimeWindow', [10, 25], ...
    'Title', '6c: Mean HbO [10-25]s');

% --- 6d: Per-group layout (side by side) ---
fig = ex.plotTopo('Biomarker', 'HbO', ...
    'Layout', 'pergroup', ...
    'TimeWindow', [10, 25], ...
    'Title', '6d: Per-Group Topo');

% --- 6e: Interpolated with custom colormap ---
fig = ex.plotTopo('Biomarker', 'HbO', ...
    'Interpolation', 'natural', ...
    'Colormap', 'hot', ...
    'TimeWindow', [10, 25], ...
    'Title', '6e: Interpolated (Hot)');

fprintf('  Created 5 topo maps\n');


%% ========================================================================
%  7. LME ANALYSIS PLOTS
%  ========================================================================
%
%  plotLME fits Linear Mixed Effects models per channel and renders
%  F-statistic bar charts. plotTopoLME maps significant results onto
%  the 3D brain surface. Key options:
%
%    SigThreshold  - significance level (default: 0.05)
%    SigType       - 'p' (uncorrected), 'q' (FDR), 'q-twostep'
%    ErrorType     - 'SEM', 'SD', or 'none' for F-stat bars
%    ShowBar       - show bar chart (default: true)
%    ShowTopo      - show ANOVA topo map (default: false)
%    AllInteractions - include all interaction terms
%    PlotMetric    - 'F' (F-statistic) or 'p' (-log10 p-value)

fprintf('\n=== 7. LME Analysis ===\n');

ex.reset();
ex.select('Condition', {'Task', 'Rest'});
ex.groupby({'Condition'});
ex.aggregate();

% --- 7a: Default LME (F-stat bars, p < 0.05) ---
[fig, results] = ex.plotLME('Biomarkers', {'HbO'}, 'Channels', 1:6, ...
    'Title', '7a: LME F-Statistics');
fprintf('  Formula: %s\n', results.formula);

% --- 7b: FDR correction ---
% 'q' applies Benjamini-Hochberg FDR correction across channels.
% 'q-twostep' uses the more conservative two-step procedure.
[fig, results] = ex.plotLME('Biomarkers', {'HbO'}, 'Channels', 1:6, ...
    'SigType', 'q', ...
    'Title', '7b: FDR-Corrected');

% --- 7c: Relaxed threshold ---
[fig, results] = ex.plotLME('Biomarkers', {'HbO'}, 'Channels', 1:6, ...
    'SigThreshold', 0.10, ...
    'Title', '7c: p < 0.10 Threshold');

% --- 7d: Multiple factors with interactions ---
ex.reset();
ex.select('Condition', {'Task', 'Rest'});
ex.groupby({'Group', 'Condition'});
ex.aggregate();

[fig, results] = ex.plotLME('Biomarkers', {'HbO'}, 'Channels', 1:4, ...
    'AllInteractions', true, ...
    'Title', '7d: Group x Condition (Interactions)');

% --- 7e: 3D Brain topo of F-statistics ---
[fig, results] = ex.plotTopoLME('Biomarkers', {'HbO'}, ...
    'SigThreshold', 0.10);

% --- 7f: Topo using -log10(p) instead of F ---
[fig, results] = ex.plotTopoLME('Biomarkers', {'HbO'}, ...
    'PlotMetric', 'p', ...
    'SigThreshold', 0.10);

% --- 7g: Accessing the results struct ---
% The results struct contains all the statistical details:
fprintf('\n  Results struct fields:\n');
fprintf('    .models     - LME model objects [nBio x nCh]\n');
fprintf('    .anova      - ANOVA tables [nBio x nCh]\n');
fprintf('    .anova_pval - p-value table (channels x terms)\n');
fprintf('    .anova_Fstat - F-statistic table (channels x terms)\n');
fprintf('    .formula    - formula: %s\n', results.formula);
fprintf('    .contrasts  - post-hoc contrast tables\n');
fprintf('  ANOVA p-values:\n');
disp(results.anova_pval);

fprintf('  Created 6 LME plots\n');


%% ========================================================================
%  8. COMPOSITE (MULTI-PANEL) FIGURES
%  ========================================================================
%
%  plotComposite arranges multiple plot types in a single figure.
%  Each panel is defined by a struct with:
%    .type     - 'temporal', 'bar', 'topo', or 'heatmap'
%    .args     - cell array of name-value args for that plot type
%    .position - (optional) [row, col] in the grid
%
%  Key options:
%    Layout      - [nRows, nCols] grid dimensions
%    PanelLabels - 'auto' (A, B, C...), 'none', or custom cell array

fprintf('\n=== 8. Composite Figures ===\n');

ex.reset();
ex.select('Condition', {'Task', 'Rest'});
ex.groupby({'Condition'});
ex.aggregate();

% --- 8a: Two-panel figure (temporal + bar) ---
panels = {
    struct('type', 'temporal', ...
           'args', {{'Biomarkers', {'HbO'}, 'Channels', 1:3}})
    struct('type', 'bar', ...
           'args', {{'Biomarker', 'HbO', 'Channels', 1:3, ...
                     'TimeWindow', [10, 25], 'ShowIndividual', true}})
};
fig = ex.plotComposite(panels, 'Layout', [1, 2], ...
    'Title', '8a: Temporal + Bar');

% --- 8b: Four-panel figure ---
panels = {
    struct('type', 'temporal', 'position', [1, 1], ...
           'args', {{'Biomarkers', {'HbO'}, 'Channels', 5}})
    struct('type', 'bar', 'position', [1, 2], ...
           'args', {{'Biomarker', 'HbO', 'Channels', 5, ...
                     'ShowIndividual', true}})
    struct('type', 'heatmap', 'position', [2, 1], ...
           'args', {{'Biomarker', 'HbO'}})
    struct('type', 'topo', 'position', [2, 2], ...
           'args', {{'Biomarker', 'HbO', 'TimeWindow', [10, 25]}})
};
fig = ex.plotComposite(panels, 'Layout', [2, 2], ...
    'PanelLabels', {'A', 'B', 'C', 'D'}, ...
    'Title', '8b: Four-Panel Composite');

% --- 8c: Custom panel labels ---
fig = ex.plotComposite(panels, 'Layout', [2, 2], ...
    'PanelLabels', 'none', ...
    'Title', '8c: No Panel Labels');

fprintf('  Created 3 composite figures\n');


%% ========================================================================
%  9. COLOR CUSTOMIZATION
%  ========================================================================
%
%  Every plot function accepts a 'Colors' parameter. Options:
%    - [N x 3] RGB matrix:       explicit colors per group
%    - Colormap name string:     e.g. 'Set1', 'tab10', 'viridis'
%    - Function handle:          @(N) returning [N x 3]
%    - ColorScheme object:       hierarchical per-factor colors
%
%  The ColorScheme class allows semantic color rules: assign base colors
%  to one factor (e.g., Group) and modifier effects to another
%  (e.g., Condition). The Experiment class stores a colorScheme that
%  auto-applies to all plots.

fprintf('\n=== 9. Color Customization ===\n');

ex.reset();
ex.select('Condition', {'Task', 'Rest'});
ex.groupby({'Group', 'Condition'});
ex.aggregate();

% --- 9a: Manual RGB colors ---
fig = ex.plotTemporal('Biomarkers', {'HbO'}, 'Channels', 1:3, ...
    'Colors', [0.8 0.2 0.2; 0.2 0.2 0.8; 0.9 0.5 0.1; 0.1 0.7 0.4], ...
    'Title', '9a: Manual RGB Colors');

% --- 9b: Named colormap ---
fig = ex.plotBar('Biomarker', 'HbO', 'Channels', 1:3, ...
    'Colors', 'Set1', ...
    'Title', '9b: Brewer Set1 Palette');

% --- 9c: ColorScheme with base colors + modifiers ---
cs = exploreFNIRS.core.ColorScheme();
cs = cs.set('Group', 'Young',  [0.2, 0.6, 0.9]);    % Blue base
cs = cs.set('Group', 'Older',  [0.9, 0.3, 0.2]);    % Red base
cs = cs.set('Condition', 'Task', 'darken', 0.15);    % Darker for Task
cs = cs.set('Condition', 'Rest', 'lighten', 0.25);   % Lighter for Rest

% Assign to Experiment (applies to all subsequent plots)
ex.colorScheme = cs;

fig = ex.plotBar('Biomarker', 'HbO', 'Channels', 1:4, ...
    'ShowIndividual', true, ...
    'Title', '9c: ColorScheme (Group Base + Condition Modifier)');
% Result: Young|Task = dark blue, Young|Rest = light blue
%         Older|Task = dark red,  Older|Rest = light red

fig = ex.plotTemporal('Biomarkers', {'HbO'}, 'Channels', 1:4, ...
    'Title', '9c: Same ColorScheme on Temporal');

% --- 9d: ColorScheme with global base color ---
cs2 = exploreFNIRS.core.ColorScheme();
cs2 = cs2.setBase([0.5, 0.5, 0.5]);                  % Gray base
cs2 = cs2.set('Group', 'Young', 'lighten', 0.3);
cs2 = cs2.set('Group', 'Older', 'darken', 0.3);
cs2 = cs2.set('Condition', 'Task', 'saturate', 0.4);
cs2 = cs2.set('Condition', 'Rest', 'desaturate', 0.3);

fig = ex.plotBar('Biomarker', 'HbO', 'Channels', 1:4, ...
    'Colors', cs2, ...
    'Title', '9d: Global Base Color + Modifiers');

% Clear colorScheme for remaining examples
ex.colorScheme = [];

fprintf('  Created 5 color customization plots\n');


%% ========================================================================
%  10. SAVING AND HEADLESS MODE
%  ========================================================================
%
%  Any plot can be saved to file by setting 'SavePath'. When SavePath
%  is set, the figure is created off-screen (Visible='off') and saved
%  automatically. Saved figures always use a white background regardless
%  of the MATLAB theme (dark mode safe).
%
%  Save options:
%    SavePath    - output file path (.png, .pdf, .fig, .svg)
%    SaveWidth   - figure width in pixels (default varies by plot type)
%    SaveHeight  - figure height in pixels
%    SaveDPI     - resolution for raster formats (default: 150)

fprintf('\n=== 10. Saving and Headless Mode ===\n');

ex.reset();
ex.groupby({'Condition'});
ex.aggregate();

% --- 10a: Save temporal plot as PNG ---
fig = ex.plotTemporal('Biomarkers', {'HbO'}, 'Channels', 1:4, ...
    'SavePath', fullfile(outDir, 'temporal_hbo.png'), ...
    'SaveWidth', 1000, 'SaveHeight', 600, 'SaveDPI', 200);
close(fig);
fprintf('  Saved: %s\n', fullfile(outDir, 'temporal_hbo.png'));

% --- 10b: Save bar chart as PDF (vector) ---
fig = ex.plotBar('Biomarker', 'HbO', 'Channels', 1:4, ...
    'ShowIndividual', true, ...
    'SavePath', fullfile(outDir, 'bar_hbo.pdf'));
close(fig);
fprintf('  Saved: %s\n', fullfile(outDir, 'bar_hbo.pdf'));

% --- 10c: Save scatter as high-DPI PNG ---
fig = ex.plotScatter('Score', ...
    'Biomarkers', {'HbO'}, 'Channels', 1:4, ...
    'ErrorBand', true, 'ErrorBandType', '95%CI', ...
    'SavePath', fullfile(outDir, 'scatter_score.png'), ...
    'SaveDPI', 300);
close(fig);
fprintf('  Saved: %s\n', fullfile(outDir, 'scatter_score.png'));

% --- 10d: Manual headless mode (Visible='off') ---
% You can also manually control visibility without saving.
fig = ex.plotTemporal('Biomarkers', {'HbO'}, 'Channels', 1:4, ...
    'Visible', 'off');
% Do something with the figure handle...
close(fig);
fprintf('  Created and closed headless figure\n');


%% ========================================================================
%  QUICK REFERENCE
%  ========================================================================

fprintf('\n=== Plot Options Quick Reference ===\n\n');

fprintf('plotTemporal:\n');
fprintf('  ErrorType   = ''SEM'' | ''SD'' | ''none''      Error band type\n');
fprintf('  Biomarkers  = {''HbO'',''HbR''}              Which biomarkers\n');
fprintf('  PlotBy      = ''Condition''                  Split by factor\n');
fprintf('  ShowN       = true | false                 n=X in legend\n');
fprintf('  Legend       = ''last'' | ''first'' | ''all'' | ''none''\n');
fprintf('  YLim, XLim  = [min, max]                  Fixed axes\n');
fprintf('  VLines      = [0 30] | struct(...)         Vertical annotations\n\n');

fprintf('plotBar:\n');
fprintf('  ErrorType      = ''SEM'' | ''SD'' | ''none''   Error bar type\n');
fprintf('  ShowIndividual = true | false              Data points\n');
fprintf('  TimeWindow     = [start, end]              Average range\n');
fprintf('  PlotBy         = ''Condition''               Clustered bars\n\n');

fprintf('plotScatter:\n');
fprintf('  CorrType       = ''Pearson'' | ''Spearman''   Correlation\n');
fprintf('  FitLine        = true | false              Regression line\n');
fprintf('  ErrorBand      = true | false              Uncertainty\n');
fprintf('  ErrorBandType  = ''95%%PI'' | ''95%%CI'' | ''SEM'' | ''SD''\n');
fprintf('  ErrorBandStyle = ''Shaded'' | ''Dashed'' | ''Fine''\n');
fprintf('  PlotTopo       = true                      Topo map mode\n');
fprintf('  FlipXY         = true | false              Swap axes\n\n');

fprintf('plotHeatmap:\n');
fprintf('  SortChannels = ''index'' | ''amplitude''      Channel order\n');
fprintf('  Colormap     = ''RdBu'', ''viridis'', etc.    Color palette\n');
fprintf('  CLim         = [min, max]                  Color limits\n\n');

fprintf('plotTopo (auto-uses probe layout, excludes short-sep):\n');
fprintf('  Time          = 15                         Time snapshot\n');
fprintf('  TimeWindow    = [10, 25]                   Average window\n');
fprintf('  Layout        = ''single'' | ''pergroup''     Group display\n');
fprintf('  Interpolation = ''none'' | ''natural''        Smoothing\n');
fprintf('  Device        = dev                        Probe layout (auto-injected)\n\n');

fprintf('plotLME / plotTopoLME:\n');
fprintf('  SigThreshold = 0.05                        Alpha level\n');
fprintf('  SigType      = ''p'' | ''q'' | ''q-twostep''    Correction\n');
fprintf('  PlotMetric   = ''F'' | ''p''                  Topo metric\n');
fprintf('  AllInteractions = true | false             Full model\n\n');

fprintf('Colors (all plots):\n');
fprintf('  Colors = [N x 3]                           Manual RGB\n');
fprintf('  Colors = ''Set1''                            Named palette\n');
fprintf('  Colors = cs                                ColorScheme\n');
fprintf('  ex.colorScheme = cs                        Auto-apply\n\n');

fprintf('Saving (all plots):\n');
fprintf('  SavePath  = ''file.png''                    Output path\n');
fprintf('  SaveWidth, SaveHeight                      Dimensions\n');
fprintf('  SaveDPI   = 150                            Resolution\n');
