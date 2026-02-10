function blocks = importBlockInfo(blocks, filepath, varargin)
% IMPORTBLOCKINFO Import block-level metadata from CSV/Excel into block structs
%
% Reads a CSV or Excel file and matches rows to specific blocks in a block
% struct array (from defineBlocks). Supports positional matching (row order)
% and key-based matching. Filtering by MarkerCode or Condition restricts
% which blocks receive metadata; non-matching blocks pass through unchanged.
%
% Syntax:
%   blocks = pf2.data.importBlockInfo(blocks, filepath)
%   blocks = pf2.data.importBlockInfo(blocks, filepath, 'MarkerCode', 49)
%   blocks = pf2.data.importBlockInfo(blocks, filepath, 'Keys', keyCol)
%   blocks = pf2.data.importBlockInfo(blocks, filepath, ..., 'Name', Value)
%
% Inputs:
%   blocks   - Struct array from pf2.data.defineBlocks [1 x N struct]
%              Each element has .markerCode, .info (with .BlockNumber, etc.)
%   filepath - Path to CSV (.csv) or Excel (.xlsx, .xls) file [char|string]
%
% Name-Value Parameters:
%   'Keys'        - Column name(s) for key-based matching [char|string|cellstr]
%                   When specified, uses exact-match semantics (like importInfo).
%                   When omitted, uses positional matching (row order).
%   'MarkerCode'  - Filter: only apply to blocks with this marker code [numeric]
%   'Condition'   - Filter: only apply to blocks with this condition label [char|string]
%   'Sheet'       - Sheet name or index for Excel files (default: 1)
%   'Overwrite'   - Overwrite existing .info fields (default: true)
%   'ReadOptions' - Cell array of extra arguments passed to readtable (default: {})
%
% Outputs:
%   blocks - Same struct array with .info fields updated on matched blocks.
%            Non-matching blocks (filtered out) are returned unchanged.
%
% Algorithm:
%   1. Read file into table via readtable
%   2. Apply MarkerCode/Condition filter to identify target blocks
%   3a. Positional mode: verify row count == filtered block count, then
%       assign row k to k-th filtered block
%   3b. Key mode: for each filtered block, find matching row (error on 0 or >1)
%   4. Copy columns into block .info (respecting Overwrite setting)
%   5. Warn if any CSV rows were not matched
%
% Example:
%   % Positional: row 1 -> block 1, row 2 -> block 2
%   blocks = pf2.data.importBlockInfo(blocks, 'trial_data.csv');
%
%   % Only apply to Task blocks (marker 49), skip Rest (marker 50)
%   blocks = pf2.data.importBlockInfo(blocks, 'trial_data.csv', ...
%       'MarkerCode', 49);
%
%   % Filter by condition label
%   blocks = pf2.data.importBlockInfo(blocks, 'trial_data.csv', ...
%       'Condition', 'Task');
%
%   % Key-based matching
%   blocks = pf2.data.importBlockInfo(blocks, 'trial_data.csv', ...
%       'Keys', 'BlockNumber');
%
% See also: pf2.data.importInfo, pf2.data.defineBlocks, pf2.data.extractBlocks

p = inputParser;
p.addParameter('Keys', {}, @(x) ischar(x) || isstring(x) || iscellstr(x));
p.addParameter('MarkerCode', [], @(x) isnumeric(x));
p.addParameter('Condition', '', @(x) ischar(x) || isstring(x));
p.addParameter('Sheet', 1, @(x) isnumeric(x) || ischar(x) || isstring(x));
p.addParameter('Overwrite', true, @islogical);
p.addParameter('ReadOptions', {}, @iscell);
p.parse(varargin{:});

keys = cellstr(p.Results.Keys);
if numel(keys) == 1 && isempty(keys{1})
    keys = {};
end
markerFilter = p.Results.MarkerCode;
condFilter = string(p.Results.Condition);
sheet = p.Results.Sheet;
overwrite = p.Results.Overwrite;
readOpts = p.Results.ReadOptions;

useKeyMode = ~isempty(keys);

% Validate file exists
if ~isfile(filepath)
    error('pf2:data:importBlockInfo:fileNotFound', ...
        'File not found: %s', filepath);
end

% Read file
readArgs = readOpts;
[~, ~, ext] = fileparts(filepath);
if any(strcmpi(ext, {'.xlsx', '.xls'}))
    readArgs = [readArgs, {'Sheet', sheet}];
end
tbl = readtable(filepath, readArgs{:});
colNames = tbl.Properties.VariableNames;

