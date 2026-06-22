function fNIR=fNIR2000()
% FNIR2000 Load the bundled fNIR Devices fNIR2000 sample recording
%
% Loads a continuous fNIR Devices fNIR2000 (18-channel, with short-separation
% channels) sample recording bundled with the toolbox. This dataset has NO
% event markers, so it is best suited for demonstrating import, processing,
% and topographic plotting rather than block averaging. For a marker-bearing
% recording use pf2.import.sampleData (fNIR1200) instead.
%
% Syntax:
%   data = pf2.import.sampleData.fNIR2000()
%   pf2.import.sampleData.fNIR2000()
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
%   % Import, process, and plot a topographic map
%   data = pf2.import.sampleData.fNIR2000();
%   processed = processFNIRS2(data);
%   pf2.probe.plot.topo(processed, 'HbO');
%
% See also: pf2.import.sampleData, pf2.import.sampleData.fNIR1200,
%           pf2.import.importNIR, processFNIRS2

[filepath]=mfilename('fullpath');

slashes=find(filepath'=='/'|filepath'=='\');
filepath=filepath(1:slashes(end)); %strip filename

nirfilepath=sprintf('%s../../../sampledata/sampleNIR_ss.nir',filepath);
mrkfilepath=sprintf('%s../../../sampledata/sampleNIR_ss.mrk',filepath);

if(nargout>0)
	fNIR=pf2.import.importNIR(nirfilepath,mrkfilepath,false); % just load data
else
	fNIR=pf2.import.importNIR(nirfilepath,mrkfilepath,true); % show GUI
end