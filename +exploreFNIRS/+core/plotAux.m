function fig = plotAux(groups, auxField, varargin)
% PLOTAUX Headless temporal plot for auxiliary signal channels
%
% Creates time-series plots for multichannel auxiliary data (e.g.,
% accelerometer, heart rate, respiration) from grouped/aggregated
% experiment data, with shaded error bands per group.
%
% Syntax:
%   fig = plotAux(groups, 'accelerometer')
%   fig = plotAux(groups, 'heartRate', 'AuxChannels', 1)
%   fig = plotAux(groups, 'accelerometer', 'Layout', 'grid', ...)
%
% Inputs:
%   groups   - Struct array from Experiment.groups (after aggregate())
%              Each element must have .gbyGrand.Aux.(auxField)
%   auxField - Name of the Aux field to plot (e.g., 'accelerometer')
%
% Name-Value Parameters:
%   AuxChannels - Vector of Aux channel indices to plot (default: all)
%   ErrorType   - 'SEM' (default), 'SD', or 'none'
%   Layout      - 'grid' (default) or 'overlay'
%                 'grid': one subplot per Aux channel
%                 'overlay': all channels on one axes
%   YLim        - [min max] y-axis limits (default: auto)
%   XLim        - [min max] x-axis limits (default: auto)
%   Title       - Figure title (default: auto-generated)
%   Visible     - 'on' (default) or 'off' for headless mode
%   SavePath    - File path to save figure (triggers headless)
%   SaveWidth   - Width in pixels (default: 800)
%   SaveHeight  - Height in pixels (default: 500)
%   SaveDPI     - Resolution (default: 150)
%   Colors      - Group color palette override (default: [] = auto)
%
% Outputs:
%   fig - Figure handle
%
% Example:
%   ex = exploreFNIRS.core.Experiment(data);
%   ex.groupby({'Group','Condition'});
%   ex.aggregate();
%
%   % Plot all accelerometer channels in grid
%   fig = exploreFNIRS.core.plotAux(ex.groups, 'accelerometer');
%
%   % Save single heart rate channel
%   exploreFNIRS.core.plotAux(ex.groups, 'heartRate', ...
%       'AuxChannels', 1, 'SavePath', 'hr.png');
%
% See also: exploreFNIRS.core.plotTemporal, exploreFNIRS.core.Experiment

    p = inputParser;
    addRequired(p, 'groups', @isstruct);
    addRequired(p, 'auxField', @ischar);
    addParameter(p, 'AuxChannels', [], @isnumeric);
    addParameter(p, 'ErrorType', 'SEM', @ischar);
    addParameter(p, 'Layout', 'grid', @ischar);
    addParameter(p, 'YLim', [], @isnumeric);
    addParameter(p, 'XLim', [], @isnumeric);
    addParameter(p, 'Title', '', @ischar);
    addParameter(p, 'Visible', 'on', @ischar);
    addParameter(p, 'SavePath', '', @ischar);
    addParameter(p, 'SaveWidth', 800, @isnumeric);
    addParameter(p, 'SaveHeight', 500, @isnumeric);
    addParameter(p, 'SaveDPI', 150, @isnumeric);
    addParameter(p, 'Colors', [], @(x) isempty(x) || isnumeric(x) || ischar(x) || isstring(x) || isa(x, 'function_handle') || isa(x, 'exploreFNIRS.core.ColorScheme'));
    parse(p, groups, auxField, varargin{:});
    opts = p.Results;

    if ~isempty(opts.SavePath)
        opts.Visible = 'off';
    end

    nGroups = length(groups);

    % Resolve Aux field name (handle flattened naming: 'accel' -> 'accel_data')
    auxField = resolveAuxField(groups(1).gbyGrand, auxField);

    % Validate Aux field exists in all groups
    for g = 1:nGroups
        ga = groups(g).gbyGrand;
        if isempty(ga)
            error('exploreFNIRS:core:plotAux', ...
                'Group %d has no grand average. Call aggregate() first.', g);
        end
        if ~isfield(ga, 'Aux') || ~isfield(ga.Aux, auxField)
            error('exploreFNIRS:core:plotAux', ...
                'Aux field "%s" not found in group %d. Available: %s', ...
                auxField, g, getAuxFieldList(ga));
        end
    end

    % Determine number of Aux channels from first group
    refAux = groups(1).gbyGrand.Aux.(auxField);
    nTotalCh = size(refAux.Mean, 2);

    if isempty(opts.AuxChannels)
        auxCh = 1:nTotalCh;
    else
        auxCh = opts.AuxChannels(opts.AuxChannels <= nTotalCh);
    end
    nCh = length(auxCh);

    if nCh == 0
        error('exploreFNIRS:core:plotAux', 'No valid Aux channels to plot');
    end

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
        chLabels = arrayfun(@(x) sprintf('ch%d', x), auxCh, 'UniformOutput', false);
    end

    % Determine layout
    if strcmpi(opts.Layout, 'grid') && nCh > 1
        nRows = ceil(sqrt(nCh));
        nCols = ceil(nCh / nRows);
        figW = opts.SaveWidth;
        figH = opts.SaveHeight * min(nRows, 3) / max(nRows, 1) * 1.5;
    else
        nRows = 1;
        nCols = 1;
        figW = opts.SaveWidth;
        figH = opts.SaveHeight;
    end

    fig = pf2_base.plot.createFigure('Visible', opts.Visible, ...
        'Width', figW, 'Height', figH, ...
        'SavePath', opts.SavePath);
    sty = pf2_base.plot.PlotStyle.getDefault();

    if isa(opts.Colors, 'exploreFNIRS.core.ColorScheme')
        groupColors = opts.Colors.resolve(groups);
    else
        groupColors = exploreFNIRS.core.getGroupColors(nGroups, opts.Colors);
    end

    if strcmpi(opts.Layout, 'grid') && nCh > 1
        % Grid: one subplot per Aux channel
        for cIdx = 1:nCh
            ch = auxCh(cIdx);
            ax = subplot(nRows, nCols, cIdx, 'Parent', fig);
            hold(ax, 'on');

            for g = 1:nGroups
                auxData = groups(g).gbyGrand.Aux.(auxField);
                if ch > size(auxData.Mean, 2), continue; end

                timeVec = groups(g).gbyGrand.time;
                mLine = auxData.Mean(:, ch);
                clr = groupColors(g, :);

                % Error band
                eLine = getErrorData(auxData, ch, opts.ErrorType);
                if ~strcmpi(opts.ErrorType, 'none') && any(eLine > 0)
                    plotErrorBand(ax, timeVec, mLine, eLine, clr);
                end

                plot(ax, timeVec, mLine, '-', 'Color', clr, 'LineWidth', 1.2);
            end

            plot(ax, xlim(ax), [0 0], 'k-', 'LineWidth', 0.5, 'HandleVisibility', 'off');
            title(ax, pf2_base.plot.escapeTeX(chLabels{cIdx}));
            xlabel(ax, 'Time (s)');
            if cIdx == 1 || mod(cIdx-1, nCols) == 0
                ylabel(ax, getAuxUnit(refAux));
            end
            if ~isempty(opts.YLim), ylim(ax, opts.YLim); end
            if ~isempty(opts.XLim), xlim(ax, opts.XLim); end
            grid(ax, 'on');
            box(ax, 'on');
        end

        % Shared legend
        addSharedLegend(fig, groups, groupColors);
    else
        % Overlay: all channels on one axes
        ax = axes('Parent', fig);
        hold(ax, 'on');

        legendHandles = [];
        legendEntries = {};
        lineStyles = {'-', '--', ':', '-.'};

        for g = 1:nGroups
            auxData = groups(g).gbyGrand.Aux.(auxField);
            timeVec = groups(g).gbyGrand.time;
            clr = groupColors(g, :);

            for cIdx = 1:nCh
                ch = auxCh(cIdx);
                if ch > size(auxData.Mean, 2), continue; end

                mLine = auxData.Mean(:, ch);
                style = lineStyles{mod(cIdx-1, length(lineStyles)) + 1};

                % Error band (only for single channel to avoid clutter)
                if nCh == 1
                    eLine = getErrorData(auxData, ch, opts.ErrorType);
                    if ~strcmpi(opts.ErrorType, 'none') && any(eLine > 0)
                        plotErrorBand(ax, timeVec, mLine, eLine, clr);
                    end
                end

                h = plot(ax, timeVec, mLine, style, 'Color', clr, 'LineWidth', 1.2);
                legendHandles(end+1) = h; %#ok<AGROW>

                if nCh > 1
                    legendEntries{end+1} = pf2_base.plot.escapeTeX(sprintf('%s: %s', groups(g).label, chLabels{cIdx})); %#ok<AGROW>
                else
                    legendEntries{end+1} = pf2_base.plot.escapeTeX(groups(g).label); %#ok<AGROW>
                end
            end
        end

        plot(ax, xlim(ax), [0 0], 'k-', 'LineWidth', 0.5, 'HandleVisibility', 'off');
        xlabel(ax, 'Time (s)');
        ylabel(ax, getAuxUnit(refAux));
        if ~isempty(opts.YLim), ylim(ax, opts.YLim); end
        if ~isempty(opts.XLim), xlim(ax, opts.XLim); end

        if ~isempty(legendHandles)
            legend(ax, legendHandles, legendEntries, 'Location', 'best', 'FontSize', 8);
        end
        grid(ax, 'on');
        box(ax, 'on');
    end

    % Figure title
    if ~isempty(opts.Title)
        pf2_base.external.suptitle(fig, opts.Title);
    else
        pf2_base.external.suptitle(fig, pf2_base.plot.escapeTeX(auxField));
    end

    sty.applyToFigure(fig);
    pf2_base.plot.handleSave(fig, opts);
