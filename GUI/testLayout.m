function testLayout()


ChxList=[1,2,3,4,5,6,7,8,1,2,3,4,5,6,7,8];
ChyList=[1,1,1,1,1,1,1,1,2,2,2,2,2,2,2,2];

h=figure(1);

handles.uipanel_arranged=uipanel('Title','Panel', 'Position',[.1 .1 .8 .8]);

setUpAxes(handles,ChxList,ChyList)



end


function setUpAxes(handles,ChxList,ChyList)

plotFigs=false;
    
global chAxesHandles

numCh=length(ChxList);

chAxesHandles=cell(numCh,1);

ChxList=(ChxList-min(ChxList))./(max(ChxList)-min(ChxList));

ChyList=(ChyList-min(ChyList))./(max(ChyList)-min(ChyList));

uiP=handles.uipanel_arranged;


uCh=unique([ChxList,ChyList],'rows');

if(size(uCh,2)<length(ChxList))
    error('Duplicate Channel Locations Present');
end

startStepSize=50;
stepSize=10;

tic

maskSize=1200;

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

toc

for c=1:numCh
    figure(1)
     [x1,y1,x2,y2]=cord2mask(ChxList(c),ChyList(c),lastWsize,lastHsize,true);
     chAxesHandles{c} = axes(uiP);
     plot([1:20],[1:20]);
     chAxesHandles{c}.OuterPosition=[x1,y1,x2-x1,y2-y1];
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