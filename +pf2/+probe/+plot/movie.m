function outPath = movie(data, biomarker, varargin)
% MOVIE Animate a biomarker over time on the probe/cortex, write MP4 or GIF
%
% Sweeps a hemoglobin biomarker through time and renders one topographic
% frame per time step, then assembles the frames into a movie. This turns a
% static activation map into the canonical "watch the hemodynamic response
% evolve on the cortex" figure used in talks and supplements. Frames are
% rendered with a single shared, global color scale so brightness is
% comparable across time, and each frame is stamped with its time (and the
% active marker label when one is present). Both a 3D cortical-surface
% projection (default) and a flat 2D probe heatmap are supported.
%
% Rendering reuses pf2.probe.project.biomarker (3D) or
% pf2.probe.plot.imageValues (2D); each frame is written through the
% headless-stable savePath path (exportgraphics, white background), so the
% function works under -batch without the getframe pitfalls that affect 3D
% off-screen capture.
%
% Reference:
%   Internal pf2 implementation.
%
% Syntax:
%   pf2.probe.plot.movie(processed, 'HbO')
%   pf2.probe.plot.movie(processed, 'HbO', 'savePath', 'hbo.mp4')
%   pf2.probe.plot.movie(processed, 'HbO', 'View', '2d', 'FPS', 10)
%   pf2.probe.plot.movie(processed, 'HbO', 'TimeRange', [0 30], 'NFrames', 60)
%   outPath = pf2.probe.plot.movie(processed, 'HbO', ...)
%
% Inputs:
%   data      - Processed fNIRS struct containing the biomarker field, a
%               .time vector, and a device with MNI coordinates (for 3D).
%   biomarker - Biomarker field name: 'HbO','HbR','HbTotal','HbDiff','CBSI'.
%
% Name-Value Parameters:
%   'savePath'   - Output movie path (default: '<biomarker>_movie.mp4').
%                  Extension selects the writer: .mp4 -> MPEG-4,
%                  .avi -> Motion JPEG AVI, .gif -> animated GIF.
%   'View'       - '3d' (default) cortical-surface projection, or '2d' flat
%                  probe heatmap.
%   'TimeRange'  - [t1 t2] seconds to animate (default: full recording).
%   'NFrames'    - Target number of frames (default: 60). The recording is
%                  decimated to approximately this many frames. Ignored when
%                  'FrameStep' is given.
%   'FrameStep'  - Explicit sample stride between frames (overrides NFrames).
%   'Window'     - Per-frame averaging window in seconds centered on the
%                  frame time (default: 0 = instantaneous sample). Smooths
%                  high-frequency flicker.
%   'FPS'        - Playback frame rate of the output (default: 15).
%   'Range'      - [lo hi] global color limits (default: symmetric
%                  [-m, m] with m = max |value| over the animated window).
%   'Colorbar'   - Colorbar label (default: data.units if present).
%   'ShowMarkers'- Stamp the active marker label onto frames whose time falls
%                  within a marker's duration (default: true; labels are shown
%                  only when markers and a marker dictionary are present).
%   'SaveWidth'  - Frame width in pixels (default: 700).
%   'SaveHeight' - Frame height in pixels (default: 560).
%   'Verbose'    - Print progress (default: true).
%
% Any other name-value pairs (e.g. 'initCamPosition', 'cmap', 'View'-specific
% options, 'interpolateType','sensitivity') are forwarded to the underlying
% renderer.
%
% Outputs:
%   outPath - Full path to the written movie file.
%
% Algorithm:
%   1. Extract the [T x C] biomarker matrix and select frame time indices
%      over TimeRange, decimated to ~NFrames (or by FrameStep).
%   2. Compute one global color range over all selected frames so colors are
%      comparable across time.
%   3. For each frame, reduce the biomarker to a [1 x C] vector (instantaneous
%      sample or Window-mean), render to a temporary PNG, and append it to the
%      movie writer (VideoWriter or GIF).
%
% Example:
%   data = pf2.import.sampleData();
%   proc = processFNIRS2(data);
%   pf2.probe.plot.movie(proc, 'HbO', 'TimeRange', [0 40], ...
%       'NFrames', 80, 'FPS', 20, 'savePath', 'hbo.mp4');
%
% Notes:
%   - Frame rendering reloads nothing per frame: the cortical mesh and the
%     geodesic distance matrix are cached on the reused axes (the renderer is
%     called with 'animated', true), so only the per-vertex colors change.
%   - GIF output is paletted (256 colors) and larger/lower-fidelity than MP4;
%     prefer MP4 for smooth gradients.
%
% See also: pf2.probe.plot.topo, pf2.probe.project.biomarker,
%           pf2.probe.plot.imageValues, pf2.data.plot.oxy

