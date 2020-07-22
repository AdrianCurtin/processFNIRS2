function varargout=ProcessRawOnly(varargin)
% This function is a wrapper for processFNIRS2's main function with the 'Skip Oxy' argument

if(nargout>0)

	varargout{1:nargout}=processFNIRS2(varargin{:},'SkipOxy',true);

else
	processFNIRS2(varargin{:},'SkipOxy',true);
end