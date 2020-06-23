function device=GetDevice()
% This function is a wrapper for the 'loadDeviceCfg' fucntion in processFNIRS2

global setF

if(exist(setF,'device'))
    device=setF.device;
else
   device=[]; 
end

end