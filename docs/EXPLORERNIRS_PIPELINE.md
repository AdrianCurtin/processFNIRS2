# exploreFNIRS Processing Pipeline

> **Layer 2** of the two-layer architecture.
> Input: Processed fNIRS structs (output of `processFNIRS2`)
> Output: Grand-averaged group data, statistical results, publication figures

---

## Overview

```
┌──────────────────────────────────────────────────────────────────────────┐
│                    exploreFNIRS Pipeline (Layer 2)                       │
│                                                                          │
│  Processed fNIRS structs (cell array)                                    │
│       ↓                                                                  │
│  ┌─────────────────────────────────────────────────────────────────┐     │
│  │ 1. METADATA EXTRACTION                                          │     │
│  │    buildSegmentInfoTable() → MATLAB table                       │     │
│  │    Each .info field becomes a table column                      │     │
│  └─────────────────────────────────────────────────────────────────┘     │
│       ↓                                                                  │
│  ┌─────────────────────────────────────────────────────────────────┐     │
│  │ 2. SELECTION (Experiment.select)                                │     │
│  │    Filter segments by metadata (AND logic)                      │     │
│  │    e.g. select('Group','Control','Condition',{'A','B'})         │     │
│  └─────────────────────────────────────────────────────────────────┘     │
│       ↓                                                                  │
│  ┌─────────────────────────────────────────────────────────────────┐     │
│  │ 3. GROUPING (Experiment.groupby)                                │     │
│  │    Create groups from unique variable combinations              │     │
│  │    e.g. groupby({'Group','Condition'}) → 4 groups               │     │
│  └─────────────────────────────────────────────────────────────────┘     │
│       ↓                                                                  │
│  ┌─────────────────────────────────────────────────────────────────┐     │
│  │ 4. AGGREGATION (Experiment.aggregate) — Two stages              │     │
│  │                                                                  │     │
│  │  ┌──────────────────────────────────────────────────────────┐   │     │
│  │  │ Stage A: PREPROCESSING  ★ Cached ★                       │   │     │
│  │  │   • Baseline extraction: pf2.data.split()                │   │     │
│  │  │   • Temporal resampling: pf2.data.resample()             │   │     │
│  │  │   • Bar resampling: pf2.data.resample() (coarser bins)   │   │     │
│  │  └──────────────────────────────────────────────────────────┘   │     │
│  │                          ↓                                       │     │
│  │  ┌──────────────────────────────────────────────────────────┐   │     │
│  │  │ Stage B: GRAND AVERAGING  (always re-run)                │   │     │
│  │  │   • grandAvgFNIRS() — hierarchical averaging             │   │     │
│  │  │   • grandAvgFNIRS() — flat averaging (for bar/export)    │   │     │
│  │  └──────────────────────────────────────────────────────────┘   │     │
│  └─────────────────────────────────────────────────────────────────┘     │
│       ↓                                                                  │
│  ┌─────────────────────────────────────────────────────────────────┐     │
│  │ 5. OUTPUT                                                       │     │
│  │    • Visualization: plotTemporal, plotBar, plotTopo, etc.       │     │
│  │    • Statistics: statsFitLME, statsRunContrasts, statsSummarize │     │
│  │    • Export: toLongTable, toWideTable                           │     │
│  └─────────────────────────────────────────────────────────────────┘     │
└──────────────────────────────────────────────────────────────────────────┘
```

---

## 1. Input: Processed fNIRS Segments

Each element in the input cell array is a processed fNIRS struct — the output of `processFNIRS2()`. The struct must contain hemoglobin data and an `.info` sub-struct with metadata.

### Required Fields

| Field | Description |
|-------|-------------|
| `data.HbO` | `[T × C]` Oxygenated hemoglobin time series |
| `data.HbR` | `[T × C]` Deoxygenated hemoglobin time series |
| `data.time` | `[T × 1]` Time vector in seconds |
| `data.fs` | Sampling frequency (Hz) |
| `data.info` | Metadata struct (SubjectID, Group, Condition, etc.) |

### The `.info` Struct

Every field in `.info` becomes a column in the metadata table. Common fields:

| Field | Type | Example | Purpose |
|-------|------|---------|---------|
| `SubjectID` | string | `'S01'` | Subject identifier (used for hierarchy) |
| `Group` | string | `'Control'` | Between-subjects grouping |
| `Condition` | string | `'Natural'` | Within-subjects condition |
| `Session` | string/num | `'Pre'` | Session identifier |
| `Trial` | numeric | `3` | Trial number |
| `Block` | numeric | `1` | Block number |
| `Age` | numeric | `25` | Subject age |

