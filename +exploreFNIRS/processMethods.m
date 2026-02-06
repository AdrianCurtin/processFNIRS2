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
    
    for i=1:numData
       fprintf('ExploreFNIRS - Processing Method %s x %s %i of %i\n',rawMethodStr_label,oxyMethodStr_label,i,numData);
       
       if(~isempty(data{i})&&length(data{i}.time)>1)
           if(processOxyOnly)
               if(isfield(data{i},'HbO'))
                   data{i}=pf2.process.processOxy(data{i});
               else
                   warning('Data file for item %i has no Oxy Data, attempting to process with ''None''\n',i);
                   data{i}=pf2(data{i});
               end
           else
               data{i}=pf2(data{i});
           end
           data{i}=pf2.data.applyChannelMask(data{i});
           data{i}=pf2.data.resample(data{i},ExFNIRS.settings.grandavg_resample_size,'centerOnT0',true,'timeOutMode','end','averageAux',false,'flattenAux',true);
       end
    end

    
    
    ExFNIRS.processedData{ExFNIRS.numProcessed+1,3}=data;
    ExFNIRS.numProcessed=ExFNIRS.numProcessed+1;
    ExFNIRS.curProcessedData= data;
else
    pf2('blLength',0);
    pf2('Raw_Method',rawMethodStr,'Oxy_Method',oxyMethodStr); 
   ExFNIRS.curProcessedData= ExFNIRS.processedData{curRawMatchIdx&curOxyMatchIdx,3};
end

if(processOxyOnly)
    ExFNIRS.curMethodName=sprintf('Skipped : %s',oxyMethodStr);
else
    ExFNIRS.curMethodName=sprintf('%s : %s',rawMethodStr,oxyMethodStr);
end
ExFNIRS.curMethodName(ExFNIRS.curMethodName=='_')='-';
