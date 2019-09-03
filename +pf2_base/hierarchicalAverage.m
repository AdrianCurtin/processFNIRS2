function [outAvg,highestTier,outHarr]=hierarchicalAverage(arr,hierachy,funcAvg)

% hierarchicalAverage takes two arguments, a numerica array arr ([x,N]) 
% and a hierachy structure size ([y,N])

% Averaging is performed itteratively such that each level in the hierarchy
% is averaged together.

% funcAvg is used to perform averaging or other operation

% ex: arr=[10,10,5,5,2,2]
% hierachy(:,1)={'Subject1';'Subject1';'Subject1';'Subject1';'Subject2';'Subject2'}
% hierachy(:,2)={1;1;2;2;1;1};

% Will return [7.5,2] and highestTier of {'Subject1';'Subject2'}


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