function fig = plotNetwork(G, varargin)
% PLOTNETWORK Node-link diagram with metric-based sizing and community coloring
%
% Renders a graph as a node-link diagram. Node size scales with a chosen
% metric (default: degree). When community assignments are provided, nodes
% are colored by community. Supports force-directed, circle, and probe-based
% 2D layouts. Respects MATLAB dark mode and PlotStyle settings.
%
% Syntax:
%   fig = exploreFNIRS.graph.plotNetwork(G)
%   fig = exploreFNIRS.graph.plotNetwork(G, 'NodeMetric', degreeVals)
%   fig = exploreFNIRS.graph.plotNetwork(G, 'Layout', 'circle', 'CommunityID', ci)
%   fig = exploreFNIRS.graph.plotNetwork(G, 'Layout', 'probe', 'Device', dev)
%
% Inputs:
%   G - Graph struct from exploreFNIRS.graph.threshold
%
% Name-Value Parameters:
%   Layout       - 'force' (default), 'circle', 'probe'
%   NodeMetric   - [1 x N] values for node sizing (default: degree)
%   CommunityID  - [1 x N] community labels for coloring
%   Device       - pf2.Device object for 'probe' layout
%   EdgeAlpha    - Edge transparency (default: 0.4)
%   MinNodeSize  - Minimum node marker size (default: 30)
%   MaxNodeSize  - Maximum node marker size (default: 300)
%   Title        - Figure title (default: auto)
%   Visible      - 'on' (default) or 'off'
%   SavePath     - File path to save figure
%   SaveWidth    - Width in pixels (default: 600)
%   SaveHeight   - Height in pixels (default: 600)
%   SaveDPI      - Resolution (default: 150)
%
% Outputs:
%   fig - Figure handle
%
% Example:
%   metrics = exploreFNIRS.graph.computeMetrics(conn);
%   G = metrics.graph;
%   fig = exploreFNIRS.graph.plotNetwork(G, ...
%       'NodeMetric', metrics.degree.strength, ...
%       'CommunityID', metrics.modularity.communityID);
%
% See also: exploreFNIRS.graph.threshold, exploreFNIRS.graph.plotMetrics,
%   exploreFNIRS.graph.computeMetrics

    p = inputParser;
    addRequired(p, 'G', @isstruct);
    addParameter(p, 'Layout', 'force', ...
        @(x) ischar(x) && ismember(lower(x), {'force','circle','probe'}));
    addParameter(p, 'NodeMetric', [], @(x) isnumeric(x));
    addParameter(p, 'CommunityID', [], @(x) isnumeric(x));
    addParameter(p, 'Device', [], @(x) isempty(x) || isobject(x));
    addParameter(p, 'EdgeAlpha', 0.4, @isnumeric);
    addParameter(p, 'MinNodeSize', 30, @isnumeric);
    addParameter(p, 'MaxNodeSize', 300, @isnumeric);
    addParameter(p, 'Title', '', @ischar);
    addParameter(p, 'Visible', 'on', @ischar);
    addParameter(p, 'SavePath', '', @ischar);
    addParameter(p, 'SaveWidth', 600, @isnumeric);
    addParameter(p, 'SaveHeight', 600, @isnumeric);
    addParameter(p, 'SaveDPI', 150, @isnumeric);
    parse(p, G, varargin{:});
    opts = p.Results;

    if ~isempty(opts.SavePath)
        opts.Visible = 'off';
    end

    N = G.N;
    W = G.W;
    sty = pf2_base.plot.PlotStyle.getDefault();

    % Default node metric: degree
    if isempty(opts.NodeMetric)
        nodeMetric = sum(G.A, 2)';
    else
        nodeMetric = opts.NodeMetric;
    end

    % Scale node sizes
    nodeSizes = scaleMetric(nodeMetric, opts.MinNodeSize, opts.MaxNodeSize);

    % Node colors: by community or default accent
    if ~isempty(opts.CommunityID)
        ci = opts.CommunityID;
        nComm = max(ci);
        cmap = lines(nComm);
        nodeColors = cmap(ci, :);
    else
        % Use a visible accent color (not foreground, which is black/white)
        defaultAccent = [0.0, 0.447, 0.741];  % MATLAB default blue
        nodeColors = repmat(defaultAccent, N, 1);
    end

    % Compute layout positions
    [xPos, yPos] = computeLayout(G, lower(opts.Layout), opts.Device);

    % Create figure
    fig = pf2_base.plot.createFigure('Visible', opts.Visible, ...
        'Width', opts.SaveWidth, 'Height', opts.SaveHeight, ...
        'SavePath', opts.SavePath);
    ax = axes('Parent', fig);
    hold(ax, 'on');
    axis(ax, 'equal');
    axis(ax, 'off');

    % Edge color from PlotStyle (dim/muted)
    edgeRGB = sty.DimColor;

    % Draw edges
    maxW = max(abs(W(:)));
    if maxW == 0, maxW = 1; end

    if G.directed
        edgePairs = find(W);
    else
        edgePairs = find(triu(W));
    end

    for idx = 1:length(edgePairs)
        [i, j] = ind2sub([N, N], edgePairs(idx));
        w = abs(W(i, j));
        lineW = 0.5 + 2.5 * (w / maxW);
        plot(ax, [xPos(i), xPos(j)], [yPos(i), yPos(j)], '-', ...
            'Color', [edgeRGB, opts.EdgeAlpha], ...
            'LineWidth', lineW);
    end

    % Draw nodes with theme-aware edge color
    for i = 1:N
        scatter(ax, xPos(i), yPos(i), nodeSizes(i), nodeColors(i, :), ...
            'filled', 'MarkerEdgeColor', sty.ForegroundColor, 'LineWidth', 0.5);
    end

    % Labels with theme-aware text color
    labels = G.labels;
    if ~isempty(labels)
        labels = pf2_base.plot.escapeTeX(labels);
        yRange = range(yPos);
        if yRange == 0, yRange = 1; end
        for i = 1:N
            text(ax, xPos(i), yPos(i) - 0.06 * yRange - 0.02, labels{i}, ...
                'HorizontalAlignment', 'center', 'FontSize', sty.FontSize - 2, ...
                'VerticalAlignment', 'top', 'Color', sty.ForegroundColor);
        end
    end

    % Title with theme-aware color
    if ~isempty(opts.Title)
        title(ax, opts.Title, 'FontSize', sty.FontSize + 1, ...
            'Color', sty.ForegroundColor);
    else
        title(ax, 'Network Graph', 'FontSize', sty.FontSize + 1, ...
            'Color', sty.ForegroundColor);
    end

    hold(ax, 'off');

    % Apply theme to figure (handles axis off case)
    sty.applyToFigure(fig);

    pf2_base.plot.handleSave(fig, opts);
