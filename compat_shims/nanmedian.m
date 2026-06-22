function y = nanmedian(x, dim)
%NANMEDIAN Median, ignoring NaNs (Statistics Toolbox fallback).
%
%   Drop-in for the Statistics and Machine Learning Toolbox NANMEDIAN,
%   built on base MATLAB's 'omitnan' option. Resides in compat_shims,
%   added to the END of the path by pf2_initialize so the toolbox version
%   wins when installed and this is used only when the toolbox is absent.
%
%   Inputs:
%     x   - Numeric array.
%     dim - (optional) Dimension to operate along. Defaults to the first
%           non-singleton dimension.
%
%   Outputs:
%     y   - Median of x ignoring NaNs.
%
%   See also: MEDIAN, nanmean

if nargin < 2
    y = median(x, 'omitnan');
else
    y = median(x, dim, 'omitnan');
end
end
