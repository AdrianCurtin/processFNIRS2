function [ imgOut ] = imageROIvalues(fNIR,data2plot,minVal,maxVal,titleString,clrBarTitle)
% IMAGEROIVALUES Display per-ROI values as a 2D image heatmap
%
% Creates a 2D image visualization where each region of interest (ROI) is
% colored according to its data value. All channels belonging to the same ROI
% are filled with the same color. This function is useful for displaying
% ROI-level statistics or averaged responses while preserving the spatial
% relationship between ROIs in the probe layout.
%
% Reference:
%   Internal pf2 implementation for ROI-based visualization.
%
% Syntax:
%   ImageROIvalues(fNIR, data2plot)
%   ImageROIvalues(fNIR, data2plot, minVal, maxVal)
%   ImageROIvalues(fNIR, data2plot, minVal, maxVal, titleString)
%   ImageROIvalues(fNIR, data2plot, minVal, maxVal, titleString, clrBarTitle)
%   imgOut = ImageROIvalues(...)
%
% Inputs:
%   fNIR        - fNIRS data structure containing ROI.info field
%                 ROI.info must be a table with 'Optodes' column specifying
%                 which channels belong to each ROI.
%   data2plot   - Values to display for each ROI [1 x R double]
%                 Must have one value per ROI defined in fNIR.ROI.info.
%   minVal      - Minimum value for color scale (default: min(data2plot))
%   maxVal      - Maximum value for color scale (default: max(data2plot))
%   titleString - Title displayed above the plot (default: '')
%   clrBarTitle - Title for the colorbar (default: '')
%
% Outputs:
%   imgOut - Handle to the image object (optional)
%
% Notes:
%   - Requires fNIR.ROI.info to be defined before calling this function
%   - ROIs must not contain duplicate channels (overlapping ROIs not supported)
%
% Example:
%   % Define ROIs and plot ROI-averaged HbO
%   data = pf2.import.sampleData.fNIR2000();
%   processed = processFNIRS2(data);
%   processed = pf2.probe.roi.defineROI(processed, {1:6, 7:12, 13:18}, ...
%                                       {'Left', 'Center', 'Right'});
%   roiMeans = [mean(processed.HbO(:,1:6), 'all'), ...
%               mean(processed.HbO(:,7:12), 'all'), ...
%               mean(processed.HbO(:,13:18), 'all')];
%   pf2.probe.plot.imageROIvalues(processed, roiMeans, [], [], 'ROI Means');
%
% See also: pf2.probe.plot.imageValues, pf2.probe.plot.interpolateROIvalues,
%           pf2.probe.roi.defineROI, pf2_base.fnirs.buildROI


if(~isempty(fNIR)&&~pf2_base.isnestedfield(fNIR,'ROI.info')&&~isempty(fNIR.info))
    error('No ROI information in the fNIR struct, unable to plot data');
end

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
    if(~isempty(probeInfo))
        error('No valid devices selected');
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
   error('Unable to identify probe'); 
end

numROI=size(fNIR.ROI.info,1);

if(~isempty(fNIR)&&length(data2plot)>numROI)
    error('Must have a value for all ROIs');
end




h{1}= axes('Position',[0.05,0.05,0.9,0.9],'Box','on');

imgSize=1000;
imgData=nan(imgSize,imgSize);


allCh=[];

for roiIdx=1:numROI
    curCh=fNIR.ROI.info.Optodes{roiIdx};
    
    for(optIdx=1:length(curCh))
        optNum=probeInfo.ChannelList(curCh(optIdx));

        optPos=probeInfo.OptLayout2D{optNum};
        
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
        error('ROIs contain duplicate channels'); 
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
