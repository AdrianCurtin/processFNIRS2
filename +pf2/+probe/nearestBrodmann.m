function tbl = nearestBrodmann(data, varargin)
% NEARESTBRODMANN Find nearest Brodmann areas for each channel in a probe
%
% Maps each channel's MNI position to the closest Brodmann areas using the
% volumetric Brodmann atlas. Useful for identifying anatomical regions
% covered by a probe, writing methods sections, and defining ROIs.
%
% Syntax:
%   tbl = pf2.probe.nearestBrodmann(data)
%   tbl = pf2.probe.nearestBrodmann('fNIR_Devices_fNIR1000.cfg')
%   tbl = pf2.probe.nearestBrodmann(data, 'N', 3)
%   tbl = pf2.probe.nearestBrodmann(data, 'N', 3, 'MaxDistance', 25)
%
% Inputs:
%   data        - fNIRS data struct or device config name string
%                 (e.g., 'fNIR_Devices_fNIR1000.cfg')
%   'N'         - Number of nearest BAs to return per channel (default: 3)
%   'MaxDistance' - Maximum distance in mm to consider (default: Inf)
%
% Outputs:
%   tbl - MATLAB table with columns:
%         Channel      - Channel number (1-based) [double]
%         BA           - Brodmann area number [double]
%         Name         - Human-readable area name [string]
%         Distance_mm  - Distance from channel to nearest voxel of that BA [double]
%         Rows sorted by Channel ascending, then Distance_mm ascending.
%
% Algorithm:
%   1. Load probe info via pf2.settings.getDevice
%   2. Extract channel MNI positions from TableOpt.Pos3D_x/y/z
%   3. Load volumetric Brodmann atlas (181x217x181, 1mm isotropic MNI)
%   4. Convert labeled voxels to MNI coordinates
%   5. For each channel, compute distance to all labeled voxels, find
%      minimum distance per unique BA, keep top N within MaxDistance
%   6. Assemble output table with BA name lookup
%
% Example:
%   % fNIR1000 probe (prefrontal cortex, expect BA 9, 10, 46)
%   tbl = pf2.probe.nearestBrodmann('fNIR_Devices_fNIR1000.cfg')
%
%   % One BA per channel
%   tbl = pf2.probe.nearestBrodmann('fNIR_Devices_fNIR1000.cfg', 'N', 1)
%
%   % Only BAs within 15 mm
%   tbl = pf2.probe.nearestBrodmann('fNIR_Devices_fNIR1000.cfg', 'MaxDistance', 15)
%
% See also: pf2.settings.getDevice, pf2.probe.plot.interpolateValues3D,
%           pf2_base.getAsset

% --- Parse inputs ---
p = inputParser;
p.addRequired('data');
p.addParameter('N', 3, @(x) isnumeric(x) && isscalar(x) && x >= 1);
p.addParameter('MaxDistance', Inf, @(x) isnumeric(x) && isscalar(x) && x > 0);
p.parse(data, varargin{:});

N = round(p.Results.N);
maxDist = p.Results.MaxDistance;

