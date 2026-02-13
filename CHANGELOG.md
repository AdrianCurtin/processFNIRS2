# Changelog

## Unreleased

### New Features

**HB-ICA (Hyper-Brain Independent Component Analysis):**
- `exploreFNIRS.hyperscanning.hbica()` — component-based inter-brain network detection for hyperscanning data using TDSEP ICA and Goodness-of-Fit classification (Luo et al. 2024)
  - Concatenates dual-subject channel data, decomposes via TDSEP, classifies components as inter-brain or intra-brain using GOF index
  - Dual regression provides subject-specific sources and spatial maps
  - Supports all biomarkers, time windowing, channel selection, adjustable GOF threshold
- `pf2_base.signal.tdsep()` — Temporal Decorrelation Source Separation (Ziehe & Muller 1998)
  - PCA whitening, time-lagged covariance matrices, Jacobi joint diagonalization
  - Configurable lags, variance retention threshold, number of components
- `exploreFNIRS.coupling.hbica()` — pairwise coupling adapter for HB-ICA (API compatibility with dispatch system)
- `exploreFNIRS.hyperscanning.plotHBICA()` — visualization: GOF bar chart, dual-brain spatial patterns, source time courses
- `Experiment.hbica()` — group-level HB-ICA with automatic subject pairing, block-wise analysis, and summary statistics
- HB-ICA registered in coupling dispatch for `computeMatrix` and `computeDyad`
- `examples/scripts/example_hbica.m` — HB-ICA tutorial: standalone dyad, group-level, block-wise, and pairwise comparison

**Graph Theory Metrics (`+exploreFNIRS/+graph/`):**
- `threshold()` — connectivity matrix to graph struct (absolute, proportional, or significance-based thresholding)
- `degree()`, `charPathLength()`, `clusteringCoefficient()`, `betweenness()`, `efficiency()` — standard graph-theoretic metrics
- `modularity()` — Louvain community detection (Blondel et al. 2008), participation coefficient
- `smallWorld()` — sigma/omega small-world indices with Maslov-Sneppen null model rewiring
- `detectHubs()` — composite z-score hub classification (provincial vs connector hubs)
- `computeMetrics()` — convenience dispatcher for computing multiple metrics at once
- `plotNetwork()` — graph visualization with force-directed, circle, or probe-based layouts and community coloring
- `plotMetrics()` — grouped bar charts for comparing graph metrics across conditions
- `metricsToTable()` — long-format table export with optional CSV save
- `Experiment.graphMetrics()` — wrapper delegating to `connectivity()` + `computeMetrics()`

**Cluster-Based Permutation Testing:**
- `exploreFNIRS.stats.clusterPermutation()` — non-parametric cluster-based testing for LME results (Maris & Oostenveld 2007)
- `exploreFNIRS.stats.findClusters()` — BFS connected-component cluster identification on thresholded stat maps
- `pf2.probe.computeAdjacency()` — spatial adjacency matrix from MNI coordinates for cluster permutation
- `Experiment.statsClusterPermutation()` — wrapper for cluster-based permutation testing

**Channel Quality Check GUI:**
- `pf2.qc.ChannelCheck` — App Designer GUI for interactive channel quality assessment
  - Spatial probe mini-plot grid, detail waveform + PSD views, undo/redo, bulk operations
  - Auto-runs QC pipeline on open (saturation, SCI, cardiac, CoV, Takizawa)
  - Configurable QC thresholds with persistent preferences
  - Two modes: single dataset or cell array with prev/next navigation
  - Dark mode support; opt-in via `'ChannelCheckVersion', 2` on import functions

**Internal Refactoring:**
- `pf2_base.resolveMethodsLib()` / `pf2_base.storeMethodsLib()` — method library access abstracted from global PF2
- `global PF2` scoping reduced in processing stages and plot functions — explicit parameters replace global reads

**Pipeline Class Hierarchy:**
- `pf2_base.PipelineFunction` — immutable value class encapsulating a single processing function with precomputed argument mappings and zero-overhead `execute()` method
  - 12 special argument types (x, fs, fTime, fchMask, etc.) resolved at construction as uint8 enums
  - `fromStruct(s)` / `toStruct()` for legacy method struct round-tripping
  - `fromString(callStr)` for parsing MATLAB call syntax
  - `detect(funcName)` for auto-discovering function signatures from source
  - `register(pf)` for persisting to config file
  - `setParam()`, `setParams()`, `addArg()`, `removeArg()`, `addOutput()`, `removeOutput()` for mutation (returns new copy)
- `pf2_base.Pipeline` — ordered chain of PipelineFunction steps (value class)
  - `add()`, `insert()`, `remove()`, `swapStep()`, `setParam()`, `setParams()` for chain manipulation
  - `toMethod()` converts to legacy method struct for backward compatibility
  - `fromMethod(name, stage)` builds Pipeline from existing named method
  - `params()` returns aggregate table of all tunable parameters
- `pf2_base.RawPipeline` — Stage 1 specialization with `hasIntensity2OD()` helper
- `pf2_base.OxyPipeline` — Stage 3 specialization with `hasROI()`, `swapROI()`, `removeROI()` helpers
- `processStageRaw2OD` and `processStageFilterHb` now support both PipelineFunction objects (precomputed context dispatch) and legacy structs (backward-compatible path)
- `pf2_unpackMethod` now converts legacy structs to PipelineFunction via `fromStruct()`
- Tutorials:
  - `examples/scripts/example_pipeline_basics.m` — Pipeline API tutorial
  - `examples/scripts/example_pipeline_custom_function.m` — Custom function tutorial

**GLM Improvements:**
- `pf2_base.fnirs.diagnoseGLM()` — comprehensive GLM diagnostic report (collinearity, VIF, partial R², residual ACF, task-data correlation, predicted amplitude, automatic flagging)
- `fitGLM` AR-IRLS method now returns prewhitened design matrix (`Xw`) and prewhitened residuals (`residuals_w`); contrasts use prewhitened quantities for correct standard errors

