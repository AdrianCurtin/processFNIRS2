function [outAvg,highestTier,outHarr]=hierarchicalAverage(arr,hierachy,funcAvg)
% HIERARCHICALAVERAGE Perform hierarchical (nested) averaging of data
%
% Computes averages iteratively through a hierarchy of grouping levels,
% ensuring proper within-subject averaging before between-subject pooling.
% Essential for fNIRS group analysis where multiple trials/conditions are
% nested within subjects.
%
% This function prevents pseudoreplication by first averaging within the
% lowest hierarchy level, then progressively averaging up through higher
% levels. The hierarchy is processed from bottom (most specific) to top
% (most general).
%
% Syntax:
%   outAvg = hierarchicalAverage(arr, hierarchy)
%   [outAvg, highestTier] = hierarchicalAverage(arr, hierarchy)
%   [outAvg, highestTier, outHarr] = hierarchicalAverage(arr, hierarchy, funcAvg)
%
% Inputs:
%   arr      - Data array to average [N x M] where N = observations
%              Can be numeric array, cell array, or table.
%              Each row is one observation, columns are variables.
%   hierarchy - Grouping structure [N x L] where L = hierarchy levels
%              Column 1 = highest level (e.g., Subject)
%              Column L = lowest level (e.g., Trial)
%              Can be cell array (strings/numbers) or numeric array.
%   funcAvg  - Averaging function (default: @nanmean)
%              Function handle or string name of function.
%              Must accept (data, dim) arguments.
%
% Outputs:
%   outAvg      - Averaged data [K x M] where K = unique highest-level groups
%   highestTier - Labels for each row in outAvg from hierarchy column 1
%   outHarr     - Encoded hierarchy array (for debugging)
%
% Algorithm:
%   1. Encode hierarchy levels to numeric indices
%   2. Starting from lowest level, average rows with same group ID
%   3. Move up hierarchy, averaging at each level
%   4. Return final averages at highest (subject) level
%
% Example:
%   % Average trial data within subjects
%   arr = [10; 10; 5; 5; 2; 2];
%   hierarchy(:,1) = {'Subject1';'Subject1';'Subject1';'Subject1';'Subject2';'Subject2'};
%   hierarchy(:,2) = {1; 1; 2; 2; 1; 1};
%
%   [avg, subjects] = hierarchicalAverage(arr, hierarchy);
%   % Returns avg = [7.5; 2], subjects = {'Subject1'; 'Subject2'}
%   % Subject1: mean([mean([10,10]), mean([5,5])]) = mean([10,5]) = 7.5
%   % Subject2: mean([2,2]) = 2
%
%   % Use custom function (e.g., median)
%   [avg, subjects] = hierarchicalAverage(arr, hierarchy, @nanmedian);
%
% Notes:
%   - Rows with identical hierarchy values are averaged together
%   - NaN values are handled by nanmean (ignored in averaging)
%   - Order of hierarchy columns matters: column 1 is topmost grouping
%
% See also: nanmean, grpstats, exploreFNIRS


if(nargin==3)
    if(ischar(funcAvg)&&exist(funcAvg)==2)
        funcAvg=str2func(funcAvg);
    elseif(isa(funcAvg, 'function_handle'))
        %works for me
    else
       error('Must provide valid function name or function handle');
    end
end    

if(nargin<1)
    error('No Input');
    %arr=[10,10,5,5,2,2]';
    %hierachy(:,1)={'Subject1';'Subject1';'Subject1';'Subject1';'Subject2';'Subject2'};
    %hierachy(:,2)={1;1;2;2;1;1};
    %funcAvg=str2func('nanmean'); 
elseif(nargin<2)
    error('Must provide a hierachy');
elseif(nargin<3)
    
    funcAvg=str2func('nanmean'); 
end

if(iscell(arr))
   arr=cell2mat(arr); 
elseif(istable(arr))
    arr=table2array(arr);
end

numLevels=size(hierachy,2);

numObservations=size(hierachy,1);

if(size(arr,1)~=numObservations&&size(arr,2)==numObservations)
    arr=arr';
end

if(size(arr,1)~=numObservations)
    error('Hierarchy does not match input data');
end

hierachyArr=nan(size(hierachy));

for i=1:numLevels
   if(iscell(hierachy))
       curLevel=hierachy(:,i);
       if(isnumeric(curLevel{1}))
           curLevel=cell2mat(curLevel);
       end
        [uVals,uCount,uIdx]=unique(curLevel);
   elseif(istable(hierachy))
       curLevel=hierachy(:,i);
       [uVals,uCount,uIdx]=unique(curLevel);
   elseif(isnumeric(hierachy))
       curLevel=hierachy(:,i);
       [uVals,uCount,uIdx]=unique(curLevel);
   else
       error('unknown structure');
   end
   if(i==1)
      highestTier=uVals; 
   end
   
   hierachyArr(:,i)=uIdx;
end


for i=1:numLevels-1
   hierachyArr(:,i+1)=hierachyArr(:,i+1)+hierachyArr(:,i)*1000;
end


outAvg=arr;
outHierarchy=hierachy;

for i=1:numLevels
    [uHArr,uFirstIdx,c]=unique(hierachyArr(:,i));
    [~,sortFirstIdx]=sort(uFirstIdx);
    newSort=nan(size(uHArr));
    newSort(sortFirstIdx)=1:length(uHArr);
    hierachyArr(:,i)=newSort(c)';
end

outHarr=hierachyArr;

for i=numLevels:-1:1
    [uVal,~,uIdx]=unique(hierachyArr(:,i));
    
    if(length(uVal)==length(uIdx)||isempty(uVal))
        outHierarchy=outHierarchy(:,1:i);
        hierachyArr=hierachyArr(:,1:i);
        outHarr(:,i)=[];
        continue;  %no need to average (at this level)! all the rows are already unique
    end
    
    newOut=nan(length(uVal),size(outAvg,2),size(outAvg,3));
    rows2keep=nan(size(uVal));
    
    for i2=1:length(uVal)
        idx=hierachyArr(:,i)==i2;  %is this the current unique value?
        if(~any(idx))   %can't find that value here
            continue;
        else
            rows2keep(i2)=find(idx,1,'first'); %still have to keep one col from the rest to merge with the average
        end
        
        try
            newOut(i2,:,:)=funcAvg(outAvg(idx,:,:),1);
        catch
            newOut(i2,:,:)=funcAvg(outAvg(idx,:,:));
        end
    end
    
    outAvg=newOut;
    
    outHierarchy=outHierarchy(rows2keep,1:i);
    hierachyArr=hierachyArr(rows2keep,1:i);
end

if(isempty(outHierarchy))
   highestTier=1:length(outAvg)';
else
    highestTier=outHierarchy(:,1);
end