function outGA = grandAvgFNIRS(FNIRScellArray,timeAlign,resampleSize,centerOnT0,hierarchyVars,showProgress,averageAux)

% grandAvgFNIRS is a function which takes an oxy-processed cell array of
% FNIRS structs and produces a grand average waveform.

% output is similar to a typical fNIR struct except that .HbO and other
% biomarker fields contain a .data .mean .median .sem .sd .max and .min field

% If timeAlign is set to true all segments will be adjusted so that the
% first sample occurs at t=0 prior to averaging

% no baselineining is performed in this function

% %if no resampling frequency is provided, resampling will automatically
% occur to the median sampling frequency of all data. If all sampling
% frequencies are identical already, no resampling will occur unless
% resampleFS is specified

% Uses precision of 0.01ms

%
if(nargin<7)
    averageAux=false;
end

if(nargin<6)
    showProgress=false;
end

if(nargin<5||isempty(hierarchyVars))
   hierarchyVars=[1:length(FNIRScellArray)]'; 
end

if(nargin<4)
   centerOnT0=false; 
end

if(nargin<2)
    timeAlign=true;
end

if(~iscell(FNIRScellArray))
   error('First argument must be a cell array of FNIRS structs'); 
end

segUnits=cell(size(FNIRScellArray));
segSampleTimes=nan(size(FNIRScellArray));
segSampleCount=nan(size(FNIRScellArray));
segROIpresent=false(size(FNIRScellArray));
hasFNIRS=true(size(FNIRScellArray));

removedIdx=false(size(FNIRScellArray));
keepMask=true(1,length(FNIRScellArray));
for i=1:length(FNIRScellArray)
    if(isempty(FNIRScellArray{i}))
        keepMask(i)=false;
        removedIdx(i)=true;
        continue;
    end
    hasAux=isfield(FNIRScellArray{i},'Aux');
    hasTime=isfield(FNIRScellArray{i},'time')&&~isempty(FNIRScellArray{i}.time);
    noValidTime=hasTime&&sum(~isnan(FNIRScellArray{i}.time))==0;
    hasROI=isfield(FNIRScellArray{i},'ROI')&&isfield(FNIRScellArray{i}.ROI,'HbO');

    if(noValidTime&&hasAux&&isempty(FNIRScellArray{i}.Aux)) % Empty Case (no valid time, empty Aux)
        keepMask(i)=false;
        removedIdx(i)=true;
    elseif(noValidTime&&hasAux) % no fnirs but has Aux
        hasFNIRS(i)=false;
        segSampleTimes(i)=nan;
        segSampleCount(i)=0;
        segROIpresent(i)=false;
    elseif(~isfield(FNIRScellArray{i},'fs')&&isfield(FNIRScellArray{i},'time')) % Missing sampling frequency
        FNIRScellArray{i}.time=round(FNIRScellArray{i}.time,5);
        if(timeAlign)
            FNIRScellArray{i}.time=FNIRScellArray{i}.time-min(FNIRScellArray{i}.time);
        end
        segSampleTimes(i)=median(diff(FNIRScellArray{i}.time));
        segSampleCount(i)=length(FNIRScellArray{i}.time);
        segUnits{i}=FNIRScellArray{i}.units;
        FNIRScellArray{i}.fs=1/segSampleTimes(i);
        FNIRScellArray{i}.fs=round(FNIRScellArray{i}.fs,3);
        segROIpresent(i)=hasROI;
    elseif(~hasTime||all(isnan(FNIRScellArray{i}.time)))  % No Time information
        keepMask(i)=false;
        warning('Cannot use groups which have no time info');
        removedIdx(i)=true;
    elseif(timeAlign)   % Force time alignment
        FNIRScellArray{i}.time=round(FNIRScellArray{i}.time,5);
        FNIRScellArray{i}.time=FNIRScellArray{i}.time-min(FNIRScellArray{i}.time);
        segSampleTimes(i)=median(diff(FNIRScellArray{i}.time));
        segSampleCount(i)=length(FNIRScellArray{i}.time);
        segUnits{i}=FNIRScellArray{i}.units;
        FNIRScellArray{i}.fs=1/segSampleTimes(i);
        FNIRScellArray{i}.fs=round(FNIRScellArray{i}.fs,3);
        segROIpresent(i)=hasROI;
    else   %Nicely aligned
        FNIRScellArray{i}.time=round(FNIRScellArray{i}.time,5);
        segSampleTimes(i)=median(diff(FNIRScellArray{i}.time));
        segSampleCount(i)=length(FNIRScellArray{i}.time);
        if(isfield(FNIRScellArray{i},'units'))
            segUnits{i}=FNIRScellArray{i}.units;
        else
            segUnits{i}='Unknown';
        end
        FNIRScellArray{i}.fs=1/segSampleTimes(i);
        FNIRScellArray{i}.fs=round(FNIRScellArray{i}.fs,3);
        segROIpresent(i)=hasROI;
    end
