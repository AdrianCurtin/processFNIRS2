function fig = plotTemporal(groups, varargin)
% PLOTTEMPORAL Headless temporal plot from grouped/aggregated experiment data
%
% Creates publication-ready time-series plots showing the hemodynamic
% response for each group, with shaded error bands. Each channel and
% biomarker gets its own subplot — channels and biomarkers are never
% averaged. Groups are overlaid as traces within each subplot.
%
% Syntax:
%   fig = plotTemporal(groups)
%   fig = plotTemporal(groups, 'Biomarkers', {'HbO'}, 'Channels', 1:5)
%   fig = plotTemporal(groups, 'ROIs', 'all', 'Biomarkers', {'HbO'})
%   fig = plotTemporal(groups, 'SavePath', 'temporal.png')
%
% Inputs:
%   groups - Struct array from Experiment.groups (after aggregate())
%            Each element must have .gbyGrand with .HbO, .HbR, etc.
%
% Name-Value Parameters:
%   Biomarkers  - Cell array of biomarkers to plot (default: {'HbO','HbR'})
%   Channels    - Vector of channel indices (default: all channels)
%   ROIs        - ROI indices, names, or 'all' (default: [])
%                 When provided, data is read from gbyGrand.ROI instead of
%                 gbyGrand. Mutually exclusive with Channels.
%   ErrorType   - 'SEM' (default), 'SD', or 'none'
%   ShowN       - Show subject count (n=X) in legend labels (default: true)
%   Legend      - 'last' (default), 'first', 'all', or 'none'
%                 Controls which subplot(s) show the legend.
%   YLim        - [min max] y-axis limits (default: auto, shared across subplots)
%   XLim        - [min max] x-axis limits (default: auto, shared across subplots)
%   PlotBy      - Groupby variable to split subplots by (e.g., 'Condition').
%                 Creates one subplot row per PlotBy value, with within-group
%                 traces overlaid. When combined with multiple biomarkers, a
%                 separate figure is created per biomarker.
%   Title       - Figure title (default: auto-generated)
%   Visible     - 'on' (default) or 'off' for headless mode
%   SavePath    - File path to save figure (triggers headless)
%   SaveWidth   - Width in pixels (default: 800)
%   SaveHeight  - Height in pixels (default: 500)
%   SaveDPI     - Resolution (default: 150)
%   Colors      - Group color palette override (default: [] = auto)
%                 [N x 3] RGB matrix, colormap name (e.g. 'Set1', 'tab10'),
%                 or function handle @(N) returning [N x 3].
%   VLines      - Vertical annotation lines drawn on all subplots.
%                 Numeric vector of time positions (default dashed gray), or
%                 struct array with fields:
%                   .time  - (required) scalar time position
%                   .label - (optional) text label string
%                   .color - (optional) color spec (default: [0.5 0.5 0.5])
%                   .style - (optional) line style (default: '--')
%
% Layout:
%   Each channel/ROI and biomarker combination gets its own subplot.
%   Groups are overlaid as colored traces within each subplot.
%
%   - 1 biomarker: channels arranged in a square-ish grid
%   - Multiple biomarkers, no PlotBy: rows = biomarkers, columns = channels
%   - With PlotBy, 1 biomarker: rows = PlotBy values, columns = channels
%   - With PlotBy, multiple biomarkers: separate figure per biomarker,
%     rows = PlotBy values, columns = channels
%
% Outputs:
%   fig - Figure handle (or array of handles if multiple figures created)
%
% Example:
%   ex = exploreFNIRS.core.Experiment(data);
%   ex.groupby({'Group','Condition'});
%   ex.aggregate();
%
%   % All channels, HbO only
%   fig = exploreFNIRS.core.plotTemporal(ex.groups, 'Biomarkers', {'HbO'});
%
%   % Specific channels
%   fig = exploreFNIRS.core.plotTemporal(ex.groups, ...
%       'Biomarkers', {'HbO'}, 'Channels', [5, 10]);
%
%   % Multiple biomarkers with PlotBy (one figure per biomarker)
%   figs = exploreFNIRS.core.plotTemporal(ex.groups, ...
%       'Biomarkers', {'HbO','HbR'}, 'PlotBy', 'Condition');
%
%   % Vertical annotation lines (numeric = dashed gray)
%   fig = exploreFNIRS.core.plotTemporal(ex.groups, 'VLines', [0, 30]);
%
%   % Labeled VLines with custom colors and styles
%   vl = struct('time', {0, 30}, 'label', {'Onset','Offset'}, ...
%               'color', {'r','b'}, 'style', {'-','--'});
%   fig = exploreFNIRS.core.plotTemporal(ex.groups, 'VLines', vl);
%
% See also: exploreFNIRS.core.Experiment, exploreFNIRS.core.plotBar

    p = inputParser;
    addRequired(p, 'groups', @isstruct);
    addParameter(p, 'Biomarkers', {'HbO','HbR'}, @iscell);
    addParameter(p, 'Channels', [], @isnumeric);
    addParameter(p, 'ROIs', [], @(x) isnumeric(x) || islogical(x) || ischar(x) || isstring(x) || iscell(x));
    addParameter(p, 'Device', [], @(v) isempty(v) || isa(v, 'pf2.Device'));
    addParameter(p, 'ExcludeShortSeparation', true, @islogical);
    addParameter(p, 'ErrorType', 'SEM', @ischar);
    addParameter(p, 'ShowN', true, @islogical);
    addParameter(p, 'Legend', 'last', @ischar);
    addParameter(p, 'PlotBy', '', @ischar);
    addParameter(p, 'YLim', [], @isnumeric);
    addParameter(p, 'XLim', [], @isnumeric);
    addParameter(p, 'Title', '', @ischar);
    addParameter(p, 'Visible', 'on', @ischar);
    addParameter(p, 'SavePath', '', @ischar);
    addParameter(p, 'SaveWidth', 800, @isnumeric);
    addParameter(p, 'SaveHeight', 500, @isnumeric);
    addParameter(p, 'SaveDPI', 150, @isnumeric);
    addParameter(p, 'TightLayout', false, @islogical);
    addParameter(p, 'Colors', [], @(x) isempty(x) || isnumeric(x) || ischar(x) || isstring(x) || isa(x, 'function_handle') || isa(x, 'exploreFNIRS.core.ColorScheme'));
    addParameter(p, 'VLines', [], @(x) isempty(x) || isnumeric(x) || isstruct(x));
    % Overlay trial-averaged auxiliary signal(s) on a right y-axis, time-locked
    % to the same epoch grid (e.g. {'heartRate'}). Requires aggregate() to have
    % averaged the Aux (AverageAux). Drawn as dashed lines per group.
    addParameter(p, 'AuxOverlay', {}, @(x) ischar(x) || isstring(x) || iscell(x));
    parse(p, groups, varargin{:});
    opts = p.Results;

    if ~isempty(opts.SavePath)
        opts.Visible = 'off';
    end

    nGroups = length(groups);
    nBioM   = length(opts.Biomarkers);

    % Validate groups
    for g = 1:nGroups
        if isempty(groups(g).gbyGrand)
            error('exploreFNIRS:core:plotTemporal', ...
                'Group %d has no grand average. Call aggregate() first.', g);
        end
    end

    % Resolve channels/ROIs (default = all)
    if ~isempty(opts.ROIs)
        if ~isempty(opts.Channels)
            error('exploreFNIRS:core:plotTemporal', ...
                'ROIs and Channels are mutually exclusive.');
        end
        if ~isfield(groups(1).gbyGrand, 'ROI')
            error('exploreFNIRS:core:plotTemporal', ...
                'No ROI data in grand average. Define ROIs before aggregating.');
        end
        [roiIdx, roiNames] = resolveROIs(groups, opts.ROIs);
        plotItems = roiIdx;
        itemNames = roiNames;
        useROI = true;
    else
        useROI = false;
        if isempty(opts.Channels)
            nTotalCh = size(groups(1).gbyGrand.(opts.Biomarkers{1}).Mean, 2);
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

    sty = pf2_base.plot.PlotStyle.getDefault();

    % --- Determine layout ---
    hasPB = ~isempty(opts.PlotBy);
    if hasPB
        [plotByValues, subGroups, withinLabels, plotByIdx] = ...
            exploreFNIRS.core.splitGroupsByFactor(groups, opts.PlotBy);
        nPlotBy = length(plotByValues);
    end

    if hasPB && nBioM > 1
        % Separate figure per biomarker; rows = PlotBy, cols = channels
        nFigs = nBioM;
        nRows = nPlotBy;
        nCols = nItems;
        layoutType = 'plotby';
    elseif hasPB
        % Single figure; rows = PlotBy, cols = channels
        nFigs = 1;
        nRows = nPlotBy;
        nCols = nItems;
        layoutType = 'plotby';
    elseif nBioM > 1
        % Single figure; rows = biomarkers, cols = channels
        nFigs = 1;
        nRows = nBioM;
        nCols = nItems;
        layoutType = 'biomarker';
    else
        % Single figure; square grid of channels
        nFigs = 1;
        nRows = ceil(sqrt(nItems));
        nCols = ceil(nItems / nRows);
        layoutType = 'channel_grid';
    end

    figs = gobjects(nFigs, 1);

    for fIdx = 1:nFigs
        figW = opts.SaveWidth * min(nCols, 4);
        figH = opts.SaveHeight * max(nRows * 0.6, 1);

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
                else
                    bioM = opts.Biomarkers{1};
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
                    for gi = 1:nCurGroups
                        curGroups(gi).label = curWithin{gi};
                    end

                    for chI = 1:nItems
                        spIdx = (pIdx - 1) * nCols + chI;
                        ax = subplot(nRows, nCols, spIdx, 'Parent', curFig);
                        hold(ax, 'on');
                        axCount = axCount + 1;
                        allAxes(axCount) = ax;

                        [lh, le] = plotChannelOnAxes(ax, curGroups, bioM, ...
                            opts, curColors, useROI, plotItems(chI), sty);

                        plot(ax, xlim(ax), [0 0], '-', 'Color', sty.ZeroLineColor, ...
                            'LineWidth', 0.5, 'HandleVisibility', 'off');

                        if pIdx == 1
                            title(ax, pf2_base.plot.escapeTeX(itemNames{chI}));
                        end
                        if chI == 1
                            ylabel(ax, pf2_base.plot.escapeTeX(sprintf('%s: %s', opts.PlotBy, plotByValues{pIdx})));
                        end
                        xlabel(ax, 'Time (s)');

                        spTotal = nPlotBy * nItems;
                        if ~isempty(lh) && showLegend(opts.Legend, spIdx, spTotal)
                            lg = legend(ax, lh, le, 'Location', 'best', ...
                                'FontSize', sty.LegendFontSize);
                            lg.TextColor = sty.LegendTextColor;
                            lg.Color = sty.LegendBgColor;
                            lg.EdgeColor = sty.LegendEdgeColor;
                        end
                        box(ax, 'on');
                        grid(ax, 'on');
                    end
                end

            case 'biomarker'
                % rows = biomarkers, cols = channels
                if isa(opts.Colors, 'exploreFNIRS.core.ColorScheme')
                    groupColors = opts.Colors.resolve(groups);
                else
                    groupColors = exploreFNIRS.core.getGroupColors(nGroups, opts.Colors);
                end

                for bIdx = 1:nBioM
                    bioM = opts.Biomarkers{bIdx};
                    for chI = 1:nItems
                        spIdx = (bIdx - 1) * nCols + chI;
                        ax = subplot(nRows, nCols, spIdx, 'Parent', curFig);
                        hold(ax, 'on');
                        axCount = axCount + 1;
                        allAxes(axCount) = ax;

                        [lh, le] = plotChannelOnAxes(ax, groups, bioM, ...
                            opts, groupColors, useROI, plotItems(chI), sty);

                        plot(ax, xlim(ax), [0 0], '-', 'Color', sty.ZeroLineColor, ...
                            'LineWidth', 0.5, 'HandleVisibility', 'off');

                        if bIdx == 1
                            title(ax, pf2_base.plot.escapeTeX(itemNames{chI}));
                        end
                        if chI == 1
                            ylabel(ax, sprintf('%s (%s)', bioM, getUnitsLabel(groups(1))));
                        end
                        xlabel(ax, 'Time (s)');

                        spTotal = nBioM * nItems;
                        if ~isempty(lh) && showLegend(opts.Legend, spIdx, spTotal)
                            lg = legend(ax, lh, le, 'Location', 'best', ...
                                'FontSize', sty.LegendFontSize);
                            lg.TextColor = sty.LegendTextColor;
                            lg.Color = sty.LegendBgColor;
                            lg.EdgeColor = sty.LegendEdgeColor;
                        end
                        box(ax, 'on');
                        grid(ax, 'on');
                    end
                end

            case 'channel_grid'
                % Square grid of channels, 1 biomarker
                bioM = opts.Biomarkers{1};
                if isa(opts.Colors, 'exploreFNIRS.core.ColorScheme')
                    groupColors = opts.Colors.resolve(groups);
                else
                    groupColors = exploreFNIRS.core.getGroupColors(nGroups, opts.Colors);
                end

                for chI = 1:nItems
                    ax = subplot(nRows, nCols, chI, 'Parent', curFig);
                    hold(ax, 'on');
                    axCount = axCount + 1;
                    allAxes(axCount) = ax;

                    [lh, le] = plotChannelOnAxes(ax, groups, bioM, ...
                        opts, groupColors, useROI, plotItems(chI), sty);

                    plot(ax, xlim(ax), [0 0], '-', 'Color', sty.ZeroLineColor, ...
                        'LineWidth', 0.5, 'HandleVisibility', 'off');

                    title(ax, pf2_base.plot.escapeTeX(itemNames{chI}));
                    xlabel(ax, 'Time (s)');
                    if chI == 1 || mod(chI - 1, nCols) == 0
                        ylabel(ax, getUnitsLabel(groups(1)));
                    end

                    if ~isempty(lh) && showLegend(opts.Legend, chI, nItems)
                        lg = legend(ax, lh, le, 'Location', 'best', ...
                            'FontSize', sty.LegendFontSize);
                        lg.TextColor = sty.LegendTextColor;
                        lg.Color = sty.LegendBgColor;
                        lg.EdgeColor = sty.LegendEdgeColor;
                    end
                    box(ax, 'on');
                    grid(ax, 'on');
                end
        end

        % Shared axes across subplots
        allAxes = allAxes(1:axCount);
        if strcmp(layoutType, 'biomarker')
            % Link within each biomarker row (different biomarkers have
            % different Y scales, e.g. HbO vs HbR)
            for bIdx = 1:nBioM
                rowStart = (bIdx - 1) * nItems + 1;
                rowEnd   = min(bIdx * nItems, axCount);
                linkaxes(allAxes(rowStart:rowEnd), 'xy');
            end
        else
            linkaxes(allAxes, 'xy');
        end
        if ~isempty(opts.YLim), arrayfun(@(a) ylim(a, opts.YLim), allAxes); end
        if ~isempty(opts.XLim), arrayfun(@(a) xlim(a, opts.XLim), allAxes); end

        % Vertical annotation lines
        if ~isempty(opts.VLines)
            drawVLines(allAxes, opts.VLines);
        end

        % Figure title
        if ~isempty(opts.Title)
            if nFigs > 1
                pf2_base.external.suptitle(curFig, sprintf('%s — %s', opts.Title, ...
                    opts.Biomarkers{fIdx}));
            else
                pf2_base.external.suptitle(curFig, opts.Title);
            end
        elseif nFigs > 1
            pf2_base.external.suptitle(curFig, opts.Biomarkers{fIdx});
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


