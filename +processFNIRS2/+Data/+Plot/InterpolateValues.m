function [ imgOut,optPos2Plot ] = InterpolateValues(fNIR,data2plot,minVal,maxVal,bufferMult,titleString,clrBarTitle)
%processFNIRS2.Data.Plot.ImageValues
%
% Uses an imagemap to change the color of each cell based on data2plot
% fNIR is a data structure that contains the fNIRS structure info, data2
% plot houses the numbers themselves
%
% Short separation channels are not presented here and are skipped
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



if(nargin<3||isempty(minVal))
   minVal=nanmin(data2plot); 
end

if(nargin<4)
    if(length(minVal)==2)
        maxVal=[];
    else
        maxVal=nanmax(data2plot);
    end
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
    elseif(maxVal(1)<=minVal(2)) % reverse plot
        twosided=false;
        maxVal=maxVal(2);
        minVal=minVal(1);
    end
    
elseif(isempty(maxVal))
     maxVal=nanmax(data2plot(:));
    
    twosided=false;
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

OptPosY=-OptPosY;

maxPosX=nanmax(OptPosX);
maxPosY=nanmax(OptPosY);
minPosX=nanmin(OptPosX);
minPosY=nanmin(OptPosY);
OptDiffX=abs(OptPosX(1)-OptPosX(2:end));
OptDiffY=abs(OptPosY(1)-OptPosY(2:end));
OptDistX=nanmin(OptDiffX(OptDiffX>0));
OptDistY=nanmin(OptDiffY(OptDiffY>0));

OptDistX=round(OptDistX,5);
OptDistY=round(OptDistY,5);

dimX=maxPosX-minPosX;
dimY=maxPosY-minPosY;

maxDim=max([dimX,dimY]);
maxDimDist=round(maxDim/OptDistX)*OptDistX;


bufferSize=bufferMult*OptDistX;
pixelPerCm=imgSize/max([dimX+bufferSize*2,dimY+bufferSize*2]);

%optDataSize=10;

OptPosX=OptPosX-minPosX;
OptPosY=OptPosY-minPosY;


buffer=bufferSize*pixelPerCm/2;

if(OptDistX==OptDistY)
    [inpX,inpY]=meshgrid(0:OptDistX*pixelPerCm:(maxDimDist+bufferSize*2)*pixelPerCm);
else
    
    error('Haven''t accoutned for this yet');
end

%maxIdxX=round(dimX/OptDistX)+bufferMult+2;
%maxIdxY=round(dimY/OptDistY)+bufferMult+2;
%inpX=inpX(1:maxIdxX,1:maxIdxY);
%inpY=inpY(1:maxIdxX,1:maxIdxY);

interpBuffer=nan(size(inpX));
alphaBuffer=zeros(size(inpX));

if(twosided)
    alphaBufferNeg=alphaBuffer;
end

numRows=size(inpY,1);
% NEed to fill in small array middle with interpolated values instead of
% minimum
for optIdx=1:length(data2plot)
    %if optIdx > 16
    %    continue
    %end
    optNum=probeInfo.ChannelList(optIdx); 
    optXidx(optIdx)=round(OptPosX(optNum)/OptDistX)+bufferMult+1;
    optYidx(optIdx)=round(OptPosY(optNum)/OptDistY)+bufferMult+1;
    
    if(~twosided&&~isnan(data2plot(optIdx))&&((data2plot(optIdx)>=minVal&&maxVal>minVal)||...
            (data2plot(optIdx)<=(minVal)&&minVal>maxVal)))
        interpBuffer(optYidx(optIdx),optXidx(optIdx))=data2plot(optIdx);
        alphaBuffer(optYidx(optIdx),optXidx(optIdx))=1;
        alphaBufferNeg(optYidx(optIdx),optXidx(optIdx))=0;
    elseif(twosided&&~isnan(data2plot(optIdx))&&data2plot(optIdx)<=minVal(1))
        interpBuffer(optYidx(optIdx),optXidx(optIdx))=data2plot(optIdx);
        alphaBufferNeg(optYidx(optIdx),optXidx(optIdx))=1;
        alphaBuffer(optYidx(optIdx),optXidx(optIdx))=0;
    elseif(twosided&&~isnan(data2plot(optIdx))&&data2plot(optIdx)>=minVal(2))
        interpBuffer(optYidx(optIdx),optXidx(optIdx))=data2plot(optIdx);
        alphaBuffer(optYidx(optIdx),optXidx(optIdx))=1;
        alphaBufferNeg(optYidx(optIdx),optXidx(optIdx))=0;
    else
        interpBuffer(optYidx(optIdx),optXidx(optIdx))=data2plot(optIdx);
    end
    mrkLbl{optIdx}=num2str(optNum);
