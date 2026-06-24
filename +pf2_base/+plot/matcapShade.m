function rgb = matcapShade(N, ax, img)
% MATCAPSHADE Sample a matcap texture by view-space normals -> per-vertex RGB
%
% Implements material-capture (matcap) shading for a MATLAB patch: each
% vertex's outward normal is rotated into the current camera frame and its
% screen-plane (x,y) components index a lit-sphere image, exactly as the
% MRIcroGL / Surfice matcap shaders do (uv = n.xy*0.5 + 0.5). The sampled
% RGB is the surface shading for that vertex under the matcap's baked
% material and lighting. Set the patch's FaceLighting to 'none' when using
% the result, since the matcap already contains the lighting.
%
% Because the mapping uses camera-space normals, the result is
% VIEW-DEPENDENT: recompute it whenever the camera moves (e.g. before each
% frame of a movie or after changing the view).
%
% Syntax:
%   rgb = pf2_base.plot.matcapShade(N, ax, img)
%
% Inputs:
%   N   - [nV x 3] outward unit vertex normals in world (data) coordinates.
%   ax  - Axes handle whose CameraPosition/Target/UpVector define the view.
%   img - [H x W x 3] matcap image in [0,1] (see matcapTexture).
%
% Outputs:
%   rgb - [nV x 3] per-vertex RGB in [0,1] to assign as FaceVertexCData
%         (optionally multiplied by a base/overlay color first).
%
% Example:
%   N   = pf2_base.plot.vertexNormals(V, F);
%   img = pf2_base.plot.matcapTexture('clay');
%   rgb = pf2_base.plot.matcapShade(N, gca, img);
%   set(patchHandle, 'FaceVertexCData', rgb, 'FaceColor','interp', ...
%                    'FaceLighting','none');
%
% See also: pf2_base.plot.matcapTexture, pf2_base.plot.vertexNormals

    % Camera basis in world coordinates.
    pos = get(ax, 'CameraPosition');
    tgt = get(ax, 'CameraTarget');
    up0 = get(ax, 'CameraUpVector');

    fwd = tgt - pos;                       % forward, into the screen
    fwd = fwd / norm(fwd);
    right = cross(fwd, up0);
    if norm(right) < 1e-10                  % up parallel to view (e.g. top/bottom)
        % Choose a reference axis not aligned with the view direction so the
        % basis stays well-conditioned and the lighting does not snap.
        if abs(fwd(3)) < 0.9
            right = cross(fwd, [0 0 1]);
        else
            right = cross(fwd, [0 1 0]);
        end
        if norm(right) < 1e-10, right = [1 0 0]; end
    end
    right = right / norm(right);
    up = cross(right, fwd);                % orthonormal true up

    % View-space normal components: x=right, y=up, z=toward viewer (-fwd).
    nxv = N * right(:);
    nyv = N * up(:);
    nzv = N * (-fwd(:));

    % uv in [0,1]; image row 1 is top, so flip v.
    H = size(img, 1); W = size(img, 2);
    u = (nxv * 0.5 + 0.5) * (W - 1) + 1;
    v = (1 - (nyv * 0.5 + 0.5)) * (H - 1) + 1;
    u = min(max(u, 1), W);
    v = min(max(v, 1), H);

    rgb = zeros(size(N, 1), 3);
    for c = 1:3
        rgb(:, c) = interp2(img(:, :, c), u, v, 'linear');
    end

    % Back faces (normal pointing away from camera) get a desaturated, dimmed
    % response so the occasional rear-facing vertex on a closed cortex mesh
    % does not flash a bright silhouette color through the surface.
    back = nzv < 0;
    if any(back)
        g = mean(rgb(back, :), 2);
        rgb(back, :) = 0.55 * [g g g];
    end
end
