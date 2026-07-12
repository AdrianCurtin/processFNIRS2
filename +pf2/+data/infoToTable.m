function T = infoToTable(data, varargin)
% INFOTOTABLE Extract .info metadata from fNIRS structs into a MATLAB table
%
% Collects the .info field from each element of a cell array (or single
% struct) into a MATLAB table with one row per struct and one column per
% info field. Only scalar-compatible values are extracted (numeric scalar,
% char, string, logical, categorical, datetime). Non-scalar fields (nested
% structs, arrays, cells) are silently skipped. Missing fields are filled
% with type-appropriate defaults (NaN, "", NaT).
%
% A single field name can be passed as the second argument to extract just
% that field as a column vector instead of a table. An optional SavePath
% writes the table to an Excel file.
%
% Syntax:
%   T    = pf2.data.infoToTable(data)
%   T    = pf2.data.infoToTable(data, 'Fields', {'SubjectID', 'Age', 'Group'})
%   vals = pf2.data.infoToTable(data, fieldName)
%   T    = pf2.data.infoToTable(data, 'SavePath', 'info.xlsx')
%
% Inputs:
%   data      - fNIRS data structure with .info field, or cell array of
%               such structures. Each struct's .info is a flat struct.
%   fieldName - (Optional positional) Single field name [char|string].
%               When provided, returns a column vector of that field's
%               values instead of a table.
%
% Name-Value Parameters:
%   'Fields'   - Cell array of field names to include (default: all)
%                If specified, only these columns appear in the output table.
%                Fields not found in any struct are still included as columns
%                filled with their type-appropriate missing value.
%   'SavePath' - File path to write the table as Excel (.xlsx) [char|string]
%                (default: ''). Ignored in single-field vector mode.
%
% Outputs:
%   T    - MATLAB table [N x F], or column vector [N x 1] when a single
%          field name is given as a positional argument.
%
% Example:
%   allData = {processed1, processed2, processed3};
%   T = pf2.data.infoToTable(allData);
%   disp(T);
%
%   % Select specific fields
%   T = pf2.data.infoToTable(allData, 'Fields', {'SubjectID', 'Group'});
%
%   % Extract single field as vector
%   groups = pf2.data.infoToTable(allData, 'Group');
%
%   % Export to Excel
%   T = pf2.data.infoToTable(allData, 'SavePath', 'metadata.xlsx');
%
% See also: pf2.data.infoFromTable, pf2.data.importInfo

% --- Detect single-field positional argument ---
singleField = '';
remainingArgs = varargin;
nvNames = {'Fields', 'SavePath'};
if ~isempty(varargin) && (ischar(varargin{1}) || (isstring(varargin{1}) && isscalar(varargin{1})))
    candidate = char(varargin{1});
    % Check if it's a name-value parameter name
    if ~any(strcmpi(candidate, nvNames))
        singleField = candidate;
        remainingArgs = varargin(2:end);
    end
end

% --- Parse remaining name-value arguments ---
p = inputParser;
p.addParameter('Fields', {}, @(x) ischar(x) || isstring(x) || iscellstr(x));
p.addParameter('SavePath', '', @(x) ischar(x) || isstring(x));
p.parse(remainingArgs{:});
requestedFields = cellstr(p.Results.Fields);
hasFieldFilter = ~isempty(requestedFields) && ~(numel(requestedFields) == 1 && isempty(requestedFields{1}));
savePath = char(p.Results.SavePath);

% Single-field mode overrides Fields parameter
returnVector = ~isempty(singleField);
if returnVector
    requestedFields = {singleField};
    hasFieldFilter = true;
end

% --- Normalize to cell array ---
if ~iscell(data)
    dataCell = {data};
else
    dataCell = data;
end
N = numel(dataCell);

if N == 0
    T = table();
    return;
end

% --- Pass 1: Discover all scalar-compatible fields and their types ---
% Map: fieldName -> MATLAB class name (first non-empty encounter wins)
allFields = {};
fieldTypes = struct();

for i = 1:N
    d = dataCell{i};
    if ~isfield(d, 'info') || ~isstruct(d.info)
        continue;
    end
    fnames = fieldnames(d.info);
    for j = 1:numel(fnames)
        fn = fnames{j};
        val = d.info.(fn);
        if ~isScalarCompatible(val)
            continue;
        end
        if ~ismember(fn, allFields)
            allFields{end+1} = fn; %#ok<AGROW>
            fieldTypes.(fn) = classOfValue(val);
        end
    end
