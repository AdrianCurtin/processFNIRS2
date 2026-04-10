function opt_2d_coords=fitProbe2D(ChxList,ChyList,ChzList, usePCA)
% Fits a 2D representation of the plane as best as possible

persistent cache
if isempty(cache)
    cache = containers.Map('KeyType','char','ValueType','any');
end

% Cache clear sentinel (matches Device.load() pattern)
if ischar(ChxList) && strcmp(ChxList, '__clear__')
    cache = containers.Map('KeyType','char','ValueType','any');
    opt_2d_coords = [];
    return
end

if(nargin<4)
    usePCA = true;
end

% Build cache key from rounded inputs
cacheKey = mat2str(round([ChxList(:); ChyList(:); ChzList(:); usePCA], 6));
if cache.isKey(cacheKey)
    opt_2d_coords = cache(cacheKey);
    return
end

if(usePCA)
    xyzArray= [ChxList,ChyList,ChzList];
    mean_data = mean(xyzArray);
    centered_data = xyzArray - mean_data;
    cov_matrix = cov(centered_data);
    [eigenvectors, eigenvalues] = eig(cov_matrix);
    [eigenvalues, idx] = sort(diag(eigenvalues), 'descend');
    eigenvectors = eigenvectors(:, idx);
    num_components = 2;
    principal_components = centered_data * eigenvectors(:, 1:num_components);

    ChxList=principal_components(:,1);
    ChyList=principal_components(:,2);
    ChzList(:)=0;
end


plotFigs=false;
fprintf('Autoplacing Channels\n');
    
global chAxesHandles

numCh=length(ChxList);

chAxesHandles=cell(numCh,1);


rangeX=max(ChxList)-min(ChxList);
rangeY=max(ChyList)-min(ChyList);
rangeZ=max(ChzList)-min(ChzList);

if(all(rangeZ>rangeY)&&all(rangeY<rangeX))
    ChyList=ChzList;
elseif(all(rangeZ>rangeX)&&all(rangeY>=rangeX))
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

cache(cacheKey) = opt_2d_coords;

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

