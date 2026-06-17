function blocks = defineBlocks(data, varargin)
% DEFINEBLOCKS Create block definition struct array from event markers
%
% Parses fNIRS markers into a block definition array describing time
% windows for epoching, GLM design matrices, or connectivity analysis.
% Supports simple positional syntax for common cases and name-value
% parameters for advanced configuration.
%
% Syntax:
%   blocks = pf2.data.defineBlocks(data, markerCodes)
%   blocks = pf2.data.defineBlocks(data, markerCodes, duration)
%   blocks = pf2.data.defineBlocks(data, markerCodes, 'EndMarker', endCode)
%   blocks = pf2.data.defineBlocks(data, 'MarkerCode', code, 'Duration', dur)
%   blocks = pf2.data.defineBlocks(data, 'MarkerCode', code, 'EndMarker', endCode)
%   blocks = pf2.data.defineBlocks(data, 'StartMarker', s, 'EndMarker', e)
%   data   = pf2.data.defineBlocks(data, ..., 'Embed', true)
%   allData = pf2.data.defineBlocks(allData, ..., 'Embed', true) % cell array
%   blocks = pf2.data.defineBlocks(data, ..., 'Name', Value)
%
% Inputs:
%   data         - fNIRS data structure with .markers field, or a cell
%                  array of fNIRS structs (requires 'Embed', true)
%                  Markers are a canonical table with variables .Time,
%                  .Code, .Duration, .Amplitude (+ optional extra columns)
%   markerCodes  - (Optional positional) Marker code(s) to find [numeric]
%                  Scalar or vector; all codes are treated as separate block types.
%   duration     - (Optional positional) Fixed block duration in seconds [scalar]
%                  If omitted and markers have nonzero .Duration values,
%                  those durations are used automatically.
%
% Name-Value Parameters:
%   'MarkerCode'   - Marker code(s) to define blocks [scalar or vector]
%   'Duration'     - Fixed duration in seconds for each block (default: 0)
%                    If 0 and markers have nonzero .Duration values, those
%                    are used. Otherwise blocks have zero duration.
%   'UseDuration'  - Force use of duration from markers .Duration (default: false)
%   'StartMarker'  - Start marker code(s) for paired extraction [scalar or column vector]
%   'EndMarker'    - End marker code(s) for paired extraction [scalar or column vector]
%                    Can be used with StartMarker or MarkerCode.
%                    Must match StartMarker/MarkerCode length or be scalar.
%   'ConditionMap' - Cell array mapping marker codes to labels (default: {})
%                    Two-column: {code1, 'Label1'; code2, 'Label2'}
%                    Multi-column: {code1, 'Easy', 'Stroop'; code2, 'Hard', 'Stroop'}
%                    Extra columns map to extra fields via ConditionField.
%                    When omitted and data.info.eventTypes exists (from BIDS
%                    events.tsv), the mapping is auto-populated for requested codes.
%   'ConditionField' - Field name(s) for ConditionMap labels (default: 'Condition')
%                      Char for single field, cell array for multiple:
%                      {'Condition', 'Task'} maps columns 2, 3 of ConditionMap.
%   'InfoTable'    - Table with one row per block (default: [])
%                    Column names become .info fields for each block.
%   'InfoFields'   - Struct of constant fields applied to all blocks (default: struct())
%   'MinDuration'  - Reject blocks shorter than this in seconds (default: 0)
%   'MaxDuration'  - Reject blocks longer than this in seconds (default: Inf)
%   'SortByTime'   - Sort blocks chronologically (default: true)
%   'PrePad'       - Seconds to include before block start (default: 0)
%                    Shifts startTime earlier by this amount.
%   'PostPad'      - Seconds to include after block end (default: 0)
%                    Shifts endTime later by this amount.
%   'Embed'        - Store blocks on data.blocks and return the data struct
%                    instead of the blocks array (default: true).
%                    Set false to return just the blocks struct array.
%
% Outputs:
%   blocks - Struct array [1 x N] (or data struct if Embed=true) with fields:
%            .startTime   - Block start time in seconds (absolute)
%            .endTime     - Block end time in seconds
%            .duration    - endTime - startTime in seconds
%            .markerCode  - Marker code that triggered this block
%            .markerIndex - Row index into data.markers
%            .amplitude   - Marker amplitude from .Amplitude (default 1)
%            .info        - Struct with block-level metadata:
%                           .BlockNumber - Sequential 1, 2, 3...
%                           .(ConditionField) - From ConditionMap (default 'Condition')
%                           ... any user fields from InfoTable/InfoFields
%
% Algorithm:
%   1. Normalize markers to the canonical table (.Time, .Code, .Duration,
%      .Amplitude) and read out the numeric values needed below
%   2. Select mode: MarkerCode (fixed duration), MarkerCode+EndMarker
%      (pair start codes with terminating marker), or StartMarker+EndMarker
%   3. For MarkerCode: duration from fixed > marker .Duration > zero
%      For MarkerCode+EndMarker or StartMarker+EndMarker: pair each start
%      with the next available end marker to determine duration
%   4. Build struct array with startTime, endTime, duration, markerCode, markerIndex
%   5. Apply PrePad/PostPad to extend block boundaries
%   6. Auto-populate ConditionMap from data.info.eventTypes if not provided
%   7. Apply ConditionMap, InfoTable, InfoFields to .info
%   8. Filter by MinDuration/MaxDuration, sort by time
%
% Example:
%   % Simple: marker codes + fixed duration
%   blocks = pf2.data.defineBlocks(data, [49, 50], 30);
%
%   % Auto-detect duration from marker .Duration
%   blocks = pf2.data.defineBlocks(data, 49);
%
%   % Marker code + end marker (duration from terminating marker)
%   blocks = pf2.data.defineBlocks(data, [49, 50], 'EndMarker', 51);
%
%   % Per-code end markers: 49->59, 48->58
%   blocks = pf2.data.defineBlocks(data, [49, 48], 'EndMarker', [59, 58]);
%
%   % Start/end pairs with condition mapping
%   blocks = pf2.data.defineBlocks(data, ...
%       'StartMarker', [50; 51], 'EndMarker', [52; 53], ...
%       'ConditionMap', {50, 'Natural'; 51, 'Synthetic'});
%
%   % With pre/post padding and metadata
%   blocks = pf2.data.defineBlocks(data, 49, 30, ...
%       'PrePad', 5, 'PostPad', 2, ...
%       'ConditionMap', {49, 'Stroop'});
%
%   % Embed blocks on the data struct (returns data, not blocks)
%   data = pf2.data.defineBlocks(data, [49,50], 30, 'Embed', true);
%   segments = pf2.data.extractBlocks(data);  % uses data.blocks
%
%   % Cell array: embed blocks on every subject in one call
%   allData = pf2.data.defineBlocks(allData, [49,50], 30, ...
%       'ConditionMap', {49,'Easy';50,'Hard'}, 'Embed', true);
%   segments = pf2.data.extractBlocks(allData);
%
%   % BIDS auto-labeling: when data has .info.eventTypes from events.tsv,
%   % ConditionMap is auto-populated (no manual mapping needed)
%   data = pf2.import.importSNIRF('sub-01_nirs.snirf');
%   blocks = pf2.data.defineBlocks(data, [1, 2, 3]);  % auto-labeled
%
% See also: pf2.data.extractBlocks, pf2.data.getMarkers, pf2.data.split

