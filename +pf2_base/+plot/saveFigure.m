function saveFigure(fig, savePath, width, height, dpi)
% SAVEFIGURE Save figure to file with specified dimensions and resolution
%
% Helper function for saving figures to various formats with control over
% size and resolution. Supports PNG, PDF, FIG, SVG, EPS, and other formats.
%
% Syntax:
%   pf2_base.plot.saveFigure(fig, savePath)
%   pf2_base.plot.saveFigure(fig, savePath, width, height)
%   pf2_base.plot.saveFigure(fig, savePath, width, height, dpi)
%
% Inputs:
%   fig      - Figure handle to save
%   savePath - Output filename (extension determines format)
%              Supported: .png, .pdf, .fig, .svg, .eps, .tif, .jpg
%   width    - Figure width in pixels (default: current figure width)
%   height   - Figure height in pixels (default: current figure height)
%   dpi      - Resolution in dots per inch (default: 150)
%              Only applies to raster formats (png, tif, jpg)
%
% Example:
%   fig = figure;
%   plot(1:10);
%   pf2_base.plot.saveFigure(fig, 'output.png', 800, 600, 300);
%
% See also: print, saveas, exportgraphics

if nargin < 5 || isempty(dpi)
    dpi = 150;
end

if nargin < 4 || isempty(height)
    height = [];
end

if nargin < 3 || isempty(width)
    width = [];
end

if isempty(savePath)
    return;
end

% Get file extension
[~, ~, ext] = fileparts(savePath);
ext = lower(ext);

% Set figure size if specified
if ~isempty(width) && ~isempty(height)
    % Store original units
    origUnits = fig.Units;
    fig.Units = 'pixels';

    % Get current position
    pos = fig.Position;

    % Set new size (keep position)
    fig.Position = [pos(1), pos(2), width, height];

    % For print/export, also set PaperPosition
    fig.PaperUnits = 'inches';
    fig.PaperPosition = [0, 0, width/dpi, height/dpi];
    fig.PaperSize = [width/dpi, height/dpi];
end

% Force white background for export (overrides dark mode theme)
fig.Color = 'w';
fig.InvertHardcopy = 'on';

% Axes: white background, black axis lines
allAx = findobj(fig, 'Type', 'Axes');
for aIdx = 1:length(allAx)
    if isequal(get(allAx(aIdx), 'Color'), 'none')
        continue;  % transparent axes (overlays) stay transparent
    end
    set(allAx(aIdx), 'Color', 'w');
    set(allAx(aIdx), 'XColor', 'k', 'YColor', 'k');
    if isprop(allAx(aIdx), 'ZColor')
        set(allAx(aIdx), 'ZColor', 'k');
    end
end

% Text objects: convert white/light text to black for export
% Preserve intentionally-colored text (e.g., red significance markers)
allText = findobj(fig, 'Type', 'Text');
for tIdx = 1:length(allText)
    curColor = get(allText(tIdx), 'Color');
    if isnumeric(curColor) && mean(curColor) > 0.85
        set(allText(tIdx), 'Color', 'k');
    elseif isequal(curColor, 'w')
        set(allText(tIdx), 'Color', 'k');
    end
end

% Titles: force black
allTitles = get(allAx, 'Title');
if iscell(allTitles)
    for tIdx = 1:length(allTitles)
        set(allTitles{tIdx}, 'Color', 'k');
    end
elseif ~isempty(allTitles)
    set(allTitles, 'Color', 'k');
end

% Labels: force black
for aIdx = 1:length(allAx)
    if ~isempty(allAx(aIdx).XLabel)
        set(allAx(aIdx).XLabel, 'Color', 'k');
    end
    if ~isempty(allAx(aIdx).YLabel)
        set(allAx(aIdx).YLabel, 'Color', 'k');
    end
end

% Legends: white background, black text
allLeg = findobj(fig, 'Type', 'Legend');
for lIdx = 1:length(allLeg)
    set(allLeg(lIdx), 'TextColor', 'k');
    set(allLeg(lIdx), 'Color', 'w');
    set(allLeg(lIdx), 'EdgeColor', [0.5 0.5 0.5]);
end

% Colorbars: black text and labels
allCb = findobj(fig, 'Type', 'Colorbar');
for cIdx = 1:length(allCb)
    set(allCb(cIdx), 'Color', 'k');
    if isprop(allCb(cIdx), 'Label')
        set(allCb(cIdx).Label, 'Color', 'k');
    end
end

% sgtitle: force black if present
allSgt = findobj(fig, 'Type', 'SubplotText');
for sIdx = 1:length(allSgt)
    set(allSgt(sIdx), 'Color', 'k');
end

% Annotation textboxes: force black text
allAnnot = findobj(fig, 'Type', 'TextBox');
for aIdx = 1:length(allAnnot)
    curColor = get(allAnnot(aIdx), 'Color');
    if isnumeric(curColor) && mean(curColor) > 0.85
        set(allAnnot(aIdx), 'Color', 'k');
    end
end

% Save based on format
switch ext
    case '.fig'
        % MATLAB figure file
        savefig(fig, savePath);

    case '.pdf'
        % PDF - vector format
        if exist('exportgraphics', 'file')
            exportgraphics(fig, savePath, 'ContentType', 'vector', ...
                'BackgroundColor', 'white');
        else
            print(fig, savePath, '-dpdf', '-bestfit');
        end

    case '.svg'
        % SVG - vector format
        if exist('exportgraphics', 'file')
            exportgraphics(fig, savePath, 'ContentType', 'vector', ...
                'BackgroundColor', 'white');
        else
            print(fig, savePath, '-dsvg');
        end

    case '.eps'
        % EPS - vector format
        print(fig, savePath, '-depsc', '-painters');

    case '.png'
        % PNG - raster format
        if exist('exportgraphics', 'file')
            exportgraphics(fig, savePath, 'Resolution', dpi, ...
                'BackgroundColor', 'white');
        else
            print(fig, savePath, '-dpng', sprintf('-r%d', dpi));
        end

    case '.tif'
        % TIFF - raster format
        print(fig, savePath, '-dtiff', sprintf('-r%d', dpi));

    case {'.jpg', '.jpeg'}
        % JPEG - raster format
        if exist('exportgraphics', 'file')
            exportgraphics(fig, savePath, 'Resolution', dpi, ...
                'BackgroundColor', 'white');
        else
            print(fig, savePath, '-djpeg', sprintf('-r%d', dpi));
        end

    otherwise
        % Default: try saveas
        warning('pf2:UnknownFormat', 'Unknown format %s, using saveas', ext);
        saveas(fig, savePath);
end

% Restore original units if changed
if ~isempty(width) && ~isempty(height)
    fig.Units = origUnits;
end

end
