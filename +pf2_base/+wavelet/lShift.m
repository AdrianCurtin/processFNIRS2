function y = lShift(x)
% LSHIFT Circular left shift of a 1-D signal
%
% Rotates a 1-D signal one sample toward lower indices, wrapping the first
% sample to the end: y(i) = x(i+1), y(n) = x(1). Used by the high-pass
% analysis filter of the periodized discrete wavelet transform to realise
% the correct phase alignment (Mallat 2009, section 7.3).
%
% Clean-room implementation.
%
% Syntax:
%   y = pf2_base.wavelet.lShift(x)
%
% Inputs:
%   x - 1-D signal [1 x n] double (row).
%
% Outputs:
%   y - Left-shifted signal [1 x n] double (row).
%
% Example:
%   y = pf2_base.wavelet.lShift([1 2 3 4]);   % [2 3 4 1]
%
% References:
%   Mallat, S. (2009). A Wavelet Tour of Signal Processing: The Sparse
%   Way (3rd ed.). Academic Press. DOI: 10.1016/B978-0-12-374370-1.X0001-8
%
% See also: pf2_base.wavelet.rShift, pf2_base.wavelet.downDyadHi

    y = [x(2:length(x)), x(1)];
end
