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
segLength=p.Results.segmentLength; % How long is each segment, ie: 1 sample
blLength=p.Results.blLength; % how long is the baseline
blfNIR=p.Results.blfNIR; % a baseline fNIR struct
%getPolyAvg=p.Results.getPolyAvg;
centerOnT0=p.Results.centerOnT0; % should the resample include t=0 as the start point
timeOutMode=p.Results.timeOutMode; % should time include or center on a point (ex: t=1 := t[0.051...1.4999]
nanRejectionLevel=p.Results.nanRejectionLevel; % number of NaNs in segment to entirely reject it
averageAux=p.Results.averageAux; % Also average/ resample the Aux channels
polyDegree=p.Results.polyDegree; % degree for polyfit


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

fNIR.time=round(fNIR.time,5);

minfTime=min(fNIR.time);
maxfTime=max(fNIR.time);

fTime=fNIR.time;

if(~isstruct(blfNIR)&&~isempty(blLength)&&blLength>0)
    % if given a specific baseline length (and no struct, create baseline
    % from times given)
    blfNIR=getFNIRS(fNIR,min(fNIR.time),min(fNIR.time)+blLength); 
elseif(isstruct(blfNIR))
    % if using a baseline struct
    if(~isempty(blfNIR.time)&&~any(isnan(blfNIR.time))&&isfield(blfNIR,'fs'))
        %if time is provided, use all of provided time
        blLength=max(blfNIR.time)-min(blfNIR.time)+1/blfNIR.fs; %Baseline length in time
    elseif(~isempty(blLength)&&~isfield(blfNIR,'empty')&&blLength==0&&~isempty(blfNIR)&&~any(isnan(blfNIR.time))&&isfield(blfNIR,'fs'))
        % else estimate from sampling rate
        blLength=1/blfNIR.fs;
    else
       warning('Entire Baseline is invalid');
       blLength=nan;
    end
elseif(blLength==0)
    blLength=[];
end

if(nargout>1) %provide poly fit only if two arguments are present
    getPolyAvg=true;
elseif(nargout<=1)
    getPolyAvg=false;
end

if(~isfield(fNIR,'HbR')&&isfield(fNIR,'raw'))
    % out of principle we don't resample the raw data
    warning('Raw data averaging not supported');
elseif(~isfield(fNIR,'HbR')&&~isfield(fNIR,'raw'))
    warning('No fNIRS data');
    outFNIR=fNIR;
    pFit=[];
    return;
else
    numCh=size(fNIR.HbR,2); 
end

%if(isfield(fNIR,'raw')&&isempty(fNIR.raw))
    %fNIR.raw=nan(size(fNIR.HbR));
    %prevent resampling of raw
%end

if(centerOnT0) % foces time blocks to start from t=0
    [fTimeInd,times]=getTimeIdx(fTime,segLength,0);
else % start at min time
    [fTimeInd,times]=getTimeIdx(fTime,segLength);
end

minSegTime=times(1);
maxSegTime=times(end);

numSegs=length(times);

if(pf2_base.isnestedfield(fNIR,'ROI.HbR')&&~isempty(fNIR.ROI.HbR))
    calcROI=true;
    numROI=size(fNIR.ROI.HbR,2);
else
    calcROI=false;
    numROI=0;
end


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


if(blLength>0) % if baseline is present
    bioMlist={'HbO','HbR','HbDiff','HbTotal','CBSI'};

    for b = 1:length(bioMlist)
        curB=bioMlist{b};
        fB=blfNIR.(curB);
   
        blNanCheck=sum(isnan(fB),1)/length(fB)<nanRejectionLevel; %calculate percentage of invalid values in baseline

        blRejectedCount=sum(~blNanCheck);
        
        if(blRejectedCount>1)
            warning('Baseline Period in %i channels was invalid',blRejectedCount); 
        end
        
        validCh=find(blNanCheck==1);

        blfNIR.(curB)=mean(fB,1,'omitnan');
        blfNIR.(curB)(~blNanCheck)=nan;

        if(isempty(blfNIR.(curB)))
            blfNIR.(curB)=nan;
        end

        if(calcROI)

            if(pf2_base.isnestedfield(blfNIR,strcat('ROI.',+curB)))
                fB=blfNIR.ROI.(curB);
            else
                warning('ROI mismatch: ROI is not defined in baseline file');
                calcROI=false;
                continue;
            end

            if(size(fB,2)~=numROI)
                warning('ROI mismatch: ROI as defined in baseline not present in main fNIRS segment, calculations not performed');
                calcROI=false;
                continue;
            end

            blNanCheck_roi=sum(isnan(fB),1)/length(fB)<nanRejectionLevel; %calculate percentage of invalid values in baseline

            blRejectedCount_roi=sum(~blNanCheck_roi);
            if(blRejectedCount_roi>1)
                warning('ROI Baseline Period in %i channels was invalid',blRejectedCount_roi); 
            end
            validCh_roi=find(blNanCheck_roi==1);
            
            blfNIR.ROI.(curB)=mean(fB,1,'omitnan');
            blfNIR.ROI.(curB)(~blNanCheck_roi)=nan;
    
            if(isempty(blfNIR.ROI.(curB)))
                blfNIR.ROI.(curB)=nan;
            end
        end
    end  
else
    validCh=1:numCh;
    if(calcROI)
       validCh_roi=1:numROI;
    else
        numROI=0;
    end
end


if(strcmp(timeOutMode,'start')) %default
    timeOutModeMid=false;
    timeOutModeEnd=false;
elseif(strcmp(timeOutMode,'end'))
    timeOutModeMid=false;
    timeOutModeEnd=true;
else %Return midpoint
    timeOutModeMid=true;
    timeOutModeEnd=false;
end

if(timeOutModeMid)
    times_start=times-segLength/2;
    times_end=times+segLength/2-(1e-10);
elseif(timeOutModeEnd)
    times_start=times-segLength+(1e-10);
    times_end=times;
else
    times_start=times;
    times_end=times+segLength-1e-10;
end

%minSegTime=times_start(1);
%maxSegTime=times_start(end);

%calculate index for each sample
%fTimeInd=floor((fTime-minfTime-rem(fTime-minfTime,segLength))/segLength)+1;
nTime=length(fTimeInd);


if(calcROI)
    %fTimeInd_numROI=repmat(fTimeInd,[numROI,1]);
    %fTimeInd_numROI=fTimeInd_numROI+numSegs*repelem([0:numROI-1]',nTime,1);

    outFNIR.ROI.info=fNIR.ROI.info;
end


ptime=zeros(numSegs,1); %polynomial time

bioMlist={'raw','HbO','HbR','HbDiff','HbTotal','CBSI'};

for b = 1:length(bioMlist)
    curB=bioMlist{b};

    isRaw=strcmpi(curB,'raw');
    fB=fNIR.(curB);

    numCh=size(fB,2);

    fB_resample=resample_internal(fB,fTimeInd,numCh,numSegs,nanRejectionLevel);

    if(~isempty(blLength)&&blLength>0&&~isRaw)
        outFNIR.(curB)=fB_resample-repmat(blfNIR.(curB),[numSegs,1]);
    elseif(~isempty(blLength)&&isnan(blLength)&&~isRaw)
        outFNIR.(curB)=nan(size([numCh,numSegs]));
    else
        outFNIR.(curB)=fB_resample;
    end


    if(getPolyAvg)
        pFit.(curB)=nan(size([numCh,numSegs,polyDegree+1]));
        bioFitVal=sprintf('%s_val',curB);
        pFit.(bioFitVal)=nan(size([numCh,numSegs]));
        
        
        for chIdx=1:length(validCh)
            ch=validCh(chIdx);
            validIdx=~isnan(fB(:,ch));
            for segIdx=1:numSegs
                tSeg=validIdx&fTimeInd==segIdx;
                tSegTimeRem=fTime(tSeg)-times_start(segIdx);
                
                pFit.(bioFitVal)(segIdx,ch,1:polyDegree+1)=mpolyfit(tSegTimeRem,fB(tSeg,ch),polyDegree);
                pFit.(curB)(segIdx,ch)=polyval(reshape(pFit.(bioFitVal)(segIdx,ch,:),[polyDegree+1,1,1]),times_end(segIdx)-segLength/2);
            end
        end

        if(~isempty(blLength)&&blLength>0&&~isRaw)
            pFit.(curB)=pFit.(curB)-repmat(blfNIR.(curB),[numSegs,1]);
        elseif(~isempty(blLength)&&isnan(blLength)&&~isRaw)
            pFit.(curB)=nan(size([numCh,numSegs]));
        else
            %pFit.(curB)=pFit.(curB);
        end
    end

    if(calcROI&&~isRaw)
        fB=fNIR.ROI.(curB);

        fB_resample=resample_internal(fB,fTimeInd,numROI,numSegs,nanRejectionLevel);

        if(~isempty(blLength)&&blLength>0)
            outFNIR.ROI.(curB)=fB_resample-repmat(blfNIR.ROI.(curB),[numSegs,1]);
        elseif(~isempty(blLength)&&isnan(blLength))
            outFNIR.ROI.(curB)=nan(size([numROI,numSegs]));
        else
            outFNIR.ROI.(curB)=fB_resample;
        end

        if(getPolyAvg)
            pFit.ROI.(curB)=nan(size([numCh,numSegs,polyDegree+1]));
            bioFitVal=sprintf('%s_val',curB);
            pFit.ROI.(bioFitVal)=nan(size([numCh,numSegs]));
            
            
            for chIdx=1:length(validCh)
                ch=validCh(chIdx);
                validIdx=~isnan(fB(:,ch));
                for segIdx=1:numSegs
                    tSeg=validIdx&fTimeInd==segIdx;
                    tSegTimeRem=fTime(tSeg)-times_start(segIdx);
                    
                    pFit.(bioFitVal)(segIdx,ch,1:polyDegree+1)=mpolyfit(tSegTimeRem,fB(tSeg,ch),polyDegree);
                    pFit.(curB)(segIdx,ch)=polyval(reshape(pFit.(bioFitVal)(segIdx,ch,:),[polyDegree+1,1,1]),times_end(segIdx)-segLength/2);
                end
            end
    
            if(~isempty(blLength)&&blLength>0)
                pFit.(curB)=pFit.(curB)-repmat(blfNIR.(curB),[numSegs,1]);
            elseif(~isempty(blLength)&&isnan(blLength))
                pFit.(curB)=nan(size([numCh,numSegs]));
            else
                %pFit.(curB)=pFit.(curB);
            end
        end
    end
end

if(averageAux&&~isempty(fNIR.Aux))
    auxFields=fields(fNIR.Aux);

    % Attempts to resample any field (and align with fNIRS)
        % criteria:
        %   1) field is same length as fNIR (and greater than 1)
        %       uses fNIR time as reference
        %   2) Aux contains own time field
        %       uses Aux time as reference
        %   3) Aux contains column which is time
        %   4) Aux contains table column t or 'time' which contains time

    auxFieldsSize=nan(size(auxFields,1),2);
    auxFieldHasTime=false(size(auxFields));
    auxFieldIsTable=false(size(auxFields));
    auxFieldIsArray=false(size(auxFields));
    auxFieldIsStruct=false(size(auxFields));

    validTimeFields={'time','t','Time'};

    for f=1:length(auxFields)
        curFieldName=auxFields{f};
        curField=fNIR.Aux.(curFieldName);

        t_aux=[];
        t_ind=[];

        auxFieldIsTable(f)=istable(curField);
        auxFieldIsStruct(f)=isstruct(curField);
        auxFieldIsArray(f)=isnumeric(curField)||islogical(curField);

        if(auxFieldIsTable(f)||auxFieldIsArray(f))
            auxFieldsSize(f,[1:2])=size(curField);
        end

        if(auxFieldIsTable(f)&&~isempty(intersect(validTimeFields,curField.Properties.VariableNames)))
            timeTableVar=intersect(validTimeFields,curField.Properties.VariableNames);
            t_aux=curField.(timeTableVar{1}){:};
            t_ind=[];
            auxFieldHasTime(f)=true;
            auxVarNames=curField.Properties.VariableNames;
            auxVarNames(ismember(auxVarNames,validTimeFields))=[];

        elseif(auxFieldIsStruct(f))&&any(isfield(curField,validTimeFields))
            timeStructVar=validTimeFields(isfield(curField,validTimeFields));
            t_aux=curField.(timeStructVar{1});
            t_ind=[];
            auxFieldHasTime(f)=true;
            auxVarNames=fields(curField);
            auxVarNames(ismember(auxVarNames,validTimeFields))=[];

        elseif(auxFieldIsArray(f)&&all(diff(curField(:,1))>0)&&length(curField(:,1))>1)
            possibleTimeField=all(diff(curField(:,1))>0); %time must increase only
            t_aux=curField(:,1);
            t_ind=[];
            auxFieldHasTime(f)=true;
            nAuxChan=size(curField,2)-1;
        else
            auxFieldHasTime(f)=false;
        end

        if(~auxFieldHasTime(f)&&auxFieldsSize(f,1)==nTime) % Match for fNIR time
            warning('Non-explicit match for Aux resampling, please use Aux.time variable or ''time'' table column ');
            t_aux=fNIR.time;
            t_ind=fTimeInd; % Just use fNIR time
            nAuxChan=auxFieldsSize(f,2);
        end

        if(isempty(t_aux))
            fprintf('Unable to average signal .Aux.%s, no matched time found\n',curFieldName);
            continue;
        end

        if(isempty(t_ind)) % if not using fNIR time, we have to figure out where time is logically
            %calculate index for each sample

            [t_ind,t_aux_resample]=getTimeIdx(t_aux,segLength,minfTime);
            
        end

        n_aux_time=length(t_ind);
        numSegs_aux=max(t_ind);

        if(auxFieldIsArray(f))

            auxDat=curField(:);
            auxDat_resample=resample_internal(auxDat,t_ind,nAuxChan,numSegs_aux,nanRejectionLevel);

            if(auxFieldHasTime(f))
                auxDat_resample(:,1)=t_aux_resample;
            end

            outFNIR.Aux.(curFieldName)=auxDat_resample;
            
        elseif(auxFieldIsTable(f))
            outFNIR.Aux.(curFieldName)=table(t_aux_resample,'VariableNames',{'time'});
            for var=1:length(auxVarNames)
                curVarName=auxVarNames{var};
                curVar=curField.(curVarName){:};

                if(isnumeric(curVar)&&any(size(curVar)==length(n_aux_time)))

                    if(size(curVar,1)~=n_aux_time) % already know at least one dimension matches
                        curVar=curVar';
                    end

                    nAuxChan=size(curVar,2);

                    auxDat=curVar(:);
                    auxDat_resample=resample_internal(auxDat,t_ind,nAuxChan,numSegs_aux,nanRejectionLevel);

        
                    outFNIR.Aux.(curFieldName).(curVarName)=auxDat_resample;
                end
            end
        elseif(auxFieldIsStruct(f))
            outFNIR.Aux.(curFieldName).time=t_aux_resample;
            for var=1:length(auxVarNames)
                curVarName=auxVarNames{var};
                curVar=curField.(curVarName);
                curVar=curVar(:);

                if(isnumeric(curVar)&&any(size(curVar)==length(n_aux_time)))
                    nAuxChan=size(curVar,2);

                    auxDat=curVar(:);
                    auxDat_resample=resample_internal(auxDat,t_ind,nAuxChan,numSegs_aux,nanRejectionLevel);
        
                    outFNIR.Aux.(curFieldName).(curVarName)=auxDat_resample;
                end
            end
        end

    end
