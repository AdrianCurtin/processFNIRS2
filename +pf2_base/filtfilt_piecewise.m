function y = filtfilt_piecewise(b,a,x,minFilt,restoreMean)

%interpolates values and then filters and deletes values afterwards

isNanArr=(isnan(x));
diffNan=diff(isNanArr);
diffNan=[ones([1,size(x,2)]);diffNan]; %add first term
diffNan(1,~isNanArr(1,:))=-1;

if(nargin<5)
   restoreMean=false; 
end

if(nargin<4)
   minFilt=5; 
end

y=nan(size(x));

for i=1:size(x,2)
	if(sum(~isnan(x(:,i)))<minFilt) %skip really dead channels or blocked channels
		continue;
    end
    
    cleanBlockStart=find(diffNan(:,i)==-1);
    cleanBlockEnd=find(diffNan(:,i)==1)-1;
    
    if(isempty(cleanBlockStart))
       continue; 
    end
    
    if(~isempty(cleanBlockEnd)&&cleanBlockEnd(1)<cleanBlockStart(1))
        cleanBlockEnd(1)=[];
    end
    if(length(cleanBlockStart)>length(cleanBlockEnd))
       cleanBlockEnd(end+1)=size(x,1);
    end
    
    
    for j=1:length(cleanBlockStart)
        
        xIdx=cleanBlockStart(j):cleanBlockEnd(j);
        if(length(xIdx)>minFilt)
            y(xIdx,i)=filtfilt(b,a,x(xIdx,i)')';
            
            if(restoreMean)
                y(xIdx,i)=y(xIdx,i)+nanmean(x(xIdx,i));
            end
        else
            y(xIdx,i)=nan; 
        end
    end

	
end

