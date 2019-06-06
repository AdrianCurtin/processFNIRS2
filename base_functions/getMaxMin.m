function [ maxArr, minArr] = getMaxMin( fNIR, segLength, blLength,blfNIR)
%NIRSAVG returns time averaged fNIR values according to segLength
% effectively resamples data
%Seg length determines the segment length in seconds
%blLength determines the baseline length in seconds
%blfNIR uses alternate fNIR struct for baseline

%Inputting one sample will self-baseline according to fNIR input
%inputting

f=0.51; %sampling frequency

if(sum((fNIR.HbR(1,:)==zeros(1,16))|isnan(fNIR.HbR(1,:)))==16)
   fNIR=getFNIRS(fNIR,fNIR.time(2),fNIR.time(end)); 
end

if(nargin<3)
    blLength=5;
end

if(nargin<2)
    segLength=round(length(fNIR.time)/20); %Segment Length in time
end
if(nargin<4)
   blfNIR=getFNIRS(fNIR,min(fNIR.time),min(fNIR.time)+blLength); 
else
    blLength=max(blfNIR.time)-min(blfNIR.time); %Baseline length in time
end



numCh=size(fNIR.HbR,2);


times=(min(fNIR.time):segLength:max(fNIR.time))';


if(length(times)==1||max(fNIR.time)-max(times)>segLength*0.7)
   times=[times;max(fNIR.time)]; 
end

numSegs=length(times)-1;



maxArr.HbR=zeros(numSegs,numCh);
maxArr.HbO=maxArr.HbR;
maxArr.HbDiff=maxArr.HbR;
maxArr.HbTotal=maxArr.HbR;
maxArr.CBSI=maxArr.HbR;

minArr.HbO=maxArr.HbR;
minArr.HbDiff=maxArr.HbR;
minArr.HbTotal=maxArr.HbR;
minArr.CBSI=maxArr.HbR;


for i=1:numSegs
    t1=times(i);
    t2=times(i+1);
    
    fSeg=getFNIRS(fNIR,t1,t2);
    if(isempty(fSeg.time))
        continue;
    end
    fSegtime=fSeg.time-fSeg.time(1);
    
    
    
    for ch=1:numCh
        blNanCheck=sum(isnan(blfNIR.HbR(:,ch)))/length(blfNIR.time); %calculate percentage of invalid values in baseline
        nanCheck=sum(isnan(fSeg.HbR(:,ch)))/length(fSeg.time);     %calculate percentage of invalid values in task

        if(blLength<=0)
            maxArr.HbR(i,ch)=max(fSeg.HbR(:,ch));
            maxArr.HbO(i,ch)=max(fSeg.HbO(:,ch));
            maxArr.HbDiff(i,ch)=max(fSeg.HbDiff(:,ch));
            maxArr.HbTotal(i,ch)=max(fSeg.HbO(:,ch)+fSeg.HbR(:,ch));
            maxArr.CBSI(i,ch)=max(fSeg.CBSI(:,ch));
            
            
            minArr.HbR(i,ch)=min(fSeg.HbR(:,ch));
            minArr.HbO(i,ch)=min(fSeg.HbO(:,ch));
            minArr.HbDiff(i,ch)=min(fSeg.HbDiff(:,ch));
            minArr.HbTotal(i,ch)=min(fSeg.HbO(:,ch)+fSeg.HbR(:,ch));
            minArr.CBSI(i,ch)=min(fSeg.CBSI(:,ch));
            
            
            
            valid=~isnan(fSeg.HbR(:,ch));
        elseif(blNanCheck<0.7&&nanCheck<0.7) %if there are more than 70% NaN in baseline or task then reject sample
            maxArr.HbR(i,ch)=max(fSeg.HbR(:,ch)-nanmean(blfNIR.HbR(:,ch)));
            maxArr.HbO(i,ch)=max(fSeg.HbO(:,ch)-nanmean(blfNIR.HbO(:,ch)));
            maxArr.HbDiff(i,ch)=max(fSeg.HbDiff(:,ch)-nanmean(blfNIR.HbDiff(:,ch)));
            maxArr.HbTotal(i,ch)=max(fSeg.HbO(:,ch)+fSeg.HbR(:,ch)-nanmean(blfNIR.HbO(:,ch))-nanmean(blfNIR.HbR(:,ch)));
            maxArr.CBSI(i,ch)=max(fSeg.CBSI(:,ch)-nanmean(blfNIR.CBSI(:,ch)));
            
            
            minArr.HbR(i,ch)=min(fSeg.HbR(:,ch)-nanmean(blfNIR.HbR(:,ch)));
            minArr.HbO(i,ch)=min(fSeg.HbO(:,ch)-nanmean(blfNIR.HbO(:,ch)));
            minArr.HbDiff(i,ch)=min(fSeg.HbDiff(:,ch)-nanmean(blfNIR.HbDiff(:,ch)));
            minArr.HbTotal(i,ch)=min(fSeg.HbO(:,ch)+fSeg.HbR(:,ch)-nanmean(blfNIR.HbO(:,ch))-nanmean(blfNIR.HbR(:,ch)));
            minArr.CBSI(i,ch)=min(fSeg.CBSI(:,ch)-nanmean(blfNIR.CBSI(:,ch)));
            
            
            
            valid=~isnan(fSeg.HbR(:,ch));
        else
            maxArr.HbR(i,ch)=NaN;
            maxArr.HbO(i,ch)=NaN;
            maxArr.HbDiff(i,ch)=NaN;
            maxArr.HbTotal(i,ch)=NaN;
            maxArr.CBSI(i,ch)=NaN;
            
            minArr.HbR(i,ch)=NaN;
            minArr.HbO(i,ch)=NaN;
            minArr.HbDiff(i,ch)=NaN;
            minArr.HbTotal(i,ch)=NaN;
            minArr.CBSI(i,ch)=NaN;
        end
    end
end


maxArr.starttimes=times;
maxArr.time=times(1:end-1)+segLength/2; %returns effective "sample point"
maxArr.f=segLength; %new "effective sampling frequency

minArr.starttimes=times;
minArr.time=times(1:end-1)+segLength/2; %returns effective "sample point"
minArr.f=segLength; %new "effective sampling frequency
