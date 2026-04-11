function fig = plotBar(groups, varargin)
% PLOTBAR Headless bar chart from grouped/aggregated experiment data
%
% Creates bar charts showing mean biomarker values per group for each
% channel, with error bars. Each channel gets its own subplot — channels
% are never averaged. Groups are shown as separate bars within each subplot.
%
% Syntax:
%   fig = plotBar(groups)
%   fig = plotBar(groups, 'Biomarker', 'HbO', 'Channels', 1:5)
%   fig = plotBar(groups, 'ROIs', 'all', 'Biomarker', 'HbO')
%   fig = plotBar(groups, 'SavePath', 'barchart.png')
%
% Inputs:
%   groups - Struct array from Experiment.groups (after aggregate())
%            Each element must have .gbyGrand with .HbO, .HbR, etc.
%
% Name-Value Parameters:
%   Biomarker   - Single biomarker name (default: 'HbO')
%   Channels    - Vector of channel indices (default: all channels)
%   ROIs        - ROI indices, names, or 'all' (default: [])
%                 When provided, data is read from gbyGrand.ROI instead of
%                 gbyGrand. Mutually exclusive with Channels.
%   TimeWindow  - [start, end] in seconds to average over (default: full range)
%   ErrorType   - 'SEM' (default), 'SD', or 'none'
%   ShowIndividual - Show individual data points (default: false)
%   ShowN       - Show subject count (n=X) above bars (default: true)
%   Legend      - 'last' (default), 'first', 'all', or 'none'
%                 Controls which subplot(s) show the legend.
%   YLim        - [min max] y-axis limits (default: auto, shared across subplots)
%   XLim        - [min max] x-axis limits (default: auto, shared across subplots)
%   PlotBy      - Groupby variable to use as series in clustered bars
%                 (e.g., 'Condition'). Creates grouped bar chart instead
%                 of flat bars. The PlotBy factor becomes the legend,
%                 remaining factors become X-axis categories.
%   Title       - Figure title (default: auto)
%   Visible     - 'on' (default) or 'off'
%   SavePath    - File path to save figure
%   SaveWidth   - Width in pixels (default: 600)
%   SaveHeight  - Height in pixels (default: 400)
%   SaveDPI     - Resolution (default: 150)
%   Colors      - Group color palette override (default: [] = auto)
%                 [N x 3] RGB matrix, colormap name (e.g. 'Set1', 'tab10'),
%                 or function handle @(N) returning [N x 3].
%
% Outputs:
%   fig - Figure handle
%
% Example:
%   ex = exploreFNIRS.core.Experiment(data);
%   ex.groupby({'Group','Condition'});
%   ex.aggregate();
%
%   % Bar chart for HbO, channels 1-5, averaged over 5-20s
%   fig = exploreFNIRS.core.plotBar(ex.groups, ...
%       'Biomarker', 'HbO', 'Channels', 1:5, ...
%       'TimeWindow', [5, 20], 'SavePath', 'bar.png');
%
% See also: exploreFNIRS.core.Experiment, exploreFNIRS.core.plotTemporal

    p = inputParser;
    addRequired(p, 'groups', @isstruct);
    addParameter(p, 'Biomarker', 'HbO', @ischar);
    addParameter(p, 'Channels', [], @isnumeric);
    addParameter(p, 'ROIs', [], @(x) isnumeric(x) || islogical(x) || ischar(x) || isstring(x) || iscell(x));
    addParameter(p, 'Device', [], @(v) isempty(v) || isa(v, 'pf2.Device'));
    addParameter(p, 'ExcludeShortSeparation', true, @islogical);
    addParameter(p, 'TimeWindow', [], @isnumeric);
    addParameter(p, 'StatWindow', [], @isnumeric);
    addParameter(p, 'ErrorType', 'SEM', @ischar);
    addParameter(p, 'ShowIndividual', false, @islogical);
    addParameter(p, 'ShowN', true, @islogical);
    addParameter(p, 'Legend', 'last', @ischar);
    addParameter(p, 'YLim', [], @isnumeric);
    addParameter(p, 'XLim', [], @isnumeric);
    addParameter(p, 'PlotBy', '', @ischar);
    addParameter(p, 'GroupByVars', {}, @iscell);
    addParameter(p, 'Title', '', @ischar);
    addParameter(p, 'Visible', 'on', @ischar);
    addParameter(p, 'SavePath', '', @ischar);
    addParameter(p, 'SaveWidth', 600, @isnumeric);
    addParameter(p, 'SaveHeight', 400, @isnumeric);
    addParameter(p, 'SaveDPI', 150, @isnumeric);
    addParameter(p, 'TightLayout', false, @islogical);
    addParameter(p, 'Colors', [], @(x) isempty(x) || isnumeric(x) || ischar(x) || isstring(x) || isa(x, 'function_handle') || isa(x, 'exploreFNIRS.core.ColorScheme'));
    parse(p, groups, varargin{:});
    opts = p.Results;

    % StatWindow is an alias for TimeWindow (for API consistency)
    if isempty(opts.TimeWindow) && ~isempty(opts.StatWindow)
        opts.TimeWindow = opts.StatWindow;
    end

    if ~isempty(opts.SavePath)
        opts.Visible = 'off';
    end

    bioM = opts.Biomarker;
    nGroups = length(groups);

    % Validate
    for g = 1:nGroups
        if isempty(groups(g).gbyGrand)
            error('exploreFNIRS:core:plotBar', ...
                'Group %d has no grand average. Call aggregate() first.', g);
        end
    end

    % Auto-expand groups by time bins when multiple bars exist
    if ~isempty(groups(1).gbyGrandBarFlat) && ...
            length(groups(1).gbyGrandBarFlat.time) > 1
        groups = exploreFNIRS.core.expandGroupsByTime(groups);
        nGroups = length(groups);
    end

    % Resolve channels/ROIs (default = all)
    if ~isempty(opts.ROIs)
        if ~isempty(opts.Channels)
            error('exploreFNIRS:core:plotBar', ...
                'ROIs and Channels are mutually exclusive.');
        end
        if ~isfield(groups(1).gbyGrand, 'ROI')
            error('exploreFNIRS:core:plotBar', ...
                'No ROI data in grand average. Define ROIs before aggregating.');
        end
        [roiIdx, roiNames] = resolveROIs(groups, opts.ROIs);
        plotItems = roiIdx;
        itemNames = roiNames;
        useROI = true;
    else
        useROI = false;
        if isempty(opts.Channels)
            nTotalCh = size(groups(1).gbyGrand.(bioM).Mean, 2);
            plotItems = 1:nTotalCh;
        else
            plotItems = opts.Channels;
        end
        % Exclude short-separation channels
        if opts.ExcludeShortSeparation
            ssIdx = getShortSeparationIdx(opts.Device, groups);
            if ~isempty(ssIdx)
                plotItems = plotItems(~ismember(plotItems, ssIdx));
            end
        end
        itemNames = arrayfun(@(c) sprintf('Ch %d', c), plotItems, ...
            'UniformOutput', false);
    end
    nItems = length(plotItems);

    % PlotBy setup
    hasPB = ~isempty(opts.PlotBy);
    if hasPB
        [plotByValues, ~, withinLabels, plotByIdx] = ...
            exploreFNIRS.core.splitGroupsByFactor(groups, opts.PlotBy);
    end

    % Layout: prefer columns (bar subplots are taller than wide)
    nCols = ceil(sqrt(nItems));
    nRows = ceil(nItems / nCols);

    figW = opts.SaveWidth * min(nCols, 5);
    figH = opts.SaveHeight * max(nRows, 1);

    fig = pf2_base.plot.createFigure('Visible', opts.Visible, ...
        'Width', figW, 'Height', figH, 'SavePath', opts.SavePath);
    sty = pf2_base.plot.PlotStyle.getDefault();

    allAxes = gobjects(nItems, 1);

    for chI = 1:nItems
        ax = subplot(nRows, nCols, chI, 'Parent', fig);
        hold(ax, 'on');
        allAxes(chI) = ax;

        ch = plotItems(chI);

        % Compute per-group means/errors for this channel
        [groupMeans, groupErrors, groupN, groupLabels, individualData] = ...
            computeChannelStats(groups, bioM, ch, opts, useROI);

        if hasPB
            % --- Clustered bar chart (barweb) ---
            nSeries = length(plotByValues);
            uniqueWithin = unique(withinLabels, 'stable');
            nX = length(uniqueWithin);

            meanMatrix = nan(nX, nSeries);
            errorMatrix = nan(nX, nSeries);
            indivData = cell(nX, nSeries);

            for g = 1:nGroups
                si = plotByIdx(g);
                xi = find(strcmp(uniqueWithin, withinLabels{g}), 1);
                meanMatrix(xi, si) = groupMeans(g);
                errorMatrix(xi, si) = groupErrors(g);
                indivData{xi, si} = individualData{g};
            end

            if isa(opts.Colors, 'exploreFNIRS.core.ColorScheme')
                seriesColors = opts.Colors.resolve(groups);
                % Remap to series-level: take one color per unique series value
                seriesColors = seriesColors(1:nSeries, :);
            else
                seriesColors = exploreFNIRS.core.getGroupColors(nSeries, opts.Colors);
            end

            if strcmpi(opts.ErrorType, 'none')
                errInput = [];
            else
                errInput = errorMatrix;
            end

            barwebArgs = {'Axes', ax, ...
                'ColorMap', seriesColors, ...
                'ErrorColor', sty.ForegroundColor, ...
                'YLabel', sprintf('%s (%s)', bioM, getUnitsLabel(groups(1)))};

            if showLegend(opts.Legend, chI, nItems) && ~strcmpi(opts.Legend, 'none')
                barwebArgs = [barwebArgs, {'Legend', pf2_base.plot.escapeTeX(plotByValues)}];
            end

            if opts.ShowIndividual
                barwebArgs = [barwebArgs, {'DataPoints', indivData}];
            end

            bwHandles = pf2_base.external.barweb(meanMatrix, errInput, 1, pf2_base.plot.escapeTeX(uniqueWithin), ...
                barwebArgs{:});
            hold(ax, 'on');

            % Style legend if barweb created one
            if ~isempty(bwHandles.legend) && isvalid(bwHandles.legend)
                bwHandles.legend.TextColor = sty.LegendTextColor;
                bwHandles.legend.Color = sty.LegendBgColor;
                bwHandles.legend.EdgeColor = sty.LegendEdgeColor;
                bwHandles.legend.Box = 'on';
            end

            % X-axis label: within factor name(s) — bottom row only
            isBottomRow = ceil(chI / nCols) == nRows;
            if isBottomRow && ~isempty(opts.GroupByVars)
                withinVars = setdiff(opts.GroupByVars, {opts.PlotBy}, 'stable');
                if ~isempty(withinVars)
                    xlabel(ax, pf2_base.plot.escapeTeX(strjoin(withinVars, ' x ')));
                end
            end

        else
            % --- Standard flat bar chart (via barweb) ---
            if isa(opts.Colors, 'exploreFNIRS.core.ColorScheme')
                colors = opts.Colors.resolve(groups);
            else
                colors = exploreFNIRS.core.getGroupColors(nGroups, opts.Colors);
            end

            meanMatrix = groupMeans(:);   % [nGroups x 1] — each group is X category
            if strcmpi(opts.ErrorType, 'none')
                errInput = [];
            else
                errInput = groupErrors(:);
            end

            indivData = cell(nGroups, 1);
            for g = 1:nGroups
                indivData{g, 1} = individualData{g};
            end

            barwebArgs = {'Axes', ax, ...
                'ColorMap', colors(1,:), ...
                'ErrorColor', sty.ForegroundColor, ...
                'YLabel', sprintf('%s (%s)', bioM, getUnitsLabel(groups(1)))};

            if opts.ShowIndividual
                barwebArgs = [barwebArgs, {'DataPoints', indivData}];
            end

            bwHandles = pf2_base.external.barweb(meanMatrix, errInput, 1, pf2_base.plot.escapeTeX(groupLabels), ...
                barwebArgs{:});
            hold(ax, 'on');

            % Color each bar individually (single series = single color by default)
            if ~isempty(bwHandles.bars)
                bwHandles.bars(1).FaceColor = 'flat';
                bwHandles.bars(1).CData = colors(1:nGroups, :);
            end

            % Add x-axis margin so bars don't touch the edges
            xlim(ax, [0.25, nGroups + 0.75]);

            % Legend identifies bars, so replace tick labels with xlabel
            % Only show xlabel on bottom row to avoid overlapping with row below
            isBottomRow = ceil(chI / nCols) == nRows;
            if ~isempty(opts.GroupByVars)
                set(ax, 'XTickLabel', {});
                if isBottomRow
                    xlabel(ax, pf2_base.plot.escapeTeX(strjoin(opts.GroupByVars, ' x ')));
                end
            end

            % Legend with colored patches (always show on designated subplot)
            if showLegend(opts.Legend, chI, nItems)
                lh = gobjects(nGroups, 1);
                for g = 1:nGroups
                    lh(g) = patch(ax, NaN, NaN, colors(g,:), ...
                        'EdgeColor', sty.ForegroundColor, 'LineWidth', 2);
                end
                lg = legend(ax, lh, pf2_base.plot.escapeTeX(groupLabels), 'Location', 'best');
                lg.TextColor = sty.LegendTextColor;
                lg.Color = sty.LegendBgColor;
                lg.EdgeColor = sty.LegendEdgeColor;
            end
        end

        % N-labels above bars
        if opts.ShowN && ~all(isnan(groupN))
            yl = ylim(ax);
            yRange = yl(2) - yl(1);
            for g = 1:nGroups
                if ~isnan(groupN(g))
                    if hasPB
                        % barweb positions categories at integer x values
                        si = plotByIdx(g);
                        xi = find(strcmp(uniqueWithin, withinLabels{g}), 1);
                        xPos = xi + bwHandles.bars(si).XOffset;
                    else
                        xPos = g;
                    end
                    yPos = groupMeans(g) + groupErrors(g) + yRange * 0.02;
                    text(ax, xPos, yPos, sprintf('n=%d', groupN(g)), ...
                        'HorizontalAlignment', 'center', ...
                        'VerticalAlignment', 'bottom', ...
                        'FontSize', 7, 'Color', sty.DimColor, ...
                        'HandleVisibility', 'off');
                end
            end
        end

        % Zero line
        plot(ax, xlim(ax), [0 0], '-', 'Color', sty.ZeroLineColor, ...
            'LineWidth', 0.5, 'HandleVisibility', 'off');

        title(ax, pf2_base.plot.escapeTeX(itemNames{chI}));
        box(ax, 'on');
        grid(ax, 'on');
    end

    % Shared axes
    linkaxes(allAxes, 'y');
    if ~isempty(opts.YLim), arrayfun(@(a) ylim(a, opts.YLim), allAxes); end
    if ~isempty(opts.XLim), arrayfun(@(a) xlim(a, opts.XLim), allAxes); end

    % Figure title (suptitle auto-rescales subplots to avoid overlap)
    if ~isempty(opts.Title)
        pf2_base.external.suptitle(fig, opts.Title);
    else
        tStr = bioM;
        if ~isempty(opts.TimeWindow)
            tStr = sprintf('%s (%g-%gs)', tStr, round(opts.TimeWindow(1), 4), round(opts.TimeWindow(2), 4));
        end
        pf2_base.external.suptitle(fig, tStr);
    end

    sty.applyToFigure(fig);
    pf2_base.plot.handleSave(fig, opts);
