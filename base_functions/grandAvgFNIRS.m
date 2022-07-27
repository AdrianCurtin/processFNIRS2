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
for i=length(FNIRScellArray):-1:1 
    if(isempty(FNIRScellArray{i})||(sum(~isnan(FNIRScellArray{i}.time))==0&&...
            pf2_base.isnestedfield(FNIRScellArray{i},'Aux')&&isempty(FNIRScellArray{i}.Aux))) % Empty Case
        FNIRScellArray(i)=[];
        segSampleTimes(i)=[];
        segSampleCount(i)=[];
        hierarchyVars(i,:)=[];
        segROIpresent(i)=[];
        segUnits(i)=[];
        removedIdx(i)=true;
        hasFNIRS(i)=[];
    elseif((sum(~isnan(FNIRScellArray{i}.time))==0&&pf2_base.isnestedfield(FNIRScellArray{i},'Aux'))) % no fnirs but has Aux
        hasFNIRS(i)=false;
        
        segSampleTimes(i)=nan;
        segSampleCount(i)=0;
        %segUnits{i}=FNIRScellArray{i}.units;
        %FNIRScellArray{i}.fs=1/segSampleTimes(i);
        %FNIRScellArray{i}.fs=round(FNIRScellArray{i}.fs,3);
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
        segROIpresent(i)=pf2_base.isnestedfield(FNIRScellArray{i},'ROI.HbO');
        
    elseif(~isfield(FNIRScellArray{i},'time'))  % No Time information
        FNIRScellArray(i)=[];
        hierarchyVars(i,:)=[];
        segSampleTimes(i)=[];
        segSampleCount(i)=[];
        segROIpresent(i)=[];
        segUnits(i)=[];
        hasFNIRS(i)=[];

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
        segROIpresent(i)=pf2_base.isnestedfield(FNIRScellArray{i},'ROI.HbO');
    else   %Nicely aligned
        FNIRScellArray{i}.time=round(FNIRScellArray{i}.time,5);
        segSampleTimes(i)=median(diff(FNIRScellArray{i}.time));
        segSampleCount(i)=length(FNIRScellArray{i}.time);
        segUnits{i}=FNIRScellArray{i}.units;
        FNIRScellArray{i}.fs=1/segSampleTimes(i);
        FNIRScellArray{i}.fs=round(FNIRScellArray{i}.fs,3);
        segROIpresent(i)=pf2_base.isnestedfield(FNIRScellArray{i},'ROI.HbO');
    end
end

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

segmentTimesArr=[];

auxFields(1)="";
auxFieldSizes=[];
auxFieldVarNames={};

