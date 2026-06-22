function p = tcdf(t, v)
%TCDF Student's t cumulative distribution function (toolbox-free).
%
%   Base-MATLAB replacement for the Statistics and Machine Learning
%   Toolbox function TCDF, computed from the regularized incomplete beta
%   function BETAINC (which ships with base MATLAB). Lets the toolbox be an
%   optional dependency: code that only needs t-distribution p-values no
%   longer requires a Statistics Toolbox license.
%
%   Inputs:
%     t - Real array of t-statistic values. May be any size. NaN/Inf are
%         handled (NaN -> NaN, +Inf -> 1, -Inf -> 0).
%     v - Degrees of freedom. Scalar, or an array broadcastable against t.
%         Non-positive or NaN df yield NaN (matching TCDF's domain).
%
%   Outputs:
%     p - Lower-tail probability P(T <= t), same size as the broadcast of
%         t and v.
%
%   Notes:
%     Uses the identity, with x = v / (v + t^2):
%       F(t) = 1 - 0.5 * I_x(v/2, 1/2)   for t > 0
%       F(t) =     0.5 * I_x(v/2, 1/2)   for t <= 0
%     where I_x is the regularized incomplete beta function. NaN t-values
%     and non-positive df are masked out BEFORE calling BETAINC, which
%     would otherwise error on out-of-domain arguments (e.g. df <= 0 gives
%     a negative beta shape parameter).
%
%   See also: BETAINC, pf2_base.compat.ttest

t = double(t);
v = double(v);

% Broadcast t and v to a common shape without 0*Inf hazards
tt = t .* ones(size(v));
vv = v .* ones(size(t));

p = NaN(size(tt));

% Only finite t with positive df go through betainc
ok = isfinite(tt) & (vv > 0);
if any(ok(:))
    xo  = vv(ok) ./ (vv(ok) + tt(ok).^2);
    ibo = betainc(xo, vv(ok) ./ 2, 0.5);
    pk  = 1 - 0.5 .* ibo;
    neg = tt(ok) <= 0;
    pk(neg) = 0.5 .* ibo(neg);
    p(ok) = pk;
end

% Infinite t with valid df saturate the CDF
p(~isfinite(tt) & (vv > 0) & (tt > 0)) = 1;   % +Inf
p(~isfinite(tt) & (vv > 0) & (tt < 0)) = 0;   % -Inf

end
