function [ imgOut ] = interpolateROIvalues(varargin)
% INTERPOLATEROIVALUES Create interpolated 2D topographic map of ROI values
%
% Generates a smooth, interpolated 2D topographic visualization of fNIRS
% ROI data. Each ROI's value is assigned to all channels within that ROI,
% then the values are interpolated between channel positions to create a
% continuous surface. This is useful for displaying region-level statistics
% while maintaining smooth spatial transitions between regions.
%
% Reference:
%   Internal pf2 implementation for ROI-based topographic visualization.
%   Uses MATLAB makima interpolation for smooth surface generation.
%
% Syntax:
%   InterpolateROIvalues(data2plot)
%   InterpolateROIvalues(data2plot, fNIR)
%   InterpolateROIvalues(data2plot, fNIR, ROIinfo)
%   InterpolateROIvalues(data2plot, fNIR, ROIinfo, minVal, maxVal)
%   InterpolateROIvalues(..., bufferMult, titleString, clrBarTitle)
%   imgOut = InterpolateROIvalues(...)
%
% Inputs:
%   data2plot   - Values to display for each ROI [1 x R double]
%                 Must have one value per ROI defined in ROIinfo or fNIR.ROI.info.
%   fNIR        - fNIRS data structure containing probe info (default: {})
%                 Can also be ROI info table if ROIinfo not provided separately.
%   ROIinfo     - ROI definition table (default: {} uses fNIR.ROI.info)
%                 Table with 'Optodes' and 'DeviceCfg' columns.
%   minVal      - Minimum value for color scale (default: min(data2plot))
%   maxVal      - Maximum value for color scale (default: max(data2plot))
%   bufferMult  - Buffer multiplier for padding around probe (default: 1)
%                 Controls how much padding in units of optode spacing.
%   titleString - Title displayed above the plot (default: '')
%   clrBarTitle - Title for the colorbar (default: '')
%
% Outputs:
%   imgOut - Handle to the image object (optional)
%
% Algorithm:
%   1. Map ROI values to individual channels based on ROI definitions
%   2. Extract 2D optode positions from probe configuration
%   3. Interpolate channel values to high-resolution image grid
%   4. Apply alpha masking to limit visualization to probe coverage area
%   5. Overlay ROI labels at channel positions
%
% Notes:
%   - Requires ROI definitions (either in fNIR.ROI.info or ROIinfo parameter)
%   - ROIs must not contain duplicate channels (overlapping ROIs not supported)
%   - ROI names are displayed as text labels on the plot
%
% Example:
%   % Define ROIs and create interpolated visualization
%   data = pf2.import.sampleData.fNIR2000();
%   processed = processFNIRS2(data);
%   processed = pf2.probe.roi.defineROI(processed, {1:6, 7:12, 13:18}, ...
%                                       {'Left', 'Center', 'Right'});
%   roiStats = [0.8, 1.2, 0.5];  % Example statistics per ROI
%   pf2.probe.plot.interpolateROIvalues(roiStats, processed, [], [], [], ...
%                                       1, 'ROI Statistics', 'Value');
%
% See also: pf2.probe.plot.imageROIvalues, pf2.probe.plot.interpolateValues,
%           pf2.probe.roi.defineROI, pf2_base.fnirs.buildROI

p = inputParser;

isStructOrEmpty=@(x) isstruct(x)||isempty(x) ||istable(x);
isStringOrChar=@(x)isstring(x)||ischar(x);


addRequired(p, 'data2plot');
addOptional(p, 'fNIR', {}, isStructOrEmpty);
addOptional(p, 'ROIinfo',{}, isStructOrEmpty);
addOptional(p, 'minVal', [], @isnumeric);
addOptional(p, 'maxVal', [], @isnumeric);
addOptional(p, 'bufferMult', 1, @isnumeric);
addOptional(p, 'titleString', '', isStringOrChar);
addOptional(p, 'clrBarTitle', '', isStringOrChar);
addParameter(p, 'savePath', '', @(x) ischar(x) || isstring(x));
addParameter(p, 'saveWidth', [], @(x) isempty(x) || isnumeric(x));
addParameter(p, 'saveHeight', [], @(x) isempty(x) || isnumeric(x));
addParameter(p, 'saveDPI', 150, @isnumeric);

parse(p, varargin{:});

clrBarTitle = p.Results.clrBarTitle;
titleString = p.Results.titleString;
bufferMult = round(p.Results.bufferMult);
minVal = p.Results.minVal;
maxVal = p.Results.maxVal;
fNIR = p.Results.fNIR;
data2plot = p.Results.data2plot;
ROIinfo = p.Results.ROIinfo;
savePath = p.Results.savePath;
saveWidth = p.Results.saveWidth;
saveHeight = p.Results.saveHeight;
saveDPI = p.Results.saveDPI;

if(isempty(ROIinfo))
    if(~isempty(fNIR)&&istable(fNIR)&&any(ismember(fNIR.Properties.VariableNames,'DeviceCfg')))%%is struct for ROI info?
        ROIinfo=fNIR;
        deviceCfg=ROIinfo.DeviceCfg{1};
    else
        ROIinfo=[];
    end
else
    deviceCfg = ROIinfo.DeviceCfg{1};
end

if(isempty(ROIinfo)&&~isempty(fNIR)&&~pf2_base.isnestedfield(fNIR,'ROI.info')&&~isempty(fNIR.info))
    error('No ROI information in the fNIR struct, unable to plot data');
