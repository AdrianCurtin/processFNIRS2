function fNIR=sampleData()
% SAMPLEDATA Load a bundled example fNIRS dataset for testing/tutorials.
%
%   data = pf2.import.sampleData()      % Default fNIR Devices sample recording
%
% Returns a ready-to-process data struct (raw, time, fs, fchMask, markers,
% info, device) so you can try the toolbox without supplying your own file:
%
%   data = pf2.import.sampleData();
%   processed = processFNIRS2(data);
%   pf2.data.plot.oxy(processed);
%
% Additional named datasets are available as functions in the sampleData
% namespace (call with parentheses):
%
%   pf2.import.sampleData.fNIR2000()            % fNIR Devices fNIR2000
%   pf2.import.sampleData.fNIR1200()            % fNIR Devices fNIR1200
%   pf2.import.sampleData.experiment()          % Multi-condition experiment
%   pf2.import.sampleData.Hitachi_ETG4000_3x5() % Hitachi ETG-4000 (3x5)
%   pf2.import.sampleData.Hitachi_ETG4000_3x11()% Hitachi ETG-4000 (3x11)
%
% With no output argument the GUI is shown; with an output it loads headless.
%
% See also: processFNIRS2, pf2.import.importNIR

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