end


validFields=pf2_base.pf2_getFNIRSfields();
fdataFields=fields(fNIR);  % Copy known fields
for fieldIdx=1:length(fdataFields)
   memberIdx=ismember(validFields,fdataFields{fieldIdx});
   if(any(memberIdx)&&~strcmp(fdataFields{fieldIdx},'time')...
           &&~strcmp(fdataFields{fieldIdx},'fs')&&~strcmp(fdataFields{fieldIdx},'ROI')&&~strcmp(fdataFields{fieldIdx},'Aux'))
        outFNIR.(validFields{memberIdx})=fNIR.(fdataFields{fieldIdx});
   end
end

outFNIR.segmentTimes=[times_start,times,times_end];

if(~isempty(outFNIR.segmentTimes))
    if(strcmp(timeOutMode,'start'))
        outFNIR.time=outFNIR.segmentTimes(:,1); %returns effective "sample point" as startpoint of segmentTimes
    elseif(strcmp(timeOutMode,'end'))
        outFNIR.time=outFNIR.segmentTimes(:,2); %returns effective "sample point" as endpoint of segmentTimes
    else %Return midpoint
        outFNIR.time=time; %mean(outFNIR.segmentTimes,2); %returns effective "sample point" as midpoint of segmentTimes
        % should match times variable
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

