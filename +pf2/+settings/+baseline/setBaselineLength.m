function setBaselineLength(baseline_length_in_seconds)
% SETBASELINELENGTH Set duration of baseline period for fNIRS normalization
%
% Configures the length of the baseline period used to normalize hemoglobin
% concentration data during processing. The baseline period starts at the
% baseline start time and extends for this duration. Mean values during the
% baseline period are subtracted from the signal to produce change-from-baseline
% measurements. This is a wrapper for the 'blLength' argument in processFNIRS2.
%
% Syntax:
%   pf2.settings.baseline.setBaselineLength(baseline_length_in_seconds)
%
% Inputs:
%   baseline_length_in_seconds - Duration of baseline period in seconds [double]
%                                Must be a positive numeric value.
%                                Set to 0 to use the global mean (entire signal)
%                                as baseline. Typical values: 5-30 seconds.
%
% Example:
%   % Set 10-second baseline
%   pf2.settings.baseline.setBaselineLength(10);
%
%   % Set 30-second baseline for longer rest periods
%   pf2.settings.baseline.setBaselineLength(30);
%
%   % Use global mean as baseline (equivalent to UseGlobalMean)
%   pf2.settings.baseline.setBaselineLength(0);
%
% Notes:
%   - The baseline period is defined by start time + length
%   - Ensure the baseline period falls within a rest/baseline condition
%   - Setting length to 0 uses the entire signal mean as baseline
%
% See also: pf2.settings.baseline.setBaselineStartTime,
%           pf2.settings.baseline.useGlobalMean, processFNIRS2

if(nargin<1||~isnumeric(baseline_length_in_seconds)||baseline_length_in_seconds<0)
	error('Please provide a valid baseline length');
end

processFNIRS2('blLength',baseline_length_in_seconds);