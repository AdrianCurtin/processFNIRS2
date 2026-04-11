classdef PlotProxy
% PLOTPROXY Grammar-of-graphics style plot API for Experiment
%
% Returned by Experiment.plot, provides .bar(), .temporal(), .scatter()
% methods that accept dimension mapping parameters (X, Color, SubplotRows,
% SubplotCols) with support for interaction terms (e.g., 'Condition:Group').
%
% The proxy holds a reference to the Experiment and orchestrates:
%   filter -> groupby -> aggregate -> layout -> render -> restore
%
% Syntax:
%   fig = ex.plot.bar('X', 'Condition', 'Color', 'Group', 'Channels', 5)
%   fig = ex.plot.temporal('Color', 'Group', 'Channels', 1:5)
%   [fig, stats] = ex.plot.scatter('X', 'reactionTime', 'Color', 'Group')
%
% Dimension Mapping:
%   X           - Variable for X-axis categories (bar/scatter)
%                 Supports interaction terms: 'Condition:Group' creates
%                 combined xtick labels like 'TaskA:Control'
%   Color       - Variable mapped to line/bar color (legend entries)
%                 Supports interaction terms: 'Condition:Group'
%   SubplotRows - Variable for faceting into subplot rows
%   SubplotCols - Variable for faceting into subplot columns
%
% Common Parameters:
%   Channels       - Channel indices (default: all)
%   Biomarkers     - Cell array of biomarker names (default: {'HbO','HbR'})
%   Biomarker      - Single biomarker (for bar/scatter; default: 'HbO')
%   Filter         - exploreFNIRS.core.Filter object for data selection
%   ErrorType      - 'SEM' (default), 'SD', or 'none'
%   SharedYAxis    - true (default) or false
%   TimeWindow     - [start, end] seconds (bar only)
%   ShowIndividual - Show individual data points (bar only)
%   FitLine        - Show regression line (scatter only)
%   InfoVar        - X-axis info variable (scatter only)
%   Title          - Figure title
%   Stats          - Return stats struct (default: false)
%   AvgMode        - Override averaging mode: 'hierarchy', 'flat', 'none'
%   Baseline       - Override baseline window: [start, end] seconds
%   UseBaseline    - Override baseline correction: true or false
%   ResampleRate   - Override resample rate: seconds per bin
%   TaskStart      - Override task onset time: seconds
%   Visible        - 'on' or 'off'
%   SavePath       - File path to save
%   SaveWidth      - Width in pixels
%   SaveHeight     - Height in pixels
%   SaveDPI        - Resolution
%
% Example:
%   ex = exploreFNIRS.core.Experiment(data);
%   fig = ex.plot.bar('X', 'Condition:Group', 'Channels', 1:5);
%   fig = ex.plot.temporal('Color', 'Group', 'SubplotRows', 'Condition', ...
%       'Channels', 5, 'Biomarkers', {'HbO','HbR'});
%   [fig, stats] = ex.plot.scatter('X', 'reactionTime', 'Color', 'Group', ...
%       'Channels', 5, 'FitLine', true);
%
% See also: exploreFNIRS.core.Experiment, exploreFNIRS.core.Filter

    properties (SetAccess = private)
        experiment  % Handle to parent Experiment
    end

    methods

        function obj = PlotProxy(experiment)
        % PLOTPROXY Create proxy linked to an Experiment
            obj.experiment = experiment;
        end


        function [figs, stats] = bar(obj, varargin)
        % BAR Dimension-mapped bar chart
        %
        %   fig = ex.plot.bar('X', 'Condition', 'Color', 'Group')
        %   fig = ex.plot.bar('X', 'Condition:Group', 'Channels', 5)
        %   figs = ex.plot.bar('X', 'Condition', 'Figure', 'Group')

            [dimMap, plotOpts, filterObj] = parseDimArgs('bar', varargin{:});
            bio = plotOpts.Biomarker;

            [groups, plotOpts] = obj.orchestrate(dimMap, filterObj, plotOpts);
            cleanup = onCleanup(@() obj.restoreExperiment()); %#ok<NASGU>

            % Auto-expand groups by time bins
            if ~isempty(groups) && ~isempty(groups(1).gbyGrandBarFlat) && ...
                    length(groups(1).gbyGrandBarFlat.time) > 1
                groups = exploreFNIRS.core.expandGroupsByTime(groups);
                if isempty(dimMap.X)
                    dimMap.X = 'Time';
                elseif ~contains(dimMap.X, 'Time')
                    dimMap.X = ['Time:' dimMap.X];
                end
            end

            figSplits = splitByFigure(groups, dimMap.Figure);

            figs = gobjects(length(figSplits), 1);
            stats = [];
            sty = pf2_base.plot.PlotStyle.getDefault();

            for fIdx = 1:length(figSplits)
                fs = figSplits(fIdx);
                fig = createPlotFigure(fs.groups, dimMap, plotOpts);

                layout = exploreFNIRS.core.buildLayout( ...
                    fs.groups, dimMap, plotOpts.Channels, {bio});
                axHandles = gobjects(layout.nRows, layout.nCols);

                for r = 1:layout.nRows
                    for c = 1:layout.nCols
                        cellIdx = sub2ind([layout.nCols, layout.nRows], c, r);
                        cl = layout.cells(cellIdx);
                        spIdx = (r - 1) * layout.nCols + c;
                        if layout.nRows * layout.nCols > 1
                            ax = subplot(layout.nRows, layout.nCols, spIdx, 'Parent', fig);
                        else
                            ax = axes('Parent', fig);
                        end
                        axHandles(r, c) = ax;

                        renderOpts = struct( ...
                            'ErrorType', plotOpts.ErrorType, ...
                            'ShowIndividual', plotOpts.ShowIndividual, ...
                            'TimeWindow', plotOpts.TimeWindow, ...
                            'Colors', plotOpts.Colors);
                        exploreFNIRS.core.renderBar(ax, fs.groups, cl.groupIdx, ...
                            dimMap.X, dimMap.Color, bio, plotOpts.Channels, renderOpts);

                        titleParts = {};
                        if ~isempty(cl.rowLabel), titleParts{end+1} = cl.rowLabel; end
                        if ~isempty(cl.colLabel), titleParts{end+1} = cl.colLabel; end
                        if ~isempty(titleParts), title(ax, pf2_base.plot.escapeTeX(strjoin(titleParts, ' | '))); end
                        ylabel(ax, sprintf('%s (%s)', bio, getUnitsLabel(fs.groups)));
                        sty.applyToAxes(ax);
                    end
                end

                if plotOpts.SharedYAxis, enforceSharedYAxis(axHandles); end
                figTitle = buildFigureTitle(plotOpts.Title, fs.label);
                if ~isempty(figTitle), pf2_base.external.suptitle(fig, figTitle); end
                sty.applyToFigure(fig);
                pf2_base.plot.handleSave(fig, plotOpts);
                figs(fIdx) = fig;
            end

            if length(figs) == 1, figs = figs(1); end
        end


        function [figs, stats] = temporal(obj, varargin)
        % TEMPORAL Dimension-mapped temporal plot
        %
        %   fig = ex.plot.temporal('Color', 'Group', 'Channels', 5)
        %   figs = ex.plot.temporal('Color', 'Condition', 'Figure', 'Group')

            [dimMap, plotOpts, filterObj] = parseDimArgs('temporal', varargin{:});
            biomarkers = plotOpts.Biomarkers;
            nBioM = length(biomarkers);

            [groups, plotOpts] = obj.orchestrate(dimMap, filterObj, plotOpts);
            cleanup = onCleanup(@() obj.restoreExperiment()); %#ok<NASGU>
            figSplits = splitByFigure(groups, dimMap.Figure);

            figs = gobjects(length(figSplits), 1);
            stats = [];
            sty = pf2_base.plot.PlotStyle.getDefault();

            for fIdx = 1:length(figSplits)
                fs = figSplits(fIdx);
                fig = createPlotFigure(fs.groups, dimMap, plotOpts);

                layout = exploreFNIRS.core.buildLayout( ...
                    fs.groups, dimMap, plotOpts.Channels, biomarkers);
                totalCols = layout.nCols * nBioM;
                totalRows = layout.nRows;

                allHandles = [];
                allEntries = {};
                axHandles = gobjects(totalRows, totalCols);

                for r = 1:layout.nRows
                    for c = 1:layout.nCols
                        cellIdx = sub2ind([layout.nCols, layout.nRows], c, r);
                        cl = layout.cells(cellIdx);

                        for bIdx = 1:nBioM
                            col = (c - 1) * nBioM + bIdx;
                            spIdx = (r - 1) * totalCols + col;
                            if totalRows * totalCols > 1
                                ax = subplot(totalRows, totalCols, spIdx, 'Parent', fig);
                            else
                                ax = axes('Parent', fig);
                            end
                            axHandles(r, col) = ax;

                            renderOpts = struct( ...
                                'ErrorType', plotOpts.ErrorType, ...
                                'XLim', plotOpts.XLim, ...
                                'YLim', plotOpts.YLim, ...
                                'Colors', plotOpts.Colors);
                            [lh, le] = exploreFNIRS.core.renderTemporal( ...
                                ax, fs.groups, cl.groupIdx, dimMap.Color, ...
                                biomarkers{bIdx}, plotOpts.Channels, renderOpts);

                            titleParts = {biomarkers{bIdx}};
                            if ~isempty(cl.rowLabel), titleParts{end+1} = cl.rowLabel; end
                            if ~isempty(cl.colLabel), titleParts{end+1} = cl.colLabel; end
                            title(ax, pf2_base.plot.escapeTeX(strjoin(titleParts, ' | ')));

                            if r == layout.nRows && c == layout.nCols && bIdx == nBioM
                                allHandles = lh;
                                allEntries = le;
                            end
                        end
                    end
                end

                if plotOpts.SharedYAxis, enforceSharedYAxis(axHandles); end
                if ~isempty(allHandles)
                    validAx = axHandles(end);
                    if isvalid(validAx)
                        legend(validAx, allHandles, allEntries, ...
                            'Location', 'best', 'FontSize', sty.LegendFontSize);
                    end
                end
                figTitle = buildFigureTitle(plotOpts.Title, fs.label);
                if ~isempty(figTitle), pf2_base.external.suptitle(fig, figTitle); end
                sty.applyToFigure(fig);
                pf2_base.plot.handleSave(fig, plotOpts);
                figs(fIdx) = fig;
            end

            if length(figs) == 1, figs = figs(1); end
        end


        function [figs, stats] = scatter(obj, varargin)
        % SCATTER Dimension-mapped scatter plot
        %
        %   [fig, stats] = ex.plot.scatter('X', 'reactionTime', ...
        %       'Color', 'Group', 'Channels', 5, 'FitLine', true)
        %   figs = ex.plot.scatter('X', 'reactionTime', 'Figure', 'Group')

            [dimMap, plotOpts, filterObj] = parseDimArgs('scatter', varargin{:});
            infoVar = plotOpts.InfoVar;
            if isempty(infoVar)
                error('exploreFNIRS:core:PlotProxy:scatter', ...
                    'InfoVar (or X) is required for scatter plots.');
            end
            bio = plotOpts.Biomarker;

            [groups, plotOpts] = obj.orchestrate(dimMap, filterObj, plotOpts);
            cleanup = onCleanup(@() obj.restoreExperiment()); %#ok<NASGU>

            % Auto-expand groups by time bins
            if ~isempty(groups) && ~isempty(groups(1).gbyGrandBarFlat) && ...
                    length(groups(1).gbyGrandBarFlat.time) > 1
                groups = exploreFNIRS.core.expandGroupsByTime(groups);
                if isempty(dimMap.Color)
                    dimMap.Color = 'Time';
                elseif ~contains(dimMap.Color, 'Time')
                    dimMap.Color = ['Time:' dimMap.Color];
                end
            end

            figSplits = splitByFigure(groups, dimMap.Figure);

            figs = gobjects(length(figSplits), 1);
            allStats = struct([]);
            sty = pf2_base.plot.PlotStyle.getDefault();

            for fIdx = 1:length(figSplits)
                fs = figSplits(fIdx);
                fig = createPlotFigure(fs.groups, dimMap, plotOpts);

                layout = exploreFNIRS.core.buildLayout( ...
                    fs.groups, dimMap, plotOpts.Channels, {bio});
                axHandles = gobjects(layout.nRows, layout.nCols);

                for r = 1:layout.nRows
                    for c = 1:layout.nCols
                        cellIdx = sub2ind([layout.nCols, layout.nRows], c, r);
                        cl = layout.cells(cellIdx);
                        spIdx = (r - 1) * layout.nCols + c;
                        if layout.nRows * layout.nCols > 1
                            ax = subplot(layout.nRows, layout.nCols, spIdx, 'Parent', fig);
                        else
                            ax = axes('Parent', fig);
                        end
                        axHandles(r, c) = ax;

                        renderOpts = struct( ...
                            'FitLine', plotOpts.FitLine, ...
                            'CorrType', plotOpts.CorrType, ...
                            'Colors', plotOpts.Colors);
                        [lh, le, cellStats] = exploreFNIRS.core.renderScatter( ...
                            ax, fs.groups, cl.groupIdx, dimMap.Color, ...
                            bio, plotOpts.Channels, infoVar, renderOpts);

                        titleParts = {};
                        if ~isempty(cl.rowLabel), titleParts{end+1} = cl.rowLabel; end
                        if ~isempty(cl.colLabel), titleParts{end+1} = cl.colLabel; end
                        if ~isempty(titleParts), title(ax, pf2_base.plot.escapeTeX(strjoin(titleParts, ' | '))); end
                        if ~isempty(lh), legend(ax, lh, le, 'Location', 'best', 'FontSize', 8); end

                        if ~isempty(cellStats)
                            if isempty(allStats)
                                allStats = cellStats;
                            else
                                allStats = [allStats, cellStats]; %#ok<AGROW>
                            end
                        end
                    end
                end

                if plotOpts.SharedYAxis, enforceSharedYAxis(axHandles); end
                figTitle = buildFigureTitle(plotOpts.Title, fs.label);
                if ~isempty(figTitle), pf2_base.external.suptitle(fig, figTitle); end
                sty.applyToFigure(fig);
                pf2_base.plot.handleSave(fig, plotOpts);
                figs(fIdx) = fig;
            end

            if length(figs) == 1, figs = figs(1); end
            stats = allStats;
        end

    end

    methods (Access = private)

        function [groups, plotOpts] = orchestrate(obj, dimMap, filterObj, plotOpts)
        % ORCHESTRATE Save state, apply filter, groupby, aggregate, set defaults

            ex = obj.experiment;

            % Save state for restore
            ex.saveState();

            % Apply aggregation overrides to settings (restored on cleanup)
            if ~isempty(plotOpts.AvgMode)
                ex.settings.avgMode = plotOpts.AvgMode;
            end
            if ~isempty(plotOpts.Baseline)
                ex.settings.baseline = plotOpts.Baseline;
            end
            if ~isempty(plotOpts.UseBaseline)
                ex.settings.useBaseline = plotOpts.UseBaseline;
            end
            if ~isempty(plotOpts.ResampleRate)
                ex.settings.resampleRate = plotOpts.ResampleRate;
            end
            if ~isempty(plotOpts.TaskStart)
                ex.settings.taskStart = plotOpts.TaskStart;
            end
            if ~isempty(plotOpts.TaskEnd)
                ex.settings.taskEnd = plotOpts.TaskEnd;
            end
            if ~isempty(plotOpts.StatWindow)
                ex.settings.statWindow = plotOpts.StatWindow;
            end

            % Apply filter if provided
            if ~isempty(filterObj) && ~filterObj.isEmpty()
                idx = filterObj.apply(ex.dataTable);
                ex.narrowSelection(idx);
            end

            % Derive groupby vars from dimension mapping
            gbyVars = deriveGroupByVars(dimMap);

            % Only re-groupby if vars differ from current state
            if ~isempty(gbyVars)
                ex.groupby(gbyVars);
                ex.aggregate();
            elseif ~ex.getIsAggregated()
                error('exploreFNIRS:core:PlotProxy', ...
                    ['No dimension variables specified and Experiment is not ' ...
                     'aggregated. Either map variables (X, Color, SubplotRows, ' ...
                     'SubplotCols) or call groupby() and aggregate() first.']);
            end

            groups = ex.getGroups();

            % Resolve named ColorScheme to object
            if ~isempty(plotOpts.ColorScheme)
                csVal = plotOpts.ColorScheme;
                if ischar(csVal) || isstring(csVal)
                    name = char(csVal);
                    if ~isfield(ex.colorSchemes, name)
                        error('exploreFNIRS:core:PlotProxy:orchestrate', ...
                            'Unknown color scheme: "%s". Available: %s', ...
                            name, strjoin(fieldnames(ex.colorSchemes), ', '));
                    end
                    csVal = ex.colorSchemes.(name);
                end
                if isempty(plotOpts.Colors)
                    plotOpts.Colors = csVal;
                end
            end

            % Auto-inject colorScheme from Experiment if Colors not set
            if isempty(plotOpts.Colors) && ~isempty(ex.colorScheme)
                plotOpts.Colors = ex.colorScheme;
            end

            % Default channels if empty
            if isempty(plotOpts.Channels) && ~isempty(groups) && ...
                    ~isempty(groups(1).gbyGrand)
                nCh = size(groups(1).gbyGrand.HbO.Mean, 2);
                plotOpts.Channels = 1:nCh;
            end
        end


        function restoreExperiment(obj)
        % Restore experiment state from snapshot
            obj.experiment.restoreState();
        end

    end
