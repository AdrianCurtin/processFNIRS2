function [L, A] = meshLaplacian(faces, varargin)
% MESHLAPLACIAN Graph Laplacian of a triangular surface mesh
%
% Builds the combinatorial (graph) Laplacian L = D - A of a triangulated
% surface, optionally restricted to a vertex subset. Used as a smoothness
% regularizer in cortically-constrained DOT reconstruction: penalizing
% ||L*x||^2 favours images that vary slowly across neighbouring vertices,
% matching the coarse spatial resolution of diffuse optical measurements.
%
% Syntax:
%   L = pf2_base.dot.meshLaplacian(faces)
%   [L, A] = pf2_base.dot.meshLaplacian(faces, 'Subset', idx)
%
% Inputs:
%   faces - [nF x 3] triangle vertex indices (1-based) into an nV-vertex mesh.
%
% Inputs (name-value):
%   'Subset' - Vertex indices to keep (default: all). Edges are induced on the
%              subset (an edge is kept only if both endpoints are in the
%              subset). L is then [numel(Subset) x numel(Subset)] in subset
%              order. Isolated subset vertices get a zero row (no smoothing).
%
% Outputs:
%   L - sparse graph Laplacian (symmetric, positive semidefinite). Row sums 0.
%   A - sparse binary adjacency used to build L (same indexing as L).
%
% Algorithm:
%   Each triangle contributes its three edges to an undirected adjacency A;
%   D = diag(sum(A)); L = D - A. With a subset, A is the induced subgraph.
%
% Example:
%   mesh = pf2_base.dot.corticalMesh();
%   cov  = pf2.probe.forward.coverage(proc);
%   idx  = find(cov > 0.05);
%   L    = pf2_base.dot.meshLaplacian(mesh.faces, 'Subset', idx);
%
% See also: pf2_base.dot.reconstructImage, pf2.probe.dot.reconstruct

p = inputParser;
addParameter(p, 'Subset', [], @(x) isempty(x) || (isnumeric(x) && isvector(x)));
parse(p, varargin{:});
subset = p.Results.Subset(:);

nV = max(faces(:));

% Undirected edges from the three triangle sides.
e = [faces(:, [1 2]); faces(:, [2 3]); faces(:, [3 1])];
e = sort(e, 2);
e = unique(e, 'rows');

A = sparse([e(:,1); e(:,2)], [e(:,2); e(:,1)], 1, nV, nV);
A = spones(A);                          % binary (collapse multiplicities)

if ~isempty(subset)
    A = A(subset, subset);
end

d = full(sum(A, 2));
L = spdiags(d, 0, size(A,1), size(A,1)) - A;
end
