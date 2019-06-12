function SetFixedDPF(dpf_fixed_value)
% This function is a wrapper for the 'DPFmode' argument in processFNIRS2
% Also sets DPF mode to Fixed

if(nargin<1||~isnumeric(dpf_fixed_value)||dpf_fixed_value<=0)
	error('Please provide a valid dpf value');
end

processFNIRS2('FixedDPF',dpf_fixed_value,'DPFmode','Fixed');