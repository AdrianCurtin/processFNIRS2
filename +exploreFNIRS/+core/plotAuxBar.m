function fig = plotAuxBar(groups, auxField, varargin)
% PLOTAUXBAR Headless bar chart for auxiliary signal data
%
% Creates bar charts showing mean auxiliary variable values per group for
% each aux channel, with error bars. Each aux channel gets its own subplot.
% Groups are shown as separate bars within each subplot.
%
% Syntax:
%   fig = plotAuxBar(groups, 'heartRate')
%   fig = plotAuxBar(groups, 'accelerometer', 'AuxChannels', 1:2)
%   fig = plotAuxBar(groups, 'heartRate', 'TimeWindow', [5, 20])
%   fig = plotAuxBar(groups, 'heartRate', 'SavePath', 'hr_bar.png')
%
% Inputs:
%   groups   - Struct array from Experiment.groups (after aggregate())
%              Each element must have .gbyGrand.Aux.(auxField)
%   auxField - Name of the Aux field to plot (e.g., 'heartRate')
%
% Name-Value Parameters:
%   AuxChannels    - Vector of Aux channel indices (default: all)
%   TimeWindow     - [start, end] in seconds to average over (default: full)
%   ErrorType      - 'SEM' (default), 'SD', or 'none'
%   ShowIndividual - Show individual subject means (default: false)
%   ShowN          - Show subject count (n=X) above bars (default: true)
%   PlotBy         - Groupby variable for clustered bars (default: '')
%   GroupByVars    - Injected by Experiment wrapper (default: {})
%   Legend         - 'last' (default), 'first', 'all', or 'none'
%   YLim           - [min max] y-axis limits (default: auto)
%   XLim           - [min max] x-axis limits (default: auto)
%   Title          - Figure title (default: auto from auxField)
%   Visible        - 'on' (default) or 'off'
%   SavePath       - File path to save figure
%   SaveWidth      - Width in pixels (default: 600)
%   SaveHeight     - Height in pixels (default: 400)
%   SaveDPI        - Resolution (default: 150)
%   Colors         - Group color palette override (default: [] = auto)
%
% Outputs:
%   fig - Figure handle
%
% Example:
%   ex = exploreFNIRS.core.Experiment(data);
%   ex.groupby({'Group','Condition'});
%   ex.aggregate();
%
%   % Bar chart for heart rate, averaged over 5-20s
%   fig = exploreFNIRS.core.plotAuxBar(ex.groups, 'heartRate', ...
%       'TimeWindow', [5, 20], 'ShowIndividual', true);
%
% See also: exploreFNIRS.core.plotAux, exploreFNIRS.core.plotBar,
%   exploreFNIRS.core.Experiment

    p = inputParser;
    addRequired(p, 'groups', @isstruct);
    addRequired(p, 'auxField', @ischar);
    addParameter(p, 'AuxChannels', [], @isnumeric);
    addParameter(p, 'TimeWindow', [], @isnumeric);
    addParameter(p, 'ErrorType', 'SEM', @ischar);
    addParameter(p, 'ShowIndividual', false, @islogical);
    addParameter(p, 'ShowN', true, @islogical);
    addParameter(p, 'PlotBy', '', @ischar);
    addParameter(p, 'GroupByVars', {}, @iscell);
    addParameter(p, 'Legend', 'last', @ischar);
    addParameter(p, 'YLim', [], @isnumeric);
    addParameter(p, 'XLim', [], @isnumeric);
    addParameter(p, 'Title', '', @ischar);
    addParameter(p, 'Visible', 'on', @ischar);
    addParameter(p, 'SavePath', '', @ischar);
    addParameter(p, 'SaveWidth', 600, @isnumeric);
    addParameter(p, 'SaveHeight', 400, @isnumeric);
    addParameter(p, 'SaveDPI', 150, @isnumeric);
    addParameter(p, 'TightLayout', false, @islogical);
    addParameter(p, 'Colors', [], @(x) isempty(x) || isnumeric(x) || ischar(x) || isstring(x) || isa(x, 'function_handle') || isa(x, 'exploreFNIRS.core.ColorScheme'));
    parse(p, groups, auxField, varargin{:});
    opts = p.Results;

    if ~isempty(opts.SavePath)
        opts.Visible = 'off';
    end

    nGroups = length(groups);

    % Resolve Aux field name (handle flattened naming)
    auxField = resolveAuxField(groups(1).gbyGrand, auxField);

    % Validate Aux field exists in all groups
    for g = 1:nGroups
        ga = groups(g).gbyGrand;
        if isempty(ga)
            error('exploreFNIRS:core:plotAuxBar', ...
                'Group %d has no grand average. Call aggregate() first.', g);
        end
        if ~isfield(ga, 'Aux') || ~isfield(ga.Aux, auxField)
            error('exploreFNIRS:core:plotAuxBar', ...
                'Aux field "%s" not found in group %d. Available: %s', ...
                auxField, g, getAuxFieldList(ga));
        end
    end

    % Auto-expand groups by time bins when multiple bars exist
    if ~isempty(groups(1).gbyGrandBarFlat) && ...
            length(groups(1).gbyGrandBarFlat.time) > 1
        groups = exploreFNIRS.core.expandGroupsByTime(groups);
        nGroups = length(groups);
    end

    % Determine number of Aux channels from first group
    refAux = groups(1).gbyGrand.Aux.(auxField);
    nTotalCh = size(refAux.Mean, 2);

    if isempty(opts.AuxChannels)
        auxCh = 1:nTotalCh;
    else
        auxCh = opts.AuxChannels(opts.AuxChannels <= nTotalCh);
    end
    nCh = length(auxCh);

    if nCh == 0
        error('exploreFNIRS:core:plotAuxBar', 'No valid Aux channels to plot');
    end

    % Get channel labels
    if isfield(refAux, 'varNames') && ~isempty(refAux.varNames)
        allLabels = refAux.varNames;
        chLabels = cell(1, nCh);
        for c = 1:nCh
            if auxCh(c) <= length(allLabels)
                chLabels{c} = allLabels{auxCh(c)};
            else
                chLabels{c} = sprintf('ch%d', auxCh(c));
            end
        end
    else
        chLabels = arrayfun(@(x) sprintf('ch%d', x), auxCh, 'UniformOutput', false);
    end

    % PlotBy setup
    hasPB = ~isempty(opts.PlotBy);
    if hasPB
        [plotByValues, ~, withinLabels, plotByIdx] = ...
            exploreFNIRS.core.splitGroupsByFactor(groups, opts.PlotBy);
    end

    % Layout
    nCols = ceil(sqrt(nCh));
    nRows = ceil(nCh / nCols);

    figW = opts.SaveWidth * min(nCols, 5);
    figH = opts.SaveHeight * max(nRows, 1);

    fig = pf2_base.plot.createFigure('Visible', opts.Visible, ...
        'Width', figW, 'Height', figH, 'SavePath', opts.SavePath);
    sty = pf2_base.plot.PlotStyle.getDefault();

    allAxes = gobjects(nCh, 1);

    for chI = 1:nCh
        ax = subplot(nRows, nCols, chI, 'Parent', fig);
        hold(ax, 'on');
        allAxes(chI) = ax;

        ch = auxCh(chI);

        % Compute per-group means/errors for this aux channel
        [groupMeans, groupErrors, groupN, groupLabels, individualData] = ...
            computeAuxChannelStats(groups, auxField, ch, opts);

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
                'YLabel', getAuxUnit(refAux)};

            if showLegend(opts.Legend, chI, nCh) && ~strcmpi(opts.Legend, 'none')
                barwebArgs = [barwebArgs, {'Legend', pf2_base.plot.escapeTeX(plotByValues)}];
            end

            if opts.ShowIndividual
                barwebArgs = [barwebArgs, {'DataPoints', indivData}];
            end

            bwHandles = pf2_base.external.barweb(meanMatrix, errInput, 1, pf2_base.plot.escapeTeX(uniqueWithin), ...
                barwebArgs{:}, 'ErrorColor', sty.ForegroundColor);
            hold(ax, 'on');

            % Style legend if barweb created one
            if ~isempty(bwHandles.legend) && isvalid(bwHandles.legend)
                bwHandles.legend.TextColor = sty.LegendTextColor;
                bwHandles.legend.Color = sty.LegendBgColor;
                bwHandles.legend.EdgeColor = sty.LegendEdgeColor;
                bwHandles.legend.Box = 'on';
            end

            % X-axis label: within factor name(s) - bottom row only
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

            meanMatrix = groupMeans(:);
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
                'ColorMap', colors(1:nGroups,:), ...
                'YLabel', getAuxUnit(refAux)};

            if opts.ShowIndividual
                barwebArgs = [barwebArgs, {'DataPoints', indivData}];
            end

            bwHandles = pf2_base.external.barweb(meanMatrix, errInput, 1, pf2_base.plot.escapeTeX(groupLabels), ...
                barwebArgs{:}, 'ErrorColor', sty.ForegroundColor);
            hold(ax, 'on');

            % Color each bar individually
            if ~isempty(bwHandles.bars)
                bwHandles.bars(1).FaceColor = 'flat';
                bwHandles.bars(1).CData = colors(1:nGroups, :);
            end

            % Add x-axis margin
            xlim(ax, [0.25, nGroups + 0.75]);

            % Replace tick labels with xlabel on bottom row
            isBottomRow = ceil(chI / nCols) == nRows;
            if ~isempty(opts.GroupByVars)
                set(ax, 'XTickLabel', {});
                if isBottomRow
                    xlabel(ax, pf2_base.plot.escapeTeX(strjoin(opts.GroupByVars, ' x ')));
                end
            end

            % Legend with colored patches
            if showLegend(opts.Legend, chI, nCh)
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
                        si = plotByIdx(g);
                        xi = find(strcmp(uniqueWithin, withinLabels{g}), 1);
                        % Read actual bar x-position from barweb handles
                        xPos = bwHandles.bars(si).XData(xi) + ...
                               bwHandles.bars(si).XOffset;
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

        title(ax, pf2_base.plot.escapeTeX(chLabels{chI}));
        box(ax, 'on');
        grid(ax, 'on');
    end

    % Shared axes
    linkaxes(allAxes, 'y');
    if ~isempty(opts.YLim), arrayfun(@(a) ylim(a, opts.YLim), allAxes); end
    if ~isempty(opts.XLim), arrayfun(@(a) xlim(a, opts.XLim), allAxes); end

    % Figure title
    if ~isempty(opts.Title)
        pf2_base.external.suptitle(fig, opts.Title);
    else
        tStr = pf2_base.plot.escapeTeX(auxField);
        if ~isempty(opts.TimeWindow)
            tStr = sprintf('%s (%g-%gs)', tStr, opts.TimeWindow(1), opts.TimeWindow(2));
        end
        pf2_base.external.suptitle(fig, tStr);
    end

    sty.applyToFigure(fig);
    pf2_base.plot.handleSave(fig, opts);
