function fNIR=editChannelMaskGUI(fNIR)
% EDITCHANNELMASKGUI Launch the interactive channel-quality mask editor
%
% Opens the probe channel-check GUI so a user can visually inspect each
% channel and toggle its quality flag in the fNIRS channel mask (fchMask).
% This is a thin wrapper around the underlying probeCheckGUI: it accepts an
% fNIRS struct, a saved channel-mask file path, or no argument at all, and
% returns the data with the edited mask applied.
%
% Syntax:
%   fNIR = pf2.data.editChannelMaskGUI(fNIR)
%   fNIR = pf2.data.editChannelMaskGUI(maskFilePath)
%   fNIR = pf2.data.editChannelMaskGUI()
%
% Inputs:
%   fNIR - One of the following [struct | char | string]:
%          - fNIRS data structure to inspect and edit interactively.
%          - Path to a saved channel-mask file (loads it into the GUI).
%          - Omitted: launches the GUI with an empty probe-check session.
%
% Outputs:
%   fNIR - fNIRS data structure with the updated .fchMask reflecting any
%          channels the user accepted or rejected in the GUI [struct].
%
% Example:
%   % Edit the channel mask for sample data interactively
%   data = pf2.import.sampleData.fNIR2000();
%   data = pf2.data.editChannelMaskGUI(data);
%
% Notes:
%   - This is an interactive GUI function and requires a display; it is not
%     suitable for headless/-batch sessions.
%
% See also: pf2.data.applyChannelMask, pf2.qc.ChannelCheck

%This is a wrapper for ProbeCheckGUI
if(nargin<1)
    fNIR=probeCheckGUI('probeCheck',''); 
elseif(isstruct(fNIR))
    fNIR=probeCheckGUI(fNIR);
elseif(ischar(fNIR)||isstring(fNIR))
   fNIR=probeCheckGUI('probeCheck',fNIR); 
end