for i=1:numfSeg % Resample and find max/min and num channels
    if(resample)
        if(centerOnT0)
            FNIRScellArray{i}=pf2.Data.Resample(FNIRScellArray{i},resampleSize,'centerOnT0',centerOnT0,'timeOutMode','start','averageAux',true,'flattenAux',true,'trimAux',true);
        else
            FNIRScellArray{i}=pf2.Data.Resample(FNIRScellArray{i},resampleSize,'centerOnT0',centerOnT0,'averageAux',true,'flattenAux',true,'trimAux',true);
        end


    end
    
    if(isfield(FNIRScellArray{i},'segmentTimes'))
        segmentTimesArr=[segmentTimesArr;FNIRScellArray{i}.segmentTimes];
    end
    
    if(isfield(FNIRScellArray{i},'Aux')&&~isempty(FNIRScellArray{i}.Aux))
        possibleFields=fields(FNIRScellArray{i}.Aux);
        possibleFieldSizes=nan(size(possibleFields));
        
        temp=false(size(possibleFields));
        for(pf_ind=1:length(possibleFields))
            curField=FNIRScellArray{i}.Aux.(possibleFields{pf_ind});
            possibleFieldSizes(pf_ind)=size(FNIRScellArray{i}.Aux.(possibleFields{pf_ind}),2);
            if(~isempty(curField)&&istable(curField)&&contains('time',curField.Properties.VariableNames))
                temp(pf_ind)=true;
                
            end
        end
        auxFields=[auxFields;possibleFields(temp==1)];
        auxFieldSizes=[auxFieldSizes;possibleFieldSizes(temp==1)];

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
    
    if(hasFNIRS(i)&&calcROI&&pf2_base.isnestedfield(FNIRScellArray{i},'ROI.info')&&size(FNIRScellArray{i}.ROI.info,1)>numROI)
        numROI=size(FNIRScellArray{i}.ROI.info,1);
    end
    
    FNIRScellArray{i}.timeIdx=[FNIRScellArray{i}.time,[1:length(FNIRScellArray{i}.time)]',zeros(size(FNIRScellArray{i}.time))];
end

auxFields(1)=[]; %remove initial value
[auxFields,idx]=unique(auxFields);
auxFieldSizes=auxFieldSizes(idx);
numAuxFields=length(auxFields);

maxTime=rem(maxTime-minTime,resampleSize)+maxTime;

outGA.time=round([minTime:resampleSize:maxTime]',5);

if(~isempty(segmentTimesArr))
    outGA.segmentTimes=unique(segmentTimesArr,'rows');
    outGA.segmentTimes=sort(outGA.segmentTimes,1);
     outGA.segmentTimes=round( outGA.segmentTimes,5);
end

outGA.time=outGA.time(ismember(outGA.time,outGA.segmentTimes(:,1)));
numSegs=length(outGA.time);

if(showProgress)
    hF=waitbar(0,sprintf('grandAvgFNIRS\nAligning segment %i of %i',1,numfSeg));
end

for i=1:numfSeg %find matching times in outGA.time, add to cell time indicies and sort by time
    if(showProgress)
        waitbar(i/numfSeg,hF,sprintf('grandAvgFNIRS\nAligning segment %i of %i',i,numfSeg));
    end
	curT_idx=FNIRScellArray{i}.timeIdx;  % 3xN [Time, TimeIndex,..]
    [~,outIdx]=ismember(curT_idx(:,1),outGA.time);
    outTimeIdx=outGA.time(outIdx==0);
    curT_idx(:,3)=outIdx;
    
    if(~isempty(outTimeIdx))
        outTimeIdx(:,2)=nan;
        outTimeIdx(:,3)=1;
        curT_idx=[curT_idx;outTimeIdx];
        [~,idx]=sort(curT_idx(:,1));
        curT_idx=curT_idx(idx,:);
        
        tDiffMissing=[diff(curT_idx(:,3));0]>0;
        
        if(any(tDiffMissing))
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
            curAuxField=auxFields{aux};
            outGA.Aux.(curAuxField).data=nan(length(outGA.time),auxFieldSizes(aux),numfSeg);
    end
end

initROI=false;

for i=1:numfSeg
    curFNIR=FNIRScellArray{i};

    if(hasFNIRS)
        numfCh=size(curFNIR.HbO,2);
        validTidx=FNIRScellArray{i}.timeIdx(:,4)==1;
        validT=false([numSegs,1]);
        validT(FNIRScellArray{i}.timeIdx(validTidx,3))=true;
        
        for b=1:length(bioMs)
            curBioM=bioMs{b};
            outGA.(curBioM).data(validT==1,1:numfCh,i)=curFNIR.(curBioM)(FNIRScellArray{i}.timeIdx(validTidx,2),:,1);
        end
        
        if(calcROI&&pf2_base.isnestedfield(curFNIR,'ROI.HbO'))
            if(~initROI&&pf2_base.isnestedfield(curFNIR,'ROI.HbO')&&~isempty(curFNIR.ROI.info))
                outGA.ROI.info=curFNIR.ROI.info;
                initROI=true;
            end
            numfCh_roi=size(curFNIR.ROI.HbO,2);
            for b=1:length(bioMs)
                curBioM=bioMs{b};
                outGA.ROI.(curBioM).data(validT==1,1:numfCh_roi,i)=curFNIR.ROI.(curBioM)(FNIRScellArray{i}.timeIdx(validTidx,2),:,1);
            end
        else
            numfCh_roi=0;
        end
    end
    
    if(isfield(curFNIR,'Aux')&&averageAux&&~isempty(curFNIR.Aux))
        curSegAuxFields=fields(curFNIR.Aux);
        
        if(~isempty(curSegAuxFields))

            rndTimesIdx=round(FNIRScellArray{i}.timeIdx,4);

            for aux=1:numAuxFields
                curAuxField=char(auxFields(aux));
                if(ismember(curAuxField,curSegAuxFields))
                        try
                            if(isstring(curFNIR.Aux.(curAuxField))||ischar(curFNIR.Aux.(curAuxField))||isempty(curFNIR.Aux.(curAuxField))...
                                    ||(~istable(curFNIR.Aux.(curAuxField))&&all(size(curFNIR.Aux.(curAuxField))==[1,1])))
                                %outGA.Aux.(curAuxField)=[];
                                continue;
                            end
                            if(pf2_base.isnestedfield(curFNIR.Aux.(curAuxField),'time'))
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
                                outGA.Aux.(curAuxField).data(validT==1,:,i)=nan;
                                continue;
                            end
                            
                            [auxValidT,auxValidIdx]=ismember(outGA.time,auxTimes);
                            auxValidIdx(auxValidIdx==0)=[]; 
                            
                            if(~isempty(auxValidIdx))
                                if(~istable(curFNIR.Aux.(curAuxField)))
                                    outGA.Aux.(curAuxField).data(auxValidT==1,:,i)=curFNIR.Aux.(curAuxField)(auxValidIdx,nonTimeColsIdx);
                                else
                                    outGA.Aux.(curAuxField).data(auxValidT==1,:,i)=curFNIR.Aux.(curAuxField){auxValidIdx,nonTimeColsIdx};
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

for b=1:length(bioMs) % Calculate hierarchical Average for each variable
    if(showProgress)
        waitbar(b/length(bioMs),hF,sprintf('grandAvgFNIRS\nAveraging biomarker %i of %i',b,length(bioMs)));
    end
    curBioM=bioMs{b};
    inData= permute(outGA.(curBioM).data,[3,1,2]);
    [hAvg.(curBioM).Mean,tierLabel,hierarchy]=pf2_base.hierarchicalAverage(inData,hierarchyVars,@nanmean);
    hAvg.(curBioM).Median=pf2_base.hierarchicalAverage(inData,hierarchyVars,@nanmedian);
    hAvg.(curBioM).Max=pf2_base.hierarchicalAverage(inData,hierarchyVars,nanmax3);
    hAvg.(curBioM).Min=pf2_base.hierarchicalAverage(inData,hierarchyVars,nanmin3);
    
    if(calcROI)
        inData= permute(outGA.ROI.(curBioM).data,[3,1,2]);
        [hAvg.ROI.(curBioM).Mean,tierLabel,hierarchy]=pf2_base.hierarchicalAverage(inData,hierarchyVars,@nanmean);
        hAvg.ROI.(curBioM).Median=pf2_base.hierarchicalAverage(inData,hierarchyVars,@nanmedian);
        hAvg.ROI.(curBioM).Max=pf2_base.hierarchicalAverage(inData,hierarchyVars,nanmax3);
        hAvg.ROI.(curBioM).Min=pf2_base.hierarchicalAverage(inData,hierarchyVars,nanmin3);
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
            fprintf('grandAvgFNIRS\nAveraging Auxillary Data %i of %i',b,length(bioMs));
        end
            
            curAuxField=char(auxFields(aux));
          
         
            inData= permute(outGA.Aux.(curAuxField).data,[3,1,2]);
            [hAvg.Aux.(curAuxField).Mean,hAvg.Aux.(curAuxField).tierLabel,hAvg.Aux.(curAuxField).Hierarchy]=pf2_base.hierarchicalAverage(inData,hierarchyVars,@nanmean);
            hAvg.Aux.(curAuxField).Median=pf2_base.hierarchicalAverage(inData,hierarchyVars,@nanmedian);
            hAvg.Aux.(curAuxField).Max=pf2_base.hierarchicalAverage(inData,hierarchyVars,nanmax3);
            hAvg.Aux.(curAuxField).Min=pf2_base.hierarchicalAverage(inData,hierarchyVars,nanmin3);
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








