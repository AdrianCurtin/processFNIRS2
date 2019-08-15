# processFNIRS2
A set of tools to process and visualize fNIRS data

processFNIRS2 is designed to be a flexible application for fNIRS preprocessing and visualization

Currently this requires you to add configuration files for each function (to map inputs) and device configuration you plan to use

Use processFNIRS2 to process your data today!

Instructions for installation
Include processFNIRS2 and the base_functions, GUI folders to your matlab path

See the wiki for more details.

ProcessFNIR2 is laid out in the following manner:

processFNIRS2
	--Data					*functions to manipulate individual fNIRS segments
		--ApplyChannelMask		*Set bad channels to nan
		--GetMarkers			*Function to find the timepoints of markers in a regex style
		--Resample				*Function to resample or average fNIRS data (ex: 30s block average or convert to 1hz)
		--SetT0					*Function to shift the fNIRS time to match start of experiment t=0
		--Split					*Functino to split fNIRS segment based on different input times
	--GUI					*Shortcut for accessing the GUI
	--Help					*This!
	--Import				*Functions to import fNIRS files
		--ImportHitachiMES		*Import Hitachi Probes
		--ImportNIRx			*Import NIRx files
		--ImportNIR				*Import fNIR Devices/Biopac files
		--ImportSampleData		*Import some sample data included here
	--Methods				*Functions to change and modify processing methods
		--Oxy					*Oxy conversion pipeline methods
			--ConfigureMethods		*GUI to edit functions in Oxy pipeline
			--ImportMethods			*Import pre-existing methods from a file
			--List					*List currently loaded methods
			--SetMethod				*Select a method based on name or method number
		--Raw				*Oxy conversion pipeline methods
			--ConfigureMethods		*GUI to edit functions in Oxy pipeline
			--ImportMethods			*Import pre-existing methods from a file
			--List					*List currently loaded methods
			--SetMethod				*Select a method based on name or method number
	--Process				*Process fNIR segment data
		--ProcessOxy			*Run the Oxy Pipeline only (raw must be run first)
		--ProcessRaw			*Run the Raw Pipeline only
	--Settings				*Change settings related to processing
		--Baseline				*Change baseline time settings
		--DPF					*Change mode of Differential Path Length (DPF)
			--SetFixedDFP			*Change to fixed distance factor
			--SetDPFmode				* Set to 'none','fixed', or 'calc'
		--SelectDevice		*Forcibly reload device settings for FNIRS probe
Please be sure to add the matlab path the main folder (processFNIRS2) and the folders named:
	 base_functions, GUI, and functions
