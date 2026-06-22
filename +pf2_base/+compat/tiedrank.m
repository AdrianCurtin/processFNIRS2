function r = tiedrank(x)
%TIEDRANK Column-wise ranks with ties averaged (toolbox-free).
%
%   Base-MATLAB replacement for the Statistics and Machine Learning
%   Toolbox function TIEDRANK. Assigns ranks 1..N to the elements of each
%   column; tied values receive the average of the ranks they span. NaN
%   entries are left as NaN and excluded from ranking. Used to implement
%   Spearman correlation without a toolbox dependency.
%
%   Inputs:
%     x - Numeric vector or matrix. Each column is ranked independently.
%         Row vectors are ranked as a single series (MATLAB convention).
%
%   Outputs:
%     r - Ranks, same size as x. NaN positions in x map to NaN in r.
%
%   Notes:
%     Matches TIEDRANK for the standard single-argument form (average tie
%     handling, NaNs omitted). Tie-adjustment/statistic outputs are not
%     produced.
%
%   See also: SORT, pf2_base.compat.corr

isRow = isrow(x);
if isRow
    x = x(:);
end

r = nan(size(x));
for c = 1:size(x, 2)
    col   = x(:, c);
    valid = find(~isnan(col));
    v     = col(valid);
    n     = numel(v);
    if n == 0
        continue;
    end

    [sorted, ord] = sort(v);
    ranks = zeros(n, 1);

    i = 1;
    while i <= n
        j = i;
        while j < n && sorted(j + 1) == sorted(i)
            j = j + 1;
        end
        ranks(i:j) = (i + j) / 2;   % average rank across the tie block
        i = j + 1;
    end

    out = zeros(n, 1);
    out(ord) = ranks;
    r(valid, c) = out;
end

if isRow
    r = r.';
end

end
