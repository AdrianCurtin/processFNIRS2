function fig = plotDyadMatrix(result, varargin)
% PLOTDYADMATRIX Dyad-level coupling heatmap
%
% Displays a heatmap with channels on the Y-axis and dyads on the X-axis.
% Each column shows one dyad's coupling values, providing an overview of
% inter-subject variability across dyads and channels.
%
% Syntax:
%   fig = exploreFNIRS.hyperscanning.plotDyadMatrix(result)
%   fig = exploreFNIRS.hyperscanning.plotDyadMatrix(result, 'SortDyads', 'mean')
%   fig = exploreFNIRS.hyperscanning.plotDyadMatrix(result, 'CLim', [-0.5, 0.5])
%
% Inputs:
%   result - Struct from computeGroup with fields:
%            .dyads     - Cell array of dyad result structs, each with .values
%            .channels  - Channel indices
%            .method, .biomarker
%
% Name-Value Parameters:
%   SortDyads    - Sort dyad columns: 'none' (default) or 'mean' (by mean coupling)
%   SortChannels - Sort channel rows: 'index' (default) or 'mean' (by mean coupling)
%   CLim         - Color limits [cmin cmax] (default: [-1, 1])
%   Colormap     - Colormap name or matrix (default: diverging blue-white-red)
%   Title        - Figure title (default: auto)
%   Visible      - 'on' (default) or 'off'
%   SavePath     - File path to save figure
%   SaveWidth    - Width in pixels (default: 700)
%   SaveHeight   - Height in pixels (default: 500)
%   SaveDPI      - Resolution (default: 150)
%
% Outputs:
%   fig - Figure handle
%
% See also: exploreFNIRS.hyperscanning.computeGroup,
%   exploreFNIRS.hyperscanning.plotGroup

    p = inputParser;
    addRequired(p, 'result', @isstruct);
    addParameter(p, 'SortDyads', 'none', @ischar);
    addParameter(p, 'SortChannels', 'index', @ischar);
    addParameter(p, 'CLim', [-1, 1], @(v) isnumeric(v) && length(v) == 2);
    addParameter(p, 'Colormap', '', @(v) ischar(v) || isnumeric(v));
    addParameter(p, 'Title', '', @ischar);
    addParameter(p, 'Visible', 'on', @ischar);
    addParameter(p, 'SavePath', '', @ischar);
    addParameter(p, 'SaveWidth', 700, @isnumeric);
    addParameter(p, 'SaveHeight', 500, @isnumeric);
    addParameter(p, 'SaveDPI', 150, @isnumeric);
    addParameter(p, 'TightLayout', false, @islogical);
    parse(p, result, varargin{:});
    opts = p.Results;

    if ~isempty(opts.SavePath)
        opts.Visible = 'off';
    end

    % Validate input
    if ~isfield(result, 'dyads') || isempty(result.dyads)
        error('exploreFNIRS:hyperscanning:plotDyadMatrix', ...
            'Result must have .dyads cell array from computeGroup.');
    end

    nDyads = length(result.dyads);

    % Determine number of channels from first dyad
    firstDyad = result.dyads{1};
    nCh = length(firstDyad.values(:));

    % Build [nCh x nDyads] matrix
    mat = zeros(nCh, nDyads);
    for d = 1:nDyads
        vals = result.dyads{d}.values(:);
        if length(vals) == nCh
            mat(:, d) = vals;
        else
            % Pad or truncate to match
            n = min(nCh, length(vals));
            mat(1:n, d) = vals(1:n);
        end
    end

    % Channel labels
    if isfield(result, 'channels')
        channels = result.channels(:)';
        chLabels = arrayfun(@(c) sprintf('Ch%d', c), channels, ...
            'UniformOutput', false);
    else
        chLabels = arrayfun(@(c) sprintf('Ch%d', c), 1:nCh, ...
            'UniformOutput', false);
    end

    % Dyad labels
    dyadLabels = cell(1, nDyads);
    for d = 1:nDyads
        dyadLabels{d} = sprintf('D%d', d);
    end

    % Sort dyads by mean coupling if requested
    dyadOrder = 1:nDyads;
    if strcmpi(opts.SortDyads, 'mean')
        dyadMeans = mean(mat, 1, 'omitnan');
        [~, dyadOrder] = sort(dyadMeans, 'descend');
        mat = mat(:, dyadOrder);
        dyadLabels = dyadLabels(dyadOrder);
    end

    % Sort channels by mean coupling if requested
    chOrder = 1:nCh;
    if strcmpi(opts.SortChannels, 'mean')
        chMeans = mean(mat, 2, 'omitnan');
        [~, chOrder] = sort(chMeans, 'descend');
        mat = mat(chOrder, :);
        chLabels = chLabels(chOrder);
    end

    % Create figure
    fig = pf2_base.plot.createFigure('Visible', opts.Visible, ...
        'SavePath', opts.SavePath, 'Width', opts.SaveWidth, ...
        'Height', opts.SaveHeight);
    ax = axes('Parent', fig);

    imagesc(ax, mat, opts.CLim);

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
    if isfield(result, 'method')
        cb.Label.String = result.method;
    else
        cb.Label.String = 'Coupling';
    end

    % Axis labels
    set(ax, 'XTick', 1:nDyads, 'XTickLabel', pf2_base.plot.escapeTeX(dyadLabels), 'XTickLabelRotation', 45);
    set(ax, 'YTick', 1:nCh, 'YTickLabel', pf2_base.plot.escapeTeX(chLabels));

    % Reduce label density for large matrices
    if nDyads > 20
        tickStep = ceil(nDyads / 20);
        ticks = 1:tickStep:nDyads;
        set(ax, 'XTick', ticks, 'XTickLabel', pf2_base.plot.escapeTeX(dyadLabels(ticks)));
    end
    if nCh > 20
        tickStep = ceil(nCh / 20);
        ticks = 1:tickStep:nCh;
        set(ax, 'YTick', ticks, 'YTickLabel', pf2_base.plot.escapeTeX(chLabels(ticks)));
    end

    xlabel(ax, 'Dyad');
    ylabel(ax, 'Channel');

    % Title
    if ~isempty(opts.Title)
        title(ax, pf2_base.plot.escapeTeX(opts.Title));
    else
        methodStr = '';
        bioStr = '';
        if isfield(result, 'method')
            methodStr = result.method;
        end
        if isfield(result, 'biomarker')
            bioStr = result.biomarker;
        end
        title(ax, pf2_base.plot.escapeTeX(sprintf('Dyad Coupling (%s, %s, N=%d)', methodStr, bioStr, nDyads)));
    end

    % Apply style
    sty = pf2_base.plot.PlotStyle.getDefault();
    sty.applyToAxes(ax);

    % Save
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
