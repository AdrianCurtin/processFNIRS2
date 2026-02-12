function fig = plotTopo(groups, varargin)
% PLOTTOPO Group-level 2D topographic maps of biomarker amplitude
%
% Creates topographic headplots showing spatial distribution of mean
% biomarker values across channels for each group. Supports time-point
% snapshots and time-window averages.
%
% Syntax:
%   fig = exploreFNIRS.core.plotTopo(groups)
%   fig = exploreFNIRS.core.plotTopo(groups, 'Time', 10)
%   fig = exploreFNIRS.core.plotTopo(groups, 'TimeWindow', [5, 15])
%   fig = exploreFNIRS.core.plotTopo(groups, 'Layout', 'pergroup')
%
% Inputs:
%   groups - Struct array from Experiment.groups (after aggregate())
%
% Name-Value Parameters:
%   Biomarker     - Biomarker to plot (default: 'HbO')
%   Time          - Single time point for snapshot (default: [])
%   TimeWindow    - [start, end] seconds to average over (default: full)
%   Colormap      - Colormap name or matrix (default: 'jet')
%   CLim          - Color limits [cmin cmax] (default: auto)
%   Layout        - 'single' (average groups) or 'pergroup' (side-by-side)
%   Interpolation - 'none' (default) or 'natural'
%   Title         - Figure title (default: auto)
%   Visible       - 'on' (default) or 'off'
%   SavePath      - File path to save figure
%   SaveWidth     - Width in pixels (default: 600)
%   SaveHeight    - Height in pixels (default: 500)
%   SaveDPI       - Resolution (default: 150)
%
% Outputs:
%   fig - Figure handle
%
% See also: exploreFNIRS.core.plotTemporal, exploreFNIRS.core.plotBar

    p = inputParser;
    addRequired(p, 'groups', @isstruct);
    addParameter(p, 'Biomarker', 'HbO', @ischar);
    addParameter(p, 'Time', [], @(v) isempty(v) || (isnumeric(v) && isscalar(v)));
    addParameter(p, 'TimeWindow', [], @(v) isempty(v) || (isnumeric(v) && numel(v) == 2));
    addParameter(p, 'Colormap', 'jet', @(v) ischar(v) || isnumeric(v));
    addParameter(p, 'CLim', [], @(v) isempty(v) || (isnumeric(v) && numel(v) == 2));
    addParameter(p, 'Layout', 'single', @ischar);
    addParameter(p, 'Interpolation', 'none', @ischar);
    addParameter(p, 'Title', '', @ischar);
    addParameter(p, 'Visible', 'on', @ischar);
    addParameter(p, 'SavePath', '', @ischar);
    addParameter(p, 'SaveWidth', 600, @isnumeric);
    addParameter(p, 'SaveHeight', 500, @isnumeric);
    addParameter(p, 'SaveDPI', 150, @isnumeric);
    parse(p, groups, varargin{:});
    opts = p.Results;

    if ~isempty(opts.SavePath)
        opts.Visible = 'off';
    end

    bioM = opts.Biomarker;
    nGroups = length(groups);

    % Validate
    for g = 1:nGroups
        if isempty(groups(g).gbyGrand)
            error('exploreFNIRS:core:plotTopo', ...
                'Group %d has no grand average. Call aggregate() first.', g);
        end
    end

    % Determine layout
    if strcmpi(opts.Layout, 'pergroup') && nGroups > 1
        nPanels = nGroups;
        figW = opts.SaveWidth * min(nPanels, 4);
    else
        nPanels = 1;
        figW = opts.SaveWidth;
    end

    fig = pf2_base.plot.createFigure('Visible', opts.Visible, ...
        'Width', figW, 'Height', opts.SaveHeight, 'SavePath', opts.SavePath);

    % Extract channel values per group
    groupValues = cell(1, nGroups);
    for g = 1:nGroups
        ga = groups(g).gbyGrand;
        if ~isfield(ga, bioM) || isempty(ga.(bioM))
            continue;
        end

        timeVec = ga.time;
        meanData = ga.(bioM).Mean;  % [T x C]

        % Time selection
        if ~isempty(opts.Time)
            [~, tIdx] = min(abs(timeVec - opts.Time));
            vals = meanData(tIdx, :);
        elseif ~isempty(opts.TimeWindow)
            tMask = timeVec >= opts.TimeWindow(1) & timeVec <= opts.TimeWindow(2);
            vals = mean(meanData(tMask, :), 1, 'omitnan');
        else
            vals = mean(meanData, 1, 'omitnan');
        end

        groupValues{g} = vals(:)';
    end

    % Determine CLim
    if isempty(opts.CLim)
        allVals = cell2mat(groupValues(~cellfun(@isempty, groupValues)));
        if ~isempty(allVals)
            maxAbs = max(abs(allVals(:)));
            if maxAbs > 0
                cLim = [-maxAbs, maxAbs];
            else
                cLim = [-1, 1];
            end
        else
            cLim = [-1, 1];
        end
    else
        cLim = opts.CLim;
    end

    % Plot
    if nPanels == 1
        % Average across groups or single group
        validVals = groupValues(~cellfun(@isempty, groupValues));
        if isempty(validVals)
            return;
        end
        allMat = cell2mat(validVals');
        avgVals = mean(allMat, 1, 'omitnan');

        ax = axes('Parent', fig);
        plotTopoOnAxes(ax, avgVals, opts, cLim);

        sty = pf2_base.plot.PlotStyle.getDefault();
        sty.applyToAxes(ax);
    else
        % Per-group panels
        for g = 1:nPanels
            ax = subplot(1, nPanels, g, 'Parent', fig);
            if ~isempty(groupValues{g})
                plotTopoOnAxes(ax, groupValues{g}, opts, cLim);
            end
            title(ax, pf2_base.plot.escapeTeX(groups(g).label), 'FontSize', 11);

            sty = pf2_base.plot.PlotStyle.getDefault();
            sty.applyToAxes(ax);
        end
    end

    % Title
    if ~isempty(opts.Title)
        pf2_base.external.suptitle(fig, opts.Title);
    else
        tStr = bioM;
        if ~isempty(opts.Time)
            tStr = sprintf('%s at t=%.1fs', tStr, opts.Time);
        elseif ~isempty(opts.TimeWindow)
            tStr = sprintf('%s [%.1f-%.1f]s', tStr, opts.TimeWindow(1), opts.TimeWindow(2));
        end
        pf2_base.external.suptitle(fig, tStr);
    end

    pf2_base.plot.handleSave(fig, opts);
end


function plotTopoOnAxes(ax, vals, opts, cLim)
% Plot topographic map on a single axes
    nCh = length(vals);

    % Generate channel positions in a grid layout
    nCols = ceil(sqrt(nCh));
    nRows = ceil(nCh / nCols);
    xPos = zeros(1, nCh);
    yPos = zeros(1, nCh);
    for c = 1:nCh
        row = ceil(c / nCols);
        col = mod(c - 1, nCols) + 1;
        xPos(c) = col;
        yPos(c) = nRows - row + 1;
    end

    if strcmpi(opts.Interpolation, 'natural') && nCh > 3
        % Interpolated surface
        xq = linspace(min(xPos) - 0.5, max(xPos) + 0.5, 50);
        yq = linspace(min(yPos) - 0.5, max(yPos) + 0.5, 50);
        [XQ, YQ] = meshgrid(xq, yq);

        F = scatteredInterpolant(xPos(:), yPos(:), vals(:), 'natural', 'none');
        ZQ = F(XQ, YQ);

        imagesc(ax, xq, yq, ZQ, cLim);
        set(ax, 'YDir', 'normal');
        hold(ax, 'on');
        % Channel markers
        scatter(ax, xPos, yPos, 30, vals, 'filled', 'MarkerEdgeColor', 'k');
        hold(ax, 'off');
    else
        % Discrete circles per channel
        hold(ax, 'on');
        scatter(ax, xPos, yPos, 200, vals, 'filled', 'MarkerEdgeColor', 'k');

        % Channel labels
        for c = 1:nCh
            text(ax, xPos(c), yPos(c), sprintf('%d', c), ...
                'HorizontalAlignment', 'center', 'FontSize', 7, 'Color', 'w');
        end
        hold(ax, 'off');
        set(ax, 'CLim', cLim);
    end

    axis(ax, 'equal');
    xlim(ax, [min(xPos) - 1, max(xPos) + 1]);
    ylim(ax, [min(yPos) - 1, max(yPos) + 1]);
    set(ax, 'XTick', [], 'YTick', []);

    if ischar(opts.Colormap)
        cmapFn = exploreFNIRS.helper.getColormap(opts.Colormap);
        colormap(ax, cmapFn(256));
    else
        colormap(ax, opts.Colormap);
    end
    colorbar(ax);
end
