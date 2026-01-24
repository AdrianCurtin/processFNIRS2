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

% Save based on format
switch ext
    case '.fig'
        % MATLAB figure file
        savefig(fig, savePath);

    case '.pdf'
        % PDF - vector format
        if exist('exportgraphics', 'file')
            exportgraphics(fig, savePath, 'ContentType', 'vector');
        else
            print(fig, savePath, '-dpdf', '-bestfit');
        end

    case '.svg'
        % SVG - vector format
        if exist('exportgraphics', 'file')
            exportgraphics(fig, savePath, 'ContentType', 'vector');
        else
            print(fig, savePath, '-dsvg');
        end

    case '.eps'
        % EPS - vector format
        print(fig, savePath, '-depsc', '-painters');

    case '.png'
        % PNG - raster format with transparency
        if exist('exportgraphics', 'file')
            exportgraphics(fig, savePath, 'Resolution', dpi);
        else
            print(fig, savePath, '-dpng', sprintf('-r%d', dpi));
        end

    case '.tif'
        % TIFF - raster format
        print(fig, savePath, '-dtiff', sprintf('-r%d', dpi));

    case {'.jpg', '.jpeg'}
        % JPEG - raster format
        if exist('exportgraphics', 'file')
            exportgraphics(fig, savePath, 'Resolution', dpi);
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