### Metadata Table Construction

`exploreFNIRS.dataset.buildSegmentInfoTable(data)` iterates over all segments and extracts `.info` fields into a MATLAB table. Missing fields are filled with type-appropriate defaults (`NaN`, `""`, or `NaT`).

```matlab
% Example
data = {seg1, seg2, seg3, seg4};
ex = exploreFNIRS.core.Experiment(data);
disp(ex.dataTable);
%   SubjectID    Group      Condition    Age
%   _________    _______    _________    ___
%   "S01"        "Control"  "Easy"       25
%   "S01"        "Control"  "Hard"       25
%   "S02"        "Tx"       "Easy"       30
%   "S02"        "Tx"       "Hard"       30
```

---

## 2. Selection

`Experiment.select()` filters segments by metadata criteria using **AND logic**.

```matlab
ex.select('Group', 'Control');                          % Exact match
ex.select('Condition', {'Easy', 'Hard'});               % Match any
ex.select('Group', 'Control', 'Condition', 'Easy');     % AND: both must match
```

- Values can be string, cell array, numeric scalar, or numeric vector.
- Calling `select()` again **narrows** the current selection (cumulative AND).
- Use `reset()` to clear and start fresh.
- Selection invalidates grouping and aggregation state.

---

## 3. Grouping

`Experiment.groupby(vars)` creates groups from unique combinations of metadata variables.

```matlab
ex.groupby({'Group', 'Condition'});
% Created 4 groups:
%   [1] Control | Easy  (4 segments)
%   [2] Control | Hard  (4 segments)
%   [3] Tx | Easy       (4 segments)
%   [4] Tx | Hard       (4 segments)
```

### Group Struct

Each group contains:

| Field | Description |
|-------|-------------|
| `gbyTables` | Metadata table rows for this group |
| `gbyFNIRS` | Cell array of raw fNIRS segments |
| `gbyGrand` | Grand average result (after `aggregate()`) |
| `gbyGrandBarFlat` | Flat grand average for bar charts/export |
| `gbyFNIRS_pp` | Preprocessed segments (after `aggregate()`) |
| `label` | Human-readable label (e.g., `'Control | Easy'`) |
| `cache` | Preprocessing cache (ppKey, ppData, barData) |

---

## 4. Aggregation

`Experiment.aggregate()` is the core computation. It has two internal stages:

### Stage A: Preprocessing (Cached)

For each segment in each group:

1. **Baseline extraction**: `pf2.data.split(seg, baseline(1), baseline(2))` extracts the baseline window. This provides the reference for baseline correction.

2. **Temporal resampling**: `pf2.data.resample(seg, resampleRate, ...)` resamples the segment to fixed time bins. The `blfNIR` parameter provides baseline subtraction.

3. **Bar resampling**: `pf2.data.resample(seg, barBinSize, ...)` resamples to coarser bins for bar chart display and LME modeling.

**If `useBaseline` is false**, resampling proceeds without baseline subtraction.
**If `resampleRate` is 0**, no resampling occurs.

#### Preprocessing Parameters

| Setting | Default | Effect |
|---------|---------|--------|
| `baseline` | `[-5, 0]` | Baseline window `[start, end]` in seconds |
| `taskStart` | `0` | Task onset time for bin alignment |
| `resampleRate` | `0.5` | Seconds per bin (temporal resolution) |
| `barBinSize` | `0` | Seconds per bin for bar data (0 = use resampleRate) |
| `useBaseline` | `true` | Apply baseline correction |

#### Caching

Stage A results are cached per group. The cache key is built from the five preprocessing settings above. When `aggregate()` is called:

- **Cache hit** (preprocessing settings unchanged): Skip Stage A, reuse cached `ppData` and `barData`. Console prints: `[g] label: using cached preprocessing`.
- **Cache miss** (settings changed or first run): Run Stage A, store results in cache.

The cache is automatically invalidated when:
- `groupby()` is called (creates new groups with empty cache)
- `select()` is called (resets groups)
- `reset()` is called (clears everything)
- Any preprocessing setting changes (key mismatch)

This means changing only `avgMode` (a Stage B parameter) **does not** trigger reprocessing.

### Stage B: Grand Averaging (Always Re-run)

After preprocessing, `grandAvgFNIRS()` is called twice:

1. **Temporal grand average** (`gbyGrand`): Uses the full hierarchy specification.
2. **Flat grand average** (`gbyGrandBarFlat`): Uses SubjectID-only hierarchy for export and LME.

### Averaging Modes

| Mode | Hierarchy Used | Purpose |
|------|----------------|---------|
| `'hierarchy'` | Full hierarchy (Subject > Session > Condition > Trial > Block) | Prevents pseudoreplication by averaging bottom-up |
| `'flat'` | SubjectID only | One value per subject per group |
| `'none'` | Each observation independent | No within-subject averaging |

#### How Hierarchical Averaging Works

`grandAvgFNIRS` uses a hierarchy table to determine averaging order. With hierarchy `{'SubjectID', 'Session', 'Condition', 'Trial'}`:

1. Average across Trials within each Subject × Session × Condition
2. Average across Conditions within each Subject × Session
3. Average across Sessions within each Subject
4. Average across Subjects → grand average

This prevents subjects with more trials from dominating the average.

Only hierarchy variables that exist in the group's metadata table are used. Missing levels are silently skipped.

---

## 5. Output Structures

### `gbyGrand` (Temporal Resolution)

The grand average struct contains one sub-struct per biomarker:

```matlab
gbyGrand.HbO.Mean   % [T × C] mean across subjects
gbyGrand.HbO.SEM    % [T × C] standard error of the mean
gbyGrand.HbO.SD     % [T × C] standard deviation
gbyGrand.HbO.Median % [T × C] median
gbyGrand.HbO.Min    % [T × C] minimum
gbyGrand.HbO.Max    % [T × C] maximum
gbyGrand.HbO.data   % [T × C × N] individual subject data
gbyGrand.time        % [T × 1] common time vector
gbyGrand.units       % string, e.g., 'μM' or 'mM*mm'
```

Same structure exists for `HbR`, `HbTotal`, `HbDiff`, `CBSI`.

### `gbyGrandBarFlat` (Bar/Export Resolution)

Same format as `gbyGrand` but:
- Uses coarser time bins (`barBinSize` or `resampleRate`)
- Uses flat (SubjectID-only) hierarchy
- Used by `toLongTable()`, `toWideTable()`, and LME modeling

### `gbyFNIRS_pp` (Preprocessed Segments)

Cell array of preprocessed segments — the individual inputs to `grandAvgFNIRS`. Useful for direct per-segment access without re-preprocessing.

---

## 6. Settings Reference

All settings are on `Experiment.settings`:

| Setting | Type | Default | Description |
|---------|------|---------|-------------|
| `baseline` | `[1×2]` | `[-5, 0]` | Baseline window [start, end] in seconds |
| `taskStart` | scalar | `0` | Task onset time for bin alignment |
| `resampleRate` | scalar | `0.5` | Seconds per temporal bin (0 = no resample) |
| `barBinSize` | scalar | `0` | Seconds per bar bin (0 = use resampleRate) |
| `useBaseline` | logical | `true` | Apply baseline correction |
| `avgMode` | string | `'hierarchy'` | Averaging mode: 'hierarchy', 'flat', 'none' |

### Modifying Settings

```matlab
% Set before aggregate()
ex.settings.baseline = [-3, 0];
ex.settings.resampleRate = 1.0;
ex.settings.avgMode = 'flat';
ex.aggregate();

% Or override transiently via PlotProxy
fig = ex.plot.bar('X', 'Group', 'AvgMode', 'flat', 'Baseline', [-3, 0]);
```

---

## 7. Caching Behavior

### What Gets Cached

Per group, the cache stores:

| Field | Description |
|-------|-------------|
| `cache.ppData` | Cell array of preprocessed temporal segments |
| `cache.barData` | Cell array of preprocessed bar-resolution segments |
| `cache.ppKey` | String key encoding preprocessing settings |

### Cache Key Format

```
bl=[-5.0000,0.0000]_rs=0.5000_bb=0.5000_ts=0.0000_ub=1
```

The key encodes: baseline window, resample rate, bar bin size, task start, use baseline. Any change to these values invalidates the cache.

### Typical Cache Scenarios

| Action | Cache Effect |
|--------|--------------|
| `ex.aggregate('hierarchy')` then `ex.aggregate('flat')` | Second call reuses cached preprocessing (only re-averages) |
| `ex.settings.baseline = [-3, 0]; ex.aggregate()` | Cache miss — preprocessing re-runs |
| `ex.groupby({'Group'})` | New groups created with empty cache |
| `ex.plot.bar('AvgMode', 'flat')` | PlotProxy save/restore handles cache correctly |