end


%% Package-level helpers

function [dimMap, plotOpts, filterObj] = parseDimArgs(plotType, varargin)
% Parse dimension mapping and common plot options

    p = inputParser;
    p.KeepUnmatched = false;

    % Dimension mapping
    addParameter(p, 'X', '', @ischar);
    addParameter(p, 'Color', '', @ischar);
    addParameter(p, 'SubplotRows', '', @ischar);
    addParameter(p, 'SubplotCols', '', @ischar);
    addParameter(p, 'Figure', '', @ischar);

    % Data dimensions
    addParameter(p, 'Channels', [], @isnumeric);
    addParameter(p, 'Biomarkers', {'HbO','HbR'}, @iscell);
    addParameter(p, 'Biomarker', 'HbO', @ischar);

    % Filter
    addParameter(p, 'Filter', [], @(x) isempty(x) || isa(x, 'exploreFNIRS.core.Filter'));

    % Common options
    addParameter(p, 'ErrorType', 'SEM', @ischar);
    addParameter(p, 'SharedYAxis', true, @islogical);
    addParameter(p, 'Title', '', @ischar);
    addParameter(p, 'Visible', 'on', @ischar);
    addParameter(p, 'SavePath', '', @ischar);
    addParameter(p, 'SaveWidth', 600, @isnumeric);
    addParameter(p, 'SaveHeight', 400, @isnumeric);
    addParameter(p, 'SaveDPI', 150, @isnumeric);
    addParameter(p, 'TightLayout', false, @islogical);

    % Colors
    addParameter(p, 'Colors', [], @(x) isempty(x) || isnumeric(x) || ischar(x) || isstring(x) || isa(x, 'function_handle') || isa(x, 'exploreFNIRS.core.ColorScheme'));

    % Named color scheme (string name or ColorScheme object)
    addParameter(p, 'ColorScheme', [], @(x) isempty(x) || ischar(x) || isstring(x) || isa(x, 'exploreFNIRS.core.ColorScheme'));

    % Bar/stats-specific
    addParameter(p, 'TimeWindow', [], @isnumeric);
    addParameter(p, 'StatWindow', [], @isnumeric);
    addParameter(p, 'ShowIndividual', false, @islogical);

    % Temporal-specific
    addParameter(p, 'XLim', [], @isnumeric);
    addParameter(p, 'YLim', [], @isnumeric);

    % Scatter-specific
    addParameter(p, 'InfoVar', '', @ischar);
    addParameter(p, 'FitLine', false, @islogical);
    addParameter(p, 'CorrType', 'Pearson', @ischar);
    addParameter(p, 'Stats', false, @islogical);

    % Aggregation overrides (forwarded to Experiment.settings temporarily)
    addParameter(p, 'AvgMode', '', @ischar);          % 'hierarchy', 'flat', 'none'
    addParameter(p, 'Baseline', [], @isnumeric);       % [start, end] seconds
    addParameter(p, 'UseBaseline', [], @(x) isempty(x) || islogical(x));
    addParameter(p, 'ResampleRate', [], @isnumeric);   % seconds per bin
    addParameter(p, 'TaskStart', [], @isnumeric);      % task onset time
    addParameter(p, 'TaskEnd', [], @isnumeric);        % task end time

    parse(p, varargin{:});
    r = p.Results;

    % For scatter, X maps to InfoVar
    if strcmp(plotType, 'scatter') && ~isempty(r.X) && isempty(r.InfoVar)
        r.InfoVar = r.X;
        r.X = '';  % X is not a groupby var for scatter
    end

    dimMap = struct( ...
        'X', r.X, ...
        'Color', r.Color, ...
        'SubplotRows', r.SubplotRows, ...
        'SubplotCols', r.SubplotCols, ...
        'Figure', r.Figure);

    % Force headless when saving
    vis = r.Visible;
    if ~isempty(r.SavePath)
        vis = 'off';
    end

    plotOpts = struct( ...
        'Channels', r.Channels, ...
        'Biomarkers', {r.Biomarkers}, ...
        'Biomarker', r.Biomarker, ...
        'ErrorType', r.ErrorType, ...
        'SharedYAxis', r.SharedYAxis, ...
        'Title', r.Title, ...
        'Visible', vis, ...
        'SavePath', r.SavePath, ...
        'SaveWidth', r.SaveWidth, ...
        'SaveHeight', r.SaveHeight, ...
        'SaveDPI', r.SaveDPI, ...
        'TimeWindow', r.TimeWindow, ...
        'StatWindow', r.StatWindow, ...
        'ShowIndividual', r.ShowIndividual, ...
        'XLim', r.XLim, ...
        'YLim', r.YLim, ...
        'InfoVar', r.InfoVar, ...
        'FitLine', r.FitLine, ...
        'CorrType', r.CorrType, ...
        'Stats', r.Stats, ...
        'AvgMode', r.AvgMode, ...
        'Baseline', r.Baseline, ...
        'UseBaseline', r.UseBaseline, ...
        'ResampleRate', r.ResampleRate, ...
        'TaskStart', r.TaskStart, ...
        'TaskEnd', r.TaskEnd, ...
        'Colors', r.Colors, ...
        'ColorScheme', r.ColorScheme, ...
        'TightLayout', r.TightLayout);

    filterObj = r.Filter;
    if isempty(filterObj)
        filterObj = exploreFNIRS.core.Filter();
    end

    % Apply filter's channel/biomarker/time to plotOpts
    if filterObj.hasChannels() && isempty(r.Channels)
        plotOpts.Channels = filterObj.channels;
    end
    if filterObj.hasBiomarkers()
        if strcmp(plotType, 'temporal')
            plotOpts.Biomarkers = filterObj.biomarkers;
        else
            plotOpts.Biomarker = filterObj.biomarkers{1};
        end
    end
    if filterObj.hasTimeWindow() && isempty(r.TimeWindow)
        plotOpts.TimeWindow = filterObj.timeWindow;
    end
