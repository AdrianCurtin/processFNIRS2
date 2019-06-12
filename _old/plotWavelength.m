function [ figHandle ] = plotWavelength(w,fNIR,channel,showMarkers)
%PLOTHITATCHI Summary of this function goes here
%   Detailed explanation goes here

if(nargin<2||isempty(channel))
    channel=1:16;
end

if(nargin<3)
    showMarkers=[44 45];
end


if(length(channel)==16&&isequal(channel,[1:16]))
    channel=channel([1 3 5 7 9 11 13 15 2 4 6 8 10 12 14 16]);
end

if(isequal(channel,[1:14]))
    channel=channel([1 3 5 7 9 11 13 2 4 6 8 10 12 14]);
end

if(~isstruct(fNIR))
    temp=fNIR;
    clear fNIR;
    fNIR.raw=temp;
   clear temp;
end

t=fNIR.raw(:,1);

if(w==805)
    ind=0;
elseif(w==850)
    ind=1;
elseif(w==730)
    ind=-1;
else
    disp('Invalid Wavelength');
end

for(x=1:length(channel))
    
    subplot(ceil(length(channel)/8),ceil(length(channel)/ceil(length(channel)/8)),x);
    
    if(length(t)>size(fNIR.raw(:,1),1))
        t=[t; max(t)+1];
    end
    
    
    %igHandle=plot(t,fNIR.raw(:,channel(x)*3-1),'r');
    hold off;
    figHandle=plot(t,fNIR.raw(:,channel(x)*3+ind),'b');
    %plot(t,fNIR.raw(:,channel(x)*3+1),'k');
    %plot(t,ones(size(t,1),1)*4000,'--k');
    
    m=median(fNIR.raw(:,channel(x)*3+ind));
    s=std(fNIR.raw(:,channel(x)*3+ind));
    axis([min(t) max(t) m-s*10 m+s*10]);    
    hold on;
    if(isfield(fNIR,'markers')&&~isempty(showMarkers))
       if(isfield(fNIR.markers,'data'))
           for i=1:size(fNIR.markers.data,1) 
               if(any(fNIR.markers.data(i,2)==showMarkers))
                    vline(fNIR.markers.data(i,1),'k'); 
               end
           end
       else
          for i=1:size(fNIR.markers,1) 
           if(any(fNIR.markers(i,2)==showMarkers))
                vline(fNIR.markers(i,1),'k'); 
           end
          end
       end
    end
    hold off;
    
    
    xlabel(sprintf('Ch %i',channel(x)));
end


end

