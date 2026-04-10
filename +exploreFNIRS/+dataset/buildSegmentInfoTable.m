function outTable = buildSegmentInfoTable(FNIRS_array)
% BUILDSEGMENTINFOTABLE Build a summary table from an array of fNIRS data structs
%
% Iterates over a cell array of processed fNIRS structs and extracts the
% .info fields from each into a standardized MATLAB table. Handles type
% mismatches and missing fields across segments by filling with NaN,
% empty strings, or NaT as appropriate.
%
% Uses a two-pass approach for performance: first discovers the complete
% field schema across all segments, then pre-allocates the table and fills
% rows with direct assignment. This avoids O(n*k) ismember calls and
% dynamic column growth.
%
% Syntax:
%   outTable = exploreFNIRS.dataset.buildSegmentInfoTable(FNIRS_array)
%
% Inputs:
%   FNIRS_array - Cell array of fNIRS data structs, each containing an
%                 .info sub-struct with metadata fields (e.g., subject ID,
%                 condition, age). Scalar numeric, string, char, logical,
%                 categorical, and single-cell table values are extracted.
%
% Outputs:
%   outTable - MATLAB table with one row per segment and columns for each
%              unique .info field found across all segments. Missing values
%              are filled with type-appropriate defaults.
%
% Example:
%   data = {seg1, seg2, seg3};  % cell array of fNIRS structs
%   infoTable = exploreFNIRS.dataset.buildSegmentInfoTable(data);
%   disp(infoTable);
%
% See also: exploreFNIRS.dataset.standardizeROIs, exploreFNIRS

if isempty(FNIRS_array)
    error('No Data to build exploreFNIRS data table!\n')
end

numF = length(FNIRS_array);

% -----------------------------------------------------------------------
% Pass 1: Discover schema — collect all unique field names and their types
% -----------------------------------------------------------------------
allFieldNames = {};
fieldTypeMap = struct();  % fieldName -> column type string

for i = 1:numF
    seg = FNIRS_array{i};
    if ~isfield(seg, 'info'), continue; end

    fNames = fieldnames(seg.info);
    for j = 1:length(fNames)
        fn = fNames{j};
        if isfield(fieldTypeMap, fn), continue; end  % already registered

        val = seg.info.(fn);
        colType = classifyForTable(val);
        if isempty(colType), continue; end  % not a valid info value

        allFieldNames{end+1} = fn; %#ok<AGROW>
        fieldTypeMap.(fn) = colType;
    end
end

nCols = length(allFieldNames);

if nCols == 0
    outTable = table('Size', [numF, 0], 'VariableTypes', {}, 'VariableNames', {});
    return;
end

% -----------------------------------------------------------------------
% Pre-allocate table with correct column types and defaults
% -----------------------------------------------------------------------
colTypes = cell(1, nCols);
for c = 1:nCols
    colTypes{c} = fieldTypeMap.(allFieldNames{c});
end

outTable = table('Size', [numF, nCols], ...
    'VariableTypes', colTypes, ...
    'VariableNames', allFieldNames);

% table() with 'Size' initializes: double→0, string→<missing>, etc.
% Override defaults: double→NaN, string→""
for c = 1:nCols
    switch colTypes{c}
        case 'double'
            outTable.(allFieldNames{c})(:) = NaN;
        case 'string'
            outTable.(allFieldNames{c})(:) = "";
        case 'datetime'
            outTable.(allFieldNames{c})(:) = NaT;
    end
end

% Build O(1) lookup: field name → column index
colIdx = containers.Map(allFieldNames, num2cell(1:nCols));

% -----------------------------------------------------------------------
% Pass 2: Fill rows with direct column assignment
% -----------------------------------------------------------------------
for i = 1:numF
    if mod(i, 500) == 0 || i == numF
        fprintf('Row %i of %i\n', i, numF);
    end

    seg = FNIRS_array{i};
    if ~isfield(seg, 'info'), continue; end

    fNames = fieldnames(seg.info);
    for j = 1:length(fNames)
        fn = fNames{j};
        if ~colIdx.isKey(fn), continue; end

        val = seg.info.(fn);
        if isempty(val), continue; end

        % Unwrap 1x1 table
        if istable(val) && size(val,1) == 1 && size(val,2) == 1
            val = val{1,1};
        end

        targetType = colTypes{colIdx(fn)};

        % Assign with type coercion
        switch targetType
            case 'double'
                if isnumeric(val) && isscalar(val)
                    outTable.(fn)(i) = double(val);
                elseif (isstring(val) || ischar(val)) && strcmpi(val, 'missing')
                    outTable.(fn)(i) = NaN;
                end
            case 'string'
                if ischar(val) || isstring(val)
                    outTable.(fn)(i) = string(strtrim(val));
                elseif islogical(val)
                    outTable.(fn)(i) = string(val);
                elseif iscategorical(val)
                    outTable.(fn)(i) = string(val);
                elseif isnumeric(val) && isscalar(val)
                    outTable.(fn)(i) = string(val);
                end
            case 'datetime'
                if isdatetime(val)
                    outTable.(fn)(i) = val;
                end
            case 'duration'
                if isduration(val)
                    outTable.(fn)(i) = val;
                end
        end
    end
end

end


% =========================================================================
% Local helper functions
% =========================================================================

function colType = classifyForTable(val)
% CLASSIFYFORTABLE Determine the table column type for an info field value.
%   Returns '' if the value is not suitable for table storage.

    colType = '';

    % Unwrap 1x1 table
    if istable(val) && size(val,1) == 1 && size(val,2) == 1
        val = val{1,1};
    end

    if isempty(val)
        return;  % can't determine type from empty
    elseif ischar(val) || isstring(val)
        colType = 'string';
    elseif isnumeric(val) && isscalar(val)
        colType = 'double';
    elseif islogical(val) && isscalar(val)
        colType = 'string';  % stored as string (matches original behavior)
    elseif iscategorical(val) && isscalar(val)
        colType = 'string';
    elseif isdatetime(val) && isscalar(val)
        colType = 'datetime';
    elseif isduration(val) && isscalar(val)
        colType = 'duration';
    end
    % Anything else (arrays, structs, cells, etc.) → not stored
end
