% pf2.data - Data manipulation and visualization
% processFNIRS2 v0.8
%
% Plotting (auto-detect):
%   plot              - Auto-select plot type based on data (oxy or raw)
%
% Subpackages:
%   +plot             - Specific plot types (oxy, raw, roi, auxData)
%
% Time/Channel Operations:
%   setT0             - Shift time reference point
%   applyChannelMask  - Apply channel mask (mark bad channels as NaN)
%   resample          - Resample data or average over time windows
%   split             - Split data by timepoints
%   getMarkers        - Extract event markers (supports regex patterns)
%
% Concatenation:
%   concatenate           - Join fNIRS segments vertically (time)
%   concatenateHorizontal - Join fNIRS segments horizontally (channels)
%
% GUI Tools:
%   editChannelMaskGUI    - Interactive channel mask editor
%
% Plot Subpackage (pf2.data.plot.*):
%   oxy               - Plot hemoglobin data (HbO, HbR, etc.)
%   raw               - Plot raw intensity data
%   roi               - Plot ROI-averaged data
%   auxData           - Plot auxiliary temporal data
%
% Example:
%   % Auto-detect plot type
%   pf2.data.plot(processed);
%
%   % Plot specific biomarker
%   pf2.data.plot.oxy(processed, [], true, {'HbO', 'HbR'});
%
%   % Data manipulation
%   shifted = pf2.data.setT0(data, 'T0', 5);
%   markers = pf2.data.getMarkers(data, 'pattern', 'stim.*');
%   resampled = pf2.data.resample(data, 'rate', 2);
%
% See also: pf2.probe.plot, processFNIRS2
