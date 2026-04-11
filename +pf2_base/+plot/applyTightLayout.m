function applyTightLayout(fig)
% APPLYTIGHTLAYOUT Minimize whitespace in figure by adjusting axes positions
%
% Adjusts axes positions to reduce margins and subplot spacing. Handles
% single-axes figures, multi-axes (subplot) figures, and tiledlayout
% figures. Wrapped in try/catch so it never crashes a plot.
%
% Syntax:
%   pf2_base.plot.applyTightLayout(fig)
%
% Inputs:
%   fig - Figure handle
%
% See also: pf2_base.plot.handleSave, pf2_base.plot.createFigure

    try
        if ~isvalid(fig)
            return;
        end

        % Check for tiledlayout first
        tl = findobj(fig, 'Type', 'TiledChartLayout');
        if ~isempty(tl)
            applyTiledLayout(tl);
            return;
        end

        % Find real axes (exclude legends, colorbars, suptitle axes)
        allAx = findRealAxes(fig);
        if isempty(allAx)
            return;
        end

        if numel(allAx) == 1
            applySingleAxes(fig, allAx);
        else
            applyMultiAxes(fig, allAx);
        end
    catch
        % Never crash a plot
    end
end


function applyTiledLayout(tl)
% Set tight spacing on tiledlayout objects
    tl.Padding = 'tight';
    tl.TileSpacing = 'tight';
end


function applySingleAxes(fig, ax)
% Expand single axes to fill figure minus label space
    pad = 0.02;  % normalized padding

    % Get the tight inset (space needed for labels, tick marks, title)
    drawnow;
    ti = get(ax, 'TightInset');  % [left bottom right top]

    % Check for colorbar
    cb = findobj(fig, 'Type', 'Colorbar');
    cbExtra = 0;
    if ~isempty(cb)
        cbExtra = 0.06;  % extra right margin for colorbar
    end

    left   = ti(1) + pad;
    bottom = ti(2) + pad;
    right  = ti(3) + pad + cbExtra;
    top    = ti(4) + pad;

    % Check for suptitle
    supAx = findobj(fig, 'Tag', 'suptitle');
    if ~isempty(supAx)
        top = top + 0.04;
    end

    newPos = [left, bottom, 1 - left - right, 1 - bottom - top];
    newPos = max(newPos, 0.01);  % safety clamp
    newPos(3:4) = max(newPos(3:4), 0.1);
    set(ax, 'Position', newPos);
end


function applyMultiAxes(fig, allAx)
% Scale all subplot axes to fill the figure with reduced margins
    pad = 0.03;

    % Check for suptitle
    supAx = findobj(fig, 'Tag', 'suptitle');
    topPad = pad;
    if ~isempty(supAx)
        topPad = topPad + 0.04;
    end

    % Target region
    targetLeft   = pad;
    targetBottom = pad;
    targetWidth  = 1 - 2 * pad;
    targetHeight = 1 - targetBottom - topPad;

    % Current bounding box of all axes via OuterPosition
    drawnow;
    outerPositions = zeros(numel(allAx), 4);
    for i = 1:numel(allAx)
        outerPositions(i, :) = get(allAx(i), 'OuterPosition');
    end

    % Current bounding box
    curLeft   = min(outerPositions(:, 1));
    curBottom = min(outerPositions(:, 2));
    curRight  = max(outerPositions(:, 1) + outerPositions(:, 3));
    curTop    = max(outerPositions(:, 2) + outerPositions(:, 4));
    curWidth  = curRight - curLeft;
    curHeight = curTop - curBottom;

    if curWidth <= 0 || curHeight <= 0
        return;
    end

    % Scale and translate each axes
    scaleX = targetWidth / curWidth;
    scaleY = targetHeight / curHeight;

    for i = 1:numel(allAx)
        op = outerPositions(i, :);
        newX = targetLeft + (op(1) - curLeft) * scaleX;
        newY = targetBottom + (op(2) - curBottom) * scaleY;
        newW = op(3) * scaleX;
        newH = op(4) * scaleY;

        newOuter = [newX, newY, newW, newH];
        newOuter = max(newOuter, 0.001);
        set(allAx(i), 'OuterPosition', newOuter);
    end
end


function realAx = findRealAxes(fig)
% Find axes that are actual plot axes (not legends, colorbars, suptitle, etc.)
    allAx = findobj(fig, 'Type', 'Axes');
    keep = true(size(allAx));

    for i = 1:numel(allAx)
        ax = allAx(i);
        % Exclude suptitle axes
        if strcmp(get(ax, 'Tag'), 'suptitle')
            keep(i) = false;
            continue;
        end
        % Exclude invisible axes (annotation helpers)
        if strcmp(char(get(ax, 'Visible')), 'off') && isempty(get(ax, 'Children'))
            keep(i) = false;
            continue;
        end
    end

    realAx = allAx(keep);
end
