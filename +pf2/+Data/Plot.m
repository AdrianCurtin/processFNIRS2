function [ varargout ] = Plot(fNIR,varargin)
% PLOT Automatically plot fNIRS data based on available fields
%
% Routes plotting to the appropriate specialized function based on what
% data is available in the fNIRS struct. If processed hemoglobin data
% (HbO) exists, calls Plot.Oxy; otherwise plots raw intensity data via
% Plot.Raw. This provides a convenient single entry point for quick
% visualization without needing to specify the data type.
%
% Syntax:
%   pf2.Data.Plot(fNIR)
%   pf2.Data.Plot(fNIR, Name, Value, ...)
%   figHandle = pf2.Data.Plot(fNIR, ...)
%
% Inputs:
%   fNIR     - fNIRS data structure [struct]
%              Must contain either 'HbO' field (processed data) or 'raw'
%              field (unprocessed intensity data).
%   varargin - Additional arguments passed to Plot.Oxy or Plot.Raw
%              See those functions for available options including
%              channels, markers, biomarkers, ylimits, and line properties.
%
% Outputs:
%   varargout - Figure handle(s) returned from the underlying plot function
%               [figure handle] Optional, only returned if requested.
%
% Example:
%   % Quick plot of raw data
%   data = pf2.Import.SampleData.fNIR2000();
%   pf2.Data.Plot(data);  % Plots raw intensity
%
%   % Quick plot of processed data
%   processed = processFNIRS2(data);
%   pf2.Data.Plot(processed);  % Plots HbO/HbR
%
%   % Pass options through to underlying function
%   pf2.Data.Plot(processed, 1:5, true, {'HbO'});  % Specific channels, with markers
%
% See also: pf2.Data.Plot.Oxy, pf2.Data.Plot.Raw, pf2.Data.Plot.ROI

if(nargin<1)
   error('Must provide an fNIR struct to plot'); 
end

if(isfield(fNIR,'HbO')&&~isempty(fNIR.HbO))
    if(nargout>0)
        varargout{1:nargout}=pf2.Data.Plot.Oxy(fNIR,varargin{:});
    else
        pf2.Data.Plot.Oxy(fNIR,varargin{:});
    end
elseif(isfield(fNIR,'raw')&&~isempty(fNIR.raw))
    if(nargout>0)
        varargout{1:nargout}=pf2.Data.Plot.Raw(fNIR,varargin{:});
    else
        pf2.Data.Plot.Raw(fNIR,varargin{:});
    end
end



end

