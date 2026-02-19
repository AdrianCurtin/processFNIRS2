function renderBar(ax, groups, groupIdx, xVar, colorVar, biomarker, channels, opts)
% RENDERBAR Render a bar chart into a single axes
%
% Draws grouped or flat bars for the specified groups, with X-axis and
% Color dimension mapping. Supports interaction terms on X (e.g., 'A:B').
%
% Syntax:
%   renderBar(ax, groups, groupIdx, xVar, colorVar, biomarker, channels, opts)
%
% Inputs:
%   ax        - Axes handle
%   groups    - Full groups struct array (after aggregate)
%   groupIdx  - Indices into groups to render in this cell
%   xVar      - X-axis variable name (or interaction 'A:B', or '')
%   colorVar  - Color/legend variable name (or '')
%   biomarker - Biomarker field name (e.g., 'HbO')
%   channels  - Channel indices to average over
%   opts      - Struct with fields: ErrorType, ShowIndividual, TimeWindow
%
% See also: exploreFNIRS.core.PlotProxy, exploreFNIRS.core.buildLayout

    hold(ax, 'on');

    if isempty(groupIdx), return; end

    nSel = length(groupIdx);
    selGroups = groups(groupIdx);

    % Extract mean/error for each selected group
    [groupMeans, groupErrors, groupN, individualData] = ...
        extractBarData(selGroups, biomarker, channels, opts);

    % Determine X and Color factor values per group
    xVals = getFactorPerGroup(selGroups, xVar);
    colorVals = getFactorPerGroup(selGroups, colorVar);

    hasX = ~isempty(xVar);
    hasColor = ~isempty(colorVar);

    % Check for ColorScheme
    colorSpec = getColorSpec(opts);
    useColorScheme = isa(colorSpec, 'exploreFNIRS.core.ColorScheme');

    if hasX && hasColor
        % --- Clustered bar (X categories, Color series) ---
        uniqueX = unique(xVals, 'stable');
        uniqueColor = unique(colorVals, 'stable');
        nX = length(uniqueX);
        nColor = length(uniqueColor);

        meanMatrix = nan(nX, nColor);
        errorMatrix = nan(nX, nColor);
        indivData = cell(nX, nColor);

        for i = 1:nSel
            xi = find(strcmp(uniqueX, xVals{i}), 1);
            ci = find(strcmp(uniqueColor, colorVals{i}), 1);
            if ~isempty(xi) && ~isempty(ci)
                meanMatrix(xi, ci) = groupMeans(i);
                errorMatrix(xi, ci) = groupErrors(i);
                indivData{xi, ci} = individualData{i};
            end
        end

        if useColorScheme
            % Resolve per-group colors, then map to X x Color grid
            allColors = colorSpec.resolve(selGroups);
            gridColors = nan(nX, nColor, 3);
            for i = 1:nSel
                xi = find(strcmp(uniqueX, xVals{i}), 1);
                ci = find(strcmp(uniqueColor, colorVals{i}), 1);
                if ~isempty(xi) && ~isempty(ci)
                    gridColors(xi, ci, :) = allColors(i, :);
                end
            end
            drawClusteredBars(ax, meanMatrix, errorMatrix, indivData, ...
                uniqueX, uniqueColor, gridColors, opts, ...
                sprintf('%s (%s)', biomarker, getUnitsLabel(selGroups(1))));
        else
            seriesColors = exploreFNIRS.core.getGroupColors(nColor, colorSpec);

            if strcmpi(opts.ErrorType, 'none')
                errInput = [];
            else
                errInput = errorMatrix;
            end

            barwebArgs = {'Axes', ax, ...
                'ColorMap', seriesColors, ...
                'Legend', uniqueColor, ...
                'YLabel', sprintf('%s (%s)', biomarker, getUnitsLabel(selGroups(1)))};
            if opts.ShowIndividual
                barwebArgs = [barwebArgs, {'DataPoints', indivData}];
            end

            sty = pf2_base.plot.PlotStyle.getDefault();
            pf2_base.external.barweb(meanMatrix, errInput, 1, uniqueX, barwebArgs{:}, ...
                'ErrorColor', sty.ForegroundColor);
            hold(ax, 'on');
        end

    elseif hasX && ~hasColor
        % --- Flat bars with X categories ---
        uniqueX = unique(xVals, 'stable');
        nX = length(uniqueX);

        if useColorScheme
            colors = colorSpec.resolve(selGroups);
        else
            colors = exploreFNIRS.core.getGroupColors(nX, colorSpec);
        end

        orderedMeans = nan(1, nX);
        orderedErrors = nan(1, nX);
        orderedIndiv = cell(1, nX);
        orderedN = nan(1, nX);
        orderedColors = nan(nX, 3);

        for i = 1:nSel
            xi = find(strcmp(uniqueX, xVals{i}), 1);
            if ~isempty(xi)
                orderedMeans(xi) = groupMeans(i);
                orderedErrors(xi) = groupErrors(i);
                orderedIndiv{xi} = individualData{i};
                orderedN(xi) = groupN(i);
                if useColorScheme
                    orderedColors(xi, :) = colors(i, :);
                end
            end
        end

        if ~useColorScheme
            orderedColors = colors;
        end

        drawFlatBars(ax, orderedMeans, orderedErrors, orderedN, ...
            orderedIndiv, uniqueX, orderedColors, opts);

    elseif ~hasX && hasColor
        % --- Flat bars colored by Color variable ---
        uniqueColor = unique(colorVals, 'stable');
        nColor = length(uniqueColor);

        if useColorScheme
            allColors = colorSpec.resolve(selGroups);
        else
            allColors = exploreFNIRS.core.getGroupColors(nColor, colorSpec);
        end

        orderedMeans = nan(1, nColor);
        orderedErrors = nan(1, nColor);
        orderedIndiv = cell(1, nColor);
        orderedN = nan(1, nColor);
        orderedColors = nan(nColor, 3);

        for i = 1:nSel
            ci = find(strcmp(uniqueColor, colorVals{i}), 1);
            if ~isempty(ci)
                orderedMeans(ci) = groupMeans(i);
                orderedErrors(ci) = groupErrors(i);
                orderedIndiv{ci} = individualData{i};
                orderedN(ci) = groupN(i);
                if useColorScheme
                    orderedColors(ci, :) = allColors(i, :);
                else
                    orderedColors(ci, :) = allColors(ci, :);
                end
            end
        end

        drawFlatBars(ax, orderedMeans, orderedErrors, orderedN, ...
            orderedIndiv, uniqueColor, orderedColors, opts);

    else
        % --- No X or Color: one bar per group ---
        labels = cell(1, nSel);
        for i = 1:nSel
            labels{i} = selGroups(i).label;
        end
        if useColorScheme
            colors = colorSpec.resolve(selGroups);
        else
            colors = exploreFNIRS.core.getGroupColors(nSel, colorSpec);
        end
        drawFlatBars(ax, groupMeans, groupErrors, groupN, ...
            individualData, labels, colors, opts);
    end

    % Zero line
    plot(ax, xlim(ax), [0 0], 'k-', 'LineWidth', 0.5, 'HandleVisibility', 'off');
    box(ax, 'on');
    grid(ax, 'on');
