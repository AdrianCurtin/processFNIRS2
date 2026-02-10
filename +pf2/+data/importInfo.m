function data = importInfo(data, filepath, varargin)
% IMPORTINFO Import subject-level metadata from CSV/Excel into fNIRS structs
%
% Reads a CSV or Excel file and matches rows to fNIRS data structures by
% key columns. Each struct must match exactly one row. All non-key columns
% are copied into the struct's .info field.
%
% Syntax:
%   data = pf2.data.importInfo(data, filepath, keyColumn)
%   data = pf2.data.importInfo(data, filepath, 'Keys', keyColumns)
%   data = pf2.data.importInfo(data, filepath, ..., 'Name', Value)
%
% Inputs:
%   data     - fNIRS data structure or cell array of structures.
%              Each struct must have an .info field containing key values.
%   filepath - Path to CSV (.csv) or Excel (.xlsx, .xls) file [char|string]
%
% Name-Value Parameters:
%   'Keys'        - Column name(s) to match on [char|string|cellstr]
%                   Also accepted as first positional argument after filepath.
%   'Sheet'       - Sheet name or index for Excel files (default: 1)
%   'Overwrite'   - Overwrite existing .info fields (default: true)
%   'ReadOptions' - Cell array of extra arguments passed to readtable (default: {})
%
% Outputs:
%   data - Same structure(s) with .info fields updated from matched rows.
%          Returns same type as input (struct -> struct, cell -> cell).
%
% Algorithm:
%   1. Read file into table via readtable
%   2. Validate key columns exist in file and in each struct's .info
%   3. For each struct, find row(s) where all keys match
%   4. Error if 0 or >1 rows match any struct
%   5. Copy non-key columns into .info (respecting Overwrite setting)
%   6. Warn if any CSV rows were not matched to any struct
%
% Example:
%   % Single key matching
%   allData = pf2.data.importInfo(allData, 'demographics.csv', 'SubjectID');
%
%   % Multi-key matching
%   allData = pf2.data.importInfo(allData, 'metadata.xlsx', ...
%       'Keys', {'SubjectID', 'Session'});
%
%   % Preserve existing .info fields
%   d = pf2.data.importInfo(d, 'extra.csv', 'SubjectID', 'Overwrite', false);
%
% See also: pf2.data.importBlockInfo, pf2.data.defineBlocks

% --- Parse positional key argument vs name-value ---
positionalKeys = {};
remainingArgs = varargin;

if ~isempty(varargin) && (ischar(varargin{1}) || isstring(varargin{1}))
    candidate = varargin{1};
    % Check if it's a name-value parameter name (not a key column name)
    nvNames = {'Keys', 'Sheet', 'Overwrite', 'ReadOptions'};
    if ~any(strcmpi(string(candidate), nvNames))
        positionalKeys = cellstr(candidate);
        remainingArgs = varargin(2:end);
    end
elseif ~isempty(varargin) && iscellstr(varargin{1})
    positionalKeys = varargin{1};
    remainingArgs = varargin(2:end);
end

p = inputParser;
p.addParameter('Keys', {}, @(x) ischar(x) || isstring(x) || iscellstr(x));
p.addParameter('Sheet', 1, @(x) isnumeric(x) || ischar(x) || isstring(x));
p.addParameter('Overwrite', true, @islogical);
p.addParameter('ReadOptions', {}, @iscell);
p.parse(remainingArgs{:});

if ~isempty(positionalKeys)
    keys = positionalKeys;
else
    keys = cellstr(p.Results.Keys);
end

sheet = p.Results.Sheet;
overwrite = p.Results.Overwrite;
readOpts = p.Results.ReadOptions;

% Validate keys provided
if isempty(keys) || (numel(keys) == 1 && isempty(keys{1}))
    error('pf2:data:importInfo:noKeys', ...
        'Must specify at least one key column.');
end

% Validate file exists
if ~isfile(filepath)
    error('pf2:data:importInfo:fileNotFound', ...
        'File not found: %s', filepath);
end

% Read file
readArgs = readOpts;
[~, ~, ext] = fileparts(filepath);
if any(strcmpi(ext, {'.xlsx', '.xls'}))
    readArgs = [readArgs, {'Sheet', sheet}];
end
tbl = readtable(filepath, readArgs{:});

% Validate key columns exist in file
colNames = tbl.Properties.VariableNames;
for k = 1:numel(keys)
    if ~any(strcmp(colNames, keys{k}))
        error('pf2:data:importInfo:keyNotInFile', ...
            'Key column ''%s'' not found in file. Available columns: %s', ...
            keys{k}, strjoin(colNames, ', '));
    end
end

% Determine non-key columns
nonKeyIdx = ~ismember(colNames, keys);
nonKeyCols = colNames(nonKeyIdx);

% Normalize input to cell array for uniform processing
inputWasCell = iscell(data);
if ~inputWasCell
    dataCell = {data};
else
    dataCell = data;
end

nStructs = numel(dataCell);
rowUsed = false(height(tbl), 1);

for s = 1:nStructs
    d = dataCell{s};

    if ~isfield(d, 'info')
        error('pf2:data:importInfo:keyNotInInfo', ...
            'Struct %d has no .info field.', s);
    end

    % Validate key fields exist in .info and build match mask
    matchMask = true(height(tbl), 1);
    keyVals = cell(1, numel(keys));

    for k = 1:numel(keys)
        keyName = keys{k};
        if ~isfield(d.info, keyName)
            error('pf2:data:importInfo:keyNotInInfo', ...
                'Key field ''%s'' not found in struct %d .info.', keyName, s);
        end

        infoVal = d.info.(keyName);
        tblCol = tbl.(keyName);
        keyVals{k} = infoVal;

        % Type-aware comparison
        if isnumeric(infoVal)
            if isnumeric(tblCol)
                matchMask = matchMask & (tblCol == infoVal);
            else
                matchMask = matchMask & (double(string(tblCol)) == infoVal);
            end
        else
            % Compare as strings for char/string/categorical interop
            matchMask = matchMask & (string(tblCol) == string(infoVal));
        end
    end

    matchIdx = find(matchMask);

    if isempty(matchIdx)
        keyStr = strjoin(cellfun(@(k,v) sprintf('%s=%s', k, string(v)), ...
            keys, keyVals, 'UniformOutput', false), ', ');
        error('pf2:data:importInfo:noMatch', ...
            'No rows match struct %d (%s).', s, keyStr);
    end

    if numel(matchIdx) > 1
        keyStr = strjoin(cellfun(@(k,v) sprintf('%s=%s', k, string(v)), ...
            keys, keyVals, 'UniformOutput', false), ', ');
        error('pf2:data:importInfo:ambiguousMatch', ...
            'Multiple rows (%d) match struct %d (%s).', numel(matchIdx), s, keyStr);
    end

    rowUsed(matchIdx) = true;

    % Copy non-key columns into .info
    for c = 1:numel(nonKeyCols)
        colName = nonKeyCols{c};
        if ~overwrite && isfield(d.info, colName)
            continue;
        end
        val = tbl.(colName)(matchIdx);
        if iscell(val)
            d.info.(colName) = val{1};
        elseif iscategorical(val)
            d.info.(colName) = char(val);
        else
            d.info.(colName) = val;
        end
    end

    dataCell{s} = d;
end

% Warn about unused rows
if any(~rowUsed)
    nUnused = sum(~rowUsed);
    warning('pf2:data:importInfo:unusedRows', ...
        '%d row(s) in file not matched to any struct.', nUnused);
end

% Return same type as input
if inputWasCell
    data = dataCell;
else
    data = dataCell{1};
end

end
