function [ imgOut ] = imageROIvalues(fNIR, data2plot, varargin)
% IMAGEROIVALUES Display per-ROI values as a 2D image heatmap
%
% Creates a 2D image visualization where each region of interest (ROI) is
% colored according to its data value. All channels belonging to the same ROI
% are filled with the same color. This function is useful for displaying
% ROI-level statistics or averaged responses while preserving the spatial
% relationship between ROIs in the probe layout.
%
% Syntax:
%   pf2.probe.plot.imageROIvalues(fNIR, data2plot)
%   pf2.probe.plot.imageROIvalues(fNIR, data2plot, Name, Value)
%   imgOut = pf2.probe.plot.imageROIvalues(...)
%
% Inputs:
%   fNIR        - fNIRS data structure containing ROI.info field
%   data2plot   - Values to display for each ROI [1 x R double]
%
% Options (Name-Value):
%   'minVal'      - Minimum value for color scale (default: min(data2plot))
%   'maxVal'      - Maximum value for color scale (default: max(data2plot))
%   'title'       - Title displayed above the plot (default: '')
%   'colorbarTitle' - Title for the colorbar (default: '')
%   'savePath'    - '' (default), filename to save figure (.png, .pdf, .fig)
%   'saveWidth'   - [] (default), figure width in pixels
%   'saveHeight'  - [] (default), figure height in pixels
%   'saveDPI'     - 150 (default), resolution for raster formats
%
% Outputs:
%   imgOut - Handle to the image object (optional)
%
% Example:
%   pf2.probe.plot.imageROIvalues(data, roiMeans)
%   pf2.probe.plot.imageROIvalues(data, roiMeans, 'minVal', -2, 'maxVal', 2)
%   pf2.probe.plot.imageROIvalues(data, roiMeans, 'title', 'ROI Means', ...
%                                  'savePath', 'roi_plot.png')
%
% See also: pf2.probe.plot.imageValues, pf2.probe.plot.interpolateROIvalues,
%           pf2.probe.roi.defineROI, pf2_base.fnirs.buildROI

% Validate fNIR input
if ~isstruct(fNIR)
    error('pf2:InvalidInput', 'First argument must be a fNIRS data structure');
end

if(~isempty(fNIR)&&~pf2_base.isnestedfield(fNIR,'ROI.info')&&~isempty(fNIR.info))
    error('pf2:probe:imageROIvalues:noROIInfo', 'No ROI information in the fNIR struct, unable to plot data');
end

% Parse name-value pairs
p = inputParser;
p.CaseSensitive = false;
addParameter(p, 'minVal', [], @(x) isempty(x) || isnumeric(x));
addParameter(p, 'maxVal', [], @(x) isempty(x) || isnumeric(x));
addParameter(p, 'title', '', @(x) ischar(x) || isstring(x));
addParameter(p, 'colorbarTitle', '', @(x) ischar(x) || isstring(x));
addParameter(p, 'savePath', '', @(x) ischar(x) || isstring(x));
addParameter(p, 'saveWidth', [], @(x) isempty(x) || isnumeric(x));
addParameter(p, 'saveHeight', [], @(x) isempty(x) || isnumeric(x));
addParameter(p, 'saveDPI', 150, @isnumeric);

parse(p, varargin{:});

minVal = p.Results.minVal;
maxVal = p.Results.maxVal;
titleString = p.Results.title;
clrBarTitle = p.Results.colorbarTitle;
savePath = p.Results.savePath;
saveWidth = p.Results.saveWidth;
saveHeight = p.Results.saveHeight;
saveDPI = p.Results.saveDPI;

% Set defaults for min/max if not provided
if isempty(maxVal)
    maxVal = nanmax(data2plot);
end

if isempty(minVal)
    minVal = nanmin(data2plot);
end

if(~isempty(fNIR)&&pf2_base.isnestedfield(fNIR,'info.probename')&&isfield(fNIR.info,'probename')&&~contains(fNIR.info.probename,'Unknown'))
    %try to load the probename cfg file
    cfgFilePath=sprintf('%s.cfg',fNIR.info.probename);
else
    cfgFilePath='';
end


if(~isempty(fNIR)&&(isempty(cfgFilePath)||~contains(cfgFilePath,'.cfg')))

    warning('Missing or invalid configuration file path\n')

    disp('No device specified. Please load device configuration');
    probeInfo=pf2_base.loadDeviceCfg([],true);
    if(isempty(probeInfo))
        error('pf2:probe:imageROIvalues:noDevice', 'No valid devices selected');
    end

elseif(~isempty(fNIR)&&~isempty(cfgFilePath)) % If we're not looking at the GUI, doesn't matter
    probeInfo=pf2_base.loadDeviceCfg(cfgFilePath,true);
end

if(~isempty(fNIR)&&pf2_base.isnestedfield(probeInfo,'Probe'))
    deviceInfo=probeInfo.Info;
    if(~isfield(deviceInfo,'numberProbes')||deviceInfo.numberProbes==1)
        probeNum=1;
    end
    probeInfo=probeInfo.Probe{probeNum};
elseif(~isempty(fNIR))
   error('pf2:probe:imageROIvalues:noProbe', 'Unable to identify probe');
end

numROI=size(fNIR.ROI.info,1);

if(~isempty(fNIR)&&length(data2plot)>numROI)
    error('pf2:probe:imageROIvalues:roiCountMismatch', 'Must have a value for all ROIs');
end




h{1}= axes('Position',[0.05,0.05,0.9,0.9],'Box','on');

imgSize=1000;
imgData=nan(imgSize,imgSize);


allCh=[];

for roiIdx=1:numROI
    curCh=fNIR.ROI.info.Optodes{roiIdx};

    for(optIdx=1:length(curCh))
        optPos=probeInfo.OptPos.subplot_layout{curCh(optIdx)};

        optPos([2])=1-optPos([2])-optPos([4]); %flips y vertical axis

        x1=round(optPos(1)*imgSize);
        y1=round(optPos(2)*imgSize);
        x2=round(optPos(3)*imgSize+x1);
        y2=round(optPos(4)*imgSize+y1);

        if(~isnan(data2plot(roiIdx)))
            imgData(y1:y2,x1:x2)=data2plot(roiIdx);
        end
    end

    allCh=[allCh,curCh];
    if(length(unique(allCh))>length(allCh))
        error('pf2:probe:imageROIvalues:duplicateChannels', 'ROIs contain duplicate channels');
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

% Save figure if requested
if ~isempty(savePath)
    fig = gcf();
    pf2_base.plot.saveFigure(fig, savePath, saveWidth, saveHeight, saveDPI);
end

end
