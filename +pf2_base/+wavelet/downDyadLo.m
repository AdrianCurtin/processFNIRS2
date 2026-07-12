function d = downDyadLo(x, qmf)
% DOWNDYADLO Low-pass periodized downsampling operator
%
% Convolves a fine-scale 1-D signal with the low-pass quadrature mirror
% filter using periodic (circular) boundary handling, then decimates by
% two, producing the coarse-scale approximation coefficients of one
% level of the periodized orthogonal discrete wavelet transform.
%
% This is a clean-room implementation of the standard cascade-algorithm
% low-pass analysis step described in Mallat (2009), section 7.3.1.
% The periodic-convolution / time-reverse-filter (adjoint convolution)
% convention is preserved so that the decomposition is orthogonal and
% perfectly invertible by pf2_base.wavelet.upDyadLo / upDyadHi.
%
% Syntax:
%   d = pf2_base.wavelet.downDyadLo(x, qmf)
%
% Inputs:
%   x   - 1-D signal at the fine scale [1 x n] or [n x 1] double.
%   qmf - Orthonormal quadrature mirror filter (low-pass) [1 x p] double,
%         e.g. from pf2_base.wavelet.makeONFilter.
%
% Outputs:
%   d   - Coarse-scale approximation coefficients [1 x n/2] double (row).
%
% Example:
%   qmf = pf2_base.wavelet.makeONFilter('Daubechies', 4);
%   a   = pf2_base.wavelet.downDyadLo(1:8, qmf);
%
% References:
%   Mallat, S. (2009). A Wavelet Tour of Signal Processing: The Sparse
%   Way (3rd ed.). Academic Press. DOI: 10.1016/B978-0-12-374370-1.X0001-8
%
% See also: pf2_base.wavelet.downDyadHi, pf2_base.wavelet.upDyadLo,
%   pf2_base.wavelet.fwtPO

    % Adjoint (time-reversed filter) periodic convolution, then keep the
    % odd-indexed samples — the standard low-pass analysis decimation.
    d = pf2_base.wavelet.adjConv(qmf, x);
    n = length(d);
    d = d(1:2:(n - 1));
end