function [legendHandles, legendEntries] = plotChannelOnAxes(ax, curGroups, bioM, opts, groupColors, useROI, chIdx, sty)
% Plot biomarker trace for a single channel across groups on one axes
    nCurGroups = length(curGroups);
    legendEntries = {};
    legendHandles = [];

    for g = 1:nCurGroups
        ga = curGroups(g).gbyGrand;

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

        timeVec = ga.time;
        meanData = src.Mean;
        nData = src.N;

        switch upper(opts.ErrorType)
            case 'SEM'
                errData = src.SEM;
            case 'SD'
                errData = src.SD;
            case 'NONE'
                errData = zeros(size(meanData));
            otherwise
                errData = src.SEM;
        end

        if chIdx > size(meanData, 2), continue; end

        mLine = meanData(:, chIdx);
        eLine = errData(:, chIdx);

        clr = groupColors(g, :);

        % Error band
        if ~strcmpi(opts.ErrorType, 'none') && any(eLine > 0)
            upperBound = mLine + eLine;
            lowerBound = mLine - eLine;
            validIdx = ~isnan(mLine) & ~isnan(upperBound);
            if any(validIdx)
                tV = timeVec(validIdx);
                fill(ax, [tV; flipud(tV)], ...
                    [upperBound(validIdx); flipud(lowerBound(validIdx))], ...
                    clr, 'FaceAlpha', sty.ErrorAlpha, 'EdgeColor', 'none', ...
                    'HandleVisibility', 'off');
            end
        end

        % Mean line
        h = plot(ax, timeVec, mLine, '-', ...
            'Color', clr, 'LineWidth', sty.LineWidth);

        legendHandles(end+1) = h; %#ok<AGROW>

        % Legend label
        lbl = pf2_base.plot.escapeTeX(curGroups(g).label);
        if opts.ShowN && mean(nData(:, chIdx), 'all', 'omitnan') > 0
            nStr = sprintf(' (n=%d)', round(mean(nData(:, chIdx), 'all', 'omitnan')));
            lbl = [lbl, nStr]; %#ok<AGROW>
        end
        legendEntries{end+1} = lbl; %#ok<AGROW>
    end

    % Optional: overlay trial-averaged auxiliary signal(s) on a right y-axis
    if isfield(opts, 'AuxOverlay') && ~isempty(opts.AuxOverlay)
        overlayAuxOnAxes(ax, curGroups, opts.AuxOverlay, groupColors, sty);
    end
