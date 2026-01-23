function probeInfo=getDevice(fNIR)
% GETDEVICE Retrieve current device configuration or extract from fNIRS data
%
% Returns the currently active device configuration or extracts probe
% information from an fNIRS data structure. If no device is currently
% selected and no input is provided, prompts the user to select one.
%
% Syntax:
%   probeInfo = pf2.settings.getDevice()
%   probeInfo = pf2.settings.getDevice(fNIR)
%   probeInfo = pf2.settings.getDevice(device_name)
%
% Inputs:
%   fNIR - fNIRS data structure with probeinfo or info.probename field,
%          OR a device configuration filename [char/string]
%          (default: returns currently loaded device from global setF)
%
% Outputs:
%   probeInfo - Structure containing device configuration including:
%               .Info       - Device metadata (name, manufacturer, etc.)
%               .Probe1     - Probe geometry and channel definitions
%               .wavelength - Wavelengths used by the device
%
% Example:
%   % Get currently loaded device
%   device = pf2.settings.getDevice();
%
%   % Extract probe info from processed data
%   data = pf2.import.sampleData.fNIR2000();
%   processed = processFNIRS2(data);
%   probeInfo = pf2.settings.getDevice(processed);
%
%   % Load device by name
%   probeInfo = pf2.settings.getDevice('fNIR2000');
%
% Notes:
%   - If the fNIRS struct has a .probeinfo field, it is returned directly
%   - If the fNIRS struct has info.probename, attempts to load that config
%   - String inputs are treated as device config filenames
%
% See also: pf2.settings.selectDevice, pf2_base.loadDeviceCfg, processFNIRS2

if(nargin<1)
    global setF
    if(pf2_base.isnestedfield(setF,'device.Info.CfgName'))
        %Device has been loaded, return global variable
            probeInfo=setF.device;
            return;
    else
        fprintf('No Device Currently Selected\nPlease select a device');
        probeInfo=pf2.settings.selectDevice();
        return;
    end
else
    if(isstruct(fNIR)&&isfield(fNIR,'probeinfo')&&~isempty(fNIR.probeinfo))
        probeInfo=fNIR.probeinfo;
        return;

    elseif(isstruct(fNIR)&&pf2_base.isnestedfield(fNIR,'info.probename')&&~contains(fNIR.info.probename,'Unknown')) 
    %try to load the probename cfg file
        cfgFilePath=sprintf('%s.cfg',fNIR.info.probename);
        probeInfo=pf2.settings.selectDevice(cfgFilePath);
    elseif(isstring(fNIR)||ischar(fNIR))
        if(contains(fNIR,'.cfg','IgnoreCase',true))
            probeInfo=pf2.settings.selectDevice(fNIR);
        else
            probeInfo=pf2.settings.selectDevice(sprintf('%s.cfg',fNIR));
        end
    else
       error('No probe information found in data and no config file specified'); 
    end
end
    