% --- Cell array input: apply to each element (requires Embed) ---
if iscell(data)
    blocks = data;
    for ci = 1:numel(data)
        blocks{ci} = pf2.data.defineBlocks(data{ci}, varargin{:});
    end
    return;
end

% --- Parse simple positional args vs name-value ---
% Detect: defineBlocks(data, numericCodes) or defineBlocks(data, numericCodes, numericDuration)
positionalCodes = [];
positionalDuration = [];
remainingArgs = varargin;

if ~isempty(varargin) && isnumeric(varargin{1})
    positionalCodes = varargin{1};
    remainingArgs = varargin(2:end);

    if ~isempty(remainingArgs) && isnumeric(remainingArgs{1}) && isscalar(remainingArgs{1})
        positionalDuration = remainingArgs{1};
        remainingArgs = remainingArgs(2:end);
    end
end

p = inputParser;
p.addParameter('MarkerCode', [], @(x) isnumeric(x));
p.addParameter('Duration', 0, @(x) isnumeric(x) && isscalar(x) && x >= 0);
p.addParameter('UseDuration', false, @islogical);
p.addParameter('StartMarker', [], @(x) isnumeric(x));
p.addParameter('EndMarker', [], @(x) isnumeric(x));
p.addParameter('ConditionMap', {}, @iscell);
p.addParameter('ConditionField', 'Condition', @(x) ischar(x) || isstring(x) || iscellstr(x));
p.addParameter('InfoTable', [], @(x) isempty(x) || istable(x));
p.addParameter('InfoFields', struct(), @isstruct);
p.addParameter('MinDuration', 0, @(x) isnumeric(x) && isscalar(x));
p.addParameter('MaxDuration', Inf, @(x) isnumeric(x) && isscalar(x));
p.addParameter('SortByTime', true, @islogical);
p.addParameter('PrePad', 0, @(x) isnumeric(x) && isscalar(x) && x >= 0);
p.addParameter('PostPad', 0, @(x) isnumeric(x) && isscalar(x) && x >= 0);
p.addParameter('Embed', true, @islogical);
p.parse(remainingArgs{:});

