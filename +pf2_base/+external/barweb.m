function handles = barweb(barvalues, errors, varargin)
% BARWEB Grouped bar chart with per-bar error bars, points, and violins
%
% Draws a clustered (grouped) bar chart from a matrix of summary values and
% overlays per-bar error bars, optional individual data points, optional
% violin densities, and a legend. It is built directly on MATLAB's native
% BAR and ERRORBAR primitives. The chart is laid out as M groups (rows of
% BARVALUES) along the x-axis, each containing N side-by-side bars (columns
% of BARVALUES).
%
% This is an original, clean-room implementation that reproduces the call
% signature historically used inside exploreFNIRS bar plotting. It does not
% depend on any external helper.
%
% Syntax:
%   handles = barweb(barvalues, errors)
%   handles = barweb(barvalues, errors, width, groupnames)
%   handles = barweb(barvalues, errors, width, groupnames, 'Name', Value, ...)
%   handles = barweb(barvalues, errors, 'Name', Value, ...)
%
% Inputs:
%   barvalues - [M x N] (or [M x N x O]) matrix of bar summary values.
%               M groups along x, N bars per group. If a single column is
%               supplied whose length mismatches GroupNames, the data is
%               assumed transposed and is transposed automatically.
%   errors    - Error specification, one of:
%                 []            : no error bars are drawn.
%                 [M x N]       : symmetric error; bars get +/- error(i,j).
%                 [M x N x 2]   : page 1 = lower bound, page 2 = upper bound,
%                                 each interpreted as an ABSOLUTE y value
%                                 (whisker endpoints), not a delta.
%                 [M x N x >=3] : box/IQR style. Page 1/2 are lower/upper
%                                 whisker y values, page 3 is the box lower
%                                 edge, page 4 (optional) the box upper edge,
%                                 page 5 (optional) the box midline. Bars are
%                                 hidden and rectangles are drawn instead.
%
% Optional name-value pairs (a leading WIDTH and GROUPNAMES may also be given
% positionally, in that order, before any name-value pairs):
%   'Width'       - Bar width, 0 < w <= 1 (default: 1).
%   'GroupNames'  - Cellstr / string array of M x-axis tick labels
%                   (default: {'1','2',...}).
%   'Title'       - Axis title string (default: '').
%   'XLabel'      - X-axis label string (default: '').
%   'YLabel'      - Y-axis label string (default: '').
%   'ColorMap'    - [K x 3] RGB rows used to color the N bar series
%                   (cycled if K < N). A single [1 x 3] row colors all bars
%                   the same. Default: lines(N).
%   'GridStatus'  - 'x', 'y', 'xy', or 'none' (default: 'none').
%   'Legend'      - Cellstr / string array of N series names. An empty value
%                   (or LegendType 'hide') suppresses the legend.
%   'LegendType'  - 'plot' (standard legend), 'axis' (rotated labels under
%                   each bar), or 'hide' (no legend). Default: 'plot'.
%   'DataPoints'  - [M x N] cell array; each cell holds the raw observations
%                   for that bar, scatter-plotted with horizontal jitter.
%   'PlotViolin'  - Logical; when true (and DataPoints supplied) draws a
%                   kernel-density violin per bar instead of bars (default: false).
%   'Axes'        - Target axes handle (default: gca). When supplied, the
%                   axes hold state is preserved on return.
%   'ErrorColor'  - [1 x 3] RGB for error bars / edges. Default adapts to the
%                   axes background (white on dark, black on light).
%
% Outputs:
%   handles - Struct of graphics handles for post-hoc styling:
%               .ax        - axes handle
%               .bars      - [1 x N] array of Bar objects (one per series)
%               .errors    - [1 x N] array of ErrorBar objects (valid only
%                            for the series that received error bars)
%               .legend    - legend handle, or [] when no legend was drawn
%               .points    - scatter handles for individual data points
%               .violins   - patch handles for violin densities
%               .rectangles- rectangle handles for box/IQR rendering
%
% Algorithm:
%   1. Parse positional WIDTH/GROUPNAMES then name-value options.
%   2. Normalize BARVALUES/ERRORS orientation and decode the error pages
%      into lower/upper whisker values (absolute y) and optional box edges.
%   3. Draw the grouped bars with BAR, recovering each series' XOffset to
%      locate true bar centers.
%   4. Overlay ERRORBAR per series, optional jittered scatter / violins, and
%      optional box rectangles.
%   5. Apply labels, legend, grid, and tidy axis limits.
%
% Example:
%   v = [1 2; 3 1; 2 2];          % 3 groups, 2 series
%   e = 0.2 * ones(3, 2);
%   figure;
%   h = barweb(v, e, 1, {'A','B','C'}, 'Legend', {'Pre','Post'}, ...
%              'YLabel', '\muM', 'ColorMap', lines(2));
%
% See also: bar, errorbar, scatter, ksdensity

