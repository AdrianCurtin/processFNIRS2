function y = medfilt1(x, n, varargin)
% MEDFILT1 One-dimensional median filtering (toolbox-free)
%
% Applies an n-point sliding-window median filter along the first
% non-singleton dimension. Clean-room reimplementation so the toolbox does
% not depend on the Signal Processing Toolbox; interface-compatible with the
% Signal Processing Toolbox MEDFILT1 for the vector/column use in
% pf2_CAR and getCAR (default window 3, zero-padded endpoints).
%
% Reference:
%   Tukey, J. W. (1977). Exploratory Data Analysis. Addison-Wesley.
%   ISBN: 978-0201076165 (running-median smoothing).
%
% Syntax:
%   y = medfilt1(x)
%   y = medfilt1(x, n)
%   y = medfilt1(x, n, [], dim)
%   y = medfilt1(..., nanflag, padflag)
%
% Inputs:
%   x       - Input vector or matrix. Row/column vectors are filtered as a
%             single sequence; matrices are filtered column-wise (or along
%             dim).
%   n       - Window length (positive integer, default 3). Even windows use
%             the mean of the two central order statistics, as in the
%             standard routine.
%   dim     - Dimension to operate along (passed as the 4th positional
%             argument, after an empty placeholder).
%   nanflag - 'includenan' (default) or 'omitnan'.
%   padflag - Endpoint handling: 'zeropad' (default) treats out-of-range
%             samples as zero; 'truncate' shrinks the window at the edges.
%
% Outputs:
%   y - Median-filtered signal, same size and orientation as x.
%
% Algorithm:
%   For each output sample the window is centered on the sample (for odd n the
%   center is exact; for even n the window spans floor/ceil halves). The
%   median (or mean of the two central values for even n) of the in-window
%   samples is taken, with out-of-range samples either zero (zeropad) or
%   dropped (truncate).
%
% See also: pf2_CAR, getCAR, median

if nargin < 2 || isempty(n)
    n = 3;
end
if ~(isscalar(n) && n == floor(n) && n >= 1)
    error('pf2_base:medfilt1:badN', 'Window length n must be a positive integer.');
end

% Parse optional arguments: an optional dim (numeric), and flag strings.
dim = [];
nanflag = 'includenan';
padflag = 'zeropad';
for ii = 1:numel(varargin)
    arg = varargin{ii};
    if isnumeric(arg)
        if ~isempty(arg), dim = arg; end
    elseif ischar(arg) || isstring(arg)
        s = lower(char(arg));
        switch s
            case {'includenan', 'omitnan'}
                nanflag = s;
            case {'zeropad', 'truncate'}
                padflag = s;
            otherwise
                error('pf2_base:medfilt1:badOption', 'Unknown option "%s".', s);
        end
    end
end

if isempty(dim)
    dim = find(size(x) ~= 1, 1);
    if isempty(dim), dim = 1; end
end

% Move the working dimension to rows, filter each column, then restore.
perm = 1:max(ndims(x), dim);
perm([1, dim]) = perm([dim, 1]);
xp = permute(x, perm);
sz = size(xp);
xp = reshape(xp, sz(1), []);

omitnan = strcmp(nanflag, 'omitnan');
truncate = strcmp(padflag, 'truncate');

yp = zeros(size(xp), 'like', xp);
T = sz(1);
half1 = floor(n / 2);     % samples before center
half2 = n - 1 - half1;    % samples after center
for col = 1:size(xp, 2)
    v = xp(:, col);
    for i = 1:T
        lo = i - half1;
        hi = i + half2;
        idx = lo:hi;
        inRange = idx >= 1 & idx <= T;
        if truncate
            w = v(idx(inRange));
        else
            w = zeros(n, 1, 'like', v);
            w(inRange) = v(idx(inRange));   % out-of-range stays zero
        end
        if omitnan
            w = w(~isnan(w));
        end
        yp(i, col) = midValue(w);
    end
end

yp = reshape(yp, sz);
y = ipermute(yp, perm);

end

%%_Subfunctions_____________________________________________________________

function m = midValue(w)
% MIDVALUE Median for odd counts, mean of the two central values for even
if isempty(w)
    m = NaN;
    return;
end
% 'includenan' semantics: any NaN in the window makes the output NaN. (In
% 'omitnan' mode NaNs were already stripped before reaching here, so this is a
% no-op there.) Without this, sort() would push NaNs to the end and the
% central-order-statistic pick would return a spurious finite value.
if any(isnan(w))
    m = NaN;
    return;
end
w = sort(w(:));
k = numel(w);
if mod(k, 2) == 1
    m = w((k + 1) / 2);
else
    m = (w(k / 2) + w(k / 2 + 1)) / 2;
end
end