end


numNeighbors=~isnan(interpBuffer)*1;
numNeighbors(numNeighbors==1)=nan; %marks all valid points as nan (so they don't add)
numNeighbors(2:end,:)=numNeighbors(2:end,:)+~isnan(interpBuffer(1:end-1,:)); %add left shift
numNeighbors(1:end-1,:)=numNeighbors(1:end-1,:)+~isnan(interpBuffer(2:end,:)); %add right shift
numNeighbors(:,2:end)=numNeighbors(:,2:end)+~isnan(interpBuffer(:,1:end-1)); %add top shift
numNeighbors(:,1:end-1)=numNeighbors(:,1:end-1)+~isnan(interpBuffer(:,2:end)); %add bottom shift

neighborIdx=find(numNeighbors>1);

[neighborIdxY,neighborIdxX]=ind2sub(size(numNeighbors),neighborIdx);
for i=1:length(neighborIdxX)
   curX=neighborIdxX(i);
   curY=neighborIdxY(i);
   
   up=interpBuffer(curY-1,curX);
   down=interpBuffer(curY+1,curX);
   left=interpBuffer(curY,curX-1);
   right=interpBuffer(curY,curX+1);
   val=nanmean([up,down,left,right]);
   
   if(~twosided&&~isnan(val)&&((val>=minVal&&maxVal>minVal)||...
            (val<=(minVal)&&minVal>maxVal)))
        interpBuffer(curY,curX)=val;
        alphaBuffer(curY,curX)=1;
        alphaBufferNeg(curY,curX)=0;
    elseif(twosided&&~isnan(val)&&val<=minVal(1))
        interpBuffer(curY,curX)=val;
        alphaBufferNeg(curY,curX)=1;
        alphaBuffer(curY,curX)=0;
    elseif(twosided&&~isnan(val)&&val>=minVal(2))
        interpBuffer(curY,curX)=val;
        alphaBuffer(curY,curX)=1;
        alphaBufferNeg(curY,curX)=0;
    else
        interpBuffer(curY,curX)=val;
    end
end


if(~twosided)
    interpBuffer(isnan(interpBuffer))=minVal;
else
    interpBuffer(isnan(interpBuffer))=0;
end


%interpBuffer=interpBuffer(end:-1:1,:);
%alphaBuffer=alphaBuffer(end:-1:1,:);

[Xq,Yq] = meshgrid(1:imgSize);




if(twosided)
    intArr=interp2(inpX,inpY,interpBuffer,Xq,Yq,'makima',0);%,method,extrapval)
elseif(minVal>maxVal)
    intArr=interp2(inpX,inpY,interpBuffer,Xq,Yq,'makima',nanmean(maxVal));%,method,extrapval)
elseif(maxVal>=minVal)
    intArr=interp2(inpX,inpY,interpBuffer,Xq,Yq,'makima',nanmean(minVal));%,method,extrapval)
end

intArrAlpha=interp2(inpX,inpY,alphaBuffer,Xq,Yq,'cubic',0);%,method,extrapval)
intArrLinear=interp2(inpX,inpY,alphaBuffer,Xq,Yq,'linear',0);%,method,extrapval)

intArrAlpha(intArrAlpha<0)=0;
intArrAlpha(intArrLinear<0)=0;

if(twosided)
    intArrAlphaNeg=interp2(inpX,inpY,alphaBufferNeg,Xq,Yq,'cubic',0);%,method,extrapval)
    intArrLinearNeg=interp2(inpX,inpY,alphaBufferNeg,Xq,Yq,'linear',0);%,method,extrapval)
    intArrAlpha(intArrAlpha<0)=0;
    intArrAlphaNeg(intArrLinearNeg<0)=0;
end

x2keep=round([inpX(1,min(optXidx)-bufferMult)+1,inpX(1,max(optXidx)+bufferMult)]);
y2keep=round([inpY(min(optYidx)-bufferMult,1)+1,inpY(max(optYidx)+bufferMult,1)]);

optPos2Plot=round([inpX(1,optXidx);inpX(1,optYidx)]);




intArr2plot=intArr(y2keep(1):y2keep(2),(x2keep(1)):x2keep(2));
%intArr2plotNeg=intArr(y2keep(1):y2keep(2),(x2keep(1)):x2keep(2));
intArrAlpha=intArrAlpha(y2keep(1):y2keep(2),(x2keep(1)):x2keep(2));
%intArrAlpha(intArrAlpha==0)=0;

