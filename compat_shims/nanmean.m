function y = nanmean(x, dim)
%NANMEAN Mean, ignoring NaNs (Statistics Toolbox fallback).
%
%   Drop-in for the Statistics and Machine Learning Toolbox NANMEAN. This
%   file lives in the compat_shims folder, which pf2_initialize adds to the
%   END of the path: when the toolbox is installed its own NANMEAN takes
%   precedence and this shim is never used; when the toolbox is absent this
%   provides the behavior so core processing does not fail.
%
%   Size-adaptive strategy. Both branches are pure base MATLAB:
%     - Small/medium arrays use a manual mask (zero-fill + sum/count), the
%       same approach the toolbox NANMEAN uses. It has near-zero fixed cost
%       and is several times faster than 'omitnan' here, which carries a
%       large (~80 us) per-call overhead that dominates small reductions.
%     - Large arrays (>= 5e4 elements) defer to base MATLAB's 'omitnan',
%       whose single compiled pass beats the manual mask's extra passes and
%       temporary copy. Empties also defer, for exact MEAN edge semantics.
%   The ~5e4 threshold is the measured crossover on R2025b. This keeps the
%   no-toolbox path at least as fast as the toolbox NANMEAN across sizes.
%
%   Inputs:
%     x   - Numeric array.
%     dim - (optional) Dimension to operate along. Defaults to the first
%           non-singleton dimension.
%
%   Outputs:
%     y   - Mean of x ignoring NaNs.
%
%   See also: MEAN, nansum

if nargin < 2
    if numel(x) >= 5e4 || isempty(x)
        y = mean(x, 'omitnan');
        return;
    end
    dim = find(size(x) ~= 1, 1);
    if isempty(dim)
        dim = 1;
    end
elseif numel(x) >= 5e4 || isempty(x)
    y = mean(x, dim, 'omitnan');
    return;
end

nans = isnan(x);
x(nans) = 0;
n = sum(~nans, dim);
y = sum(x, dim) ./ n;   % all-NaN slice -> 0/0 = NaN, matching NANMEAN
end
