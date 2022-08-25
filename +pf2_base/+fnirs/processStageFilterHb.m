function outData=processStageFilterHb(method,data,fs,probeInfo,ProcessRejected,showGUIerrors)
% Oxy data processing

if(nargin<6)
    showGUIerrors=false;
end

bioM_list={'HbO','HbR','HbTotal','HbDiff','CBSI'};
validChannels=false(size(data.channels));
numOptodes=length(data.channels(data.channels>0));
validChannels(data.channels>0)=data.channels(data.channels>0)&(reshape(data.fchMask(:)|ProcessRejected,[numOptodes,1]));% error in this line
%validChannels(data.channels>0)=data.channels(data.channels>0)&(reshape(data.fchMask(:)|ProcessRejected,[1,numOptodes,1]));


curfMask=data.fchMask|ProcessRejected;

if(isfield(data,'ftimeChMask'))
    curftimeMask=data.ftimeChMask|ProcessRejected;
else
    curftimeMask=ones(size(data.HbO));
end


if(pf2_base.isnestedfield(data,'ROI.info')&&~isempty(data.ROI.info)&&isfield(data.ROI,'HbO')&&~isempty(data.ROI.HbO))
    if(~isempty(data.ROI)&&isfield(data.ROI,'HbO'))
        validChannels_roi=true(1,size(data.ROI.('HbO'),2));
        curftimeMask_roi=true(size(data.ROI.('HbO')));
    end
end

if(pf2_base.isnestedfield(data,'ROI.HbO')&&~isempty(data.ROI))
    validChannels_roi=true(1,size(data.ROI.('HbO'),2));
end

global PF2
if(~isfield(method,'F'))
    disp('No stage2 processing method left');
    outData=data;
    %outData.HbO(:,validChannels)=medfilt1(outData.HbO(:,validChannels),25);
    %outData.HbR(:,validChannels)=medfilt1(outData.HbR(:,validChannels),25);
