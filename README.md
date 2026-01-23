# processFNIRS2 v8.1

## Overview
processFNIRS2 is a modular MATLAB toolbox designed for processing functional Near-Infrared Spectroscopy (fNIRS) data. The toolbox provides a flexible framework for importing, processing, analyzing, and visualizing fNIRS data from multiple device manufacturers.

## Key Features
- **Modular processing pipeline** for both raw intensity data and hemoglobin concentration data
- **Device-agnostic design** with support for multiple fNIRS systems:
  - fNIR Devices/Biopac
  - Hitachi ETG-4000
  - NIRx systems
- **Customizable processing methods** that can be configured and saved
- **Robust visualization tools** including:
  - Time series plots
  - Topographic mapping
  - Interactive data exploration via exploreFNIRS
- **Channel quality assessment** and artifact rejection capabilities
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

% Export data
pf2.export.asNIR(myprocesseddata, 'myexport.nir');
pf2.export.asSNIRF(myprocesseddata, 'myexport.snirf');

% Explore and analyze data
exploreFNIRS(myprocesseddata);
```

## Processing Pipeline

### Data Import
Use functions in the `pf2.Import` module to load data from various fNIRS devices:
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
- `pf2.data.plot`: Visualize fNIRS data (Oxy, Raw, ROI, AuxData)
- `pf2.Export`: Export data to NIR or SNIRF formats

### Method Configuration
processFNIRS2 uses a two-stage processing pipeline:
1. **Raw processing** (Raw → Optical Density)
   - Configure and select methods using `pf2.methods.Raw`
   - Common preprocessing includes: motion artifact correction, filtering, CAR, etc.

2. **Oxy processing** (Optical Density → Hemoglobin)
   - Configure and select methods using `pf2.methods.Oxy`
   - Processing includes: Beer-Lambert conversion, filtering, ROI analysis, etc.

Methods can be configured through the GUI or programmatically:
```matlab
% Open method configuration GUI
pf2.methods.raw.configureMethods();
pf2.methods.oxy.configureMethods();

% List available methods
pf2.methods.raw.List();
pf2.methods.oxy.List();

% Set methods programmatically
pf2.methods.raw.setMethod('MyRawMethod');
pf2.methods.oxy.setMethod('MyOxyMethod');
```

### Data Processing
Process data using the selected methods:
```matlab
% Process both raw and oxy stages
myprocesseddata = processFNIRS2(mydata);

% Process specific stages only
myrawprocessed = pf2.process.processRaw(mydata);
myoxyprocessed = pf2.process.processOxy(myrawprocessed);
```

### Visualization and Export
Visualize and export your processed data:
```matlab
% Visualize different aspects of the data
pf2.data.plot.oxy(myprocesseddata);      % Plot oxygenation data
pf2.data.plot.raw(myprocesseddata);      % Plot raw intensity data
pf2.data.plot.roi(myprocesseddata);      % Plot region of interest data
pf2.data.plot.auxData(myprocesseddata);  % Plot auxiliary data

% Export data to different formats
pf2.export.asNIR(myprocesseddata, 'myexport.nir');
pf2.export.asSNIRF(myprocesseddata, 'myexport.snirf');
```

### Advanced Analysis with exploreFNIRS
For more advanced data exploration and analysis, use the exploreFNIRS module:
```matlab
% Basic usage
exploreFNIRS(myprocesseddata);

% With additional options
exploreFNIRS(myprocesseddata, 'timeShiftTo0', true, 'blStart', 0, 'blEnd', 5, ...
             'blockStart', 5, 'blockEnd', 65, 'barSegmentLength', 60);
```

exploreFNIRS features:
- Group-level analysis
- Statistical modeling with LME
- Various visualization options:
  - Temporal plots: `exploreFNIRS.plot.temporal()`
  - Bar charts: `exploreFNIRS.plot.barchart()`
  - Scatter plots: `exploreFNIRS.plot.scatter()`
- FDR correction: `exploreFNIRS.fx.performFDR()`
- Data export: `exploreFNIRS.export.mergeGbyTablesWide()` / `mergeGbyTablesLong()`

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
- `+pf2/`: User-facing API (Import, Export, Data, Methods, Settings, Probe)
- `+pf2_base/`: Internal infrastructure and utilities
- `+exploreFNIRS/`: Group analysis functions (plot, export, fx, dataset)
- `base_functions/`: Utility functions (legacy)
- `GUI/`: User interface components (legacy, GUIDE-based)
- `functions/`: Signal processing algorithms (filters, motion correction, etc.)
- `devices/`: Device configuration files (.cfg)
- `sampledata/`: Example datasets

## Overall Structure
processFNIRS2 is laid out in the following manner:
- **Data**: Functions to manipulate individual fNIRS segments
  - ApplyChannelMask: Set bad channels to nan
  - GetMarkers: Find timepoints of markers in a regex style
  - Resample: Resample or average fNIRS data
  - SetT0: Shift fNIRS time to match start of experiment
  - Split: Split fNIRS segment based on different input times
  - **Plot**: Functions to visualize fNIRS data
    - AuxData: Plot auxiliary data channels
    - Oxy: Plot oxygenation data
    - ROI: Plot Region of Interest data
    - Raw: Plot raw intensity data
  - **Export**: Functions to export fNIRS data
    - asNIR: Export to NIR file format
    - asSNIRF: Export to SNIRF file format
- **GUI**: Shortcut for accessing the GUI
- **Help**: Access to help documentation
- **Import**: Functions to import fNIRS files
  - importHitachiMES: Import Hitachi Probes
  - importNIRX: Import NIRx files
  - importNIR: Import fNIR Devices/Biopac files
  - importSNIRF: Import SNIRF format files
  - sampleData: Load sample data included with the toolbox
- **Methods**: Functions to change and modify processing methods
  - Oxy: Oxy conversion pipeline methods
  - Raw: Raw domain pipeline methods
- **Process**: Process fNIR segment data
  - processOxy: Run the Oxy Pipeline only
  - processRaw: Run the Raw Pipeline only
- **Settings**: Change settings related to processing
  - Baseline: Change baseline time settings
  - DPF: Change mode of Differential Path Length
  - selectDevice: Reload device settings for FNIRS probe

## Troubleshooting Tips
- When importing data for the first time, verify that the probe configuration is correct
- If you get errors about DPF factors, check the settings using `pf2.settings.DPF`
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
help pf2.methods.Raw
help pf2.import.importNIR
```

## License
processFNIRS2 is free for academic and non-commercial use, but some included code may have other licenses.

## Citation
If you use processFNIRS2 in your research, please cite:
[Citation information to be added]

## Contact
For questions or support, contact Dr. Adrian Curtin at adrian.b.curtin@drexel.edu