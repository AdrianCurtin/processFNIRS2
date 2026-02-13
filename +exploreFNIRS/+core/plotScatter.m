function [fig, stats] = plotScatter(groups, varargin)
% PLOTSCATTER Scatter plot correlating info variable vs fNIRS biomarker
%
% Creates scatter plots showing the relationship between an info/behavioral
% variable (X-axis) and fNIRS biomarker channel data (Y-axis). Each channel
% and biomarker gets its own subplot — channels and biomarkers are never
% averaged. Supports Pearson/Spearman correlation, regression lines, error
% bands, and topographic correlation maps.
%
% Syntax:
%   [fig, stats] = plotScatter(groups, 'InfoVar', 'reactionTime')
%   [fig, stats] = plotScatter(groups, 'InfoVar', 'Age', ...
%       'Biomarkers', {'HbO'}, 'Channels', 1:5)
%   [fig, stats] = plotScatter(groups, 'InfoVar', 'Age', ...
%       'PlotTopo', true, 'SigThreshold', 0.05)
%
% Inputs:
%   groups - Struct array from Experiment.groups (after aggregate())
%            Each element must have .gbyGrandBarFlat and .gbyTables
%
% Name-Value Parameters:
%   InfoVar        - (required) X-axis variable name from info fields
%   Biomarkers     - Cell array of biomarkers (default: {'HbO'})
%   Channels       - Vector of channel indices (default: all channels)
%   Averaging      - 'hierarchy' (default), 'flat', or 'none'
%                    'hierarchy' averages within SubjectID first
%                    'flat'/'none' uses raw block-level data
%   CorrType       - 'Pearson' (default) or 'Spearman'
%   FitLine        - Show regression line (default: true)
%   ErrorBand      - Show error band (default: false)
%   ErrorBandType  - '95%PI' (default), 'SEM', 'SD', '95%CI'
%   ErrorBandStyle - 'Shaded' (default), 'Dashed', 'Fine'
%   FlipXY         - Swap X and Y axes (default: false)
%   PlotTopo       - Generate topo correlation map (default: false)
%   SigThreshold   - Significance threshold for topo (default: 0.05)
%   SigType        - 'p' (default), 'q', 'q-twostep'
%   PlotBy         - Groupby variable to split subplots by (e.g., 'Condition').
%                    Creates one subplot row per PlotBy value. When combined
%                    with multiple biomarkers, a separate figure is created
%                    per biomarker. Only for scatter mode (not topo).
%   Legend         - 'last' (default), 'first', 'all', or 'none'
%                    Controls which subplot(s) show the legend.
%   YLim           - [min max] y-axis limits (default: auto, shared across subplots)
%   XLim           - [min max] x-axis limits (default: auto, shared across subplots)
%   Title          - Figure title (default: auto)
%   Visible        - 'on' (default) or 'off'
%   SavePath       - File path to save figure
%   SaveWidth      - Width in pixels (default: 600)
%   SaveHeight     - Height in pixels (default: 400)
%   SaveDPI        - Resolution (default: 150)
%   Colors         - Group color palette override (default: [] = auto)
%                    [N x 3] RGB matrix, colormap name (e.g. 'Set1'),
%                    or function handle @(N) returning [N x 3].
%
% Layout:
%   Each channel and biomarker combination gets its own subplot.
%   Groups are overlaid as differently colored scatter points.
%
%   - 1 biomarker: channels in a square-ish grid
%   - Multiple biomarkers, no PlotBy: rows = biomarkers, columns = channels
%   - With PlotBy, 1 biomarker: rows = PlotBy values, columns = channels
%   - With PlotBy, multiple biomarkers: separate figure per biomarker,
%     rows = PlotBy values, columns = channels
%
% Outputs:
%   fig   - Figure handle (or array of handles if multiple figures created)
%   stats - Struct with correlation statistics per group:
%           .r, .p        - Pearson correlation and p-value
%           .rho, .pval   - Spearman correlation and p-value
%           .N            - Sample size
%           .coefficients - [slope, intercept] from polyfit
%           .q            - FDR-corrected p-values (topo mode only)
%
% Example:
%   ex = exploreFNIRS.core.Experiment(data);
%   ex.groupby({'Group','Condition'});
%   ex.aggregate();
%
%   % Scatter: reaction time vs HbO, all channels
%   [fig, stats] = exploreFNIRS.core.plotScatter(ex.groups, ...
%       'InfoVar', 'reactionTime', 'Biomarkers', {'HbO'});
%
%   % Topographic correlation map
%   [fig, stats] = exploreFNIRS.core.plotScatter(ex.groups, ...
%       'InfoVar', 'Age', 'PlotTopo', true, 'SigThreshold', 0.05);
%
% See also: exploreFNIRS.core.Experiment, exploreFNIRS.core.plotBar

    p = inputParser;
    addRequired(p, 'groups', @isstruct);
    addParameter(p, 'InfoVar', '', @ischar);
    addParameter(p, 'Biomarkers', {'HbO'}, @iscell);
    addParameter(p, 'Channels', [], @isnumeric);
    addParameter(p, 'ROIs', [], @(x) isnumeric(x) || islogical(x) || ischar(x) || isstring(x) || iscell(x));
    addParameter(p, 'Averaging', 'hierarchy', @(x) ismember(lower(x), {'hierarchy','flat','none'}));
    addParameter(p, 'CorrType', 'Pearson', @ischar);
    addParameter(p, 'FitLine', true, @islogical);
    addParameter(p, 'ErrorBand', false, @islogical);
    addParameter(p, 'ErrorBandType', '95%PI', @ischar);
    addParameter(p, 'ErrorBandStyle', 'Shaded', @ischar);
    addParameter(p, 'FlipXY', false, @islogical);
    addParameter(p, 'PlotTopo', false, @islogical);
    addParameter(p, 'SigThreshold', 0.05, @isnumeric);
    addParameter(p, 'SigType', 'p', @ischar);
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
    parse(p, groups, varargin{:});
    opts = p.Results;

    if isempty(opts.InfoVar)
        error('exploreFNIRS:core:plotScatter', ...
            'InfoVar is required. Specify the X-axis variable name.');
    end

    if ~isempty(opts.SavePath)
        opts.Visible = 'off';
    end

    nGroups = length(groups);
    nBioM = length(opts.Biomarkers);

    % Validate groups have bar-flat grand averages
    for g = 1:nGroups
        if isempty(groups(g).gbyGrandBarFlat)
            error('exploreFNIRS:core:plotScatter', ...
                'Group %d has no bar-flat grand average. Call aggregate() first.', g);
        end
    end

    % Resolve ROIs vs Channels
    useROI = ~isempty(opts.ROIs);
    if useROI
        if ~isempty(opts.Channels)
            error('exploreFNIRS:core:plotScatter', ...
                'ROIs and Channels are mutually exclusive.');
        end
        if ~isfield(groups(1).gbyGrandBarFlat, 'ROI')
            error('exploreFNIRS:core:plotScatter', ...
                'No ROI data in grand average. Define ROIs before aggregating.');
        end
        [roiIdx, roiNames] = resolveROIs(groups, opts.ROIs);
        allChannels = roiIdx;
        nCh = length(allChannels);
        itemNames = roiNames;
    else
        % Determine channels (default = all)
        if isempty(opts.Channels)
            nCh = size(groups(1).gbyGrandBarFlat.(opts.Biomarkers{1}).data, 2);
            allChannels = 1:nCh;
        else
            allChannels = opts.Channels;
            nCh = length(allChannels);
        end
        itemNames = arrayfun(@(c) sprintf('Ch %d', c), allChannels, ...
            'UniformOutput', false);
    end

    % Auto-expand groups by time bins when multiple bars exist
    if ~isempty(groups(1).gbyGrandBarFlat) && ...
            length(groups(1).gbyGrandBarFlat.time) > 1
        groups = exploreFNIRS.core.expandGroupsByTime(groups);
        nGroups = length(groups);
    end
    tIdx = 1;

    % Initialize stats output
    stats = repmat(emptyStats(), nGroups, nBioM, nCh);

    sty = pf2_base.plot.PlotStyle.getDefault();

    if opts.PlotTopo && useROI
        warning('exploreFNIRS:core:plotScatter', ...
            'PlotTopo is not supported with ROIs (topo is inherently spatial). Using scatter mode.');
    end

    if opts.PlotTopo && ~useROI
        % --- Topo mode (unchanged) ---
        [fig, stats] = plotTopoCorrelation(groups, opts, allChannels, tIdx);
        sty.applyToFigure(fig);
        pf2_base.plot.handleSave(fig, opts);
        return;
    end

    % --- Determine layout ---
    hasPB = ~isempty(opts.PlotBy);
    if hasPB
        [plotByValues, subGroups, withinLabels, plotByIdx] = ...
            exploreFNIRS.core.splitGroupsByFactor(groups, opts.PlotBy);
        nPlotBy = length(plotByValues);
    end

    if hasPB && nBioM > 1
        nFigs = nBioM;
        nRows = nPlotBy;
        nCols = nCh;
        layoutType = 'plotby';
    elseif hasPB
        nFigs = 1;
        nRows = nPlotBy;
        nCols = nCh;
        layoutType = 'plotby';
    elseif nBioM > 1
        nFigs = 1;
        nRows = nBioM;
        nCols = nCh;
        layoutType = 'biomarker';
    else
        nFigs = 1;
        nRows = ceil(sqrt(nCh));
        nCols = ceil(nCh / nRows);
        layoutType = 'channel_grid';
    end

    figs = gobjects(nFigs, 1);

    for fIdx = 1:nFigs
        figW = opts.SaveWidth * min(nCols, 4);
        figH = opts.SaveHeight * max(nRows * 0.7, 1);

        curFig = pf2_base.plot.createFigure('Visible', opts.Visible, ...
            'Width', figW, 'Height', figH, 'SavePath', opts.SavePath);
        figs(fIdx) = curFig;

        allAxes = gobjects(nRows * nCols, 1);
        axCount = 0;

        switch layoutType
            case 'plotby'
                % rows = PlotBy values, cols = channels
                if nBioM > 1
                    bioM = opts.Biomarkers{fIdx};
                    bIdx = fIdx;
                else
                    bioM = opts.Biomarkers{1};
                    bIdx = 1;
                end

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
                        ch = allChannels(chI);
                        spIdx = (pIdx - 1) * nCols + chI;
                        ax = subplot(nRows, nCols, spIdx, 'Parent', curFig);
                        hold(ax, 'on');
                        axCount = axCount + 1;
                        allAxes(axCount) = ax;

                        for g = 1:nCurGroups
                            curStats = plotGroupScatter(ax, curGroups(g), ...
                                bioM, ch, tIdx, opts, curColors(g,:), g, useROI);
                            stats(g, bIdx, chI) = curStats;
                        end

                        if pIdx == 1
                            title(ax, itemNames{chI});
                        end
                        if chI == 1
                            ylabel(ax, sprintf('%s: %s', opts.PlotBy, plotByValues{pIdx}));
                        end

                        if opts.FlipXY
                            xlabel(ax, sprintf('\\Delta[%s]', bioM));
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

            case 'biomarker'
                % rows = biomarkers, cols = channels
                if isa(opts.Colors, 'exploreFNIRS.core.ColorScheme')
                    colors = opts.Colors.resolve(groups);
                else
                    colors = exploreFNIRS.core.getGroupColors(nGroups, opts.Colors);
                end

                for bIdx = 1:nBioM
                    bioM = opts.Biomarkers{bIdx};
                    for chI = 1:nCh
                        ch = allChannels(chI);
                        spIdx = (bIdx - 1) * nCols + chI;
                        ax = subplot(nRows, nCols, spIdx, 'Parent', curFig);
                        hold(ax, 'on');
                        axCount = axCount + 1;
                        allAxes(axCount) = ax;

                        for g = 1:nGroups
                            curStats = plotGroupScatter(ax, groups(g), bioM, ch, ...
                                tIdx, opts, colors(g,:), g);
                            stats(g, bIdx, chI) = curStats;
                        end

                        if bIdx == 1
                            title(ax, itemNames{chI});
                        end
                        if chI == 1
                            if opts.FlipXY
                                ylabel(ax, pf2_base.plot.escapeTeX(opts.InfoVar));
                            else
                                ylabel(ax, sprintf('\\Delta[%s]', bioM));
                            end
                        end
                        if opts.FlipXY
                            xlabel(ax, sprintf('\\Delta[%s]', bioM));
                        else
                            xlabel(ax, pf2_base.plot.escapeTeX(opts.InfoVar));
                        end

                        spTotal = nBioM * nCh;
                        if nGroups > 1 && showLegend(opts.Legend, spIdx, spTotal)
                            legendLabels = arrayfun(@(g) groups(g).label, ...
                                1:nGroups, 'UniformOutput', false);
                            lg = legend(ax, legendLabels, 'Location', 'best', 'FontSize', 8);
                            lg.TextColor = sty.LegendTextColor;
                            lg.Color = sty.LegendBgColor;
                            lg.EdgeColor = sty.LegendEdgeColor;
                        end

                        grid(ax, 'on');
                        box(ax, 'on');
                    end
                end

            case 'channel_grid'
                % Square grid of channels, 1 biomarker
                bioM = opts.Biomarkers{1};
                if isa(opts.Colors, 'exploreFNIRS.core.ColorScheme')
                    colors = opts.Colors.resolve(groups);
                else
                    colors = exploreFNIRS.core.getGroupColors(nGroups, opts.Colors);
                end

                for chI = 1:nCh
                    ch = allChannels(chI);

                    if nCh > 1
                        ax = subplot(nRows, nCols, chI, 'Parent', curFig);
                    else
                        ax = axes('Parent', curFig);
                    end
                    hold(ax, 'on');
                    axCount = axCount + 1;
                    allAxes(axCount) = ax;

                    for g = 1:nGroups
                        curStats = plotGroupScatter(ax, groups(g), bioM, ch, ...
                            tIdx, opts, colors(g,:), g, useROI);
                        stats(g, 1, chI) = curStats;
                    end

                    title(ax, itemNames{chI});
                    if opts.FlipXY
                        xlabel(ax, sprintf('\\Delta[%s]', bioM));
                        if chI == 1 || mod(chI - 1, nCols) == 0
                            ylabel(ax, pf2_base.plot.escapeTeX(opts.InfoVar));
                        end
                    else
                        xlabel(ax, pf2_base.plot.escapeTeX(opts.InfoVar));
                        if chI == 1 || mod(chI - 1, nCols) == 0
                            ylabel(ax, sprintf('\\Delta[%s]', bioM));
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
        if strcmp(layoutType, 'biomarker')
            % Link within each biomarker row
            for bIdx = 1:nBioM
                rowStart = (bIdx - 1) * nCh + 1;
                rowEnd   = min(bIdx * nCh, axCount);
                linkaxes(allAxes(rowStart:rowEnd), 'xy');
            end
        elseif axCount > 1
            linkaxes(allAxes, 'xy');
        end
        if ~isempty(opts.YLim), arrayfun(@(a) ylim(a, opts.YLim), allAxes); end
        if ~isempty(opts.XLim), arrayfun(@(a) xlim(a, opts.XLim), allAxes); end

        % Title
        if ~isempty(opts.Title)
            if nFigs > 1
                pf2_base.external.suptitle(curFig, sprintf('%s — %s', opts.Title, ...
                    opts.Biomarkers{fIdx}));
            else
                pf2_base.external.suptitle(curFig, opts.Title);
            end
        elseif nFigs > 1
            pf2_base.external.suptitle(curFig, sprintf('%s vs %s (%s)', ...
                pf2_base.plot.escapeTeX(opts.InfoVar), opts.Biomarkers{fIdx}, ...
                opts.CorrType));
        else
            pf2_base.external.suptitle(curFig, sprintf('%s vs fNIRS (%s)', ...
                pf2_base.plot.escapeTeX(opts.InfoVar), opts.CorrType));
        end

        sty.applyToFigure(curFig);

        % Save
        if nFigs > 1 && ~isempty(opts.SavePath)
            [fPath, fName, fExt] = fileparts(opts.SavePath);
            figOpts = opts;
            figOpts.SavePath = fullfile(fPath, ...
                sprintf('%s_%s%s', fName, opts.Biomarkers{fIdx}, fExt));
            pf2_base.plot.handleSave(curFig, figOpts);
        else
            pf2_base.plot.handleSave(curFig, opts);
        end
    end

    % Return figure handle(s)
    if nFigs == 1
        fig = figs(1);
    else
        fig = figs;
    end
