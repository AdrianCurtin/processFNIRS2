function fNIR=fNIR2000()
% FNIR2000 Load the bundled fNIR Devices fNIR2000 sample recording
%
% Loads a continuous fNIR Devices fNIR2000 (18-channel, with short-separation
% channels) sample recording bundled with the toolbox. The bundled .nir file
% has no usable event markers, so a deterministic two-condition block design
% is synthesized and attached so the recording can also demonstrate block
% averaging, GLM, and event-related workflows out of the box. The markers
% alternate between codes 1 ('TaskA') and 2 ('TaskB') in fixed 20 s blocks,
% and a matching marker dictionary is stored at info.markerDict.
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
%          .markers is a canonical table of the synthesized block onsets and
%          .info.markerDict maps codes 1/2 to 'TaskA'/'TaskB'.
%
% Example:
%   % Import, process, and plot a topographic map
%   data = pf2.import.sampleData.fNIR2000();
%   processed = processFNIRS2(data);
%   pf2.probe.plot.topo(processed, 'HbO');
%
%   % Block-average the synthesized TaskA condition (code 1)
%   blocks   = pf2.data.defineBlocks(processed, 1, 20, 'Embed', false);
%   segments = pf2.data.extractBlocks(processed, blocks, 'PreTime', 5, ...
%       'PostTime', 20, 'SetT0', true);
%   ga = pf2.data.blockAverage(segments);
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

% The bundled .mrk carries only COBI header/config and no event rows, so the
% recording loads with an empty markers table. Synthesize a deterministic
% two-condition block design (codes 1='TaskA', 2='TaskB') so this dataset can
% also exercise block-averaging / GLM / event-related workflows.
fNIR.markers = buildSampleMarkers(fNIR.time);
fNIR = pf2.data.setMarkerDict(fNIR, {1, 'TaskA'; 2, 'TaskB'});

end

function mrk = buildSampleMarkers(time)
% Build an alternating 2-condition block design over the recording span.
%   Codes  : 1 (TaskA), 2 (TaskB), alternating
%   Onsets : every 40 s starting 30 s in (20 s block + 20 s rest)
%   Block  : 20 s duration, unit amplitude
blockDur = 20;     % block (event) duration, seconds
cycle    = 40;     % onset-to-onset spacing, seconds
firstOn  = 30;     % first onset, seconds into the recording
tail     = 20;     % keep the last block clear of the recording end

tEnd   = time(end);
onsets = (firstOn:cycle:(tEnd - blockDur - tail))';
codes  = mod(0:numel(onsets)-1, 2)' + 1;          % 1,2,1,2,...
mrk    = pf2_base.normalizeMarkers( ...
    [onsets, codes, repmat(blockDur, numel(onsets), 1)]);
end
