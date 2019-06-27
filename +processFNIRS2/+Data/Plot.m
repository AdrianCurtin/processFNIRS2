function [ varargout ] = Plot(fNIR,varargin)
%processFNIRS.Data.Plot Provides a quick plot of the fnirs data
%   Triages whether or not to autoplot Oxy or Raw data
%   and passes them to Plot.Raw and Plot.Oxy respectively

%mask=true;

if(nargin<1)
   error('Must provide an fNIR struct to plot'); 
end

if(isfield(fNIR,'HbO')&&~isempty(fNIR.HbO))
    if(nargout>0)
        varargout{1:nargout}=processFNIRS2.Data.Plot.Oxy(fNIR,varargin{:});
    else
        processFNIRS2.Data.Plot.Oxy(fNIR,varargin{:});
    end
elseif(isfield(fNIR,'raw')&&~isempty(fNIR.raw))
    if(nargout>0)
        varargout{1:nargout}=processFNIRS2.Data.Plot.Raw(fNIR,varargin{:});
    else
        processFNIRS2.Data.Plot.Raw(fNIR,varargin{:});
    end
end



end

