function [ imgOut ] = ImageValues(fNIR,data2plot,minVal,maxVal,titleString,clrBarTitle)
%processFNIRS2.Data.Plot.ImageValues
%
% Uses an imagemap to change the color of each cell based on data2plot
%
if(nargin<6)
    clrBarTitle='';
end

if(nargin<5)
   titleString=''; 
end

if(nargin<4||isempty(maxVal))
    maxVal=nanmax(data2plot);
end

if(nargin<3||isempty(minVal))
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

if(length(data2plot)~=probeInfo.NumOptodes)
    error('Must have a value for all optodes');
end




h{1}= axes('Position',[0.05,0.05,0.9,0.9],'Box','on');

imgSize=1000;
imgData=nan(imgSize,imgSize);

for(optIdx=1:length(data2plot))
    optNum=probeInfo.ChannelList(optIdx);

    optPos=probeInfo.OptLayout2D{optNum};

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