else
    outData=data;
    for i=1:length(method.F)
        Fidx=method.F{i};
        if(isfield(Fidx,'f'))
            func=str2func(Fidx(1).f);
            x_ind=[];
            fs_ind=[];
            time_ind=[];
            fmask_ind=[];
            fchInfo_ind=[];
            fmrk_ind=[];
            fAux_ind=[];
            fsd_ind=[];
            fStruct_ind=[];
            ftimeMask_ind=[];
            
            
            if(length(Fidx)>1||~iscell(Fidx.args)) %This is a struct array for some reason?
               %Change it back!
               args=cell(0,0);
               passedArgVals=cell(0,0);
               for j=1:length(Fidx)
                    args{j}=Fidx(j).args;
                    passedArgVals{j}=Fidx(j).argvals;
               end
            else
                args=Fidx.args;
                passedArgVals=Fidx.argvals;
            end
            
            if(isfield(Fidx,'output'))
               x_out_ind=[];
               roi_out_ind=[];
               fmask_out_ind=[];
               ftimeMask_out_ind=[];
               fstruct_out_ind=[];
               
               outputList=Fidx.output;
               
               if(iscell(outputList)&&iscell(outputList{1}))
                  outputList=outputList{1}; 
               elseif(~iscell(outputList))
                  outputList={outputList};   
               end
               for output_idx=1:length(outputList)
                   if strcmpi(outputList{output_idx},'x')==1 && isempty(x_out_ind)
                        x_out_ind=output_idx;
                   elseif strcmpi(outputList{output_idx},'fchMask')==1 && isempty(fmask_out_ind)
                       fmask_out_ind=output_idx;
                   elseif strcmpi(outputList{output_idx},'ftimeChMask')==1 && isempty(ftimeMask_out_ind)
                       ftimeMask_out_ind=output_idx;
                   elseif strcmpi(outputList{output_idx},'fNIRstruct')==1 && isempty(fstruct_out_ind)
                       fstruct_out_ind=output_idx;
                   elseif strcmpi(outputList{output_idx},'ROI')==1 && isempty(roi_out_ind)
                       roi_out_ind=output_idx;
                   end
               end
            else %legacy code missing output
                x_out_ind=1;
                roi_out_ind=[];
                fmask_out_ind=[];
                ftimeMask_out_ind=[];
                fstruct_out_ind=[];
            end
            
            
            for a=1:length(args)
               if strcmp(args{a},'x')==1
                  x_ind=a;
               elseif strcmp(args{a},'fs')==1
                  fs_ind=a; 
                  passedArgVals{fs_ind}=fs;
               elseif strcmp(args{a},'fTime')==1
                  time_ind=a; 
                  passedArgVals{time_ind}=data.time;
               elseif strcmp(args{a},'fchMask')==1
                  fmask_ind=a;
                  passedArgVals{fmask_ind}=curfMask;
               elseif strcmp(args{a},'fChannelNumbers')==1
                  fchInfo_ind=a;
                  passedArgVals{fchInfo_ind}=data.channels(validChannels);
               elseif strcmp(args{a},'fMarkers')==1
                  fmrk_ind=a; 
                  passedArgVals{fmrk_ind}=data.markers;
               elseif strcmp(args{a},'fAux')==1
                  fAux_ind=a;
                  passedArgVals{fAux_ind}=data.Aux;
               elseif strcmp(args{a},'fChannelSD')==1
                  fsd_ind=a;
                  passedArgVals{fsd_ind}=probeInfo.SD(validChannels);
               elseif strcmp(args{a},'fProbeInfo')==1
                  fprobe_ind=a;
                  passedArgVals{fprobe_ind}=probeInfo;
               elseif strcmp(args{a},'ftimeChMask')==1
                  ftimeMask_ind=a;
                  passedArgVals{ftimeMask_ind}=curftimeMask(:,validChannels); % always needs channel info when used in raw
               elseif strcmp(args{a},'fNIRstruct')==1  % Try not to use, can be inefficient
                   fStruct_ind=a;
                   passedArgVals{fStruct_ind}=data;
               end
               
            end
            
            
            if(~isempty(x_ind)||~isempty(fStruct_ind))
                outData=data;
                %TODO move channel mask that doesn't process data outside
                %of loop 
                if(~isempty(fStruct_ind)||~isempty(fstruct_out_ind))
                    runOnce=true;
                else
                    runOnce=false;
                end
                for bioM=1:length(bioM_list) % go through each biomarker and process data
                    
                    if(~isempty(x_ind))
                        passedArgVals{x_ind}=data.(bioM_list{bioM})(:,validChannels);
                        if(pf2_base.isnestedfield(data,'ROI.HbO'))
                            % Note ROI functions may not be able to handle
                            % functions using channel numbers of SD separation
                            passedArgVals_roi=passedArgVals;
                            passedArgVals_roi{x_ind}=data.ROI.(bioM_list{bioM})(:,validChannels_roi);
                        end
                    end
                    
                    if(~isempty(fStruct_ind))
                        passedArgVals{fStruct_ind}=data;
                        if(pf2_base.isnestedfield(data,'ROI.HbO'))
                            % Note ROI functions may not be able to handle
                            % functions using channel numbers of SD separation
                           % passedArgVals_roi=passedArgVals;
                           % passedArgVals_roi{x_ind}=data.ROI.(bioM_list{bioM})(:,validChannels_roi);
                        end
                    end
                    
                    funcOutput{:}=func(passedArgVals{:});
                    
                    if(pf2_base.isnestedfield(data,'ROI.HbO')&&~isempty(x_ind))
                        % Note ROI functions may not be able to handle
                        % functions using channel numbers of SD separation
                        passedArgVals_roi=passedArgVals;
                        passedArgVals_roi{x_ind}=data.ROI.(bioM_list{bioM})(:,validChannels_roi);
                        funcOutput_roi{:}=func(passedArgVals_roi{:}); 
                    end
                    
                    if(~isempty(x_out_ind)) % Assign values to fNIRS Biomarkers and ROIs when available
                        outData.(bioM_list{bioM})(:,validChannels)=funcOutput{x_out_ind};
                        if(pf2_base.isnestedfield(data,'ROI.HbO')&&~isempty(x_ind))
                            outData.ROI.(bioM_list{bioM})(:,validChannels_roi)=funcOutput_roi{x_out_ind};
                        end
                    end
                    
                    if(~isempty(fmask_out_ind)) % Or with current fmask
                        if(size(funcOutput{fmask_out_ind},2)<size(curfMask,2))
                            curfMask(:,validChannels)=curfMask(:,validChannels)&funcOutput{fmask_out_ind};
                        else
                            curfMask=curfMask&funcOutput{fmask_out_ind};
                        end
                        
                        validChannels=validChannels&curfMask(:);
                        outData.(bioM_list{bioM})(:,~validChannels)=nan;
                        if(pf2_base.isnestedfield(data,'ROI.HbO')&&~isempty(x_ind))
                            if(size(funcOutput_roi{fmask_out_ind},2)<size(validChannels_roi,2))
                                validChannels_roi(:,validChannels)=validChannels_roi(:,validChannels)&funcOutput{fmask_out_ind};
                            else
                                validChannels_roi=validChannels_roi&funcOutput_roi{fmask_out_ind};
                            end
                            outData.ROI.(bioM_list{bioM})(:,~validChannels_roi)=nan;
                        end
                    end
                    
                    if(~isempty(ftimeMask_out_ind)) % Or with current ftimemask
                        if(size(funcOutput{ftimeMask_out_ind},2)<size(validChannels,2))
                            curftimeMask(:,validChannels)=curftimeMask(:,validChannels)&funcOutput{ftimeMask_out_ind};
                        else
                            curftimeMask=curftimeMask&funcOutput{ftimeMask_out_ind};
                        end
                        if(pf2_base.isnestedfield(data,'ROI.HbO'))
                            if(size(funcOutput_roi{ftimeMask_out_ind},2)<size(validChannels_roi,2))
                                curftimeMask_roi(:,validChannels_roi)=curftimeMask_roi(:,validChannels_roi)&funcOutput_roi{ftimeMask_out_ind};
                            else
                                curftimeMask_roi=curftimeMask_roi&funcOutput_roi{ftimeMask_out_ind};
                            end
                        end
                    end
                    
                    if(~isempty(roi_out_ind)) % Build ROIs
                        outData=funcOutput{roi_out_ind};
                        if(isfield(outData,'ROI')&&~isempty(outData.ROI'))
                            validChannels_roi=true(1,size(outData.ROI.(bioM_list{bioM}),2));
                            curftimeMask_roi=true(size(outData.ROI.(bioM_list{bioM})));
                        end
                    end
                    
                    if(~isempty(fstruct_out_ind)) % Build ROIs
                        outData=funcOutput{fstruct_out_ind};
                    end
                    
                    if(runOnce)
                        break;
                    end
                end
                
                data=outData;
            else
                %outData=data;
                warning('Unable to identify NIRS input argument\n');
            end
        end
    end
end

if(pf2_base.isnestedfield(outData,'ROI.info')&&~isempty(outData.ROI.info)&&~isfield(outData.ROI,'HbO'))
    fprintf(2,'No ROI build step was specified\nDefaulting to nanmean of valid channels\n');
    outData=pf2_build_nanmean_ROI(outData);
    if(~isempty(outData.ROI)&&isfield(outData.ROI,'HbO'))
        validChannels_roi=true(1,size(outData.ROI.('HbO'),2));
        curftimeMask_roi=true(size(outData.ROI.('HbO')));
    else
        clear outData.ROI; 
    end
end


invalidChannels=false(size(data.channels));

%error in this line
invalidChannels(data.channels>0)=data.channels(data.channels>0)&(reshape(~curfMask,[numOptodes,1]));

%invalidChannels(data.channels>0)=data.channels(data.channels>0)&(reshape(~curfMask,[1,numOptodes]));

for bioM=1:length(bioM_list) % go through each biomarker and set invalid cahnnels to nan
    outData.(bioM_list{bioM})(:,invalidChannels)=nan;
    
    outData.(bioM_list{bioM})(~curftimeMask)=nan;
    
    if(pf2_base.isnestedfield(outData,'ROI.HbO'))
        outData.ROI.(bioM_list{bioM})(:,~validChannels_roi)=nan;
        outData.ROI.(bioM_list{bioM})(~curftimeMask_roi)=nan;
    end
end

end