**New Processing Functions:**
- `pf2_MotionCorrectSplineSG` — spline interpolation with Savitzky-Golay smoothing motion correction

**SNIRF Import Improvements:**
- Source and detector labels from SNIRF probe info now stored during import
- Per-optode S_D channel labels (e.g., "S1_D11") built with fallback to numeric format

**Interactive Setup Wizard:**
- `pf2_scripts.quickSetup` — interactive wizard for first-time users

### Config Changes
- `pf2_functions_default.cfg` reformatted and alphabetized
- Added `requiresOD` field to motion correction functions (TDDR, Wavelet, Spline, SplineSG, SMAR, SMAR2, MARA, kbWF, sSMART) — validated at runtime in processStageRaw2OD
- New function entries: `pf2_MotionCorrectSpline`, `pf2_MotionCorrectSplineSG`

### GUI Changes
- Method configuration GUI now converts between PipelineFunction and legacy struct for editing
- `requiresOD` added to reserved args in GUI

### New Tests
- **PipelineFunctionTest.m** — PipelineFunction construction, precomputed mapping, execute, round-trip
- **PipelineTest.m** — Pipeline hierarchy: add, insert, remove, setParam, toMethod, fromMethod
- **GLMDiagnosticsTest.m** — diagnoseGLM diagnostic output validation
- **HBICATest.m** — HB-ICA decomposition, inter/intra-brain detection, coupling adapter, ROI mode
- **TDSEPTest.m** — TDSEP mixing recovery, dimensionality reduction, reconstruction
- **GraphMetricsTest.m** — Graph theory metrics on known topologies (K5, star, ring, block-diagonal)
- **ClusterPermutationTest.m** — Adjacency computation, cluster finding, null distribution

### GUI Refactoring
- `updateCurrentDevice` consolidated: GUI and headless paths now delegate to shared `pf2_base.gui.updateCurrentDevice`
- `updatePlots` extracted into per-stage helpers: `pf2_base.gui.plotStageRaw` (stages 1–2) and `pf2_base.gui.plotStageHb` (stages 3–4)
- `plotOxyArranged` / `plotRawArranged` consolidated into single `pf2_base.gui.plotArranged` helper
- `processStageOD2Hb` GUI wrapper now delegates to shared function with `BaselineSamples` option instead of calling `bvoxy` directly
- `processFNIR_GUI` inlined raw and filter-Hb wrappers — processing calls now use explicit parameters instead of reading globals inside wrapper functions
- `GUIContext` sync wired up via `syncContextFromGUI()` at the start of each processing cycle
- GUI processing calls now pass `showGUIerrors=true` so pipeline errors show as dialog boxes instead of crashing

### Bug Fixes
- Fixed AR-IRLS contrast p-values being anti-conservative — contrasts now use prewhitened X and residuals instead of original-space quantities
- Fixed `pf2_unpackMethod` struct array output duplication — when INI-stored method definitions used `struct()` with cell array values, MATLAB creates a struct array; the old code iterated all elements to build the `output` field, producing e.g. `{'x','x','x','x','x'}` instead of `{'x'}`, which caused "Too many output arguments" errors when executing pipeline functions
- Fixed missing `data.markers` crash in GUI filter-Hb processing — `processStageFilterHb` accesses `data.markers` for the pipeline context, but the GUI's stage{4} data lacked `.markers`, `.Aux`, and `.time` fields
- Fixed `plotArranged` `LightColorAuto` validation error — parameter used `@islogical` validator but the GUI stores the value as numeric 0/1
- Fixed HB-ICA GOF computation — combined GOF was always zero for two-subject case due to symmetric z-score cancellation; now uses absolute loading ratios
- Fixed `clusterPermutation` permutation loop fitting the same formula (same dependent variable) for all channels instead of rewriting per channel
- Fixed `clusterPermutation` RNG seeded inside the inner channel loop instead of per permutation
- Fixed `plotHBICA` subplot layout — `subplot(nRows,1,1)` conflicted with `subplot(nRows,3,...)` destroying the GOF panel
- Fixed `ChannelCheck` QC tooltip referencing non-existent `pctSaturated` field instead of `totalPct`
- Fixed `ChannelCheck` ambient/marker/reference lines accumulating on mini-plots during repeated redraws

---

## v1.0 (2026-02-11)
Scriptable Group Analysis, Connectivity, Hyperscanning, Statistics & Processing Optimizations

### API Changes

**Experiment method renames (breaking):**
- `plotInfoVar()` renamed to `plotInfoBar()` (clarifies it produces a bar chart)
- `plotScatter()` renamed to `plotInfoScatter()` (clarifies it plots info-vs-info)
- `plotScatterFNIRS()` renamed to `plotScatter()` (fNIRS is assumed in this toolbox)
- Underlying standalone function renamed: `+exploreFNIRS/+core/plotScatterFNIRS.m` -> `plotScatter.m`

### New Features

**GLM Analysis Pipeline:**
- **GLMExperiment class** (`+exploreFNIRS/+core/GLMExperiment.m`) — scriptable wrapper that extends Experiment for GLM-based analysis
  - Encapsulates processing, design matrix construction, first-level fitting, and beta packaging into `fit()`
  - Auto-invalidation: changing `glm.*` or `settings.rawMethod`/`oxyMethod` triggers refit on next `aggregate()`
  - Per-subject result inspection via `subjectResults` and `plotDesignMatrix()`
  - Block-level behavioral data (reactionTime, accuracy, etc.) aggregated onto beta segments
  - Auxiliary data GLM: fits GLM on Aux signals (e.g. heartRate) at their native sampling rate
  - `betaTable()` for direct export to R/Python (bypasses Experiment pipeline)
  - All inherited Experiment methods (plotBar, plotLME, plotTopoLME, connectivity, ROI, export) work on beta data
