# Changelog

## v1.0.0 (2026-02-06)
Scriptable Group Analysis, Connectivity, Hyperscanning & Method CRUD

### New Features

**exploreFNIRS Scriptable API:**
- **Experiment container class** (`+exploreFNIRS/+core/Experiment.m`) for fully scriptable group analysis without the GUI
  - `select()`, `groupby()`, `aggregate()` methods for data organization
  - `connectivity()` and `hyperscanning()` methods with block-wise support
  - `plotTemporal()`, `plotBar()` wrappers that forward to headless plotting
  - `exportLong()`, `exportWide()` for data export
- **Headless plotting** (`+exploreFNIRS/+core/plotTemporal.m`, `plotBar.m`)
  - Publication-ready temporal and bar chart plots without GUI
  - ROI support via `'ROIs'` parameter (indices, names, or `'all'`)
  - Configurable error bands (SEM/SD), layout (overlay/grid), and save options

**Connectivity Analysis:**
- **Connectivity module** (`+exploreFNIRS/+connectivity/`) with `computeMatrix`, `plotMatrix`, `plotBlockComparison`
- **Coupling functions** (`+exploreFNIRS/+coupling/`) — Pearson, Spearman, cross-correlation, coherence, wavelet coherence
- **Visualization** — `plotWcoherence` (time-freq heatmap), `plotWindowed` (windowed coupling time series)

**Hyperscanning Analysis:**
- **Hyperscanning module** (`+exploreFNIRS/+hyperscanning/`) with `pairSubjects`, `computeDyad`, `computeGroup`, `permutationTest`, `plotGroup`
- Block-wise hyperscanning with struct array results

**Block Definition & Extraction:**
- `pf2.data.defineBlocks()` — convert markers to block struct array
- `pf2.data.extractBlocks()` — extract fNIRS segments by block definitions
- Positional API: `defineBlocks(data, [49,50], 30)` or name-value pairs

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

**Other New Features:**
- `pf2_base.normalizeMarkers()` — standardize marker codes across devices
- `pf2_base.applyLightTheme()` — consistent light theme for figures
- `+exploreFNIRS/+export/connectivityToTable.m` — export connectivity results as tables
- `+exploreFNIRS/+core/getGroupColors.m` — consistent group coloring across plots

### New Tests
- **ConnectivityTest.m** — 31 tests covering all coupling functions, matrix computation, and block-wise connectivity
- **BlockDefinitionTest.m** — 29 tests covering marker-to-block conversion and extraction
- **GLMTest.m** — GLM design matrix and fitting tests
- **SSRTest.m** — Short-channel regression tests
- **HierarchicalAverageTest.m** — Hierarchical averaging validation
- **NormalizeMarkersTest.m** — Marker normalization tests
- **SplitTest.m** — Data splitting tests
- **GoldenFileTest.m** — Regression testing with golden reference files
- **testExperiment.m** — Experiment class integration tests
- Test count: 225 → 300+ tests across 20+ test classes

### Bug Fixes
- Fixed `grandAvgFNIRS.m` crash when data lacks segmentTimes field
- Fixed `plotTemporal.m` shadowing MATLAB builtins (`upper`/`lower` renamed to `upperBound`/`lowerBound`)

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