end
% Single vectorized deletion instead of per-element shifting
FNIRScellArray(~keepMask)=[];
segSampleTimes(~keepMask)=[];
segSampleCount(~keepMask)=[];
hierarchyVars(~keepMask,:)=[];
segROIpresent(~keepMask)=[];
segUnits(~keepMask)=[];
hasFNIRS(~keepMask)=[];

numfSeg=length(FNIRScellArray);

if(isempty(FNIRScellArray))
    outGA=[];
    return;
end


uUnitsArray=unique(segUnits(hasFNIRS));
if(~iscell(uUnitsArray))
    uUnitsArray={uUnitsArray};
end
if(length(uUnitsArray)>1)
   error('Mismatched units in grandaveraged data'); 
else
    outGA=[];
    outGA.units=uUnitsArray{1};
end

ufsArray=unique(segSampleTimes(~isnan(segSampleTimes)));

if(length(ufsArray)>1)
    resample=true;
else
    resample=false;
end

if(nargin<3||isempty(resampleSize))
    resampleSize=nanmedian(segSampleTimes);
    if(resample)
        warning('Mismatched data fs!\nAutomatic resampling performed at %.2f Hz',1/resampleSize);
    end
elseif(sum(segSampleCount>1)>0)
    resample=true;
end

% Handle single-point data (e.g. GLM betas): when all segments have only
% one timepoint, median(diff) yields NaN. Use a dummy sample interval of 1
% so the time grid [minTime:1:maxTime] collapses to a single point.
if (isnan(resampleSize) || resampleSize <= 0) && all(segSampleCount <= 1)
    resampleSize = 1;
    resample = false;
end

if(sum(segROIpresent)==length(FNIRScellArray))
    calcROI=true;
elseif(sum(segROIpresent)>0)
    %warning('ROI definitions not present in all segments, ROI regions will not be calculated');
    calcROI=true;
else
   calcROI=false; 
end

minTime=inf;
maxTime=-inf;
numCh=0;
numROI=0;

if(isnan(resampleSize)||resampleSize<=0)
    warning('Unable to resample data, invalid resampleFS');
end

segTimesAccum=cell(numfSeg,1);
auxFieldsAccum=cell(numfSeg,1);
auxSizesAccum=cell(numfSeg,1);

