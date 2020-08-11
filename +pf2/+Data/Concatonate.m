function outFNIR=Concatonate(fNIR_objs,varargin)

%// function that merges two fNIRS probes together into one fNIR struct

centerOnT0=true;

if(nargin>1)
   if(isstruct(varargin{1}))
      fNIR_objs={fNIR_objs,varargin{1}}; 
   end
end

minFs=inf;
minFsIdx=nan;



for i=1:length(fNIR_objs) %use Slowest fNIR file as reference
    if(fNIR_objs{i}.fs<minFs)
       minFs=fNIR_objs{i}.fs;
       minFsIdx=i;
       
       minTime=nanmin(fNIR_objs{i}.time);
       maxTime=nanmax(fNIR_objs{i}.time);
       
    end
end

minTime=inf;
maxTime=-inf;

numCh=0;


for i=1:length(fNIR_objs) %use Slowest fNIR file as reference
    if(~isfield(fNIR_objs{i},'HbO'))
       error('fNIR segment %i has not been processed for Oxy data yet'); 
    end
    numCh=numCh+length(fNIR_objs{i}.channels);
    if(minFsIdx~=i||centerOnT0)
        
        
        fNIR_objs{i}=pf2.Data.Resample(fNIR_objs{i},1/minFs,'centerOnT0',centerOnT0,'timeOutMode','start','averageAux',true); 
       
        fMinTime=nanmin(fNIR_objs{i}.time);
        fMaxTime=nanmax(fNIR_objs{i}.time);
        
        if(fMinTime<minTime)
            minTime=fMinTime;
        end
        
        if(fMaxTime>maxTime)
           maxTime= fMaxTime;
        end
        
        if(minTime>fMaxTime||maxTime<fMinTime)
            warning('fNIRS segments do not overlap at all');
        end
      
    end
end



outFNIR=fNIR_objs{minFsIdx};

newTime=[minTime:1/outFNIR.fs:maxTime]';

fieldsToFill={'HbO','HbR','CBSI','HbDiff','HbTotal'};

outFNIR.time=newTime;
outFNIR.rawTime = cell(1,length(fNIR_objs));
outFNIR.channels=cell(1,numCh);
outFNIR.probeNum=zeros(1,numCh);
outFNIR.fchMask=[];

outFNIR.raw={};
outFNIR.DPF_factor={};

outFNIR.info.probename={};%'Unknown';

for j=1:length(fieldsToFill)  % Build NULL Oxy fields
     outFNIR.(fieldsToFill{j})=nan(length(newTime),numCh);
end

curCh=1;

probeFieldsToRetain={'time','raw','markers','DPF_factor','fs','units','fchMask','channels'};

for i=1:length(fNIR_objs) %use Slowest fNIR file as reference
     %outFNIR.rawTime{i} = fNIR_objs{i}.time;
     fMinTime=nanmin(fNIR_objs{i}.time);
     
     fMinIdx=find(fNIR_objs{i}.time==fMinTime);
     fLength=size(fNIR_objs{i}.time);
     fNumCh=length(fNIR_objs{i}.channels);
     
     outFNIR.probeNum(curCh:fNumCh+curCh-1)=i;
     outFNIR.info.probename{i}=fNIR_objs{i}.info.probename;
     %outFNIR.raw{i}=fNIR_objs{i}.raw;
     %outFNIR.DPF_factor{i}=fNIR_objs{i}.DPF_factor;
     
     %outFNIR.markers_orig{i}=fNIR_objs{i}.markers;
     
     %Fill in oxy fields
     for j=1:length(fieldsToFill)
          temp= outFNIR.(fieldsToFill{j});
          temp(fMinIdx:fLength,curCh:fNumCh+curCh-1)=fNIR_objs{i}.(fieldsToFill{j});
          outFNIR.(fieldsToFill{j})=temp;
          
     end
     
     %Save old probe information
      outFNIR.probe{i}.probename=fNIR_objs{i}.info.probename;
      for j=1:length(probeFieldsToRetain)
          outFNIR.probe{i}.(probeFieldsToRetain{j})=fNIR_objs{i}.(probeFieldsToRetain{j});
      end
     
     %Build new channel information
     for ch=1:fNumCh
         outFNIR.channels{ch-1+curCh}=sprintf('%i:%i',i,ch);
     end
     curCh=fNumCh+curCh;
     
     %Merge channel mask info
     outFNIR.fchMask=[outFNIR.fchMask,fNIR_objs{i}.fchMask];
end






