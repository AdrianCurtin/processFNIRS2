% pf2.settings.baseline - Baseline correction settings
% processFNIRS2 v0.8
%
% Baseline correction normalizes fNIRS signals to a reference period
% (typically at rest before task onset).
%
% Settings:
%   setBaselineStartTime  - Set baseline start time (seconds relative to t0)
%   setBaselineLength     - Set baseline duration (seconds)
%   useGlobalMean         - Use entire signal mean as baseline reference
%
% Example:
%   % Standard baseline: 0-10 seconds
%   pf2.settings.baseline.setBaselineStartTime(0);
%   pf2.settings.baseline.setBaselineLength(10);
%
%   % Use global mean (no specific baseline period)
%   pf2.settings.baseline.useGlobalMean();
%
% See also: pf2.settings, processFNIRS2