end


function overlayAuxOnAxes(ax, curGroups, auxOverlay, groupColors, sty)
% OVERLAYAUXONAXES Draw trial-averaged aux signal(s) on the right y-axis
    if ischar(auxOverlay) || isstring(auxOverlay)
        auxOverlay = cellstr(auxOverlay);
    end

    % Gather drawable series first; only switch the axes into dual-y mode if
    % there is something to draw (otherwise leave the axes untouched so
    % linkaxes/YLim behave identically to a plain plot).
    series = struct('t', {}, 'm', {}, 'clr', {});
    drawnNames = {};
    for a = 1:numel(auxOverlay)
        auxName = auxOverlay{a};
        nameDrawn = false;
        for g = 1:numel(curGroups)
            ga = curGroups(g).gbyGrand;
            if ~isfield(ga, 'Aux') || isempty(ga.Aux) || ~isstruct(ga.Aux)
                continue;
            end
            src = resolveAuxAvg(ga.Aux, auxName);
            if isempty(src) || ~isfield(src, 'Mean') || isempty(src.Mean)
                continue;
            end
            series(end+1) = struct('t', ga.time(:), 'm', src.Mean(:, 1), ...
                'clr', groupColors(g, :)); %#ok<AGROW>
            nameDrawn = true;
        end
        if nameDrawn
            drawnNames{end+1} = auxName; %#ok<AGROW>
        end
    end

    if isempty(series)
        return;   % nothing resolvable: do not alter the axes
    end

    yyaxis(ax, 'right');
    for s = 1:numel(series)
        plot(ax, series(s).t, series(s).m, '--', 'Color', series(s).clr, ...
            'LineWidth', sty.LineWidth, 'HandleVisibility', 'off');
    end
    ylabel(ax, pf2_base.plot.escapeTeX(strjoin(drawnNames, ', ')));
    yyaxis(ax, 'left');   % restore so subsequent left-axis ops are correct
