# processFNIRS v0.7

## Overview
processFNIRS is a modular MATLAB toolbox designed for processing functional Near-Infrared Spectroscopy (fNIRS) data. The toolbox provides a flexible framework for importing, processing, analyzing, and visualizing fNIRS data from multiple device manufacturers.

## Key Features
- **Modular processing pipeline** for both raw intensity data and hemoglobin concentration data
- **Device-agnostic design** with support for multiple fNIRS systems:
  - fNIR Devices/Biopac
  - Hitachi ETG-4000
  - NIRx systems
  - Custom devices
- **Customizable processing methods** that can be configured and saved
- **Robust visualization tools** including:
  - Time series plots
  - Topographic mapping
  - Interactive data exploration via exploreFNIRS
- **Channel quality assessment** and artifact rejection capabilities
- **Region-of-Interest (ROI) analysis** support
- **Statistical analysis** with LME models integrated in exploreFNIRS
- **Data export** in various formats including CSV, nir, snirf and MATLAB formats

## Getting Started

### Installation
1. Clone or download this repository
2. Add the main processFNIRS2 folder and the following subdirectories to your MATLAB path:
   ```matlab
   addpath('base_functions', 'GUI', 'functions');
   ```
   Note: Folders with + signs in front of the name will be automatically included

### Quick Start Guide
```matlab
% Import data
mydata = processFNIRS2.Import.ImportNIR('myNIRSfile.nir');

% Configure processing methods
processFNIRS2(); % Opens GUI for method configuration
% Or select methods programmatically:
processFNIRS2.Methods.Raw.SetMethod('MyRawMethod');
processFNIRS2.Methods.Oxy.SetMethod('MyOxyMethod');

% Process data
myprocesseddata = processFNIRS2(mydata);

% Visualize data
processFNIRS2(myprocesseddata);

% Explore and analyze data
exploreFNIRS(myprocesseddata);
```

## Processing Pipeline

### Data Import
Use functions in the `processFNIRS2.Import` module to load data from various fNIRS devices:
- `ImportNIR`: Import fNIR Devices/Biopac files
- `ImportHitachiMES`: Import Hitachi ETG-4000 files
- `ImportNIRx`: Import NIRx system files
- `ImportSampleData`: Load example datasets included with the toolbox

### Method Configuration
processFNIRS2 uses a two-stage processing pipeline:
1. **Raw processing** (Raw → Optical Density)
   - Configure and select methods using `processFNIRS2.Methods.Raw`
   - Common preprocessing includes: motion artifact correction, filtering, CAR, etc.

2. **Oxy processing** (Optical Density → Hemoglobin)
   - Configure and select methods using `processFNIRS2.Methods.Oxy`
   - Processing includes: Beer-Lambert conversion, filtering, ROI analysis, etc.

Methods can be configured through the GUI or programmatically:
```matlab
% Open method configuration GUI
processFNIRS2.Methods.Raw.ConfigureMethods();
processFNIRS2.Methods.Oxy.ConfigureMethods();

% List available methods
processFNIRS2.Methods.Raw.List();
processFNIRS2.Methods.Oxy.List();

% Set methods programmatically
processFNIRS2.Methods.Raw.SetMethod('MyRawMethod');
processFNIRS2.Methods.Oxy.SetMethod('MyOxyMethod');
```

### Data Processing
Process data using the selected methods:
```matlab
% Process both raw and oxy stages
myprocesseddata = processFNIRS2(mydata);

% Process specific stages only
myrawprocessed = processFNIRS2.Process.ProcessRaw(mydata);
myoxyprocessed = processFNIRS2.Process.ProcessOxy(myrawprocessed);
```

### Data Manipulation
The toolbox provides various functions for manipulating fNIRS data:
- `processFNIRS2.Data.ApplyChannelMask`: Set bad channels to NaN
- `processFNIRS2.Data.GetMarkers`: Find specific markers in the data
- `processFNIRS2.Data.Resample`: Resample or average fNIRS data
- `processFNIRS2.Data.SetT0`: Shift time to align with experiment start
- `processFNIRS2.Data.Split`: Split fNIRS segments based on time points

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
- Various visualization options (temporal plots, scatter plots, bar charts)
- Exportable statistics and figures

## Settings Configuration
Adjust common settings using the Settings module:
```matlab
% Baseline settings
processFNIRS2.Settings.Baseline.SetBaselineStartTime(0);
processFNIRS2.Settings.Baseline.SetBaselineLength(5);

% DPF (Differential Path Length) settings
processFNIRS2.Settings.DPF.SetDPFmode('Calc'); % 'None', 'Fixed', or 'Calc'
processFNIRS2.Settings.DPF.SetFixedDPF(5.93);

% Device selection
processFNIRS2.Settings.SelectDevice('fNIR_Devices_fNIR1200_16ch.cfg');
```

## File Structure
- `processFNIRS2.m`: Main function for processing fNIRS data
- `+pf2/`: Main module containing user-facing functions
- `+pf2_base/`: Internal base functions
- `base_functions/`: Core processing functions
- `GUI/`: User interface components
- `functions/`: Processing algorithms
- `devices/`: Device configuration files
- `sampledata/`: Example datasets

## Preferences and Configuration
Settings, loaded functions, and methods are stored in the MATLAB preference directory.
Access this location using the MATLAB command: `prefdir`

## Documentation
For detailed function documentation, use MATLAB's `help` command:
```matlab
help processFNIRS2
help processFNIRS2.Methods.Raw
help processFNIRS2.Import.ImportNIR
```

## License
processFNIRS2 is free for academic and non-commercial use, but some included code may have other licenses.

## Citation
If you use processFNIRS2 in your research, please cite:
[Citation information to be added]

## Contact
For questions or support, contact Adrian Curtin at abc48@drexel.edu
