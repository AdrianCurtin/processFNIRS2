function fig = plotChord(result, varargin)
% PLOTCHORD Chord diagram / connectogram for channel/ROI connectivity
%
% Visualizes a connectivity matrix as a chord diagram with nodes arranged
% on a unit circle and quadratic Bezier arcs connecting coupled pairs.
% Arc width encodes coupling magnitude; arc color encodes coupling sign by
% default, or can be set to a single uniform color.
%
% Nodes can additionally be colored by a per-node statistic (e.g. a
% condition contrast such as Delta-r Together-Apart) with a matching
% colorbar, and grouped under region anchor labels (L-FP, R-DLPFC, ...) -
% reproducing the publication-style connectogram where the colorbar tracks
% the *node* value rather than the edges.
%
% Syntax:
%   fig = exploreFNIRS.connectivity.plotChord(result)
%   fig = exploreFNIRS.connectivity.plotChord(result, 'MinThreshold', 0.3)
%   fig = exploreFNIRS.connectivity.plotChord(result, 'ArcWidth', 'fixed')
%   fig = exploreFNIRS.connectivity.plotChord(result, 'NodeValues', dr, ...
%             'ColorbarLabel', '\Deltar (Together - Apart)', ...
%             'EdgeColor', [0.55 0.75 0.88], 'GroupLabels', 'auto')
%
% Inputs:
%   result - Connectivity result struct from computeMatrix with fields:
%            .matrix, .pmatrix, .channels, .method, .biomarker, .labels
%
% Name-Value Parameters:
%   MinThreshold     - Minimum absolute coupling value to draw (default: 0)
%   ArcWidth         - 'proportional' (default) or 'fixed'
%                      proportional: width scales with absolute value
%                      fixed: uniform line width for all arcs
%   SignificanceMask - Mask non-significant connections (default: false)
%   PThreshold       - p-value threshold for masking (default: 0.05)
%   NodeSize         - Scatter marker size (default: 100)
%   NodeColors       - [N x 3] explicit node RGB. Highest precedence; when
%                      given, NodeValues colouring and its colorbar are off.
%   NodeValues       - Per-node scalar driving node color + a colorbar:
%                        []         (default) legacy flat-blue nodes, no bar
%                        [N x 1]    numeric, mapped through NodeColormap
%                        'auto'     signed node strength (mean off-diagonal
%                        /'signed'  coupling per node) - keeps sign
%                        'strength' absolute node strength (mean |off-diag|),
%                        /'degree'  the conventional unsigned weighted degree
%   NodeColormap     - Colormap name or [M x 3] for NodeValues (default:
%                      'rdbu', CVD-safe diverging, for signed values). When
%                      the values are all non-negative and this is left at
%                      default, a sequential map ('viridis') over [0, m] is
%                      used instead.
%   NodeCLim         - [lo hi] node color limits (default: symmetric about 0).
%   ColorbarLabel    - Label for the node colorbar (default: auto). Empty
%                      string hides the colorbar even when NodeValues is set.
%   GroupLabels      - Region anchor labels around the ring:
%                        []               (default) per-node labels as before
%                        'auto'           infer groups from result.labels
%                        {1xN}/[N x 1]    per-node group name ('' = none)
%   ShowLabels       - Force per-node labels on/off ([] = auto: on unless
%                      group anchors are shown).
%   RingGuide        - Draw a faint guide circle through the nodes (default: true)
%   EdgeColor        - [] (default) color arcs by coupling sign, or an RGB
%                      triplet to draw every arc in one uniform color.
%   ArcAlpha         - Arc transparency (default: 0.6)
%   Title            - Figure title (default: auto)
%   Visible          - 'on' (default) or 'off'
%   SavePath         - File path to save figure
%   SaveWidth        - Width in pixels (default: 600)
%   SaveHeight       - Height in pixels (default: 600)
%   SaveDPI          - Resolution (default: 150)
%
% Outputs:
%   fig - Figure handle
%
% Notes:
%   - NodeColors > NodeValues > flat blue, in decreasing precedence.
%   - 'auto' group inference strips a trailing index from each label (so
%     'L-FP 1','L-FP 2' share the 'L-FP' anchor); it is skipped when the
%     labels yield one group or all-distinct groups (nothing to anchor).
%   - The colorbar tracks NodeValues; arc colors are drawn as explicit RGB
%     and are independent of the axes colormap.
%   - MinThreshold / SignificanceMask affect the drawn EDGES only. The node
%     value ('auto'/'signed'/'strength' or a supplied vector) is computed
%     from the full matrix, so a node can be strongly colored while few or no
%     arcs touch it.
%   - 'auto'/'strength' node values are a data-dependent descriptive summary,
%     not a statistic. With default limits the color scale is rescaled per
%     figure from that matrix, so node colors are NOT comparable across
%     figures/subjects/conditions unless you pass a shared explicit NodeCLim.
%   - RingGuide defaults to true: a faint guide circle is drawn through the
%     nodes (set false to restore the bare layout).
%
% Example:
%   r = exploreFNIRS.connectivity.computeMatrix(proc, 'Method', 'pearson');
%   % Publication-style connectogram: nodes colored by a contrast, region
%   % anchors from labels, uniform subtle edges.
%   exploreFNIRS.connectivity.plotChord(r, ...
%       'NodeValues', deltaR, 'NodeColormap', 'rdbu', ...
%       'ColorbarLabel', '\Deltar (Together - Apart)', ...
%       'EdgeColor', [0.55 0.75 0.88], 'GroupLabels', 'auto', ...
%       'MinThreshold', 0.3, 'SavePath', 'connectogram.png');
%   % Or derive a node strength when no contrast is available:
%   exploreFNIRS.connectivity.plotChord(r, 'NodeValues', 'auto');
%
% See also: exploreFNIRS.connectivity.plotMatrix, exploreFNIRS.connectivity.plotDirected

    p = inputParser;
    addRequired(p, 'result', @isstruct);
    addParameter(p, 'MinThreshold', 0, @isnumeric);
    addParameter(p, 'ArcWidth', 'proportional', @ischar);
    addParameter(p, 'SignificanceMask', false, @islogical);
    addParameter(p, 'PThreshold', 0.05, @isnumeric);
    addParameter(p, 'NodeSize', 100, @isnumeric);
    addParameter(p, 'NodeColors', [], @isnumeric);
    addParameter(p, 'NodeValues', [], @(x) isempty(x) || isnumeric(x) || ...
        ischar(x) || isstring(x));
    addParameter(p, 'NodeColormap', 'rdbu', @(x) ischar(x) || isstring(x) || isnumeric(x));
    addParameter(p, 'NodeCLim', [], @(x) isempty(x) || (isnumeric(x) && numel(x) == 2));
    addParameter(p, 'ColorbarLabel', [], @(x) isempty(x) || ischar(x) || isstring(x));
    addParameter(p, 'GroupLabels', [], @(x) isempty(x) || ischar(x) || isstring(x) || iscell(x));
    addParameter(p, 'ShowLabels', [], @(x) isempty(x) || islogical(x));
    addParameter(p, 'RingGuide', true, @islogical);
    addParameter(p, 'EdgeColor', [], @(x) isempty(x) || (isnumeric(x) && numel(x) == 3));
    addParameter(p, 'ArcAlpha', 0.6, @isnumeric);
    addParameter(p, 'Title', '', @ischar);
    addParameter(p, 'Visible', 'on', @ischar);
    addParameter(p, 'SavePath', '', @ischar);
    addParameter(p, 'SaveWidth', 600, @isnumeric);
    addParameter(p, 'SaveHeight', 600, @isnumeric);
    addParameter(p, 'SaveDPI', 150, @isnumeric);
    addParameter(p, 'TightLayout', false, @islogical);
    parse(p, result, varargin{:});
    opts = p.Results;
    result = exploreFNIRS.connectivity.normalizeResult(result);

    if ~isempty(opts.SavePath)
        opts.Visible = 'off';
    end

    mat = result.matrix;
    nCh = size(mat, 1);

    % Build labels
    if isfield(result, 'labels') && ~isempty(result.labels)
        chLabels = pf2_base.plot.escapeTeX(result.labels);
    else
        chLabels = arrayfun(@(c) sprintf('Ch%d', c), result.channels, ...
            'UniformOutput', false);
    end

    % Apply significance mask
    if opts.SignificanceMask && isfield(result, 'pmatrix')
        nonsig = result.pmatrix > opts.PThreshold;
        mat(nonsig) = 0;
    end

    % Zero diagonal
    for i = 1:nCh
        mat(i, i) = 0;
    end

    % Resolve per-node values + colors (NodeColors > NodeValues > flat blue)
    nodeVals = resolveNodeValues(opts.NodeValues, mat, nCh);
    nodeColorActive = ~isempty(nodeVals) && ...
        (isempty(opts.NodeColors) || size(opts.NodeColors, 1) < nCh);
    valueNodeColors = [];   % only assigned when nodeColorActive
    if nodeColorActive
        % Diverging 'rdbu'/symmetric limits suit a SIGNED value. When the
        % node values are all non-negative and the caller left the colormap
        % and limits at defaults, switch to a sequential map over [0, m] so
        % half the diverging map is not wasted (and no false sign is implied).
        defaultCmap = ismember('NodeColormap', p.UsingDefaults);
        defaultCLim = ismember('NodeCLim', p.UsingDefaults);
        nonNeg = ~any(nodeVals < 0);
        cmapSpec = opts.NodeColormap;
        if nonNeg && defaultCmap
            cmapSpec = 'viridis';
        end
        nodeCmap = resolveNodeColormap(cmapSpec, 256);
        nodeCLim = opts.NodeCLim;
        if isempty(nodeCLim)
            m = max(abs(nodeVals), [], 'omitnan');
            if isempty(m) || ~isfinite(m) || m == 0, m = 1; end
            if nonNeg && defaultCLim
                nodeCLim = [0, m];
            else
                nodeCLim = [-m, m];
            end
        end
        nodeCLim = sort(nodeCLim);
        valueNodeColors = valuesToColors(nodeVals, nodeCmap, nodeCLim);
    end

    % Resolve region anchor groups
    groups = resolveGroups(opts.GroupLabels, chLabels, nCh);
    showNodeLabels = opts.ShowLabels;
    if isempty(showNodeLabels)
        showNodeLabels = isempty(groups);   % default: hide per-node when grouped
    end

    fig = pf2_base.plot.createFigure('Visible', opts.Visible, ...
        'Width', opts.SaveWidth, 'Height', opts.SaveHeight, ...
        'SavePath', opts.SavePath);
    ax = axes('Parent', fig);
    sty = pf2_base.plot.PlotStyle.getDefault();

    hold(ax, 'on');
    axis(ax, 'equal');
    axis(ax, 'off');

    % Node positions on unit circle
    angles = linspace(0, 2*pi, nCh + 1);
    angles = angles(1:nCh);
    nodeX = cos(angles);
    nodeY = sin(angles);

    % Faint guide ring through the nodes
    if opts.RingGuide
        th = linspace(0, 2*pi, 200);
        plot(ax, cos(th), sin(th), '-', 'Color', [0.8 0.8 0.8], ...
            'LineWidth', 0.75, 'HandleVisibility', 'off');
    end

    % Colormap for arcs (diverging: blue = negative, red = positive)
    cmap = divergingColormap(256);

    maxVal = max(abs(mat(:)), [], 'omitnan');
    if isempty(maxVal) || ~isfinite(maxVal) || maxVal == 0
        maxVal = 1;
    end

    % Draw arcs (upper triangle only for symmetric)
    for i = 1:nCh
        for j = (i+1):nCh
            val = mat(i, j);
            if isnan(val) || abs(val) < opts.MinThreshold
                continue;
            end

            % Quadratic Bezier arc
            midX = (nodeX(i) + nodeX(j)) / 2;
            midY = (nodeY(i) + nodeY(j)) / 2;
            % Control point pulled toward center
            pullFactor = 0.5;
            ctrlX = midX * (1 - pullFactor);
            ctrlY = midY * (1 - pullFactor);

            t = linspace(0, 1, 80);
            bx = (1-t).^2 * nodeX(i) + 2*(1-t).*t * ctrlX + t.^2 * nodeX(j);
            by = (1-t).^2 * nodeY(i) + 2*(1-t).*t * ctrlY + t.^2 * nodeY(j);

            % Arc width
            if strcmpi(opts.ArcWidth, 'proportional')
                lw = 0.5 + 3.0 * abs(val) / maxVal;
            else
                lw = 1.5;
            end

            % Arc color: uniform EdgeColor if given, else by coupling sign
            if ~isempty(opts.EdgeColor)
                arcColor = opts.EdgeColor(:)';
            else
                cidx = round((val / maxVal + 1) / 2 * 255) + 1;
                cidx = max(1, min(256, cidx));
                arcColor = cmap(cidx, :);
            end

            plot(ax, bx, by, '-', 'Color', [arcColor, opts.ArcAlpha], ...
                'LineWidth', lw);
        end
    end

    % Draw nodes (NodeColors > NodeValues > flat blue)
    if ~isempty(opts.NodeColors) && size(opts.NodeColors, 1) >= nCh
        nodeColors = opts.NodeColors;
    elseif nodeColorActive
        nodeColors = valueNodeColors;
    else
        nodeColors = repmat([0.3, 0.5, 0.8], nCh, 1);
    end
    scatter(ax, nodeX, nodeY, opts.NodeSize, nodeColors, 'filled', ...
        'MarkerEdgeColor', sty.ForegroundColor, 'LineWidth', 0.8);

    % Per-node labels
    if showNodeLabels
        labelOffset = 1.15;
        for i = 1:nCh
            ha = 'center';
            if nodeX(i) > 0.1
                ha = 'left';
            elseif nodeX(i) < -0.1
                ha = 'right';
            end
            text(ax, nodeX(i) * labelOffset, nodeY(i) * labelOffset, ...
                pf2_base.plot.escapeTeX(chLabels{i}), ...
                'HorizontalAlignment', ha, 'FontSize', 9, ...
                'Color', sty.ForegroundColor);
        end
    end

    % Region anchor labels (one per group, at the group's mean angle)
    if ~isempty(groups)
        groupOffset = 1.3;
        for g = 1:numel(groups)
            ga = meanAngle(angles(groups(g).nodes));
            gx = cos(ga); gy = sin(ga);
            ha = 'center';
            if gx > 0.1
                ha = 'left';
            elseif gx < -0.1
                ha = 'right';
            end
            text(ax, gx * groupOffset, gy * groupOffset, ...
                pf2_base.plot.escapeTeX(groups(g).name), ...
                'HorizontalAlignment', ha, 'FontSize', 11, ...
                'FontWeight', 'bold', 'Color', sty.ForegroundColor);
        end
    end

    if ~isempty(opts.Title)
        title(ax, pf2_base.plot.escapeTeX(opts.Title));
    else
        titleStr = sprintf('Chord Diagram (%s, %s)', result.method, result.biomarker);
        if opts.SignificanceMask
            titleStr = sprintf('%s [p < %.2f]', titleStr, opts.PThreshold);
        end
        title(ax, pf2_base.plot.escapeTeX(titleStr));
    end

    hold(ax, 'off');
    sty.applyToAxes(ax);

    % Pad limits so node (1.15) / group (1.3) labels are not clipped
    lim = 1.15;
    if showNodeLabels, lim = 1.32; end
    if ~isempty(groups), lim = 1.5; end
    xlim(ax, [-lim lim]); ylim(ax, [-lim lim]);

    % Node colorbar (tracks NodeValues, independent of arc colors)
    cbLabel = opts.ColorbarLabel;
    if nodeColorActive && ~(ischar(cbLabel) || isstring(cbLabel)) % [] -> auto
        cbLabel = nodeColorbarLabel(result);
    end
    if nodeColorActive && ~isempty(char(string(cbLabel)))
        colormap(ax, nodeCmap);
        set(ax, 'CLim', nodeCLim);
        cb = colorbar(ax);
        cb.Label.String = pf2_base.plot.escapeTeX(char(string(cbLabel)));
    end

    % Save
    if ~isempty(opts.SavePath)
        pf2_base.plot.handleSave(fig, opts);
    end
end


function vals = resolveNodeValues(param, mat, nCh)
% Resolve the per-node value vector from the NodeValues parameter.
%   []            -> [] (legacy flat-blue nodes)
%   'auto'        -> signed node strength (mean off-diagonal coupling)
%   [N x 1]/[1xN] -> as given
    vals = [];
    if isempty(param)
        return;
    end
    if ischar(param) || isstring(param)
        key = lower(char(string(param)));
        switch key
            case {'auto', 'signed'}
                M = mat;
                M(1:nCh+1:end) = NaN;            % ignore diagonal
                vals = mean(M, 2, 'omitnan');     % signed mean coupling per node
            case {'strength', 'degree', 'abs', 'absstrength'}
                M = abs(mat);                     % unsigned weighted degree
                M(1:nCh+1:end) = NaN;            % ignore diagonal
                vals = mean(M, 2, 'omitnan');
            otherwise
                error('exploreFNIRS:connectivity:plotChord:badNodeValues', ...
                    ['NodeValues string must be ''auto''/''signed'' (signed ', ...
                     'mean coupling) or ''strength''/''degree'' (absolute); ', ...
                     'got ''%s''.'], key);
        end
        return;
    end
    vals = param(:);
    if numel(vals) ~= nCh
        error('exploreFNIRS:connectivity:plotChord:nodeValuesSize', ...
            'NodeValues must have %d elements (one per node); got %d.', ...
            nCh, numel(vals));
    end
end


function cmap = resolveNodeColormap(name, n)
% Resolve a node colormap from a name or an [M x 3] matrix.
    if isnumeric(name) && size(name, 2) == 3
        cmap = name;
        return;
    end
    cmap = pf2_base.plot.brainColormap(char(string(name)), n);
end


function colors = valuesToColors(vals, cmap, clim)
% Map a value vector to RGB rows through cmap over the limits clim.
    n = size(cmap, 1);
    span = clim(2) - clim(1);
    if span == 0, span = 1; end
    idx = round((vals - clim(1)) / span * (n - 1)) + 1;
    idx(~isfinite(idx)) = 1;
    idx = max(1, min(n, idx));
    colors = cmap(idx, :);
end


function groups = resolveGroups(param, labels, nCh)
% Resolve region anchor groups -> struct array with .name and .nodes.
%   []            -> [] (no anchors)
%   'auto'        -> infer from labels by stripping a trailing index
%   {1xN}/strings -> explicit per-node group name ('' = no group)
    groups = struct('name', {}, 'nodes', {});
    if isempty(param)
        return;
    end
    if (ischar(param) || isstring(param)) && isscalar(string(param))
        if ~strcmpi(char(string(param)), 'auto')
            error('exploreFNIRS:connectivity:plotChord:badGroupLabels', ...
                'GroupLabels string must be ''auto''.');
        end
        names = cellfun(@stripIndexSuffix, cellstr(string(labels(:))), ...
            'UniformOutput', false);
    else
        names = cellstr(string(param(:)));
        if numel(names) ~= nCh
            error('exploreFNIRS:connectivity:plotChord:groupLabelsSize', ...
                'GroupLabels must have %d elements (one per node); got %d.', ...
                nCh, numel(names));
        end
    end

    uniq = unique(names(~cellfun(@isempty, names)), 'stable');
    % Degenerate auto-inference yields no useful anchors, so skip it. This
    % covers default labels like {'Ch1'..'ChN'} (all collapse to 'Ch' -> one
    % group) and labels with no shared stem (N distinct groups). The guard is
    % intentionally 'auto'-only: an explicit per-node GroupLabels cell is
    % taken at face value, even if every node ends up its own anchor.
    if (ischar(param) || isstring(param)) && ...
            (numel(uniq) <= 1 || numel(uniq) >= nCh)
        return;
    end
    for k = 1:numel(uniq)
        groups(k).name = uniq{k}; %#ok<AGROW>
        groups(k).nodes = find(strcmp(names, uniq{k})); %#ok<AGROW>
    end
end


function s = stripIndexSuffix(s)
% Strip a trailing channel/ROI index so 'L-FP 2' -> 'L-FP'.
    s = regexprep(char(s), '[\s_\-]*\d+\s*$', '');
    s = strtrim(s);
end


function a = meanAngle(angles)
% Circular mean of a set of angles (radians).
    a = atan2(mean(sin(angles)), mean(cos(angles)));
end


function lbl = nodeColorbarLabel(result)
% Default colorbar label for node values - self-identifies as node-level so
% it is not mistaken for an edge scale.
    lbl = 'Node value';
    if isfield(result, 'method') && ~isempty(result.method)
        lbl = sprintf('Node value (%s)', char(string(result.method)));
    end
end


function cmap = divergingColormap(n)
% Blue-white-red diverging colormap
    half = floor(n / 2);

    r1 = linspace(0.2, 1, half)';
    g1 = linspace(0.3, 1, half)';
    b1 = linspace(0.8, 1, half)';

    r2 = linspace(1, 0.8, n - half)';
    g2 = linspace(1, 0.2, n - half)';
    b2 = linspace(1, 0.2, n - half)';

    cmap = [r1 g1 b1; r2 g2 b2];
end
