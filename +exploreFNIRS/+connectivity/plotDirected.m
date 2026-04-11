function fig = plotDirected(result, varargin)
% PLOTDIRECTED Visualize directed (asymmetric) connectivity matrix
%
% Renders a directed connectivity matrix as either an asymmetric heatmap
% or a circular graph with directed arcs and arrowheads. Designed for
% directed methods such as Granger causality and transfer entropy.
%
% Syntax:
%   fig = exploreFNIRS.connectivity.plotDirected(result)
%   fig = exploreFNIRS.connectivity.plotDirected(result, 'Layout', 'circular')
%   fig = exploreFNIRS.connectivity.plotDirected(result, 'MinThreshold', 0.5)
%
% Inputs:
%   result - Connectivity result struct from computeMatrix with fields:
%            .matrix, .pmatrix, .channels, .method, .biomarker, .labels
%
% Name-Value Parameters:
%   Layout          - 'matrix' (default) or 'circular'
%                     matrix: asymmetric heatmap (rows = source, cols = target)
%                     circular: nodes on a circle with directed arcs
%   MinThreshold    - Minimum absolute value to display (default: 0)
%   SignificanceMask - Mask non-significant connections (default: false)
%   PThreshold      - p-value threshold for masking (default: 0.05)
%   ArrowScale      - Scale factor for arrow size in circular layout (default: 1)
%   CLim            - Color limits [cmin cmax] for matrix layout (default: auto)
%   ShowValues      - Show values in matrix cells (default: false)
%   Title           - Figure title (default: auto)
%   Visible         - 'on' (default) or 'off'
%   SavePath        - File path to save figure
%   SaveWidth       - Width in pixels (default: 600)
%   SaveHeight      - Height in pixels (default: 600)
%   SaveDPI         - Resolution (default: 150)
%
% Outputs:
%   fig - Figure handle
%
% See also: exploreFNIRS.connectivity.computeMatrix, exploreFNIRS.connectivity.plotMatrix

    p = inputParser;
    addRequired(p, 'result', @isstruct);
    addParameter(p, 'Layout', 'matrix', @ischar);
    addParameter(p, 'MinThreshold', 0, @isnumeric);
    addParameter(p, 'SignificanceMask', false, @islogical);
    addParameter(p, 'PThreshold', 0.05, @isnumeric);
    addParameter(p, 'ArrowScale', 1, @isnumeric);
    addParameter(p, 'CLim', [], @(v) isempty(v) || (isnumeric(v) && length(v) == 2));
    addParameter(p, 'ShowValues', false, @islogical);
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
        chLabels = result.labels;
    else
        chLabels = arrayfun(@(c) sprintf('Ch%d', c), result.channels, ...
            'UniformOutput', false);
    end

    % Apply significance mask
    if opts.SignificanceMask && isfield(result, 'pmatrix')
        nonsig = result.pmatrix > opts.PThreshold;
        mat(nonsig) = 0;
    end

    % Apply threshold
    if opts.MinThreshold > 0
        mat(abs(mat) < opts.MinThreshold) = 0;
    end

    % Zero out diagonal
    for i = 1:nCh
        mat(i, i) = 0;
    end

    switch lower(opts.Layout)
        case 'matrix'
            fig = plotMatrixLayout(mat, chLabels, result, opts);
        case 'circular'
            fig = plotCircularLayout(mat, chLabels, result, opts);
        otherwise
            error('exploreFNIRS:connectivity:plotDirected', ...
                'Unknown layout "%s". Use: matrix, circular', opts.Layout);
    end

    % Save
    if ~isempty(opts.SavePath)
        pf2_base.plot.handleSave(fig, opts);
    end
end


function fig = plotMatrixLayout(mat, chLabels, result, opts)
% Asymmetric heatmap: rows = source (from), columns = target (to)

    nCh = size(mat, 1);

    fig = pf2_base.plot.createFigure('Visible', opts.Visible, ...
        'Width', opts.SaveWidth, 'Height', opts.SaveHeight, ...
        'SavePath', opts.SavePath);
    ax = axes('Parent', fig);
    sty = pf2_base.plot.PlotStyle.getDefault();

    if isempty(opts.CLim)
        maxVal = max(abs(mat(:)));
        if maxVal == 0
            maxVal = 1;
        end
        cLim = [0, maxVal];
    else
        cLim = opts.CLim;
    end

    imagesc(ax, mat, cLim);
    axis(ax, 'square');

    chLabels = pf2_base.plot.escapeTeX(chLabels);
    set(ax, 'XTick', 1:nCh, 'XTickLabel', chLabels, 'XTickLabelRotation', 45);
    set(ax, 'YTick', 1:nCh, 'YTickLabel', chLabels);

    % Reduce label density for large matrices
    if nCh > 20
        tickStep = ceil(nCh / 20);
        ticks = 1:tickStep:nCh;
        set(ax, 'XTick', ticks, 'XTickLabel', chLabels(ticks));
        set(ax, 'YTick', ticks, 'YTickLabel', chLabels(ticks));
    end

    % Hot colormap for directed values (typically positive F-stats or TE)
    cmap = hot(256);
    cmap = flipud(cmap);
    colormap(ax, cmap);
    cb = colorbar(ax);
    cb.Label.String = result.method;

    xlabel(ax, 'Target (to)');
    ylabel(ax, 'Source (from)');

    % Show values in cells
    if opts.ShowValues && nCh <= 20
        for i = 1:nCh
            for j = 1:nCh
                if i ~= j && mat(i,j) ~= 0 && ~isnan(mat(i,j))
                    txt = sprintf('%.2f', mat(i,j));
                    textColor = 'k';
                    if mat(i,j) > 0.7 * max(abs(mat(:)))
                        textColor = 'w';
                    end
                    text(ax, j, i, txt, 'HorizontalAlignment', 'center', ...
                        'FontSize', 7, 'Color', textColor);
                end
            end
        end
    end

    if ~isempty(opts.Title)
        title(ax, pf2_base.plot.escapeTeX(opts.Title));
    else
        titleStr = sprintf('Directed Connectivity (%s, %s)', result.method, result.biomarker);
        if opts.SignificanceMask
            titleStr = sprintf('%s [p < %.2f]', titleStr, opts.PThreshold);
        end
        title(ax, pf2_base.plot.escapeTeX(titleStr));
    end

    sty.applyToAxes(ax);
