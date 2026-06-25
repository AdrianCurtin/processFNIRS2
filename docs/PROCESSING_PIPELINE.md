# Processing Pipeline

## Three-Stage Processing Model

```
┌─────────────────────────────────────────────────────────────────┐
│                    STAGE 1: Raw → Optical Density               │
├─────────────────────────────────────────────────────────────────┤
│ Input: Raw light intensity data                                 │
│ Function: processStageRaw2OD()                                  │
│ Methods: Configured in +pf2/+methods/+raw                       │
│                                                                 │
│ Processing steps:                                               │
│   • Motion artifact correction (SMAR, MARA, TDDR, Wavelet,     │
│     Spline)                                                     │
│   • Filtering (bandpass, highpass, lowpass — FIR or IIR)        │
│   • Ambient subtraction                                         │
│   • ICA cleaning                                                │
│   • Common Average Reference (CAR)                             │
│                                                                 │
│ Note: Some methods require optical density and automatically    │
│ run after Intensity2OD conversion. The pipeline enforces this   │
│ via the `requiresOD` flag in pf2_functions_default.cfg:         │
│   • TDDR (Temporal Derivative Distribution Repair)              │
│   • Spline interpolation                                        │
│   • Wavelet correction                                          │
│   • MARA (Movement Artifact Reduction Algorithm)                │
│ If a requiresOD function is placed before Intensity2OD in a     │
│ method chain, processStageRaw2OD will error at runtime.         │
│                                                                 │
│ Output: Optical Density (log scale)                             │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│                    STAGE 2: OD → Hemoglobin                     │
├─────────────────────────────────────────────────────────────────┤
│ Input: Optical Density                                          │
│ Function: bvoxy()                                               │
│                                                                 │
│ Beer-Lambert Law conversion using:                              │
│   • Subject age (for age-dependent DPF calculation)            │
│   • Source-detector distance                                    │
│   • Two wavelengths (typically ~730nm and ~850nm)              │
│                                                                 │
│ DPF Modes:                                                      │
│   • 'None': No DPF, units in mM*mm                             │
│   • 'Fixed': Single DPF value (default 5.93)                   │
│   • 'Calc': Age/wavelength-dependent (Scholkmann et al. 2013)  │
│                                                                 │
│ Output: HbO, HbR, HbTotal, HbDiff, CBSI                        │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│                    STAGE 3: Hemoglobin Processing               │
├─────────────────────────────────────────────────────────────────┤
│ Input: Hemoglobin concentrations                                │
│ Function: processStageFilterHb()                                │
│ Methods: Configured in +pf2/+methods/+oxy                       │
│                                                                 │
│ Processing steps:                                               │
│   • Baseline correction                                         │
│   • Filtering                                                   │
│   • ROI averaging                                               │
│   • Statistical processing                                      │
│                                                                 │
│ Output: Final hemoglobin data, ROI averages                     │
└─────────────────────────────────────────────────────────────────┘
```

## Processing Flow Architecture

```
processFNIRS2.m (main)
    ↓
pf2_base.pf2_initialize() → Load methods, device, defaults
    ↓
Load device config → Probe geometry, channel info
    ↓
Raw data input (fNIRS struct)
    ↓
Stage 1: processStageRaw2OD()
    ├─ Apply raw methods from PF2.stageRawMethod
    ├─ Iterate through F (PipelineFunction objects, converted at unpack time)
    └─ Output: Optical Density
    ↓
Stage 2: processStageOD2Hb()
    ├─ Beer-Lambert conversion (bvoxy)
    ├─ DPF calculation (age-dependent)
    └─ Output: HbO, HbR, HbTotal, HbDiff, CBSI
    ↓
Stage 3: processStageFilterHb()
    ├─ Apply oxy methods from PF2.stageOxyMethod
    ├─ Iterate through F (PipelineFunction chain)
    └─ Output: Filtered Hb data
    ↓
Output fNIRS struct with all stages
```

---

## Available Processing Methods

### Raw Processing Methods
Methods for Stage 1 processing (Raw → Optical Density):

