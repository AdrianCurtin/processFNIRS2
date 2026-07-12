function w = hamming(L, sflag)
% HAMMING Symmetric (or periodic) Hamming window
%
% Returns an L-point Hamming window. This is a clean-room reimplementation
% provided so the toolbox does not depend on the Signal Processing Toolbox;
% it is used by pf2_base.external.fir1 as the default FIR design window and is
% interface-compatible with the Signal Processing Toolbox HAMMING.
%
% Syntax:
%   w = hamming(L)
%   w = hamming(L, sflag)
%
% Inputs:
%   L     - Window length (positive integer scalar).
%   sflag - Sampling flag: 'symmetric' (default) yields a window symmetric
%           about its midpoint (the form used for FIR design); 'periodic'
%           yields the L-point periodic extension used for spectral analysis.
%
% Outputs:
%   w - Hamming window [L x 1 double].
%
% Algorithm:
%   The symmetric window of length L is
%       w(n) = 0.54 - 0.46*cos(2*pi*n/(L-1)),  n = 0..L-1.
%   The periodic window is the first L points of the length-(L+1) symmetric
%   window.
%
% Reference:
%   Harris, F. J. (1978). On the use of windows for harmonic analysis with
%   the discrete Fourier transform. Proceedings of the IEEE, 66(1), 51-83.
%   DOI: 10.1109/PROC.1978.10837
%
% See also: hann, hanning, fir1, pf2_base.external.fir1

if nargin < 2 || isempty(sflag)
    sflag = 'symmetric';
end

w = pf2_base.external.genCosWin(L, sflag, [0.54 0.46]);

end
