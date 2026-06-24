function [ao, concavity] = meshCurvature(V, F, N, varargin)
% MESHCURVATURE Per-vertex curvature and an ambient-occlusion shading weight
%
% Estimates discrete surface concavity (a mean-curvature proxy) at every
% vertex and converts it into a per-vertex multiplicative shading weight in
% (0, 1] that darkens sulci (concave crevices) and leaves gyral crowns near
% full brightness. Baking this weight into a surface's vertex colors
% reproduces the soft "ambient occlusion in the sulci" look that makes a
% cortical render read as a real, dimensional brain rather than a smooth
% blob. The weight is view-independent, so it is computed once and reused
% across camera poses.
%
% The concavity at vertex i is the projection of the umbrella (uniform
% Laplacian) vector onto the outward normal: vertices whose neighbours sit
% outward relative to them (sulci) score positive; gyral crowns score
% negative. This is a discrete approximation of mean curvature, robust
% enough for shading without a full cotangent-Laplacian.
%
% Syntax:
%   ao = pf2_base.plot.meshCurvature(V, F, N)
%   [ao, concavity] = pf2_base.plot.meshCurvature(V, F, N, 'Strength', 0.5)
%
% Inputs:
%   V - [nV x 3] vertex coordinates.
%   F - [nF x 3] triangle face indices (1-based).
%   N - [nV x 3] outward unit vertex normals (see vertexNormals).
%
% Name-Value Parameters:
%   'Strength' - Maximum darkening in [0,1] (default 0.5). Sulci floor at
%                (1 - Strength); 0 disables (ao all ones).
%   'Smooth'   - Number of neighbour-averaging passes applied to the
%                concavity field before shaping (default 2). Reduces
%                per-triangle noise for a cleaner result.
%   'Gyral'    - Amount of mild brightening applied to convex crowns in
%                [0,1] (default 0.12). 0 darkens only.
%
% Outputs:
%   ao        - [nV x 1] shading weight in (1-Strength, 1+Gyral]; multiply
%               into vertex RGB (sulci < 1 darken, gyral crowns may exceed 1
%               to brighten when Gyral > 0; callers should clamp RGB to [0,1]).
%   concavity - [nV x 1] raw concavity score (positive = sulcus).
%
% Example:
%   N  = pf2_base.plot.vertexNormals(V, F);
%   ao = pf2_base.plot.meshCurvature(V, F, N, 'Strength', 0.55);
%   cdata = baseGray .* ao;   % darker sulci, lighter gyri
%
% See also: pf2_base.plot.vertexNormals, pf2_base.plot.matcapShade

    ip = inputParser;
    ip.addParameter('Strength', 0.5, @(x) isnumeric(x) && isscalar(x) && x>=0 && x<=1);
    ip.addParameter('Smooth', 2, @(x) isnumeric(x) && isscalar(x) && x>=0);
    ip.addParameter('Gyral', 0.12, @(x) isnumeric(x) && isscalar(x) && x>=0 && x<=1);
    ip.parse(varargin{:});
    strength = ip.Results.Strength;
    nSmooth  = round(ip.Results.Smooth);
    gyral    = ip.Results.Gyral;

    nV = size(V, 1);

    % Symmetric vertex adjacency (each undirected edge counted both ways).
    e = [F(:,[1 2]); F(:,[2 3]); F(:,[3 1])];
    e = [e; fliplr(e)];
    src = e(:,1); dst = e(:,2);
    cnt = accumarray(src, 1, [nV 1]);
    cnt(cnt == 0) = 1;

    sumNbr = [accumarray(src, V(dst,1), [nV 1]), ...
              accumarray(src, V(dst,2), [nV 1]), ...
              accumarray(src, V(dst,3), [nV 1])];
    meanNbr = sumNbr ./ cnt;

    % Umbrella vector projected on the normal -> signed concavity.
    concavity = sum((meanNbr - V) .* N, 2);

    % Optional smoothing of the scalar field over the same adjacency.
    for s = 1:nSmooth
        sm = accumarray(src, concavity(dst), [nV 1]) ./ cnt;
        concavity = 0.5 * concavity + 0.5 * sm;
    end

    if strength == 0
        ao = ones(nV, 1);
        return;
    end

    % Robust normalization so a few extreme vertices don't flatten the rest.
    % Use the toolbox-free percentile shim so AO (now on every showcase render)
    % does not introduce a Statistics Toolbox dependency.
    scale = pf2_base.compat.prctile(abs(concavity), 95);
    if ~isfinite(scale) || scale == 0
        scale = max(abs(concavity));
        if scale == 0, scale = 1; end
    end
    cn = concavity / scale;                 % ~[-1,1] for the bulk of vertices

    sulcus = min(max(cn, 0), 1);            % concave amount in [0,1]
    gyrus  = min(max(-cn, 0), 1);           % convex amount in [0,1]

    % Smoothstep shaping for a soft falloff.
    sulcus = sulcus .* sulcus .* (3 - 2 * sulcus);
    gyrus  = gyrus  .* gyrus  .* (3 - 2 * gyrus);

    ao = 1 - strength * sulcus + gyral * gyrus;
    ao = min(max(ao, 1 - strength), 1 + gyral);
end
