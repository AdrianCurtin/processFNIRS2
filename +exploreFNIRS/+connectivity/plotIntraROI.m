function fig = plotIntraROI(result, varargin)
% PLOTINTRAAROI Visualize within-ROI coupling as bar chart or radar plot
%
% Renders the output of computeIntraROI as either a bar chart (one bar per
% ROI showing mean within-ROI coupling with variability error bars) or a
% radar/spider plot with ROI names around the circumference.
%
% Syntax:
%   fig = exploreFNIRS.connectivity.plotIntraROI(result)
%   fig = exploreFNIRS.connectivity.plotIntraROI(result, 'PlotType', 'radar')
%   fig = exploreFNIRS.connectivity.plotIntraROI(result, 'SortBy', 'coupling')
%   fig = exploreFNIRS.connectivity.plotIntraROI(result, 'SavePath', 'intra.png')
%
% Inputs:
%   result - Output struct from computeIntraROI with fields:
%            .roiMetrics (struct array), .method
%
% Name-Value Parameters:
%   PlotType              - 'bar' (default) or 'radar'
%   ShowIndividualChannels - Show individual channel pair values (default: false)
%   SortBy                - Sort ROIs by 'name' (default) or 'coupling'
%   Title                 - Figure title (default: auto)
%   Visible               - 'on' (default) or 'off'
%   SavePath              - File path to save figure
%   SaveWidth             - Width in pixels (default: 700)
%   SaveHeight            - Height in pixels (default: 450)
%   SaveDPI               - Resolution (default: 150)
%
% Outputs:
%   fig - Figure handle
%
% Example:
%   result = exploreFNIRS.connectivity.computeIntraROI(processed);
%   fig = exploreFNIRS.connectivity.plotIntraROI(result, ...
%       'PlotType', 'bar', 'SortBy', 'coupling');
%
% See also: exploreFNIRS.connectivity.computeIntraROI,
%   exploreFNIRS.connectivity.plotInterROI

    p = inputParser;
    addRequired(p, 'result', @isstruct);
    addParameter(p, 'PlotType', 'bar', @(v) ischar(v) && ismember(lower(v), {'bar', 'radar'}));
    addParameter(p, 'ShowIndividualChannels', false, @islogical);
    addParameter(p, 'SortBy', 'name', @(v) ischar(v) && ismember(lower(v), {'name', 'coupling'}));
    addParameter(p, 'Title', '', @ischar);
    addParameter(p, 'Visible', 'on', @ischar);
    addParameter(p, 'SavePath', '', @ischar);
    addParameter(p, 'SaveWidth', 700, @isnumeric);
    addParameter(p, 'SaveHeight', 450, @isnumeric);
    addParameter(p, 'SaveDPI', 150, @isnumeric);
    addParameter(p, 'TightLayout', false, @islogical);
    parse(p, result, varargin{:});
    opts = p.Results;

    metrics = result.roiMetrics;
    nROIs = length(metrics);

    % Extract values
    roiNames = {metrics.roiName};
    meanVals = [metrics.meanCoupling];
    sdVals = [metrics.sdCoupling];

    % Sort
    switch lower(opts.SortBy)
        case 'coupling'
            [meanVals, sortIdx] = sort(meanVals, 'descend');
            sdVals = sdVals(sortIdx);
            roiNames = roiNames(sortIdx);
            metrics = metrics(sortIdx);
        case 'name'
            [roiNames, sortIdx] = sort(roiNames);
            meanVals = meanVals(sortIdx);
            sdVals = sdVals(sortIdx);
            metrics = metrics(sortIdx);
    end

    % Create figure
    fig = pf2_base.plot.createFigure('Visible', opts.Visible, ...
        'SavePath', opts.SavePath, ...
        'Width', opts.SaveWidth, 'Height', opts.SaveHeight);

    switch lower(opts.PlotType)
        case 'bar'
            ax = axes('Parent', fig);
            plotBar(ax, roiNames, meanVals, sdVals, metrics, opts);
        case 'radar'
            ax = axes('Parent', fig);
            plotRadar(ax, roiNames, meanVals, nROIs, opts);
    end

    % Apply style
    sty = pf2_base.plot.PlotStyle.getDefault();
    sty.applyToAxes(ax);

    % Title
    if ~isempty(opts.Title)
        title(ax, opts.Title);
    else
        title(ax, sprintf('Within-ROI Coupling (%s)', result.method));
    end

    % Save
    pf2_base.plot.handleSave(fig, opts);
