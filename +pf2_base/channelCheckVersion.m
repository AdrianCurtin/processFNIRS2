function v = channelCheckVersion()
% CHANNELCHECKVERSION Auto-select the channel check GUI version supported by MATLAB
%
% Returns the highest channel check GUI version that the running MATLAB
% installation can run. Version 2 (pf2.qc.ChannelCheck, App Designer) is
% preferred when the modern uifigure/uigridlayout stack is available
% (MATLAB R2018b+); otherwise version 1 (probeCheckGUI, legacy GUIDE) is
% used as the fallback.
%
% Syntax:
%   v = pf2_base.channelCheckVersion()
%
% Outputs:
%   v - Channel check GUI version [double]
%       1 = probeCheckGUI (legacy GUIDE)
%       2 = pf2.qc.ChannelCheck (App Designer)
%
% Algorithm:
%   Feature-tests for uigridlayout (R2018b+) and matlab.apps.AppBase. If
%   both are available the modern App Designer GUI is selected; otherwise
%   the legacy GUIDE GUI is selected. Result is cached per MATLAB session.
%
% Example:
%   v = pf2_base.channelCheckVersion();
%   fNIR = pf2_base.loadExistingMaskOrCheck(fNIR, filename, v);
%
% See also: pf2.qc.ChannelCheck, probeCheckGUI, pf2_base.loadExistingMaskOrCheck

    persistent cached
    if ~isempty(cached)
        v = cached;
        return;
    end

    hasGridLayout = ~isempty(which('uigridlayout'));
    hasAppBase = ~isempty(meta.class.fromName('matlab.apps.AppBase'));

    if hasGridLayout && hasAppBase
        cached = 2;
    else
        cached = 1;
    end
    v = cached;
end
