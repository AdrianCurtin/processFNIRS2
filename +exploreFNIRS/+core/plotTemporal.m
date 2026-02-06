function fig = plotTemporal(groups, varargin)
% PLOTTEMPORAL Headless temporal plot from grouped/aggregated experiment data
%
% Creates publication-ready time-series plots showing the hemodynamic
% response for each group, with shaded error bands. Works without the
% exploreFNIRS GUI.
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
%   Channels    - Vector of channel indices to plot (default: 1)
%   ROIs        - ROI indices, names, or 'all' (default: [])
%                 When provided, data is read from gbyGrand.ROI instead of
%                 gbyGrand. Mutually exclusive with Channels.
%   ErrorType   - 'SEM' (default), 'SD', or 'none'
%   Layout      - 'overlay' (default) or 'grid'
%                 'overlay': all channels on one axes per biomarker
%                 'grid': separate subplot per channel
%   YLim        - [min max] y-axis limits (default: auto)
%   XLim        - [min max] x-axis limits (default: auto)
%   Title       - Figure title (default: auto-generated)
%   Visible     - 'on' (default) or 'off' for headless mode
%   SavePath    - File path to save figure (triggers headless)
%   SaveWidth   - Width in pixels (default: 800)
%   SaveHeight  - Height in pixels (default: 500)
%   SaveDPI     - Resolution (default: 150)
%
% Outputs:
%   fig - Figure handle
%
% Example:
%   ex = exploreFNIRS.core.Experiment(data);
%   ex.groupby({'Group','Condition'});
%   ex.aggregate();
%
%   % Interactive plot
%   fig = exploreFNIRS.core.plotTemporal(ex.groups, ...
%       'Biomarkers', {'HbO'}, 'Channels', [5, 10]);
%
%   % Headless save
%   exploreFNIRS.core.plotTemporal(ex.groups, ...
%       'Biomarkers', {'HbO','HbR'}, 'Channels', 1, ...
%       'SavePath', 'temporal_plot.png', 'SaveDPI', 300);
%
% See also: exploreFNIRS.core.Experiment, exploreFNIRS.core.plotBar

    p = inputParser;
    addRequired(p, 'groups', @isstruct);
    addParameter(p, 'Biomarkers', {'HbO','HbR'}, @iscell);
    addParameter(p, 'Channels', 1, @isnumeric);
    addParameter(p, 'ROIs', [], @(x) isnumeric(x) || islogical(x) || ischar(x) || isstring(x) || iscell(x));
    addParameter(p, 'ErrorType', 'SEM', @ischar);
    addParameter(p, 'Layout', 'overlay', @ischar);
    addParameter(p, 'YLim', [], @isnumeric);
    addParameter(p, 'XLim', [], @isnumeric);
    addParameter(p, 'Title', '', @ischar);
    addParameter(p, 'Visible', 'on', @ischar);
    addParameter(p, 'SavePath', '', @ischar);
    addParameter(p, 'SaveWidth', 800, @isnumeric);
    addParameter(p, 'SaveHeight', 500, @isnumeric);
    addParameter(p, 'SaveDPI', 150, @isnumeric);
    parse(p, groups, varargin{:});
    opts = p.Results;

    % Force headless if saving
    if ~isempty(opts.SavePath)
        opts.Visible = 'off';
    end

    % Resolve ROI mode
    if ~isempty(opts.ROIs)
        if ~any(strcmp(p.UsingDefaults, 'Channels'))
            error('exploreFNIRS:core:plotTemporal', ...
                'ROIs and Channels are mutually exclusive.');
        end
        if ~isfield(groups(1).gbyGrand, 'ROI')
            error('exploreFNIRS:core:plotTemporal', ...
                'No ROI data in grand average. Define ROIs before aggregating.');
        end
        [roiIdx, roiNames] = resolveROIs(groups, opts.ROIs);
        useROI = true;
        nItems = length(roiIdx);
    else
        useROI = false;
        nItems = length(opts.Channels);
    end

    nGroups   = length(groups);
    nBioM     = length(opts.Biomarkers);
    nChannels = nItems;

    % Validate groups have grand averages
    for g = 1:nGroups
        if isempty(groups(g).gbyGrand)
            error('exploreFNIRS:core:plotTemporal', ...
                'Group %d has no grand average. Call aggregate() first.', g);
        end
    end

    % Determine layout
    if strcmpi(opts.Layout, 'grid') && nChannels > 1
        nRows = ceil(sqrt(nChannels));
        nCols = ceil(nChannels / nRows);
        figW = opts.SaveWidth * min(nCols, 3);
        figH = opts.SaveHeight * min(nRows, 3);
    else
        nRows = 1;
        nCols = nBioM;
        figW = opts.SaveWidth;
        figH = opts.SaveHeight;
    end

    fig = figure('Visible', opts.Visible, ...
        'Position', [100, 100, figW, figH], ...
        'Color', 'w');

    % Color setup: distinct color per group
    groupColors = exploreFNIRS.core.getGroupColors(nGroups);

    % Biomarker line styles
    bioMStyles = {'-', '--', ':', '-.'};

    if strcmpi(opts.Layout, 'grid') && nChannels > 1
        % Grid layout: one subplot per channel/ROI, all biomarkers overlaid
        for iItem = 1:nChannels
            if useROI
                itemIdx = roiIdx(iItem);
                itemLabel = roiNames{iItem};
            else
                itemIdx = opts.Channels(iItem);
                itemLabel = sprintf('Ch %d', itemIdx);
            end
            ax = subplot(nRows, nCols, iItem, 'Parent', fig);
            hold(ax, 'on');

            plotItemOnAxes(ax, groups, itemIdx, opts, groupColors, bioMStyles, useROI);

            title(ax, itemLabel);
            xlabel(ax, 'Time (s)');
            if iItem == 1 || mod(iItem-1, nCols) == 0
                ylabel(ax, getUnitsLabel(groups(1)));
            end
        end
        % Single legend for the figure
        addFigureLegend(fig, groups, opts, groupColors, bioMStyles);
    else
        % Overlay layout: one axes per biomarker, channels averaged or overlaid
        for bIdx = 1:nBioM
            if nBioM > 1
                ax = subplot(1, nBioM, bIdx, 'Parent', fig);
            else
                ax = axes('Parent', fig);
            end
            hold(ax, 'on');

            bioM = opts.Biomarkers{bIdx};
            legendEntries = {};
            legendHandles = [];

            for g = 1:nGroups
                ga = groups(g).gbyGrand;

                if useROI
                    if ~isfield(ga.ROI, bioM) || isempty(ga.ROI.(bioM))
                        continue;
                    end
                else
                    if ~isfield(ga, bioM) || isempty(ga.(bioM))
                        continue;
                    end
                end

                timeVec = ga.time;

                % Select data source: ROI or channel
                if useROI
                    src = ga.ROI.(bioM);
                else
                    src = ga.(bioM);
                end

                meanData = src.Mean;
                nData = src.N;

                % Get error data
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

                % Select indices to plot
                if useROI
                    chIdx = roiIdx;
                else
                    chIdx = opts.Channels;
                end
                chIdx = chIdx(chIdx <= size(meanData, 2));
                if isempty(chIdx), continue; end

                if length(chIdx) > 1
                    mLine = mean(meanData(:, chIdx), 2, 'omitnan');
                    eLine = mean(errData(:, chIdx), 2, 'omitnan');
                else
                    mLine = meanData(:, chIdx);
                    eLine = errData(:, chIdx);
                end

                clr = groupColors(g, :);

                % Plot error band
                if ~strcmpi(opts.ErrorType, 'none') && any(eLine > 0)
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

                % Plot mean line
                h = plot(ax, timeVec, mLine, '-', ...
                    'Color', clr, 'LineWidth', 1.5);

                legendHandles(end+1) = h; %#ok<AGROW>

                % Build legend label
                lbl = groups(g).label;
                if mean(nData(:, chIdx), 'all', 'omitnan') > 0
                    nStr = sprintf(' (n=%d)', round(mean(nData(:, chIdx), 'all', 'omitnan')));
                    lbl = [lbl, nStr]; %#ok<AGROW>
                end
                legendEntries{end+1} = lbl; %#ok<AGROW>
            end

            % Zero line
            plot(ax, xlim(ax), [0 0], 'k-', 'LineWidth', 0.5, ...
                'HandleVisibility', 'off');

            title(ax, bioM);
            xlabel(ax, 'Time (s)');
            ylabel(ax, getUnitsLabel(groups(1)));

            if ~isempty(opts.YLim), ylim(ax, opts.YLim); end
            if ~isempty(opts.XLim), xlim(ax, opts.XLim); end

            if ~isempty(legendHandles)
                legend(ax, legendHandles, legendEntries, ...
                    'Location', 'best', 'FontSize', 8);
            end
            box(ax, 'on');
            grid(ax, 'on');
        end
    end

    % Figure title
    if ~isempty(opts.Title)
        sgtitle(fig, opts.Title);
    elseif useROI
        if nChannels == 1
            sgtitle(fig, roiNames{1});
        elseif ~strcmpi(opts.Layout, 'grid')
            sgtitle(fig, sprintf('ROIs: %s (averaged)', strjoin(roiNames, ', ')));
        end
    elseif nChannels == 1
        sgtitle(fig, sprintf('Channel %d', opts.Channels(1)));
    elseif nChannels > 1 && ~strcmpi(opts.Layout, 'grid')
        sgtitle(fig, sprintf('Channels %s (averaged)', mat2str(opts.Channels)));
    end

    % Save if requested
    if ~isempty(opts.SavePath)
        if exist('pf2_base.plot.saveFigure', 'file') || ...
                ~isempty(which('pf2_base.plot.saveFigure'))
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


