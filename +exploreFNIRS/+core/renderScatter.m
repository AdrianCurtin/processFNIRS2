function [legendHandles, legendEntries, stats] = renderScatter(ax, groups, groupIdx, colorVar, biomarker, channels, infoVar, opts)
% RENDERSCATTER Render scatter plot into a single axes
%
% Draws scatter points correlating an info variable (X) with fNIRS
% biomarker data (Y) for the specified groups. Supports fit lines and
% per-group coloring.
%
% Syntax:
%   [h, e, s] = renderScatter(ax, groups, groupIdx, colorVar, biomarker, channels, infoVar, opts)
%
% Inputs:
%   ax        - Axes handle
%   groups    - Full groups struct array (after aggregate)
%   groupIdx  - Indices into groups to render in this cell
%   colorVar  - Color/legend variable name (or '' for auto)
%   biomarker - Biomarker field name (e.g., 'HbO')
%   channels  - Channel indices to average over
%   infoVar   - Name of the info variable for X-axis
%   opts      - Struct with fields: FitLine, CorrType
%
% Outputs:
%   legendHandles - Array of scatter handles for legend
%   legendEntries - Cell array of legend label strings
%   stats         - Struct array with correlation stats per group
%
% See also: exploreFNIRS.core.PlotProxy, exploreFNIRS.core.buildLayout

    hold(ax, 'on');

    legendHandles = [];
    legendEntries = {};

    if isempty(groupIdx)
        stats = struct([]);
        return;
    end

    nSel = length(groupIdx);
    selGroups = groups(groupIdx);

    % Pre-initialize stats with consistent fields
    emptyS = struct('r', NaN, 'p', NaN, 'rho', NaN, 'pval', NaN, ...
        'N', 0, 'coefficients', []);
    stats = repmat(emptyS, 1, nSel);

    % Determine colors
    colorSpec = [];
    if isfield(opts, 'Colors'), colorSpec = opts.Colors; end

    if isa(colorSpec, 'exploreFNIRS.core.ColorScheme')
        palette = colorSpec.resolve(selGroups);
        colorIdx = 1:nSel;
    elseif ~isempty(colorVar)
        colorVals = getFactorPerGroup(selGroups, colorVar);
        uniqueColors = unique(colorVals, 'stable');
        nColors = length(uniqueColors);
        palette = exploreFNIRS.core.getGroupColors(nColors, colorSpec);
        colorIdx = zeros(1, nSel);
        for i = 1:nSel
            colorIdx(i) = find(strcmp(uniqueColors, colorVals{i}), 1);
        end
    else
        nColors = nSel;
        palette = exploreFNIRS.core.getGroupColors(nColors, colorSpec);
        colorIdx = 1:nSel;
    end

    for i = 1:nSel
        gIdx = groupIdx(i);
        curGrand = groups(gIdx).gbyGrandBarFlat;
        curTable = groups(gIdx).gbyTables;

        if isempty(curGrand) || ~isfield(curGrand, biomarker)
            continue;
        end

        bioData = curGrand.(biomarker);
        validCh = channels(channels <= size(bioData.data, 2));
        if isempty(validCh)
            continue;
        end

        % Y: average across channels and first time bin
        tIdx = 1;
        yVals = squeeze(mean(bioData.data(tIdx, validCh, :), 2, 'omitnan'));
        yVals = yVals(:);

        % X: info variable
        if ~ismember(infoVar, curTable.Properties.VariableNames)
            continue;
        end
        xData = curTable.(infoVar);
        if ~isnumeric(xData), xData = double(string(xData)); end
        xData(xData == -9999) = NaN;

        % Average per subject
        if ismember('SubjectID', curTable.Properties.VariableNames)
            xVals = pf2_base.hierarchicalAverage(xData, curTable(:, 'SubjectID'), @nanmean);
        else
            xVals = xData;
        end

        % Align
        n = min(length(xVals), length(yVals));
        xVals = xVals(1:n);
        yVals = yVals(1:n);
        valid = ~isnan(xVals) & ~isnan(yVals);
        xVals = xVals(valid);
        yVals = yVals(valid);
        N = length(xVals);

        % Stats
        curStats = struct('r', NaN, 'p', NaN, 'rho', NaN, 'pval', NaN, ...
            'N', N, 'coefficients', []);
        if N >= 3
            [curStats.r, curStats.p] = corr(xVals, yVals, 'Type', 'Pearson');
            [curStats.rho, curStats.pval] = corr(xVals, yVals, 'Type', 'Spearman');
        end
        stats(i) = curStats;

        clr = palette(colorIdx(i), :);

        % Scatter
        h = scatter(ax, xVals, yVals, 25, clr, 'filled', 'MarkerFaceAlpha', 0.7);
        legendHandles(end+1) = h; %#ok<AGROW>
        legendEntries{end+1} = sprintf('%s (n=%d)', selGroups(i).label, N); %#ok<AGROW>

        % Fit line
        fitLine = false;
        if isfield(opts, 'FitLine'), fitLine = opts.FitLine; end
        if fitLine && N > 2
            coeffs = polyfit(xVals, yVals, 1);
            curStats.coefficients = coeffs;
            stats(i).coefficients = coeffs;
            xFit = linspace(min(xVals), max(xVals), 50);
            yFit = polyval(coeffs, xFit);
            hLine = plot(ax, xFit, yFit, '-', 'Color', clr, 'LineWidth', 1.5);
            set(hLine.Annotation.LegendInformation, 'IconDisplayStyle', 'off');

            % Stat annotation
            corrType = 'Pearson';
            if isfield(opts, 'CorrType'), corrType = opts.CorrType; end
            if strcmpi(corrType, 'Spearman')
                statStr = sprintf('rho=%.3f, p=%.4f', curStats.rho, curStats.pval);
            else
                statStr = sprintf('r=%.3f, p=%.4f', curStats.r, curStats.p);
            end
            text(ax, 0.02, 0.98 - 0.06 * (i - 1), ...
                sprintf('N=%d, %s', N, statStr), ...
                'Units', 'normalized', 'FontSize', 7, 'Color', clr, ...
                'VerticalAlignment', 'top');
        end
    end

    xlabel(ax, pf2_base.plot.escapeTeX(infoVar));
    ylabel(ax, sprintf('\\Delta[%s]', biomarker));
    box(ax, 'on');
    grid(ax, 'on');
end


function vals = getFactorPerGroup(selGroups, varSpec)
    nSel = length(selGroups);
    vals = cell(1, nSel);
    if isempty(varSpec), vals = {}; return; end

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
