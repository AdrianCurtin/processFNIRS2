function varargout=process(varargin)
% This function is a wrapper for processFNIRS2's main function

if(nargout>0)

	varargout{1:nargout}=pf2(varargin{:});

else
	pf2(varargin{:});
end