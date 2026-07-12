function y = upDyadLo(x, qmf)
% UPDYADLO Low-pass periodized upsampling (synthesis) operator
%
% Upsamples a coarse-scale 1-D signal by two (inserting zeros) and convolves
% with the low-pass quadrature mirror filter using periodic boundary
% handling, producing the low-pass contribution to the next finer scale in
% the inverse periodized orthogonal discrete wavelet transform.
%
% Clean-room implementation of the cascade-algorithm low-pass synthesis
% step (Mallat 2009, section 7.3.1). The zero-interpolation upsampling
% followed by forward periodic convolution is the orthogonal-transform
% adjoint of pf2_base.wavelet.downDyadLo, giving perfect reconstruction.
%
% Syntax:
%   y = pf2_base.wavelet.upDyadLo(x, qmf)
%
% Inputs:
%   x   - 1-D signal at the coarse scale [1 x n] or [n x 1] double.
%   qmf - Orthonormal quadrature mirror filter (low-pass) [1 x p] double.
%
% Outputs:
%   y   - Low-pass synthesized signal at the finer scale [1 x 2n] double.
%
% Example:
%   qmf = pf2_base.wavelet.makeONFilter('Daubechies', 4);
%   y   = pf2_base.wavelet.upDyadLo([1 2 3 4], qmf);
%
% References:
%   Mallat, S. (2009). A Wavelet Tour of Signal Processing: The Sparse
%   Way (3rd ed.). Academic Press. DOI: 10.1016/B978-0-12-374370-1.X0001-8
%
% See also: pf2_base.wavelet.upDyadHi, pf2_base.wavelet.downDyadLo,
%   pf2_base.wavelet.iwtPO

    y = pf2_base.wavelet.fwdConv(qmf, pf2_base.wavelet.upSample(x));
end
