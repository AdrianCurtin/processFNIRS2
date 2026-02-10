# exploreFNIRS

## Overview

exploreFNIRS is the group-level analysis module for processFNIRS2. It provides tools for organizing multi-subject fNIRS data, computing group statistics, fitting linear mixed-effects models, and generating publication-ready visualizations.

While processFNIRS2 handles single-subject signal processing (raw data to hemoglobin concentrations), exploreFNIRS operates on collections of processed fNIRS structs to perform group-level statistical analysis.

## Getting Started

### Basic Usage

```matlab
% Load processed fNIRS data into a cell array
allData = {subject1_data, subject2_data, subject3_data, ...};

% Launch the exploreFNIRS GUI
exploreFNIRS(allData);
```

### With Configuration Options

```matlab
exploreFNIRS(allData, ...
    'timeShiftTo0', true, ...      % Shift time vectors to start at 0
    'blStart', 0, ...              % Baseline start time (seconds)
    'blEnd', 5, ...                % Baseline end time (seconds)
    'blockStart', 5, ...           % Analysis block start time
    'blockEnd', 65, ...            % Analysis block end time
    'barSegmentLength', 60);       % Segment length for bar charts
```

## Data Requirements

### Required Metadata Fields

Each fNIRS struct in the input cell array must have the following fields in `data.info`:

| Field | Description | Example |
|-------|-------------|---------|
| `SubjectID` | Unique subject identifier | `'S01'` |
| `Group` | Experimental group | `'Control'`, `'Treatment'` |
| `Session` | Session number or label | `1`, `'Pre'` |
| `Trial` | Trial number | `1`, `2`, `3` |
| `Block` | Block identifier | `'Task'`, `'Rest'` |
| `Condition` | Experimental condition | `'Congruent'`, `'Incongruent'` |

### Data Format

```matlab
% Input: Cell array of processed fNIRS structs
allData = {N x 1 cell}

% Each cell contains a processed fNIRS struct with:
data.HbO      % [T x C] Oxygenated hemoglobin
data.HbR      % [T x C] Deoxygenated hemoglobin
data.time     % [T x 1] Time vector
data.fs       % Sampling frequency
data.fchMask  % [1 x C] Channel mask
data.info     % Struct with metadata fields above
data.ROI      % (optional) ROI-averaged data
```

## Core Features

### Grouping and Hierarchical Averaging

exploreFNIRS supports flexible grouping of data by any metadata field:

- Group by condition, session, or any combination of factors
- Automatic hierarchical within-subject averaging to prevent pseudoreplication
- Grand averages computed across subjects with proper error estimation

### Statistical Analysis

#### Linear Mixed-Effects Models

exploreFNIRS fits LME models with:
- Fixed effects for experimental factors
- Random intercepts for subjects
- Satterthwaite degrees of freedom for accurate p-values
- ANOVA tables with F-statistics

#### FDR Correction

Multiple comparison correction using:
- Standard Benjamini-Hochberg FDR
- Two-step adaptive FDR (Benjamini-Krieger-Yekutieli 2006)

```matlab
% Programmatic FDR correction
[qValues, significant, criticalK] = exploreFNIRS.fx.performFDR(pValues, 0.05);
```

#### Automatic Contrasts