end


%% Local helpers

function curStats = plotGroupScatter(ax, group, bioM, ch, tIdx, opts, clr, gIdx, useROI)
% Plot scatter for one group, one channel/ROI, one biomarker
% gIdx is the 1-based group index for stacking stat annotations
% useROI: if true, read from gbyGrandBarFlat.ROI.(bioM) instead

    if nargin < 9, useROI = false; end

    curGrand = group.gbyGrandBarFlat;
    curTable = group.gbyTables;

    % Extract Y: per-subject biomarker value at this channel/ROI
    if useROI
        if ~isfield(curGrand, 'ROI') || ~isfield(curGrand.ROI, bioM) || ...
                isempty(curGrand.ROI.(bioM))
            curStats = emptyStats();
            return;
        end
        bioData = curGrand.ROI.(bioM);
    else
        if ~isfield(curGrand, bioM) || isempty(curGrand.(bioM))
            curStats = emptyStats();
            return;
        end
        bioData = curGrand.(bioM);
    end
    if ch > size(bioData.data, 2)
        curStats = emptyStats();
        return;
    end

    % Extract Y: per-subject biomarker value at this channel/ROI and time bin
    yVals = permute(bioData.data(tIdx, ch, :), [3, 1, 2]);

    % Hierarchical averaging of Y values
    if strcmpi(opts.Averaging, 'hierarchy') && ...
            isfield(curGrand, 'info') && isfield(curGrand.info, 'Hierarchy')
        [yVals, ~] = pf2_base.hierarchicalAverage(yVals, ...
            curGrand.info.Hierarchy, @nanmean);
    end

    % Extract X: info variable from table
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

    % Apply averaging to X values
    if strcmpi(opts.Averaging, 'hierarchy') && ...
            ismember('SubjectID', curTable.Properties.VariableNames)
        [xVals] = pf2_base.hierarchicalAverage(xData, ...
            curTable(:, 'SubjectID'), @nanmean);
    else
        xVals = xData;
    end

    % Align lengths (X and Y may differ after hierarchical averaging)
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

            % Annotation with stats (stacked by group index)
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


