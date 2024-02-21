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
   end
end



if(length(t0times)>0)
    [sortedIdx,b]=sort(t0times);
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
    outFNIR.raw=[outFNIR.raw;appendFNIR.raw];
    outFNIR.markers=[outFNIR.markers;appendFNIR.markers];

    outFNIR.fchMask=outFNIR.fchMask.*appendFNIR.fchMask;
end







