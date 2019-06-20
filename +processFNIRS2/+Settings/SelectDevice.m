function SelectDevice(device_cfg_path_string)
% This function is a wrapper for the 'loadDeviceCfg' fucntion in processFNIRS2
if(nargin<1)
    pf2_base.loadDeviceCfg();
else

    pf2_base.loadDeviceCfg(device_cfg_path_string);
end