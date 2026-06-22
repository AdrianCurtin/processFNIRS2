function hout = suptitle(varargin)
%SUPTITLE PLACE A CENTERED SUPER-TITLE ABOVE ALL SUBPLOTS IN A FIGURE
%
%   Places a single centered title across the top of a figure, above every
%   subplot it contains (a "super title"). It is intended to be called
%   after all subplots have been created. The title is drawn into an
%   invisible full-figure overlay axes tagged 'suptitle' so that it does
%   not disturb the data axes and can be located/removed later. Existing
%   subplots are gently shrunk downward to make room for the title, and any
%   prior super-title on the same figure is removed first.
%
%   This is an ORIGINAL processFNIRS2 implementation written from the
%   documented behavior. It replaces a previously bundled third-party
%   utility and is now first-party toolbox code (GPLv3).
%
%   The title colour follows the active processFNIRS2 plot theme
%   (light/dark) via pf2_base.plot.PlotStyle.
%
% Syntax:
%   h = pf2_base.external.suptitle(str)
%   h = pf2_base.external.suptitle(figH, str)
%
% Inputs:
%   str  - Title text. Char row vector or string scalar.
%   figH - (optional) Target figure handle. When omitted the current
%          figure (gcf) is used. May be passed as the first argument
%          followed by the title string.
%
% Outputs:
%   h    - Handle to the created text object (only assigned when an output
%          is requested). The text lives in an axes tagged 'suptitle'.
%
% Example:
%   figure;
%   subplot(2,1,1); plot(rand(1,10));
%   subplot(2,1,2); plot(rand(1,10));
%   h = pf2_base.external.suptitle('Overall Title');
%
% See also: title, sgtitle, pf2_base.plot.addProcessingInfoTitle,
%           pf2_base.plot.applyTightLayout

    % --- Parse arguments: either (str) or (figH, str) ---
    if nargin == 1
        figH = gcf;
        str  = varargin{1};
    elseif nargin >= 2
        figH = varargin{1};
        str  = varargin{2};
        if ~(isgraphics(figH) && strcmp(get(figH, 'Type'), 'figure'))
            % First arg was not a figure handle: treat as (str) form and
            % fall back to the current figure.
            str  = figH;
            figH = gcf;
        end
    else
        error('pf2_base:external:suptitle:nargin', ...
            'suptitle requires a title string (and optionally a figure handle).');
    end

    if isstring(str)
        str = char(str);
    end

    % --- Theme-aware text colour ---
    try
        sty       = pf2_base.plot.PlotStyle.getDefault();
        textColor = sty.ForegroundColor;
    catch
        textColor = [0 0 0];
    end

    % Font size: a few points larger than the default axes font.
    baseFont = get(figH, 'defaultaxesfontsize');
    if isempty(baseFont) || ~isscalar(baseFont)
        baseFont = 10;
    end
    fontSize = baseFont + 4;

    % --- Remove any previous super-title overlay on this figure ---
    oldOverlay = findobj(figH, 'Type', 'axes', 'Tag', 'suptitle');
    if ~isempty(oldOverlay)
        delete(oldOverlay);
    end

    % --- Shrink existing data axes downward to make headroom ---
    % Operate in normalized units, restoring whatever units were in use.
    dataAxes = findobj(figH, 'Type', 'axes');
    dataAxes = dataAxes(~strcmp(get(dataAxes, 'Tag'), 'suptitle'));

    titleBand = 0.075;   % fraction of figure height reserved at the top
    titleY    = 1 - titleBand / 2;  % vertical centre of the reserved band

    if ~isempty(dataAxes)
        oldUnits = get(dataAxes, {'Units'});
        set(dataAxes, 'Units', 'normalized');
        restore = onCleanup(@() restoreUnits(dataAxes, oldUnits));

        positions = get(dataAxes, {'Position'});
        topEdge = 0;
        for k = 1:numel(positions)
            p = positions{k};
            topEdge = max(topEdge, p(2) + p(4));
        end

        % Only rescale when subplots currently reach into the reserved band.
        limit = 1 - titleBand;
        if topEdge > limit
            scale = limit / topEdge;
            for k = 1:numel(dataAxes)
                p = positions{k};
                p(2) = p(2) * scale;
                p(4) = p(4) * scale;
                set(dataAxes(k), 'Position', p);
            end
        end
        clear restore;  % run unit restoration now
    end

    % --- Create the invisible overlay axes and place the title text ---
    prevAx = get(figH, 'CurrentAxes');
    nextState = get(figH, 'NextPlot');
    set(figH, 'NextPlot', 'add');

    % NOTE: HandleVisibility is deliberately left 'on' so that the overlay
    % axes (and thus the title) can be located via findobj(...,'Tag',
    % 'suptitle') by applyTightLayout and by repeat calls that replace an
    % existing super-title.
    overlay = axes('Parent', figH, ...
        'Position', [0 0 1 1], ...
        'Units', 'normalized', ...
        'Visible', 'off', ...
        'HitTest', 'off', ...
        'Tag', 'suptitle');
    set(overlay, 'XLim', [0 1], 'YLim', [0 1]);

    ht = text(overlay, 0.5, titleY, str, ...
        'HorizontalAlignment', 'center', ...
        'VerticalAlignment', 'middle', ...
        'FontSize', fontSize, ...
        'FontWeight', 'bold', ...
        'Color', textColor, ...
        'Interpreter', 'tex');

    set(figH, 'NextPlot', nextState);

    % Restore the previously current axes so subsequent plotting is unaffected.
    if ~isempty(prevAx) && isgraphics(prevAx)
        set(figH, 'CurrentAxes', prevAx);
    end

    if nargout
        hout = ht;
    end
end

function restoreUnits(h, oldUnits)
    % Restore the original Units of each axes that still exists.
    valid = isgraphics(h);
    if any(valid)
        set(h(valid), {'Units'}, oldUnits(valid));
    end
end