end


function src = resolveAuxAvg(auxStruct, name)
% RESOLVEAUXAVG Find the averaged aux struct (Mean/SEM/N) for a base name
%   Tries the flattened '<name>_data' field first, then '<name>'.
    src = [];
    fn = fieldnames(auxStruct);
    cand = {[lower(name) '_data'], lower(name)};
    for c = 1:numel(cand)
        hit = find(strcmpi(fn, cand{c}), 1);
        if ~isempty(hit) && isstruct(auxStruct.(fn{hit}))
            src = auxStruct.(fn{hit});
            return;
        end
    end
end


function lbl = getUnitsLabel(group)
% Get units string from a group's grand average
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


function drawVLines(allAxes, vlines)
% Draw vertical annotation lines on all axes
    if isnumeric(vlines)
        % Simple numeric vector — convert to struct array
        vlines = vlines(:);
        tmp = struct('time', num2cell(vlines), ...
            'label', repmat({''}, numel(vlines), 1), ...
            'color', repmat({[0.5 0.5 0.5]}, numel(vlines), 1), ...
            'style', repmat({'--'}, numel(vlines), 1));
        vlines = tmp;
    end

    for vi = 1:numel(vlines)
        v = vlines(vi);
        xPos = v.time;

        if isfield(v, 'color') && ~isempty(v.color)
            clr = v.color;
        else
            clr = [0.5 0.5 0.5];
        end

        if isfield(v, 'style') && ~isempty(v.style)
            sty = v.style;
        else
            sty = '--';
        end

        if isfield(v, 'label') && ~isempty(v.label)
            lbl = {v.label};
        else
            lbl = {};
        end

        hasLabel = ~isempty(lbl);
        lineArgs = {'Color', clr, 'LineStyle', sty, 'LineWidth', 1};

        for ai = 1:numel(allAxes)
            ax = allAxes(ai);
            pf2_base.external.vline(ax, xPos, lineArgs, lbl, ...
                'handleVisibility', hasLabel);
        end
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
