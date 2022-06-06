function opt_2d_coords=fitProbe2D(ChxList,ChyList,ChzList)
% Fits a 2D representation of the plane as best as possible


plotFigs=false;
fprintf('Autoplacing Channels\n');
    
global chAxesHandles

numCh=length(ChxList);

chAxesHandles=cell(numCh,1);


rangeX=max(ChxList)-min(ChxList);
rangeY=max(ChyList)-min(ChyList);
rangeZ=max(ChzList)-min(ChzList);

if(rangeZ>rangeY&&rangeY<rangeX)
    ChyList=ChzList;
elseif(rangeZ>rangeX&&rangeY>=rangeX)
    ChxList=ChzList;
end


ChxList_Norm=(ChxList-min(ChxList))./(max(ChxList)-min(ChxList));

if(any(isnan(ChxList_Norm)))
   [~,srtIdx]=sort(ChxList,'ascend');
   ChxList= (srtIdx-min(srtIdx))./(max(srtIdx)-min(srtIdx));
else
   ChxList=ChxList_Norm;
end

ChyList_Norm=1-(ChyList-min(ChyList))./(max(ChyList)-min(ChyList));


if(any(isnan(ChyList_Norm)))
   [~,srtIdx]=sort(ChyList,'ascend');
   ChyList= (srtIdx-min(srtIdx))./(max(srtIdx)-min(srtIdx));
else
   ChyList=ChyList_Norm;
end


% if(plotFigs)
%     figure(999);
%     handles.uipanel_arranged=uipanel('Title','Panel', 'Position',[.1 .1 .8 .8]);
%     uiP=handles.uipanel_arranged;
% end


uCh=unique([ChxList,ChyList],'rows');

if(size(uCh,1)<length(ChxList))
    error('Duplicate Channel Locations Present');
end



uCh=unique([ChxList(:),ChyList(:)],'rows');

if(size(uCh,1)<length(ChxList))
    error('Duplicate Channel Locations Present');
end

startStepSize=10;
stepSize=10;


maskSize=1200;

lastPsize=startStepSize;
for pSize=startStepSize:stepSize:maskSize
    bitMask=zeros(maskSize,maskSize);
    for c=1:numCh
        [x1,y1,x2,y2]=cord2mask(ChxList(c),ChyList(c),pSize,pSize);
        bitMask(x1:x2,y1:y2)=bitMask(x1:x2,y1:y2)+1;
    end
    if(plotFigs)
        figure(2);
        imagesc(bitMask);
        java.lang.Thread.sleep(100) ;
    end
    
    if(sum(sum(bitMask>1))>0)
        break;
    end
    lastPsize=pSize-stepSize;
end

lastWsize=lastPsize;
for wSize=lastPsize:stepSize:maskSize
    bitMask=zeros(maskSize,maskSize);
    for c=1:numCh
        [x1,y1,x2,y2]=cord2mask(ChxList(c),ChyList(c),wSize,lastPsize);
        bitMask(x1:x2,y1:y2)=bitMask(x1:x2,y1:y2)+1;
    end
    if(plotFigs)
        figure(2);
        imagesc(bitMask);
        java.lang.Thread.sleep(100) ;
    end
    if(sum(sum(bitMask>1))>0)
        break;
    end
    lastWsize=wSize-stepSize;
end

lastHsize=lastPsize;
for hSize=lastPsize:stepSize:maskSize
    bitMask=zeros(maskSize,maskSize);
    for c=1:numCh
        [x1,y1,x2,y2]=cord2mask(ChxList(c),ChyList(c),lastWsize,hSize);
        bitMask(x1:x2,y1:y2)=bitMask(x1:x2,y1:y2)+1;
    end
    if(plotFigs)
        figure(2)
        imagesc(bitMask);
        java.lang.Thread.sleep(100) ;
    end
    if(sum(sum(bitMask>1))>0)
        break;
    end
    lastHsize=hSize-stepSize;
end



for c=1:numCh
    
     [x1,y1,x2,y2]=cord2mask(ChxList(c),ChyList(c),lastWsize,lastHsize,true);
     opt_2d_coords{c}=[x1,y1,x2-x1,y2-y1];
end

end




function [x1,y1,x2,y2]=cord2mask(x,y,wPixelSize,hPixelSize,returnRelative)
    
if(nargin<5)
    returnRelative=false;
end

    
bitMaskRes=1200;
adjBitMaskResW=bitMaskRes-wPixelSize;
adjBitMaskResH=bitMaskRes-hPixelSize;

x1=round(x*adjBitMaskResW)+1;
y1=round(y*adjBitMaskResH)+1;
x2=round(x*adjBitMaskResW+wPixelSize)-1;
y2=round(y*adjBitMaskResH+hPixelSize)-1;


if(returnRelative)
    x1=x1/bitMaskRes;
    y1=y1/bitMaskRes;
    x2=x2/bitMaskRes;
    y2=y2/bitMaskRes;
end


end

