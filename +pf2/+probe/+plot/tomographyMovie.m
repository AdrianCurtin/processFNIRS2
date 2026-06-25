function outPath = tomographyMovie(data, varargin)
% TOMOGRAPHYMOVIE Animate a DOT image reconstruction over time on cortex
%
% Reconstructs a hemoglobin biomarker at a sequence of time points and writes a
% movie (MP4/AVI/GIF) of the evolving cortical image, masked to the montage's
% sensitivity field. The whole sequence shares one regularization and one
% global colour scale so frames are comparable.
%
% Syntax:
%   pf2.probe.plot.tomographyMovie(proc, 'savePath', 'dot.mp4')
%   pf2.probe.plot.tomographyMovie(proc, 'Biomarker', 'HbR', 'TimeRange', [0 40])
%   out = pf2.probe.plot.tomographyMovie(proc, 'NFrames', 80, 'FPS', 20)
%
% Inputs:
%   data - processed fNIRS struct with geometry.
%
% Inputs (name-value):
%   'Biomarker'  - Field to reconstruct/animate (default 'HbO').
%   'TimeRange'  - [t0 t1] seconds (default: whole recording).
%   'NFrames'    - Number of frames (default 60); the window is decimated.
%   'FPS'        - Output frame rate (default 15).
%   'savePath'   - Output path (default '<Biomarker>_dot_movie.mp4'). Extension
%                  picks the writer (.mp4/.avi/.gif).
%   'Range'      - [lo hi] fixed colour limits (default symmetric, global auto).
%   'Prior','ScalpRegression','DepthWeight','Lambda',... forward to
%   pf2.probe.dot.reconstruct; render options ('Style','initCamPosition','cmap')
%   forward to pf2.probe.project.tomography.
%
% Outputs:
%   outPath - the written movie path (suppressed if no output requested).
%
% Notes:
%   - Headless-stable: each frame is rendered to a PNG via the project.tomography
%     savePath path, then encoded — no getframe dependence.
%   - One lambda (from the peak-variance frame) and one colour scale across all
%     frames keep the animation consistent.
%
% Example:
%   pf2.probe.plot.tomographyMovie(proc, 'TimeRange', [0 30], ...
%       'NFrames', 60, 'FPS', 20, 'savePath', 'hbo_dot.mp4');
%
% See also: pf2.probe.dot.reconstruct, pf2.probe.project.tomography,
%           pf2.probe.plot.movie

p = inputParser;
p.KeepUnmatched = true;
addRequired(p, 'data', @isstruct);
addParameter(p, 'Biomarker', 'HbO', @(x) ischar(x) || isstring(x));
addParameter(p, 'TimeRange', [], @(x) isempty(x) || (isnumeric(x) && numel(x) == 2));
addParameter(p, 'NFrames', 60, @(x) isnumeric(x) && isscalar(x) && x >= 2);
addParameter(p, 'FPS', 15, @(x) isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, 'savePath', '', @(x) ischar(x) || isstring(x));
addParameter(p, 'Range', [], @(x) isempty(x) || (isnumeric(x) && numel(x) == 2));
addParameter(p, 'Verbose', false, @(x) islogical(x) && isscalar(x));
parse(p, data, varargin{:});
bm = char(p.Results.Biomarker);

reconNames = {'Prior','ScalpRegression','ScalpMethod','DepthWeight','Whiten', ...
    'Lambda','LambdaFraction','RegMethod','HighRes','ScalpOffset','MaxDistance', ...
    'Prune','MaskThreshold'};
reconArgs = pickPairs(p.Unmatched, reconNames, true);
renderArgs = pickPairs(p.Unmatched, reconNames, false);

% --- Frame time indices ----------------------------------------------------
t = data.time(:);
tr = p.Results.TimeRange;
if isempty(tr), tr = [t(1), t(end)]; end
inWin = find(t >= min(tr) & t <= max(tr));
if numel(inWin) < 2
    error('pf2:probe:plot:tomographyMovie:emptyWindow', ...
        'TimeRange selects fewer than 2 samples.');
end
nF = min(p.Results.NFrames, numel(inWin));
frameIdx = inWin(round(linspace(1, numel(inWin), nF)));
tvec = t(frameIdx);

