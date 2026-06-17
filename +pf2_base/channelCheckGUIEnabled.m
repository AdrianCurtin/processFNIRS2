function out = channelCheckGUIEnabled(val)
% CHANNELCHECKGUIENABLED Get/set whether the channel-check GUI may be shown
%
% Session-scoped switch that lets callers (notably automated tests) force the
% interactive channel-quality GUI off without relying on display detection.
% When disabled, import code that would otherwise launch probeCheckGUI /
% pf2.qc.ChannelCheck instead falls back to a saved mask or an all-good
% default. Defaults to enabled (true).
%
% Syntax:
%   tf  = pf2_base.channelCheckGUIEnabled()        % query current setting
%   pf2_base.channelCheckGUIEnabled(false)         % disable (e.g. in tests)
%   old = pf2_base.channelCheckGUIEnabled(false)   % set and return prior value
%
% Inputs:
%   val - (optional) Logical scalar to set the flag.
%
% Outputs:
%   out - The current flag value (the PRIOR value when setting), so callers
%         can save and restore it around a block.
%
% Algorithm:
%   Stores the flag in a persistent variable initialized to true. With an
%   argument, records and overwrites the flag, returning the previous value;
%   with no argument, returns the current value.
%
% Example:
%   prev = pf2_base.channelCheckGUIEnabled(false);
%   c = onCleanup(@() pf2_base.channelCheckGUIEnabled(prev));
%   data = pf2.import.sampleData();   % no GUI even on a display
%
% See also: pf2_base.allowChannelCheckGUI, pf2_base.isHeadless,
%           pf2_base.loadExistingMaskOrCheck

    persistent flag
    if isempty(flag)
        flag = true;
    end

    out = flag;
    if nargin > 0
        flag = logical(val);
    end
end
