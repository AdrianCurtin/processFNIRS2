function SetBaselineStart(time_relative_to_start_in_seconds)
% This function is a wrapper for the 'blStartTime' argument in processFNIRS2

if(nargin<1||~isnumeric(time_relative_to_start_in_seconds)||time_relative_to_start_in_seconds<0)
	error('Please provide a valid baseline length');
end

processFNIRS2('blStartTime',time_relative_to_start_in_seconds);