% ----------------------------------------------------------------------
% Input handling
% ----------------------------------------------------------------------
if nargin < 1
    error('pf2:barweb:notEnoughInputs', ...
        'barweb requires at least BARVALUES.');
end
if nargin < 2
    errors = [];
end

% Accept a leading positional WIDTH and GROUPNAMES (classic call form)
% before the name-value list. WIDTH is numeric scalar; GROUPNAMES is a
% cell/string array.
posWidth = [];
posGroupNames = {};
if ~isempty(varargin) && isnumeric(varargin{1}) && isscalar(varargin{1})
    posWidth = varargin{1};
    varargin(1) = [];
    if ~isempty(varargin) && (iscell(varargin{1}) || isstring(varargin{1}) ...
            || isnumeric(varargin{1}) && ~isscalar(varargin{1}))
        % Next token is the group-names vector (cellstr/string/numeric list)
        if ~ischar(varargin{1})
            posGroupNames = varargin{1};
            varargin(1) = [];
        end
    elseif ~isempty(varargin) && isempty(varargin{1}) && ~ischar(varargin{1})
        posGroupNames = varargin{1};
        varargin(1) = [];
    end
end

p = inputParser;
p.FunctionName = 'barweb';
addParameter(p, 'Width', [], @(x) isempty(x) || (isnumeric(x) && isscalar(x)));
addParameter(p, 'GroupNames', {}, @(x) iscell(x) || isstring(x) || isnumeric(x) || isempty(x));
addParameter(p, 'Title', '', @(x) ischar(x) || isstring(x));
addParameter(p, 'XLabel', '', @(x) ischar(x) || isstring(x));
addParameter(p, 'YLabel', '', @(x) ischar(x) || isstring(x));
addParameter(p, 'ColorMap', [], @(x) isnumeric(x) || ischar(x) || isstring(x));
addParameter(p, 'GridStatus', 'none', @(x) ischar(x) || isstring(x));
addParameter(p, 'Legend', {}, @(x) iscell(x) || isstring(x) || isempty(x));
addParameter(p, 'LegendType', 'plot', @(x) ischar(x) || isstring(x));
addParameter(p, 'DataPoints', {}, @(x) iscell(x) || isempty(x));
addParameter(p, 'PlotViolin', false, @(x) islogical(x) || isnumeric(x));
addParameter(p, 'Axes', [], @(x) isempty(x) || isgraphics(x));
addParameter(p, 'ErrorColor', [], @(x) isempty(x) || (isnumeric(x) && numel(x) == 3));
parse(p, varargin{:});

R = p.Results;

% Positional overrides take precedence when given.
if ~isempty(posWidth)
    width = posWidth;
elseif ~isempty(R.Width)
    width = R.Width;
else
    width = 0.8;
end

if ~isempty(posGroupNames)
    groupnames = posGroupNames;
else
    groupnames = R.GroupNames;
end

legendNames = cellstrColumn(R.Legend);
legendType  = lower(char(R.LegendType));
dataPoints  = R.DataPoints;
plotViolin  = logical(R.PlotViolin);
cmap        = resolveColorMap(R.ColorMap);

% ----------------------------------------------------------------------
% Target axes and foreground (edge / error) color
% ----------------------------------------------------------------------
ownAxes = isempty(R.Axes);
if ownAxes
    ax = gca;
else
    ax = R.Axes;
end
priorHold = ishold(ax);

if ~isempty(R.ErrorColor)
    fgColor = R.ErrorColor(:)';
