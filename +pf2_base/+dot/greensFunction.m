function phi = greensFunction(R, optodePos, normal, D, mueff, musp)
% GREENSFUNCTION Steady-state diffusion Green's function, semi-infinite medium
%
% Continuous-wave (DC) fluence at field points R due to an isotropic source on
% the surface of a semi-infinite homogeneous turbid medium, using the
% extrapolated-boundary image-source construction of Kienle & Patterson (1997).
% The real source is buried one transport mean free path below the surface and
% a negative image source is placed above the extrapolated boundary, enforcing
% the zero-fluence boundary condition. This is the building block of the
% photon-measurement-density (sensitivity) function used by DOT.
%
% Syntax:
%   phi = pf2_base.dot.greensFunction(R, optodePos, normal, D, mueff, musp)
%
% Inputs:
%   R         - [N x 3] field points (mm) at which to evaluate the fluence.
%   optodePos - [1 x 3] optode location on the medium surface (mm).
%   normal    - [1 x 3] outward unit surface normal at the optode (points away
%               from tissue). Need not be exactly unit length; it is normalised.
%   D         - scalar diffusion coefficient 1/(3*(mua+musp)) (mm).
%   mueff     - scalar effective attenuation sqrt(3*mua*(mua+musp)) (mm^-1).
%   musp      - scalar reduced scattering coefficient (mm^-1); sets the source
%               burial depth z0 = 1/musp.
%
% Outputs:
%   phi - [N x 1] fluence (arbitrary but internally consistent units). Values
%         are >= 0 inside the medium and decay toward 0 at the surface.
%
% Algorithm:
%   z0  = 1/musp                              (transport mean free path)
%   zb  = 2*D*(1+Reff)/(1-Reff)               (extrapolated boundary distance)
%   real source  : optodePos - z0*n           (into tissue, along -n)
%   image source : optodePos + (z0 + 2*zb)*n  (outside, along +n)
%   phi(r) = 1/(4*pi*D) [ exp(-mueff*r1)/r1 - exp(-mueff*r2)/r2 ]
%   with r1, r2 the distances to the real and image sources. Reff is the
%   diffuse internal-reflection coefficient for a tissue/air index ratio
%   (~1.4), taken as 0.493 (Kienle & Patterson).
%
% References:
%   Kienle, A. & Patterson, M. S. (1997). Improved solutions of the
%     steady-state and the time-resolved diffusion equations for reflectance
%     from a semi-infinite turbid medium. Journal of the Optical Society of
%     America A, 14(1), 246-254. DOI: 10.1364/JOSAA.14.000246
%
% Example:
%   props = pf2_base.dot.opticalProperties(800);
%   R = [0 0 -10; 0 0 -20];   % 10 and 20 mm below a surface optode at origin
%   phi = pf2_base.dot.greensFunction(R, [0 0 0], [0 0 1], ...
%       props.D, props.mueff, props.musp);
%
% See also: pf2_base.dot.sensitivityMatrix, pf2_base.dot.opticalProperties

n = normal(:)';
nn = norm(n);
if nn < eps
    error('pf2:dot:greensFunction:degenerateNormal', ...
        'Surface normal has near-zero length.');
end
n = n / nn;

Reff = 0.493;                      % diffuse reflection, tissue/air (n~1.4)
z0 = 1 / musp;                     % source burial depth
zb = 2 * D * (1 + Reff) / (1 - Reff);

srcReal  = optodePos(:)' - z0 * n;             % buried in tissue
srcImage = optodePos(:)' + (z0 + 2 * zb) * n;  % mirrored above boundary

r1 = vecnorm(R - srcReal,  2, 2);
r2 = vecnorm(R - srcImage, 2, 2);
% Floor distances at one transport mean free path: the diffusion
% approximation is invalid closer than ~z0, and this removes the 1/r
% singularity when a field point nearly coincides with the buried source.
r1 = max(r1, z0);
r2 = max(r2, z0);

phi = (1 / (4 * pi * D)) * (exp(-mueff .* r1) ./ r1 - exp(-mueff .* r2) ./ r2);
phi = max(phi, 0);   % clamp tiny negatives near the boundary
end
