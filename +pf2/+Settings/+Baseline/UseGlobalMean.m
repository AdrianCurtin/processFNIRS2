function UseGlobalMean()
% USEGLOBALMEAN Use entire signal mean as baseline for fNIRS normalization
%
% Configures processing to use the mean of the entire signal as the baseline
% rather than a specific time window. This is useful when there is no clear
% rest period or when analyzing continuous data without a defined baseline.
% Equivalent to setting baseline length to 0 in processFNIRS2.
%
% Syntax:
%   pf2.Settings.Baseline.UseGlobalMean()
%
% Example:
%   % Use global mean baseline
%   pf2.Settings.Baseline.UseGlobalMean();
%
%   % Then process data
%   data = pf2.Import.SampleData.fNIR2000();
%   processed = processFNIRS2(data);
%
% Notes:
%   - Global mean baseline may be appropriate for block designs
%   - For event-related designs, a specific baseline window is preferred
%   - This setting overrides any previous baseline length setting
%
% See also: pf2.Settings.Baseline.SetBaselineLength,
%           pf2.Settings.Baseline.SetBaselineStartTime, processFNIRS2

processFNIRS2('blLength',0);