| Method | Description |
|--------|-------------|
| `None` | No processing |
| `x1_lpf` | Low-pass filter only |
| `x1_lpf_mask` | Low-pass filter with masking |
| `x2_lpf_smar` | Low-pass filter + SMAR |
| `x2_lpf_smar_permissive` | LPF + SMAR (permissive settings) |
| `x2_lpf_smar_short` | LPF + SMAR (short window) |
| `x3_bpf` | Band-pass filter |
| `x3_bpf_008_1` | BPF (0.008-1 Hz) |
| `x3_bpf_008_1_mask` | BPF (0.008-1 Hz) with masking |
| `x4_bpf_smar` | Band-pass filter + SMAR |
| `x5_TDDR` | Temporal Derivative Distribution Repair |
| `x5_TDDR_mask` | TDDR with masking |
| `x5_TDDR_mask_smar` | TDDR + masking + SMAR |
| `x6_TDDR_lpf` | TDDR + low-pass filter |
| `x6_TDDR_lpf_mask` | TDDR + LPF + masking |
| `x6_lpf_MARA` | LPF + Movement Artifact Reduction |
| `x6_lpf_SMAR_SR` | LPF + SMAR (spline reconstruction) |
| `x6_lpf_TDDR` | LPF + TDDR |
| `x6_medfilt_TDDR` | Median filter + TDDR |
| `x7_kbWF` | Kalman-Butterworth Wiener filter |
| `x7_kbWF_lpf` | kbWF + low-pass filter |
| `x8_lpf_mask_subAmb` | LPF + masking + ambient subtraction |
| `x8_mask_subAmb_tddr` | Masking + ambient subtraction + TDDR |
| `x8_mask_subAmb_wave` | Masking + ambient subtraction + wavelet |
| `x8_mask_subAmb_wave_bpf` | Masking + ambient + wavelet + BPF |
| `x8_mask_subAmb_wave_detrend` | Masking + ambient + wavelet + detrend |
| `x8_mask_subAmb_wave_lpf` | Masking + ambient + wavelet + LPF |
| `x9_bpf_mask_subAmb` | BPF + masking + ambient subtraction |
| `x9_lpf_mask_subAmb_detrend` | LPF + masking + ambient + detrend |

### Oxy Processing Methods
Methods for Stage 3 processing (Hemoglobin post-processing):

| Method | Description |
|--------|-------------|
| `None` | No processing |
| `bpf_butter` | Butterworth band-pass filter |
| `bpf_fir` | FIR band-pass filter |
| `car` | Common Average Reference |
| `hpf` | High-pass filter |
| `lpf_car` | Low-pass filter + CAR |
| `medfilt` | Median filter |
| `medfilt_car` | Median filter + CAR |
| `takizawa_easy` | Takizawa rejection (easy threshold) |
| `takizawa_easy_car` | Takizawa easy + CAR |
| `takizawa_easy_car_pca` | Takizawa easy + CAR + PCA |
| `takizawa_easy_lpf` | Takizawa easy + low-pass filter |
| `takizawa_easy_lpf_detrend` | Takizawa easy + LPF + detrend |
| `takizawa_easy_pca` | Takizawa easy + PCA |
| `takizawa_hard` | Takizawa rejection (hard threshold) |
| `takizawa_hard_car` | Takizawa hard + CAR |
| `takizawa_hard_car_pca` | Takizawa hard + CAR + PCA |
| `takizawa_hard_lpf` | Takizawa hard + low-pass filter |
| `takizawa_hard_lpf_detrend` | Takizawa hard + LPF + detrend |
| `takizawa_hard_pca` | Takizawa hard + PCA |

---

## Pipeline Class System

The Pipeline class hierarchy provides a programmatic, type-safe alternative to legacy method structs for building processing chains:

```
pf2_base.Pipeline          (base, value class — ordered chain of steps)
├── pf2_base.RawPipeline   (Stage 1 — hasIntensity2OD())
└── pf2_base.OxyPipeline   (Stage 3 — hasROI(), swapROI(), removeROI())

pf2_base.PipelineFunction  (immutable value class — single processing step)
```

### PipelineFunction

Each processing function is encapsulated as a `PipelineFunction` with precomputed argument mappings. At construction, string argument names are resolved to uint8 enum types (x, fs, fTime, fchMask, etc.), so `execute(ctx)` runs with zero string comparison overhead.

```matlab
% Build from config (auto-discovers signature)
pf = pf2_base.PipelineFunction.detect('pf2_lpf');

% Convert from legacy struct
pf = pf2_base.PipelineFunction.fromStruct(legacyStruct);

% Convert back to legacy
s = pf.toStruct();
```

### Building Pipelines

