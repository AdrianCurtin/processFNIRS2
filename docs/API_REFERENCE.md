# processFNIRS2 API Reference

## Contents
- [+pf2 — User-Facing Interface](#pf2-user-facing-interface) — import, export, data, methods, probe, QC, settings
- [+pf2_base — Internal Infrastructure](#pf2_base-internal-infrastructure) — pipelines, core processing, signal/wavelet
- [+exploreFNIRS — Analysis & Visualization](#explorefnirs-analysis-and-visualization-gui) — Experiment class, stats, connectivity, hyperscanning, graph, report
- [Signal Processing Functions (`/functions/`)](#signal-processing-functions-functions)
- [Supported Devices (`/devices/`)](#supported-devices-devices)
- [Global Variables](#global-variables)
- [File Type Associations](#file-type-associations)

## +pf2 (User-Facing Interface)

The primary user-facing package with intuitive function paths.

### +pf2/+import - Data Import Functions
| Function | Purpose |
|----------|---------|
| `importNIR.m` | Import fNIR Devices/Biopac (.nir) files |
| `importNIRX.m` | Import NIRx system files |
| `importHitachiMES.m` | Import Hitachi ETG-4000 (.csv) files |
| `importOxy3.m` | Import Artinis OxySoft (.oxy3) files. Parses the OXY3 binary container (UTF-16LE XML header + int16 frames), derives channels/wavelengths, and extracts markers from the digital port/trigger channels. Optode geometry is a placeholder unless an OxySoft `optodetemplates.xml` is supplied via `'OptodeTemplate'` |
| `importSNIRF.m` | Import standardized SNIRF format files (auto-reads BIDS `_events.tsv` for `trial_type` labels) |
| `importDirectory.m` | Batch-import files from a directory tree with auto-format detection |
| `importEmbeddings.m` | Re-import learned features/predictions from an HDF5 file (foundation-model export contract) into a `data.embeddings` block aligned to the recording's time base |
| `fromTable.m` | Build fNIRS-shaped segment structs from a long-format (tidy) data table — survey waves, longitudinal scores, diary measures — so the Experiment class, temporal/bar plots, and the LME engine work on non-device data. Each Subject → one segment, Time → the time axis, each Value → a pseudo-channel. No device/probe, so spatial viz is unavailable |
| `sampleData.m` | Load included example datasets (bare call loads fNIR1200; `sampleData.fNIR2000()`, `sampleData.experiment()`, `sampleData.group()` for siblings) |

### +pf2/+export - Data Export Functions
| Function | Purpose |
|----------|---------|
| `export.m` | Auto-detect format from extension; batch-capable with `'Format'` param |
| `asNIR.m` | Export to NIR file format (single struct or batch cell array) |
| `asSNIRF.m` | Export to SNIRF standardized format (single struct, multi-run, or batch) |
| `asBIDS.m` | Export a cell array as a true BIDS-NIRS dataset — `*_nirs.snirf` plus JSON/`channels.tsv`/`events.tsv` sidecars in a `sub-/ses-/nirs` tree, with `dataset_description.json`, `participants.tsv`, and README. Requires a `'Task'` label; entities resolve from each struct's `.info` |
| `asTensor.m` | Export as a self-describing HDF5 tensor (foundation-model contract v1.0): `[time × channel × feature]` payload + montage descriptor + manifest (QC, markers, info, provenance). Supports windowed `[window × time × channel × feature]` output |

Batch export: pass a cell array and a directory path to write one file per element. Use `'Dir1'..'Dir4'` to map `.info` fields to subdirectories, and `'Prefix'` to build filenames from `.info` values.

### +pf2/+data - Data Manipulation
| Function | Purpose |
|----------|---------|
| `plot.m` | Route to appropriate plot function |
| `applyChannelMask.m` | Mark bad channels as NaN |
| `concatenate.m` | Merge multiple devices/probes into one structure (more channels; resamples to a common rate and aligns time) |
| `concatenateHorizontal.m` | Concatenate segments in time (temporal merge of runs from the same probe — despite the name, this appends rows, not channels) |
| `defineBlocks.m` | Convert markers to block struct array (auto-labels blocks from the marker dictionary — `markerDict`/`eventTypes`/COBI) |
| `slidingWindows.m` | Tile a continuous recording with fixed-length/overlapping window blocks (`'Length'`, `'Step'`/`'Overlap'`) on a regular grid; same block format as `defineBlocks`, feeds `extractBlocks` (dynamic FC, resting-state, model input) |
| `labelMarkers.m` | Stamp a categorical `.Label` column on the marker table from a `{code,'Label'}` map or the dataset's marker dictionary |
| `getMarkerDict.m` | Resolve the dataset's code→label dictionary (`info.markerDict` → `eventTypes` → COBI `MarkerDict` → unique codes) |
| `setMarkerDict.m` | Set/merge `data.info.markerDict` (table/cell/`Map`); `'Merge'` (default true) unions, new wins |
| `editChannelMaskGUI.m` | GUI for channel masking |
| `extractBlocks.m` | Extract fNIRS segments by block definitions (note: when `PreTime`/`PostTime` are omitted, a small default `Buffer` of 2 s per side is used — set them explicitly to size epochs; passing an embedded data struct as the `blocks` arg is detected and resolved) |
| `blockAverage.m` | Trial/grand average of epoched segments onto a common grid (resamples segments to a shared grid first, so marker-epoched data does not average to NaN) |
| `grandAverage.m` | Alias for `blockAverage.m` |
| `importInfo.m` | Import subject-level metadata from CSV/Excel into .info |
| `importBlockInfo.m` | Import block-level metadata into block structs from a CSV/Excel path, an in-memory MATLAB table, or a numeric per-block vector (assigned to the field named by `'Field'`, default `'value'`) |
| `infoToTable.m` | Extract `.info` fields to a MATLAB table. Options: `'Fields'` to select columns, `'SavePath'` to export. Single-field shorthand: `infoToTable(allData, 'Group')` returns vector |
| `infoFromTable.m` | Write table (or single field) back into `.info`. Options: `'Overwrite'` (default true), `'Clear'` (replace `.info` entirely). Scalar broadcast: `infoFromTable(allData, 'Group', 'Control')`. Per-element: `infoFromTable(allData, 'Group', ["A";"B";"C"])` |
| `getMarkers.m` | Extract marker timepoints. Scalar = single code; row vector `[50,51]` = sequence (50 then 51); column vector `[50;51]` = either code (OR); warns when no requested code is found |
| `resample.m` | resample/average fNIRS data |
| `setT0.m` | Shift time alignment |
| `split.m` | Extract time segment with optional baseline correction |
| `auxOnGrid.m` | Resample a named auxiliary signal (nested or flattened) onto the fNIRS time base — anti-aliased and NaN-gap aware; `'Channels'` selects a subset |
| `betasToSegments.m` | Convert GLM betas back to segment-style data format |

### +pf2/+data/+plot - Visualization
| Function | Purpose |
|----------|---------|
| `oxy.m` | Plot hemoglobin concentration data |
| `raw.m` | Plot raw light intensity data |
| `roi.m` | Plot region-of-interest data |
| `auxData.m` | Plot auxiliary temporal data |

### +pf2/+data/+aux - Auxiliary Signal Features
Type-aware feature extractors that turn a raw auxiliary waveform into a derived
feature series. Aux signals are typed (HR, EKG, PPG, ACCEL, GSR/EDA, EEG, RESP,
TEMP) by `pf2_base.auxSignalType` and put in canonical form by
`pf2_base.normalizeAux`.
| Function | Purpose |
|----------|---------|
| `heartRateFrom.m` | Derive a heart-rate (bpm) series from a PPG or EKG waveform |
| `hrvFeatures.m` | Heart-rate variability metrics (SDNN/RMSSD/pNN50/LF/HF/LFHF) from a waveform or beat series |
| `hrvSeries.m` | Time-resolved HRV via a sliding window over a waveform |
| `edaDecompose.m` | Split electrodermal activity (GSR) into tonic (SCL) and phasic (SCR) components |
| `accelFeatures.m` | Motion features (norm, jerk) from a multi-axis accelerometer signal |
| `eegBandPower.m` | Canonical EEG band-power feature series (delta..gamma) |
| `respFeatures.m` | Respiration rate (br/min) and RVT from a respiration waveform |
| `addFeature.m` | Store a derived signal back as a typed Aux feature (survives SNIRF round-trip) |

### +pf2/+methods - Processing Method Management
| Subpackage | Purpose |
|------------|---------|
| `+raw/` | Raw processing stage method configuration |
| `+oxy/` | Oxygenation processing stage method configuration |

Each subpackage contains:
- `list.m` - List available methods
- `setMethod.m` - Select active method
- `configureMethods.m` - Create/edit methods (GUI)
- `describeMethod.m` - Display method documentation
- `importMethods.m` / `importMethod.m` - Import method configuration files
- `create.m` - Create a new method programmatically
- `delete.m` - Delete a method
- `editFunction.m` - Modify a function in a method chain
- `removeFunction.m` - Remove a function from a method chain
- `exportMethod.m` - Export method for sharing

**+pf2/+methods (shared):**
- `validateFunction.m` - Validate function compatibility with processing stages

### +pf2/+process - Processing Pipeline
| Function | Purpose |
|----------|---------|
| `process.m` | Generic processing dispatcher |
| `processRaw.m` | Execute raw processing stage only |
| `processOxy.m` | Execute oxy processing stage only |

### +pf2/Device — Device Value Class
| Member | Returns |
|--------|---------|
| `Device.load(nameOrData)` | Create Device from config name or data struct (cached) |
| `Device.fromProbeInfo(probeInfo)` | Create Device from already-loaded probeInfo struct |
| `Device.clearCache()` | Reset persistent cache |
| `dev.wavelengths()` | `[1×C_raw]` wavelength per raw column |
| `dev.channelNumbers()` | `[1×C_raw]` optode number per raw column |
| `dev.channelList()` | `[1×nCh]` unique channel indices |
| `dev.mniPositions()` | `[nCh×3]` MNI coordinates |
| `dev.sdDistances()` | `[1×nCh]` source-detector distances |
| `dev.channelTable()` | MATLAB table (TableCh) |
| `dev.optodeTable()` | MATLAB table (TableOpt) |
| `dev.layout2D()` | Cell array of subplot positions |
| `dev.hasMNI()` | logical |
| `dev.isShortSep()` | `[1×nCh]` logical mask |

Immutable properties: `name`, `manufacturer`, `model`, `nChannels`, `nShortSep`, `defaultFs`, `wavelengthSet`, `rawMax`, `rawMin`, `probeInfo`.

Auto-attached as `data.device` by all import functions and `processFNIRS2`.

### +pf2/+settings - Configuration Management
| Function | Purpose |
|----------|---------|
| `selectDevice.m` | Load device configuration file |
| `getDevice.m` | Query current device settings (checks `data.device` first) |
| `setRejectLevel.m` | Set channel rejection threshold |

**+baseline subfolder:**
- `setBaselineStartTime.m` - Set baseline start time
- `setBaselineLength.m` - Set baseline duration
- `useGlobalMean.m` - Use entire signal as baseline

**+dpf subfolder:**
- `setDPFmode.m` - Set DPF calculation mode (None/Fixed/Calc)
- `setFixedDPF.m` - Set fixed DPF value

### +pf2/+probe - Probe Geometry and ROI
| Function/Subpackage | Purpose |
|---------------------|---------|
| `nearestBrodmann.m` | Find nearest Brodmann areas for each channel |
| `montage.m` | Portable, self-describing montage export — per-channel table + montage descriptor struct (MNI coords, S-D distances, wavelengths, short-sep flags, nearest Brodmann); optional JSON/CSV/XLSX sidecar |
| `saveCfg.m` | Write a probe's geometry to a toolbox-native device `.cfg` (reloadable via `pf2.Device.load`) — reconstructs src/det coords, channel/wavelength mapping, and sI/dI from the device tables; accepts a data struct, `pf2.Device`, `.snirf` path, or config name; prefers 3D (mm), falls back to 2D |
| `canonicalize.m` | Project channel biomarker series onto a shared Brodmann-region axis for cross-montage/cross-device comparison (region averaging via `nearestBrodmann`); a cell array yields a common region axis |
| `+plot/` | Probe visualization functions |
| `+project/` | Project statistical values onto the cortical surface |
| `+roi/` | Region of interest management |
| `+forward/` | DOT forward model — optical sensitivity (PMDF) on the cortical mesh |
| `+dot/` | Diffuse optical tomography — image reconstruction and diagnostics |

**Plot functions:**
- `topo.m` - Convenience topographic map (2D/3D); `'View','movie'` animates over time
- `arrangedValues.m` - Plot arranged channel values
- `imageValues.m` - Create 2D heatmap of channel values
- `interpolateValues.m` - Interpolate values across probe
- `interpolateValues3D.m` - 3D interpolation visualization (`'interpolateType','sensitivity'` for a Gaussian optical-sensitivity kernel; `'Style','showcase'|'publication'` render presets — see below)
- `imageROIvalues.m` - Heatmap for ROI values
- `interpolateROIvalues.m` - Interpolated ROI visualization
- `showProbe3D.m` - 3D probe geometry visualization
- `movie.m` - Animate a biomarker over time on the cortex/probe (MP4/AVI/GIF)
- `connectome.m` - Draw a connectivity network anchored at channel/ROI positions (2D/3D)
- `tomographyMovie.m` - Animate a time-resolved DOT reconstruction on the cortex (MP4/AVI/GIF)
- `Explore3D.m` - Interactive explorer for `interpolateValues3D`: live controls for style/material/AO/view/colormap/interpolation/biomarker/labels, with the equivalent generating command shown for copy-paste

> **3D render styles.** `interpolateValues3D` (and everything built on it —
> `topo` `'View','3d'`, `project.*`) takes a `'Style'` preset. `'showcase'`
> (default) uses procedural matcap shading, a neutral-gray cortex, sulcal
> ambient occlusion, an elevated 3/4 "hero" view and 2× supersampled export
> (inspired by MRIcroGL/Surfice). `'publication'` is a conservative Gouraud
> matte look. Pass a struct (`pf2_base.plot.RenderStyle.get('showcase')`) to
> override individual fields (`matcapMaterial`, `aoStrength`, `heroView`,
> `supersample`, ...). Colormap names now resolve through
> `pf2_base.plot.brainColormap` — MRIcroGL LUTs (`actc`,`warm`,`cool`,
> `blue2red`,`bone`,`surface`) plus CVD-safe maps (`rdbu`,`viridis`,`cividis`).

**Project functions (`+pf2/+probe/+project/`):** 3D cortical-surface projection of per-channel statistics, with significance-based transparency.
- `pvalues.m` - Project p-values onto the cortex
- `fstats.m` - Project F-statistics
- `correlation.m` - Project correlation values
- `biomarker.m` - Project biomarker (e.g. mean HbO) values
- `counts.m` - Project per-channel N counts
- `regions.m` - Flat-fill Brodmann parcels from canonicalized region values
- `parcels.m` - Optode parcel map: per-channel Voronoi cells (nearest-optode) with outlines and on-surface numbers; optional value-fill and highlighted subset (channel-assignment cartoon, not reconstruction)
- `pmdf.m` - Project channel values through the physical sensitivity "banana" (honest footprint vs a Gaussian kernel)
- `tomography.m` - Render a DOT image reconstruction (signed, sensitivity-masked) on the cortex

**Diffuse Optical Tomography (`+pf2/+probe/+forward/`, `+pf2/+probe/+dot/`):** image-space HbO/HbR reconstruction on the cortical surface via an atlas forward model and a regularized inverse.
- `forward.sensitivity` - Channel-by-vertex PMDF sensitivity matrix on the MNI cortical mesh (options: wavelength, scalp offset, max S-D distance, pruning)
- `forward.coverage` - Per-vertex sensitivity support map for a montage
- `dot.reconstruct` - Vertex-space HbO/HbR reconstruction (depth-weighted, channel-whitened Tikhonov min-norm; auto-regularization; time-mean/windowed/all-time; priors `minnorm`/`laplacian`/`parcel`; optional layered head model + scalp regression)
- `dot.montageInfo` - Report whether a montage is high-density / multi-distance and its reconstruction suitability
- `dot.resolution` - Point-spread-function diagnostics (localization error, spread, FWHM)

---

## +pf2_base (Internal Infrastructure)

Core processing and utility functions used internally.

### Pipeline Classes
| Class | Purpose |
|-------|---------|
| `PipelineFunction.m` | Immutable value class encapsulating a single processing function with precomputed argument mappings and zero-overhead `execute()` |
| `Pipeline.m` | Ordered chain of PipelineFunction steps — `add()`, `insert()`, `remove()`, `setParam()`, `toMethod()`, `fromMethod()`, `params()` |
| `RawPipeline.m` | Stage 1 specialization — `hasIntensity2OD()` helper |
| `OxyPipeline.m` | Stage 3 specialization — `hasROI()`, `swapROI()`, `removeROI()` helpers |
| `ProcessingContext.m` | Execution context passed to `PipelineFunction.execute()`; carries the working data, settings, and device for an isolated processing run |

**PipelineFunction** resolves all argument lookups at construction time using uint8 enum types, so `execute(ctx)` runs with zero string comparison overhead. Supports `fromStruct(s)` / `toStruct()` for legacy method round-tripping, `detect(funcName)` for auto-discovering signatures, and `fromString(callStr)` for parsing MATLAB call syntax.

**Pipeline** is a value class — all mutating methods return a new copy. `toMethod()` converts to the legacy method struct consumed by `processStageRaw2OD` and `processStageFilterHb`. `fromMethod(name, stage)` reconstructs a Pipeline from an existing named method.

### Core Initialization
| Function | Purpose |
|----------|---------|
| `pf2_initialize.m` | Initialize system, load default settings |
| `pf2version.m` | Version information (note: no underscore) |
| `pf2_defaultRootPath.m` | Get installation path |
| `pf2_unpackMethod.m` | Parse method configuration; converts legacy structs to PipelineFunction |
| `pf2_updateCurrentDevice.m` | Sync device configuration |
| `pf2_describeMethod.m` | Display method information |
| `pf2_getFNIRSfields.m` | Get standard fNIRS field names |
| `pf2_getFNIRSbiomFields.m` | Get biomarker field aliases |
| `normalizeMarkers.m` | Normalize markers (matrix/table/`[]`) into the canonical table (`.Time`, `.Code`, `.Duration`, `.Amplitude` + extras) |
| `markersToArray.m` | Convert a canonical marker table (or matrix) to a numeric `[M x 4]` array |
| `mergeMarkers.m` | Row-concatenate two marker sets, unioning their columns |
| `normalizeMarkerDict.m` | Normalize a code→label dictionary (table/cell/`Map`/`[]`) into the canonical dict table (`.Code`, `.Label` + per-code attributes), deduped by `Code` |
| `mergeMarkerDict.m` | Merge two marker dictionaries, unioning codes and columns (first argument wins on `Code` conflicts) |
| `applyLightTheme.m` | Consistent light theme for figures |

### Utility Functions
| Function | Purpose |
|----------|---------|
| `isnestedfield.m` | Check nested struct fields |
| `mergestructs.m` | Merge structure arrays |
| `resolveDeviceFromData.m` | Return `data.device` if present, otherwise `pf2.Device.load(data)` |
| `loadDeviceCfg.m` | Load device configuration files |
| `loadProbeInfo.m` | Load probe geometry information |
| `buildProbeLayout.m` | Construct probe structure from config |
| `optTo2d.m` | Map 3D optode positions to 2D |
| `fitProbe2D.m` | Fit probe positions to 2D plane |
| `tablerow2struct.m` | Convert table row to struct |
| `hierarchicalAverage.m` | Hierarchical within-subject averaging |
| `pf2_plotArranged.m` | Plot data in configured arrangement |
| `filtfilt_interp.m` | Filtering with interpolation |
| `filtfilt_piecewise.m` | Piecewise filtering |
| `quickopen.m` / `quicksave.m` | Quick file I/O utilities |
| `getBioColors.m` | Get standard biomarker colors |
| `getAsset.m` | Load visualization assets (brain models, images) |
| `listAssets.m` | List available visualization assets |

### +pf2_base/+signal — Signal Processing Algorithms
| Function | Purpose |
|----------|---------|
| `tdsep.m` | Temporal Decorrelation Source Separation (TDSEP) — blind source separation via joint diagonalization of time-lagged covariance matrices (Ziehe & Muller 1998) |
| `lpf.m` / `hpf.m` / `bpf.m` | Numerically stable low-pass / high-pass / band-pass Butterworth filters |

### +pf2_base/+wavelet — Wavelet Transforms
Self-contained discrete and continuous wavelet routines (no external Wavelab or Wavelet Toolbox dependency).
| Function | Purpose |
|----------|---------|
| `makeONFilter.m` | Generate an orthonormal quadrature mirror filter (Haar, Daubechies, Symmlet, Coiflet, etc.) |
| `resolveWavelet.m` | Map a user-friendly wavelet name to an orthonormal QMF filter |
| `fwtPO.m` / `iwtPO.m` | Forward / inverse periodized orthogonal 1-D discrete wavelet transform |
| `fwtTI.m` / `iwtTI.m` | Forward / inverse translation-invariant (stationary) 1-D wavelet transform |
| `cwt.m` | Batch continuous wavelet transform (Morlet) |
| `wcoherence.m` | Wavelet coherence without the Wavelet Toolbox |
| `downDyadHi/Lo`, `upDyadHi/Lo`, `upSample`, `lShift`/`rShift`, `mirrorFilt`, `fwdConv`/`adjConv` | Filter-bank / convolution helpers |

### +pf2/+qc - Signal Quality Assessment
| Function | Purpose |
|----------|---------|
| `sci.m` | Scalp Coupling Index (cross-correlates cardiac across wavelengths; uses `data.device` for wavelength resolution) |
| `powerSpectrum.m` | PSD with physiological peak detection (cardiac, respiratory, Mayer) |
| `plotQuality.m` | Visualize SCI bar charts or PSD line plots with band overlays |
| `snapshot.m` | One-call headless QC summary — runs the pipeline and writes dashboard + PSD + SCI PNGs to a directory |
| `takizawa.m` | Four-rule Hb quality check (Takizawa). Rule 4 (body movement) counts discrete movement events; default jump threshold 0.5 mM*mm (generalizes better across devices than the published 0.15) |
| `ChannelCheck.m` | App Designer GUI for interactive channel quality review (replaces `probeCheckGUI`) |

### +pf2/+qc/+pipeline - Automated QC Pipeline
| Function | Purpose |
|----------|---------|
| `assess.m` | Run configurable quality checks on raw data (saturation, SCI, cardiac, CoV, Takizawa). Default CoV threshold 0.2 (raw intensity runs higher CoV than filtered Hb) |
| `apply.m` | Apply QC report recommendations to data |
| `report.m` | Print QC report summary to command window |
| `plotReport.m` | Visualize QC report as spatial channel map |

### +pf2_base/+fnirs - Core fNIRS Processing
| Function | Purpose |
|----------|---------|
| `processStageRaw2OD.m` | Raw data to optical density conversion (Stage 1) |
| `bvoxy.m` | Beer-Lambert conversion to hemoglobin (Stage 2) |
| `processStageFilterHb.m` | Hemoglobin filtering (Stage 3) |
| `bvoxy_basic.m` | Simplified Beer-Lambert conversion |
| `buildROI.m` | Create region of interest from channels |
| `buildHRF.m` | Build hemodynamic response function |
| `buildDesignMatrix.m` | Construct GLM design matrices (Legendre or DCT drift) |
| `fitGLM.m` | Fit general linear model (OLS or AR-IRLS); AR-IRLS returns prewhitened X and residuals |
| `diagnoseGLM.m` | Comprehensive GLM diagnostic report (collinearity, VIF, partial R², residual ACF, flagging) |
| `shortChannelRegression.m` | Regress out short-channel signals |
| `extractShortChannelPCs.m` | Extract PCA components from short channels for GLM |
| `ezBuildROI.m` | Easy ROI construction |
| `calcLocalCV.m` | Calculate local coefficient of variation |

### +pf2_base/+external - Third-Party Libraries

**Signal Processing (first-party replacements for Signal Processing Toolbox functions, called as `pf2_base.external.*`):**
- `butter.m`, `fir1.m`, `zp2sos.m` - Filter design (Butterworth, FIR, zero-pole-gain → second-order sections)
- `filtfilt_classic.m` - Zero-phase forward-backward filtering
- `sgolay.m`, `sgolayfilt.m` - Savitzky-Golay smoothing
- `medfilt1.m` - One-dimensional median filter
- `hamming.m`, `hann.m`, `hanning.m`, `genCosWin.m` - Window functions
- `barweb.m` - Error bar visualization

**Statistical Analysis:**
- `polyparci.m` - Polynomial confidence intervals

**Visualization:**
- `suptitle.m` - Super title for subplots
- `vline.m` - Vertical line annotation

**Configuration / Geometry:**
- `INI.m` - INI configuration file parser
- `icbm_fsl2tal.m` - ICBM to Talairach conversion
- `vrrotvec.m` / `vrrotvec2mat.m` - Rotation vector / rotation matrix utilities

**+colormaps subfolder:**
- `brewermap.m` - ColorBrewer color schemes
- `+matplotlib/` - Python matplotlib colormaps (viridis, plasma, inferno, magma, cividis, twilight, twilight_shifted, tab10, tab20, tab20b, tab20c)

**+jsnirfy subfolder (SNIRF I/O):**
- `loadsnirf.m` / `savesnirf.m` - SNIRF file I/O
- `loadjsnirf.m` / `savejsnirf.m` - JSON SNIRF I/O
- `snirfdecode.m` / `snirfcreate.m` - SNIRF structure handling

**+easyh5 subfolder (HDF5 utilities):**
- `loadh5.m` / `saveh5.m` - HDF5 file I/O
- `jdataencode.m` / `jdatadecode.m` - JSON data encoding

---

## +exploreFNIRS (Analysis and Visualization GUI)

Advanced GUI for multi-subject analysis and statistics. This is the **group-level analysis layer** that consumes processed fNIRS structs from processFNIRS2.

```
processFNIRS2 (per-subject)     exploreFNIRS (multi-subject)
─────────────────────────────   ─────────────────────────────
Raw → Hemoglobin conversion     Statistics & visualization
Single fNIRS struct output      Cell array of structs input
Signal processing algorithms    LME modeling, FDR correction
```

### Main Components
| File | Purpose |
|------|---------|
| `exploreFNIRS.m` | Main GUI application |
| `exploreFNIRS_App.mlapp` | Compiled App Designer version |
| `browseEx.m` | File browser function |
| `loadEx.m` | Load data for exploration |
| `saveEx.m` | Save explorer results |
| `processMethods.m` | Process method configuration |
| `plotExTimeline.m` | Plot experimental timeline |

### Subpackages
| Subpackage | Purpose | Scriptable |
|------------|---------|------------|
| `+core/` | Experiment container, headless plotting (temporal, bar, topo, heatmap, composite, LME, scatter) | **Yes** |
| `+connectivity/` | Connectivity analysis (matrix, dynamic FC, brain states, intra/inter-ROI) | **Yes** |
| `+coupling/` | Coupling functions (Pearson, Spearman, xcorr, coherence, wcoherence, Granger, transfer entropy, HB-ICA) | **Yes** |
| `+hyperscanning/` | Multi-brain hyperscanning analysis, HB-ICA, inter-brain visualization | **Yes** |
| `+dataset/` | Data organization (buildSegmentInfoTable, standardizeROIs) | **Yes** |
| `+graph/` | Graph-theory metrics on connectivity matrices (degree, clustering, efficiency, modularity, small-world, hubs) | **Yes** |
| `+report/` | Publication report generation (HTML pipeline, APA tables, demographics, figure export, LaTeX) | **Yes** |
| `+plot/` | Plotting functions (temporal, barchart, scatter) | GUI-only* |
| `+export/` | Data export (mergeGbyTablesLong, mergeGbyTablesWide, connectivityToTable) | **Yes** |
| `+fx/` | Statistical functions (performFDR, performFDR_twostep, autoContrast) | **Yes** |
| `+helper/` | Utilities (getColormap, listColormaps) | **Yes** |

*Legacy plotting functions in `+plot/` require GUI handles. Use `+core/plotTemporal` and `+core/plotBar` for headless plotting.

### +exploreFNIRS/+core — Scriptable Experiment API
| Function | Purpose |
|----------|---------|
| `Experiment.m` | Main experiment container class (select, groupby, aggregate, connectivity, hyperscanning, hbica, intraROI, interROI, plot, export) |
| `GLMExperiment.m` | GLM wrapper extending Experiment — processing, design matrix, first-level fitting, beta packaging, `betaSeriesConnectivity()`, `ppi()`; both support `'Align'` for unbalanced channels |
| `plotTemporal.m` | Headless temporal plots with ROI support |
| `plotBar.m` | Headless bar charts with ROI support |
| `plotTopo.m` | Headless topographic maps (single/pergroup layout, time snapshot or window) |
| `plotHeatmap.m` | Channel × time heatmap (sortable, diverging colormap, ROI support) |
| `plotComposite.m` | Multi-panel publication figures (tiledlayout, auto panel labels) |
| `plotLME.m` | LME analysis with bar charts, ANOVA tables, and topographic F-maps (fNIRS, ROI, Aux) |
| `plotScatter.m` | Scatter correlation with regression, topographic maps, and ROI support |
| `ColorScheme.m` | Hierarchical color rules for multi-factor plots (set, setBase, setPriority, resolve, preview) |
| `getGroupColors.m` | Consistent group coloring across plots |

### +pf2_base/+plot — Plot Style Infrastructure
| Function | Purpose |
|----------|---------|
| `PlotStyle.m` | Value class with style defaults and MATLAB dark mode support. Static factories: `getDefault()`, `getPublication()`, `getPresentation()`. Theme detection via `isDarkMode()` |
| `RenderStyle.m` | 3D cortical render presets (`get('showcase')` / `get('publication')`): lighting/AO/matcap/view/supersample knobs consumed by `interpolateValues3D` |
| `brainColormap.m` | Cortical-overlay colormaps: MRIcroGL/Surfice LUTs (`actc`,`warm`,`cool`,`hot`,`blue2red`,`bone`,`surface`) + CVD-safe (`rdbu`,`viridis`,`cividis`); returns `[N x 3]` RGB and an alpha ramp |
| `matcapTexture.m` | Procedurally generate a lit-sphere matcap image (clay/porcelain/matte/glossy/pewter/jade) — no licensed assets |
| `matcapShade.m` | Sample a matcap by view-space vertex normals -> per-vertex RGB (view-dependent) |
| `vertexNormals.m` | Smooth area-weighted outward per-vertex normals for a triangle mesh |
| `meshCurvature.m` | Per-vertex curvature -> ambient-occlusion shading weight (darkens sulci) |
| `createFigure.m` | Standardized figure creation (auto Visible=off when SavePath set) |
| `handleSave.m` | Standardized save-if-requested (delegates to saveFigure) |
| `saveFigure.m` | Core save logic (PNG, PDF, SVG, FIG, etc.). Forces light mode for exported figures |

**PlotStyle Theme Properties:**

All plot functions use `PlotStyle` for theme-aware colors. When MATLAB is in dark mode, colors adapt automatically:

| Property | Light Mode | Dark Mode |
|----------|------------|-----------|
| `FigureColor` | `[1 1 1]` | MATLAB's `defaultFigureColor` |
| `ForegroundColor` | `[0 0 0]` | `[1 1 1]` |
| `BackgroundColor` | `[1 1 1]` | MATLAB's `defaultAxesColor` |
| `ZeroLineColor` | `[0 0 0]` | `[0.8 0.8 0.8]` |
| `DimColor` | `[0.4 0.4 0.4]` | `[0.65 0.65 0.65]` |
| `GridColor` | `[0.5 0.5 0.5]` | `[0.55 0.55 0.55]` |
| `LegendBgColor` | `[1 1 1]` | MATLAB's `defaultAxesColor` |
| `LegendTextColor` | `[0 0 0]` | `[1 1 1]` |
| `LegendEdgeColor` | `[0.5 0.5 0.5]` | `[0.5 0.5 0.5]` |

**Theme Control:**
```matlab
% Check if dark mode is active
tf = pf2_base.plot.PlotStyle.isDarkMode();

% Force light mode regardless of MATLAB theme (persistent preference)
pf2_base.plot.PlotStyle.setForceLightMode(true);

% Re-enable theme detection
pf2_base.plot.PlotStyle.setForceLightMode(false);
```

Semantic colors (biomarker red/blue, significance markers, group colors) are unaffected by theme. Saved figures always export with a white background and dark text.

### +exploreFNIRS/+stats — Statistical Analysis
| Function | Purpose |
|----------|---------|
| `fitLME.m` | Standalone channel-wise LME fitting (fNIRS, ROI, Aux; no visualization) |
| `fitInfoLME.m` | Fit an LME for an info/behavioral variable |
| `autoModelLME.m` | Automatic per-channel LME model selection via forward stepwise information criteria |
| `runContrasts.m` | Post-hoc contrasts with FDR correction across channels |
| `buildContrasts.m` | Generate standard contrast matrices from a fitted LME model |
| `summarize.m` | Publication-ready summary tables (ANOVA, contrasts, coefficients, fit, APA) |
| `permTest.m` | Non-parametric permutation test for paired comparisons |
| `clusterPermutation.m` | Cluster-based permutation testing across channels |
| `findClusters.m` | Find spatially contiguous clusters in a thresholded stat map |
| `effectSize.m` | Effect size with bootstrap confidence intervals |
| `behavioralTable.m` | Descriptive stats, comparisons, or correlations for behavioral data |

### +exploreFNIRS/+connectivity — Connectivity Analysis
| Function | Purpose |
|----------|---------|
| `computeMatrix.m` | Compute channel-pair connectivity matrices (symmetric or directed) |
| `alignMatrices.m` | Align connectivity/hyperscanning results from subjects with different channels into a common grid. Modes: `'union'`, `'intersection'`, numeric threshold |
| `computeDynamicFC.m` | Sliding-window dynamic functional connectivity → 3D tensor |
| `detectStates.m` | K-means clustering of dynamic FC matrices into brain states |
| `computeIntraROI.m` | Within-ROI pairwise coupling analysis |
| `computeInterROI.m` | Between-ROI coupling (wrapper with UseROI=true) |
| `computeBetaSeries.m` | Beta-series correlation connectivity (LSA or LSS estimation, condition filtering) |
| `computePPI.m` | Psychophysiological interaction analysis (gPPI, contrast specification, Wiener deconvolution) |
| `plotMatrix.m` | Visualize connectivity matrices |
| `plotBlockComparison.m` | Compare connectivity across blocks |
| `plotDirected.m` | Directed connectivity visualization (matrix heatmap or circular arc diagram) |
| `plotDynamicFC.m` | Dynamic FC time series with brain state visualization |
| `plotChord.m` | Chord diagram / connectogram for ROI/channel connectivity (per-node coloring + colorbar, region anchors, uniform edges) |
| `plotIntraROI.m` | Intra-ROI bar/radar visualization |
| `plotInterROI.m` | Inter-ROI chord/matrix visualization |

> Brain-anchored network rendering (edges drawn at real channel/ROI positions on the cortex/probe) is provided by `pf2.probe.plot.connectome`.

### +exploreFNIRS/+coupling — Coupling Functions
| Function | Purpose |
|----------|---------|
| `pearson.m` | Pearson correlation |
| `spearman.m` | Spearman rank correlation |
| `xcorr.m` | Cross-correlation |
| `coherence.m` | Magnitude-squared coherence |
| `wcoherence.m` | Wavelet coherence |
| `granger.m` | Granger causality (directed, AR model F-test) |
| `transferEntropy.m` | Transfer entropy (directed, histogram-based with surrogate p-values) |
| `hbica.m` | HB-ICA pairwise coupling adapter (product-of-normalized-weights for 2-channel case) |
| `partialCorr.m` | Partial correlation (controls for confounds; precision-matrix batch in computeMatrix) |
| `mutualInfo.m` | Mutual information (histogram-based, normalized, surrogate p-values) |
| `partialCoherence.m` | Partial magnitude-squared coherence controlling for one or more shared signals (e.g. shared physiology) |
| `plotWcoherence.m` | Wavelet coherence time-frequency heatmap |
| `plotWindowed.m` | Windowed coupling time series |

### +exploreFNIRS/+hyperscanning — Multi-Brain Analysis
| Function | Purpose |
|----------|---------|
| `pairSubjects.m` | Pair subjects by matching criteria |
| `computeDyad.m` | Compute coupling for dyads (supports all 8 coupling methods) |
| `computeGroup.m` | Group-level statistics with SEM; supports `'Align'` for unbalanced channels |
| `permutationTest.m` | Permutation-based significance testing; supports `'Align'` for unbalanced channels |
| `hbica.m` | HB-ICA decomposition for a dyad (TDSEP ICA + GOF classification, dual regression, UseROI support) |
| `plotGroup.m` | Group bar chart with significance markers |
| `plotHBICA.m` | HB-ICA visualization (GOF bar chart, dual-brain spatial patterns, source time courses) |
| `plotInterBrainTopo.m` | Dual-brain topographic display with coupling lines (synthetic grid) |
| `plotDualBrain.m` | Dual-brain inter-brain synchrony at real 2D probe geometry, cross-brain edges + optional linked wavelet panel |
| `plotDyadMatrix.m` | Dyad-level coupling heatmap (channels × dyads) |
| `plotGroupTemporal.m` | Time-resolved group coupling with SEM error bands |
| `physioConfoundQC.m` | Flag shared-physiology (LFO/VLFO) confound risk for a hyperscanning dyad |

### +exploreFNIRS/+graph — Graph-Theory Metrics
Network metrics computed on a connectivity matrix (from `+connectivity`).
| Function | Purpose |
|----------|---------|
| `threshold.m` | Convert a connectivity matrix to a graph struct for analysis |
| `computeMetrics.m` | Compute the full suite of graph-theory metrics from a connectivity matrix |
| `degree.m` | Node degree and strength |
| `clusteringCoefficient.m` | Weighted clustering coefficient and transitivity |
| `charPathLength.m` | Characteristic path length and distance matrix |
| `efficiency.m` | Global and local network efficiency |
| `betweenness.m` | Betweenness centrality per node |
| `modularity.m` | Community detection via the Louvain algorithm |
| `smallWorld.m` | Small-world indices vs random null networks |
| `detectHubs.m` | Identify hub nodes via composite z-score |
| `metricsToTable.m` | Export graph metrics to a long-format table |
| `plotMetrics.m` | Grouped bar chart comparing node-level metrics |
| `plotNetwork.m` | Node-link diagram with metric-based sizing and community coloring |

### +exploreFNIRS/+report — Report Generation
Publication-ready tables and HTML report assembly.
| Function | Purpose |
|----------|---------|
| `Pipeline.m` | Orchestrator for reproducible report generation |
| `generate.m` | Create an HTML report from Pipeline results |
| `anovaTable.m` | Formatted ANOVA table (df, F, p, partial η²) |
| `contrastTable.m` | Formatted contrast table with significance stars and CI |
| `correlationTable.m` | Formatted correlation matrix with significance stars |
| `demographicsTable.m` | Publication "Table 1" demographics summary |
| `connectivitySummary.m` | Summary statistics from connectivity analysis |
| `formatStats.m` | APA-style statistical result string from LME/GLM output |
| `formatPValue.m` | APA-style p-value formatting |
| `toLatex.m` | Convert a MATLAB table to a LaTeX tabular string |
| `saveFigureSet.m` | Batch-save a struct of figure handles with consistent naming |

### Statistical Functions (+fx/)

| Function | Purpose |
|----------|---------|
| `performFDR.m` | Benjamini-Hochberg FDR correction for multiple comparisons |
| `performFDR_twostep.m` | Two-step adaptive FDR (Benjamini-Krieger-Yekutieli 2006) |
| `autoContrast.m` | Automatic contrast generation for LME models |

**FDR Correction Methods:**
- **Standard FDR** (`performFDR`): Classic Benjamini-Hochberg (1995) procedure. Controls expected proportion of false discoveries. Returns q-values and the critical index k.
- **Two-step Adaptive FDR** (`performFDR_twostep`): More powerful when many null hypotheses are true. Estimates π₀ (proportion of true nulls) in first pass, then adjusts threshold in second pass.

### Plotting Functions (+plot/)

| Function | Purpose |
|----------|---------|
| `temporal.m` | Time-series plots with shaded error regions |
| `barchart.m` | Grouped bar charts with error bars, violin plots, LME analysis |
| `scatter.m` | Correlation scatter plots with regression lines, topographic maps |

**Bar Chart Features:**
- Error bar options: SEM, SD, MaxMin, IQR, IQR-NoOutliers, Violin
- Automatic LME model fitting with Satterthwaite degrees of freedom
- Topographic display of ANOVA F-statistics across probe
- Individual data point overlay
- Console output of fitted model statistics

**Scatter Plot Features:**
- Pearson and Spearman correlation options
- Regression lines with confidence/prediction intervals (SEM, SD, 95%CI, 95%PI)
- Topographic correlation maps with FDR correction
- Hierarchical averaging for within-subject designs

### Export Functions (+export/)

| Function | Purpose |
|----------|---------|
| `mergeGbyTablesLong.m` | Export to long format (one row per observation/timepoint) |
| `mergeGbyTablesWide.m` | Export to wide format (one row per subject) |

**Long Format** - Preferred for:
- R mixed-effects models (lme4, lmerTest)
- tidyverse/ggplot2 visualization
- Repeated measures with multiple timepoints

**Wide Format** - Preferred for:
- SPSS repeated measures ANOVA
- Excel pivot tables
- Simple between-subjects comparisons

### Global State Structure

exploreFNIRS uses the `ExFNIRS` global variable to maintain GUI state:

```matlab
ExFNIRS =
    data: [cell array]           % Loaded fNIRS data structs
    settings: [struct]           % Current GUI settings
    curMethodName: [string]      % Active processing method
    statusGroupByStr: [string]   % Current grouping description
    dataHierarchy: [cell]        % Within-subject hierarchy variables
    currentROI: [table]          % Active ROI definitions
    figHandles: [struct]         % Figure handle references
    curChartModels: [cell]       % Fitted LME models (populated by barchart)
    curChartModelsANOVA: [cell]  % ANOVA tables for each model
    curChartModelsCoefficents_pval: [table]  % p-values by channel/biomarker
    curChartModelsANOVACoefficents_Fstat: [table]  % F-statistics
```

### Grouped-By Data Structure

The `exGby` structure array (passed to plotting functions) contains grouped data:

```matlab
exGby(i) =
    gbyTables: [table]           % Subject-level metadata and variables
    gbyGrandBar: [struct]        % Grand average with summary statistics
        .time: [vector]          % Time points
        .segmentTimes: [Tx3]     % [start, middle, end] for each segment
        .HbO/.HbR/etc: [struct]  % Biomarker data
            .data: [TxCxN]       % Raw values (time x channel x observation)
            .Mean: [TxC]         % Mean across observations
            .SEM: [TxC]          % Standard error
            .SD: [TxC]           % Standard deviation
            .N: [TxC]            % Sample size
        .ROI: [struct]           % ROI-averaged data (if computed)
        .Aux: [struct]           % Auxiliary data (if present)
        .info: [struct]          % Hierarchy and observation metadata
    gbyFNIRS_blk: [cell]         % Block-level fNIRS structs
```

---

## Signal Processing Functions (`/functions/`)

### Intensity-to-OD Conversion
- `pf2_Intensity2OD.m` - Convert raw intensity to optical density (log10)

### Filtering
| Function | Purpose |
|----------|---------|
| `pf2_lpf.m` | Low-pass Butterworth filter |
| `pf2_hpf.m` | High-pass Butterworth filter |
| `pf2_bpf_butter.m` | Band-pass Butterworth filter |
| `pf2_bpf_fir.m` | Band-pass FIR filter |
| `pf2_bpf_iir.m` | Butterworth IIR bandpass/lowpass/highpass filter with NaN handling |
| `pf2_bandstop.m` | Band-stop filter |
| `detrend_nan.m` | Detrending with NaN handling |
| `detrend_3rd_order.m` | Third-order polynomial detrending |

### Motion Artifact Correction
| Function | Purpose |
|----------|---------|
| `pf2_SMAR.m` | Sliding Motion Artifact Rejection |
| `pf2_SMAR2.m` | SMAR v2.0 (improved algorithm) |
| `pf2_SMAR2_mask.m` | SMAR2 with masking |
| `pf2_fnirs_MARA.m` | Movement Artifact Reduction Algorithm |
| `pf2_MotionCorrectTDDR.m` | Temporal Derivative Distribution Repair |
| `pf2_MotionCorrectSpline.m` | Spline interpolation motion correction |
| `pf2_MotionCorrectSplineSG.m` | Spline interpolation with Savitzky-Golay smoothing |
| `pf2_MotionCorrectWavelet.m` | Wavelet-based motion correction |

### Channel Processing
| Function | Purpose |
|----------|---------|
| `pf2_CAR.m` | Common Average Reference |
| `pf2_GSR.m` | Global signal removal via PCA spatial filter (tunable CAR generalization) |
| `pf2_subtractAmbient.m` | Subtract dark/ambient channel |
| `applyTimeChMask.m` | Apply channel mask across time |
| `pf2_ambient_ICA_clean.m` | ICA-based ambient channel removal |
| `icaClean.m` | Independent component analysis cleaning |
| `waveClean.m` | Wavelet-based cleaning |

### Quality Control
| Function | Purpose |
|----------|---------|
| `pf2_thresholdValues.m` | Threshold outlier values |
| `pf2_thresholdValues_mask.m` | Threshold with masking |
| `pf2_TakizawaRejection.m` | Takizawa artifact criterion (on processed Hb data) |
| `pf2_SCIRejection.m` | SCI-based channel rejection (on raw intensity data) |
| `pf2_SSR.m` | Short separation regression processing function |

### ROI Construction
| Function | Purpose |
|----------|---------|
| `pf2_build_nanmean_ROI.m` | ROI from mean of channels |
| `pf2_build_pca_ROI.m` | ROI from PCA components |

---

## Supported Devices (`/devices/`)

### fNIR Devices/Biopac
- `fNIR_Devices_fNIR1000.cfg` - fNIR 1000
- `fNIR_Devices_fNIR1000_LD.cfg` - fNIR 1000 (long-distance optode spacing)
- `fNIR_Devices_fNIR1000_Linear.cfg` - fNIR 1000 linear array
- `fNIR_Devices_fNIR1000_Split_2x2ch.cfg` - fNIR 1000 split configuration
- `fNIR_Devices_fNIR1200_16ch.cfg` - fNIR 1200 (16 channels)
- `fNIR_Devices_fNIR2000.cfg` - fNIR 2000
- `fNIR_Devices_fNIR2000_18ch.cfg` - fNIR 2000 (18 channels)
- `fNIR_Devices_fNIR3000.cfg` - fNIR 3000

### Hitachi ETG-4000
- `Hitachi_ETG4000_3x5.cfg` - 3x5 probe configuration
- `Hitachi_ETG4000_3x11.cfg` - 3x11 probe configuration
- `fNIR_Hitachi_3x5_merged.cfg` - Merged Hitachi 3x5

### NIRx Systems
- `NIRX_Sport_8x8_frontal.cfg` - 8x8 frontal configuration
- `NIRX_Sport_16x16_parietal.cfg` - 16x16 parietal configuration
- `NIRX_Sport_16x16_lw.cfg` - 16x16 lightweight version

### Artinis OxySoft
- No `.cfg` file: device geometry is read per-recording from the `.oxy3`
  header (sampling rate, lasers/wavelengths, detector and ADC counts).
- Optode **positions** are not stored in the `.oxy3` (OxySoft references an
  external optode template by ID). `importOxy3` generates a placeholder
  layout by default; pass `'OptodeTemplate', 'optodetemplates.xml'` to recover
  real 2D optode coordinates for the recording's `OptodeTemplateID`.
- Supports both newer (`<SampleRate>`) and older (`<SampleTime>`-only) OxySoft
  schemas, dual-wavelength (≈760/850 nm) systems, and OxyMon/OctaMon-class
  montages where disconnected source–detector combinations are imported and
  then flagged by the saturation quality check.

### Other
- `Rogue_BrainSight.cfg` - Rogue/BrainSight system
- `DrP_probe.cfg` - Custom DrP probe

### Device Configuration File Structure
```ini
[Info]
CfgName = 'Device_Name'
Name = 'Display Name'
Manufacturer = 'Manufacturer'
DefaultSamplingRate = 10  % Hz
NumberChannels = 18
TimeIsSampleCount = 0

[Probe1]
ChannelNumbers = [...]    % Channel indices
Wavelength = [...]        % Wavelengths in nm
DetPosX, DetPosY, DetPosZ % Detector 2D positions
SrcPosX, SrcPosY, SrcPosZ % Source 2D positions
DetPos3DX, etc.           % 3D detector positions (Talairach/MNI)
SrcPos3DX, etc.           % 3D source positions
sI = [...]                % Source indices per channel
dI = [...]                % Detector indices per channel
```

---

## Global Variables

| Variable | Description |
|----------|-------------|
| `PF2` | Processing settings and loaded methods |
| `setF` | Device/file information |
| `outputData` | Processing stage control |

---

## File Type Associations

| Extension | Format | Import Function |
|-----------|--------|-----------------|
| `.nir` | fNIR Devices/Biopac | `pf2.import.importNIR` |
| `.hdr`/`.wl1`/`.wl2` | NIRx | `pf2.import.importNIRX` |
| `.csv` | Hitachi ETG-4000 | `pf2.import.importHitachiMES` |
| `.snirf` | SNIRF standard | `pf2.import.importSNIRF` |