for i=1:numfSeg % Resample and find max/min and num channels
    if(resample)
        if(centerOnT0)
            FNIRScellArray{i}=pf2.data.resample(FNIRScellArray{i},resampleSize,'centerOnT0',centerOnT0,'timeOutMode','start','averageAux',true,'flattenAux',true,'trimAux',true);
        else
            FNIRScellArray{i}=pf2.data.resample(FNIRScellArray{i},resampleSize,'centerOnT0',centerOnT0,'averageAux',true,'flattenAux',true,'trimAux',true);
        end
    end

    if(isfield(FNIRScellArray{i},'segmentTimes'))
        segTimesAccum{i}=FNIRScellArray{i}.segmentTimes;
    end

    if(isfield(FNIRScellArray{i},'Aux')&&~isempty(FNIRScellArray{i}.Aux))
        possibleFields=fieldnames(FNIRScellArray{i}.Aux);
        possibleFieldSizes=nan(size(possibleFields));

        temp=false(size(possibleFields));
        for pf_ind=1:length(possibleFields)
            curField=FNIRScellArray{i}.Aux.(possibleFields{pf_ind});
            possibleFieldSizes(pf_ind)=size(FNIRScellArray{i}.Aux.(possibleFields{pf_ind}),2);
            if(~isempty(curField)&&istable(curField)&&ismember('time',curField.Properties.VariableNames))
                temp(pf_ind)=true;
            end
        end
        auxFieldsAccum{i}=possibleFields(temp);
        auxSizesAccum{i}=possibleFieldSizes(temp);
    end

    minFtime=min(FNIRScellArray{i}.time);
    maxFtime=max(FNIRScellArray{i}.time);
    if(minFtime<minTime)
        minTime=minFtime;
    end
    if(maxFtime>maxTime)
        maxTime=maxFtime;
    end

    if(hasFNIRS(i)&&size(FNIRScellArray{i}.HbO,2)>numCh)
       numCh=size(FNIRScellArray{i}.HbO,2);
    end

    if(hasFNIRS(i)&&calcROI&&isfield(FNIRScellArray{i},'ROI')&&isfield(FNIRScellArray{i}.ROI,'info')&&size(FNIRScellArray{i}.ROI.info,1)>numROI)
        numROI=size(FNIRScellArray{i}.ROI.info,1);
    end

    FNIRScellArray{i}.timeIdx=[FNIRScellArray{i}.time,[1:length(FNIRScellArray{i}.time)]',zeros(size(FNIRScellArray{i}.time))];
end

segmentTimesArr=vertcat(segTimesAccum{~cellfun(@isempty,segTimesAccum)});
auxFieldsAll=vertcat(auxFieldsAccum{~cellfun(@isempty,auxFieldsAccum)});
auxFieldSizesAll=vertcat(auxSizesAccum{~cellfun(@isempty,auxSizesAccum)});
if(isempty(auxFieldsAll))
    auxFields=string.empty;
    auxFieldSizes=[];
else
    [auxFields,idx]=unique(string(auxFieldsAll));
    auxFieldSizes=auxFieldSizesAll(idx);
end
numAuxFields=length(auxFields);

maxTime=rem(maxTime-minTime,resampleSize)+maxTime;

outGA.time=round([minTime:resampleSize:maxTime]',5);

if(~isempty(segmentTimesArr))
    outGA.segmentTimes=unique(segmentTimesArr,'rows');
    outGA.segmentTimes=sort(outGA.segmentTimes,1);
     outGA.segmentTimes=round( outGA.segmentTimes,5);
    outGA.time=outGA.time(ismember(outGA.time,outGA.segmentTimes(:,1)));
else
    % Build segmentTimes from the time grid when not provided by input
    % segments (e.g. single-point GLM betas). Format: [start, mid, end].
    nT = length(outGA.time);
    if nT == 1
        outGA.segmentTimes = [outGA.time, outGA.time, outGA.time];
    else
        halfBin = resampleSize / 2;
        outGA.segmentTimes = [outGA.time - halfBin, outGA.time, outGA.time + halfBin];
    end
end

numSegs=length(outGA.time);

if(showProgress)
    hF=waitbar(0,sprintf('grandAvgFNIRS\nAligning segment %i of %i',1,numfSeg));
end

for i=1:numfSeg %find matching times in outGA.time, add to cell time indicies and sort by time
    if(showProgress)
        waitbar(i/numfSeg,hF,sprintf('grandAvgFNIRS\nAligning segment %i of %i',i,numfSeg));
    end
    
	curT_idx=FNIRScellArray{i}.timeIdx;  % 3xN [Time, TimeIndex,..]

    [validT,alignedTimeIdx]=ismember(curT_idx(:,1),outGA.time); % check if current indexes are present in outGA.time

    curT_idx(:,3)=alignedTimeIdx; % 3xN [Time, OriginalTimeIndex,AlignedTimeIndex]
    
    % Check for GA sections with no data
    [~,missingTimeIdx]=ismember(outGA.time,curT_idx(:,1));

    if(~isempty(missingTimeIdx)&&any(missingTimeIdx==0))
        outsideTimeIdx=outGA.time(missingTimeIdx==0);

        if(~isempty(outsideTimeIdx))
            % if time segement is unmatched, build a nan style matrix for
            % 3xN [Time, Nan,AlignedTimeIndex]
            % 
            outsideTimeIdx(:,2)=nan;
            outsideTimeIdx(:,3)=0;
            curT_idx=[curT_idx;outsideTimeIdx];

            % insert missing segments into timeline
            [~,idx]=sort(curT_idx(:,1));
            curT_idx=curT_idx(idx,:);
            
            % if time is missing  in between two samples
            tDiffMissing=[diff(curT_idx(:,3));0]>1;
            
            if(any(tDiffMissing))
                % see if it is more appropriate to move samples up by one
                % or down by one
                tTimeDiff=[0;diff(curT_idx(:,1))];
                tTimeDiffUp=tDiffMissing&tTimeDiff>resampleSize/2;
                tTimeDiffDown=tDiffMissing&tTimeDiff<=resampleSize/2;
                upOneArr=[tTimeDiffUp(2:end);false];
                downOneArr=[false;tTimeDiffDown(1:end-1)];
                if(any(tTimeDiffUp))
                    curT_idx(tTimeDiffUp,1)=curT_idx(upOneArr,1);
                    curT_idx(upOneArr,2)=curT_idx(tTimeDiffUp,2);
                end
                if(any(tTimeDiffDown))
                    curT_idx(tTimeDiffDown,1)=curT_idx(downOneArr,1);
                    curT_idx(downOneArr,2)=curT_idx(tTimeDiffDown,2);
                end
            end
        end
    end
                
    % remove any unmatched rows (alignedtime index is zero)
    curT_idx(curT_idx(:,3)==0,:)=[];
    curT_idx(:,4)=~isnan(curT_idx(:,2));
    FNIRScellArray{i}.timeIdx=curT_idx; % t idx isMemberOfTime isNan
end

bioMs={'HbO','HbDiff','HbR','HbTotal','CBSI'};
for b=1:length(bioMs)
        curBioM=bioMs{b};
        outGA.(curBioM).data=nan(length(outGA.time),numCh,numfSeg);
        
    if(calcROI)
        curBioM=bioMs{b};
        outGA.ROI.(curBioM).data=nan(length(outGA.time),numROI,numfSeg);
    end
end


if(averageAux)
    auxFieldSizes(auxFieldSizes>1)=auxFieldSizes(auxFieldSizes>1)-1; % remove anticipated time column from var count (for all but single column data)
    for aux=1:length(auxFields)
            curAuxField=char(auxFields(aux));
            outGA.Aux.(curAuxField).data=nan(length(outGA.time),auxFieldSizes(aux),numfSeg);
    end
end

initROI=false;

for i=1:numfSeg
    curFNIR=FNIRScellArray{i};

    if(hasFNIRS(i))
        numfCh=size(curFNIR.HbO,2);
        
        validTidx=FNIRScellArray{i}.timeIdx(:,3)>0 & logical(FNIRScellArray{i}.timeIdx(:,4));
        validT=false([numSegs,1]);
        validT(FNIRScellArray{i}.timeIdx(validTidx,3))=true;

        for b=1:length(bioMs)
            curBioM=bioMs{b};
            srcRows=FNIRScellArray{i}.timeIdx(validTidx,2);
            nSrc=size(curFNIR.(curBioM),1);
            if(max(srcRows)<=nSrc)
                outGA.(curBioM).data(validT,1:numfCh,i)=curFNIR.(curBioM)(srcRows,:,1);
            end
        end

        hasROI_i=isfield(curFNIR,'ROI')&&isfield(curFNIR.ROI,'HbO');
        if(calcROI&&hasROI_i)
            if(~initROI&&isfield(curFNIR.ROI,'info')&&~isempty(curFNIR.ROI.info))
                outGA.ROI.info=curFNIR.ROI.info;
                initROI=true;
            end
            numfCh_roi=size(curFNIR.ROI.HbO,2);
            for b=1:length(bioMs)
                curBioM=bioMs{b};
                outGA.ROI.(curBioM).data(validT,1:numfCh_roi,i)=curFNIR.ROI.(curBioM)(FNIRScellArray{i}.timeIdx(validTidx,2),:,1);
            end
        else
            numfCh_roi=0;
        end
    end
    
    if(isfield(curFNIR,'Aux')&&averageAux&&~isempty(curFNIR.Aux))
        curSegAuxFields=fieldnames(curFNIR.Aux);

        if(~isempty(curSegAuxFields))

            rndTimesIdx=round(FNIRScellArray{i}.timeIdx,4);

            for aux=1:numAuxFields
                curAuxField=char(auxFields(aux));
                if(ismember(curAuxField,curSegAuxFields))
                        try
                            if(isstring(curFNIR.Aux.(curAuxField))||ischar(curFNIR.Aux.(curAuxField))||isempty(curFNIR.Aux.(curAuxField))...
                                    ||(~istable(curFNIR.Aux.(curAuxField))&&all(size(curFNIR.Aux.(curAuxField))==[1,1])))
                                continue;
                            end
                            if(istable(curFNIR.Aux.(curAuxField))&&ismember('time',curFNIR.Aux.(curAuxField).Properties.VariableNames))
                                auxTimes=round(curFNIR.Aux.(curAuxField).time,4);
                                nonTimeColsIdx=~ismember(curFNIR.Aux.(curAuxField).Properties.VariableNames,'time');
                                

                                tableFields=curFNIR.Aux.(curAuxField).Properties.VariableNames;
                                numericTimeColsIdx=false(size(tableFields));
                                for fType=1:length(tableFields)
                                    curVar=curFNIR.Aux.(curAuxField).(tableFields{fType});
                                    if(isduration(curVar))
                                        curFNIR.Aux.(curAuxField).(tableFields{fType})=seconds(curFNIR.Aux.(curAuxField).(tableFields{fType}));
                                        numericTimeColsIdx(fType)=true;
                                    else
                                        numericTimeColsIdx(fType)=isnumeric(curVar)||islogical(curVar);

                                        if(~numericTimeColsIdx(fType))
                                            curFNIR.Aux.(curAuxField).(tableFields{fType})=nan(size(curFNIR.Aux.(curAuxField).(tableFields{fType})));
                                            numericTimeColsIdx(fType)=true;

                                        end
                                    end
                                end

                                nonTimeColsIdx=nonTimeColsIdx&numericTimeColsIdx;
                            elseif(size(curFNIR.Aux.(curAuxField),2)>1)
                                % Array, time is first position
                                auxTimes=round(curFNIR.Aux.(curAuxField)(:,1),4);
                                nonTimeColsIdx=[2:size(curFNIR.Aux.(curAuxField),2)];
                            elseif(isfield(curFNIR.Aux,'time'))
                                auxTimes=round(curFNIR.Aux.time,4);
                                nonTimeColsIdx=1;
                            else
                                outGA.Aux.(curAuxField).data(validT,:,i)=nan;
                                continue;
                            end
                            
                            [auxValidT,auxValidIdx]=ismember(outGA.time,auxTimes);
                            auxValidIdx(auxValidIdx==0)=[]; 
                            
                            if(~isempty(auxValidIdx))
                                if(~istable(curFNIR.Aux.(curAuxField)))
                                    outGA.Aux.(curAuxField).data(auxValidT,:,i)=curFNIR.Aux.(curAuxField)(auxValidIdx,nonTimeColsIdx);
                                else
                                    outGA.Aux.(curAuxField).data(auxValidT,:,i)=curFNIR.Aux.(curAuxField){auxValidIdx,nonTimeColsIdx};
                                    if(~isfield(outGA.Aux.(curAuxField),'varNames'))
                                        temp_curVarNames=curFNIR.Aux.(curAuxField).Properties.VariableNames;
                                        outGA.Aux.(curAuxField).varNames=temp_curVarNames(~strcmp(temp_curVarNames,'time'));
                                    end
                                end
                            end
                        catch
                            warning('Mismatch between sampling of aux time and fNIRS time');
                            outGA.Aux.(curAuxField).data(:,:,i)=nan;
                        end
                            % this will only work if time indexes match between
                        % auxtime and fnirs time. they either need to be
                        % resampled at this point, or need to be resampled
                        % earlier
                end
            end
        else
            for aux=1:numAuxFields
                curAuxField=char(auxFields(aux));
                if(ismember(curAuxField,curSegAuxFields))
                        outGA.Aux.(curAuxField).data(:,:,i)=nan;
                end
            end
        end
    end
end

nanmax3=@(x,dim) nanmax(x,[],dim);
nanmin3=@(x,dim) nanmin(x,[],dim);
hAvgFuncs={@nanmean, @nanmedian, nanmax3, nanmin3};

for b=1:length(bioMs) % Calculate hierarchical Average for each variable
    if(showProgress)
        waitbar(b/length(bioMs),hF,sprintf('grandAvgFNIRS\nAveraging biomarker %i of %i',b,length(bioMs)));
    end
    curBioM=bioMs{b};
    inData=permute(outGA.(curBioM).data,[3,1,2]);
    [res,tierLabel,hierarchy]=pf2_base.hierarchicalAverageMulti(inData,hierarchyVars,hAvgFuncs);
    hAvg.(curBioM).Mean=res{1};
    hAvg.(curBioM).Median=res{2};
    hAvg.(curBioM).Max=res{3};
    hAvg.(curBioM).Min=res{4};

    if(calcROI)
        inData=permute(outGA.ROI.(curBioM).data,[3,1,2]);
        [res,tierLabel,hierarchy]=pf2_base.hierarchicalAverageMulti(inData,hierarchyVars,hAvgFuncs);
        hAvg.ROI.(curBioM).Mean=res{1};
        hAvg.ROI.(curBioM).Median=res{2};
        hAvg.ROI.(curBioM).Max=res{3};
        hAvg.ROI.(curBioM).Min=res{4};
    end

    if(b==1)
       outGA.info.Observation=tierLabel;
       outGA.info.Hierarchy=hierarchy;
       outGA.info.fs=resampleSize;
    end
end

for b=1:length(bioMs) % reshape and get final statistics
        curBioM=bioMs{b};
        outGA.(curBioM).Mean=permute(mean(hAvg.(curBioM).Mean,1,'omitnan'),[2,3,1]);
        outGA.(curBioM).Median=permute(nanmedian(hAvg.(curBioM).Median,1),[2,3,1]);
        outGA.(curBioM).Max=permute(nanmax(hAvg.(curBioM).Max,[],1),[2,3,1]);
        outGA.(curBioM).Min=permute(nanmin(hAvg.(curBioM).Min,[],1),[2,3,1]);
        outGA.(curBioM).N=permute(sum(~isnan(hAvg.(curBioM).Mean),1),[2,3,1]);
        outGA.(curBioM).SD=permute(std(hAvg.(curBioM).Mean,0,1,'omitnan'),[2,3,1]);
        outGA.(curBioM).SEM=outGA.(curBioM).SD./sqrt(outGA.(curBioM).N);
        
        if(calcROI)
            outGA.ROI.(curBioM).Mean=permute(mean(hAvg.ROI.(curBioM).Mean,1,'omitnan'),[2,3,1]);
            outGA.ROI.(curBioM).Median=permute(nanmedian(hAvg.ROI.(curBioM).Median,1),[2,3,1]);
            outGA.ROI.(curBioM).Max=permute(nanmax(hAvg.ROI.(curBioM).Max,[],1),[2,3,1]);
            outGA.ROI.(curBioM).Min=permute(nanmin(hAvg.ROI.(curBioM).Min,[],1),[2,3,1]);
            outGA.ROI.(curBioM).N=permute(sum(~isnan(hAvg.ROI.(curBioM).Mean),1),[2,3,1]);
            outGA.ROI.(curBioM).SD=permute(std(hAvg.ROI.(curBioM).Mean,0,1,'omitnan'),[2,3,1]);
            outGA.ROI.(curBioM).SEM=outGA.ROI.(curBioM).SD./sqrt(outGA.ROI.(curBioM).N);

            if(any(removedIdx))
                temp=outGA.ROI.(curBioM).data;
                outGA.ROI.(curBioM).data=nan([size(temp,1),size(temp,2),size(removedIdx,1)]);
                outGA.ROI.(curBioM).data(:,:,~removedIdx)=temp;
            end
        end

        if(any(removedIdx))
            temp=outGA.(curBioM).data;
            outGA.(curBioM).data=nan([size(temp,1),size(temp,2),size(removedIdx,1)]);
            outGA.(curBioM).data(:,:,~removedIdx)=temp;
        end
end


if(averageAux)
    for aux=1:numAuxFields
        if(showProgress)
            fprintf('grandAvgFNIRS\nAveraging Auxillary Data %i of %i',aux,numAuxFields);
        end

            curAuxField=char(auxFields(aux));
            inData=permute(outGA.Aux.(curAuxField).data,[3,1,2]);
            [res,hAvg.Aux.(curAuxField).tierLabel,hAvg.Aux.(curAuxField).Hierarchy]=pf2_base.hierarchicalAverageMulti(inData,hierarchyVars,hAvgFuncs);
            hAvg.Aux.(curAuxField).Mean=res{1};
            hAvg.Aux.(curAuxField).Median=res{2};
            hAvg.Aux.(curAuxField).Max=res{3};
            hAvg.Aux.(curAuxField).Min=res{4};
    end
    
    for aux=1:numAuxFields
        curAuxField=char(auxFields(aux));
        outGA.Aux.(curAuxField).Hierarchy=hAvg.Aux.(curAuxField).Hierarchy;
        outGA.Aux.(curAuxField).Mean=permute(mean(hAvg.Aux.(curAuxField).Mean,1,'omitnan'),[2,3,1]);
        outGA.Aux.(curAuxField).Median=permute(nanmedian(hAvg.Aux.(curAuxField).Median,1),[2,3,1]);
        outGA.Aux.(curAuxField).Max=permute(nanmax(hAvg.Aux.(curAuxField).Max,[],1),[2,3,1]);
        outGA.Aux.(curAuxField).Min=permute(nanmin(hAvg.Aux.(curAuxField).Min,[],1),[2,3,1]);
        outGA.Aux.(curAuxField).N=permute(sum(~isnan(hAvg.Aux.(curAuxField).Mean),1),[2,3,1]);
        outGA.Aux.(curAuxField).SD=permute(std(hAvg.Aux.(curAuxField).Mean,0,1,'omitnan'),[2,3,1]);
        outGA.Aux.(curAuxField).SEM=outGA.Aux.(curAuxField).SD./sqrt(outGA.Aux.(curAuxField).N);

        if(any(removedIdx))
            temp=outGA.Aux.(curAuxField).data;
            outGA.Aux.(curAuxField).data=nan([size(temp,1),size(temp,2),size(removedIdx,1)]);
            outGA.Aux.(curAuxField).data(:,:,~removedIdx)=temp;
        end
    end

end




if(showProgress)
    if(isvalid(hF))
       close(hF); 
    end
end








