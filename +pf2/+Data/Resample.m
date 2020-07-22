function [ outFNIR, pFit] = Resample(varargin)
%Data.Resample returns time averaged fNIR values according to segLength
% effectively resamples data
%   Data.Resample(fNIR,segmentLength,blLength,blfNIR,'centerOnT0',false,'timeOutMode','start','nanRejectionLevel',0.7)
%
%Seg length determines the segment length in seconds, resampling to
%fs=1/segLength
%blLength determines the baseline length in seconds, entering 0 will
%disable baseline performance
%blfNIR uses alternate fNIR struct for baseline
%centerOnT0 will try to use T0 in the included timepoints
%timeOutMode will change the .time output to reflect the start/end/midpoint
%of the chosen semgent
%nanRejectionLevel = fraction of values missing before signal is returned
%as nan, defaults to 70%

%Outputting two arguments will perform polyfit and return the mean values after
%interpolation performed

%f=0.51; %sampling frequency

% Usage examples
% Data.Resample(fnirData,10) : Resample data to one sample per 10 seconds (0.1hz)
%                       No baselining performed
%       Equivalent to Data.Resample('fNIR',fnirData,'segmentLength',10);
% Data.Resample(fnirData,5,5) : Resample data to one sample per 5 seconds, use
%                        first 5 seconds as a baseline period
%       Equivalent to Data.Resample('fNIR',fnirData,'segmentLength',5,'blLength',5);
%
% Data.Resample(fnirData,1,'blfNIR',baselineData) : Resample data to 1 sample per second, use
%                        baselineData fNIR struct as a baseline period
%                       using a baseline period overrrides blLength
%                       argument
%
% Data.Resample(fnirData,10,'centerOnT0',true) : Resample data to one sample per 10 seconds (0.1hz)
%                       No baselining performed. Forces the inclusion of
%                       t=0 as a sample. ie all times will be relative to
%                       t0 (0s,10s,20s,30s) and fNIR data will be binned
%                       within each categoty, sample at 5s would be moved
%                       into the [0:10s] bin
%                           Otherwise if first sample is at 5s time would
%                           be   (5s,15s,25s)...
%       Equivalent to Data.Resample('fNIR',fnirData,'segmentLength',10,'centerOnT0',true);
%
%Data.Resample(fnirData,10,'centerOnT0',true,'timeOutMode','start')
%                   A sample at t=5, placed within the bin [0:10s] would
%                   returns the .time structure as the start of the bin
%                   [0.000001:10]  would return 0s as the sample time
%Data.Resample(fnirData,10,'centerOnT0',true,'timeOutMode','mid')
%                   A sample at t=5, placed within the bin [0:10s] would
%                   returns the .time structure would return 5s as the sample time
%Data.Resample(fnirData,10,'centerOnT0',true,'timeOutMode','end')
%                   A sample at t=5, placed within the bin [0:10s] would
%                   returns the .time structure would return 10s as the sample time
%
% Data.Resample(fnirData,10,'nanRejectionLevel',0.5) : Resample data to one sample per 10 seconds (0.1hz)
%                       No baselining performed, Segments with more than
%                       50% of the values listed as nan are rejected
%                       (includes baseline)

p=inputParser;

validfNIRInput = @(x) (isnumeric(x)&&length(x)>1) || (isstruct(x) && (isfield(x,'raw')||isfield(x,'time')||isfield(x,'info')));
validScalarPosNum = @(x) isnumeric(x) && isscalar(x) && (x >= 0);
validTimeOutMode = @(x) ischar(x)&&(ismember(x,{'mid','start','end'}));

addRequired(p,'fNIR',validfNIRInput);
addOptional(p,'segmentLength',1,validScalarPosNum);
addOptional(p,'blLength',[],validScalarPosNum);
addOptional(p,'blfNIR',[],validfNIRInput);
addParameter(p,'centerOnT0',false,@islogical);
addParameter(p,'timeOutMode','start',validTimeOutMode);
addParameter(p,'nanRejectionLevel',0.7,validScalarPosNum);
addParameter(p,'averageAux',false,@islogical);
addParameter(p,'polyDegree',1,validScalarPosNum);

parse(p,varargin{:});

