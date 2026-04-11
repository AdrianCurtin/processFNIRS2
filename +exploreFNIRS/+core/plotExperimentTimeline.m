function fig = plotExperimentTimeline(settings, varargin)
% PLOTEXPERIMENTTIMELINE Visualize experiment time settings as a timeline diagram
%
% Shows the relationship between baseline, task block, temporal resample,
% and bar chart resample settings. Useful for verifying configuration
% before running aggregate().
%
% Syntax:
%   fig = plotExperimentTimeline(settings)
%   fig = plotExperimentTimeline(settings, 'DataRange', [-10, 40])
%   fig = plotExperimentTimeline(settings, 'SavePath', 'timeline.png')
%
% Inputs:
%   settings - Experiment.settings struct with fields:
%              baseline, taskStart, taskEnd, resampleRate, barBinSize,
%              useBaseline
%
% Name-Value Parameters:
%   DataRange  - [min, max] time range of actual data (default: inferred)
%   Title      - Figure title (default: 'Experiment Time Settings')
%   Visible    - 'on' (default) or 'off'
%   SavePath   - File path to save figure
%   SaveWidth  - Width in pixels (default: 800)
%   SaveHeight - Height in pixels (default: 350)
%   SaveDPI    - Resolution (default: 150)
%
% Outputs:
%   fig - Figure handle
%
% See also: exploreFNIRS.core.Experiment

    p = inputParser;
    addRequired(p, 'settings', @isstruct);
    addParameter(p, 'DataRange', [], @isnumeric);
    addParameter(p, 'Title', 'Experiment Time Settings', @ischar);
    addParameter(p, 'Visible', 'on', @ischar);
    addParameter(p, 'SavePath', '', @ischar);
    addParameter(p, 'SaveWidth', 800, @isnumeric);
    addParameter(p, 'SaveHeight', 350, @isnumeric);
    addParameter(p, 'SaveDPI', 150, @isnumeric);
    addParameter(p, 'TightLayout', false, @islogical);
    parse(p, settings, varargin{:});
    opts = p.Results;

    if ~isempty(opts.SavePath)
        opts.Visible = 'off';
    end

    s = settings;

    % Resolve task end
    if isfinite(s.taskEnd)
        taskEnd = s.taskEnd;
    elseif ~isempty(opts.DataRange)
        taskEnd = opts.DataRange(2);
    else
        taskEnd = 30;  % reasonable default
    end

    % Resolve data range
    if ~isempty(opts.DataRange)
        dataMin = opts.DataRange(1);
        dataMax = opts.DataRange(2);
    else
        dataMin = min([s.baseline(1), s.taskStart]) - 2;
        dataMax = taskEnd + 2;
    end

    % Resolve bar bin size
    taskDuration = taskEnd - s.taskStart;
    barBin = s.barBinSize;
    if barBin <= 0
        barBin = taskDuration;
    end

    % Axis padding
    pad = (dataMax - dataMin) * 0.1;
    xMin = dataMin - pad;
    xMax = dataMax + pad;

    % --- Create figure ---
    fig = pf2_base.plot.createFigure('Visible', opts.Visible, ...
        'Width', opts.SaveWidth, 'Height', opts.SaveHeight, ...
        'SavePath', opts.SavePath);
    ax = axes('Parent', fig);
    hold(ax, 'on');

    % Row positions (bottom to top)
    yBar      = 0.15;
    yTemporal = 0.35;
    yBaseline = 0.55;
    yTask     = 0.75;

    barH = 0.04;   % half-height of bracket bars
    sigAmp = 0.04; % amplitude of square wave signals
    lwBracket = 3;
    lwSig = 2;

    sty = pf2_base.plot.PlotStyle.getDefault();

    % Colors
    cTask     = sty.ForegroundColor;
    cBaseline = [0.85 0.2 0.2];
    cTemporal = [0.2 0.7 0.3];
    cBar      = [0.55 0.15 0.7];
    cDim      = sty.DimColor;

    % --- Task block bracket ---
    drawBracket(ax, [s.taskStart, taskEnd], yTask, barH, lwBracket, cTask);
    text(ax, mean([s.taskStart, taskEnd]), yTask + barH + 0.03, ...
        sprintf('Task [%.1f, %.1f]s', s.taskStart, taskEnd), ...
        'HorizontalAlignment', 'center', 'FontSize', 9, ...
        'FontWeight', 'bold', 'Color', cTask);

    % --- Baseline bracket ---
    if s.useBaseline
        drawBracket(ax, s.baseline, yBaseline, barH, lwBracket, cBaseline);
        text(ax, mean(s.baseline), yBaseline + barH + 0.03, ...
            sprintf('Baseline [%.1f, %.1f]s', s.baseline(1), s.baseline(2)), ...
            'HorizontalAlignment', 'center', 'FontSize', 9, ...
            'FontWeight', 'bold', 'Color', cBaseline);
    end

    % --- Temporal resample (square wave) ---
    if s.resampleRate > 0
        % Dim: outside task
        drawSquareWave(ax, xMin, xMax, s.taskStart, yTemporal, ...
            sigAmp, s.resampleRate, lwSig * 0.4, cDim);
        % Active: within task
        drawSquareWave(ax, s.taskStart, taskEnd, s.taskStart, yTemporal, ...
            sigAmp, s.resampleRate, lwSig, cTemporal);
        text(ax, xMax, yTemporal, ...
            sprintf(' Temporal (%.2fs)', s.resampleRate), ...
            'FontSize', 8, 'Color', cTemporal, ...
            'VerticalAlignment', 'middle');
    end

    % --- Bar resample (square wave, dashed outside) ---
    if barBin > 0
        % Dim: outside task
        drawSquareWave(ax, xMin, xMax, s.taskStart, yBar, ...
            sigAmp, barBin, lwSig * 0.4, cDim);
        % Active: within task
        drawSquareWave(ax, s.taskStart, taskEnd, s.taskStart, yBar, ...
            sigAmp, barBin, lwSig, cBar);
        if s.barBinSize <= 0
            binLabel = sprintf(' Bar (full window: %.1fs)', barBin);
        else
            binLabel = sprintf(' Bar (%.1fs bins)', barBin);
        end
        text(ax, xMax, yBar, binLabel, ...
            'FontSize', 8, 'Color', cBar, ...
            'VerticalAlignment', 'middle');
    end

    % --- Vertical reference lines at task boundaries ---
    for xv = [s.taskStart, taskEnd]
        plot(ax, [xv xv], [0 1], '--', 'Color', [sty.GridColor 0.4], ...
            'LineWidth', 0.8, 'HandleVisibility', 'off');
    end

    % --- Vertical lines at baseline boundaries ---
    if s.useBaseline
        for xv = s.baseline
            plot(ax, [xv xv], [0 1], '--', 'Color', [cBaseline 0.3], ...
                'LineWidth', 0.8, 'HandleVisibility', 'off');
        end
    end

    % --- Zero line ---
    plot(ax, [0 0], [0 1], '-', 'Color', [sty.ZeroLineColor 0.3], ...
        'LineWidth', 1.2, 'HandleVisibility', 'off');
    text(ax, 0, 0.95, ' t=0', 'FontSize', 8, 'Color', sty.DimColor);

    % --- Formatting ---
    xlim(ax, [xMin, xMax]);
    ylim(ax, [0, 1]);
    xlabel(ax, 'Time (s)');
    set(ax, 'YTick', []);
    set(ax, 'Box', 'on');
    title(ax, pf2_base.plot.escapeTeX(opts.Title));

    pf2_base.plot.PlotStyle.getDefault().applyToFigure(fig);
    pf2_base.plot.handleSave(fig, opts);
