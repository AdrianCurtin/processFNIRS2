% pf2.settings.dpf - Differential Pathlength Factor settings
% processFNIRS2 v0.8
%
% DPF accounts for light scattering in tissue when converting optical
% density to hemoglobin concentration (Beer-Lambert Law).
%
% Settings:
%   setDPFmode    - Set calculation mode: 'None', 'Fixed', or 'Calc'
%   setFixedDPF   - Set fixed DPF value (when mode is 'Fixed')
%
% DPF Modes:
%   'None'   - No DPF correction, units remain mM*mm
%   'Fixed'  - Use constant DPF value (default: 5.93)
%   'Calc'   - Age-dependent calculation (Scholkmann & Wolf 2013)
%
% Example:
%   % Age-dependent DPF (recommended)
%   pf2.settings.dpf.setDPFmode('Calc');
%
%   % Fixed DPF value
%   pf2.settings.dpf.setDPFmode('Fixed');
%   pf2.settings.dpf.setFixedDPF(6.0);
%
%   % No DPF correction
%   pf2.settings.dpf.setDPFmode('None');
%
% See also: pf2.settings, processFNIRS2