end


function gbyVars = deriveGroupByVars(dimMap)
% Derive the set of groupby variables from the dimension mapping
    gbyVars = {};

    dims = {dimMap.X, dimMap.Color, dimMap.SubplotRows, dimMap.SubplotCols, dimMap.Figure};

    for i = 1:length(dims)
        varSpec = dims{i};
        if isempty(varSpec), continue; end

        if contains(varSpec, ':')
            % Interaction term: split into individual variables
            parts = strsplit(varSpec, ':');
            for j = 1:length(parts)
                if ~ismember(parts{j}, gbyVars)
                    gbyVars{end+1} = parts{j}; %#ok<AGROW>
                end
            end
        else
            if ~ismember(varSpec, gbyVars)
                gbyVars{end+1} = varSpec; %#ok<AGROW>
            end
        end
    end
end


function enforceSharedYAxis(axHandles)
% Set all axes to the same Y limits
    allLims = [];
    for i = 1:numel(axHandles)
        if isvalid(axHandles(i)) && ~isempty(get(axHandles(i), 'Children'))
            yl = ylim(axHandles(i));
            allLims = [allLims; yl]; %#ok<AGROW>
        end
    end
    if ~isempty(allLims)
        globalYLim = [min(allLims(:, 1)), max(allLims(:, 2))];
        for i = 1:numel(axHandles)
            if isvalid(axHandles(i))
                ylim(axHandles(i), globalYLim);
            end
        end
    end
