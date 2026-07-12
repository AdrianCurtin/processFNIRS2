function [b, g] = sgolay(order, framelen)
% SGOLAY Savitzky-Golay FIR smoothing/differentiation filter matrix
%
% Returns the Savitzky-Golay projection matrix used to fit an order-K
% polynomial, by least squares, to each length-F frame of data. Clean-room
% reimplementation so the toolbox does not depend on the Signal Processing
% Toolbox; interface-compatible with the Signal Processing Toolbox SGOLAY for
% the smoothing use in pf2_base.external.sgolayfilt.
%
% Reference:
%   Savitzky, A. & Golay, M. J. E. (1964). Smoothing and differentiation of
%   data by simplified least squares procedures. Analytical Chemistry,
%   36(8), 1627-1639. DOI: 10.1021/ac60214a047
%
% Syntax:
%   b      = sgolay(order, framelen)
%   [b, g] = sgolay(order, framelen)
%
% Inputs:
%   order    - Polynomial order (non-negative integer, < framelen).
%   framelen - Frame length (positive odd integer).
%
% Outputs:
%   b - [framelen x framelen] projection matrix. Row i holds the FIR weights
%       that estimate the polynomial fit at the i-th frame position; the
%       middle row is the steady-state smoothing filter.
%   g - [framelen x (order+1)] matrix of differentiation filters; column d+1
%       differentiates to order d (g = S / (S'*S) in the monomial basis).
%
% Algorithm:
%   Build the Vandermonde design matrix S over the centered index grid
%   -m:m (m = (framelen-1)/2) with columns x^0..x^order, then form the
%   orthogonal projector b = S*pinv(S) and the pseudo-inverse factor g.
%
% See also: sgolayfilt, pf2_MotionCorrectSplineSG

if ~(isscalar(order) && order == floor(order) && order >= 0)
    error('pf2_base:sgolay:badOrder', 'Polynomial order must be a non-negative integer.');
end
if ~(isscalar(framelen) && framelen == floor(framelen) && framelen >= 1 && mod(framelen, 2) == 1)
    error('pf2_base:sgolay:badFrame', 'Frame length must be a positive odd integer.');
end
if order >= framelen
    error('pf2_base:sgolay:orderTooLarge', 'Polynomial order must be less than the frame length.');
end

m = (framelen - 1) / 2;
xgrid = (-m:m).';
S = xgrid .^ (0:order);        % [framelen x (order+1)] Vandermonde

% Pseudo-inverse via QR for numerical stability: g = S*inv(S'*S), b = S*g'.
[Q, R] = qr(S, 0);
g = Q / R.';                   % S * inv(S'*S)
b = g * S.';                   % projection matrix S*pinv(S)

end