- `pf2.data.blocksToEvents()` — convert defineBlocks output to GLM event structs for buildDesignMatrix
- `pf2.data.betasToSegments()` — package first-level GLM betas into Experiment-compatible pseudo-segments for group analysis
- `buildDesignMatrix` amplitude support — `events.amplitude` field scales boxcar/impulse regressors for parametric modulation designs
- Tutorials:
  - `examples/scripts/example_glm_analysis.m` — GLMExperiment workflow from continuous recordings through group statistics, topographic LME, and export
  - `examples/scripts/example_glm_advanced.m` — manual step-by-step GLM pipeline with design matrix construction, per-subject fitting, first-level contrasts, and beta packaging

**exploreFNIRS Scriptable API:**
- **Experiment container class** (`+exploreFNIRS/+core/Experiment.m`) for fully scriptable group analysis without the GUI
  - `select()`, `groupby()`, `aggregate()` methods for data organization
  - Copy constructor: `ex2 = Experiment(ex)` copies data, settings, and hierarchy for branching analyses
  - `connectivity()` and `hyperscanning()` methods with block-wise support
  - `plotTemporal()`, `plotBar()`, `plotLME()`, `plotTopoLME()` wrappers
  - `plotExperimentTimeline()` — visualize time settings (baseline, task block, temporal/bar resample) as a diagram before aggregating
  - `plotAuxLME()`, `plotInfoLME()` for auxiliary and info variable LME visualization
  - `plotAuxScatter()` for info vs auxiliary signal scatter correlation
  - `statsFitLME()`, `statsRunContrasts()`, `statsSummarize()`, `statsROILME()` for statistics
  - `statsInfoLME()` for LME analysis on info/behavioral variables (no aggregate needed)
  - `statsAuxLME()` for LME analysis on auxiliary signal channels
  - `exportLong()`, `exportWide()` for data export (with `IncludeROI` option)
- **Headless plotting** (`+exploreFNIRS/+core/plotTemporal.m`, `plotBar.m`, `plotScatter.m`)
  - Publication-ready temporal, bar chart, and scatter plots without GUI
  - Channels and biomarkers are never averaged — each gets its own subplot
  - Default `Channels = []` plots all channels as separate subplots
  - Automatic subplot layout adapts to channel count, biomarker count, and `PlotBy` factor
  - When all three dimensions present (channels x biomarkers x PlotBy), separate figures per biomarker with auto-named save paths
  - `PlotBy` splits subplots by a groupby variable; `Legend` controls placement (`'last'`/`'first'`/`'all'`/`'none'`)
  - `ShowN` parameter to hide subject count (n=X) from bar labels and legend entries
  - `YLim`/`XLim` with shared axes across subplots; per-biomarker-row linking when HbO and HbR have different Y scales
  - Legend styled with white background and black text for consistent appearance across themes
  - plotBar uses column-preferred layout (bar subplots are taller than wide) and delegates to `barweb` for both flat and clustered bar modes
  - plotScatter stacks per-group correlation annotations vertically to avoid overlap
  - ROI support via `'ROIs'` parameter (indices, names, or `'all'`)
  - Configurable error bands (SEM/SD) and save options
- **Auxiliary data scatter** (`plotAuxScatter`) — scatter correlation of info variables vs auxiliary signal data with per-channel subplots and regression lines
- **Time bin expansion** — when `barBinSize` produces multiple time bins, each bin becomes a separate group in bar/scatter plots (e.g. "Young [0s]", "Young [10s]")
  - `expandGroupsByTime` utility function slices gbyGrandBarFlat and creates single-bin gbyGrand per group
  - `PlotProxy` auto-adds Time to X (bar) or Color (scatter) dimensions
  - `plotBar`, `plotAuxBar`, `plotScatter`, `plotAuxScatter` all support time expansion
  - `fitLME` auto-includes Time as categorical fixed effect when multiple bins exist
  - `taskEnd` parameter on `aggregate()` controls task window endpoint

**Connectivity Analysis:**
- **Connectivity module** (`+exploreFNIRS/+connectivity/`) with `computeMatrix`, `plotMatrix`, `plotBlockComparison`
- **Coupling functions** (`+exploreFNIRS/+coupling/`) — Pearson, Spearman, cross-correlation, coherence, wavelet coherence
- **Directed coupling** — Granger causality (AR model F-test), transfer entropy (histogram-based with surrogate p-values)
- **Dynamic FC** — `computeDynamicFC` (sliding-window connectivity), `detectStates` (k-means brain state detection)
- **ROI connectivity** — `computeIntraROI` (within-ROI coupling), `computeInterROI` (between-ROI coupling)
- **GLM-based connectivity:**
  - `computeBetaSeries` — beta-series correlation via LSA (single GLM) or LSS (per-trial GLM), with condition filtering and Pearson/Spearman options
  - `computePPI` — psychophysiological interaction analysis (gPPI) with contrast specification, multi-channel seed averaging, and optional Wiener deconvolution
  - Both produce output compatible with existing `plotMatrix`/`plotChord` visualization
  - GLMExperiment integration: `betaSeriesConnectivity()` and `ppi()` methods aggregate across subjects (Fisher z-transform for beta-series, one-sample t-test for PPI)
- **Visualization** — `plotWcoherence`, `plotWindowed`, `plotDirected` (matrix + circular), `plotDynamicFC` (with brain states), `plotChord` (chord diagram), `plotIntraROI` (bar/radar), `plotInterROI` (chord/matrix)
- Tutorial: `examples/scripts/example_glm_connectivity.m` — beta-series and PPI from single-subject through group analysis with ROIs

