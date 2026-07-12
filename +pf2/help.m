function help()
% HELP Print a getting-started overview for processFNIRS2 to the console
%
% Displays the toolbox version followed by a guided walkthrough of the
% typical workflow: importing data, configuring and selecting raw/oxy
% processing methods, and running the three-stage processing pipeline. Use
% this as a first stop when getting oriented in the toolbox.
%
% Syntax:
%   pf2.help()
%
% Inputs:
%   None
%
% Outputs:
%   None. The overview is printed to the command window.
%
% Example:
%   % Show the getting-started overview
%   pf2.help();
%
% See also: processFNIRS2, pf2.methods, pf2.process, pf2.import.importNIR

[~,vers]=pf2_base.pf2version();
fprintf('<strong>Welcome to processFNIRS2 %s</strong>\n',vers);

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

fprintf('This is generally done in three stages\n\n');

fprintf('\t<strong>1) Import Data</strong>\n');
fprintf('\t\tImport your data using pf2.import.importNIR (or other function)\n');
fprintf('\t\tLoad your data using the function as a string or select the file yourself\n');
fprintf(2,'\t\tex: mydata = pf2.import.importNIR(''myNIRSfile.nir'')\n');
fprintf('\n');

fprintf('\t<strong>2) Set Methods</strong>\n');
fprintf('\t\tSelect a method for both Raw and Oxy domain processing\n');
fprintf('\t\tYou can visualize the effects of your methods by using processFNIRS2(mydata)\n');
fprintf('\t\tand configure your methods by using pf2.methods.oxy/Raw.configureMethods\n');
fprintf('\t\tSelecting methods is easy, you can select a method using either the method name,\n');
fprintf('\t\tOr selecting the method interactively\n');
fprintf('\t\tPlease note that both the Raw method is applied first and then the Oxy method\n');
fprintf(2,'\t\tex: pf2.methods.raw.setMethod(''MyMethodName'')\n');
fprintf(2,'\t\tex: pf2.methods.oxy.setMethod(''MyMethodName'')\n');
fprintf('\n');

fprintf('\t<strong>3) Process Data</strong>\n');
fprintf('\t\tRun your processing method on your data using processFNIRS2(mydata)\n');
fprintf('\t\tYou can optionally process only the oxy or raw domain signals using pf2.process.processRaw/processOxy\n');
fprintf('\t\tHowever the default function will run both Raw and Oxy pipelines\n');
fprintf(2,'\t\tex: myprocesseddata = processFNIRS2(mydata)\n');
fprintf('\n');

fprintf('\t<strong>4) Visualize and Export</strong>\n');
fprintf('\t\tVisualize your data using the Plot functions\n');
fprintf(2,'\t\tex: pf2.data.plot.oxy(myprocesseddata)\n');
fprintf(2,'\t\tex: pf2.data.plot.roi(myprocesseddata)\n');
fprintf('\t\tExport your data to different file formats\n');
fprintf(2,'\t\tex: pf2.export.asNIR(myprocesseddata, ''myexport.nir'')\n');
fprintf(2,'\t\tex: pf2.export.asSNIRF(myprocesseddata, ''myexport.snirf'')\n');

fprintf('\n');

