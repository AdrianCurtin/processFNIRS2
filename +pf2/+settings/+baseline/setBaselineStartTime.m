function setBaselineStartTime(time_relative_to_start_in_seconds)
% SETBASELINESTARTTIME Set start time of baseline period for fNIRS normalization
%
% Configures the start time of the baseline period used to normalize hemoglobin
% concentration data during processing. The baseline period extends from this
% start time for the duration specified by SetBaselineLength. This is a wrapper
% for the 'blStartTime' argument in processFNIRS2.
%
% Syntax:
%   pf2.settings.baseline.setBaselineStartTime(time_relative_to_start_in_seconds)
%
% Inputs:
%   time_relative_to_start_in_seconds - Start time of baseline relative to
%                                       data start or t0 in seconds [double]
%                                       Must be a non-negative numeric value.
%                                       (default: 0, baseline starts at t0)
%
% Example:
%   % Start baseline at time 0 (beginning of recording)
%   pf2.settings.baseline.setBaselineStartTime(0);
%
%   % Start baseline 5 seconds into recording (skip initial artifacts)
%   pf2.settings.baseline.setBaselineStartTime(5);
%
%   % Configure complete baseline: 5-15 seconds
%   pf2.settings.baseline.setBaselineStartTime(5);
%   pf2.settings.baseline.setBaselineLength(10);
%
% Notes:
%   - Time is relative to the data start or the t0 reference point
%   - Ensure the baseline period falls within a rest/baseline condition
%   - Combined with SetBaselineLength to define the complete baseline window
%
% See also: pf2.settings.baseline.setBaselineLength,
%           pf2.settings.baseline.useGlobalMean, pf2.data.setT0, processFNIRS2

if(nargin<1||~isnumeric(time_relative_to_start_in_seconds)||time_relative_to_start_in_seconds<0)
	error('Please provide a valid baseline start time');
end

processFNIRS2('blStartTime',time_relative_to_start_in_seconds);