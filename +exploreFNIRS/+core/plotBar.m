function fig = plotBar(groups, varargin)
% PLOTBAR Headless bar chart from grouped/aggregated experiment data
%
% Creates bar charts showing mean biomarker values per group for selected
% channels and time windows, with error bars. Works without the
% exploreFNIRS GUI.
%
% Syntax:
%   fig = plotBar(groups)
%   fig = plotBar(groups, 'Biomarker', 'HbO', 'Channels', 1:5)
%   fig = plotBar(groups, 'ROIs', 'all', 'Biomarker', 'HbO')
%   fig = plotBar(groups, 'SavePath', 'barchart.png')
%
% Inputs:
%   groups - Struct array from Experiment.groups (after aggregate())
%            Each element must have .gbyGrand with .HbO, .HbR, etc.
%
% Name-Value Parameters:
%   Biomarker   - Single biomarker name (default: 'HbO')
%   Channels    - Vector of channel indices (default: all)
%   ROIs        - ROI indices, names, or 'all' (default: [])
%                 When provided, data is read from gbyGrand.ROI instead of
%                 gbyGrand. Mutually exclusive with Channels.
%   TimeWindow  - [start, end] in seconds to average over (default: full range)
%   ErrorType   - 'SEM' (default), 'SD', or 'none'
%   ShowIndividual - Show individual data points (default: false)
%   Title       - Figure title (default: auto)
%   Visible     - 'on' (default) or 'off'
%   SavePath    - File path to save figure
%   SaveWidth   - Width in pixels (default: 600)
%   SaveHeight  - Height in pixels (default: 400)
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
%   % Bar chart for HbO, channels 1-10, averaged over 5-20s
%   fig = exploreFNIRS.core.plotBar(ex.groups, ...
%       'Biomarker', 'HbO', 'Channels', 1:10, ...
%       'TimeWindow', [5, 20], 'SavePath', 'bar.png');
%
% See also: exploreFNIRS.core.Experiment, exploreFNIRS.core.plotTemporal

    p = inputParser;
    addRequired(p, 'groups', @isstruct);
    addParameter(p, 'Biomarker', 'HbO', @ischar);
    addParameter(p, 'Channels', [], @isnumeric);
    addParameter(p, 'ROIs', [], @(x) isnumeric(x) || islogical(x) || ischar(x) || isstring(x) || iscell(x));
    addParameter(p, 'TimeWindow', [], @isnumeric);
    addParameter(p, 'ErrorType', 'SEM', @ischar);
    addParameter(p, 'ShowIndividual', false, @islogical);
    addParameter(p, 'Title', '', @ischar);
    addParameter(p, 'Visible', 'on', @ischar);
    addParameter(p, 'SavePath', '', @ischar);
    addParameter(p, 'SaveWidth', 600, @isnumeric);
    addParameter(p, 'SaveHeight', 400, @isnumeric);
    addParameter(p, 'SaveDPI', 150, @isnumeric);
    parse(p, groups, varargin{:});
    opts = p.Results;

    if ~isempty(opts.SavePath)
        opts.Visible = 'off';
    end

    bioM = opts.Biomarker;
    nGroups = length(groups);

    % Validate
    for g = 1:nGroups
        if isempty(groups(g).gbyGrand)
            error('exploreFNIRS:core:plotBar', ...
                'Group %d has no grand average. Call aggregate() first.', g);
        end
    end

    % Resolve ROI mode
    if ~isempty(opts.ROIs)
        if ~any(strcmp(p.UsingDefaults, 'Channels'))
            error('exploreFNIRS:core:plotBar', ...
                'ROIs and Channels are mutually exclusive.');
        end
        if ~isfield(groups(1).gbyGrand, 'ROI')
            error('exploreFNIRS:core:plotBar', ...
                'No ROI data in grand average. Define ROIs before aggregating.');
        end
        [roiIdx, roiNames] = resolveROIs(groups, opts.ROIs);
        useROI = true;
    else
        useROI = false;
    end

    % Determine channels/ROIs
    if useROI
        channels = roiIdx;
    elseif isempty(opts.Channels)
        nCh = size(groups(1).gbyGrand.(bioM).Mean, 2);
        channels = 1:nCh;
    else
        channels = opts.Channels;
    end
    nCh = length(channels);

    % For each group: compute mean and error across time window and channels
    groupMeans = nan(1, nGroups);
    groupErrors = nan(1, nGroups);
    groupN = nan(1, nGroups);
    groupLabels = cell(1, nGroups);
    individualData = cell(1, nGroups);

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

        % Time window selection
        if ~isempty(opts.TimeWindow)
            tMask = timeVec >= opts.TimeWindow(1) & timeVec <= opts.TimeWindow(2);
        else
            tMask = true(size(timeVec));
        end

        if ~any(tMask), continue; end

        % Select data source
        if useROI
            src = ga.ROI.(bioM);
        else
            src = ga.(bioM);
        end

        chIdx = channels(channels <= size(src.Mean, 2));
        if isempty(chIdx), continue; end

        % Grand mean: average over time window and channels/ROIs
        meanSlice = src.Mean(tMask, chIdx);
        groupMeans(g) = mean(meanSlice, 'all', 'omitnan');

        % Error: use the per-subject data for proper SEM
        if isfield(src, 'data') && ~isempty(src.data)
            % data is [T x C x N]
            subjectData = src.data(tMask, chIdx, :);
            % Average over time and channels per subject
            perSubject = squeeze(mean(mean(subjectData, 1, 'omitnan'), 2, 'omitnan'));
            perSubject = perSubject(:);
            perSubject(isnan(perSubject)) = [];

            groupN(g) = length(perSubject);
            individualData{g} = perSubject;

            switch upper(opts.ErrorType)
                case 'SEM'
                    groupErrors(g) = std(perSubject, 'omitnan') / sqrt(groupN(g));
                case 'SD'
                    groupErrors(g) = std(perSubject, 'omitnan');
                case 'NONE'
                    groupErrors(g) = 0;
            end
        else
            % Fallback to pre-computed stats
            semSlice = src.SEM(tMask, chIdx);
            groupErrors(g) = mean(semSlice, 'all', 'omitnan');
            nSlice = src.N(tMask, chIdx);
            groupN(g) = round(mean(nSlice, 'all', 'omitnan'));
        end

        groupLabels{g} = groups(g).label;
    end

    % Create figure
    fig = figure('Visible', opts.Visible, ...
        'Position', [100, 100, opts.SaveWidth, opts.SaveHeight], ...
        'Color', 'w');
    ax = axes('Parent', fig);
    hold(ax, 'on');

    % Colors
    colors = exploreFNIRS.core.getGroupColors(nGroups);

    % Bar plot
    barX = 1:nGroups;
    for g = 1:nGroups
        bar(ax, barX(g), groupMeans(g), 0.6, ...
            'FaceColor', colors(g,:), 'EdgeColor', 'k', 'FaceAlpha', 0.7);
    end

    % Error bars
    if ~strcmpi(opts.ErrorType, 'none')
        errorbar(ax, barX, groupMeans, groupErrors, 'k.', ...
            'LineWidth', 1.2, 'CapSize', 8);
    end

    % Individual data points
    if opts.ShowIndividual
        for g = 1:nGroups
            if ~isempty(individualData{g})
                jitter = (rand(size(individualData{g})) - 0.5) * 0.25;
                scatter(ax, barX(g) + jitter, individualData{g}, 20, ...
                    colors(g,:), 'filled', 'MarkerFaceAlpha', 0.5, ...
                    'HandleVisibility', 'off');
            end
        end
    end

    % Labels
    set(ax, 'XTick', barX, 'XTickLabel', groupLabels, 'XTickLabelRotation', 30);
    ylabel(ax, sprintf('%s (%s)', bioM, getUnitsLabel(groups(1))));

    % N labels above bars
    for g = 1:nGroups
        if ~isnan(groupN(g))
            yPos = groupMeans(g) + groupErrors(g);
            if isnan(yPos), yPos = groupMeans(g); end
            text(ax, barX(g), yPos, sprintf('n=%d', groupN(g)), ...
                'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', ...
                'FontSize', 8);
        end
    end

    % Zero line
    plot(ax, xlim(ax), [0 0], 'k-', 'LineWidth', 0.5, 'HandleVisibility', 'off');

    % Title
    if ~isempty(opts.Title)
        title(ax, opts.Title);
    else
        if useROI
            if nCh == 1
                itemStr = roiNames{1};
            else
                itemStr = sprintf('ROIs: %s', strjoin(roiNames, ', '));
            end
        else
            if nCh == 1
                itemStr = sprintf('Ch %d', channels(1));
            else
                itemStr = sprintf('Ch %d-%d', channels(1), channels(end));
            end
        end
        if ~isempty(opts.TimeWindow)
            tStr = sprintf(', %g-%gs', opts.TimeWindow(1), opts.TimeWindow(2));
        else
            tStr = '';
        end
        title(ax, sprintf('%s: %s%s', bioM, itemStr, tStr));
    end

    box(ax, 'on');
    grid(ax, 'on');

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


function lbl = getUnitsLabel(group)
    if ~isempty(group.gbyGrand) && isfield(group.gbyGrand, 'units')
        lbl = group.gbyGrand.units;
    else
        lbl = '\DeltaHb';
    end
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
