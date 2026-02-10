function [legendHandles, legendEntries] = renderTemporal(ax, groups, groupIdx, colorVar, biomarker, channels, opts)
% RENDERTEMPORAL Render temporal traces into a single axes
%
% Draws time-series traces with error bands for the specified groups.
% Color dimension maps groups to different line colors.
%
% Syntax:
%   [h, e] = renderTemporal(ax, groups, groupIdx, colorVar, biomarker, channels, opts)
%
% Inputs:
%   ax        - Axes handle
%   groups    - Full groups struct array (after aggregate)
%   groupIdx  - Indices into groups to render in this cell
%   colorVar  - Color/legend variable name (or '' for auto)
%   biomarker - Biomarker field name (e.g., 'HbO')
%   channels  - Channel indices to average over
%   opts      - Struct with fields: ErrorType, XLim, YLim
%
% Outputs:
%   legendHandles - Array of line handles for legend
%   legendEntries - Cell array of legend label strings
%
% See also: exploreFNIRS.core.PlotProxy, exploreFNIRS.core.buildLayout

    hold(ax, 'on');
    sty = pf2_base.plot.PlotStyle.getDefault();

    legendHandles = [];
    legendEntries = {};

    if isempty(groupIdx), return; end

    nSel = length(groupIdx);
    selGroups = groups(groupIdx);

    % Determine colors
    colorSpec = [];
    if isfield(opts, 'Colors'), colorSpec = opts.Colors; end

    if isa(colorSpec, 'exploreFNIRS.core.ColorScheme')
        % ColorScheme: resolve per-group colors directly
        palette = colorSpec.resolve(selGroups);
        colorIdx = 1:nSel;
    elseif ~isempty(colorVar)
        % Color by the Color variable values
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
        ga = selGroups(i).gbyGrand;
        if isempty(ga) || ~isfield(ga, biomarker) || isempty(ga.(biomarker))
            continue;
        end

        src = ga.(biomarker);
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

        validCh = channels(channels <= size(meanData, 2));
        if isempty(validCh), continue; end

        if length(validCh) > 1
            mLine = mean(meanData(:, validCh), 2, 'omitnan');
            eLine = mean(errData(:, validCh), 2, 'omitnan');
        else
            mLine = meanData(:, validCh);
            eLine = errData(:, validCh);
        end

        clr = palette(colorIdx(i), :);

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
        h = plot(ax, timeVec, mLine, '-', 'Color', clr, 'LineWidth', sty.LineWidth);

        legendHandles(end+1) = h; %#ok<AGROW>

        % Build label (hide n=1 since it adds no information)
        lbl = selGroups(i).label;
        nSubj = round(mean(nData(:, validCh), 'all', 'omitnan'));
        if nSubj > 1
            lbl = [lbl, sprintf(' (n=%d)', nSubj)]; %#ok<AGROW>
        end
        legendEntries{end+1} = lbl; %#ok<AGROW>
    end

    % Zero line
    plot(ax, xlim(ax), [0 0], 'k-', 'LineWidth', 0.5, 'HandleVisibility', 'off');

    xlabel(ax, 'Time (s)');

    if ~isempty(groupIdx)
        ga1 = groups(groupIdx(1)).gbyGrand;
        if ~isempty(ga1) && isfield(ga1, 'units')
            ylabel(ax, ga1.units);
        else
            ylabel(ax, '\DeltaHb');
        end
    end

    if isfield(opts, 'XLim') && ~isempty(opts.XLim)
        xlim(ax, opts.XLim);
    end
    if isfield(opts, 'YLim') && ~isempty(opts.YLim)
        ylim(ax, opts.YLim);
    end

    box(ax, 'on');
    grid(ax, 'on');
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
