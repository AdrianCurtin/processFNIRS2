function [ figHandle ] = ArrangedValues(varargin)
%pf2.Data.Plot.ArrangedValues
%
% Uses an imagemap to change the color of each cell based on data2plot
%
% ArrangedValues(fNIR,data2plot,minVal,maxVal,suptitleString,clrBarTitle)

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

if(pf2_base.isnestedfield(fNIR,'info.probename')&&isfield(fNIR.info,'probename')&&~contains(fNIR.info.probename,'Unknown')) 
    %try to load the probename cfg file
    cfgFilePath=sprintf('%s.cfg',fNIR.info.probename);
else
    cfgFilePath='';
end


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

if(pf2_base.isnestedfield(probeInfo,'Probe'))
    deviceInfo=probeInfo.Info;
    if(~isfield(deviceInfo,'numberProbes')||deviceInfo.numberProbes==1)
        probeNum=1;
    end
    probeInfo=probeInfo.Probe{probeNum};
else
   error('Unable to identify probe'); 
end


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
