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

### Scriptable Analysis (Headless)

```matlab
% Build segment info table
segmentTable = exploreFNIRS.dataset.buildSegmentInfoTable(allData);

% Standardize ROIs across subjects
allData = exploreFNIRS.dataset.standardizeROIs(allData);

% Export for external analysis
longData = exploreFNIRS.export.mergeGbyTablesLong(gbyData);
writetable(longData, 'export_for_R.csv');
```

## Scriptable Functions

The following functions can be used outside the GUI:

| Package | Function | Purpose |
|---------|----------|---------|
| `+dataset` | `buildSegmentInfoTable` | Create metadata table from structs |
| `+dataset` | `standardizeROIs` | Align ROI definitions across subjects |
| `+export` | `mergeGbyTablesLong` | Export to long format |
| `+export` | `mergeGbyTablesWide` | Export to wide format |
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
