function x = iwtTI(pkt, qmf)
% IWTTI Inverse translation-invariant (stationary) wavelet transform (1-D)
%
% Reconstructs a 1-D signal from the translation-invariant wavelet table
% produced by pf2_base.wavelet.fwtTI. At each stage the two shifted
% reconstructions (no-shift and the left-shift undo of the forward
% right-shift) of both the low-pass and high-pass synthesis are AVERAGED.
% This averaging over all circular shifts is exactly the cycle-spinning
% inverse that gives the transform its translation invariance.
%
% Clean-room implementation of the textbook translation-invariant inverse
% DWT (Mallat 2009, section 5.2). The coarsest scale L is inferred from the
% table width: L = J - D, where D = size(pkt,2) - 1 and J = log2(n). The
% averaging conventions are preserved exactly so motion-correction output
% is numerically unchanged.
%
% Syntax:
%   x = pf2_base.wavelet.iwtTI(tiwt, qmf)
%
% Inputs:
%   tiwt - Translation-invariant transform table [n x (D+1)] double from
%          pf2_base.wavelet.fwtTI.
%   qmf  - Orthonormal quadrature mirror filter [1 x p] double.
%
% Outputs:
%   x    - Reconstructed 1-D signal [1 x n] double (row).
%
% Example:
%   qmf  = pf2_base.wavelet.makeONFilter('Symmlet', 4);
%   tiwt = pf2_base.wavelet.fwtTI(randn(256, 1), 4, qmf);
%   x    = pf2_base.wavelet.iwtTI(tiwt, qmf);
%
% References:
%   Mallat, S. (2009). A Wavelet Tour of Signal Processing: The Sparse
%   Way (3rd ed.). Academic Press. DOI: 10.1016/B978-0-12-374370-1.X0001-8
%
% See also: pf2_base.wavelet.fwtTI, pf2_base.wavelet.makeONFilter,
%   pf2_base.wavelet.iwtPO

    [n, D1] = size(pkt);
    D = D1 - 1;

    wp = pkt;
    sig = wp(:, 1)';
    for d = (D - 1):-1:0
        for b = 0:(2^d - 1)
            hsr = wp(packetIdx(d + 1, 2 * b,     n), d + 2)';
            hsl = wp(packetIdx(d + 1, 2 * b + 1, n), d + 2)';
            lsr = sig(packetIdx(d + 1, 2 * b,     n));
            lsl = sig(packetIdx(d + 1, 2 * b + 1, n));
            loterm = (pf2_base.wavelet.upDyadLo(lsr, qmf) ...
                + pf2_base.wavelet.lShift(pf2_base.wavelet.upDyadLo(lsl, qmf))) / 2;
            hiterm = (pf2_base.wavelet.upDyadHi(hsr, qmf) ...
                + pf2_base.wavelet.lShift(pf2_base.wavelet.upDyadHi(hsl, qmf))) / 2;
            sig(packetIdx(d, b, n)) = loterm + hiterm;
        end
    end
    x = sig;
end

% -------------------------------------------------------------------------
function p = packetIdx(d, b, n)
% Linear indices of block b (0-based) at splitting depth d in a length-n
% packet table: the contiguous range of length n/2^d.
    npack = 2^d;
    p = (b * (n / npack) + 1):((b + 1) * n / npack);
end
