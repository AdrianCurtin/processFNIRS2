function varargout=plot(varargin)
% This function is a wrapper for processFNIRS2's main function

if(nargout>0)

	varargout{1:nargout}=pf2(varargin{:});

else
	pf2.probe.plot.showProbe3D(varargin{:});
end