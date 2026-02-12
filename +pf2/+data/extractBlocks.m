function segments = extractBlocks(data, varargin)
% EXTRACTBLOCKS Extract each block as a separate fNIRS struct
%
% Takes an fNIRS data structure and a block definition array (from
% defineBlocks) and extracts each block as a separate fNIRS struct.
% Returns a cell array ready for exploreFNIRS.core.Experiment.
%
% Blocks can be provided explicitly as the second argument or read
% from data.blocks (set by defineBlocks with 'Embed', true). When
% data is a cell array, each element is extracted and results are
% concatenated.
%
% Syntax:
%   segments = pf2.data.extractBlocks(data, blocks)
%   segments = pf2.data.extractBlocks(data, blocks, 'Name', Value)
%   segments = pf2.data.extractBlocks(data)                % uses data.blocks
%   segments = pf2.data.extractBlocks(data, 'Name', Value) % uses data.blocks
%   segments = pf2.data.extractBlocks(cellData)             % cell array input
%
% Inputs:
%   data   - fNIRS data structure with time-series fields (.HbO, .time, etc.)
%            or a cell array of fNIRS structs (each with .blocks)
%   blocks - (Optional) Block definition struct array from pf2.data.defineBlocks
%            Each element must have .startTime, .endTime, and .info fields.
%            If omitted, data.blocks is used.
%
% Name-Value Parameters:
%   'PreTime'        - Seconds to include before block start (default: 120)
%   'PostTime'       - Seconds to include after block end (default: 120)
%   'BaselineWindow' - [start, end] relative to block start for baseline
%                      subtraction, e.g. [-5, 0] (default: [])
%   'SetT0'          - Shift time so block start = 0 (default: true)
%   'OverwriteInfo'  - Allow block.info fields to overwrite parent data.info
%                      fields of the same name (default: true). When false,
%                      parent fields are preserved and block.info only adds
%                      new fields.
%   'SkipInvalid'    - Skip blocks outside data time range (default: true)
%
% Outputs:
%   segments - Cell array {1 x N} of fNIRS structs, one per valid block
%              Each struct has merged .info from parent data and block.
%
% Algorithm:
%   1. For each block, compute extraction window with PreTime/PostTime
%   2. Optionally compute baseline window relative to block start
%   3. Call pf2.data.split to extract the time window
%   4. Optionally shift time with pf2.data.setT0 so block onset = 0
%   5. Merge parent data.info and block.info into segment.info
%
% Example:
%   blocks = pf2.data.defineBlocks(data, 'StartMarker', 50, 'EndMarker', 51);
%   segments = pf2.data.extractBlocks(data, blocks, ...
%       'PreTime', 5, 'PostTime', 2, ...
%       'BaselineWindow', [-5, 0], 'SetT0', true);
%
%   % Prevent block info from overwriting parent subject info
%   segments = pf2.data.extractBlocks(data, 'OverwriteInfo', false);
%
%   % Using embedded blocks
%   data = pf2.data.defineBlocks(data, [49,50], 30, 'Embed', true);
%   segments = pf2.data.extractBlocks(data, 'PreTime', 5);
%
%   % Cell array of subjects with embedded blocks
%   segments = pf2.data.extractBlocks(allData);
%
%   % Feed directly to Experiment
%   ex = exploreFNIRS.core.Experiment(segments);
%
% See also: pf2.data.defineBlocks, pf2.data.split, pf2.data.setT0

% --- Cell array input: iterate and concatenate ---
if iscell(data)
    segments = {};
    for i = 1:numel(data)
        segs = pf2.data.extractBlocks(data{i}, varargin{:});
        segments = [segments, segs]; %#ok<AGROW>
    end
    return;
end

% --- Resolve blocks: explicit argument or data.blocks ---
if ~isempty(varargin) && isstruct(varargin{1})
    blocks = varargin{1};
    nvArgs = varargin(2:end);
else
    if isfield(data, 'blocks') && ~isempty(data.blocks)
        blocks = data.blocks;
    else
        error('pf2:extractBlocks:noBlocks', ...
            'No blocks provided and data.blocks is empty. Call defineBlocks first.');
    end
    nvArgs = varargin;
end

p = inputParser;
p.addParameter('PreTime', 120, @(x) isnumeric(x) && isscalar(x) && x >= 0);
p.addParameter('PostTime', 120, @(x) isnumeric(x) && isscalar(x) && x >= 0);
p.addParameter('BaselineWindow', [], @(x) isempty(x) || (isnumeric(x) && numel(x) == 2));
p.addParameter('SetT0', true, @islogical);
p.addParameter('OverwriteInfo', true, @islogical);
p.addParameter('CopyInfo', true, @islogical);  % Kept for backward compat, ignored
p.addParameter('SkipInvalid', true, @islogical);
p.parse(nvArgs{:});

preTime = p.Results.PreTime;
postTime = p.Results.PostTime;
blWindow = p.Results.BaselineWindow;
doSetT0 = p.Results.SetT0;
overwriteInfo = p.Results.OverwriteInfo;
skipInvalid = p.Results.SkipInvalid;

if isempty(blocks)
    segments = {};
    return;
end

% Get data time range for validation
dataTimeMin = min(data.time);
dataTimeMax = max(data.time);

segments = {};
for k = 1:length(blocks)
    blk = blocks(k);

    % Compute extraction window
    extractStart = blk.startTime - preTime;
    extractEnd = blk.endTime + postTime;

    % Validate time range
    if skipInvalid
        if extractStart > dataTimeMax || extractEnd < dataTimeMin
            continue;
        end
    end

    % Extract segment using split (without baseline - apply separately)
    segment = pf2.data.split(data, extractStart, extractEnd);

    % Apply baseline subtraction if requested
    if ~isempty(blWindow)
        blAbsStart = blk.startTime + blWindow(1);
        blAbsEnd = blk.startTime + blWindow(2);

        if blAbsEnd > blAbsStart
            % Extract baseline period from original data
            blSeg = pf2.data.split(data, blAbsStart, blAbsEnd);

            % Subtract baseline mean from hemoglobin fields
            hbFields = {'HbO', 'HbR', 'HbDiff', 'HbTotal', 'CBSI'};
            for f = 1:length(hbFields)
                fn = hbFields{f};
                if isfield(segment, fn) && isfield(blSeg, fn)
                    segment.(fn) = segment.(fn) - mean(blSeg.(fn), 1, 'omitnan');
                end
            end
        end
    end

    % Skip empty/invalid segments
    if isfield(segment, 'empty') && segment.empty
        if skipInvalid
            continue;
        end
    end

    % Shift time so block start = 0
    if doSetT0
        segment = pf2.data.setT0(segment, blk.startTime);
    end

    % Remove parent blocks from segment (segments are individual blocks)
    if isfield(segment, 'blocks')
        segment = rmfield(segment, 'blocks');
    end

    % Merge info: start with parent data.info, overlay block.info
    mergedInfo = struct();
    if isfield(data, 'info')
        parentFields = fieldnames(data.info);
        for f = 1:length(parentFields)
            mergedInfo.(parentFields{f}) = data.info.(parentFields{f});
        end
    end

    % Overlay block-level info
    if isstruct(blk.info)
        blockFields = fieldnames(blk.info);
        for f = 1:length(blockFields)
            if overwriteInfo || ~isfield(mergedInfo, blockFields{f})
                mergedInfo.(blockFields{f}) = blk.info.(blockFields{f});
            end
        end
    end

    segment.info = mergedInfo;

    segments{end+1} = segment; %#ok<AGROW>
end

end
