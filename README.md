# processFNIRS2 v1.0.0

## Overview
processFNIRS2 is a modular MATLAB toolbox designed for processing functional Near-Infrared Spectroscopy (fNIRS) data. The toolbox provides a flexible framework for importing, processing, analyzing, and visualizing fNIRS data from multiple device manufacturers.

## Key Features
- **Modular processing pipeline** for both raw intensity data and hemoglobin concentration data
- **Device-agnostic design** with support for multiple fNIRS systems:
  - fNIR Devices/Biopac
  - Hitachi ETG-4000
  - NIRx systems
- **Customizable processing methods** that can be configured and saved
- **Motion correction**: TDDR, SMAR, wavelet, spline interpolation (Scholkmann 2010)
- **Filtering**: FIR bandpass, Butterworth IIR bandpass/lowpass/highpass
- **Robust visualization tools** including:
  - Time series plots
  - Topographic mapping
  - Interactive data exploration via exploreFNIRS
- **Channel quality assessment** with Scalp Coupling Index (SCI), power spectrum analysis, and artifact rejection
- **Region-of-Interest (ROI) analysis** support
- **Statistical analysis** with LME models integrated in exploreFNIRS
- **Data export** in various formats including NIR, SNIRF, CSV and MATLAB formats

## Getting Started

### Installation
1. Clone or download this repository
2. Add the main processFNIRS2 folder and the following subdirectories to your MATLAB path:
   ```matlab
   addpath('/path/to/processFNIRS2');
   addpath('base_functions', 'GUI', 'functions');
   ```
   Note: Package folders (those with `+` prefix like `+pf2`, `+pf2_base`) are automatically available once the parent folder is on the path.

### Quick Start Guide
```matlab
% Import data
mydata = pf2.import.importNIR('myNIRSfile.nir');

% Configure processing methods
processFNIRS2(); % Opens GUI for method configuration
% Or select methods programmatically:
pf2.methods.raw.setMethod('MyRawMethod');
pf2.methods.oxy.setMethod('MyOxyMethod');

% Process data
myprocesseddata = processFNIRS2(mydata);

% Visualize data
pf2.data.plot.oxy(myprocesseddata);
pf2.data.plot.roi(myprocesseddata);

% Export single file
pf2.export.asNIR(myprocesseddata, 'myexport.nir');
pf2.export.asSNIRF(myprocesseddata, 'myexport.snirf');

% Batch export cell array to directory
pf2.export.asSNIRF(allData, 'output/');
pf2.export.asSNIRF(allData, 'output/', 'Dir1', 'Group', 'Prefix', {'SubjectID'});

% Explore and analyze data
exploreFNIRS(myprocesseddata);
```

## Processing Pipeline

### Data Import
Use functions in the `pf2.import` module to load data from various fNIRS devices:
- `pf2.import.importNIR`: Import fNIR Devices/Biopac files
- `pf2.import.importHitachiMES`: Import Hitachi ETG-4000 files
- `pf2.import.importNIRX`: Import NIRx system files
- `pf2.import.importSNIRF`: Import SNIRF format files
- `pf2.import.sampleData`: Load example datasets included with the toolbox

### Data Manipulation
The toolbox provides various functions for manipulating fNIRS data:
- `pf2.data.applyChannelMask`: Set bad channels to NaN
- `pf2.data.getMarkers`: Find specific markers in the data
- `pf2.data.resample`: Resample or average fNIRS data
- `pf2.data.setT0`: Shift time to align with experiment start
- `pf2.data.split`: Split fNIRS segments based on time points
- `pf2.data.defineBlocks`: Convert markers to block struct array
- `pf2.data.extractBlocks`: Extract fNIRS segments by block definitions
- `pf2.data.blockAverage` / `grandAverage`: Trial/grand average epoched segments
- `pf2.data.plot`: Visualize fNIRS data (Oxy, Raw, ROI, AuxData)
- `pf2.qc`: Channel quality assessment (SCI, power spectrum, QC plots)
- `pf2.export`: Export data to NIR or SNIRF formats

