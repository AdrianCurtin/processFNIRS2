function varargout = showHead3D(fNIR, varargin)
% SHOWHEAD3D Render the Colin27 head (scalp + brain) with the probe in MNI space
%
% Draws an anatomically-registered head model in MNI millimetre space: the
% Colin27 scalp surface as a translucent shell over a brain surface, with the
% fNIRS montage overlaid as source/detector optodes (or channel midpoints).
% Unlike interpolateValues3D (which stretches a model-frame cortex to fit MNI
% bounds), this renders the Colin27 surfaces directly in real MNI mm, so a
% montage expressed in MNI coordinates sits on the head roughly where it
% belongs. Use it to sanity-check probe placement, give a qualitative sense of
% scalp-to-brain separation, or produce head figures with or without the scalp.
%
% This is a qualitative VISUALIZATION / QC aid, not a quantitative anatomical
% or photon-transport model. Do not use these surfaces for DOT, forward
% modelling, or depth measurement (see Notes).
%
% The scalp is a smoothed isosurface of the Colin27 whole-head mask; the
% default brain surface is the Colin27 intracranial-cavity (brain-mask)
% boundary. That boundary is the outer envelope of brain + subarachnoid CSF, so
% it sits a few millimetres SUPERFICIAL to the true pial cortical surface and
% is not a folded gray-matter surface. Pass 'Cortex','cerebro' for the folded
% pf2 cortical mesh (mapped into the same MNI bounding box via
% pf2_base.dot.corticalMesh); note that mapping is a per-axis bounding-box
% stretch (the same distortion interpolateValues3D applies), so 'cerebro' is a
% different, metrically-stretched brain that is only approximately aligned
% (shared MNI bounding box) with the Colin27 scalp.
%
% Reference:
%   Holmes CJ, Hoge R, Collins L, Woods R, Toga AW, Evans AC (1998).
%   Enhancement of MR Images Using Registration for Signal Averaging.
%   Journal of Computer Assisted Tomography, 22(2), 324-333.
%   DOI: 10.1097/00004728-199803000-00032
%   Colin27 model (c) 1993-2009 D.L. Collins, McConnell Brain Imaging Centre,
%   Montreal Neurological Institute, McGill University.
%
% Syntax:
%   pf2.probe.plot.showHead3D(fNIR)
%   pf2.probe.plot.showHead3D(fNIR, Name, Value, ...)
%   h = pf2.probe.plot.showHead3D(...)
%   [h, imgOut] = pf2.probe.plot.showHead3D(...)
%
% Inputs:
%   fNIR - fNIRS data struct (imported or processed). Its device supplies the
%          optode/channel positions. May be [] to render the head model alone.
%
% Optional Parameters (name-value):
%   'ShowScalp'     - Draw the translucent scalp shell (default true). False
%                     renders the brain surface only ("without scalp").
%   'Cortex'        - Brain surface: 'colin27' (default, smooth intracranial
%                     envelope) | 'cerebro' (folded pf2 mesh) | 'none'.
%   'ScalpAlpha'    - Scalp face transparency in [0,1] (default 0.18).
%   'BrainAlpha'    - Brain face transparency in [0,1] (default 1).
%   'ScalpColor'    - Scalp RGB (default [0.85 0.80 0.72]).
%   'BrainColor'    - Brain RGB (default [0.92 0.68 0.68]).
%   'Markers'       - Probe overlay: 'optodes' (default; sources + detectors)
%                     | 'channels' (per-channel S-D midpoints) | 'both'
%                     | 'none'. If 'optodes' is requested but the device only
%                     has channel positions, falls back to channel midpoints
%                     with a warning.
%   'SourceColor'   - Source marker RGB (default [0.85 0.20 0.20]).
%   'DetectorColor' - Detector marker RGB (default [0.20 0.45 0.85]).
%   'ChannelColor'  - Channel-midpoint marker RGB (default [0.10 0.35 0.90]).
%   'MarkerSize'    - Marker area in points^2 (default 45).
%   'ShowLabels'    - Draw optode labels next to source/detector markers
%                     (default false).
%   'View'          - Camera preset ('left'|'right'|'front'|'back'|'top'|
%                     'bottom'|'hero') or a [azimuth elevation] pair
%                     (default 'hero').
%   'savePath'      - If set, render headlessly and write a PNG to this path
%                     (correct white background; preferred over saveas for 3D).
%
% Outputs:
%   varargout{1} - Axes handle (h). NOTE: in headless ('savePath') mode the
%                  figure is closed after saving, so this is returned as [].
%   varargout{2} - RGB image capture [H x W x 3 uint8] (imgOut).
%
% Example:
%   data = pf2.import.sampleData.fNIR2000();
%   proc = processFNIRS2(data);
%   % Scalp + sources/detectors:
%   pf2.probe.plot.showHead3D(proc, 'savePath', 'head.png');
%   % Brain only, channel midpoints, folded cortex:
%   pf2.probe.plot.showHead3D(proc, 'ShowScalp', false, ...
%       'Cortex', 'cerebro', 'Markers', 'channels');
%   % Head model alone, no probe, viewed from the left:
%   pf2.probe.plot.showHead3D([], 'View', 'left');
%
% Notes:
%   - Surfaces are in the standard MNI 1 mm stereotaxic frame. The Colin27-lin
%     model shares that linear frame with ICBM152, so treating its world-mm as
%     MNI152 introduces no gross offset; only the colin27-lin -> ICBM152-2009a
%     NONLINEAR residual is dropped. That residual is typically a few mm but can
%     reach ~1 cm locally, which is fine for visualization/QC but is why these
%     surfaces must not be used for DOT/forward modelling or depth estimates.
%   - The scalp mask is coarse (2 mm, "rough") and is usually cropped at the
%     neck, so fine features (ears/nose) are blobby and the base is flat.
%   - Optode/channel positions are used as stored (MNI for MNI-registered
%     montages); no coordinate transform is applied. Markers are not scalp-
%     projected, so on a convex head channel midpoints sit ~1-3 mm below the
%     scalp surface.
%   - This renderer is intentionally OUTSIDE the pf2 'Style'/RenderStyle system
%     used by interpolateValues3D; it uses fixed lighting and does not follow
%     interactive dark-mode theming.
%   - HEADLESS SAVING: pass 'savePath' rather than the off-screen figure +
%     saveas pattern, which is unreliable for 3D renders.
%
% See also: pf2.probe.plot.showProbe3D, pf2.probe.plot.interpolateValues3D,
%           pf2.Device/sourcePositions, pf2_base.dot.corticalMesh, pf2_base.getAsset