else
    % Honor the active processFNIRS2 plot theme (respects ForceLightMode)
    % rather than sniffing the axes background, so bar edges, error bars,
    % and the legend stay consistent with the rest of the toolbox.
    try
        fgColor = pf2_base.plot.PlotStyle.getDefault().ForegroundColor;
    catch
        axBg = get(ax, 'Color');
        if isnumeric(axBg) && mean(axBg) < 0.5
            fgColor = [1 1 1];
        else
            fgColor = [0 0 0];
        end
    end
end

% ----------------------------------------------------------------------
% Normalize barvalues / groupnames orientation
% ----------------------------------------------------------------------
barMeans = barvalues(:, :, 1);

if isempty(groupnames)
    groupnames = arrayfun(@(k) sprintf('%d', k), 1:size(barMeans, 1), ...
        'UniformOutput', false);
else
    groupnames = cellstrColumn(groupnames);
end

% Single-column data whose length disagrees with the group labels is almost
% certainly transposed (a single group of several bars passed as a column).
if size(barMeans, 2) == 1 && ~isempty(groupnames) ...
        && size(barMeans, 1) ~= numel(groupnames) ...
        && size(barMeans, 1) == 1
    barMeans = barMeans.';
end

% ----------------------------------------------------------------------
% Decode the error pages into whisker / box geometry
% ----------------------------------------------------------------------
[lowerY, upperY, boxLow, boxHigh, boxMid, drawWhiskers, drawBox] = ...
    decodeErrors(errors, barMeans);

nGroups = size(barMeans, 1);
nBars   = size(barMeans, 2);

% ----------------------------------------------------------------------
% Individual data points / violins
% ----------------------------------------------------------------------
hasPoints = ~isempty(dataPoints) && any(~cellfun(@isempty, dataPoints(:)));
plotViolin = plotViolin && hasPoints;
hideBars   = drawBox || plotViolin;

handles = struct('ax', ax, 'bars', gobjects(1, nBars), ...
    'errors', gobjects(1, nBars), 'legend', [], ...
    'points', gobjects(0), 'violins', gobjects(0), ...
    'rectangles', gobjects(0));

% ----------------------------------------------------------------------
% Draw the bars
% ----------------------------------------------------------------------
% BAR groups columns side-by-side automatically. A single group of N bars is
% awkward for BAR (it would treat N as series of 1 group), so pad with a
% zero second group to keep the clustered layout, then trim the x-limits.
padded = false;
plotMeans = barMeans;
if nGroups == 1 && nBars > 1
    plotMeans = [barMeans; zeros(1, nBars)];
    padded = true;
end

hold(ax, 'on');
hbars = bar(ax, plotMeans, width, 'EdgeColor', fgColor, 'LineWidth', 1.5);
handles.bars = hbars;

% Color each series.
for j = 1:nBars
    c = cmap(mod(j - 1, size(cmap, 1)) + 1, :);
    hbars(j).FaceColor = c;
    if ~isempty(legendNames) && j <= numel(legendNames) && ~isempty(legendNames{j})
        hbars(j).DisplayName = legendNames{j};
    end
end

if hideBars
    set(hbars, 'Visible', 'off');
end

% Recover the true x-center of every bar series. XEndPoints holds the
% per-group bar centers and is reliably populated (unlike XOffset, which can
% return 0 before the figure has flushed, collapsing every series onto the
% shared group center). Fall back to XData + XOffset if XEndPoints is absent.
xCenters = zeros(nGroups, nBars);
for j = 1:nBars
    if isprop(hbars(j), 'XEndPoints') && numel(hbars(j).XEndPoints) >= nGroups
        xe = hbars(j).XEndPoints;
        xCenters(:, j) = xe(1:nGroups).';
    else
        xData = hbars(j).XData(1:nGroups);
        xCenters(:, j) = xData(:) + hbars(j).XOffset;
    end
end

% Approximate per-bar width (for violin / box rectangle footprint).
if nBars > 1
    barFootprint = mean(diff(xCenters(1, :)), 'omitnan') * 0.7;
else
    barFootprint = 0.7 * width;
end
if ~isfinite(barFootprint) || barFootprint <= 0
    barFootprint = 0.5;
end

