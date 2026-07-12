function [ h, imgOut ] = interpolateValues3D(varargin)
% INTERPOLATEVALUES3D Create 3D brain surface visualization with interpolated fNIRS data
%
% Generates a 3D brain surface visualization with fNIRS channel data projected
% onto the cortical surface. Values are interpolated across the brain mesh
% using nearest-neighbor or weighted distance methods, or (with 'Parcellate')
% drawn as a discrete optode parcel map. Supports MNI and Talairach coordinate
% systems, multiple probe configurations, EEG 10-20 electrode positions,
% Brodmann area overlays, and various visualization options.
%
% Reference:
%   Brain mesh coordinates based on MNI/ICBM templates.
%   10-20 EEG positions from: Koessler, L. et al. (2009). Automated cortical
%   projection of EEG sensors: Anatomical correlation via the international
%   10-10 system. NeuroImage, 46(1), 64-72.
%   DOI: 10.1016/j.neuroimage.2009.02.006
%
% Syntax:
%   InterpolateValues3D(data2plot)
%   InterpolateValues3D(data2plot, fNIR)
%   InterpolateValues3D(data2plot, fNIR, minVal, maxVal)
%   InterpolateValues3D(data2plot, fNIR, minVal, maxVal, titleString, colorbarStr)
%   [h, imgOut] = InterpolateValues3D(...)
%   InterpolateValues3D(ax, ...)  % Plot to specific axes
%
% Inputs:
%   data2plot     - Values to display for each channel [1 x C double] or
%                   cell array for multi-probe {[1xC1], [1xC2], ...}
%                   Pass [] to show probe geometry without data coloring.
%   fNIR          - fNIRS data structure or probe name string (default: {})
%                   For multi-probe, pass cell array of structs/names.
%   minVal        - Minimum value(s) for color scale (default: min(data2plot))
%                   For two-sided, pass [negMin, posMin].
%   maxVal        - Maximum value(s) for color scale (default: max(data2plot))
%   titleString   - Title displayed above the plot (default: '')
%   colorbarStr   - Title for the colorbar (default: '')
%
% Name-Value Parameters:
%   'ax'                - Target axes handle (default: gca)
%   'ChannelLabels'     - Show channel number labels (default: true)
%   'SDLabels'          - Show source/detector labels (default: varies)
%   'I1020_labels'      - Show 10-20 EEG labels (default: false)
%                         Can be true/false or cell array of electrode names.
%   'useHighRes'        - Use high-resolution brain mesh (default: true)
%   'cmap'              - Colormap for positive values (default: 'hotCropped')
%   'cmap_lower'        - Colormap for negative values (default: 'winter')
%   'labelfontsize'     - Font size for labels (default: 10)
%   'labelfontcolor'    - Font color for labels (default: theme-aware via
%                         pf2_base.plot.PlotStyle; black in light mode,
%                         white in dark mode)
%   'labelspherecolors' - Colors for source/detector spheres (default: ["r","y","w"])
%   'brainColor'        - Base brain surface color (default: [0.92, 0.68, 0.68])
%   'brainAlpha'        - Brain surface transparency (default: 1)
%   'showColorbar'      - Display colorbar (default: true)
%   'initCamPosition'   - Initial camera position (default: 'auto'). 'auto'
%                         frames the montage from an elevated 3/4 view (more
%                         dramatic for 'showcase', gentler for 'publication')
%                         so it never sits dead-on the camera.
%                         Options: 'auto', 'front', 'back', 'top', 'bottom',
%                         'left', 'right', 'face', 'top-left', 'top-right',
%                         'top-front', 'top-back', 'front-left', 'front-right',
%                         'back-left', 'back-right', or numeric [x, y, z].
%   'logScale'          - Use logarithmic color scale (default: false)
%   'interpolateType'   - Interpolation method (default: 'nearest')
%                         Options: 'nearest', 'linear', 'quadratic', 'cubic',
%                         'sensitivity'.
%                         Note: 'linear'/'quadratic'/'cubic' are IDW powers
%                         (0.5/1/1.5) applied to squared distance, not true
%                         polynomial interpolation schemes. 'sensitivity'
%                         weights channels by a Gaussian optical-sensitivity
%                         profile (smooth falloff tied to the buffer); it
%                         approximates the LATERAL sensitivity of a channel
%                         and is NOT a full Monte-Carlo photon measurement
%                         density ("banana").
%   'UseGeodesic'       - Use graph-geodesic distance on the cortical mesh
%                         instead of Euclidean (default: true). Prevents
%                         value bleed across sulci and the interhemispheric
%                         fissure. Pass false to restore the pre-v0.9
%                         Euclidean behavior. Applies to the surface brain
%                         only; voxel brain projection remains Euclidean.
%                         Adds a one-time mesh-graph build (cached per axes).
%   'ForceLightMode'    - Override theme detection: white background, black
%                         axes tick/labels and probe labels (default: false).
%                         Useful for publication figures regardless of the
%                         MATLAB desktop theme.
%   'ChannelAlpha'      - [1 x K] per-channel alpha in [0,1]. Default all 1
%                         (fully opaque). Use with 'AlphaMode','transparent'
%                         to hide channels (e.g. non-significant stats) —
%                         the brain surface shows through rather than being
%                         blended with brainColor.
%   'AlphaMode'         - 'blend' (default) | 'transparent'. In 'blend',
%                         non-contributing vertices are mixed with brainColor
%                         (legacy behavior). In 'transparent', per-vertex
%                         FaceVertexAlphaData is set so the mesh is actually
%                         see-through where channel alpha is low.
%   'bufferDistance'    - Buffer around optodes in mm (default: auto)
%   'includeSS'         - Include short separation channels (default: varies)
%   'useTalairach'      - Use Talairach coordinates (default: false, uses MNI)
%   'transformToMNI'    - Transform non-MNI coordinates to MNI space (default: 'auto')
%                         'auto': Transform if coordinate system is not MNI and
%                                 landmarks (10-20 electrode positions) are available
%                         true: Always transform (error if no landmarks)
%                         false: Never transform, use original coordinates
%   'BrodmannAreas'     - Highlight Brodmann areas (default: false)
%                         Set true for all areas, or [9,10,46] for specific areas.
%   'showScattering'    - Show light scattering paths (default: false)
%   'optodeLines'       - Show optode direction lines (default: false)
%   'animated'          - Optimize for animation (default: false)
%   'voxelLighting'     - Lighting style for voxel brain (default: 'none')
%                         Options: 'none', 'realistic', 'dramatic', 'clinical'
%   'savePath'          - File path to save the rendered figure (default: '').
%                         This is the supported way to save 3D renders
%                         headlessly — see Notes.
%   'saveWidth'         - Saved image width in pixels (default: figure width)
%   'saveHeight'        - Saved image height in pixels (default: figure height)
%   'saveDPI'           - Saved image resolution (default: 150)
%   'Style'             - Render-quality preset (default 'showcase'):
%                         'showcase' (default) - procedural matcap shading
%                           (clay), neutral-gray cortex so activation pops,
%                           stronger sulcal ambient occlusion, an elevated 3/4
%                           "hero" default view and 2x export supersampling;
%                           the polished, presentation look (inspired by
%                           MRIcroGL/Surfice surface renders).
%                         'publication' - smooth Gouraud matte cortex, gentle
%                           sulcal ambient occlusion, peachy anatomical tone,
%                           data-facing default view; the conservative look.
%                         A style struct (see pf2_base.plot.RenderStyle) may
%                         also be passed to override individual fields.
%   'Parcellate'        - Render an optode PARCEL MAP instead of a smooth
%                         field (default false). Each in-coverage cortical
%                         vertex is hard-assigned to its nearest optode,
%                         producing discrete flat-filled cells (Voronoi-style)
%                         with outlined boundaries. With data2plot, each cell
%                         is filled by its channel value through the colormap
%                         (a discrete per-channel map); without data, cells
%                         use 'ParcelColor'. Surface render only (ignored for
%                         the voxel brain and when VertexData is supplied);
%                         honors 'UseGeodesic'. This is a channel-assignment
%                         cartoon, NOT image reconstruction or DOT — see Notes.
%   'HighlightChannels' - Channels whose parcels are painted in
%                         'HighlightColor' (default []). A NUMERIC list matches
%                         the PRINTED optode numbers (OptodeNum), so
%                         [2 8 9 16] highlights the cells labelled 2, 8, 9, 16.
%                         A LOGICAL mask selects by position in the plotted-
%                         channel order. Parcellation only.
%   'HighlightColor'    - Fill color for highlighted parcels (default purple
%                         [0.62 0.40 0.78]).
%   'ParcelColor'       - Flat fill for non-highlighted parcels when no data
%                         is supplied (default light gray [0.78 0.78 0.80]).
%   'ParcelOutlineColor'- Color of the cell boundary outlines (default white).
%   'ParcelOutlineWidth'- Line width of the cell boundary outlines (default 1.5).
%
% Outputs:
%   h      - Handle to the axes containing the visualization
%   imgOut - RGB image capture of the rendered figure [H x W x 3 uint8]
%
% Example:
%   % Basic 3D visualization of HbO data
%   data = pf2.import.sampleData.fNIR2000();
%   processed = processFNIRS2(data);
%   hboVals = processed.HbO(100, :);  % Single timepoint
%   pf2.probe.plot.interpolateValues3D(hboVals, processed, -1, 1, 'HbO');
%
%   % Show probe geometry without data
%   pf2.probe.plot.interpolateValues3D([], processed, 'initCamPosition', 'front');
%
%   % Multi-probe visualization
%   pf2.probe.plot.interpolateValues3D({hbo1, hbo2}, {fnir1, fnir2});
%
%   % Show with Brodmann areas
%   pf2.probe.plot.interpolateValues3D([], processed, 'BrodmannAreas', [9,10,46]);
%
%   % Optode parcel map: gray cells with a highlighted (purple) subset
%   pf2.probe.plot.interpolateValues3D([], processed, 'Parcellate', true, ...
%       'HighlightChannels', [2 8 9 16]);
%
%   % Parcel map filled discretely by HbO value (a discrete per-channel map)
%   pf2.probe.plot.interpolateValues3D(hboVals, processed, 'Parcellate', true);
%
% Notes:
%   - Requires cerebro_mdl.mat brain mesh data file
%   - Short separation channels are excluded by default when data is provided
%   - Uses 'animated' mode for video generation to avoid redrawing static elements
%   - PARCELLATION ('Parcellate') is a channel-assignment cartoon, NOT image
%     reconstruction or DOT, and NOT a measurement of cortical activity at the
%     cell's spatial extent. Spatial resolution is channel-limited (set by
%     source-detector geometry, typically ~2-3 cm), not by the mesh. In the
%     data-filled mode each cell is flat-filled with a single channel value:
%     that conveys WHICH channel covers a region, not that the hemodynamic
%     response is spatially uniform across the cell. For a smooth, uncertainty-
%     communicating field use the default interpolation; for sensitivity-
%     weighted footprints use interpolateType='sensitivity'; for genuine
%     image-space estimates use pf2.probe.dot.reconstruct.
%   - The parcellation coverage radius is a display heuristic derived from the
%     montage-median source-detector distance (via 'bufferDistance'), not a
%     measured sensitivity boundary or penetration depth. It is uniform across
%     the montage; changing it rescales apparent coverage without changing the
%     data. Vertices are assigned to the nearest parcel center by proximity
%     (geodesic by default, which prevents bleed across sulci/the midline);
%     this is a heuristic and does not imply the channel samples that vertex's
%     cortex. Cell boundaries are cosmetically smoothed and are illustrative —
%     their exact placement carries no anatomical or functional meaning.
%   - HEADLESS SAVING: 3D cortical surfaces only rasterize in a *visible*
%     figure. Under headless MATLAB (-batch / -nodisplay) the generic
%     figure('Visible','off') + saveas/exportgraphics pattern produces a
%     BLANK image. Use the 'savePath' option instead (or capture the imgOut
%     output and imwrite it) — both render correctly headlessly. This applies
%     to all wrappers (pf2.probe.plot.showProbe3D, pf2.probe.project.*).
%
% See also: pf2.probe.plot.showProbe3D, pf2.probe.plot.interpolateValues,
%           pf2.probe.plot.imageValues, pf2.probe.project.parcels,
%           pf2.probe.dot.reconstruct, exploreFNIRS
isStructOrEmpty=@(x) isstruct(x)||isempty(x);
isStringOrChar=@(x)isstring(x)||ischar(x);

validAxesHandle= @(x) isa(x,'matlab.graphics.axis.Axes')&&isvalid(x);
validScalarPosNumOr0 = @(x) isnumeric(x) && x>=0;
validScalarPosNum = @(x) isnumeric(x) && x>0;
validScalarPosNumOrNan = @(x) isnumeric(x) && (x>0||isnan(x));
validI1020Label = @(x) islogical(x) || isStringOrChar(x) || iscell(x);
validBrodmann = @(x) islogical(x) || isnumeric(x)&&all(x<=55)&&all(x>0);
validColor = @(x) (ischar(x) && length(x) == 1) || (isnumeric(x) && length(x) == 3) || isempty(x);
validFnirs = @(x) isStructOrEmpty(x) || iscell(x);
%validColorList = @(x) validColor(x) || all(arrayfun(validColor, x));

defaultInterpolateType = 'nearest';
validInterpolateTypes = {'nearest', 'linear', 'quadratic', 'cubic', 'sensitivity'};
validInterpolateType = @(x) any(validatestring(x, validInterpolateTypes));

defaultCamPosition = 'auto';
validCamPositions = {'auto','front', 'back', 'top', 'bottom', 'left', 'right', 'face', ...
    'top-left', 'top-right', 'top-front', 'top-back', ...
    'front-left', 'front-right', 'back-left', 'back-right'};
validCamPosition = @(x) ((isstring(x)||ischar(x))&&any(validatestring(x, validCamPositions))) || (isnumeric(x) && length(x) == 3);

defaultColormap = 'hotCropped';
defaultColormapLow = 'winter';

cropFn = @(var,n) var(end-n+1:end,:);
hotCropped = @(n) cropFn(hot(ceil(n*1.25)),n);

validColormapLabels = exploreFNIRS.helper.listColormaps('all');
% Accept numeric [Nx3], a function handle, or any name string (resolved by
% iResolveColormap, which also handles pf2_base.plot.brainColormap names such
% as 'rdbu','viridis','cividis','actc','warm','cool').
validColormap = @(x) (isnumeric(x)&&(size(x,2)==3))||isa(x,'function_handle') || any(ishandle(x)) || ischar(x) || isstring(x);

if(numel(varargin) > 0 && isa(varargin{1},'matlab.graphics.axis.Axes')) %If first argument is axes then move to front
    ax=varargin{1};
    varargin=varargin(2:end);
else
    % Draw into the current figure/axes. Do NOT spawn a new visible figure
    % when the current one is off-screen — that orphaned the caller's
    % invisible figure and produced blank headless saves (the figure the
    % caller saved was empty because drawing went to the new figure instead).
    ax=gca;
end

% 3D cortical surfaces only rasterize in a visible figure under headless
% MATLAB (-batch / -nodisplay). If the target figure is off-screen, make it
% visible for the duration of the render and restore its original visibility
% on return. This lets 'savePath' and the returned imgOut work headlessly
% without spawning a surprise window or orphaning the caller's figure.
renderFig = ancestor(ax, 'figure');
if ~isempty(renderFig) && strcmpi(char(renderFig.Visible), 'off')
    origVisibleState = renderFig.Visible;
    renderFig.Visible = 'on';
    restoreVisibleOnExit = onCleanup(@() iLocalRestoreVisible(renderFig, origVisibleState)); %#ok<NASGU>
end




p_pre=inputParser;
p=inputParser;

addOptional(p_pre,'data2plot', []);

parse(p_pre,varargin{1});
data2plot = p_pre.Results.data2plot;
shouldHideByDefault = isempty(data2plot);

addOptional(p,'data2plot', []);
addOptional(p,'fNIR', {}, validFnirs);
addOptional(p,'minval', [], @isnumeric);
addOptional(p,'maxval', [], @isnumeric);
addOptional(p,'titleString', '', isStringOrChar);
addOptional(p,'colorbarStr', '', isStringOrChar);