end


%% Local helpers

function eLine = getErrorData(auxData, ch, errorType)
    switch upper(errorType)
        case 'SEM'
            if isfield(auxData, 'SEM')
                eLine = auxData.SEM(:, ch);
            else
                eLine = zeros(size(auxData.Mean(:, ch)));
            end
        case 'SD'
            if isfield(auxData, 'SD')
                eLine = auxData.SD(:, ch);
            else
                eLine = zeros(size(auxData.Mean(:, ch)));
            end
        case 'NONE'
            eLine = zeros(size(auxData.Mean(:, ch)));
        otherwise
            eLine = zeros(size(auxData.Mean(:, ch)));
    end
end


function plotErrorBand(ax, timeVec, mLine, eLine, clr)
    upperBound = mLine + eLine;
    lowerBound = mLine - eLine;
    validIdx = ~isnan(mLine) & ~isnan(upperBound);
    if any(validIdx)
        tV = timeVec(validIdx);
        fill(ax, [tV; flipud(tV)], ...
            [upperBound(validIdx); flipud(lowerBound(validIdx))], ...
            clr, 'FaceAlpha', 0.2, 'EdgeColor', 'none', ...
            'HandleVisibility', 'off');
    end
end



function lbl = getAuxUnit(auxStruct)
    if isfield(auxStruct, 'unit')
        lbl = auxStruct.unit;
    else
        lbl = 'a.u.';
    end
