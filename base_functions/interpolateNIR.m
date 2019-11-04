function interpolateNIR(varargin) %(fNIRarr,minVal,maxVal,interpolationType,transparent,brainStyle,titleTxt,fontSize,clr,showChText)
% InterpolateNIR functions to draw a 2D interpolated value image onto a 2D
% brain image
%   specify the image array and the minimum and maximum values for use
%   brainStyle will change the background image depending on what you
%   require

p=inputParser;

validfNIRInput = @(x) (isnumeric(x)&&length(x)>1);
validScalarNum = @(x) isnumeric(x) && isscalar(x);
validScalarPosNum = @(x) isnumeric(x) && isscalar(x) && (x > 0);
validMatrixPosNum = @(x) isnumeric(x) && ismatrix(x) && (sum(x(:)<0)==0);

addOptional(p,'fNIRarr',[],validfNIRInput); % original data
validSPM_mode = @(x) ischar(validatestring(x,{'value','HbR','HbO','HbDiff','HbTotal','CBSI','tstat','fstat','corr','rcorr','rhocorr','pvalue','logical','percentage'}));
    %value plots the value with no specific cutoffs
    % Hb is the same as value for now
    % t stat assumes that you provide it with a pvalue for thresholding
    % corr assumes that the value goes from -1:1 like a pearsons or
    %       spearmans correlation
    % p value assumes that p<alpha is the threshold
    % logical will just show the locations of specified channels
    % percentage will show the the channel as a percentage
    
validInterpolation_mode = @(x) ischar(validatestring(x,{'None','Interpolated','Broadened'}));
validStyle=@(x) ischar(validatestring(x,{'None','Anatomy_Black','Anatomy_White','Anatomy_White_TMS','3D_Black','3D_White','Gray_3D_White','Gray_3D_Black','Gray_3D_White_TMS','Gray_3D_Black_TMS'}));
%BrainStyle
% 0 = Photo Anatomy Project (Black Background)
% 1 = Photo Anatomy Project (White Background)
% 2 = Photo Anatomy Project (White Background) w/ TMS coil)
% 3 = 3D Brain Image (Black Background)
% 4 = 3D Brain Image (White Background)
% 5 = 3D Brain Image Greyscale (White Background)
% 6 = 3D Brain Image Greyscale (Black Background)
    
addParameter(p,'Mode','value',validSPM_mode); %selects style of SPM plot

addParameter(p,'lowerThreshold',[],validScalarNum); %lower limit for colorbar plot (values out of range are missing)
addParameter(p,'upperThreshold',[],validScalarNum); %upper limit for colorbar plot
addParameter(p,'interpolationType','broadened',validInterpolation_mode); %change type of interpolation
addParameter(p,'transparent',false,@islogical);  %makes interpolation transparent
addParameter(p,'brainStyle','3D_White',validStyle); %select bacground image for plot
addParameter(p,'logScale',false,@islogical); %Option to scale data using log

addParameter(p,'channelMask',[],@islogical); %Mask to show hide channels
addParameter(p,'pValueMask',[],validMatrixPosNum); %p Value array to show/hide channels (if present, minVal applies to p values instead)
addParameter(p,'pThreshold',0.05,validScalarPosNum); %pvalue threshold used with pvalue mask

addParameter(p,'TitleText','',@ischar);
addParameter(p,'fontSize',30,validScalarPosNum);
addParameter(p,'colorScheme','autumn',@ischar);
addParameter(p,'ChannelLabels',false,@islogical);
addParameter(p,'UseFDR',false,@islogical);

parse(p,varargin{:});

fNIRarr=p.Results.fNIRarr;
Mode=p.Results.Mode;
lowerThreshold=p.Results.lowerThreshold;
upperThreshold=p.Results.upperThreshold;
interpolationType=p.Results.interpolationType;
transparent=p.Results.transparent;
brainStyle=p.Results.brainStyle;
titleTxt=p.Results.TitleText;
fontSize=p.Results.fontSize;
colorScheme=p.Results.colorScheme;
showChannelLabels=p.Results.ChannelLabels;
logScale=p.Results.logScale;
pValueMask=p.Results.pValueMask;
channelMask=p.Results.channelMask;
pThreshold=p.Results.pThreshold;
useFDR=p.Results.UseFDR;