**Hyperscanning Analysis:**
- **Hyperscanning module** (`+exploreFNIRS/+hyperscanning/`) with `pairSubjects`, `computeDyad`, `computeGroup`, `permutationTest`, `plotGroup`
- **Advanced visualization** — `plotInterBrainTopo` (dual-brain topographic display), `plotDyadMatrix` (channels x dyads heatmap), `plotGroupTemporal` (time-resolved coupling with error bands)
- Block-wise hyperscanning with struct array results

**Statistical Analysis Module:**
- `exploreFNIRS.stats.fitLME` — Standalone channel-wise LME fitting (statistics only, no visualization)
  - Supports `'DataType','Aux'` with `'AuxField'` for auxiliary signal LME
  - Supports `'DataType','ROI'` for ROI-level LME (iterates ROIs instead of channels)
- `exploreFNIRS.stats.fitInfoLME` — LME fitting for info/behavioral variables (single model, no channel iteration)
- `exploreFNIRS.stats.runContrasts` — Post-hoc contrasts across channels with FDR correction (BH or adaptive two-step)
- `exploreFNIRS.stats.summarize` — Publication-ready summary tables (ANOVA, contrasts, coefficients, fit) with optional APA formatting
- `plotLME` — LME analysis with bar charts, ANOVA tables, contrasts, and topographic F-statistic maps
  - Supports `DataType='Aux'` with `AuxField` for auxiliary signal LME visualization
  - Supports `DataType='ROI'` for ROI-level LME (iterates ROIs instead of channels)
- `plotInfoLME` — LME analysis with bar chart for info/behavioral variables (single model, F-stat per ANOVA term)
  - Convenience wrappers: `ex.plotAuxLME('heartRate')`, `ex.plotInfoLME('reactionTime')`

**plotTopoLME — 3D brain topo of LME ANOVA F-statistics:**
- `exploreFNIRS.core.plotTopoLME` renders significant ANOVA F-statistics onto the 3D brain surface
- One subplot per model term (excluding Intercept); terms with no significant channels are omitted
- Non-significant channels are NaN-masked so they render as brain color (no misleading color)
- Supports `SigType`: `'p'` (uncorrected), `'q'` (FDR), `'q-twostep'` (adaptive FDR)
- Probe geometry sourced from grouped data (no `setF` global dependency)
- `ShowNonSig`, `CameraPosition` options; returns `results.sigMasks` logical matrix

**Brodmann Area Lookup:**
- `pf2.probe.nearestBrodmann()` — find nearest Brodmann areas for each channel in a probe
  - Accepts data struct or device config name string (e.g. `'fNIR_Devices_fNIR1000.cfg'`)
  - Uses volumetric Brodmann atlas (1mm MNI) for accurate spatial lookup
  - `'N'` parameter controls how many BAs per channel (default 3), `'MaxDistance'` filters by mm
  - Returns MATLAB table with Channel, BA, Name, Distance_mm columns
  - Device and atlas data cached with persistent variables for fast repeated calls

**Block Definition & Extraction:**
- `pf2.data.defineBlocks()` — convert markers to block struct array
- `pf2.data.extractBlocks()` — extract fNIRS segments by block definitions
- Positional API: `defineBlocks(data, [49,50], 30)` or name-value pairs

**Metadata Import:**
- `pf2.data.importInfo()` — import subject-level metadata from CSV/Excel into fNIRS `.info` fields
  - Match by single or multiple key columns (e.g. SubjectID, Session)
  - Handles char/string/categorical/numeric type mismatches transparently
  - Works with single struct or cell array of structs
  - `Overwrite` option to protect existing fields
- `pf2.data.importBlockInfo()` — import block-level metadata from CSV/Excel into block struct arrays
  - Positional mode (row order) or key-based matching
  - `MarkerCode` and `Condition` filters to target specific block types
  - Integrates with `defineBlocks` output; non-matching blocks pass through unchanged

**GLM & Short-Channel Regression:**
- `pf2_base.fnirs.buildDesignMatrix()` — construct GLM design matrices from markers
- `pf2_base.fnirs.fitGLM()` — fit general linear model to fNIRS data
- `pf2_base.fnirs.shortChannelRegression()` — regress out short-channel signals
- `functions/pf2_SSR.m` — short separation regression processing function

**Method CRUD Operations:**
- `pf2.methods.raw.create()` / `pf2.methods.oxy.create()` — create new methods programmatically
- `pf2.methods.raw.delete()` / `pf2.methods.oxy.delete()` — delete methods
- `pf2.methods.raw.editFunction()` / `removeFunction()` — modify method function chains
- `pf2.methods.raw.exportMethod()` / `importMethod()` — portable method sharing
- `pf2.methods.validateFunction()` — validate function compatibility

**New Processing Functions:**
- `pf2_bpf_iir.m` — Butterworth IIR bandpass filter (used by 22/34 FRESH teams)
- `pf2_MotionCorrectSpline.m` — Spline interpolation motion correction (Scholkmann 2010, adapted from HOMER3)
- `pf2_SCIRejection.m` — SCI-based channel rejection on raw intensity
- `pf2_base.fnirs.extractShortChannelPCs()` — PCA on short-separation channels for GLM regressors

**Quality Control Module:**
- `pf2.qc.sci()` — Scalp Coupling Index for channel quality assessment (Pollonini 2014)
- `pf2.qc.powerSpectrum()` — Power spectral density with physiological peak detection
- `pf2.qc.plotQuality()` — Unified QC visualization (SCI bar chart or PSD line plots)
- **QC Pipeline** (`pf2.qc.pipeline.*`) — Standalone, orchestrated channel quality assessment independent of the processing pipeline
  - `assess()` — runs configurable checks (saturation, SCI, cardiac peak, CoV, Takizawa) on raw data with lightweight internal processing
  - `apply()` — applies QC report to `fchMask` (AND-only, never promotes rejected channels), stores report for traceability
  - `report()` — prints formatted channel-by-channel summary with per-check values and rejection reasons
  - `plotReport()` — 4-panel visual dashboard (SCI bars, cardiac SNR bars, CoV bars, Takizawa rule heatmap)

