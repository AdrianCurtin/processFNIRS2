function [h, p, ci, stats] = ttest2(x, y, varargin)
%TTEST2 Two-sample t-test, pooled variance (toolbox-free).
%
%   Base-MATLAB replacement for the Statistics and Machine Learning
%   Toolbox function TTEST2 for the equal-variance (pooled) two-sided form
%   used in processFNIRS2. Operates on vectors.
%
%   Inputs:
%     x, y - Numeric vectors (NaNs ignored). The two independent samples.
%   Name/value options:
%     'Alpha' - Significance level for H (default 0.05). 'Vartype',
%               'Tail', and 'Dim' are not supported (pooled, two-sided).
%
%   Outputs:
%     h     - Test decision (1 reject, 0 fail to reject) at level Alpha.
%     p     - Two-sided p-value.
%     ci    - Confidence interval on the mean difference [lower upper].
%     stats - Struct with fields tstat, df, sd (pooled).
%
%   See also: pf2_base.compat.tcdf, pf2_base.compat.ttest

alpha = 0.05;
k = 1;
while k <= numel(varargin) - 1
    if strcmpi(varargin{k}, 'Alpha')
        alpha = varargin{k+1};
    end
    k = k + 2;
end

x = x(~isnan(x));
y = y(~isnan(y));
nx = numel(x);
ny = numel(y);

mx = mean(x);
my = mean(y);
vx = var(x);
vy = var(y);

df  = nx + ny - 2;
sp2 = ((nx - 1) * vx + (ny - 1) * vy) / df;   % pooled variance
se  = sqrt(sp2 * (1/nx + 1/ny));
t   = (mx - my) / se;

p = 2 * pf2_base.compat.tcdf(-abs(t), df);
h = double(p < alpha);

tcrit = localTinv(1 - alpha/2, df);
ci    = [(mx - my) - tcrit * se, (mx - my) + tcrit * se];

stats = struct('tstat', t, 'df', df, 'sd', sqrt(sp2));

end

% -----------------------------------------------------------------------
function tc = localTinv(prob, df)
if df <= 0 || isnan(df)
    tc = NaN; return;
end
lo = 0; hi = 1e6;
for it = 1:100
    mid = (lo + hi) / 2;
    if pf2_base.compat.tcdf(mid, df) < prob
        lo = mid;
    else
        hi = mid;
    end
end
tc = (lo + hi) / 2;
end