debugPlot=false;

if(isempty(fNIRarr))
   fNIRarr=nan(2,8); 
end

if(length(fNIRarr)==16)
   temp=fNIRarr(1:2:15);
   temp2=fNIRarr(2:2:16);
   fNIRarr=[temp;temp2];
end

if(~isempty(channelMask))
    channelMask(isnan(fNIRarr))=false;
else
    channelMask=~isnan(fNIRarr);
end
    

if(~isempty(pValueMask))
    if(any(isnan(pValueMask)))
       warning('Only pass nan if you don''t want FDR correction to be applied for rejected channels'); 
    end
    
    for i=1:length(pValueMask)
        if(isnan(pValueMask(i)))
            pValueMask(i)=i;
        end
    end
    
    %%Perform FDR here
    if(useFDR)
        [pUniq,~,pUidx]=unique(pValueMask(:));
        [fUniq,~,fUidx]=unique(fNIRarr(:));
        
        if(length(pUniq)==length(fUniq)&&length(pUniq)<length(pValueMask)) %checking for ROI mode
            %FDR should only be used with the full setup
            sortedP=pUniq;
            sortedIdx=pUidx;
        else
            [sortedP,sortedIdx]=sort(pValueMask);
        end
        
        numP=length(sortedP);
        
        if(any(sortedP)==9999)
            numP=numP-1;
        end
        for i=1:numP
            q=pThreshold/(numP+1-i);
            pValueMask(sortedIdx==i)=pValueMask(sortedIdx==i)*(numP+1-i);
        end
        
        
    end
    
    channelMask(pValueMask>pThreshold|pValueMask<0)=false;
        
   
end

if(isempty(lowerThreshold))
    lowerThreshold=nanmin(fNIRarr(channelMask));
end
if(isempty(upperThreshold))
    upperThreshold=nanmax(fNIRarr(channelMask));
end

if(isempty(lowerThreshold))
    lowerThreshold=nan;
end
if(isempty(upperThreshold))
    upperThreshold=nan;
end


cMapLabel='';
nanReplaceVal=nan;

twoSided=false;
twoSidedOffset=1000;

