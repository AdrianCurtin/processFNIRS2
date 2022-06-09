function [ varargout ] = showProbe3D(fNIR,varargin)
%processFNIRS.Probe.Plot.showProbe3D Provides a quick plot of the loaded
%probe on the head model


if(nargin<1)
   error('Must provide an fNIR struct to plot'); 
end

if(isfield(fNIR,'HbO')||isfield(fNIR,'raw'))
    if(nargout>0)
        varargout{1:nargout}=pf2.Probe.Plot.InterpolateValues3D([],fNIR,varargin{:});
    else
        pf2.Probe.Plot.InterpolateValues3D([],fNIR,varargin{:});
    end
end



end

