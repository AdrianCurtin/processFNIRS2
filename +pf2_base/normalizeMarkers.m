function mrk = normalizeMarkers(mrk)
% NORMALIZEMARKERS Standardize event markers into a canonical table
%
% Converts marker data from any supported form into a MATLAB table with the
% canonical variables Time, Code, Duration, Amplitude (in that column order).
% This table is the canonical in-memory representation of markers used
% throughout processFNIRS2. Importers, data generators, and any code that
% assigns data.markers should pass through this function so the field is
% always a well-formed table with named columns.
%
% Syntax:
%   mrk = pf2_base.normalizeMarkers(mrk)
%
% Inputs:
%   mrk - Marker data in any of these forms:
%         table   - Variables mapped onto the canonical schema by name
%                   (synonyms such as onset/value/type/length are recognized);
%                   any unrecognized variables are retained after Amplitude.
%         [M x 2] - [Time, Code]            (Duration=0, Amplitude=1 added)
%         [M x 3] - [Time, Code, Duration]  (Amplitude=1 added)
%         [M x 4] - [Time, Code, Duration, Amplitude]
%         [M x N] - N>4: extra columns retained as Data5..DataN
%         []      - Empty input (returns a 0-row canonical table)
%
% Outputs:
%   mrk - Marker table [M x >=4] with variables:
%         .Time      - Event time (seconds)
%         .Code      - Marker value/code
%         .Duration  - Event duration (seconds), default 0
%         .Amplitude - Event amplitude/weight, default 1
%         (.Data5..) - Any additional columns, preserved in order
%
% Notes:
%   - Idempotent: re-normalizing a canonical table returns it unchanged.
%   - A 0-row TABLE is routed through the table path, so a fully-filtered table
%     keeps its extra-column schema (only a non-table [] yields the bare
%     4-column canonical table).
%   - Canonical fields are matched by name first, then a conservative substring
%     fallback; text-typed columns (string/char/cellstr) are parsed by VALUE,
%     not character codepoint, so a "49" code becomes 49.
%
% Example:
%   mrk = pf2_base.normalizeMarkers([10 49; 25 51]);  % 2x4 canonical table
%   mrk = pf2_base.normalizeMarkers(existingTable);    % remapped to canonical
%
% See also: pf2_base.markersToArray, pf2.data.getMarkers, pf2.data.defineBlocks

canon = {'Time', 'Code', 'Duration', 'Amplitude'};

% --- Table input: map variables onto the canonical schema ----------------
% Handled before the generic empty check so a 0-row table that still carries
% extra columns (e.g. a fully-filtered split result) keeps its schema rather
% than collapsing to the bare 4-column canonical table.
if istable(mrk)
    mrk = normalizeTable(mrk, canon);
    return;
end

% --- Empty (non-table) input: return a typed 0-row canonical table --------
if isempty(mrk)
    z = zeros(0, 1);
    mrk = table(z, z, z, z, 'VariableNames', canon);
    return;
end

% --- Numeric matrix input: pad to canonical 4 columns --------------------
if ~isnumeric(mrk)
    error('pf2:normalizeMarkers:badType', ...
        'Markers must be numeric or a table; got %s.', class(mrk));
end

nRows = size(mrk, 1);
nCols = size(mrk, 2);

if nCols < 4
    % Pad missing columns. The final padded column is global column 4
    % (Amplitude, default 1); any intermediate padded columns default to 0.
    pad = zeros(nRows, 4 - nCols);
    pad(:, end) = 1;
    mrk = [mrk, pad];
    nCols = 4;
end

vars = canon;
for c = 5:nCols
    vars{c} = sprintf('Data%d', c);
end

mrk = array2table(mrk, 'VariableNames', vars);

end

%%_Subfunctions_________________________________________________________

function T = normalizeTable(T, canon)
% NORMALIZETABLE Remap an existing marker table onto the canonical schema
%
% Recognizes canonical names and common synonyms, reorders to Time, Code,
% Duration, Amplitude, and appends any remaining variables unchanged.

vn = T.Properties.VariableNames;
lvn = lower(vn);
nRows = height(T);
used = false(1, numel(vn));

% Each field is matched first by EXACT name (full synonym list), then by a
% conservative substring fallback. Short/ambiguous tokens (id, type, amp,
% weight, length) are exact-only so they can never swallow a user-defined
% attribute column (e.g. GameScore, isDeviceMarker) via a substring hit.
[Time, used]      = pick(T, lvn, used, {'time', 'onset'},               {'time', 'onset'}, zeros(nRows, 1));
[Code, used]      = pick(T, lvn, used, {'code', 'value', 'type', 'id'}, {'code', 'value'}, zeros(nRows, 1));
[Duration, used]  = pick(T, lvn, used, {'duration', 'length'},          {'duration'},      zeros(nRows, 1));
[Amplitude, used] = pick(T, lvn, used, {'amplitude', 'amp', 'weight'},  {'amplitude'},     ones(nRows, 1));

out = table(Time, Code, Duration, Amplitude, 'VariableNames', canon);

% Append unrecognized variables, preserving their names and order
extras = find(~used);
for k = 1:numel(extras)
    name = matlab.lang.makeValidName(vn{extras(k)});
    out.(name) = T{:, extras(k)};
end

T = out;

end

function [col, used] = pick(T, lvn, used, exactSyns, containsSyns, default)
% PICK Extract the first variable matching a synonym, else a default column
%   Already-claimed columns (used==true) are never matched again.
idx = firstMatch(lvn, used, exactSyns, containsSyns);
if isempty(idx)
    col = default;
else
    col = T{:, idx};
    if islogical(col)
        col = double(col);
    elseif ~isnumeric(col)
        % Parse text-typed columns (string/char/cellstr) by value rather than
        % codepoint, so e.g. a char/cellstr "49" becomes 49, not its ASCII.
        col = double(str2double(string(col)));
    end
    used(idx) = true;
end
end

function idx = firstMatch(names, used, exactSyns, containsSyns)
% FIRSTMATCH Locate an unclaimed variable name: exact synonyms, then substring
idx = [];
for s = 1:numel(exactSyns)
    hit = find(strcmp(names, exactSyns{s}) & ~used, 1);
    if ~isempty(hit)
        idx = hit;
        return;
    end
end
for s = 1:numel(containsSyns)
    hit = find(contains(names, containsSyns{s}) & ~used, 1);
    if ~isempty(hit)
        idx = hit;
        return;
    end
end
end
