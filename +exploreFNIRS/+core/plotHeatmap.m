function fig = plotHeatmap(groups, varargin)
% PLOTHEATMAP Channel x time heatmap for grouped fNIRS data
%
% Renders a channel-by-time heatmap showing biomarker amplitude as color,
% with channels on Y-axis and time on X-axis. Useful for identifying
% spatial-temporal activation patterns.
%
% Syntax:
%   fig = exploreFNIRS.core.plotHeatmap(groups)
%   fig = exploreFNIRS.core.plotHeatmap(groups, 'Biomarker', 'HbR')
%   fig = exploreFNIRS.core.plotHeatmap(groups, 'SortChannels', 'amplitude')
%
% Inputs:
%   groups - Struct array from Experiment.groups (after aggregate())
%
% Name-Value Parameters:
%   Biomarker     - Biomarker to plot (default: 'HbO')
%   Channels      - Channel indices to include (default: all)
%   Device        - pf2.Device object for short-sep detection (default: [])
%   ExcludeShortSeparation - Exclude short-sep channels (default: true)
%   GroupIndex    - Which group to plot (default: 1)
%   SortChannels  - Channel ordering: 'index' (default), 'amplitude'
%   Colormap      - Colormap name or [N x 3] matrix (default: blue-white-red)
%                   Supports MATLAB builtins, Brewer (e.g. 'RdBu', 'Spectral'),
%                   and matplotlib (e.g. 'viridis', 'plasma') names.
%   CLim          - Color limits [cmin cmax] (default: auto symmetric)
%   XLim          - [min max] x-axis (time) limits for visual cropping
%                   (default: full data range)
%   VLines        - Vertical annotation lines (e.g. task start/end).
%                   Numeric vector of time positions (default dashed gray), or
%                   struct array with fields:
%                     .time  - (required) scalar time position
%                     .label - (optional) text label string
%                     .color - (optional) color spec (default: [0.5 0.5 0.5])
%                     .style - (optional) line style (default: '--')
%   Title         - Figure title (default: auto)
%   Visible       - 'on' (default) or 'off'
%   SavePath      - File path to save figure
%   SaveWidth     - Width in pixels (default: 800)
%   SaveHeight    - Height in pixels (default: 500)
%   SaveDPI       - Resolution (default: 150)
%
% Outputs:
%   fig - Figure handle
%
% See also: exploreFNIRS.core.plotTopo, exploreFNIRS.core.plotTemporal

    p = inputParser;
    addRequired(p, 'groups', @isstruct);
    addParameter(p, 'Biomarker', 'HbO', @ischar);
    addParameter(p, 'Channels', [], @isnumeric);
    addParameter(p, 'ROIs', [], @(x) isnumeric(x) || islogical(x) || ischar(x) || isstring(x) || iscell(x));
    addParameter(p, 'Device', [], @(v) isempty(v) || isa(v, 'pf2.Device'));
    addParameter(p, 'ExcludeShortSeparation', true, @islogical);
    addParameter(p, 'GroupIndex', 1, @(v) isnumeric(v) && isscalar(v));
    addParameter(p, 'SortChannels', 'index', @ischar);
    addParameter(p, 'Colormap', '', @(v) ischar(v) || isnumeric(v));
    addParameter(p, 'CLim', [], @(v) isempty(v) || (isnumeric(v) && numel(v) == 2));
    addParameter(p, 'XLim', [], @(v) isempty(v) || (isnumeric(v) && numel(v) == 2));
    addParameter(p, 'VLines', [], @(x) isempty(x) || isnumeric(x) || isstruct(x));
    addParameter(p, 'Title', '', @ischar);
    addParameter(p, 'Visible', 'on', @ischar);
    addParameter(p, 'SavePath', '', @ischar);
    addParameter(p, 'SaveWidth', 800, @isnumeric);
    addParameter(p, 'SaveHeight', 500, @isnumeric);
    addParameter(p, 'SaveDPI', 150, @isnumeric);
    addParameter(p, 'TightLayout', false, @islogical);
    addParameter(p, 'Colors', [], @(x) true);  % Accepted for API consistency, unused (heatmaps use Colormap)
    parse(p, groups, varargin{:});
    opts = p.Results;

    if ~isempty(opts.SavePath)
        opts.Visible = 'off';
    end

    bioM = opts.Biomarker;
    gi = opts.GroupIndex;

    if gi > length(groups)
        error('exploreFNIRS:core:plotHeatmap', ...
            'GroupIndex %d exceeds number of groups (%d)', gi, length(groups));
    end

    ga = groups(gi).gbyGrand;
    if isempty(ga)
        error('exploreFNIRS:core:plotHeatmap', ...
            'Group %d has no grand average. Call aggregate() first.', gi);
    end

    % Resolve ROIs vs Channels
    useROI = ~isempty(opts.ROIs);
    if useROI
        if ~isempty(opts.Channels)
            error('exploreFNIRS:core:plotHeatmap', ...
                'ROIs and Channels are mutually exclusive.');
        end
        if ~isfield(ga, 'ROI')
            error('exploreFNIRS:core:plotHeatmap', ...
                'No ROI data in grand average. Define ROIs before aggregating.');
        end
        [roiIdx, roiNames] = resolveROIs(groups(gi:gi), opts.ROIs);
        if ~isfield(ga.ROI, bioM) || isempty(ga.ROI.(bioM))
            error('exploreFNIRS:core:plotHeatmap', ...
                'Biomarker "%s" not found in ROI data', bioM);
        end
        timeVec = ga.time;
        meanData = ga.ROI.(bioM).Mean;  % [T x nROI]
        channels = roiIdx;
        chLabelsCustom = roiNames;
    else
        if ~isfield(ga, bioM) || isempty(ga.(bioM))
            error('exploreFNIRS:core:plotHeatmap', ...
                'Biomarker "%s" not found in group %d', bioM, gi);
        end
        timeVec = ga.time;
        meanData = ga.(bioM).Mean;  % [T x C]
        if isempty(opts.Channels)
            channels = 1:size(meanData, 2);
        else
            channels = opts.Channels(opts.Channels <= size(meanData, 2));
        end
        % Exclude short-separation channels
        if opts.ExcludeShortSeparation
            ssIdx = getShortSeparationIdx(opts.Device, groups);
            if ~isempty(ssIdx)
                channels = channels(~ismember(channels, ssIdx));
            end
        end
        chLabelsCustom = {};
    end
    nCh = length(channels);

    plotData = meanData(:, channels)';  % [C x T]

    % Sort channels
    switch lower(opts.SortChannels)
        case 'amplitude'
            chMean = mean(plotData, 2, 'omitnan');
            [~, sortIdx] = sort(chMean, 'descend');
            plotData = plotData(sortIdx, :);
            channels = channels(sortIdx);
            if ~isempty(chLabelsCustom)
                chLabelsCustom = chLabelsCustom(sortIdx);
            end
        case 'index'
            % keep as-is
    end

    % CLim
    if isempty(opts.CLim)
        maxAbs = max(abs(plotData(:)));
        if maxAbs > 0
            cLim = [-maxAbs, maxAbs];
        else
            cLim = [-1, 1];
        end
    else
        cLim = opts.CLim;
    end

    fig = pf2_base.plot.createFigure('Visible', opts.Visible, ...
        'Width', opts.SaveWidth, 'Height', opts.SaveHeight, ...
        'SavePath', opts.SavePath);
    ax = axes('Parent', fig);

    imagesc(ax, timeVec, 1:nCh, plotData, cLim);
    set(ax, 'YDir', 'normal');

    % Channel/ROI labels
    if ~isempty(chLabelsCustom)
        chLabels = chLabelsCustom;
    else
        chLabels = arrayfun(@(c) sprintf('Ch%d', c), channels, 'UniformOutput', false);
    end
    chLabels = pf2_base.plot.escapeTeX(chLabels);
    if nCh <= 30
        set(ax, 'YTick', 1:nCh, 'YTickLabel', chLabels);
    else
        tickStep = ceil(nCh / 20);
        ticks = 1:tickStep:nCh;
        set(ax, 'YTick', ticks, 'YTickLabel', chLabels(ticks));
    end

    xlabel(ax, 'Time (s)');
    if useROI
        ylabel(ax, 'ROI');
    else
        ylabel(ax, 'Channel');
    end

    % Colormap
    if isempty(opts.Colormap)
        colormap(ax, divergingColormap(256));
    elseif ischar(opts.Colormap)
        colormap(ax, resolveColormapName(opts.Colormap, 256));
    else
        colormap(ax, opts.Colormap);
    end
    cb = colorbar(ax);
    cb.Label.String = bioM;

    sty = pf2_base.plot.PlotStyle.getDefault();
    sty.applyToAxes(ax);

    % Title
    if ~isempty(opts.Title)
        title(ax, opts.Title);
    else
        title(ax, sprintf('%s Heatmap - %s', bioM, pf2_base.plot.escapeTeX(groups(gi).label)));
    end

    % Colorbar styling
    set(cb, 'Color', sty.ForegroundColor);
    set(cb.Label, 'Color', sty.ForegroundColor);

    % Visual x-axis cropping (does not change underlying data)
    if ~isempty(opts.XLim)
        xlim(ax, opts.XLim);
    end

    % Vertical annotation lines (task start/end etc.)
    if ~isempty(opts.VLines)
        drawVLines(ax, opts.VLines);
    end

    sty.applyToFigure(fig);
    pf2_base.plot.handleSave(fig, opts);
