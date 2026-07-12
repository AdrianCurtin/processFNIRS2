function fNIR=sampleData()
% SAMPLEDATA Load a bundled example fNIRS dataset for testing/tutorials
%
% Loads the default bundled fNIR Devices sample recording (fNIR1200, with
% event markers) so you can try the toolbox without supplying your own file.
% Returns a ready-to-process data struct. Additional named datasets are
% available as sibling functions in the sampleData namespace (call with
% parentheses), each covering a different device or workflow stage.
%
% Syntax:
%   data = pf2.import.sampleData()                % default fNIR1200 recording
%   pf2.import.sampleData()                        % show channel-check GUI
%   pf2.import.sampleData.fNIR2000()               % fNIR Devices fNIR2000
%   pf2.import.sampleData.fNIR1200()               % fNIR Devices fNIR1200
%   pf2.import.sampleData.experiment()             % multi-condition experiment
%   pf2.import.sampleData.group()                  % grouped Experiment object
%   pf2.import.sampleData.Hitachi_ETG4000_3x5()    % Hitachi ETG-4000 (3x5)
%   pf2.import.sampleData.Hitachi_ETG4000_3x11()   % Hitachi ETG-4000 (3x11)
%
% Inputs:
%   (none)
%
% Outputs:
%   fNIR - fNIRS data struct (.raw, .time, .fs, .fchMask, .markers, .info,
%          .device) ready to pass to processFNIRS2. With no output argument
%          the channel-check GUI is shown; with an output it loads headless.
%
% Example:
%   % Import, process, and plot the sample recording
%   data = pf2.import.sampleData();
%   processed = processFNIRS2(data);
%   pf2.data.plot.oxy(processed);
%
% See also: processFNIRS2, pf2.import.importNIR,
%           pf2.import.sampleData.fNIR2000, pf2.import.sampleData.experiment

[filepath]=mfilename('fullpath');

slashes=find(filepath'=='/'|filepath'=='\');
filepath=filepath(1:slashes(end)); %strip filename

nirfilepath=sprintf('%s../../sampledata/sampleNIR.nir',filepath);
mrkfilepath=sprintf('%s../../sampledata/sampleNIR.mrk',filepath);

if(nargout>0)
	fNIR=pf2.import.importNIR(nirfilepath,mrkfilepath,false); % just load data
else
	fNIR=pf2.import.importNIR(nirfilepath,mrkfilepath,true); % show GUI
end