p = inputParser;
p.FunctionName = 'pf2.probe.plot.movie';
p.KeepUnmatched = true;
addRequired(p, 'data', @isstruct);
addRequired(p, 'biomarker', @(x) ischar(x) || isstring(x));
addParameter(p, 'savePath', '', @(x) ischar(x) || isstring(x));
addParameter(p, 'View', '3d', @(x) any(strcmpi(char(x), {'2d','3d'})));
addParameter(p, 'TimeRange', [], @(x) isempty(x) || (isnumeric(x) && numel(x) == 2));
addParameter(p, 'NFrames', 60, @(x) isnumeric(x) && isscalar(x) && x >= 2);
addParameter(p, 'FrameStep', [], @(x) isempty(x) || (isnumeric(x) && isscalar(x) && x >= 1));
addParameter(p, 'Window', 0, @(x) isnumeric(x) && isscalar(x) && x >= 0);
addParameter(p, 'FPS', 15, @(x) isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, 'Range', [], @(x) isempty(x) || (isnumeric(x) && numel(x) == 2));
addParameter(p, 'Colorbar', '', @(x) ischar(x) || isstring(x));
addParameter(p, 'ShowMarkers', true, @islogical);
addParameter(p, 'SaveWidth', 700, @(x) isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, 'SaveHeight', 560, @(x) isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, 'Verbose', true, @islogical);
parse(p, data, biomarker, varargin{:});

bio = char(p.Results.biomarker);
view3d = strcmpi(char(p.Results.View), '3d');

% Validate biomarker
if ~isfield(data, bio) || isempty(data.(bio))
    valid = {'HbO','HbR','HbTotal','HbDiff','CBSI'};
    present = valid(isfield(data, valid));
    error('pf2:probe:plot:movie:badBiomarker', ...
        'Biomarker ''%s'' not found in data. Available: %s', ...
        bio, strjoin(present, ', '));
end

M = data.(bio);                 % [T x C]
if ~isfield(data, 'time') || isempty(data.time)
    tvec = (1:size(M,1))';
else
    tvec = data.time(:);
end
nT = size(M, 1);

% --- Select frame time indices ---
tr = p.Results.TimeRange;
if isempty(tr)
    inWin = true(nT, 1);
else
    inWin = tvec >= min(tr) & tvec <= max(tr);
end
winIdx = find(inWin);
if isempty(winIdx)
    error('pf2:probe:plot:movie:emptyRange', ...
        'No samples in TimeRange [%.1f %.1f] s.', min(tr), max(tr));
end

if ~isempty(p.Results.FrameStep)
    step = round(p.Results.FrameStep);
else
    step = max(1, round(numel(winIdx) / p.Results.NFrames));
end
frameIdx = winIdx(1:step:end);
nFrames = numel(frameIdx);

% --- Per-frame value reduction (instantaneous or windowed mean) ---
% Reduce every frame once up front; reused for the global range and render.
halfWin = p.Results.Window / 2;
allVals = zeros(nFrames, size(M, 2));
for k = 1:nFrames
    allVals(k, :) = iReduceFrame(M, tvec, frameIdx(k), halfWin);
end

% --- Global color range over all rendered frames ---
rangeVals = p.Results.Range;
if isempty(rangeVals)
    m = max(abs(allVals(:)), [], 'omitnan');
    if ~isfinite(m) || m == 0, m = 1; end
    rangeVals = [-m, m];
else
    rangeVals = sort(rangeVals);
end

% Colorbar label
cbar = char(p.Results.Colorbar);
if isempty(cbar) && isfield(data, 'units') && ~isempty(data.units)
    cbar = char(string(data.units));
end

% Output path + writer selection
savePath = char(p.Results.savePath);
if isempty(savePath)
    savePath = [bio, '_movie.mp4'];
