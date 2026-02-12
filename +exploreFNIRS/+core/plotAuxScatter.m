function [fig, stats] = plotAuxScatter(groups, auxField, varargin)
% PLOTAUXSCATTER Scatter plot correlating info variable vs auxiliary data
%
% Creates scatter plots showing the relationship between an info/behavioral
% variable (X-axis) and auxiliary signal channel data (Y-axis). Each aux
% channel gets its own subplot. Supports Pearson/Spearman correlation,
% regression lines, and error bands.
%
% Syntax:
%   [fig, stats] = plotAuxScatter(groups, 'heartRate', 'InfoVar', 'Age')
%   [fig, stats] = plotAuxScatter(groups, 'accelerometer', ...
%       'InfoVar', 'reactionTime', 'AuxChannels', 1:2)
%
% Inputs:
%   groups   - Struct array from Experiment.groups (after aggregate())
%              Each element must have .gbyGrandBarFlat.Aux.(auxField)
%   auxField - Name of the Aux field to plot (e.g., 'heartRate')
%
% Name-Value Parameters:
%   InfoVar        - (required) X-axis variable name from info fields
%   AuxChannels    - Vector of Aux channel indices (default: all)
%   CorrType       - 'Pearson' (default) or 'Spearman'
%   FitLine        - Show regression line (default: true)
%   ErrorBand      - Show error band (default: false)
%   ErrorBandType  - '95%PI' (default), 'SEM', 'SD', '95%CI'
%   ErrorBandStyle - 'Shaded' (default), 'Dashed', 'Fine'
%   FlipXY         - Swap X and Y axes (default: false)
%   PlotBy         - Groupby variable to split subplots by
%   Legend         - 'last' (default), 'first', 'all', or 'none'
%   YLim           - [min max] y-axis limits (default: auto)
%   XLim           - [min max] x-axis limits (default: auto)
%   Title          - Figure title (default: auto)
%   Visible        - 'on' (default) or 'off'
%   SavePath       - File path to save figure
%   SaveWidth      - Width in pixels (default: 600)
%   SaveHeight     - Height in pixels (default: 400)
%   SaveDPI        - Resolution (default: 150)
%   Colors         - Group color palette override (default: [] = auto)
%
% Outputs:
%   fig   - Figure handle
%   stats - Struct with correlation statistics per group:
%           .r, .p        - Pearson correlation and p-value
%           .rho, .pval   - Spearman correlation and p-value
%           .N            - Sample size
%           .coefficients - [slope, intercept] from polyfit
%
% Example:
%   ex = exploreFNIRS.core.Experiment(data);
%   ex.groupby({'Group','Condition'});
%   ex.aggregate();
%
%   [fig, stats] = ex.plotAuxScatter('heartRate', 'Age', ...
%       'FitLine', true, 'CorrType', 'Spearman');
%
% See also: exploreFNIRS.core.plotScatter, exploreFNIRS.core.plotAuxBar

    p = inputParser;
    addRequired(p, 'groups', @isstruct);
    addRequired(p, 'auxField', @ischar);
    addParameter(p, 'InfoVar', '', @ischar);
    addParameter(p, 'AuxChannels', [], @isnumeric);
    addParameter(p, 'CorrType', 'Pearson', @ischar);
    addParameter(p, 'FitLine', true, @islogical);
    addParameter(p, 'ErrorBand', false, @islogical);
    addParameter(p, 'ErrorBandType', '95%PI', @ischar);
    addParameter(p, 'ErrorBandStyle', 'Shaded', @ischar);
    addParameter(p, 'FlipXY', false, @islogical);
    addParameter(p, 'PlotBy', '', @ischar);
    addParameter(p, 'Legend', 'last', @ischar);
    addParameter(p, 'YLim', [], @isnumeric);
    addParameter(p, 'XLim', [], @isnumeric);
    addParameter(p, 'Title', '', @ischar);
    addParameter(p, 'Visible', 'on', @ischar);
    addParameter(p, 'SavePath', '', @ischar);
    addParameter(p, 'SaveWidth', 600, @isnumeric);
    addParameter(p, 'SaveHeight', 400, @isnumeric);
    addParameter(p, 'SaveDPI', 150, @isnumeric);
    addParameter(p, 'Colors', [], @(x) isempty(x) || isnumeric(x) || ischar(x) || isstring(x) || isa(x, 'function_handle') || isa(x, 'exploreFNIRS.core.ColorScheme'));
    parse(p, groups, auxField, varargin{:});
    opts = p.Results;

    if isempty(opts.InfoVar)
        error('exploreFNIRS:core:plotAuxScatter', ...
            'InfoVar is required. Specify the X-axis variable name.');
    end

    if ~isempty(opts.SavePath)
        opts.Visible = 'off';
    end

    nGroups = length(groups);

    % Validate groups have bar-flat grand averages with Aux data
    for g = 1:nGroups
        if isempty(groups(g).gbyGrandBarFlat)
            error('exploreFNIRS:core:plotAuxScatter', ...
                'Group %d has no bar-flat grand average. Call aggregate() first.', g);
        end
    end

    % Resolve Aux field name (handle flattened naming)
    auxField = resolveAuxField(groups(1).gbyGrandBarFlat, auxField);

    % Validate Aux field exists
    for g = 1:nGroups
        ga = groups(g).gbyGrandBarFlat;
        if ~isfield(ga, 'Aux') || ~isfield(ga.Aux, auxField)
            error('exploreFNIRS:core:plotAuxScatter', ...
                'Aux field "%s" not found in group %d.', auxField, g);
        end
    end

    % Auto-expand groups by time bins when multiple bars exist
    if ~isempty(groups(1).gbyGrandBarFlat) && ...
            length(groups(1).gbyGrandBarFlat.time) > 1
        groups = exploreFNIRS.core.expandGroupsByTime(groups);
        nGroups = length(groups);
    end
    tIdx = 1;

    % Determine aux channels
    refAux = groups(1).gbyGrandBarFlat.Aux.(auxField);
    nTotalCh = size(refAux.data, 2);

    if isempty(opts.AuxChannels)
        auxCh = 1:nTotalCh;
    else
        auxCh = opts.AuxChannels(opts.AuxChannels <= nTotalCh);
    end
    nCh = length(auxCh);

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
        chLabels = arrayfun(@(x) sprintf('ch%d', x), auxCh, ...
            'UniformOutput', false);
    end

    % Y-axis label
    if isfield(refAux, 'unit') && ~isempty(refAux.unit)
        yUnit = refAux.unit;
    else
        yUnit = 'a.u.';
    end

    % Initialize stats output
    stats = repmat(emptyStats(), nGroups, nCh);

    sty = pf2_base.plot.PlotStyle.getDefault();

    % --- Determine layout ---
    hasPB = ~isempty(opts.PlotBy);
    if hasPB
        [plotByValues, subGroups, withinLabels, plotByIdx] = ...
            exploreFNIRS.core.splitGroupsByFactor(groups, opts.PlotBy);
        nPlotBy = length(plotByValues);
        nRows = nPlotBy;
        nCols = nCh;
    else
        nRows = ceil(sqrt(nCh));
        nCols = ceil(nCh / nRows);
    end

    figW = opts.SaveWidth * min(nCols, 4);
    figH = opts.SaveHeight * max(nRows * 0.7, 1);

    fig = pf2_base.plot.createFigure('Visible', opts.Visible, ...
        'Width', figW, 'Height', figH, 'SavePath', opts.SavePath);

    allAxes = gobjects(nRows * nCols, 1);
    axCount = 0;

    if hasPB
        % rows = PlotBy values, cols = aux channels
        for pIdx = 1:nPlotBy
            curGroups = subGroups{pIdx};
            nCurGroups = length(curGroups);
            if isa(opts.Colors, 'exploreFNIRS.core.ColorScheme')
                curColors = opts.Colors.resolve(curGroups);
            else
                curColors = exploreFNIRS.core.getGroupColors(nCurGroups, opts.Colors);
            end
            curWithin = withinLabels(plotByIdx == pIdx);

            for chI = 1:nCh
                ch = auxCh(chI);
                spIdx = (pIdx - 1) * nCols + chI;
                ax = subplot(nRows, nCols, spIdx, 'Parent', fig);
                hold(ax, 'on');
                axCount = axCount + 1;
                allAxes(axCount) = ax;

                for g = 1:nCurGroups
                    curStats = plotGroupAuxScatter(ax, curGroups(g), ...
                        auxField, ch, tIdx, opts, curColors(g,:), g);
                    stats(g, chI) = curStats;
                end

                if pIdx == 1
                    title(ax, pf2_base.plot.escapeTeX(chLabels{chI}));
                end
                if chI == 1
                    ylabel(ax, pf2_base.plot.escapeTeX(sprintf('%s: %s', opts.PlotBy, plotByValues{pIdx})));
                end

                if opts.FlipXY
                    xlabel(ax, sprintf('%s (%s)', auxField, yUnit));
                else
                    xlabel(ax, pf2_base.plot.escapeTeX(opts.InfoVar));
                end

                spTotal = nPlotBy * nCh;
                if nCurGroups > 1 && showLegend(opts.Legend, spIdx, spTotal)
                    lg = legend(ax, curWithin, 'Location', 'best', 'FontSize', 8);
                    lg.TextColor = sty.LegendTextColor;
                    lg.Color = sty.LegendBgColor;
                    lg.EdgeColor = sty.LegendEdgeColor;
                end

                grid(ax, 'on');
                box(ax, 'on');
            end
        end
    else
        % Square grid of aux channels
        if isa(opts.Colors, 'exploreFNIRS.core.ColorScheme')
            colors = opts.Colors.resolve(groups);
        else
            colors = exploreFNIRS.core.getGroupColors(nGroups, opts.Colors);
        end

        for chI = 1:nCh
            ch = auxCh(chI);

            if nCh > 1
                ax = subplot(nRows, nCols, chI, 'Parent', fig);
            else
                ax = axes('Parent', fig);
            end
            hold(ax, 'on');
            axCount = axCount + 1;
            allAxes(axCount) = ax;

            for g = 1:nGroups
                curStats = plotGroupAuxScatter(ax, groups(g), ...
                    auxField, ch, tIdx, opts, colors(g,:), g);
                stats(g, chI) = curStats;
            end

            title(ax, pf2_base.plot.escapeTeX(chLabels{chI}));
            if opts.FlipXY
                xlabel(ax, sprintf('%s (%s)', auxField, yUnit));
                if chI == 1 || mod(chI - 1, nCols) == 0
                    ylabel(ax, pf2_base.plot.escapeTeX(opts.InfoVar));
                end
            else
                xlabel(ax, pf2_base.plot.escapeTeX(opts.InfoVar));
                if chI == 1 || mod(chI - 1, nCols) == 0
                    ylabel(ax, sprintf('%s (%s)', auxField, yUnit));
                end
            end

            if nGroups > 1 && showLegend(opts.Legend, chI, nCh)
                legendLabels = arrayfun(@(g) groups(g).label, ...
                    1:nGroups, 'UniformOutput', false);
                lg = legend(ax, legendLabels, 'Location', 'best', 'FontSize', 8);
                lg.TextColor = 'k';
                lg.Color = 'w';
                lg.EdgeColor = [0.5 0.5 0.5];
            end

            grid(ax, 'on');
            box(ax, 'on');
        end
    end

    % Shared axes
    allAxes = allAxes(1:axCount);
    if axCount > 1
        linkaxes(allAxes, 'xy');
    end
    if ~isempty(opts.YLim), arrayfun(@(a) ylim(a, opts.YLim), allAxes); end
    if ~isempty(opts.XLim), arrayfun(@(a) xlim(a, opts.XLim), allAxes); end

    % Title
    if ~isempty(opts.Title)
        pf2_base.external.suptitle(fig, opts.Title);
    else
        pf2_base.external.suptitle(fig, sprintf('%s vs %s (%s)', ...
            pf2_base.plot.escapeTeX(opts.InfoVar), auxField, opts.CorrType));
    end

    sty.applyToFigure(fig);
    pf2_base.plot.handleSave(fig, opts);
