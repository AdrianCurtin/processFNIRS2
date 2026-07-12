function [fig, stats] = plotNeuralEfficiencyCore(plotGroups, varargin)
% PLOTNEURALEFFICIENCYCORE Core renderer for neural efficiency plots
%
% Internal rendering function used by plotNeuralEfficiency and
% plotNeuralEfficiencyFromTable. Takes a struct array of pre-extracted
% data groups and handles z-scoring, centroid+error-bar rendering,
% optional scatter points, identity line, centroid arrows, regression
% lines, and stat annotations.
%
% By convention, the calling wrapper places activation on X and
% performance on Y (so efficient subjects appear above the identity
% line). The core is axis-agnostic — it plots .x on X and .y on Y.
%
% Inputs:
%   plotGroups - struct array with fields:
%     .x           [N x 1] raw values (z-scored internally)
%     .y           [N x 1] raw values (z-scored internally)
%     .label       Display name for stats annotation
%     .color       [1 x 3] RGB
%     .subjectIDs  Cell array for point labels (optional)
%     .arrowChain  Integer — items with same value get arrow-connected
%                  in their array order. NaN = no chain. (optional)
%
% Name-Value Parameters:
%   ZScoreMode   - 'pooled' (default) or 'pergroup'
%   InvertX      - Negate z-scored X values (default: false)
%   ReverseAxes  - Reverse X-axis direction (default: false)
%   ShowIdentity - Show y=x identity line (default: true)
%   ShowPoints   - Show individual data points (default: true)
%   ShowLabels   - Label points with subjectIDs (default: false)
%   ErrorType    - 'sem' (default), 'std', or 'none'
%   CentroidSize - Marker size for centroid dot (default: 120)
%   FitLine      - Per-group regression line (default: false)
%   ShowArrows   - Arrows between same-chain centroids (default: false)
%   ArrowColor   - Arrow RGB color (default: [1 1 1] white)
%   ShowQuadrantLabels - Show "High/Low Efficiency" labels (default: true)
%   HighCorner   - Corner for "High Efficiency": 'topleft' (default) or
%                  'bottomright'. Set automatically by wrappers via FlipXY.
%   Legend        - Legend location (default: 'best'), 'none' to hide
%   Title/XLabel/YLabel - Text overrides
%   Visible/SavePath/SaveWidth/SaveHeight/SaveDPI - Standard plot params
%
% Outputs:
%   fig   - Figure handle
%   stats - Struct array [nItems x 1]:
%           .r, .p, .rho, .pval, .N, .zX, .zY, .NE, .centroid,
%           .semX, .semY, .stdX, .stdY, .meanNE, .label
%           NE = zY - zX (positive = above identity line = efficient)
%
% See also: plotNeuralEfficiency, plotNeuralEfficiencyFromTable

    % --- Ensure optional struct fields exist ---
    if ~isfield(plotGroups, 'subjectIDs')
        [plotGroups.subjectIDs] = deal({});
    end
    if ~isfield(plotGroups, 'arrowChain')
        [plotGroups.arrowChain] = deal(NaN);
    end

    p = inputParser;
    addRequired(p, 'plotGroups', @isstruct);
    addParameter(p, 'ZScoreMode', 'pooled', @(x) ismember(lower(x), {'pooled','pergroup'}));
    addParameter(p, 'InvertX', false, @islogical);
    addParameter(p, 'ReverseAxes', false, @islogical);
    addParameter(p, 'ShowIdentity', true, @islogical);
    addParameter(p, 'ShowPoints', true, @islogical);
    addParameter(p, 'ShowLabels', false, @islogical);
    addParameter(p, 'ErrorType', 'sem', @(x) ismember(lower(x), {'sem','std','none'}));
    addParameter(p, 'CentroidSize', 120, @isnumeric);
    addParameter(p, 'FitLine', false, @islogical);
    addParameter(p, 'ShowArrows', false, @islogical);
    addParameter(p, 'ArrowColor', [1 1 1], @(x) isnumeric(x) && numel(x)==3);
    addParameter(p, 'ShowQuadrantLabels', true, @islogical);
    addParameter(p, 'HighCorner', 'topleft', @(x) ismember(lower(x), {'topleft','bottomright'}));
    addParameter(p, 'Legend', 'best', @ischar);
    addParameter(p, 'Title', '', @ischar);
    addParameter(p, 'XLabel', '', @ischar);
    addParameter(p, 'YLabel', '', @ischar);
    addParameter(p, 'Visible', 'on', @ischar);
    addParameter(p, 'SavePath', '', @ischar);
    addParameter(p, 'SaveWidth', 600, @isnumeric);
    addParameter(p, 'SaveHeight', 500, @isnumeric);
    addParameter(p, 'SaveDPI', 150, @isnumeric);
    addParameter(p, 'TightLayout', false, @islogical);
    parse(p, plotGroups, varargin{:});
    opts = p.Results;

    if ~isempty(opts.SavePath)
        opts.Visible = 'off';
    end

    nItems = length(plotGroups);

    % --- Z-score ---
    if strcmpi(opts.ZScoreMode, 'pooled')
        allX = vertcat(plotGroups.x);
        allY = vertcat(plotGroups.y);
        muX = mean(allX, 'omitnan');
        sdX = std(allX, 'omitnan');
        muY = mean(allY, 'omitnan');
        sdY = std(allY, 'omitnan');
        if sdX == 0, sdX = 1; end
        if sdY == 0, sdY = 1; end
        for i = 1:nItems
            plotGroups(i).x = (plotGroups(i).x - muX) ./ sdX;
            plotGroups(i).y = (plotGroups(i).y - muY) ./ sdY;
        end
    else
        for i = 1:nItems
            muX = mean(plotGroups(i).x, 'omitnan');
            sdX = std(plotGroups(i).x, 'omitnan');
            muY = mean(plotGroups(i).y, 'omitnan');
            sdY = std(plotGroups(i).y, 'omitnan');
            if sdX == 0, sdX = 1; end
            if sdY == 0, sdY = 1; end
            plotGroups(i).x = (plotGroups(i).x - muX) ./ sdX;
            plotGroups(i).y = (plotGroups(i).y - muY) ./ sdY;
        end
    end

    % Invert X
    if opts.InvertX
        for i = 1:nItems
            plotGroups(i).x = -plotGroups(i).x;
        end
    end

    % --- Create figure ---
    sty = pf2_base.plot.PlotStyle.getDefault();
    fig = pf2_base.plot.createFigure('Visible', opts.Visible, ...
        'Width', opts.SaveWidth, 'Height', opts.SaveHeight, ...
        'SavePath', opts.SavePath);
    ax = axes('Parent', fig);
    hold(ax, 'on');

    % --- Identity line (y = x) ---
    if opts.ShowIdentity
        allZ = [vertcat(plotGroups.x); vertcat(plotGroups.y)];
        zRange = [min(allZ) - 0.5, max(allZ) + 0.5];
        hId = plot(ax, zRange, zRange, '--', 'Color', [0.6 0.6 0.6], ...
            'LineWidth', 1);
        set(hId.Annotation.LegendInformation, 'IconDisplayStyle', 'off');
    end

    % --- Quadrant labels ---
    if opts.ShowQuadrantLabels
        if strcmpi(opts.HighCorner, 'topleft')
            highPos = [0.03, 0.97];
            lowPos  = [0.97, 0.03];
            highHA = 'left';   lowHA = 'right';
            highVA = 'top';    lowVA = 'bottom';
        else
            highPos = [0.97, 0.03];
            lowPos  = [0.03, 0.97];
            highHA = 'right';  lowHA = 'left';
            highVA = 'bottom'; lowVA = 'top';
        end
        text(ax, highPos(1), highPos(2), 'High Efficiency', ...
            'Units', 'normalized', 'FontSize', 12, 'FontWeight', 'bold', ...
            'Color', [0.4 0.7 0.4], 'HorizontalAlignment', highHA, ...
            'VerticalAlignment', highVA);
        text(ax, lowPos(1), lowPos(2), 'Low Efficiency', ...
            'Units', 'normalized', 'FontSize', 12, 'FontWeight', 'bold', ...
            'Color', [0.8 0.4 0.4], 'HorizontalAlignment', lowHA, ...
            'VerticalAlignment', lowVA);
    end

    % --- Render per item ---
    stats = struct('r', {}, 'p', {}, 'rho', {}, 'pval', {}, ...
        'N', {}, 'zX', {}, 'zY', {}, 'centroid', {}, ...
        'semX', {}, 'semY', {}, 'stdX', {}, 'stdY', {}, 'label', {});

    legendHandles = gobjects(0);
    legendLabels = {};
    seenLabels = {};

    showErr = ~strcmpi(opts.ErrorType, 'none');

    for i = 1:nItems
        xZ = plotGroups(i).x;
        yZ = plotGroups(i).y;
        N = length(xZ);
        clr = plotGroups(i).color;
        lbl = plotGroups(i).label;

        % Legend deduplication: one entry per unique label
        isNewLabel = ~any(strcmp(seenLabels, lbl));

        % --- Individual scatter points (behind centroid) ---
        if opts.ShowPoints && N > 0
            hPts = scatter(ax, xZ, yZ, 25, clr, 'filled', ...
                'MarkerFaceAlpha', 0.35);
            set(hPts.Annotation.LegendInformation, 'IconDisplayStyle', 'off');
        end

        % --- Per-item stats ---
        cx = mean(xZ, 'omitnan');
        cy = mean(yZ, 'omitnan');
        semXval = std(xZ, 'omitnan') ./ sqrt(sum(~isnan(xZ)));
        semYval = std(yZ, 'omitnan') ./ sqrt(sum(~isnan(yZ)));
        stdXval = std(xZ, 'omitnan');
        stdYval = std(yZ, 'omitnan');

        % Neural efficiency: NE = zY - zX (positive = above identity line)
        neVals = yZ - xZ;

        s = struct('r', NaN, 'p', NaN, 'rho', NaN, 'pval', NaN, ...
            'N', N, 'zX', xZ, 'zY', yZ, 'NE', neVals, ...
            'centroid', [cx, cy], ...
            'semX', semXval, 'semY', semYval, ...
            'stdX', stdXval, 'stdY', stdYval, ...
            'meanNE', mean(neVals, 'omitnan'), ...
            'label', lbl);
        if N >= 3
            [s.r, s.p] = pf2_base.compat.corr(xZ, yZ, 'Type', 'Pearson');
            [s.rho, s.pval] = pf2_base.compat.corr(xZ, yZ, 'Type', 'Spearman');
        end

        % --- Error crosshairs ---
        if showErr && N > 1
            if strcmpi(opts.ErrorType, 'sem')
                errX = semXval;
                errY = semYval;
            else
                errX = stdXval;
                errY = stdYval;
            end
            % Horizontal error bar
            hErrH = plot(ax, [cx - errX, cx + errX], [cy, cy], '-', ...
                'Color', clr, 'LineWidth', 2);
            set(hErrH.Annotation.LegendInformation, 'IconDisplayStyle', 'off');
            % Vertical error bar
            hErrV = plot(ax, [cx, cx], [cy - errY, cy + errY], '-', ...
                'Color', clr, 'LineWidth', 2);
            set(hErrV.Annotation.LegendInformation, 'IconDisplayStyle', 'off');
        end

        % --- Centroid marker (primary visual element, used for legend) ---
        hCent = scatter(ax, cx, cy, opts.CentroidSize, clr, 'filled', ...
            'MarkerEdgeColor', clr, 'LineWidth', 1.5);
        if isNewLabel
            set(hCent, 'DisplayName', lbl);
            legendHandles(end+1) = hCent; %#ok<AGROW>
            legendLabels{end+1} = lbl; %#ok<AGROW>
            seenLabels{end+1} = lbl; %#ok<AGROW>
        else
            set(hCent.Annotation.LegendInformation, 'IconDisplayStyle', 'off');
        end

        % --- Regression line ---
        if opts.FitLine && N > 2
            coeffs = polyfit(xZ, yZ, 1);
            xFit = linspace(min(xZ), max(xZ), 200);
            yFit = polyval(coeffs, xFit);
            hLine = plot(ax, xFit, yFit, '-', 'Color', clr, 'LineWidth', 1.5);
            set(hLine.Annotation.LegendInformation, 'IconDisplayStyle', 'off');
        end

        % --- Stat annotation (bottom-left, avoids quadrant labels) ---
        yOff = 0.02 + (nItems - i) * 0.07;
        text(ax, 0.02, yOff, sprintf('%s: r=%.2f, p=%.3f, N=%d', ...
            lbl, s.r, s.p, N), ...
            'Units', 'normalized', 'FontSize', 8, 'Color', clr, ...
            'VerticalAlignment', 'bottom');

        % --- Subject labels ---
        if opts.ShowPoints && opts.ShowLabels && ~isempty(plotGroups(i).subjectIDs)
            sids = plotGroups(i).subjectIDs;
            for j = 1:min(N, length(sids))
                text(ax, xZ(j), yZ(j), ['  ' sids{j}], ...
                    'FontSize', 6, 'Color', clr, 'Clipping', 'on');
            end
        end

        stats(i) = s;
    end

    % --- Arrows between same-chain centroids ---
    if opts.ShowArrows
        trimFrac = 0.12;  % trim 12% from each end
        chains = [plotGroups.arrowChain];
        uniqueChains = unique(chains(~isnan(chains)));
        for c = uniqueChains(:)'
            idx = find(chains == c);
            if length(idx) < 2, continue; end
            centroids = vertcat(stats(idx).centroid);
            for j = 1:(length(idx) - 1)
                x0 = centroids(j, 1);
                y0 = centroids(j, 2);
                x1 = centroids(j+1, 1);
                y1 = centroids(j+1, 2);
                % Trim start and end so arrow doesn't overlap centroids
                startX = x0 + trimFrac * (x1 - x0);
                startY = y0 + trimFrac * (y1 - y0);
                endX   = x1 - trimFrac * (x1 - x0);
                endY   = y1 - trimFrac * (y1 - y0);
                dx = endX - startX;
                dy = endY - startY;
                hArrow = quiver(ax, startX, startY, dx, dy, 0, ...
                    'Color', opts.ArrowColor, 'LineWidth', 2, ...
                    'MaxHeadSize', 0.5);
                set(hArrow.Annotation.LegendInformation, ...
                    'IconDisplayStyle', 'off');
            end
        end
    end

    % --- Labels ---
    if ~isempty(opts.XLabel)
        xlabel(ax, opts.XLabel);
    else
        xlabel(ax, 'X (z-scored)');
    end
    if ~isempty(opts.YLabel)
        ylabel(ax, opts.YLabel);
    else
        ylabel(ax, 'Y (z-scored)');
    end

    % --- Legend ---
    nLeg = length(legendHandles);
    if nLeg > 1 && ~strcmpi(opts.Legend, 'none')
        lg = legend(ax, legendHandles, legendLabels, ...
            'Location', opts.Legend, 'FontSize', 9);
        lg.TextColor = sty.LegendTextColor;
        lg.Color = sty.LegendBgColor;
        lg.EdgeColor = sty.LegendEdgeColor;
    end

    % --- Title ---
    if ~isempty(opts.Title)
        title(ax, opts.Title);
    end

    grid(ax, 'on');
    box(ax, 'on');
    axis(ax, 'equal');

    if opts.ReverseAxes
        set(ax, 'XDir', 'reverse');
    end

    sty.applyToFigure(fig);
    pf2_base.plot.handleSave(fig, opts);
end