### Method Configuration
processFNIRS2 uses a two-stage processing pipeline:
1. **Raw processing** (Raw → Optical Density)
   - Configure and select methods using `pf2.methods.raw`
   - Common preprocessing includes: motion artifact correction, filtering, CAR, etc.

2. **Oxy processing** (Optical Density → Hemoglobin)
   - Configure and select methods using `pf2.methods.oxy`
   - Processing includes: Beer-Lambert conversion, filtering, ROI analysis, etc.

Methods can be configured through the GUI or programmatically:
```matlab
% Open method configuration GUI
pf2.methods.raw.configureMethods();
pf2.methods.oxy.configureMethods();

% List available methods
pf2.methods.raw.list();
pf2.methods.oxy.list();

% Set methods programmatically
pf2.methods.raw.setMethod('MyRawMethod');
pf2.methods.oxy.setMethod('MyOxyMethod');

% Create, modify, and share methods (new in v1.0.0)
pf2.methods.raw.create('MyCustomMethod');
pf2.methods.raw.editFunction('MyCustomMethod', 'pf2_lpf', struct('freq_cut', 0.08));
pf2.methods.raw.exportMethod('MyCustomMethod', 'my_method.mat');
pf2.methods.raw.importMethod('shared_method.mat');
pf2.methods.raw.delete('OldMethod');
```

### Building Pipelines Programmatically
For full code-level control, build a processing chain step by step with the
Pipeline API (`pf2_base.RawPipeline` for Stage 1, `pf2_base.OxyPipeline` for
Stage 3). Pipelines are value objects: every mutating call returns a new copy.

```matlab
% Build a raw-stage pipeline from scratch
p = pf2_base.RawPipeline('myPipeline');
p = p.add('pf2_Intensity2OD');                 % required first step
p = p.add('pf2_MotionCorrectTDDR');
p = p.add('pf2_lpf', 'freq_cut', 0.08);        % step with a parameter

% Inspect, modify, reorder
disp(p.describe());                             % print steps + current params
p = p.setParam('pf2_lpf', 'freq_cut', 0.05);   % tune a parameter
p = p.insert(2, 'pf2_hpf', 'freq_cut', 0.01);  % insert at a position
p = p.move('pf2_hpf', 3);                       % reorder steps (no add/remove)
p = p.swapStep('pf2_MotionCorrectTDDR', 'pf2_MotionCorrectWavelet'); % replace a step
p = p.remove('pf2_hpf');                        % drop a step

% Run it end-to-end on a data struct
out = p.run(data);                             % returns standard processFNIRS2 output

% Or persist it as a named method (the pipeline's name becomes the method name)
p.save('raw');                                  % register 'myPipeline' as a raw method
p2 = pf2_base.RawPipeline.fromMethod('myPipeline');  % reload later
```

To start from an existing method instead of an empty pipeline, load it with
`pf2_base.RawPipeline.fromMethod('x6_TDDR_lpf')`, then `describe()`, edit, and
`run()` or `save()`.

**Writing a custom processing step:** a step is a plain function on the path.
Its arguments are bound *by name* — reserved names like `x` (the signal
matrix), `fs`, `fTime`, and `fchMask` are auto-filled from the processing
context; any other name takes its value from the step's defaults. Declare `x`
as an output to write the result back into the pipeline.

```matlab
% functions/pf2_zscore.m
function xz = pf2_zscore(x)
    xz = (x - mean(x,1,'omitnan')) ./ std(x,0,1,'omitnan');
end

% wire it in: add('name', {args}, {defaults}, {outputs})
p = p.add('pf2_zscore', {'x'}, {[]}, {'x'});
```

See `help pf2_base.PipelineFunction` for the full list of reserved argument
names and the input/output contract, and `examples/scripts/example_pipeline_basics.m`
and `examples/scripts/example_pipeline_custom_function.m` for runnable walkthroughs.

### Data Processing
Process data using the selected methods:
```matlab
% Process both raw and oxy stages
myprocesseddata = processFNIRS2(mydata);

% Process specific stages only
myrawprocessed = pf2.process.processRaw(mydata);
myoxyprocessed = pf2.process.processOxy(myrawprocessed);
```