end


%% Local helpers

function [means, errors, ns, indiv] = extractBarData(selGroups, biomarker, channels, opts)
% Extract mean and error for each group
    nSel = length(selGroups);
    means = nan(1, nSel);
    errors = nan(1, nSel);
    ns = nan(1, nSel);
    indiv = cell(1, nSel);

    for i = 1:nSel
        ga = selGroups(i).gbyGrand;
        if isempty(ga) || ~isfield(ga, biomarker) || isempty(ga.(biomarker))
            continue;
        end

        src = ga.(biomarker);
        timeVec = ga.time;

        % Time window
        if isfield(opts, 'TimeWindow') && ~isempty(opts.TimeWindow)
            tMask = timeVec >= opts.TimeWindow(1) & timeVec <= opts.TimeWindow(2);
        else
            tMask = true(size(timeVec));
        end
        if ~any(tMask), continue; end

        chIdx = channels(channels <= size(src.Mean, 2));
        if isempty(chIdx), continue; end

        meanSlice = src.Mean(tMask, chIdx);
        means(i) = mean(meanSlice, 'all', 'omitnan');

        if isfield(src, 'data') && ~isempty(src.data)
            subjectData = src.data(tMask, chIdx, :);
            perSubject = squeeze(mean(mean(subjectData, 1, 'omitnan'), 2, 'omitnan'));
            perSubject = perSubject(:);
            perSubject(isnan(perSubject)) = [];
            ns(i) = length(perSubject);
            indiv{i} = perSubject;

            switch upper(opts.ErrorType)
                case 'SEM'
                    errors(i) = std(perSubject, 'omitnan') / sqrt(ns(i));
                case 'SD'
                    errors(i) = std(perSubject, 'omitnan');
                case 'NONE'
                    errors(i) = 0;
            end
        else
            semSlice = src.SEM(tMask, chIdx);
            errors(i) = mean(semSlice, 'all', 'omitnan');
            nSlice = src.N(tMask, chIdx);
            ns(i) = round(mean(nSlice, 'all', 'omitnan'));
        end
    end
end


function vals = getFactorPerGroup(selGroups, varSpec)
% Get factor value string per group
    nSel = length(selGroups);
    vals = cell(1, nSel);

    if isempty(varSpec)
        vals = {};
        return;
    end

    for i = 1:nSel
        T = selGroups(i).gbyTables;
        if contains(varSpec, ':')
            parts = strsplit(varSpec, ':');
            subVals = cell(1, length(parts));
            for p = 1:length(parts)
                v = T.(parts{p})(1);
                if isnumeric(v)
                    subVals{p} = num2str(v);
                else
                    subVals{p} = char(string(v));
                end
            end
            vals{i} = strjoin(subVals, ':');
        else
            if ~ismember(varSpec, T.Properties.VariableNames)
                vals{i} = '';
                continue;
            end
            v = T.(varSpec)(1);
            if isnumeric(v)
                vals{i} = num2str(v);
            else
                vals{i} = char(string(v));
            end
        end
    end
