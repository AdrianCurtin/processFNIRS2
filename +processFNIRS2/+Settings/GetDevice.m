function probeInfo=GetDevice(fNIR)
% This function is a wrapper for the 'loadDeviceCfg' fucntion in processFNIRS2

if(nargin<1)
    global setF
    if(pf2_base.isnestedfield(setF,'device.Info.CfgName'))
        %Device has been loaded, return global variable
            probeInfo=setF.device;
            return;
    else
        fprintf('No Device Currently Selected\nPlease select a device');
        probeInfo=processFNIRS2.Settings.SelectDevice();
        return;
    end
else
    if(isstruct(fNIR)&&isfield(fNIR,'probeinfo')&&~isempty(fNIR.probeinfo))
        probeInfo=fNIR.probeinfo;
        return;

    elseif(isstruct(fNIR)&&pf2_base.isnestedfield(fNIR,'info.probename')&&~contains(fNIR.info.probename,'Unknown')) 
    %try to load the probename cfg file
        cfgFilePath=sprintf('%s.cfg',fNIR.info.probename);
        probeInfo=processFNIRS2.Settings.SelectDevice(cfgFilePath);
    elseif(isstring(fNIR)||ischar(fNIR))
        if(contains(fNIR,'.cfg','IgnoreCase',true))
            probeInfo=processFNIRS2.Settings.SelectDevice(fNIR);
        else
            probeInfo=processFNIRS2.Settings.SelectDevice(sprintf('%s.cfg',fNIR));
        end
    else
       error('No probe information found in data and no config file specified'); 
    end
end
    