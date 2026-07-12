function wp = fwtTI(x, L, qmf)
% FWTTI Forward translation-invariant (stationary) wavelet transform (1-D)
%
% Computes the translation-invariant (undecimated / cycle-spinning)
% orthogonal wavelet transform of a 1-D signal of dyadic length n = 2^J.
% Unlike the decimated transform, at every cascade stage BOTH the original
% and a one-sample circular shift of each block are filtered and retained,
% so the representation is invariant to translations of the input. The
% result is the classical stationary-wavelet packet-style table.
%
% Clean-room implementation of the textbook translation-invariant DWT
% (Mallat 2009, section 5.2 — translation-invariant / cycle-spinning
% wavelet representations; cascade per section 7.3.1). The output table
% layout is preserved exactly so that pf2_MotionCorrectWavelet, which
% indexes the table by block within each level/column, is numerically
% unchanged.
%
% Output layout (this is load-bearing — match it exactly):
%   wp is [n x (D+1)] where D = J - L.
%   - Column 1 holds, after all stages, the coarse low-pass blocks: at the
%     deepest stage the 2^D shifted approximations of length n/2^D are laid
%     end to end (block b occupies rows packet(D,b,n)).
%   - Column d+2 holds the detail coefficients produced at stage d
%     (d = 0..D-1): the 2^(d+1) shifted detail blocks of length n/2^(d+1)
%     laid end to end (block 2b is the no-shift result, block 2b+1 the
%     right-shifted result).
%
% Syntax:
%   tiwt = pf2_base.wavelet.fwtTI(x, L, qmf)
%
% Inputs:
%   x   - 1-D signal of dyadic length n = 2^J [n x 1] or [1 x n] double.
%   L   - Coarsest scale (degree of coarsest level); 0 <= L < J. The number
%         of stages is D = J - L.
%   qmf - Orthonormal quadrature mirror filter [1 x p] double.
%
% Outputs:
%   tiwt - Translation-invariant transform table [n x (J-L+1)] double.
%
% Example:
%   qmf  = pf2_base.wavelet.makeONFilter('Daubechies', 4);
%   tiwt = pf2_base.wavelet.fwtTI(randn(256, 1), 4, qmf);
%   xr   = pf2_base.wavelet.iwtTI(tiwt, qmf);   % xr ~ x
%
% References:
%   Mallat, S. (2009). A Wavelet Tour of Signal Processing: The Sparse
%   Way (3rd ed.). Academic Press. DOI: 10.1016/B978-0-12-374370-1.X0001-8
%
% See also: pf2_base.wavelet.iwtTI, pf2_base.wavelet.makeONFilter,
%   pf2_base.wavelet.fwtPO

    [n, J] = dyadLength(x);
    D = J - L;
    wp = zeros(n, D + 1);
    x = x(:)';                          % row vector

    wp(:, 1) = x';
    for d = 0:(D - 1)
        for b = 0:(2^d - 1)
            s   = wp(packetIdx(d, b, n), 1)';
            hsr = pf2_base.wavelet.downDyadHi(s, qmf);
            hsl = pf2_base.wavelet.downDyadHi(pf2_base.wavelet.rShift(s), qmf);
            lsr = pf2_base.wavelet.downDyadLo(s, qmf);
            lsl = pf2_base.wavelet.downDyadLo(pf2_base.wavelet.rShift(s), qmf);
            wp(packetIdx(d + 1, 2 * b,     n), d + 2) = hsr';
            wp(packetIdx(d + 1, 2 * b + 1, n), d + 2) = hsl';
            wp(packetIdx(d + 1, 2 * b,     n), 1)     = lsr';
            wp(packetIdx(d + 1, 2 * b + 1, n), 1)     = lsl';
        end
    end
end

% -------------------------------------------------------------------------
function [n, J] = dyadLength(x)
% Length n of x and J = ceil(log2(n)). Warns if n is not a power of two.
    n = length(x);
    J = ceil(log2(n));
    if 2^J ~= n
        warning('pf2_base:wavelet:fwtTI:notDyadic', ...
            'Signal length %d is not a power of two.', n);
    end
end

% -------------------------------------------------------------------------
function p = packetIdx(d, b, n)
% Linear indices of block b (0-based) at splitting depth d in a length-n
% packet table: the contiguous range of length n/2^d.
    npack = 2^d;
    p = (b * (n / npack) + 1):((b + 1) * n / npack);
end
