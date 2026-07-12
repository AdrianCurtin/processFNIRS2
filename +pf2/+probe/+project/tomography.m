function [h, imgOut] = tomography(recon, varargin)
% TOMOGRAPHY Render a DOT image reconstruction on the cortical surface
%
% Paints a vertex-space hemoglobin reconstruction (from
% `pf2.probe.dot.reconstruct`) directly onto the MNI cortical surface, masked
% to the montage's optical-sensitivity field so unsupported cortex stays gray.
% Uses a signed diverging colormap and the shared 3D render/headless-save
% machinery of `interpolateValues3D`.
%
% Syntax:
%   pf2.probe.project.tomography(recon)
%   pf2.probe.project.tomography(recon, 'Biomarker', 'HbR')
%   [h, imgOut] = pf2.probe.project.tomography(recon, 'savePath', 'dot.png')
%
% Inputs:
%   recon - reconstruction struct from pf2.probe.dot.reconstruct (carries the
%           per-vertex maps, mesh, coverage, and source device).
%
% Inputs (name-value):
%   'Biomarker' - Which reconstructed field to show (default 'HbO').
%   'TimeIndex' - For an AllTimes reconstruction ([T x nV]), the row to render
%                 (default: the peak-absolute-value frame).
%   'Range'     - [lo hi] colorbar limits (default symmetric auto from data).
%   'CoverageAlpha' - Fade overlay opacity by the coverage field (default true)
%                 so low-sensitivity cortex reads as faint (honest confidence).
%   'cmap'      - Diverging colormap name/array (default 'rdbu').
%   (Other pairs forward to interpolateValues3D, e.g. 'savePath', 'Style',
%    'initCamPosition', 'showSD'.)
%
% Outputs:
%   [h, imgOut] - axes handle and captured RGB image (for headless imwrite).
%
% Notes:
%   - Headless saving: use 'savePath' (the off-screen figure + saveas pattern
%     is unreliable for 3D renders).
%   - The reconstruction is masked to the sensitivity support; NaN vertices
%     render transparent over the gray cortex.
%
% Example:
%   recon = pf2.probe.dot.reconstruct(proc, 'Time', [10 30]);
%   pf2.probe.project.tomography(recon, 'Biomarker', 'HbO', ...
%       'savePath', 'dot_hbo.png');
%
% See also: pf2.probe.dot.reconstruct, pf2.probe.forward.coverage,
%           pf2.probe.plot.interpolateValues3D

p = inputParser;
p.KeepUnmatched = true;
addRequired(p, 'recon', @isstruct);
addParameter(p, 'Biomarker', 'HbO', @(x) ischar(x) || isstring(x));
addParameter(p, 'TimeIndex', [], @(x) isempty(x) || (isnumeric(x) && isscalar(x)));
addParameter(p, 'Range', [], @(x) isempty(x) || (isnumeric(x) && numel(x) == 2));
addParameter(p, 'CoverageAlpha', true, @(x) islogical(x) && isscalar(x));
addParameter(p, 'cmap', 'rdbu', @(x) ischar(x) || isstring(x) || isnumeric(x));
addParameter(p, 'titleString', '', @(x) ischar(x) || isstring(x));
parse(p, recon, varargin{:});
bm = char(p.Results.Biomarker);

if ~isfield(recon, bm)
    error('pf2:probe:project:tomography:noField', ...
        'recon has no reconstructed field ''%s''.', bm);
end
if ~isfield(recon, 'device')
    error('pf2:probe:project:tomography:noDevice', ...
        'recon lacks a device; reconstruct from a processed struct with geometry.');
end

% Select the frame to render.
vals = recon.(bm);
if size(vals, 1) > 1
    ti = p.Results.TimeIndex;
    if isempty(ti)
        [~, ti] = max(max(abs(vals), [], 2));
    end
    vals = vals(ti, :);
end
vals = vals(:);                       % [nV x 1], may contain NaN (masked)

% Symmetric diverging range.
rangeVals = p.Results.Range;
if isempty(rangeVals)
    m = max(abs(vals), [], 'omitnan');
    if ~isfinite(m) || m == 0, m = 1; end
    rangeVals = [-m, m];
end
rangeVals = sort(rangeVals);

% Per-vertex opacity: fade by coverage so faint support reads as low-confidence.
vertexAlpha = [];
if p.Results.CoverageAlpha && isfield(recon, 'coverage')
    cov = recon.coverage(:);
    mx = max(cov(cov > 0));
    if isempty(mx) || mx == 0, mx = 1; end       % guard fully-uncovered montage
    vertexAlpha = min(max(cov / mx, 0), 1);
end

% Dummy channel vector so interpolateValues3D enters its data branch; the
% actual colouring comes from VertexData. interpolateValues3D resolves
% geometry from a struct's `.probeinfo`.
nCh = size(recon.device.mniPositions(), 1);
dummy = zeros(1, nCh);
fNIRstruct = struct('probeinfo', recon.device.probeInfo);

fwd = unmatchedToVarargin(p.Unmatched);
colorbarStr = char(recon.units);
ttl = char(p.Results.titleString);
if isempty(ttl), ttl = sprintf('DOT %s', bm); end
[h, imgOut] = pf2.probe.plot.interpolateValues3D( ...
    dummy, fNIRstruct, rangeVals(1), rangeVals(2), ...
    ttl, colorbarStr, ...
    'VertexData', vals, 'VertexAlpha', vertexAlpha, ...
    'cmap', p.Results.cmap, 'useHighRes', true, ...
    fwd{:});
end

function c = unmatchedToVarargin(s)
fn = fieldnames(s);
c = cell(1, 2 * numel(fn));
for i = 1:numel(fn)
    c{2*i - 1} = fn{i};
    c{2*i}     = s.(fn{i});
end
end
