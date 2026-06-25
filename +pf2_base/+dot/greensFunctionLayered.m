function phi = greensFunctionLayered(R, optodePos, normal, layers, centroid, headRadius)
% GREENSFUNCTIONLAYERED Diffusion Green's function through a layered head
%
% Continuous-wave fluence at field points R from a surface optode, accounting
% for a depth-layered medium (scalp/skull/CSF/gray) via ray-segmented effective
% attenuation. It keeps the semi-infinite image-source geometry of the
% homogeneous solution but replaces the single exponential decay exp(-mueff*r)
% with exp(-integral mueff(s) ds) along each source-to-field ray, so light
% crossing the low-absorption CSF layer penetrates deeper. This is a documented
% APPROXIMATION to a full layered diffusion solution (the rigorous two-layer
% steady-state form of Kienle et al. 1998 is the future path); it captures the
% first-order effect of layering on cortical sensitivity at low cost.
%
% Syntax:
%   phi = pf2_base.dot.greensFunctionLayered(R, optodePos, normal, layers, ...
%             centroid, headRadius)
%
% Inputs:
%   R          - [N x 3] field points (mm).
%   optodePos  - [1 x 3] optode location on the scalp shell (mm).
%   normal     - [1 x 3] outward unit surface normal at the optode.
%   layers     - layer struct array from pf2_base.dot.layeredHeadModel.
%   centroid   - [1 x 3] head centroid; depth is measured radially from it.
%   headRadius - scalp shell radius (mm); depth(p) = headRadius - |p-centroid|.
%
% Outputs:
%   phi - [N x 1] fluence (consistent arbitrary units), >= 0.
%
% Algorithm:
%   Source burial z0 and extrapolated boundary zb use the surface (scalp)
%   layer. Real and image sources are placed as in the homogeneous case. For
%   each field point the attenuation to the real/image source is the mean
%   effective attenuation sampled along the ray times the path length; the
%   diffusion prefactor uses the field point's local layer D. Distances are
%   floored at the surface-layer transport mean free path.
%
% References:
%   Kienle, A. et al. (1998). Noninvasive determination of the optical
%     properties of two-layered turbid media. Applied Optics, 37(4), 779-791.
%     DOI: 10.1364/AO.37.000779
%   Custo, A. et al. (2006). Effective scattering coefficient of the cerebral
%     spinal fluid in adult head models. Applied Optics, 45(19), 4747-4755.
%     DOI: 10.1364/AO.45.004747
%
% Example:
%   layers = pf2_base.dot.layeredHeadModel();
%   mesh = pf2_base.dot.corticalMesh();
%   phi = pf2_base.dot.greensFunctionLayered(mesh.vertices, [0 80 0], ...
%       [0 1 0], layers, mesh.centroid, 90);
%
% See also: pf2_base.dot.greensFunction, pf2_base.dot.layeredHeadModel

n = normal(:)'; nn = norm(n);
if nn < eps
    error('pf2:dot:greensFunctionLayered:degenerateNormal', 'Zero-length normal.');
end
n = n / nn;

surf = layers(1);                         % scalp layer sets z0/zb
Reff = 0.493;
z0 = 1 / surf.musp;
zb = 2 * surf.D * (1 + Reff) / (1 - Reff);

srcReal  = optodePos(:)' - z0 * n;
srcImage = optodePos(:)' + (z0 + 2 * zb) * n;

% Local diffusion coefficient at each field point (from its layer).
depthR = headRadius - vecnorm(R - centroid, 2, 2);
D_R = layerValue(depthR, layers, 'D');

att1 = rayAttenuation(srcReal,  R, layers, centroid, headRadius);
att2 = rayAttenuation(srcImage, R, layers, centroid, headRadius);
r1 = max(vecnorm(R - srcReal,  2, 2), z0);
r2 = max(vecnorm(R - srcImage, 2, 2), z0);

phi = (1 ./ (4 * pi * D_R)) .* (exp(-att1) ./ r1 - exp(-att2) ./ r2);
phi = max(phi, 0);
end

% ------------------------------------------------------------------------- %
function att = rayAttenuation(S, R, layers, centroid, headRadius)
% Integral of effective attenuation along each segment S->R(i): mean mueff
% sampled along the ray times the path length.
S = S(:)';
N = size(R, 1);
nSamp = 8;
ts = linspace(0, 1, nSamp);
meff = zeros(N, nSamp);
for k = 1:nSamp
    pts = S + ts(k) * (R - S);            % [N x 3]
    depth = headRadius - vecnorm(pts - centroid, 2, 2);
    meff(:, k) = layerValue(depth, layers, 'mueff');
end
meanMeff = mean(meff, 2);
pathLen = vecnorm(R - S, 2, 2);
att = meanMeff .* pathLen;
end

function v = layerValue(depth, layers, field)
% Per-point value of a layer field, selecting the layer that contains each
% depth (depths above 0 clamp to the surface layer).
depth = max(depth, 0);
v = repmat(layers(end).(field), size(depth));   % default: deepest layer
for L = numel(layers):-1:1
    in = depth >= layers(L).depthTop & depth < layers(L).depthBot;
    v(in) = layers(L).(field);
end
end