end


function fig = plotCircularLayout(mat, chLabels, result, opts)
% Nodes on a circle with directed arcs

    nCh = size(mat, 1);

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

    % Find max value for normalization
    maxVal = max(abs(mat(:)));
    if maxVal == 0
        maxVal = 1;
    end

    % Color map for arcs
    cmap = hot(256);
    cmap = flipud(cmap);

    % Draw arcs
    for i = 1:nCh
        for j = 1:nCh
            if i == j, continue; end
            val = mat(i, j);
            if val == 0 || isnan(val), continue; end

            % Quadratic Bezier from node i to node j
            % Control point at center, pulled inward
            midX = (nodeX(i) + nodeX(j)) / 2;
            midY = (nodeY(i) + nodeY(j)) / 2;
            % Pull control point toward center
            pullFactor = 0.3;
            ctrlX = midX * (1 - pullFactor);
            ctrlY = midY * (1 - pullFactor);

            % Bezier curve
            t = linspace(0, 1, 50);
            bx = (1-t).^2 * nodeX(i) + 2*(1-t).*t * ctrlX + t.^2 * nodeX(j);
            by = (1-t).^2 * nodeY(i) + 2*(1-t).*t * ctrlY + t.^2 * nodeY(j);

            % Line width proportional to value
            lw = 0.5 + 2.5 * abs(val) / maxVal;

            % Color from colormap
            cidx = max(1, min(256, round(abs(val) / maxVal * 255) + 1));
            arcColor = cmap(cidx, :);

            plot(ax, bx, by, '-', 'Color', arcColor, 'LineWidth', lw);

            % Arrowhead at destination
            arrowLen = 0.08 * opts.ArrowScale;
            % Direction at end of curve (tangent)
            dx = bx(end) - bx(end-1);
            dy = by(end) - by(end-1);
            normD = sqrt(dx^2 + dy^2);
            if normD > 0
                dx = dx / normD;
                dy = dy / normD;
            end
            % Arrow tip slightly before the node
            tipX = nodeX(j) - dx * 0.08;
            tipY = nodeY(j) - dy * 0.08;
            % Arrow wings
            perpX = -dy;
            perpY = dx;
            wing1X = tipX - dx * arrowLen + perpX * arrowLen * 0.4;
            wing1Y = tipY - dy * arrowLen + perpY * arrowLen * 0.4;
            wing2X = tipX - dx * arrowLen - perpX * arrowLen * 0.4;
            wing2Y = tipY - dy * arrowLen - perpY * arrowLen * 0.4;

            fill(ax, [tipX, wing1X, wing2X], [tipY, wing1Y, wing2Y], ...
                arcColor, 'EdgeColor', 'none');
        end
    end

    % Draw nodes
    nodeSize = 80;
    scatter(ax, nodeX, nodeY, nodeSize, [0.3, 0.5, 0.8], 'filled', ...
        'MarkerEdgeColor', sty.ForegroundColor, 'LineWidth', 0.8);

    % Node labels
    chLabels = pf2_base.plot.escapeTeX(chLabels);
    labelOffset = 1.15;
    for i = 1:nCh
        text(ax, nodeX(i) * labelOffset, nodeY(i) * labelOffset, ...
            pf2_base.plot.escapeTeX(chLabels{i}), ...
            'HorizontalAlignment', 'center', 'FontSize', 9);
    end

    if ~isempty(opts.Title)
        title(ax, pf2_base.plot.escapeTeX(opts.Title));
    else
        title(ax, pf2_base.plot.escapeTeX(sprintf('Directed Connectivity (%s, %s)', result.method, result.biomarker)));
    end

    hold(ax, 'off');
    sty.applyToAxes(ax);
end