**Wavelet Family Selection & Parallel Acceleration:**
- `pf2_base.wavelet.resolveWavelet()` maps user-friendly names (e.g. `'db4'`, `'sym8'`, `'coif3'`) to WaveLab850 QMF filters
- Supports all 7 WaveLab families: Haar, Daubechies, Symmlet, Coiflet, Beylkin, Vaidyanathan, Battle-Lemarie
- `pf2_MotionCorrectWavelet`, `waveClean`, `pf2_kbWF` — new `wavelet` and `accelerate` parameters
- `accelerate` (`'auto'`, `'parfor'`, `'none'`): uses `parfor` when parallel pool is running and nChannels > 8

**Advanced Visualization:**
- `plotTopo` — Group-level 2D topographic maps (single or per-group layout)
- `plotHeatmap` — Channel × time heatmap with sortable channels, diverging colormap, and ROI support
- `plotComposite` — Multi-panel publication figures with tiledlayout and auto panel labels
- `plotScatter` — Scatter correlation of info/behavioral variables vs fNIRS biomarkers with per-channel subplots, ROI support, stacked annotations, and error bands
- `plotAux` — Headless temporal plots for auxiliary signal channels with automatic channel labels from `varNames`
- `plotInfoBar` — Bar charts for info/behavioral variables (no aggregate needed)
- `plotInfoScatter` — Scatter plots of info-vs-info variables with regression lines, error bands (`ErrorBand` parameter for 95% CI), and styled legends

**Plot Style Infrastructure:**
- `pf2_base.plot.PlotStyle` — Centralized style value class with publication/presentation presets
- `pf2_base.plot.createFigure` — Standardized figure creation with auto-Visible=off when SavePath set
- `pf2_base.plot.handleSave` — Standardized save-if-requested logic
- All existing plot functions retrofitted to use centralized style system

**Sample Experiment Data Generator:**
- `pf2.import.sampleData.experiment()` — synthetic multi-subject fNIRS experiment for testing and tutorials
  - 4 subjects (2 Young, 2 Older) with 6 task blocks each (Easy, Hard, Rest)
  - Event markers, auxiliary signals (heart rate, 3-axis accelerometer) with channel labels (`varNames`), and behavioral metadata (reaction time, accuracy)
  - 4 processing stages: `'raw'`, `'blocks'`, `'extracted'`, `'aligned'` (default)
  - Jittered onsets and shuffled block orders for realistic experimental design

**Tutorial Scripts:**
- `example_experiment_cli.m` — comprehensive Experiment class CLI usage covering group analysis, behavioral variables, multi-factor grouping, auxiliary signals, LME, ROI, and export workflows
- `example_import_blocks.m` — end-to-end workflow for importing metadata from CSV, defining blocks from markers, attaching per-trial behavioral data, extracting segments, and feeding into Experiment
- `tutorial_batch_workflow.m` — realistic multi-subject workflow: directory import with `importDirectory`, CSV metadata merge with `importInfo`, batch processing, block extraction, Experiment analysis with LME statistics, and batch SNIRF export back to a directory tree

**Batch Export:**
- `pf2.export.asSNIRF` and `pf2.export.asNIR` now accept cell arrays for batch export to a directory
  - `Dir1`–`Dir4` name-value params map `.info` field values to subdirectories (inverse of `importDirectory`)
  - `Prefix` param builds filenames from `.info` field values
  - `pf2.export.export()` supports batch mode with `'Format'` param for auto-detection
  - `pf2_base.buildExportPaths()` shared helper for path generation

**Other:**
- `pf2_base.normalizeMarkers()` — standardize marker codes across devices
- `pf2_base.applyLightTheme()` — consistent light theme for figures
- `+exploreFNIRS/+export/connectivityToTable.m` — export connectivity results as tables
- `+exploreFNIRS/+core/getGroupColors.m` — consistent group coloring across plots
- `+exploreFNIRS/+core/splitGroupsByFactor.m` — split grouped data by a factor for PlotBy layouts
- `pf2_base.external.suptitle` — figure super-title with automatic subplot spacing

**FRESH Benchmark Suite** (`tests/benchmarks/fresh/`):
- Reproduces the FRESH study (Yuecel et al. 2025, Communications Biology) within processFNIRS2

### Performance

**Voxel brain rendering — isosurface optimization:**
- `interpolateValues3D` voxel brain (`showVoxelBrain=true`) now uses `isosurface()` (marching cubes) instead of individual cube patches via `plotCube`
- Multi-depth normal sampling for vertex coloring prevents dark patches in sulci and ventricles
- Isosurface mesh cached via `setappdata` so animated mode and re-renders skip recomputation
- Channel data projection now works on voxel brain — color interpolation is applied to isosurface vertices when both `showVoxelBrain` and channel data are active
- `plotCube.m` unchanged (still used by `mni3d.m`)

**Context-based processing optimization:**
- `processFNIRS2()` skips `pf2_base.pf2_initialize()` when `'Context'` parameter is provided (no disk I/O)
- Context values copied to local PF2/setF for backward compatibility
- Enables parallel processing with isolated state per worker

**Memory-efficient probe storage:**
- Output stores `info.probename` reference instead of full `probeinfo` struct
- `loadProbeInfo()` reloads full probe data from cfg file when needed

