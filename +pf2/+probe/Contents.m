% pf2.probe - Probe geometry and visualization
% processFNIRS2 v0.8
%
% Visualization (auto-detect):
%   plot              - Auto-select best visualization (3D, 2D, or arranged)
%
% Subpackages:
%   +plot             - Specific probe visualization functions
%   +roi              - Region of Interest management
%
% Plot Subpackage (pf2.probe.plot.*):
%   showProbe3D           - 3D brain surface visualization
%   interpolateValues     - 2D interpolated topographic map
%   interpolateValues3D   - 3D interpolated visualization
%   imageValues           - 2D channel heatmap
%   arrangedValues        - Values in probe arrangement
%   imageROIvalues        - ROI-based heatmap
%   interpolateROIvalues  - ROI-based interpolated map
%
% ROI Subpackage (pf2.probe.roi.*):
%   defineROI         - Interactive ROI definition GUI
%
% Example:
%   % Auto-select visualization
%   pf2.probe.plot(processed);
%
%   % Specific visualization
%   pf2.probe.plot.showProbe3D(processed);
%   pf2.probe.plot.interpolateValues(processed, 'HbO', 500);
%
%   % Define ROIs
%   pf2.probe.roi.defineROI(data);
%
% See also: pf2.data.plot, processFNIRS2
