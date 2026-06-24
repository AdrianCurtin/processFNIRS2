function img = matcapTexture(name, sz)
% MATCAPTEXTURE Procedurally generate a material-capture (matcap) image
%
% Returns a square RGB image of a lit unit sphere viewed head-on. A matcap
% bakes a full lighting+material response into a texture that surface
% renderers sample by the view-space normal direction, reproducing the
% polished "clay"/"porcelain"/"metal" surface look popularized by MRIcroGL
% and Surfice without any per-frame lighting math. Generating it
% analytically (rather than shipping a photographed sphere) avoids any
% image-licensing constraints and lets the material be tuned.
%
% The sphere is shaded with a two-light (key + fill) Blinn-Phong model plus
% a subtle Fresnel rim. Pixels outside the unit disk are filled with the
% silhouette (z=0) response so bilinear sampling near the rim never grabs a
% background hole. Materials are deliberately near-neutral in hue so that
% multiplying the matcap into a surface's own vertex colors tints correctly
% (the matcap supplies shading, the vertex color supplies hue).
%
% Syntax:
%   img = pf2_base.plot.matcapTexture()              % 'clay', 256 px
%   img = pf2_base.plot.matcapTexture(name)
%   img = pf2_base.plot.matcapTexture(name, sz)
%
% Inputs:
%   name - Material preset (default 'clay'): 'clay', 'porcelain', 'matte',
%          'glossy', 'pewter', 'jade'.
%   sz   - Image side length in pixels (default 256).
%
% Outputs:
%   img - [sz x sz x 3] double RGB in [0,1].
%
% Example:
%   img = pf2_base.plot.matcapTexture('porcelain', 256);
%   imshow(img);
%
% See also: pf2_base.plot.matcapShade, pf2_base.plot.meshCurvature

    if nargin < 1 || isempty(name), name = 'clay'; end
    if nargin < 2 || isempty(sz),   sz = 256;      end

    % Material parameters: [baseGray ka kd ks shininess rim frontFill], tint.
    % frontFill is a gentle headlight (brightens camera-facing normals) so the
    % surface never reads too dark in head-on / frontal views.
    switch lower(char(name))
        case 'clay'
            base = 0.80; ka = 0.52; kd = 0.78; ks = 0.12; sh = 8;  rim = 0.10; ff = 0.22; tint = [1 1 1];
        case 'porcelain'
            base = 0.88; ka = 0.56; kd = 0.74; ks = 0.26; sh = 22; rim = 0.14; ff = 0.22; tint = [1 1 1];
        case 'matte'
            base = 0.82; ka = 0.56; kd = 0.78; ks = 0.00; sh = 1;  rim = 0.04; ff = 0.20; tint = [1 1 1];
        case 'glossy'
            base = 0.80; ka = 0.40; kd = 0.78; ks = 0.50; sh = 42; rim = 0.18; ff = 0.18; tint = [1 1 1];
        case 'pewter'
            base = 0.64; ka = 0.40; kd = 0.60; ks = 0.55; sh = 30; rim = 0.20; ff = 0.18; tint = [0.96 0.97 1.0];
        case 'jade'
            base = 0.72; ka = 0.46; kd = 0.74; ks = 0.30; sh = 26; rim = 0.16; ff = 0.20; tint = [0.80 1.0 0.86];
        otherwise
            error('pf2_base:plot:matcapTexture:badName', ...
                'Unknown matcap material ''%s''.', char(name));
    end

    % Pixel grid in [-1,1]; +y up (image row 1 is top, so flip y).
    ax1 = linspace(-1, 1, sz);
    [x, yTop] = meshgrid(ax1, ax1);
    y = -yTop;
    r2 = x.^2 + y.^2;
    inside = r2 <= 1;

    % Sphere normal; outside the disk, clamp to the silhouette direction.
    z = sqrt(max(0, 1 - r2));
    rr = sqrt(r2); rr(rr == 0) = 1;
    nx = x;  ny = y;  nz = z;
    nx(~inside) = x(~inside) ./ rr(~inside);
    ny(~inside) = y(~inside) ./ rr(~inside);
    nz(~inside) = 0;

    % Lights (view space): key from upper-left-front, dim fill from lower-right.
    L1 = [-0.40, 0.50, 0.75]; L1 = L1 / norm(L1);
    L2 = [ 0.50,-0.25, 0.60]; L2 = L2 / norm(L2); f2 = 0.35;
    Vd = [0 0 1];                              % view direction (toward camera)

    dot1 = max(nx*L1(1) + ny*L1(2) + nz*L1(3), 0);
    dot2 = max(nx*L2(1) + ny*L2(2) + nz*L2(3), 0);

    H1 = (L1 + Vd); H1 = H1 / norm(H1);
    spec1 = max(nx*H1(1) + ny*H1(2) + nz*H1(3), 0).^sh;

    ndv = max(nx*Vd(1) + ny*Vd(2) + nz*Vd(3), 0);
    fres = (1 - ndv).^3;                       % Fresnel-ish rim

    lum = ka + kd*(dot1 + f2*dot2) + ff*ndv;   % ambient + key/fill + headlight
    lum = base * lum + rim * fres;             % + rim
    img = cat(3, lum*tint(1), lum*tint(2), lum*tint(3)) + ks * spec1;  % specular is white

    img = min(max(img, 0), 1);
end