fNIR=p.Results.fNIR;
segLength=p.Results.segmentLength;
blLength=p.Results.blLength;
blfNIR=p.Results.blfNIR;
%getPolyAvg=p.Results.getPolyAvg;
centerOnT0=p.Results.centerOnT0;
timeOutMode=p.Results.timeOutMode;
nanRejectionLevel=p.Results.nanRejectionLevel;
averageAux=p.Results.averageAux;
polyDegree=p.Results.polyDegree;


if(~isstruct(fNIR))
    temp=fNIR;
    fNIR=[];
    fNIR.raw=temp;
    clear temp;
    
    fNIR.time=fNIR.raw(:,1);
end

if(~isempty(blfNIR)&&~isstruct(blfNIR)&&isnumeric(blfNIR))
    temp=blfNIR;
    blfNIR=[];
    blfNIR.raw=temp;
    clear temp;
    
    blfNIR.time=blfNIR.raw(:,1);
end

if(~isfield(fNIR,'time')&&isfield(fNIR,'raw'))
    fNIR.time=fNIR.raw(:,1);
end

minfTime=min(fNIR.time);
maxfTime=max(fNIR.time);


if(~isstruct(blfNIR)&&~isempty(blLength)&&blLength>0)
    blfNIR=getFNIRS(fNIR,min(fNIR.time),min(fNIR.time)+blLength); 
elseif(isstruct(blfNIR))
    if(~isempty(blfNIR.time)&&~any(isnan(blfNIR.time))&&isfield(blfNIR,'fs'))
        blLength=max(blfNIR.time)-min(blfNIR.time)+1/blfNIR.fs; %Baseline length in time
    elseif(~isempty(blLength)&&~isfield(blfNIR,'empty')&&blLength==0&&~isempty(blfNIR)&&~any(isnan(blfNIR.time))&&isfield(blfNIR,'fs'))
        blLength=1/blfNIR.fs;
    else
       warning('Entire Baseline is invalid');
       blLength=nan;
    end
elseif(blLength==0)
    blLength=[];
end

if(nargout>1)
    getPolyAvg=true;
elseif(nargout<=1)
    getPolyAvg=false;
end

if(~isfield(fNIR,'HbR')&&isfield(fNIR,'raw'))
    error('Raw data averaging not supported');
elseif(~isfield(fNIR,'HbR')&&~isfield(fNIR,'raw'))
    warning('No fNIRS data');
    outFNIR=fNIR;
    pFit=[];
    return;
else
    numCh=size(fNIR.HbR,2); 
end

