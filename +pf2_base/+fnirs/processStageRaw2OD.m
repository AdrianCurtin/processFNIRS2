
function [outDataOD,outDataRaw]=processStageRaw2OD(method,data,fs,time,rawMask,fMarkers,fAux,channelNumbers,wavelengths)
 % Raw data processing

global PF2

outData=data;
OD_converted=false;

if(isstring(method)||ischar(method))
    % load method from string
elseif(isempty(method)) % use loaded method
    if(~isfield(PF2,'stageRawMethod'))
        disp('No current Filters enabled');
        %outData(:,validChannels)=medfilt1(data(:,validChannels),10);
    else
        method=PF2.stageRawMethod;
    end

end
    
    



validChannels=(wavelengths>0)&rawMask;  %Dark Channel should be 0, time should be NA, other information should be negative values

timeChMask=ones(size(data));

for i=1:length(method.F)
    Fidx=method.F{i};
    if(isfield(Fidx,'f'))
        func=str2func(Fidx(1).f);
        if(contains(Fidx(1).f,'Intensity2OD'))
            outDataRaw=outData;
            OD_converted=true;
        end
        x_ind=[];
        fs_ind=[];
        time_ind=[];
        fmask_ind=[];
        fchInfo_ind=[];
        fmrk_ind=[];
        fAux_ind=[];
        fsd_ind=[];
        ftimeMask_ind=[];

        if(length(Fidx)>1) %This is a struct array for some reason?
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
            if(~iscell(args))
                args={args};
            end
            if(~iscell(passedArgVals))
                passedArgVals={passedArgVals};
            end
        end

        if(isfield(Fidx,'output'))
           x_out_ind=[];
           fmask_out_ind=[];
           ftimeMask_out_ind=[];

           outputList=Fidx.output;

           if(iscell(outputList{1}))
              outputList=outputList{1}; 
           end
           for output_idx=1:length(outputList)
               if strcmpi(outputList{output_idx},'x')==1 && isempty(x_out_ind)
                    x_out_ind=output_idx;
               elseif strcmpi(outputList{output_idx},'fchMask')==1 && isempty(fmask_out_ind)
                   fmask_out_ind=output_idx;
               elseif strcmpi(outputList{output_idx},'ftimeChMask')==1 && isempty(ftimeMask_out_ind)
                   ftimeMask_out_ind=output_idx;
               end
           end
        else %legacy code missing output
            x_out_ind=1;
            fmask_out_ind=[];
            ftimeMask_out_ind=[];
        end

        for a=1:length(args)
           if strcmp(args{a},'x')==1
              x_ind=a;
              passedArgVals{x_ind}=data(:,validChannels);
           elseif strcmp(args{a},'fs')==1
              fs_ind=a; 
              passedArgVals{fs_ind}=fs;
           elseif strcmp(args{a},'fTime')==1
              time_ind=a; 
              passedArgVals{time_ind}=time;
           elseif strcmp(args{a},'fchMask')==1
              fmask_ind=a;
              passedArgVals{fmask_ind}=rawMask(:,validChannels);
           elseif strcmp(args{a},'ftimeChMask')==1
              ftimeMask_ind=a;
              passedArgVals{ftimeMask_ind}=timeChMask(:,validChannels); % always needs channel info when used in raw
           elseif strcmp(args{a},'fChannelNumbers')==1
              fchInfo_ind=a;
              passedArgVals{fchInfo_ind}=channelNumbers;
           elseif strcmp(args{a},'fChannelSD')==1
              fsd_ind=a;
              passedArgVals{fsd_ind}=PF2.curSDSet(ismember(PF2.curChList,PF2.curChSet(validChannels)));
           elseif strcmp(args{a},'fMarkers')==1
              fmrk_ind=a; 
              passedArgVals{fmrk_ind}=fMarkers;
           elseif strcmp(args{a},'fAux')==1
              fAux_ind=a;
              passedArgVals{fAux_ind}=fAux;
           end
        end

        if(~isempty(x_ind))
            outData=data;

            funcOutput{:}=func(passedArgVals{:});
            if(~isempty(x_out_ind)) % Assign values to fNIRS Biomarkers and ROIs when available
                    outData(:,validChannels)=funcOutput{x_out_ind};
            end

            if(~isempty(fmask_out_ind)) % Or with current fmask
                if(size(funcOutput{fmask_out_ind},2)<size(rawMask,2))
                    rawMask(:,validChannels)=rawMask(:,validChannels)&funcOutput{fmask_out_ind};
                else
                    rawMask=rawMask&funcOutput{fmask_out_ind};
                end

                validChannels=validChannels&rawMask;
                %outData(:,~rawMask)=nan;

            end

            if(~isempty(ftimeMask_out_ind)) % Or with current fmask
                if(size(funcOutput{ftimeMask_out_ind},2)<size(rawMask,2))
                    timeChMask(:,validChannels)=timeChMask(:,validChannels)&funcOutput{ftimeMask_out_ind};
                else
                    timeChMask=timeChMask&funcOutput{ftimeMask_out_ind};
                end

            end

            %end
            data=outData;
        else
            outData=data;
            warning('Unable to identify NIRS input argument\n');
        end
    end
end

outData(~timeChMask)=nan;

if(OD_converted==false)
    outDataRaw=outData;
    outDataOD=outData;
    validChannels=((wavelengths>=0)&rawMask); %convert all and Dark channels
    outDataOD(:,validChannels)=pf2_Intensity2OD(outData(:,validChannels));
    
else
    validDarkChannels=((wavelengths==0)&rawMask); %convert just dark channels
    outDataOD=outData; 
    outDataOD(:,validDarkChannels)=pf2_Intensity2OD(outData(:,validDarkChannels));
end

outDataRaw(:,((wavelengths>=0)&~rawMask))=nan;
outDataOD(:,((wavelengths>=0)&~rawMask))=nan;


end