end


%% Local helpers

function [groupMeans, groupErrors, groupN, groupLabels, individualData] = ...
        computeAuxChannelStats(groups, auxField, ch, opts)
% Compute per-group mean, error, N for a single aux channel
    nGroups = length(groups);
    groupMeans = nan(1, nGroups);
    groupErrors = nan(1, nGroups);
    groupN = nan(1, nGroups);
    groupLabels = cell(1, nGroups);
    individualData = cell(1, nGroups);

    % Pre-fill labels so escapeTeX/legend code never sees an empty
    % numeric [] slot when a group is skipped for lack of data.
    for g = 1:nGroups
        lbl = groups(g).label;
        if isempty(lbl) || ~(ischar(lbl) || isstring(lbl))
            lbl = sprintf('Group%d', g);
        end
        groupLabels{g} = char(lbl);
    end

    for g = 1:nGroups
        ga = groups(g).gbyGrand;
        if ~isfield(ga, 'Aux') || ~isfield(ga.Aux, auxField)
            continue;
        end
        src = ga.Aux.(auxField);

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


function lbl = getAuxUnit(auxStruct)
    if isfield(auxStruct, 'unit')
        lbl = auxStruct.unit;
    else
        lbl = 'a.u.';
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


function resolved = resolveAuxField(ga, name)
% Resolve user-facing Aux field name to actual field in grand average
    if ~isfield(ga, 'Aux')
        resolved = name;
        return;
    end

    % Exact match
    if isfield(ga.Aux, name)
        resolved = name;
        return;
    end

    % Try _data suffix (from flattenAux)
    dataName = [name, '_data'];
    if isfield(ga.Aux, dataName)
        resolved = dataName;
        return;
    end

    % No match - return original (will produce helpful error later)
    resolved = name;
