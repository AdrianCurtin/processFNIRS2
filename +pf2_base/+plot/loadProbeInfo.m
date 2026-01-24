function [probeInfo, deviceInfo] = loadProbeInfo(fNIR, loadLayout)
% LOADPROBEINFO Load probe configuration from fNIRS data or config file
%
% Extracts probe information from an fNIRS data structure or loads it from
% a device configuration file. This helper reduces code duplication across
% plotting functions that all need to access probe geometry.
%
% Syntax:
%   probeInfo = pf2_base.plot.loadProbeInfo(fNIR)
%   probeInfo = pf2_base.plot.loadProbeInfo(fNIR, loadLayout)
%   [probeInfo, deviceInfo] = pf2_base.plot.loadProbeInfo(...)
%
% Inputs:
%   fNIR       - fNIRS data structure [struct] or empty []
%                If struct, attempts to extract probe info from:
%                1. fNIR.probeinfo field (if present)
%                2. fNIR.info.probename to load config file
%   loadLayout - Load 2D layout information [logical] (default: false)
%                Set true when probe geometry is needed for arranged plots.
%
% Outputs:
%   probeInfo  - Probe configuration struct containing:
%                - NumOptodes: Number of optodes
%                - TableCh: Channel table with wavelengths
%                - TableOpt: Optode table
%                - OptPos: Optode positions (if loadLayout=true)
%   deviceInfo - Device information struct (optional)
%
% Example:
%   [probeInfo, deviceInfo] = pf2_base.plot.loadProbeInfo(fNIR, true);
%   optLayout = probeInfo.OptPos.subplot_layout_ss;
%
% See also: pf2_base.loadDeviceCfg, pf2.data.plot.oxy, pf2.data.plot.raw

if nargin < 2
    loadLayout = false;
end

probeInfo = [];
deviceInfo = [];

% Check if probeinfo is already in the data struct
if isstruct(fNIR) && isfield(fNIR, 'probeinfo')
    probeInfo = fNIR.probeinfo;
else
    % Try to get config file path from fNIR.info.probename
    cfgFilePath = '';
    if isstruct(fNIR) && pf2_base.isnestedfield(fNIR, 'info.probename') && ...
            isfield(fNIR.info, 'probename') && ~contains(fNIR.info.probename, 'Unknown')
        cfgFilePath = sprintf('%s.cfg', fNIR.info.probename);
    end

    % If no config path, try global setF
    if isempty(cfgFilePath) || ~contains(cfgFilePath, '.cfg')
        global setF
        if ~isempty(setF) && isfield(setF, 'device')
            cfgFilePath = setF.device.cfg.File;
            % Check if layout already loaded
            if loadLayout && isfield(setF.device.Probe{1}, 'OptLayout2D')
                probeInfo = setF.device;
            end
        end
    end

    % Load from config file if needed
    if isempty(probeInfo)
        if isempty(cfgFilePath) || ~contains(cfgFilePath, '.cfg')
            warning('Missing or invalid configuration file path');
            disp('No device specified. Please load device configuration');
            probeInfo = pf2_base.loadDeviceCfg([], true);
            if isempty(probeInfo)
                error('No valid devices selected');
            end
        else
            probeInfo = pf2_base.loadDeviceCfg(cfgFilePath, loadLayout);
        end
    end
end

% Extract probe from multi-probe structure
if pf2_base.isnestedfield(probeInfo, 'Probe')
    deviceInfo = probeInfo.Info;
    if ~isfield(deviceInfo, 'numberProbes') || deviceInfo.numberProbes == 1
        probeNum = 1;
    else
        probeNum = 1; % Default to first probe
    end
    probeInfo = probeInfo.Probe{probeNum};
elseif isempty(probeInfo)
    error('Unable to identify probe');
end

end
