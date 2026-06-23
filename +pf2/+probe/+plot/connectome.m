function [h, imgOut] = connectome(result, data, varargin)
% CONNECTOME Draw a connectivity network anchored on the probe / cortex
%
% Renders a connectivity matrix as a node-edge network placed at the real
% channel (or ROI) locations - on the 3D cortical surface (default) or the
% flat 2D probe layout. Unlike the circular chord diagram
% (exploreFNIRS.connectivity.plotChord) or the heatmap
% (exploreFNIRS.connectivity.plotMatrix), edges here are drawn between
% anatomical positions, so the spatial structure of the network (front-back,
% left-right, long- vs short-range) is directly visible. Edge color encodes
% coupling sign/strength and edge width its magnitude.
%
% Node positions are taken from the same optode coordinate space the cortical
% renderer uses, so the network sits correctly on the rendered brain.
%
% Reference:
%   Internal pf2 implementation.
%
% Syntax:
%   pf2.probe.plot.connectome(result, data)
%   pf2.probe.plot.connectome(result, data, 'View', '2d')
%   pf2.probe.plot.connectome(result, data, 'Threshold', 0.4)
%   pf2.probe.plot.connectome(result, data, 'TopN', 30)
%   pf2.probe.plot.connectome(result, data, 'SignificanceMask', true)
%   pf2.probe.plot.connectome(result, data, 'savePath', 'net.png')
%   [h, imgOut] = pf2.probe.plot.connectome(...)
%
% Inputs:
%   result - Connectivity result from exploreFNIRS.connectivity.computeMatrix
%            (fields .matrix [N x N], .pmatrix, .channels, .labels, .useROI),
%            or a raw [N x N] coupling matrix.
%   data   - Processed fNIRS struct providing the probe geometry. For 3D it
%            must carry 3D optode coordinates; for ROI results, channel
%            membership is read from data.ROI.info to place ROI nodes.
%
% Name-Value Parameters:
%   'View'             - '3d' (default) cortical surface, or '2d' flat probe.
%   'Threshold'        - Minimum |coupling| to draw an edge (default: 0).
%   'TopN'             - Keep only the strongest N edges (default: [] = all
%                        edges passing Threshold / significance).
%   'SignificanceMask' - Draw only edges with p < PThreshold (default: false).
%   'PThreshold'       - Significance cutoff for SignificanceMask (default: 0.05).
%   'CLim'             - [lo hi] edge color limits (default: symmetric
%                        [-m, m], m = max |coupling| among drawn edges).
%   'EdgeColormap'     - [M x 3] colormap or name for edges (default: a
%                        blue-white-red diverging map).
%   'EdgeWidthRange'   - [min max] line width mapped from |coupling|
%                        (default: [0.5 5]).
%   'NodeSize'         - Node marker area (default: 36).
%   'NodeColor'        - Node marker RGB (default: [0.15 0.15 0.15]).
%   'ShowLabels'       - Label nodes with result.labels (default: false).
%   'Colorbar'         - Colorbar label (default: 'coupling').
%   'Title'            - Title string (default: auto from method/biomarker).
%   'BrainAlpha'       - (3D) cortical surface opacity (default: 1).
%
% Other name-value pairs (e.g. 'initCamPosition','savePath','ForceLightMode')
% are forwarded to the 3D renderer. Use 'savePath' for headless saving.
%
% Outputs:
%   h      - Axes handle.
%   imgOut - RGB capture of the render (empty if not requested).
%
% Algorithm:
%   1. Build the edge list from the upper triangle, applying Threshold,
%      SignificanceMask, and TopN.
%   2. Resolve node positions from the probe (channel optode coordinates, or
%      ROI centroids of member channels).
%   3. Draw the cortical surface (3D) or a faint probe context (2D), then
%      overlay edges (colored/sized by coupling) and nodes.
%
% Example:
%   data = pf2.import.sampleData.fNIR2000();
%   proc = processFNIRS2(data);
%   r = exploreFNIRS.connectivity.computeMatrix(proc, 'Method', 'pearson');
%   pf2.probe.plot.connectome(r, proc, 'Threshold', 0.5, ...
%       'savePath', 'connectome.png');
%
% Notes:
%   - 3D edges are lifted slightly off the cortical surface so they remain
%     visible rather than disappearing into the mesh.
%   - For ROI results without per-ROI coordinates, nodes are placed at the
%     centroid of each ROI's member optodes.
%   - Only the upper triangle is drawn (undirected edges). For directed
%     methods (granger/transferentropy) the reverse direction is not shown;
%     use exploreFNIRS.connectivity.plotDirected for that.
%   - 'SignificanceMask' requires result.pmatrix; it is ignored (with a
%     warning) when absent, e.g. for a raw-matrix input.
%
% See also: exploreFNIRS.connectivity.computeMatrix,
%           exploreFNIRS.connectivity.plotChord,
%           exploreFNIRS.connectivity.plotMatrix,
%           pf2.probe.plot.interpolateValues3D