% ----------------------------------------------------------------------
% Error bars (whiskers)
% ----------------------------------------------------------------------
if drawWhiskers
    for j = 1:nBars
        x = xCenters(:, j);
        yc = barMeans(:, j);
        lo = yc - lowerY(:, j);   % positive distance below
        hi = upperY(:, j) - yc;   % positive distance above
        lo(lo < 0) = 0;
        hi(hi < 0) = 0;
        valid = ~all(isnan(lo) & isnan(hi));
        if valid
            handles.errors(j) = errorbar(ax, x, yc, lo, hi, ...
                'Color', fgColor, 'LineStyle', 'none', 'LineWidth', 1, ...
                'HandleVisibility', 'off');
        end
    end
end

% ----------------------------------------------------------------------
% Box / IQR rectangles (replaces hidden bars)
% ----------------------------------------------------------------------
if drawBox
    rects = gobjects(0);
    for j = 1:nBars
        c = cmap(mod(j - 1, size(cmap, 1)) + 1, :);
        for g = 1:nGroups
            top = boxHigh(g, j);
            mid = boxMid(g, j);
            bot = boxLow(g, j);
            if any(isnan([top, mid, bot]))
                continue
            end
            x0 = xCenters(g, j) - barFootprint / 2;
            yLo = min([top, bot]);
            h = abs(top - bot);
            if h > 0
                rh = rectangle(ax, 'Position', [x0, yLo, barFootprint, h], ...
                    'FaceColor', c, 'EdgeColor', fgColor, 'LineWidth', 1.5);
                rects(end + 1) = rh; %#ok<AGROW>
            end
            % Median line
            line(ax, [x0, x0 + barFootprint], [mid, mid], ...
                'Color', fgColor, 'LineWidth', 1.5);
        end
    end
    handles.rectangles = rects;
end

% ----------------------------------------------------------------------
% Violins and scatter points
% ----------------------------------------------------------------------
if hasPoints
    [pj, pk] = size(dataPoints);
    pts = gobjects(0);
    vio = gobjects(0);
    warnState = warning('off', 'all');
    cleanupWarn = onCleanup(@() warning(warnState));
    for g = 1:min(pj, nGroups)
        for j = 1:min(pk, nBars)
            d = dataPoints{g, j};
            if isempty(d)
                continue
            end
            d = d(:);
            d = d(~isnan(d));
            if isempty(d)
                continue
            end
            xc = xCenters(g, j);
            c = cmap(mod(j - 1, size(cmap, 1)) + 1, :);

            if plotViolin && numel(d) > 1
                [f, u] = ksdensity(d);
                f = f(:) / max(f) * (barFootprint / 2);
                u = u(:);
                vh = fill(ax, [xc + f; flipud(xc - f)], [u; flipud(u)], c, ...
                    'EdgeColor', fgColor, 'FaceAlpha', 0.5, ...
                    'HandleVisibility', 'off');
                vio(end + 1) = vh; %#ok<AGROW>
            end

            jitter = (rand(numel(d), 1) - 0.5) * barFootprint * 0.6;
            ph = scatter(ax, xc + jitter, d, 10, 'filled', ...
                'MarkerFaceColor', c, 'MarkerEdgeColor', fgColor, ...
                'MarkerFaceAlpha', 0.6, 'HandleVisibility', 'off');
            pts(end + 1) = ph; %#ok<AGROW>
        end
    end
    handles.points = pts;
    handles.violins = vio;
end

% ----------------------------------------------------------------------
% Legend
% ----------------------------------------------------------------------
showLegend = ~isempty(legendNames) && ~strcmp(legendType, 'hide');
if showLegend && strcmp(legendType, 'plot')
    nShow = min(numel(legendNames), nBars);
    if nShow >= 1
        handles.legend = legend(ax, hbars(1:nShow), legendNames(1:nShow), ...
            'Location', 'best', 'TextColor', fgColor);
        legend(ax, 'boxoff');
        % Match the legend background to the theme so it does not show a dark
        % fill under ForceLightMode (boxoff only removes the outline).
        try
            set(handles.legend, 'Color', ...
                pf2_base.plot.PlotStyle.getDefault().LegendBgColor);
        catch
        end
    end
end

% ----------------------------------------------------------------------
% Labels, ticks, grid, limits
% ----------------------------------------------------------------------
set(ax, 'XTick', 1:nGroups, 'XTickLabel', groupnames, ...
    'Box', 'off', 'TickLength', [0 0], 'LineWidth', 1.5);

if nGroups == 1
    set(ax, 'XLim', [0.5, 1.5]);