end


function plotBar(ax, roiNames, meanVals, sdVals, metrics, opts)
% Bar chart with one bar per ROI

    nROIs = length(roiNames);
    cmap = lines(nROIs);

    hold(ax, 'on');

    for r = 1:nROIs
        bar(ax, r, meanVals(r), 0.6, ...
            'FaceColor', cmap(r, :), 'EdgeColor', 'none', 'FaceAlpha', 0.7);
    end

    % Error bars from channel pair variability (SD)
    errorbar(ax, 1:nROIs, meanVals, sdVals, 'k.', ...
        'LineWidth', 1.2, 'CapSize', 6);

    % Individual channel pair values
    if opts.ShowIndividualChannels
        for r = 1:nROIs
            mat = metrics(r).matrix;
            nCh = size(mat, 1);
            utMask = triu(true(nCh), 1);
            utVals = mat(utMask);
            utVals = utVals(~isnan(utVals));
            if ~isempty(utVals)
                jitter = (rand(length(utVals), 1) - 0.5) * 0.2;
                plot(ax, r + jitter, utVals, 'o', ...
                    'MarkerSize', 3, 'MarkerFaceColor', cmap(r, :) * 0.7, ...
                    'MarkerEdgeColor', 'none');
            end
        end
    end

    hold(ax, 'off');

    set(ax, 'XTick', 1:nROIs, 'XTickLabel', pf2_base.plot.escapeTeX(roiNames), 'XTickLabelRotation', 30);
    xlabel(ax, 'ROI');
    ylabel(ax, 'Mean Within-ROI Coupling');
    xlim(ax, [0.4, nROIs + 0.6]);
    box(ax, 'on');
end


function plotRadar(ax, roiNames, meanVals, nROIs, ~)
% Radar/spider plot with ROI names around the circumference

    % Compute angles for each ROI
    angles = linspace(0, 2*pi, nROIs + 1);
    angles = angles(1:end-1);

    % Normalize values to [0, 1] range for radar display
    minVal = min(meanVals);
    maxVal = max(meanVals);
    if maxVal == minVal
        normVals = ones(size(meanVals)) * 0.5;
    else
        normVals = (meanVals - minVal) / (maxVal - minVal);
    end

    % Close the polygon
    anglesPlot = [angles, angles(1)];
    normPlot = [normVals, normVals(1)];

    hold(ax, 'on');

    % Draw grid circles
    gridLevels = [0.25, 0.5, 0.75, 1.0];
    gridClr = sty.GridColor;
    for g = gridLevels
        theta = linspace(0, 2*pi, 100);
        plot(ax, g * cos(theta), g * sin(theta), '-', ...
            'Color', gridClr, 'LineWidth', 0.5);
    end

    % Draw radial lines
    for r = 1:nROIs
        plot(ax, [0, cos(angles(r))], [0, sin(angles(r))], '-', ...
            'Color', gridClr, 'LineWidth', 0.5);
    end

    % Plot data polygon
    xData = normPlot .* cos(anglesPlot);
    yData = normPlot .* sin(anglesPlot);
    fill(ax, xData, yData, [0.3, 0.6, 0.9], ...
        'FaceAlpha', 0.3, 'EdgeColor', [0.2, 0.4, 0.7], 'LineWidth', 1.5);
    plot(ax, xData, yData, 'o-', ...
        'Color', [0.2, 0.4, 0.7], 'MarkerFaceColor', [0.2, 0.4, 0.7], ...
        'MarkerSize', 5, 'LineWidth', 1.5);

    % Label each ROI
    labelOffset = 1.15;
    for r = 1:nROIs
        lx = labelOffset * cos(angles(r));
        ly = labelOffset * sin(angles(r));
        ha = 'center';
        if cos(angles(r)) > 0.1
            ha = 'left';
        elseif cos(angles(r)) < -0.1
            ha = 'right';
        end
        text(ax, lx, ly, sprintf('%s (%.2f)', pf2_base.plot.escapeTeX(roiNames{r}), meanVals(r)), ...
            'HorizontalAlignment', ha, 'FontSize', 9);
    end

    hold(ax, 'off');

    axis(ax, 'equal');
    axis(ax, 'off');
    xlim(ax, [-1.4, 1.4]);
    ylim(ax, [-1.4, 1.4]);
end
