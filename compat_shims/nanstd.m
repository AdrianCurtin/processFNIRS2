function y = nanstd(x, flag, dim)
%NANSTD Standard deviation, ignoring NaNs (Statistics Toolbox fallback).
%
%   Drop-in for the Statistics and Machine Learning Toolbox NANSTD. Resides
%   in compat_shims, added to the END of the path by pf2_initialize so the
%   toolbox version wins when installed and this is used only when the
%   toolbox is absent.
%
%   Size-adaptive strategy (both branches pure base MATLAB): small/medium
%   arrays use a manual mask (NaN-aware mean, then masked sum of squares),
%   avoiding the large (~80 us) per-call overhead of the 'omitnan' option;
%   large arrays (>= 5e4 elements) and empties defer to base MATLAB's
%   'omitnan'. See NANMEAN for the measured crossover rationale. The manual
%   branch reproduces STD(...,'omitnan') exactly, including all-NaN slices
%   (NaN) and the single-value N-1 convention (0).
%
%   Inputs:
%     x    - Numeric array.
%     flag - (optional) Normalization: 0 (default, N-1) or 1 (N).
%     dim  - (optional) Dimension to operate along. Defaults to the first
%            non-singleton dimension.
%
%   Outputs:
%     y    - Standard deviation of x ignoring NaNs.
%
%   See also: STD, nanmean

if nargin < 2 || isempty(flag)
    flag = 0;
end
if nargin < 3
    if numel(x) >= 5e4 || isempty(x)
        y = std(x, flag, 'omitnan');
        return;
    end
    dim = find(size(x) ~= 1, 1);
    if isempty(dim)
        dim = 1;
    end
elseif numel(x) >= 5e4 || isempty(x)
    y = std(x, flag, dim, 'omitnan');
    return;
end

nans = isnan(x);
n = sum(~nans, dim);
xz = x;
xz(nans) = 0;
mu = sum(xz, dim) ./ n;     % NaN-ignoring mean
d = x - mu;                 % NaN where x is NaN
d(nans) = 0;
ss = sum(d.^2, dim);
if flag == 1
    denom = n;
else
    denom = n - 1;
end
y = sqrt(ss ./ denom);
y(n == 0) = NaN;            % all-NaN slice
if flag == 0
    y(n == 1) = 0;         % single value, N-1 convention -> 0 (matches STD)
end
end
