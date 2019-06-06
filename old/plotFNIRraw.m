function [ figHandle ] = plotFNIRraw(fNIR,channel)
%PLOTHITATCHI Summary of this function goes here
%   Detailed explanation goes here

if(nargin<2)
    channel=1:16;
end


if(length(channel)==16&&isequal(channel,[1:16]))
    channel=channel([1 3 5 7 9 11 13 15 2 4 6 8 10 12 14 16]);
end

if(isequal(channel,[1:14]))
    channel=channel([1 3 5 7 9 11 13 2 4 6 8 10 12 14]);
end

if(isfield(fNIR,'raw'))
    t=fNIR.raw(:,1);
else
   temp=fNIR;
   clear fNIR;
   fNIR.raw=temp;
   t=fNIR.raw(:,1);
end

for(x=1:length(channel))
    
    subplot(ceil(length(channel)/8),ceil(length(channel)/ceil(length(channel)/8)),x);
    
    if(length(t)>size(fNIR.raw(:,1),1))
        t=[t; max(t)+1];
    end
    
    hold off;
    figHandle=plot(t,fNIR.raw(:,channel(x)*3-1),'r');
    hold on;
    plot(t,fNIR.raw(:,channel(x)*3),'b');
    plot(t,fNIR.raw(:,channel(x)*3+1),'k');
    
    axis([min(t) max(t) 0 4000])
    
    xlabel(sprintf('Ch %i',channel(x)));
end

end

