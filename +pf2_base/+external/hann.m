function w = hann(L, sflag)
% HANN Symmetric (or periodic) Hann (Hanning) window
%
% Returns an L-point Hann window, whose endpoints reach zero. Clean-room
% reimplementation so the toolbox does not require the Signal Processing
% Toolbox; interface-compatible with the Signal Processing Toolbox HANN.
%
% Syntax:
%   w = hann(L)
%   w = hann(L, sflag)
%
% Inputs:
%   L     - Window length (positive integer scalar).
%   sflag - 'symmetric' (default) or 'periodic'. The periodic form is the
%           one used for spectral analysis (Welch/coherence) so successive
%           segments tile without discontinuity.
%
% Outputs:
%   w - Hann window [L x 1 double].
%
% Algorithm:
%   Symmetric: w(n) = 0.5 - 0.5*cos(2*pi*n/(L-1)), n = 0..L-1.
%
% Reference:
%   Harris, F. J. (1978). On the use of windows for harmonic analysis with
%   the discrete Fourier transform. Proceedings of the IEEE, 66(1), 51-83.
%   DOI: 10.1109/PROC.1978.10837
%
% See also: hanning, hamming, pf2_base.external.genCosWin

if nargin < 2 || isempty(sflag)
    sflag = 'symmetric';
end

w = pf2_base.external.genCosWin(L, sflag, [0.5 0.5]);

end
