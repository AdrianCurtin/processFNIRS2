function arr = markersToArray(mrk)
% MARKERSTOARRAY Convert canonical marker table (or matrix) to a numeric array
%
% Returns markers as a numeric matrix with columns in canonical order
% [Time, Code, Duration, Amplitude, <extras...>]. Accepts the canonical
% marker table, a raw numeric matrix, or empty input. Use this at
% serialization boundaries (e.g. NIR export) and inside numeric algorithms
% that index marker columns positionally, while keeping the stored
% data.markers field as a table.
%
% Syntax:
%   arr = pf2_base.markersToArray(mrk)
%
% Inputs:
%   mrk - Marker table, numeric [M x N] matrix, or [].
%
% Outputs:
%   arr - Numeric matrix [M x >=4] in canonical column order, followed by any
%         numeric/logical extra columns (in their existing order). Empty input
%         returns zeros(0, 4). Non-numeric extras (text/categorical/datetime/
%         duration) cannot live in a numeric matrix and are dropped; numeric
%         extras survive even when a non-numeric extra is also present.
%
% Example:
%   arr = pf2_base.markersToArray(data.markers);
%   onsets = arr(:, 1);
%   codes  = arr(:, 2);
%
% See also: pf2_base.normalizeMarkers, pf2.data.getMarkers

if isempty(mrk)
    arr = zeros(0, 4);
    return;
end

% Route through normalizeMarkers so columns are padded and ordered canonically
T = pf2_base.normalizeMarkers(mrk);

% Keep the four canonical columns plus any numeric/logical extras (in their
% existing order); non-numeric extras (text/categorical/datetime/duration)
% cannot live in a numeric matrix and are dropped. Selecting per-column (not
% all-or-nothing) ensures a numeric extra survives even when a non-numeric
% extra (e.g. a categorical Label) is also present.
vn = T.Properties.VariableNames;
canonVars = {'Time', 'Code', 'Duration', 'Amplitude'};
isNumLog = varfun(@(v) isnumeric(v) || islogical(v), T, 'OutputFormat', 'uniform');
keep = isNumLog | ismember(vn, canonVars);
arr = double(table2array(T(:, keep)));

end