switch(Mode)
    case 'value'
        channelMask(fNIRarr<lowerThreshold|fNIRarr>upperThreshold)=false;
    case 'HbR'
        channelMask(fNIRarr<lowerThreshold|fNIRarr>upperThreshold)=false;
		cMapLabel='\\Delta[HbR]';
	case 'HbO'
        channelMask(fNIRarr<lowerThreshold|fNIRarr>upperThreshold)=false;
		cMapLabel='\\Delta[HbO]';
	case 'HbDiff'
        channelMask(fNIRarr<lowerThreshold|fNIRarr>upperThreshold)=false;
		cMapLabel='\\Delta[HbDiff]';
	case 'HbTotal'
        channelMask(fNIRarr<lowerThreshold|fNIRarr>upperThreshold)=false;
		cMapLabel='\\Delta[HbTotal]';
	case 'CBSI'
        channelMask(fNIRarr<lowerThreshold|fNIRarr>upperThreshold)=false;
		cMapLabel='\\Delta[CBSI]';
    case 'tstat'
        %channelMask(abs(fNIRarr)<lowerThreshold)=false;
        %channelMask(abs(fNIRarr)>upperThreshold)=false;
        if(upperThreshold<0||lowerThreshold>0)
            if(upperThreshold<0)
               temp=upperThreshold;
               upperThreshold=lowerThreshold;
               lowerThreshold=temp;
            end
            twoSided=false;
        else
            twoSided=true;
            cmap=@parula;
            upperThreshold=max(abs([upperThreshold,lowerThreshold]));
            lowerThreshold=-1*min(abs([upperThreshold,lowerThreshold]));
            
        end
		cMapLabel='T-Statistic';
        nanReplaceVal=0;
        
	case 'fstat'
		cMapLabel='F-Statistic';
        nanReplaceVal=0;
        if(upperThreshold<0||lowerThreshold>0)
            if(upperThreshold<0)
               temp=upperThreshold;
               upperThreshold=lowerThreshold;
               lowerThreshold=temp;
            end
            twoSided=false;
        else
            twoSided=true;
            cmap=@parula;
            upperThreshold=max(abs([upperThreshold,lowerThreshold]));
            lowerThreshold=-1*min(abs([upperThreshold,lowerThreshold]));
            
        end
    case 'corr'
        channelMask(abs(fNIRarr)<lowerThreshold)=false;
        channelMask(abs(fNIRarr)>upperThreshold)=false;
		cMapLabel='rho';
        nanReplaceVal=0;
        if(upperThreshold<0||lowerThreshold>0)
            if(upperThreshold<0)
               temp=upperThreshold;
               upperThreshold=lowerThreshold;
               lowerThreshold=temp;
            end
            twosided=false;
        else
            twoSided=true;
        end
    case 'rcorr'
        channelMask(abs(fNIRarr)<lowerThreshold)=false;
        channelMask(abs(fNIRarr)>upperThreshold)=false;
		cMapLabel='r';
        nanReplaceVal=0;
        if(upperThreshold<0||lowerThreshold>0)
            if(upperThreshold<0)
               temp=upperThreshold;
               upperThreshold=lowerThreshold;
               lowerThreshold=temp;
            end
            twosided=false;
        else
            twoSided=true;
        end
    case 'rhocorr'
        channelMask(abs(fNIRarr)<lowerThreshold)=false;
        channelMask(abs(fNIRarr)>upperThreshold)=false;
		cMapLabel='rho';
        nanReplaceVal=0;
        if(upperThreshold<0||lowerThreshold>0)
            if(upperThreshold<0)
               temp=upperThreshold;
               upperThreshold=lowerThreshold;
               lowerThreshold=temp;
            end
            twosided=false;
        else
            twoSided=true;
        end
    case 'pvalue'
        channelMask(abs(fNIRarr)<lowerThreshold)=false;
        channelMask(abs(fNIRarr)>upperThreshold)=false;
		cMapLabel='p value';
        nanReplaceVal=1;
    case 'logical'
        channelMask(fNIRarr~=true)=false;
        nanReplaceVal=false;
    case 'percentage'
        channelMask(abs(fNIRarr)<lowerThreshold)=false;
        channelMask(abs(fNIRarr)>upperThreshold)=false;
		cMapLabel='%';
        nanReplaceVal=0;
end


if(isempty(lowerThreshold))
    lowerThreshold=nanmin(fNIRarr(channelMask));
end
if(isempty(upperThreshold))
    upperThreshold=nanmax(fNIRarr(channelMask));
end

fNIRarr(isnan(fNIRarr))=nanReplaceVal;

if(isempty(upperThreshold)||isnan(upperThreshold))
    maxVal=1e6;
    minVal=maxVal-1;
    
    emptyplot=true;
else
    maxVal=upperThreshold;
    minVal=lowerThreshold;
    
    emptyplot=false;
end

if(minVal==maxVal)
    maxVal=maxVal*1.1;
    minVal=minVal*0.95;
end




yCrop=40;
xCrop=730;% margin for right border


