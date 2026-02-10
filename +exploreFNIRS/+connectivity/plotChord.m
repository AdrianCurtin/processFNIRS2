function fig = plotChord(result, varargin)
% PLOTCHORD Chord diagram for channel/ROI connectivity
%
% Visualizes a connectivity matrix as a chord diagram with nodes arranged
% on a unit circle and quadratic Bezier arcs connecting coupled pairs.
% Arc color and width encode coupling strength.
%
% Syntax:
%   fig = exploreFNIRS.connectivity.plotChord(result)
%   fig = exploreFNIRS.connectivity.plotChord(result, 'MinThreshold', 0.3)
%   fig = exploreFNIRS.connectivity.plotChord(result, 'ArcWidth', 'fixed')
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
%   NodeColors       - [N x 3] custom node colors (default: auto)
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
% See also: exploreFNIRS.connectivity.plotMatrix, exploreFNIRS.connectivity.plotDirected

    p = inputParser;
    addRequired(p, 'result', @isstruct);
    addParameter(p, 'MinThreshold', 0, @isnumeric);
    addParameter(p, 'ArcWidth', 'proportional', @ischar);
    addParameter(p, 'SignificanceMask', false, @islogical);
    addParameter(p, 'PThreshold', 0.05, @isnumeric);
    addParameter(p, 'NodeSize', 100, @isnumeric);
    addParameter(p, 'NodeColors', [], @isnumeric);
    addParameter(p, 'ArcAlpha', 0.6, @isnumeric);
    addParameter(p, 'Title', '', @ischar);
    addParameter(p, 'Visible', 'on', @ischar);
    addParameter(p, 'SavePath', '', @ischar);
    addParameter(p, 'SaveWidth', 600, @isnumeric);
    addParameter(p, 'SaveHeight', 600, @isnumeric);
    addParameter(p, 'SaveDPI', 150, @isnumeric);
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

    % Colormap for arcs (diverging: blue = negative, red = positive)
    cmap = divergingColormap(256);

    maxVal = max(abs(mat(:)));
    if maxVal == 0
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

            % Color from diverging colormap
            cidx = round((val / maxVal + 1) / 2 * 255) + 1;
            cidx = max(1, min(256, cidx));
            arcColor = cmap(cidx, :);

            plot(ax, bx, by, '-', 'Color', [arcColor, opts.ArcAlpha], ...
                'LineWidth', lw);
        end
    end

    % Draw nodes
    if ~isempty(opts.NodeColors) && size(opts.NodeColors, 1) >= nCh
        nodeColors = opts.NodeColors;
    else
        nodeColors = repmat([0.3, 0.5, 0.8], nCh, 1);
    end
    scatter(ax, nodeX, nodeY, opts.NodeSize, nodeColors, 'filled', ...
        'MarkerEdgeColor', sty.ForegroundColor, 'LineWidth', 0.8);

    % Node labels
    labelOffset = 1.15;
    for i = 1:nCh
        ha = 'center';
        if nodeX(i) > 0.1
            ha = 'left';
        elseif nodeX(i) < -0.1
            ha = 'right';
        end
        text(ax, nodeX(i) * labelOffset, nodeY(i) * labelOffset, ...
            chLabels{i}, 'HorizontalAlignment', ha, 'FontSize', 9);
    end

    if ~isempty(opts.Title)
        title(ax, opts.Title);
    else
        titleStr = sprintf('Chord Diagram (%s, %s)', result.method, result.biomarker);
        if opts.SignificanceMask
            titleStr = sprintf('%s [p < %.2f]', titleStr, opts.PThreshold);
        end
        title(ax, titleStr);
    end

    hold(ax, 'off');
    sty.applyToAxes(ax);

    % Save
    if ~isempty(opts.SavePath)
        pf2_base.plot.handleSave(fig, opts);
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