### Context-Based Processing
For isolated, reproducible processing (useful for testing, parallel processing, or saving analysis settings):
```matlab
% Create a context from current settings
ctx = pf2_base.ProcessingContext.fromGlobals();

% Modify settings without affecting globals
ctx.dpfMode = 'Fixed';
ctx.dpfFixedValue = 6.0;
ctx.baselineLength = 5;
ctx.setRawMethod('x5_TDDR');
ctx.setOxyMethod('takizawa_easy');

% Process with isolated settings
result = processFNIRS2(mydata, 'Context', ctx);

% Save settings for reproducibility
save('my_analysis_settings.mat', '-struct', ctx.toStruct());

% Parallel processing with different ages
parfor i = 1:numSubjects
    ctx = pf2_base.ProcessingContext.fromGlobals();
    ctx.subjectAge = ages(i);
    results{i} = processFNIRS2(data{i}, 'Context', ctx);
end
```

### Visualization and Export
Visualize and export your processed data:
```matlab
% Visualize different aspects of the data
pf2.data.plot.oxy(myprocesseddata);                   % Plot all channels
pf2.data.plot.oxy(myprocesseddata, 5);                % Single channel
pf2.data.plot.oxy(myprocesseddata, 'baseline', 10);   % With 10s baseline
pf2.data.plot.oxy(myprocesseddata, 1:5, 'ylim', [-2 2]);  % Channels 1-5, fixed y
pf2.data.plot.raw(myprocesseddata);                   % Plot raw intensity data
pf2.data.plot.roi(myprocesseddata);                   % Plot region of interest data
pf2.data.plot.auxData(myprocesseddata);               % Plot auxiliary data

% Topographic activation maps (2D heatmap or 3D cortical surface)
pf2.probe.plot.topo(myprocesseddata, 'HbO', 'Time', 30);            % 2D at t=30s
pf2.probe.plot.topo(myprocesseddata, 'HbO', 'View', '3d');         % 3D surface
pf2.probe.plot.topo(myprocesseddata, 'HbO', 'savePath', 'topo.png'); % headless save

% Plots automatically show device, method, and DPF info in title
% e.g., "fNIR2000C | x5_TDDR | DPF(age=25)"

% Export single file
pf2.export.asNIR(myprocesseddata, 'myexport.nir');
pf2.export.asSNIRF(myprocesseddata, 'myexport.snirf');

% Batch export cell array to a directory
pf2.export.asSNIRF(allData, 'output/');                          % Flat
pf2.export.asSNIRF(allData, 'output/', 'Dir1', 'Group');         % Subdirs from .info
pf2.export.asSNIRF(allData, 'output/', 'Prefix', {'SubjectID'}); % Named files
```

### Group & Statistical Visualization
Once you have a group of processed subjects, exploreFNIRS provides group plots
and statistics. The fastest on-ramp uses the built-in synthetic group:
```matlab
% One-call ready group (or pass your own cell array of processed structs)
[ex, allData] = pf2.import.sampleData.group();

% Group plots
ex.plotBar('Biomarker', 'HbO');                   % Condition bar chart
ex.plotTemporal('Biomarkers', {'HbO','HbR'});     % Group-averaged timeseries
[fig, results] = ex.plotLME('Biomarkers', {'HbO'});  % LME + F-stat bars
ex.plotTopoLME('Biomarkers', {'HbO'});            % LME mapped onto the brain

% Bridge computed stats to a brain projection (compute -> project)
pCondition = nan(1, size(allData{1}.HbO, 2));
pCondition(results.channels) = results.anova_pval.Condition;
pf2.probe.project.pvalues(pCondition, allData{1}, 'includeSS', true);

% See examples/scripts/example_group_stats_bridge.m for the full pattern.
```

