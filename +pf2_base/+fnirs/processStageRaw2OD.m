function [outDataOD,outDataRaw]=processStageRaw2OD(method,data,fs,time,rawMask,fMarkers,fAux,channelNumbers,wavelengths,probeInfo,fNIR_input,showGUIerrors)
% PROCESSSTAGERAW2OD Stage 1 processing: Raw intensity to Optical Density
%
% Executes the first stage of the fNIRS processing pipeline, applying a
% configurable chain of processing methods to raw light intensity data.
% Methods can include motion artifact correction, filtering, ambient
% subtraction, and conversion to optical density (log transform).
%
% This function is typically called internally by processFNIRS2() but can
% be used directly for custom processing workflows.
%
% Reference:
%   Internal pf2 implementation. Processing methods are documented in
%   their respective function files (e.g., pf2_SMAR, pf2_lpf, pf2_TDDR).
%
% Syntax:
%   [outDataOD, outDataRaw] = processStageRaw2OD(method, data, fs, time, ...
%       rawMask, fMarkers, fAux, channelNumbers, wavelengths, probeInfo, ...
%       fNIR_input, showGUIerrors)
%
% Inputs:
%   method         - Method configuration struct with fields:
%                    .name - Method display name (string)
%                    .F    - Cell array of function specifications
%                    Each F{i} contains: .f (function name), .args (argument
%                    names), .argvals (argument values), .output (output names)
%                    If empty, uses PF2.stageRawMethod from global state.
%   data           - Raw light intensity matrix [T x C_raw]
%                    T = samples, C_raw = all raw channels (including dark)
%   fs             - Sampling frequency in Hz
%   time           - Time vector [T x 1] in seconds
%   rawMask        - Channel validity mask [1 x C_raw]
%                    1 = valid channel, 0 = invalid/masked
%   fMarkers       - Event markers [M x 3] (time, code, duration)
%   fAux           - Auxiliary data struct (physiology, accelerometer, etc.)
%   channelNumbers - Channel identifier mapping [1 x C_raw]
%                    Positive values = optode numbers
%                    Zero = time column
%                    Negative = marker/metadata columns
%   wavelengths    - Wavelength for each column [1 x C_raw]
%                    >0 = light wavelength in nm (e.g., 730, 850)
%                    0  = dark/ambient channel
%                    <0 = metadata column
%   probeInfo      - Probe geometry struct from loadDeviceCfg()
%   fNIR_input     - Complete fNIRS data struct (for functions needing full context)
%   showGUIerrors  - Display error dialogs in GUI mode (default: false)
%
% Outputs:
%   outDataOD      - Processed optical density data [T x C_raw]
%                    After all Stage 1 methods including log transform.
%                    OD = -log10(I / I_baseline)
%   outDataRaw     - Processed raw data before OD conversion [T x C_raw]
%                    Captured just before Intensity2OD is applied.
%                    Useful for QC visualization and debugging.
%
% Method Chain Execution:
%   For each function in method.F:
%     1. Parse declared arguments and match to available data
%     2. Special argument names are auto-filled:
%        'x'              -> data matrix (valid channels only)
%        'fs'             -> sampling frequency
%        'fTime'          -> time vector
%        'fchMask'        -> channel mask (valid channels)
%        'ftimeChMask'    -> time-channel mask [T x C]
%        'fChannelNumbers'-> channel IDs
%        'fChannelSD'     -> source-detector distances
%        'fProbeInfo'     -> probe geometry struct
%        'fMarkers'       -> event markers
%        'fAux'           -> auxiliary data
%        'fAmbient'       -> dark channel data
%        'fNIRstruct'     -> full fNIRS struct
%     3. Execute function and capture outputs
%     4. Update data, masks based on declared outputs ('x', 'fchMask', 'ftimeChMask')
%
% Algorithm:
%   1. Initialize output data and time-channel mask
%   2. Identify valid channels (wavelength > 0 and mask = true)
%   3. For each function in method chain:
%      a. Build argument list from available data
%      b. Execute function on valid channels
%      c. Update data matrix and masks from outputs
%   4. Apply NaN to masked time-channel positions
%   5. Convert to optical density: OD = -log10(I/baseline)
%
% Global Variables Used:
%   PF2 - Contains default method (PF2.stageRawMethod) if none provided
%
% Example:
%   % Use default method from PF2
%   [od, raw] = pf2_base.fnirs.processStageRaw2OD([], rawData, 10, time, ...
%       mask, markers, aux, chNums, wavelengths, probe, fData, false);
%
%   % Use specific method
%   method = pf2.methods.raw.GetMethod('x2_lpf_smar');
%   [od, raw] = pf2_base.fnirs.processStageRaw2OD(method, data, fs, ...
%       time, mask, markers, aux, chNums, wavelengths, probe, fData, false);
%
% See also: processStageFilterHb, bvoxy, processFNIRS2, pf2_initialize,
%           pf2_SMAR, pf2_lpf, pf2_MotionCorrectTDDR, pf2_Intensity2OD
 
 if(nargin<12)
    showGUIerrors=false; 
 end

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
    

wavelengths=wavelengths(:)';
rawMask=rawMask(:)';

validChannels=(wavelengths>0)&rawMask;  %Dark Channel should be 0, time should be NA, other information should be negative values
validDarkChannels=((wavelengths==0)&rawMask);

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
              passedArgVals{fchInfo_ind}=channelNumbers(validChannels);
           elseif strcmp(args{a},'fChannelSD')==1
              fsd_ind=a;
              passedArgVals{fsd_ind}=probeInfo.SD(channelNumbers(validChannels));
           elseif strcmp(args{a},'fProbeInfo')==1
              fsd_ind=a;
              passedArgVals{fsd_ind}=probeInfo;
           elseif strcmp(args{a},'fMarkers')==1
              fmrk_ind=a; 
              passedArgVals{fmrk_ind}=fMarkers;
           elseif strcmp(args{a},'fNIRstruct')==1
              fnir_ind=a; 
              passedArgVals{fnir_ind}=fNIR_input;
           elseif strcmp(args{a},'fAux')==1
              fAux_ind=a;
              passedArgVals{fAux_ind}=fAux;
           elseif strcmp(args{a},'fAmbient')==1
              fAmb_ind=a;
              passedArgVals{fAmb_ind}=data(:,validDarkChannels);
           end
        end

        if(~isempty(x_ind))
            outData=data;

            if(showGUIerrors)
                try
                    funcOutput{:}=func(passedArgVals{:});
                catch ME
                    outData(:,validChannels)=nan;
                    warning('Error occured in method %s when processing %s\n',method.name,Fidx(1).f);
                    waitfor(errordlg(sprintf('Error occured in method %s when processing %s\n%s\n',method.name,Fidx(1).f,ME.message),'Raw Processing Error'));
                end
            else
                funcOutput{:}=func(passedArgVals{:});
            end
            
            
            
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
