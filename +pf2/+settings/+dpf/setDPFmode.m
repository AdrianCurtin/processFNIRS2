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
%   dpfModeString - DPF calculation mode [char/string]
%                   'None'  - No DPF correction, output units are mM*mm
%                   'Fixed' - Use a single fixed DPF value for all wavelengths
%                             (set via SetFixedDPF, default: 5.93)
%                   'Calc'  - Calculate wavelength and age-dependent DPF
%                             using Scholkmann & Wolf (2013) equation
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
% Notes:
%   - 'Calc' mode requires subject age to be set (defaultSubjectAge parameter)
%   - 'Fixed' mode uses SetFixedDPF value or default of 5.93
%   - 'None' mode outputs concentration in mM*mm instead of microMolar
%
% See also: pf2.settings.dpf.setFixedDPF, pf2_base.fnirs.bvoxy, processFNIRS2

validDPFmode = @(x) ischar(validatestring(x,{'None','Fixed','Calc'})); % None uses no DPF factor (units mm*mMol), fixed uses one DPF for all wavelenghts,Calc attempts tocalculate wavelength*age dependent changes

if(nargin<1||~validDPFmode(dpfModeString))
	error('pf2:settings:setDPFmode:invalidMode', 'Choose from None, Fixed, or Calc');
end

processFNIRS2('DPFmode',dpfModeString);