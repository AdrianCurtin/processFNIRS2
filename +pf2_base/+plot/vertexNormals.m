function N = vertexNormals(V, F)
% VERTEXNORMALS Area-weighted per-vertex outward normals for a triangle mesh
%
% Computes smooth per-vertex normals by summing the normals of incident
% faces weighted by face area, then normalizing. Area weighting yields
% smoother shading than MATLAB's default face-derived normals and avoids
% the dark seams that appear on decimated cortical meshes under Gouraud
% lighting. Normals are flipped to point outward (away from the mesh
% centroid) so the surface lights correctly from outside.
%
% Syntax:
%   N = pf2_base.plot.vertexNormals(V, F)
%
% Inputs:
%   V - [nV x 3] vertex coordinates.
%   F - [nF x 3] triangle face indices (1-based) into V.
%
% Outputs:
%   N - [nV x 3] unit outward vertex normals.
%
% Example:
%   m = load('cerebro_mdl.mat');
%   N = pf2_base.plot.vertexNormals(m.cerebro_mdl.v, m.cerebro_mdl.f.v);
%
% See also: pf2_base.plot.meshCurvature, pf2_base.plot.matcapShade

    nV = size(V, 1);

    v1 = V(F(:,1), :);
    v2 = V(F(:,2), :);
    v3 = V(F(:,3), :);

    % Face normal = cross product of two edges. Its magnitude is twice the
    % triangle area, so accumulating the raw (un-normalized) cross product
    % already weights each face's contribution by its area.
    fn = cross(v2 - v1, v3 - v1, 2);

    N = zeros(nV, 3);
    for k = 1:3
        N(:,1) = N(:,1) + accumarray(F(:,k), fn(:,1), [nV 1]);
        N(:,2) = N(:,2) + accumarray(F(:,k), fn(:,2), [nV 1]);
        N(:,3) = N(:,3) + accumarray(F(:,k), fn(:,3), [nV 1]);
    end

    len = sqrt(sum(N.^2, 2));
    len(len == 0) = 1;       % isolated vertices keep a zero-length placeholder
    N = N ./ len;

    % Orient outward with a single GLOBAL sign. The mesh ships with
    % consistent face winding, so normals are uniformly outward or uniformly
    % inward; flipping per-vertex against a centroid-radial test would
    % corrupt legitimately inward-facing normals on a convoluted cortex
    % (deep sulci, medial walls). Decide by majority vote and flip all-or-none.
    c = mean(V, 1);
    radial = V - c;
    if sum(sum(N .* radial, 2)) < 0
        N = -N;
    end
end
