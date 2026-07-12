function fNIR=Hitachi_ETG4000_3x11()
% HITACHI_ETG4000_3X11 Load the bundled Hitachi ETG-4000 3x11 sample recording
%
% Loads a Hitachi ETG-4000 optical topography sample recording acquired with
% a 3x11 probe array (104 raw channels), bundled with the toolbox. Useful for
% demonstrating the Hitachi MES import path and larger probe-specific layouts.
%
% Syntax:
%   data = pf2.import.sampleData.Hitachi_ETG4000_3x11()
%   pf2.import.sampleData.Hitachi_ETG4000_3x11()
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
%   % Import and process a Hitachi 3x11 recording
%   data = pf2.import.sampleData.Hitachi_ETG4000_3x11();
%   processed = processFNIRS2(data);
%
% See also: pf2.import.sampleData, pf2.import.sampleData.Hitachi_ETG4000_3x5,
%           pf2.import.importHitachiMES

[filepath]=mfilename('fullpath');

slashes=find(filepath'=='/'|filepath'=='\');
filepath=filepath(1:slashes(end)); %strip filename

nirfilepath=sprintf('%s../../../sampledata/sample_MES_Probe2.csv',filepath);

if(nargout>0)
	fNIR=pf2.import.importHitachiMES(nirfilepath,[],false); % just load data
else
	fNIR=pf2.import.importHitachiMES(nirfilepath,[],true); % show GUI
end