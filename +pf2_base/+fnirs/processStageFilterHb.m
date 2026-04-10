function outData=processStageFilterHb(method,data,fs,probeInfo,ProcessRejected,showGUIerrors)
% PROCESSSTAGEFILTERHB Stage 3 processing: Filter hemoglobin concentrations
%
% Executes the third stage of the fNIRS processing pipeline, applying a
% configurable chain of post-Beer-Lambert processing methods to hemoglobin
% concentration data. Methods can include filtering, baseline correction,
% artifact rejection (Takizawa), common average reference (CAR), and ROI
% averaging.
%
% This function operates on all hemoglobin biomarkers simultaneously:
% HbO, HbR, HbTotal, HbDiff, and CBSI, ensuring consistent processing
% across all derived signals.
%
% Reference:
%   Internal pf2 implementation. Processing methods are documented in
%   their respective function files (e.g., pf2_TakizawaRejection, pf2_CAR).
%
%   Takizawa Rejection:
%     Takizawa, R. et al. (2014). Neuroimaging-aided differential diagnosis.
%     NeuroImage, 85, 498-507. DOI: 10.1016/j.neuroimage.2013.05.126
%
% Syntax:
%   outData = processStageFilterHb(method, data, fs, probeInfo)
%   outData = processStageFilterHb(method, data, fs, probeInfo, ProcessRejected)
%   outData = processStageFilterHb(method, data, fs, probeInfo, ProcessRejected, showGUIerrors)
%
% Inputs:
%   method          - Method configuration struct with fields:
%                     .name - Method display name (string)
%                     .F    - Cell array of function specifications
%                     Each F{i} contains: .f (function name), .args,
%                     .argvals, .output
%                     If missing .F field, returns data unchanged.
%   data            - fNIRS data struct after Beer-Lambert conversion:
%                     Required fields:
%                       .HbO [T x C]      - Oxygenated hemoglobin
%                       .HbR [T x C]      - Deoxygenated hemoglobin
%                       .HbTotal [T x C]  - Total hemoglobin
%                       .HbDiff [T x C]   - Differential hemoglobin
%                       .CBSI [T x C]     - Correlation-based signal improvement
%                       .channels [1 x C] - Channel identifiers
%                       .fchMask [1 x C]  - Channel validity mask
%                       .time [T x 1]     - Time vector
%                       .markers [M x 4]  - Event markers (time, code, duration, amplitude)
%                     Optional fields:
%                       .Aux              - Auxiliary data struct
%                       .ROI              - Pre-computed ROI data
%                       .ftimeChMask [T x C] - Time-varying channel mask
%   fs              - Sampling frequency in Hz
%   probeInfo       - Probe geometry struct from loadDeviceCfg()
%   ProcessRejected - Override mask to include rejected channels (logical)
%                     (default: false). Set true to process all channels
%                     regardless of fchMask, useful for visualization.
%   showGUIerrors   - Display error dialogs in GUI mode (default: false)
%
% Outputs:
%   outData         - Processed fNIRS data struct with fields:
%                     .HbO, .HbR, .HbTotal, .HbDiff, .CBSI - Filtered biomarkers
%                     .fchMask    - Updated if methods reject channels
%                     .ftimeChMask - Updated for time-varying rejection
%                     .ROI        - Updated if ROI methods applied
%                     All other input fields are preserved.
%
% Biomarker Fields Processed:
%   HbO     - Oxygenated hemoglobin concentration
%   HbR     - Deoxygenated hemoglobin concentration
%   HbTotal - Total hemoglobin (HbO + HbR)
%   HbDiff  - Differential hemoglobin (HbO - HbR)
%   CBSI    - Cerebral blood saturation index
%
% Method Chain Execution:
%   For each function in method.F:
%     1. Parse declared arguments and match to available data
%     2. Special argument names are auto-filled:
%        'x'              -> biomarker matrix (iterates over all)
%        'fs'             -> sampling frequency
%        'fTime'          -> time vector
%        'fchMask'        -> channel mask
%        'ftimeChMask'    -> time-channel mask
%        'fChannelNumbers'-> channel IDs
%        'fChannelSD'     -> source-detector distances
%        'fProbeInfo'     -> probe geometry struct
%        'fMarkers'       -> event markers
%        'fAux'           -> auxiliary data
%        'fNIRstruct'     -> full fNIRS struct
%     3. Execute function on each biomarker field
%     4. Update masks based on declared outputs
%     5. Process ROI data if ROI output declared
%
% Algorithm:
%   1. Initialize valid channel mask from data.fchMask
%   2. For each function in method chain:
%      a. Build argument list from available data
%      b. For each biomarker (HbO, HbR, HbTotal, HbDiff, CBSI):
%         - Execute function on valid channels
%         - Update biomarker data and masks
%      c. Apply same processing to ROI data if present
%   3. Set invalid channels/time points to NaN
%   4. Build default ROIs if ROI.info defined but ROI data missing
%
% Global Variables Used:
%   PF2 - Contains processing configuration
%
% Example:
%   % Apply Takizawa rejection and low-pass filter
%   method = pf2.methods.oxy.GetMethod('takizawa_easy_lpf');
%   filtered = pf2_base.fnirs.processStageFilterHb(method, hbData, 10, ...
%       probe, false, false);
%
%   % Process including rejected channels for visualization
%   filtered = pf2_base.fnirs.processStageFilterHb(method, hbData, 10, ...
%       probe, true, false);
%
% Notes:
%   - Invalid channels are set to NaN in output
%   - ROI data is processed with same methods if present
%   - If ROI.info exists but ROI.HbO is empty, builds ROIs via nanmean
%
% See also: processStageRaw2OD, bvoxy, processFNIRS2, pf2_TakizawaRejection,
%           pf2_CAR, pf2_build_nanmean_ROI, pf2_lpf

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