### New Tests
- **WaveletResolveTest.m** — wavelet family resolution
- **ConnectivityTest.m** — coupling functions and matrix computation
- **BlockDefinitionTest.m** — marker-to-block conversion and extraction
- **GLMTest.m** — GLM design matrix and fitting
- **SSRTest.m** — short-channel regression
- **HierarchicalAverageTest.m** — hierarchical averaging validation
- **NormalizeMarkersTest.m** — marker normalization
- **SplitTest.m** — data splitting
- **NewMethodsTest.m** — IIR, spline, SCI rejection, short-channel PCA
- **QualityControlTest.m** — SCI and power spectrum QC
- **ProcessingContextTest.m** — context creation, validation, serialization
- **GoldenFileTest.m** — regression testing with golden reference files
- **testExperiment.m** — Experiment class integration
- **PlotStyleTest.m** — style infrastructure
- **VisualizationTest.m** — plotTopo, plotHeatmap, plotComposite
- **DirectedConnectivityTest.m** — Granger, transfer entropy, dynamic FC, directed/chord plots
- **IntraROITest.m** — intra/inter-ROI connectivity
- **HyperscanVisualizationTest.m** — hyperscanning visualization
- **AllPlotsSmokeTest.m** — smoke tests for all plot functions
- **StatsModuleTest.m** — stats.fitLME, runContrasts, summarize
- **QCPipelineTest.m** — assess, apply, report, and plotReport
- **MetadataImportTest.m** — importInfo and importBlockInfo with positional, key-based, and filtered matching

### Improvements
- **Auxiliary channel labels** — `Aux.varNames` field propagates through the full pipeline (split → resample → grand average → plot). Set `d.Aux.accelerometer.varNames = {'X','Y','Z'}` on input data and `plotAux` subplot titles automatically reflect them.
- **plotTopoLME layout overhaul** — colorbars are now manually positioned on separate axes to prevent overflow, with F-stat tick labels on the right side. Non-significant terms display as titled cells with centered "n.s." text. `PositionConstraint = 'innerposition'` on all axes prevents MATLAB auto-layout from overriding grid positions. Invisible border annotations prevent `exportgraphics` from cropping whitespace.
- **plotInfoScatter `ErrorBand` parameter** — draws a 95% confidence band around regression fit lines (per-group or overall)
- **Legend styling** — `plotTemporal` (channel grid mode), `plotInfoScatter`, and `renderTemporal` legends now use white background with black text. Subject count `(n=N)` is hidden when N=1 to reduce visual clutter.
- **Bar chart overhaul** — flat and clustered bar charts now both use `barweb` for consistency with the GUI
  - `PlotBy` parameter for clustered bar charts (e.g. `'PlotBy', 'Condition'` groups bars by condition within each X-axis category)
  - `GroupByVars` parameter auto-labels x-axis with factor names (e.g. "Group x Condition")
  - Per-bar coloring with colored-patch legends for flat bars
  - X-axis margin so bars don't touch y-axis borders
  - xlabel restricted to bottom row in multi-row layouts to prevent inter-row overlap
- **plotInfoBar converted to barweb** — consistent styling with plotBar (per-bar colors, x-axis labels, patch-based legends)
- **suptitle replaces sgtitle** across all headless plot functions — `suptitle` auto-rescales subplot positions to prevent title/subplot overlap on save. Affected: `plotBar`, `plotTemporal`, `plotAux`, `plotLME`, `plotScatter`, `plotTopo`, `plotTopoLME`, `PlotProxy`, `plotQuality`, `plotReport`, `addProcessingInfoTitle`
- **plotLME** — figure title now shows full model formula (e.g. `biom ~ Condition + (1 | SubjectID)`), matching `plotTopoLME`; Intercept term restored as a column in the bar chart
- **SNIRF import** — supports BIDS `events.tsv` sidecar loading, 4-column markers (amplitude), `dataTypeLabel` inference, m/cm/mm length units
- **SNIRF export** — `MeasurementDate` and `MeasurementTime` now written from `info` fields or derived from `UnixTime` when `.t0` is not available
- **Processing function headers** — standardized documentation for TDDR, wavelet, Takizawa, MARA
- **Line ending cleanup** — `bpf.m`, `lpf.m`, `pf2_bpf_fir.m` reformatted to readable multi-line format
- `buildProcessingInfo` accepts Context parameter, reads values directly without global access
- Method fallback uses Context libraries when available

**3D visualization camera angles:**
- `interpolateValues3D` `initCamPosition` expanded with diagonal and corner views: `'bottom'`, `'top-left'`, `'top-right'`, `'top-front'`, `'top-back'`, `'front-left'`, `'front-right'`, `'back-left'`, `'back-right'`

### Config Changes
- `pf2_functions_default.cfg` updated: wavelet functions now include `wavelet` and `accelerate` parameters

### Bug Fixes
- Fixed `pf2_unpackMethod` S# extraction always failing — `strcmp(string, cellArray)` returns a logical array, and `if(logicalArray)` requires ALL elements true, so the S# → `.F` conversion never executed. Replaced with `isfield`. This bug was dormant in the normal GUI workflow (the GUI unpacked methods before `pf2_unpackMethod` saw them), but broke any code path calling `pf2_unpackMethod` on raw INI data (Pipeline API, ProcessingContext). Consolidated three duplicate S# extraction implementations (GUI `unpackMethods`, raw `unpackMethodsLocal`, oxy `unpackMethodsLocal`) to delegate to the single fixed `pf2_unpackMethod`.
- Fixed SNIRF import marker corruption — when SNIRF stimulus groups had names and 4+ data columns (e.g., amplitude), the stim name string was concatenated onto the numeric marker array, causing MATLAB to silently convert the entire marker matrix to `char`. This broke all downstream marker-dependent functions (`defineBlocks`, `extractBlocks`, `setT0`). Marker names are now discarded during import since the marker code in column 2 already encodes the stimulus identity.
- Fixed Aux metadata fields (`varNames`, `unit`) being flattened into separate aux fields (e.g. `accelerometer_varNames`) that caused `grandAvgFNIRS` to error on cell array data. These fields are now skipped during flatten and `varNames` values are used as table column names instead.
- Fixed `barweb` scatter data points leaking into legends as "data1", "data2" entries (`HandleVisibility` set to `'off'`)
- Fixed `grandAvgFNIRS.m` crash when data lacks segmentTimes field
- Fixed `plotTemporal.m` shadowing MATLAB builtins (`upper`/`lower` renamed to `upperBound`/`lowerBound`)
- Fixed `bvoxy_basic` size mismatch crash — `channels` arg was `1:T` instead of `[1,1]`, and DPF was incorrectly passed as `baselineSamples` positional arg
- Fixed `pf2.data.resample` operator precedence bug in Aux time detection — `all(diff(col>0))` was comparing before differencing, causing monotonic time fallback to always fail
- Fixed `pf2.data.resample` allowing `segmentLength=0` which caused division by zero
- Fixed `pf2.data.resample` potential uninitialized `validCh`/`validCh_roi` when baseline loop skips all biomarker fields
- Cleaned up `pf2.data.resample` — removed unused variable allocations and commented-out code
- Fixed `aggregate()` passing NaN resample size to `grandAvgFNIRS` when `barBinSize=0` — single-point segments produce empty time vectors, breaking LME and scatter plots
- Fixed `expandGroupsByTime` not slicing ROI data from `gbyGrandBarFlat` when expanding time bins