% --- Frame check: BA lookup uses a 1mm MNI atlas, so it is only valid for
%     MNI-space coordinates. Warn (don't block) on a declared non-MNI system,
%     and flag idealized-template coordinates as a group-level approximation. ---
if isstruct(data) && isfield(data, 'device') && isa(data.device, 'pf2.Device')
    cs = char(data.device.CoordinateSystem);
    prov = char(data.device.CoordinateProvenance);
    if ~isempty(cs) && ~strcmpi(strtrim(cs), 'MNI')
        iWarnOnce('pf2:probe:nearestBrodmann:notMNI', ...
            ['Coordinates declare CoordinateSystem=''%s'', not MNI. Brodmann ' ...
             'lookup assumes MNI space and results may be wrong. Register with ' ...
             'pf2.probe.transformToMNI first.'], cs);
    elseif ~isempty(prov) && (contains(lower(prov), 'template') || contains(lower(prov), 'idealized'))
        iWarnOnce('pf2:probe:nearestBrodmann:templateCoords', ...
            ['Coordinates are an idealized template (provenance=''%s''), not ' ...
             'subject-digitized. Brodmann assignments are a group-level ' ...
             'approximation; treat reported distances as indicative.'], prov);
    end
end

% --- Get channel MNI positions ---
chPos = getChannelPositions(data);
nCh = size(chPos, 1);

% --- Load Brodmann atlas (cached after first call) ---
[voxelMNI, voxelBA, uniqueBAs] = getBrodmannAtlas();

% --- For each channel, find nearest BAs ---
channelCol = [];
baCol = [];
distCol = [];

for ch = 1:nCh
    % Euclidean distance from this channel to all labeled voxels
    diffs = voxelMNI - chPos(ch, :);
    dists = sqrt(sum(diffs .^ 2, 2));

    % Find minimum distance per unique BA
    baDists = zeros(numel(uniqueBAs), 1);
    for k = 1:numel(uniqueBAs)
        baDists(k) = min(dists(voxelBA == uniqueBAs(k)));
    end

    % Sort by distance, keep top N within MaxDistance
    [sortedDists, sortIdx] = sort(baDists, 'ascend');
    sortedBAs = uniqueBAs(sortIdx);

    withinRange = sortedDists <= maxDist;
    sortedDists = sortedDists(withinRange);
    sortedBAs = sortedBAs(withinRange);

    nKeep = min(N, numel(sortedBAs));
    if nKeep > 0
        channelCol = [channelCol; repmat(ch, nKeep, 1)]; %#ok<AGROW>
        baCol = [baCol; sortedBAs(1:nKeep)]; %#ok<AGROW>
        distCol = [distCol; sortedDists(1:nKeep)]; %#ok<AGROW>
    end
end

% --- Build name lookup ---
nameMap = brodmannNames();
nameCol = strings(numel(baCol), 1);
for i = 1:numel(baCol)
    if nameMap.isKey(baCol(i))
        nameCol(i) = nameMap(baCol(i));
    else
        nameCol(i) = sprintf("BA%d", baCol(i));
    end
end

% --- Assemble table ---
tbl = table(channelCol, baCol, nameCol, round(distCol, 2), ...
    'VariableNames', {'Channel', 'BA', 'Name', 'Distance_mm'});

end


% =========================================================================
% Local function: Get channel MNI positions with device caching
% =========================================================================
function chPos = getChannelPositions(data)
% GETCHANNELPOSITIONS Extract channel 3D MNI positions from data or config.
%
% Caches device configs by name so loadDeviceCfg is only called once per
% device per MATLAB session.

persistent deviceCache

if isempty(deviceCache)
    deviceCache = containers.Map('KeyType', 'char', 'ValueType', 'any');
end

% Determine cache key
if ischar(data) || isstring(data)
    cacheKey = char(data);
elseif isstruct(data) && pf2_base.isnestedfield(data, 'info.probename')
    cacheKey = data.info.probename;
else
    cacheKey = '';
end

% Try cache first
if ~isempty(cacheKey) && deviceCache.isKey(cacheKey)
    chPos = deviceCache(cacheKey);
    return;
end

% Load device (triggers fitProbe2D on first call)
probeInfo = pf2.settings.getDevice(data);

% Extract probe struct (Probe is a cell array from loadDeviceCfg)
if isfield(probeInfo, 'Probe') && iscell(probeInfo.Probe)
    probe = probeInfo.Probe{1};
elseif isfield(probeInfo, 'TableOpt')
    probe = probeInfo;
else
    error('pf2:probe:nearestBrodmann:noProbe', ...
        'No probe geometry found in device configuration.');
end

% Get 3D positions
if ~isfield(probe, 'TableOpt') || ...
   ~ismember('Pos3D_x', probe.TableOpt.Properties.VariableNames) || ...
   isempty(probe.TableOpt.Pos3D_x)
    error('pf2:probe:nearestBrodmann:no3D', ...
        ['No 3D MNI positions found (layout-only device?). Brodmann lookup ' ...
         'requires a device config with 3D MNI coordinates.']);
end

chPos = [probe.TableOpt.Pos3D_x(:), ...
         probe.TableOpt.Pos3D_y(:), ...
         probe.TableOpt.Pos3D_z(:)];

% Cache for next time
if ~isempty(cacheKey)
    deviceCache(cacheKey) = chPos;
end

end


% =========================================================================
% Local function: Load and cache Brodmann atlas voxel data
% =========================================================================
function [voxelMNI, voxelBA, uniqueBAs] = getBrodmannAtlas()
% GETBRODMANNATLAS Load the volumetric Brodmann atlas and extract labeled
% voxel positions. Results are cached in a persistent variable so the
% 181x217x181 volume is only parsed once per MATLAB session.

persistent cachedMNI cachedBA cachedUnique

if ~isempty(cachedMNI)
    voxelMNI = cachedMNI;
    voxelBA = cachedBA;
    uniqueBAs = cachedUnique;
    return;
end

% 181x217x181 uint8 volume, 1mm isotropic, MNI space
% Origin at voxel [91, 127, 73] (same mapping as mni3d.m)
brdm = pf2_base.getAsset('brodmann');
center = [91, 127, 73];

% Extract labeled voxel positions in MNI coordinates
[vi, vj, vk] = ind2sub(size(brdm), find(brdm > 0));
cachedBA = double(brdm(brdm > 0));
cachedMNI = [vi - center(1), vj - center(2), vk - center(3)];
cachedUnique = unique(cachedBA);

voxelMNI = cachedMNI;
voxelBA = cachedBA;
uniqueBAs = cachedUnique;

end


% =========================================================================
% Local function: Brodmann area name lookup
% =========================================================================
function m = brodmannNames()
% BRODMANNNAMES Standard anatomical labels for Brodmann areas
%
% Returns a containers.Map mapping BA numbers to short human-readable names.

m = containers.Map('KeyType', 'double', 'ValueType', 'char');

m(1)  = 'Primary Somatosensory';
m(2)  = 'Primary Somatosensory';
m(3)  = 'Primary Somatosensory';
m(4)  = 'Primary Motor';
m(5)  = 'Somatosensory Association';
m(6)  = 'Premotor';
m(7)  = 'Superior Parietal';
m(8)  = 'Frontal Eye Fields';
m(9)  = 'Dorsolateral PFC';
m(10) = 'Anterior PFC';
m(11) = 'Orbitofrontal';
m(13) = 'Insular';
m(17) = 'Primary Visual (V1)';
m(18) = 'Secondary Visual (V2)';
m(19) = 'Associative Visual (V3)';
m(20) = 'Inferior Temporal';
m(21) = 'Middle Temporal';
m(22) = 'Superior Temporal';
m(23) = 'Posterior Cingulate';
m(24) = 'Anterior Cingulate';
m(25) = 'Subgenual Cingulate';
m(28) = 'Entorhinal';
m(29) = 'Retrosplenial';
m(30) = 'Retrosplenial';
m(31) = 'Posterior Cingulate';
m(32) = 'Anterior Cingulate';
m(34) = 'Entorhinal';
m(37) = 'Fusiform Gyrus';
m(38) = 'Temporal Pole';
m(39) = 'Angular Gyrus';
m(40) = 'Supramarginal Gyrus';
m(41) = 'Primary Auditory';
m(42) = 'Primary Auditory';
m(43) = 'Subcentral';
m(44) = 'Broca''s Area (pars opercularis)';
m(45) = 'Broca''s Area (pars triangularis)';
m(46) = 'Dorsolateral PFC';
m(47) = 'Inferior PFC';

end

function iWarnOnce(id, varargin)
% IWARNONCE Emit a warning with the given id at most once per MATLAB session.
persistent seen
if isempty(seen), seen = {}; end
if any(strcmp(seen, id)), return; end
seen{end+1} = id; %#ok<AGROW>
warning(id, varargin{:});

end