% Validate key columns exist in file
if useKeyMode
    for k = 1:numel(keys)
        if ~any(strcmp(colNames, keys{k}))
            error('pf2:data:importBlockInfo:keyNotInFile', ...
                'Key column ''%s'' not found in file. Available columns: %s', ...
                keys{k}, strjoin(colNames, ', '));
        end
    end
end

% Determine columns to copy (all columns if positional, non-key if key mode)
if useKeyMode
    copyCols = colNames(~ismember(colNames, keys));
else
    copyCols = colNames;
end

% Apply filter to find target block indices
nBlocks = numel(blocks);
filterMask = true(1, nBlocks);

if ~isempty(markerFilter)
    for b = 1:nBlocks
        filterMask(b) = filterMask(b) && ismember(blocks(b).markerCode, markerFilter);
    end
end

if strlength(condFilter) > 0
    for b = 1:nBlocks
        if isfield(blocks(b).info, 'Condition')
            filterMask(b) = filterMask(b) && string(blocks(b).info.Condition) == condFilter;
        else
            filterMask(b) = false;
        end
    end
end

targetIdx = find(filterMask);
nTargets = numel(targetIdx);

if useKeyMode
    % --- Key-based matching ---
    rowUsed = false(height(tbl), 1);

    for t = 1:nTargets
        bidx = targetIdx(t);
        blk = blocks(bidx);

        matchMask = true(height(tbl), 1);
        keyVals = cell(1, numel(keys));

        for k = 1:numel(keys)
            keyName = keys{k};

            % Look for key in block .info first, then top-level block fields
            if isfield(blk.info, keyName)
                infoVal = blk.info.(keyName);
            elseif isfield(blk, keyName)
                infoVal = blk.(keyName);
            else
                error('pf2:data:importBlockInfo:keyNotInBlock', ...
                    'Key field ''%s'' not found in block %d .info or block fields.', ...
                    keyName, bidx);
            end

            tblCol = tbl.(keyName);
            keyVals{k} = infoVal;

            if isnumeric(infoVal)
                if isnumeric(tblCol)
                    matchMask = matchMask & (tblCol == infoVal);
                else
                    matchMask = matchMask & (double(string(tblCol)) == infoVal);
                end
            else
                matchMask = matchMask & (string(tblCol) == string(infoVal));
            end
        end

        matchRows = find(matchMask);

        if isempty(matchRows)
            keyStr = strjoin(cellfun(@(k,v) sprintf('%s=%s', k, string(v)), ...
                keys, keyVals, 'UniformOutput', false), ', ');
            error('pf2:data:importBlockInfo:noMatch', ...
                'No rows match block %d (%s).', bidx, keyStr);
        end

        if numel(matchRows) > 1
            keyStr = strjoin(cellfun(@(k,v) sprintf('%s=%s', k, string(v)), ...
                keys, keyVals, 'UniformOutput', false), ', ');
            error('pf2:data:importBlockInfo:ambiguousMatch', ...
                'Multiple rows (%d) match block %d (%s).', numel(matchRows), bidx, keyStr);
        end

        rowUsed(matchRows) = true;
        blocks(bidx) = applyRow(blocks(bidx), tbl, matchRows, copyCols, overwrite);
    end

    % Warn about unused rows
    if any(~rowUsed)
        warning('pf2:data:importBlockInfo:unusedRows', ...
            '%d row(s) in file not matched to any block.', sum(~rowUsed));
    end

else
    % --- Positional matching ---
    nRows = height(tbl);

    if nRows ~= nTargets
        error('pf2:data:importBlockInfo:rowCountMismatch', ...
            'Row count (%d) does not match filtered block count (%d).', nRows, nTargets);
    end

    for t = 1:nTargets
        bidx = targetIdx(t);
        blocks(bidx) = applyRow(blocks(bidx), tbl, t, copyCols, overwrite);
    end
end

end

%%_Subfunctions_________________________________________________________

function blk = applyRow(blk, tbl, rowIdx, copyCols, overwrite)
% APPLYROW Copy table row columns into block .info
%
% Inputs:
%   blk      - Single block struct
%   tbl      - Table read from file
%   rowIdx   - Row index to copy from
%   copyCols - Cell array of column names to copy
%   overwrite - Whether to overwrite existing fields

for c = 1:numel(copyCols)
    colName = copyCols{c};
    if ~overwrite && isfield(blk.info, colName)
        continue;
    end
    val = tbl.(colName)(rowIdx);
    if iscell(val)
        blk.info.(colName) = val{1};
    elseif iscategorical(val)
        blk.info.(colName) = char(val);
    else
        blk.info.(colName) = val;
    end
end

end