function [fig, stats] = plotTopoCorrelation(groups, opts, allChannels, tIdx)
% Compute per-channel correlations and render topo map
    nGroups = length(groups);
    nBioM = length(opts.Biomarkers);
    nCh = length(allChannels);

    nCols = nGroups;
    nRows = nBioM;

    fig = pf2_base.plot.createFigure('Visible', opts.Visible, ...
        'Width', opts.SaveWidth * min(nCols, 3), ...
        'Height', opts.SaveHeight * min(nRows, 3), ...
        'SavePath', opts.SavePath);

    stats = struct();

    for bIdx = 1:nBioM
        bioM = opts.Biomarkers{bIdx};

        for g = 1:nGroups
            curGrand = groups(g).gbyGrandBarFlat;
            curTable = groups(g).gbyTables;

            rVals = nan(1, nCh);
            pVals = nan(1, nCh);
            rhoVals = nan(1, nCh);
            pvalVals = nan(1, nCh);
            nVals = nan(1, nCh);

            for chI = 1:nCh
                ch = allChannels(chI);

                if ~isfield(curGrand, bioM) || ch > size(curGrand.(bioM).data, 2)
                    continue;
                end

                % Y: biomarker at channel for this time bin
                yVals = permute(curGrand.(bioM).data(tIdx, ch, :), [3, 1, 2]);
                if strcmpi(opts.Averaging, 'hierarchy') && ...
                        isfield(curGrand, 'info') && isfield(curGrand.info, 'Hierarchy')
                    yVals = pf2_base.hierarchicalAverage(yVals, ...
                        curGrand.info.Hierarchy, @nanmean);
                end

                % X: info variable
                xData = curTable.(opts.InfoVar);
                if ~isnumeric(xData)
                    xData = double(string(xData));
                end
                xData(xData == -9999) = NaN;
                if strcmpi(opts.Averaging, 'hierarchy') && ...
                        ismember('SubjectID', curTable.Properties.VariableNames)
                    xVals = pf2_base.hierarchicalAverage(xData, ...
                        curTable(:, 'SubjectID'), @nanmean);
                else
                    xVals = xData;
                end

                n = min(length(xVals), length(yVals));
                xV = xVals(1:n);
                yV = yVals(1:n);
                valid = ~isnan(xV) & ~isnan(yV);
                xV = xV(valid);
                yV = yV(valid);

                nVals(chI) = length(xV);
                if nVals(chI) >= 3
                    [rVals(chI), pVals(chI)] = corr(xV, yV, 'Type', 'Pearson');
                    [rhoVals(chI), pvalVals(chI)] = corr(xV, yV, 'Type', 'Spearman');
                end
            end

            % Select correlation type
            if strcmpi(opts.CorrType, 'Spearman')
                curR = rhoVals;
                curP = pvalVals;
                clrBarTitle = 'rho';
            else
                curR = rVals;
                curP = pVals;
                clrBarTitle = 'r';
            end

            % FDR correction
            [curQ, ~] = exploreFNIRS.fx.performFDR(curP, opts.SigThreshold);

            % Store stats
            stats(g, bIdx).r = rVals;
            stats(g, bIdx).p = pVals;
            stats(g, bIdx).rho = rhoVals;
            stats(g, bIdx).pval = pvalVals;
            stats(g, bIdx).N = nVals;
            stats(g, bIdx).q = curQ;

            % Plot topo
            spIdx = (bIdx - 1) * nGroups + g;
            ax = subplot(nRows, nCols, spIdx, 'Parent', fig);

            % Determine significance threshold
            switch opts.SigType
                case 'q'
                    sigP = curQ;
                case 'q-twostep'
                    [curQ2] = exploreFNIRS.fx.performFDR_twostep(curP, opts.SigThreshold);
                    sigP = curQ2;
                    stats(g, bIdx).q = curQ2;
                otherwise
                    sigP = curP;
            end

            % Find significant channels and threshold
            sigMask = sigP <= opts.SigThreshold;
            if any(sigMask)
                minR = min(abs(curR(sigMask)));
                if ~isempty(which('pf2.probe.plot.interpolateValues'))
                    axes(ax); %#ok<LAXES>
                    pf2.probe.plot.interpolateValues(curR, [], ...
                        [minR, -minR], [], groups(g).label, clrBarTitle, ...
                        'bufferDistance', 1);
                else
                    bar(ax, allChannels, curR, 'FaceColor', 'flat');
                    ylabel(ax, clrBarTitle);
                    xlabel(ax, 'Channel');
                    title(ax, groups(g).label);
                end
            else
                text(ax, 0.5, 0.5, sprintf('%s\nn.s.', groups(g).label), ...
                    'HorizontalAlignment', 'center', 'Units', 'normalized');
                axis(ax, 'off');
            end
        end
    end

    % Title
    if ~isempty(opts.Title)
        pf2_base.external.suptitle(fig, opts.Title);
    else
        pf2_base.external.suptitle(fig, sprintf('Topo: %s (%s, %s=%.2f)', ...
            pf2_base.plot.escapeTeX(opts.InfoVar), opts.CorrType, ...
            opts.SigType, opts.SigThreshold));
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
% Determine whether to show legend on this subplot
    switch lower(mode)
        case 'last',  tf = (idx == total);
        case 'first', tf = (idx == 1);
        case 'all',   tf = true;
        case 'none',  tf = false;
        otherwise,    tf = (idx == total);
    end
end


function s = emptyStats()
% Return empty stats struct
    s = struct('r', NaN, 'p', NaN, 'rho', NaN, 'pval', NaN, ...
        'N', 0, 'coefficients', [], 'q', []);
end


function [roiIdx, roiNames] = resolveROIs(groups, rois)
% Convert ROI input to numeric indices and name strings
    roiInfo = groups(1).gbyGrandBarFlat.ROI.info;
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