```matlab
raw = pf2_base.RawPipeline('myPipeline');
raw = raw.add('pf2_Intensity2OD');
raw = raw.add('pf2_MotionCorrectTDDR');
raw = raw.add('pf2_lpf', 'freq_cut', 0.2);

% Convert to legacy method struct for processing
m = raw.toMethod();

% Reconstruct from existing named method
raw = pf2_base.RawPipeline.fromMethod('x5_TDDR');
```

### Eager Conversion at Unpack Time

`pf2_unpackMethod` converts all legacy structs in `.F{}` to PipelineFunction objects when a method is unpacked. This is the single canonical conversion point — all callers (`processFNIRS2`, `ProcessingContext`, GUI, method CRUD via `create.m`) receive PipelineFunction objects ready for execution. The stage functions (`processStageRaw2OD`, `processStageFilterHb`) retain a silent `fromStruct()` fallback for safety but should never encounter plain structs in normal operation.

---

## Configuration Files

### Method Configuration (`/prefs/`)
- `pf2_functions_default.cfg` - Default processing function configurations

**User-specific (stored in MATLAB `prefdir`):**
- `pf2_raw_methods_stored_processFNIRS2.cfg` - User's raw method configs
- `pf2_oxy_methods_stored_processFNIRS2.cfg` - User's oxy method configs

### Method Configuration Structure
```ini
[MethodName]
Name = 'Display Name'
Description = 'Method description'
Arguments = {'arg1', 'arg2', ...}
Output = {'x', 'fchMask', ...}
validStages = [1, 2]  % Which processing stages
requiresOD = 1         % (optional) Function needs OD input — validated at runtime
arg1 = value1
arg2 = value2
```

The `requiresOD` field marks functions that operate on optical density data (e.g., motion correction algorithms). When present, `processStageRaw2OD` validates that `pf2_Intensity2OD` has been applied before executing the function.

### Method Storage Format (S# → .F)

Processing method chains are stored in INI using sequential `S1`, `S2`, `S3` fields. Each S# field holds a struct defining one function in the chain. At runtime, `pf2_base.pf2_unpackMethod()` converts these to a `.F` cell array of `PipelineFunction` objects:

```matlab
% INI storage (packed)          →  Runtime (unpacked)
% method.S1 = struct(...)       →  method.F{1} = PipelineFunction(...)
% method.S2 = struct(...)       →  method.F{2} = PipelineFunction(...)
```

This unpacking is the single canonical implementation — the GUI's `unpackMethods` and the CLI's `unpackMethodsLocal` both delegate to `pf2_unpackMethod`.

### Color Schemes (`/prefs/`)
- `exploreFNIRS_defaultColors.csv` - Default color scheme for plots
- `exploreFNIRS_pastelColors.csv` - Alternative pastel colors

---

## Recommended Method Configurations

Based on real research usage:

**For motion-prone data (head movement):**
```matlab
% Raw stage: Motion correction + filtering
pf2.methods.raw.setMethod('x2_lpf_smar');        % LPF + SMAR
% or
pf2.methods.raw.setMethod('x5_TDDR');            % TDDR alone
% or
pf2.methods.raw.setMethod('x6_lpf_TDDR');        % LPF + TDDR

% Spline interpolation — good for isolated, large artifacts
% Can combine with wavelet for hybrid correction (spline first, then wavelet)
pf2_MotionCorrectSpline(dod, fs);                % Default params
pf2_MotionCorrectSpline(dod, fs, 0.99, 0.5, 1, 10, 0.5);  % Custom thresholds

% Spline + Savitzky-Golay — combines spline with SG smoothing
pf2_MotionCorrectSplineSG(dod, fs);
```

**For cleaner data (minimal motion):**
```matlab
% Raw stage: Filtering only
pf2.methods.raw.setMethod('x1_lpf');             % Low-pass only
pf2.methods.raw.setMethod('x3_bpf');             % Band-pass (0.008-0.1 Hz)
```

**For oxy stage (post-hemoglobin):**
```matlab
% Conservative artifact rejection
pf2.methods.oxy.setMethod('takizawa_easy');      % Lenient thresholds

% Aggressive artifact rejection
pf2.methods.oxy.setMethod('takizawa_hard_lpf_detrend');  % Strict + detrend

% Spatial filtering
pf2.methods.oxy.setMethod('medfilt_car');        % Median + CAR
```

## Common Processing Parameters

