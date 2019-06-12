function SetRawMethod(raw_method_string)
% This function is a wrapper for the 'Raw_Method' argument in processFNIRS2

if(nargin<1)
	disp('TODO: Add listbox with current methods');
end

processFNIRS2('Raw_Method',raw_method_string);