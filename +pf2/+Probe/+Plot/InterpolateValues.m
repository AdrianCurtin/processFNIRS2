function [ imgOut,optPos2Plot ] = InterpolateValues(varargin)
% INTERPOLATEVALUES Create interpolated 2D topographic map of channel values
%
% Generates a smooth, interpolated 2D topographic visualization of fNIRS
% channel data. Values are interpolated between channel positions using
% makima interpolation to create a continuous surface representation.
% Supports both single-sided and two-sided colormaps for displaying
% activation/deactivation patterns. Short separation channels are excluded
% from visualization.
%
% Reference:
%   Internal pf2 implementation for topographic visualization.
%   Uses MATLAB makima interpolation for smooth surface generation.
%
% Syntax:
%   InterpolateValues(data2plot)
%   InterpolateValues(data2plot, fNIR)
%   InterpolateValues(data2plot, fNIR, minVal, maxVal)
%   InterpolateValues(data2plot, fNIR, minVal, maxVal, titleString, clrBarTitle)
%   [imgOut, optPos2Plot] = InterpolateValues(...)
%   InterpolateValues(..., 'bufferDistance', 1)
%
% Inputs:
%   data2plot      - Values to display for each channel [1 x C double]
%                    Must have one value per optode/channel in the probe.
%   fNIR           - fNIRS data structure containing probe info (default: {})
%                    If empty, attempts to load from global setF or prompts user.
%   minVal         - Minimum value(s) for color scale (default: min(data2plot))
%                    For two-sided colormap, pass [negMin, posMin] to create
%                    separate hot/cold colormaps with a gap in between.
%   maxVal         - Maximum value for color scale (default: max(data2plot))
%   titleString    - Title displayed above the plot (default: '')
%   clrBarTitle    - Title for the colorbar (default: '')
%   'bufferDistance' - Buffer distance around probe in optode spacing units
%                      (default: 1). Controls how much padding around edges.
%
% Outputs:
%   imgOut      - Handle to the image object (optional)
%   optPos2Plot - Pixel positions of optodes in the plot [2 x C]
%                 Row 1: X positions, Row 2: Y positions
%
% Algorithm:
%   1. Extract 2D optode positions from probe configuration
%   2. Create sparse grid at optode locations with data values
%   3. Fill interior grid points with neighbor-averaged values
%   4. Interpolate to high-resolution image using makima method
%   5. Apply alpha masking to limit visualization to probe coverage area
%
% Example:
%   % Create interpolated HbO topography
%   data = pf2.Import.SampleData.fNIR2000();
%   processed = processFNIRS2(data);
%   timepoint = 100;  % Sample index
%   hboVals = processed.HbO(timepoint, :);
%   pf2.Probe.Plot.InterpolateValues(hboVals, processed, -1, 1, ...
%                                    'HbO at t=10s', 'uM');
%
%   % Two-sided colormap for activation/deactivation
%   pf2.Probe.Plot.InterpolateValues(hboVals, processed, [-0.5, 0.5], [], ...
%                                    'HbO Changes');
%
% Notes:
%   - Short separation channels are automatically excluded
%   - Two-sided colormap uses hot colors for positive, cool for negative
%   - NaN values in data are handled gracefully
%
% See also: pf2.Probe.Plot.InterpolateValues3D, pf2.Probe.Plot.ImageValues,
%           pf2.Probe.Plot.InterpolateROIvalues, pf2.Data.Plot.Oxy
p = inputParser;

isStructOrEmpty=@(x) isstruct(x)||isempty(x);
isStringOrChar=@(x)isstring(x)||ischar(x);

addRequired(p, 'data2plot');
addOptional(p, 'fNIR', {}, isStructOrEmpty);
addOptional(p, 'minVal', [], @isnumeric);
addOptional(p, 'maxVal', [], @isnumeric);
addOptional(p, 'titleString', '', isStringOrChar);
addOptional(p, 'clrBarTitle', '', isStringOrChar);
addParameter(p, 'bufferDistance', 1, @isnumeric);

parse(p, varargin{:});

clrBarTitle = p.Results.clrBarTitle;
titleString = p.Results.titleString;
bufferDistance = round(p.Results.bufferDistance);
minVal = p.Results.minVal;
maxVal = p.Results.maxVal;
fNIR = p.Results.fNIR;
data2plot = p.Results.data2plot;

if(isempty(minVal))
    minVal=nanmin(data2plot);
end

if(isempty(maxVal))
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
    if(length(setF)>1)
        setF=setF(1);
    end
    
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

include_ss=false;
if(~include_ss)
    numOptodes=sum(~probeInfo.TableOpt.IsShortSeparation);
    channelList=probeInfo.TableOpt.OptodeNum(~probeInfo.TableOpt.IsShortSeparation);
    optLayout=probeInfo.OptPos.subplot_layout;
    if(length(data2plot)~=numOptodes&&length(data2plot)==height(probeInfo.TableOpt))
        
        data2plot=data2plot(~probeInfo.TableOpt.IsShortSeparation);
    end
end


if(length(data2plot)~=numOptodes)
    error('Must have a value for all optodes');
end

%clf(gcf)


%h{1}= axes('Position',[0.05,0.05,0.9,0.9],'Box','on');

imgSize=1000;

OptPosX=probeInfo.OptPos.x_2d(~probeInfo.TableOpt.IsShortSeparation);
OptPosY=probeInfo.OptPos.y_2d(~probeInfo.TableOpt.IsShortSeparation);


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


bufferSize=bufferDistance*OptDistX;
pixelPerCm=imgSize/max([dimX+bufferSize*2,dimY+bufferSize*2]);