end


function drawVLines(ax, vlines)
% Draw vertical annotation lines on heatmap axes
    if isnumeric(vlines)
        vlines = vlines(:);
        tmp = struct('time', num2cell(vlines), ...
            'label', repmat({''}, numel(vlines), 1), ...
            'color', repmat({[0.5 0.5 0.5]}, numel(vlines), 1), ...
            'style', repmat({'--'}, numel(vlines), 1));
        vlines = tmp;
    end

    for vi = 1:numel(vlines)
        v = vlines(vi);
        xPos = v.time;

        if isfield(v, 'color') && ~isempty(v.color)
            clr = v.color;
        else
            clr = [0.5 0.5 0.5];
        end

        if isfield(v, 'style') && ~isempty(v.style)
            sty = v.style;
        else
            sty = '--';
        end

        if isfield(v, 'label') && ~isempty(v.label)
            lbl = {v.label};
        else
            lbl = {};
        end

        hasLabel = ~isempty(lbl);
        lineArgs = {'Color', clr, 'LineStyle', sty, 'LineWidth', 1};
        pf2_base.external.vline(ax, xPos, lineArgs, lbl, ...
            'handleVisibility', hasLabel);
    end
end


function cmap = divergingColormap(n)
% Blue-white-red diverging colormap
    half = floor(n / 2);
    r1 = linspace(0.2, 1, half)';
    g1 = linspace(0.3, 1, half)';
    b1 = linspace(0.8, 1, half)';
    r2 = linspace(1, 0.8, n - half)';
    g2 = linspace(1, 0.2, n - half)';
    b2 = linspace(1, 0.2, n - half)';
    cmap = [r1 g1 b1; r2 g2 b2];
end


function cmap = resolveColormapName(name, n)
% Resolve a colormap name to an [n x 3] RGB matrix via getColormap
    cmapFn = exploreFNIRS.helper.getColormap(name);
    cmap = cmapFn(n);
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


function ssIdx = getShortSeparationIdx(dev, groups)
% Get short-separation channel indices from Device or probe info
    ssIdx = [];

    % Method 1: Device object
    if ~isempty(dev) && isa(dev, 'pf2.Device')
        ssMask = dev.isShortSep();
        ssIdx = find(ssMask);
        return;
    end

    % Method 2: Probe info in group data
    for g = 1:length(groups)
        ga = groups(g).gbyGrand;
        if isfield(ga, 'probeInfo') && isstruct(ga.probeInfo)
            pi = ga.probeInfo;
            if isfield(pi, 'TableOpt') && istable(pi.TableOpt) ...
                    && ismember('IsShortSeparation', pi.TableOpt.Properties.VariableNames)
                ssIdx = find(pi.TableOpt.IsShortSeparation);
                return;
            end
            if isfield(pi, 'SD') && isstruct(pi.SD) && isfield(pi.SD, 'distances')
                ssIdx = find(pi.SD.distances < 2);
                return;
            end
        end
    end
end