% Defensive initialization — may be overwritten below if ROI data exists
validChannels_roi = [];
curftimeMask_roi = [];
funcOutput_roi = {};

if isfield(data,'ROI') && isstruct(data.ROI) && isfield(data.ROI,'HbO') && ~isempty(data.ROI.HbO)
    validChannels_roi=true(1,size(data.ROI.('HbO'),2));
    curftimeMask_roi=true(size(data.ROI.('HbO')));
end

% Fallback to global method if none provided
if isempty(method)
    global PF2
    if ~isfield(PF2, 'stageOxyMethod')
        disp('No oxy method configured');
        outData = data;
        return;
    else
        method = PF2.stageOxyMethod;
    end
end

if(~isfield(method,'F'))
    disp('No stage2 processing method specified');
    outData=data;
    %outData.HbO(:,validChannels)=medfilt1(outData.HbO(:,validChannels),25);
    %outData.HbR(:,validChannels)=medfilt1(outData.HbR(:,validChannels),25);
else
    outData=data;
    hasROI = isfield(data,'ROI') && isstruct(data.ROI) && isfield(data.ROI,'HbO');

    for i=1:length(method.F)
        pf=method.F{i};

        % Silent fallback: convert legacy structs if they slip through
        if ~isa(pf, 'pf2_base.PipelineFunction')
            if isstruct(pf) && isfield(pf, 'f')
                pf = pf2_base.PipelineFunction.fromStruct(pf);
            else
                continue
            end
        end

        hasXArg = pf.hasSpecialArg('x');
        hasStructArg = pf.hasSpecialArg('fNIRstruct');
        runOnce = hasStructArg || (pf.structOutIdx > 0);

        if hasXArg || hasStructArg
            outData=data;

            % Build context (non-x fields, shared across biomarkers)
            ctx.fs = fs;
            ctx.fTime = data.time;
            ctx.fchMask = curfMask;
            ctx.ftimeChMask = curftimeMask(:,validChannels);
            ctx.fChannelNumbers = data.channels(validChannels);
            if isfield(probeInfo,'SD')
                ctx.fChannelSD = probeInfo.SD(validChannels);
            else
                ctx.fChannelSD = [];
            end
            ctx.fProbeInfo = probeInfo;
            ctx.fMarkers = data.markers;
            if isfield(data,'Aux')
                ctx.fAux = data.Aux;
            else
                ctx.fAux = [];
            end
            ctx.fNIRstruct = data;
            ctx.fAmbient = [];
            ctx.x = [];

            for bioM=1:length(bioM_list)

                if hasXArg
                    ctx.x = data.(bioM_list{bioM})(:,validChannels);
                end
                if hasStructArg
                    ctx.fNIRstruct = data;
                end

                if showGUIerrors
                    try
                        funcOutput = pf.execute(ctx);
                    catch ME
                        outData.(bioM_list{bioM})(:,validChannels) = nan;
                        warning('Error in method %s processing %s: %s', method.name, pf.funcName, ME.message);
                        waitfor(errordlg(sprintf('Error in method %s processing %s\n%s', method.name, pf.funcName, ME.message), 'Hb Processing Error'));
                        continue
                    end
                else
                    funcOutput = pf.execute(ctx);
                end

                % ROI processing
                funcOutput_roi = {};
                if pf.xOutIdx > 0 && hasXArg && hasROI && ~isempty(validChannels_roi)
                    ctx_roi = ctx;
                    ctx_roi.x = data.ROI.(bioM_list{bioM})(:,validChannels_roi);
                    if showGUIerrors
                        try
                            funcOutput_roi = pf.execute(ctx_roi);
                        catch ME
                            warning('Error in ROI processing %s for %s: %s', pf.funcName, bioM_list{bioM}, ME.message);
                        end
                    else
                        funcOutput_roi = pf.execute(ctx_roi);
                    end
                end

                if pf.xOutIdx > 0
                    outData.(bioM_list{bioM})(:,validChannels)=funcOutput{pf.xOutIdx};
                    if hasROI && hasXArg && ~isempty(funcOutput_roi) && ~isempty(validChannels_roi)
                        outData.ROI.(bioM_list{bioM})(:,validChannels_roi)=funcOutput_roi{pf.xOutIdx};
                    end
                end

                if pf.maskOutIdx > 0
                    if(size(funcOutput{pf.maskOutIdx},2)<size(curfMask,2))
                        curfMask(:,validChannels)=curfMask(:,validChannels)&funcOutput{pf.maskOutIdx};
                    else
                        curfMask=curfMask&funcOutput{pf.maskOutIdx};
                    end
                    validChannels=validChannels&curfMask(:);
                    outData.(bioM_list{bioM})(:,~validChannels)=nan;
                    if hasROI && hasXArg && ~isempty(funcOutput_roi) && ~isempty(validChannels_roi)
                        if(size(funcOutput_roi{pf.maskOutIdx},2)<size(validChannels_roi,2))
                            validChannels_roi(:,validChannels)=validChannels_roi(:,validChannels)&funcOutput{pf.maskOutIdx};
                        else
                            validChannels_roi=validChannels_roi&funcOutput_roi{pf.maskOutIdx};
                        end
                        outData.ROI.(bioM_list{bioM})(:,~validChannels_roi)=nan;
                    end
                end

                if pf.timeMaskOutIdx > 0
                    if(size(funcOutput{pf.timeMaskOutIdx},2)<size(validChannels,2))
                        curftimeMask(:,validChannels)=curftimeMask(:,validChannels)&funcOutput{pf.timeMaskOutIdx};
                    else
                        curftimeMask=curftimeMask&funcOutput{pf.timeMaskOutIdx};
                    end
                    if hasROI && ~isempty(funcOutput_roi) && ~isempty(validChannels_roi)
                        if(size(funcOutput_roi{pf.timeMaskOutIdx},2)<size(validChannels_roi,2))
                            curftimeMask_roi(:,validChannels_roi)=curftimeMask_roi(:,validChannels_roi)&funcOutput_roi{pf.timeMaskOutIdx};
                        else
                            curftimeMask_roi=curftimeMask_roi&funcOutput_roi{pf.timeMaskOutIdx};
                        end
                    end
                end

                if pf.roiOutIdx > 0
                    outData=funcOutput{pf.roiOutIdx};
                    if(isfield(outData,'ROI')&&~isempty(outData.ROI))
                        validChannels_roi=true(1,size(outData.ROI.(bioM_list{bioM}),2));
                        curftimeMask_roi=true(size(outData.ROI.(bioM_list{bioM})));
                        hasROI = true;
                    end
                end

                if pf.structOutIdx > 0
                    outData=funcOutput{pf.structOutIdx};
                end

                if runOnce
                    break;
                end
            end

            data=outData;
            hasROI = isfield(data,'ROI') && isstruct(data.ROI) && isfield(data.ROI,'HbO');
        else
            warning('Unable to identify NIRS input argument\n');
        end
    end