%optDataSize=10;

OptPosX=OptPosX-minPosX;
OptPosY=OptPosY-minPosY;


buffer=bufferSize*pixelPerCm/2;

if(round(OptDistX,1)==(round(OptDistY,1)))
    [inpX,inpY]=meshgrid(0:OptDistX*pixelPerCm:(maxDimDist+bufferSize*2)*pixelPerCm);
    
    
    %maxIdxX=round(dimX/OptDistX)+bufferDistance+2;
    %maxIdxY=round(dimY/OptDistY)+bufferDistance+2;
    %inpX=inpX(1:maxIdxX,1:maxIdxY);
    %inpY=inpY(1:maxIdxX,1:maxIdxY);
    
    interpBuffer=nan(size(inpX));
    alphaBuffer=zeros(size(inpX));
    
    if(twosided)
        alphaBufferNeg=alphaBuffer;
    end
    
    numRows=size(inpY,1);
    % Need to fill in small array middle with interpolated values instead of
    % minimum
    for optIdx=1:length(data2plot)
        %if optIdx > 16
        %    continue
        %end
        
        optXidx(optIdx)=round(OptPosX(optIdx)/OptDistX)+bufferDistance+1;
        optYidx(optIdx)=round(OptPosY(optIdx)/OptDistY)+bufferDistance+1;
        
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
    
    x2keep=round([inpX(1,min(optXidx)-bufferDistance)+1,inpX(1,max(optXidx)+bufferDistance)]);
    y2keep=round([inpY(min(optYidx)-bufferDistance,1)+1,inpY(max(optYidx)+bufferDistance,1)]);
    
    optPos2Plot=round([inpX(1,optXidx);inpX(1,optYidx)]);
    
    if(twosided)
        intArrAlphaNeg=intArrAlpha(y2keep(1):y2keep(2),(x2keep(1)):x2keep(2));
        %intArrAlphaNeg(intArrAlphaNeg==0)=0;
    end
    
else
    
    
    % Calculate the size of the interpolation grid
    maxX = max(OptPosX);
    maxY = max(OptPosY);
    
    % flip X and Y
    
    %OptPosX = maxX-OptPosX;
    %OptPosY = maxY-OptPosY;
    
    % Create a fine mesh for interpolation
    [Xq, Yq] = meshgrid(linspace(0, maxX, imgSize), linspace(0, maxY, imgSize));
    
    % Perform the interpolation
    if twosided
        intArr = griddata(OptPosX, OptPosY, data2plot, Xq, Yq, 'cubic');
    elseif minVal > maxVal
        intArr = griddata(OptPosX, OptPosY, data2plot, Xq, Yq, 'cubic');
        intArr(isnan(intArr)) = maxVal;
        intArr(intArr<maxVal)=maxVal;
    else
        intArr = griddata(OptPosX, OptPosY, data2plot, Xq, Yq, 'cubic');
        intArr(isnan(intArr)) = minVal;
        intArr(intArr<minVal)=minVal;
    end
    
    % Calculate alpha values
    rawGrid = griddata(OptPosX, OptPosY, data2plot, Xq, Yq, 'cubic');
    alphaValues = ~isnan(rawGrid);
    if twosided
        alphaValues = alphaValues.*(rawGrid>minVal(2));
        alphaValuesNeg = ~isnan(rawGrid).*rawGrid<minVal(1);
        
        intArrAlphaNeg = imgaussfilt(double(alphaValuesNeg), 10);  % Gaussian filter for smooth edges
    end
    
    intArrAlpha = imgaussfilt(double(alphaValues), 10);  % Gaussian filter for smooth edges
    
    % Adjust the plotting code
    x2keep = [1, imgSize];
    y2keep = [1, imgSize];
    
    intArr2plot = intArr;
    
    optPos2Plot = [interp1(linspace(0, maxX, imgSize), 1:imgSize, OptPosX),...
        interp1(linspace(0, maxY, imgSize), 1:imgSize, OptPosY)]';
    
    
end




intArr2plot=intArr(y2keep(1):y2keep(2),(x2keep(1)):x2keep(2));
%intArr2plotNeg=intArr(y2keep(1):y2keep(2),(x2keep(1)):x2keep(2));
intArrAlpha=intArrAlpha(y2keep(1):y2keep(2),(x2keep(1)):x2keep(2));
%intArrAlpha(intArrAlpha==0)=0;



%imgFinal=imagesc(intArr,[minVal,maxVal]);

ax1=gca;
set(ax1,'YDir','normal');

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
    set(gca,'YDir','normal');
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
    optNum=probeInfo.TableOpt.OptodeNum(optIdx);
    mrkLbl{optIdx}=num2str(optNum);
    %if optIdx > 16
    %    continue
    %end
    %t=text(optPos2Plot(1,optIdx)/1.01+1,optPos2Plot(2,optIdx)/1.01+1,mrkLbl{optIdx},'FontSize',11,'VerticalAlignment','middle','HorizontalAlignment', 'left','color','white');
    %t2=text(optPos2Plot(1,optIdx)/1.01+1,optPos2Plot(2,optIdx)/1.01+1,mrkLbl{optIdx},'FontSize',8,'VerticalAlignment','middle','HorizontalAlignment', 'right','color','white');
    %t.FontWeight='bold';
    t=text(optPos2Plot(1,optIdx)/1.01+1,optPos2Plot(2,optIdx)/1.01+1,mrkLbl{optIdx},'BackgroundColor','Black','margin',0.25,'FontSize',10,'VerticalAlignment','middle','HorizontalAlignment', 'center','color','white');
    
    t.FontWeight='bold';
    
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


