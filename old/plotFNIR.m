function [ figHandle ] = plotFNIR(fNIR,channel,showMarkers,yl,baseline)
%PLOTHITATCHI Summary of this function goes here
%   Detailed explanation goes here

%mask=true;

if(nargin<2||isempty(channel))
    channel=1:16;
end

if(nargin<5)
    baseline=false;
end

if(nargin<3)
    showMarkers=[44 45];
end

if(nargin<4 || isempty(ylim))
    yl=[-5,5];
end

if(isequal(channel,[1:16]))
    channel=channel([1 3 5 7 9 11 13 15 2 4 6 8 10 12 14 16]);
end

if(isequal(channel,[1:14]))
    channel=channel([1 3 5 7 9 11 13 2 4 6 8 10 12 14]);
end

if(iscell(fNIR))
   error('This function takes structs not cells'); 
end

if(~isfield(fNIR,'time'))
   error('fNIR data has not yet been processed into Oxy/DeHbDiff. Please use plotFNIRraw instead'); 
end

t=fNIR.time;
if(t(end)==0)
    t(end)=t(end-1)+0.5;
end

if(isfield(fNIR,'markers')&&~isempty(showMarkers))
    curMarkers=fNIR.markers;
    if(~isnumeric(curMarkers)&&isfield(curMarkers,'data'))
        curMarkers=curMarkers.data;
    end
end

for(x=1:length(channel))
    blIndex=find(~isnan(fNIR.HbO(:,channel(x))),1);
    if(length(channel)>1)
        subplot(ceil(length(channel)/8),ceil(length(channel)/ceil(length(channel)/8)),x);
    end
    if(~isfield(fNIR,'fchMask')||fNIR.fchMask(channel(x)))
    hold off;
    if(baseline&&~isempty(blIndex))
        bHbO=fNIR.HbO(blIndex,channel(x));
        bHbR=fNIR.HbR(blIndex,channel(x));
    else
        bHbO=0;
        bHbR=0; 
    end
    
    figHandle=plot(t,fNIR.HbO(:,channel(x))-bHbO,'r');
    hold on;
    plot(t,fNIR.HbR(:,channel(x))-bHbR,'b');
    hold on;
    plot(t,fNIR.HbO(:,channel(x))-fNIR.HbR(:,channel(x))-bHbO+bHbR,'k')
    xlabel(sprintf('Ch %i',channel(x)));
    
    
    if(length(t)>1)
        xlim([min(t),max(t)]);
    end
    ylim(yl);
    
    if(isfield(fNIR,'markers')&&~isempty(showMarkers))
       for i=1:size(curMarkers,1) 
           if(any(curMarkers(i,2)==showMarkers))
                vline(curMarkers(i,1),'k'); 
           end
       end
    end  
    else
        hold off;
        plot(0,0);
    end
    xlabel(sprintf(' Ch %i',channel(x)));
end

end

