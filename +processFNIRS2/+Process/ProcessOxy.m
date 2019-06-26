function varargout=ProcessOxy(varargin)
% This function is a wrapper for processFNIRS2's main function with the 'Skip Raw' argument
% 	(Processes only the Oxy stage

if(nargout>0)

	varargout{1:nargout}=processFNIRS2(varargin{:},'SkipRaw',true);

else
	processFNIRS2(varargin{:},'SkipRaw',true);
end