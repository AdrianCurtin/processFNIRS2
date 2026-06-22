function y = adjConv(f, x)
% ADJCONV Periodic convolution of a signal with the time-reverse of a filter
%
% Filters the 1-D signal x with the time-reversed filter f using circular
% boundary extension, returning a result the same length as x. This adjoint
% periodic convolution is the analysis (low-pass) and synthesis (high-pass)
% counterpart to pf2_base.wavelet.fwdConv in the periodized orthogonal
% discrete wavelet transform; together they make the transform orthogonal
% and exactly invertible.
%
% Clean-room implementation. The signal is extended on the RIGHT by p
% wrapped samples (p = filter length), filtered with the flipped filter,
% and the result sampled at indices p..n+p-1 to realise the periodic
% correlation sum_k f(k) x((i+k) mod n) (Mallat 2009).
%
% Syntax:
%   y = pf2_base.wavelet.adjConv(f, x)
%
% Inputs:
%   f - Filter coefficients [1 x p] double.
%   x - 1-D signal [1 x n] double (row).
%
% Outputs:
%   y - Periodically (adjoint-)filtered signal [1 x n] double (row).
%
% Example:
%   y = pf2_base.wavelet.adjConv([1 1]/sqrt(2), [1 2 3 4]);
%
% References:
%   Mallat, S. (2009). A Wavelet Tour of Signal Processing: The Sparse
%   Way (3rd ed.). Academic Press. DOI: 10.1016/B978-0-12-374370-1.X0001-8
%
% See also: pf2_base.wavelet.fwdConv, pf2_base.wavelet.downDyadLo,
%   pf2_base.wavelet.upDyadHi

    n = length(x);
    p = length(f);
    if p < n
        xpadded = [x, x(1:p)];
    else
        % Filter longer than signal: wrap the right padding modulo n.
        z = zeros(1, p);
        for i = 1:p
            imod = 1 + rem(i - 1, n);
            z(i) = x(imod);
        end
        xpadded = [x, z];
    end
    fflip = f(end:-1:1);
    ypadded = filter(fflip, 1, xpadded);
    y = ypadded(p:(n + p - 1));
end