| Parameter | Typical Value | Purpose |
|-----------|---------------|---------|
| `blLength` | 5-10 sec | Baseline duration for normalization |
| `blStartTime` | 0 sec | Baseline start relative to t0 |
| `defaultSubjectAge` | 25 years | For DPF calculation |
| `DPFmode` | 'Calc' | Age-dependent DPF |
| resample rate | 2-10 Hz | Common time grid for multi-device |
| LPF cutoff | 0.1 Hz | Remove cardiac/respiratory |
| BPF range | 0.008-0.1 Hz | Isolate hemodynamic response |
| IIR filter order | 3-5 | Butterworth IIR (sharper rolloff than FIR) |
| SCI threshold | 0.75 | Scalp coupling index channel rejection |
| GLM drift type | 'legendre' or 'dct' | Low-frequency drift model |
| DCT cutoff | 128 sec | High-pass cutoff for DCT drift basis |

## When to Use Bandpass Filtering

Bandpass filtering on hemoglobin data (Stage 3) is **not always necessary**. The right choice depends on the downstream analysis.

### GLM Analysis — No Bandpass Needed

When using `fitGLM` with drift regressors and AR-IRLS, explicit bandpass filtering is redundant and can be harmful:

- **Drift regressors** (Legendre polynomials or DCT basis) model low-frequency trends explicitly, replacing a high-pass filter
- **AR-IRLS** estimates and removes autocorrelated noise structure, replacing a low-pass filter
- Bandpass filtering (especially low-pass at 0.1 Hz) can distort the fast peak of the hemodynamic response function (HRF)

Recommended GLM pipeline:
```matlab
pf2.methods.raw.setMethod('x5_TDDR_mask');  % Motion correction on OD
pf2.methods.oxy.setMethod('None');           % No bandpass — GLM handles it

% Design matrix includes drift regressors
[X, names] = pf2_base.fnirs.buildDesignMatrix(data.time, data.fs, events, ...
    'DriftOrder', 3);                        % Legendre drift replaces high-pass
results = pf2_base.fnirs.fitGLM(data.HbO, X, names, 'Method', 'AR-IRLS');
```

### Wavelet Coherence — No Pre-Filtering Needed

Wavelet coherence (WCT) is inherently frequency-selective — it decomposes the signal into time-frequency space. Pre-filtering would remove the very frequencies you want to analyze:

```matlab
pf2.methods.oxy.setMethod('None');  % No bandpass before WCT

% WCT isolates frequency bands of interest directly
connResults = ex.connectivity('Method', 'wcoherence');
```

### When Bandpass Filtering IS Appropriate

Use bandpass filtering (`bpf_butter`, 0.008–0.1 Hz) for:

- **Block averaging** without GLM (epoch-based approach)
- **Trial-by-trial amplitude extraction** (peak/mean in a time window)
- **Pearson/Spearman correlation** on full continuous time series (not block-extracted segments)
- **Visualization** of hemodynamic response shape

```matlab
pf2.methods.oxy.setMethod('bpf_butter');  % 0.008-0.1 Hz Butterworth
```

Short block-extracted segments (e.g., 30s) naturally limit low-frequency drift contribution, so bandpass is less critical for block-wise correlation analyses.

## Advanced Processing

### Systemic / Global Interference Removal
Scalp blood flow, Mayer waves (~0.1 Hz), cardiac, and blood-pressure swings
are spatially shared across channels. Three approaches, in increasing order of
how well-motivated they are:

| Method | Function | Idea | When |
|--------|----------|------|------|
| CAR | `pf2_CAR` | Subtract the raw spatial mean (one fixed component) | Quick global knockdown; dense coverage |
| GSR | `pf2_GSR` | Subtract the leading PCA component(s) of the across-channel covariance (tunable generalization of CAR) | No short channels available |
| SSR | `pf2_SSR` | Regress out measured short-separation channels | **Preferred** — when short channels exist |

CAR and GSR force a component out of every channel, which can remove focal
signal and inject spurious anti-correlations (a known negative bias for
connectivity). Prefer SSR when short channels are present.

```matlab
% GSR: remove the dominant global PCA component (nComp=1 ~ CAR, but tunable)
processed.HbO = pf2_GSR(processed.HbO, 1);
processed.HbR = pf2_GSR(processed.HbR, 1);
% As a registered oxy-stage pipeline step:
oxy = pf2_base.OxyPipeline('demo').add('pf2_GSR', 'nComp', 1);
```