function [fTimeInd,timeSeries]=getTimeIdx(times_in,segLength,centerTime)
    % Returns the time indicies for a time series times_in
    % sampled by segmentLength and "centered" with a point at centerTime
        % ie: the time series includes the point centerTime, (or would if
        % samples around that time were collected


 
    t1=times_in(1);
    %te=times_in(end);

    times_in=times_in(:);

    %tRange_in=te-t1;

    if(nargin<3) % just use min time
        centerTime=t1;
    end

   

    minSegTime=centerTime+floor((t1-centerTime)/segLength)*segLength;
    % minimum SegTime is the first value that meets the crieria
    %       t0_rs = centerTime+segLength*N  (where N is some number of samples
    %       and t0_sample > t0_rs  but t0_sample < t0_rs +segLength
    
    %maxSegTime=centerTime+floor((te-centerTime)/segLength)*segLength;

    fTimeInd=[floor((times_in-minSegTime)/segLength+1+1e-10)];
    % 1e-10 helps fix conditions where floor returns n-1 instead of n
    % fTimeInd(end) is the highest value here, faster than max()
    
    maxSegTime=minSegTime+(fTimeInd(end)-1)*segLength;


    timeSeries=[minSegTime:segLength:maxSegTime]';

    
end

function [rsData] = resample_internal(rsData_in,fTimeInd,numCh,numSegs,nanRejectionLevel)
    % resamples data according to the values in fTimeInd(sample indicies)
    % numCh defines the original number of channels
    
    % nanRejectionLevel defines how many nans are allowed before rejecting
    % the segment

        % variable names and sizes
        %   fTimeInd: t x 1
        %   rsData_in: t x N
        %   fTimeInd_numCh t*N x 1
        %   fB_count: s*N x 1
        %   rsData: s x N
    
    nTime=length(fTimeInd);
    fTimeInd_numCh=repmat(fTimeInd,[numCh,1]);
    fTimeInd_numCh=fTimeInd_numCh+numSegs*repelem([0:numCh-1]',nTime,1);

try
    fB_isNA=accumarray(fTimeInd_numCh,isnan(rsData_in(:)));
catch
    rsData=[];
    return;
end
    fB_count=accumarray(fTimeInd_numCh,ones(size(fTimeInd_numCh)));

    % Check edge case where last sample does not include last index, pad
    % with 0s
    diffCheck=(numCh*numSegs)-length(fB_isNA);
    if(diffCheck>0)
        fB_isNA=[fB_isNA;zeros([diffCheck,1])];
        fB_count=[fB_count;zeros([diffCheck,1])];
    end

    fB_nanCheck= reshape(fB_isNA./fB_count,[numCh,numSegs])<=nanRejectionLevel;

    rsData=reshape(accumarray(fTimeInd_numCh,rsData_in(:),[numCh*numSegs',1],@(x)nanmean(x)),[numSegs,numCh]);

    rsData(~fB_nanCheck)=NaN;

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