end


function drawFlatBars(ax, means, errors, ns, indiv, labels, colors, opts)
% Draw simple flat bar chart
    nBars = length(means);
    sty = pf2_base.plot.PlotStyle.getDefault();
    barX = 1:nBars;

    for i = 1:nBars
        bar(ax, barX(i), means(i), 0.6, ...
            'FaceColor', colors(i,:), 'EdgeColor', 'k', 'FaceAlpha', 0.7);
    end

    if ~strcmpi(opts.ErrorType, 'none')
        errorbar(ax, barX, means, errors, 'k.', ...
            'LineWidth', sty.AxisLineWidth, 'CapSize', 8);
    end

    if opts.ShowIndividual
        for i = 1:nBars
            if ~isempty(indiv{i})
                jitter = (rand(size(indiv{i})) - 0.5) * 0.25;
                scatter(ax, barX(i) + jitter, indiv{i}, 20, ...
                    colors(i,:), 'filled', 'MarkerFaceAlpha', 0.5, ...
                    'HandleVisibility', 'off');
            end
        end
    end

    set(ax, 'XTick', barX, 'XTickLabel', labels, 'XTickLabelRotation', 30);

    % N labels
    for i = 1:nBars
        if ~isnan(ns(i))
            yPos = means(i) + errors(i);
            if isnan(yPos), yPos = means(i); end
            text(ax, barX(i), yPos, sprintf('n=%d', ns(i)), ...
                'HorizontalAlignment', 'center', ...
                'VerticalAlignment', 'bottom', 'FontSize', 8);
        end
    end
end


function lbl = getUnitsLabel(group)
    if ~isempty(group.gbyGrand) && isfield(group.gbyGrand, 'units')
        lbl = group.gbyGrand.units;
    else
        lbl = '\DeltaHb';
    end
end


function cs = getColorSpec(opts)
% Extract Colors field from opts if present
    if isfield(opts, 'Colors')
        cs = opts.Colors;
    else
        cs = [];
    end
end


function drawClusteredBars(ax, meanMatrix, errorMatrix, indivData, ...
        uniqueX, uniqueColor, gridColors, opts, ylabelStr)
% Draw clustered bars with per-bar colors (for ColorScheme)
    nX = length(uniqueX);
    nColor = length(uniqueColor);
    sty = pf2_base.plot.PlotStyle.getDefault();

    % Bar positioning
    groupWidth = 0.8;
    barWidth = groupWidth / nColor;

    legendHandles = gobjects(nColor, 1);
    legendLabels = uniqueColor;

    for ci = 1:nColor
        for xi = 1:nX
            xPos = xi + (ci - (nColor + 1)/2) * barWidth;
            clr = squeeze(gridColors(xi, ci, :))';
            if any(isnan(clr))
                clr = [0.7 0.7 0.7];
            end

            h = bar(ax, xPos, meanMatrix(xi, ci), barWidth * 0.9, ...
                'FaceColor', clr, 'EdgeColor', 'k', 'FaceAlpha', 0.7);

            if xi == 1
                legendHandles(ci) = h;
            end
        end
    end

    % Error bars
    if ~strcmpi(opts.ErrorType, 'none')
        for ci = 1:nColor
            for xi = 1:nX
                xPos = xi + (ci - (nColor + 1)/2) * barWidth;
                if ~isnan(errorMatrix(xi, ci))
                    errorbar(ax, xPos, meanMatrix(xi, ci), errorMatrix(xi, ci), ...
                        'k.', 'LineWidth', sty.AxisLineWidth, 'CapSize', 6);
                end
            end
        end
    end

    % Individual data points
    if opts.ShowIndividual
        for ci = 1:nColor
            for xi = 1:nX
                xPos = xi + (ci - (nColor + 1)/2) * barWidth;
                pts = indivData{xi, ci};
                if ~isempty(pts)
                    clr = squeeze(gridColors(xi, ci, :))';
                    if any(isnan(clr)), clr = [0.7 0.7 0.7]; end
                    jitter = (rand(size(pts)) - 0.5) * barWidth * 0.5;
                    scatter(ax, xPos + jitter, pts, 20, clr, 'filled', ...
                        'MarkerFaceAlpha', 0.5, 'HandleVisibility', 'off');
                end
            end
        end
    end

    set(ax, 'XTick', 1:nX, 'XTickLabel', uniqueX, 'XTickLabelRotation', 30);
    ylabel(ax, ylabelStr);

    % Legend
    validH = isvalid(legendHandles) & legendHandles ~= 0;
    if any(validH)
        legend(ax, legendHandles(validH), legendLabels(validH), ...
            'Location', 'best', 'FontSize', 8);
    end
end
