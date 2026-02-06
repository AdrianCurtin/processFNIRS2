function [fig, stats] = plotScatterFNIRS(groups, varargin)
% PLOTSCATTERFNIRS Scatter plot correlating info variable vs fNIRS biomarker
%
% Creates scatter plots showing the relationship between an info/behavioral
% variable (X-axis) and fNIRS biomarker channel data (Y-axis). Supports
% Pearson/Spearman correlation, regression lines, error bands, and
% topographic correlation maps.
%
% Syntax:
%   [fig, stats] = plotScatterFNIRS(groups, 'InfoVar', 'reactionTime')
%   [fig, stats] = plotScatterFNIRS(groups, 'InfoVar', 'Age', ...
%       'Biomarkers', {'HbO'}, 'Channels', 1:5)
%   [fig, stats] = plotScatterFNIRS(groups, 'InfoVar', 'Age', ...
%       'PlotTopo', true, 'SigThreshold', 0.05)
%
% Inputs:
%   groups - Struct array from Experiment.groups (after aggregate())
%            Each element must have .gbyGrandBarFlat and .gbyTables
%
% Name-Value Parameters:
%   InfoVar        - (required) X-axis variable name from info fields
%   Biomarkers     - Cell array of biomarkers (default: {'HbO'})
%   Channels       - Vector of channel indices (default: all)
%   CorrType       - 'Pearson' (default) or 'Spearman'
%   FitLine        - Show regression line (default: true)
%   ErrorBand      - Show error band (default: false)
%   ErrorBandType  - '95%PI' (default), 'SEM', 'SD', '95%CI'
%   ErrorBandStyle - 'Shaded' (default), 'Dashed', 'Fine'
%   FlipXY         - Swap X and Y axes (default: false)
%   PlotTopo       - Generate topo correlation map (default: false)
%   SigThreshold   - Significance threshold for topo (default: 0.05)
%   SigType        - 'p' (default), 'q', 'q-twostep'
%   Title          - Figure title (default: auto)
%   Visible        - 'on' (default) or 'off'
%   SavePath       - File path to save figure
%   SaveWidth      - Width in pixels (default: 600)
%   SaveHeight     - Height in pixels (default: 400)
%   SaveDPI        - Resolution (default: 150)
%
% Outputs:
%   fig   - Figure handle
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
%   % Scatter: reaction time vs HbO, channel 5
%   [fig, stats] = exploreFNIRS.core.plotScatterFNIRS(ex.groups, ...
%       'InfoVar', 'reactionTime', 'Biomarkers', {'HbO'}, ...
%       'Channels', 5, 'FitLine', true);
%
%   % Topographic correlation map
%   [fig, stats] = exploreFNIRS.core.plotScatterFNIRS(ex.groups, ...
%       'InfoVar', 'Age', 'PlotTopo', true, 'SigThreshold', 0.05);
%
% See also: exploreFNIRS.core.Experiment, exploreFNIRS.core.plotBar

    p = inputParser;
    addRequired(p, 'groups', @isstruct);
    addParameter(p, 'InfoVar', '', @ischar);
    addParameter(p, 'Biomarkers', {'HbO'}, @iscell);
    addParameter(p, 'Channels', [], @isnumeric);
    addParameter(p, 'CorrType', 'Pearson', @ischar);
    addParameter(p, 'FitLine', true, @islogical);
    addParameter(p, 'ErrorBand', false, @islogical);
    addParameter(p, 'ErrorBandType', '95%PI', @ischar);
    addParameter(p, 'ErrorBandStyle', 'Shaded', @ischar);
    addParameter(p, 'FlipXY', false, @islogical);
    addParameter(p, 'PlotTopo', false, @islogical);
    addParameter(p, 'SigThreshold', 0.05, @isnumeric);
    addParameter(p, 'SigType', 'p', @ischar);
    addParameter(p, 'Title', '', @ischar);
    addParameter(p, 'Visible', 'on', @ischar);
    addParameter(p, 'SavePath', '', @ischar);
    addParameter(p, 'SaveWidth', 600, @isnumeric);
    addParameter(p, 'SaveHeight', 400, @isnumeric);
    addParameter(p, 'SaveDPI', 150, @isnumeric);
    parse(p, groups, varargin{:});
    opts = p.Results;

    if isempty(opts.InfoVar)
        error('exploreFNIRS:core:plotScatterFNIRS', ...
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
            error('exploreFNIRS:core:plotScatterFNIRS', ...
                'Group %d has no bar-flat grand average. Call aggregate() first.', g);
        end
    end

    % Determine channels
    if isempty(opts.Channels)
        nCh = size(groups(1).gbyGrandBarFlat.(opts.Biomarkers{1}).data, 2);
        allChannels = 1:nCh;
    else
        allChannels = opts.Channels;
        nCh = length(allChannels);
    end

    % Determine time bin (use first available)
    barTime = groups(1).gbyGrandBarFlat.time;
    tIdx = 1;

    % Initialize stats output (pre-allocate with consistent struct fields)
    stats = repmat(emptyStats(), nGroups, nBioM, nCh);

    if opts.PlotTopo
        % --- Topo mode: iterate all channels, compute correlation, render map ---
        [fig, stats] = plotTopoCorrelation(groups, opts, allChannels, tIdx);
    else
        % --- Scatter mode ---
        colors = exploreFNIRS.core.getGroupColors(nGroups);

        % Layout: one subplot per channel (or per biomarker if single channel)
        if nCh > 1 && nBioM == 1
            nPlots = nCh;
            plotMode = 'channels';
        elseif nBioM > 1 && nCh == 1
            nPlots = nBioM;
            plotMode = 'biomarkers';
        else
            nPlots = nCh * nBioM;
            plotMode = 'both';
        end

        nCols = min(nPlots, 4);
        nRows = ceil(nPlots / nCols);
        figW = opts.SaveWidth * min(nCols, 3);
        figH = opts.SaveHeight * min(nRows, 3);

        fig = figure('Visible', opts.Visible, ...
            'Position', [100, 100, figW, figH], 'Color', 'w');

        plotIdx = 0;
        for bIdx = 1:nBioM
            bioM = opts.Biomarkers{bIdx};
            for chI = 1:nCh
                ch = allChannels(chI);
                plotIdx = plotIdx + 1;

                if nPlots > 1
                    ax = subplot(nRows, nCols, plotIdx, 'Parent', fig);
                else
                    ax = axes('Parent', fig);
                end
                hold(ax, 'on');

                for g = 1:nGroups
                    curStats = plotGroupScatter(ax, groups(g), bioM, ch, ...
                        tIdx, opts, colors(g,:));
                    stats(g, bIdx, chI) = curStats;
                end

                % Labels
                if strcmp(plotMode, 'channels')
                    title(ax, sprintf('Ch %d', ch));
                elseif strcmp(plotMode, 'biomarkers')
                    title(ax, bioM);
                else
                    title(ax, sprintf('%s Ch %d', bioM, ch));
                end

                if opts.FlipXY
                    xlabel(ax, sprintf('\\Delta[%s]', bioM));
                    ylabel(ax, strrep(opts.InfoVar, '_', ' '));
                else
                    xlabel(ax, strrep(opts.InfoVar, '_', ' '));
                    ylabel(ax, sprintf('\\Delta[%s]', bioM));
                end

                grid(ax, 'on');
                box(ax, 'on');
            end
        end

        % Legend on last subplot
        if nGroups > 1
            legendLabels = cell(nGroups, 1);
            for g = 1:nGroups
                legendLabels{g} = groups(g).label;
            end
            legend(ax, legendLabels, 'Location', 'best', 'FontSize', 8);
        end

        % Title
        if ~isempty(opts.Title)
            sgtitle(fig, opts.Title);
        else
            corrStr = opts.CorrType;
            sgtitle(fig, sprintf('%s vs fNIRS (%s)', ...
                strrep(opts.InfoVar, '_', ' '), corrStr));
        end
    end

    % Save
    if ~isempty(opts.SavePath)
        if ~isempty(which('pf2_base.plot.saveFigure'))
            pf2_base.plot.saveFigure(fig, opts.SavePath, ...
                opts.SaveWidth, opts.SaveHeight, opts.SaveDPI);
        else
            set(fig, 'PaperPositionMode', 'auto');
            print(fig, opts.SavePath, '-dpng', sprintf('-r%d', opts.SaveDPI));
        end
        fprintf('Saved: %s\n', opts.SavePath);
    end
end


%% Local helpers

function curStats = plotGroupScatter(ax, group, bioM, ch, tIdx, opts, clr)
% Plot scatter for one group, one channel, one biomarker

    curGrand = group.gbyGrandBarFlat;
    curTable = group.gbyTables;

    % Extract Y: per-subject biomarker value at this channel and time bin
    if ~isfield(curGrand, bioM) || isempty(curGrand.(bioM))
        curStats = emptyStats();
        return;
    end

    bioData = curGrand.(bioM);
    if ch > size(bioData.data, 2) || tIdx > size(bioData.data, 1)
        curStats = emptyStats();
        return;
    end

    yVals = permute(bioData.data(tIdx, ch, :), [3, 1, 2]);

    % Hierarchical averaging of Y values
    if isfield(curGrand, 'info') && isfield(curGrand.info, 'Hierarchy')
        [yVals, outH] = pf2_base.hierarchicalAverage(yVals, ...
            curGrand.info.Hierarchy, @nanmean);
    end

    % Extract X: info variable from table, with hierarchical averaging
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

    % Hierarchical averaging of X values
    if ismember('SubjectID', curTable.Properties.VariableNames)
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
        [~, p] = sort(xVals, 'descend');
        r = 1:length(xVals);
        r(p) = r;
        xVals = r(:);

        [~, p] = sort(yVals, 'descend');
        r = 1:length(yVals);
        r(p) = r;
        yVals = r(:);
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

            % Annotation with stats
            if strcmpi(opts.CorrType, 'Spearman')
                statStr = sprintf('rho=%.3f, p=%.4f', curStats.rho, curStats.pval);
            else
                statStr = sprintf('r=%.3f, p=%.4f', curStats.r, curStats.p);
            end
            text(ax, 0.02, 0.98 - 0.06 * (find(isfield(curStats, 'r'))), ...
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

    fig = figure('Visible', opts.Visible, ...
        'Position', [100, 100, opts.SaveWidth * min(nCols, 3), ...
        opts.SaveHeight * min(nRows, 3)], 'Color', 'w');

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

                % Y: biomarker at channel
                yVals = permute(curGrand.(bioM).data(tIdx, ch, :), [3, 1, 2]);
                if isfield(curGrand, 'info') && isfield(curGrand.info, 'Hierarchy')
                    yVals = pf2_base.hierarchicalAverage(yVals, ...
                        curGrand.info.Hierarchy, @nanmean);
                end

                % X: info variable
                xData = curTable.(opts.InfoVar);
                if ~isnumeric(xData)
                    xData = double(string(xData));
                end
                xData(xData == -9999) = NaN;
                if ismember('SubjectID', curTable.Properties.VariableNames)
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
            [curQ, curK] = exploreFNIRS.fx.performFDR(curP, opts.SigThreshold);

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
                % Plot using interpolateValues if available
                if ~isempty(which('pf2.probe.plot.interpolateValues'))
                    axes(ax); %#ok<LAXES>
                    pf2.probe.plot.interpolateValues(curR, [], ...
                        [minR, -minR], [], groups(g).label, clrBarTitle, ...
                        'bufferDistance', 1);
                else
                    % Fallback: simple bar-style plot
                    bar(ax, allChannels, curR, 'FaceColor', 'flat');
                    ylabel(ax, clrBarTitle);
                    xlabel(ax, 'Channel');
                    title(ax, groups(g).label);
                end
            else
                % No significant channels
                text(ax, 0.5, 0.5, sprintf('%s\nn.s.', groups(g).label), ...
                    'HorizontalAlignment', 'center', 'Units', 'normalized');
                axis(ax, 'off');
            end
        end
    end

    % Title
    if ~isempty(opts.Title)
        sgtitle(fig, opts.Title);
    else
        sgtitle(fig, sprintf('Topo: %s (%s, %s=%.2f)', ...
            strrep(opts.InfoVar, '_', ' '), opts.CorrType, ...
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


function s = emptyStats()
% Return empty stats struct
    s = struct('r', NaN, 'p', NaN, 'rho', NaN, 'pval', NaN, ...
        'N', 0, 'coefficients', [], 'q', []);
end
