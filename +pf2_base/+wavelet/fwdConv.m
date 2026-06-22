function y = fwdConv(f, x)
% FWDCONV Periodic (circular) convolution of a signal with a filter
%
% Filters the 1-D signal x with the filter f using circular boundary
% extension, returning a result the same length as x. This is the forward
% periodic convolution used by the low-pass/high-pass synthesis and
% high-pass analysis steps of the periodized orthogonal discrete wavelet
% transform.
%
% Clean-room implementation. The signal is pre-extended on the LEFT by p
% wrapped samples (p = filter length) so that the causal FIR filter()
% output, sampled at indices p+1..n+p, equals the periodic convolution
% sum_k f(k) x((i-k) mod n). When the filter is longer than the signal the
% wrap indices are computed modulo n. This matches the standard
% two-scale-transform convolution convention (Mallat 2009).
%
% Syntax:
%   y = pf2_base.wavelet.fwdConv(f, x)
%
% Inputs:
%   f - Filter coefficients [1 x p] double.
%   x - 1-D signal [1 x n] double (row).
%
% Outputs:
%   y - Periodically filtered signal [1 x n] double (row).
%
% Example:
%   y = pf2_base.wavelet.fwdConv([1 1]/sqrt(2), [1 2 3 4]);
%
% References:
%   Mallat, S. (2009). A Wavelet Tour of Signal Processing: The Sparse
%   Way (3rd ed.). Academic Press. DOI: 10.1016/B978-0-12-374370-1.X0001-8
%
% See also: pf2_base.wavelet.adjConv, pf2_base.wavelet.downDyadHi,
%   pf2_base.wavelet.upDyadLo

    n = length(x);
    p = length(f);
    if p <= n
        xpadded = [x((n + 1 - p):n), x];
    else
        % Filter longer than signal: wrap the left padding modulo n.
        z = zeros(1, p);
        for i = 1:p
            imod = 1 + rem(p * n - p + i - 1, n);
            z(i) = x(imod);
        end
        xpadded = [z, x];
    end
    ypadded = filter(f, 1, xpadded);
    y = ypadded((p + 1):(n + p));
end
