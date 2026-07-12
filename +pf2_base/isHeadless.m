function tf = isHeadless()
% ISHEADLESS True when MATLAB is running without an interactive display
%
% Reports whether the current session is non-interactive (started with
% -batch / -nodisplay / -nodesktop, or otherwise lacking the Java desktop).
% Use it to gate blocking UI: code that would open a modal/figure GUI should
% fall back to a non-interactive default when this returns true, so automated
% runs (CI, -batch tests) never hang waiting on a window that cannot appear.
%
% Syntax:
%   tf = pf2_base.isHeadless()
%
% Outputs:
%   tf - Logical scalar; true when no interactive display is available.
%
% Algorithm:
%   Treats the session as headless if MATLAB was started with -batch
%   (batchStartupOptionUsed, R2019a+) or the Java desktop is unavailable
%   (~usejava('desktop')). Both probes are wrapped defensively so the helper
%   never errors on older releases or unusual configurations.
%
% Example:
%   if pf2_base.isHeadless()
%       fNIR.fchMask = ones(1, fNIR.device.nChannels);  % skip the GUI
%   else
%       fNIR = probeCheckGUI(fNIR, filename);
%   end
%
% See also: pf2_base.loadExistingMaskOrCheck, pf2.qc.ChannelCheck

    tf = false;

    % -batch sessions: explicit non-interactive startup
    try
        if exist('batchStartupOptionUsed', 'builtin') == 5 || ...
                exist('batchStartupOptionUsed', 'file') == 2
            if batchStartupOptionUsed()
                tf = true;
                return;
            end
        end
    catch
    end

    % No Java desktop (-nodisplay / -nodesktop / no GUI environment)
    try
        if ~usejava('desktop')
            tf = true;
        end
    catch
    end
end
