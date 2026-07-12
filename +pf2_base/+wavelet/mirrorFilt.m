function y = mirrorFilt(x)
% MIRRORFILT Conjugate-mirror modulation of a filter
%
% Applies the alternating-sign modulation y(t) = -(-1)^t x(t) that converts
% a low-pass quadrature mirror filter into its high-pass conjugate mirror
% (and vice versa), shifting DC frequency content to the Nyquist frequency.
% This is the standard wavelet high-pass filter construction g(t) used in
% the discrete wavelet transform (Mallat 2009, section 7.3).
%
% Clean-room implementation.
%
% Syntax:
%   y = pf2_base.wavelet.mirrorFilt(x)
%
% Inputs:
%   x - 1-D filter or signal [1 x n] double.
%
% Outputs:
%   y - Modulated filter, y(t) = -(-1)^t x(t), same size as x.
%
% Example:
%   g = pf2_base.wavelet.mirrorFilt([1 1]/sqrt(2));
%
% References:
%   Mallat, S. (2009). A Wavelet Tour of Signal Processing: The Sparse
%   Way (3rd ed.). Academic Press. DOI: 10.1016/B978-0-12-374370-1.X0001-8
%
% See also: pf2_base.wavelet.downDyadHi, pf2_base.wavelet.upDyadHi

    y = -((-1) .^ (1:length(x))) .* x;
end
