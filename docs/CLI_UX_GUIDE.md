# processFNIRS2 CLI/UX Guide

> **Date**: 2026-01-23 | **Updated**: 2026-06-23 | **Version**: v1.0.0

A user-focused guide to the processFNIRS2 command-line interface.

---

## Table of Contents

1. [Quick Start](#1-quick-start)
2. [Glossary of Terms](#2-glossary-of-terms)
3. [Understanding the API: Progressive Disclosure](#3-understanding-the-api-progressive-disclosure)
4. [Overview: Two-Layer Model](#4-overview-two-layer-model)
5. [Layer 1: pf2 API Reference](#5-layer-1-pf2-api-reference)
6. [Layer 2: exploreFNIRS API Reference](#6-layer-2-explorefnirs-api-reference)
- [Appendix A: Complete Function List](#appendix-a-complete-function-list)
- [Appendix B: GUI-to-CLI Mapping](#appendix-b-gui-to-cli-mapping)

> **For developers**: identified issues and improvement plans are tracked in the project's internal CLI/UX roadmap.

---

## 1. Quick Start

### Your First Processing Script (5 lines)

```matlab
% 1. Load sample data (or use pf2.import.importNIR('yourfile.nir'))
data = pf2.import.sampleData.fNIR2000();

% 2. Process with default settings
processed = processFNIRS2(data);

% 3. View the results
pf2.data.plot(processed);
```

### Common Workflows

**Basic Processing Pipeline:**
```matlab
% Load → Configure → Process → Visualize → Export
data = pf2.import.importNIR('subject01.nir');
pf2.methods.raw.setMethod('x2_lpf_smar');     % Motion correction + filtering
processed = processFNIRS2(data);
pf2.data.plot.oxy(processed);                  % Time series plot
pf2.export.asSNIRF(processed, 'subject01_processed.snirf');
```

**Batch Processing Multiple Subjects:**
```matlab
files = dir('data/*.nir');
for i = 1:length(files)
    data = pf2.import.importNIR(fullfile(files(i).folder, files(i).name));
    processed = processFNIRS2(data);
    [~, name] = fileparts(files(i).name);
    save(['output/' name '_processed.mat'], 'processed');
end
```

**Group Analysis (after processing all subjects):**
```matlab
% Load processed data into cell array
allData = {processed1, processed2, processed3, ...};

% Launch group analysis GUI
exploreFNIRS(allData);

% Or use the scriptable Experiment class (no GUI needed)
ex = exploreFNIRS.core.Experiment(allData);
ex.select('Group', {'Control', 'Treatment'});
ex.groupby({'Group', 'Condition'});
ex.aggregate();
fig = ex.plotTemporal('Biomarkers', {'HbO'}, 'Channels', 1:5);
fig = ex.plotBar('Biomarker', 'HbO', 'TimeWindow', [5, 25]);
```

### Verify Your Setup

Run this to confirm everything is working:
```matlab
data = pf2.import.sampleData.fNIR2000();
processed = processFNIRS2(data);
pf2.data.plot.oxy(processed);
disp('✓ processFNIRS2 is working correctly!');
```

---

## 2. Glossary of Terms

### fNIRS Basics

| Term | Definition |
|------|------------|
| **fNIRS** | Functional Near-Infrared Spectroscopy - a neuroimaging technique that measures brain activity by detecting changes in blood oxygenation |
| **Channel** | A measurement location defined by a source-detector pair; measures light that traveled through brain tissue |
| **Optode** | A light source or detector placed on the scalp |
| **Probe** | The arrangement of all optodes (sources and detectors) on the head |

### Biomarkers (What fNIRS Measures)

| Term | Definition |
|------|------------|
| **HbO** | Oxygenated hemoglobin - increases when brain region is active |
| **HbR** | Deoxygenated hemoglobin - typically decreases when brain region is active |
| **HbTotal** | Total hemoglobin (HbO + HbR) - related to blood volume |
| **HbDiff** | Differential hemoglobin (HbO - HbR) - emphasizes oxygenation changes |
| **CBSI** | Correlation-Based Signal Improvement - noise-reduced signal combining HbO and HbR |

### Processing Concepts

| Term | Definition |
|------|------------|
| **Optical Density (OD)** | Logarithmic measure of light attenuation; intermediate processing step |
| **Beer-Lambert Law** | Physics equation that converts light changes to hemoglobin concentration changes |
| **DPF** | Differential Pathlength Factor - correction factor accounting for light scattering in tissue. Modes: `'None'` (no correction), `'Fixed'` (constant value), `'Calc'` (age-dependent) |
| **Baseline** | Reference period (typically at rest) used to normalize the signal; set via `pf2.settings.baseline.*` |
| **Channel Mask** | Array marking channels as good (1) or bad (0); stored in `data.fchMask` |

### Motion Correction Methods

| Method | Description |
|--------|-------------|
| **SMAR** | Sliding-window Motion Artifact Rejection - detects and interpolates artifacts |
| **TDDR** | Temporal Derivative Distribution Repair - robust to spike artifacts |
| **MARA** | Movement Artifact Reduction Algorithm - spline-based correction |
| **Wavelet** | Frequency-based artifact removal |

### File Formats

| Format | Extension | Description |
|--------|-----------|-------------|
| **NIR** | `.nir` | fNIR Devices/Biopac format |
| **SNIRF** | `.snirf` | Standardized format (recommended for sharing) |
| **NIRx** | `.hdr`, `.wl1`, `.wl2` | NIRx system files |
| **Hitachi** | `.csv` | Hitachi ETG-4000 export |

### Processing Stages

```
Stage 1: Raw → Optical Density
  - Motion correction (SMAR, TDDR, etc.)
  - Filtering (low-pass, band-pass)
  - Methods: pf2.methods.raw.*

Stage 2: Optical Density → Hemoglobin
  - Beer-Lambert Law conversion
  - DPF correction
  - (Automatic, no user configuration)

Stage 3: Hemoglobin → Final Output
  - Baseline correction
  - Additional filtering
  - Artifact rejection (Takizawa)
  - Methods: pf2.methods.oxy.*
```

---

## 3. Understanding the API: Progressive Disclosure

### The Key Insight

The API hierarchy is intentional: **depth = specificity**.

- **Shallow calls** (parent level) → Auto-detect or interactive prompts
- **Deep calls** (child level) → Explicit, specific behavior

```
pf2.import                      % → Interactive file browser
pf2.import.importNIR(file)      % → Explicit NIR format
pf2.import.sampleData           % → Interactive sample selection
pf2.import.sampleData.fNIR2000  % → Specific sample dataset
```

### Why This Matters

**Don't know the file format?** Call the parent:
```matlab
data = pf2.import();  % Opens file browser, auto-detects format
```

**Know exactly what you want?** Call the specific function:
```matlab
data = pf2.import.importNIR('myfile.nir');  % No guessing
```

### Examples of Progressive Disclosure

| Parent (General) | Child (Specific) | Behavior |
|------------------|------------------|----------|
| `pf2.data.plot(data)` | `pf2.data.plot.oxy(data)` | Parent auto-detects: has HbO? → Oxy plot, else → Raw plot |
| `pf2.methods()` | `pf2.methods.raw()` | Parent lists ALL methods; child lists only raw methods |
| `pf2.methods.raw.setMethod()` | `pf2.methods.raw.setMethod('x2_lpf_smar')` | No-arg prompts interactively; with-arg sets directly |

### Tab-Completion is Your Friend

In MATLAB, type `pf2.` and press Tab to see all subpackages:
```
pf2.<Tab>
    data      export    gui       help      import    methods   process   probe     settings
```

Then drill down: `pf2.import.<Tab>` shows import functions.

---

## 4. Overview: Two-Layer Model

processFNIRS2 has two main layers for different analysis stages:

```
┌─────────────────────────────────────────────────────────────────┐
│                   LAYER 2: exploreFNIRS                         │
│                   (Group Analysis & Statistics)                  │
│                                                                 │
│   Input: Cell array of processed fNIRS structs                  │
│   Output: Statistical results, visualizations, exports          │
│                                                                 │
│   Use for: Multi-subject analysis, LME modeling, group plots   │
└─────────────────────────────────────────────────────────────────┘
                              ▲
                              │ Processed fNIRS structs
                              │
┌─────────────────────────────────────────────────────────────────┐
│                   LAYER 1: pf2 / processFNIRS2                  │
│                   (Single-Subject Processing)                    │
│                                                                 │
│   Input: Raw device files (.nir, .snirf, .csv)                  │
│   Output: Processed fNIRS struct with HbO/HbR                   │
│                                                                 │
│   Use for: Import, processing, visualization, export            │
└─────────────────────────────────────────────────────────────────┘
```

### When to Use Each Layer

| Task | Use Layer |
|------|-----------|
| Import a raw fNIRS file | Layer 1: `pf2.import.*` |
| Process a single subject | Layer 1: `processFNIRS2(data)` |
| View time series for one subject | Layer 1: `pf2.data.plot.oxy(data)` |
| Compare conditions across subjects | Layer 2: `exploreFNIRS(allData)` |
| Run statistical tests (LME, t-test) | Layer 2: exploreFNIRS GUI |
| Export data for R/SPSS | Layer 2: `exploreFNIRS.export.*` |

### Naming Conventions

| Layer | Packages | Functions | Example |
|-------|----------|-----------|---------|
| Layer 1 (pf2) | `lowercase` | `camelCase` | `pf2.import.importNIR` |
| Layer 2 (exploreFNIRS) | `lowercase` | `lowercase` | `exploreFNIRS.plot.barchart` |

---

## 5. Layer 1: pf2 API Reference

### 5.1 Top-Level Entry Points

```matlab
% Main processing
processFNIRS2(data)                    % With GUI (no output assignment)
processed = processFNIRS2(data)         % Headless (assigning an output suppresses the GUI)
processed = processFNIRS2(data, 'ShowGUI', true)  % Force GUI with an output
pf2(data)                              % Alias for processFNIRS2

% Information
pf2.help()                             % Interactive help
pf2.methods()                          % List all methods

% GUI
pf2.gui()                              % Launch processing GUI
```

### 5.2 Import Functions (`pf2.import.*`)

```matlab
% File import
data = pf2.import.importNIR(filepath)           % fNIR Devices/Biopac
data = pf2.import.importNIRX(filepath)          % NIRx systems
data = pf2.import.importSNIRF(filepath)         % SNIRF format (auto-reads BIDS events.tsv)
data = pf2.import.importHitachiMES(filepath)    % Hitachi ETG-4000
data = pf2.import.importOxy3(filepath)          % Artinis OxySoft (.oxy3)

% Batch / directory import
allData = pf2.import.importDirectory('data/', '*.snirf')  % Tree import w/ metadata mapping

% Learned features (foundation-model re-import)
data = pf2.import.importEmbeddings(data, 'embeddings.h5')  % Attach data.embeddings

% Sample data
data = pf2.import.sampleData()                  % Interactive selection
data = pf2.import.sampleData.fNIR2000()         % Specific device
data = pf2.import.sampleData.fNIR1200()
data = pf2.import.sampleData.Hitachi_ETG4000_3x5()
data = pf2.import.sampleData.Hitachi_ETG4000_3x11()
[ex, allData] = pf2.import.sampleData.group()   % Ready-to-analyze group Experiment
```

### 5.3 Export Functions (`pf2.export.*`)

```matlab
pf2.export.asNIR(data, filepath)       % Export to .nir format
pf2.export.asSNIRF(data, filepath)     % Export to .snirf format
pf2.export.asBIDS(data, outputDir)     % Export to BIDS structure
pf2.export.asTensor(data, 'out.h5')    % Self-describing HDF5 tensor (foundation-model contract)
pf2.export.export(data, filepath)      % Auto-detect format from extension

% Batch export (cell array → directory)
pf2.export.asSNIRF(allData, 'output/')
pf2.export.asNIR(allData, 'output/')
```

### 5.4 Data Manipulation (`pf2.data.*`)

```matlab
% Time/channel operations
data = pf2.data.setT0(data, 5)                          % Shift t0 to 5 s (positional)
data = pf2.data.applyChannelMask(data, mask)            % Apply channel mask
data = pf2.data.resample(data, 0.5)                     % Resample to 2 Hz (0.5 s bins)

% Splitting and joining
segments = pf2.data.split(data, times)                  % Split by timepoints
markers = pf2.data.getMarkers(data, 49)                 % Onset times of marker code 49
data = pf2.data.concatenate(data1, data2)               % Merge devices (more channels)
data = pf2.data.concatenateHorizontal(data1, data2)     % Concatenate in time

% GUI tools
pf2.data.editChannelMaskGUI(data)                       % Channel mask editor

% Blocks and trial averaging
blocks = pf2.data.defineBlocks(data, 50, 15)            % Markers → blocks (code 50, 15 s)
segments = pf2.data.extractBlocks(data, blocks, 'PreTime', 5, 'PostTime', 15)
ga = pf2.data.blockAverage(segments)                    % Trial/grand average

% Marker dictionary (code → label)
data = pf2.data.setMarkerDict(data, {49,'Stroop'; 50,'Control'})
dict = pf2.data.getMarkerDict(data)
data = pf2.data.labelMarkers(data)                      % Per-row categorical Label

% Metadata (CSV/Excel ↔ .info)
allData = pf2.data.importInfo(allData, 'demographics.csv', 'SubjectID')
T = pf2.data.infoToTable(allData)                       % .info → table
allData = pf2.data.infoFromTable(allData, T)            % table → .info
```

### 5.5 Data Plotting (`pf2.data.plot.*`)

```matlab
% Auto-routing (chooses oxy or raw based on data)
pf2.data.plot(data)

% Specific plot types
pf2.data.plot.oxy(data)                 % Hemoglobin data
pf2.data.plot.oxy(data, channels, showMarkers, {'HbO', 'HbR'})
pf2.data.plot.raw(data)                 % Raw intensity
pf2.data.plot.raw(data, channels, showMarkers)
pf2.data.plot.roi(data)                 % ROI-averaged data
pf2.data.plot.auxData(data)             % Auxiliary channels

% Batch/headless mode (suppress interactive prompts)
pf2.data.plot.oxy(data, 'interactive', false)

% Save figures programmatically
pf2.data.plot.oxy(data, 'savePath', 'timeseries.png')
pf2.data.plot.oxy(data, 'savePath', 'timeseries.pdf', ...
    'saveWidth', 800, 'saveHeight', 600, 'saveDPI', 300)
```

**Common Plot Parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `'interactive'` | logical | Set `false` to suppress input prompts (default: `true`) |
| `'savePath'` | string | File path for saving (supports .png, .pdf, .fig, .svg, .eps) |
| `'saveWidth'` | numeric | Output width in pixels |
| `'saveHeight'` | numeric | Output height in pixels |
| `'saveDPI'` | numeric | Resolution in DPI (default: 150) |

### 5.6 Probe Visualization (`pf2.probe.plot.*`)

```matlab
% Quickest path: high-level topo wrapper (takes a biomarker NAME)
pf2.probe.plot.topo(processed, 'HbO')                     % 2D heatmap, time-averaged
pf2.probe.plot.topo(processed, 'HbO', 'Time', 30)         % at t = 30 s
pf2.probe.plot.topo(processed, 'HbO', 'Time', [20 40])    % window mean
pf2.probe.plot.topo(processed, 'HbO', 'View', '3d')       % cortical surface
pf2.probe.plot.topo(processed, 'HbO', 'Time', 30, 'savePath', 'topo.png')

% Underlying primitives (NOTE: data2plot is a [1×C] vector, NOT a biomarker name)
meanHbO = mean(processed.HbO, 1);
pf2.probe.plot.imageValues(meanHbO, processed)            % 2D heatmap
pf2.probe.plot.interpolateValues(meanHbO, processed)      % Interpolated
pf2.probe.plot.arrangedValues(meanHbO, processed)         % Arranged layout

% ROI-based plots
pf2.probe.plot.imageROIvalues(data)
pf2.probe.plot.interpolateROIvalues(data)

% 3D visualization
pf2.probe.plot.showProbe3D(data)                          % 3D brain view
pf2.probe.plot.interpolateValues3D(meanHbO, processed)    % 3D interpolated
pf2.probe.plot.connectome(data, connMatrix)               % Connectome edges on probe
pf2.probe.plot.movie(processed, 'HbO')                    % Time-evolving topo movie

% Statistical projections onto cortex (pf2.probe.project.*)
pf2.probe.project.pvalues(pvals, processed, 'savePath', 'stats.png')
pf2.probe.project.fstats(Fvals, processed)
pf2.probe.project.biomarker(meanHbO, processed)
pf2.probe.project.correlation(rvals, processed)
pf2.probe.project.counts(nvals, processed)
pf2.probe.project.regions(labels, processed)
pf2.probe.project.parcels(processed, 'Highlight', [2 8 9 16]) % optode parcel map
```

All probe plotting functions support the same save parameters as data plots:
`'savePath'`, `'saveWidth'`, `'saveHeight'`, `'saveDPI'`. For 3D renders
(`showProbe3D`, `interpolateValues3D`, `topo 'View','3d'`, `project.*`), prefer
the built-in `'savePath'` option over `figure('Visible','off') + saveas` (the
off-screen pattern is unreliable for 3D).

### 5.7 Probe ROI (`pf2.probe.roi.*`)

```matlab
pf2.probe.roi.defineROI(data)           % GUI ROI definition
```

### 5.7b Quality Control (`pf2.qc.*`)

```matlab
% Interactive channel-check GUI (auto-QC, PSD, per-channel detail)
app = pf2.qc.ChannelCheck(data)
app = pf2.qc.ChannelCheck(data, 'SkipConfirmation', true)   % headless-safe

% One-call headless QC summary (dashboard + PSD + SCI PNGs)
report = pf2.qc.snapshot(data, 'SaveDir', 'qc_out')

% Programmatic QC pipeline (headless)
report = pf2.qc.pipeline.assess(data)        % checks: saturation, sci, cardiac, cov, takizawa
data   = pf2.qc.pipeline.apply(data, report) % apply recommendations to fchMask
pf2.qc.pipeline.report(report)               % print summary
pf2.qc.pipeline.plotReport(report, 'SavePath', 'qc.png')
```

### 5.8 Method Management (`pf2.methods.*`)

```matlab
% List methods
pf2.methods()                           % List all (raw + oxy)
pf2.methods.raw()                       % List raw methods
pf2.methods.oxy()                       % List oxy methods
pf2.methods.raw.list()                  % Same as raw()
pf2.methods.oxy.list()                  % Same as oxy()

% Set active method
pf2.methods.raw.setMethod('x2_lpf_smar')    % By name
pf2.methods.raw.setMethod(3)                 % By index
pf2.methods.raw.setMethod()                  % Interactive

pf2.methods.oxy.setMethod('takizawa_easy')
pf2.methods.oxy.setMethod(2)
pf2.methods.oxy.setMethod()

% Method information
pf2.methods.raw.describeMethod('x2_lpf_smar')
pf2.methods.oxy.describeMethod('takizawa_easy')
pf2.methods.describeCurrentMethods()

% Method configuration (GUI)
pf2.methods.raw.configureMethods()
pf2.methods.oxy.configureMethods()

% Import external methods
pf2.methods.raw.importMethods(filepath)
pf2.methods.oxy.importMethods(filepath)
```

**Common Processing Methods:**

| Raw Method | Description | When to Use |
|------------|-------------|-------------|
| `x1_lpf` | Low-pass filter only | Clean data, minimal motion |
| `x2_lpf_smar` | LPF + SMAR motion correction | Moderate motion artifacts |
| `x5_TDDR` | TDDR motion correction | Spike artifacts |
| `x3_bpf` | Band-pass filter (0.008-0.1 Hz) | Isolate hemodynamic response |

| Oxy Method | Description | When to Use |
|------------|-------------|-------------|
| `None` | No post-processing | Already clean data |
| `takizawa_easy` | Lenient artifact rejection | Most data |
| `takizawa_hard` | Strict artifact rejection | Noisy data |
| `car` | Common Average Reference | Reduce global noise |

### 5.9 Settings (`pf2.settings.*`)

```matlab
% Device configuration
probeInfo = pf2.settings.selectDevice()                    % GUI selection
probeInfo = pf2.settings.selectDevice('fNIR_2000.cfg')     % By file
deviceInfo = pf2.settings.getDevice()                       % Query current

% Baseline settings
pf2.settings.baseline.setBaselineStartTime(0)
pf2.settings.baseline.setBaselineLength(10)
pf2.settings.baseline.useGlobalMean()                       % Use entire signal

% DPF (Differential Pathlength Factor)
pf2.settings.dpf.setDPFmode('Calc')     % 'None', 'Fixed', or 'Calc'
pf2.settings.dpf.setFixedDPF(5.93)      % Fixed value

% Quality control
pf2.settings.setRejectLevel(0)          % 0 = reject when fchMask==0
```

### 5.10 Processing (`pf2.process.*`)

```matlab
% Full processing (alias for processFNIRS2)
processed = pf2.process.process(data)

% Stage-specific processing
rawProcessed = pf2.process.processRaw(data)    % Stage 1 only
oxyProcessed = pf2.process.processOxy(data)    % Stage 3 only
```

### 5.11 GUI Configuration (`pf2.gui.*`)

```matlab
pf2.gui()                               % Launch main GUI
pf2.gui.configureRawMethods()           % Raw method editor
pf2.gui.configureOxyMethods()           % Oxy method editor
pf2.gui.functions()                     % Function library
pf2.gui.functions.add()                 % Add function
pf2.gui.functions.edit()                % Edit function
```

---

## 6. Layer 2: exploreFNIRS API Reference

### 6.1 Top-Level Entry Points

```matlab
% Launch GUI
exploreFNIRS(dataCell)                              % With data
exploreFNIRS(dataCell, 'timeShiftTo0', true, ...)   % With options
exploreFNIRS()                                       % Empty

% Session management
exploreFNIRS.loadEx()                               % Load session (dialog)
exploreFNIRS.loadEx(filepath)                       % Load specific file
exploreFNIRS.saveEx()                               % Save session (dialog)
exploreFNIRS.saveEx(filepath)                       % Save specific file
exploreFNIRS.browseEx()                             % File browser

% Version info
exploreFNIRS.versInfo()
```

### 6.1b Scriptable Experiment API (`exploreFNIRS.core.*`)

```matlab
% Create experiment from processed data
ex = exploreFNIRS.core.Experiment(allData);

% Filter and organize
ex.select('Group', {'Control', 'Treatment'}, 'Condition', 'Task');
ex.groupby({'Group', 'Condition'});
ex.aggregate();

% Headless temporal plot
fig = exploreFNIRS.core.plotTemporal(ex.groups, ...
    'Biomarkers', {'HbO'}, 'Channels', [1 5 10], ...
    'SavePath', 'temporal.png');

% Headless bar chart
fig = exploreFNIRS.core.plotBar(ex.groups, ...
    'Biomarker', 'HbO', 'TimeWindow', [5 25], ...
    'SavePath', 'bar.png');

% ROI-based plotting
fig = exploreFNIRS.core.plotTemporal(ex.groups, ...
    'Biomarkers', {'HbO'}, 'ROIs', 'all');

% Export
longTable = ex.toLongTable();
wideTable = ex.toWideTable();

% Connectivity analysis
connResults = ex.connectivity('Method', 'pearson');
fig = exploreFNIRS.connectivity.plotMatrix(connResults);

% Hyperscanning analysis
hsResults = ex.hyperscanning('Method', 'coherence');   % pairs by .info.DyadID
```

### 6.2 Dataset Operations (`exploreFNIRS.dataset.*`)

```matlab
% Build metadata table from fNIRS struct info fields
segmentTable = exploreFNIRS.dataset.buildSegmentInfoTable(dataCell)

% Standardize ROI definitions across subjects
dataCell = exploreFNIRS.dataset.standardizeROIs(dataCell, roiDef)
```

### 6.3 Export Functions (`exploreFNIRS.export.*`)

```matlab
% Export grouped data to tables
longTable = exploreFNIRS.export.mergeGbyTablesLong(gbyData)
wideTable = exploreFNIRS.export.mergeGbyTablesWide(gbyData)
```

**When to use each format:**
- **Long format**: R (lme4), tidyverse, repeated measures
- **Wide format**: SPSS, Excel pivot tables, between-subjects comparisons

### 6.4 Statistical Functions (`exploreFNIRS.fx.*`)

```matlab
% FDR correction for multiple comparisons
[qValues, criticalIdx] = exploreFNIRS.fx.performFDR(pValues, alpha)
[qValues, criticalIdx] = exploreFNIRS.fx.performFDR_twostep(pValues, alpha)

% Automated post-hoc contrasts
contrastTable = exploreFNIRS.fx.autoContrast(lmeModel)
contrastTable = exploreFNIRS.fx.autoContrast(lmeModel, pThreshold)
```

### 6.5 Plotting Functions (`exploreFNIRS.plot.*`)

> **Note**: Legacy `+plot/` functions require GUI handles. For headless plotting, use `exploreFNIRS.core.plotTemporal` and `exploreFNIRS.core.plotBar` instead.

```matlab
% Temporal plots (time series with error bands)
exploreFNIRS.plot.temporal(handles, gbyData, ...)

% Bar charts (with LME analysis)
exploreFNIRS.plot.barchart(handles, gbyData, ...)

% Scatter plots (correlations)
exploreFNIRS.plot.scatter(handles, gbyData, ...)
```

### 6.6 Helper Functions (`exploreFNIRS.helper.*`)

```matlab
% Colormap utilities
cmap = exploreFNIRS.helper.getColormap(name)
cmapList = exploreFNIRS.helper.listColormaps()

% String conversion
str = exploreFNIRS.helper.num2strOrNot(value)
```

---

## Appendix A: Complete Function List

### Layer 1 (pf2)

```
pf2.help
pf2.gui
pf2.methods
pf2.process

pf2.import.importNIR
pf2.import.importNIRX
pf2.import.importSNIRF
pf2.import.importHitachiMES
pf2.import.importOxy3
pf2.import.importDirectory
pf2.import.importEmbeddings
pf2.import.sampleData
pf2.import.sampleData.fNIR2000
pf2.import.sampleData.fNIR1200
pf2.import.sampleData.Hitachi_ETG4000_3x5
pf2.import.sampleData.Hitachi_ETG4000_3x11
pf2.import.sampleData.group

pf2.export.asNIR
pf2.export.asSNIRF
pf2.export.asBIDS
pf2.export.asTensor
pf2.export.export

pf2.data.plot
pf2.data.plot.oxy
pf2.data.plot.raw
pf2.data.plot.roi
pf2.data.plot.auxData
pf2.data.setT0
pf2.data.applyChannelMask
pf2.data.resample
pf2.data.crop
pf2.data.split
pf2.data.slidingWindows
pf2.data.getMarkers
pf2.data.getMarkerDict
pf2.data.setMarkerDict
pf2.data.labelMarkers
pf2.data.concatenate
pf2.data.concatenateHorizontal
pf2.data.defineBlocks
pf2.data.extractBlocks
pf2.data.blockAverage
pf2.data.grandAverage
pf2.data.blocksToEvents
pf2.data.betasToSegments
pf2.data.importInfo
pf2.data.importBlockInfo
pf2.data.infoToTable
pf2.data.infoFromTable
pf2.data.editChannelMaskGUI

pf2.probe.plot
pf2.probe.plot.topo
pf2.probe.plot.imageValues
pf2.probe.plot.imageROIvalues
pf2.probe.plot.interpolateValues
pf2.probe.plot.interpolateROIvalues
pf2.probe.plot.interpolateValues3D
pf2.probe.plot.arrangedValues
pf2.probe.plot.showProbe3D
pf2.probe.plot.connectome
pf2.probe.plot.movie
pf2.probe.project.biomarker
pf2.probe.project.pvalues
pf2.probe.project.fstats
pf2.probe.project.correlation
pf2.probe.project.counts
pf2.probe.project.regions
pf2.probe.project.parcels
pf2.probe.nearestBrodmann
pf2.probe.roi.defineROI

pf2.qc.ChannelCheck
pf2.qc.snapshot
pf2.qc.pipeline.assess
pf2.qc.pipeline.apply
pf2.qc.pipeline.report
pf2.qc.pipeline.plotReport

pf2.methods.raw
pf2.methods.raw.list
pf2.methods.raw.setMethod
pf2.methods.raw.describeMethod
pf2.methods.raw.configureMethods
pf2.methods.raw.importMethods
pf2.methods.raw.create
pf2.methods.raw.delete
pf2.methods.raw.editFunction
pf2.methods.raw.removeFunction
pf2.methods.raw.exportMethod
pf2.methods.raw.importMethod
pf2.methods.oxy
pf2.methods.oxy.list
pf2.methods.oxy.setMethod
pf2.methods.oxy.describeMethod
pf2.methods.oxy.configureMethods
pf2.methods.oxy.importMethods
pf2.methods.oxy.create
pf2.methods.oxy.delete
pf2.methods.oxy.editFunction
pf2.methods.oxy.removeFunction
pf2.methods.oxy.exportMethod
pf2.methods.oxy.importMethod
pf2.methods.validateFunction
pf2.methods.describeCurrentMethods

pf2.settings.selectDevice
pf2.settings.getDevice
pf2.settings.setRejectLevel
pf2.settings.baseline.setBaselineStartTime
pf2.settings.baseline.setBaselineLength
pf2.settings.baseline.useGlobalMean
pf2.settings.dpf.setDPFmode
pf2.settings.dpf.setFixedDPF

pf2.process.process
pf2.process.processRaw
pf2.process.processOxy

pf2.gui.configureRawMethods
pf2.gui.configureOxyMethods
pf2.gui.functions
pf2.gui.functions.add
pf2.gui.functions.edit
```

### Layer 2 (exploreFNIRS)

```
exploreFNIRS (main)
exploreFNIRS.loadEx
exploreFNIRS.saveEx
exploreFNIRS.browseEx
exploreFNIRS.versInfo
exploreFNIRS.processMethods
exploreFNIRS.plotExTimeline

exploreFNIRS.core.Experiment
exploreFNIRS.core.plotTemporal
exploreFNIRS.core.plotBar
exploreFNIRS.core.getGroupColors

exploreFNIRS.connectivity.computeMatrix
exploreFNIRS.connectivity.plotMatrix
exploreFNIRS.connectivity.plotBlockComparison

exploreFNIRS.coupling.pearson
exploreFNIRS.coupling.spearman
exploreFNIRS.coupling.xcorr
exploreFNIRS.coupling.coherence
exploreFNIRS.coupling.wcoherence

exploreFNIRS.hyperscanning.pairSubjects
exploreFNIRS.hyperscanning.computeDyad
exploreFNIRS.hyperscanning.computeGroup
exploreFNIRS.hyperscanning.permutationTest
exploreFNIRS.hyperscanning.plotGroup

exploreFNIRS.dataset.buildSegmentInfoTable
exploreFNIRS.dataset.standardizeROIs

exploreFNIRS.export.mergeGbyTablesLong
exploreFNIRS.export.mergeGbyTablesWide
exploreFNIRS.export.connectivityToTable

exploreFNIRS.fx.performFDR
exploreFNIRS.fx.performFDR_twostep
exploreFNIRS.fx.autoContrast

exploreFNIRS.plot.temporal
exploreFNIRS.plot.barchart
exploreFNIRS.plot.barchart_infogroup
exploreFNIRS.plot.scatter

exploreFNIRS.helper.getColormap
exploreFNIRS.helper.listColormaps
exploreFNIRS.helper.num2strOrNot
```

---

## Appendix B: GUI-to-CLI Mapping

For users transitioning from the GUI to command-line:

### processFNIRS2 GUI Actions

| GUI Action | CLI Equivalent |
|------------|----------------|
| File → Open | `data = pf2.import.importNIR(filepath)` |
| Select Raw Method (dropdown) | `pf2.methods.raw.setMethod('method_name')` |
| Select Oxy Method (dropdown) | `pf2.methods.oxy.setMethod('method_name')` |
| Set Baseline Length | `pf2.settings.baseline.setBaselineLength(10)` |
| Click "Process" | `processed = processFNIRS2(data)` |
| View Time Series | `pf2.data.plot.oxy(processed)` |
| View Topography | `pf2.probe.plot.topo(processed, 'HbO', 'Time', t)` |
| Edit Channel Mask | `pf2.data.editChannelMaskGUI(data)` or `data.fchMask = [...]` |
| Export SNIRF | `pf2.export.asSNIRF(processed, 'output.snirf')` |

### exploreFNIRS GUI Actions

| GUI Action | CLI Equivalent |
|------------|----------------|
| Load Session | `exploreFNIRS.loadEx(filepath)` |
| Save Session | `exploreFNIRS.saveEx(filepath)` |
| Group by Variable | `ex.groupby({'Group', 'Condition'})` |
| Within-subject Average | `ex.aggregate()` |
| Generate Temporal Plot | `exploreFNIRS.core.plotTemporal(ex.groups, ...)` |
| Generate Bar Chart | `exploreFNIRS.core.plotBar(ex.groups, ...)` |
| Export Long Format | `ex.toLongTable()` or `exploreFNIRS.export.mergeGbyTablesLong(gbyData)` |
| Export Wide Format | `ex.toWideTable()` or `exploreFNIRS.export.mergeGbyTablesWide(gbyData)` |

### Example: Replicating a GUI Workflow

**In the GUI, you would:**
1. Click File → Open and select a .nir file
2. In the Method dropdown, select "x2_lpf_smar"
3. Set baseline to 10 seconds
4. Click "Process"
5. View the time series plot
6. Save as SNIRF

**CLI equivalent:**
```matlab
% Steps 1-2: Import and configure
data = pf2.import.importNIR('/path/to/file.nir');
pf2.methods.raw.setMethod('x2_lpf_smar');

% Step 3: Set baseline
pf2.settings.baseline.setBaselineLength(10);

% Step 4: Process
processed = processFNIRS2(data);

% Step 5: View
pf2.data.plot.oxy(processed);

% Step 6: Export
pf2.export.asSNIRF(processed, 'output.snirf');
```

---

*Document created: 2026-01-23*
*Updated: 2026-06-23 — Corrected headless processing (output-assignment suppresses GUI, not `'ShowGUI', false`); added importOxy3/importDirectory/importEmbeddings, asBIDS/asTensor/export, block-averaging and marker-dictionary helpers, metadata table round-trip, the topo wrapper and `pf2.probe.project.*` projections (fixing the stale imageValues signature), and the `pf2.qc.*` surface; refreshed the Appendix A function list.*
*Updated: 2026-02-06 — Added Experiment class, connectivity, hyperscanning, method CRUD, block definition*
