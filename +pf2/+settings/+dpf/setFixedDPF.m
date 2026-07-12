function setFixedDPF(dpf_fixed_value)
% SETFIXEDDPF Set fixed differential pathlength factor value
%
% Sets a fixed Differential Pathlength Factor (DPF) value to use during
% Beer-Lambert law conversion. Also automatically sets DPF mode to 'Fixed'.
% The DPF accounts for the increased optical path length due to light
% scattering in tissue. This is a wrapper for the 'FixedDPF' and 'DPFmode'
% arguments in processFNIRS2.
%
% The DPF typically ranges from 5-7 for adult frontal cortex measurements
% and varies with age and wavelength. Using a fixed value simplifies
% processing when age is unknown or for consistency across subjects.
%
% Syntax:
%   pf2.settings.dpf.setFixedDPF(dpf_fixed_value)
%
% Inputs:
%   dpf_fixed_value - Fixed DPF value to use [double]
%                     Must be a positive numeric value.
%                     Typical range: 5.0-7.0 for adult frontal cortex.
%                     Common default: 5.93
%
% Example:
%   % Set fixed DPF to common literature value
%   pf2.settings.dpf.setFixedDPF(5.93);
%
%   % Set fixed DPF for older adult population
%   pf2.settings.dpf.setFixedDPF(6.5);
%
%   % Process with fixed DPF
%   pf2.settings.dpf.setFixedDPF(6.0);
%   data = pf2.import.sampleData.fNIR2000();
%   processed = processFNIRS2(data);
%
% Notes:
%   - Calling this function automatically sets DPFmode to 'Fixed'
%   - The fixed DPF is applied uniformly to all wavelengths
%   - For age-dependent DPF, use SetDPFmode('Calc') instead
%
% See also: pf2.settings.dpf.setDPFmode, pf2_base.fnirs.bvoxy, processFNIRS2

if(nargin<1||~isnumeric(dpf_fixed_value)||dpf_fixed_value<=0)
	error('pf2:settings:setFixedDPF:invalidValue', 'Please provide a valid dpf value');
end

processFNIRS2('FixedDPF',dpf_fixed_value,'DPFmode','Fixed');