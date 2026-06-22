function wcoef = fwtPO(x, L, qmf)
% FWTPO Forward periodized orthogonal discrete wavelet transform (1-D)
%
% Computes the periodized, orthogonal discrete wavelet transform of a 1-D
% signal of dyadic length n = 2^J using the Mallat fast cascade algorithm.
% At each scale the signal is split into low-pass approximation and
% high-pass detail bands by pf2_base.wavelet.downDyadLo / downDyadHi, and
% the cascade is iterated down to the coarsest level L. The output packs the
% coarse approximation in wc(1:2^L) and the detail band of scale j in
% wc(2^j+1 : 2^(j+1)), the standard contiguous dyadic layout.
%
% This is a clean-room implementation of the textbook periodized orthogonal
% forward DWT (Mallat 2009, section 7.3.1). It reproduces the column-vector
% / row-vector shape-preserving, dyadic, periodic-boundary conventions of
% the classical FWT_PO so that downstream code (kbWF, waveClean) is
% numerically unchanged.
%
% Syntax:
%   wc = pf2_base.wavelet.fwtPO(x, L, qmf)
%
% Inputs:
%   x   - 1-D signal of dyadic length n = 2^J [n x 1] or [1 x n] double.
%   L   - Coarsest scale of the approximation (V_L); 0 <= L < J. The number
%         of cascade stages is J - L.
%   qmf - Orthonormal quadrature mirror filter [1 x p] double, e.g. from
%         pf2_base.wavelet.makeONFilter. Usually length(qmf) < 2^(L+1).
%
% Outputs:
%   wc  - Wavelet transform of x [n x 1] or [1 x n] (shaped like x).
%         wc(1:2^L) holds the coarse approximation; wc(2^j+1:2^(j+1)) holds
%         the detail coefficients at scale j, for j = L..J-1.
%
% Example:
%   qmf = pf2_base.wavelet.makeONFilter('Daubechies', 8);
%   x   = randn(256, 1);
%   wc  = pf2_base.wavelet.fwtPO(x, 4, qmf);
%   xr  = pf2_base.wavelet.iwtPO(wc, 4, qmf);   % xr ~ x
%
% References:
%   Mallat, S. (2009). A Wavelet Tour of Signal Processing: The Sparse
%   Way (3rd ed.). Academic Press. DOI: 10.1016/B978-0-12-374370-1.X0001-8
%
% See also: pf2_base.wavelet.iwtPO, pf2_base.wavelet.makeONFilter,
%   pf2_base.wavelet.fwtTI

    [n, J] = dyadLength(x);
    wcoef = zeros(1, n);
    beta = x(:)';                       % finest-scale coefficients (row)
    for j = (J - 1):-1:L
        alfa = pf2_base.wavelet.downDyadHi(beta, qmf);
        wcoef(dyadIdx(j)) = alfa;
        beta = pf2_base.wavelet.downDyadLo(beta, qmf);
    end
    wcoef(1:(2^L)) = beta;

    % Match the shape (row/column) of the input.
    if size(x, 1) > 1
        wcoef = wcoef(:);
    end
end

% -------------------------------------------------------------------------
function [n, J] = dyadLength(x)
% Length n of x and J = ceil(log2(n)). Warns if n is not a power of two.
    n = length(x);
    J = ceil(log2(n));
    if 2^J ~= n
        warning('pf2_base:wavelet:fwtPO:notDyadic', ...
            'Signal length %d is not a power of two.', n);
    end
end

% -------------------------------------------------------------------------
function idx = dyadIdx(j)
% Linear indices of all wavelet coefficients at scale j.
    idx = (2^j + 1):(2^(j + 1));
end
