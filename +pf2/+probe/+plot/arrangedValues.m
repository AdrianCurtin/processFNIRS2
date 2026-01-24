function [ figHandle ] = arrangedValues(varargin)
% ARRANGEDVALUES Display per-channel values in probe-arranged subplot grid
%
% Creates a visualization where each fNIRS channel is displayed as a separate
% subplot positioned according to the probe layout geometry. Each subplot is
% colored according to the corresponding data value using an image colormap.
% This function is useful for displaying spatial distributions of channel-level
% metrics such as signal quality, statistical values, or averaged responses.
%
% Reference:
%   Internal pf2 implementation for probe-based visualization.
%
% Syntax:
%   ArrangedValues(data2plot)
%   ArrangedValues(data2plot, fNIR)
%   ArrangedValues(data2plot, fNIR, minVal, maxVal)
%   ArrangedValues(data2plot, fNIR, minVal, maxVal, titleString, clrBarTitle)
%   figHandle = ArrangedValues(...)
%   ArrangedValues(..., 'includeSS', false)
%
% Inputs:
%   data2plot   - Values to display for each channel [1 x C double]
%                 Must have one value per optode/channel in the probe.
%   fNIR        - fNIRS data structure containing probe info (default: {})
%                 If empty, attempts to load from global setF or prompts user.
%   minVal      - Minimum value for color scale (default: min(data2plot))
%   maxVal      - Maximum value for color scale (default: max(data2plot))
%   titleString - Title displayed above the plot (default: '')
%   clrBarTitle - Title for the colorbar (default: '')
%   'includeSS' - Include short separation channels (default: true)
%                 Set to false to exclude short separation channels.
%
% Outputs:
%   figHandle - Handle to the created figure (optional)
%
% Example:
%   % Display signal quality per channel
%   data = pf2.import.sampleData.fNIR2000();
%   processed = processFNIRS2(data);
%   snr = std(processed.HbO);
%   pf2.probe.plot.arrangedValues(snr, processed, [], [], 'SNR', 'Std Dev');
%
%   % Display t-statistics from analysis
%   tvals = randn(1, 18);  % Example t-values
%   pf2.probe.plot.arrangedValues(tvals, processed, -3, 3, 'T-Statistics');
%
% See also: pf2.probe.plot.imageValues, pf2.probe.plot.interpolateValues,
%           pf2.data.plot.oxy, pf2_base.pf2_plotArranged

p = inputParser;

isStructOrEmpty=@(x) isstruct(x)||isempty(x);
isStringOrChar=@(x)isstring(x)||ischar(x);

addRequired(p, 'data2plot');
addOptional(p, 'fNIR', {}, isStructOrEmpty);
addOptional(p, 'minVal', [], @isnumeric);
addOptional(p, 'maxVal', [], @isnumeric);
addOptional(p, 'titleString', '', isStringOrChar);
addOptional(p, 'clrBarTitle', '', isStringOrChar);

addParameter(p, 'includeSS', true, @islogical);

parse(p, varargin{:});

clrBarTitle = p.Results.clrBarTitle;
suptitleString = p.Results.titleString;
minVal = p.Results.minVal;
maxVal = p.Results.maxVal;
fNIR = p.Results.fNIR;
data2plot = p.Results.data2plot;

include_ss= p.Results.includeSS;

if(isempty(maxVal))
    maxVal=nanmax(data2plot);
end

if(isempty(minVal))
   minVal=nanmin(data2plot); 
end

% Load probe info using helper
probeInfo = pf2_base.plot.loadProbeInfo(fNIR, true);


if(include_ss&&size(probeInfo.OptPos,1)>length(data2plot)&&sum(~probeInfo.TableOpt.IsShortSeparation)==length(data2plot))   include_ss=false;
   warning('Not enough data for all channels, ignoring short separation channels');
end

if(include_ss)
    numOptodes=size(probeInfo.TableOpt,1);
    channelList=probeInfo.TableOpt.OptodeNum;
    optLayout=probeInfo.OptPos.subplot_layout_ss;
else
    numOptodes=sum(~probeInfo.TableOpt.IsShortSeparation);
    channelList=probeInfo.TableOpt.OptodeNum(~probeInfo.TableOpt.IsShortSeparation);
    optLayout=probeInfo.OptPos.subplot_layout;
end


if(length(data2plot)~=numOptodes)
    error('Must have a value for all optodes');
end


g=gcf;
clf(gcf);


h{length(data2plot)}= axes('Position',[0.90,0.05,0.045,0.9],'Box','on');

numClrValues=1000;
clrBarValues=minVal:(maxVal-minVal)/numClrValues:maxVal;
clrBarValues(end)=maxVal;

clrBarValues=clrBarValues(end:-1:1)';
imagesc(clrBarValues,[minVal,maxVal]);

caxis('manual')

numTicks=11;

ytickLocs=0:numClrValues/(numTicks-1):numClrValues;
ytickLocs(1)=0;
ytickLocs(end)=numClrValues;
ytickVals=ytickLocs/numClrValues*(maxVal-minVal)+minVal;
ytickLocs(1)=1;
ytickVals(end)=maxVal;
ytickLocs(end)=numClrValues-numClrValues/numTicks*0.05;
ytickVals=ytickVals(end:-1:1);

ytickLocs=round(ytickLocs);

yticks(ytickLocs);
clrBarTickLabels=cell(1,numTicks);
for i=1:numTicks
   clrBarTickLabels{i}=sprintf('%.2f', ytickVals(i));
end
yticklabels(clrBarTickLabels');
set(gca,'YAxisLocation','right');
set(gca,'xtick',[]);

if(~isempty(clrBarTitle))
    title(clrBarTitle);
end




h=cell(0);
for(optIdx=1:length(data2plot))
    optNum=channelList(optIdx);

	optPos=optLayout{optNum};
    
    optPos([2])=1-optPos([2])-optPos([4]); %flips y vertical axis
    optPos([3,4])=optPos([3,4]).*[0.8,0.9];
    
    optPos([1])=optPos([1])+0.01;
    optPos([1])=optPos([1])/1.15;
    h{optIdx}= axes('Position',optPos,'Box','on');
    
%     gh=gcf();
%     dcm_obj=datacursormode(gh);
%     set(dcm_obj,'DisplayStyle','datatip',...
%         'SnapToDataVertex','off','Enable','on');
%     set(dcm_obj,'UpdateFcn', @myupdatefcn);
    

   
    if(~isnan(data2plot(optIdx)))
        imagesc(data2plot(optIdx));
         caxis('manual')
        caxis([minVal,maxVal]);
        axis off
    end
    title(sprintf('Opt %i',optNum));
    
end

if(~isempty(suptitleString))
    suptitle(suptitleString);
end

end
