function [h, imgOut] = regions(regionValues, data, varargin)
% REGIONS Paint anatomical (Brodmann) parcels on the cortical surface
%
% Renders an anatomically-parcellated cortical map: each Brodmann area is
% flat-filled with a single value, rather than the smooth channel-to-vertex
% interpolation used by pf2.probe.project.biomarker. This is the natural
% display for region-indexed data produced by pf2.probe.canonicalize - the
% representation that makes datasets from different montages and devices
% directly comparable - and for any per-region statistic (group means,
% F-stats, effect sizes) defined on a Brodmann axis.
%
% Coloring uses the per-vertex Brodmann labels carried by the high-resolution
% cortical mesh (cerebro_mdl.b_area): every vertex whose label matches a
% supplied region takes that region's value; unlabeled or unsupplied regions
% keep the base brain color. The brain surface, camera, and lighting are drawn
% by pf2.probe.plot.interpolateValues3D and reused unchanged.
%
% Reference:
%   Internal pf2 implementation.
%
% Syntax:
%   pf2.probe.project.regions(regionValues, proc)
%   pf2.probe.project.regions('HbO', proc)            % mean over canonical.HbO
%   pf2.probe.project.regions(regionValues, proc, 'Regions', [9 10 46])
%   pf2.probe.project.regions(regionValues, proc, 'Range', [-1 1])
%   pf2.probe.project.regions(..., 'savePath', 'regions.png')
%   [h, imgOut] = pf2.probe.project.regions(...)
%
% Inputs:
%   regionValues - [1 x R] numeric value per region (one per row of the
%                  region axis, see 'Regions'/canonical.regions), OR a
%                  biomarker name ('HbO','HbR',...) to take the time-mean of
%                  data.canonical.<biomarker> as the region values.
%   data         - Processed fNIRS struct. To resolve the region axis
%                  automatically it should carry a .canonical field (run
%                  pf2.probe.canonicalize first); otherwise pass 'Regions'.
%
% Name-Value Parameters (wrapper-specific):
%   'Regions'   - [1 x R] Brodmann area numbers defining the value axis.
%                 Default: data.canonical.regions.BA. Required if data has no
%                 .canonical field.
%   'Range'     - [lo hi] color limits. Default: symmetric [-m, m] with
%                 m = max |regionValues|.
%   'Colormap'  - [N x 3] colormap, or a name. Default: a blue-white-red
%                 diverging map (suited to signed values).
%   'BrainColor'- [R G B] base color for unlabeled/unsupplied cortex
%                 (default: [0.92 0.68 0.68], matching the renderer).
%   'Title'     - Title string (default: '').
%   'Colorbar'  - Colorbar label (default: data.units if present, else '').
%   'ShowProbe' - Draw optode markers for context (default: false).
%
% Any other name-value pairs (e.g. 'initCamPosition', 'ForceLightMode',
% 'savePath', 'saveWidth') are forwarded to interpolateValues3D. For headless
% saving use 'savePath'.
%
% Outputs:
%   h      - Axes handle.
%   imgOut - RGB capture of the render (empty if not requested).
%
% Algorithm:
%   1. Resolve the region axis (Brodmann numbers) and per-region values.
%   2. Draw the cortical surface via interpolateValues3D (data2plot = []).
%   3. For each region, set the value on all mesh vertices whose Brodmann
%      label matches; map values through the colormap to per-vertex colors
%      (base brain color elsewhere) and rebind the Brain patch.
%   4. Attach a colorbar matching the value range; save if requested.
%
% Example:
%   data = pf2.import.sampleData();
%   proc = processFNIRS2(data);
%   proc = pf2.probe.canonicalize(proc, 'MaxDistance', 20);
%   meanHbO = mean(proc.canonical.HbO, 1, 'omitnan');   % [1 x R]
%   pf2.probe.project.regions(meanHbO, proc, 'savePath', 'regions.png');
%
% Notes:
%   - Uses the high-resolution mesh (cerebro_mdl); its b_area labels define
%     the parcels. Regions absent from the atlas labels are not painted.
%   - Flat per-parcel fill is an anatomical summary, not a spatially smooth
%     activation map; for the latter use pf2.probe.project.biomarker.
%
% See also: pf2.probe.canonicalize, pf2.probe.project.biomarker,
%           pf2.probe.plot.interpolateValues3D, pf2.probe.nearestBrodmann

