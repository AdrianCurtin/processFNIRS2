function out = canonicalize(data, opts)
% CANONICALIZE Project channel data onto a common anatomical region grid
%
% Maps each channel of a processed recording to its nearest anatomical
% region (Brodmann area) and averages channel biomarker time series within
% each region, producing a region-indexed representation that is directly
% comparable across montages and devices. This solves the cross-device
% group-analysis problem: two datasets recorded with different probes,
% channel counts, or hardware yield matrices on an identical, fixed region
% axis. Region averaging reuses the volumetric Brodmann atlas via
% pf2.probe.nearestBrodmann.
%
% When given a cell array, all datasets are projected onto a single shared
% region set (the union of mapped regions, unless 'Regions' is given), so
% every element's canonical matrix shares the same column ordering - the
% prerequisite for pooling heterogeneous datasets in one analysis.
%
% Syntax:
%   out = pf2.probe.canonicalize(data)
%   out = pf2.probe.canonicalize(data, 'MaxDistance', 20)
%   out = pf2.probe.canonicalize(data, 'Regions', [9 10 46])
%   out = pf2.probe.canonicalize(allData)            % shared region axis
%
% Inputs:
%   data          - Processed fNIRS struct with biomarker fields (HbO, ...),
%                   a .time field, and a device carrying 3D MNI positions;
%                   or a cell array of such structs.
%   'MaxDistance' - Max channel-to-region distance in mm for assignment
%                   (default: 20). Channels with no region within this
%                   distance are dropped from the projection.
%   'Regions'     - Explicit Brodmann area numbers defining the region axis
%                   (default: []). When empty, the axis is the set of regions
%                   the data actually maps to (union across a cell array).
%   'Space'       - Anatomical target space (default: 'Brodmann'). Only
%                   'Brodmann' is currently supported.
%   'Aggregate'   - Channel aggregation within a region (default: 'nanmean').
%                   'nanmean' ignores NaN channels; 'mean' propagates NaN.
%
% Outputs:
%   out - Same shape as the input (struct or cell array). Each struct gains a
%         .canonical field:
%           .space       - 'Brodmann' [char]
%           .regions     - Table [R rows]: Index (1..R), BA, Name
%           .time        - Time vector copied from the source [T x 1]
%           .<biomarker> - [T x R] region-averaged series, one per biomarker
%                          present in the source (HbO/HbR/HbTotal/HbDiff/CBSI).
%                          Columns with no contributing channel are NaN.
%           .N           - [1 x R] channel count contributing to each region
%           .channelBA   - [nCh x 1] BA assigned to each source channel
%                          (NaN if unassigned), for traceability
%           .MaxDistance - Distance threshold used [mm]
%
% Algorithm:
%   1. Assign each channel to its nearest Brodmann area within MaxDistance
%      (pf2.probe.nearestBrodmann with N=1)
%   2. Determine the region axis: explicit 'Regions', else the union of
%      assigned regions across all input datasets
%   3. For each region, average the contributing channels per biomarker
%      (nanmean by default) into a [T x 1] column
%   4. Assemble .canonical with a shared, sorted region table
%
% Example:
%   % Single subject: prefrontal probe -> region-indexed HbO
%   data = pf2.import.sampleData();
%   proc = processFNIRS2(data);
%   proc = pf2.probe.canonicalize(proc, 'MaxDistance', 20);
%   proc.canonical.regions               % Index / BA / Name
%   size(proc.canonical.HbO)             % [T x R]
%
%   % Group of mixed devices onto one shared region axis
%   allData = pf2.probe.canonicalize(allData);
%   allData{1}.canonical.regions         % identical to allData{2}.canonical.regions
%
% Notes:
%   - Requires 3D MNI coordinates; layout-only devices error with guidance.
%   - Brodmann assignment for idealized-template coordinates is a group-level
%     approximation (see pf2.probe.nearestBrodmann); for pediatric data an
%     adult MNI atlas adds further approximation.
%   - fNIRS channels sample a volume, not a point, so nearest-single-BA
%     assignment is a coarse harmonizer. Dense single-region montages (e.g.
%     frontal) can collapse most channels into one BA, erasing L/R or
%     dorsal/ventral structure (a regionCollapse warning is emitted). A
%     hand-curated ROI scheme (exploreFNIRS.dataset.standardizeROIs) may be
%     more faithful in that case.
%   - Cross-device pooling caveats: a region's NaN column is structurally
%     (montage-)missing, not missing-at-random, so prefer regions covered in
%     all groups for group contrasts. Carry .N as a per-region weight, since a
%     region may average many channels in one subject and one in another.
%     Datasets must share biomarker units (a unitsMismatch warning is emitted
%     for cell-array input) and ideally comparable source-detector ranges.
%
% See also: pf2.probe.nearestBrodmann, exploreFNIRS.dataset.standardizeROIs,
%           pf2.probe.roi.defineROI, pf2.data.extractBlocks