% Merge positional args with name-value (positional takes precedence)
if ~isempty(positionalCodes)
    markerCode = positionalCodes(:);  % Always treat as column (OR logic)
else
    markerCode = p.Results.MarkerCode;
end

if ~isempty(positionalDuration)
    fixedDuration = positionalDuration;
else
    fixedDuration = p.Results.Duration;
end

useDuration = p.Results.UseDuration;
startMarker = p.Results.StartMarker;
endMarker = p.Results.EndMarker;
conditionMap = p.Results.ConditionMap;
conditionField = p.Results.ConditionField;
if ischar(conditionField) || isstring(conditionField)
    conditionField = {char(conditionField)};
end
infoTable = p.Results.InfoTable;
infoFields = p.Results.InfoFields;
minDur = p.Results.MinDuration;
maxDur = p.Results.MaxDuration;
sortByTime = p.Results.SortByTime;
prePad = p.Results.PrePad;
postPad = p.Results.PostPad;
embedBlocks = p.Results.Embed;

% Validate input data
if ~isstruct(data) || ~isfield(data, 'markers')
    error('pf2:defineBlocks:badInput', 'First argument must be an fNIRS struct with .markers field.');
end

% Validate mode: MarkerCode, MarkerCode+EndMarker, or StartMarker+EndMarker
hasMarkerCode = ~isempty(markerCode);
hasStartMarker = ~isempty(startMarker);
hasEndMarker = ~isempty(endMarker);

if ~hasMarkerCode && ~hasStartMarker
    error('pf2:defineBlocks:noMode', ...
        'Must specify marker codes or ''StartMarker''.');
end

if hasMarkerCode && hasStartMarker
    error('pf2:defineBlocks:ambiguousMode', ...
        'Cannot specify both marker codes and ''StartMarker''.');
end