fprintf('<strong>pf2 API Structure:</strong>\n\n')
fprintf('<strong>pf2</strong>\n');
fprintf('\t--<strong>data</strong>\t\t\t\t\t*functions to manipulate individual fNIRS segments\n');
fprintf('\t\t--applyChannelMask\t\t*Set bad channels to nan\n');
fprintf('\t\t--getMarkers\t\t\t*Find timepoints of markers (regex style)\n');
fprintf('\t\t--resample\t\t\t\t*Resample or average fNIRS data\n');
fprintf('\t\t--setT0\t\t\t\t\t*Shift fNIRS time to match start of experiment\n');
fprintf('\t\t--split\t\t\t\t\t*Split fNIRS segment based on time points\n');
fprintf('\t\t--<strong>plot</strong>\t\t\t\t*Functions to visualize fNIRS data\n');
fprintf('\t\t\t--auxData\t\t\t*Plot auxiliary data channels\n');
fprintf('\t\t\t--oxy\t\t\t\t*Plot oxygenation data\n');
fprintf('\t\t\t--roi\t\t\t\t*Plot Region of Interest data\n');
fprintf('\t\t\t--raw\t\t\t\t*Plot raw intensity data\n');
fprintf('\t--<strong>export</strong>\t\t\t\t*Functions to export fNIRS data\n');
fprintf('\t\t--asNIR\t\t\t\t\t*Export to NIR file format\n');
fprintf('\t\t--asSNIRF\t\t\t\t*Export to SNIRF file format\n');
fprintf('\t--<strong>gui</strong>\t\t\t\t\t*Shortcut for accessing the GUI\n');
fprintf('\t--<strong>help</strong>\t\t\t\t\t*This help function\n');
fprintf('\t--<strong>import</strong>\t\t\t\t*Functions to import fNIRS files\n');
fprintf('\t\t--importHitachiMES\t\t*Import Hitachi Probes\n');
fprintf('\t\t--importNIRX\t\t\t*Import NIRx files\n');
fprintf('\t\t--importNIR\t\t\t\t*Import fNIR Devices/Biopac files\n');
fprintf('\t\t--importSNIRF\t\t\t*Import SNIRF format files\n');
fprintf('\t\t--sampleData\t\t\t*Load sample data included with toolbox\n');
fprintf('\t--<strong>methods</strong>\t\t\t\t*Functions to change processing methods\n');
fprintf('\t\t--oxy\t\t\t\t\t*Oxy conversion pipeline methods\n');
fprintf('\t\t\t--configureMethods\t*GUI to edit functions in Oxy pipeline\n');
fprintf('\t\t\t--importMethods\t\t*Import pre-existing methods from a file\n');
fprintf('\t\t\t--list\t\t\t\t*List currently loaded methods\n');
fprintf('\t\t\t--setMethod\t\t\t*Select a method by name or number\n');
fprintf('\t\t--raw\t\t\t\t\t*Raw domain pipeline methods\n');
fprintf('\t\t\t--configureMethods\t*GUI to edit functions in Raw pipeline\n');
fprintf('\t\t\t--importMethods\t\t*Import pre-existing methods from a file\n');
fprintf('\t\t\t--list\t\t\t\t*List currently loaded methods\n');
fprintf('\t\t\t--setMethod\t\t\t*Select a method by name or number\n');
fprintf('\t--<strong>process</strong>\t\t\t\t*Process fNIR segment data\n');
fprintf('\t\t--processOxy\t\t\t*Run the Oxy Pipeline only\n');
fprintf('\t\t--processRaw\t\t\t*Run the Raw Pipeline only\n');
fprintf('\t--<strong>probe</strong>\t\t\t\t\t*Probe geometry and ROI functions\n');
fprintf('\t\t--plot\t\t\t\t\t*Topographic visualization\n');
fprintf('\t\t--roi\t\t\t\t\t*Region of Interest definition\n');
fprintf('\t--<strong>settings</strong>\t\t\t\t*Change settings related to processing\n');
fprintf('\t\t--baseline\t\t\t\t*Change baseline time settings\n');
fprintf('\t\t--dpf\t\t\t\t\t*Change mode of Differential Path Length\n');
fprintf('\t\t\t--setFixedDPF\t\t*Set fixed distance factor\n');
fprintf('\t\t\t--setDPFmode\t\t*Set to ''none'', ''fixed'', or ''calc''\n');
fprintf('\t\t--selectDevice\t\t\t*Reload device settings for fNIRS probe\n');
fprintf('\n');

fprintf('<strong>Advanced Analysis: exploreFNIRS</strong>\n');
fprintf('For group-level analysis and advanced visualization, use the exploreFNIRS tool:\n');
fprintf('\tex: exploreFNIRS(myprocesseddata)\n');
fprintf('\tex: exploreFNIRS(myprocesseddata, ''timeShiftTo0'', true, ''blStart'', 0, ''blEnd'', 5)\n');
fprintf('exploreFNIRS provides statistical tools, visualization options, and data export:\n');
fprintf('\t- Temporal plots: exploreFNIRS.plot.temporal()\n');
fprintf('\t- Bar charts: exploreFNIRS.plot.barchart()\n');
fprintf('\t- Scatter plots: exploreFNIRS.plot.scatter()\n');
fprintf('\t- FDR correction: exploreFNIRS.fx.performFDR()\n');
fprintf('\t- Export data: exploreFNIRS.export.mergeGbyTablesWide() / mergeGbyTablesLong()\n\n');

fprintf('<strong>Installation and Setup</strong>\n');
fprintf('Add the main processFNIRS2 folder and the following subdirectories to your MATLAB path:\n');
fprintf(2,'\taddpath(''base_functions'', ''GUI'', ''functions'')\n');
fprintf('Package folders (+pf2, +pf2_base, etc.) are automatically available.\n\n');

fprintf('<strong>Configuration and Preferences</strong>\n');
fprintf('Loaded functions and methods are stored in the matlab preference directory\n');
fprintf('You may find these settings using the matlab command: prefdir\n');
fprintf('If you are having trouble loading processFNIRS2, delete these files and try again\n');

fprintf('\n');

fprintf('<strong>Troubleshooting Tips</strong>\n');
fprintf('1. When importing data for the first time, verify that the probe configuration is correct\n');
fprintf('2. If you get errors about DPF factors, check the settings using pf2.settings.dpf\n');
fprintf('3. For visualization issues, try running with default methods first\n\n');

fprintf('processFNIRS2 is free for academic and non-commercial use.\n');
fprintf('Some included third-party code may have other licenses.\n');
fprintf('Contact Dr. Adrian Curtin for more information at adrian.b.curtin@drexel.edu\n');
end