p = inputParser;
p.KeepUnmatched = true;
addRequired(p, 'result', @(x) isstruct(x) || (isnumeric(x) && ismatrix(x)));
addRequired(p, 'data', @isstruct);
addParameter(p, 'View', '3d', @(x) any(strcmpi(char(x), {'2d','3d'})));
addParameter(p, 'Threshold', 0, @(x) isnumeric(x) && isscalar(x) && x >= 0);
addParameter(p, 'TopN', [], @(x) isempty(x) || (isnumeric(x) && isscalar(x) && x >= 1));
addParameter(p, 'SignificanceMask', false, @islogical);
addParameter(p, 'PThreshold', 0.05, @(x) isnumeric(x) && isscalar(x) && x > 0 && x < 1);
addParameter(p, 'CLim', [], @(x) isempty(x) || (isnumeric(x) && numel(x) == 2));
addParameter(p, 'EdgeColormap', [], @(x) isempty(x) || isnumeric(x) || ischar(x) || isstring(x));
addParameter(p, 'EdgeWidthRange', [0.5 5], @(x) isnumeric(x) && numel(x) == 2);
addParameter(p, 'NodeSize', 36, @(x) isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, 'NodeColor', [0.15 0.15 0.15], @(x) isnumeric(x) && numel(x) == 3);
addParameter(p, 'ShowLabels', false, @islogical);
addParameter(p, 'Colorbar', 'coupling', @(x) ischar(x) || isstring(x));
addParameter(p, 'Title', '', @(x) ischar(x) || isstring(x));
addParameter(p, 'BrainAlpha', 1, @(x) isnumeric(x) && isscalar(x) && x >= 0 && x <= 1);
parse(p, result, data, varargin{:});

view3d = strcmpi(char(p.Results.View), '3d');

% --- Unpack the connectivity result ---
if isnumeric(result)
    M = result;
    pmat = [];
    channels = 1:size(M, 1);
    labels = compose("%d", channels(:));
    useROI = false;
    method = ''; biomarker = '';
