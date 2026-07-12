function y = iqr(x, dim)
%IQR Interquartile range (toolbox-free).
%
%   Base-MATLAB replacement for the Statistics and Machine Learning
%   Toolbox function IQR. Computes the 75th minus the 25th percentile via
%   pf2_base.compat.quantile.
%
%   Inputs:
%     x   - Numeric array. NaNs are ignored.
%     dim - (optional) Dimension to operate along. Defaults to the first
%           non-singleton dimension.
%
%   Outputs:
%     y   - Interquartile range. Scalar for a vector input; otherwise the
%           operating dimension is reduced to length 1.
%
%   See also: pf2_base.compat.quantile

if nargin < 2
    q = pf2_base.compat.quantile(x, [0.25 0.75]);
else
    q = pf2_base.compat.quantile(x, [0.25 0.75], dim);
end

if isvector(x)
    y = q(2) - q(1);
    return;
end

% Array case: the operating dim now has length 2 (q25, q75)
if nargin < 2
    d = find(size(x) ~= 1, 1);
    if isempty(d), d = 1; end
else
    d = dim;
end
idx1 = repmat({':'}, 1, ndims(q)); idx1{d} = 1;
idx2 = repmat({':'}, 1, ndims(q)); idx2{d} = 2;
y = q(idx2{:}) - q(idx1{:});

end
