function y = upSample(x, s)
% UPSAMPLE Insert zeros between samples (dyadic upsampling)
%
% Expands a 1-D signal by factor s (default 2) by placing the original
% samples at every s-th position and zeros elsewhere:
% y(s*i - (s-1)) = x(i). This is the zero-interpolation step of the inverse
% discrete wavelet transform synthesis filters (Mallat 2009, section 7.3).
%
% Clean-room implementation.
%
% Syntax:
%   y = pf2_base.wavelet.upSample(x)
%   y = pf2_base.wavelet.upSample(x, s)
%
% Inputs:
%   x - 1-D signal [1 x n] double.
%   s - Upsampling factor (optional scalar, default 2).
%
% Outputs:
%   y - Upsampled signal [1 x s*n] double (row), zeros interpolated.
%
% Example:
%   y = pf2_base.wavelet.upSample([1 2 3]);   % [1 0 2 0 3 0]
%
% References:
%   Mallat, S. (2009). A Wavelet Tour of Signal Processing: The Sparse
%   Way (3rd ed.). Academic Press. DOI: 10.1016/B978-0-12-374370-1.X0001-8
%
% See also: pf2_base.wavelet.upDyadLo, pf2_base.wavelet.upDyadHi

    if nargin == 1
        s = 2;
    end
    n = length(x) * s;
    y = zeros(1, n);
    y(1:s:(n - s + 1)) = x;
end