% if(isstruct(fNIRarr))
%     if(length(fNIRarr.p)==16)
%         t=zeros(2,8);
%         t(:)=fNIRarr.p;
%        fNIRarr.p=t;
%        t(:)=fNIRarr.f
%        fNIRarr.f=t;
%        clear t;
%     end
%     
%     
%     pArr=fNIRarr.p;
%     fNIRarr=fNIRarr.f;
%     tmp=[pArr(:),fNIRarr(:)];
%     [~,i]=sort(tmp(:,1));
%     tmp=tmp(i,:);
%     max1=max(tmp(tmp(:,1)==1,2));
%     tmp(tmp(:,1)==1,:)=[];
%     if(~isempty(max1))
% %         if(size(tmp,1)==1)
% %             max1=max(
% %             tmp=[tmp;1,max1];
% %         else
%             tmp=[tmp;1,max1];
% %         end
%     end
%    %max(tmp(tmp(:,1)==1,2));
%    if(isempty(minVal)==1||minVal==0) 
%     minVal=interp1(tmp(:,1),tmp(:,2),0.05,'linear','extrap');
%     
%     disp(sprintf('f Min Val: %f',minVal));
%     if(isempty(maxVal))
%         maxVal=max(fNIRarr(:));
%     end
%     disp(sprintf('f Max Val: %f',maxVal));
%     if(maxVal<minVal)
%         maxVal=minVal+1;
%     end
%    end
% end

for(i=1:size(fNIRarr,1)) %flip Left/Right
   fNIRarr(i,:)=flip(fNIRarr(i,:));
end
%maxVal=1;
%minVal=0.4;

if(logScale)
    fNIRarr=log10(fNIRarr);
    if(minVal<=0)
        minVal=1e-5;
    end
    minVal=log10(minVal);
    maxVal=log10(maxVal);
    
end

if(maxVal<minVal)
    invertAxis=true;
    
    %fNIRarr(fNIRarr<maxVal)=maxVal;
    %fNIRarr(fNIRarr>minVal)=minVal;
    minVal=-minVal;%+1000;
    maxVal=-maxVal;%+1000;
    fNIRarr=-fNIRarr;
else
    invertAxis=false;
end

minE=min([minVal-abs(maxVal-minVal),nanmin(fNIRarr(:))]);
if(minE<0&&nanmin(fNIRarr(:))>0)
   minE=0; 
end

if(logScale)
    minE=minVal/2;
end

fNIRarr(fNIRarr<minE)=minE;




nCol=256;

if(exist(colorScheme)==2)
    cmapFunc=str2func(colorScheme);
else
   warning('Invalid cmap function %s\ndefaulting to Hot',colorScheme');
   cmapFunc=@hot;
end

if(twoSided)
  % cmapFunc=@parula; 
end

cmp=cmapFunc(nCol);

cmp=cmp(round(nCol/4):end,:);
nCol=size(cmp,1);


if(debugPlot)
    figure(10);
    
    colormap(gca,cmp);
    caxis([minVal,maxVal]);
    subplot(3,1,1);


    imagesc(fNIRarr);
    colorbar();
    caxis([minVal,maxVal]);
end



if(strcmp(interpolationType,'broadened')) %pad sides
   newArr=ones(size(fNIRarr,1),size(fNIRarr,2)+2)*minE;
   alphaArr=zeros(size(fNIRarr,1),size(fNIRarr,2)+2);
   for i=1:size(fNIRarr,1)
      newArr(i,:)=[minE,fNIRarr(i,:),minE];
      alphaArr(i,:)=[0,channelMask(i,:),0];
   end
   fNIRarr=[ones(1,size(newArr,2))*minE;newArr;ones(1,size(newArr,2))*minE];
   alphaArr=[zeros(1,size(newArr,2));alphaArr;zeros(1,size(newArr,2))];
else
    alphaArr=channelMask;
end

if(~invertAxis)
    
end



xLen=size(fNIRarr,1);
yLen=size(fNIRarr,2);


if(debugPlot)
    subplot(3,1,2);
end

rWidth=100+1;


if(~strcmp(interpolationType,'broadened')) 
    [intArrX,intArrY]= meshgrid(1:(size(fNIRarr,2))*rWidth,1:size(fNIRarr,1)*rWidth);

    midArrYorig=(1:xLen)*(rWidth)-(rWidth-1)/2+1;
    midArrX_orig=(1:yLen)*(rWidth)-(rWidth-1)/2+1;
else
    [intArrX,intArrY]= meshgrid(1:((size(fNIRarr,2)-2)*rWidth+2),1:((size(fNIRarr,1)-2)*rWidth+2));

    midArrYorig=(1:(xLen-2))*(rWidth)-(rWidth-1)/2+1;
    midArrYorig=[1,midArrYorig,max(midArrYorig)+round(rWidth/2)];
    midArrX_orig=(1:(yLen-2))*(rWidth)-(rWidth-1)/2+1;
    midArrX_orig=[1,midArrX_orig,max(midArrX_orig)+round(rWidth/2)-1];
end

%%%Curve handling
flexArrX=midArrX_orig;%(2:end-1);
flexArrY=midArrYorig;%(2:end-1);
midpointX=(length(flexArrX)+1)/2;

if(rem(midpointX,1)~=0)
    midpointX=mean([flexArrX(floor(midpointX)),flexArrX(ceil(midpointX))]);
else
    midpointX=flexArrX(midpointX);
end


constAngle=0.12;
rangeFlex=(max(midArrX_orig)-min(midArrX_orig));
flexArrX=(flexArrX-midpointX)/rWidth;
flexArrX=flexArrX.*cos(constAngle*flexArrX);
flexArrX=flexArrX-min(flexArrX);
flexArrX=flexArrX/max(flexArrX)*rangeFlex+1;


intArr=interp2(midArrX_orig,midArrYorig,fNIRarr,intArrX,intArrY,'makima',minE);%,method,extrapval)

intAlphaArrLinear=interp2(midArrX_orig,midArrYorig,alphaArr,intArrX,intArrY,'linear',0);%,method,extrapval)
intAlphaArr=interp2(midArrX_orig,midArrYorig,alphaArr,intArrX,intArrY,'spline',0);%,method,extrapval)
% 
% intArr(intAlphaArrLinear<0.1)=minE;
% 
% intAlphaArr(intAlphaArrLinear==0)=0;

