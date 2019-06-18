function ProcessOxy(varargin)
% This function is a wrapper for processFNIRS2's main function with the 'Skip Raw' argument
% 	(Processes only the Oxy stage


[varargout(:)]=processFNIRS2(varargin{:},'SkipRaw',true);