end
[outDir, outName, outExt] = fileparts(savePath);
if isempty(outExt), outExt = '.mp4'; savePath = [savePath, outExt]; end
if isempty(outDir), outDir = pwd; end
outPath = fullfile(outDir, [outName, outExt]);
isGif = strcmpi(outExt, '.gif');

% Marker dictionary for label overlay
markerInfo = iResolveMarkers(data, p.Results.ShowMarkers);

% Temp dir for per-frame PNGs (headless-stable render path)
tmpDir = tempname;
mkdir(tmpDir);
cleanupTmp = onCleanup(@() iCleanupDir(tmpDir));

% Reused figure/axes so the mesh + geodesic cache persist across frames
fig = figure('Visible', 'off', 'Color', 'w');
cleanupFig = onCleanup(@() iCloseFig(fig));
ax = axes('Parent', fig); %#ok<LAXES>

forward = iUnmatched(p.Unmatched);
% imageValues (2D) has no 'ax'/KeepUnmatched; forward only options it knows.
forward2d = iFilterNames(p.Unmatched, {'includeSS', 'Layout', 'saveDPI'});

% Open video writer (GIF handled per-frame via imwrite)
vw = [];
if ~isGif
    switch lower(outExt)
        case '.mp4',  profile = 'MPEG-4';
        case '.avi',  profile = 'Motion JPEG AVI';
        otherwise,    profile = 'MPEG-4';
    end
    vw = VideoWriter(outPath, profile); %#ok<TNMLP>
    cleanupVw = onCleanup(@() iCloseWriter(vw)); %#ok<NASGU>
    vw.FrameRate = p.Results.FPS;
    open(vw);
end

verbose = p.Results.Verbose;
if verbose
    fprintf('pf2.probe.plot.movie: rendering %d frames (%s, %s)...\n', ...
        nFrames, bio, char(p.Results.View));
end

% exportgraphics frame dimensions can vary by a few pixels across frames
% (colorbar/title width changes); lock all frames to the first frame's size.
targetSize = [];

for k = 1:nFrames
    vals = allVals(k, :);
    t = tvec(frameIdx(k));
    ttl = iFrameTitle(bio, t, markerInfo);

    framePng = fullfile(tmpDir, sprintf('frame_%05d.png', k));

    set(0, 'CurrentFigure', fig);

    if view3d
        % Make our reused axes current so the renderer's gca-based mesh and
        % geodesic-distance caches (and the getAsset cache) bind to it and
        % persist across frames; clear only the drawn content.
        set(fig, 'CurrentAxes', ax);
        cla(ax);
        delete(findall(fig, 'Type', 'ColorBar'));
        pf2.probe.project.biomarker(vals, data, ...
            'Range', rangeVals, 'titleString', ttl, 'colorbarStr', cbar, ...
            'ax', ax, 'animated', true, ...
            'savePath', framePng, 'saveWidth', p.Results.SaveWidth, ...
            'saveHeight', p.Results.SaveHeight, forward{:});
    else
        % imageValues runs clf(gcf) itself; it just needs fig to be current.
        pf2.probe.plot.imageValues(vals, data, rangeVals(1), rangeVals(2), ...
            ttl, cbar, ...
            'savePath', framePng, 'saveWidth', p.Results.SaveWidth, ...
            'saveHeight', p.Results.SaveHeight, forward2d{:});
    end

    img = iEnsureRGB(imread(framePng));
    if isempty(targetSize)
        targetSize = [size(img, 1), size(img, 2)];
    elseif ~isequal([size(img, 1), size(img, 2)], targetSize)
        img = imresize(img, targetSize);
    end

    if isGif
        iAppendGif(img, outPath, k == 1, 1 / p.Results.FPS);
    else
        writeVideo(vw, img);
    end

    if verbose && (mod(k, 10) == 0 || k == nFrames)
        fprintf('  frame %d/%d (t=%.1fs)\n', k, nFrames, t);
    end
end

if verbose
    fprintf('pf2.probe.plot.movie: wrote %s\n', outPath);
end

if nargout == 0
    clear outPath;
end

end

%%_Subfunctions_________________________________________________________

function vals = iReduceFrame(M, tvec, idx, halfWin)
% Reduce the biomarker matrix to a [1 x C] vector at a frame.
if halfWin <= 0
    vals = M(idx, :);