addParameter(p,'ax',ax,validAxesHandle,'PartialMatchPriority',1);
addParameter(p,'ChannelLabels',true,@islogical);
addParameter(p,'SDLabels',shouldHideByDefault,@islogical);
addParameter(p,'I1020_labels',false,validI1020Label);
addParameter(p, 'useHighRes', true, @islogical);
% VertexData: pre-computed per-vertex field (e.g. DOT reconstruction, coverage,
% PMDF backprojection) coloured directly onto the cortical mesh, bypassing the
% channel->vertex interpolation. Must match the mesh vertex count (high-res by
% default). NaN vertices render transparent (sensitivity masking). VertexAlpha
% optionally sets per-vertex opacity.
addParameter(p, 'VertexData', [], @(x) isempty(x) || isnumeric(x));
addParameter(p, 'VertexAlpha', [], @(x) isempty(x) || isnumeric(x));
addParameter(p, 'cmap', defaultColormap, validColormap);
addParameter(p, 'cmap_lower', defaultColormapLow, validColormap);
addParameter(p, 'labelfontsize', 10, validScalarPosNum);
addParameter(p, 'LabelLift', 1, @(x) isnumeric(x) && isscalar(x) && x>=0); % mm to lift S/D/channel labels toward the camera so they sit on top of neighbouring marker spheres (0 disables)
addParameter(p, 'MarkerScale', 1, @(x) isnumeric(x) && isscalar(x) && x>0); % multiplier on optode/source/detector marker size (1 = default)
addParameter(p, 'ShowAxes', true, @islogical); % show the x/y/z axes, ticks and box (false drops them for a clean probe render)
addParameter(p, 'labelfontcolor', [], validColor);  % [] => PlotStyle theme-aware default
addParameter(p, 'labelspherecolors', ["r", "y","w"]);
addParameter(p, 'brainColor', [0.92, 0.68, 0.68], validColor);
addParameter(p, 'voxelColor', [1, 1, 1], validColor);
addParameter(p, 'brainAlpha', 1, validScalarPosNumOr0);
addParameter(p, 'brainLineColor', [], validColor);
addParameter(p, 'backgroundColor', [], validColor);
addParameter(p, 'showColorbar', true, @islogical);
addParameter(p, 'initCamPosition', defaultCamPosition, validCamPosition);
addParameter(p, 'logScale', false, @islogical);
addParameter(p, 'interpolateType', defaultInterpolateType, validInterpolateType);
addParameter(p, 'UseGeodesic', true, @islogical); % Geodesic distance on cortical mesh (surface only). Pass false for legacy Euclidean.
addParameter(p, 'ChannelAlpha', [], @(x) isempty(x) || (isnumeric(x) && all(x(:) >= 0) && all(x(:) <= 1))); % [1xK] per-channel alpha in [0,1]
addParameter(p, 'AlphaMode', 'blend', @(x) any(validatestring(lower(char(x)), {'blend','transparent'}))); % 'blend' (default) | 'transparent'
addParameter(p, 'bufferDistance', nan, validScalarPosNumOrNan); %In a grid, this may equal to sqrt(sd distance^2/2)
addParameter(p, 'includeSS', shouldHideByDefault, @islogical);
addParameter(p, 'showReference', false, @islogical);
addParameter(p, 'showScattering', false, @islogical);
addParameter(p, 'scatteringFactor', 1, validScalarPosNumOrNan);
addParameter(p, 'useEEG', false, @islogical);
addParameter(p, 'optodeLines', false, @islogical);
addParameter(p, 'useProjectedOptodeLocations', false,@islogical);
addParameter(p, 'useTalairach', false, @islogical); % Otherwise will default to MNI
addParameter(p, 'BrodmannAreas', false, validBrodmann); % Colors in Brodmann areas
addParameter(p, 'BA_cmp', @lines, validColormap); % Colors in Brodmann areas
addParameter(p, 'useVoxelBrodmannAreas', false, @islogical); % Colors in Brodmann areas
addParameter(p, 'showVoxelBrain', false, @islogical); % Colors in Brodmann areas
addParameter(p, 'voxelLighting', 'none', @(x) ischar(x) || isstring(x));
addParameter(p, 'ForceLightMode', false, @islogical); % Per-call override: white bg, black axes/labels
centerCamPos=[0,-20,0];
addParameter(p, 'camTarget', centerCamPos, validCamPosition); % Target Camera location
addParameter(p, 'camUp', [0,0,1] , validCamPosition); % Target Camera location
addParameter(p, 'animated', false, @islogical); % Optimizes for animation (By not redrawing certain things when possible)
addParameter(p, 'transformToMNI', 'auto', @(x) islogical(x) || (ischar(x) && strcmpi(x, 'auto'))); % Transform non-MNI coords to MNI
addParameter(p, 'savePath', '', @(x) ischar(x) || isstring(x));
addParameter(p, 'saveWidth', [], @(x) isempty(x) || isnumeric(x));
addParameter(p, 'saveHeight', [], @(x) isempty(x) || isnumeric(x));
addParameter(p, 'saveDPI', 150, @isnumeric);
addParameter(p, 'Style', 'showcase', @(x) ischar(x) || isstring(x) || isstruct(x)); % render preset: 'showcase' (default) | 'publication' | style struct

% Parcellation variant: hard-assign each in-coverage vertex to its nearest
% optode and render discrete flat-filled cells with outlined boundaries
% (Voronoi-style optode parcel map) instead of a smoothly interpolated field.
addParameter(p, 'Parcellate', false, @islogical);
addParameter(p, 'HighlightChannels', [], @(x) isempty(x) || ((isnumeric(x)||islogical(x))&&isvector(x))); % indices (or logical mask) into the plotted channels to paint in HighlightColor
addParameter(p, 'HighlightColor', [0.62 0.40 0.78], validColor);   % fill for highlighted parcels (default purple)
addParameter(p, 'ParcelColor', [0.78 0.78 0.80], validColor);      % flat fill for non-highlighted parcels when no data is supplied
addParameter(p, 'ParcelOutlineColor', [1 1 1], validColor);        % color of the cell boundary outlines
addParameter(p, 'ParcelOutlineWidth', 1.5, validScalarPosNum);     % line width of the cell boundary outlines


parse(p,varargin{:});



data2plot = p.Results.data2plot;
vertexData = p.Results.VertexData;
vertexAlphaIn = p.Results.VertexAlpha;
if ~isempty(vertexData), vertexData = vertexData(:); end
if ~isempty(vertexAlphaIn), vertexAlphaIn = vertexAlphaIn(:); end
titleString = p.Results.titleString;
clrBarTitle = p.Results.colorbarStr;
projectmode = p.Results.interpolateType;
bufferDistance=p.Results.bufferDistance;
include_ss=p.Results.includeSS;
savePath = p.Results.savePath;
saveWidth = p.Results.saveWidth;
saveHeight = p.Results.saveHeight;
saveDPI = p.Results.saveDPI;

% Resolve the render-quality preset (lighting/AO/matcap/view/supersample).
renderStyle = pf2_base.plot.RenderStyle.get(p.Results.Style);


multiprobe = iscell(data2plot);


if(~multiprobe&&isnumeric(data2plot))
    data2plot={data2plot};
end

numProbes=length(data2plot);

for i=1:numProbes
    dataEmpty(i)=isempty(data2plot{i});
end

if(multiprobe && ~all(dataEmpty))
    data2plot_cell = data2plot;
    concat_data = [];
    for i=1:numel(data2plot)
        concat_data = [concat_data, data2plot{i}];
    end
    data2plot_concat = concat_data(:);
else
    data2plot_concat=data2plot{1}(:);
end

fNIR = p.Results.fNIR;

% Unwrap single-element cell of config name string for single-probe mode
if iscell(fNIR) && numel(fNIR) == 1 && (isstring(fNIR{1}) || ischar(fNIR{1}))
    fNIR = fNIR{1};
end

