function fig = plotTopo(groups, varargin)
% PLOTTOPO Group-level 2D topographic maps of biomarker amplitude
%
% Creates topographic headplots showing spatial distribution of mean
% biomarker values across channels for each group. Supports time-point
% snapshots and time-window averages. When a Device is provided, channels
% are positioned according to the probe geometry and short-separation
% channels are excluded.
%
% Syntax:
%   fig = exploreFNIRS.core.plotTopo(groups)
%   fig = exploreFNIRS.core.plotTopo(groups, 'Time', 10)
%   fig = exploreFNIRS.core.plotTopo(groups, 'TimeWindow', [5, 15])
%   fig = exploreFNIRS.core.plotTopo(groups, 'Layout', 'pergroup')
%
% Inputs:
%   groups - Struct array from Experiment.groups (after aggregate())
%
% Name-Value Parameters:
%   Biomarker     - Biomarker to plot (default: 'HbO')
%   Device        - pf2.Device object for probe layout (default: [])
%   Time          - Single time point for snapshot (default: [])
%   TimeWindow    - [start, end] seconds to average over (default: full)
%   Colormap      - Colormap name or matrix (default: 'jet')
%   CLim          - Color limits [cmin cmax] (default: auto)
%   Layout        - 'single' (average groups) or 'pergroup' (side-by-side)
%   Interpolation - 'none' (default) or 'natural'
%   Title         - Figure title (default: auto)
%   Visible       - 'on' (default) or 'off'
%   SavePath      - File path to save figure
%   SaveWidth     - Width in pixels (default: 600)
%   SaveHeight    - Height in pixels (default: 500)
%   SaveDPI       - Resolution (default: 150)
%
% Outputs:
%   fig - Figure handle
%
% See also: exploreFNIRS.core.plotTemporal, exploreFNIRS.core.plotBar

    p = inputParser;
    addRequired(p, 'groups', @isstruct);
    addParameter(p, 'Biomarker', 'HbO', @ischar);
    addParameter(p, 'Device', [], @(v) isempty(v) || isa(v, 'pf2.Device'));
    addParameter(p, 'Time', [], @(v) isempty(v) || (isnumeric(v) && isscalar(v)));
    addParameter(p, 'TimeWindow', [], @(v) isempty(v) || (isnumeric(v) && numel(v) == 2));
    addParameter(p, 'Colormap', 'jet', @(v) ischar(v) || isnumeric(v));
    addParameter(p, 'CLim', [], @(v) isempty(v) || (isnumeric(v) && numel(v) == 2));
    addParameter(p, 'Layout', 'single', @ischar);
    addParameter(p, 'Interpolation', 'none', @ischar);
    addParameter(p, 'Title', '', @ischar);
    addParameter(p, 'Visible', 'on', @ischar);
    addParameter(p, 'SavePath', '', @ischar);
    addParameter(p, 'SaveWidth', 600, @isnumeric);
    addParameter(p, 'SaveHeight', 500, @isnumeric);
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
            error('exploreFNIRS:core:plotTopo', ...
                'Group %d has no grand average. Call aggregate() first.', g);
        end
    end

    % Resolve probe layout from Device
    [probeXY, chMask, chNums] = resolveProbeLayout(opts.Device);

    % Determine layout
    if strcmpi(opts.Layout, 'pergroup') && nGroups > 1
        nPanels = nGroups;
        figW = opts.SaveWidth * min(nPanels, 4);
    else
        nPanels = 1;
        figW = opts.SaveWidth;
    end

    fig = pf2_base.plot.createFigure('Visible', opts.Visible, ...
        'Width', figW, 'Height', opts.SaveHeight, 'SavePath', opts.SavePath);

    % Extract channel values per group
    groupValues = cell(1, nGroups);
    for g = 1:nGroups
        ga = groups(g).gbyGrand;
        if ~isfield(ga, bioM) || isempty(ga.(bioM))
            continue;
        end

        timeVec = ga.time;
        meanData = ga.(bioM).Mean;  % [T x C]

        % Time selection
        if ~isempty(opts.Time)
            [~, tIdx] = min(abs(timeVec - opts.Time));
            vals = meanData(tIdx, :);
        elseif ~isempty(opts.TimeWindow)
            tMask = timeVec >= opts.TimeWindow(1) & timeVec <= opts.TimeWindow(2);
            vals = mean(meanData(tMask, :), 1, 'omitnan');
        else
            vals = mean(meanData, 1, 'omitnan');
        end

        % Filter to non-short-sep channels
        if ~isempty(chMask) && length(vals) >= length(chMask)
            vals = vals(chMask);
        end

        groupValues{g} = vals(:)';
    end

    % Determine CLim
    if isempty(opts.CLim)
        allVals = cell2mat(groupValues(~cellfun(@isempty, groupValues)));
        if ~isempty(allVals)
            maxAbs = max(abs(allVals(:)));
            if maxAbs > 0
                cLim = [-maxAbs, maxAbs];
            else
                cLim = [-1, 1];
            end
        else
            cLim = [-1, 1];
        end
    else
        cLim = opts.CLim;
    end

    % Plot
    if nPanels == 1
        % Average across groups or single group
        validVals = groupValues(~cellfun(@isempty, groupValues));
        if isempty(validVals)
            return;
        end
        allMat = cell2mat(validVals');
        avgVals = mean(allMat, 1, 'omitnan');

        ax = axes('Parent', fig);
        plotTopoOnAxes(ax, avgVals, probeXY, chNums, opts, cLim);

        sty = pf2_base.plot.PlotStyle.getDefault();
        sty.applyToAxes(ax);
    else
        % Per-group panels
        for g = 1:nPanels
            ax = subplot(1, nPanels, g, 'Parent', fig);
            if ~isempty(groupValues{g})
                plotTopoOnAxes(ax, groupValues{g}, probeXY, chNums, opts, cLim);
            end
            title(ax, pf2_base.plot.escapeTeX(groups(g).label), 'FontSize', 11);

            sty = pf2_base.plot.PlotStyle.getDefault();
            sty.applyToAxes(ax);
        end
    end

    % Title
    if ~isempty(opts.Title)
        pf2_base.external.suptitle(fig, opts.Title);
    else
        tStr = bioM;
        if ~isempty(opts.Time)
            tStr = sprintf('%s at t=%.1fs', tStr, opts.Time);
        elseif ~isempty(opts.TimeWindow)
            tStr = sprintf('%s [%.1f-%.1f]s', tStr, opts.TimeWindow(1), opts.TimeWindow(2));
        end
        pf2_base.external.suptitle(fig, tStr);
    end

    pf2_base.plot.handleSave(fig, opts);
end


function [probeXY, chMask, chNums] = resolveProbeLayout(dev)
% Extract 2D probe positions and short-sep mask from Device
%   probeXY - [nStd x 2] normalized (x,y) centers for standard channels
%   chMask  - [1 x nTotal] logical, true for standard channels
%   chNums  - [1 x nStd] channel numbers for labels

    probeXY = [];
    chMask  = [];
    chNums  = [];

    if isempty(dev)
        return;
    end

    % Get short-sep mask
    ssMask = dev.isShortSep();
    chMask = ~ssMask;

    % Get layout positions (cell array of [x, y, w, h])
    lay = dev.layout2D();
    if isempty(lay)
        chMask = [];
        return;
    end

    % Extract center positions for standard channels
    stdIdx = find(chMask);
    probeXY = zeros(length(stdIdx), 2);
    chNums  = zeros(1, length(stdIdx));
    for i = 1:length(stdIdx)
        pos = lay{stdIdx(i)};
        if isempty(pos)
            % Fallback: shouldn't happen for standard channels
            probeXY(i, :) = [i, 1];
        else
            probeXY(i, 1) = pos(1) + pos(3) / 2;  % x center
            probeXY(i, 2) = pos(2) + pos(4) / 2;  % y center
        end
        chNums(i) = stdIdx(i);
    end

    % Flip Y so top of head is at top of plot
    probeXY(:, 2) = 1 - probeXY(:, 2);
end


function plotTopoOnAxes(ax, vals, probeXY, chNums, opts, cLim)
% Plot topographic map on a single axes
    nCh = length(vals);

    % Determine channel positions
    if ~isempty(probeXY) && size(probeXY, 1) == nCh
        xPos = probeXY(:, 1)';
        yPos = probeXY(:, 2)';
        labels = chNums;
    else
        % Fallback: grid layout
        nCols = ceil(sqrt(nCh));
        nRows = ceil(nCh / nCols);
        xPos = zeros(1, nCh);
        yPos = zeros(1, nCh);
        for c = 1:nCh
            row = ceil(c / nCols);
            col = mod(c - 1, nCols) + 1;
            xPos(c) = col;
            yPos(c) = nRows - row + 1;
        end
        labels = 1:nCh;
    end

    if strcmpi(opts.Interpolation, 'natural') && nCh > 3
        % Interpolated surface
        padX = 0.05 * (max(xPos) - min(xPos) + eps);
        padY = 0.05 * (max(yPos) - min(yPos) + eps);
        xq = linspace(min(xPos) - padX, max(xPos) + padX, 80);
        yq = linspace(min(yPos) - padY, max(yPos) + padY, 80);
        [XQ, YQ] = meshgrid(xq, yq);

        F = scatteredInterpolant(xPos(:), yPos(:), vals(:), 'natural', 'none');
        ZQ = F(XQ, YQ);

        imagesc(ax, xq, yq, ZQ, cLim);
        set(ax, 'YDir', 'normal');
        hold(ax, 'on');
        scatter(ax, xPos, yPos, 30, vals, 'filled', 'MarkerEdgeColor', 'k');
        hold(ax, 'off');
    else
        % Discrete circles per channel
        hold(ax, 'on');
        scatter(ax, xPos, yPos, 200, vals, 'filled', 'MarkerEdgeColor', 'k');

        for c = 1:nCh
            text(ax, xPos(c), yPos(c), sprintf('%d', labels(c)), ...
                'HorizontalAlignment', 'center', 'FontSize', 7, 'Color', 'w');
        end
        hold(ax, 'off');
        set(ax, 'CLim', cLim);
    end

    axis(ax, 'equal');
    padX = 0.08 * (max(xPos) - min(xPos) + eps);
    padY = 0.08 * (max(yPos) - min(yPos) + eps);
    xlim(ax, [min(xPos) - padX, max(xPos) + padX]);
    ylim(ax, [min(yPos) - padY, max(yPos) + padY]);
    set(ax, 'XTick', [], 'YTick', []);

    if ischar(opts.Colormap)
        cmapFn = exploreFNIRS.helper.getColormap(opts.Colormap);
        colormap(ax, cmapFn(256));
    else
        colormap(ax, opts.Colormap);
    end
    colorbar(ax);
end
