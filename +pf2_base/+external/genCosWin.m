function w = genCosWin(L, sflag, coeffs)
% GENCOSWIN Generalized cosine window generator (shared window backend)
%
% Builds a generalized cosine window of the form
%   w(n) = a0 - a1*cos(2*pi*n/N) + a2*cos(4*pi*n/N) - ...
% for the Hamming/Hann family. Internal helper so the toolbox-free window
% functions (hamming, hann, hanning) share one numerically careful core and
% need no Signal Processing Toolbox.
%
% Syntax:
%   w = genCosWin(L, sflag, coeffs)
%
% Inputs:
%   L      - Window length (non-negative integer scalar).
%   sflag  - 'symmetric' (default form for FIR design) or 'periodic'
%            (length-(L+1) symmetric window truncated to L points).
%   coeffs - Cosine-series coefficients [a0 a1 a2 ...]. Two coefficients
%            cover the Hamming (0.54/0.46) and Hann (0.5/0.5) windows.
%
% Outputs:
%   w - Window samples [L x 1 double].
%
% Algorithm:
%   For the symmetric case the cosine arguments span 0..2*pi over N = L-1
%   points; the periodic case uses N = L so the window tiles seamlessly. The
%   first coefficient is the DC term; subsequent coefficients alternate sign.
%
% Reference:
%   Harris, F. J. (1978). On the use of windows for harmonic analysis with
%   the discrete Fourier transform. Proceedings of the IEEE, 66(1), 51-83.
%   DOI: 10.1109/PROC.1978.10837
%
% Example:
%   % Build a 64-point Hamming window from its cosine coefficients.
%   w = pf2_base.external.genCosWin(64, 'symmetric', [0.54 0.46]);
%
% See also: hamming, hann, hanning

if nargin < 2 || isempty(sflag)
    sflag = 'symmetric';
end

if ~(isscalar(L) && L == floor(L) && L >= 0)
    error('pf2_base:genCosWin:badLength', 'Window length must be a non-negative integer.');
end

if L == 0
    w = zeros(0, 1);
    return;
end
if L == 1
    w = 1;
    return;
end

isPeriodic = strcmpi(sflag, 'periodic');
if isPeriodic
    N = L;            % periodic: sample the length-(L+1) symmetric window
else
    N = L - 1;        % symmetric about the midpoint
end

n = (0:L-1).';
w = coeffs(1) * ones(L, 1);
for m = 2:numel(coeffs)
    w = w + ((-1)^(m-1)) * coeffs(m) * cos(2*pi*(m-1)*n / N);
end

end
