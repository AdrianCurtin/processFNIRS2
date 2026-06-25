function [A, info] = sensitivityMatrix(geom, mesh, props, varargin)
% SENSITIVITYMATRIX Photon-measurement-density (PMDF) forward operator for DOT
%
% Builds the channel-by-vertex sensitivity matrix A relating an absorption
% change at each cortical vertex to the change in each channel's measured
% optical density. Each row is the photon-measurement-density function (the
% "banana") of a source-detector pair, formed from the product of the two
% optode Green's functions normalised by the baseline source-detector flux
% (the Rytov/adjoint sensitivity; Arridge 1995).
%
% Syntax:
%   A = pf2_base.dot.sensitivityMatrix(geom, mesh, props)
%   [A, info] = pf2_base.dot.sensitivityMatrix(geom, mesh, props, 'Prune', 1e-3)
%
% Inputs:
%   geom  - channel geometry struct from `pf2_base.dot.channelGeometry`
%           (.src, .det [nCh x 3], .mid).
%   mesh  - cortical mesh struct from `pf2_base.dot.corticalMesh`
%           (.vertices [nV x 3], .centroid).
%   props - single-wavelength optical properties (scalar .D, .mueff, .musp)
%           from `pf2_base.dot.opticalProperties` (use one wavelength).
%
% Inputs (name-value):
%   'Prune'       - Relative threshold; per-row entries below Prune*max(row)
%                   are zeroed to sparsify (default 1e-3). 0 disables.
%   'MaxDistance' - Discard vertices farther than this (mm) from every optode
%                   before evaluation (default Inf; bounds compute on large
%                   meshes). Pruned vertices get sensitivity 0.
%   'Normalize'   - 'pmdf' (default) divides each row by the baseline
%                   source-detector flux so channels are comparable; 'none'
%                   leaves the raw Green's-function product.
%   'ScalpOffset' - Push each optode this far (mm) outward along its own normal
%                   before evaluation (default 12), so optodes sit on a scalp
%                   shell above the cortex rather than on it. The atlas
%                   registration compresses the scalp-cortex gap; this restores
%                   a realistic measurement depth. 0 disables.
%   'NormalMode'  - 'surface' (default) fits per-optode normals to the local
%                   cortical-mesh patch (faithful for frontal/temporal montages,
%                   where the surface normal is NOT radial from the brain
%                   centroid); 'radial' uses the centroid direction (spherical-
%                   head approximation). Drives both the push and the source
%                   orientation.
%
% Outputs:
%   A    - [nCh x nV] sensitivity matrix (sparse). A(c,v) >= 0.
%   info - struct: .vertexMask (vertices retained), .normalize, .prune,
%          .rowMax (per-channel peak sensitivity before pruning).
%
% Algorithm:
%   For channel c with source s, detector d:
%     n_s, n_d = per-optode outward normals (local surface fit, or radial)
%     Gs(v) = greensFunction(v; s, n_s),  Gd(v) = greensFunction(v; d, n_d)
%     G0    = greensFunction(d; s, n_s)            (baseline flux at detector)
%     A(c,v) = Gs(v) .* Gd(v) / G0                 (PMDF normalisation)
%   'surface' normals follow the true local curvature of the head; 'radial'
%   assumes a sphere and mis-aims the source for frontal/temporal optodes.
%
% References:
%   Arridge, S. R. (1995). Photon-measurement density functions. Part I:
%     Analytical forms. Applied Optics, 34(31), 7395-7409.
%     DOI: 10.1364/AO.34.007395
%
% Example:
%   geom  = pf2_base.dot.channelGeometry(proc.device);
%   mesh  = pf2_base.dot.corticalMesh();
%   props = pf2_base.dot.opticalProperties(800);
%   A = pf2_base.dot.sensitivityMatrix(geom, mesh, props);
%
% See also: pf2_base.dot.greensFunction, pf2_base.dot.reconstructImage

