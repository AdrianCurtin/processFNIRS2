function processMethods(rawMethodStr,oxyMethodStr)
% PROCESSMETHODS Process all loaded fNIRS data with specified method pair
%
% Runs a raw+oxy method combination on all segments in the exploreFNIRS
% dataset. Results are cached so re-selecting a previously processed
% method pair returns instantly. On first load, ROI fields are
% standardized across devices.
%
% Syntax:
%   exploreFNIRS.processMethods(rawMethodStr, oxyMethodStr)
%
% Inputs:
%   rawMethodStr - Name of the raw processing method, or empty [] to skip
%                  raw processing and apply oxy-only
%   oxyMethodStr - Name of the oxy processing method
%
% Example:
%   exploreFNIRS.processMethods('x5_TDDR', 'takizawa_easy');
%   exploreFNIRS.processMethods([], 'None');  % oxy-only reprocessing
%
% See also: processFNIRS2, pf2.methods.raw.list, pf2.methods.oxy.list,
%           exploreFNIRS.dataset.standardizeROIs
global ExFNIRS
%global ProgressHandles

if(isempty(rawMethodStr))
   processOxyOnly=true; 
else
   processOxyOnly=false; 
end

strsOxy=pf2.methods.oxy();
strsRaw=pf2.methods.raw();

if(~isfield(ExFNIRS,'processedData')||(size(ExFNIRS.processedData,1)~=length(strsOxy)*length(strsRaw))) 
    ExFNIRS.processedData=cell(length(strsOxy)*length(strsRaw),3);
    ExFNIRS.numProcessed=0;
end


if(~processOxyOnly&&iscell(rawMethodStr))
   rawMethodStr=rawMethodStr{1}; 
elseif(processOxyOnly)
    rawMethodStr='None';
end


if(iscell(oxyMethodStr))
   oxyMethodStr=oxyMethodStr{1}; 
end

ProcRawMethods=ExFNIRS.processedData(:,1);
ProcOxyMethods=ExFNIRS.processedData(:,2);

curRawMatchIdx=strcmp(rawMethodStr,ProcRawMethods);
curOxyMatchIdx=strcmp(oxyMethodStr,ProcOxyMethods);

if(~any(curRawMatchIdx&curOxyMatchIdx))
    ExFNIRS.processedData{ExFNIRS.numProcessed+1,1}=rawMethodStr;
    ExFNIRS.processedData{ExFNIRS.numProcessed+1,2}=oxyMethodStr;
    data=ExFNIRS.data;

    numData=length(data);
    if(~isfield(ExFNIRS,'currentROI')) % standardize all ROIs on first load
        fprintf('Scanning ROI fields...\n');
    
        [uROI,uROInames,ExFNIRS.data]=exploreFNIRS.dataset.standardizeROIs(ExFNIRS.data);

        ExFNIRS.currentROInames=uROInames;
        ExFNIRS.currentROI=uROI;
    end
    
    pf2('blLength',0);
    pf2('Raw_Method',rawMethodStr,'Oxy_Method',oxyMethodStr); 
    
    rawMethodStr_label=rawMethodStr;
    oxyMethodStr_label=oxyMethodStr;
    rawMethodStr_label(rawMethodStr_label=='_')='-';
    oxyMethodStr_label(oxyMethodStr_label=='_')='-';
    %fprintf('ExploreFNIRS\nProcessing Method %s x %s %i of %i\n',rawMethodStr_label,oxyMethodStr_label,1,numData);
    %hF=ProgressHandles.h.hF;
    
    % Filter out empty/invalid segments
    validIdx = find(cellfun(@(d) ~isempty(d) && length(d.time) > 1, data));

    if processOxyOnly
        % Oxy-only: must loop (processOxy doesn't support cell arrays)
        for k = 1:numel(validIdx)
            i = validIdx(k);
            fprintf('ExploreFNIRS - Processing Method %s x %s %i of %i\n', rawMethodStr_label, oxyMethodStr_label, i, numData);
            if isfield(data{i}, 'HbO')
                data{i} = pf2.process.processOxy(data{i});
            else
                warning('Data file for item %i has no Oxy Data, attempting full processing', i);
                data{i} = pf2(data{i});
            end
        end
    else
        % Full processing: use batch mode (processFNIRS2 handles parfor internally)
        fprintf('ExploreFNIRS - Processing Method %s x %s (%d segments)\n', rawMethodStr_label, oxyMethodStr_label, numel(validIdx));
        validData = data(validIdx);
        validData = processFNIRS2(validData);
        data(validIdx) = validData;
    end

    % Apply channel mask + resample
    rsSize = ExFNIRS.settings.grandavg_resample_size;
    for k = 1:numel(validIdx)
        i = validIdx(k);
        data{i} = pf2.data.applyChannelMask(data{i});
        data{i} = pf2.data.resample(data{i}, rsSize, 'centerOnT0', true, ...
            'timeOutMode', 'end', 'averageAux', false, 'flattenAux', true);
    end

    
    
    ExFNIRS.processedData{ExFNIRS.numProcessed+1,3}=data;
    ExFNIRS.numProcessed=ExFNIRS.numProcessed+1;
    ExFNIRS.curProcessedData= data;
else
    pf2('blLength',0);
    pf2('Raw_Method',rawMethodStr,'Oxy_Method',oxyMethodStr); 
   ExFNIRS.curProcessedData= ExFNIRS.processedData{curRawMatchIdx&curOxyMatchIdx,3};
end

% Update optode list from processed data (channels created by bvoxy)
uOpt = [];
for ii = 1:length(ExFNIRS.curProcessedData)
    if ~isempty(ExFNIRS.curProcessedData{ii}) && isfield(ExFNIRS.curProcessedData{ii}, 'channels')
        uOpt = [uOpt; ExFNIRS.curProcessedData{ii}.channels(:)]; %#ok<AGROW>
    end
end
if ~isempty(uOpt)
    uOpt = sort(unique(uOpt));
    ExFNIRS.currentOpt = uOpt;
    % Rebuild labels with short-sep markers
    labels = arrayfun(@num2str, uOpt, 'UniformOutput', false);
    try
        dev = [];
        for ii2 = 1:length(ExFNIRS.curProcessedData)
            d = ExFNIRS.curProcessedData{ii2};
            if ~isempty(d) && isfield(d,'device') && isa(d.device,'pf2.Device')
                dev = d.device; break;
            end
        end
        if ~isempty(dev) && dev.nShortSep > 0
            ssMask = dev.isShortSep();
            chList = dev.channelList();
            for kk = 1:numel(uOpt)
                idx = find(chList == uOpt(kk), 1);
                if ~isempty(idx) && idx <= numel(ssMask) && ssMask(idx)
                    labels{kk} = sprintf('%d (ss)', uOpt(kk));
                end
            end
        end
    catch
    end
    ExFNIRS.currentOptLabels = labels;
end

if(processOxyOnly)
    ExFNIRS.curMethodName=sprintf('Skipped : %s',oxyMethodStr);
else
    ExFNIRS.curMethodName=sprintf('%s : %s',rawMethodStr,oxyMethodStr);
end
ExFNIRS.curMethodName(ExFNIRS.curMethodName=='_')='-';
