function probeInfo=SelectDevice(device_cfg_path_string)
% SELECTDEVICE Load and activate a device configuration for fNIRS processing
%
% Loads a device configuration file (.cfg) that defines probe geometry,
% channel layout, wavelengths, and other hardware-specific parameters.
% This is a wrapper for pf2_base.loadDeviceCfg() that provides a user-friendly
% interface for device selection. When called without arguments, opens a
% file selection dialog.
%
% Syntax:
%   probeInfo = pf2.Settings.SelectDevice()
%   probeInfo = pf2.Settings.SelectDevice(device_cfg_path_string)
%   pf2.Settings.SelectDevice(device_cfg_path_string)
%
% Inputs:
%   device_cfg_path_string - Path to device configuration file [char/string]
%                            Can be a full path or just the filename if the
%                            file is in the /devices/ folder.
%                            (default: opens file selection dialog)
%
% Outputs:
%   probeInfo - Structure containing device configuration including:
%               .Info       - Device metadata (name, manufacturer, etc.)
%               .Probe1     - Probe geometry and channel definitions
%               .wavelength - Wavelengths used by the device
%
% Example:
%   % Select device interactively
%   probeInfo = pf2.Settings.SelectDevice();
%
%   % Load specific device configuration
%   probeInfo = pf2.Settings.SelectDevice('fNIR_Devices_fNIR2000.cfg');
%
%   % Load device without capturing output (sets global)
%   pf2.Settings.SelectDevice('Hitachi_ETG4000_3x5.cfg');
%
% See also: pf2.Settings.GetDevice, pf2_base.loadDeviceCfg, processFNIRS2

if(nargin<1)
    probeInfo=pf2_base.loadDeviceCfg();
elseif(nargout>0)
    probeInfo=pf2_base.loadDeviceCfg(device_cfg_path_string);
else
    pf2_base.loadDeviceCfg(device_cfg_path_string);
end
end