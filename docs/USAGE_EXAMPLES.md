# Usage Examples

Worked, copy-pasteable workflows. Each is self-contained; most run on the
bundled sample data.

## Contents
1. [Command-Line Processing](#workflow-1-command-line-processing)
2. [GUI-Based Processing](#workflow-2-gui-based-processing)
3. [Programmatic Method Selection](#workflow-3-programmatic-method-selection)
4. [Advanced Analysis (exploreFNIRS)](#workflow-4-advanced-analysis-explorefnirs)
5. [Connectivity Analysis](#workflow-5-connectivity-analysis)
6. [Hyperscanning Analysis](#workflow-6-hyperscanning-analysis) · [6b. HB-ICA Hyperscanning](#workflow-6b-hb-ica-hyperscanning)
7. [Block Definition, Extraction, and Trial Averaging](#workflow-7-block-definition-extraction-and-trial-averaging)
8. [Metadata Import from CSV/Excel](#workflow-8-metadata-import-from-csvexcel)
9. [Context-Based Processing](#workflow-9-context-based-processing)
10. [Custom Method Management](#workflow-10-custom-method-management)
11. [GLM Analysis with Short-Channel PCA](#workflow-11-glm-analysis-with-short-channel-pca)
12. [Data Quality Assessment](#workflow-12-data-quality-assessment)
13. [Color Schemes for Group Plots](#workflow-13-color-schemes-for-group-plots)
14. [Dark Mode and Theme Control](#workflow-14-dark-mode-and-theme-control)
15. [Data Manipulation](#workflow-15-data-manipulation)
16. [Metadata Table Editing](#workflow-16-metadata-table-editing)
17. [Probe Visualization](#workflow-17-probe-visualization)
18. [Brodmann Area Lookup](#workflow-18-brodmann-area-lookup)
19. [Pipeline API](#workflow-19-pipeline-api)
20. [GLM Diagnostics](#workflow-20-glm-diagnostics)
21. [Portable Montage Descriptor](#workflow-21-portable-montage-descriptor)
22. [Sliding Windows](#workflow-22-sliding-windows-dynamic-connectivity-fixed-length-input)
23. [Canonical Region Axis](#workflow-23-canonical-region-axis-cross-device-pooling)
24. [Foundation-Model Export (HDF5 tensor)](#workflow-24-foundation-model-export-hdf5-tensor-and-re-import)
- [Real-World Usage: Multi-Device Workflow](#real-world-usage-multi-device-workflow)

## Workflow 1: Command-Line Processing
```matlab
% Load data
data = pf2.import.importNIR('myfile.nir');

% Process with defaults
processed = processFNIRS2(data);

% Export
pf2.export.asSNIRF(processed, 'output.snirf');
```

## Workflow 2: GUI-Based Processing
```matlab
% Open GUI (interactive method selection)
processFNIRS2('ShowGUI', true);

% Or simply:
processFNIRS2();
```

## Workflow 3: Programmatic Method Selection
```matlab
% Set methods (browse names with pf2.methods.raw.list() / pf2.methods.oxy.list())
pf2.methods.raw.setMethod('OD_TDDR');
pf2.methods.oxy.setMethod('takizawa_easy');

% Configure parameters
processFNIRS2('blLength', 10, 'blStartTime', 0, ...
              'defaultSubjectAge', 30, 'DPFmode', 'Calc');

% Process
result = processFNIRS2(data);
```

## Workflow 4: Advanced Analysis (exploreFNIRS)
```matlab
% Load multiple fNIRS structs in cell array
alldata = {data1, data2, data3, ...};

% Launch exploreFNIRS GUI
exploreFNIRS(alldata);

% Or use the scriptable Experiment class (no GUI needed)
ex = exploreFNIRS.core.Experiment(alldata);
ex.select('Group', {'Control', 'Treatment'});
ex.groupby({'Group', 'Condition'});
ex.aggregate();

% Headless plots
fig = ex.plotTemporal('Biomarkers', {'HbO'}, 'Channels', 1:5);
fig = ex.plotBar('Biomarker', 'HbO', 'TimeWindow', [5, 25]);

% ROI-based plotting
fig = ex.plotTemporal('Biomarkers', {'HbO'}, 'ROIs', 'all');
fig = ex.plotBar('Biomarker', 'HbO', 'ROIs', {'DLPFC_L', 'DLPFC_R'});

% Export for external analysis
longTable = ex.toLongTable({'HbO'});       % long format for R/Python
wideTable = ex.toWideTable({'HbO'});       % wide format
writetable(longTable, 'export_for_R.csv');
```

## Workflow 5: Connectivity Analysis
```matlab
% Set up experiment
ex = exploreFNIRS.core.Experiment(alldata);
ex.select('Group', {'Control', 'Treatment'});
ex.groupby({'Group', 'Condition'});
ex.aggregate();

% Compute connectivity matrices
connResults = ex.connectivity('Method', 'pearson');
fig = exploreFNIRS.connectivity.plotMatrix(connResults);

% Block-wise connectivity
blocks = pf2.data.defineBlocks(alldata{1}, [49, 50], 30);
connBlocks = ex.connectivity('Method', 'coherence', 'Blocks', blocks);
fig = exploreFNIRS.connectivity.plotBlockComparison(connBlocks);

% Channel alignment for subjects with different valid channels
% Union (default): all channels, NaN where a subject lacks data
connResults = ex.connectivity('Method', 'pearson', 'Align', 'union');

% Intersection: only channels present in ALL subjects
connResults = ex.connectivity('Method', 'pearson', 'Align', 'intersection');

% Threshold: channels in >= 75% of subjects
connResults = ex.connectivity('Method', 'pearson', 'Align', 0.75);

% Export connectivity as table
T = exploreFNIRS.export.connectivityToTable(connResults);
```

## Workflow 6: Hyperscanning Analysis
```matlab
% Pair subjects (by .info.DyadID) and compute inter-brain coupling
hsResults = ex.hyperscanning('Method', 'wcoherence');

% With channel alignment for dyads with different valid channels
hsResults = ex.hyperscanning('Method', 'pearson', ...
    'Align', 'union');  % 'union' (default), 'intersection', or numeric threshold

% Group-level statistics with permutation testing. The package functions take
% the data cell array plus a pairs struct (from pairSubjects), not the
% Experiment result:
pairs      = exploreFNIRS.hyperscanning.pairSubjects(alldata);
groupStats = exploreFNIRS.hyperscanning.computeGroup(alldata, pairs, 'Method', 'wcoherence');
permStats  = exploreFNIRS.hyperscanning.permutationTest(alldata, pairs, 'Permutations', 1000);
fig = exploreFNIRS.hyperscanning.plotGroup(groupStats);
```

## Workflow 6b: HB-ICA Hyperscanning
```matlab
% Standalone HB-ICA on a single dyad
result = exploreFNIRS.hyperscanning.hbica(dataA, dataB, ...
    'Biomarker', 'HbO', 'GOFThreshold', 0);
fprintf('%d inter-brain components\n', sum(result.isInterBrain));

% ROI-level HB-ICA
result = exploreFNIRS.hyperscanning.hbica(dataA, dataB, 'UseROI', true);

% Group-level HB-ICA via Experiment
groupResult = ex.hbica('Biomarker', 'HbO');

% Block-wise HB-ICA
blockResult = ex.hbica('Blocks', blocks);

% Visualize
fig = exploreFNIRS.hyperscanning.plotHBICA(result);
```

## Workflow 7: Block Definition, Extraction, and Trial Averaging
```matlab
% Process first, then epoch (extractBlocks carries HbO/HbR through, so there
% is no need to reprocess each block).
proc = processFNIRS2(data);

% Define blocks from marker codes with 30-second duration.
% Embed=false returns the block ARRAY (Embed defaults to true, which returns
% the data struct with .blocks embedded — handy for extractBlocks(data)).
blocks = pf2.data.defineBlocks(proc, [49, 50], 30, 'Embed', false);

% Extract time-locked segments. ALWAYS pass PreTime/PostTime — when omitted,
% each side falls back to a small default Buffer of 2 s, so set them to size
% the epoch deliberately.
segments = pf2.data.extractBlocks(proc, blocks, ...
    'PreTime', 5, 'PostTime', 15, 'SetT0', true);

% Single-subject trial/grand average onto a common grid (one call).
% blockAverage regrids the segments first, so the marker-epoched data does
% not average to NaN (segments share a sampling rate but differ in phase).
ga = pf2.data.blockAverage(segments);          % or pf2.data.grandAverage
plot(ga.time, ga.HbO.Mean(:, 1));              % averaged HbO, channel 1
% ga.<HbO|HbR|HbTotal|HbDiff|CBSI>.{Mean, SEM, SD, N, Median, Max, Min}

% For multi-condition / group averaging, feed segments to Experiment:
%   ex = exploreFNIRS.core.Experiment(segments);
%   ex.groupby({'Condition'}); ex.aggregate(); ex.plotTemporal('Biomarkers', {'HbO'});

% Inspect / select markers before epoching. data.markers is a canonical
% table — access fields by name (.Time, .Code, .Duration, .Amplitude) rather
% than by column position:
times = pf2.data.getMarkers(proc, 49);         % all onsets of code 49
times = pf2.data.getMarkers(proc, [49; 50]);   % column vector = code 49 OR 50
onsets = proc.markers.Time(proc.markers.Code == 49);   % read by variable name
```

Any extra columns you append to the marker table (beyond `.Time`, `.Code`,
`.Duration`, `.Amplitude`) are preserved through preprocessing and splicing.

### BIDS Events.tsv Integration

When importing SNIRF files with a companion BIDS `_events.tsv` sidecar, `importSNIRF` automatically reads the `trial_type` and `value` columns and stores the mapping as `data.info.eventTypes`. This lets `defineBlocks` auto-label blocks without a manual `ConditionMap`.

```matlab
% Import SNIRF — events.tsv auto-detected and parsed
data = pf2.import.importSNIRF('sub-01_nirs.snirf');
% data.info.eventTypes = {1, 'Control'; 2, 'Noise'; 3, 'Speech'}

% defineBlocks auto-populates ConditionMap from eventTypes
blocks = pf2.data.defineBlocks(data, [1, 2, 3]);
% blocks(k).info.Condition = 'Control' / 'Noise' / 'Speech'
% Duration auto-read from markers .Duration (e.g. 5.25s from events.tsv)

% Explicit ConditionMap always overrides eventTypes
blocks = pf2.data.defineBlocks(data, [1, 2, 3], ...
    'ConditionMap', {1, 'Ctrl'; 2, 'Nse'; 3, 'Sp'});
```

The `_events.tsv` file follows the BIDS standard format:
```
onset    duration    trial_type    value
30.336   5.25        Noise         2
53.568   5.25        Control       1
76.800   5.25        Speech        3
```

When the `value` column is present with numeric codes, those codes are used as marker values and the `trial_type` string is stored in the mapping. When no `value` column exists, sequential integers are assigned to each unique `trial_type`.

### Marker Table and the Marker Dictionary

Markers are stored as a **table** — `data.markers` with variables `Time`, `Code`, `Duration`, `Amplitude`, plus any extra per-event columns you add (e.g. reaction time, accuracy). Read columns by name, not by position. Extra columns survive preprocessing and splicing (`setT0`, `split`, `extractBlocks`, `concatenateHorizontal`, processing).

```matlab
% Append per-event attributes; they ride along through preprocessing
data.markers.RT  = trialReactionTimes(:);     % numeric column
data.markers.Hit = trialAccuracy(:) == 1;     % logical column
proc = processFNIRS2(data);
proc.markers.RT(proc.markers.Code == 49)      % still here after processing
```

Marker **codes** get meaning from a per-dataset dictionary at `data.info.markerDict` — a table keyed by `Code` with a `Label` column and any per-code attributes. It is the single source that `defineBlocks` (block labels) and `labelMarkers` (per-row labels) consult, and it unifies the source-specific formats: importers fold BIDS `events.tsv` (`info.eventTypes`) and the COBI `.nir` Marker Dictionary into it.

```matlab
% Name your codes once, dataset-wide (with optional per-code attributes)
dict = table([49; 50], ["Stroop"; "Control"], [true; true], ...
    'VariableNames', {'Code', 'Label', 'isTask'});
data = pf2.data.setMarkerDict(data, dict);     % stored at data.info.markerDict

% Resolve the dictionary (markerDict -> eventTypes -> COBI -> unique codes)
d = pf2.data.getMarkerDict(data);
d.Label(d.Code == 49)                          % "Stroop"

% Stamp a categorical .Label on every marker row from the dictionary
data = pf2.data.labelMarkers(data);
summary(data.markers.Label)                    % counts per condition

% defineBlocks auto-labels Conditions from the dictionary — no inline map
blocks = pf2.data.defineBlocks(data, [49, 50], 30, 'Embed', false);
% blocks(k).info.Condition = 'Stroop' / 'Control'
```

`setMarkerDict(data, dict, 'Merge', true)` (the default) merges new entries into an existing dictionary, with new entries winning on `Code` conflicts; pass `'Merge', false` to replace it. For a cell array of subjects, `setMarkerDict` broadcasts to each and `getMarkerDict` returns the union across subjects. Underlying helpers: `pf2_base.normalizeMarkerDict` (any form → canonical dict) and `pf2_base.mergeMarkerDict` (union two dicts).

## Workflow 8: Metadata Import from CSV/Excel
```matlab
% --- Subject-level metadata ---
% Match CSV rows to fNIRS structs by SubjectID
allData = pf2.data.importInfo(allData, 'demographics.csv', 'SubjectID');
% Now allData{1}.info.Age, .info.Sex, etc. are populated

% Multi-key matching (SubjectID + Session)
allData = pf2.data.importInfo(allData, 'sessions.xlsx', ...
    'Keys', {'SubjectID', 'Session'});

% Protect existing fields from overwrite
allData = pf2.data.importInfo(allData, 'extra.csv', 'SubjectID', ...
    'Overwrite', false);

% --- Block-level metadata (trial-by-trial data) ---
% Define blocks from markers
blocks = pf2.data.defineBlocks(data, [49, 50], 30, ...
    'ConditionMap', {49, 'Task'; 50, 'Rest'});

% Import behavioral data: row 1 -> block 1, row 2 -> block 2
blocks = pf2.data.importBlockInfo(blocks, 'trial_data.csv');

% Import only for Task blocks (skip Rest), matching by row order
blocks = pf2.data.importBlockInfo(blocks, 'task_responses.csv', ...
    'MarkerCode', 49);

% Key-based matching by BlockNumber (order-independent)
blocks = pf2.data.importBlockInfo(blocks, 'scored_trials.csv', ...
    'Keys', 'BlockNumber');

% In-memory table (behaves like a just-read CSV; same key/positional semantics)
T = table([85; 90], 'VariableNames', {'Score'});
blocks = pf2.data.importBlockInfo(blocks, T);

% Numeric per-block vector -> named .info field ('Field', default 'value');
% length must match the number of (filtered) blocks
scores = (1:numel(blocks))';
blocks = pf2.data.importBlockInfo(blocks, scores, 'Field', 'score');

% Extract segments with imported metadata attached
segments = pf2.data.extractBlocks(data, blocks);
% segments{1}.info now contains both block and imported fields
```

## Workflow 9: Context-Based Processing
```matlab
% Create an isolated processing context, configured in one call. The public
% pf2.ProcessingContext is usable straight from construction (no fromGlobals
% bootstrap) and accepts processFNIRS2-style Name-Value settings.
ctx = pf2.ProcessingContext('DPFmode', 'Calc', 'SubjectAge', 30, ...
    'RawMethod', 'OD_TDDR', 'OxyMethod', 'takizawa_easy');

% Process without modifying global state (either form works)
result = ctx.process(data);                       % context as receiver
% result = processFNIRS2(data, 'Context', ctx);   % equivalent keyword form

% Parallel processing with different ages. Configure ONCE, then take an
% independent copy() per worker -- a plain ctx = base would alias one handle,
% and fromGlobals() on a worker sees empty globals.
parfor i = 1:length(subjects)
    c = ctx.copy();
    c.subjectAge = ages(i);
    results{i} = processFNIRS2(data{i}, 'Context', c);
end
```

> **Context is fully isolated from globals.** When a `'Context'` is passed,
> `processFNIRS2` bypasses global-state initialization entirely (it never reads
> or writes `PF2`/`setF`), so concurrent `parfor` workers cannot clobber each
> other's settings. Omit `'Context'` and processing falls back to the global
> `PF2` settings as before.

## Workflow 10: Custom Method Management
```matlab
% Create a new raw processing method
pf2.methods.raw.create('MyCustomMethod');

% Add processing functions with parameters
pf2.methods.raw.editFunction('MyCustomMethod', 'pf2_lpf', struct('freq_cut', 0.08));
pf2.methods.raw.editFunction('MyCustomMethod', 'pf2_MotionCorrectTDDR', struct());

% Remove a function from the method
pf2.methods.raw.removeFunction('MyCustomMethod', 'pf2_lpf');

% Export method for sharing
pf2.methods.raw.exportMethod('MyCustomMethod', 'my_custom_method.mat');

% Import a shared method
pf2.methods.raw.importMethod('shared_method.mat');

% Delete a method
pf2.methods.raw.delete('OldMethod');
```

## Workflow 11: GLM Analysis with Short-Channel PCA
```matlab
% Import SNIRF data (short channels auto-detected)
data = pf2.import.importSNIRF('sub-01_task-motor_nirs.snirf');

% Process (motion correction + filtering)
processed = processFNIRS2(data);

% Apply short-channel regression
corrected = pf2_base.fnirs.shortChannelRegression(processed, 'Method', 'nearest');

% Or extract short-channel PCs for GLM regressors
[pcMatrix, pcInfo] = pf2_base.fnirs.extractShortChannelPCs(processed, ...
    'NumPCs', 2, 'Biomarker', 'HbO');

% Define task events
events(1).name = 'LeftTap';  events(1).onsets = [10, 50, 90]; events(1).duration = 15;
events(2).name = 'RightTap'; events(2).onsets = [30, 70, 110]; events(2).duration = 15;

% Build design matrix with DCT drift and short-channel PCA regressors
[X, names] = pf2_base.fnirs.buildDesignMatrix(corrected.time, corrected.fs, events, ...
    'DriftType', 'dct', 'DriftCutoff', 128, ...
    'ShortChannels', pcMatrix, ...
    'IncludeDerivative', true);

% Fit GLM with AR-IRLS (robust to serial correlation)
results = pf2_base.fnirs.fitGLM(corrected.HbO, X, names, 'Method', 'AR-IRLS');

% Note: No bandpass filtering is applied before GLM because:
%   1. DCT drift regressors model low-frequency trends (replaces high-pass)
%   2. AR-IRLS handles serial correlation (replaces low-pass)
%   3. Pre-filtering can distort the HRF peak shape
% See PROCESSING_PIPELINE.md "When to Use Bandpass Filtering" for details.

% Examine results
fprintf('R² range: %.2f - %.2f\n', min(results.R2), max(results.R2));
sigChannels = results.pval(1,:) < 0.05;  % Channels significant for LeftTap
```

## Workflow 12: Data Quality Assessment

### Interactive Channel Check (GUI)
```matlab
data = pf2.import.importSNIRF('sub-01_task-motor_nirs.snirf');

% Open ChannelCheck GUI — auto-runs QC, interactive review
app = pf2.qc.ChannelCheck(data);
% GUI opens with: probe mini-plot grid, detail timeseries, PSD, QC results
% - Click channels to inspect, right-click to cycle Good/Noisy/Reject
% - QC auto-runs on open; hover mini-plots for per-check breakdown
% - QC Setup button to configure thresholds (persisted across sessions)
% - Accept Recs applies QC recommendations, Reject Noisy bulk-rejects
data = app.OutputData;
delete(app);

% Multi-file mode: browse datasets with prev/next
allData = pf2.import.importDirectory('data/', '*.snirf');
app = pf2.qc.ChannelCheck(allData);
allData = app.OutputData;
delete(app);
```

### Programmatic QC Pipeline (headless)
```matlab
data = pf2.import.importSNIRF('sub-01_task-motor_nirs.snirf');

% One-call summary: runs all checks and writes dashboard + PSD + SCI PNGs
report = pf2.qc.snapshot(data, 'SaveDir', 'qc_out');

% Or run the assessment directly
report = pf2.qc.pipeline.assess(data);
% report.pass        — [1×nCh] logical overall pass/fail
% report.saturation  — .pass, .pctSaturated per channel
% report.sci         — .pass, .values (SCI scores)
% report.cardiac     — .pass, .snr (cardiac peak SNR)
% report.cov         — .pass, .values (coefficient of variation)
% report.takizawa    — .pass (4-rule Hb quality check)

% Customize thresholds (defaults: SCI 0.75, CoV 0.2, Takizawa jump 0.5 mM*mm)
report = pf2.qc.pipeline.assess(data, ...
    'SCIThreshold', 0.8, ...
    'CoVThreshold', 0.15, ...
    'Checks', {'saturation', 'sci', 'cov'});  % disable cardiac + takizawa

% Apply recommendations (ANDs into data.fchMask, never promotes bad -> good)
data = pf2.qc.pipeline.apply(data, report);

% Print per-channel summary table
pf2.qc.pipeline.report(report);

% Then process
processed = processFNIRS2(data);
```

> **QC default calibration.** The CoV threshold (0.2) and Takizawa Rule 4
> (event-based body-movement detection, 0.5 mM\*mm jump threshold) were
> recalibrated so normal-range data is not over-rejected — the previous
> defaults rejected every channel of the bundled sample. They are validated
> on `fNIR2000`; confirm thresholds on your own device data.

### SCI-Only Rejection (legacy)
```matlab
% SCI-based channel rejection (on raw intensity data, before processing)
fMask = pf2_SCIRejection(data, 0.75, [0.5, 2.5]);
data.fchMask = data.fchMask & fMask;

% Detailed SCI metrics
qcResults = pf2.qc.sci(data, 'CardiacBand', [0.5, 2.5]);
pf2.qc.plotQuality(qcResults);
```

## Workflow 13: Color Schemes for Group Plots
```matlab
% Define a color scheme with base colors per group and modifier effects per condition
cs = exploreFNIRS.core.ColorScheme();
cs = cs.set('Group', 'Patient', [0.85, 0.2, 0.2]);   % Red base
cs = cs.set('Group', 'Healthy', [0.2, 0.65, 0.3]);    % Green base
cs = cs.set('Condition', 'Easy', 'lighten', 0.25);     % Lighter variant
cs = cs.set('Condition', 'Hard', 'darken', 0.15);      % Darker variant

% Preview the resolved colors without needing real data
fig = cs.preview();

% Save the preview to a file (headless)
fig = cs.preview('SavePath', 'colorscheme.png');

% Use a global base color instead of per-value colors
csGray = exploreFNIRS.core.ColorScheme();
csGray = csGray.setBase([0.5, 0.5, 0.5]);
csGray = csGray.set('Condition', 'Easy', 'lighten', 0.3);
csGray = csGray.set('Condition', 'Hard', 'darken', 0.3);
csGray.preview();

% Assign to an Experiment for automatic color injection
ex = exploreFNIRS.core.Experiment(alldata);
ex.colorScheme = cs;
fig = ex.plotBar('Biomarker', 'HbO', 'Channels', 1);

% Register named presets and switch between them
ex.addColorScheme('byGroup', cs);
ex.addColorScheme('byCondition', csGray);
ex.useColorScheme('byGroup');

% Per-plot override (by name or by object)
fig = ex.plotBar('Biomarker', 'HbO', 'Channels', 1, 'ColorScheme', 'byCondition');
fig = ex.plotBar('Biomarker', 'HbO', 'Channels', 1, 'ColorScheme', cs);
```

## Workflow 14: Dark Mode and Theme Control
```matlab
% All plots automatically adapt to MATLAB's dark mode theme.
% No code changes needed — just enable dark mode in MATLAB preferences.

% Check if dark mode is active
isDark = pf2_base.plot.PlotStyle.isDarkMode();

% Force light mode for all pf2 plots (ignores MATLAB theme)
pf2_base.plot.PlotStyle.setForceLightMode(true);

% Re-enable theme detection
pf2_base.plot.PlotStyle.setForceLightMode(false);

% Saved figures always export with white background, regardless of theme
pf2.data.plot.oxy(data, 'savePath', 'output.png');  % Always white bg
```

## Workflow 15: Data Manipulation
```matlab
% Extract a time segment (absolute seconds)
segment = pf2.data.split(data, 10, 120);   % Keep only 10-120 seconds
segment = pf2.data.split(data, 60);         % Keep from 60 seconds to end

% Resample data (segmentLength is seconds-per-sample, positional;
% 0.2 s bins -> 5 Hz output)
resampled = pf2.data.resample(data, 0.2);

% Set baseline time (t0time is positional, in seconds)
shifted = pf2.data.setT0(data, 5);

% Extract marker onsets by code (codes are numeric, passed positionally)
markers = pf2.data.getMarkers(data, 49);        % all onsets of code 49
markers = pf2.data.getMarkers(data, [49; 50]);  % column vector = code 49 OR 50

% Apply channel mask
masked = pf2.data.applyChannelMask(data, mask);

% Plot results
pf2.data.plot.oxy(masked);
```

## Workflow 16: Metadata Table Editing
```matlab
% Extract all .info fields into a browsable table
T = pf2.data.infoToTable(allData);
disp(T);

% Extract specific fields
T = pf2.data.infoToTable(allData, 'Fields', {'SubjectID', 'Group', 'Age'});

% Extract a single field as a vector
groups = pf2.data.infoToTable(allData, 'Group');

% Edit the table and write back
T.Group(3) = "Control";
T.Condition = repmat("Task", height(T), 1);
allData = pf2.data.infoFromTable(allData, T);

% Set a single field across all structs (scalar broadcast)
allData = pf2.data.infoFromTable(allData, 'Study', 'MyStudy');

% Set a single field per-element
allData = pf2.data.infoFromTable(allData, 'Group', ["A"; "B"; "C"]);

% Export metadata to Excel
pf2.data.infoToTable(allData, 'SavePath', 'subject_metadata.xlsx');

% Merge without overwriting existing values
allData = pf2.data.infoFromTable(allData, T, 'Overwrite', false);

% Replace .info entirely with table contents
allData = pf2.data.infoFromTable(allData, T, 'Clear', true);
```

## Workflow 17: Probe Visualization
```matlab
% Easiest path: topo() takes a biomarker NAME and handles time-averaging
pf2.probe.plot.topo(processed, 'HbO');             % 2D heatmap, time-averaged
pf2.probe.plot.topo(processed, 'HbO', 'Time', 30); % at t = 30 s

% Underlying primitives take a [1xC] data VECTOR (not a biomarker name)
meanHbO = mean(processed.HbO, 1);                  % [1 x C]
pf2.probe.plot.imageValues(meanHbO, processed, [], [], 'Mean HbO', '\muM');
pf2.probe.plot.interpolateValues(meanHbO, processed);   % interpolated 2D map

% 3D brain visualization
pf2.probe.plot.showProbe3D(processed);

% 3D brain with voxel rendering
pf2.probe.plot.interpolateValues3D(channelData, probeConfig, ...
    'showVoxelBrain', true, 'voxelColor', [0.92, 0.68, 0.68]);

% Camera angles: 'front', 'back', 'top', 'bottom', 'left', 'right',
%   'top-left', 'top-right', 'top-front', 'top-back',
%   'front-left', 'front-right', 'back-left', 'back-right',
%   or numeric [x, y, z]
pf2.probe.plot.interpolateValues3D(channelData, probeConfig, ...
    'initCamPosition', 'top-left');
```

---

## Workflow 18: Brodmann Area Lookup
```matlab
% Find the 3 nearest Brodmann areas per channel
tbl = pf2.probe.nearestBrodmann('fNIR_Devices_fNIR1000.cfg');

% From a processed data struct
tbl = pf2.probe.nearestBrodmann(processed);

% Only the nearest BA per channel
tbl = pf2.probe.nearestBrodmann(processed, 'N', 1);

% Filter to BAs within 15 mm
tbl = pf2.probe.nearestBrodmann(processed, 'MaxDistance', 15);

% Returns a MATLAB table:
%   Channel | BA | Name             | Distance_mm
%   1       | 10 | Anterior PFC     | 9.14
%   1       | 46 | Dorsolateral PFC | 9.81
%   ...
```

## Workflow 19: Pipeline API
```matlab
% Build a raw processing pipeline programmatically
pipe = pf2_base.RawPipeline();
pipe = pipe.add('pf2_Intensity2OD');
pipe = pipe.add('pf2_MotionCorrectTDDR');
pipe = pipe.add('pf2_lpf', struct('freq_cut', 0.08));

% Inspect the pipeline
disp(pipe);                          % Pretty-print step chain
pipe.params()                        % Table of all tunable parameters

% Modify parameters without rebuilding
pipe = pipe.setParam('pf2_lpf', 'freq_cut', 0.05);

% Insert or remove steps
pipe = pipe.insert(2, 'pf2_hpf', struct('freq_cut', 0.01));
pipe = pipe.remove('pf2_hpf');

% Convert to/from named methods for persistence
method = pipe.toMethod('MyPipeline');             % Save as named method
pipe2 = pf2_base.RawPipeline.fromMethod('MyPipeline');  % Reload

% Oxy pipeline with ROI support
oxyPipe = pf2_base.OxyPipeline();
oxyPipe = oxyPipe.add('pf2_takizawa');
oxyPipe = oxyPipe.add('pf2_BuildROI');
oxyPipe.hasROI()                     % true

% Process using Pipeline objects
processed = processFNIRS2(data, pipe, oxyPipe);
```

## Workflow 20: GLM Diagnostics
```matlab
% After fitting a GLM, run comprehensive diagnostics
results = pf2_base.fnirs.fitGLM(processed.HbO, X, names, 'Method', 'AR-IRLS');

% Generate diagnostic report
report = pf2_base.fnirs.diagnoseGLM(processed.HbO, X, names);

% Check for issues
report.conditionNumber       % Design matrix condition number
report.VIF                   % Variance inflation factors per regressor
report.R2                    % Per-channel R-squared
report.residualACF           % Residual autocorrelation (lag-1)
report.flags                 % Automatically flagged issues
```

## Workflow 21: Portable Montage Descriptor
```matlab
% Serialize a probe's geometry + metadata into a portable, self-describing form.
% Accepts a data struct, a device config name, or a pf2.Device object.
data = pf2.import.sampleData();

% Per-channel table (Channel/Source/Detector/X_mni.../SD_mm/ShortSep, plus
% nearest-Brodmann columns when the device has 3D MNI positions)
tbl = pf2.probe.montage(data);

% Also get the montage-level descriptor struct (device, wavelengths,
% coordinateSystem/provenance, per-channel records)
[tbl, descriptor] = pf2.probe.montage(data);

% Write a portable JSON sidecar (montage + channels) next to an export
pf2.probe.montage(data, 'SavePath', 'montage.json');

% Or export just the per-channel table (extension selects format)
pf2.probe.montage(data, 'SavePath', 'montage.csv');

% Skip the Brodmann lookup; load directly from a config name
tbl = pf2.probe.montage('fNIR_Devices_fNIR1000.cfg', 'Brodmann', false);
```

## Workflow 22: Sliding Windows (dynamic connectivity / fixed-length input)
```matlab
% Tile a continuous recording with fixed-length windows on a regular grid.
% Returns a defineBlocks-compatible block array that feeds extractBlocks.
proc = processFNIRS2(pf2.import.sampleData());

% 10 s windows, 50% overlap (Overlap and Step are mutually exclusive)
blocks  = pf2.data.slidingWindows(proc, 'Length', 10, 'Overlap', 0.5, 'Embed', false);

% Extract each window. Set PreTime/PostTime to 0 so each segment is exactly the
% window (extractBlocks otherwise pads by a default Buffer of 2 s per side).
windows = pf2.data.extractBlocks(proc, blocks, 'PreTime', 0, 'PostTime', 0);

% Contiguous non-overlapping windows via an explicit step (default Step = Length)
blocks  = pf2.data.slidingWindows(proc, 'Length', 30, 'Step', 30, 'Embed', false);

% Restrict the tiled span and keep a short trailing partial window
blocks  = pf2.data.slidingWindows(proc, 'Length', 20, ...
    'Start', 30, 'End', 300, 'Partial', true, 'Embed', false);
```

## Workflow 23: Canonical Region Axis (cross-device pooling)
```matlab
% Map channels to their nearest Brodmann area and average within each region,
% yielding a region-indexed matrix comparable across montages/devices.
% Requires 3D MNI coordinates on the device.
proc = processFNIRS2(pf2.import.sampleData());
proc = pf2.probe.canonicalize(proc, 'MaxDistance', 20);
proc.canonical.regions      % table: Index / BA / Name
size(proc.canonical.HbO)    % [T x R] region-averaged HbO

% A cell array of mixed-device subjects is projected onto ONE shared region
% axis (the union of mapped regions), so every element shares column ordering.
allData = pf2.probe.canonicalize(allData);
isequal(allData{1}.canonical.regions, allData{2}.canonical.regions)   % true

% Pin the axis to an explicit region set
proc = pf2.probe.canonicalize(proc, 'Regions', [9 10 46]);
```

## Workflow 24: Foundation-Model Export (HDF5 tensor) and Re-import
```matlab
% Export a processed recording as a self-describing HDF5 tensor for transformer
% / foundation-model training. The .h5 bundles a [time x channel x feature]
% tensor + the pf2.probe.montage descriptor + a manifest (markers, marker dict,
% info, QC, processing provenance). Numeric arrays are native HDF5 datasets
% (read directly by Python h5py); metadata is UTF-8 JSON.
proc = processFNIRS2(pf2.import.sampleData.fNIR2000());

% Default: stack the biomarkers present (HbO/HbR/...) -> [T x C x F]
outPath = pf2.export.asTensor(proc, 'sub-01.h5');

% Choose features explicitly and include a QC manifest
outPath = pf2.export.asTensor(proc, 'sub-01.h5', ...
    'Features', {'HbO', 'HbR'}, 'QC', true);

% Windowed export for fixed-length model input -> [W x T x C x F]
blocks  = pf2.data.slidingWindows(proc, 'Length', 10, 'Embed', false);
windows = pf2.data.extractBlocks(proc, blocks, 'PreTime', 0, 'PostTime', 0);
outPath = pf2.export.asTensor(proc, 'sub-01_win.h5', ...
    'Windows', windows, 'Features', {'HbO', 'HbR'});

% Re-import embeddings produced by the Python sibling, aligned to the recording.
% Attaches data.embeddings (.data/.time/.dims/.names/.info), so the learned
% features behave like any other biomarker block in exploreFNIRS.
proc = pf2.import.importEmbeddings(proc, 'sub-01_embeddings.h5');
size(proc.embeddings.data)                          % [T x E] (per-timepoint)
isequal(proc.embeddings.time, proc.time(:))         % aligned to recording

% Store under a custom field name
proc = pf2.import.importEmbeddings(proc, 'feats.h5', 'Field', 'cnnFeatures');
```

---

## Real-World Usage: Multi-Device Workflow

### Typical Analysis Pipeline

```
┌─────────────────────────────────────────────────────────────────┐
│                     MULTI-DEVICE WORKFLOW                        │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Raw fNIR (.nir)          Raw Hitachi (.mes)                   │
│       ↓                         ↓                               │
│  pf2.import.importNIR    pf2.import.importHitachiMES           │
│       ↓                         ↓                               │
│       └──────────┬──────────────┘                               │
│                  ↓                                              │
│         Device Synchronization                                  │
│         (match marker intervals)                                │
│                  ↓                                              │
│         Probe Merging                                           │
│         (spatial offset, resample to common grid)              │
│                  ↓                                              │
│         processFNIRS2()                                         │
│         (with custom method configs)                           │
│                  ↓                                              │
│         NIRS Toolbox GLM                                        │
│         (first-level → group-level)                            │
│                  ↓                                              │
│         Statistical Contrasts                                   │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Batch Directory Import

```matlab
% Import all SNIRF files from a flat directory
allData = pf2.import.importDirectory('data/', '*.snirf');

% Import with directory-level metadata mapping
% Given: data/Young/Sub01/file.snirf, data/Old/Sub02/file.snirf
allData = pf2.import.importDirectory('data/', '*.snirf', ...
    'Dir1', 'Group', 'Dir2', 'SubjectID');
% Result: allData{1}.info.Group = 'Young', allData{1}.info.SubjectID = 'Sub01'

% Import NIRx recordings (folder-based format, matched by .hdr)
allData = pf2.import.importDirectory('data/', '*.hdr', ...
    'Dir1', 'Group', 'Dir2', 'SubjectID');

% Process all imported data and feed into experiment
allData = processFNIRS2(allData);
ex = exploreFNIRS.core.Experiment(allData);
```

### Multi-Device Import Pattern

```matlab
% Import from different device types
fnirData = pf2.import.importNIR(fnirFile);
hitachiData = pf2.import.importHitachiMES(hitachiFile);

% Handle probe orientation differences
if needsFlip
    fnirData.raw = fliplr(fnirData.raw);  % Flip channels for rotated probe
end

% resample to common time grid (e.g., 2 Hz -> 0.5 s bins, positional)
fnirData = pf2.data.resample(fnirData, 0.5);
hitachiData = pf2.data.resample(hitachiData, 0.5);
```

### Device Synchronization Strategy

When using multiple fNIRS devices, synchronization is critical:

1. **Marker Matching**: Compare marker inter-intervals between devices
2. **Time Offset**: Calculate offset from matched marker sequences
3. **Tolerance**: Typically < 0.3-0.4 seconds acceptable
4. **Rescaling**: Hitachi output may need rescaling (e.g., factor 4000/5)

```matlab
% Pseudo-code for device sync ([49;50;51] column vector = match ANY of the codes)
fnirMarkers = pf2.data.getMarkers(fnirData, [49; 50; 51]);
hitMarkers = pf2.data.getMarkers(hitachiData, [49; 50; 51]);
timeOffset = median(fnirMarkers(:,1) - hitMarkers(:,1));
hitachiData = pf2.data.setT0(hitachiData, timeOffset);   % t0time positional
```

### Integration with NIRS Toolbox

pf2 output can feed into NIRS Toolbox for GLM analysis:

```matlab
% After pf2 processing, convert to NIRS toolbox format
% (requires separate conversion functions)

% Typical NIRS Toolbox pipeline after pf2:
job = nirs.modules.OpticalDensity();
job = nirs.modules.BeerLambertLaw(job);
job = nirs.modules.GLM(job);           % First-level
job = nirs.modules.MixedEffects(job);  % Group-level

% Run pipeline
GroupStats = job.run(processedData);
```

### Export for Cross-Platform Analysis

```matlab
% Export to SNIRF for use with other tools (MNE-Python, Homer3, etc.)
pf2.export.asSNIRF(processed, 'output.snirf');

% Export to legacy NIR format
pf2.export.asNIR(processed, 'output.nir');
```

### Batch Export

Export a cell array of processed data back to a directory tree, mirroring the
structure used during `importDirectory`:

```matlab
% Flat export with index-based filenames
pf2.export.asSNIRF(allData, 'output/');
% → output/data_1.snirf, output/data_2.snirf, ...

% Subdirectory mapping (inverse of importDirectory Dir1/Dir2 params)
pf2.export.asSNIRF(allData, 'output/', 'Dir1', 'Group', 'Dir2', 'SubjectID');
% → output/Young/Sub01/data_1.snirf, output/Old/Sub02/data_2.snirf, ...

% Filename from .info fields
pf2.export.asSNIRF(allData, 'output/', 'Prefix', {'Task', 'SubjectID'});
% → output/MEMORY_Sub01.snirf, output/VISUAL_Sub02.snirf, ...

% Combined Dir + Prefix
pf2.export.asSNIRF(allData, 'output/', ...
    'Dir1', 'Group', 'Prefix', {'SubjectID', 'SessionNum'});

% NIR batch export
pf2.export.asNIR(allData, 'output/');

% Auto-detect format via export.export()
pf2.export.export(allData, 'output/', 'Format', 'snirf', 'Dir1', 'Group');
```

### End-to-End Batch Workflow

A complete workflow from directory import through group statistics and batch export.
See `examples/scripts/tutorial_batch_workflow.m` for the full runnable tutorial.

```matlab
% 1. Import all subjects from a directory tree
allData = pf2.import.importDirectory('data/', '*.snirf', ...
    'Dir1', 'Group', 'Dir2', 'SubjectID');
%  -> allData{i}.info.Group and .info.SubjectID set from folder names

% 2. Merge experiment metadata from a single CSV
allData = pf2.data.importInfo(allData, 'demographics.csv', 'SubjectID');
%  -> allData{i}.info now has Age, Sex, etc.

% 3. Batch process all subjects
allProcessed = processFNIRS2(allData, 'DPFmode', 'Calc', 'blLength', 10);

% 4. Define blocks and extract segments for each subject
allSegments = {};
for i = 1:numel(allProcessed)
    blocks = pf2.data.defineBlocks(allProcessed{i}, [10, 20], 30, ...
        'ConditionMap', {10, 'Natural'; 20, 'Synthetic'});
    segs = pf2.data.extractBlocks(allProcessed{i}, blocks, ...
        'PreTime', 5, 'SetT0', true, 'CopyInfo', true);
    allSegments = [allSegments, segs];
end

% 5. Build Experiment, run statistics, plot
ex = exploreFNIRS.core.Experiment(allSegments);
ex.settings.baseline = [-5, 0];
ex.settings.resampleRate = 1;
ex.settings.useBaseline = true;
ex.select('Condition', {'Natural', 'Synthetic'});
ex.groupby({'Group', 'Condition'});
ex.aggregate();

fig = ex.plotTemporal('Biomarkers', {'HbO'}, 'PlotBy', 'Condition');
results = ex.statsFitLME('Biomarkers', {'HbO'}, 'Channels', 1:4);

% 6. Export: CSV for R/Python, batch SNIRF back to directory tree
longT = ex.toLongTable({'HbO', 'HbR'}, 1:4);
writetable(longT, 'results.csv');

pf2.export.asSNIRF(allProcessed, 'output/', ...
    'Dir1', 'Group', 'Prefix', {'SubjectID'});
```

### Marker Code Conventions

When designing experiments, establish clear marker conventions:

```matlab
% Example marker scheme:
% 10-19: Baseline markers
% 20-29: Stimulus onset markers
% 30-39: Response markers
% 40-49: Block markers
% 50-59: Condition markers

% Extract specific markers by code (column vector = match ANY listed code)
stimMarkers = pf2.data.getMarkers(data, (20:29)');
```

### Batch Processing Pattern

```matlab
% Process multiple subjects
subjects = 11:22;
allProcessed = cell(1, length(subjects));

for i = 1:length(subjects)
    subID = subjects(i);

    % Import
    data = pf2.import.importNIR(sprintf('Sub%d/data.nir', subID));

    % Set subject-specific parameters
    data.info.SubjectID = sprintf('Sub%02d', subID);
    data.info.Age = subjectAges(i);  % If known

    % Process
    processed = processFNIRS2(data, ...
        'defaultSubjectAge', subjectAges(i), ...
        'DPFmode', 'Calc');

    allProcessed{i} = processed;
end

% Save for group analysis
save('group_processed.mat', 'allProcessed');
```