end


function str = getAuxFieldList(ga)
% List available Aux fields
    if isfield(ga, 'Aux') && isstruct(ga.Aux)
        flds = getCleanAuxFields(ga);
        if ~isempty(flds)
            str = strjoin(flds, ', ');
        else
            str = '(none)';
        end
    else
        str = '(no Aux data)';
    end
end


function cleanNames = getCleanAuxFields(ga)
% Get deduplicated, clean Aux field names
    if ~isfield(ga, 'Aux') || ~isstruct(ga.Aux)
        cleanNames = {};
        return;
    end

    flds = fieldnames(ga.Aux);
    flds = flds(~ismember(flds, {'flattened'}));

    baseNames = {};
    for i = 1:length(flds)
        f = flds{i};
        base = regexprep(f, '_(data|time|unit)$', '');
        if ~ismember(base, baseNames)
            if isfield(ga.Aux, f) && isstruct(ga.Aux.(f)) && isfield(ga.Aux.(f), 'Mean')
                baseNames{end+1} = base; %#ok<AGROW>
            elseif isfield(ga.Aux, [base '_data']) && isstruct(ga.Aux.([base '_data'])) && isfield(ga.Aux.([base '_data']), 'Mean')
                baseNames{end+1} = base; %#ok<AGROW>
            end
        end
    end
    cleanNames = unique(baseNames, 'stable');
end