if(centerOnT0) % foces time blocks to start from t=0
    times=(0:segLength:(maxfTime+segLength))';
    
    if(min(fNIR.time)<0)
        newMinTime=(minfTime-segLength);
        times=[fliplr(0:-segLength:newMinTime)';times(2:end)];
    end
    
    times=times(times>=(min(fNIR.time)-segLength));
    times=times(times<=(max(fNIR.time)));
else
    times=((min(fNIR.time)):segLength:(max(fNIR.time)+segLength))';
end


numSegs=length(times);

HbR=nan(numSegs,numCh);
HbO=HbR;
HbDiff=HbR;
HbTotal=HbR;
CBSI=HbR;

if(getPolyAvg)
    phbr=nan(numSegs,numCh,polyDegree+1);
    phbo=nan(numSegs,numCh,polyDegree+1);
    poxy=nan(numSegs,numCh,polyDegree+1);
    ptotal=nan(numSegs,numCh,polyDegree+1);
    pcbsi=nan(numSegs,numCh,polyDegree+1);
    
    phbrfit=nan(numSegs,numCh,3);
    phbofit=nan(numSegs,numCh,3);
    poxyfit=nan(numSegs,numCh,3);
    ptotalfit=nan(numSegs,numCh,3);
    pcbsifit=nan(numSegs,numCh,3);
end

if(isfield(fNIR,'Aux'))
    if(~averageAux)
        outFNIR.Aux=fNIR.Aux;
    else
        
        outFNIR.Aux=struct();
    end
else
    averageAux=false;
end


if(blLength>0)
    blNanCheck=sum(isnan(blfNIR.HbR),1)/length(blfNIR.time)<nanRejectionLevel; %calculate percentage of invalid values in baseline

    blRejectedCount=sum(~blNanCheck);
    if(blRejectedCount>1)
        warning('Baseline Period in %i channels was invalid',blRejectedCount); 
    end
    validCh=find(blNanCheck==1);
    
    blHbR=nanmean(blfNIR.HbR(:,validCh),1);
    blHbO=nanmean(blfNIR.HbO(:,validCh),1);
    blHbDiff=nanmean(blfNIR.HbDiff(:,validCh),1);
    blHbTotal=nanmean(blfNIR.HbTotal(:,validCh),1);
    blCBSI=nanmean(blfNIR.CBSI(:,validCh),1);
    
    if(isempty(blHbR))
        blHbR=nan;
    end
    
    if(isempty(blHbO))
        blHbO=nan;
    end
    
    if(isempty(blHbDiff))
        blHbDiff=nan;
    end
    
    if(isempty(blHbTotal))
        blHbTotal=nan;
    end
    if(isempty(blCBSI))
        blCBSI=nan;
    end
    
    if(pf2_base.isnestedfield(blfNIR,'ROI.HbO'))
        blNanCheck_roi=sum(isnan(blfNIR.ROI.HbR),1)/length(blfNIR.time)<nanRejectionLevel; %calculate percentage of invalid values in baseline

        blRejectedCount_roi=sum(~blNanCheck_roi);
        if(blRejectedCount_roi>1)
            warning('ROI Baseline Period in %i channels was invalid',blRejectedCount_roi); 
        end
        validCh_roi=find(blNanCheck_roi==1);

        blHbR_roi=nanmean(blfNIR.ROI.HbR(:,validCh_roi),1);
        blHbO_roi=nanmean(blfNIR.ROI.HbO(:,validCh_roi),1);
        blHbDiff_roi=nanmean(blfNIR.ROI.HbDiff(:,validCh_roi),1);
        blHbTotal_roi=nanmean(blfNIR.ROI.HbTotal(:,validCh_roi),1);
        blCBSI_roi=nanmean(blfNIR.ROI.CBSI(:,validCh_roi),1);
        
        if(pf2_base.isnestedfield(fNIR,'ROI.HbO')&&size(blfNIR.ROI.HbO,2)==size(fNIR.ROI.HbO,2))
            
            calcROI=true;
        else
            warning('ROI mismatch: ROI as defined in baseline not present in main fNIRS segment, calculations not performed');
            calcROI=false;
        end
        
    else
        calcROI=false; 
    end
else
    validCh=1:numCh;
    if(pf2_base.isnestedfield(fNIR,'ROI.HbO'))
       calcROI=true;
       validCh_roi=1:size(fNIR.ROI.HbO,2);
    else
        calcROI=false;
    end
end

ind=1;
fTime=fNIR.time;
fTimeInd=nan(size(fNIR.time));
maxFtime=length(fTime);

fHbR=fNIR.HbR(:,validCh);
fHbO=fNIR.HbO(:,validCh);
fHbDiff=fNIR.HbDiff(:,validCh);
fHbTotal=fNIR.HbTotal(:,validCh);
fCBSI=fNIR.CBSI(:,validCh);
fraw=fNIR.raw;

if(calcROI)
    fHbR_roi=fNIR.ROI.HbR(:,validCh_roi);
    fHbO_roi=fNIR.ROI.HbO(:,validCh_roi);
    fHbDiff_roi=fNIR.ROI.HbDiff(:,validCh_roi);
    fHbTotal_roi=fNIR.ROI.HbTotal(:,validCh_roi);
    fCBSI_roi=fNIR.ROI.CBSI(:,validCh_roi);
end

if(strcmp(timeOutMode,'start'))
    timeOutModeMid=false;
    timeOutModeEnd=false;
elseif(strcmp(timeOutMode,'end'))
    timeOutModeMid=false;
    timeOutModeEnd=true;
else %Return midpoint
    timeOutModeMid=true;
    timeOutModeEnd=false;
end


ptime=zeros(numSegs,1);
for i=0:numSegs-1
    
    t1=times(i+1); %get the current segment start time
    ind_init=ind;  %get the index
    ind_2=ind;
    
    if(ind>maxFtime) %if the index is bigger than the max time, we're done
        continue;
    end
    
    while(ind<=maxFtime&&fTime(ind)<t1) %if the index is less than the max time and less than the start time
        % keep increasing until ind until it marks the segment just
        % slightly after t1
        % and ind_2 is the one before that
        ind=ind+1;
        ind_2=ind-1;
        fTimeInd(ind_2)=i;
    end
    
    if(i==0&&numSegs==1&&isnan(fTimeInd(ind_2))&&fTime(ind)<(t1+segLength))
        blLength=nan; %way of marking segment invalid
        ind_2=find(fTime==max(fTime(fTime<(t1+segLength))));
        i=1;
    elseif(i==0||(isnan(fTimeInd(ind_2)))) %TODO make this check so that it operates even if zero is slightly before
        continue;
    end
    

    
    if(averageAux&&~isempty(fNIR.Aux))
        auxFields=fields(fNIR.Aux);
        for f=1:length(auxFields)
            curFieldName=auxFields{f};
            curField=fNIR.Aux.(curFieldName);
            if(isstruct(curField)||iscell(curField)||istable(curField))
                if(~isfield(curField,'t')||~isfield(curField,'time'))
                    outFNIR.Aux.(curFieldName)=curField;
                else
                    warning('embedded aux field times not supported yet');
                    outFNIR.Aux.(curFieldName)=curField;
                end
            elseif(size(curField,2)==1)
                outFNIR.Aux.(curFieldName)=curField;

            elseif(size(curField,2)>1) %Assume first column is time and is synchronized with fNIRS
                curFieldTime=curField(:,1);
                indexStart=find(curFieldTime>=t1-segLength,1);
                indexEnd=find(curFieldTime<t1,1,'last');
                
                if(~isfield(outFNIR.Aux,curFieldName))
                    outFNIR.Aux.(curFieldName)=nan(size(times,1),size(curField,2));
                end

                outFNIR.Aux.(curFieldName)(i,:)=nanmean(curField(indexStart:indexEnd,:),1);
                outFNIR.Aux.(curFieldName)(i,1)=t1-segLength+timeOutModeEnd*segLength+timeOutModeMid*segLength/2;
            end
        end
    end
        
    
    
    nanCheck=(sum(isnan(fHbR(ind_init:ind_2,:)),1)/(ind_2-ind_init+1))<=nanRejectionLevel;     %calculate percentage of invalid values in task
    nanCheckValid=validCh(nanCheck);
    
    if(calcROI)
        nanCheck_roi=(sum(isnan(fHbR_roi(ind_init:ind_2,:)),1)/(ind_2-ind_init+1))<=nanRejectionLevel;     %calculate percentage of invalid values in task
        nanCheckValid_roi=validCh_roi(nanCheck_roi);
    end
    
    if(blLength>0)
        HbR(i,nanCheckValid)=nanmean(fHbR(ind_init:ind_2,nanCheck),1)-blHbR(nanCheck);
        HbO(i,nanCheckValid)=nanmean(fHbO(ind_init:ind_2,nanCheck),1)-blHbO(nanCheck);
        HbDiff(i,nanCheckValid)=nanmean(fHbDiff(ind_init:ind_2,nanCheck),1)-blHbDiff(nanCheck);
        HbTotal(i,nanCheckValid)=nanmean(fHbTotal(ind_init:ind_2,nanCheck),1)-blHbTotal(nanCheck);
        CBSI(i,nanCheckValid)=nanmean(fCBSI(ind_init:ind_2,nanCheck),1)-blCBSI(nanCheck);
        raw(i,:)=nanmean(fraw(ind_init:ind_2,:),1);
    elseif(isnan(blLength))
        HbR(i,nanCheckValid)=nan;
        HbO(i,nanCheckValid)=nan;
        HbDiff(i,nanCheckValid)=nan;
        HbTotal(i,nanCheckValid)=nan;
        CBSI(i,nanCheckValid)=nan;
        raw(i,:)=nan;
    else
        HbR(i,nanCheckValid)=nanmean(fHbR(ind_init:ind_2,nanCheck),1);
        HbO(i,nanCheckValid)=nanmean(fHbO(ind_init:ind_2,nanCheck),1);
        HbDiff(i,nanCheckValid)=nanmean(fHbDiff(ind_init:ind_2,nanCheck),1);
        HbTotal(i,nanCheckValid)=nanmean(fHbTotal(ind_init:ind_2,nanCheck),1);
        CBSI(i,nanCheckValid)=nanmean(fCBSI(ind_init:ind_2,nanCheck),1);
        raw(i,:)=nanmean(fraw(ind_init:ind_2,:),1);
    end
    
    
    if(calcROI)
        if(blLength>0)
            HbR_roi(i,nanCheckValid_roi)=nanmean(fHbR_roi(ind_init:ind_2,nanCheck_roi),1)-blHbR_roi(nanCheck_roi);
            HbO_roi(i,nanCheckValid_roi)=nanmean(fHbO_roi(ind_init:ind_2,nanCheck_roi),1)-blHbO_roi(nanCheck_roi);
            HbDiff_roi(i,nanCheckValid_roi)=nanmean(fHbDiff_roi(ind_init:ind_2,nanCheck_roi),1)-blHbDiff_roi(nanCheck_roi);
            HbTotal_roi(i,nanCheckValid_roi)=nanmean(fHbTotal_roi(ind_init:ind_2,nanCheck_roi),1)-blHbTotal_roi(nanCheck_roi);
            CBSI_roi(i,nanCheckValid_roi)=nanmean(fCBSI_roi(ind_init:ind_2,nanCheck_roi),1)-blCBSI_roi(nanCheck_roi);
        elseif(isnan(blLength))
            HbR_roi(i,nanCheckValid_roi)=nan;
            HbO_roi(i,nanCheckValid_roi)=nan;
            HbDiff_roi(i,nanCheckValid_roi)=nan;
            HbTotal_roi(i,nanCheckValid_roi)=nan;
            CBSI_roi(i,nanCheckValid_roi)=nan;
        else
            HbR_roi(i,nanCheckValid_roi)=nanmean(fHbR_roi(ind_init:ind_2,nanCheck_roi),1);
            HbO_roi(i,nanCheckValid_roi)=nanmean(fHbO_roi(ind_init:ind_2,nanCheck_roi),1);
            HbDiff_roi(i,nanCheckValid_roi)=nanmean(fHbDiff_roi(ind_init:ind_2,nanCheck_roi),1);
            HbTotal_roi(i,nanCheckValid_roi)=nanmean(fHbTotal_roi(ind_init:ind_2,nanCheck_roi),1);
            CBSI_roi(i,nanCheckValid_roi)=nanmean(fCBSI_roi(ind_init:ind_2,nanCheck_roi),1);
        end
    end
    
    for chIdx=1:length(validCh)  

        validIdx=(~isnan(fHbR(:,chIdx)).*ismembc([1:length(fHbR(:,1))], [ind_init:ind_2])')==1;
        fSegtime=fTime(validIdx);
        
        if(any(validIdx))
            if(getPolyAvg)
                ch=validCh(chIdx);
                pFitTime=fSegtime-min(fSegtime);
                phbr(i,ch,:)=mpolyfit(pFitTime,fHbR(validIdx,chIdx),polyDegree);
                phbo(i,ch,:)=mpolyfit(pFitTime,fHbO(validIdx,chIdx),polyDegree);
                poxy(i,ch,:)=mpolyfit(pFitTime,fHbDiff(validIdx,chIdx),polyDegree);
                ptotal(i,ch,:)=mpolyfit(pFitTime,fHbTotal(validIdx,chIdx),polyDegree);
                pcbsi(i,ch,:)=mpolyfit(pFitTime,fCBSI(validIdx,chIdx),polyDegree);
                ptime(i)=nanmean(fSegtime);
                
                tseg=[min(pFitTime),(max(pFitTime)-min(pFitTime))/2,max(pFitTime)]-min(pFitTime);

                
                phbrfit(i,ch,:)=polyval(reshape(phbr(i,ch,:),[polyDegree+1,1,1]),tseg);
                phbofit(i,ch,:)=polyval(reshape(phbo(i,ch,:),[polyDegree+1,1,1]),tseg);
                poxyfit(i,ch,:)=polyval(reshape(poxy(i,ch,:),[polyDegree+1,1,1]),tseg);
                ptotalfit(i,ch,:)=polyval(reshape(ptotal(i,ch,:),[polyDegree+1,1,1]),tseg);
                pcbsifit(i,ch,:)=polyval(reshape(pcbsi(i,ch,:),[polyDegree+1,1,1]),tseg);
                
            end
        end
    end
end

outFNIR.HbR=HbR(1:end-1,:);
outFNIR.HbO=HbO(1:end-1,:);
outFNIR.HbDiff=HbDiff(1:end-1,:);
outFNIR.HbTotal=HbTotal(1:end-1,:);
outFNIR.CBSI=CBSI(1:end-1,:);
outFNIR.raw=raw(1:end,:);

if(calcROI&&exist('HbR_roi'))
    outFNIR.ROI=fNIR.ROI;
    hbo_field_length=size(outFNIR.HbO,1);
    roi_field_length=size(HbR_roi,1);
    field_diff=hbo_field_length-roi_field_length; %Fix for it being different?
    
    outFNIR.ROI.HbR=nan(hbo_field_length,size(HbR_roi,2));
    outFNIR.ROI.HbO=outFNIR.ROI.HbR;
    outFNIR.ROI.HbDiff=outFNIR.ROI.HbR;
    outFNIR.ROI.HbTotal=outFNIR.ROI.HbR;
    outFNIR.ROI.CBSI=outFNIR.ROI.HbR;
    
    outFNIR.ROI.HbR=HbR_roi;
    outFNIR.ROI.HbO=HbO_roi;
    outFNIR.ROI.HbDiff=HbDiff_roi;
    outFNIR.ROI.HbTotal=HbTotal_roi;
    outFNIR.ROI.CBSI=CBSI_roi;
end

validFields=pf2_base.pf2_getFNIRSfields();
fdataFields=fields(fNIR);  % Copy known fields
for i=1:length(fdataFields)
   memberIdx=ismember(validFields,fdataFields{i});
   if(any(memberIdx)&&~strcmp(fdataFields{i},'time')...
           &&~strcmp(fdataFields{i},'fs')&&~strcmp(fdataFields{i},'ROI'))
        outFNIR.(validFields{memberIdx})=fNIR.(fdataFields{i});
   end
end

times=times(1:size(outFNIR.HbR,1),:);
outFNIR.segmentTimes=[times,times+segLength/2,times+segLength];

if(~isempty(outFNIR.segmentTimes))
    if(strcmp(timeOutMode,'start'))
        outFNIR.time=outFNIR.segmentTimes(1:end,1); %returns effective "sample point" at midpoint of segmentTimes
    elseif(strcmp(timeOutMode,'end'))
        outFNIR.time=outFNIR.segmentTimes(1:end,3); %returns effective "sample point" at midpoint of segmentTimes
    else %Return midpoint
        outFNIR.time=outFNIR.segmentTimes(1:end,2); %returns effective "sample point" at midpoint of segmentTimes
    end
else
   outFNIR.time=[]; 
end

if(isempty(outFNIR.time))
    outFNIR.time=nan;
    outFNIR.empty=1;
end
    

outFNIR.fs=1/segLength; %new "effective sampling frequency

if(getPolyAvg) % returns a time X channel X coefficient array
    pFit=outFNIR;
    pFit.HbR_poly=phbr;
    pFit.HbO_poly=phbo;
    pFit.HbDiff_poly=poxy;
    pFit.HbTotal_poly=ptotal;
    pFit.CBSI_poly=pcbsi;
    pFit.time=ptime;
    %pFit.time(end+1)=outFNIR.segmentTimes(end,3);
    
    pFit.HbR=phbrfit;
    pFit.HbO=phbofit;
    pFit.HbDiff=poxyfit;
    pFit.HbTotal=ptotalfit;
    pFit.CBSI=pcbsifit;
else
    pFit=[];
end

end

function [c,R2] = mpolyfit(x,y,n) 
% Fits polynomial n to x and y data
if(size(x,1)==1&&size(x,2)>1)
    x=x';
    y=y';
end

if(size(y,1)~=size(x,1))
   error('Size of x and y matricies must be the same'); 
end
    m = size(x,2); % number of polynomials to fit
    c = zeros(n+1,m); 
    r = zeros(size(y)); 
    for k = 1:m 
        M = repmat(x(:,k),1,n+1); 
        M = bsxfun(@power,M,0:n); 
        c(:,k) = M\y(:,k); 
        r(:,k) = M*c(:,k)-y(:,k);  %calculate residuals
    end 
    sserr = sum(r.^2); 
    sstot = sum(bsxfun(@minus,y,mean(y)).^2); 
    R2 = 1 - sserr./sstot;
    c=fliplr(c')';
    R2=fliplr(R2')';
end