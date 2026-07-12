function y = rShift(x)
% RSHIFT Circular right shift of a 1-D signal
%
% Rotates a 1-D signal one sample toward higher indices, wrapping the last
% sample to the front: y(i) = x(i-1), y(1) = x(n). Used by the high-pass
% synthesis filter of the periodized discrete wavelet transform and by the
% translation-invariant transform's cycle-spinning (Mallat 2009).
%
% Clean-room implementation.
%
% Syntax:
%   y = pf2_base.wavelet.rShift(x)
%
% Inputs:
%   x - 1-D signal [1 x n] double (row).
%
% Outputs:
%   y - Right-shifted signal [1 x n] double (row).
%
% Example:
%   y = pf2_base.wavelet.rShift([1 2 3 4]);   % [4 1 2 3]
%
% References:
%   Mallat, S. (2009). A Wavelet Tour of Signal Processing: The Sparse
%   Way (3rd ed.). Academic Press. DOI: 10.1016/B978-0-12-374370-1.X0001-8
%
% See also: pf2_base.wavelet.lShift, pf2_base.wavelet.upDyadHi

    n = length(x);
    y = [x(n), x(1:(n - 1))];
end