if(debugPlot)
    imagesc(intArr);
    colorbar();
    caxis([minVal,maxVal]);
end

midArrX=flexArrX;
midArrY=flexArrY;
rW2=ceil(size(intArr,2)-max(flexArrX));

 

if(strcmp(interpolationType,"Interpolated")) %%Should remove everything not inbetween optodes 
   intArr([1:(rWidth+1)/2,(size(intArr,1)-(rWidth-1)/2):size(intArr,1)],:)=[]; 
   intArr(:,[1:rW2,(size(intArr,2)-rW2):size(intArr,2)])=[]; 
   intAlphaArr([1:(rWidth+1)/2,(size(intAlphaArr,1)-(rWidth-1)/2):size(intAlphaArr,1)],:)=[]; 
   intAlphaArr(:,[1:rW2,(size(intAlphaArr,2)-rW2):size(intAlphaArr,2)])=[]; 
   
   midArrX=midArrX-min(midArrX)+1;
   midArrY=midArrY-min(midArrY)+1;
else
%    intArr(:,[(size(intArr,2)-rW2):size(intArr,2)])=[]; 
%    intAlphaArr(:,[(size(intAlphaArr,2)-rW2):size(intAlphaArr,2)])=[]; 
%    midArrX=midArrX-min(midArrX)+1;
end


nullColInd=ind2rgb(0,cmp);

scaleArr=intArr;
%First crop by max/min

scaleArr(scaleArr>maxVal)=maxVal;
scaleArr(scaleArr<minVal)=minVal;


%Then rescale from 0:1
scaleArr=(scaleArr-minVal)/(maxVal-minVal);

scaleArr=floor(scaleArr*nCol);

rgbArr = ind2rgb(scaleArr,cmp);

if(debugPlot)
    subplot(3,1,3);
    image(rgbArr)
    colorbar()
end

    % Brain Part