end


function str = getAuxFieldList(ga)
% List available Aux fields, showing clean names for flattened fields
    if isfield(ga, 'Aux') && isstruct(ga.Aux)
        flds = getCleanAuxFields(ga);
        if ~isempty(flds)
            str = strjoin(flds, ', ');
        else
            str = '(none)';
        end
    else
        str = '(no Aux data)';
    end
end


function resolved = resolveAuxField(ga, name)
% Resolve user-facing Aux field name to actual field in grand average
% Handles flattened naming: 'accelerometer' -> 'accelerometer_data'
    if ~isfield(ga, 'Aux')
        resolved = name;
        return;
    end

    % Exact match
    if isfield(ga.Aux, name)
        resolved = name;
        return;
    end

    % Try _data suffix (from flattenAux)
    dataName = [name, '_data'];
    if isfield(ga.Aux, dataName)
        resolved = dataName;
        return;
    end

    % No match - return original (will produce helpful error later)
    resolved = name;
end


function cleanNames = getCleanAuxFields(ga)
% Get deduplicated, clean Aux field names (strip _data/_time/_unit suffixes)
    if ~isfield(ga, 'Aux') || ~isstruct(ga.Aux)
        cleanNames = {};
        return;
    end

    flds = fieldnames(ga.Aux);
    flds = flds(~ismember(flds, {'flattened'}));

    % Collect unique base names
    baseNames = {};
    for i = 1:length(flds)
        f = flds{i};
        % Strip known suffixes from flattening
        base = regexprep(f, '_(data|time|unit)$', '');
        if ~ismember(base, baseNames)
            % Only include if the _data version (or exact) has .Mean (i.e., was averaged)
            if isfield(ga.Aux, f) && isstruct(ga.Aux.(f)) && isfield(ga.Aux.(f), 'Mean')
                baseNames{end+1} = base; %#ok<AGROW>
            elseif isfield(ga.Aux, [base '_data']) && isstruct(ga.Aux.([base '_data'])) && isfield(ga.Aux.([base '_data']), 'Mean')
                baseNames{end+1} = base; %#ok<AGROW>
            end
        end
    end
    cleanNames = unique(baseNames, 'stable');
end


function addSharedLegend(fig, groups, groupColors)
    nGroups = length(groups);
    axLeg = axes('Parent', fig, 'Visible', 'off', 'Position', [0 0 0.01 0.01]);
    hold(axLeg, 'on');

    handles = gobjects(nGroups, 1);
    entries = cell(nGroups, 1);
    for g = 1:nGroups
        handles(g) = plot(axLeg, NaN, NaN, '-', 'Color', groupColors(g,:), 'LineWidth', 1.2);
        entries{g} = pf2_base.plot.escapeTeX(groups(g).label);
    end

    legend(handles, entries, 'Location', 'southoutside', ...
        'Orientation', 'horizontal', 'FontSize', 8);
end