end


%% Local helpers

function drawBracket(ax, points, y, halfH, lw, color)
% Draw an I-beam bracket: |------|
    left = min(points);
    right = max(points);
    % Horizontal bar
    plot(ax, [left, right], [y, y], '-', 'Color', color, ...
        'LineWidth', lw, 'HandleVisibility', 'off');
    % Left end cap
    plot(ax, [left, left], [y - halfH, y + halfH], '-', 'Color', color, ...
        'LineWidth', lw, 'HandleVisibility', 'off');
    % Right end cap
    plot(ax, [right, right], [y - halfH, y + halfH], '-', 'Color', color, ...
        'LineWidth', lw, 'HandleVisibility', 'off');
end


function drawSquareWave(ax, startT, endT, alignT, y, amp, binSize, lw, color)
% Draw a square wave signal between startT and endT, aligned to alignT
    if binSize <= 0 || startT >= endT
        return;
    end

    % Compute first sample point aligned to alignT
    firstSample = alignT + floor((startT - alignT) / binSize) * binSize;
    if firstSample < startT
        firstSample = firstSample + binSize;
    end

    nPts = ceil((endT - firstSample) / binSize) + 1;
    if nPts < 1
        return;
    end

    xSamples = firstSample + (0:nPts-1) * binSize;
    xSamples = xSamples(xSamples <= endT + binSize * 0.01);

    % Build square wave: alternate high/low
    alignIdx = find(abs(xSamples - alignT) < binSize * 0.001, 1);
    if isempty(alignIdx)
        offset = 0;
    else
        offset = mod(alignIdx + 1, 2);
    end

    nS = length(xSamples);
    yVals = y - amp/2 + amp * (mod((1:nS) + offset, 2) == 0);

    % Duplicate points for step plot
    yStep = repelem(yVals, 2);
    if ~isempty(yStep)
        yStep(1) = [];
        yStep(end+1) = yStep(1);
    end
    xStep = repelem(xSamples, 2);

    plot(ax, xStep, yStep, '-', 'Color', color, 'LineWidth', lw, ...
        'HandleVisibility', 'off');
end