### Processing Metadata
Processed data includes `processingInfo` for reproducibility:
```matlab
% Access processing settings used
myprocesseddata.processingInfo.dpfMode        % 'None', 'Fixed', 'Calc'
myprocesseddata.processingInfo.rawMethod      % e.g., 'x5_TDDR'
myprocesseddata.processingInfo.deviceName     % e.g., 'fNIR2000C'
myprocesseddata.processingInfo.timestamp      % When processed
```

### Quality Control
Assess signal quality before or after processing. The recommended workflow is
the headless QC pipeline (`assess` → `report`/`plotReport` → `apply`), with
`snapshot` as a one-call summary:
```matlab
% One-call headless summary — runs all checks and writes dashboard + PSD + SCI
% PNGs to a directory, returns the report struct
report = pf2.qc.snapshot(data, 'SaveDir', 'qc_out');

% Programmatic pipeline (headless, no GUI)
report = pf2.qc.pipeline.assess(data);            % checks: saturation, sci,
                                                  %   cardiac, cov, takizawa
report = pf2.qc.pipeline.assess(data, ...         % override thresholds / subset
    'SCIThreshold', 0.8, 'Checks', {'saturation','sci','cov'});
pf2.qc.pipeline.report(report);                   % per-channel text table
pf2.qc.pipeline.plotReport(report, 'Visible', 'off', 'SavePath', 'qc.png');
data = pf2.qc.pipeline.apply(data, report);       % AND results into data.fchMask
% report.pass [1×nCh]; report.<check>.pass / .values

% Interactive GUI (auto-runs all checks, probe grid, PSD); headless-safe with
% 'SkipConfirmation', true
app = pf2.qc.ChannelCheck(data);

% Individual primitives
sciResult = pf2.qc.sci(data);                     % Scalp Coupling Index
psdResult = pf2.qc.powerSpectrum(data, 'Signal', 'raw');  % cardiac/resp peaks
pf2.qc.plotQuality(sciResult);
```

### Block Definition & Extraction
Define and extract experimental blocks from marker events:
```matlab
% Define blocks from marker codes with 30-second duration
blocks = pf2.data.defineBlocks(data, [49, 50], 30, ...
    'ConditionMap', {49, 'Easy'; 50, 'Hard'}, 'Embed', false);

% Import per-trial behavioral data from CSV
blocks = pf2.data.importBlockInfo(blocks, 'trial_data.csv', ...
    'MarkerCode', [49, 50]);

% Extract fNIRS segments aligned to block onset. NOTE: PreTime and PostTime
% both default to 120 s — always set them, or a short block becomes a very
% long segment.
segments = pf2.data.extractBlocks(data, blocks, ...
    'PreTime', 5, 'PostTime', 15, 'SetT0', true);

% Single-subject trial/grand average onto a common grid (one call)
ga = pf2.data.blockAverage(segments);             % or pf2.data.grandAverage
plot(ga.time, ga.HbO.Mean(:,1));                  % ga.<HbO|...>.{Mean,SEM,SD,N}

% Or feed segments into Experiment for multi-condition / group analysis
ex = exploreFNIRS.core.Experiment(segments);
```

### Metadata Import
Import subject-level and block-level metadata from CSV/Excel:
```matlab
% Subject demographics (one row per subject, matched by SubjectID)
allData = pf2.data.importInfo(allData, 'demographics.csv', 'SubjectID');

% Block-level behavioral data (positional or key-based matching)
blocks = pf2.data.importBlockInfo(blocks, 'behavior.csv', ...
    'MarkerCode', 49);  % only apply to task blocks
```

See `examples/scripts/example_import_blocks.m` for a complete walkthrough, or `examples/scripts/tutorial_batch_workflow.m` for a realistic multi-subject workflow with directory import, CSV metadata merge, batch processing, and batch export.