p = inputParser;
p.KeepUnmatched = true;
addRequired(p, 'regionValues', @(x) (isnumeric(x) && isvector(x)) || ischar(x) || isstring(x));
addRequired(p, 'data', @isstruct);
addParameter(p, 'Regions', [], @(x) isempty(x) || (isnumeric(x) && isvector(x)));
addParameter(p, 'Range', [], @(x) isempty(x) || (isnumeric(x) && numel(x) == 2));
addParameter(p, 'Colormap', [], @(x) isempty(x) || isnumeric(x) || ischar(x) || isstring(x));
addParameter(p, 'BrainColor', [0.92, 0.68, 0.68], @(x) isnumeric(x) && numel(x) == 3);
addParameter(p, 'Title', '', @(x) ischar(x) || isstring(x));
addParameter(p, 'Colorbar', '', @(x) ischar(x) || isstring(x));
addParameter(p, 'ShowProbe', false, @islogical);
parse(p, regionValues, data, varargin{:});

brainColor = p.Results.BrainColor(:)';

% Match the render preset's cortex tone: showcase uses a neutral-gray base so
% parcels read cleanly, unless the caller set BrainColor explicitly.
rstyle = pf2_base.plot.RenderStyle.get(iGetOpt(p.Unmatched, 'Style', 'showcase'));
if ismember('BrainColor', p.UsingDefaults) && isfield(rstyle,'grayCortex') && rstyle.grayCortex
    brainColor = rstyle.baseGray(:)';
end

% --- Resolve the region axis (Brodmann numbers) ---
regionBA = p.Results.Regions(:)';
if isempty(regionBA)
    if isfield(data, 'canonical') && isfield(data.canonical, 'regions')
        regionBA = data.canonical.regions.BA(:)';
    else
        error('pf2:probe:project:regions:noAxis', ...
            ['No region axis available. Run pf2.probe.canonicalize(data) first, ', ...
             'or pass ''Regions'' with the Brodmann area numbers.']);
    end
end

% --- Resolve the per-region values ---
if ischar(regionValues) || isstring(regionValues)
    bio = char(regionValues);
    if ~isfield(data, 'canonical') || ~isfield(data.canonical, bio)
        error('pf2:probe:project:regions:noCanonical', ...
            ['Biomarker ''%s'' not found in data.canonical. Run ', ...
             'pf2.probe.canonicalize(data) first.'], bio);
    end
    vals = mean(data.canonical.(bio), 1, 'omitnan');   % [1 x R]
