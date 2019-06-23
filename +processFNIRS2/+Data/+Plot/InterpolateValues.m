function [ imgOut ] = InterpolateValues(fNIR,data2plot,minVal,maxVal,bufferMult,titleString,clrBarTitle)
%processFNIRS2.Data.Plot.ImageValues
%
% Uses an imagemap to change the color of each cell based on data2plot
%
if(nargin<7)
    clrBarTitle='';
end

if(nargin<6)
   titleString=''; 
end

if(nargin<5)
    bufferMult=1;
else
    bufferMult=round(bufferMult);
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

OptPosX=probeInfo.OptPosX(~probeInfo.IsShortSeparation);
OptPosY=probeInfo.OptPosY(~probeInfo.IsShortSeparation);

maxPosX=nanmax(OptPosX);
maxPosY=nanmax(OptPosY);
minPosX=nanmin(OptPosX);
minPosY=nanmin(OptPosY);
optDiffX=abs(OptPosX(1)-OptPosX(2:end));
optDiffY=abs(OptPosY(1)-OptPosY(2:end));
OptDistX=nanmin(optDiffX(optDiffX>0));
OptDistY=nanmin(optDiffY(optDiffY>0));

OptDistX=round(OptDistX,5);
OptDistY=round(OptDistY,5);

dimX=maxPosX-minPosX;
dimY=maxPosY-minPosY;

maxDim=max([dimX,dimY]);
maxDimDist=round(maxDim/OptDistX)*OptDistX;


bufferSize=bufferMult*OptDistX;
pixelPerCm=imgSize/max([dimX+bufferSize*2,dimY+bufferSize*2]);

optDataSize=10;

optPosX=probeInfo.OptPosX-minPosX;
optPosY=probeInfo.OptPosY-minPosY;


buffer=bufferSize*pixelPerCm/2;

if(OptDistX==OptDistY)
    [inpX,inpY]=meshgrid(0:OptDistX*pixelPerCm:(maxDimDist+bufferSize*2)*pixelPerCm);
else
    
    error('Haven''t accoutned for this yet');
end

interpBuffer=ones(size(inpX))*minVal;
alphaBuffer=ones(size(inpX))*-1;

numRows=size(inpY,1);

for optIdx=1:length(data2plot)
    optNum=probeInfo.ChannelList(optIdx);
    optXidx(optIdx)=round(OptPosX(optNum)/OptDistX+bufferMult+1);
    optYidx(optIdx)=round(OptPosY(optNum)/OptDistY+bufferMult+1);
    if(~isnan(data2plot(optIdx))&&data2plot(optIdx)>minVal)
        interpBuffer(optYidx(optIdx),optXidx(optIdx))=data2plot(optIdx);
        alphaBuffer(optYidx(optIdx),optXidx(optIdx))=1;
    else
        interpBuffer(optYidx(optIdx),optXidx(optIdx))=data2plot(optIdx);
    end
    mrkLbl{optIdx}=num2str(optNum);
end



%interpBuffer=interpBuffer(end:-1:1,:);
%alphaBuffer=alphaBuffer(end:-1:1,:);

[Xq,Yq] = meshgrid(1:imgSize);



intArr=interp2(inpX,inpY,interpBuffer,Xq,Yq,'spline',minVal);%,method,extrapval)
intArrAlpha=interp2(inpX,inpY,alphaBuffer,Xq,Yq,'cubic',-1);%,method,extrapval)
intArrLinear=interp2(inpX,inpY,alphaBuffer,Xq,Yq,'linear',-1);%,method,extrapval)

intArrAlpha(intArrAlpha<0)=0;
intArrAlpha(intArrLinear<0)=0;

x2keep=round([inpX(1,min(optXidx)-bufferMult)+1,inpX(1,max(optXidx)+bufferMult)]);
y2keep=round([inpY(min(optYidx)-bufferMult,1)+1,inpY(max(optYidx)+bufferMult,1)]);

optPos2Plot=round([inpX(1,optXidx);inpX(1,optYidx)]);


intArr2plot=intArr(y2keep(1):y2keep(2),(x2keep(1)):x2keep(2));
intArrAlpha=intArrAlpha(y2keep(1):y2keep(2),(x2keep(1)):x2keep(2));
intArrAlpha(intArrAlpha==0)=0;

imgFinal=imagesc(intArr,[minVal,maxVal]);

imgFinal=imagesc(intArr2plot,[minVal,maxVal]);
set(gca,'xtick',[]);
set(gca,'ytick',[]);
imgFinal.AlphaData=intArrAlpha;
imgFinal.AlphaDataMapping='scaled';

hold on

plot(optPos2Plot(1,:)/1.01+1,optPos2Plot(2,:)/1.01+1,'O','MarkerSize',15,'LineWidth',3,'color','black', 'MarkerFaceColor', 'k');
for optIdx=1:length(data2plot)
    text(optPos2Plot(1,optIdx)/1.01+1,optPos2Plot(2,optIdx)/1.01+1,mrkLbl{optIdx},'FontSize',10,'HorizontalAlignment', 'center','color','white');
end

ch=colorbar();
hold off
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
