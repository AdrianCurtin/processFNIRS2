function fig = plotMetrics(results, varargin)
% PLOTMETRICS Grouped bar chart comparing node-level graph metrics
%
% Displays per-node graph metrics as a grouped bar chart. Accepts a single
% computeMetrics result or a struct array (one per group/condition) for
% between-group comparison. Respects MATLAB dark mode and PlotStyle settings.
%
% Syntax:
%   fig = exploreFNIRS.graph.plotMetrics(result)
%   fig = exploreFNIRS.graph.plotMetrics(results, 'Metric', 'betweenness')
%   fig = exploreFNIRS.graph.plotMetrics(results, 'GroupLabels', {'Rest','Task'})
%
% Inputs:
%   results - Single computeMetrics result struct, or struct array for
%             multi-group comparison
%
% Name-Value Parameters:
%   Metric      - Which metric to plot: 'degree' (default), 'strength',
%                 'clustering', 'betweenness', 'localEfficiency', 'hubScore'
%   GroupLabels - Cell array of group names (default: 'Group 1', 'Group 2', ...)
%   Title       - Figure title (default: auto)
%   Visible     - 'on' (default) or 'off'
%   SavePath    - File path to save figure
%   SaveWidth   - Width in pixels (default: 800)
%   SaveHeight  - Height in pixels (default: 400)
%   SaveDPI     - Resolution (default: 150)
%
% Outputs:
%   fig - Figure handle
%
% Example:
%   metrics = exploreFNIRS.graph.computeMetrics(conn);
%   fig = exploreFNIRS.graph.plotMetrics(metrics, 'Metric', 'betweenness');
%
% See also: exploreFNIRS.graph.computeMetrics, exploreFNIRS.graph.plotNetwork

    validMetrics = {'degree','strength','clustering','betweenness', ...
        'localEfficiency','hubScore'};

    p = inputParser;
    addRequired(p, 'results');
    addParameter(p, 'Metric', 'degree', ...
        @(x) ischar(x) && ismember(lower(x), validMetrics));
    addParameter(p, 'GroupLabels', {}, @iscell);
    addParameter(p, 'Title', '', @ischar);
    addParameter(p, 'Visible', 'on', @ischar);
    addParameter(p, 'SavePath', '', @ischar);
    addParameter(p, 'SaveWidth', 800, @isnumeric);
    addParameter(p, 'SaveHeight', 400, @isnumeric);
    addParameter(p, 'SaveDPI', 150, @isnumeric);
    parse(p, results, varargin{:});
    opts = p.Results;
    metricName = lower(opts.Metric);

    if ~isempty(opts.SavePath)
        opts.Visible = 'off';
    end

    % Ensure struct array
    if ~isstruct(results)
        error('exploreFNIRS:graph:plotMetrics', 'Input must be a struct or struct array');
    end
    nGroups = length(results);

    % Extract metric values for each group
    vals = cell(1, nGroups);
    for g = 1:nGroups
        vals{g} = extractMetricValues(results(g), metricName);
    end

    % Labels from first result
    if isfield(results(1), 'labels') && ~isempty(results(1).labels)
        nodeLabels = pf2_base.plot.escapeTeX(results(1).labels);
    else
        N = length(vals{1});
        nodeLabels = arrayfun(@(c) sprintf('Ch%d', c), 1:N, 'UniformOutput', false);
    end

    % Group labels
    if isempty(opts.GroupLabels)
        groupLabels = arrayfun(@(g) sprintf('Group %d', g), 1:nGroups, ...
            'UniformOutput', false);
    else
        groupLabels = opts.GroupLabels;
    end

    % Build data matrix [nNodes x nGroups]
    nNodes = length(vals{1});
    dataMat = zeros(nNodes, nGroups);
    for g = 1:nGroups
        v = vals{g};
        dataMat(1:length(v), g) = v(:);
    end

    % Create figure
    fig = pf2_base.plot.createFigure('Visible', opts.Visible, ...
        'Width', opts.SaveWidth, 'Height', opts.SaveHeight, ...
        'SavePath', opts.SavePath);
    sty = pf2_base.plot.PlotStyle.getDefault();
    ax = axes('Parent', fig);

    if nGroups == 1
        % Visible accent color for single-group bars
        defaultAccent = [0.0, 0.447, 0.741];  % MATLAB default blue
        bar(ax, dataMat, 'FaceColor', defaultAccent);
    else
        bar(ax, dataMat);
    end

    set(ax, 'XTick', 1:nNodes, 'XTickLabel', nodeLabels, ...
        'FontSize', sty.FontSize - 1);
    if nNodes > 10
        set(ax, 'XTickLabelRotation', 45);
    end

    ylabel(ax, formatMetricName(metricName), 'FontSize', sty.FontSize);

    if nGroups > 1
        lg = legend(ax, groupLabels, 'Location', 'best', 'FontSize', sty.FontSize - 1);
        set(lg, 'TextColor', sty.LegendTextColor, ...
            'Color', sty.LegendBgColor, 'EdgeColor', sty.LegendEdgeColor);
    end

    if ~isempty(opts.Title)
        title(ax, opts.Title, 'FontSize', sty.FontSize + 1);
    else
        title(ax, formatMetricName(metricName), 'FontSize', sty.FontSize + 1);
    end

    % Apply theme colors to axes (foreground, background, grid, etc.)
    sty.applyToAxes(ax);

    pf2_base.plot.handleSave(fig, opts);
end


function vals = extractMetricValues(result, metricName)
% Extract the appropriate vector from a computeMetrics result struct

    switch metricName
        case 'degree'
            if isfield(result, 'degree')
                vals = result.degree.degree;
            else
                error('exploreFNIRS:graph:plotMetrics', 'degree not computed');
            end
        case 'strength'
            if isfield(result, 'degree')
                vals = result.degree.strength;
            else
                error('exploreFNIRS:graph:plotMetrics', 'degree not computed');
            end
        case 'clustering'
            if isfield(result, 'clustering')
                vals = result.clustering.C;
            else
                error('exploreFNIRS:graph:plotMetrics', 'clustering not computed');
            end
        case 'betweenness'
            if isfield(result, 'betweenness')
                vals = result.betweenness.BC;
            else
                error('exploreFNIRS:graph:plotMetrics', 'betweenness not computed');
            end
        case 'localefficiency'
            if isfield(result, 'efficiency')
                vals = result.efficiency.localEfficiency;
            else
                error('exploreFNIRS:graph:plotMetrics', 'efficiency not computed');
            end
        case 'hubscore'
            if isfield(result, 'hubs')
                vals = result.hubs.hubScore;
            else
                error('exploreFNIRS:graph:plotMetrics', 'hubs not computed');
            end
    end
end


function name = formatMetricName(metricName)
% Format metric name for display
    switch metricName
        case 'degree',           name = 'Degree';
        case 'strength',         name = 'Strength';
        case 'clustering',       name = 'Clustering Coefficient';
        case 'betweenness',      name = 'Betweenness Centrality';
        case 'localefficiency',  name = 'Local Efficiency';
        case 'hubscore',         name = 'Hub Score';
        otherwise,               name = metricName;
    end
end