switch(brainStyle)
    case 'Drawing_White'
        %brainImg=imread('blankBrainDrawWhite.bmp'); //not validated yet
    case 'Anatomy_Black'
        brainImg=imread('blankBrainBlack.bmp');
    case 'Anatomy_White'
        brainImg=imread('blankBrainWhite.bmp');
    case 'Anatomy_White_TMS'
        brainImg=imread('TMSBrainWhite.bmp');
    case '3D_Black'
        brainImg=imread('blankBrain3DBlack.bmp'); 
    case '3D_White'
        brainImg=imread('blankBrain3DWhite.bmp');
    case 'Gray_3D_White'
        brainImg=imread('blankBrain3DGreyscaleWhite.bmp');
    case 'Gray_3D_Black'
        brainImg=imread('blankBrain3DGreyscaleBlack.bmp'); 
    case 'Gray_3D_White_TMS'
        brainImg=imread('blankBrain3DGreyscaleWhiteTMS.bmp');
    case 'Gray_3D_Black_TMS'
        brainImg=imread('blankBrain3DGreyscaleBlackTMS.bmp'); 
    otherwise
        brainImg=imread('blankBrainWhite.bmp');
        brainImg=zeros(size(brainImg));
end
        
bYlen=size(brainImg,1);
bXlen=size(brainImg,2);

bWidth=852;
bHeight=733;

bBrainHoffset=325;
bBrainHeight=86;

bBrainWOffset=112;
bBrainWidth=556;

if(~strcmp(interpolationType,'broadened'))     %259 from top to first row-mid, 144 from left to first row mid %233 from right to last, %408 from bottom
    brainRectX=[bBrainWOffset/bWidth*bXlen,(bBrainWoffset+bBrainWidth)/bWidth*bXlen];
    brainRectY=[bBrainHoffset/bHeight*bYlen,(bBrainHoffset+bBrainHeight)/bHeight*bYlen];
else %Add 50 to top/bottom/
    chOffsetX=5;
    chOffsetY=50;
    brainRectX=[bBrainWOffset/bWidth*bXlen-chOffsetX/bWidth*bXlen,(bBrainWOffset+bBrainWidth)/bWidth*bXlen+chOffsetX/bWidth*bXlen];
    brainRectY=[bBrainHoffset/bHeight*bYlen-32/bHeight*bYlen,(bBrainHoffset+bBrainHeight)/bHeight*bYlen+32/bHeight*bYlen];
end

brainRectY=round(brainRectY);
brainRectX=round(brainRectX);

chArr=zeros(size(rgbArr(:,:,1)));
for(i=1:length(midArrX))
    for (j=1:length(midArrY))
        chArr(round(midArrY(j)),round(midArrX(i)))=1;
    end
end
    
rsCh=imresize(chArr,[brainRectY(2)+1-brainRectY(1),brainRectX(2)+1-brainRectX(1)])>0;
xChLoc=find(sum(rsCh,1)>0);
 xChLoc(diff(xChLoc)<3)=[];
yChLoc=find(sum(rsCh,2)>0);
yChLoc(diff(yChLoc)<3)=[];

if(strcmp(interpolationType,'broadened'))
    xChLoc=xChLoc(1:end-1);
    if(length(xChLoc)>(size(fNIRarr,2)-2))
       xChLoc=xChLoc(2:end);
    end
    
    yChLoc=yChLoc(1:end-1);
    if(length(yChLoc)>(size(fNIRarr,1)-2))
       yChLoc=yChLoc(2:end);
    end
end


xChLoc=xChLoc+brainRectX(1);%+brainRectX(2)-rCrop;
yChLoc=yChLoc+brainRectY(1)-yCrop;

