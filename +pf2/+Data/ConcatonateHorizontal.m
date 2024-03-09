function outFNIR=ConcatonateHorizontal(fNIR_objs,varargin)

%// function that merges two fNIRS structs together in time

% // requires t0 to be set for best support, assumes that all fNIR
% configurations are the same. 



%centerOnT0=true;

if(nargin>1)
   if(isstruct(varargin{1}))
      fNIR_objs={fNIR_objs,varargin{1}}; 
   end
end

numObjects=length(fNIR_objs);
%t0times=[];
minT=nan([1,numObjects]);
for i=1:numObjects %use earliest fNIR file as reference



   minT(i)=nanmin(fNIR_objs{i}.time);
   
   if(isfield(fNIR_objs{i},'t0'))
        t0times(i)=fNIR_objs{i}.t0;
        minTimes(i)=fNIR_objs{i}.t0+seconds(minT(i));
   end
end



if(length(minTimes)>0)
    [sortedIdx,b]=sort(minTimes);
else
     [sortedIdx,b]=sort(minT);
end



for i=1:length(fNIR_objs) %use Slowest fNIR file as reference
    curIndex=b(i);
    if(i==1)
        outFNIR = fNIR_objs{curIndex};
        referenceT0 = outFNIR.t0;
        continue;
    end

    appendFNIR = fNIR_objs{curIndex};
    appendFNIR=pf2.Data.SetT0(appendFNIR,referenceT0);
    outFNIR.time=[outFNIR.time;appendFNIR.time];
    if(isfield(outFNIR,'datetime'))
         outFNIR.datetime=[outFNIR.datetime;appendFNIR.datetime];
    end
    outFNIR.raw=[outFNIR.raw;appendFNIR.raw];
    outFNIR.markers=[outFNIR.markers;appendFNIR.markers];
    
    
    outFNIR.fchMask=outFNIR.fchMask.*appendFNIR.fchMask;
end

% order data
outFNIR.markers = sortrows(outFNIR.markers);
[outFNIR.time,b] = sort(outFNIR.time);
if(isfield(outFNIR,'datetime'))
     outFNIR.datetime=outFNIR.datetime(b,:);
end
outFNIR.raw=outFNIR.raw(b,:);







