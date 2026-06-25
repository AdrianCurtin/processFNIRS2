function N = surfaceNormals(pts, V, centroid, varargin)
% SURFACENORMALS Per-point outward surface normals from a reference mesh
%
% Estimates the local outward surface normal at each query point (e.g. an
% optode) by fitting a plane to its nearest mesh vertices and orienting the
% plane normal away from the mesh centroid. Unlike a radial (point - centroid)
% direction, this follows the true local curvature of the head — important for
% frontal/temporal montages where the surface normal is NOT radial from the
% brain centroid (the forehead is flat and tilted, so a radial normal mis-aims
% the photon-diffusion source and biases reconstructed depth/position).
%
% Syntax:
%   N = pf2_base.dot.surfaceNormals(pts, V, centroid)
%   N = pf2_base.dot.surfaceNormals(pts, V, centroid, 'K', 150)
%
% Inputs:
%   pts      - [M x 3] query points (mm), e.g. optode positions.
%   V        - [P x 3] reference surface vertices (mm), e.g. the cortical mesh.
%   centroid - [1 x 3] mesh centroid; used only to orient normals outward.
%
% Inputs (name-value):
%   'K' - Number of nearest vertices for the local plane fit (default 150).
%         Larger = smoother (more regional) normals; smaller = more local.
%
% Outputs:
%   N - [M x 3] outward unit normals, one per query point.
%
% Algorithm:
%   For each point: take its K nearest mesh vertices, form their covariance,
%   and take the eigenvector of the smallest eigenvalue as the plane normal
%   (total-least-squares plane fit). Flip it if it points toward the centroid
%   so all normals face outward.
%
% Example:
%   mesh = pf2_base.dot.corticalMesh();
%   geom = pf2_base.dot.channelGeometry(proc.device);
%   nS = pf2_base.dot.surfaceNormals(geom.src, mesh.vertices, mesh.centroid);
%
% See also: pf2_base.dot.sensitivityMatrix, pf2_base.dot.corticalMesh

p = inputParser;
addParameter(p, 'K', 150, @(x) isnumeric(x) && isscalar(x) && x >= 3);
parse(p, varargin{:});
K = min(p.Results.K, size(V, 1));

M = size(pts, 1);
N = zeros(M, 3);
for i = 1:M
    d2 = sum((V - pts(i, :)).^2, 2);
    [~, idx] = mink(d2, K);
    P = V(idx, :);
    Pc = P - mean(P, 1);
    C = Pc' * Pc;
    [vec, val] = eig((C + C') / 2);
    [~, j] = min(real(diag(val)));
    n = real(vec(:, j))';
    if dot(n, pts(i, :) - centroid) < 0   % orient outward
        n = -n;
    end
    nn = norm(n);
    if nn < eps, n = pts(i, :) - centroid; nn = norm(n); end  % degenerate fallback
    N(i, :) = n / max(nn, eps);
end
end
