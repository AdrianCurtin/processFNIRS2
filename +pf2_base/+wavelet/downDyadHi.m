function d = downDyadHi(x, qmf)
% DOWNDYADHI High-pass periodized downsampling operator
%
% Convolves a fine-scale 1-D signal with the high-pass (mirror) quadrature
% mirror filter using periodic (circular) boundary handling, then decimates
% by two, producing the detail coefficients of one level of the periodized
% orthogonal discrete wavelet transform.
%
% Clean-room implementation of the standard cascade-algorithm high-pass
% analysis step (Mallat 2009, section 7.3.1). The high-pass filter is the
% conjugate-mirror of the low-pass qmf: g(t) = (-1)^t h(t). The forward
% (iconv) periodic convolution with a left-circular-shift of the signal is
% used so the result is the orthogonal-transform detail band that
% pf2_base.wavelet.upDyadHi inverts exactly.
%
% Syntax:
%   d = pf2_base.wavelet.downDyadHi(x, qmf)
%
% Inputs:
%   x   - 1-D signal at the fine scale [1 x n] or [n x 1] double.
%   qmf - Orthonormal quadrature mirror filter (low-pass) [1 x p] double.
%
% Outputs:
%   d   - Detail coefficients [1 x n/2] double (row).
%
% Example:
%   qmf = pf2_base.wavelet.makeONFilter('Daubechies', 4);
%   dcoef = pf2_base.wavelet.downDyadHi(1:8, qmf);
%
% References:
%   Mallat, S. (2009). A Wavelet Tour of Signal Processing: The Sparse
%   Way (3rd ed.). Academic Press. DOI: 10.1016/B978-0-12-374370-1.X0001-8
%
% See also: pf2_base.wavelet.downDyadLo, pf2_base.wavelet.upDyadHi,
%   pf2_base.wavelet.fwtPO

    % Mirror filter g(t) = -(-1)^t h(t), forward periodic convolution with a
    % left-shifted signal, then keep the odd-indexed (decimated) samples.
    mf = pf2_base.wavelet.mirrorFilt(qmf);
    d = pf2_base.wavelet.fwdConv(mf, pf2_base.wavelet.lShift(x));
    n = length(d);
    d = d(1:2:(n - 1));
end