end


function [x, y] = computeLayout(G, layout, dev)
% Compute 2D node positions based on layout type

    N = G.N;

    switch layout
        case 'circle'
            angles = linspace(0, 2*pi, N + 1);
            angles = angles(1:N);
            x = cos(angles);
            y = sin(angles);

        case 'probe'
            if ~isempty(dev) && isobject(dev)
                try
                    lay = dev.layout2D();
                    chIdx = G.channels;
                    if max(chIdx) <= size(lay, 1)
                        x = lay(chIdx, 1)';
                        y = lay(chIdx, 2)';
                        return;
                    end
                catch
                    % Fall through to force layout
                end
            end
            warning('exploreFNIRS:graph:plotNetwork', ...
                'Probe layout unavailable, falling back to force layout');
            [x, y] = forceLayout(G);

        case 'force'
            [x, y] = forceLayout(G);
    end
end


function [x, y] = forceLayout(G)
% Simple force-directed layout (Fruchterman-Reingold style)

    N = G.N;
    if N <= 1
        x = 0; y = 0;
        return;
    end

    % Initialize random positions
    rng_state = rng;
    rng(42);  % reproducible layout
    pos = rand(N, 2) * 2 - 1;
    rng(rng_state);

    area = 4;
    k = sqrt(area / N);
    temp = 1;
    nIter = 50;

    for iter = 1:nIter
        % Repulsive forces
        dx = zeros(N, 1);
        dy = zeros(N, 1);

        for i = 1:N
            for j = (i+1):N
                delta = pos(i, :) - pos(j, :);
                dist = max(norm(delta), 0.01);
                force = k^2 / dist;
                fVec = (delta / dist) * force;
                dx(i) = dx(i) + fVec(1);
                dy(i) = dy(i) + fVec(2);
                dx(j) = dx(j) - fVec(1);
                dy(j) = dy(j) - fVec(2);
            end
        end

        % Attractive forces (edges)
        for i = 1:N
            for j = (i+1):N
                if G.A(i, j) || G.A(j, i)
                    delta = pos(i, :) - pos(j, :);
                    dist = max(norm(delta), 0.01);
                    force = dist^2 / k;
                    fVec = (delta / dist) * force;
                    dx(i) = dx(i) - fVec(1);
                    dy(i) = dy(i) - fVec(2);
                    dx(j) = dx(j) + fVec(1);
                    dy(j) = dy(j) + fVec(2);
                end
            end
        end

        % Apply with temperature cooling
        for i = 1:N
            disp_len = max(sqrt(dx(i)^2 + dy(i)^2), 0.01);
            pos(i, 1) = pos(i, 1) + (dx(i) / disp_len) * min(disp_len, temp);
            pos(i, 2) = pos(i, 2) + (dy(i) / disp_len) * min(disp_len, temp);
        end

        temp = temp * (1 - iter / nIter);
    end

    x = pos(:, 1)';
    y = pos(:, 2)';
end


function sizes = scaleMetric(metric, minSize, maxSize)
% Scale metric values to [minSize, maxSize] range
    mn = min(metric);
    mx = max(metric);
    if mx - mn < eps
        sizes = repmat((minSize + maxSize) / 2, size(metric));
    else
        sizes = minSize + (maxSize - minSize) * (metric - mn) / (mx - mn);
    end
end