end


%% Local helpers


function [groupMeans, groupErrors, groupN, groupLabels, individualData] = ...
        computeChannelStats(groups, bioM, ch, opts, useROI)
% Compute per-group mean, error, N for a single channel
    nGroups = length(groups);
    groupMeans = nan(1, nGroups);
    groupErrors = nan(1, nGroups);
    groupN = nan(1, nGroups);
    groupLabels = cell(1, nGroups);
    individualData = cell(1, nGroups);

    for g = 1:nGroups
        ga = groups(g).gbyGrand;
        if useROI
            if ~isfield(ga.ROI, bioM) || isempty(ga.ROI.(bioM))
                continue;
            end
            src = ga.ROI.(bioM);
        else
            if ~isfield(ga, bioM) || isempty(ga.(bioM))
                continue;
            end
            src = ga.(bioM);
        end

        if ch > size(src.Mean, 2), continue; end

        timeVec = ga.time;

        % Time window selection
        if ~isempty(opts.TimeWindow)
            tMask = timeVec >= opts.TimeWindow(1) & timeVec <= opts.TimeWindow(2);
        else
            tMask = true(size(timeVec));
        end
        if ~any(tMask), continue; end

        % Mean: average over time window for this single channel
        groupMeans(g) = mean(src.Mean(tMask, ch), 'omitnan');

        % Error: use per-subject data when available
        if isfield(src, 'data') && ~isempty(src.data)
            % data is [T x C x N]
            subjectData = src.data(tMask, ch, :);
            perSubject = squeeze(mean(subjectData, 1, 'omitnan'));
            perSubject = perSubject(:);
            perSubject(isnan(perSubject)) = [];

            groupN(g) = length(perSubject);
            individualData{g} = perSubject;

            switch upper(opts.ErrorType)
                case 'SEM'
                    groupErrors(g) = std(perSubject, 'omitnan') / sqrt(groupN(g));
                case 'SD'
                    groupErrors(g) = std(perSubject, 'omitnan');
                case 'NONE'
                    groupErrors(g) = 0;
            end
        else
            groupErrors(g) = mean(src.SEM(tMask, ch), 'omitnan');
            groupN(g) = round(mean(src.N(tMask, ch), 'omitnan'));
        end

        groupLabels{g} = groups(g).label;
    end
