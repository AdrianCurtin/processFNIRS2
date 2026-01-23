function outFNIR = ConcatenateHorizontal(fNIR_objs, varargin)
% CONCATENATEHORIZONTAL Concatenate fNIRS data segments in time (temporal merge)
%
% Combines multiple fNIRS recording segments from the same device/probe into
% a single continuous time series. Useful for merging split recording files
% or combining multiple runs from the same session.
%
% Note: Despite the name "Horizontal", this function concatenates data
% temporally (appending rows), not spatially. Use pf2.Data.Concatenate for
% multi-probe spatial merging.
%
% Syntax:
%   outFNIR = pf2.Data.ConcatenateHorizontal(fNIR_objs)
%   outFNIR = pf2.Data.ConcatenateHorizontal(fNIR1, fNIR2)
%
% Inputs:
%   fNIR_objs - Cell array of fNIRS structures {fNIR1, fNIR2, ...}
%               All structures should have same channel configuration.
%               Order in array doesn't matter - sorted by timestamp.
%               Alternatively, pass two structs directly as separate arguments.
%
% Outputs:
%   outFNIR   - Merged fNIRS structure with:
%               .raw - Vertically concatenated raw data [T_total x C]
%               .time - Merged and sorted time vector [T_total x 1]
%               .markers - Merged and sorted event markers
%               .fchMask - Combined mask (channel valid only if valid in all)
%               .t0 - Reference time from earliest segment
%
% Algorithm:
%   1. Sort input segments by timestamp (t0 + min(time))
%   2. Re-reference all segments to earliest t0
%   3. Concatenate raw data, time vectors, and markers
%   4. Sort combined data by time
%   5. Combine channel masks (intersection - must be valid in all)
%
% Notes:
%   - Requires t0 field for proper time alignment
%   - Assumes all inputs have same channel configuration
%   - Does NOT concatenate processed fields (HbO, HbR, etc.)
%   - Use before processing, not after
%   - Channel mask uses AND logic (valid only if valid in ALL segments)
%
% Example:
%   % Merge two recording segments from same session
%   merged = pf2.Data.ConcatenateHorizontal({run1, run2});
%
%   % Process the merged data
%   processed = processFNIRS2(merged);
%
% See also: pf2.Data.Concatenate, pf2.Data.SetT0, pf2.Data.Split 



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







