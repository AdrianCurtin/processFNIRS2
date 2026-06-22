function x = iwtPO(wc, L, qmf)
% IWTPO Inverse periodized orthogonal discrete wavelet transform (1-D)
%
% Reconstructs a 1-D signal of dyadic length n = 2^J from its periodized
% orthogonal wavelet coefficients produced by pf2_base.wavelet.fwtPO. The
% Mallat fast cascade is run forward from the coarsest scale L to the
% finest: at each stage the running approximation is upsampled and low-pass
% synthesised (pf2_base.wavelet.upDyadLo) and added to the high-pass
% synthesis (pf2_base.wavelet.upDyadHi) of that scale's detail band.
%
% Clean-room implementation of the textbook periodized orthogonal inverse
% DWT (Mallat 2009, section 7.3.1). With an orthonormal qmf this is the
% exact inverse of fwtPO: iwtPO(fwtPO(x, L, qmf), L, qmf) == x to numerical
% precision. The dyadic, periodic-boundary, shape-preserving conventions of
% the classical IWT_PO are reproduced so downstream results are unchanged.
%
% Syntax:
%   x = pf2_base.wavelet.iwtPO(wc, L, qmf)
%
% Inputs:
%   wc  - Wavelet transform of length n = 2^J [n x 1] or [1 x n] double,
%         in the contiguous dyadic layout produced by fwtPO.
%   L   - Coarsest scale used in the forward transform (0 <= L < J).
%   qmf - Orthonormal quadrature mirror filter [1 x p] double.
%
% Outputs:
%   x   - Reconstructed 1-D signal [n x 1] or [1 x n] (shaped like wc).
%
% Example:
%   qmf = pf2_base.wavelet.makeONFilter('Symmlet', 8);
%   wc  = pf2_base.wavelet.fwtPO(randn(512, 1), 3, qmf);
%   x   = pf2_base.wavelet.iwtPO(wc, 3, qmf);
%
% References:
%   Mallat, S. (2009). A Wavelet Tour of Signal Processing: The Sparse
%   Way (3rd ed.). Academic Press. DOI: 10.1016/B978-0-12-374370-1.X0001-8
%
% See also: pf2_base.wavelet.fwtPO, pf2_base.wavelet.makeONFilter,
%   pf2_base.wavelet.iwtTI

    wcoef = wc(:)';                     % work as a row vector
    x = wcoef(1:2^L);                   % coarse approximation
    [~, J] = dyadLength(wcoef);
    for j = L:(J - 1)
        x = pf2_base.wavelet.upDyadLo(x, qmf) ...
            + pf2_base.wavelet.upDyadHi(wcoef(dyadIdx(j)), qmf);
    end

    % Match the shape (row/column) of the input coefficient vector.
    if size(wc, 1) > 1
        x = x(:);
    end
end

% -------------------------------------------------------------------------
function [n, J] = dyadLength(x)
% Length n of x and J = ceil(log2(n)). Warns if n is not a power of two.
    n = length(x);
    J = ceil(log2(n));
    if 2^J ~= n
        warning('pf2_base:wavelet:iwtPO:notDyadic', ...
            'Coefficient length %d is not a power of two.', n);
    end
end

% -------------------------------------------------------------------------
function idx = dyadIdx(j)
% Linear indices of all wavelet coefficients at scale j.
    idx = (2^j + 1):(2^(j + 1));
end
