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

yticks([sort([plotHeight,blHeight,blockHeight,temporalHeight,barchartHeight])]);


plotHorizViewBar([blockStart,blockEnd],blockHeight,lineBarHeight,lineWeight,{'k'});

hold on;

plotHorizViewBar([plotStart,plotEnd],plotHeight,lineBarHeight,lineWeight,{'b'});
if(blEnabled)
    plotHorizViewBar([blStart,blEnd],blHeight,lineBarHeight,lineWeight,{'r'});
    %text(mean([blStart,blEnd]),blHeight+0.05,'\downarrow Baseline Period');
end

%text(mean([plotStart,plotEnd]),plotHeight+0.05,'\downarrow Plot View');

%text(mean([blockStart,blockEnd]),blockHeight+0.05,'\downarrow Task Block Period');

ylim([0,1]);

pf2_base.external.vline([ExFNIRS.settings.block_start,ExFNIRS.settings.block_end],{'--k','HandleVisibility','off'});


pf2_base.external.vline([ExFNIRS.settings.plot_start,ExFNIRS.settings.plot_end],{'--b','HandleVisibility','off'});

if(blEnabled)
    pf2_base.external.vline([ExFNIRS.settings.baseline_start,ExFNIRS.settings.baseline_end],{'--r','HandleVisibility','off'});
    
end 

% Plot temporal signal
plotPeriodicSample(minStart-grandavg_resample_size,maxEnd+grandavg_resample_size,blockStart,temporalHeight,sigAmp,grandavg_resample_size,sigWeight/4,{'Color',[40,40,40]/255});

plotPeriodicSample(plotStart,plotEnd,blockStart,temporalHeight,sigAmp,grandavg_resample_size,sigWeight/2,{'Color',[50,200,78]/255});


% Plot barchart/block signal
plotPeriodicSample(minStart-blk_resample_size,maxEnd+blk_resample_size,blockStart,barchartHeight,sigAmp,blk_resample_size,sigWeight/4,{'lineStyle','--','Color',[40,40,40]/255});
plotPeriodicSample(plotStart,plotEnd,blockStart,barchartHeight,sigAmp,blk_resample_size,sigWeight,{'Color',[150,30,178]/255});



hold off;


xlim([minStart,maxEnd]);

title('ExFNIRS Experiment Time Settings')
xlabel('Time (s)');

[ytickVals,srtIdx]=sort([plotHeight,blHeight,blockHeight,temporalHeight,barchartHeight]);
yticks(ytickVals);
ytLabels={'Plot View','Baseline Period','Task Block Period','Temporal Resample','Barchart Resample'};
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

    offset0=rem(find(xPoints==centerTime)+1,2);

    yPoints= sigHeight-sigAmp/2+ones(1,sigLen)*sigAmp.*(rem(idx+offset0,2)==0);
    yPoints=repelem(yPoints,2);
    yPoints(1)=[];
    yPoints(end+1)=yPoints(1);
    
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