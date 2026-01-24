% pf2.settings - Configuration management
% processFNIRS2 v0.8
%
% Summary:
%   settings          - Display current settings summary
%
% Device Configuration:
%   selectDevice      - Load device configuration (GUI or by filename)
%   getDevice         - Query current device settings
%
% Quality Control:
%   setRejectLevel    - Set channel rejection threshold
%
% Subpackages:
%   +baseline         - Baseline correction settings
%   +dpf              - Differential Pathlength Factor settings
%
% Baseline Settings (pf2.settings.baseline.*):
%   setBaselineStartTime  - Set baseline start time (seconds)
%   setBaselineLength     - Set baseline duration (seconds)
%   useGlobalMean         - Use entire signal as baseline reference
%
% DPF Settings (pf2.settings.dpf.*):
%   setDPFmode        - Set DPF mode: 'None', 'Fixed', or 'Calc'
%   setFixedDPF       - Set fixed DPF value (when mode is 'Fixed')
%
% Example:
%   % View current settings
%   pf2.settings();
%
%   % Configure baseline
%   pf2.settings.baseline.setBaselineStartTime(0);
%   pf2.settings.baseline.setBaselineLength(10);
%
%   % Configure DPF
%   pf2.settings.dpf.setDPFmode('Calc');
%
%   % Load device
%   pf2.settings.selectDevice('fNIR_Devices_fNIR2000.cfg');
%
% See also: pf2.methods, processFNIRS2
