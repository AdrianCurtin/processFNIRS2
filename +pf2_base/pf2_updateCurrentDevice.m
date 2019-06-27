function [fData] = pf2_updateCurrentDevice(fData,cfgFilePath)
%PF2_UPDATECURRENTDEVICE Summary of this function goes here
%   Detailed explanation goes here

global setF
global PF2

PF2.curChSet=[];
PF2.curWvSet=[];
PF2.curSDSet=[];
PF2.curProbeInd=[];


if(nargin>1&&isempty(cfgFilePath)||~contains(cfgFilePath,'.cfg'))&&(~isempty(fData)) %if nothing, invalid, or no data
    
    warning('Missing or invalid configuration file path\n')
    
    disp('No device specified. Please load device configuration');
    pf2_base.loadDeviceCfg();
    if(~isfield(setF,'device'))
        error('No valid devices selected');
    end
    
elseif(nargin>1&&~isempty(cfgFilePath)) 
    
    if(pf2_base.isnestedfield(setF,'device.cfg.Info.CfgName')) % look to see if they match,...
            
        curProbeName=sprintf('%s.cfg',setF.device.cfg.Info.CfgName);
        
        if(~strcmp(curProbeName,cfgFilePath)) %if they do don't bother loading
            pf2_base.loadDeviceCfg(cfgFilePath,true);
        end
    else
        pf2_base.loadDeviceCfg(cfgFilePath,true);
    end
elseif(nargin==1)
    
    if(pf2_base.isnestedfield(fData,'info.probename')) % look to see if they match,...
            
        dataProbeName=sprintf('%s.cfg',fData.info.probename);
        
        if(pf2_base.isnestedfield(setF,'device.cfg.Info.CfgName')) % look to see if they match,...
            if(~strcmp(dataProbeName,(setF.device.cfg.Info.CfgName)) %if they do don't bother loading
                    pf2_base.loadDeviceCfg(dataProbeName,true);
            end
        else
            pf2_base.loadDeviceCfg(dataProbeName,true);
        end
    else
        warning('Missing or invalid configuration file path\n')
    
        disp('No device specified. Please load device configuration');
        pf2_base.loadDeviceCfg();
        if(~isfield(setF,'device'))
            error('No valid devices selected');
        end
    end
    
end


if(length(setF.device.Probe)==1)
    PF2.mergedProbe=true;
    fData.probeInfo=setF.device{1};
else
    PF2.mergedProbe=true;
    warning('Multiple Probes may not be fully supported');
end

if(PF2.mergedProbe) %All channel numbers are unique for merged probes
    for i =1:length(setF.device.Probe)
        PF2.curChSet=[PF2.curChSet,setF.device.Probe{i}.ChannelNumbers];
        PF2.curProbeInd=[PF2.curProbeInd,i*length(setF.device.Probe{i}.ChannelNumbers)];
    
        PF2.curWvSet=[PF2.curWvSet,setF.device.Probe{i}.Wavelength];
        PF2.curSDSet=[PF2.curSDSet,setF.device.Probe{i}.SD];
    end
    PF2.timeIndex=find(PF2.curChSet==0);
    if(isempty(PF2.timeIndex))
        warning('Time column could not be found, assuming each row is a sample');
        PF2.timeIndex=0;
    end
else
    error('Not yet implemented for seperate probe data,\nAssumes concatenated datasets with unique channels in the config file'); 
end

[~,i]=unique(PF2.curChSet);
PF2.curChList=PF2.curChSet(i);


if(PF2.mergedProbe) %All channel numbers are unique for merged probes  
    
    data=fData.raw;
    
    if(~isempty(data))
        if(isfield(fData,'time')&&~isempty(fData.time))
            fData.fs=1./median(diff(fData.time));
            fData.sampleTime=1:length(data(:,1));
        elseif(PF2.timeIndex==0)
            fData.sampleTime=1:length(data(:,1));
            fData.time=(fData.sampleTime-1)./fData.device.Info.DefaultSamplingRate;
            fData.fs=fData.device.Info.DefaultSamplingRate;
        elseif(setF.device.Info.TimeIsSampleCount==1)
            fData.sampleTime=data(:,PF2.timeIndex);
            fData.time=(fData.sampleTime-1)./fData.device.Info.DefaultSamplingRate;
            fData.fs=fData.device.Info.DefaultSamplingRate;
        else
            fData.sampleTime=1:length(data(:,1));
            fData.time=data(:,PF2.timeIndex);
            fData.fs=1./median(diff(fData.time));
        end
    elseif(isfield(data,'time')&&~isempty(fData.time))  %If time exists
        fData.sampleTime=1:length(fData.time);
        fData.fs=1./median(diff(fData.time));
    elseif(~isempty(fData.stage{4})) %try to calculate from oxy data
        data=fData.stage{4};
        if(isfield(fData,'time')&&~isempty(fData.time))
            fData.fs=1./median(diff(fData.time));
            fData.sampleTime=1:length(data(:,1));
        elseif(PF2.timeIndex==0)
            fData.sampleTime=1:length(data.HbO(:,1));
            fData.time=(fData.sampleTime-1)./fData.device.Info.DefaultSamplingRate;
            fData.fs=fData.device.Info.DefaultSamplingRate;
        elseif(fData.device.Info.TimeIsSampleCount==1)
            fData.sampleTime=data.HbO(:,PF2.timeIndex);
            fData.time=(fData.sampleTime-1)./fData.device.Info.DefaultSamplingRate;
            fData.fs=fData.device.Info.DefaultSamplingRate;
        else
            fData.sampleTime=1:length(data.HbO(:,1));
            fData.time=data.HbO(:,PF2.timeIndex);
            fData.fs=1./median(diff(fData.time));
        end
    end

else
   error('Not Yet Implemented for seperate probe data,\nAssumes concatenated datasets with unique channels in the config file'); 
end
end
