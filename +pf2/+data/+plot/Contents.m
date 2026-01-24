% pf2.data.plot - Time series visualization functions
% processFNIRS2 v0.8
%
% Plot Types:
%   oxy       - Plot hemoglobin concentration data (HbO, HbR, HbTotal, HbDiff)
%   raw       - Plot raw light intensity data
%   roi       - Plot ROI-averaged hemoglobin data
%   auxData   - Plot auxiliary temporal data (accelerometer, etc.)
%
% Example:
%   % Plot HbO and HbR
%   pf2.data.plot.oxy(processed);
%
%   % Plot specific channels with markers
%   pf2.data.plot.oxy(processed, [1 2 3], true, {'HbO', 'HbR'});
%
%   % Plot raw data
%   pf2.data.plot.raw(data, [], true);
%
% See also: pf2.data, pf2.probe.plot
