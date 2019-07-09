function [ imgOut,optPos2Plot ] = InterpolateValues(fNIR,data2plot,minVal,maxVal,bufferMult,titleString,clrBarTitle)
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

if(nargin<4)
    maxVal=nanmax(data2plot);
end

if(nargin<3||isempty(minVal))
   minVal=nanmin(data2plot); 
end

cla


if(length(minVal)==2&&sum(minVal>0)==1&&isempty(maxVal))  %% expects two minimum values
    twosided=true; 
    minVal=sort(minVal);
    maxVal(1)=nanmax(data2plot(:));
    maxVal(2)=nanmin(data2plot(:));
    
    if(maxVal(2)>=minVal(1))
        twosided=false;
        minVal=minVal(2);
        maxVal=maxVal(1);
    elseif(maxVal(1)<=minVal(2))
        twosided=false;
        temp=minVal;
        minVal=maxVal(2);
        maxVal=temp(1);
    end
    
else
    twosided=false;
end

if(isempty(fNIR))
    global setF
end

probeInfo=[];

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

if(~isempty(probeInfo))

elseif(isempty(cfgFilePath)||~contains(cfgFilePath,'.cfg'))
    
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

%clf(gcf)


%h{1}= axes('Position',[0.05,0.05,0.9,0.9],'Box','on');

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

if(~twosided)
    interpBuffer=ones(size(inpX))*minVal;
else
    interpBuffer=zeros(size(inpX));
end


alphaBuffer=ones(size(inpX))*-1;

if(twosided)
    alphaBufferNeg=alphaBuffer;
end

numRows=size(inpY,1);

for optIdx=1:length(data2plot)
    optNum=probeInfo.ChannelList(optIdx);
    optXidx(optIdx)=round(OptPosX(optNum)/OptDistX+bufferMult+1);
    optYidx(optIdx)=round(OptPosY(optNum)/OptDistY+bufferMult+1);
    
    if(~twosided&&~isnan(data2plot(optIdx))&&((data2plot(optIdx)>=minVal&&maxVal>minVal)||...
            (data2plot(optIdx)<=(maxVal*-1)&&minVal>maxVal)))
        interpBuffer(optYidx(optIdx),optXidx(optIdx))=data2plot(optIdx);
        alphaBuffer(optYidx(optIdx),optXidx(optIdx))=1;
        alphaBufferNeg(optYidx(optIdx),optXidx(optIdx))=-1;
    elseif(twosided&&~isnan(data2plot(optIdx))&&data2plot(optIdx)<=minVal(1))
        interpBuffer(optYidx(optIdx),optXidx(optIdx))=data2plot(optIdx);
        alphaBufferNeg(optYidx(optIdx),optXidx(optIdx))=1;
        alphaBuffer(optYidx(optIdx),optXidx(optIdx))=-1;
    elseif(twosided&&~isnan(data2plot(optIdx))&&data2plot(optIdx)>=minVal(2))
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


intArr=interp2(inpX,inpY,interpBuffer,Xq,Yq,'spline',minVal(end));%,method,extrapval)

if(twosided)
    intArr=interp2(inpX,inpY,interpBuffer,Xq,Yq,'spline',0);%,method,extrapval)
end

intArrAlpha=interp2(inpX,inpY,alphaBuffer,Xq,Yq,'cubic',0);%,method,extrapval)
intArrLinear=interp2(inpX,inpY,alphaBuffer,Xq,Yq,'linear',0);%,method,extrapval)

intArrAlpha(intArrAlpha<0)=0;
intArrAlpha(intArrLinear<0)=0;

if(twosided)
    intArrAlphaNeg=interp2(inpX,inpY,alphaBufferNeg,Xq,Yq,'cubic',0);%,method,extrapval)
    intArrLinearNeg=interp2(inpX,inpY,alphaBufferNeg,Xq,Yq,'linear',0);%,method,extrapval)
    intArrAlphaNeg(intArrLinearNeg<0)=0;
    intArrAlphaNeg(intArrLinearNeg<0)=0;
end

