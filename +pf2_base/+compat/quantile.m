function q = quantile(x, p, dim)
%QUANTILE Empirical quantiles (toolbox-free).
%
%   Base-MATLAB replacement for the Statistics and Machine Learning
%   Toolbox function QUANTILE, using the same linear-interpolation
%   convention so results match to floating-point tolerance.
%
%   Inputs:
%     x   - Numeric array. NaNs are ignored.
%     p   - Probabilities in [0,1] (scalar or vector), OR a scalar integer
%           N >= 1 requesting N evenly spaced quantiles at probabilities
%           (1, 2, ..., N)/(N+1).
%     dim - (optional) Dimension to operate along. Defaults to the first
%           non-singleton dimension (MATLAB convention). Ignored when x is
%           a vector.
%
%   Outputs:
%     q   - Quantiles. For a vector x, q is the same size as p. For an
%           array, the operating dimension is replaced by numel(p).
%
%   Notes:
%     Data points are assigned cumulative probabilities (0.5:1:n-0.5)/n and
%     linearly interpolated; probabilities outside that range clamp to the
%     min/max sample. Matches QUANTILE's default method.
%
%   See also: SORT, INTERP1, pf2_base.compat.prctile

% Integer N -> N evenly spaced quantile probabilities
expandedN = false;
if isscalar(p) && p == floor(p) && p >= 1
    N = p;
    p = (1:N) / (N + 1);
    expandedN = true;
end

% --- Vector fast path: q matches the shape of p --------------------------
if isvector(x)
    qv = localCol(x(:), p(:).');
    if expandedN
        q = qv(:).';           % N-form returns a row of N quantiles
    else
        q = reshape(qv, size(p));
    end
    return;
end

% --- Array path ----------------------------------------------------------
if nargin < 3 || isempty(dim)
    dim = find(size(x) ~= 1, 1);
    if isempty(dim)
        dim = 1;
    end
end
pRow = p(:).';

perm = [dim, setdiff(1:max(ndims(x), dim), dim)];
xp   = permute(x, perm);
szp  = size(xp);
xp   = reshape(xp, szp(1), []);

out = zeros(numel(pRow), size(xp, 2));
for c = 1:size(xp, 2)
    out(:, c) = localCol(xp(:, c), pRow);
end

szOut    = szp;
szOut(1) = numel(pRow);
out      = reshape(out, szOut);
q        = ipermute(out, perm);

end

% -----------------------------------------------------------------------
function q = localCol(v, p)
v = sort(v(~isnan(v)));
n = numel(v);
if n == 0
    q = nan(numel(p), 1);
    return;
elseif n == 1
    q = repmat(v, numel(p), 1);
    return;
end
cp = ((1:n) - 0.5) / n;
q  = interp1(cp, v, p, 'linear');
q(p < cp(1))   = v(1);
q(p > cp(end)) = v(end);
q = q(:);
end
