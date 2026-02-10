function fig = plotMatrix(result, varargin)
% PLOTMATRIX Heatmap visualization of a connectivity matrix
%
% Renders a channel-to-channel connectivity matrix as a heatmap with
% optional significance masking and customizable appearance.
%
% Syntax:
%   fig = exploreFNIRS.connectivity.plotMatrix(result)
%   fig = exploreFNIRS.connectivity.plotMatrix(result, 'SignificanceMask', true)
%   fig = exploreFNIRS.connectivity.plotMatrix(result, 'SavePath', 'conn.png')
%
% Inputs:
%   result - Connectivity result struct from computeMatrix, with fields:
%            .matrix, .pmatrix, .channels, .method, .biomarker
%
% Name-Value Parameters:
%   SignificanceMask - Mask non-significant cells (default: false)
%   PThreshold       - Significance threshold for masking (default: 0.05)
%   CLim             - Color limits [cmin cmax] (default: [-1, 1])
%   Colormap         - Colormap name or matrix (default: 'RdBu_r' diverging)
%   ShowValues       - Display r values in cells (default: false)
%   Title            - Figure title (default: auto)
%   Visible          - 'on' (default) or 'off'
%   SavePath         - File path to save figure
%   SaveWidth        - Width in pixels (default: 600)
%   SaveHeight       - Height in pixels (default: 550)
%   SaveDPI          - Resolution (default: 150)
%
% Outputs:
%   fig - Figure handle
%
% See also: exploreFNIRS.connectivity.computeMatrix

    p = inputParser;
    addRequired(p, 'result', @isstruct);
    addParameter(p, 'SignificanceMask', false, @islogical);
    addParameter(p, 'PThreshold', 0.05, @isnumeric);
    addParameter(p, 'CLim', [-1, 1], @(v) isnumeric(v) && length(v) == 2);
    addParameter(p, 'Colormap', '', @(v) ischar(v) || isnumeric(v));
    addParameter(p, 'ShowValues', false, @islogical);
    addParameter(p, 'Title', '', @ischar);
    addParameter(p, 'Visible', 'on', @ischar);
    addParameter(p, 'SavePath', '', @ischar);
    addParameter(p, 'SaveWidth', 600, @isnumeric);
    addParameter(p, 'SaveHeight', 550, @isnumeric);
    addParameter(p, 'SaveDPI', 150, @isnumeric);
    parse(p, result, varargin{:});
    opts = p.Results;
    result = exploreFNIRS.connectivity.normalizeResult(result);

    if ~isempty(opts.SavePath)
        opts.Visible = 'off';
    end

    mat = result.matrix;
    channels = result.channels;
    nCh = length(channels);

    % Apply significance mask
    if opts.SignificanceMask && isfield(result, 'pmatrix')
        nonsig = result.pmatrix > opts.PThreshold;
        mat(nonsig) = 0;
    end

    fig = pf2_base.plot.createFigure('Visible', opts.Visible, ...
        'Width', opts.SaveWidth, 'Height', opts.SaveHeight, ...
        'SavePath', opts.SavePath);
    sty = pf2_base.plot.PlotStyle.getDefault();
    ax = axes('Parent', fig);

    imagesc(ax, mat, opts.CLim);
    axis(ax, 'square');

    % Channel/ROI labels
    if isfield(result, 'labels') && ~isempty(result.labels)
        chLabels = result.labels;
    else
        chLabels = arrayfun(@(c) sprintf('Ch%d', c), channels, 'UniformOutput', false);
    end
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

    % Colormap
    if isempty(opts.Colormap)
        cmap = divergingColormap(256);
    elseif ischar(opts.Colormap)
        cmap = colormap(ax, opts.Colormap);
    else
        cmap = opts.Colormap;
    end
    colormap(ax, cmap);
    cb = colorbar(ax);
    cb.Label.String = result.method;

    % Show values in cells
    if opts.ShowValues && nCh <= 20
        for i = 1:nCh
            for j = 1:nCh
                if ~isnan(mat(i,j)) && i ~= j
                    txt = sprintf('%.2f', mat(i,j));
                    textColor = 'k';
                    if abs(mat(i,j)) > 0.7
                        textColor = 'w';
                    end
                    text(ax, j, i, txt, 'HorizontalAlignment', 'center', ...
                        'FontSize', sty.LegendFontSize - 2, 'Color', textColor);
                end
            end
        end
    end

    % Title
    if ~isempty(opts.Title)
        title(ax, opts.Title);
    else
        titleStr = sprintf('Connectivity (%s, %s)', result.method, result.biomarker);
        if opts.SignificanceMask
            titleStr = sprintf('%s [p < %.2f]', titleStr, opts.PThreshold);
        end
        title(ax, titleStr);
    end

    if isfield(result, 'useROI') && result.useROI
        xlabel(ax, 'ROI');
        ylabel(ax, 'ROI');
    else
        xlabel(ax, 'Channel');
        ylabel(ax, 'Channel');
    end

    sty.applyToAxes(ax);

    pf2_base.plot.handleSave(fig, opts);
end


function cmap = divergingColormap(n)
% Blue-white-red diverging colormap
    half = floor(n / 2);

    % Blue to white
    r1 = linspace(0.2, 1, half)';
    g1 = linspace(0.3, 1, half)';
    b1 = linspace(0.8, 1, half)';

    % White to red
    r2 = linspace(1, 0.8, n - half)';
    g2 = linspace(1, 0.2, n - half)';
    b2 = linspace(1, 0.2, n - half)';

    cmap = [r1 g1 b1; r2 g2 b2];
end
