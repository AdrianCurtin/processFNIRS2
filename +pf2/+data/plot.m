function [ varargout ] = plot(fNIR,varargin)
% PLOT Automatically plot fNIRS data based on available fields
%
% Routes plotting to the appropriate specialized function based on what
% data is available in the fNIRS struct. If processed hemoglobin data
% (HbO) exists, calls Plot.Oxy; otherwise plots raw intensity data via
% Plot.Raw. This provides a convenient single entry point for quick
% visualization without needing to specify the data type.
%
% Syntax:
%   pf2.data.plot(fNIR)
%   pf2.data.plot(fNIR, Name, Value, ...)
%   figHandle = pf2.data.plot(fNIR, ...)
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
%   data = pf2.import.sampleData.fNIR2000();
%   pf2.data.plot(data);  % Plots raw intensity
%
%   % Quick plot of processed data
%   processed = processFNIRS2(data);
%   pf2.data.plot(processed);  % Plots HbO/HbR
%
%   % Pass options through to underlying function
%   pf2.data.plot(processed, 1:5, true, {'HbO'});  % Specific channels, with markers
%
% See also: pf2.data.plot.oxy, pf2.data.plot.raw, pf2.data.plot.roi

if(nargin<1)
   error('pf2:data:plot:noInput', 'Must provide an fNIR struct to plot');
end

if(isfield(fNIR,'HbO')&&~isempty(fNIR.HbO))
    if(nargout>0)
        varargout{1:nargout}=pf2.data.plot.oxy(fNIR,varargin{:});
    else
        pf2.data.plot.oxy(fNIR,varargin{:});
    end
elseif(isfield(fNIR,'raw')&&~isempty(fNIR.raw))
    if(nargout>0)
        varargout{1:nargout}=pf2.data.plot.raw(fNIR,varargin{:});
    else
        pf2.data.plot.raw(fNIR,varargin{:});
    end
end



end

