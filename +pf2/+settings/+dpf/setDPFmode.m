function setDPFmode(dpfModeString)
% SETDPFMODE Set differential pathlength factor calculation mode
%
% Configures how the Differential Pathlength Factor (DPF) is determined
% during Beer-Lambert law conversion from optical density to hemoglobin
% concentration. The DPF accounts for the increased optical path length
% due to light scattering in tissue. This is a wrapper for the 'DPFmode'
% argument in processFNIRS2.
%
% Reference:
%   Scholkmann, F. & Wolf, M. (2013). General equation for the differential
%   pathlength factor of the frontal human head. J. Biomed. Opt. 18(10).
%   DOI: 10.1117/1.JBO.18.10.105004
%
% Syntax:
%   pf2.settings.dpf.setDPFmode(dpfModeString)
%
% Inputs:
%   dpfModeString - DPF calculation mode [char/string]. Matched
%                   case-insensitively (e.g. 'ppf' and 'PPF' are equivalent),
%                   but always canonicalized to the spelling below.
%                   'None'  - No DPF correction, output units are mM*mm
%                   'Fixed' - Use a single fixed DPF value for all wavelengths
%                             (set via SetFixedDPF, default: 5.93)
%                   'Calc'  - Calculate wavelength and age-dependent DPF
%                             using Scholkmann & Wolf (2013) equation
%                   'PPF'   - ESCAPE HATCH: a complete effective pathlength
%                             factor supplied directly (L = SD .* ppf), with
%                             no DPF/PVC decomposition. Set the factor via the
%                             'PPF' argument to processFNIRS2 (scalar or
%                             [ppf1 ppf2]); see pf2_base.fnirs.bvoxy for the
%                             full explanation of when to use this mode.
%
% Example:
%   % Use calculated DPF based on subject age
%   pf2.settings.dpf.setDPFmode('Calc');
%
%   % Use fixed DPF value
%   pf2.settings.dpf.setDPFmode('Fixed');
%   pf2.settings.dpf.setFixedDPF(6.0);
%
%   % Skip DPF correction (results in mM*mm units)
%   pf2.settings.dpf.setDPFmode('None');
%
%   % Escape hatch: a complete effective pathlength factor (no DPF/PVC split)
%   pf2.settings.dpf.setDPFmode('PPF');
%   processFNIRS2(data, 'DPFmode', 'PPF', 'PPF', [0.1 0.12]);
%
% Notes:
%   - 'Calc' mode requires subject age to be set (defaultSubjectAge parameter)
%   - 'Fixed' mode uses SetFixedDPF value or default of 5.93
%   - 'None' mode outputs concentration in mM*mm instead of microMolar
%   - 'PPF' mode requires a partial pathlength factor supplied via the 'PPF'
%     argument to processFNIRS2; it is mutually exclusive with Fixed/Calc DPF
%     and with PartialVolumeCorrection ('PVC')
%
% See also: pf2.settings.dpf.setFixedDPF, pf2_base.fnirs.bvoxy, processFNIRS2

validDPFmode = @(x) ischar(validatestring(x,{'None','Fixed','Calc','PPF'})); % None -> mM*mm; Fixed -> one DPF; Calc -> age/wavelength DPF; PPF -> complete effective factor (escape hatch)

if(nargin<1||~validDPFmode(dpfModeString))
	error('pf2:settings:setDPFmode:invalidMode', 'Choose from None, Fixed, Calc, or PPF');
end

processFNIRS2('DPFmode',dpfModeString);