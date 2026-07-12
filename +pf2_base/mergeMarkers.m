function T = mergeMarkers(a, b)
% MERGEMARKERS Vertically concatenate two marker sets, unioning their columns
%
% Combines two marker collections into a single canonical table, stacking
% their rows. Unlike a plain vertical concatenation, this tolerates differing
% column sets: any extra variable present in only one input (e.g. behavioral
% columns appended to one recording's markers) is retained, with missing
% entries filled by a type-appropriate missing value. Used when splicing
% recordings together so user-appended marker columns survive the join.
%
% Syntax:
%   T = pf2_base.mergeMarkers(a, b)
%
% Inputs:
%   a - Marker table, numeric matrix, or [] (normalized internally).
%   b - Marker table, numeric matrix, or [] (normalized internally).
%
% Outputs:
%   T - Canonical marker table containing the rows of a followed by the rows
%       of b, with the union of both inputs' columns. Column order follows a,
%       then any columns unique to b.
%
% Example:
%   a.Time=...; % canonical markers with an extra .RT column
%   T = pf2_base.mergeMarkers(a, b);  % b lacking .RT -> filled with NaN
%
% See also: pf2_base.normalizeMarkers, pf2.data.concatenateHorizontal

a = pf2_base.normalizeMarkers(a);
b = pf2_base.normalizeMarkers(b);

if height(a) == 0
    T = b;
    return;
end
if height(b) == 0
    T = a;
    return;
end

% Add any columns each side is missing, then align order before stacking
a = addMissingVars(a, b);
b = addMissingVars(b, a);
b = b(:, a.Properties.VariableNames);

T = [a; b];

end

%%_Subfunctions_________________________________________________________

function T = addMissingVars(T, ref)
% ADDMISSINGVARS Add variables present in ref but missing from T (filled blank)
miss = setdiff(ref.Properties.VariableNames, T.Properties.VariableNames, 'stable');
n = height(T);
for k = 1:numel(miss)
    name = miss{k};
    T.(name) = defaultColumn(ref.(name), n);
end
end

function col = defaultColumn(proto, n)
% DEFAULTCOLUMN Build an n-row column matching proto's type, filled blank
w = size(proto, 2);
if isnumeric(proto)
    col = nan(n, w);
elseif islogical(proto)
    col = false(n, w);
elseif isstring(proto)
    col = repmat(string(missing), n, w);
elseif iscell(proto)
    col = repmat({''}, n, w);
elseif iscategorical(proto)
    col = categorical(nan(n, w));
elseif isdatetime(proto)
    col = NaT(n, w);
elseif isduration(proto)
    col = seconds(nan(n, w));
else
    col = nan(n, w);
end
end