Post-hoc pairwise comparisons with:
- Bonferroni correction
- Effect size calculation (Hedges' g)
- Contrast coefficient matrices

```matlab
% Generate contrasts from fitted model
contrasts = exploreFNIRS.fx.autoContrast(lmeModel);
```

### Visualization

#### Temporal Plots

Time-series visualization with shaded error regions:

```matlab
exploreFNIRS.plot.temporal(gbyData, ...
    'ErrorType', 'SEM', ...        % SEM, SD, or CI
    'Biomarker', 'HbO', ...
    'ShowMarkers', true);
```

#### Bar Charts

Grouped bar charts with statistical overlays:

```matlab
exploreFNIRS.plot.barchart(gbyData, ...
    'ErrorType', 'SEM', ...        % SEM, SD, IQR, Violin
    'ShowIndividualPoints', true, ...
    'FitLME', true);               % Fit and display LME results
```

#### Scatter Plots

Correlation analysis with regression:

```matlab
exploreFNIRS.plot.scatter(gbyData, ...
    'CorrelationType', 'Pearson', ...  % Pearson or Spearman
    'ShowRegression', true, ...
    'ShowCI', true);                   % Confidence intervals
```

#### Topographic Maps

Channel-level statistics displayed on probe geometry:
- F-statistic maps from ANOVA
- Correlation coefficient maps
- FDR-corrected significance overlays

### Data Export

Export grouped data for external analysis:

```matlab
% Long format (one row per observation) - for R/lme4
longTable = exploreFNIRS.export.mergeGbyTablesLong(gbyData);

% Wide format (one row per subject) - for SPSS
wideTable = exploreFNIRS.export.mergeGbyTablesWide(gbyData);
```

## Workflow Example

### Complete Analysis Pipeline

```matlab
% 1. Load and organize data
allData = cell(numSubjects, 1);
for i = 1:numSubjects
    raw = pf2.import.importNIR(files{i});
    processed = processFNIRS2(raw);

    % Add required metadata
    processed.info.SubjectID = sprintf('S%02d', i);
    processed.info.Group = groups{i};
    processed.info.Condition = conditions{i};

    allData{i} = processed;
end

% 2. Launch exploreFNIRS
exploreFNIRS(allData);

% 3. In GUI:
%    - Select grouping variables
%    - Choose biomarker (HbO, HbR, etc.)
%    - Select time window
%    - Generate plots
%    - Export statistics
```

### Scriptable Analysis (Headless) — New in v1.0.0

The `Experiment` class enables complete group analysis without the GUI:

```matlab
% Create experiment from processed data
ex = exploreFNIRS.core.Experiment(allData);

% Filter and organize
ex.select('Group', {'Control', 'Treatment'}, 'Condition', 'Task');
ex.groupby({'Group', 'Condition'});
ex.aggregate();

% Headless temporal plot
fig = ex.plotTemporal('Biomarkers', {'HbO'}, 'Channels', [1 5 10], ...
    'SavePath', 'temporal.png', 'SaveDPI', 300);

% Headless bar chart with time window
fig = ex.plotBar('Biomarker', 'HbO', 'TimeWindow', [5 25], ...
    'SavePath', 'bar.png');

% ROI-based plotting
fig = ex.plotTemporal('Biomarkers', {'HbO'}, 'ROIs', 'all');
fig = ex.plotBar('Biomarker', 'HbO', 'ROIs', {'DLPFC_L', 'DLPFC_R'});

% LME analysis with ANOVA tables and topo maps
[fig, results] = ex.plotLME('Biomarkers', {'HbO'}, 'ShowTopo', true);

% Scatter correlation of behavioral variable vs biomarker
[fig, stats] = ex.plotScatter('InfoVar', 'reactionTime', 'Biomarkers', {'HbO'});

% Auxiliary channel plots (accelerometer, heart rate, etc.)
fig = ex.plotAux('accelerometer', 'Layout', 'grid');

% Export for external analysis
longTable = ex.exportLong();
wideTable = ex.exportWide();
writetable(longTable, 'export_for_R.csv');
```

### Statistical Analysis Module — New in v1.0.0

```matlab
% Standalone LME fitting (no visualization)
results = ex.statsFitLME('Biomarkers', {'HbO'}, 'Channels', 1:5);

% ANOVA summary table
T = ex.statsSummarize(results, 'Type', 'anova');
disp(T);

% APA-formatted strings for manuscripts
T = ex.statsSummarize(results, 'Type', 'anova', 'Format', 'apa');
disp(T.APA);

% Post-hoc contrasts with FDR correction across channels
cr = ex.statsRunContrasts(results, 'FDRThreshold', 0.05);

% Fixed-effect coefficients
T = ex.statsSummarize(results, 'Type', 'coefficients');

% Model fit statistics (AIC, BIC, null model LRT)
T = ex.statsSummarize(results, 'Type', 'fit');
writetable(T, 'model_fit.csv');

% Direct function calls (without Experiment)
results = exploreFNIRS.stats.fitLME(groups, {'Group','Condition'});
T = exploreFNIRS.stats.summarize(results, 'Type', 'anova', 'IncludeFDR', true);
cr = exploreFNIRS.stats.runContrasts(results, 'FDRMethod', 'twostep');
```

### Advanced Visualization — New in v1.0.0

```matlab
% Topographic maps
fig = ex.plotTopo('Biomarker', 'HbO', 'Time', 15, 'SavePath', 'topo.png');
fig = ex.plotTopo('Layout', 'pergroup', 'TimeWindow', [10, 20]);

% Channel × time heatmap
fig = ex.plotHeatmap('Biomarker', 'HbO', 'SortChannels', 'amplitude');

% Multi-panel composite figures
panels = {
    struct('type', 'temporal', 'args', {{'Biomarkers', {'HbO'}}}), ...
    struct('type', 'bar', 'args', {{'Biomarker', 'HbO'}})
};
fig = ex.plotComposite(panels, 'Layout', [1, 2], 'SavePath', 'composite.png');
```

### Connectivity Analysis — New in v1.0.0

```matlab
% Compute connectivity matrices
connResults = ex.connectivity('Method', 'pearson');
fig = exploreFNIRS.connectivity.plotMatrix(connResults);

% Directed connectivity (Granger causality)
connResults = ex.connectivity('Method', 'granger');
fig = exploreFNIRS.connectivity.plotDirected(connResults, 'Layout', 'circular');

% Dynamic functional connectivity with brain state detection
dfc = exploreFNIRS.connectivity.computeDynamicFC(data, 'WindowSize', 30);
states = exploreFNIRS.connectivity.detectStates(dfc, 'K', 3);
fig = exploreFNIRS.connectivity.plotDynamicFC(dfc, 'States', states);

% Intra-ROI and inter-ROI connectivity
intraResult = ex.intraROI('Method', 'pearson');
fig = exploreFNIRS.connectivity.plotIntraROI(intraResult, 'PlotType', 'radar');

interResult = ex.interROI('Method', 'pearson');
fig = exploreFNIRS.connectivity.plotInterROI(interResult, 'PlotType', 'chord');

% Block-wise connectivity
connBlocks = ex.connectivity('Method', 'coherence', 'Blocks', blocks);
fig = exploreFNIRS.connectivity.plotBlockComparison(connBlocks);

% Export connectivity as table
T = exploreFNIRS.export.connectivityToTable(connResults);
writetable(T, 'connectivity_results.csv');
```

### Hyperscanning Analysis — New in v1.0.0

```matlab
% Pair subjects and compute inter-brain coupling
hsResults = ex.hyperscanning('PairBy', 'Dyad', 'Method', 'wcoherence');

% Group-level statistics with permutation testing
groupStats = exploreFNIRS.hyperscanning.computeGroup(hsResults);
pValues = exploreFNIRS.hyperscanning.permutationTest(hsResults, 1000);
fig = exploreFNIRS.hyperscanning.plotGroup(groupStats);

% Dual-brain topographic display
fig = exploreFNIRS.hyperscanning.plotInterBrainTopo(groupStats, ...
    'BrainLabels', {'Speaker', 'Listener'});

% Dyad-level heatmap
fig = exploreFNIRS.hyperscanning.plotDyadMatrix(groupStats, 'SortDyads', 'mean');

% Time-resolved group coupling (requires windowed coupling)
fig = exploreFNIRS.hyperscanning.plotGroupTemporal(groupStats, 'ErrorType', 'SEM');
```

### Other Scriptable Functions

```matlab
% Build segment info table
segmentTable = exploreFNIRS.dataset.buildSegmentInfoTable(allData);

% Standardize ROIs across subjects
allData = exploreFNIRS.dataset.standardizeROIs(allData);
```

## Scriptable Functions

The following functions can be used outside the GUI:

| Package | Function | Purpose |
|---------|----------|---------|
| `+core` | `Experiment` | Main experiment container class |
| `+core` | `plotTemporal` | Headless temporal plots with ROI support |
| `+core` | `plotBar` | Headless bar charts with ROI support |
| `+core` | `plotTopo` | Headless topographic maps (single/pergroup) |
| `+core` | `plotHeatmap` | Channel × time heatmap |
| `+core` | `plotComposite` | Multi-panel publication figures |
| `+core` | `plotLME` | LME analysis with bar charts and topo F-maps |
| `+core` | `plotScatterFNIRS` | Scatter correlation with regression and topo maps |
| `+core` | `plotAux` | Headless auxiliary channel temporal plots |
| `+core` | `getGroupColors` | Consistent group coloring |
| `+stats` | `fitLME` | Standalone channel-wise LME fitting (no visualization) |
| `+stats` | `runContrasts` | Post-hoc contrasts with FDR correction across channels |
| `+stats` | `summarize` | Publication-ready tables (ANOVA, contrasts, coefficients, fit, APA) |
| `+connectivity` | `computeMatrix` | Channel-pair connectivity matrices (symmetric + directed) |
| `+connectivity` | `computeDynamicFC` | Sliding-window dynamic functional connectivity |
| `+connectivity` | `detectStates` | K-means brain state detection from dynamic FC |
| `+connectivity` | `computeIntraROI` | Within-ROI pairwise coupling analysis |
| `+connectivity` | `computeInterROI` | Between-ROI coupling analysis |
| `+connectivity` | `plotMatrix` | Matrix visualization |
| `+connectivity` | `plotBlockComparison` | Block-wise comparison |
| `+connectivity` | `plotDirected` | Directed connectivity (matrix + circular) |
| `+connectivity` | `plotDynamicFC` | Dynamic FC with brain state visualization |
| `+connectivity` | `plotChord` | Chord diagram for connectivity |
| `+connectivity` | `plotIntraROI` | Intra-ROI bar/radar visualization |
| `+connectivity` | `plotInterROI` | Inter-ROI chord/matrix visualization |
| `+coupling` | `pearson`, `spearman`, `xcorr`, `coherence`, `wcoherence` | Undirected coupling |
| `+coupling` | `granger`, `transferEntropy` | Directed coupling (Granger causality, transfer entropy) |
| `+coupling` | `plotWcoherence`, `plotWindowed` | Coupling visualization |
| `+hyperscanning` | `pairSubjects` | Pair subjects by criteria |
| `+hyperscanning` | `computeDyad` | Dyad-level coupling |
| `+hyperscanning` | `computeGroup` | Group-level statistics |
| `+hyperscanning` | `permutationTest` | Permutation significance testing |
| `+hyperscanning` | `plotGroup` | Group bar chart visualization |
| `+hyperscanning` | `plotInterBrainTopo` | Dual-brain topographic display |
| `+hyperscanning` | `plotDyadMatrix` | Dyad-level coupling heatmap |
| `+hyperscanning` | `plotGroupTemporal` | Time-resolved group coupling |
| `+dataset` | `buildSegmentInfoTable` | Create metadata table from structs |
| `+dataset` | `standardizeROIs` | Align ROI definitions across subjects |
| `+export` | `mergeGbyTablesLong` | Export to long format |
| `+export` | `mergeGbyTablesWide` | Export to wide format |
| `+export` | `connectivityToTable` | Export connectivity results |
| `+fx` | `performFDR` | Benjamini-Hochberg FDR correction |
| `+fx` | `performFDR_twostep` | Adaptive two-step FDR |
| `+fx` | `autoContrast` | Generate post-hoc contrasts |
| `+helper` | `getColormap` | Get named colormap |
| `+helper` | `listColormaps` | List available colormaps |

## Tips

- Ensure all subjects have consistent channel counts and ROI definitions
- Use `standardizeROIs` when combining data from different probe configurations
- For within-subject designs, specify hierarchy variables to enable proper averaging
- Export to long format for analysis in R with lme4/lmerTest packages
- Use FDR correction when testing multiple channels or timepoints

## Related Documentation

- `README.md` - Main processFNIRS2 documentation
- `CLAUDE.md` - Detailed API reference and data structures
- `help exploreFNIRS` - MATLAB help documentation

## License

exploreFNIRS is part of processFNIRS2 and is free for academic and non-commercial use.

## Contact

For questions or support, contact Dr. Adrian Curtin at adrian.b.curtin@drexel.edu
