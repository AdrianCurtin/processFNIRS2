function probeInfo = loadProbeInfo(fNIR, buildProbeLayout, includeSS)
if(nargin < 2)
    buildProbeLayout=true;
end

if(nargin<3)
    includeSS=true;
end

if(isfield(fNIR,'probeinfo'))
    probeInfo=fNIR.probeinfo;
else
    numProbes = 1;
    cfgFilePaths = {};
    if(pf2_base.isnestedfield(fNIR,'info.probename')&&isfield(fNIR.info,'probename'))
        if(iscell(fNIR.info.probename))
            numProbes = length(fNIR.info.probename);
        end
        for i=1:numProbes
           if(numProbes == 1)
               probename = fNIR.info.probename;
           else
               probename = fNIR.info.probename{1};
           end
           if(~contains(probename, 'Unknown'))
               cfgFilePaths{i} = sprintf('%s.cfg', probename);
           else
               cfgFilePaths{i} = '';
           end
        end
    else
        cfgFilePaths{1} = '';
    end

    for i=1:length(cfgFilePaths)
        cfgFilePath = cfgFilePaths{i};
        if(isempty(cfgFilePath)||~contains(cfgFilePath,'.cfg'))
            
            warning('Missing or invalid configuration file path\n')
            
            disp('No device specified. Please load device configuration');
            probeInfo=pf2_base.loadDeviceCfg([],true);
            if(~isempty(probeInfo))
                error('No valid devices selected');
            end
            
        elseif(~isempty(cfgFilePath)) % If we're not looking at the GUI, doesn't matter
            probeInfo=pf2_base.loadDeviceCfg(cfgFilePath, buildProbeLayout, includeSS);
        end
    end
    
    if(pf2_base.isnestedfield(probeInfo,'Probe'))
        deviceInfo=probeInfo.Info;
        if(~isfield(deviceInfo,'numberProbes')||deviceInfo.numberProbes==1)
            probeNum=1;
        end
        probeInfo=probeInfo.Probe{probeNum};
    else
        error('Unable to identify probe');
    end
end