### Cache and PlotProxy

When `PlotProxy` renders a plot:

1. `saveState()` snapshots current groups (including cache)
2. Filter narrows selection → `groupby()` creates new groups (no cache)
3. `aggregate()` runs full preprocessing (cache miss for new groups)
4. Plot renders
5. `restoreState()` restores original groups with their cache intact

For PlotProxy calls that only override `AvgMode` without changing preprocessing settings or applying a filter, the cache benefits apply if the user has already called `aggregate()` on the same groups.

---

## 8. PlotProxy Integration

The `PlotProxy` (accessed via `ex.plot`) orchestrates the full pipeline for each plot call:

```
ex.plot.bar('X', 'Condition', 'Color', 'Group', ...)
    ↓
parseDimArgs() → dimMap + plotOpts + filterObj
    ↓
orchestrate():
    saveState()
    apply setting overrides (AvgMode, Baseline, etc.)
    apply Filter if present
    deriveGroupByVars() from dimension mapping
    groupby() + aggregate()
    ↓
buildLayout() → subplot grid from SubplotRows/SubplotCols
    ↓
renderBar/renderTemporal/renderScatter per subplot cell
    ↓
restoreState() → original experiment state restored
```

### Dimension Mapping

| Dimension | Effect |
|-----------|--------|
| `X` | X-axis categories (bar) or info variable (scatter) |
| `Color` | Line/bar color (legend entries) |
| `SubplotRows` | Facet into subplot rows |
| `SubplotCols` | Facet into subplot columns |
| `Figure` | Split into separate figure windows |

Interaction terms (`'Condition:Group'`) are supported — they create combined labels and split into separate groups.

### Available Plot Types

| Method | Description |
|--------|-------------|
| `ex.plot.bar(...)` | Grouped bar chart with error bars |
| `ex.plot.temporal(...)` | Time-series with error bands |
| `ex.plot.scatter(...)` | Scatter + correlation (info var vs biomarker) |

### Legacy Plot API

Direct methods on Experiment still work (require manual `groupby` + `aggregate` first):

```matlab
ex.groupby({'Group','Condition'});
ex.aggregate();
fig = ex.plotTemporal('Biomarkers', {'HbO'}, 'Channels', 1:5);
fig = ex.plotBar('Biomarker', 'HbO', 'Channels', 1:5);
fig = ex.plotTopo('Biomarker', 'HbO', 'Time', 15);
```

---

## Complete Workflow Example

```matlab
% 1. Load processed data
data = cell(20, 1);
for i = 1:20
    tmp = load(sprintf('subject_%02d.mat', i));
    data{i} = tmp.processed;
end

% 2. Create experiment
ex = exploreFNIRS.core.Experiment(data, ...
    'Hierarchy', {'SubjectID','Session','Condition','Trial'});

% 3. Configure settings
ex.settings.baseline = [-5, 0];
ex.settings.resampleRate = 0.5;
ex.settings.avgMode = 'hierarchy';

% 4. Select and group
ex.select('Group', {'Control','Treatment'}, 'Condition', {'Easy','Hard'});
ex.groupby({'Group','Condition'});

% 5. Aggregate (full pipeline runs)
ex.aggregate();

% 6. Explore different averaging without reprocessing
ex.aggregate('flat');    % Cache hit: only re-averages

% 7. Visualize
fig = ex.plot.temporal('Color', 'Condition', 'SubplotRows', 'Group', ...
    'Channels', 1:5, 'Biomarkers', {'HbO','HbR'}, 'Visible', 'off');

fig = ex.plot.bar('X', 'Condition', 'Color', 'Group', ...
    'Channels', 1:5, 'Visible', 'off');

% 8. Statistics
results = ex.statsFitLME('Biomarkers', {'HbO'}, 'Channels', 1:16);
T = ex.statsSummarize(results, 'Type', 'anova', 'Format', 'apa');

% 9. Export
longTable = ex.toLongTable({'HbO','HbR'});
writetable(longTable, 'results.csv');
```

---

## See Also

- [PROCESSING_PIPELINE.md](PROCESSING_PIPELINE.md) — Layer 1 (single-subject: raw → hemoglobin)
- [API_REFERENCE.md](API_REFERENCE.md) — Full function reference
- [ARCHITECTURE.md](ARCHITECTURE.md) — Data flow and package map