xChLocParts=[brainRectX(1),xChLoc,brainRectX(2)+1]-brainRectX(1);
numXlocs=length(xChLoc);
midArrX_orig(end)=size(rgbArr,2);
midArrX_orig=round(midArrX_orig);
for i=1:length(xChLoc)+1  % break apart into parts, resize each part separately to account for changing channel spacing (x direction)
    rsRGBarr(:,xChLocParts(i)+1:xChLocParts(i+1),:)=imresize(rgbArr(:,midArrX_orig(i):midArrX_orig(i+1),:),[brainRectY(2)+1-brainRectY(1),(xChLocParts(i+1)-xChLocParts(i))]);
end


%yX deformation happens here (ydirection channel spacing changes with x)

%%%Curve handling
flexArrY=zeros(size(xChLocParts));%(2:end-1);
rangeFlexX=round(max(xChLocParts)-min(xChLocParts));
midpointX=(length(xChLocParts)+1)/2;

if(rem(midpointX,1)~=0)
    midpointX=mean(xChLocParts);
else
    midpointX=xChLocParts(midpointX);
end

nDeformBuffer=68;
nDeformAngle=0.4;

constAngle=pi/(rangeFlexX/2)*nDeformAngle;
flexArrX=(xChLocParts-midpointX);
flexArrY=-1*cos(constAngle*(flexArrX));
yChLocShift=(flexArrY-min(flexArrY))/(max(flexArrY)-min(flexArrY))*nDeformBuffer/2;
flexArrImgY=-1*cos(constAngle*([1:rangeFlexX]-midpointX));
flexArrImgY=(flexArrImgY-min(flexArrImgY))/(max(flexArrY)-min(flexArrY))*nDeformBuffer/2;

%get nullColor
nullColInd=ind2rgb(0,cmp);
nullCol=rgb2ind(nullColInd,cmp);

warpedRSrgb=nan(size(rsRGBarr,1)+nDeformBuffer,size(rsRGBarr,2),3);
warpedRSrgb(:,:,1)=nullColInd(1);
warpedRSrgb(:,:,2)=nullColInd(2);
warpedRSrgb(:,:,3)=nullColInd(3);

for i=1:size(rsRGBarr,2)
    offset=floor(flexArrImgY(i));
    warpedRSrgb(offset+1:(offset+size(rsRGBarr,1)),i,:)=rsRGBarr(:,i,:);
end

temp=rgb2ind(warpedRSrgb,nCol);

maskArr=temp>mode(temp(:));

if(nnz(~maskArr)==0)
    maskArr=(warpedRSrgb(:,:,1)==nullCol(1)&...
        warpedRSrgb(:,:,2)==nullCol(2)&...
        warpedRSrgb(:,:,3)==nullCol(3));
end

 
brainRectY(2)=brainRectY(2)+nDeformBuffer;

% Masking happens here based on null colors
maskRect=zeros(bYlen,bXlen);
maskRect(brainRectY(1):brainRectY(2),brainRectX(1):brainRectX(2))=maskArr;
maskRect=maskRect==1;



%figure(11);
hold off;
colormap(gca,cmp);

if(~emptyplot)
    caxis([minVal,maxVal]);
end

blank=double(brainImg*0);
blank(brainRectY(1):brainRectY(2),brainRectX(1):brainRectX(2),:)=blank(brainRectY(1):brainRectY(2),brainRectX(1):brainRectX(2),:)+warpedRSrgb(:,:,:);



for i=1:3 % Merge image one at a time according to mask
    l1=brainImg(:,:,i);
    %rgbL=rsRGBarr(:,:,i);
    
    b1=256*blank(:,:,i);
    if(~transparent)
        l1(maskRect)=b1(maskRect);
    else
        l1(maskRect)=round(double(l1(maskRect))/4+double(b1(maskRect)*3/4));
    end
    brainImg(:,:,i)=l1;
end




brainImg=brainImg(yCrop:end,1:xCrop,:);
bImg=image(brainImg);
% set(bImg,'border',0);


set(gca,'xtick',[]);
set(gca,'ytick',[]);
axis image;

h=gca;

% if(invertAxis)
%     cmp=cmp(size(cmp,1):-1:1,:);
% %    colormap(cmp)
% end
% 