% Store config name for downstream loading (don't load yet)
fNIR_cfgOverride = '';
if (isstring(fNIR) || ischar(fNIR)) && ~isempty(fNIR)
    fNIR_cfgOverride = char(fNIR);
    if ~endsWith(fNIR_cfgOverride, '.cfg')
        fNIR_cfgOverride = [fNIR_cfgOverride '.cfg'];
    end
    fNIR = {};  % clear so downstream treats as empty struct
end

if isempty(fNIR) && ~p.Results.useEEG
    if multiprobe
        error('pf2:probe:interpolateValues3D:noMultiprobeDevice', "Must specify FNIRS devices when using Multi-probe plotting")
    end
end

if(iscell(fNIR)&&all(dataEmpty))
    if(length(fNIR)>1)
        multiprobe=true;
        dataEmpty=true(size(fNIR));
    end
end

animationOptimized=p.Results.animated;

cbarUpper_minmax=[nan,nan];
cbarLower_minmax=[nan,nan];

minVal = p.Results.minval;
maxVal = p.Results.maxval;

negColorbar=false; % Enabled when only negative color bar is present and min>max


if(isempty(p.Results.minval))
    minVal = min(data2plot_concat, [], 'omitnan');
end

if(length(minVal)==2)
    twosided = true;
    minVal=sort(minVal);
else
    twosided = false;
end

if(length(maxVal)==2)
    twosided=true;
    maxVal=sort(maxVal);
elseif(length(maxVal)==1)
    if(~twosided&&minVal>maxVal)
        negColorbar=true;
    end
end

if(isempty(maxVal)) % No max value specified
    if(~twosided)
        %[X,X] [Min1, Datamax]
        maxVal=max(data2plot_concat, [], 'omitnan');
        cbarUpper_minmax=[minVal maxVal];
    else
        %[DataMin, Min2] [Min1, Datamax] or DataMin-1e-3, DataMax+1e-3
        dataMaxVal=max(max(minVal)+1e-3,max(data2plot_concat, [], 'omitnan'));
        cbarUpper_minmax=[max(minVal) dataMaxVal];
        if(max(data2plot_concat, [], 'omitnan')<max(minVal))
            hasUpperData=false;
        else
            hasUpperData=true;
        end
        dataMinVal=min(min(minVal)-1e-3,min(data2plot_concat, [], 'omitnan'));
        cbarLower_minmax=[dataMinVal min(minVal)];
        if(min(data2plot_concat, [], 'omitnan')>min(minVal))
            hasLowerData=false;
        else
            hasLowerData=true;
        end
    end
elseif(length(maxVal) == 1 && length(minVal) == 2) % One Max value specified
    % If a max value is in the middle, then it is the 0
    if maxVal > min(minVal)  && maxVal < max(minVal)
        % [Min1 Max Min2]
        s = sort([minVal, maxVal]);
        cbarLower_minmax=s(1:2);
        cbarUpper_minmax=s(2:3);
    else
        % [-Max Min1], [Min2 Max]
        maxVal = [-abs(maxVal) abs(maxVal)];
        s = sort([minVal, maxVal]);
        cbarLower_minmax=s(1:2);
        cbarUpper_minmax=s(3:4);
    end
elseif(length(maxVal) == 2 && length(minVal) == 1) % Two Max value specified, one min, two colorbars
    s = sort([minVal, maxVal]);
    cbarLower_minmax=s(1:2);
    cbarUpper_minmax=s(2:3);
elseif(length(maxVal) == 2 && length(minVal) == 2) % Everything specified
    s = sort([minVal, maxVal]);
    cbarLower_minmax=s(1:2);
    cbarUpper_minmax=s(3:4);
elseif(length(maxVal)==1 && length(minVal)==1)
    cbarUpper_minmax=sort([minVal, maxVal]);
end

% Default hasUpperData/hasLowerData when maxVal was explicitly provided
if twosided && ~exist('hasUpperData', 'var')
    hasUpperData = true;
end
if twosided && ~exist('hasLowerData', 'var')
    hasLowerData = true;
end

if(p.Results.logScale)
    if(any(data2plot_concat<=0))
        error('pf2:probe:interpolateValues3D:negativeLogScale', "Cannot use logscale when data contains negative values")
    end
    data2plot_concat = log(data2plot_concat);
    cbarLower_minmax=log(cbarUpper_minmax);
    cbarUpper_minmax=log(cbarUpper_minmax);
end



% Resolve colormaps to n->[n x 3] handles (numeric matrices and names alike).
cmap_high = iResolveColormap(p.Results.cmap, hotCropped);
cmap_low_t = iResolveColormap(p.Results.cmap_lower, hotCropped);
cmap_low = @(n) flip(cmap_low_t(n));

ax = p.Results.ax;
forceLightMode = p.Results.ForceLightMode;
bgc = p.Results.backgroundColor;
if forceLightMode && (isempty(bgc) || any(ismissing(bgc)))
    bgc = [1 1 1];
end
if(~any(ismissing(bgc)) && ~isempty(bgc))
    set(ax, 'color', bgc);
    parentFig = ancestor(ax, 'figure');
    if ~isempty(parentFig) && isvalid(parentFig) && forceLightMode
        set(parentFig, 'Color', bgc);
    end
end

% Resolve theme-aware default for label font color (dark-mode visibility).
% ForceLightMode overrides any theme detection to keep axes/labels readable
% on a white background.
labelFontColor = p.Results.labelfontcolor;
if isempty(labelFontColor)
    if forceLightMode
        labelFontColor = [0 0 0];
    else
        try
            labelFontColor = pf2_base.plot.PlotStyle.getDefault().ForegroundColor;
        catch
            labelFontColor = [0 0 0];
        end
    end
end

% When forcing light mode, set axes tick/label colors so xyz labels render black
if forceLightMode
    set(ax, 'XColor', [0 0 0], 'YColor', [0 0 0], 'ZColor', [0 0 0]);
end

numericColors = isnumeric(p.Results.labelspherecolors);
ss = size(p.Results.labelspherecolors);
if(numericColors)
    numColors = ss(1);
else
    numColors = length(p.Results.labelspherecolors);
end
if(numericColors)
    switch(numColors)
        case 1
            srcColor = p.Results.labelspherecolors;
            detColor = p.Results.labelspherecolors;
            optColor = p.Results.labelspherecolors;
            color1020 = p.Results.labelspherecolors;
        case 2
            srcColor = p.Results.labelspherecolors(1,:);
            detColor = p.Results.labelspherecolors(2,:);
            optColor=[];
        case 3
            srcColor = p.Results.labelspherecolors(1,:);
            detColor = p.Results.labelspherecolors(2,:);
            optColor = p.Results.labelspherecolors(3,:);
        otherwise
            srcColor = p.Results.labelspherecolors(1,:);
            detColor = p.Results.labelspherecolors(2,:);
            optColor = p.Results.labelspherecolors(3,:);
            color1020 = p.Results.labelspherecolors(4,:);
    end
else
    switch(numColors)
        case 1
            srcColor = p.Results.labelspherecolors;
            detColor = p.Results.labelspherecolors;
            optColor = p.Results.labelspherecolors;
            color1020 = p.Results.labelspherecolors;
        case 2
            srcColor = p.Results.labelspherecolors(1);
            detColor = p.Results.labelspherecolors(2);
            optColor=[];
        case 3
            srcColor = p.Results.labelspherecolors(1);
            detColor = p.Results.labelspherecolors(2);
            optColor = p.Results.labelspherecolors(3);
        otherwise
            srcColor = p.Results.labelspherecolors(1);
            detColor = p.Results.labelspherecolors(2);
            optColor = p.Results.labelspherecolors(3);
            color1020 = p.Results.labelspherecolors(4);
    end
end
useHighRes = p.Results.useHighRes;
show1020 = p.Results.useEEG || islogical(p.Results.I1020_labels) && p.Results.I1020_labels || ~islogical(p.Results.I1020_labels) && ~isempty(p.Results.I1020_labels);
showSD = p.Results.SDLabels;
showChannels = p.Results.ChannelLabels;

%cla
hold off



itemsToDelete={'BrainVoxel','BrainOverlay','BrainVoxelOverlay','BA_area_mrk','Eye','ProbeOpt','OptLabel','ProbeSrc','ProbeSrcLabel','ProbeDet','ProbeDetLabel','Scatter1020','Label1020','ScatterCurve','OptLines','BrainRef','ParcelEdges'};

grootHandle=groot;
grootHandle.ShowHiddenHandles=true;
itemsToSkipPlot=cell(0);
j=1;
for i=1:length(itemsToDelete)
    item = findobj(ax, "Tag", itemsToDelete{i});
    if(~isempty(item)&&~animationOptimized)
        delete(item);
    elseif(~isempty(item)&&animationOptimized)
        itemsToSkipPlot{j}=itemsToDelete{i};
        j=j+1;
    end
end
grootHandle.ShowHiddenHandles=false;

probeInfo=[];

if(multiprobe)
    num_devices = length(fNIR);
    probeInfos = {};
    maxSrcIdx=0;
    maxDetIdx=0;
    for i=1:num_devices
        if(isstring(fNIR{i})||ischar(fNIR{i}))
            cfgFilePath=sprintf('%s.cfg', fNIR{i});
            
        elseif(pf2_base.isnestedfield(fNIR{i}, 'info.probename')&&isfield(fNIR{i}.info, 'probename')&&~contains(fNIR{i}.info.probename,'Unknown'))
            cfgFilePath = sprintf('%s.cfg', fNIR{i}.info.probename);
        else
            cfgFilePath = '';
        end
        probeInfos{i} = pf2_base.loadDeviceCfg(cfgFilePath);
        
        if(pf2_base.isnestedfield(probeInfos{i},'Probe'))
            deviceInfo=probeInfos{i}.Info;
            if(~isfield(deviceInfo,'numberProbes')||deviceInfo.numberProbes==1)
                probeNum=1;
            end
            probeInfos{i}=probeInfos{i}.Probe{probeNum};
            probeInfos{i}.TableOpt.ProbeNum(:,1)=i;
            probeInfos{i}.TableSD.ProbeNum(:,1)=i;
            probeInfos{i}.TableOpt.SrcIdx=probeInfos{i}.TableOpt.SrcIdx+maxSrcIdx;
            maxSrcIdx=maxSrcIdx+max(probeInfos{i}.TableOpt.SrcIdx);
            probeInfos{i}.TableOpt.DetIdx=probeInfos{i}.TableOpt.DetIdx+maxDetIdx;
            maxDetIdx=maxDetIdx+max(probeInfos{i}.TableOpt.DetIdx);
            probeInfos{i}.TableOpt.HasData(:,1)=~dataEmpty(i);
        else
            error('pf2:probe:interpolateValues3D:noProbe', 'Unable to identify probe');
        end

        nData=length(data2plot{i});
        nOpt=probeInfos{i}.NumOptodes;
        nSS=probeInfos{i}.NumShortSeparation;
        if(~dataEmpty(i) && (include_ss&&nData~=nOpt...
                || (~include_ss&&nData~=(nOpt-nSS))))
            error('pf2:probe:interpolateValues3D:optodeCountMismatch', 'Must have a value for all optodes');
        end
        clear nData nOpt nSS
    end
    probeInfo = {};
    fields = fieldnames(probeInfos{1});
    for i=1:numel(fields)
        value = probeInfos{1}.(fields{i});
        if size(value, 1) == 1 && size(value, 2) == 1
            continue;
        elseif size(value, 1) == 1
            result = [];
            for j=1:num_devices
                result = [result, probeInfos{j}.(fields{i})];
            end
            probeInfo.(fields{i}) = result;
        elseif size(value, 2) == 1
            result = [];
            for j=1:num_devices
                result = [result; probeInfos{j}.(fields{i})];
            end
            probeInfo.(fields{i}) = result;
        elseif istable(value)
            result = probeInfos{1}.(fields{i});
            if strcmp(fields{i}, "TableOpt")
                result = removevars(result, {'Ch', 'wv'});
            end
            for j = 2:num_devices
                temp = probeInfos{j}.(fields{i});
                if strcmp(fields{i}, 'TableOpt')
                    temp = removevars(temp, {'Ch', 'wv'});
                end
                
                result = [result; temp];
            end
            probeInfo.(fields{i}) = result;
        end
    end
    
    
    
    probeInfo.OptPos3D_mean = [mean(probeInfo.OptPos.x, 'omitnan') mean(probeInfo.OptPos.y, 'omitnan') mean(probeInfo.OptPos.z, 'omitnan')];
    probeInfo.NumShortSeparation = sum(probeInfo.TableOpt.IsShortSeparation);
    probeInfo.NumOptodes = length(probeInfo.OptPos.x);
else
    if(p.Results.useEEG && isempty(fNIR))
        probeDraw = {};
        cfgFilePath = '';
    elseif ~isempty(fNIR_cfgOverride)
        cfgFilePath = fNIR_cfgOverride;
    elseif(isfield(fNIR,'probeinfo'))
        probeInfo=fNIR.probeinfo;
    elseif(pf2_base.isnestedfield(fNIR,'info.probename')&&isfield(fNIR.info,'probename')&&~contains(fNIR.info.probename,'Unknown'))
        %try to load the probename cfg file
        cfgFilePath=sprintf('%s.cfg',fNIR.info.probename);
    else
        cfgFilePath='';
    end
    
    if(~isempty(probeInfo) || isempty(cfgFilePath) && p.Results.useEEG)
        
        
    elseif(isempty(cfgFilePath)||~contains(cfgFilePath,'.cfg'))
        
        warning('Missing or invalid configuration file path\n')
        
        disp('No device specified. Please load device configuration');
        probeInfo=pf2_base.loadDeviceCfg('',false);
        if(isempty(probeInfo))
            error('pf2:probe:interpolateValues3D:noDevice', 'No valid devices selected');
        end
        
        
        
    elseif(~isempty(cfgFilePath)) % If we're not looking at the GUI, doesn't matter
        probeInfo=pf2_base.loadDeviceCfg(cfgFilePath,false);
    end
    
    if(pf2_base.isnestedfield(probeInfo,'Probe'))
        deviceInfo=probeInfo.Info;
        if(~isfield(deviceInfo,'numberProbes')||deviceInfo.numberProbes==1)
            probeNum=1;
        end
        probeInfo=probeInfo.Probe{probeNum};
        
        probeInfo.TableOpt.HasData(:,1)=~dataEmpty;
        probeInfo.TableOpt.ProbeNum(:,1)=1;
        
    elseif(~p.Results.useEEG)
        error('pf2:probe:interpolateValues3D:noProbe', 'Unable to identify probe');
    end
end

% 3D rendering needs physical MNI optode coordinates. Layout-only devices
% (schematic grid, no positions) have no Pos3D columns -- fail with a clear
% message instead of an opaque "Unrecognized variable name 'Pos3D_x'" later.
if ~p.Results.useEEG && isfield(probeInfo, 'TableOpt') && istable(probeInfo.TableOpt) ...
        && ~ismember('Pos3D_x', probeInfo.TableOpt.Properties.VariableNames)
    error('pf2:interpolateValues3D:noGeometry', ...
        ['This device has no 3D optode coordinates (layout-only montage). ' ...
         'Use pf2.probe.plot.topo / imageValues for a 2D view instead.']);
end

if(show1020)
    c1020=pf2_base.getAsset('cerebro_1020'); %estimation of 10-20 coordinates
    
    if(p.Results.useTalairach)
        txyz=pf2_base.external.icbm_fsl2tal([c1020.mx,c1020.my,c1020.mz]);
        
        c1020.x = txyz(:,1);
        c1020.y = txyz(:,2);
        c1020.z = txyz(:,3);
    else
        c1020.x = c1020.mx;
        c1020.y = c1020.my;
        c1020.z = c1020.mz;
    end
    
    c1020 = c1020(~isnan(c1020.x), :);
    if ~islogical(p.Results.I1020_labels)
        labels = p.Results.I1020_labels;
        c1020 = c1020(ismember(c1020.Electrode, labels), :);
    end
    
    if(p.Results.useEEG)
        probeDraw = probeInfo;
        probeInfo = {};
        idx = arrayfun(@(x) find(strcmp(c1020.Electrode, x)), labels);
        data2plot_concat = data2plot_concat(idx);
        
        probeInfo.OptPos3DX = c1020.x;
        probeInfo.OptPos3DY = c1020.y;
        probeInfo.OptPos3DZ = c1020.z;
        
        probeInfo.OptPos.x=c1020.x;
        probeInfo.OptPos.y=c1020.y;
        probeInfo.OptPos.z=c1020.z;
        
        probeInfo.NumOptodes = height(c1020);
        probeInfo.IsShortSeparation = zeros(1, probeInfo.NumOptodes);
        probeInfo.OptPos3D_mean = mean([probeInfo.OptPos3DX probeInfo.OptPos3DY probeInfo.OptPos3DZ], 'omitnan');
        if(isnan(p.Results.bufferDistance))
            bufferDistance = 40/sqrt(2);
        end
    end
end

if(p.Results.useEEG && ~isempty(probeDraw))
    tempProbe = probeInfo;
    probeInfo =  probeDraw;
end

% Apply MNI transformation if needed
transformOpt = p.Results.transformToMNI;
if isfield(probeInfo, 'TableOpt') && ~p.Results.useEEG
    doTransform = false;
    fNIR_orig = p.Results.fNIR;
    if iscell(fNIR_orig) && ~isempty(fNIR_orig)
        fNIR_orig = fNIR_orig{1};
    end

    if ischar(transformOpt) && strcmpi(transformOpt, 'auto')
        % Auto: transform if coordinate system is not MNI and landmarks exist
        if isstruct(fNIR_orig) && isfield(fNIR_orig, 'device')
            dev = fNIR_orig.device;
            if isa(dev, 'pf2.Device')
                coordSys = dev.CoordinateSystem;
                hasLandmarks = ~isempty(dev.Landmarks);
            elseif isstruct(dev)
                coordSys = '';
                if isfield(dev, 'CoordinateSystem')
                    coordSys = dev.CoordinateSystem;
                end
                hasLandmarks = isfield(dev, 'Landmarks') && ~isempty(dev.Landmarks);
            else
                coordSys = '';
                hasLandmarks = false;
            end
            % Transform if not already in MNI and landmarks available
            if hasLandmarks && ~strcmpi(coordSys, 'MNI') && ~isempty(coordSys) && ~strcmpi(coordSys, 'Unknown')
                doTransform = true;
            end
        end
    elseif islogical(transformOpt) && transformOpt
        % Explicit true: always transform
        doTransform = true;
    end

    if doTransform
        % Get all coordinates to transform
        optCoords = [probeInfo.TableOpt.Pos3D_x, probeInfo.TableOpt.Pos3D_y, probeInfo.TableOpt.Pos3D_z];
        srcCoords = [probeInfo.TableSD.Pos3D_x(probeInfo.TableSD.Type == 'Src'), ...
                     probeInfo.TableSD.Pos3D_y(probeInfo.TableSD.Type == 'Src'), ...
                     probeInfo.TableSD.Pos3D_z(probeInfo.TableSD.Type == 'Src')];
        detCoords = [probeInfo.TableSD.Pos3D_x(probeInfo.TableSD.Type ~= 'Src'), ...
                     probeInfo.TableSD.Pos3D_y(probeInfo.TableSD.Type ~= 'Src'), ...
                     probeInfo.TableSD.Pos3D_z(probeInfo.TableSD.Type ~= 'Src')];

        try
            % Transform all coordinate sets using the same transformation
            [optMNI, T] = pf2.probe.transformToMNI(optCoords, fNIR_orig);
            srcMNI = T.s * (srcCoords * T.R) + T.t;
            detMNI = T.s * (detCoords * T.R) + T.t;

            % Update canonical TableOpt and sync the OptPos view from it.
            probeInfo.TableOpt.Pos3D_x = optMNI(:, 1);
            probeInfo.TableOpt.Pos3D_y = optMNI(:, 2);
            probeInfo.TableOpt.Pos3D_z = optMNI(:, 3);
            probeInfo = pf2_base.syncOptodeCoords(probeInfo);

            srcIdx = probeInfo.TableSD.Type == 'Src';
            probeInfo.TableSD.Pos3D_x(srcIdx) = srcMNI(:, 1);
            probeInfo.TableSD.Pos3D_y(srcIdx) = srcMNI(:, 2);
            probeInfo.TableSD.Pos3D_z(srcIdx) = srcMNI(:, 3);
            probeInfo.TableSD.Pos3D_x(~srcIdx) = detMNI(:, 1);
            probeInfo.TableSD.Pos3D_y(~srcIdx) = detMNI(:, 2);
            probeInfo.TableSD.Pos3D_z(~srcIdx) = detMNI(:, 3);

            % Update mean position
            probeInfo.OptPos3D_mean = mean(optMNI, 1, 'omitnan');

        catch ME
            if islogical(transformOpt) && transformOpt
                % Explicit request to transform but failed
                error('pf2:probe:plot:interpolateValues3D:transformFailed', ...
                    'Failed to transform coordinates to MNI: %s', ME.message);
            end
            % Auto mode: silently fall back to original coordinates
        end
    end
end

if(isfield(probeInfo, 'TableOpt'))
    if(~isfield(probeInfo,'NumShortSeparation'))
        probeInfo.NumShortSeparation =0;
    end
    if(include_ss&&probeInfo.NumOptodes>length(data2plot_concat)&&probeInfo.NumOptodes-probeInfo.NumShortSeparation==length(data2plot_concat))
        include_ss=false;
        warning('Not enough data for all channels, ignoring short separation channels');
    end
    
    includeChannels=probeInfo.TableOpt.HasData&(include_ss|~probeInfo.TableOpt.IsShortSeparation);
    
    channelList=probeInfo.TableOpt.OptodeNum(includeChannels);
    numOptodes=length(channelList);
    
    srcIdx=probeInfo.TableSD.Type=='Src';
    detIdx=~srcIdx;
    srcPos = [probeInfo.TableSD.Pos3D_x(srcIdx), probeInfo.TableSD.Pos3D_y(srcIdx), probeInfo.TableSD.Pos3D_z(srcIdx)];
    srcLabels = probeInfo.TableSD.Label(srcIdx);
    detLabels = probeInfo.TableSD.Label(detIdx);
    detPos = [probeInfo.TableSD.Pos3D_x(detIdx), probeInfo.TableSD.Pos3D_y(detIdx), probeInfo.TableSD.Pos3D_z(detIdx)];
    optPos = [probeInfo.TableOpt.Pos3D_x, probeInfo.TableOpt.Pos3D_y, probeInfo.TableOpt.Pos3D_z];
    
    if(p.Results.useTalairach)
        % icbm_fsl2tal is the MNI152->Talairach (Lancaster/Brett) transform; it
        % is only valid for true MNI152 input. The 'MNI' label alone is not
        % enough: an idealized-template montage with an unverified reference
        % head is not MNI152, so warn on that too (once per session).
        talFnir = p.Results.fNIR;
        if iscell(talFnir) && ~isempty(talFnir), talFnir = talFnir{1}; end
        talCoordSys = ''; refHead = ''; prov = '';
        if isstruct(talFnir) && isfield(talFnir, 'device') && isa(talFnir.device, 'pf2.Device')
            talCoordSys = talFnir.device.CoordinateSystem;
            refHead = talFnir.device.ReferenceHead;
            prov = talFnir.device.CoordinateProvenance;
        end
        notMNI = ~isempty(talCoordSys) && ~strcmpi(strtrim(char(talCoordSys)), 'MNI');
        unverifiedHead = isempty(refHead) || ~strcmpi(strtrim(char(refHead)), 'MNI152');
        isTemplate = ~isempty(prov) && contains(lower(char(prov)), 'template');
        if notMNI
            iWarnOnce('pf2:interpolateValues3D:talFromNonMNI', ...
                ['useTalairach applies the MNI152->Talairach transform, but ' ...
                 'coordinates declare CoordinateSystem=''%s''. Result is invalid ' ...
                 'unless coordinates are MNI152.'], char(talCoordSys));
        elseif unverifiedHead || isTemplate
            iWarnOnce('pf2:interpolateValues3D:talUnverifiedHead', ...
                ['useTalairach applies the MNI152->Talairach transform, but these ' ...
                 'coordinates are not verified MNI152 (ReferenceHead=''%s'', ' ...
                 'provenance=''%s''). Talairach output may be biased.'], ...
                char(refHead), char(prov));
        end
        optPos=pf2_base.external.icbm_fsl2tal(optPos);
        detPos=pf2_base.external.icbm_fsl2tal(detPos);
        srcPos=pf2_base.external.icbm_fsl2tal(srcPos);
    end
    
    probeInfo.TableOpt.OptPos=optPos;
    probeInfo.TableOpt.SrcPos=srcPos(probeInfo.TableOpt.SrcIdx, :);
    probeInfo.TableOpt.DetPos=detPos(probeInfo.TableOpt.DetIdx, :);
    probeInfo.TableOpt.sd=probeInfo.TableOpt.SrcPos-probeInfo.TableOpt.DetPos;
    probeInfo.TableOpt.sdDist=sqrt(sum(probeInfo.TableOpt.sd.^2,2));
    
    % formula for ellipse: C + a cos(theta) U + b sin(theta) V
    
    uProbe=unique(probeInfo.TableOpt.ProbeNum);
    
    probeInfo.TableOpt.b(:,1)=probeInfo.TableOpt.sdDist/2;
    probeInfo.TableOpt.a(:,1)=probeInfo.TableOpt.b*p.Results.scatteringFactor;
    probeInfo.TableOpt.U=probeInfo.TableOpt.sd./vecnorm(probeInfo.TableOpt.sd')';
    probeInfo.TableOpt.V=centerCamPos-probeInfo.TableOpt.OptPos;
    probeInfo.TableOpt.V=probeInfo.TableOpt.V./vecnorm(probeInfo.TableOpt.V')';
    probeInfo.TableOpt.VectorDir=probeInfo.TableOpt.OptPos+probeInfo.TableOpt.V.*probeInfo.TableOpt.sdDist/3;
    
    
end

if(p.Results.useEEG)
    if(~isempty(probeDraw))
        probeInfo = tempProbe;
    end
    numOptodes = probeInfo.NumOptodes;
    includeChannels = ~isnan(probeInfo.OptPos3DX);
end

if(~include_ss && isfield(probeInfo, 'TableOpt'))
    includeChannels=includeChannels&~probeInfo.TableOpt.IsShortSeparation;

    if(length(data2plot_concat)>sum(includeChannels))
        data2plot_concat=data2plot_concat(includeChannels);
    end
end

if(~all(dataEmpty) && length(data2plot_concat)~=numOptodes)
    error('pf2:probe:interpolateValues3D:optodeCountMismatch', 'Must have a value for all optodes');
end

%clf(gcf)


%h{1}= axes('Position',[0.05,0.05,0.9,0.9],'Box','on');


optPos=[probeInfo.OptPos.x(includeChannels),probeInfo.OptPos.y(includeChannels),probeInfo.OptPos.z(includeChannels)];

if(p.Results.useTalairach)
    optPos=pf2_base.external.icbm_fsl2tal(optPos);
end

OptPos3D_mean=mean(optPos, 1, 'omitnan');


if(isnan(bufferDistance))
    bufferDistance=median(probeInfo.TableOpt.SD(includeChannels))*10/sqrt(2);
end



% TAL EEG locations from Automated cortical projection of EEG sensors: Anatomical correlation via the international 10–10 system
h=ax;
if(useHighRes)
    cerebro_mdl=pf2_base.getAsset('cerebro_mdl', 'cache', h);    %high res model
else
    cerebro_mdl=pf2_base.getAsset('cerebro_mdl_05', 'cache', h); %low res model
end

%

if(isempty(itemsToSkipPlot))
    camproj('perspective');
    axis('image');
end

plotFNIRS_SD=showSD&&~contains('ProbeSrc',itemsToSkipPlot);
plot1020=show1020;
brainColor=p.Results.brainColor;
% Showcase uses a desaturated neutral-gray cortex (MRIcroGL convention) so
% activation overlays pop, unless the caller set brainColor explicitly.
if isfield(renderStyle,'grayCortex') && renderStyle.grayCortex && ...
        ismember('brainColor', p.UsingDefaults)
    brainColor = renderStyle.baseGray;
end
cMdl=cerebro_mdl;



TAL_RosCaud=[70,-110];
TAL_RL=[68, -65];
TAL_UD=[76, -50-13.5];

MNI_RosCaud=[75,-108];
MNI_RL=[73, -71];
MNI_UD=[83, -70-13.5];

x2tx=@(x) (x-min(x))/(max(x)-min(x))*(TAL_RL(1)-TAL_RL(2))+TAL_RL(2);%*49/1.73/brainResizeFactor;  %L/R scaling
y2ty=@(y) (y-min(y))/(max(y)-min(y))*(TAL_RosCaud(1)-TAL_RosCaud(2))+TAL_RosCaud(2);%(y-0.57)*143.5/4.35/brainResizeFactor; %rostral/caudal scaling
z2tz=@(z) (z-min(z))/(max(z)-min(z))*(TAL_UD(1)-TAL_UD(2))+TAL_UD(2);%(z-2.32)*79/2.4/brainResizeFactor;  %up down scaling

x2mx=@(x) (x-min(x))/(max(x)-min(x))*(MNI_RL(1)-MNI_RL(2))+MNI_RL(2);  %L/R scaling
y2my=@(y) (y-min(y))/(max(y)-min(y))*(MNI_RosCaud(1)-MNI_RosCaud(2))+MNI_RosCaud(2); %rostral/caudal scaling
z2mz=@(z) (z-min(z))/(max(z)-min(z))*(MNI_UD(1)-MNI_UD(2))+MNI_UD(2);  %up down scaling

rotx = @(t) [1 0 0; 0 cos(t) -sin(t) ; 0 sin(t) cos(t)] ;
roty = @(t) [cos(t) 0 sin(t) ; 0 1 0 ; -sin(t) 0  cos(t)] ;
rotz = @(t) [cos(t) -sin(t) 0 ; sin(t) cos(t) 0 ; 0 0 1] ;

reorderIdx=[3,1,2];
mdl.v=cMdl.v(:,reorderIdx);

if(p.Results.useTalairach)
    mdl.v=mdl.v*rotx(4/180*pi);
    mdl.v=[x2tx(mdl.v(:,1)),y2ty(mdl.v(:,2)),z2tz(mdl.v(:,3))];
else
    mdl.v=mdl.v*rotx(0/180*pi);
    mdl.v=[x2mx(mdl.v(:,1)),y2my(mdl.v(:,2)),z2mz(mdl.v(:,3))];
    
    
    
end

if(p.Results.showReference)
    fprintf('Min X: %.3f Max X %.3f\n',min(mdl.v(:,1)),max(mdl.v(:,1)));
    fprintf('Min Y: %.3f Max Y %.3f\n',min(mdl.v(:,2)),max(mdl.v(:,2)));
    fprintf('Min Z: %.3f Max Z %.3f\n',min(mdl.v(mdl.v(:,2)<-60,3)),max(mdl.v(:,3)));
end

mdl.f=cMdl.f.v(:,reorderIdx);
%mdl.f=[x2tx(mdl.f(:,1)),y2ty(mdl.f(:,2)),z2tz(mdl.f(:,3))];

% Smooth per-vertex normals and a curvature-based ambient-occlusion weight
% for the cortical surface. These drive Gouraud shading, matcap sampling and
% sulcal darkening. The mesh is static per axes, so cache the result keyed on
% vertex count + AO parameters and recompute only when those change.
surfaceNormals = [];
surfaceAO = [];
if ~p.Results.showVoxelBrain
    try
        [surfaceNormals, surfaceAO] = iLocalSurfaceShading(ax, mdl.v, mdl.f, renderStyle);
    catch shErr
        warning('pf2:probe:interpolateValues3D:shadingFailed', ...
            'Surface shading precompute failed (%s); falling back to flat colors.', shErr.message);
    end
end

%set(h,'linestyle','None');
%shading interp
%cameratoolbar

camIntensity=0.8;
camColor=[1,1,1]*camIntensity;

% Surface material coefficients come from the render preset so the cortex can
% be rendered conservatively ('publication') or with a richer matcap-driven
% look ('showcase'). See pf2_base.plot.RenderStyle.
ka=renderStyle.ka;
kd=renderStyle.kd;
ks=renderStyle.ks;

% Voxel brain lighting presets
switch lower(p.Results.voxelLighting)
    case 'realistic'
        voxKa = 0.7;   voxKd = 0.5;  voxKs = 0.25;  voxSE = 12;
    case 'dramatic'
        voxKa = 0.5;   voxKd = 0.65; voxKs = 0.4;   voxSE = 25;
    case 'clinical'
        voxKa = 0.65;  voxKd = 0.55; voxKs = 0.1;   voxSE = 8;
    otherwise % 'none'
        voxKa = ka;    voxKd = kd;   voxKs = ks;     voxSE = 10;
end
useVoxelLighting = ~strcmpi(p.Results.voxelLighting, 'none');

hold on;

lht=findobj(ax,'Type','Light','Tag','Front');
if(isempty(lht))
    lht=camlight('right');
    lht.Tag='Front';
    lht.Color=[1,1,1]*renderStyle.keyIntensity;   % key light
    lht.Position=[0,100,0];

    shading('interp');

    lighting(renderStyle.lighting);   % honor the style's lighting model (was flat by default)

    %camlight(lht,0, 180);
else
    lht.Color=[1,1,1]*renderStyle.keyIntensity;
end

if(islogical(p.Results.BrodmannAreas)&&p.Results.BrodmannAreas||isnumeric(p.Results.BrodmannAreas))
    showBrodmann=true;
    if(islogical(p.Results.BrodmannAreas))
        BA_areas=1:55;
    else
        BA_areas=p.Results.BrodmannAreas;
    end
else
    showBrodmann=false;
    BA_areas=[];
end



if(p.Results.showVoxelBrain&&(isempty(itemsToSkipPlot)||~contains(itemsToSkipPlot,'BrainVoxel')))
    h=ax;
    mni_t1=pf2_base.getAsset('mni_t1', 'cache', h);

    center=[91,127,73];

    voxelRes=1;

    % Check for cached isosurface mesh
    cacheKey = 'voxelISOmesh';
    cached = getappdata(ax, cacheKey);

    if ~isempty(cached)
        % Reuse cached mesh
        if isfield(cached, 'brodmann') && ~isempty(cached.brodmann)
            for ci = 1:length(cached.brodmann)
                cb = cached.brodmann(ci);
                h = patch('Faces', cb.faces, 'Vertices', cb.verts, ...
                    'FaceVertexCData', cb.colors, 'FaceColor', 'interp', ...
                    'EdgeColor', 'none');
                h.DisplayName = cb.displayName;
                h.Tag = 'BA_area_mrk';
                hold on
            end
            legend();
        end
        if isfield(cached, 'background') && ~isempty(cached.background)
            bg = cached.background;
            h = patch('Faces', bg.faces, 'Vertices', bg.verts, ...
                'FaceVertexCData', bg.colors, 'FaceColor', 'interp', ...
                'EdgeColor', 'none', ...
                'AmbientStrength', voxKa, 'DiffuseStrength', voxKd, ...
                'SpecularStrength', voxKs, 'SpecularExponent', voxSE, ...
                'FaceAlpha', 1);
            h.Tag = 'BrainVoxel';
            h.HandleVisibility = 'off';
            hold on
        end
        if isfield(cached, 'brain') && ~isempty(cached.brain)
            br = cached.brain;
            h = patch('Faces', br.faces, 'Vertices', br.verts, ...
                'FaceVertexCData', br.colors, 'FaceColor', 'interp', ...
                'EdgeColor', 'none', 'VertexNormals', br.normals, ...
                'AmbientStrength', voxKa, 'DiffuseStrength', voxKd, ...
                'SpecularStrength', voxKs, 'SpecularExponent', voxSE, ...
                'FaceAlpha', 1);
            h.Tag = 'BrainVoxel';
            h.HandleVisibility = 'off';
            hold on
        end
        if useVoxelLighting
            lighting('gouraud');
        else
            lighting('none');
        end
    else
        % Compute isosurface meshes from scratch
        isoCache = struct('brodmann', [], 'background', [], 'brain', []);

        if useVoxelLighting
            lighting('gouraud');
        else
            lighting('none');
        end

        if(p.Results.useVoxelBrodmannAreas)
            brdm=pf2_base.getAsset('brodmann', 'cache', ax);
            brdm=brdm(1:voxelRes:end,1:voxelRes:end,1:voxelRes:end);

            origMni = mni_t1; % preserve intensity before zeroing BA voxels

            if(showBrodmann)
                brainColmap=p.Results.BA_cmp(length(BA_areas));
                brodmannCache = [];

                for i=1:length(BA_areas)
                    mask = (brdm == BA_areas(i));
                    if ~any(mask(:)), continue; end

                    % Zero out these voxels from T1 so background doesn't overlap
                    mni_t1(mask) = 0;

                    % Pad to avoid edge artifacts, smooth for clean surface
                    maskPad = padarray(double(mask), [1 1 1], 0);
                    maskSmooth = smooth3(maskPad, 'gaussian', [3 3 3]);
                    [f, v] = isosurface(maskSmooth, 0.3);

                    if isempty(f), continue; end

                    v = v - 1; % undo padarray offset

                    % MNI transform: isosurface returns (col, row, slice)
                    v_mni = [v(:,2) - center(1), v(:,1) - center(2), v(:,3) - center(3)];

                    % Intensity-modulated color from original T1
                    vInt = interp3(double(origMni), v(:,1), v(:,2), v(:,3), 'linear', 0);
                    vColors = brainColmap(i,:) .* (vInt/255/3 + 0.66);

                    h = patch('Faces', f, 'Vertices', v_mni, ...
                        'FaceVertexCData', vColors, 'FaceColor', 'interp', ...
                        'EdgeColor', 'none');
                    h.DisplayName = sprintf('BA%i', BA_areas(i));
                    h.Tag = 'BA_area_mrk';
                    hold on

                    % Store for cache
                    entry = struct('faces', f, 'verts', v_mni, 'colors', vColors, ...
                        'displayName', sprintf('BA%i', BA_areas(i)));
                    if isempty(brodmannCache)
                        brodmannCache = entry;
                    else
                        brodmannCache(end+1) = entry; %#ok<AGROW>
                    end
                end
                legend();
                isoCache.brodmann = brodmannCache;
            end

            % Remaining Brodmann voxels (background)
            if useVoxelLighting
                lighting('gouraud');
            else
                lighting('none');
            end
            remainMask = brdm > 0 & ~ismember(brdm, BA_areas);
            mni_bg = double(mni_t1) .* double(remainMask);

            if any(mni_bg(:) > 0)
                mni_t1(remainMask) = 0;

                bgPad = padarray(mni_bg, [1 1 1], 0);
                bgSmooth = smooth3(bgPad, 'gaussian', [3 3 3]);
                [bgF, bgV] = isosurface(bgSmooth, 10);

                if ~isempty(bgF)
                    bgV = bgV - 1; % undo padarray offset
                    bgV_mni = [bgV(:,2) - center(1), bgV(:,1) - center(2), bgV(:,3) - center(3)];

                    % Sample at multiple depths inward, take max to avoid dark sulci
                    bgN = isonormals(bgSmooth, bgV + 1); % +1 to match padded coords
                    bgN_mag = max(sqrt(sum(bgN.^2, 2)), eps);
                    bgN_unit = bgN ./ bgN_mag;
                    origMni_dbl = double(origMni);
                    bgInt = zeros(size(bgV, 1), 1);
                    for sd = [3, 6, 10, 15]
                        bgSPts = bgV - sd * bgN_unit;
                        bgSPts = max(bgSPts, 1);
                        bgSPts(:,1) = min(bgSPts(:,1), size(origMni,2));
                        bgSPts(:,2) = min(bgSPts(:,2), size(origMni,1));
                        bgSPts(:,3) = min(bgSPts(:,3), size(origMni,3));
                        bgInt = max(bgInt, interp3(origMni_dbl, bgSPts(:,1), bgSPts(:,2), bgSPts(:,3), 'linear', 0));
                    end
                    bgInt = max(bgInt, 100); % brightness floor
                    bgColors = p.Results.voxelColor .* (bgInt / 255);

                    h = patch('Faces', bgF, 'Vertices', bgV_mni, ...
                        'FaceVertexCData', bgColors, 'FaceColor', 'interp', ...
                        'EdgeColor', 'none', ...
                        'AmbientStrength', voxKa, 'DiffuseStrength', voxKd, ...
                        'SpecularStrength', voxKs, 'SpecularExponent', voxSE, ...
                        'FaceAlpha', 1);
                    h.Tag = 'BrainVoxel';
                    h.HandleVisibility = 'off';
                    hold on

                    isoCache.background = struct('faces', bgF, 'verts', bgV_mni, 'colors', bgColors);
                end
            end
            legend();

        else
            % Non-Brodmann voxel brain path
            vol = smooth3(double(mni_t1), 'gaussian', [3 3 3]);
            isoVal = 20;
            [isoF, isoV] = isosurface(vol, isoVal);
            isoN = isonormals(vol, isoV);

            % MNI transform: isosurface returns (col, row, slice)
            isoV_mni = [isoV(:,2) - center(1), isoV(:,1) - center(2), isoV(:,3) - center(3)];

            % Per-vertex intensity coloring — sample at multiple depths inward
            % and take the max to avoid dark patches from sulci/ventricles.
            % isonormals returns outward-pointing normals (toward smaller values).
            isoN_mag = max(sqrt(sum(isoN.^2, 2)), eps);
            isoN_unit = isoN ./ isoN_mag;
            mni_dbl = double(mni_t1);
            sampleDepths = [3, 6, 10, 15]; % multiple depths in voxels
            vInt = zeros(size(isoV, 1), 1);
            for sd = sampleDepths
                sPts = isoV - sd * isoN_unit;
                sPts = max(sPts, 1);
                sPts(:,1) = min(sPts(:,1), size(mni_t1,2));
                sPts(:,2) = min(sPts(:,2), size(mni_t1,1));
                sPts(:,3) = min(sPts(:,3), size(mni_t1,3));
                vInt = max(vInt, interp3(mni_dbl, sPts(:,1), sPts(:,2), sPts(:,3), 'linear', 0));
            end
            vInt = max(vInt, 100); % brightness floor for any remaining dark vertices
            vColors = p.Results.voxelColor .* (vInt / 255);

            h = patch('Faces', isoF, 'Vertices', isoV_mni, ...
                'FaceVertexCData', vColors, 'FaceColor', 'interp', ...
                'EdgeColor', 'none', 'VertexNormals', -isoN, ...
                'AmbientStrength', voxKa, 'DiffuseStrength', voxKd, ...
                'SpecularStrength', voxKs, 'SpecularExponent', voxSE, ...
                'FaceAlpha', 1);
            h.Tag = 'BrainVoxel';
            h.HandleVisibility = 'off';
            if useVoxelLighting
                lighting('gouraud');
            else
                lighting('none');
            end
            hold on

            isoCache.brain = struct('faces', isoF, 'verts', isoV_mni, ...
                'colors', vColors, 'normals', -isoN);
        end

        % Store computed mesh in cache
        setappdata(ax, cacheKey, isoCache);
    end

    % Add camera lights when voxel lighting is active
    if useVoxelLighting
        lht = findobj(ax, 'Type', 'Light', 'Tag', 'Front');
        if isempty(lht)
            lht = camlight('right');
            lht.Tag = 'Front';
            lht.Color = camColor;
            lht.Position = [0, 100, 0];
        end
        lht2 = findobj(ax, 'Type', 'Light', 'Tag', 'Rear');
        if isempty(lht2)
            lht2 = camlight('left');
            lht2.Tag = 'Rear';
            lht2.Position = [0, -100, 90];
            lht2.Color = camColor;
        end
    end
end



if(~all(dataEmpty))
    C=data2plot_concat;
    
    num_vertices = size(mdl.v, 1);

    Cs = zeros(num_vertices, 3);

  if isempty(vertexData)
    if(p.Results.useProjectedOptodeLocations)
        controlPoints=probeInfo.TableOpt.VectorDir(includeChannels,:);
        max_distance_2 = bufferDistance^1.2;
    else
        controlPoints = optPos;
        max_distance_2 = bufferDistance^2/sqrt(2);
    end
    
    num_control = size(controlPoints, 1);
    
    %
    %     controlPoints=bigbd;
    %
    %     num_control = size(controlPoints, 1);
    %
    %     d=nan(num_vertices,1);
    %     ind=nan(num_vertices,1);
    %     for i=1:num_vertices
    %         q = repmat(mdl.v(i,:), num_control, 1);
    %         dist_array = sum((controlPoints - q).^2, 2);
    %         [d(i), ind(i)] = min(dist_array);
    %         if(rem(i,1000)==0)
    %             toc
    %             fprintf('%i\n',i);
    %             tic
    %         end
    %     end
    %     cerebro_mdl.b_dist=d;
    %     cerebro_mdl.b_area=bigbdidx(ind);
    
    useGeodesic = p.Results.UseGeodesic;

    % Build or retrieve squared-distance matrix [V x K]. Cache is keyed on
    % controlPoints + useGeodesic so moving or adding optodes invalidates it.
    cacheKey = 'iv3d_distCache';
    cache = [];
    if animationOptimized
        cache = getappdata(ax, cacheKey);
    end

    cacheValid = ~isempty(cache) ...
                 && isfield(cache, 'controlPoints') ...
                 && isequal(cache.controlPoints, controlPoints) ...
                 && isfield(cache, 'useGeodesic') ...
                 && isequal(cache.useGeodesic, useGeodesic);

    if cacheValid
        dist_array = cache.dist_array;
    else
        if useGeodesic
            dist_array = iLocalGeodesicDistSq(ax, mdl.v, mdl.f, controlPoints);
        else
            dist_array = sum(mdl.v.^2, 2) + sum(controlPoints.^2, 2)' ...
                         - 2 * (mdl.v * controlPoints');
        end
        if animationOptimized
            setappdata(ax, cacheKey, struct( ...
                'controlPoints', controlPoints, ...
                'useGeodesic', useGeodesic, ...
                'dist_array', dist_array));
        end
    end

    % Exclude NaN channels from interpolation (e.g. masked-out channels)
    nanChannels = isnan(C);
    if any(nanChannels)
        dist_array(:, nanChannels) = Inf;
        C(nanChannels) = 0;
    end

    % Per-channel alpha (default fully opaque; NaN channels → 0). The user
    % may pass alpha in the same shape as their data2plot (pre-subset) or
    % already subset to numel(C); both are accepted.
    chanAlpha = p.Results.ChannelAlpha;
    if isempty(chanAlpha)
        chanAlpha = ones(size(C));
    else
        chanAlpha = chanAlpha(:);
        if numel(chanAlpha) == numel(C)
            % already subset — use as-is
        elseif numel(chanAlpha) == numel(includeChannels) && any(includeChannels)
            chanAlpha = chanAlpha(includeChannels);
        else
            error('pf2:interpolateValues3D:channelAlphaSize', ...
                'ChannelAlpha must have one entry per channel (got %d, expected %d or %d).', ...
                numel(chanAlpha), numel(C), numel(includeChannels));
        end
    end
    if any(nanChannels)
        chanAlpha(nanChannels) = 0;
    end
    alphaMode = lower(string(p.Results.AlphaMode));
    transparentMode = alphaMode == "transparent";
  else
    % Pre-computed per-vertex field path: no channel interpolation. Render as
    % a transparent overlay so masked-out (NaN) cortex shows the gray base.
    chanAlpha = [];
    transparentMode = true;
  end

    if(isnumeric(cmap_high))
        nColorsMaxBar=size(cmap_high,1);
    else
        nColorsMaxBar=1024;
    end
    cbarUpperRange=max(cbarUpper_minmax)-min(cbarUpper_minmax);

    mapWithAlpha = @(cmap, isUpper) [cmap, [linspace( 1* ~isUpper, 1*isUpper, size(cmap(1:floor(end/3),:), 1)).^(0.5)'; ones(size(cmap(floor(end*1/3)+1:end,1)))]];
   
    
    if twosided
        cbarLowerRange = max(cbarLower_minmax) - min(cbarLower_minmax);
        cbarRangeFull = max(cbarUpper_minmax) - min(cbarLower_minmax);
        cbarOverlappingRange = max(cbarLower_minmax) - min(cbarUpper_minmax);
        cbarIsOverlapping = cbarOverlappingRange > 0;
        
        fracUpper = cbarUpperRange / cbarRangeFull;
        fracLower = cbarLowerRange / cbarRangeFull;
        fracOverlap = cbarOverlappingRange / cbarRangeFull;
        
        nColorLower = floor(fracLower * nColorsMaxBar) + 1;
        nColorUpper = floor(fracUpper * nColorsMaxBar) + 1;
        nOverlap = floor(fracOverlap * nColorsMaxBar) + 1;
   
        if cbarIsOverlapping
            cmap = [mapWithAlpha(cmap_low(nColorLower),false); repmat([brainColor,1], nOverlap, 1); mapWithAlpha(cmap_high(nColorUpper),true)];
        else
            cmap = [mapWithAlpha(cmap_low(nColorLower),false); mapWithAlpha(cmap_high(nColorUpper),true)];
        end
        
        % Normalize C to the range [0, 1] based on the full range
        c_ind = (C(:) - min(cbarLower_minmax)) / cbarRangeFull;
        
        % Create a mask for values that should not be colorized
        mask = (C(:) > max(cbarLower_minmax)) & (C(:) < min(cbarUpper_minmax));
    else
        if ~negColorbar
            if(isnumeric(cmap_high))
                cmap = cmap_high;
            else
                cmap = cmap_high(nColorsMaxBar);
            end
            
        else
            if(isnumeric(cmap_low))
                cmap = flip(cmap_low);
            else
                cmap = flip(cmap_low(nColorsMaxBar));
            end
           
        end

        cmap = mapWithAlpha(cmap,~negColorbar);
        
        c_ind = (C(:) - min(cbarUpper_minmax)) / (max(cbarUpper_minmax) - min(cbarUpper_minmax));
        mask = false(size(C));
    end

    % Blend colormap alpha with brainColor so downstream RGB has no alpha
    cmap = cmap .* cmap(:, 4) + repmat([brainColor(1:3),1], size(cmap, 1), 1) .* (1 - cmap(:, 4));
    cmapRGB = cmap(:, 1:3);

    if ~isempty(vertexData)
        % Direct per-vertex colouring (DOT reconstruction / coverage / PMDF).
        if numel(vertexData) ~= size(mdl.v, 1)
            error('pf2:interpolateValues3D:vertexDataSize', ...
                ['VertexData has %d entries but the mesh has %d vertices. ' ...
                 'Match the mesh resolution (high-res by default).'], ...
                numel(vertexData), size(mdl.v, 1));
        end
        cbRange = max(cbarUpper_minmax) - min(cbarUpper_minmax);
        if cbRange <= 0, cbRange = 1; end
        vci = (vertexData - min(cbarUpper_minmax)) / cbRange;
        nanV = isnan(vci);
        vci = min(max(vci, 0), 1);
        idx = round(vci * (size(cmapRGB, 1) - 1)) + 1;
        idx = min(max(idx, 1), size(cmapRGB, 1));
        Cs_proj = cmapRGB(idx, :);
        if isempty(vertexAlphaIn)
            fadeAlpha_v = ones(size(mdl.v, 1), 1);
        else
            fadeAlpha_v = min(max(vertexAlphaIn, 0), 1);
        end
        fadeAlpha_v(nanV) = 0;          % NaN vertices -> transparent (masked)
        Cs = Cs_proj;
        vertexAlpha = fadeAlpha_v;
    else
        % Channel path: spread channel values onto vertices via the projection
        % kernel (Gaussian/sensitivity/nearest).
        [Cs_proj, fadeAlpha_v] = pf2_base.plot.interpolateChannelColors( ...
            dist_array, c_ind(:), cmapRGB, ...
            'MaxDistance2', max_distance_2, ...
            'ProjectMode', projectmode, ...
            'ChanMask', mask(:));

        if transparentMode
            % Two-sided dead-zone channels (mask == true) should be transparent
            % rather than brainColor — the gap between the two colorbars then
            % appears as see-through rather than as a flat brain-colored band.
            chanAlphaCombined = chanAlpha;
            if any(mask)
                chanAlphaCombined(mask(:)) = 0;
            end
            % Interpolate per-channel alpha onto vertices with the same kernel,
            % then combine with the distance-based fade. Caller binds vertexAlpha
            % to the brain patch as FaceVertexAlphaData.
            chanAlphaInterp = iLocalInterpScalar(dist_array, chanAlphaCombined, max_distance_2, projectmode);
            vertexAlpha = fadeAlpha_v .* chanAlphaInterp;
            Cs = Cs_proj;
        else
            % Legacy blend path — non-contributing vertices mix with brainColor.
            Cs = Cs_proj .* fadeAlpha_v + brainColor .* (1 - fadeAlpha_v);
            vertexAlpha = [];
        end
    end

else % No data to plot, everything is brain and anatomy
    Cs = repmat(brainColor, size(mdl.v, 1), 1);
    vertexAlpha = [];
    transparentMode = false;

    if(showBrodmann&&~p.Results.showVoxelBrain)
        
        
        brainColmap=[brainColor;p.Results.BA_cmp(length(BA_areas));];
        
        
        
        if(p.Results.useVoxelBrodmannAreas)

            h=ax;
            brdm=pf2_base.getAsset('brodmann', 'cache', h);

            center=[90,126,72];
            szB=size(brdm);
            
            brodmannRes=1;
            
            brainColmap=p.Results.BA_cmp(length(BA_areas));
            
            
            for i=1:length(BA_areas)
                bdI=find(brdm==BA_areas(i));
                [bdx,bdz,bdy] = ind2sub(size(brdm),bdI);
                bdx=(szB(1)-center(1)-bdx);
                bdz=szB(2)-center(2)-bdz;
                bdy=bdy-center(3);
                bdxyz=unique(round([bdx,bdz,bdy]/brodmannRes)*brodmannRes,'rows');
                hold on
                %h=scatter3(bdxyz(:,1),bdxyz(:,2),bdxyz(:,3),50*brodmannRes,'square','MarkerFaceColor',brainColmap(i,:),'MarkerEdgeColor','none');
                % h.DisplayName=sprintf('BA%i',BA_areas(i));
                % h.Tag='BA_area_mrk';
                
            end
            
            % legend(legendStr);
            
            
        else
            
            cerebro_mdl.b_area(~ismember(cerebro_mdl.b_area,BA_areas))=0;
            cerebro_mdl.b_area(cerebro_mdl.b_dist>150)=0;
            
            brainstembox=[-15,15;-40,15;-80,5];
            
            inBox=@(xyz,xminmax,yminmax,zminmax) xyz(:,1)>min(xminmax)&xyz(:,1)<max(xminmax)& ...
                xyz(:,2)>min(yminmax)&xyz(:,2)<max(yminmax)& ...
                xyz(:,3)>min(zminmax)&xyz(:,3)<max(zminmax);
            
            cerebro_mdl.b_area(inBox(mdl.v,brainstembox(1,:),brainstembox(2,:),brainstembox(3,:)))=0;
            
            cerstembox=[-55,55;-120,-40;-80,-25];
            
            cerebro_mdl.b_area(inBox(mdl.v,cerstembox(1,:),cerstembox(2,:),cerstembox(3,:)))=0;
            
            [a,b,c]=unique(cerebro_mdl.b_area);
            
            cerebro_mdl.Cs=brainColmap(c,:);
            Cs=cerebro_mdl.Cs;
            
            
            for i=2:length(a)
                h=scatter3(0,0,0,0.1,'square','MarkerFaceColor',brainColmap(i,:));
                h.Tag='BA_area_mrk';
                h.DisplayName=sprintf('BA%i',a(i));
                hold on
            end
            
        end
        
        legend();
    end
end

% ---- Optode parcellation variant -------------------------------------
% Hard-assign each in-coverage cortical vertex to its nearest optode and
% render the result as discrete flat-filled cells (a Voronoi-style parcel
% map) with outlined boundaries, rather than a smoothly interpolated field.
% Cells are filled by channel value (when data2plot is supplied) or a
% neutral fill, with an optional highlighted subset (the "purple" cells).
% Boundary outlines are stashed in parcelEdgesToDraw and drawn after the
% brain patch. Surface render only (not the voxel brain).
parcelEdgesToDraw = [];
% Parcellation is a channel-space render; the precomputed per-vertex field
% (VertexData, e.g. a DOT reconstruction) is a different representation and
% the two cannot be combined. Warn and skip rather than silently clobber it.
if p.Results.Parcellate && ~isempty(vertexData)
    warning('pf2:interpolateValues3D:parcellateVertexData', ...
        'Parcellate is ignored when VertexData is supplied (they are different render modes).');
end
doParcellate = p.Results.Parcellate && ~p.Results.showVoxelBrain && isempty(vertexData);
if doParcellate && isfield(probeInfo, 'TableOpt')
    % Control points (parcel centers) and the OptodeNum label for each, so
    % HighlightChannels can be resolved against the printed numbers. With
    % data, reuse the data-path controlPoints so cell colors align with
    % data2plot; without data, take the full optode set (respecting short-
    % separation inclusion) since the data-path optode list is empty then.
    if ~all(dataEmpty) && exist('controlPoints','var') && ~isempty(controlPoints)
        parcelControl = controlPoints;
        parcelOptodeNum = probeInfo.TableOpt.OptodeNum(includeChannels);
    else
        parcelControl = [probeInfo.TableOpt.Pos3D_x, probeInfo.TableOpt.Pos3D_y, probeInfo.TableOpt.Pos3D_z];
        parcelOptodeNum = probeInfo.TableOpt.OptodeNum;
        if ~include_ss
            keepOpt = ~probeInfo.TableOpt.IsShortSeparation;
            parcelControl = parcelControl(keepOpt, :);
            parcelOptodeNum = parcelOptodeNum(keepOpt);
        end
        if p.Results.useTalairach
            parcelControl = pf2_base.external.icbm_fsl2tal(parcelControl);
        end
    end
    parcelOptodeNum = parcelOptodeNum(:)';
    nParcel = size(parcelControl, 1);
end
if doParcellate && exist('nParcel','var') && nParcel >= 1
    % Coverage radius: the data-path value when available, otherwise derived
    % from the source-detector distances (bufferDistance is NaN with no data).
    if exist('max_distance_2','var') && ~isempty(max_distance_2) && ~isnan(max_distance_2)
        parcelMaxDist2 = max_distance_2;
    else
        bd = bufferDistance;
        if isempty(bd) || isnan(bd)
            sdcol = probeInfo.TableOpt.SD;
            bd = median(sdcol(~isnan(sdcol))) * 10 / sqrt(2);
        end
        parcelMaxDist2 = bd^2 / sqrt(2);
    end

    [parcelIdx, inCoverage, parcelEdgesToDraw] = iLocalParcellate( ...
        ax, mdl.v, mdl.f, parcelControl, parcelMaxDist2, ...
        p.Results.UseGeodesic, animationOptimized, surfaceNormals);

    % Per-parcel fill: discrete data value (when data supplied) else flat.
    parcelFill = repmat(p.Results.ParcelColor(:)', nParcel, 1);
    if ~all(dataEmpty) && exist('c_ind','var') && exist('cmapRGB','var')
        ci = min(max(c_ind(:), 0), 1);
        cidx = round(ci * (size(cmapRGB,1) - 1)) + 1;
        cidx = min(max(cidx, 1), size(cmapRGB,1));
        if numel(cidx) == nParcel
            parcelFill = cmapRGB(cidx, :);
            % Suppress channels the smooth path would hide: NaN/masked-out
            % channels and two-sided dead-zone channels (between the two
            % colorbars). Paint these cells the neutral ParcelColor rather
            % than the spurious value-0 color so the parcel map agrees with
            % the smooth render.
            dead = false(nParcel, 1);
            if exist('mask','var') && numel(mask) == nParcel
                dead = dead | mask(:);
            end
            if numel(data2plot_concat) == nParcel
                dead = dead | isnan(data2plot_concat(:));
            end
            if any(dead)
                parcelFill(dead, :) = repmat(p.Results.ParcelColor(:)', nnz(dead), 1);
            end
        end
    end

    % Highlighted subset. A numeric list matches the PRINTED optode numbers
    % (OptodeNum); a logical mask selects by position in the plotted-channel
    % order. This keeps highlighting intuitive on montages whose optode
    % numbers are not a simple 1..N sequence.
    hl = p.Results.HighlightChannels;
    if ~isempty(hl)
        if islogical(hl)
            hlMask = false(1, nParcel);
            n = min(numel(hl), nParcel);
            hlMask(1:n) = hl(1:n);
            hlIdx = find(hlMask);
        else
            [tf, loc] = ismember(round(hl(:)'), parcelOptodeNum);
            hlIdx = loc(tf);
            if any(~tf)
                missing = round(hl(~tf));
                warning('pf2:interpolateValues3D:highlightNotFound', ...
                    'HighlightChannels values not in the plotted optode numbers: %s', ...
                    mat2str(missing(:)'));
            end
        end
        hlIdx = hlIdx(hlIdx >= 1 & hlIdx <= nParcel);
        if ~isempty(hlIdx)
            parcelFill(hlIdx, :) = repmat(p.Results.HighlightColor(:)', numel(hlIdx), 1);
        end
    end

    % Paint vertices: in-coverage -> its parcel color; else brainColor with
    % zero alpha so out-of-coverage cortex shows the gray base through.
    Cs = repmat(brainColor, size(mdl.v,1), 1);
    covIdx = find(inCoverage);
    Cs(covIdx, :) = parcelFill(parcelIdx(covIdx), :);
    vertexAlpha = double(inCoverage);
    transparentMode = true;
end

if(~p.Results.showVoxelBrain)
    brainHndl  = findobj(ax,'Type','Patch','Tag','Brain');
    overlayHndl = findobj(ax,'Type','Patch','Tag','BrainOverlay');

    useLineColor = ~isempty(p.Results.brainLineColor) && all(~isnan(p.Results.brainLineColor));
    if useLineColor
        edgeProps = {'EdgeColor', p.Results.brainLineColor, 'LineStyle', '-'};
    else
        edgeProps = {'LineStyle', 'None'};
    end

    % In transparent mode the base Brain patch stays solid (brainColor) and
    % a second BrainOverlay patch holds the stat colors with per-vertex
    % alpha so the anatomy remains visible under non-significant regions.
    if transparentMode && ~isempty(vertexAlpha)
        baseCs = repmat(brainColor, size(mdl.v, 1), 1);
    else
        baseCs = Cs;
    end

    % Shading props from the render preset: smooth normals + Gouraud lighting
    % (or 'none' when a matcap will be baked post-camera) and a specular
    % exponent. Bake the sulcal ambient-occlusion weight into the BASE patch
    % colours only, leaving the stat overlay hue pure.
    if renderStyle.useMatcap
        faceLighting = 'none';
    else
        faceLighting = renderStyle.lighting;
    end
    if ~isempty(surfaceNormals) && size(surfaceNormals,1) == size(mdl.v,1)
        vnProps = {'VertexNormals', surfaceNormals};
    else
        vnProps = {};
    end
    shadeProps = [{'FaceLighting', faceLighting, 'SpecularExponent', renderStyle.specExp}, vnProps];

    if ~isempty(surfaceAO) && numel(surfaceAO) == size(mdl.v,1)
        baseCs = baseCs .* surfaceAO(:);
        baseCs = min(max(baseCs, 0), 1);
    end

    baseProps = {'vertices', mdl.v, 'faces', mdl.f, ...
                 'FaceVertexCData', baseCs, 'FaceColor','interp', ...
                 'AmbientStrength', ka, 'DiffuseStrength', kd, 'SpecularStrength', ks, ...
                 'FaceAlpha', p.Results.brainAlpha, shadeProps{:}};

    if(isempty(brainHndl))
        brainHndl=ax;
        cameratoolbar
        hold off
        brainHndl = patch(brainHndl, baseProps{:}, edgeProps{:});

        brainHndl.Tag='Brain';
        brainHndl.DisplayName='Brain';
        brainHndl.HandleVisibility='off';
        hold on;
    else
        set(brainHndl, baseProps{:}, edgeProps{:}, 'FaceVertexAlphaData', []);
    end

    % Manage stat overlay patch
    if transparentMode && ~isempty(vertexAlpha)
        overlayProps = {'vertices', mdl.v, 'faces', mdl.f, ...
                        'FaceVertexCData', Cs, 'FaceColor','interp', ...
                        'AmbientStrength', ka, 'DiffuseStrength', kd, 'SpecularStrength', ks, ...
                        'FaceVertexAlphaData', vertexAlpha, 'FaceAlpha', 'interp', ...
                        'AlphaDataMapping', 'none', 'LineStyle', 'None', shadeProps{:}};
        hold on
        if isempty(overlayHndl)
            overlayHndl = patch(ax, overlayProps{:});
            overlayHndl.Tag = 'BrainOverlay';
            overlayHndl.DisplayName = 'BrainOverlay';
            overlayHndl.HandleVisibility = 'off';
        else
            set(overlayHndl, overlayProps{:});
        end
    elseif ~isempty(overlayHndl)
        delete(overlayHndl);
    end

    % Draw the parcellation cell-boundary outlines on top of the cortex.
    if ~isempty(parcelEdgesToDraw)
        hold on
        hEdge = plot3(ax, parcelEdgesToDraw(:,1), parcelEdgesToDraw(:,2), parcelEdgesToDraw(:,3), ...
            '-', 'Color', p.Results.ParcelOutlineColor, 'LineWidth', p.Results.ParcelOutlineWidth);
        hEdge.Tag = 'ParcelEdges';
        hEdge.HandleVisibility = 'off';
    end

end

% Project channel data onto voxel brain isosurface when both are active.
% Voxel path uses Euclidean distance regardless of UseGeodesic — building a
% geodesic graph on the voxel isosurface would be prohibitively expensive
% and the voxel render is primarily anatomical context.
if p.Results.showVoxelBrain && ~isempty(vertexData)
    % The voxel-overlay path projects CHANNEL data through controlPoints/
    % max_distance_2, which the VertexData path never computes. They are
    % mutually exclusive; warn and skip the voxel overlay.
    warning('pf2:interpolateValues3D:voxelVertexData', ...
        'showVoxelBrain is ignored when VertexData is supplied.');
end
if p.Results.showVoxelBrain && isempty(vertexData) && ~all(dataEmpty)
    voxelPatches = findall(ax, 'Type', 'Patch', 'Tag', 'BrainVoxel');
    existingOverlays = findall(ax, 'Type', 'Patch', 'Tag', 'BrainVoxelOverlay');
    if ~isempty(existingOverlays) && ~transparentMode
        delete(existingOverlays);
        existingOverlays = [];
    end
    for vi = 1:length(voxelPatches)
        vp = voxelPatches(vi);
        vpVerts = get(vp, 'Vertices');
        vpFaces = get(vp, 'Faces');
        vpBaseColors = get(vp, 'FaceVertexCData');

        vp_dist = sum(vpVerts.^2, 2) + sum(controlPoints.^2, 2)' ...
                  - 2 * (vpVerts * controlPoints');
        if exist('nanChannels', 'var') && any(nanChannels)
            vp_dist(:, nanChannels) = Inf;
        end

        [vp_proj, vp_fade] = pf2_base.plot.interpolateChannelColors( ...
            vp_dist, c_ind(:), cmapRGB, ...
            'MaxDistance2', max_distance_2, ...
            'ProjectMode', projectmode, ...
            'ChanMask', mask(:));

        if transparentMode
            % Leave the anatomical voxel patch untouched and draw an overlay.
            % Dead-zone channels contribute zero alpha so the two-sided gap
            % appears transparent rather than filled.
            vpChanAlphaIn = chanAlpha;
            if any(mask)
                vpChanAlphaIn(mask(:)) = 0;
            end
            vpChanAlpha = iLocalInterpScalar(vp_dist, vpChanAlphaIn, max_distance_2, projectmode);
            vpVertexAlpha = vp_fade .* vpChanAlpha;
            set(vp, 'FaceVertexCData', vpBaseColors, 'FaceVertexAlphaData', []);

            hold on
            overlay = patch(ax, 'Vertices', vpVerts, 'Faces', vpFaces, ...
                'FaceVertexCData', vp_proj, 'FaceColor', 'interp', ...
                'FaceVertexAlphaData', vpVertexAlpha, 'FaceAlpha', 'interp', ...
                'AlphaDataMapping', 'none', 'EdgeColor', 'none');
            overlay.Tag = 'BrainVoxelOverlay';
            overlay.HandleVisibility = 'off';
        else
            vpCs = vp_proj .* vp_fade + vpBaseColors .* (1 - vp_fade);
            set(vp, 'FaceVertexCData', vpCs, 'FaceVertexAlphaData', []);
        end
    end
end

if(multiprobe)
    probe_colors=lines(num_devices);
end

mrkScaleFactor=22;

% Nudge scatter markers slightly inward so text always wins depth test.
% 0.5mm is imperceptible but resolves z-fighting between co-located objects.
markerInsetMM = 0.001;
insetPos = @(pos) pos - markerInsetMM * pos ./ max(vecnorm(pos, 2, 2), 1e-6);

if(showChannels&&isfield(probeInfo, 'TableOpt')&&~contains('ProbeOpt',itemsToSkipPlot))
    optPos = [probeInfo.TableOpt.Pos3D_x probeInfo.TableOpt.Pos3D_y probeInfo.TableOpt.Pos3D_z];

    if(~include_ss)
        optPos=optPos(~probeInfo.TableOpt.IsShortSeparation,:);
    end

    if(p.Results.useTalairach)
        optPos=pf2_base.external.icbm_fsl2tal(optPos);
    end

    % For the parcel map, pull the channel numbers (and their marker circles)
    % onto the cortical surface: snap each optode to the nearest mesh vertex
    % and lift it just above the outline so the number sits on its cell rather
    % than floating at scalp depth.
    if p.Results.Parcellate && exist('mdl','var') && isfield(mdl,'v') && ~isempty(mdl.v)
        snapped = optPos;
        for oi = 1:size(optPos,1)
            dd = sum((mdl.v - optPos(oi,:)).^2, 2);
            [~, nv] = min(dd);
            snapped(oi,:) = mdl.v(nv,:);
        end
        cc = mean(mdl.v, 1);
        d = snapped - cc;
        d = d ./ max(vecnorm(d, 2, 2), 1e-6);
        optPos = snapped + 2.6 * d;   % above the 1.8mm outline lift
    end

    optPosInset = insetPos(optPos);

    if(~isempty(optColor) && (isnumeric(optColor) && ~any(isnan(optColor(:))) || (isstring(optColor) && ~any(ismissing(optColor)))))
        if(multiprobe)
            uDevices=unique(probeInfo.TableOpt.ProbeNum);

            probe_string=cell(0);
            for i=1:num_devices

                selOpt=probeInfo.TableOpt.ProbeNum(:,1)==uDevices(i);
                if(~include_ss)
                    selOpt(probeInfo.TableOpt.IsShortSeparation)=[];
                end
                h(i) = scatter3(optPosInset(selOpt,1), optPosInset(selOpt,2), optPosInset(selOpt,3),20*p.Results.labelfontsize*p.Results.MarkerScale,'filled',optColor,'MarkerEdgeColor' ,probe_colors(i,:),'LineWidth',1.5);

                probe_string{i}=sprintf('Probe %i',uDevices(i));

                h(i).Tag='ProbeOpt';
                h(i).DisplayName=probe_string{i};
            end
            legend(h,probe_string);
        else
            h = scatter3(optPosInset(:,1), optPosInset(:,2), optPosInset(:,3),20*p.Results.labelfontsize*p.Results.MarkerScale,'filled',optColor,'MarkerEdgeColor' ,'k');
            h.Tag='ProbeOpt';
            h.DisplayName='Optode';
        end
    end

    if(include_ss)
        h=text(optPos(:,1), optPos(:,2), optPos(:,3), string(probeInfo.TableOpt.OptodeNum), 'HorizontalAlignment', 'center','VerticalAlignment', 'middle', "FontSize", p.Results.labelfontsize, 'color', labelFontColor);
    else
        h=text(optPos(:,1), optPos(:,2), optPos(:,3), string(probeInfo.TableOpt.OptodeNum(~probeInfo.TableOpt.IsShortSeparation)), 'HorizontalAlignment', 'center','VerticalAlignment', 'middle', "FontSize", p.Results.labelfontsize, 'color', labelFontColor);
    end
    for i=1:length(h)
        h(i).Tag='OptLabel';
    end
end

if(plotFNIRS_SD&&isfield(probeInfo,'TableSD'))
    %srcIdx=probeInfo.TableSD.Type=='Src';
    %detIdx=~srcIdx;
    
    
    %srcPos = [probeInfo.TableSD.Pos3D_x(srcIdx), probeInfo.TableSD.Pos3D_y(srcIdx), probeInfo.TableSD.Pos3D_z(srcIdx)];
    
    %if(p.Results.useTalairach)
    %    srcPos=pf2_base.external.icbm_fsl2tal(srcPos);
    %end
    
    srcPosInset = insetPos(srcPos);
    if(~isempty(srcColor) && (isnumeric(srcColor) && ~any(isnan(srcColor)) || ~ismissing(srcColor)))
        h = scatter3(srcPosInset(:,1),srcPosInset(:,2),srcPosInset(:,3),mrkScaleFactor*p.Results.labelfontsize*p.Results.MarkerScale,'filled',srcColor);
        h.Tag=sprintf('ProbeSrc');
        h.DisplayName='Source';
    end
    h=text(srcPos(:,1), srcPos(:,2), srcPos(:,3), srcLabels, 'HorizontalAlignment', 'center','VerticalAlignment', 'middle', "FontSize", p.Results.labelfontsize, 'color', labelFontColor);
    for i=1:length(h)
        h(i).Tag='ProbeSrcLabel';
    end
    hold on

    detPosInset = insetPos(detPos);
    if(~isempty(detColor) && (isnumeric(detColor) && ~any(isnan(detColor)) || ~ismissing(detColor)))
        h = scatter3(detPosInset(:,1), detPosInset(:,2), detPosInset(:,3), mrkScaleFactor*p.Results.labelfontsize*p.Results.MarkerScale, 'filled', detColor);
        h.Tag=sprintf('ProbeDet');
        h.DisplayName='Detector';
    end
    h=text(detPos(:,1), detPos(:,2), detPos(:,3), detLabels, 'HorizontalAlignment', 'center','VerticalAlignment', 'middle', "FontSize", p.Results.labelfontsize, 'color', labelFontColor);
    for i=1:length(h)
        h(i).Tag='ProbeDetLabel';
    end
end

if(plot1020&&~contains('Scatter1020',itemsToSkipPlot))
    
    for i=1:size(c1020,1)
        %text(cerebro1020(i,1),cerebro1020(i,2),cerebro1020(i,3),cerebro1020_labels{i})
        if(~isnan(c1020.BA(i)))
            ePos = [c1020.x(i), c1020.y(i), c1020.z(i)];
            ePosInset = insetPos(ePos);
            if(numColors == 4 || numColors == 1)
                h = scatter3(ePosInset(1),ePosInset(2),ePosInset(3),mrkScaleFactor*1.5*p.Results.labelfontsize*p.Results.MarkerScale, 'filled', color1020);

            else
                h = scatter3(ePosInset(1),ePosInset(2),ePosInset(3),mrkScaleFactor*1.5*p.Results.labelfontsize*p.Results.MarkerScale, 'filled');
            end
            h.Tag=sprintf('Scatter1020');
            hold on

            h=text(ePos(1),ePos(2),ePos(3),c1020.Electrode(i),'HorizontalAlignment', 'center','VerticalAlignment', 'middle', "FontSize", p.Results.labelfontsize, 'color', labelFontColor);
            for k=1:length(h)
                h(k).Tag='Label1020';
            end
            %text(x2tx(c1020.x(i)),y2ty(c1020.y(i)),z2tz(c1020.z(i)),c1020.Electrode(i),'HorizontalAlignment','center')
            
        end
    end
end

if(isempty(itemsToSkipPlot))
    
    xlabel('x (R/L)');
    ylabel('y (R/C)');
    zlabel('z (U/D)');
    
    
    camPosUp=p.Results.camUp;
    camup(camPosUp);
    
    camPosTarget=p.Results.camTarget;
    camtarget(camPosTarget);
    
    
    if(isnumeric(p.Results.initCamPosition))
        campos(p.Results.initCamPosition);
    else
        switch(p.Results.initCamPosition)
            case 'auto'
                % Frame from the data's side, lifted and rotated into an
                % elevated 3/4 view so the montage never sits dead-on (which
                % foreshortens it and collides with the colorbar). The hero
                % preset (showcase) lifts/rotates more dramatically; the
                % conservative preset (publication) uses a gentler 3/4.
                if renderStyle.heroView
                    liftZ = 0.40; azDeg = 25; dist = 1550;
                    fallbackPos = [-500, 1150, 650];
                else
                    liftZ = 0.28; azDeg = 18; dist = 1500;
                    fallbackPos = [-350, 1150, 520];
                end
                autoPos = mean(optPos, 1, 'omitnan');
                if any(isnan(autoPos)) || norm(autoPos) == 0
                    campos(fallbackPos);
                else
                    base = autoPos / norm(autoPos);
                    base = base + liftZ * [0 0 1];
                    th = azDeg*pi/180; c = cos(th); s = sin(th);
                    base = ([c -s 0; s c 0; 0 0 1] * base(:))';
                    campos(base / norm(base) * dist);
                end
            case 'front'
                campos([0,1200,0]);
            case 'back'
                campos([0,-1200,0]);
            case 'top'
                campos([0,0,1500]);
            case 'bottom'
                campos([0,0,-1500]);
            case 'left'
                campos([-1200,0,0]);
            case 'right'
                campos([1200,0,0]);
            case 'face'
                campos([0,1200,-300]);
            case 'top-left'
                campos([-900,0,1100]);
            case 'top-right'
                campos([900,0,1100]);
            case 'top-front'
                campos([0,900,1100]);
            case 'top-back'
                campos([0,-900,1100]);
            case 'front-left'
                campos([-850,850,0]);
            case 'front-right'
                campos([850,850,0]);
            case 'back-left'
                campos([-850,-850,0]);
            case 'back-right'
                campos([850,-850,0]);
            otherwise
                warning('Invalid camera position');
                campos(OptPos3D_mean/norm(OptPos3D_mean)*1500);  %Front facing
        end
    end
    
    
    
    
    
    
    
    % Fill light (softens the shadow side without flattening form).
    lht2=findobj(ax,'Type','Light','Tag','Rear');
    if(isempty(lht2))
        lht2=camlight('left');
        lht2.Tag='Rear';
        lht2.Position=[0,-100,90];
    end
    lht2.Color=[1,1,1]*renderStyle.fillIntensity;

    % Optional rim/back light for silhouette separation (showcase). Only
    % created when the preset asks for it; intensity 0 removes it.
    lht3=findobj(ax,'Type','Light','Tag','Rim');
    if renderStyle.rimIntensity > 0
        if isempty(lht3)
            lht3=light('Parent',ax);
            lht3.Tag='Rim';
            lht3.Style='infinite';
            lht3.Position=[-0.4,-0.7,0.6];   % grazing from behind/below-left
        end
        lht3.Color=[1,1,1]*renderStyle.rimIntensity;
    elseif ~isempty(lht3)
        delete(lht3);
    end

end

% Showcase matcap shading: bake a view-dependent material-capture response
% into the surface patch colours and turn MATLAB lighting off for them,
% reproducing the polished MRIcroGL/Surfice surface look. The matcap supplies
% shading; the existing per-vertex colours (anatomy gray + sulcal AO, or stat
% overlay) supply hue. View-dependent, so this runs after the camera is set
% (and re-runs every call, e.g. each animation frame).
if renderStyle.useMatcap && ~p.Results.showVoxelBrain && ~isempty(surfaceNormals)
    try
        matImg = pf2_base.plot.matcapTexture(renderStyle.matcapMaterial);
        mcRGB  = pf2_base.plot.matcapShade(surfaceNormals, ax, matImg);
        mcLum  = mean(mcRGB, 2);
        bH = findall(ax, 'Type', 'Patch', 'Tag', 'Brain');
        for bi = 1:numel(bH)
            cd = get(bH(bi), 'FaceVertexCData');
            if size(cd,1) == size(mcRGB,1) && size(cd,2) == 3
                set(bH(bi), 'FaceVertexCData', min(max(cd .* mcRGB, 0), 1), ...
                    'FaceLighting', 'none');
            end
        end
        % Overlay keeps its hue; scale by matcap luminance so it sits on the
        % shaded surface rather than floating as flat colour.
        oH = findall(ax, 'Type', 'Patch', 'Tag', 'BrainOverlay');
        for oi = 1:numel(oH)
            cd = get(oH(oi), 'FaceVertexCData');
            if size(cd,1) == numel(mcLum) && size(cd,2) == 3
                set(oH(oi), 'FaceVertexCData', min(max(cd .* mcLum, 0), 1), ...
                    'FaceLighting', 'none');
            end
        end
    catch mcErr
        warning('pf2:probe:interpolateValues3D:matcapFailed', ...
            'Matcap shading failed (%s); using the lit surface instead.', mcErr.message);
    end
end


if(p.Results.showScattering||p.Results.optodeLines)&&~contains('OptLines',itemsToSkipPlot)&&~contains('ScatterCurve',itemsToSkipPlot)
    t = linspace(0, pi, 16);
    
    s = probeInfo.TableOpt.SrcPos;
    d = probeInfo.TableOpt.DetPos;
    o = probeInfo.TableOpt.OptPos;
    
    
    % formula for ellipse: C + a cos(theta) U + b sin(theta) V
    b = probeInfo.TableOpt.b;%norm(s - d)/2;
    a = probeInfo.TableOpt.a;%p.Results.scatteringFactor * b;
    %U = s - d;
    U = probeInfo.TableOpt.U;%U / norm(U);
    %V = camtarget-o;
    V = probeInfo.TableOpt.V;%V / norm(V);
    
    for i=1:length(probeInfo.TableOpt.OptPos)
        
        points = o(i,:) + b(i)*cos(t)' .* U(i,:) + a(i)*sin(t)' .* V(i,:);
        
        if(p.Results.optodeLines)
            hold on
            vectorDir=probeInfo.TableOpt.VectorDir(i,:);
            h=plot3([o(i,1),vectorDir(1)], [o(i,2),vectorDir(2)],[o(i,3),vectorDir(3)], '--k', 'LineWidth', 2,'HandleVisibility','off');
            h.Tag='OptLines';
            
        end
        
        if(p.Results.showScattering)
            hold on
            h=plot3(points(:,1), points(:,2), points(:,3), 'k', 'LineWidth', 1,'HandleVisibility','off');
            h.Tag='ScatterCurve';
        end
    end
end


% Determine text color from figure background (handles dark mode)
figBg = get(ancestor(ax, 'figure'), 'Color');
if isnumeric(figBg) && mean(figBg) > 0.5
    textClr = [0 0 0];
else
    textClr = [1 1 1];
end

title(ax, titleString, 'Color', textClr);
if p.Results.showColorbar && ~all(dataEmpty) && isempty(itemsToSkipPlot)
    % Remove existing colorbars
    delete(findobj(ax, 'Type', 'ColorBar'));

    ax1 = ax;
    curAxPosition = ax1.Position;
    
    if twosided
        % Two-sided colorbar
        if hasUpperData || hasLowerData
            cbWidth = 0.01;
            cbGap = curAxPosition(4) * 0.03;  % Small gap between bars
            cbX = curAxPosition(1) + curAxPosition(3);

            if hasUpperData && hasLowerData
                cbHeight = (curAxPosition(4) - cbGap) / 2;
            else
                cbHeight = curAxPosition(4);
            end

            % Create upper colorbar
            if hasUpperData
                chPos = colorbar(ax1, 'Location', 'eastoutside');
                chPos.Tag = 'Main';
                chPos.Color = textClr;
                title(chPos, clrBarTitle, 'Color', textClr);

                % Set colormap for upper colorbar
                colormap(ax1, cmap_high(nColorsMaxBar));
                clim(ax1, cbarUpper_minmax);

                % Position upper colorbar in top half (or full height if no lower)
                if hasLowerData
                    chPos.Position = [cbX, curAxPosition(2) + cbHeight + cbGap, cbWidth, cbHeight];
                else
                    chPos.Position = [cbX, curAxPosition(2), cbWidth, cbHeight];
                end
            end

            % Create lower colorbar if needed
            if hasLowerData
                % Must parent ax2 to the same figure as ax1 — `axes(...)`
                % without 'Parent' binds to gcf, which may be a different
                % figure when the caller passed 'ax' as a name-value.
                ax2 = axes('Parent', ancestor(ax1, 'figure'), ...
                           'Position', ax1.Position, 'Visible', 'off');
                chNeg = colorbar(ax2, 'Location', 'eastoutside');
                chNeg.Tag = 'Lower';
                chNeg.Color = textClr;

                if(~hasUpperData)
                    title(chNeg, clrBarTitle, 'Color', textClr);
                end

                % Set colormap for lower colorbar
                colormap(ax2, cmap_low(nColorsMaxBar));
                clim(ax2, cbarLower_minmax);

                % Position lower colorbar in bottom half (or full height if no upper)
                chNeg.Position = [cbX, curAxPosition(2), cbWidth, cbHeight];

                % Link properties of both axes
                linkprop([ax1, ax2], {'CameraUpVector', 'CameraPosition', 'CameraTarget', 'XLim', 'YLim', 'ZLim'});
            end
        end
    else
        % Single-sided colorbar
        chPos = colorbar(ax1, 'Location', 'eastoutside');
        chPos.Color = textClr;
        title(chPos, clrBarTitle, 'Color', textClr);

        % Set colormap for single colorbar
        if isnumeric(cmap_high)
            colormap(ax1, cmap_high);
        else
            colormap(ax1, cmap_high(nColorsMaxBar));
        end

        if p.Results.logScale
            set(ax1, 'ColorScale', 'log');
            clim(ax1, exp(cbarUpper_minmax));
        else
            clim(ax1, cbarUpper_minmax);
        end

    end
end

% Alt reference code
% for y=-90:30:90
%     y
%     for x=-60:10:60
%         z=0;
%     %for z=-60:30:60
%        mni3d(x,y,z);
%     %end
%
%     end
% end
%




if(p.Results.showReference&&(isempty(itemsToSkipPlot)))
    %% Reference brain images
    imgData = pf2_base.getAsset('sideprofile');
    img = imgData.img; map = imgData.map; alpha = imgData.alpha;
    
    %https://www.openanatomy.org/atlases/nac/brain-2017-01/viewer/#!/view/33316a96-32f2-47f4-b5e0-a6225be09803/state/9dc9a3eb-7805-4b2b-943f-0b6e63ba488f
    
    imgXY=size(img);
    if(p.Results.useTalairach)
        [lEyeX,lEyeY,lEyeZ]=sphere(10);
        lEyeX=lEyeX*14-32;
        lEyeY=lEyeY*14+45;
        lEyeZ=lEyeZ*14-30;
        
        h=surf(lEyeX,lEyeY,lEyeZ,'FaceColor','white');
        h.Tag='Eye';
        
        h=surf(-1*lEyeX,lEyeY,lEyeZ,'FaceColor','white');
        h.Tag='Eye';
    else
        [lEyeX,lEyeY,lEyeZ]=sphere(10);
        lEyeX=lEyeX*14-32;
        lEyeY=lEyeY*14+45;
        lEyeZ=lEyeZ*14-40;
        
        h=surf(lEyeX,lEyeY,lEyeZ,'FaceColor','white');
        h.Tag='Eye';
        
        h=surf(-1*lEyeX,lEyeY,lEyeZ,'FaceColor','white');
        h.Tag='Eye';
        
    end
    
    if(p.Results.useTalairach)
        zStretch=1;
        xStretch=1.15;
        yStretch=1;
        
        xOffset=0;
        yOffset=-5;
        zOffset=-1;
        
        
        xMid=0;
        yMid=-10;
        zMid=9;
        
        rotX=rotx(10*pi/180);
        
        imgRes=1/4.3;
    else
        zStretch=1.1;
        xStretch=1.16;
        yStretch=1;
        
        xOffset=0;
        yOffset=-3;
        zOffset=-10;
        
        xMid=0;
        yMid=-10;
        zMid=17;
        
        imgRes=1/4.25;
        rotX=rotx(15*pi/180);
    end
    
    
    imgCoord1=[0,imgXY(1)*imgRes,imgXY(2)*imgRes]*rotX;
    imgCoord2=[0,-imgXY(1)*imgRes,imgXY(2)*imgRes]*rotX;
    imgCoord3=[0,imgXY(1)*imgRes,-imgXY(2)*imgRes]*rotX;
    imgCoord4=[0,-imgXY(1)*imgRes,-imgXY(2)*imgRes]*rotX;
    
    xImage = [imgCoord1(1)+xMid imgCoord2(1)+xMid; imgCoord3(1)+xMid imgCoord4(1)+xMid]*xStretch+xOffset;       % The x data for the image corners
    yImage = [imgCoord1(2)+yMid imgCoord2(2)+yMid; imgCoord3(2)+yMid imgCoord4(2)+yMid]*yStretch+yOffset;            % The y data for the image corners
    zImage = [imgCoord1(3)+zMid imgCoord2(3)+zMid; imgCoord3(3)+zMid imgCoord4(3)+zMid]*zStretch+zOffset;   % The z data for the image corners
    
    
    
    
    hold on
    h=surf(xImage,yImage,zImage,...    % Plot the surface
        'CData',img,...
        'FaceColor','texturemap','FaceLighting','none','AlphaData',alpha,'FaceAlpha','texture');
    hold off
    
    
    h.Tag='BrainRef';
    imgData = pf2_base.getAsset('rcSlice');
    img = imgData.img; map = imgData.map; alpha = imgData.alpha;

    imgXY=size(img);

    if(p.Results.useTalairach)
        xMid=-1;
        yMid=-7;
        zMid=6;
        
        
        %rotX=rotx(10*pi/180);
    else
        xMid=0;
        yMid=-11;
        zMid=17;
        
        
        %rotX=rotx(15*pi/180);
    end
    
    
    imgRes=1/4.45;
    imgCoord1=[imgXY(1)*imgRes,0,imgXY(2)*imgRes]*rotX;
    imgCoord2=[-imgXY(1)*imgRes,0,imgXY(2)*imgRes]*rotX;
    imgCoord3=[imgXY(1)*imgRes,0,-imgXY(2)*imgRes]*rotX;
    imgCoord4=[-imgXY(1)*imgRes,0,-imgXY(2)*imgRes]*rotX;
    
    xImage = [imgCoord1(1)+xMid imgCoord2(1)+xMid; imgCoord3(1)+xMid imgCoord4(1)+xMid]*xStretch+xOffset;       % The x data for the image corners
    yImage = [imgCoord1(2)+yMid imgCoord2(2)+yMid; imgCoord3(2)+yMid imgCoord4(2)+yMid]*yStretch+yOffset;            % The y data for the image corners
    zImage = [imgCoord1(3)+zMid imgCoord2(3)+zMid; imgCoord3(3)+zMid imgCoord4(3)+zMid]*zStretch+zOffset;   % The z data for the image corners
    
    
    hold on
    h=surf(xImage,yImage,zImage,...    % Plot the surface
        'CData',img,...
        'FaceColor','texturemap','FaceLighting','none','AlphaData',alpha,'FaceAlpha','texture');
    hold off
    h.Tag='BrainRef';

    imgData = pf2_base.getAsset('topprofile');
    img = imgData.img; map = imgData.map; alpha = imgData.alpha;

    imgXY=size(img);

    if(p.Results.useTalairach)
        xMid=1;
        yMid=-16;
        zMid=-16;
        
        %rotX=rotx(10*pi/180);
    else
        xMid=1;
        yMid=-20;
        zMid=-4;
        
        %rotX=rotx(15*pi/180);
    end
    
    
    imgCoord1=[imgXY(1)*imgRes,imgXY(2)*imgRes,0]*rotX;
    imgCoord2=[-imgXY(1)*imgRes,imgXY(2)*imgRes,0]*rotX;
    imgCoord3=[imgXY(1)*imgRes,-imgXY(2)*imgRes,0]*rotX;
    imgCoord4=[-imgXY(1)*imgRes,-imgXY(2)*imgRes,0]*rotX;
    
    xImage = [imgCoord1(1)+xMid imgCoord2(1)+xMid; imgCoord3(1)+xMid imgCoord4(1)+xMid]*xStretch+xOffset;       % The x data for the image corners
    yImage = [imgCoord1(2)+yMid imgCoord2(2)+yMid; imgCoord3(2)+yMid imgCoord4(2)+yMid]*yStretch+yOffset;            % The y data for the image corners
    zImage = [imgCoord1(3)+zMid imgCoord2(3)+zMid; imgCoord3(3)+zMid imgCoord4(3)+zMid]*zStretch+zOffset;   % The z data for the image corners
    
    
    hold on
    h=surf(xImage,yImage,zImage,...    % Plot the surface
        'CData',img,...
        'FaceColor','texturemap','FaceLighting','none','AlphaData',alpha,'FaceAlpha','texture');
    hold off
    
    h.Tag='BrainRef';
    
    text(-85,55,-50,'L');
    text(85,55,-50,'R');
    
end

% --- Keep optode / channel labels on top of marker spheres -------------
% In dense montages a label can be occluded by a NEIGHBOURING optode's
% sphere (e.g. S28 hidden behind D29). Lift each label along the view axis
% toward the camera: because the shift is parallel to the line of sight, the
% on-screen position is essentially unchanged (near-orthographic, distant
% camera) while the label's depth now beats nearby marker spheres. Labels on
% the far side of the head remain correctly hidden behind the opaque brain.
labelLift = p.Results.LabelLift;
if labelLift > 0
    viewVec = campos(ax) - camtarget(ax);
    nv = norm(viewVec);
    if nv > 0
        viewVec = viewVec / nv;
        lbls = findobj(ax, 'Type', 'text');
        keep = ismember(get(lbls, {'Tag'}), {'OptLabel','ProbeSrcLabel','ProbeDetLabel'});
        for ti = find(keep(:))'
            lbls(ti).Position = lbls(ti).Position + labelLift * viewVec;
        end
    end
end

% Drop the x/y/z axes, ticks and box for a clean probe render (children such
% as the brain surface, optode markers and labels are unaffected).
if ~p.Results.ShowAxes
    axis(ax, 'off');
end

h=ax;

% The render figure is made visible above (when off-screen) for the whole
% draw, so getframe/saveFigure here rasterize real content rather than a
% blank frame. Visibility is restored on function return via onCleanup.
if (nargout > 1)
    frame=getframe(ax);
    imgOut = frame.cdata;
end

% Save figure if requested. The render preset's supersample factor scales the
% export resolution (render large, downsample) for cleaner edges / specular —
% the equivalent of MRIcroGL's bmpzoom.
if ~isempty(savePath)
    fig = ancestor(ax, 'figure');
    pf2_base.plot.saveFigure(fig, savePath, saveWidth, saveHeight, ...
        saveDPI * max(1, renderStyle.supersample));
end

end  % interpolateValues3D


function fn = iResolveColormap(c, hotCroppedFn)
% Resolve a colormap spec to an n->[n x 3] function handle. Accepts: a function
% handle (returned as-is); an [Nx3] numeric matrix (wrapped in a resampling
% handle so every downstream cmap(n) call works); 'hotCropped'; or any other
% name, which is routed through pf2_base.plot.brainColormap. brainColormap
% resolves MRIcroGL/Surfice LUTs and CVD-safe maps (rdbu/viridis/cividis),
% falls through to MATLAB built-in colormap functions, and errors clearly on an
% unknown name (so a typo surfaces as a clear error, not a silent wrong map).
if isa(c, 'function_handle')
    fn = c;
    return;
end
if isnumeric(c)
    M = c;
    fn = @(k) iResampleColormap(M, k);
    return;
end
nm = char(c);
if strcmp(nm, 'hotCropped')
    fn = hotCroppedFn;
    return;
end
fn = @(n) pf2_base.plot.brainColormap(nm, n);
end


function M2 = iResampleColormap(M, k)
% Linearly resample a [Nx3] colormap matrix to k rows (identity if N==k).
k = max(2, round(k));
if size(M, 1) == k
    M2 = M;
    return;
end
t  = linspace(0, 1, size(M, 1));
ti = linspace(0, 1, k);
M2 = [interp1(t, M(:,1), ti)', interp1(t, M(:,2), ti)', interp1(t, M(:,3), ti)'];
M2 = min(max(M2, 0), 1);
end


function [N, ao] = iLocalSurfaceShading(ax, V, F, style)
% Smooth per-vertex normals + sulcal ambient-occlusion weight for the cortex.
% Cached in axes appdata keyed on vertex count and AO parameters so repeated
% draws (and animation frames) reuse the result; only matcap, which is
% view-dependent, recomputes per frame elsewhere.
cache = getappdata(ax, 'iv3d_shadeCache');
% Key on vertex count, AO params, and a cheap coordinate fingerprint so a
% reused axes that switches mesh resolution or coordinate space (e.g. MNI vs
% Talairach, which keeps the vertex count but moves the coordinates) does not
% reuse stale normals/AO.
fp = sum(V(1,:)) + sum(V(end,:));
key = [size(V,1), style.aoStrength, style.aoGyral, fp];
if ~isempty(cache) && isfield(cache,'key') && isequal(cache.key, key)
    N = cache.N; ao = cache.ao;
    return;
end
N  = pf2_base.plot.vertexNormals(V, F);
ao = pf2_base.plot.meshCurvature(V, F, N, ...
    'Strength', style.aoStrength, 'Gyral', style.aoGyral);
setappdata(ax, 'iv3d_shadeCache', struct('key', key, 'N', N, 'ao', ao));
end


function iLocalRestoreVisible(figHandle, vis)
% Restore a figure's Visible state (used by the off-screen render path).
if isgraphics(figHandle)
    figHandle.Visible = vis;
end
end


function va = iLocalInterpScalar(distSquared, cAlpha, maxDist2, projectMode)
% Interpolate a per-channel scalar in [0,1] onto mesh vertices using the
% same kernel that interpolateChannelColors uses for values. Returns zero
% for out-of-range vertices. Used to build per-vertex alpha in transparent
% AlphaMode. NOTE: unlike interpolateChannelColors this helper has no
% ChanMask argument; callers must pre-zero masked-channel entries in cAlpha
% before calling so the two paths stay consistent.
    [d, ind] = min(distSquared, [], 2);
    outOfRange = d > maxDist2 | ~isfinite(d);
    ind(outOfRange) = 0;
    V = size(distSquared, 1);
    va = zeros(V, 1);

    switch lower(string(projectMode))
        case "nearest"
            valid = ind > 0;
            va(valid) = cAlpha(ind(valid));
        case {"linear", "quadratic", "cubic"}
            switch lower(string(projectMode))
                case "linear",    beta = 0.5;
                case "quadratic", beta = 1;
                case "cubic",     beta = 1.5;
            end
            d2 = distSquared;
            d2(d2 >= maxDist2 | isnan(d2)) = Inf;
            w = 1 ./ (d2.^beta + 1e-8);
            wSum = sum(w, 2);
            va = (w * cAlpha) ./ wSum;
            va(~isfinite(wSum) | wSum == 0) = 0;
        case "sensitivity"
            sigma2 = maxDist2 / 4;
            w = exp(-distSquared / (2 * sigma2));
            w(distSquared > maxDist2 | isnan(distSquared)) = 0;
            wSum = sum(w, 2);
            va = (w * cAlpha) ./ wSum;
            va(~isfinite(wSum) | wSum == 0) = 0;
        otherwise
            error('pf2:interpolateValues3D:badProjectMode', ...
                'Unknown ProjectMode for alpha interpolation: %s', projectMode);
    end
    va(~isfinite(va)) = 0;
    va = max(0, min(1, va));
end


function [parcelIdx, inCoverage, edgeXYZ] = iLocalParcellate(ax, V, F, controlPoints, maxDist2, useGeodesic, animated, surfaceNormals)
% Hard nearest-optode assignment of cortical vertices for the parcellation
% render variant. Each vertex is labelled with its nearest optode; vertices
% beyond the coverage radius are dropped. Boundary edges (between differing
% parcels and along the coverage rim) are returned as NaN-separated segments,
% lifted slightly off the surface so the outlines sit cleanly on top.
%
% Inputs:
%   ax             - axes handle (used only for the distance cache lookup)
%   V              - [nV x 3] cortical mesh vertices
%   F              - [nF x 3] mesh faces (1-indexed)
%   controlPoints  - [K x 3] optode positions (parcel centers)
%   maxDist2       - squared coverage radius; vertices farther are uncovered
%   useGeodesic    - logical; geodesic vs Euclidean nearest assignment
%   animated       - logical; reuse the cached [nV x K] distance matrix
%   surfaceNormals - [nV x 3] vertex normals (accepted for API stability;
%                    outlines are lifted radially, so this is unused)
%
% Outputs:
%   parcelIdx   - [nV x 1] nearest-optode index for every vertex (>=1)
%   inCoverage  - [nV x 1] logical mask of vertices within coverage
%   edgeXYZ     - [M x 3] NaN-separated boundary segment endpoints ([] if none)

    cacheKey = 'iv3d_distCache';
    cache = [];
    if animated
        cache = getappdata(ax, cacheKey);
    end
    cacheValid = ~isempty(cache) && isfield(cache,'controlPoints') ...
        && isequal(cache.controlPoints, controlPoints) ...
        && isfield(cache,'useGeodesic') && isequal(cache.useGeodesic, useGeodesic);

    if cacheValid
        dist_array = cache.dist_array;
    elseif useGeodesic
        dist_array = iLocalGeodesicDistSq(ax, V, F, controlPoints);
    else
        dist_array = sum(V.^2,2) + sum(controlPoints.^2,2)' - 2*(V*controlPoints');
    end

    [minD, parcelIdx] = min(dist_array, [], 2);
    inCoverage = minD <= maxDist2;

    % Mesh vertex adjacency (neighbors + self), built once and reused for both
    % coverage hole-closing and label smoothing below.
    nV = size(V, 1);
    Iadj = [F(:,1); F(:,2); F(:,2); F(:,3); F(:,3); F(:,1)];
    Jadj = [F(:,2); F(:,1); F(:,3); F(:,2); F(:,1); F(:,3)];
    A = sparse(Iadj, Jadj, 1, nV, nV);
    A = double(A > 0) + speye(nV);         % neighbors + self
    deg = full(sum(A, 2)) - 1;             % neighbor count (excludes self)

    % Close interior coverage pinholes. A vertex can fall just outside every
    % optode's coverage radius where the cortex curves away from the montage
    % (a positioning/geometry artifact), leaving a small gap between otherwise
    % adjacent parcels. Pull any uncovered vertex whose neighbors are mostly
    % covered into coverage (it already carries a nearest-optode label). The
    % true outer rim, where few neighbors are covered, is left intact.
    for it = 1:2
        covNbr = A * double(inCoverage);   % covered neighbors (self adds 0 here)
        fillv = ~inCoverage & deg > 0 & covNbr >= 0.6 * deg;
        inCoverage(fillv) = true;
    end

    % Majority-vote label smoothing among covered vertices. The raw nearest-
    % optode field is ragged at parcel borders (single-vertex protrusions),
    % which sprout whisker-like side chains when boundaries are traced. A few
    % iterations of "adopt the most common neighbor label" straighten the
    % borders and remove the speckle. Coverage status is held fixed.
    K = size(controlPoints, 1);
    if K >= 2
        cov = inCoverage;
        covRows = find(cov);
        for it = 1:3
            % One sparse matvec against the label indicator gives every
            % vertex's neighbor vote-count for all parcels at once: counts is
            % [nV x K], and the column-wise max is the majority label.
            indicator = sparse(covRows, parcelIdx(cov), 1, nV, K);
            counts = A * indicator;
            [mx, best] = max(counts, [], 2);
            upd = cov & mx > 0;
            parcelIdx(upd) = best(upd);
        end
    end

    % Label uncovered vertices 0 so the coverage rim registers as a boundary.
    pLabel = parcelIdx;
    pLabel(~inCoverage) = 0;

    % Marching-triangles label contour: trace boundaries through triangle edge
    % MIDPOINTS rather than through mesh vertices. A vertex-routed boundary
    % always zigzags (it can only step between vertices); the midpoint contour
    % runs between vertices and yields a clean piecewise-linear curve that
    % Chaikin then smooths into a continuous outline.
    la = pLabel(F(:,1));  lb = pLabel(F(:,2));  lc = pLabel(F(:,3));
    active = find(~(la == lb & lb == lc) & max([la, lb, lc], [], 2) > 0);
    if isempty(active)
        edgeXYZ = [];
        return;
    end

    nFa = numel(active);
    nodePos = zeros(4 * nFa, 3);    % up to 3 edge-crossings + 1 centroid / face
    edgesC  = zeros(3 * nFa, 2);
    nNode = 0; nEdge = 0;
    edgeNodeMap = containers.Map('KeyType', 'double', 'ValueType', 'double');
    keyBase = size(V, 1) + 1;
    pairs = [1 2; 2 3; 3 1];
    for t = 1:nFa
        f  = active(t);
        vv = F(f, :);                       % [a b c]
        ll = [la(f), lb(f), lc(f)];
        cross = zeros(1, 3); nc = 0;
        for q = 1:3
            if ll(pairs(q,1)) ~= ll(pairs(q,2))
                v1 = vv(pairs(q,1));  v2 = vv(pairs(q,2));
                key = min(v1,v2) * keyBase + max(v1,v2);    % unique per mesh edge
                if isKey(edgeNodeMap, key)
                    id = edgeNodeMap(key);
                else
                    nNode = nNode + 1;  id = nNode;
                    edgeNodeMap(key) = id;
                    nodePos(id, :) = (V(v1,:) + V(v2,:)) / 2;
                end
                nc = nc + 1;  cross(nc) = id;
            end
        end
        if nc == 2
            nEdge = nEdge + 1;
            edgesC(nEdge, :) = cross(1:2);
        elseif nc == 3
            nNode = nNode + 1;  cId = nNode;       % triple-junction -> centroid
            nodePos(cId, :) = mean(V(vv, :), 1);
            edgesC(nEdge+1, :) = [cId, cross(1)];
            edgesC(nEdge+2, :) = [cId, cross(2)];
            edgesC(nEdge+3, :) = [cId, cross(3)];
            nEdge = nEdge + 3;
        end
    end
    nodePos = nodePos(1:nNode, :);
    edgesC  = edgesC(1:nEdge, :);

    chains = iLocalTraceChains(edgesC);
    if isempty(chains)
        edgeXYZ = [];
        return;
    end

    % Smooth each contour chain (corner-cut + light relax) and lift it off the
    % cortex so the outline reads as a clean curve.
    c = mean(V, 1);
    liftMag = 1.8;          % mm outward; clears the surface after smoothing
    minChainLen = 2.0;      % mm; prune sub-voxel stubs at junctions
    segs = cell(numel(chains), 1);
    keep = false(numel(chains), 1);
    for i = 1:numel(chains)
        idx = chains{i}(:);
        P = nodePos(idx, :);
        isLoop = numel(idx) > 2 && idx(1) == idx(end);
        if ~isLoop && sum(vecnorm(diff(P), 2, 2)) < minChainLen
            continue;       % drop tiny spikes that would read as whiskers
        end
        P = iLocalChaikin(P, isLoop, 3);            % corner-cut to a smooth curve
        P = iLocalSmoothChain(P, isLoop, 4, 0.5);   % light relax
        dir = P - c;        % radial lift (cortex is locally convex)
        dir = dir ./ max(vecnorm(dir, 2, 2), 1e-6);
        P = P + liftMag * dir;
        segs{i} = [P; nan(1, 3)];   % NaN row breaks the polyline
        keep(i) = true;
    end
    edgeXYZ = vertcat(segs{keep});
end


function P = iLocalChaikin(P, isLoop, nIter)
% Chaikin corner-cutting subdivision: replace each segment endpoint pair with
% points at the 1/4 and 3/4 marks, smoothing sharp mesh-edge corners while
% staying inside the original polyline's convex hull (no surface overshoot).
% Open-chain endpoints are preserved so shared junctions stay stitched.
    for it = 1:nIter
        n = size(P, 1);
        if n < 3, return; end
        if isLoop
            A = P;
            B = P([2:n, 1], :);
            Q = 0.75 * A + 0.25 * B;
            R = 0.25 * A + 0.75 * B;
            P = zeros(2*n, 3);
            P(1:2:end, :) = Q;
            P(2:2:end, :) = R;
        else
            A = P(1:end-1, :);
            B = P(2:end, :);
            Q = 0.75 * A + 0.25 * B;
            R = 0.25 * A + 0.75 * B;
            inner = zeros(2*size(A,1), 3);
            inner(1:2:end, :) = Q;
            inner(2:2:end, :) = R;
            P = [P(1,:); inner; P(end,:)];
        end
    end
end


function [chain, used] = iLocalWalkChain(Er, deg, eadj, used, startNode, firstEdge)
% Walk a boundary chain from startNode along firstEdge, stopping at a
% junction/endpoint (degree ~= 2), a dead end, or loop closure. Returns the
% ordered remapped-vertex sequence and the updated edge-used mask.
    chain = startNode;
    curr = startNode;
    ei = firstEdge;
    guard = 0;
    maxStep = numel(used) + 5;
    while guard < maxStep
        guard = guard + 1;
        used(ei) = true;
        nxt = Er(ei, 1);
        if nxt == curr, nxt = Er(ei, 2); end
        chain(end+1) = nxt; %#ok<AGROW>
        curr = nxt;
        if deg(curr) ~= 2, break; end
        cand = eadj{curr}(~used(eadj{curr}));
        if isempty(cand), break; end
        ei = cand(1);
    end
end


function chains = iLocalTraceChains(E)
% Order an unstructured set of undirected boundary edges [M x 2] (mesh vertex
% index pairs) into connected polylines. Chains are split at junctions where
% 3+ parcels meet and at coverage-rim endpoints; remaining all-degree-2
% components are closed loops. Returns a cell array of mesh-vertex sequences.
    chains = {};
    if isempty(E), return; end
    verts = unique(E(:));
    lut = zeros(max(verts), 1);
    lut(verts) = 1:numel(verts);
    Er = [lut(E(:,1)), lut(E(:,2))];
    nB = numel(verts);

    adj = cell(nB, 1);
    eadj = cell(nB, 1);
    for i = 1:size(Er, 1)
        a = Er(i,1); b = Er(i,2);
        adj{a}(end+1) = b;  eadj{a}(end+1) = i;
        adj{b}(end+1) = a;  eadj{b}(end+1) = i;
    end
    deg = cellfun(@numel, adj);
    used = false(size(Er, 1), 1);

    % Anchor chains at junctions / endpoints (degree ~= 2) first.
    starts = find(deg ~= 2)';
    for s = starts
        es = eadj{s};
        for k = 1:numel(es)
            if ~used(es(k))
                [cseq, used] = iLocalWalkChain(Er, deg, eadj, used, s, es(k));
                chains{end+1} = verts(cseq)'; %#ok<AGROW>
            end
        end
    end

    % Whatever remains is part of a pure (all degree-2) loop.
    rem = find(~used)';
    for r = rem
        if used(r), continue; end
        [cseq, used] = iLocalWalkChain(Er, deg, eadj, used, Er(r,1), r);
        chains{end+1} = verts(cseq)'; %#ok<AGROW>
    end
end


function P = iLocalSmoothChain(P, isLoop, nIter, lambda)
% Laplacian smoothing of an ordered 3D polyline. Loops wrap around; open
% chains keep their endpoints fixed so shared junctions stay stitched.
    n = size(P, 1);
    if n < 3, return; end
    for it = 1:nIter
        if isLoop
            ip = [n, 1:n-1];
            in = [2:n, 1];
            P = P + lambda * ((P(ip,:) + P(in,:)) / 2 - P);
        else
            ip = [1, 1:n-1];
            in = [2:n, n];
            Q = P + lambda * ((P(ip,:) + P(in,:)) / 2 - P);
            Q(1,:) = P(1,:);
            Q(end,:) = P(end,:);
            P = Q;
        end
    end
end


function distSq = iLocalGeodesicDistSq(ax, V, F, controlPoints)
% Graph-geodesic squared distance from each mesh vertex to each control
% point. The mesh graph (the expensive graph() build over ~100k faces) is
% cached PERSISTENTLY across calls keyed on mesh identity, so repeated
% renders (time series, multiple subjects, successive figures) reuse it.
% The per-control-point Dijkstra below is NOT cached here -- it is cheap once
% the graph exists and must vary with the (per-subject) control points.
%
% Falls back to Euclidean (with warning) if MATLAB's graph/distances is
% unavailable or the mesh is empty.

    persistent meshGraphCache
    if isempty(meshGraphCache)
        meshGraphCache = containers.Map('KeyType', 'char', 'ValueType', 'any');
    end

    nV = size(V, 1);
    K = size(controlPoints, 1);

    try
        % Build-or-retrieve mesh graph. The brain mesh is static atlas data,
        % so a cheap signature (vertex/face counts + coordinate/index
        % checksums) uniquely identifies it without an O(nF) isequal compare.
        sig = sprintf('%d_%d_%.12g_%d', nV, size(F, 1), sum(V(:)), sum(F(:)));
        if isKey(meshGraphCache, sig)
            G = meshGraphCache(sig);
        else
            E = [F(:, [1 2]); F(:, [2 3]); F(:, [3 1])];
            E = sort(E, 2);
            E = unique(E, 'rows');
            w = sqrt(sum((V(E(:, 1), :) - V(E(:, 2), :)).^2, 2));
            G = graph(E(:, 1), E(:, 2), w, nV);
            meshGraphCache(sig) = G;
        end

        % Per-axes breadcrumb: record which cached mesh this axes used (the
        % heavy graph lives in the persistent cache above, not here).
        if ~isempty(ax) && isgraphics(ax)
            setappdata(ax, 'iv3d_meshGraph', sig);
        end

        % Snap each control point to its nearest mesh vertex
        seedDistSq = sum(V.^2, 2) + sum(controlPoints.^2, 2)' ...
                     - 2 * (V * controlPoints');
        [~, seedVerts] = min(seedDistSq, [], 1);   % 1 x K

        % Dijkstra from each seed to all vertices
        distGeo = zeros(nV, K);
        for k = 1:K
            distGeo(:, k) = distances(G, seedVerts(k));
        end
        distSq = distGeo.^2;
        distSq(~isfinite(distSq)) = Inf;
    catch ME
        warning('pf2:interpolateValues3D:geodesicFallback', ...
            'Geodesic distance failed (%s); falling back to Euclidean.', ME.message);
        distSq = sum(V.^2, 2) + sum(controlPoints.^2, 2)' ...
                 - 2 * (V * controlPoints');
    end
end

function iWarnOnce(id, varargin)
% IWARNONCE Emit a warning with the given id at most once per MATLAB session.
    persistent seen
    if isempty(seen), seen = {}; end
    if any(strcmp(seen, id)), return; end
    seen{end+1} = id; %#ok<AGROW>
    warning(id, varargin{:});
end