% --- Parse inputs ---
arguments
    data
    opts.MaxDistance (1,1) {mustBeNumeric} = 20
    opts.Regions = []
    opts.Space = 'Brodmann'
    opts.Aggregate = 'nanmean'
end

maxDist   = opts.MaxDistance;
regions   = opts.Regions(:)';
space     = char(opts.Space);
aggregate = lower(char(opts.Aggregate));

if ~strcmpi(space, 'Brodmann')
    error('pf2:probe:canonicalize:unsupportedSpace', ...
        'Only ''Brodmann'' space is supported (got ''%s'').', space);
end
if ~ismember(aggregate, {'nanmean', 'mean'})
    error('pf2:probe:canonicalize:badAggregate', ...
        '''Aggregate'' must be ''nanmean'' or ''mean''.');
end

isCellInput = iscell(data);
if isCellInput
    items = data;
else
    items = {data};
end
nItems = numel(items);

% Cross-device units guard: averaging into a shared axis assumes comparable
% units. Warn (don't block) when a cell array mixes biomarker units.
if isCellInput
    unitSet = strings(0, 1);
    for i = 1:nItems
        if isstruct(items{i}) && isfield(items{i}, 'units') && ~isempty(items{i}.units)
            unitSet(end+1, 1) = string(items{i}.units); %#ok<AGROW>
        end
    end
    if numel(unique(unitSet)) > 1
        warning('pf2:probe:canonicalize:unitsMismatch', ...
            ['Datasets carry mixed biomarker units (%s); canonicalized values ', ...
             'are not comparable across them. Reprocess to common units before ', ...
             'pooling.'], strjoin(unique(unitSet)', ', '));
    end
end

% --- Pass 1: assign channels to Brodmann areas for every dataset ---
baMaps   = cell(1, nItems);   % per-channel BA (NaN if unassigned)
nameByBA = containers.Map('KeyType', 'double', 'ValueType', 'char');
for i = 1:nItems
    [baMaps{i}, nameByBA] = mapChannelsToBA(items{i}, maxDist, nameByBA);
end

% Report channels dropped beyond MaxDistance and montages that collapse into a
% single region (which erases within-region structure such as L/R).
totalCh = 0; totalDropped = 0; collapsed = 0;
for i = 1:nItems
    bm = baMaps{i};
    totalCh = totalCh + numel(bm);
    totalDropped = totalDropped + sum(isnan(bm));
    assigned = bm(~isnan(bm));
    if numel(assigned) >= 4
        u = unique(assigned);
        counts = arrayfun(@(x) sum(assigned == x), u);
        if max(counts) / numel(assigned) >= 0.8
            collapsed = collapsed + 1;
        end
    end
end
if totalDropped > 0
    warning('pf2:probe:canonicalize:channelsDropped', ...
        ['%d of %d channels mapped to no region within MaxDistance=%.1f mm and ', ...
         'were dropped from the projection.'], totalDropped, totalCh, maxDist);
end
if collapsed > 0
    warning('pf2:probe:canonicalize:regionCollapse', ...
        ['%d dataset(s) collapsed >=80%% of assigned channels into a single ', ...
         'Brodmann area at MaxDistance=%.1f mm, erasing within-region (e.g. ', ...
         'L/R) structure. For dense single-region montages a hand-curated ROI ', ...
         'scheme (exploreFNIRS.dataset.standardizeROIs) may be more faithful.'], ...
        collapsed, maxDist);
end

% --- Determine the shared region axis ---
if isempty(regions)
    observed = [];
    for i = 1:nItems
        observed = [observed; baMaps{i}(~isnan(baMaps{i}))]; %#ok<AGROW>
    end
    regions = unique(observed(:))';
end
regions = sort(regions);
R = numel(regions);

if R == 0
    error('pf2:probe:canonicalize:noRegions', ...
        ['No channels mapped to any region within MaxDistance=%.1f mm. ', ...
         'Increase MaxDistance or check probe MNI coordinates.'], maxDist);
end

% Build the shared region table (Index / BA / Name)
regionNames = strings(R, 1);
for r = 1:R
    if nameByBA.isKey(regions(r))
        regionNames(r) = string(nameByBA(regions(r)));
    else
        regionNames(r) = sprintf("BA%d", regions(r));
    end
end
regionTable = table((1:R)', regions(:), regionNames, ...
    'VariableNames', {'Index', 'BA', 'Name'});

% --- Pass 2: project each dataset onto the shared region axis ---
for i = 1:nItems
    items{i} = buildCanonical(items{i}, baMaps{i}, regions, regionTable, ...
        space, aggregate, maxDist);
end

% --- Return in the same shape as the input ---
if isCellInput
    out = items;
else
    out = items{1};
end

end

%%_Subfunctions_________________________________________________________

function [chanBA, nameByBA] = mapChannelsToBA(data, maxDist, nameByBA)
% MAPCHANNELSTOBA Assign each channel to its nearest Brodmann area
%
% Inputs:
%   data     - fNIRS data struct (must resolve to a device with MNI coords)
%   maxDist  - Max channel-to-region distance in mm
%   nameByBA - containers.Map accumulating BA number -> name across datasets
%
% Outputs:
%   chanBA   - [nCh x 1] BA assigned to each channel (NaN if none within range)
%   nameByBA - Updated BA -> name map

if ~isstruct(data)
    error('pf2:probe:canonicalize:badInput', ...
        'Each dataset must be an fNIRS data struct.');
end

% Resolve channel count from the device when available, else from biomarkers
nCh = channelCount(data);

try
    baTbl = pf2.probe.nearestBrodmann(data, 'N', 1, 'MaxDistance', maxDist);
catch ME
    error('pf2:probe:canonicalize:noMNI', ...
        ['Brodmann assignment failed (%s). canonicalize requires a device ', ...
         'with 3D MNI coordinates; register first with pf2.probe.transformToMNI.'], ...
        ME.message);
end

chanBA = nan(nCh, 1);
for r = 1:height(baTbl)
    ch = baTbl.Channel(r);
    if ch >= 1 && ch <= nCh
        chanBA(ch) = baTbl.BA(r);
        if ~nameByBA.isKey(baTbl.BA(r))
            nameByBA(baTbl.BA(r)) = char(baTbl.Name(r));
        end
    end
end

end

function data = buildCanonical(data, chanBA, regions, regionTable, space, aggregate, maxDist)
% BUILDCANONICAL Average channels into the shared region axis for one dataset
%
% Inputs:
%   data        - fNIRS data struct
%   chanBA      - [nCh x 1] BA per channel (NaN if unassigned)
%   regions     - [1 x R] sorted region (BA) axis
%   regionTable - Shared region table (Index / BA / Name)
%   space       - Anatomical space label
%   aggregate   - 'nanmean' or 'mean'
%   maxDist     - Distance threshold used (stored for provenance)
%
% Outputs:
%   data - Input struct with a populated .canonical field

R = numel(regions);
biomFields = biomarkerFields(data);

canon = struct();
canon.space = space;
canon.regions = regionTable;
if isfield(data, 'time')
    canon.time = data.time;
else
    canon.time = [];
end
canon.channelBA = chanBA;
canon.MaxDistance = maxDist;

% Channel count per region (shared axis)
N = zeros(1, R);
for r = 1:R
    N(r) = sum(chanBA == regions(r));
end
canon.N = N;

% Region-average each biomarker
for f = 1:numel(biomFields)
    fn = biomFields{f};
    X = data.(fn);                 % [T x nCh]
    T = size(X, 1);
    Y = nan(T, R);
    for r = 1:R
        cols = (chanBA == regions(r));
        if any(cols)
            sub = X(:, cols);
            if strcmp(aggregate, 'nanmean')
                Y(:, r) = mean(sub, 2, 'omitnan');
            else
                Y(:, r) = mean(sub, 2);
            end
        end
    end
    canon.(fn) = Y;
end

data.canonical = canon;

end

function n = channelCount(data)
% CHANNELCOUNT Resolve the channel count from device or biomarker width
%
% Inputs:
%   data - fNIRS data struct
%
% Outputs:
%   n - Channel count [scalar]

% Prefer the biomarker matrix width: that is what buildCanonical indexes
% into, so sizing chanBA to it keeps X(:, cols) in bounds even if the device
% channel count and the processed biomarker width ever disagree (e.g. short-
% separation stripping or channel rejection upstream).
n = [];
biom = biomarkerFields(data);
if ~isempty(biom)
    n = size(data.(biom{1}), 2);
elseif isfield(data, 'device') && isa(data.device, 'pf2.Device')
    n = data.device.nChannels;
end
if isempty(n)
    error('pf2:probe:canonicalize:noChannels', ...
        'Could not determine channel count from device or biomarker fields.');
end

end

function fields = biomarkerFields(data)
% BIOMARKERFIELDS List biomarker matrix fields present on the struct
%
% Inputs:
%   data - fNIRS data struct
%
% Outputs:
%   fields - Cell array of present biomarker field names

candidates = {'HbO', 'HbR', 'HbTotal', 'HbDiff', 'CBSI'};
present = false(size(candidates));
for k = 1:numel(candidates)
    present(k) = isfield(data, candidates{k}) && ~isempty(data.(candidates{k})) ...
        && size(data.(candidates{k}), 2) > 0;
end
fields = candidates(present);

end