---

## v0.9 (2026-01-23)
API Standardization, Testing Infrastructure & Context-Based Processing

### New Features
- **ProcessingContext class** for isolated, reproducible processing
  - Encapsulates all processing settings (DPF, baseline, methods, device)
  - Enables parallel processing with different settings per worker
  - Supports serialization via `toStruct()`/`fromStruct()` for saving analysis settings
  - Pass via `processFNIRS2(data, 'Context', ctx)` parameter
- **processingInfo in output data** - Processed data now includes `fNIR.processingInfo` struct
  - Stores all processing settings used (DPF mode/value, baseline, methods, device)
  - Enables reproducibility by documenting exactly how data was processed
  - Plots automatically display device name, method, and DPF settings in figure title
- **Improved plotting functions** (`pf2.data.plot.oxy`, `raw`, `roi`, `auxData`)
  - Hybrid argument pattern: positional for common args, name-value for options
  - Auto-generated figure titles from processingInfo (e.g., "fNIR2000C | x5_TDDR | DPF(age=25)")
  - Added `interactive` parameter to control GUI prompts for headless/batch processing
  - Added save functionality: `savePath`, `saveWidth`, `saveHeight`, `saveDPI` parameters
  - Input validation with clear error messages
- **Improved probe plotting functions** (all `pf2.probe.plot.*` functions)
  - Added save parameters to all visualization functions:
    - `arrangedValues`, `imageValues`, `imageROIvalues`
    - `interpolateValues`, `interpolateROIvalues`, `interpolateValues3D`
  - Supports .png, .pdf, .fig, .svg, .eps, .tif, .jpg output formats
  - Configurable output dimensions and resolution
- **New helper function**: `pf2_base.plot.saveFigure` for centralized figure saving
- **Bug fixes in probe plots**:
  - Fixed `imageROIvalues.m` inverted error check that blocked valid data
  - Fixed `roi.m` incorrect fchMask reference (was using channel mask instead of ROI mask)
- **Refactored `auxData.m`**: Full refactor to use inputParser with hybrid argument pattern
- Moved `processStageOD2Hb` to external function `pf2_base.fnirs.processStageOD2Hb`

### Breaking Changes
- **camelCase API migration**: All public API functions now use camelCase naming convention
  - `pf2.Import.*` → `pf2.import.*`
  - `pf2.Export.*` → `pf2.export.*`
  - `pf2.Data.*` → `pf2.data.*`
  - `pf2.Process.*` → `pf2.process.*`
  - `pf2.Methods.*` → `pf2.methods.*`
  - `pf2.Settings.*` → `pf2.settings.*`
  - `pf2.Probe.*` → `pf2.probe.*`

### New Features
- Added comprehensive unit testing infrastructure using MATLAB's unittest framework
- Added integration tests for full processing pipeline validation
- Added synthetic fNIRS data generators with configurable physiological and artifact components
- Added quick validation scripts for rapid sanity checking

### Testing Infrastructure

**Test Runners:**
- `pf2_base.tests.runAllTests()` - Run complete test suite
- `pf2_base.tests.runQuickTests()` - Run fast validation tests

**Unit Tests:**
- `ImportNIRTest` - NIR file import validation
- `DataStructureTest` - fNIRS struct invariant validation
- `SignalProcessingTest` - Filter function testing
- `DataManipulationTest` - Resample, concatenate, split operations
- `BeerLambertTest` - Beer-Lambert conversion (bvoxy, Intensity2OD)
- `TDDRTest` - TDDR motion correction algorithm
- `ROIDefinitionTest` - ROI definition and configuration
- `ROIBuildingTest` - ROI aggregation (nanmean, PCA)
- `ExportTest` - NIR and SNIRF export functions
- `FDRTest` - FDR statistical correction (Benjamini-Hochberg, two-step)
- `MethodConfigTest` - Processing method configuration
- `AuxDataTest` - Auxiliary data handling
- `ProcessingContextTest` - Context class creation, validation, serialization
- `ProcessStageOD2HbTest` - Beer-Lambert conversion stage testing

**Integration Tests:**
- `FullPipelineTest` - End-to-end processing pipeline tests
- `RoundtripTest` - SNIRF import/export roundtrip validation
- `ProcessingContextIntegrationTest` - Context isolation, parallel processing simulation

**Synthetic Data Generators:**
- `generateFNIRS` - Realistic raw fNIRS data with HRF, cardiac, respiratory signals
- `generateHemoglobin` - Synthetic HbO/HbR concentration data
- `generateNoise` - White, pink, and brown noise generation
- `generateArtifacts` - Motion artifact generation (spikes, steps, drift)
- `generatePhysiological` - Cardiac and respiratory signal generation

**Documentation:**
- Added `testing_plan.md` - Comprehensive testing strategy document
- Added `golden/README.md` - Golden file infrastructure documentation

