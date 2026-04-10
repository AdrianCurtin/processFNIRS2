function versInfoString=plotExTimeline()
% visualize current ExFNIRS processing settings

global ExFNIRS

blEnabled=ExFNIRS.settings.use_baseline;
blStart=ExFNIRS.settings.baseline_start;
blEnd=ExFNIRS.settings.baseline_end;

blockStart=ExFNIRS.settings.block_start;
blockEnd=ExFNIRS.settings.block_end;

plotStart=ExFNIRS.settings.plot_start;
plotEnd=ExFNIRS.settings.plot_end;

blk_resample_size=ExFNIRS.settings.barchart_resample_size;
grandavg_resample_size=ExFNIRS.settings.grandavg_resample_size;

%plotRange=plotEnd-plotStart;
%blockRange=blockEnd-blockStart;
%blRange=blEnd-blStart;

if(blEnabled)
    starts=[blockStart,blStart,plotStart];
    ends=[blockEnd,blEnd,plotEnd];
else
    starts=[blockStart,plotStart];
    ends=[blockEnd,plotEnd];
end

maxEnd=max(ends);
minStart=min(starts);

minmaxRange=maxEnd-minStart;

minStart=minStart-(minmaxRange)*0.1;
minStart=minStart-max(blk_resample_size,grandavg_resample_size);
maxEnd=maxEnd+(minmaxRange)*0.1;
maxEnd=maxEnd+max(blk_resample_size,grandavg_resample_size);

figure(2700);
hold off;

lineBarHeight=0.045;
lineWeight=4;

plotHeight=0.1;
blHeight=0.25;
blockHeight=0.4;

sigWeight=3;
sigAmp=0.05;
temporalHeight=0.8;
barchartHeight=0.6;

% Dark mode color adaptation
isDark = pf2_base.plot.PlotStyle.isDarkMode();
if isDark
    blockColor = [0.85 0.85 0.85];
    plotColor = [0.4 0.6 1.0];
    blColor = [1.0 0.4 0.4];
    dimColor = [0.45 0.45 0.45];
    blockDash = {'--', 'Color', blockColor, 'HandleVisibility', 'off'};
    plotDash = {'--', 'Color', plotColor, 'HandleVisibility', 'off'};
    blDash = {'--', 'Color', blColor, 'HandleVisibility', 'off'};
else
    blockColor = 'k';
    plotColor = 'b';
    blColor = 'r';
    dimColor = [40,40,40]/255;
    blockDash = {'--k', 'HandleVisibility', 'off'};
    plotDash = {'--b', 'HandleVisibility', 'off'};
    blDash = {'--r', 'HandleVisibility', 'off'};
end

yticks([sort([plotHeight,blHeight,blockHeight,temporalHeight,barchartHeight])]);


plotHorizViewBar([blockStart,blockEnd],blockHeight,lineBarHeight,lineWeight,{'Color',blockColor});

hold on;

plotHorizViewBar([plotStart,plotEnd],plotHeight,lineBarHeight,lineWeight,{'Color',plotColor});
if(blEnabled)
    plotHorizViewBar([blStart,blEnd],blHeight,lineBarHeight,lineWeight,{'Color',blColor});
end

ylim([0,1]);

pf2_base.external.vline([ExFNIRS.settings.block_start,ExFNIRS.settings.block_end],blockDash);

pf2_base.external.vline([ExFNIRS.settings.plot_start,ExFNIRS.settings.plot_end],plotDash);

if(blEnabled)
    pf2_base.external.vline([ExFNIRS.settings.baseline_start,ExFNIRS.settings.baseline_end],blDash);
end

% Plot temporal signal
plotPeriodicSample(minStart-grandavg_resample_size,maxEnd+grandavg_resample_size,blockStart,temporalHeight,sigAmp,grandavg_resample_size,sigWeight/4,{'Color',dimColor});

plotPeriodicSample(plotStart,plotEnd,blockStart,temporalHeight,sigAmp,grandavg_resample_size,sigWeight/2,{'Color',[50,200,78]/255});


% Plot barchart/block signal
plotPeriodicSample(minStart-blk_resample_size,maxEnd+blk_resample_size,blockStart,barchartHeight,sigAmp,blk_resample_size,sigWeight/4,{'lineStyle','--','Color',dimColor});
plotPeriodicSample(plotStart,plotEnd,blockStart,barchartHeight,sigAmp,blk_resample_size,sigWeight,{'Color',[150,30,178]/255});



hold off;


xlim([minStart,maxEnd]);

title('ExFNIRS Experiment Time Settings')
xlabel('Time (s)');

[ytickVals,srtIdx]=sort([plotHeight,blHeight,blockHeight,temporalHeight,barchartHeight]);
yticks(ytickVals);
ytLabels={sprintf('Plot View [%.1f–%.1fs]', plotStart, plotEnd), ...
    sprintf('Baseline [%.1f–%.1fs]', blStart, blEnd), ...
    sprintf('Task Block [%.1f–%.1fs]', blockStart, blockEnd), ...
    sprintf('Temporal (%.2fs, %.1fHz)', grandavg_resample_size, 1/grandavg_resample_size), ...
    sprintf('Barchart (%.2fs)', blk_resample_size)};
yticklabels(ytLabels(srtIdx));

end

function plotPeriodicSample(startTime,endTime,centerTime,sigHeight,sigAmp,rsLen,weight,style)
    if(nargin<7)
        style={'Color','Red'};
    end
    if(nargin<6)
        weight=2.5;
    end
    if(nargin<5)
        rsLen=1;
    end
    if(nargin<4)
        sigAmp=0.5;
    end
    if(nargin<3)
        centerTime=0;
    end

    %startTime=startTime-rem(startTime,rsLen);
    startTimePlt=centerTime+floor((startTime-centerTime)/rsLen)*rsLen;
    if(startTimePlt<startTime)
        startTimePlt=startTimePlt+rsLen;
    end

    sigLen=ceil((endTime-startTimePlt)/rsLen)+(rem(endTime-startTimePlt,rsLen)==0);
    idx=1:sigLen;

    xPoints=round(startTimePlt+(idx-1)*rsLen,5);

    centerIdx=find(xPoints==centerTime,1);
    if isempty(centerIdx)
        offset0=0;
    else
        offset0=rem(centerIdx+1,2);
    end

    if(isnan(sigLen))
        return;
    end

    yPoints= sigHeight-sigAmp/2+ones(1,sigLen)*sigAmp.*(rem(idx+offset0,2)==0);
    yPoints=repelem(yPoints,2);

    if(~isempty(yPoints))
        yPoints(1)=[];
        yPoints(end+1)=yPoints(1);
    end

    xPoints=repelem(xPoints,2);

    plot(xPoints,yPoints,style{:},'lineWidth',weight);
end

function plotHorizViewBar(points,lineHeight,barHeight,weight,style)
    if(nargin<5)
        style={'Color','Red'};
    end
    if(nargin<4)
        weight=2.5;
    end
    if(nargin<3)
        barHeight=0.1;
    end
    if(nargin<2)
        lineHeight=0.5;
    end
        topPoint=lineHeight+barHeight;
        bottomPoint=lineHeight-barHeight;
        midPoint=lineHeight;
        leftPoint=min(points);
        rightPoint=max(points);
        yPoints=[topPoint,bottomPoint,midPoint,midPoint,bottomPoint,topPoint];
        xPoints=[leftPoint,leftPoint,leftPoint,rightPoint,rightPoint,rightPoint];
    
        plot(xPoints,yPoints,style{:},'lineWidth',weight);
    end