elseif(isempty(ROIinfo))
    ROIinfo=fNIR.ROI.info;
    if(pf2_base.isnestedfield(fNIR,'info.probename'))
        deviceCfg=fNIR.info.probename;
    else
       deviceCfg=''; 
    end
end

if(isempty(maxVal))
    maxVal=nanmax(data2plot);
end

if(isempty(minVal))
   minVal=nanmin(data2plot); 
end

if(~isempty(deviceCfg)&&~contains(deviceCfg,'Unknown')) 
    %try to load the probename cfg file
    cfgFilePath=sprintf('%s.cfg',deviceCfg);
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

numROI=size(ROIinfo,1);

if(~isempty(ROIinfo)&&length(data2plot)>numROI)
    error('Must have a value for all ROIs');
end



allCh=[];
chData2plot=nan(height(probeInfo.TableOpt));

mrkLbl=cell(size(chData2plot));
mrkLbl(:)={''};

ROInames=ROIinfo.Properties.RowNames;

for roiIdx=1:numROI

    if(~strcmp(deviceCfg,ROIinfo.DeviceCfg(roiIdx)))
        continue;
    end

    curCh=ROIinfo.Optodes{roiIdx};
    
    for(optIdx=1:length(curCh))
        optNum=probeInfo.TableOpt.OptodeNum(curCh(optIdx));

        chData2plot(optNum)=data2plot(ROIinfo.index(roiIdx));
        mrkLbl{optNum}=ROInames{ROIinfo.index(roiIdx)};
    end
    
    allCh=[allCh,curCh];
    if(length(unique(allCh))>length(allCh))
        error('ROIs contain duplicate channels'); 
    end
end

imgSize=1000;

OptPosX=probeInfo.TableOpt.Pos2D_x(~probeInfo.TableOpt.IsShortSeparation);
OptPosY=probeInfo.TableOpt.Pos2D_y(~probeInfo.TableOpt.IsShortSeparation);

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


buffer=bufferSize*pixelPerCm/2;

if(OptDistX==OptDistY)
    [inpX,inpY]=meshgrid(0:OptDistX*pixelPerCm:(maxDimDist+bufferSize*3)*pixelPerCm);
else
    [inpX,inpY]=meshgrid(0:OptDistX*pixelPerCm:(maxDimDist+bufferSize*3)*pixelPerCm);
    %error('Haven''t accoutned for this yet');
end

interpBuffer=ones(size(inpX))*minVal;
alphaBuffer=ones(size(inpX))*-1;

numRows=size(inpY,1);

for optIdx=1:length(chData2plot)
    optNum=probeInfo.TableOpt.OptodeNum(optIdx);
    optXidx(optIdx)=round(OptPosX(optNum)/OptDistX+bufferMult+1);
    if(isempty(OptDistY))
        optYidx(optIdx)=bufferMult+1;
    else
        optYidx(optIdx)=round(OptPosY(optNum)/OptDistY+bufferMult+1);
    end
    if(~isnan(chData2plot(optIdx))&&chData2plot(optIdx)>minVal)
        interpBuffer(optYidx(optIdx),optXidx(optIdx))=chData2plot(optIdx);
        alphaBuffer(optYidx(optIdx),optXidx(optIdx))=1;
    else
        interpBuffer(optYidx(optIdx),optXidx(optIdx))=minVal;
    end
    
end



%interpBuffer=interpBuffer(end:-1:1,:);
%alphaBuffer=alphaBuffer(end:-1:1,:);

[Xq,Yq] = meshgrid(1:imgSize);



intArr=interp2(inpX,inpY,interpBuffer,Xq,Yq,'makima',minVal);%,method,extrapval)
intArrAlpha=interp2(inpX,inpY,alphaBuffer,Xq,Yq,'cubic',-1);%,method,extrapval)
intArrLinear=interp2(inpX,inpY,alphaBuffer,Xq,Yq,'linear',-1);%,method,extrapval)

intArrAlpha(intArrAlpha<0)=0;
intArrAlpha(intArrLinear<0)=0;

x2keep=round([inpX(1,min(optXidx)-bufferMult)+1,inpX(1,min(max(optXidx)+bufferMult,length(optXidx)))]);
y2keep=round([inpY(min(optYidx)-bufferMult,1)+1,inpY(max(optYidx)+bufferMult,1)]);

optPos2Plot=round([inpX(1,optXidx);inpX(1,optYidx)]);


intArr2plot=intArr(y2keep(1):y2keep(2),(x2keep(1)):x2keep(2));
intArrAlpha=intArrAlpha(y2keep(1):y2keep(2),(x2keep(1)):x2keep(2));
intArrAlpha(intArrAlpha==0)=0;


imgFinal=imagesc(intArr2plot,[minVal,maxVal]);
set(gca,'xtick',[]);
set(gca,'ytick',[]);
imgFinal.AlphaData=intArrAlpha;
imgFinal.AlphaDataMapping='scaled';

hold on

plot(optPos2Plot(1,:)/1.01+1,optPos2Plot(2,:)/1.01+1,'O','MarkerSize',25,'LineWidth',3,'color','black', 'MarkerFaceColor', 'k');
for optIdx=1:length(chData2plot)
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

% Save figure if requested
if ~isempty(savePath)
    fig = gcf();
    pf2_base.plot.saveFigure(fig, savePath, saveWidth, saveHeight, saveDPI);
end

end