% --- Parse inputs ----------------------------------------------------------
validColor = @(x) isnumeric(x) && numel(x)==3;
validAlpha = @(x) isnumeric(x) && isscalar(x) && x>=0 && x<=1;
p = inputParser;
p.addParameter('ShowScalp', true, @(x) islogical(x) && isscalar(x));
p.addParameter('Cortex', 'colin27', @(x) ischar(x) || (isstring(x) && isscalar(x)));
p.addParameter('ScalpAlpha', 0.18, validAlpha);
p.addParameter('BrainAlpha', 1, validAlpha);
p.addParameter('ScalpColor', [0.85 0.80 0.72], validColor);
p.addParameter('BrainColor', [0.92 0.68 0.68], validColor);
p.addParameter('Markers', 'optodes', @(x) ischar(x) || (isstring(x) && isscalar(x)));
p.addParameter('SourceColor', [0.85 0.20 0.20], validColor);
p.addParameter('DetectorColor', [0.20 0.45 0.85], validColor);
p.addParameter('ChannelColor', [0.10 0.35 0.90], validColor);
p.addParameter('MarkerSize', 45, @(x) isnumeric(x) && isscalar(x) && x>0);
p.addParameter('ShowLabels', false, @(x) islogical(x) && isscalar(x));
p.addParameter('View', 'hero', @iValidView);
p.addParameter('savePath', '', @(x) ischar(x) || (isstring(x) && isscalar(x)));
p.parse(varargin{:});
o = p.Results;
cortex = lower(char(o.Cortex));
if ~ismember(cortex, {'colin27', 'cerebro', 'none'})
    error('pf2:probe:plot:showHead3D:badCortex', ...
        'Cortex must be ''colin27'', ''cerebro'', or ''none''.');