end


%% Local helpers

function curStats = plotGroupAuxScatter(ax, group, auxField, ch, tIdx, opts, clr, gIdx)
% Plot scatter for one group, one aux channel

    curGrand = group.gbyGrandBarFlat;
    curTable = group.gbyTables;

    % Extract Y: per-subject aux value at this channel and time bin
    if ~isfield(curGrand, 'Aux') || ~isfield(curGrand.Aux, auxField)
        curStats = emptyStats();
        return;
    end

    auxData = curGrand.Aux.(auxField);
    if ~isfield(auxData, 'data') || ch > size(auxData.data, 2)
        curStats = emptyStats();
        return;
    end

    yVals = permute(auxData.data(tIdx, ch, :), [3, 1, 2]);

    % Hierarchical averaging of Y values
    if isfield(curGrand, 'info') && isfield(curGrand.info, 'Hierarchy')
        [yVals, ~] = pf2_base.hierarchicalAverage(yVals, ...
            curGrand.info.Hierarchy, @nanmean);
    end

    % Extract X: info variable from table, with hierarchical averaging
    if ~ismember(opts.InfoVar, curTable.Properties.VariableNames)
        warning('Variable "%s" not found in group table', opts.InfoVar);
        curStats = emptyStats();
        return;
    end

    xData = curTable.(opts.InfoVar);
    if ~isnumeric(xData)
        xData = double(string(xData));
    end
    xData(xData == -9999) = NaN;

    % Hierarchical averaging of X values
    if ismember('SubjectID', curTable.Properties.VariableNames)
        [xVals] = pf2_base.hierarchicalAverage(xData, ...
            curTable(:, 'SubjectID'), @nanmean);
    else
        xVals = xData;
    end

    % Align lengths
    n = min(length(xVals), length(yVals));
    xVals = xVals(1:n);
    yVals = yVals(1:n);

    % Remove NaN pairs
    validIdx = ~isnan(xVals) & ~isnan(yVals);
    xVals = xVals(validIdx);
    yVals = yVals(validIdx);
    N = length(xVals);

    % Compute correlations
    curStats = emptyStats();
    curStats.N = N;

    if N >= 3
        [curStats.r, curStats.p] = corr(xVals, yVals, 'Type', 'Pearson');
        [curStats.rho, curStats.pval] = corr(xVals, yVals, 'Type', 'Spearman');
    end

    % Apply Spearman rank transform if requested
    if strcmpi(opts.CorrType, 'Spearman')
        [~, p2] = sort(xVals, 'descend');
        r2 = 1:length(xVals);
        r2(p2) = r2;
        xVals = r2(:);

        [~, p2] = sort(yVals, 'descend');
        r2 = 1:length(yVals);
        r2(p2) = r2;
        yVals = r2(:);
    end

    % Flip axes
    if opts.FlipXY
        temp = xVals;
        xVals = yVals;
        yVals = temp;
    end

    % Scatter points
    scatter(ax, xVals, yVals, 25, clr, 'filled', 'MarkerFaceAlpha', 0.7);

    % Regression line and error band
    if (opts.FitLine || opts.ErrorBand) && N > 2
        [coefficients, PolyS] = polyfit(xVals, yVals, 1);
        curStats.coefficients = coefficients;
        xFit = linspace(min(xVals), max(xVals), 200);
        [yFit, deltaY] = polyval(coefficients, xFit, PolyS);

        % Error band
        if opts.ErrorBand
            yEst = polyval(coefficients, xVals);
            yDiff = yVals - yEst;
            SD = std(yDiff);
            SEM = SD / sqrt(N);

            switch opts.ErrorBandType
                case 'SEM'
                    yUpper = yFit + SEM;
                    yLower = yFit - SEM;
                case 'SD'
                    yUpper = yFit + SD;
                    yLower = yFit - SD;
                case '95%CI'
                    CI = pf2_base.external.polyparci(coefficients, PolyS);
                    yUpper = polyval(CI(1,:), xFit);
                    yLower = polyval(CI(2,:), xFit);
                case '95%PI'
                    yUpper = yFit + deltaY * tinv(0.95, N - 1);
                    yLower = yFit - deltaY * tinv(0.95, N - 1);
                otherwise
                    yUpper = yFit + deltaY * tinv(0.95, N - 1);
                    yLower = yFit - deltaY * tinv(0.95, N - 1);
            end

            plotBand(ax, xFit, yUpper, yLower, clr, opts.ErrorBandStyle);
        end

        % Regression line
        if opts.FitLine
            h = plot(ax, xFit, yFit, '-', 'Color', clr, 'LineWidth', 1.5);
            set(h.Annotation.LegendInformation, 'IconDisplayStyle', 'off');

            % Annotation with stats
            if strcmpi(opts.CorrType, 'Spearman')
                statStr = sprintf('rho=%.3f, p=%.4f', curStats.rho, curStats.pval);
            else
                statStr = sprintf('r=%.3f, p=%.4f', curStats.r, curStats.p);
            end
            yOff = 0.98 - (gIdx - 1) * 0.08;
            text(ax, 0.02, yOff, ...
                sprintf('N=%d, %s', N, statStr), ...
                'Units', 'normalized', 'FontSize', 7, 'Color', clr, ...
                'VerticalAlignment', 'top');
        end
    end
