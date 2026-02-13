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
%                    .F    - Cell array of PipelineFunction objects
%                    Legacy structs in .F are auto-converted via
%                    PipelineFunction.fromStruct().
%                    If empty, uses PF2.stageRawMethod from global state.
%   data           - Raw light intensity matrix [T x C_raw]
%                    T = samples, C_raw = all raw channels (including dark)
%   fs             - Sampling frequency in Hz
%   time           - Time vector [T x 1] in seconds
%   rawMask        - Channel validity mask [1 x C_raw]
%                    1 = valid channel, 0 = invalid/masked
%   fMarkers       - Event markers [M x 4] (time, code, duration, amplitude)
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
% See also: pf2_base.PipelineFunction, processStageFilterHb, bvoxy,
%           processFNIRS2, pf2_initialize, pf2_SMAR, pf2_lpf,
%           pf2_MotionCorrectTDDR, pf2_Intensity2OD
 
 if(nargin<12)
    showGUIerrors=false; 
 end

outData=data;
outDataRaw=data;
OD_converted=false;

if(isstring(method)||ischar(method))
    % load method from string
elseif(isempty(method)) % use loaded method
    global PF2
    if(~isfield(PF2,'stageRawMethod'))
        disp('No current Filters enabled');
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
    pf=method.F{i};

    % Convert legacy structs inline if they slip through
    if ~isa(pf, 'pf2_base.PipelineFunction')
        if isstruct(pf) && isfield(pf, 'f')
            warning('pf2:legacyStruct', 'Converting legacy struct to PipelineFunction for %s', pf(1).f);
            pf = pf2_base.PipelineFunction.fromStruct(pf);
        else
            continue
        end
    end

    if pf.isIntensity2OD
        outDataRaw=outData;
        OD_converted=true;
    end

    if ~OD_converted && pf.requiresOD
        error('pf2:processStageRaw2OD:notOD', ...
            ['%s requires optical density input but Intensity2OD has not been applied yet. ' ...
             'Move Intensity2OD before %s in the processing pipeline.'], ...
            pf.funcName, pf.funcName);
    end

    % Build context struct
    ctx.x = data(:,validChannels);
    ctx.fs = fs;
    ctx.fTime = time;
    ctx.fchMask = rawMask(:,validChannels);
    ctx.ftimeChMask = timeChMask(:,validChannels);
    ctx.fChannelNumbers = channelNumbers(validChannels);
    if isfield(probeInfo,'SD')
        ctx.fChannelSD = probeInfo.SD(channelNumbers(validChannels));
    else
        ctx.fChannelSD = [];
    end
    ctx.fProbeInfo = probeInfo;
    ctx.fMarkers = fMarkers;
    ctx.fNIRstruct = fNIR_input;
    ctx.fAux = fAux;
    ctx.fAmbient = data(:,validDarkChannels);

    if pf.hasSpecialArg('x')
        outData=data;

        if(showGUIerrors)
            try
                funcOutput = pf.execute(ctx);
            catch ME
                outData(:,validChannels)=nan;
                warning('Error occured in method %s when processing %s\n',method.name,pf.funcName);
                waitfor(errordlg(sprintf('Error occured in method %s when processing %s\n%s\n',method.name,pf.funcName,ME.message),'Raw Processing Error'));
                data=outData;
                continue
            end
        else
            funcOutput = pf.execute(ctx);
        end

        if pf.xOutIdx > 0
            outData(:,validChannels)=funcOutput{pf.xOutIdx};
        end

        if pf.maskOutIdx > 0
            if(size(funcOutput{pf.maskOutIdx},2)<size(rawMask,2))
                rawMask(:,validChannels)=rawMask(:,validChannels)&funcOutput{pf.maskOutIdx};
            else
                rawMask=rawMask&funcOutput{pf.maskOutIdx};
            end
            validChannels=validChannels&rawMask;
        end

        if pf.timeMaskOutIdx > 0
            if(size(funcOutput{pf.timeMaskOutIdx},2)<size(rawMask,2))
                timeChMask(:,validChannels)=timeChMask(:,validChannels)&funcOutput{pf.timeMaskOutIdx};
            else
                timeChMask=timeChMask&funcOutput{pf.timeMaskOutIdx};
            end
        end

        data=outData;
    else
        outData=data;
        warning('Unable to identify NIRS input argument\n');
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