end

if isfield(outData,'ROI') && isstruct(outData.ROI) && isfield(outData.ROI,'info') && ~isempty(outData.ROI.info) && ~isfield(outData.ROI,'HbO')
    warning('pf2:processStageFilterHb:noROIBuildStep', ...
        'No ROI build step was specified. Defaulting to nanmean of valid channels.');
    outData=pf2_build_nanmean_ROI(outData);
    if(~isempty(outData.ROI)&&isfield(outData.ROI,'HbO'))
        validChannels_roi=true(1,size(outData.ROI.('HbO'),2));
        curftimeMask_roi=true(size(outData.ROI.('HbO')));
    else
        clear outData.ROI; 
    end
end


% Check ROI state once for the final NaN-setting loop
hasROI_final = isfield(outData,'ROI') && isstruct(outData.ROI) && isfield(outData.ROI,'HbO');

invalidChannels=false(size(data.channels));

%error in this line
invalidChannels(data.channels>0)=data.channels(data.channels>0)&(reshape(~curfMask,[numOptodes,1]));

%invalidChannels(data.channels>0)=data.channels(data.channels>0)&(reshape(~curfMask,[1,numOptodes]));

for bioM=1:length(bioM_list) % go through each biomarker and set invalid cahnnels to nan
    outData.(bioM_list{bioM})(:,invalidChannels)=nan;
    
    outData.(bioM_list{bioM})(~curftimeMask)=nan;
    
    if hasROI_final && ~isempty(validChannels_roi)
        outData.ROI.(bioM_list{bioM})(:,~validChannels_roi)=nan;
        if ~isempty(curftimeMask_roi)
            outData.ROI.(bioM_list{bioM})(~curftimeMask_roi)=nan;
        end
    end
end

end
