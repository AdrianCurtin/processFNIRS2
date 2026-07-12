function [h, p, ci, stats] = ttest(x, varargin)
%TTEST One-sample/paired t-test (toolbox-free).
%
%   Base-MATLAB replacement for the Statistics and Machine Learning
%   Toolbox function TTEST, covering the one-sample (and paired, via a
%   difference vector) forms used in processFNIRS2. Operates column-wise.
%
%   Inputs:
%     x   - Numeric vector or matrix. Each column is tested against MU.
%     mu  - (optional) Null-hypothesis mean. Scalar, default 0. May be
%           passed positionally as the second argument.
%   Name/value options:
%     'Alpha' - Significance level for H (default 0.05). 'Dim'/'Tail' are
%               not supported (not used in this codebase; two-sided only).
%
%   Outputs:
%     h     - Test decision per column (1 reject, 0 fail to reject) at
%             level Alpha.
%     p     - Two-sided p-values per column.
%     ci    - Confidence intervals, 2-by-Ncol ([lower; upper]).
%     stats - Struct with fields tstat, df, sd (per column).
%
%   See also: pf2_base.compat.tcdf, pf2_base.compat.ttest2

mu    = 0;
alpha = 0.05;

k = 1;
if k <= numel(varargin) && isnumeric(varargin{k})
    mu = varargin{k};
    k = k + 1;
end
while k <= numel(varargin) - 1
    if strcmpi(varargin{k}, 'Alpha')
        alpha = varargin{k+1};
    end
    k = k + 2;
end

if isrow(x)
    x = x(:);
end

m  = mean(x, 1, 'omitnan');
sd = std(x, 0, 1, 'omitnan');
n  = sum(~isnan(x), 1);
df = n - 1;

se = sd ./ sqrt(n);
t  = (m - mu) ./ se;

p = 2 * pf2_base.compat.tcdf(-abs(t), df);
h = double(p < alpha);
h(isnan(p)) = NaN;

% Confidence interval via t critical value (Newton bisection on tcdf)
tcrit = localTinv(1 - alpha/2, df);
ci    = [m - tcrit .* se; m + tcrit .* se];

stats = struct('tstat', t, 'df', df, 'sd', sd);

end

% -----------------------------------------------------------------------
function tc = localTinv(prob, df)
% Inverse t CDF by bisection (vectorized over df), good to ~1e-6.
tc = zeros(size(df));
for i = 1:numel(df)
    if df(i) <= 0 || isnan(df(i))
        tc(i) = NaN; continue;
    end
    lo = 0; hi = 1e6;
    for it = 1:100
        mid = (lo + hi) / 2;
        if pf2_base.compat.tcdf(mid, df(i)) < prob
            lo = mid;
        else
            hi = mid;
        end
    end
    tc(i) = (lo + hi) / 2;
end
end