end


function lbl = getUnitsLabel(groups)
    if ~isempty(groups) && ~isempty(groups(1).gbyGrand) && ...
            isfield(groups(1).gbyGrand, 'units')
        lbl = groups(1).gbyGrand.units;
    else
        lbl = '\DeltaHb';
    end
end


function figSplits = splitByFigure(groups, figVar)
% Split groups by Figure variable; returns struct array with .groups, .label
    if isempty(figVar)
        figSplits.groups = groups;
        figSplits.label = '';
        return;
    end

    nGroups = length(groups);
    vals = cell(1, nGroups);
    for g = 1:nGroups
        T = groups(g).gbyTables;
        if contains(figVar, ':')
            parts = strsplit(figVar, ':');
            subVals = cell(1, length(parts));
            for p = 1:length(parts)
                v = T.(parts{p})(1);
                if isnumeric(v)
                    subVals{p} = num2str(v);
                else
                    subVals{p} = char(string(v));
                end
            end
            vals{g} = strjoin(subVals, ':');
        else
            if ~ismember(figVar, T.Properties.VariableNames)
                vals{g} = '';
                continue;
            end
            v = T.(figVar)(1);
            if isnumeric(v)
                vals{g} = num2str(v);
            else
                vals{g} = char(string(v));
            end
        end
    end

    uniqueVals = unique(vals, 'stable');
    nFigs = length(uniqueVals);
    figSplits = struct([]);
    for f = 1:nFigs
        mask = strcmp(vals, uniqueVals{f});
        figSplits(f).groups = groups(mask);
        figSplits(f).label = uniqueVals{f};
    end
end


function fig = createPlotFigure(groups, dimMap, plotOpts)
% Create a figure with size scaled by subplot layout
    layout = exploreFNIRS.core.buildLayout( ...
        groups, dimMap, plotOpts.Channels, {});
    figW = plotOpts.SaveWidth * max(1, layout.nCols);
    figH = plotOpts.SaveHeight * max(1, layout.nRows * 0.7);
    fig = pf2_base.plot.createFigure( ...
        'Visible', plotOpts.Visible, ...
        'Width', figW, 'Height', figH, ...
        'SavePath', plotOpts.SavePath);
end


function t = buildFigureTitle(userTitle, figLabel)
% Build figure title with optional figure-split label
    if ~isempty(userTitle) && ~isempty(figLabel)
        t = sprintf('%s (%s)', userTitle, figLabel);
    elseif ~isempty(userTitle)
        t = userTitle;
    elseif ~isempty(figLabel)
        t = figLabel;
    else
        t = '';
    end
    if ~isempty(t)
        t = pf2_base.plot.escapeTeX(t);
    end
end