end


function plotBand(ax, xFit, yUpper, yLower, clr, style)
% Plot error band around regression line
    errColor = clr + (1 - clr) * 0.55;

    switch style
        case 'Shaded'
            xPatch = [xFit, fliplr(xFit)];
            yPatch = [yLower, fliplr(yUpper)];
            h = patch(ax, xPatch, yPatch, -1, ...
                'FaceColor', errColor, 'EdgeColor', 'none', 'FaceAlpha', 0.15);
            set(h, 'HandleVisibility', 'off');
        case 'Dashed'
            h1 = plot(ax, xFit, yUpper, '--', 'Color', errColor, 'LineWidth', 1.5);
            h2 = plot(ax, xFit, yLower, '--', 'Color', errColor, 'LineWidth', 1.5);
            set(h1.Annotation.LegendInformation, 'IconDisplayStyle', 'off');
            set(h2.Annotation.LegendInformation, 'IconDisplayStyle', 'off');
        case 'Fine'
            h1 = plot(ax, xFit, yUpper, '-', 'Color', errColor, 'LineWidth', 0.5);
            h2 = plot(ax, xFit, yLower, '-', 'Color', errColor, 'LineWidth', 0.5);
            set(h1.Annotation.LegendInformation, 'IconDisplayStyle', 'off');
            set(h2.Annotation.LegendInformation, 'IconDisplayStyle', 'off');
    end
end


function tf = showLegend(mode, idx, total)
    switch lower(mode)
        case 'last',  tf = (idx == total);
        case 'first', tf = (idx == 1);
        case 'all',   tf = true;
        case 'none',  tf = false;
        otherwise,    tf = (idx == total);
    end
end


function s = emptyStats()
    s = struct('r', NaN, 'p', NaN, 'rho', NaN, 'pval', NaN, ...
        'N', 0, 'coefficients', []);
end


function resolved = resolveAuxField(ga, name)
% Resolve user-facing Aux field name to actual field in data
    if ~isfield(ga, 'Aux')
        resolved = name;
        return;
    end
    if isfield(ga.Aux, name)
        resolved = name;
        return;
    end
    dataName = [name, '_data'];
    if isfield(ga.Aux, dataName)
        resolved = dataName;
        return;
    end
    resolved = name;
end
