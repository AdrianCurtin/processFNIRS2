function [ varargout ] = showProbe3D(fNIR,varargin)
% SHOWPROBE3D Display fNIRS probe geometry on 3D brain surface
%
% Provides a quick visualization of the fNIRS probe optode positions overlaid
% on a 3D brain surface model. This is a convenience wrapper around
% InterpolateValues3D that displays probe geometry without data coloring.
% Useful for verifying probe placement and optode positions.
%
% Reference:
%   Internal pf2 implementation wrapping InterpolateValues3D.
%
% Syntax:
%   showProbe3D(fNIR)
%   showProbe3D(fNIR, Name, Value, ...)
%   h = showProbe3D(...)
%   [h, imgOut] = showProbe3D(...)
%
% Inputs:
%   fNIR     - fNIRS data structure containing probe geometry information
%              Must have 'HbO' or 'raw' field to confirm valid structure.
%   varargin - Additional name-value pairs passed to InterpolateValues3D
%              See InterpolateValues3D for full list of options including:
%              'initCamPosition', 'ChannelLabels', 'SDLabels', etc.
%
% Outputs:
%   varargout{1} - Handle to the axes (h)
%   varargout{2} - RGB image capture of the figure (imgOut) [H x W x 3 uint8]
%
% Example:
%   % Display probe on brain surface
%   data = pf2.Import.SampleData.fNIR2000();
%   processed = processFNIRS2(data);
%   pf2.Probe.Plot.showProbe3D(processed);
%
%   % View from different angle
%   pf2.Probe.Plot.showProbe3D(processed, 'initCamPosition', 'top');
%
%   % Show source/detector labels
%   pf2.Probe.Plot.showProbe3D(processed, 'SDLabels', true);
%
% See also: pf2.Probe.Plot.InterpolateValues3D, pf2.Probe.Plot.InterpolateValues,
%           pf2.Probe.Plot.ArrangedValues, pf2.Settings.SelectDevice


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

