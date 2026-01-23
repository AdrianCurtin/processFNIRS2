function useGlobalMean()
% USEGLOBALMEAN Use entire signal mean as baseline for fNIRS normalization
%
% Configures processing to use the mean of the entire signal as the baseline
% rather than a specific time window. This is useful when there is no clear
% rest period or when analyzing continuous data without a defined baseline.
% Equivalent to setting baseline length to 0 in processFNIRS2.
%
% Syntax:
%   pf2.settings.baseline.useGlobalMean()
%
% Example:
%   % Use global mean baseline
%   pf2.settings.baseline.useGlobalMean();
%
%   % Then process data
%   data = pf2.import.sampleData.fNIR2000();
%   processed = processFNIRS2(data);
%
% Notes:
%   - Global mean baseline may be appropriate for block designs
%   - For event-related designs, a specific baseline window is preferred
%   - This setting overrides any previous baseline length setting
%
% See also: pf2.settings.baseline.setBaselineLength,
%           pf2.settings.baseline.setBaselineStartTime, processFNIRS2

processFNIRS2('blLength',0);