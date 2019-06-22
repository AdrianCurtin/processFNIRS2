function [ figHandle ] = Raw(fNIR,channels)
%processFNIRS2.Plot.Raw  
%   plots an individual channels or autoarranged plot of the channelss based on the device

if(nargin<2)
    channels=1:16;
end


if(length(channels)==16&&isequal(channels,[1:16]))
    channels=channels([1 3 5 7 9 11 13 15 2 4 6 8 10 12 14 16]);
end

if(isequal(channels,[1:14]))
    channels=channels([1 3 5 7 9 11 13 2 4 6 8 10 12 14]);
end

if(isfield(fNIR,'raw'))
    t=fNIR.raw(:,1);
else
   temp=fNIR;
   clear fNIR;
   fNIR.raw=temp;
   t=fNIR.raw(:,1);
end

for(x=1:length(channels))
    
    subplot(ceil(length(channels)/8),ceil(length(channels)/ceil(length(channels)/8)),x);
    
    if(length(t)>size(fNIR.raw(:,1),1))
        t=[t; max(t)+1];
    end
    
    hold off;
    figHandle=plot(t,fNIR.raw(:,channels(x)*3-1),'r');
    hold on;
    plot(t,fNIR.raw(:,channels(x)*3),'b');
    plot(t,fNIR.raw(:,channels(x)*3+1),'k');
    
    axis([min(t) max(t) 0 4000])
    
    xlabel(sprintf('Ch %i',channels(x)));
end

end

