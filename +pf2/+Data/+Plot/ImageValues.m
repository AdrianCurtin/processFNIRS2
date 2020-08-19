function [ imgOut ] = ImageValues(varargin)
%pf2.Data.Plot.ImageValues
%
% Uses an imagemap to change the color of each cell based on data2plot
%
% ImageValues(fNIR,data2plot,minVal,maxVal,titleString,clrBarTitle)

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

if(include_ss&&length(probeInfo.OptLayout2D_ss)>length(data2plot)&&length(probeInfo.OptLayout2D)==length(data2plot))
   include_ss=false;
   warning('Not enough data for all channels, ignoring short separation channels');
end

if(pf2_base.isnestedfield(probeInfo,'OptPos.subplot_layout_ss'))
	optLayout=probeInfo.OptPos.subplot_layout_ss;
elseif(pf2_base.isnestedfield(probeInfo,'OptPos.subplot_layout'))
	optLayout=probeInfo.OptPos.subplot_layout;
else
   plotArranged=false; 
end

if(include_ss)
    numOptodes=probeInfo.NumOptodes;
    channelList=probeInfo.ChannelList;
    optLayout=probeInfo.OptLayout2D_ss;
else
    numOptodes=probeInfo.NumOptodes-probeInfo.NumShortSeparation;
    channelList=probeInfo.ChannelList(~probeInfo.IsShortSeparation);
    optLayout=probeInfo.OptLayout2D;
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