### Bug Fixes
- Fixed SNIRF import optode reindexing crash when optode numbers exceed array dimensions
- Fixed SNIRF import channel mapping loop iterating over wrong count (numOpt vs numCh)

## v0.8.1 (2026-01-23)
Documentation & SNIRF Improvements

- Added detailed function headers across import, export, data manipulation, plotting, and methods configuration modules
- Added `pf2.data.concatenateHorizontal` for joining fNIRS segments side-by-side with probe geometry merging
- Added `exploreFNIRS.versInfo` for version tracking
- Fixed `pf2.data.resample` to skip missing fields gracefully
- Fixed SNIRF import to use stable sort for consistent channel ordering
- Fixed SNIRF export to handle NaN wavelengths correctly
- Improved probe layout ordering to prefer source/detector index
- Fixed channel filter to determine channels in advance during processing
- Fixed probe check GUI
- Fixed help file to reflect moved export functions
- Fixed "strip extra raw" functionality
- Renamed `Concatonate` to `Concatenate` and `ConcatonateHorizontal` to `ConcatenateHorizontal`

## v0.8a (2024)
SNIRF Support & Visualization Enhancements

- Added SNIRF format import and export with embedded probe information and short separation channel handling
- Added `pf2.export.asNIR` to export fNIRS structs back to .nir file format
- Added violin plot support in exploreFNIRS bar charts with kernel density estimation
- Added IQR and IQR-without-outliers options for error bar display
- Added non-ordinal optode support (channels no longer require sequential optode numbering)
- Added datetime support in `pf2.data.setT0`
- `pf2.data.split` now properly splits and flattens auxiliary data channels
- 3D interpolation plots filter short separation channels by default
- Fixed scatter plots displaying flipped orientation
- Fixed barchart plotting with model indices
- Fixed temporal ROI plotting
- Fixed export for long and wide table formats
- Fixed channel ordering after Beer-Lambert conversion
- Fixed crash when markers are missing
- Fixed crash with mismatched channel numbers
- Fixed t0 calculation from datetime/unix timestamps
- Fixed marker sorting on SNIRF import
- Fixed probe check GUI in auto mode
- Fixed errorbar means calculation
- Fixed autocontrast indexing

## v0.7a (2022-07-05)
3D Visualization & Multi-Probe Support

- Migrated 3D visualization to MNI coordinates for standardized brain mapping
- Added Brodmann area plotting, labeling, and legend support on 3D brain models
- Added ability to plot and concatenate data from multiple probes
- Added 10-20 EEG probe plotting and ability to overlay EEG/fNIRS data
- Added voxel-based brain visualization mode
- Moved temporal, scatter, and barchart plotting to standalone functions in `exploreFNIRS.plot`
- Added Aux channel support in temporal, scatter, and barchart plots
- exploreFNIRS now handles categorical values in grouping and analysis
- Enhanced regex pattern matching for marker extraction
- Faster Hitachi import with datetime extraction
- Added datetime/duration field support and recursive struct/table resampling
- Fixed autocontrast sorting and indexing
- Fixed LME model failures with categorical types
- Fixed vline support for datetime/duration axes
- Fixed interpolate values chart orientation
- Fixed grandavg for auxiliary data with time integration
- Fixed suptitle spacing issues
- Fixed ICA clean and wavelet clean functionality

## v0.6a (2021-10-29)
Processing Pipeline Consolidation

- Merged GUI and non-GUI processing pipelines into external functions
- Created `plot_arranged` function for unified arranged plotting
- Restored classic oxy and raw plot functionality
- Added OptTable support for plotting functions
- Changed Oxy and Raw plot functions to varargin structure
- Added multiprobe plotting for Raw method
- Concatenate function improvements (saves more fields, retains markers)
- ICA clean fixes and fastica/runica configuration option
- Updated help documentation to pf2 format
- Fixed SkipOD functionality and header saving in importNIR
- GetMarkers now supports table marker types and asymmetric patterns

## v0.5a (2020-07-22)
3D Visualization Foundation

- Added InterpolateValues3D for brain surface visualization
- Added multiprobe plotting support
- Added custom colorbars and transparency controls
- Added 10-20 EEG probe plotting capability
- Added fNIR2000 sample data
- Added short separation channel visualization
- Hitachi ETG-4000 configuration updates with 3D positions
- Renamed processFNIRS2 wrapper to pf2

## v0.4a (2019-07-22)
Motion Correction & Statistics

- Added FastICA and Wavelab libraries
- Added Homer-style wavelet motion correction (Molavi)
- Added buildHRF function for hemodynamic response modeling
- Improved SMAR and SMAR2 motion correction algorithms
- Added piecewise and interpolation as NaN alternatives for filtering
- TDDR improvements
- FDR correction implementation
- ANOVA as primary LME measure in exploreFNIRS
- Save/load functionality in exploreFNIRS
- NIRx import improvements
- Baseline period improvements

## v0.3a (2019-06-22)
ROI & Visualization

- ROI support and reorganization complete
- Plot Oxy and Plot Raw functionality complete
- Added plotROI function
- Added Interpolate ROI values
- Added image values and image ROI values visualization
- Channel mask GUI editing
- Short separation channel filtering option
- Rejection level configuration
- Version number display in GUIs
- Added ability to describe methods
- List current method and method output functions

## v0.2a (2019-06-12)
Package Migration

- Migrated codebase to MATLAB package format (`+pf2`, `+pf2_base`)
- ConfigureMethods autoload default functions
- Added functionality to autoload channel rejection if present
- Fixed subtractambientlight values
- Added settings functions
- Modified exploreFNIRS to check for default root path

## v0.1a (2019-06-06)
Initial Release

- Initial commit and codebase reorganization
- Created README
- Added auto addpath functionality
- Basic exploreFNIRS with multi-biomarker LME support
- Automatic demographic loading in importNIR
- Updated ImportNIR for COBI format and space-delimited files