else
    t0 = tvec(idx);
    m = tvec >= (t0 - halfWin) & tvec <= (t0 + halfWin);
    vals = mean(M(m, :), 1, 'omitnan');
end
end

function info = iResolveMarkers(data, showMarkers)
% Build a lightweight marker table (Time/Duration/Label) for overlay, or [].
info = [];
if ~showMarkers, return; end
if ~isfield(data, 'markers') || isempty(data.markers), return; end
try
    mk = pf2_base.normalizeMarkers(data.markers);
catch
    return;
end
if isempty(mk) || ~ismember('Time', mk.Properties.VariableNames), return; end
info.Time = mk.Time;
if ismember('Duration', mk.Properties.VariableNames)
    info.Duration = mk.Duration;
else
    info.Duration = zeros(height(mk), 1);
end
% Prefer an explicit Label column; else resolve codes via the dictionary
labels = strings(height(mk), 1);
if ismember('Label', mk.Properties.VariableNames)
    labels = string(mk.Label);
else
    try
        dict = pf2.data.getMarkerDict(data);
        for r = 1:height(mk)
            hit = dict.Code == mk.Code(r);
            if any(hit)
                labels(r) = string(dict.Label(find(hit, 1)));
            else
                labels(r) = sprintf("code %g", mk.Code(r));
            end
        end
    catch
        labels = string(compose("code %g", mk.Code));
    end
end
info.Label = labels;
end

function ttl = iFrameTitle(bio, t, markerInfo)
% Compose the per-frame title with time and (optionally) the active marker.
ttl = sprintf('%s   t = %.1f s', bio, t);
if isempty(markerInfo), return; end
dur = markerInfo.Duration;
dur(dur <= 0) = 0;
active = t >= markerInfo.Time & t <= (markerInfo.Time + max(dur, 0));
% For zero-duration markers, flag the one nearest within 0.5 s
if ~any(active)
    near = abs(markerInfo.Time - t) <= 0.5 & markerInfo.Duration <= 0;
    active = near;
end
if any(active)
    lbl = markerInfo.Label(find(active, 1));
    if strlength(lbl) > 0
        ttl = sprintf('%s   [%s]', ttl, lbl);
    end
end
end

function iAppendGif(img, outPath, isFirst, delay)
% Append one RGB frame to an animated GIF.
img = iEnsureRGB(img);
[A, map] = rgb2ind(img, 256);
if isFirst
    imwrite(A, map, outPath, 'gif', 'LoopCount', Inf, 'DelayTime', delay);
else
    imwrite(A, map, outPath, 'gif', 'WriteMode', 'append', 'DelayTime', delay);
end
end

function img = iEnsureRGB(img)
% Coerce indexed/grayscale frames to RGB and even dimensions for video.
if ndims(img) == 2
    img = repmat(img, 1, 1, 3);
elseif size(img, 3) == 1
    img = repmat(img, 1, 1, 3);
elseif size(img, 3) == 4
    img = img(:, :, 1:3);
end
% MPEG-4 requires even frame dimensions; trim a row/column if odd.
sz = size(img);
if mod(sz(1), 2) == 1, img = img(1:end-1, :, :); end
if mod(sz(2), 2) == 1, img = img(:, 1:end-1, :); end
end

function c = iUnmatched(s)
% Convert an inputParser Unmatched struct to a name-value cell array.
fn = fieldnames(s);
c = cell(1, 2 * numel(fn));
for i = 1:numel(fn)
    c{2*i - 1} = fn{i};
    c{2*i}     = s.(fn{i});
end
end

function c = iFilterNames(s, allowed)
% Return a name-value cell of only the allowed fields present in struct s.
fn = fieldnames(s);
keep = fn(ismember(fn, allowed));
c = cell(1, 2 * numel(keep));
for i = 1:numel(keep)
    c{2*i - 1} = keep{i};
    c{2*i}     = s.(keep{i});
end
end

function iCloseWriter(vw)
if ~isempty(vw) && isvalid(vw)
    close(vw);
end
end

function iCloseFig(fig)
if isgraphics(fig)
    close(fig);
end
end

function iCleanupDir(d)
if exist(d, 'dir')
    rmdir(d, 's');
end
end