end
markers = lower(char(o.Markers));
if ~ismember(markers, {'optodes', 'channels', 'both', 'none'})
    error('pf2:probe:plot:showHead3D:badMarkers', ...
        'Markers must be ''optodes'', ''channels'', ''both'', or ''none''.');
end

% --- Probe positions (best effort) ----------------------------------------
srcPos = []; detPos = []; chPos = [];
srcLbl = strings(0,1); detLbl = strings(0,1);
wantOpt = ismember(markers, {'optodes', 'both'});
wantCh  = ismember(markers, {'channels', 'both'});
if ~strcmp(markers, 'none')
    if isempty(fNIR)
        % nothing to place; head-only render
    elseif ~isstruct(fNIR)
        warning('pf2:probe:plot:showHead3D:notStruct', ...
            ['fNIR must be a data struct to overlay the probe (got %s); ', ...
             'skipping. Pass a single struct, not a cell array.'], class(fNIR));
    else
        try
            dev = pf2.Device.load(fNIR);
            if wantOpt
                if dev.hasSDPositions()
                    [srcPos, srcLbl] = dev.sourcePositions();
                    [detPos, detLbl] = dev.detectorPositions();
                elseif dev.hasMNI()
                    chPos = dev.mniPositions();   % fallback to channel midpoints
                    warning('pf2:probe:plot:showHead3D:noOptodes', ...
                        'Device has no source/detector positions; showing channel midpoints instead.');
                else
                    warning('pf2:probe:plot:showHead3D:noMNI', ...
                        'Device has no MNI coordinates; skipping probe overlay.');
                end
            end
            if wantCh
                if dev.hasMNI()
                    chPos = dev.mniPositions();
                else
                    warning('pf2:probe:plot:showHead3D:noMNI', ...
                        'Device has no MNI coordinates; skipping channel overlay.');
                end
            end
        catch ME
            warning('pf2:probe:plot:showHead3D:probeLoadFailed', ...
                'Could not resolve probe positions (%s); skipping overlay.', ME.message);
        end
    end
end

% --- Figure / axes ---------------------------------------------------------
headless = ~isempty(char(o.savePath));
imgOut = [];
if headless
    fig = figure('Visible', 'off', 'Color', 'w');
else
    fig = figure('Color', 'w');
end

