# Changelog

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
