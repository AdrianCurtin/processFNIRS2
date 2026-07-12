function fNIR=fNIR1200()
% FNIR1200 Load the bundled fNIR Devices fNIR1200 sample recording with markers
%
% Loads a continuous fNIR Devices fNIR1200 (16-channel) sample recording
% bundled with the toolbox. Unlike fNIR2000, this dataset carries event
% markers, making it the canonical choice for demonstrating block definition,
% epoch extraction, and trial averaging.
%
% Syntax:
%   data = pf2.import.sampleData.fNIR1200()
%   pf2.import.sampleData.fNIR1200()
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
%   % Import a marker-bearing recording and inspect onsets
%   data = pf2.import.sampleData.fNIR1200();
%   times = pf2.data.getMarkers(data, 50);
%
% See also: pf2.import.sampleData, pf2.import.sampleData.fNIR2000,
%           pf2.import.importNIR, pf2.data.defineBlocks

[filepath]=mfilename('fullpath');

slashes=find(filepath'=='/'|filepath'=='\');
filepath=filepath(1:slashes(end)); %strip filename

nirfilepath=sprintf('%s../../../sampledata/sampleNIR.nir',filepath);
mrkfilepath=sprintf('%s../../../sampledata/sampleNIR.mrk',filepath);

if(nargout>0)
	fNIR=pf2.import.importNIR(nirfilepath,mrkfilepath,false); % just load data
else
	fNIR=pf2.import.importNIR(nirfilepath,mrkfilepath,true); % show GUI
end