end


function lbl = getUnitsLabel(group)
    if ~isempty(group.gbyGrand) && isfield(group.gbyGrand, 'units')
        lbl = group.gbyGrand.units;
    else
        lbl = '\DeltaHb';
    end
end


function tf = showLegend(mode, idx, total)
% Determine whether to show legend on this subplot
    switch lower(mode)
        case 'last',  tf = (idx == total);
        case 'first', tf = (idx == 1);
        case 'all',   tf = true;
        case 'none',  tf = false;
        otherwise,    tf = (idx == total);
    end
end


function [roiIdx, roiNames] = resolveROIs(groups, rois)
% Convert ROI input to numeric indices and name strings
    roiInfo = groups(1).gbyGrand.ROI.info;
    allNames = roiInfo.Properties.RowNames;

    if ischar(rois) || isstring(rois)
        if strcmpi(rois, 'all')
            roiIdx = 1:length(allNames);
        else
            roiIdx = find(ismember(allNames, {char(rois)}));
        end
    elseif iscell(rois)
        roiIdx = find(ismember(allNames, rois));
    elseif islogical(rois)
        roiIdx = find(rois);
    else
        roiIdx = rois;  % numeric
    end

    roiIdx = roiIdx(roiIdx <= length(allNames));
    roiNames = allNames(roiIdx);
end


function ssIdx = getShortSeparationIdx(dev, groups)
% Get short-separation channel indices from Device or probe info
    ssIdx = [];
    if ~isempty(dev) && isa(dev, 'pf2.Device')
        ssIdx = find(dev.isShortSep());
        return;
    end
    for g = 1:length(groups)
        ga = groups(g).gbyGrand;
        if isfield(ga, 'probeInfo') && isstruct(ga.probeInfo)
            pi = ga.probeInfo;
            if isfield(pi, 'TableOpt') && istable(pi.TableOpt) ...
                    && ismember('IsShortSeparation', pi.TableOpt.Properties.VariableNames)
                ssIdx = find(pi.TableOpt.IsShortSeparation);
                return;
            end
            if isfield(pi, 'SD') && isstruct(pi.SD) && isfield(pi.SD, 'distances')
                ssIdx = find(pi.SD.distances < 2);
                return;
            end
        end
    end
end
