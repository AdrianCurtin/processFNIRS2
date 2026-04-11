function fig = plotComposite(groups, panels, varargin)
% PLOTCOMPOSITE Multi-panel publication figure from grouped data
%
% Creates a composite figure with multiple sub-panels arranged in a grid,
% each rendering a different plot type. Panel labels (A, B, C...) are
% automatically added.
%
% Syntax:
%   fig = exploreFNIRS.core.plotComposite(groups, panels)
%   fig = exploreFNIRS.core.plotComposite(groups, panels, 'Layout', [2, 2])
%
% Inputs:
%   groups - Struct array from Experiment.groups (after aggregate())
%   panels - Cell array of panel definition structs. Each struct has:
%            .type - 'temporal', 'bar', 'topo', or 'heatmap'
%            .args - Cell array of name-value args for that plot function
%                    (default: {})
%            .position - [row, col] in the grid (default: auto-assigned)
%
% Name-Value Parameters:
%   Layout      - [nRows, nCols] grid size (default: auto from panels)
%   PanelLabels - 'auto' (A,B,C...), 'none', or cell array of strings
%   Title       - Figure super-title (default: '')
%   Visible     - 'on' (default) or 'off'
%   SavePath    - File path to save figure
%   SaveWidth   - Width in pixels (default: 1200)
%   SaveHeight  - Height in pixels (default: 800)
%   SaveDPI     - Resolution (default: 150)
%
% Outputs:
%   fig - Figure handle
%
% Example:
%   panels = { ...
%       struct('type', 'temporal', 'args', {{'Biomarkers', {'HbO'}}}), ...
%       struct('type', 'bar', 'args', {{'Biomarker', 'HbO'}}) ...
%   };
%   fig = exploreFNIRS.core.plotComposite(ex.groups, panels, ...
%       'Layout', [1, 2], 'SavePath', 'composite.png');
%
% See also: exploreFNIRS.core.plotTemporal, exploreFNIRS.core.plotBar,
%   exploreFNIRS.core.plotTopo, exploreFNIRS.core.plotHeatmap

    ip = inputParser;
    addRequired(ip, 'groups', @isstruct);
    addRequired(ip, 'panels', @iscell);
    addParameter(ip, 'Layout', [], @(v) isempty(v) || (isnumeric(v) && numel(v) == 2));
    addParameter(ip, 'PanelLabels', 'auto', @(v) ischar(v) || iscell(v));
    addParameter(ip, 'Title', '', @ischar);
    addParameter(ip, 'Visible', 'on', @ischar);
    addParameter(ip, 'SavePath', '', @ischar);
    addParameter(ip, 'SaveWidth', 1200, @isnumeric);
    addParameter(ip, 'SaveHeight', 800, @isnumeric);
    addParameter(ip, 'SaveDPI', 150, @isnumeric);
    addParameter(ip, 'TightLayout', false, @islogical);
    parse(ip, groups, panels, varargin{:});
    opts = ip.Results;

    if ~isempty(opts.SavePath)
        opts.Visible = 'off';
    end

    nPanels = length(panels);

    % Determine layout
    if isempty(opts.Layout)
        nCols = ceil(sqrt(nPanels));
        nRows = ceil(nPanels / nCols);
    else
        nRows = opts.Layout(1);
        nCols = opts.Layout(2);
    end

    % Panel labels
    if ischar(opts.PanelLabels) && strcmpi(opts.PanelLabels, 'auto')
        labels = cell(1, nPanels);
        for k = 1:nPanels
            labels{k} = sprintf('(%c)', char('A' + k - 1));
        end
    elseif ischar(opts.PanelLabels) && strcmpi(opts.PanelLabels, 'none')
        labels = {};
    else
        labels = opts.PanelLabels;
    end

    fig = pf2_base.plot.createFigure('Visible', opts.Visible, ...
        'Width', opts.SaveWidth, 'Height', opts.SaveHeight, ...
        'SavePath', opts.SavePath);

    tl = tiledlayout(fig, nRows, nCols, 'TileSpacing', 'compact', ...
        'Padding', 'compact');

    for k = 1:nPanels
        pDef = panels{k};

        % Get position
        if isfield(pDef, 'position') && ~isempty(pDef.position)
            tileIdx = (pDef.position(1) - 1) * nCols + pDef.position(2);
        else
            tileIdx = k;
        end

        ax = nexttile(tl, tileIdx);

        % Get args
        if isfield(pDef, 'args') && ~isempty(pDef.args)
            panelArgs = pDef.args;
        else
            panelArgs = {};
        end

        % Render panel into the axes
        renderPanel(ax, groups, pDef.type, panelArgs);

        sty = pf2_base.plot.PlotStyle.getDefault();

        % Panel label
        if ~isempty(labels) && k <= length(labels)
            text(ax, -0.1, 1.05, labels{k}, 'Units', 'normalized', ...
                'FontSize', 14, 'FontWeight', 'bold', ...
                'Color', sty.ForegroundColor);
        end
        sty.applyToAxes(ax);
    end

    if ~isempty(opts.Title)
        title(tl, pf2_base.plot.escapeTeX(opts.Title));
    end

    pf2_base.plot.handleSave(fig, opts);
end


function renderPanel(ax, groups, panelType, panelArgs)
% Render a single panel type into the given axes

    % Create a temporary invisible figure, plot into it, then copy children
    % to the target axes. This avoids each plot function creating its own fig.
    switch lower(panelType)
        case 'temporal'
            tmpFig = exploreFNIRS.core.plotTemporal(groups, ...
                'Visible', 'off', panelArgs{:});
        case 'bar'
            tmpFig = exploreFNIRS.core.plotBar(groups, ...
                'Visible', 'off', panelArgs{:});
        case 'topo'
            tmpFig = exploreFNIRS.core.plotTopo(groups, ...
                'Visible', 'off', panelArgs{:});
        case 'heatmap'
            tmpFig = exploreFNIRS.core.plotHeatmap(groups, ...
                'Visible', 'off', panelArgs{:});
        otherwise
            warning('exploreFNIRS:core:plotComposite', ...
                'Unknown panel type "%s". Skipping.', panelType);
            return;
    end

    % Copy content from temp figure axes to target axes
    tmpAxes = findobj(tmpFig, 'Type', 'Axes');
    if ~isempty(tmpAxes)
        srcAx = tmpAxes(1);  % use first axes
        children = get(srcAx, 'Children');
        copyobj(children, ax);

        % Copy axis properties
        ax.XLim = srcAx.XLim;
        ax.YLim = srcAx.YLim;
        ax.XLabel.String = srcAx.XLabel.String;
        ax.YLabel.String = srcAx.YLabel.String;
        ax.Title.String = srcAx.Title.String;

        if ~isempty(srcAx.CLim)
            ax.CLim = srcAx.CLim;
        end
    end

    close(tmpFig);
end