function lbl = getUnitsLabel(group)
% Get units string from a group's grand average
    if ~isempty(group.gbyGrand) && isfield(group.gbyGrand, 'units')
        lbl = group.gbyGrand.units;
    else
        lbl = '\DeltaHb';
    end
end


function plotItemOnAxes(ax, groups, idx, opts, groupColors, bioMStyles, useROI)
% Plot all groups/biomarkers for a single channel or ROI on given axes
    nGroups = length(groups);
    nBioM = length(opts.Biomarkers);

    for g = 1:nGroups
        ga = groups(g).gbyGrand;
        clr = groupColors(g, :);

        for bIdx = 1:nBioM
            bioM = opts.Biomarkers{bIdx};
            if useROI
                if ~isfield(ga.ROI, bioM) || isempty(ga.ROI.(bioM)), continue; end
                src = ga.ROI.(bioM);
            else
                if ~isfield(ga, bioM) || isempty(ga.(bioM)), continue; end
                src = ga.(bioM);
            end
            if idx > size(src.Mean, 2), continue; end

            timeVec = ga.time;
            mLine = src.Mean(:, idx);
            style = bioMStyles{mod(bIdx-1, length(bioMStyles)) + 1};

            plot(ax, timeVec, mLine, style, 'Color', clr, 'LineWidth', 1.2);
        end
    end

    plot(ax, xlim(ax), [0 0], 'k-', 'LineWidth', 0.5, 'HandleVisibility', 'off');
    if ~isempty(opts.YLim), ylim(ax, opts.YLim); end
    if ~isempty(opts.XLim), xlim(ax, opts.XLim); end
    grid(ax, 'on');
end


function addFigureLegend(fig, groups, opts, groupColors, bioMStyles)
% Add a shared legend to the figure for grid layout
    nGroups = length(groups);
    nBioM = length(opts.Biomarkers);
    entries = {};
    handles = [];

    % Invisible axes for legend items
    axLeg = axes('Parent', fig, 'Visible', 'off', 'Position', [0 0 0.01 0.01]);
    hold(axLeg, 'on');

    for g = 1:nGroups
        for bIdx = 1:nBioM
            style = bioMStyles{mod(bIdx-1, length(bioMStyles)) + 1};
            h = plot(axLeg, NaN, NaN, style, 'Color', groupColors(g,:), 'LineWidth', 1.2);
            handles(end+1) = h; %#ok<AGROW>
            entries{end+1} = sprintf('%s %s', groups(g).label, opts.Biomarkers{bIdx}); %#ok<AGROW>
        end
    end

    legend(handles, entries, 'Location', 'southoutside', ...
        'Orientation', 'horizontal', 'FontSize', 8);
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