GSR implements a global PCA spatial filter in the spirit of Zhang et al.
(2005), J. Biomed. Opt. 10(1) 011014. See `example_global_signal_removal.m`
for a CAR vs GSR vs SSR comparison against ground truth.

Implementation: `functions/pf2_GSR.m`, `functions/pf2_CAR.m`

### Short Channel Regression (SSR)
Short-separation channels can be used to regress out superficial (scalp) hemodynamics:

```matlab
% Direct regression (nearest short channel per long channel)
corrected = pf2_base.fnirs.shortChannelRegression(data, 'Method', 'nearest');

% PCA-based: extract principal components, then use as GLM regressors
[pcMatrix, pcInfo] = pf2_base.fnirs.extractShortChannelPCs(data, 'NumPCs', 2);
[X, names] = pf2_base.fnirs.buildDesignMatrix(data.time, data.fs, events, ...
    'ShortChannels', pcMatrix);

% Pipeline-compatible wrapper
processed = pf2_SSR(processed);
```

Short channels are detected with the precedence `probeinfo.IsShortSeparation`
→ `device.isShortSep()` → an SD-distance threshold (`ShortSepMax`). The device
fallback lets SSR run on device-config imports that carry short channels in the
device but no probeinfo — e.g. the bundled `pf2.import.sampleData.fNIR2000()`
recording (channels 17–18). A NaN gap in a short channel leaves the affected
long-channel samples uncorrected rather than erasing them. Pass
`'CenterRegressors', true` for an exactly mean-preserving correction (the
default leaves a small `mean(regressor)*beta` DC offset, matching historical
behavior).

Implementation: `functions/pf2_SSR.m`, `+pf2_base/+fnirs/shortChannelRegression.m`, `+pf2_base/+fnirs/extractShortChannelPCs.m`

### GLM Analysis
Build design matrices and fit general linear models to fNIRS data:

```matlab
% Define events from markers
events(1).name = 'TaskA'; events(1).onsets = [10, 40, 70]; events(1).duration = 15;
events(2).name = 'TaskB'; events(2).onsets = [25, 55, 85]; events(2).duration = 15;

% Build design matrix (Legendre drift — default)
[X, names] = pf2_base.fnirs.buildDesignMatrix(data.time, data.fs, events, ...
    'DriftOrder', 3, 'IncludeDerivative', true);

% Build design matrix (DCT cosine drift — SPM-style)
[X, names] = pf2_base.fnirs.buildDesignMatrix(data.time, data.fs, events, ...
    'DriftType', 'dct', 'DriftCutoff', 128);

% Include short-channel PCA regressors
[pcMatrix, pcInfo] = pf2_base.fnirs.extractShortChannelPCs(data, 'NumPCs', 2);
[X, names] = pf2_base.fnirs.buildDesignMatrix(data.time, data.fs, events, ...
    'ShortChannels', pcMatrix);

% Fit GLM (OLS or AR-IRLS)
results = pf2_base.fnirs.fitGLM(data.HbO, X, names);
results = pf2_base.fnirs.fitGLM(data.HbO, X, names, 'Method', 'AR-IRLS');
```

Implementation: `+pf2_base/+fnirs/buildDesignMatrix.m`, `+pf2_base/+fnirs/fitGLM.m`, `+pf2_base/+fnirs/extractShortChannelPCs.m`

### Block Definition and Extraction
Define experimental blocks from markers and extract corresponding data segments:

```matlab
% Define blocks from marker codes. Embed=false returns the block ARRAY;
% the default Embed=true returns the data struct with .blocks embedded.
blocks = pf2.data.defineBlocks(data, [49, 50], 30, 'Embed', false);

% Extract block data. When PreTime/PostTime are omitted, a small default
% Buffer of 2 s per side is used (a one-time pf2:extractBlocks:defaultBuffer
% note is emitted) — set them explicitly to size the epoch deliberately. If you
% accidentally pass an Embed=true data struct as the blocks arg it uses its .blocks.
segments = pf2.data.extractBlocks(data, blocks, 'PreTime', 5, 'PostTime', 15);

% Single-subject trial/grand average onto a common grid (one call). Required
% because epoched segments share a sampling rate but differ in sub-sample
% phase; blockAverage regrids them so the average is not all-NaN.
ga = pf2.data.blockAverage(segments);   % or pf2.data.grandAverage
% ga.<HbO|HbR|HbTotal|HbDiff|CBSI>.{Mean,SEM,SD,N,Median,Max,Min}, ga.time
```