elseif padded
    set(ax, 'XLim', [0.5, 1.5]);  % single real group, padded second hidden
else
    set(ax, 'XLim', [0.5, nGroups + 0.5]);
end

if ~isempty(char(R.Title))
    title(ax, R.Title, 'FontSize', 14);
end
if ~isempty(char(R.XLabel))
    xlabel(ax, R.XLabel, 'FontSize', 14);
end
if ~isempty(char(R.YLabel))
    ylabel(ax, R.YLabel, 'FontSize', 14);
end

gs = lower(char(R.GridStatus));
set(ax, 'XGrid', 'off', 'YGrid', 'off');
if contains(gs, 'x')
    set(ax, 'XGrid', 'on');
end
if contains(gs, 'y')
    set(ax, 'YGrid', 'on');
end

% Axis-style legend: rotated labels beneath each bar.
if showLegend && strcmp(legendType, 'axis')
    yl = ylim(ax);
    yBase = yl(1) - 0.03 * (yl(2) - yl(1));
    for j = 1:min(numel(legendNames), nBars)
        for g = 1:nGroups
            text(ax, xCenters(g, j), yBase, legendNames{j}, ...
                'Rotation', 60, 'FontSize', 11, ...
                'HorizontalAlignment', 'right', 'Color', fgColor);
        end
    end
    set(ax, 'XAxisLocation', 'top');
end

% Restore hold state when operating on a caller-supplied axes.
if ~priorHold
    hold(ax, 'off');
end

end

% ======================================================================
% Local helpers
% ======================================================================

function out = cellstrColumn(in)
% Coerce a cellstr / string array / numeric list into a column cellstr.
if isempty(in)
    out = {};
    return
end
if isstring(in)
    out = cellstr(in(:));
elseif isnumeric(in)
    out = arrayfun(@(k) sprintf('%g', k), in(:), 'UniformOutput', false);
elseif iscell(in)
    out = in(:);
    for k = 1:numel(out)
        if isnumeric(out{k})
            out{k} = sprintf('%g', out{k});
        elseif isstring(out{k})
            out{k} = char(out{k});
        end
    end
else
    out = {char(in)};
end
end

function cmap = resolveColorMap(spec)
% Turn a colormap spec (RGB rows, name string, or empty) into RGB rows.
if isempty(spec)
    cmap = lines(8);
elseif isnumeric(spec)
    if size(spec, 2) == 3
        cmap = spec;
    else
        cmap = lines(8);
    end
else
    name = char(spec);
    try
        cmap = feval(name, 8);
    catch
        cmap = lines(8);
    end
end
end

function [lowerY, upperY, boxLow, boxHigh, boxMid, drawWhiskers, drawBox] = ...
        decodeErrors(errors, barMeans)
% Decode the error pages into absolute whisker y-values and box edges.
%
%   1 page  : symmetric +/- error (delta about the bar mean).
%   2 pages : lower / upper whisker as ABSOLUTE y values.
%   >=3      : box/IQR rendering; pages 3..5 give box low/high/mid edges.
[m, n] = size(barMeans);
lowerY  = nan(m, n);
upperY  = nan(m, n);
boxLow  = nan(m, n);
boxHigh = nan(m, n);
boxMid  = nan(m, n);
drawWhiskers = false;
drawBox = false;

if isempty(errors)
    return
end

nPages = size(errors, 3);

% Align error orientation to barMeans when a transpose occurred upstream.
if size(errors, 1) ~= m && size(errors, 2) == m && size(errors, 1) == n
    errors = permute(errors, [2 1 3]);
end

if nPages == 1
    e = errors(:, :, 1);
    lowerY = barMeans - e;
    upperY = barMeans + e;
    drawWhiskers = true;
elseif nPages == 2
    lowerY = errors(:, :, 1);   % absolute whisker endpoints
    upperY = errors(:, :, 2);
    drawWhiskers = true;
else  % nPages >= 3: box/IQR
    lowerY = errors(:, :, 1);
    upperY = errors(:, :, 2);
    boxLow = errors(:, :, 3);
    if nPages >= 4
        boxHigh = errors(:, :, 4);
    else
        boxHigh = barMeans;
    end
    if nPages >= 5
        boxMid = errors(:, :, 5);
    else
        boxMid = barMeans;
    end
    drawWhiskers = true;
    drawBox = true;
end
end
