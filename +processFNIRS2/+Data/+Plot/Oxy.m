function [ figHandle ] = Oxy(fNIR,channels,showMarkers,ylimit,baseline)
%processFNIRS2.Data.Plot.Oxy
%   Plots the dataset with individual channels or autoarranged


if(nargin<2||isempty(channels))
    channels=1:16;
end

if(nargin<5)
    baseline=false;
end

if(nargin<3)
    showMarkers=[44 45];
end

if(nargin<4 || isempty(ylim))
    ylimit=[-5,5];
end

if(isequal(channels,[1:16]))
    channels=channels([1 3 5 7 9 11 13 15 2 4 6 8 10 12 14 16]);
end

if(isequal(channels,[1:14]))
    channels=channels([1 3 5 7 9 11 13 2 4 6 8 10 12 14]);
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

for(x=1:length(channels))
    blIndex=find(~isnan(fNIR.HbO(:,channels(x))),1);
    if(length(channels)>1)
        subplot(ceil(length(channels)/8),ceil(length(channels)/ceil(length(channels)/8)),x);
    end
    if(~isfield(fNIR,'fchMask')||fNIR.fchMask(channels(x)))
    hold off;
    if(baseline&&~isempty(blIndex))
        bHbO=fNIR.HbO(blIndex,channels(x));
        bHbR=fNIR.HbR(blIndex,channels(x));
    else
        bHbO=0;
        bHbR=0; 
    end
    
    figHandle=plot(t,fNIR.HbO(:,channels(x))-bHbO,'r');
    hold on;
    plot(t,fNIR.HbR(:,channels(x))-bHbR,'b');
    hold on;
    plot(t,fNIR.HbO(:,channels(x))-fNIR.HbR(:,channels(x))-bHbO+bHbR,'k')
    xlabel(sprintf('Ch %i',channels(x)));
    
    
    if(length(t)>1)
        xlim([min(t),max(t)]);
    end
    ylim(ylimit);
    
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
    xlabel(sprintf(' Ch %i',channels(x)));
end

end

