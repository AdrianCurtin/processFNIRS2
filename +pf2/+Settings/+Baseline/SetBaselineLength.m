function SetBaselineLength(baseline_length_in_seconds)
% This function is a wrapper for the 'blLength' argument in processFNIRS2

if(nargin<1||~isnumeric(baseline_length_in_seconds)||baseline_length_in_seconds<0)
	error('Please provide a valid baseline length');
end

processFNIRS2('blLength',baseline_length_in_seconds);