### GLM Analysis
An alternative to the epoch/average approach. The GLM keeps continuous recordings intact and fits HRF-convolved regressors per subject:
```matlab
% 1. Define blocks and convert to GLM events
blocks = pf2.data.defineBlocks(data, [49, 50], 30, ...
    'ConditionMap', {49, 'Easy'; 50, 'Hard'}, 'Embed', false);
events = pf2.data.blocksToEvents(blocks);

% 2. Build design matrix (with drift regressors)
[X, names] = pf2_base.fnirs.buildDesignMatrix(data.time, data.fs, events);

% 3. Fit GLM per biomarker
hboResults = pf2_base.fnirs.fitGLM(data.HbO, X, names);
hbrResults = pf2_base.fnirs.fitGLM(data.HbR, X, names);

% 4. Package betas for Experiment
segments = pf2.data.betasToSegments(hboResults, data, ...
    'BiomarkerResults', struct('HbO', hboResults, 'HbR', hbrResults), ...
    'Conditions', {'Easy', 'Hard'});

% 5. Group analysis (no baseline correction or resampling for betas)
ex = exploreFNIRS.core.Experiment(allSegments);
ex.settings.useBaseline = false;
ex.settings.resampleRate = 0;
ex.groupby({'Condition'});
ex.aggregate();
fig = ex.plotBar('Biomarker', 'HbO', 'ShowIndividual', true);
```

For a streamlined workflow, `GLMExperiment` wraps the entire pipeline into a single class:
```matlab
% GLMExperiment: processing + GLM + group analysis in one object
[subjects, blockDefs] = pf2.import.sampleData.experiment('blocks');
gx = exploreFNIRS.core.GLMExperiment(subjects, blockDefs);
gx.glm.conditions = {'Easy', 'Hard'};
gx.glm.auxFields = {'heartRate'};  % also fit GLM on heart rate
gx.fit();

% All Experiment methods work on beta data
gx.groupby({'Condition'});
gx.aggregate();
fig = gx.plotBar('Biomarker', 'HbO', 'ShowIndividual', true);

% Topographic LME: F-statistics on 3D brain surface
[fig, results] = gx.plotTopoLME('Biomarkers', {'HbO'}, 'ShowIntercept', false);

% Per-subject inspection and direct export
gx.plotDesignMatrix(1);
T = gx.betaTable('IncludeStats', true);
```

See `examples/scripts/example_glm_analysis.m` for a complete walkthrough, or `examples/scripts/example_glm_advanced.m` for the manual step-by-step pipeline with first-level contrasts.

### Advanced Analysis with exploreFNIRS
For group-level data exploration and statistical analysis, use the exploreFNIRS module:

> **Input expectations.** `Experiment` computes task/baseline statistics over
> **epoched segments**, not continuous recordings. For task-based stats, first
> extract blocks (`pf2.data.defineBlocks` → `pf2.data.extractBlocks`, see
> [Block Definition & Extraction](#block-definition--extraction)) and build the
> Experiment from the resulting segments. Also make sure `settings.baseline`
> falls **within** each segment's time range — a baseline window that precedes
> the data (e.g. `[-5 0]` on data starting at t≈0 with `useBaseline=true`)
> yields all-NaN aggregates and empty LME results.

```matlab
% Load multiple processed subjects into a cell array
allData = {subject1, subject2, subject3, ...};

% Launch exploreFNIRS GUI
exploreFNIRS(allData);

% Or use the scriptable Experiment class (no GUI needed)
ex = exploreFNIRS.core.Experiment(allData);
ex.select('Group', {'Control', 'Treatment'});
ex.groupby({'Group', 'Condition'});

% Configure preprocessing
ex.settings.baseline = [-5, 0];
ex.settings.resampleRate = 1;
ex.settings.useBaseline = true;

% Visualize time settings before aggregating
fig = ex.plotExperimentTimeline();

ex.aggregate();

% Branch a new analysis from the same data and settings
ex2 = exploreFNIRS.core.Experiment(ex);
ex2.select('Condition', 'Hard');
ex2.groupby({'Group'});

% Headless plots
fig = ex.plotTemporal('Biomarkers', {'HbO'}, 'Channels', 1:5);
fig = ex.plotBar('Biomarker', 'HbO', 'ShowIndividual', true);
[fig, stats] = ex.plotLME('Biomarkers', {'HbO'});
[fig, stats] = ex.plotScatter('InfoVar', 'Age', 'Biomarkers', {'HbO'});

% ROI-based plotting
fig = ex.plotTemporal('Biomarkers', {'HbO'}, 'ROIs', 'all');

% Advanced visualization (auto-uses probe geometry, excludes short-sep)
fig = ex.plotTopo('Biomarker', 'HbO', 'Time', 15);
fig = ex.plotHeatmap('Biomarker', 'HbO');
fig = ex.plotComposite(panels, 'Layout', [1, 3]);

% Connectivity analysis (symmetric and directed)
connResults = ex.connectivity('Method', 'pearson');
connDirected = ex.connectivity('Method', 'granger');
intraROI = ex.intraROI('Method', 'pearson');
interROI = ex.interROI('Method', 'pearson');

% Dynamic functional connectivity with brain states
dfc = exploreFNIRS.connectivity.computeDynamicFC(data, 'WindowSize', 30);
states = exploreFNIRS.connectivity.detectStates(dfc, 'K', 3);

% Hyperscanning analysis (inter-brain synchrony)
% Input: a cell array of processed subjects, each tagged with a shared
% .info.DyadID so partners can be paired (.info.Role optionally labels them).
subjA.info.DyadID = 1; subjA.info.Role = 'A';
subjB.info.DyadID = 1; subjB.info.Role = 'B';
exHS = exploreFNIRS.core.Experiment({subjA, subjB});
hsResults = exHS.hyperscanning('Method', 'coherence');   % pairs by DyadID
% For HB-ICA on a single dyad: exploreFNIRS.hyperscanning.hbica(subjA, subjB)

% Standalone statistical analysis (no visualization)
results = ex.statsFitLME('Biomarkers', {'HbO'}, 'Channels', 1:5);
T = ex.statsSummarize(results, 'Type', 'anova', 'Format', 'apa');
cr = ex.statsRunContrasts(results, 'FDRThreshold', 0.05);

% Export
longTable = ex.exportLong();
```

exploreFNIRS features:
- **Scriptable Experiment class** for complete headless group analysis with copy constructor for branching analyses
- **Timeline visualization** (`plotExperimentTimeline`) shows baseline, task, and resample settings before processing
- Group-level analysis with hierarchical averaging
- **Connectivity analysis** with 7 coupling methods (Pearson, Spearman, xcorr, coherence, wavelet coherence, Granger causality, transfer entropy)
- **Dynamic FC** — sliding-window connectivity with k-means brain state detection
- **ROI connectivity** — intra-ROI and inter-ROI coupling analysis with chord/radar visualization
- **Hyperscanning** with subject pairing, dyad/group computation, permutation testing, and inter-brain topographic display
- **Block-wise analysis** for connectivity and hyperscanning
- **Statistical analysis module** (`+stats/`) — standalone LME fitting, post-hoc contrasts with FDR, publication-ready summaries (ANOVA, coefficients, fit, APA format)
- Linear mixed-effects modeling with Satterthwaite degrees of freedom
- **Publication-ready visualization**: temporal plots, bar charts, scatter plots, topographic maps, heatmaps, composite multi-panel figures, directed connectivity diagrams, chord diagrams, dynamic FC plots
- **Headless plotting** with ROI support (plotTemporal, plotBar, plotTopo, plotHeatmap, plotComposite, plotLME, plotScatter)
- **Centralized plot styling** via PlotStyle with publication/presentation presets
- FDR correction: `exploreFNIRS.fx.performFDR()`
- Data export: `exploreFNIRS.export.mergeGbyTablesWide()` / `mergeGbyTablesLong()`

See [ExploreFNIRS_README.md](ExploreFNIRS_README.md) for detailed documentation.

## Settings Configuration
Adjust common settings using the Settings module:
```matlab
% Baseline settings
pf2.settings.baseline.setBaselineStartTime(0);
pf2.settings.baseline.setBaselineLength(5);

% DPF (Differential Path Length) settings
pf2.settings.dpf.setDPFmode('Calc'); % 'None', 'Fixed', or 'Calc'
pf2.settings.dpf.setFixedDPF(5.93);

% Device selection
pf2.settings.selectDevice('fNIR_Devices_fNIR1200_16ch.cfg');
```

## File Structure
- `processFNIRS2.m`: Main function for processing fNIRS data
- `pf2.m`: Convenience wrapper for processFNIRS2
- `exploreFNIRS.m`: Group-level analysis GUI
- `+pf2/`: User-facing API (import, export, data, methods, settings, probe)
- `+pf2_base/`: Internal infrastructure, utilities, and tests (300+ tests)
- `+exploreFNIRS/`: Group analysis (core, connectivity, coupling, hyperscanning, plot, export, fx, dataset)
- `base_functions/`: Utility functions (legacy)
- `GUI/`: User interface components (legacy, GUIDE-based)
- `functions/`: Signal processing algorithms (TDDR, SMAR, wavelet, spline, Butterworth IIR, FIR, SCI rejection, SSR, Takizawa)
- `devices/`: Device configuration files (.cfg)
- `sampledata/`: Example datasets

## Overall Structure
processFNIRS2 is laid out in the following manner:
- **data**: Functions to manipulate individual fNIRS segments
  - applyChannelMask: Set bad channels to nan
  - getMarkers: Find timepoints of markers in a regex style
  - resample: Resample or average fNIRS data
  - setT0: Shift fNIRS time to match start of experiment
  - split: Split fNIRS segment based on different input times
  - defineBlocks: Convert markers to block struct array
  - extractBlocks: Extract fNIRS segments by block definitions
  - blockAverage / grandAverage: Trial/grand average of epoched segments
  - blocksToEvents: Convert blocks to GLM event structs
  - betasToSegments: Package GLM betas for Experiment
  - **plot**: Functions to visualize fNIRS data
    - auxData: Plot auxiliary data channels
    - oxy: Plot oxygenation data
    - roi: Plot Region of Interest data
    - raw: Plot raw intensity data
  - **export**: Functions to export fNIRS data (single file or batch)
    - export: Auto-detect format from extension; batch with `'Format'` param
    - asNIR: Export to NIR file format (single or batch)
    - asSNIRF: Export to SNIRF file format (single, multi-run, or batch)
- **gui**: Shortcut for accessing the GUI
- **help**: Access to help documentation
- **import**: Functions to import fNIRS files
  - importHitachiMES: Import Hitachi Probes
  - importNIRX: Import NIRx files
  - importNIR: Import fNIR Devices/Biopac files
  - importSNIRF: Import SNIRF format files
  - sampleData: Load sample data included with the toolbox
- **methods**: Functions to change and modify processing methods
  - oxy: Oxy conversion pipeline methods
  - raw: Raw domain pipeline methods
- **qc**: Channel quality assessment
  - sci: Scalp Coupling Index
  - powerSpectrum: Power spectral density with peak detection
  - plotQuality: QC visualization
- **process**: Process fNIR segment data
  - processOxy: Run the Oxy Pipeline only
  - processRaw: Run the Raw Pipeline only
- **settings**: Change settings related to processing
  - baseline: Change baseline time settings
  - dpf: Change mode of Differential Path Length
  - selectDevice: Reload device settings for FNIRS probe

## Troubleshooting Tips
- When importing data for the first time, verify that the probe configuration is correct
- If you get errors about DPF factors, check the settings using `pf2.settings.dpf`
- For visualization issues, try running with default methods first
- If having trouble loading the software, check the MATLAB preference directory (`prefdir`) and delete any related settings files
- Remember that GUI settings are for visualization only and don't affect your data

## Preferences and Configuration
Settings, loaded functions, and methods are stored in the MATLAB preference directory.
Access this location using the MATLAB command: `prefdir`

## Documentation
For detailed function documentation, use MATLAB's `help` command:
```matlab
help processFNIRS2
help pf2.methods.raw
help pf2.import.importNIR
```

## License
processFNIRS2 is free for academic and non-commercial use, but some included code may have other licenses.

## Citation
If you use processFNIRS2 in your research, please cite:
[Citation information to be added]

## Contact
For questions or support, contact Dr. Adrian Curtin at adrian.b.curtin@drexel.edu