function fig = plotInterBrainTopo(result, varargin)
% PLOTINTERBRAINTOPO Dual-brain topographic display with inter-brain coupling
%
% Shows two probe layouts (Subject A, Subject B) side-by-side with colored
% lines connecting coupled channel pairs. Line color encodes coupling
% strength and line width is proportional to absolute coupling value.
%
% Syntax:
%   fig = exploreFNIRS.hyperscanning.plotInterBrainTopo(result)
%   fig = exploreFNIRS.hyperscanning.plotInterBrainTopo(result, 'LineThreshold', 0.5)
%   fig = exploreFNIRS.hyperscanning.plotInterBrainTopo(result, 'BrainLabels', {'Speaker','Listener'})
%
% Inputs:
%   result - Struct from computeGroup or computeDyad with fields:
%            .Mean or .values  - [nCh x 1] coupling values (same-channel pairing)
%            .channels or .channelsA/.channelsB - channel indices
%            .method, .biomarker
%
% Name-Value Parameters:
%   LineThreshold - Minimum absolute coupling to draw a line (default: 0.3)
%   BrainLabels   - Cell array of two labels (default: {'Subject A','Subject B'})
%   CLim          - Color limits [cmin cmax] for coupling lines (default: auto)
%   Colormap      - Colormap name or matrix for lines (default: 'hot')
%   Title         - Figure title (default: auto)
%   Visible       - 'on' (default) or 'off'
%   SavePath      - File path to save figure
%   SaveWidth     - Width in pixels (default: 800)
%   SaveHeight    - Height in pixels (default: 500)
%   SaveDPI       - Resolution (default: 150)
%
% Outputs:
%   fig - Figure handle
%
% See also: exploreFNIRS.hyperscanning.computeGroup,
%   exploreFNIRS.hyperscanning.computeDyad

    p = inputParser;
    addRequired(p, 'result', @isstruct);
    addParameter(p, 'LineThreshold', 0.3, @isnumeric);
    addParameter(p, 'BrainLabels', {'Subject A', 'Subject B'}, @iscell);
    addParameter(p, 'CLim', [], @(v) isempty(v) || (isnumeric(v) && length(v) == 2));
    addParameter(p, 'Colormap', 'hot', @(v) ischar(v) || isnumeric(v));
    addParameter(p, 'Title', '', @ischar);
    addParameter(p, 'Visible', 'on', @ischar);
    addParameter(p, 'SavePath', '', @ischar);
    addParameter(p, 'SaveWidth', 800, @isnumeric);
    addParameter(p, 'SaveHeight', 500, @isnumeric);
    addParameter(p, 'SaveDPI', 150, @isnumeric);
    addParameter(p, 'TightLayout', false, @islogical);
    parse(p, result, varargin{:});
    opts = p.Results;

    if ~isempty(opts.SavePath)
        opts.Visible = 'off';
    end

    % Extract coupling values
    if isfield(result, 'Mean')
        couplingVals = result.Mean(:);
    elseif isfield(result, 'values')
        couplingVals = result.values(:);
    else
        error('exploreFNIRS:hyperscanning:plotInterBrainTopo', ...
            'Result must have .Mean or .values field.');
    end

    nCh = length(couplingVals);

    % Extract channel indices
    if isfield(result, 'channelsA')
        channelsA = result.channelsA(:)';
        channelsB = result.channelsB(:)';
    elseif isfield(result, 'channels')
        channelsA = result.channels(:)';
        channelsB = result.channels(:)';
    else
        channelsA = 1:nCh;
        channelsB = 1:nCh;
    end

    % Generate grid positions for channel nodes
    nCols = ceil(sqrt(nCh));
    nRows = ceil(nCh / nCols);

    % Compute node positions in grid
    xA = zeros(nCh, 1);
    yA = zeros(nCh, 1);
    xB = zeros(nCh, 1);
    yB = zeros(nCh, 1);

    xOffset = nCols + 2;  % gap between left and right brain

    for ch = 1:nCh
        row = ceil(ch / nCols);
        col = ch - (row - 1) * nCols;
        xA(ch) = col;
        yA(ch) = nRows - row + 1;
        xB(ch) = col + xOffset;
        yB(ch) = nRows - row + 1;
    end

    % Determine color limits
    if isempty(opts.CLim)
        absMax = max(abs(couplingVals));
        if absMax == 0
            absMax = 1;
        end
        cLim = [0, absMax];
    else
        cLim = opts.CLim;
    end

    % Build colormap
    if ischar(opts.Colormap)
        cmapFunc = str2func(opts.Colormap);
        cmap = cmapFunc(256);
    else
        cmap = opts.Colormap;
    end
    nColors = size(cmap, 1);

    % Create figure
    fig = pf2_base.plot.createFigure('Visible', opts.Visible, ...
        'SavePath', opts.SavePath, 'Width', opts.SaveWidth, ...
        'Height', opts.SaveHeight);
    ax = axes('Parent', fig);
    hold(ax, 'on');

    % Draw coupling lines between brains
    maxLineWidth = 4;
    minLineWidth = 0.5;

    for ch = 1:nCh
        val = couplingVals(ch);
        if abs(val) < opts.LineThreshold
            continue;
        end

        % Map value to colormap index
        normVal = (abs(val) - cLim(1)) / (cLim(2) - cLim(1));
        normVal = max(0, min(1, normVal));
        colorIdx = max(1, round(normVal * (nColors - 1)) + 1);
        lineColor = cmap(colorIdx, :);

        % Line width proportional to absolute coupling
        lineWidth = minLineWidth + (maxLineWidth - minLineWidth) * normVal;

        plot(ax, [xA(ch), xB(ch)], [yA(ch), yB(ch)], '-', ...
            'Color', [lineColor, 0.6], 'LineWidth', lineWidth);
    end

    % Draw channel nodes - Subject A (left brain)
    nodeSize = 60;
    scatter(ax, xA, yA, nodeSize, [0.3, 0.5, 0.8], 'filled', ...
        'MarkerEdgeColor', 'k', 'LineWidth', 0.5);
    for ch = 1:nCh
        text(ax, xA(ch), yA(ch), sprintf('%d', channelsA(ch)), ...
            'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', ...
            'FontSize', 7, 'Color', 'w', 'FontWeight', 'bold');
    end

    % Draw channel nodes - Subject B (right brain)
    scatter(ax, xB, yB, nodeSize, [0.8, 0.3, 0.3], 'filled', ...
        'MarkerEdgeColor', 'k', 'LineWidth', 0.5);
    for ch = 1:nCh
        text(ax, xB(ch), yB(ch), sprintf('%d', channelsB(ch)), ...
            'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', ...
            'FontSize', 7, 'Color', 'w', 'FontWeight', 'bold');
    end

    % Brain labels
    labels = opts.BrainLabels;
    text(ax, mean(xA), max(yA) + 0.8, labels{1}, ...
        'HorizontalAlignment', 'center', 'FontSize', 12, 'FontWeight', 'bold');
    text(ax, mean(xB), max(yB) + 0.8, labels{2}, ...
        'HorizontalAlignment', 'center', 'FontSize', 12, 'FontWeight', 'bold');

    hold(ax, 'off');

    % Colorbar
    colormap(ax, cmap);
    clim(ax, cLim);
    cb = colorbar(ax);
    if isfield(result, 'method')
        cb.Label.String = result.method;
    else
        cb.Label.String = 'Coupling';
    end

    % Title
    if ~isempty(opts.Title)
        title(ax, opts.Title);
    else
        methodStr = 'coupling';
        bioStr = '';
        if isfield(result, 'method')
            methodStr = result.method;
        end
        if isfield(result, 'biomarker')
            bioStr = sprintf(', %s', result.biomarker);
        end
        title(ax, sprintf('Inter-Brain Coupling (%s%s)', methodStr, bioStr));
    end

    % Clean up axes
    axis(ax, 'equal');
    set(ax, 'XTick', [], 'YTick', []);
    xlim(ax, [min(xA) - 1, max(xB) + 1]);
    ylim(ax, [min(yA) - 1, max(yA) + 1.5]);
    box(ax, 'off');

    % Apply style
    sty = pf2_base.plot.PlotStyle.getDefault();
    sty.applyToAxes(ax);

    % Save
    pf2_base.plot.handleSave(fig, opts);

end
