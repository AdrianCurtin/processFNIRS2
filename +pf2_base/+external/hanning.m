function w = hanning(L, sflag)
% HANNING Symmetric (or periodic) Hanning window (non-zero endpoints)
%
% Returns an L-point Hanning window. Unlike HANN, the symmetric HANNING
% window omits the zero-valued endpoints (its first and last samples are
% non-zero). Clean-room reimplementation so the toolbox does not require the
% Signal Processing Toolbox; interface-compatible with the Signal Processing
% Toolbox HANNING.
%
% Syntax:
%   w = hanning(L)
%   w = hanning(L, sflag)
%
% Inputs:
%   L     - Window length (positive integer scalar).
%   sflag - 'symmetric' (default) or 'periodic'.
%
% Outputs:
%   w - Hanning window [L x 1 double].
%
% Algorithm:
%   Symmetric: w(k) = 0.5*(1 - cos(2*pi*k/(L+1))), k = 1..L (interior points
%   of the raised cosine, so the endpoints are non-zero). Periodic: the
%   first L points of HANN(L+1).
%
% Reference:
%   Harris, F. J. (1978). On the use of windows for harmonic analysis with
%   the discrete Fourier transform. Proceedings of the IEEE, 66(1), 51-83.
%   DOI: 10.1109/PROC.1978.10837
%
% See also: hann, hamming

if nargin < 2 || isempty(sflag)
    sflag = 'symmetric';
end

if ~(isscalar(L) && L == floor(L) && L >= 0)
    error('pf2_base:hanning:badLength', 'Window length must be a non-negative integer.');
end

if L == 0
    w = zeros(0, 1);
    return;
end
if L == 1
    w = 1;
    return;
end

if strncmpi(sflag, 'periodic', numel(sflag))
    % Periodic: first L points of the length-(L+1) HANN window.
    full = pf2_base.external.hann(L + 1, 'symmetric');
    w = full(1:L);
else
    k = (1:L).';
    w = 0.5 * (1 - cos(2*pi*k / (L + 1)));
end

end