if(~emptyplot)
    c=colorbar();
    colormap(gca,cmp);


    if(invertAxis)
       t=minVal;
       minVal=-maxVal;
       maxVal=-t; 
    end

    if(logScale)
        maxVal=10^(maxVal);
        minVal=10^(minVal);
    end

    caxis([minVal,maxVal]);
    
    
    if(logScale)

        ticks_wanted=unique([minVal,get(c,'YTick'),maxVal]);
        l=length(ticks_wanted);
        l=5;
        % or for example ticks_wanted=10.^(2:4);
        caxis([log10(minVal),log10(maxVal)]);
        ticks_wanted=log10(minVal):((log10(maxVal)-log10(minVal)))/(l-1):log10(maxVal);
        set(c,'YTick',(ticks_wanted));
        set(c,'YTickLabel',sprintf('%0.5f\n', 10.^ticks_wanted));
    end
    
    if(invertAxis)
        ticks_wanted=(minVal):(maxVal-minVal)/5:(maxVal);
        set(c,'YTick',(ticks_wanted));
        set(c,'YTickLabel',sprintf('%0.2f\n', ticks_wanted(end:-1:1)));
    end


    % c.Position=[h.Position(1)+h.Position(3)*19/20,c.Position(2), c.Position(3),c.Position(4)];
    %c.Position=[h.Position(1)+0.1,h.Position(2)+h.Position(4),h.Position(3),0.03];
    % Idea is c.Position=[h.Position(1)+h.Position(3)*19/20,0.5-h.Position(4)/4,h.Position(3)*1/30,h.Position(4)/2];
    c.LineWidth=1;
    set(c,'FontSize',fontSize-2);
    set(get(c,'title'),'string',cMapLabel);

end

t1=text(bXlen*0.05,bYlen*0.91,'R');
t1.FontSize=fontSize;
t2=text(bXlen*0.8,bYlen*0.91,'L');
t2.FontSize=fontSize;

% l=length(titleTxt)-1;
% tTitle=text(bXlen*0.43-fontSize/3*l,bYlen*0.05,titleTxt);
% tTitle.FontSize=fontSize;
title(titleTxt,'FontSize',fontSize);

if(~brainStyle)
    if(~emptyplot)
        c.Color=[1,1,1];
    end
    set(gcf,'color','k'); 
    t1.Color=[1,1,1];
    t2.Color=[1,1,1];
    tTitle.Color=[1,1,1];
else
   set(gcf,'color','w'); 
end



for(i=1:length(xChLoc))
    for (j=1:length(yChLoc))
        hold on;
        chNum=(length(xChLoc)-i+1)*2-rem((length(yChLoc)-j),2);
        cLen=length(sprintf('%i',chNum));
        
        curYloc=yChLoc(j)+yChLocShift(i+1);
        if(showChannelLabels)
            if(~brainStyle)
                plot(xChLoc(i), curYloc, '.k', 'MarkerSize',42);
                chT=text(xChLoc(i),curYloc,sprintf('%i',chNum),'FontWeight','Bold',...
                    'HorizontalAlignment', 'center','VerticalAlignment', 'middle');
                plot(xChLoc(i), curYloc, 'ok', 'MarkerSize',11);
                chT.Color=[1,1,1];
            else
                %plot(xChLoc(i), yChLoc(j), '.k', 'MarkerSize',42);
                chT=text(xChLoc(i),curYloc,sprintf('%i',chNum),'FontWeight','Bold',...
                    'HorizontalAlignment', 'center','VerticalAlignment', 'middle');
                chT.Color=[0,0,0];
                plot(xChLoc(i), curYloc, 'ok', 'MarkerSize',11);
            end
        else
            plot(xChLoc(i), curYloc, 'ok', 'MarkerSize',10);
            plot(xChLoc(i), curYloc, 'xk', 'MarkerSize',10);
        end
        hold off;
    end
end

end





