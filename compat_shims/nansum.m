function y = nansum(x, dim)
%NANSUM Sum, ignoring NaNs (Statistics Toolbox fallback).
%
%   Drop-in for the Statistics and Machine Learning Toolbox NANSUM. Resides
%   in compat_shims, added to the END of the path by pf2_initialize so the
%   toolbox version wins when installed and this is used only when the
%   toolbox is absent.
%
%   Size-adaptive strategy (both branches pure base MATLAB): small/medium
%   arrays use a manual mask (zero-fill + sum), which avoids the large
%   (~80 us) per-call overhead of the 'omitnan' option and is several times
%   faster for the small reductions common in fNIRS work; large arrays
%   (>= 5e4 elements) and empties defer to base MATLAB's 'omitnan'. See
%   NANMEAN for the measured crossover rationale.
%
%   Inputs:
%     x   - Numeric array.
%     dim - (optional) Dimension to operate along. Defaults to the first
%           non-singleton dimension.
%
%   Outputs:
%     y   - Sum of x ignoring NaNs (all-NaN slices sum to 0, as in NANSUM).
%
%   See also: SUM, nanmean

if nargin < 2
    if numel(x) >= 5e4 || isempty(x)
        y = sum(x, 'omitnan');
        return;
    end
    dim = find(size(x) ~= 1, 1);
    if isempty(dim)
        dim = 1;
    end
elseif numel(x) >= 5e4 || isempty(x)
    y = sum(x, dim, 'omitnan');
    return;
end

x(isnan(x)) = 0;
y = sum(x, dim);   % all-NaN slice -> 0, matching NANSUM
end