x2keep=round([inpX(1,min(optXidx)-bufferMult)+1,inpX(1,max(optXidx)+bufferMult)]);
y2keep=round([inpY(min(optYidx)-bufferMult,1)+1,inpY(max(optYidx)+bufferMult,1)]);

optPos2Plot=round([inpX(1,optXidx);inpX(1,optYidx)]);




intArr2plot=intArr(y2keep(1):y2keep(2),(x2keep(1)):x2keep(2));
intArr2plotNeg=intArr(y2keep(1):y2keep(2),(x2keep(1)):x2keep(2));
intArrAlpha=intArrAlpha(y2keep(1):y2keep(2),(x2keep(1)):x2keep(2));
intArrAlpha(intArrAlpha==0)=0;

if(twosided)
    intArrAlphaNeg=intArrAlphaNeg(y2keep(1):y2keep(2),(x2keep(1)):x2keep(2));
    intArrAlphaNeg(intArrAlphaNeg==0)=0; 
end

%imgFinal=imagesc(intArr,[minVal,maxVal]);

ax1=gca;

curAxPosition=ax1.Position;


if(~twosided)
    
    if(maxVal>minVal)
        colormap(gca,hot);
        negColorbar=false;
    else
        cool256=hot(512);
        colormap(gca,cool256(end:-1:92,[3,2,1]));
        temp=minVal;
        minVal=maxVal;
        maxVal=temp;
        negColorbar=true;
    end
    
    imgFinal=imagesc(intArr2plot,[minVal,maxVal]);
    set(gca,'xtick',[]);
    set(gca,'ytick',[]);
    chPos=colorbar();
    
    
    imgFinal.AlphaData=intArrAlpha;
    imgFinal.AlphaDataMapping='none';
    axis off

    if(negColorbar)
        %set( chPos, 'YDir', 'reverse' );
    end
else

    ax1 = gca;
    imgFinalPos=imagesc(intArr2plot,[minVal(2),maxVal(1)]);
    imgFinalPos.AlphaData=intArrAlpha;
    imgFinalPos.AlphaDataMapping='none';
    set(gca,'xtick',[]);
    set(gca,'ytick',[]);
    
    hot382=hot(512);
    colormap(ax1,hot382(92:end,:));
    axis off
    
    ax2=axes('OuterPosition',curAxPosition);

    %yyaxis left
    imgFinalNeg=imagesc(intArr2plotNeg,[maxVal(2),minVal(1)]);
    imgFinalNeg.AlphaData=intArrAlphaNeg;
    imgFinalNeg.AlphaDataMapping='none';
    set(gca,'xtick',[]);
    set(gca,'ytick',[]);
    
    %set( chNeg, 'YDir', 'reverse' );
    cool256=hot(512);
    colormap(ax2,cool256(end:-1:92,[3,2,1]));
    %caxis([-1*minVal(1),-1*maxVal(2)])
  
    axis off
    
    linkaxes([ax1,ax2]);
    %set([ax1,ax2],'Position',[.05 .11 .885 .815]);
    chPos=colorbar(ax1);
    %chPos_position=chPos.OuterPosition;
    cbHeight=curAxPosition(4)/2;
    
    set(chPos,'Position',[curAxPosition(1)+curAxPosition(3),curAxPosition(2)+cbHeight,0.02,cbHeight]);
    
    
    chNeg=colorbar(ax2,'Position',[curAxPosition(1)+curAxPosition(3),curAxPosition(2)-cbHeight/20,0.02,cbHeight]);
    
    
    
end



hold on

plot(optPos2Plot(1,:)/1.01+1,optPos2Plot(2,:)/1.01+1,'O','MarkerSize',15,'LineWidth',3,'color','black', 'MarkerFaceColor', 'k');
for optIdx=1:length(data2plot)
    text(optPos2Plot(1,optIdx)/1.01+1,optPos2Plot(2,optIdx)/1.01+1,mrkLbl{optIdx},'FontSize',10,'HorizontalAlignment', 'center','color','white');
end


hold off
if(~isempty(clrBarTitle))
    set(get(chPos,'title'),'string',clrBarTitle);
end





if(nargout>0)
    imgOut=imgFinal;
end

if(~isempty(titleString))
    title(titleString);
end

end
