function [R, P] = corr(varargin)
%CORR Pearson/Spearman linear correlation (toolbox-free).
%
%   Base-MATLAB replacement for the Statistics and Machine Learning
%   Toolbox function CORR, supporting the option subset used across
%   processFNIRS2. Lets correlation-based QC, coupling, and scatter plots
%   run without a Statistics Toolbox license.
%
%   Inputs:
%     corr(X)          - Correlations among the columns of X. R is
%                        Ncol-by-Ncol.
%     corr(X, Y)       - Correlations between columns of X and columns of
%                        Y. R is size(X,2)-by-size(Y,2). Vectors give a
%                        scalar.
%   Name/value options:
%     'Type'  - 'Pearson' (default) or 'Spearman'.
%     'Rows'  - 'all' (default; NaNs propagate), 'complete' (drop any row
%               with a NaN across the involved columns), or 'pairwise'
%               (use rows valid for each column pair).
%
%   Outputs:
%     R - Correlation coefficients.
%     P - Two-sided p-values from a t-distribution approximation
%         (t = r*sqrt((n-2)/(1-r^2)), df = n-2). For Spearman this is the
%         standard large-sample approximation, matching CORR's default for
%         all but very small n.
%
%   Notes:
%     Kendall's tau and the exact/permutation Spearman p-values are not
%     implemented (not used in this codebase).
%
%   See also: pf2_base.compat.tiedrank, pf2_base.compat.tcdf, CORRCOEF

% --- Separate numeric leading args from name/value options -------------
numArgs = {};
k = 1;
while k <= numel(varargin) && ~(ischar(varargin{k}) || isstring(varargin{k}))
    numArgs{end+1} = varargin{k}; %#ok<AGROW>
    k = k + 1;
end

opts = struct('Type', 'Pearson', 'Rows', 'all');
while k <= numel(varargin) - 1
    name = lower(char(varargin{k}));
    val  = varargin{k+1};
    switch name
        case 'type', opts.Type = char(val);
        case 'rows', opts.Rows = char(val);
        % silently ignore unsupported options (e.g. 'Tail')
    end
    k = k + 2;
end

X = numArgs{1};
if isvector(X) && size(X, 1) == 1
    X = X(:);   % treat row vector as a single column
end
if numel(numArgs) >= 2
    Y = numArgs{2};
    if isvector(Y) && size(Y, 1) == 1
        Y = Y(:);
    end
else
    Y = X;
end

isSpearman = strncmpi(opts.Type, 'Spearman', 1);
rowsMode   = lower(opts.Rows);

% 'complete' = drop rows with any NaN across all columns up front
if strcmp(rowsMode, 'complete')
    good = all(~isnan(X), 2) & all(~isnan(Y), 2);
    X = X(good, :);
    Y = Y(good, :);
end

nx = size(X, 2);
ny = size(Y, 2);
R  = zeros(nx, ny);
P  = zeros(nx, ny);

for i = 1:nx
    for j = 1:ny
        [R(i, j), P(i, j)] = localPair(X(:, i), Y(:, j), isSpearman, rowsMode);
    end
end

end

% -----------------------------------------------------------------------
function [r, p] = localPair(x, y, isSpearman, rowsMode)

if strcmp(rowsMode, 'pairwise') || strcmp(rowsMode, 'all') || strcmp(rowsMode, 'complete')
    valid = ~isnan(x) & ~isnan(y);
    if strcmp(rowsMode, 'all') && ~all(valid)
        % 'all' propagates NaN when any involved value is missing
        r = NaN; p = NaN; return;
    end
    x = x(valid);
    y = y(valid);
end

n = numel(x);
if n < 2
    r = NaN; p = NaN; return;
end

if isSpearman
    x = pf2_base.compat.tiedrank(x);
    y = pf2_base.compat.tiedrank(y);
end

x = x - mean(x);
y = y - mean(y);
sx = sqrt(sum(x.^2));
sy = sqrt(sum(y.^2));
if sx == 0 || sy == 0
    r = NaN; p = NaN; return;
end

r = sum(x .* y) / (sx * sy);
r = max(min(r, 1), -1);

% Two-sided p-value from t-distribution. Exact |r| == 1 is the degenerate
% zero-residual-variance case (e.g. a variable with itself on the diagonal
% of corr(X)); MATLAB reports p = 1 there rather than 0.
if abs(r) >= 1
    p = 1;
else
    t = r .* sqrt((n - 2) / (1 - r.^2));
    p = 2 * pf2_base.compat.tcdf(-abs(t), n - 2);
end

end