For multi-condition or group averaging, feed the segments to
`exploreFNIRS.core.Experiment` instead (`groupby` → `aggregate` → plots).

When data is imported from SNIRF with a companion BIDS `_events.tsv`, `defineBlocks` auto-labels blocks from `data.info.eventTypes` without needing a manual `ConditionMap`:

```matlab
data = pf2.import.importSNIRF('sub-01_nirs.snirf');  % reads events.tsv
blocks = pf2.data.defineBlocks(data, [1, 2, 3]);     % auto-labeled
```

### Context-Based Processing
Use `ProcessingContext` for isolated, reproducible processing. The context path
is **fully isolated** from global state: when `'Context', ctx` is passed,
`processFNIRS2` neither initializes nor writes the `PF2`/`setF` globals —
config, methods, and the device are threaded as locals (the device is resolved
from the context, or from the data's embedded probeinfo/cfg). This makes the
path safe for `parfor` and byte-for-byte reproducible.

```matlab
ctx = pf2_base.ProcessingContext.fromGlobals();
ctx.dpfMode = 'Calc';
ctx.subjectAge = 30;
ctx.setRawMethod('x5_TDDR');
result = processFNIRS2(data, 'Context', ctx);   % globals left untouched
```

The legacy (no-context) call still uses the `PF2`/`setF` globals for
interactive/GUI back-compat. An explicit `ctx.applyToGlobals()` remains as an
opt-in for GUI code that reads from globals.

### Custom Method Management
Create, modify, and share processing methods programmatically:

```matlab
pf2.methods.raw.create('MyMethod');
pf2.methods.raw.editFunction('MyMethod', 'pf2_lpf', struct('freq_cut', 0.08));
pf2.methods.raw.exportMethod('MyMethod', 'my_method.mat');
pf2.methods.raw.importMethod('shared_method.mat');
pf2.methods.raw.delete('OldMethod');
```

### Foundation-Model Export / Embeddings (HDF5 contract)
Processed recordings can be exported to a self-describing HDF5 tensor for
machine-learning pipelines, and learned features read back in. The tensor
payload follows the canonical `[time × channel × feature]` shape (or
`[window × time × channel × feature]` with a windowing layer), carrying the
montage descriptor, QC, markers, marker dictionary, demographics, and full
processing provenance. See the [foundation-model tensor export](API_REFERENCE.md)
(`pf2.export.asTensor`) for the contract.

```matlab
pf2.export.asTensor(processed, 'subj01.h5');          % HDF5 tensor (contract v1.0)
data = pf2.import.importEmbeddings(processed, 'subj01_emb.h5'); % attach learned features
% data.embeddings then behaves like any other biomarker block in exploreFNIRS
```

---

## Data Quality Indicators

Watch for these quality issues:

| Issue | Detection | pf2 Solution |
|-------|-----------|--------------|
| Motion artifacts | Spikes in raw signal | SMAR, TDDR, MARA, Spline, Wavelet |
| Poor optode contact | Low signal, high noise | SCI rejection (`pf2_SCIRejection`), Takizawa rejection |
| Saturation | Clipped values | Mask as NaN before processing |
| Drift | Slow baseline shift | Detrend methods, BPF |
| Cardiac contamination | ~1 Hz oscillation | LPF < 0.5 Hz |

For automated, headless quality control use the QC pipeline
(`pf2.qc.pipeline.assess` → `report`/`plotReport` → `apply`, or the one-call
`pf2.qc.snapshot`). Two defaults were recalibrated so normal data is not
over-rejected:

- **CoV threshold 0.2** (was 0.1) — raw fNIR intensity naturally runs higher
  CoV than filtered Hb.
- **Takizawa Rule 4 (body movement)** now counts discrete movement *events*
  (rising edges) rather than per-sample threshold crossings, with the jump
  threshold raised to **0.5 mM\*mm** (the published 0.15 was calibrated for
  Hitachi ETG-4000 verbal-fluency data and over-rejected elsewhere). The
  tolerated event count scales as `floor(recordingLength / ProtocolDuration)`.
  These defaults are validated on the bundled `fNIR2000` sample; confirm
  thresholds on your own device data.
