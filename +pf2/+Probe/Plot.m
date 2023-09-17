function varargout=Plot(varargin)
% This function is a wrapper for processFNIRS2's main function

if(nargout>0)

	varargout{1:nargout}=pf2(varargin{:});

else
	pf2.Probe.Plot.showProbe3D(varargin{:});
end