p = inputParser;
addParameter(p, 'Prune', 1e-3, @(x) isnumeric(x) && isscalar(x) && x >= 0);
addParameter(p, 'MaxDistance', Inf, @(x) isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, 'Normalize', 'pmdf', @(x) any(strcmpi(x, {'pmdf','none'})));
addParameter(p, 'ScalpOffset', 12, @(x) isnumeric(x) && isscalar(x) && x >= 0);
addParameter(p, 'HeadModel', 'homogeneous', @(x) any(strcmpi(x, {'homogeneous','layered'})));
addParameter(p, 'Layers', [], @(x) isempty(x) || isstruct(x));
addParameter(p, 'NormalMode', 'surface', @(x) any(strcmpi(x, {'surface','radial'})));
parse(p, varargin{:});
prune = p.Results.Prune;
maxDist = p.Results.MaxDistance;
normalize = lower(p.Results.Normalize);
scalpOffset = p.Results.ScalpOffset;
headModel = lower(p.Results.HeadModel);
normalMode = lower(p.Results.NormalMode);

if ~(isscalar(props.D) && isscalar(props.mueff) && isscalar(props.musp))
    error('pf2:dot:sensitivityMatrix:multiWavelength', ...
        ['Pass single-wavelength optical properties (scalar D/mueff/musp). ' ...
         'Call opticalProperties with one wavelength.']);
end

V = mesh.vertices;
nV = size(V, 1);
nCh = size(geom.src, 1);
centroid = mesh.centroid;

% Per-optode outward normals. 'surface' fits the local cortical-mesh patch
% (faithful for frontal/temporal montages where the surface normal is not
% radial from the brain centroid); 'radial' uses the centroid direction.
if strcmp(normalMode, 'surface')
    srcN = pf2_base.dot.surfaceNormals(geom.src, V, centroid);
    detN = pf2_base.dot.surfaceNormals(geom.det, V, centroid);
else
    srcN = unitRows(geom.src - centroid);
    detN = unitRows(geom.det - centroid);
end

% Push optodes outward onto a scalp shell ALONG their own normal so the
% sensitivity banana sits at a realistic cortical depth (the atlas registration
% otherwise places optodes on the cortical surface).
srcPos = geom.src + scalpOffset * srcN;
detPos = geom.det + scalpOffset * detN;

% Layered head model: scalp shell radius + per-layer optical profile.
layered = strcmp(headModel, 'layered');
if layered
    layers = p.Results.Layers;
    if isempty(layers), layers = pf2_base.dot.layeredHeadModel(); end
    headRadius = mean(vecnorm([srcPos; detPos] - centroid, 2, 2));
end

% Optional distance gate: drop vertices far from all optodes.
vmask = true(nV, 1);
if isfinite(maxDist)
    optAll = [srcPos; detPos];
    dmin = inf(nV, 1);
    for k = 1:size(optAll, 1)
        dmin = min(dmin, vecnorm(V - optAll(k, :), 2, 2));
    end
    vmask = dmin <= maxDist;
end
Vk = V(vmask, :);

D = props.D; mueff = props.mueff; musp = props.musp;
if layered
    g = @(pts, opt, nrm) pf2_base.dot.greensFunctionLayered( ...
        pts, opt, nrm, layers, centroid, headRadius);
else
    g = @(pts, opt, nrm) pf2_base.dot.greensFunction(pts, opt, nrm, D, mueff, musp);
end

rows = cell(nCh, 1);
cols = cell(nCh, 1);
vals = cell(nCh, 1);
rowMax = zeros(nCh, 1);
vkIdx = find(vmask);

for c = 1:nCh
    s = srcPos(c, :);
    d = detPos(c, :);
    nS = srcN(c, :); nD = detN(c, :);         % per-optode outward normals
    Gs = g(Vk, s, nS);
    Gd = g(Vk, d, nD);
    a = Gs .* Gd;
    if strcmp(normalize, 'pmdf')
        G0 = g(d, s, nS);                      % baseline flux at detector
        a = a / max(G0, eps);
    end
    rowMax(c) = max(a);
    if prune > 0 && rowMax(c) > 0
        keep = a >= prune * rowMax(c);
    else
        keep = a > 0;
    end
    idx = find(keep);
    rows{c} = repmat(c, numel(idx), 1);
    cols{c} = vkIdx(idx);
    vals{c} = a(idx);
end

A = sparse(vertcat(rows{:}), vertcat(cols{:}), vertcat(vals{:}), nCh, nV);

info = struct('vertexMask', vmask, 'normalize', normalize, ...
    'prune', prune, 'rowMax', rowMax);
end

function u = unitRows(X)
% Row-wise unit vectors (radial normals when X = pos - centroid).
nrm = vecnorm(X, 2, 2);
nrm(nrm < eps) = eps;
u = X ./ nrm;
end
