function SetDPFmode(dpfModeString)
% This function is a wrapper for the 'DPFmode' argument in processFNIRS2

validDPFmode = @(x) ischar(validatestring(x,{'None','Fixed','Calc'})); % None uses no DPF factor (units mm*mMol), fixed uses one DPF for all wavelenghts,Calc attempts tocalculate wavelength*age dependent changes

if(nargin<1||~validDPFmode(dpfModeString))
	error('Choose from None, Fixed, or Calc');
end

processFNIRS2('DPFmode',dpfModeString);