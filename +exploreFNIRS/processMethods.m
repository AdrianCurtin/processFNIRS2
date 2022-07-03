function processMethods(rawMethodStr,oxyMethodStr)
global ExFNIRS
%global ProgressHandles

if(isempty(rawMethodStr))
   processOxyOnly=true; 
else
   processOxyOnly=false; 
end

strsOxy=pf2.Methods.Oxy();
strsRaw=pf2.Methods.Raw();

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
    
    pf2('blLength',0);
    pf2('Raw_Method',rawMethodStr,'Oxy_Method',oxyMethodStr); 
    numData=length(data);
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
                   data{i}=pf2.Process.ProcessOxy(data{i});
               else
                   warning('Data file for item %i has no Oxy Data, attempting to process with ''None''\n',data{i});
                   data{i}=pf2(data{i});
               end
           else
               data{i}=pf2(data{i});
           end
           data{i}=pf2.Data.ApplyChannelMask(data{i});
           data{i}=pf2.Data.Resample(data{i},ExFNIRS.settings.grandavg_resample_size,'centerOnT0',true,'timeOutMode','end','averageAux',false,'flattenAux',true);
       end
    end
    try
    close(hF);
    catch
        
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
