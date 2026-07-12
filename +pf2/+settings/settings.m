function settings()
% SETTINGS Display current processFNIRS2 configuration summary
%
% Displays a formatted summary of the current processing settings including
% selected methods, baseline parameters, DPF configuration, and device info.
% This provides a quick overview without needing to inspect global variables.
%
% Syntax:
%   pf2.settings.settings()
%   pf2.settings()            % Package-level call
%
% Example:
%   % Configure and verify settings
%   pf2.methods.raw.setMethod('x2_lpf_smar');
%   pf2.settings.baseline.setBaselineLength(10);
%   pf2.settings();  % Display current configuration
%
%   % Output example:
%   % ═══════════════════════════════════════════════════
%   % processFNIRS2 Current Settings
%   % ═══════════════════════════════════════════════════
%   %
%   % PROCESSING METHODS
%   %   Raw Method:    x2_lpf_smar
%   %   Oxy Method:    takizawa_easy
%   %
%   % BASELINE
%   %   Start Time:    0.0 sec
%   %   Length:        10.0 sec
%   %   End Time:      10.0 sec
%   %
%   % DPF (Differential Pathlength Factor)
%   %   Mode:          Calc (age-dependent)
%   %   Subject Age:   25 years
%   %
%   % QUALITY CONTROL
%   %   Reject Level:  0 (reject when fchMask==0)
%   %
%   % DEVICE
%   %   Name:          fNIR 2000
%   %   Channels:      18
%
% See also: pf2.methods.raw.setMethod, pf2.methods.oxy.setMethod,
%           pf2.settings.baseline, pf2.settings.dpf, pf2.settings.selectDevice

global PF2
global setF

% Ensure initialized
if isempty(PF2) || ~isfield(PF2, 'baseline')
    pf2_base.pf2_initialize();
end

fprintf('\n');
fprintf('\x2550\x2550\x2550\x2550\x2550\x2550\x2550\x2550\x2550\x2550\x2550\x2550\x2550\x2550\x2550\x2550\x2550\x2550\x2550\x2550\x2550\x2550\x2550\x2550\x2550\x2550\x2550\x2550\x2550\x2550\x2550\x2550\x2550\x2550\x2550\x2550\x2550\x2550\x2550\x2550\x2550\x2550\x2550\x2550\x2550\x2550\x2550\x2550\x2550\x2550\x2550\n');
fprintf('<strong>processFNIRS2 Current Settings</strong>\n');
fprintf('\x2550\x2550\x2550\x2550\x2550\x2550\x2550\x2550\x2550\x2550\x2550\x2550\x2550\x2550\x2550\x2550\x2550\x2550\x2550\x2550\x2550\x2550\x2550\x2550\x2550\x2550\x2550\x2550\x2550\x2550\x2550\x2550\x2550\x2550\x2550\x2550\x2550\x2550\x2550\x2550\x2550\x2550\x2550\x2550\x2550\x2550\x2550\x2550\x2550\x2550\x2550\n\n');

% Processing Methods
fprintf('<strong>PROCESSING METHODS</strong>\n');
if isfield(PF2, 'stageRawMethod') && isfield(PF2.stageRawMethod, 'name')
    fprintf('  Raw Method:    %s\n', PF2.stageRawMethod.name);
else
    fprintf('  Raw Method:    <not set>\n');
end

if isfield(PF2, 'stageOxyMethod') && isfield(PF2.stageOxyMethod, 'name')
    fprintf('  Oxy Method:    %s\n', PF2.stageOxyMethod.name);
else
    fprintf('  Oxy Method:    <not set>\n');
end
fprintf('\n');

% Baseline Settings
fprintf('<strong>BASELINE</strong>\n');
if isfield(PF2, 'baseline')
    startTime = 0;
    blLength = 10;

    if isfield(PF2.baseline, 'startTime')
        startTime = PF2.baseline.startTime;
    end
    if isfield(PF2.baseline, 'blLength')
        blLength = PF2.baseline.blLength;
    end

    fprintf('  Start Time:    %.1f sec\n', startTime);
    fprintf('  Length:        %.1f sec\n', blLength);
    fprintf('  End Time:      %.1f sec\n', startTime + blLength);
else
    fprintf('  <not configured>\n');
end
fprintf('\n');

% DPF Settings
fprintf('<strong>DPF (Differential Pathlength Factor)</strong>\n');
if isfield(PF2, 'dpf_mode')
    dpfMode = PF2.dpf_mode;
    switch lower(dpfMode)
        case 'none'
            fprintf('  Mode:          None (no DPF correction, units: mM*mm)\n');
        case 'fixed'
            fixedVal = 5.93;
            if isfield(PF2, 'curDPF_fixed')
                fixedVal = PF2.curDPF_fixed;
            end
            fprintf('  Mode:          Fixed\n');
            fprintf('  Fixed Value:   %.2f\n', fixedVal);
        case 'calc'
            age = 25;
            if isfield(PF2, 'curDPF_age')
                age = PF2.curDPF_age;
            end
            fprintf('  Mode:          Calc (age-dependent)\n');
            fprintf('  Subject Age:   %d years\n', age);
        otherwise
            fprintf('  Mode:          %s\n', dpfMode);
    end
else
    fprintf('  Mode:          <not set> (default: Calc)\n');
end
fprintf('\n');

% Quality Control
fprintf('<strong>QUALITY CONTROL</strong>\n');
if isfield(PF2, 'RejectLevel')
    rejectLevel = PF2.RejectLevel;
    if rejectLevel == 0
        fprintf('  Reject Level:  %d (reject when fchMask==0)\n', rejectLevel);
    else
        fprintf('  Reject Level:  %d\n', rejectLevel);
    end
else
    fprintf('  Reject Level:  0 (default)\n');
end
fprintf('\n');

% Device Info
fprintf('<strong>DEVICE</strong>\n');
if ~isempty(setF) && pf2_base.isnestedfield(setF, 'device.Info')
    deviceInfo = setF.device.Info;

    if isfield(deviceInfo, 'Name')
        fprintf('  Name:          %s\n', deviceInfo.Name);
    elseif isfield(deviceInfo, 'CfgName')
        fprintf('  Name:          %s\n', deviceInfo.CfgName);
    end

    if isfield(deviceInfo, 'NumberChannels')
        fprintf('  Channels:      %d\n', deviceInfo.NumberChannels);
    end

    if isfield(deviceInfo, 'DefaultSamplingRate')
        fprintf('  Sampling Rate: %d Hz\n', deviceInfo.DefaultSamplingRate);
    end

    if isfield(deviceInfo, 'Manufacturer')
        fprintf('  Manufacturer:  %s\n', deviceInfo.Manufacturer);
    end
else
    fprintf('  <no device loaded>\n');
end
fprintf('\n');

% Available methods count
if isfield(PF2, 'myRawMethods') && isfield(PF2.myRawMethods, 'cfg')
    numRaw = length(PF2.myRawMethods.cfg.Sections);
else
    numRaw = 0;
end

if isfield(PF2, 'myOxyMethods') && isfield(PF2.myOxyMethods, 'cfg')
    numOxy = length(PF2.myOxyMethods.cfg.Sections);
else
    numOxy = 0;
end

fprintf('<strong>AVAILABLE METHODS</strong>\n');
fprintf('  Raw methods:   %d available (pf2.methods.raw.list() to see)\n', numRaw);
fprintf('  Oxy methods:   %d available (pf2.methods.oxy.list() to see)\n', numOxy);
fprintf('\n');

end