else
    vals = double(regionValues(:)');
end

if numel(vals) ~= numel(regionBA)
    error('pf2:probe:project:regions:sizeMismatch', ...
        'regionValues has %d entries but the region axis has %d.', ...
        numel(vals), numel(regionBA));
end

% --- Color range ---
rangeVals = p.Results.Range;
if isempty(rangeVals)
    m = max(abs(vals), [], 'omitnan');
    if ~isfinite(m) || m == 0, m = 1; end
    rangeVals = [-m, m];
end
rangeVals = sort(rangeVals);

% --- Colormap ---
cmap = p.Results.Colormap;
if isempty(cmap)
    cmap = iDivergingMap(256);
elseif ischar(cmap) || isstring(cmap)
    cmap = feval(char(cmap), 256);
end

% Colorbar label
cbar = char(p.Results.Colorbar);
if isempty(cbar) && isfield(data, 'units') && ~isempty(data.units)
    cbar = char(string(data.units));
end

% Strip save-related keys: the inner render must not save the pre-recolor
% frame; regions saves once after the parcels are painted.
forward = iUnmatched(rmfieldIfPresent(p.Unmatched, ...
    {'savePath', 'saveWidth', 'saveHeight', 'saveDPI'}));

% --- Draw the cortical surface (brain + camera + lighting) ---
% Start from a pristine axes: a stale axes left by a prior 2D plot carries
% YDir='reverse', 2D limits and a peer colorbar that would corrupt the 3D
% render. colorbar(ax,'off') drops only this axes' colorbar, then
% cla('reset') restores axes defaults without touching sibling subplots.
ax = gca;
colorbar(ax, 'off');
cla(ax, 'reset');
pf2.probe.plot.interpolateValues3D([], data, ...
    'ax', ax, 'useHighRes', true, ...
    'ChannelLabels', p.Results.ShowProbe, 'SDLabels', p.Results.ShowProbe, ...
    'brainColor', brainColor, 'showColorbar', false, ...
    'titleString', char(p.Results.Title), forward{:});

% --- Recolor the Brain patch by Brodmann parcel ---
cerebro = pf2_base.getAsset('cerebro_mdl', 'cache', ax);
bArea = double(cerebro.b_area(:));            % [V x 1] per-vertex BA label
brainHndl = findall(ax, 'Type', 'Patch', 'Tag', 'Brain');
if isempty(brainHndl)
    error('pf2:probe:project:regions:noBrain', ...
        'Could not find the rendered brain surface to recolor.');
end
if numel(brainHndl) > 1
    warning('pf2:probe:project:regions:multipleBrainPatches', ...
        'Found %d brain patches; recoloring all.', numel(brainHndl));
end
V = numel(bArea);

vertVal = nan(V, 1);
for r = 1:numel(regionBA)
    if isnan(vals(r)), continue; end
    vertVal(bArea == regionBA(r)) = vals(r);
end

% Map values to per-vertex RGB; base brain color where unlabeled
nc = size(cmap, 1);
RGB = repmat(brainColor, V, 1);
inReg = ~isnan(vertVal);
if any(inReg)
    span = rangeVals(2) - rangeVals(1);
    if span == 0, span = 1; end
    nrm = (vertVal(inReg) - rangeVals(1)) / span;
    idx = round(nrm * (nc - 1)) + 1;
    idx = max(1, min(nc, idx));
    RGB(inReg, :) = cmap(idx, :);
end

% Preserve the surface's 3D shading. Under a matcap style the renderer baked
% shading into the patch colours and set FaceLighting='none'; overwriting with
% flat parcel colours would lose all relief. Modulate the parcel colours by
% the baked shading luminance so the parcels stay dimensional. (Under the lit
% styles FaceLighting is gouraud/flat, so MATLAB shades the new colours live
% and no modulation is needed.)
existingCData = get(brainHndl(1), 'FaceVertexCData');
if strcmpi(get(brainHndl(1), 'FaceLighting'), 'none') && isequal(size(existingCData), [V 3])
    shadeLum = mean(existingCData, 2);
    ref = pf2_base.compat.prctile(shadeLum(shadeLum > 0), 98);
    if ~isfinite(ref) || ref == 0, ref = max(shadeLum); end
    if ref == 0, ref = 1; end
    shadeN = min(shadeLum / ref, 1.05);
    RGB = min(max(RGB .* shadeN, 0), 1);
end

set(brainHndl, 'FaceVertexCData', RGB, 'FaceColor', 'interp');

% --- Colorbar matching the value range ---
colormap(ax, cmap);
clim(ax, rangeVals);
% Remove any stale colorbars in this figure so exactly one (ours) remains.
delete(findall(ancestor(ax, 'figure'), 'Type', 'ColorBar'));
cb = colorbar(ax);
if ~isempty(cbar)
    cb.Label.String = cbar;
end

% --- Save / capture (headless-stable) ---
imgOut = [];
if isfield(p.Unmatched, 'savePath') && ~isempty(p.Unmatched.savePath)
    % savePath already forwarded to interpolateValues3D would have saved the
    % pre-recolor frame; re-save now that the parcels are painted.
    fig = ancestor(ax, 'figure');
    sw = iGetOpt(p.Unmatched, 'saveWidth', []);
    sh = iGetOpt(p.Unmatched, 'saveHeight', []);
    sd = iGetOpt(p.Unmatched, 'saveDPI', 150);
    pf2_base.plot.saveFigure(fig, char(p.Unmatched.savePath), sw, sh, sd);
end
if nargout > 1
    imgOut = iCaptureAxes(ax);
end

h = ax;
if nargout == 0
    clear h imgOut;
end

end

%%_Subfunctions_________________________________________________________

function cmap = iDivergingMap(n)
% Blue-white-red diverging colormap with n rows.
half = floor(n / 2);
top = ones(half, 1);
ramp = linspace(0, 1, half)';
lower = [ramp, ramp, top];                 % blue -> white
upper = [top, flipud(ramp), flipud(ramp)]; % white -> red
mid = [1 1 1];
cmap = [lower; mid; upper];
% Resize to exactly n rows
if size(cmap, 1) ~= n
    xi = linspace(1, size(cmap, 1), n);
    cmap = interp1(1:size(cmap, 1), cmap, xi);
end
cmap = max(0, min(1, cmap));
end

function img = iCaptureAxes(ax)
% Capture an RGB image of the axes' figure headlessly. getframe on a 3D
% render is unreliable once the renderer has restored figure visibility to
% 'off' (blank frame), so round-trip through the stable saveFigure path.
tmp = [tempname, '.png'];
c = onCleanup(@() iDeleteIfExists(tmp));
pf2_base.plot.saveFigure(ancestor(ax, 'figure'), tmp, [], [], 150);
img = imread(tmp);
end

function iDeleteIfExists(f)
if exist(f, 'file'), delete(f); end
end

function s = rmfieldIfPresent(s, names)
present = names(isfield(s, names));
if ~isempty(present)
    s = rmfield(s, present);
end
end

function v = iGetOpt(s, name, default)
if isfield(s, name) && ~isempty(s.(name))
    v = s.(name);
else
    v = default;
end
end

function c = iUnmatched(s)
% Convert an inputParser Unmatched struct to a name-value cell array.
fn = fieldnames(s);
c = cell(1, 2 * numel(fn));
for i = 1:numel(fn)
    c{2*i - 1} = fn{i};
    c{2*i}     = s.(fn{i});
end
end
