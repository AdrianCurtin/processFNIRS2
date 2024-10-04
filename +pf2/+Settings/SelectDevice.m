function probeInfo=SelectDevice(device_cfg_path_string)
% This function is a wrapper for the 'loadDeviceCfg' fucntion in processFNIRS2

if(nargin<1)
    probeInfo=pf2_base.loadDeviceCfg();
elseif(nargout>0)
    probeInfo=pf2_base.loadDeviceCfg(device_cfg_path_string);
else
    pf2_base.loadDeviceCfg(device_cfg_path_string);
end
end