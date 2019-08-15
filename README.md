# Welcome to processFNIRS v0.4

 This tool is designed to allow modular processing of fNIRS data. If this is your first time using this software, try running processFNIRS2() and click configure methods to build your first methods file. You will need to load the default functions first, but then you may add functions to your library and build your first processing methods. Test out a few methods using the visualization tool to see how they work!

Note: settings changed in the GUI do not affect your data and are for visualization only.

Once you have defined a few functions you can use the normal processFNIRS2 pipeline.

This is generally done in three stages:

	1) Import Data
		Import your data using processFNIRS.Import.ImportNIR (or other function)
		Load your data using the function as a string or select the file yourself
		ex: mydata = processFNIRS.Import.ImportNIR('myNIRSfile.nir')

	2) Set Methods
		Select a method for both Raw and Oxy domain processing
		You can visualize the effects of your methods by using processFNIRS(mydata)
		and configure your methods by using processFNIRS.Methods.Oxy/Raw.ConfigureMethods
		Selecting methods is easy, you can select a method using either the method name,
		Or selecting the method interactively
		Please note that both the Raw method is applied first and then the Oxy method
		ex: processFNIRS2.Methods.Raw.SetMethod('MyMethodName')
		ex: processFNIRS2.Methods.Oxy.SetMethod('MyMethodName')

	3) Process Data
		Run your processing method on your data using processFNIRS2(mydata)
		You can optionally process only the oxy or raw domain signals using processFNIRS2.Process.ProcessRaw/ProcessOxy
		However the default function will run both Raw and Oxy pipelines
		exL myprocesseddata=processFNIRS2(mydata))

processfNIRS2 is laid out in the following manner&nbsp;&nbsp;&nbsp;&nbsp;

|Function|Description|
| ------------- | ------------- |
|processFNIRS2|Main function (runs GUI if no assignment)|
|*Data|functions to manipulate individual fNIRS segments<br>|
|&nbsp;&nbsp;&nbsp;&nbsp;-ApplyChannelMask|Set bad channels to nan|
|&nbsp;&nbsp;&nbsp;&nbsp;-GetMarkers|Function to find the timepoints of markers in a regex style|
|&nbsp;&nbsp;&nbsp;&nbsp;-Resample|Function to resample or average fNIRS data (ex&nbsp;&nbsp;&nbsp;&nbsp; 30s block average or convert to 1hz)|
|&nbsp;&nbsp;&nbsp;&nbsp;-SetT0|Function to shift the fNIRS time to match start of experiment t=0|
|&nbsp;&nbsp;&nbsp;&nbsp;-Split|Function to split fNIRS segment based on different input times|
|*GUI|Shortcut for accessing the GUI|
|*Help|This!|
|*Import|Functions to import fNIRS files|
|&nbsp;&nbsp;&nbsp;&nbsp;-ImportHitachiMES|Import Hitachi Probes|
|&nbsp;&nbsp;&nbsp;&nbsp;-ImportNIRx|Import NIRx files|
|&nbsp;&nbsp;&nbsp;&nbsp;-ImportNIR|Import fNIR Devices/Biopac files|
|&nbsp;&nbsp;&nbsp;&nbsp;-ImportSampleData|Import some sample data included here|
|*Methods|Functions to change and modify processing methods|
|&nbsp;&nbsp;&nbsp;&nbsp;-Oxy|Oxy conversion pipeline methods|
|&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;-ConfigureMethods|GUI to edit functions in Oxy pipeline|
|&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;-ImportMethods|Import pre-existing methods from a file|
|&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;-List|List currently loaded methods|
|&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;-SetMethod|Select a method based on name or method number|
|&nbsp;&nbsp;&nbsp;&nbsp;-Raw|Raw conversion pipeline methods|
|&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;ConfigureMethods|GUI to edit functions in Oxy pipeline|
|&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;ImportMethods|Import pre-existing methods from a file|
|&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;List|List currently loaded methods|
|&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;SetMethod|Select a method based on name or method number|
|&nbsp;&nbsp;&nbsp;&nbsp;-Process|Process fNIR segment data|
|&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;-ProcessOxy|Run the Oxy Pipeline only (raw must be run first)|
|&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;-ProcessRaw|Run the Raw Pipeline only|
|&nbsp;&nbsp;&nbsp;&nbsp;-Settings|Change settings related to processing|
|&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Baseline|Change baseline time settings|
|&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;DPF|Change mode of Differential Path Length (DPF)|
|&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;SetFixedDFP|Change to fixed distance factor|
|&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;SetDPFmode| Set to 'none','fixed', or 'calc'|
|&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;SelectDevice|Forcibly reload device settings for FNIRS probe|

Please be sure to add the matlab path the main folder (processFNIRS2) and the folders named&nbsp;&nbsp;&nbsp;&nbsp;

      base_functions, GUI, and functions

Folders with + signs in front of the name do not need to be included

base_functions and GUI contain functions related to the operation of processFNIRS2

functions contains the functions used in the processFNIRS2 method pipelines, but you may use any matlab functions in a pipeline if you add the function to your method

Loaded functions and methods are stored in the matlab preference directory

You may find these settings using the matlab command&nbsp;&nbsp;&nbsp;&nbsp; prefdir

If you are having trouble loading processFNIRS2, delete these files and try again


processFNIRS2 is free for academic and non-commercial use, but some included code may have other licenses

(c)2019

Contact Adrian Curtin for more information at abc48@drexel.edu
