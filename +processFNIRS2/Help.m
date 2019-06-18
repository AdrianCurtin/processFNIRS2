function Help()

[~,vers]=pf2_base.pf2version();
fprintf('<strong>Welcome to processFNIRS %s\n</strong>',vers);

fprintf(' This tool is designed to allow modular processing of fNIRS data\n');

fprintf('If this is your first time using this software, try running processFNIRS2()\n');

fprintf('And click configure methods to build your first methods file\n');


fprintf('You will need to load the default functions first, but then you may add functions\n');

fprintf('to your library and build your first processing methods\n');


fprintf('\n');


fprintf('Test out a few methods using the visualization tool to see how they work.\n');

fprintf(2,'Note: settings changed in the GUI do not affect your data and are for visualization only\n');


fprintf('\n');


fprintf('Once you have defined a few functions you can use the normal processFNIRS2 pipeline\n');

fprintf('This is genearlly done in three stages\n\n');


fprintf('\t<strong>1) Import Data\n</strong>');
fprintf('\t\tImport your data using processFNIRS.Import.ImportNIR (or other function)\n');
fprintf('\t\tLoad your data using the function as a string or select the file yourself\n');
fprintf(2,'\t\tex: mydata = processFNIRS.Import.ImportNIR(''myNIRSfile.nir'')\n');
fprintf('\n');

fprintf('\t<strong>2) Set Methods\n</strong>');
fprintf('\t\tSelect a method for both Raw and Oxy domain proccesing\n');
fprintf('\t\tYou can visualize the effects of your methods by using processFNIRS(mydata)\n');
fprintf('\t\tand configure your methods by using processFNIRS.Methods.Oxy/Raw.ConfigureMethods\n');
fprintf('\t\tSelecting methods is easy, you can select a method using either the methond name,\n');
fprintf('\t\tOr selecting the method interactively\n');
fprintf('\t\tPlease note that both the Raw method is applied first and then the Oxy method\n');
fprintf(2,'\t\tex: processFNIRS2.Methods.Raw.SetMethod(''MyMethodName'')\n');
fprintf(2,'\t\tex: processFNIRS2.Methods.Oxy.SetMethod(''MyMethodName'')\n');
fprintf('\n');

fprintf('\t<strong>3) Process Data\n</strong>');
fprintf('\t\tRun your processing method on your data using processFNIRS2(mydata)\n');
fprintf('\t\tYou can optionally process only the oxy or raw domain signals using processFNIRS2.Process.ProcessRaw/ProcessOxy\n');
fprintf('\t\tHowever the default funciton will run both Raw and Oxy pipelines\n');
fprintf(2,'\t\tex: myprocesseddata=processFNIRS2(mydata))\n');

fprintf('\n\nPress Any Key to continue...\n\n\n')
pause;

fprintf('<strong>processfNIRS2 is laid out in the following manner:</strong>\n\n')
fprintf('<strong>processFNIRS2</strong>\n\t--<strong>Data</strong>\t\t\t\t\t*functions to manipulate individual fNIRS segments\n\t\t--ApplyChannelMask\t\t*Set bad channels to nan\n\t\t--GetMarkers\t\t\t*Function to find the timepoints of markers in a regex style\n\t\t--Resample\t\t\t\t*Function to resample or average fNIRS data (ex: 30s block average or convert to 1hz)\n\t\t--SetT0\t\t\t\t\t*Function to shift the fNIRS time to match start of experiment t=0\n\t\t--Split\t\t\t\t\t*Functino to split fNIRS segment based on different input times\n\t--<strong>GUI</strong>\t\t\t\t\t*Shortcut for accessing the GUI\n\t--<strong>Help</strong>\t\t\t\t\t*This!\n\t--<strong>Import</strong>\t\t\t\t*Functions to import fNIRS files\n\t\t--ImportHitachiMES\t\t*Import Hitachi Probes\n\t\t--ImportNIRx\t\t\t*Import NIRx files\n\t\t--ImportNIR\t\t\t\t*Import fNIR Devices/Biopac files\n\t\t--ImportSampleData\t\t*Import some sample data included here\n\t--<strong>Methods</strong>\t\t\t\t*Functions to change and modify processing methods\n\t\t--Oxy\t\t\t\t\t*Oxy conversion pipeline methods\n\t\t\t--ConfigureMethods\t\t*GUI to edit functions in Oxy pipeline\n\t\t\t--ImportMethods\t\t\t*Import pre-existing methods from a file\n\t\t\t--List\t\t\t\t\t*List currently loaded methods\n\t\t\t--SetMethod\t\t\t\t*Select a method based on name or method number\n\t\t--Raw\t\t\t\t*Oxy conversion pipeline methods\n\t\t\t--ConfigureMethods\t\t*GUI to edit functions in Oxy pipeline\n\t\t\t--ImportMethods\t\t\t*Import pre-existing methods from a file\n\t\t\t--List\t\t\t\t\t*List currently loaded methods\n\t\t\t--SetMethod\t\t\t\t*Select a method based on name or method number\n\t--<strong>Process</strong>\t\t\t\t*Process fNIR segment data\n\t\t--ProcessOxy\t\t\t*Run the Oxy Pipeline only (raw must be run first)\n\t\t--ProcessRaw\t\t\t*Run the Raw Pipeline only\n\t--<strong>Settings</strong>\t\t\t\t*Change settings related to processing\n\t\t--Baseline\t\t\t\t*Change baseline time settings\n\t\t--DPF\t\t\t\t\t*Change mode of Differential Path Length (DPF)\n\t\t\t--SetFixedDFP\t\t\t*Change to fixed distance factor\n\t\t\t--SetDPFmode\t\t\t\t* Set to ''none'',''fixed'', or ''calc''\n\t\t--SelectDevice\t\t*Forcibly reload device settings for FNIRS probe\n\t\t\n\t\t\n\t');

fprintf('\n\nPress Any Key to continue...\n\n\n')
pause;

fprintf('<strong>Lastly...</strong>\n');
fprintf('\nPlease be sure to add the matlab path the main folder (processFNIRS2) and the folders named:');
fprintf(2,'\n\t base_functions, GUI, and functions\n');
fprintf('Folders with + signs in front of the name do not need to be included\n');

fprintf('\nbase_functions and GUI contain functions related to the operation of processFNIRS2\n');
fprintf('\nfunctions contains the functions used in the processFNIRS2 method pipelines, \nbut you may use any matlab functions in a pipeline if you add the function to your method\n');

fprintf('\n');


fprintf('Loaded functions and methods are stored in the matlab preference directory\n');
fprintf('You may find these settings using the matlab command: prefdir');
fprintf('\nIf you are having trouble loading processFNIRS2, delete these files and try again\n');

fprintf('\n');
fprintf('\nprocessFNIRS2 is free for academic and non-commercial use, but some included code may have other lisences\n');
fprintf('(c)2019\n');
fprintf('Contact Adrian Curtin for more information at abc48@drexel.edu\n');



