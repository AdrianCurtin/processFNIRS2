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
outFNIR.channels=cell(1,numCh);
outFNIR.probeNum=zeros(1,numCh);
outFNIR.fchMask=[];

outFNIR.raw=[];

outFNIR.info.probename='Unknown';

for j=1:length(fieldsToFill)
     outFNIR.(fieldsToFill{j})=nan(length(newTime),numCh);
end

curCh=1;

for i=1:length(fNIR_objs) %use Slowest fNIR file as reference
     fMinTime=nanmin(fNIR_objs{i}.time);
     
     fMinIdx=find(fNIR_objs{i}.time==fMinTime);
     fLength=size(fNIR_objs{i}.time);
     fNumCh=length(fNIR_objs{i}.channels);
     
     outFNIR.probeNum(curCh:fNumCh+curCh-1)=i;
     %outFNIR.info.probename{i}=fNIR_objs{i}.info.probename;
     
     for j=1:length(fieldsToFill)
          temp= outFNIR.(fieldsToFill{j});
          temp(fMinIdx:fLength,curCh:fNumCh+curCh-1)=fNIR_objs{i}.(fieldsToFill{j});
          outFNIR.(fieldsToFill{j})=temp;
          
     end
     
     for ch=1:fNumCh
         outFNIR.channels{ch-1+curCh}=sprintf('%i:%i',i,ch);
     end
     curCh=fNumCh+curCh;
     
     outFNIR.fchMask=[outFNIR.fchMask,fNIR_objs{i}.fchMask];
end