% --- Reconstruct all frames at once (slim struct, shared lambda) -----------
slim = struct('time', t(frameIdx), 'device', data.device, ...
    'units', getfielddef(data, 'units', ''));
slim.(bm) = data.(bm)(frameIdx, :);
recon = pf2.probe.dot.reconstruct(slim, 'AllTimes', true, ...
    'Biomarkers', {bm}, reconArgs{:});
X = recon.(bm);                                  % [nF x nV], NaN outside mask

% Global symmetric colour scale.
rangeVals = p.Results.Range;
if isempty(rangeVals)
    m = max(abs(X(:)), [], 'omitnan');
    if ~isfinite(m) || m == 0, m = 1; end
    rangeVals = [-m, m];
end
rangeVals = sort(rangeVals);

% --- Writer setup ----------------------------------------------------------
savePath = char(p.Results.savePath);
if isempty(savePath), savePath = [bm, '_dot_movie.mp4']; end
[~, ~, outExt] = fileparts(savePath);
if isempty(outExt), outExt = '.mp4'; savePath = [savePath, outExt]; end
isGif = strcmpi(outExt, '.gif');
tmpDir = tempname; mkdir(tmpDir);
cleanupTmp = onCleanup(@() rmdir(tmpDir, 's')); %#ok<NASGU>

vw = [];
if ~isGif
    switch lower(outExt)
        case '.avi', profile = 'Motion JPEG AVI';
        otherwise,   profile = 'MPEG-4';
    end
    vw = VideoWriter(savePath, profile); %#ok<TNMLP>
    vw.FrameRate = p.Results.FPS;
    open(vw);
    closeVw = onCleanup(@() close(vw)); %#ok<NASGU>
end

fig = figure('Visible', 'off');
cleanupFig = onCleanup(@() close(fig)); %#ok<NASGU>
ax = axes('Parent', fig);
targetSize = [];

for k = 1:nF
    framePng = fullfile(tmpDir, sprintf('frame_%05d.png', k));
    frameRecon = recon;
    frameRecon.(bm) = X(k, :);
    set(0, 'CurrentFigure', fig);
    set(fig, 'CurrentAxes', ax);
    cla(ax);
    delete(findall(fig, 'Type', 'ColorBar'));
    pf2.probe.project.tomography(frameRecon, 'Biomarker', bm, ...
        'Range', rangeVals, 'ax', ax, 'animated', true, ...
        'titleString', sprintf('DOT %s   t = %.1f s', bm, tvec(k)), ...
        'savePath', framePng, renderArgs{:});

    img = ensureRGB(imread(framePng));
    if isempty(targetSize)
        targetSize = [size(img,1), size(img,2)];
    elseif ~isequal([size(img,1), size(img,2)], targetSize)
        img = imresize(img, targetSize);
    end
    if isGif
        appendGif(img, savePath, k == 1, 1 / p.Results.FPS);
    else
        writeVideo(vw, img);
    end
    if p.Results.Verbose && (mod(k,10)==0 || k==nF)
        fprintf('  frame %d/%d (t=%.1fs)\n', k, nF, tvec(k));
    end
end

outPath = savePath;
if nargout == 0, clear outPath; end
end

% ------------------------------------------------------------------------- %
function img = ensureRGB(img)
if size(img, 3) == 1, img = repmat(img, 1, 1, 3); end
if ~isa(img, 'uint8'), img = im2uint8(img); end
end

function appendGif(img, outPath, isFirst, delay)
[ind, cm] = rgb2ind(img, 256);
if isFirst
    imwrite(ind, cm, outPath, 'gif', 'LoopCount', Inf, 'DelayTime', delay);
else
    imwrite(ind, cm, outPath, 'gif', 'WriteMode', 'append', 'DelayTime', delay);
end
end

function v = getfielddef(s, f, dflt)
if isfield(s, f), v = s.(f); else, v = dflt; end
end

function c = pickPairs(s, names, keep)
fn = fieldnames(s);
if keep, fn = fn(ismember(fn, names)); else, fn = fn(~ismember(fn, names)); end
c = cell(1, 2 * numel(fn));
for i = 1:numel(fn)
    c{2*i - 1} = fn{i};
    c{2*i}     = s.(fn{i});
end
end
