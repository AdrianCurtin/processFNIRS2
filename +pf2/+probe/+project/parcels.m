function [h, imgOut] = parcels(varargin)
% PARCELS Draw an optode parcel map (Voronoi cells) on the cortical surface
%
% Renders a channel-space "parcel map": each in-coverage cortical vertex is
% hard-assigned to its nearest optode, producing discrete flat-filled cells
% with smooth outlined boundaries and a number on each cell. An optional
% subset of channels can be highlighted, and (when channel values are given)
% each cell is flat-filled by its value through the colormap. This is a thin
% convenience wrapper over pf2.probe.plot.interpolateValues3D's 'Parcellate'
% mode that also forwards every other interpolateValues3D option.
%
% IMPORTANT: a parcel map is a channel-assignment cartoon, NOT image
% reconstruction or DOT. Spatial resolution is channel-limited (source-
% detector geometry, typically ~2-3 cm), the coverage radius is a display
% heuristic, and a value-filled cell shows WHICH channel covers a region, not
% that the response is spatially uniform across it. For genuine image-space
% estimates use pf2.probe.dot.reconstruct; for a smooth field use
% pf2.probe.project.biomarker / interpolateValues3D's default interpolation.
%
% Reference:
%   Internal pf2 implementation (wraps pf2.probe.plot.interpolateValues3D).
%
% Syntax:
%   pf2.probe.project.parcels(proc)                       % gray numbered cells
%   pf2.probe.project.parcels(proc, 'Highlight', [2 8 9]) % highlight a subset
%   pf2.probe.project.parcels(channelValues, proc)        % value-filled cells
%   pf2.probe.project.parcels(..., 'savePath', 'parcels.png')
%   [h, imgOut] = pf2.probe.project.parcels(...)
%
% Inputs:
%   channelValues - [1 x C] value per plotted channel for the value-filled
%                   mode. Omit (or pass []) for a plain/highlighted parcel map.
%                   The first argument may instead be the data struct, in which
%                   case channelValues defaults to [].
%   data          - Processed fNIRS struct (must carry 3D optode coordinates).
%
% Name-Value Parameters (wrapper-specific):
%   'Highlight'    - Channels to paint in 'HighlightColor'. A NUMERIC list
%                    matches the PRINTED optode numbers ([2 8 9 16] highlights
%                    the cells labelled 2, 8, 9, 16); a LOGICAL mask selects by
%                    position in the plotted-channel order. Default [].
%   'HighlightColor'- Fill for highlighted cells (default purple).
%   'ParcelColor'  - Flat fill for non-highlighted cells with no value
%                    (default light gray).
%   'OutlineColor' - Cell boundary color (default white).
%   'OutlineWidth' - Cell boundary line width (default 1.5).
%   'Range'        - [lo hi] color limits for value-filled cells (default: the
%                    renderer's data-driven range).
%   'Colormap'     - Colormap name or [N x 3] for value-filled cells.
%   'Title'        - Title string (default '').
%   'Colorbar'     - Colorbar label for value-filled cells (default '').
%
% Any other name-value pairs (e.g. 'initCamPosition', 'Style', 'UseGeodesic',
% 'ForceLightMode', 'savePath', 'saveWidth') are forwarded to
% interpolateValues3D. For headless saving use 'savePath'.
%
% Outputs:
%   h      - Axes handle.
%   imgOut - RGB capture of the render (empty if not requested).
%
% Algorithm:
%   1. Resolve (channelValues, data) from the inputs.
%   2. Map the wrapper-friendly names to interpolateValues3D options and
%      enable 'Parcellate'.
%   3. Reset the target axes (drop a stale 2D axes / peer colorbar) and call
%      interpolateValues3D, which draws the cells, outlines, numbers, and
%      (for value-filled cells) the colorbar, and handles saving.
%
% Example:
%   data = pf2.import.sampleData.fNIR2000();
%   proc = processFNIRS2(data);
%   % Gray numbered cells with channels 2, 8, 9, 16 highlighted
%   pf2.probe.project.parcels(proc, 'Highlight', [2 8 9 16], ...
%       'initCamPosition', 'front', 'savePath', 'parcels.png');
%   % Value-filled cells (discrete per-channel map)
%   meanHbO = mean(proc.HbO(100:200, :), 1);
%   pf2.probe.project.parcels(meanHbO, proc, 'Colorbar', '\muM');
%
% Notes:
%   - Surface render only; honors 'UseGeodesic' (geodesic by default, which
%     prevents parcels bleeding across sulci / the midline).
%   - See pf2.probe.plot.interpolateValues3D for the full list of forwarded
%     options and the complete interpretive caveats.
%
% See also: pf2.probe.plot.interpolateValues3D, pf2.probe.project.regions,
%           pf2.probe.project.biomarker, pf2.probe.dot.reconstruct

% --- Resolve (channelValues, data) ---
if nargin >= 1 && isstruct(varargin{1})
    channelValues = [];
    data = varargin{1};
    rest = varargin(2:end);
elseif nargin >= 2
    channelValues = varargin{1};
    data = varargin{2};
    rest = varargin(3:end);
else
    error('pf2:probe:project:parcels:args', ...
        'Usage: parcels(proc, ...) or parcels(channelValues, proc, ...).');
end
if ~isstruct(data)
    error('pf2:probe:project:parcels:noData', ...
        'A processed fNIRS data struct is required.');
end

p = inputParser;
p.KeepUnmatched = true;
addParameter(p, 'Highlight', [], @(x) isempty(x) || (isnumeric(x) && isvector(x)) || islogical(x));
addParameter(p, 'HighlightColor', [0.62 0.40 0.78], @(x) isnumeric(x) && numel(x) == 3);
addParameter(p, 'ParcelColor', [0.78 0.78 0.80], @(x) isnumeric(x) && numel(x) == 3);
addParameter(p, 'OutlineColor', [1 1 1], @(x) isnumeric(x) && numel(x) == 3);
addParameter(p, 'OutlineWidth', 1.5, @(x) isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, 'Range', [], @(x) isempty(x) || (isnumeric(x) && numel(x) == 2));
addParameter(p, 'Colormap', [], @(x) isempty(x) || isnumeric(x) || ischar(x) || isstring(x));
addParameter(p, 'Title', '', @(x) ischar(x) || isstring(x));
addParameter(p, 'Colorbar', '', @(x) ischar(x) || isstring(x));
parse(p, rest{:});

% --- Map wrapper names to interpolateValues3D options ---
fwd = {'Parcellate', true, ...
       'HighlightColor', p.Results.HighlightColor, ...
       'ParcelColor', p.Results.ParcelColor, ...
       'ParcelOutlineColor', p.Results.OutlineColor, ...
       'ParcelOutlineWidth', p.Results.OutlineWidth};
if ~isempty(p.Results.Highlight)
    fwd = [fwd, {'HighlightChannels', p.Results.Highlight}];
end
if ~isempty(p.Results.Range)
    r = sort(p.Results.Range);
    fwd = [fwd, {'minval', r(1), 'maxval', r(2)}];
end
if ~isempty(p.Results.Colormap)
    fwd = [fwd, {'cmap', p.Results.Colormap}];
end
if ~isempty(char(p.Results.Title))
    fwd = [fwd, {'titleString', char(p.Results.Title)}];
end
if ~isempty(char(p.Results.Colorbar))
    fwd = [fwd, {'colorbarStr', char(p.Results.Colorbar)}];
end
fwd = [fwd, iUnmatched(p.Unmatched)];

% --- Reset the target axes and render ---
% A stale axes left by a prior 2D plot carries YDir='reverse', 2D limits and
% a peer colorbar that would corrupt the 3D render. Drop them first, unless
% the caller passed an explicit 'ax' (already forwarded via Unmatched).
if ~(isfield(p.Unmatched, 'ax') && ~isempty(p.Unmatched.ax))
    ax = gca;
    colorbar(ax, 'off');
    cla(ax, 'reset');
    fwd = [fwd, {'ax', ax}];
end

if nargout > 1
    [h, imgOut] = pf2.probe.plot.interpolateValues3D(channelValues, data, fwd{:});
else
    h = pf2.probe.plot.interpolateValues3D(channelValues, data, fwd{:});
    imgOut = [];
end

if nargout == 0
    clear h imgOut;
end

end

%%_Subfunctions_________________________________________________________

function c = iUnmatched(s)
% Convert an inputParser Unmatched struct to a name-value cell array.
fn = fieldnames(s);
c = cell(1, 2 * numel(fn));
for i = 1:numel(fn)
    c{2*i - 1} = fn{i};
    c{2*i}     = s.(fn{i});
end
end
