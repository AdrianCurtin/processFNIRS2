function hhh = vline(varargin)
%VLINE DRAW VERTICAL REFERENCE LINE(S) ON THE CURRENT OR GIVEN AXES
%
%   Draws one or more vertical lines spanning the full y-range of an axes
%   at the requested x-position(s), with optional per-line style, text
%   label, and label height. The axes hold state is preserved across the
%   call. Lines can be tagged and (by default for unlabeled lines) hidden
%   from legends/findobj via HandleVisibility 'off'.
%
%   This is an ORIGINAL processFNIRS2 implementation written from the
%   documented behaviour and the call forms used across the toolbox. It
%   replaces a previously bundled, unlicensed third-party File Exchange
%   utility and is now first-party toolbox code (GPLv3).
%
% Syntax:
%   h = pf2_base.external.vline(x)
%   h = pf2_base.external.vline(x, lineStyle)
%   h = pf2_base.external.vline(x, lineStyle, labels)
%   h = pf2_base.external.vline(x, lineStyle, labels, labelHeights)
%   h = pf2_base.external.vline(ax, ...)
%   h = pf2_base.external.vline(..., 'lineTags', tags)
%   h = pf2_base.external.vline(..., 'handleVisibility', tf)
%   h = pf2_base.external.vline(..., 'ax', axHandle)
%
% Inputs:
%   x            - x-position(s) of the line(s). Numeric / datetime /
%                  duration vector. Empty returns [] and draws nothing.
%   ax           - (optional) Leading axes handle. Defaults to gca.
%   lineStyle    - (optional) Line appearance. One of:
%                    * a linespec char (e.g. 'r:', '--k'),
%                    * a numeric RGB triple or RGBA quad (used as Color),
%                    * a cell of plot name-value options
%                      (e.g. {'Color',[0 0 0],'LineStyle',':'}).
%                  Default 'r:'.
%   labels       - (optional) Text label(s) drawn next to the line(s).
%                  Char, numeric, or cell array (one entry per line).
%                  Default: none.
%   labelHeights - (optional) Vertical position(s) of the label as a
%                  fraction (0..1) of the axes y-range. Scalar or per-line
%                  vector. Default 0.1.
%   'ax'         - (name-value) Target axes (alternative to leading arg).
%   'lineTags'   - (name-value) Tag string(s) for the line object(s).
%   'handleVisibility' - (name-value, logical) When false, sets each line's
%                  HandleVisibility to 'off'. Default true.
%
% Outputs:
%   hhh          - Line handle when a single line is drawn; a cell array of
%                  line handles for multiple lines. Empty when x is empty.
%                  Only assigned when an output is requested.
%
% Example:
%   plot(1:10, rand(1,10));
%   h = pf2_base.external.vline(5, 'g', 'Onset', 0.9);
%   pf2_base.external.vline([3 7], '--k', {'A','B'});
%
% See also: line, plot, xline, pf2_base.external.suptitle

    % --- Optional leading axes handle ---
    if ~isempty(varargin) && isa(varargin{1}, 'matlab.graphics.axis.Axes')
        ax = varargin{1};
        varargin = varargin(2:end);
    else
        ax = gca;
    end

    % --- Validators ---
    validX = @(v) isempty(v) || isnumeric(v) || isdatetime(v) || isduration(v);
    validAx = @(v) isa(v, 'matlab.graphics.axis.Axes') && isvalid(v);
    % linespec char, cell of options, or numeric RGB[A] triple/quad.
    validStyle = @(v) ischar(v) || isstring(v) || iscell(v) || ...
        (isnumeric(v) && isvector(v) && (numel(v) == 3 || numel(v) == 4));
    validLabels = @(v) ischar(v) || isstring(v) || iscell(v) || isnumeric(v);
    validHeights = @(v) isnumeric(v) && ~isempty(v);

    % Consume the trailing name-value pairs ('ax', 'lineTags',
    % 'handleVisibility') MANUALLY before running the positional parser.
    % inputParser cannot disambiguate here: a parameter NAME such as
    % 'lineTags' is itself a valid linespec char, so the parser would
    % greedily swallow it into the optional 'lineStyle' slot. Scanning for
    % the first arg that names a known parameter lets us split cleanly.
    lineTags = cell(0);
    handleVisible = true;
    paramNames = {'ax', 'lineTags', 'handleVisibility'};
    splitIdx = numel(varargin) + 1;
    for ii = 2:numel(varargin)   % start at 2: arg 1 is always x
        a = varargin{ii};
        if (ischar(a) || (isstring(a) && isscalar(a))) && ...
                any(strcmpi(char(a), paramNames))
            splitIdx = ii;
            break;
        end
    end
    positional = varargin(1:splitIdx-1);
    nameValue  = varargin(splitIdx:end);

    for ii = 1:2:numel(nameValue)
        name = lower(char(nameValue{ii}));
        val  = nameValue{ii+1};
        switch name
            case 'ax'
                assert(validAx(val), 'pf2_base:external:vline:ax', ...
                    '''ax'' must be a valid axes handle.');
                ax = val;
            case 'linetags'
                lineTags = val;
            case 'handlevisibility'
                assert(islogical(val), 'pf2_base:external:vline:handleVisibility', ...
                    '''handleVisibility'' must be logical.');
                handleVisible = val;
        end
    end

    p = inputParser;
    addRequired(p, 'x', validX);
    addOptional(p, 'lineStyle', 'r:', validStyle);
    addOptional(p, 'labels', cell(0), validLabels);
    addOptional(p, 'labelHeights', 0.1, validHeights);
    parse(p, positional{:});

    x            = p.Results.x;
    lineStyle    = p.Results.lineStyle;
    labels       = p.Results.labels;
    labelHeights = p.Results.labelHeights;

    if isempty(x)
        hhh = [];
        return;
    end

    % --- Normalize the style argument into a plot() option cell ---
    if isnumeric(lineStyle) && isvector(lineStyle) && ...
            (numel(lineStyle) == 3 || numel(lineStyle) == 4)
        styleArgs = {'Color', lineStyle(:)'};
    elseif iscell(lineStyle)
        styleArgs = lineStyle;
    else
        styleArgs = {char(lineStyle)};
    end

    % --- Normalize labels and tags to cell arrays ---
    labels = toCell(labels);
    lineTags = toCell(lineTags);

    x = x(:);
    numLines = numel(x);

    % Preserve the axes hold state.
    wasHeld = ishold(ax);
    hold(ax, 'on');

    yl = get(ax, 'YLim');
    xl = get(ax, 'XLim');
    xrange = double(xl(2) - xl(1));
    yrange = yl(2) - yl(1);

    handles = cell(numLines, 1);

    for k = 1:numLines
        xVal = x(k);

        h = plot(ax, [xVal xVal], yl, styleArgs{:});

        % --- Per-line label ---
        lbl = pickEntry(labels, k);
        if ~isempty(lbl)
            if isnumeric(lbl)
                lbl = num2str(lbl);
            end
            hVal = pickHeight(labelHeights, k);
            hVal = max(0, min(1, hVal));
            yPos = yl(1) + hVal * yrange;

            % Offset label left of the line when it sits near the right edge.
            if xrange > 0
                xunit = double(xVal - xl(1)) / xrange;
            else
                xunit = 0;
            end
            if xunit < 0.8
                xPos = xVal + 0.01 * xrange;
            else
                xPos = xVal - 0.05 * xrange;
            end
            text(ax, xPos, yPos, lbl, 'Color', get(h, 'Color'));
        end

        % --- Tag selection: explicit tag, else label, else 'vline' ---
        tag = pickEntry(lineTags, k);
        if isempty(tag)
            if ~isempty(lbl) && (ischar(lbl) || isstring(lbl))
                tag = char(lbl);
            else
                tag = 'vline';
            end
        else
            tag = char(tag);
        end
        set(h, 'Tag', tag);

        if ~handleVisible
            set(h, 'HandleVisibility', 'off');
        end

        handles{k} = h;
    end

    if ~wasHeld
        hold(ax, 'off');
    end

    % --- Output shape: single handle vs. cell of handles ---
    if nargout
        if numLines == 1
            hhh = handles{1};
        else
            hhh = handles;
        end
    end
end

function c = toCell(v)
    % Convert char/string/numeric/cell labels-or-tags into a cell array.
    if isempty(v)
        c = cell(0);
    elseif iscell(v)
        c = v;
    elseif isstring(v)
        c = cellstr(v);
    else
        c = {v};
    end
end

function e = pickEntry(c, k)
    % Select the k-th entry of a cell array, falling back to the first
    % entry when there are fewer entries than lines. Empty when none.
    if isempty(c)
        e = [];
    elseif isscalar(c)
        e = c{1};
    elseif numel(c) >= k
        e = c{k};
    else
        e = [];
    end
end

function h = pickHeight(v, k)
    % Select the k-th label height, falling back to the first/default.
    if isscalar(v)
        h = v;
    elseif numel(v) >= k
        h = v(k);
    else
        h = 0.1;
    end
end
