function tf = isOctave()
% ISOCTAVE Return true when running under GNU Octave instead of MATLAB
%
% Single-point runtime check used to gate MATLAB-only features (App Designer
% GUIs, GUIDE dispatch, fitlme group statistics) and to select compatible
% code paths in the headless processing pipeline. The result is constant for
% the life of a session and is cached on first call.
%
% Reference:
%   Internal pf2 implementation. Standard detection idiom per the GNU Octave
%   FAQ: the OCTAVE_VERSION built-in exists only under Octave.
%
% Syntax:
%   tf = pf2_base.env.isOctave()
%
% Inputs:
%   (none)
%
% Outputs:
%   tf - Logical scalar. True when the host interpreter is GNU Octave,
%        false when it is MATLAB.
%
% Example:
%   % Gate a MATLAB-only feature
%   if pf2_base.env.isOctave()
%       error('pf2:gui:octaveUnsupported', 'GUI requires MATLAB.');
%   end
%
% See also: pf2_base.env.runtime

    persistent cached
    if isempty(cached)
        cached = (exist('OCTAVE_VERSION', 'builtin') ~= 0);
    end
    tf = cached;
end
