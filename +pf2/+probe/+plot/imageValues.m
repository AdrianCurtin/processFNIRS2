function [ imgOut ] = imageValues(varargin)
% IMAGEVALUES Display per-channel values as a 2D image heatmap
%
% Creates a 2D image visualization where each fNIRS channel position is filled
% with a color corresponding to its data value. Channel positions are mapped
% to a grid image based on probe layout, creating a rectangular heatmap
% representation of the channel data. This is useful for creating publication-
% ready topographic plots of channel-level metrics.
%
% Reference:
%   Internal pf2 implementation for probe-based visualization.
%
% Syntax:
%   ImageValues(data2plot)
%   ImageValues(data2plot, fNIR)
%   ImageValues(data2plot, fNIR, minVal, maxVal)
%   ImageValues(data2plot, fNIR, minVal, maxVal, titleString, clrBarTitle)
%   imgOut = ImageValues(...)
%   ImageValues(..., 'includeSS', false)
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
%   imgOut - Handle to the image object (optional)
%
% Example:
%   % Display mean HbO values as heatmap
%   data = pf2.import.sampleData.fNIR2000();
%   processed = processFNIRS2(data);
%   meanHbO = mean(processed.HbO, 1);
%   pf2.probe.plot.imageValues(meanHbO, processed, [], [], 'Mean HbO', 'uM');
%
%   % Display p-values with custom range
%   pvals = rand(1, 18) * 0.1;
%   pf2.probe.plot.imageValues(pvals, processed, 0, 0.05, 'P-values');
%
% See also: pf2.probe.plot.arrangedValues, pf2.probe.plot.interpolateValues,
%           pf2.probe.plot.imageROIvalues, pf2.data.plot.oxy

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
addParameter(p, 'savePath', '', @(x) ischar(x) || isstring(x));
addParameter(p, 'saveWidth', [], @(x) isempty(x) || isnumeric(x));
addParameter(p, 'saveHeight', [], @(x) isempty(x) || isnumeric(x));
addParameter(p, 'saveDPI', 150, @isnumeric);

parse(p, varargin{:});

clrBarTitle = p.Results.clrBarTitle;
titleString = p.Results.titleString;
minVal = p.Results.minVal;
maxVal = p.Results.maxVal;
fNIR = p.Results.fNIR;
data2plot = p.Results.data2plot;

include_ss=p.Results.includeSS;
savePath = p.Results.savePath;
saveWidth = p.Results.saveWidth;
saveHeight = p.Results.saveHeight;
saveDPI = p.Results.saveDPI;


if(isempty(maxVal))
    maxVal=nanmax(data2plot);
end

if(isempty(minVal))
   minVal=nanmin(data2plot);
end

% Load probe info using helper
probeInfo = pf2_base.plot.loadProbeInfo(fNIR, true);

if(include_ss&&size(probeInfo.OptPos,1)>length(data2plot)&&sum(~probeInfo.TableOpt.IsShortSeparation)==length(data2plot))
   include_ss=false;
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
% 
% clf(gcf);
% 
% h{1}= axes('Position',[0.05,0.05,0.9,0.9],'Box','on');

g=gcf;
clf(gcf);


imgSize=1000;
imgData=nan(imgSize,imgSize);




for(optIdx=1:length(data2plot))
    optNum=channelList(optIdx);

    optPos=optLayout{optNum};

    optPos([2])=1-optPos([2])-optPos([4]); %flips y vertical axis
    
    x1=round(optPos(1)*imgSize);
    y1=round(optPos(2)*imgSize);
    x2=round(optPos(3)*imgSize+x1);
    y2=round(optPos(4)*imgSize+y1);
    
    if(~isnan(data2plot(optIdx)))
    	imgData(y1:y2,x1:x2)=data2plot(optIdx);
    end
end
imgData=imgData(end:-1:1,:);

imgFinal=imagesc(imgData,[minVal,maxVal]);
set(gca,'xtick',[]);
set(gca,'ytick',[]);
imgFinal.AlphaData=~isnan(imgData);
imgFinal.AlphaDataMapping='scaled';

ch=colorbar();

if(~isempty(clrBarTitle))
set(get(ch,'title'),'string',clrBarTitle);
end


axis off


if(nargout>0)
    imgOut=imgFinal;
end

if(~isempty(titleString))
    title(titleString);
end

% Save figure if requested
if ~isempty(savePath)
    fig = gcf();
    pf2_base.plot.saveFigure(fig, savePath, saveWidth, saveHeight, saveDPI);
end

end
