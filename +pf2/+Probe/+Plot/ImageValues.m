function [ imgOut ] = ImageValues(varargin)
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
%   data = pf2.Import.SampleData.fNIR2000();
%   processed = processFNIRS2(data);
%   meanHbO = mean(processed.HbO, 1);
%   pf2.Probe.Plot.ImageValues(meanHbO, processed, [], [], 'Mean HbO', 'uM');
%
%   % Display p-values with custom range
%   pvals = rand(1, 18) * 0.1;
%   pf2.Probe.Plot.ImageValues(pvals, processed, 0, 0.05, 'P-values');
%
% See also: pf2.Probe.Plot.ArrangedValues, pf2.Probe.Plot.InterpolateValues,
%           pf2.Probe.Plot.ImageROIvalues, pf2.Data.Plot.Oxy

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
titleString = p.Results.titleString;
minVal = p.Results.minVal;
maxVal = p.Results.maxVal;
fNIR = p.Results.fNIR;
data2plot = p.Results.data2plot;

include_ss=p.Results.includeSS;


if(isempty(maxVal))
    maxVal=nanmax(data2plot);
end

if(isempty(minVal))
   minVal=nanmin(data2plot); 
end
probeInfo=[];

if(isempty(fNIR))
    global setF
end

if(isempty(fNIR)&&isfield(setF,'device'))
    
    cfgFilePath=setF.device.cfg.File;
    if(~isfield(setF.device.Probe{1},'OptLayout2D'))
        probeInfo=pf2_base.loadDeviceCfg(cfgFilePath,true);
        setF.device=probeInfo;
    else
       probeInfo=setF.device; 
    end
elseif(pf2_base.isnestedfield(fNIR,'info.probename')&&isfield(fNIR.info,'probename')&&~contains(fNIR.info.probename,'Unknown')) 
    %try to load the probename cfg file
    cfgFilePath=sprintf('%s.cfg',fNIR.info.probename);
else
    cfgFilePath='';
end

if(isempty(probeInfo))
    if(isempty(cfgFilePath)||~contains(cfgFilePath,'.cfg'))

        warning('Missing or invalid configuration file path\n')

        disp('No device specified. Please load device configuration');
        probeInfo=pf2_base.loadDeviceCfg([],true);
        if(~isempty(probeInfo))
            error('No valid devices selected');
        end

    elseif(~isempty(cfgFilePath)) % If we're not looking at the GUI, doesn't matter
        probeInfo=pf2_base.loadDeviceCfg(cfgFilePath,true);
    end
end

if(pf2_base.isnestedfield(probeInfo,'Probe'))
    deviceInfo=probeInfo.Info;
    if(~isfield(deviceInfo,'numberProbes')||deviceInfo.numberProbes==1)
        probeNum=1;
    end
    probeInfo=probeInfo.Probe{probeNum};
else
   error('Unable to identify probe'); 
end

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

end