end

% --- Apply field filter ---
if hasFieldFilter
    colNames = requestedFields;
else
    colNames = allFields;
end

if isempty(colNames)
    T = table();
    T = T(ones(N, 0), :); % N rows, 0 columns -> won't work; just return empty
    % Actually return a table with N rows and no columns
    T = cell2table(cell(N, 0));
    return;
end

% --- Pass 2: Build column arrays ---
cols = cell(1, numel(colNames));
for c = 1:numel(colNames)
    fn = colNames{c};

    % Determine column type
    if isfield(fieldTypes, fn)
        colType = fieldTypes.(fn);
    else
        colType = 'string'; % unknown fields default to string
    end

    % Initialize column with missing values
    col = initMissingColumn(N, colType);

    % Fill values
    for i = 1:N
        d = dataCell{i};
        if ~isfield(d, 'info') || ~isstruct(d.info) || ~isfield(d.info, fn)
            continue;
        end
        val = d.info.(fn);
        if ~isScalarCompatible(val)
            continue;
        end

        % Coerce to column type
        col(i) = coerceValue(val, colType);
    end

    cols{c} = col;
end

% --- Assemble table or return vector ---
if returnVector
    T = cols{1};
else
    T = table(cols{:}, 'VariableNames', colNames);
end

% --- Export to file if requested ---
if ~isempty(savePath) && ~returnVector
    writetable(T, savePath);
    fprintf('Saved info table to: %s\n', savePath);
end

end

% =========================================================================
% Local functions
% =========================================================================

function tf = isScalarCompatible(val)
% Returns true if val can be stored as a single table cell
    if isempty(val)
        % empty char '' or empty numeric [] -- allow empty char
        if ischar(val) && isequal(size(val), [1 0])
            tf = true; % empty char ''
        else
            tf = false;
        end
        return;
    end
    if isstruct(val) || iscell(val) || istable(val)
        tf = false;
        return;
    end
    if (isnumeric(val) || islogical(val)) && ~isscalar(val)
        tf = false;
        return;
    end
    if ischar(val) && size(val, 1) > 1
        tf = false; % multi-row char array
        return;
    end
    if (iscategorical(val) || isdatetime(val) || isduration(val)) && ~isscalar(val)
        tf = false;
        return;
    end
    tf = true;
end

function cls = classOfValue(val)
% Determine storage class for a scalar-compatible value
    if ischar(val) || isstring(val) || iscategorical(val)
        cls = 'string';
    elseif islogical(val)
        cls = 'logical';
    elseif isdatetime(val)
        cls = 'datetime';
    elseif isduration(val)
        cls = 'duration';
    elseif isnumeric(val)
        cls = 'double';
    else
        cls = 'string'; % fallback
    end
end

function col = initMissingColumn(N, colType)
% Create an N-element column filled with the type-appropriate missing value
    switch colType
        case 'double'
            col = nan(N, 1);
        case 'string'
            col = repmat("", N, 1);
        case 'logical'
            % Store as double to allow NaN for missing
            col = nan(N, 1);
        case 'datetime'
            col = NaT(N, 1);
        case 'duration'
            col = duration(nan(N, 1), 0, 0);
        otherwise
            col = repmat("", N, 1);
    end
end

function out = coerceValue(val, colType)
% Coerce a scalar value into the target column type
    switch colType
        case 'double'
            if isnumeric(val)
                out = double(val);
            elseif islogical(val)
                out = double(val);
            else
                out = NaN;
            end
        case 'string'
            if ischar(val) || isstring(val)
                out = string(strtrim(val));
            elseif iscategorical(val)
                out = string(val);
            elseif isnumeric(val)
                out = string(num2str(val));
            elseif islogical(val)
                out = string(num2str(val));
            else
                out = string(val);
            end
        case 'logical'
            % Stored as double column to allow NaN
            if islogical(val)
                out = double(val);
            elseif isnumeric(val)
                out = double(val);
            else
                out = NaN;
            end
        case 'datetime'
            if isdatetime(val)
                out = val;
            else
                out = NaT;
            end
        case 'duration'
            if isduration(val)
                out = val;
            else
                out = duration(NaN, 0, 0);
            end
        otherwise
            out = string(val);
    end
end