if hasStartMarker && ~hasEndMarker
    error('pf2:defineBlocks:missingEndMarker', ...
        '''StartMarker'' requires ''EndMarker''.');
end

% Convert markers to a numeric array [time, value, duration, amplitude]
% for the positional column math in the block builders below. The stored
% data.markers field remains a canonical table.
mrk = pf2_base.markersToArray(data.markers);

if isempty(mrk) || size(mrk, 1) == 0
    blocks = struct('startTime', {}, 'endTime', {}, 'duration', {}, ...
        'markerCode', {}, 'markerIndex', {}, 'amplitude', {}, 'info', {});
    if embedBlocks
        data.blocks = blocks;
        blocks = data;
    end
    return;
end

% Build blocks based on mode
if hasMarkerCode && hasEndMarker
    % MarkerCode + EndMarker: use start/end pairing with MarkerCode as start
    blocks = buildFromStartEnd(mrk, markerCode, endMarker);
elseif hasMarkerCode
    blocks = buildFromMarkerCode(mrk, markerCode, fixedDuration, useDuration);
else
    blocks = buildFromStartEnd(mrk, startMarker, endMarker);
end

if isempty(blocks)
    if embedBlocks
        data.blocks = blocks;
        blocks = data;
    end
    return;
end

% Apply PrePad / PostPad
if prePad > 0 || postPad > 0
    for k = 1:length(blocks)
        blocks(k).startTime = blocks(k).startTime - prePad;
        blocks(k).endTime = blocks(k).endTime + postPad;
        blocks(k).duration = blocks(k).endTime - blocks(k).startTime;
    end
end

% Sort by time
if sortByTime
    [~, sortIdx] = sort([blocks.startTime]);
    blocks = blocks(sortIdx);
end

% Assign BlockNumber
for k = 1:length(blocks)
    blocks(k).info.BlockNumber = k;
end

% Auto-populate ConditionMap from the dataset's marker dictionary when not
% explicitly provided (markerDict -> eventTypes -> COBI MarkerDict).
if isempty(conditionMap) && ismember('ConditionMap', p.UsingDefaults) && isstruct(data)
    dict = pf2.data.getMarkerDict(data);
    dict = dict(~ismissing(dict.Label), :);
    if ~isempty(dict)
        % Determine which codes are being extracted
        if hasMarkerCode
            allCodes = markerCode(:);
        elseif hasStartMarker
            allCodes = startMarker(:);
        else
            allCodes = [];
        end
        if ~isempty(allCodes)
            keep = ismember(dict.Code, allCodes);
            if any(keep)
                conditionMap = [num2cell(dict.Code(keep)), cellstr(dict.Label(keep))];
            end
        end
    end
end

% Apply ConditionMap
if ~isempty(conditionMap) && size(conditionMap, 2) >= 2
    mapCodes = cell2mat(conditionMap(:, 1));
    nFields = min(length(conditionField), size(conditionMap, 2) - 1);
    for k = 1:length(blocks)
        idx = find(mapCodes == blocks(k).markerCode, 1);
        if ~isempty(idx)
            for f = 1:nFields
                blocks(k).info.(conditionField{f}) = conditionMap{idx, f + 1};
            end
        end
    end
end

% Apply InfoTable (row k -> block k)
if ~isempty(infoTable)
    nRows = height(infoTable);
    nBlocks = length(blocks);
    nApply = min(nRows, nBlocks);
    colNames = infoTable.Properties.VariableNames;
    for k = 1:nApply
        for c = 1:length(colNames)
            val = infoTable.(colNames{c})(k);
            if iscell(val)
                blocks(k).info.(colNames{c}) = val{1};
            else
                blocks(k).info.(colNames{c}) = val;
            end
        end
    end
end

% Apply InfoFields (constant across all blocks)
if ~isempty(fieldnames(infoFields))
    fNames = fieldnames(infoFields);
    for k = 1:length(blocks)
        for f = 1:length(fNames)
            blocks(k).info.(fNames{f}) = infoFields.(fNames{f});
        end
    end
end

% Filter by duration
if minDur > 0 || isfinite(maxDur)
    keep = arrayfun(@(b) b.duration >= minDur && b.duration <= maxDur, blocks);
    blocks = blocks(keep);
    % Re-number after filtering
    for k = 1:length(blocks)
        blocks(k).info.BlockNumber = k;
    end
end

% Embed: store blocks on data struct and return data instead
if embedBlocks
    data.blocks = blocks;
    blocks = data;
end

end

%%_Subfunctions_________________________________________________________

function blocks = buildFromMarkerCode(mrk, markerCode, fixedDuration, useDuration)
% BUILDFROMMARKERCODE Find markers matching code and build blocks
%
% Inputs:
%   mrk           - Normalized marker array [M x 4]
%   markerCode    - Marker code(s) to match [column vector]
%   fixedDuration - Fixed block duration in seconds (0 = auto from markers)
%   useDuration   - Force use of column 3 duration
%
% Outputs:
%   blocks - Struct array of block definitions

mrkValues = mrk(:, 2);
mrkTimes = mrk(:, 1);
mrkDurations = mrk(:, 3);
mrkAmplitudes = mrk(:, 4);

% Find matching markers
matchIdx = find(ismember(mrkValues, markerCode(:)));

if isempty(matchIdx)
    blocks = struct('startTime', {}, 'endTime', {}, 'duration', {}, ...
        'markerCode', {}, 'markerIndex', {}, 'amplitude', {}, 'info', {});
    return;
end

nBlocks = length(matchIdx);
blocks = repmat(struct('startTime', 0, 'endTime', 0, 'duration', 0, ...
    'markerCode', 0, 'markerIndex', 0, 'amplitude', 1, 'info', struct()), 1, nBlocks);

for k = 1:nBlocks
    idx = matchIdx(k);
    st = mrkTimes(idx);
    code = mrkValues(idx);

    if useDuration
        % Explicitly requested: always use column 3
        dur = mrkDurations(idx);
    elseif fixedDuration > 0
        % Fixed duration provided: use it
        dur = fixedDuration;
    else
        % Auto: if marker has nonzero duration in column 3, use it
        dur = mrkDurations(idx);
    end

    blocks(k).startTime = st;
    blocks(k).endTime = st + dur;
    blocks(k).duration = dur;
    blocks(k).markerCode = code;
    blocks(k).markerIndex = idx;
    blocks(k).amplitude = mrkAmplitudes(idx);
    blocks(k).info = struct();
end

end

function blocks = buildFromStartEnd(mrk, startMarker, endMarker)
% BUILDFROMSTARTEND Pair start/end markers to build blocks
%
% Inputs:
%   mrk         - Normalized marker array [M x 4]
%   startMarker - Start marker code(s) [column vector]
%   endMarker   - End marker code(s) [column vector]
%
% Outputs:
%   blocks - Struct array of block definitions

mrkValues = mrk(:, 2);
mrkTimes = mrk(:, 1);
mrkAmplitudes = mrk(:, 4);

% Ensure column vectors
startMarker = startMarker(:);
endMarker = endMarker(:);

% If scalar endMarker, expand to match startMarker
if isscalar(endMarker) && ~isscalar(startMarker)
    endMarker = repmat(endMarker, size(startMarker));
end
if isscalar(startMarker) && ~isscalar(endMarker)
    startMarker = repmat(startMarker, size(endMarker));
end

if length(startMarker) ~= length(endMarker)
    error('pf2:defineBlocks:markerMismatch', ...
        'StartMarker and EndMarker must have the same number of elements (or one must be scalar).');
end

blockList = [];
for pidx = 1:length(startMarker)
    sCode = startMarker(pidx);
    eCode = endMarker(pidx);

    sIdx = find(mrkValues == sCode);
    eIdx = find(mrkValues == eCode);

    % Pair each start with the next available end
    for s = 1:length(sIdx)
        si = sIdx(s);
        st = mrkTimes(si);
        % Find first end marker after this start
        validEnds = eIdx(mrkTimes(eIdx) > st);
        if isempty(validEnds)
            continue;
        end
        ei = validEnds(1);
        et = mrkTimes(ei);

        entry.startTime = st;
        entry.endTime = et;
        entry.duration = et - st;
        entry.markerCode = sCode;
        entry.markerIndex = si;
        entry.amplitude = mrkAmplitudes(si);
        entry.info = struct();

        if isempty(blockList)
            blockList = entry;
        else
            blockList(end+1) = entry; %#ok<AGROW>
        end

        % Remove this end marker from available pool so it's not reused
        eIdx(eIdx == ei) = [];
    end
end

if isempty(blockList)
    blocks = struct('startTime', {}, 'endTime', {}, 'duration', {}, ...
        'markerCode', {}, 'markerIndex', {}, 'amplitude', {}, 'info', {});
else
    blocks = blockList;
end

end
