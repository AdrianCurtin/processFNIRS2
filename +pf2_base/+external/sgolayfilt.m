function y = sgolayfilt(x, order, framelen)
% SGOLAYFILT Savitzky-Golay smoothing filter (toolbox-free)
%
% Smooths data with a Savitzky-Golay FIR filter: a least-squares polynomial
% fit applied in a sliding frame, with special handling of the start/end
% transients. Clean-room reimplementation so the toolbox does not depend on
% the Signal Processing Toolbox; interface-compatible with the Signal
% Processing Toolbox SGOLAYFILT for the use in pf2_MotionCorrectSplineSG.
%
% Reference:
%   Savitzky, A. & Golay, M. J. E. (1964). Smoothing and differentiation of
%   data by simplified least squares procedures. Analytical Chemistry,
%   36(8), 1627-1639. DOI: 10.1021/ac60214a047
%
% Syntax:
%   y = sgolayfilt(x, order, framelen)
%
% Inputs:
%   x        - Input vector or matrix. Vectors are filtered as a single
%              sequence; matrices are filtered column-wise.
%   order    - Polynomial order (non-negative integer, < framelen).
%   framelen - Frame length (positive odd integer).
%
% Outputs:
%   y - Smoothed signal, same size and orientation as x.
%
% Algorithm:
%   1. Obtain the Savitzky-Golay projection matrix (pf2_base.external.sgolay).
%   2. Filter the steady-state interior by convolving with the center row.
%   3. Replace the first and last (framelen-1)/2 samples with the polynomial
%      fit evaluated at those frame positions using the corresponding rows of
%      the projection matrix.
%
% See also: sgolay, pf2_MotionCorrectSplineSG

if ~(isscalar(framelen) && framelen == floor(framelen) && framelen >= 1 && mod(framelen, 2) == 1)
    error('pf2_base:sgolayfilt:badFrame', 'Frame length must be a positive odd integer.');
end

isRowVec = isrow(x);
if isRowVec
    x = x(:);
end
[T, C] = size(x);

if T < framelen
    error('pf2_base:sgolayfilt:dataTooShort', ...
        'Input length (%d) must be at least the frame length (%d).', T, framelen);
end

B = pf2_base.external.sgolay(order, framelen);
m = (framelen - 1) / 2;

y = zeros(T, C, 'like', x);
% Steady-state smoothing: convolve with the (reversed) center row of B.
center = B(m + 1, :);
for c = 1:C
    y(:, c) = filter(center(end:-1:1), 1, x(:, c));
end
% filter() output at sample i uses x(i-framelen+1:i); shift so the smoothed
% value lands at the frame center (delay of m samples).
y(1:T - m, :) = y(m + 1:T, :);

% Start/end transients: evaluate the polynomial fit at the edge frame
% positions using the leading/trailing rows of the projection matrix.
for c = 1:C
    y(1:m, c)        = B(1:m, :)            * x(1:framelen, c);
    y(T - m + 1:T, c) = B(framelen - m + 1:framelen, :) * x(T - framelen + 1:T, c);
end

if isRowVec
    y = y.';
end

end
