function y = upDyadHi(x, qmf)
% UPDYADHI High-pass periodized upsampling (synthesis) operator
%
% Upsamples a coarse-scale 1-D signal by two (inserting zeros) and convolves
% with the high-pass (mirror) quadrature mirror filter using periodic
% boundary handling, producing the detail (high-pass) contribution to the
% next finer scale in the inverse periodized orthogonal discrete wavelet
% transform.
%
% Clean-room implementation of the cascade-algorithm high-pass synthesis
% step (Mallat 2009, section 7.3.1). Zero-interpolation upsampling, a
% right-circular-shift, and an adjoint periodic convolution with the mirror
% filter form the orthogonal-transform adjoint of
% pf2_base.wavelet.downDyadHi, giving perfect reconstruction.
%
% Syntax:
%   y = pf2_base.wavelet.upDyadHi(x, qmf)
%
% Inputs:
%   x   - 1-D detail signal at the coarse scale [1 x n] or [n x 1] double.
%   qmf - Orthonormal quadrature mirror filter (low-pass) [1 x p] double.
%
% Outputs:
%   y   - High-pass synthesized signal at the finer scale [1 x 2n] double.
%
% Example:
%   qmf = pf2_base.wavelet.makeONFilter('Daubechies', 4);
%   y   = pf2_base.wavelet.upDyadHi([1 2 3 4], qmf);
%
% References:
%   Mallat, S. (2009). A Wavelet Tour of Signal Processing: The Sparse
%   Way (3rd ed.). Academic Press. DOI: 10.1016/B978-0-12-374370-1.X0001-8
%
% See also: pf2_base.wavelet.upDyadLo, pf2_base.wavelet.downDyadHi,
%   pf2_base.wavelet.iwtPO

    mf = pf2_base.wavelet.mirrorFilt(qmf);
    y = pf2_base.wavelet.adjConv(mf, ...
        pf2_base.wavelet.rShift(pf2_base.wavelet.upSample(x)));
end