else
    M = result.matrix;
    pmat = iField(result, 'pmatrix', []);
    channels = iField(result, 'channels', 1:size(M, 1));
    labels = iField(result, 'labels', compose("%d", (1:size(M,1))'));
    useROI = iField(result, 'useROI', false);
    method = char(string(iField(result, 'method', '')));
    biomarker = char(string(iField(result, 'biomarker', '')));
end
channels = channels(:)';
N = size(M, 1);

% Directed methods produce an asymmetric matrix; connectome draws undirected
% edges from the upper triangle, so the reverse direction is not shown.
if any(strcmpi(method, {'granger', 'transferentropy'}))
    warning('pf2:probe:plot:connectome:directedUndirected', ...
        ['Method ''%s'' is directed, but connectome draws undirected edges ', ...
         '(upper triangle only); use exploreFNIRS.connectivity.plotDirected ', ...
         'to show edge direction.'], method);
end

% --- Build the edge list from the upper triangle ---
[ii, jj] = find(triu(true(N), 1));
w = arrayfun(@(a, b) M(a, b), ii, jj);
keep = isfinite(w) & abs(w) >= p.Results.Threshold;
if p.Results.SignificanceMask
    if isempty(pmat)
        warning('pf2:probe:plot:connectome:noPMatrix', ...
            'SignificanceMask is true but result has no p-value matrix; mask ignored.');
    else
        pe = arrayfun(@(a, b) pmat(a, b), ii, jj);
        keep = keep & (pe < p.Results.PThreshold);
    end
end
ii = ii(keep); jj = jj(keep); w = w(keep);

if ~isempty(p.Results.TopN) && numel(w) > p.Results.TopN
    [~, order] = sort(abs(w), 'descend');
    sel = order(1:round(p.Results.TopN));
    ii = ii(sel); jj = jj(sel); w = w(sel);
end

% --- Node positions in the renderer's coordinate space ---
nodeP = iNodePositions(data, channels, useROI, view3d);

% --- Edge color scale + colormap ---
clim = p.Results.CLim;
if isempty(clim)
    m = max(abs(w), [], 'omitnan');
    if isempty(m) || ~isfinite(m) || m == 0, m = 1; end
    clim = [-m, m];
end
clim = sort(clim);
ecmap = p.Results.EdgeColormap;
if isempty(ecmap)
    ecmap = iDivergingMap(256);
elseif ischar(ecmap) || isstring(ecmap)
    ecmap = feval(char(ecmap), 256);
end

% Title
titleStr = char(p.Results.Title);
if isempty(titleStr)
    bits = strtrim(strjoin({method, biomarker}, ' '));
    if isempty(bits)
        titleStr = 'Connectome';
    else
        titleStr = sprintf('Connectome (%s)', bits);
    end
end

forward = iUnmatched(rmfieldIfPresent(p.Unmatched, ...
    {'savePath', 'saveWidth', 'saveHeight', 'saveDPI'}));

% --- Set up the axes / background ---
ax = gca;
colorbar(ax, 'off');
cla(ax, 'reset');

if view3d
    pf2.probe.plot.interpolateValues3D([], data, ...
        'ax', ax, 'ChannelLabels', false, 'SDLabels', false, ...
        'showColorbar', false, 'brainAlpha', p.Results.BrainAlpha, ...
        'titleString', titleStr, forward{:});
    hold(ax, 'on');
    % Lift nodes slightly off the surface (radially from the probe centroid)
    ctr = mean(nodeP, 1, 'omitnan');
    drawP = ctr + (nodeP - ctr) * 1.06;
else
    hold(ax, 'on');
    axis(ax, 'equal'); axis(ax, 'off');
    title(ax, titleStr);
    % Faint probe context: all nodes
    scatter(ax, nodeP(:,1), nodeP(:,2), p.Results.NodeSize*0.6, ...
        [0.7 0.7 0.7], 'filled', 'MarkerFaceAlpha', 0.4);
    drawP = nodeP;
end

% --- Draw edges (sorted weakest-first so strong edges render on top) ---
[~, eorder] = sort(abs(w), 'ascend');
wr = p.Results.EdgeWidthRange;
span = clim(2) - clim(1); if span == 0, span = 1; end
nc = size(ecmap, 1);
maxAbs = max(abs(w), [], 'omitnan'); if isempty(maxAbs) || maxAbs == 0, maxAbs = 1; end
for e = eorder(:)'
    a = ii(e); b = jj(e);
    cn = (w(e) - clim(1)) / span;
    ci = max(1, min(nc, round(cn * (nc - 1)) + 1));
    col = ecmap(ci, :);
    lw = wr(1) + (wr(2) - wr(1)) * (abs(w(e)) / maxAbs);
    if view3d
        plot3(ax, drawP([a b],1), drawP([a b],2), drawP([a b],3), ...
            '-', 'Color', col, 'LineWidth', lw);
    else
        plot(ax, drawP([a b],1), drawP([a b],2), ...
            '-', 'Color', col, 'LineWidth', lw);
    end
end

% --- Draw nodes ---
if view3d
    scatter3(ax, drawP(:,1), drawP(:,2), drawP(:,3), p.Results.NodeSize, ...
        p.Results.NodeColor, 'filled', 'MarkerEdgeColor', 'k');
else
    scatter(ax, drawP(:,1), drawP(:,2), p.Results.NodeSize, ...
        p.Results.NodeColor, 'filled', 'MarkerEdgeColor', 'k');
end

if p.Results.ShowLabels
    labStr = string(labels);
    for n = 1:size(drawP, 1)
        if view3d
            text(ax, drawP(n,1), drawP(n,2), drawP(n,3), ' ' + labStr(n), ...
                'FontSize', 8, 'Color', p.Results.NodeColor);
        else
            text(ax, drawP(n,1), drawP(n,2), ' ' + labStr(n), ...
                'FontSize', 8, 'Color', p.Results.NodeColor);
        end
    end
end

% --- Colorbar matching the edge scale ---
colormap(ax, ecmap);
set(ax, 'CLim', clim);
delete(findall(ancestor(ax, 'figure'), 'Type', 'ColorBar'));
cb = colorbar(ax);
cb.Label.String = char(p.Results.Colorbar);

% --- Save / capture (headless-stable) ---
imgOut = [];
if isfield(p.Unmatched, 'savePath') && ~isempty(p.Unmatched.savePath)
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

function img = iCaptureAxes(ax)
% Capture an RGB image of the axes' figure headlessly (getframe is unreliable
% after the 3D renderer restores figure visibility to 'off').
tmp = [tempname, '.png'];
c = onCleanup(@() iDeleteIfExists(tmp));
pf2_base.plot.saveFigure(ancestor(ax, 'figure'), tmp, [], [], 150);
img = imread(tmp);
end

function iDeleteIfExists(f)
if exist(f, 'file'), delete(f); end
end

function P = iNodePositions(data, channels, useROI, view3d)
% Resolve node display positions for the requested view.
probeInfo = pf2_base.plot.loadProbeInfo(data, true);
cols = probeInfo.OptPos.Properties.VariableNames;
if view3d
    if ~all(ismember({'x','y','z'}, cols))
        error('pf2:probe:plot:connectome:noGeometry', ...
            ['This device has no 3D optode coordinates; use ''View'',''2d'' ', ...
             'or register MNI coordinates first.']);
    end
    allP = [probeInfo.OptPos.x(:), probeInfo.OptPos.y(:), probeInfo.OptPos.z(:)];
else
    allP = [probeInfo.OptPos.x_2d(:), probeInfo.OptPos.y_2d(:)];
end

if useROI
    % Place each ROI node at the centroid of its member optodes.
    if ~isfield(data, 'ROI') || ~isfield(data.ROI, 'info')
        error('pf2:probe:plot:connectome:noROI', ...
            'ROI result requires data.ROI.info to place ROI nodes.');
    end
    opt = data.ROI.info.Optodes;
    nR = numel(channels);
    P = nan(nR, size(allP, 2));
    for r = 1:nR
        idx = channels(r);
        if idx >= 1 && idx <= numel(opt)
            members = opt{idx};
            members = members(members >= 1 & members <= size(allP, 1));
            if ~isempty(members)
                P(r, :) = mean(allP(members, :), 1, 'omitnan');
            end
        end
    end
else
    valid = channels >= 1 & channels <= size(allP, 1);
    if ~all(valid)
        error('pf2:probe:plot:connectome:badChannels', ...
            'Some result channels exceed the probe optode count (%d).', ...
            size(allP, 1));
    end
    P = allP(channels, :);
end
end

function cmap = iDivergingMap(n)
% Blue-white-red diverging colormap with n rows.
half = floor(n / 2);
top = ones(half, 1);
ramp = linspace(0, 1, half)';
lower = [ramp, ramp, top];                 % blue -> white
upper = [top, flipud(ramp), flipud(ramp)]; % white -> red
cmap = [lower; 1 1 1; upper];
if size(cmap, 1) ~= n
    xi = linspace(1, size(cmap, 1), n);
    cmap = interp1(1:size(cmap, 1), cmap, xi);
end
cmap = max(0, min(1, cmap));
end

function v = iField(s, name, default)
if isfield(s, name) && ~isempty(s.(name))
    v = s.(name);
else
    v = default;
end
end

function v = iGetOpt(s, name, default)
if isfield(s, name) && ~isempty(s.(name))
    v = s.(name);
else
    v = default;
end
end

function s = rmfieldIfPresent(s, names)
present = names(isfield(s, names));
if ~isempty(present)
    s = rmfield(s, present);
end
end

function c = iUnmatched(s)
fn = fieldnames(s);
c = cell(1, 2 * numel(fn));
for i = 1:numel(fn)
    c{2*i - 1} = fn{i};
    c{2*i}     = s.(fn{i});
end
end