if(twosided)
    intArrAlphaNeg=intArrAlphaNeg(y2keep(1):y2keep(2),(x2keep(1)):x2keep(2));
    %intArrAlphaNeg(intArrAlphaNeg==0)=0; 
end

%imgFinal=imagesc(intArr,[minVal,maxVal]);

ax1=gca;

curAxPosition=ax1.Position;


if(~twosided)
    
    if(maxVal>minVal)
        hot382=hot(512);
        colormap(ax1,hot382(92:end-64,:));
        negColorbar=false;
    else
        cool256=hot(512);
        colormap(gca,cool256(end-64:-1:92,[3,2,1]));
        temp=minVal;
        minVal=maxVal;
        maxVal=temp;
        negColorbar=true;
    end
    
    imgFinal=imagesc(intArr2plot,[minVal,maxVal]);
    set(gca,'xtick',[]);
    set(gca,'ytick',[]);
    xlim([1,size(intArrAlpha,2)]);
    ylim([1,size(intArrAlpha,1)]);
    chPos=colorbar();
    
    
    imgFinal.AlphaData=intArrAlpha;
    imgFinal.AlphaDataMapping='none';
    axis off

    if(negColorbar)
        %set( chPos, 'YDir', 'reverse' );
    end
else
    curAxPosition=ax1.OuterPosition;
    imgFinalPos=imagesc(intArr2plot,[minVal(2),maxVal(1)]);
    set(gca,'YDir','normal');
    imgFinalPos.AlphaData=intArrAlpha;
    imgFinalPos.AlphaDataMapping='none';
    set(gca,'xtick',[]);
    set(gca,'ytick',[]);
    xlim([1,size(intArrAlpha,2)]);
    ylim([1,size(intArrAlpha,1)]);
    
    hot382=hot(512);
    colormap(ax1,hot382(92:end-64,:));
    axis off
    
    

    
    ax2=axes('OuterPosition',curAxPosition);
    ax2.Position=ax1.Position;

    %yyaxis left
    imgFinalNeg=imagesc(intArr2plot,[maxVal(2),minVal(1)]);
    set(gca,'YDir','normal');
    imgFinalNeg.AlphaData=intArrAlphaNeg;
    imgFinalNeg.AlphaDataMapping='none';
    set(gca,'xtick',[]);
    set(gca,'ytick',[]);
    
    xlim([1,size(intArrAlpha,2)]);
    ylim([1,size(intArrAlpha,1)]);
    
    %set( chNeg, 'YDir', 'reverse' );
    cool256=hot(512);
    colormap(ax2,cool256(end-64:-1:92,[3,2,1]));
    %caxis([-1*minVal(1),-1*maxVal(2)])
  
    axis off
    
    curAxInnerPosition=ax1.Position;
    
    linkaxes([ax1,ax2]);
    %set([ax1,ax2],'Position',[.05 .11 .885 .815]);
    chPos=colorbar(ax1);
    %chPos_position=chPos.OuterPosition;
    cbHeight=curAxInnerPosition(4)/2;
    
    set(chPos,'Position',[curAxInnerPosition(1)+curAxInnerPosition(3),curAxInnerPosition(2)+cbHeight,0.02,cbHeight]);
    
    
    chNeg=colorbar(ax2,'Position',[curAxInnerPosition(1)+curAxInnerPosition(3),curAxInnerPosition(2)-cbHeight/20,0.02,cbHeight]);
    
    
    
end



hold on

%hpt=plot(optPos2Plot(1,:)/1.01+1,optPos2Plot(2,:)/1.01+1,'square','MarkerSize',4,'LineWidth',3,'color','white', 'MarkerFaceColor', 'white');

for optIdx=1:length(data2plot)
    %if optIdx > 16
    %    continue 
    %end
    t=text(optPos2Plot(1,optIdx)/1.01+1,optPos2Plot(2,optIdx)/1.01+1,mrkLbl{optIdx},'FontSize',11,'VerticalAlignment','middle','HorizontalAlignment', 'center','color','white');
    t2=text(optPos2Plot(1,optIdx)/1.01+1,optPos2Plot(2,optIdx)/1.01+1,mrkLbl{optIdx},'FontSize',8,'VerticalAlignment','middle','HorizontalAlignment', 'center','color','white');
    t.FontWeight='bold';
    t2.FontWeight='bold';
    
    text(optPos2Plot(1,optIdx)/1.01+1,optPos2Plot(2,optIdx)/1.01+1,mrkLbl{optIdx},'FontSize',10,'VerticalAlignment','middle','HorizontalAlignment', 'center','color','black');
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
