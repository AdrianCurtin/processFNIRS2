function varargout=pf2(varargin)
% This function is a wrapper for processFNIRS2's main function

if(nargout>0)

	varargout{1:nargout}=processFNIRS2(varargin{:});

else
	processFNIRS2(varargin{:});
end