try
    ax = axes('Parent', fig); hold(ax, 'on');

    % --- Cortex ------------------------------------------------------------
    switch cortex
        case 'colin27'
            m = pf2_base.getAsset('colin27_brain');
            cortV = m.vertices; cortF = m.faces;
        case 'cerebro'
            cm = pf2_base.dot.corticalMesh();   % folded mesh, stretched to MNI mm
            cortV = cm.vertices; cortF = cm.faces;
        otherwise  % 'none'
            cortV = []; cortF = [];
    end
    if ~isempty(cortV)
        patch(ax, 'Faces', cortF, 'Vertices', cortV, ...
            'FaceColor', o.BrainColor, 'EdgeColor', 'none', ...
            'FaceAlpha', o.BrainAlpha, 'FaceLighting', 'gouraud', ...
            'AmbientStrength', 0.35, 'DiffuseStrength', 0.7, 'SpecularStrength', 0.15);
    end

    % --- Scalp -------------------------------------------------------------
    if o.ShowScalp
        s = pf2_base.getAsset('colin27_scalp');
        patch(ax, 'Faces', s.faces, 'Vertices', s.vertices, ...
            'FaceColor', o.ScalpColor, 'EdgeColor', 'none', ...
            'FaceAlpha', o.ScalpAlpha, 'FaceLighting', 'gouraud', ...
            'AmbientStrength', 0.4, 'DiffuseStrength', 0.6, 'SpecularStrength', 0.1);
    end

    % --- Probe markers -----------------------------------------------------
    legHandles = gobjects(0); legLabels = strings(0,1);
    if ~isempty(srcPos)
        h = scatter3(ax, srcPos(:,1), srcPos(:,2), srcPos(:,3), o.MarkerSize, ...
            o.SourceColor, 'filled', 'MarkerEdgeColor', 'k', 'DisplayName', 'Source');
        legHandles(end+1) = h; legLabels(end+1) = "Source";
        if o.ShowLabels
            iLabelOptodes(ax, srcPos, srcLbl);
        end
    end
    if ~isempty(detPos)
        h = scatter3(ax, detPos(:,1), detPos(:,2), detPos(:,3), o.MarkerSize, ...
            o.DetectorColor, 'filled', 'MarkerEdgeColor', 'k', 'DisplayName', 'Detector');
        legHandles(end+1) = h; legLabels(end+1) = "Detector";
        if o.ShowLabels
            iLabelOptodes(ax, detPos, detLbl);
        end
    end
    if ~isempty(chPos)
        h = scatter3(ax, chPos(:,1), chPos(:,2), chPos(:,3), o.MarkerSize, ...
            o.ChannelColor, 'filled', 'MarkerEdgeColor', 'k', 'DisplayName', 'Channel');
        legHandles(end+1) = h; legLabels(end+1) = "Channel";
    end

    % --- Camera / lighting -------------------------------------------------
    axis(ax, 'equal'); axis(ax, 'off');
    iApplyView(ax, o.View);
    camlight(ax, 'headlight'); camlight(ax, 'left');
    lighting(ax, 'gouraud'); material(ax, 'dull');
    if numel(legHandles) > 1
        legend(ax, legHandles, cellstr(legLabels), 'Location', 'best', 'TextColor', 'k');
    end

    % --- Headless export ---------------------------------------------------
    % 3D surfaces only rasterize correctly in a visible figure under headless
    % MATLAB (-batch/-nodisplay); flip Visible on for the export + capture.
    if headless
        fig.Visible = 'on';
        try
            exportgraphics(ax, char(o.savePath), 'Resolution', 150, ...
                'BackgroundColor', 'white');
        catch ME
            warning('pf2:probe:plot:showHead3D:saveFailed', ...
                'exportgraphics failed: %s', ME.message);
        end
        if nargout >= 2
            try
                fr = getframe(fig); imgOut = fr.cdata;
            catch
                imgOut = [];
            end
        end
    end
catch ME
    if ishghandle(fig), close(fig); end   % never leak our figure on error
    rethrow(ME);
end

% --- Finalize --------------------------------------------------------------
if headless
    if ishghandle(fig), close(fig); end
    axOut = [];                            % do not hand back a closed axes
else
    axOut = ax;
end

if nargout >= 1, varargout{1} = axOut; end
if nargout >= 2, varargout{2} = imgOut; end
end

% ------------------------------------------------------------------------
function iLabelOptodes(ax, pos, lbl)
% Draw optode labels next to their markers (skips missing/empty labels).
if isempty(lbl) || numel(lbl) ~= size(pos, 1), return; end
for i = 1:size(pos, 1)
    if strlength(lbl(i)) == 0, continue; end
    text(ax, pos(i,1), pos(i,2), pos(i,3), char(lbl(i)), ...
        'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', ...
        'FontSize', 8, 'Color', 'k');
end
end

% ------------------------------------------------------------------------
function tf = iValidView(v)
% Accept a named preset (char/scalar string) or an [azimuth elevation] pair.
tf = (ischar(v) || (isstring(v) && isscalar(v))) || ...
     (isnumeric(v) && numel(v) == 2);
end

% ------------------------------------------------------------------------
function iApplyView(ax, v)
% Apply a named camera preset or an explicit [azimuth elevation] pair.
if isnumeric(v) && numel(v) == 2
    view(ax, v(1), v(2)); return;
end
switch lower(char(v))
    case 'left',   view(ax, -90, 0);
    case 'right',  view(ax,  90, 0);
    case 'front',  view(ax, 180, 0);
    case 'back',   view(ax,   0, 0);
    case 'top',    view(ax,   0, 90);
    case 'bottom', view(ax,   0, -90);
    case 'hero',   view(ax, -35, 22);
    otherwise
        warning('pf2:probe:plot:showHead3D:unknownView', ...
            'Unknown View preset ''%s''; using ''hero''.', char(v));
        view(ax, -35, 22);
end
end
