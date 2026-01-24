% pf2.probe.plot - Topographic probe visualization functions
% processFNIRS2 v0.8
%
% 3D Visualization:
%   showProbe3D           - 3D brain surface with probe overlay
%   interpolateValues3D   - 3D interpolated values on brain surface
%
% 2D Topographic Maps:
%   interpolateValues     - 2D interpolated topographic map
%   imageValues           - 2D heatmap of channel values
%   arrangedValues        - Values displayed in probe arrangement
%
% ROI Visualization:
%   imageROIvalues        - Heatmap of ROI-averaged values
%   interpolateROIvalues  - Interpolated ROI values
%
% Example:
%   % 3D brain view
%   pf2.probe.plot.showProbe3D(processed);
%
%   % 2D interpolated topography at time index 500
%   pf2.probe.plot.interpolateValues(processed, 'HbO', 500);
%
%   % Heatmap
%   pf2.probe.plot.imageValues(processed, 'HbO', 500);
%
% See also: pf2.probe, pf2.data.plot
