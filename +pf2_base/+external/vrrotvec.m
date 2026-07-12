function r = vrrotvec(a, b, options)
% VRROTVEC Axis-angle rotation that maps one 3-D vector onto another
%
% Computes the rotation needed to transform the 3-D vector A so that it points
% in the same direction as the 3-D vector B, returned as a 4-element
% axis-angle row vector [x y z theta]. The rotation axis is the normalized
% cross product of the two (unit) vectors and the angle is the angle between
% them. This is a clean-room implementation based on the standard relationship
% between two unit vectors and the axis-angle (Rodrigues) rotation, replacing
% the third-party Simulink 3D Animation function of the same name so the
% toolbox has no external dependency.
%
% Reference:
%   Rodrigues' rotation formula (standard result; see e.g. any rigid-body
%   kinematics text). The axis is u = (a x b)/|a x b| and the angle is
%   theta = atan2(|a x b|, a.b) for unit a, b.
%
% Syntax:
%   r = vrrotvec(a, b)
%   r = vrrotvec(a, b, options)
%
% Inputs:
%   a       - Source vector [3 x 1] or [1 x 3] real.
%   b       - Target vector [3 x 1] or [1 x 3] real.
%   options - Optional struct with field 'epsilon', the magnitude below which
%             a vector or cross product is treated as zero (default: 1e-12).
%
% Outputs:
%   r - Axis-angle rotation [1 x 4] = [ux uy uz theta]. The first three
%       elements are the unit rotation axis; theta is the rotation angle in
%       radians. For parallel inputs r = [0 0 0 0]; for antiparallel inputs an
%       arbitrary axis perpendicular to a is chosen with theta = pi.
%
% Algorithm:
%   1. Normalize a and b to unit vectors an, bn.
%   2. Compute c = an x bn and the angle theta = atan2(|c|, an.bn).
%   3. If |c| is non-negligible use axis = c/|c|; otherwise (parallel or
%      antiparallel) pick axis = 0 for theta ~ 0, or any unit vector
%      perpendicular to an for theta ~ pi.
%
% Example:
%   r = pf2_base.external.vrrotvec([0 0 1], [0 1 0]);   % -> [-1 0 0 pi/2]
%
% Notes:
%   - Using atan2 (rather than acos) keeps the angle numerically robust near
%     0 and pi.
%
% See also: pf2_base.external.vrrotvec2mat, cross, dot

if nargin < 2
    error('pf2_base:vrrotvec:nargin', 'Two input vectors are required.');
end

if ~isnumeric(a) || ~isreal(a) || numel(a) ~= 3
    error('pf2_base:vrrotvec:badInput', 'A must be a real 3-element vector.');
end
if ~isnumeric(b) || ~isreal(b) || numel(b) ~= 3
    error('pf2_base:vrrotvec:badInput', 'B must be a real 3-element vector.');
end

epsilon = 1e-12;
if nargin == 3
    if ~isstruct(options) || ~isfield(options, 'epsilon')
        error('pf2_base:vrrotvec:badOptions', ...
            'OPTIONS must be a struct with an ''epsilon'' field.');
    end
    if ~isnumeric(options.epsilon) || ~isreal(options.epsilon) || options.epsilon < 0
        error('pf2_base:vrrotvec:badOptions', 'OPTIONS.epsilon must be real >= 0.');
    end
    epsilon = options.epsilon;
end

an = normalizeVec(a(:).', epsilon);
bn = normalizeVec(b(:).', epsilon);

c = cross(an, bn);
nc = norm(c);
theta = atan2(nc, dot(an, bn));

if nc > epsilon
    axis = c / nc;
else
    % Parallel or antiparallel.
    if theta < epsilon
        % Same direction: no rotation, axis is arbitrary.
        axis = [0 0 0];
        theta = 0;
    else
        % Opposite direction (theta ~ pi): choose any unit vector
        % perpendicular to an.
        axis = perpendicular(an);
    end
end

r = [axis(:).', theta];

end

%%_Subfunctions_____________________________________________________________

function vn = normalizeVec(v, maxzero)
% NORMALIZEVEC Return a unit vector parallel to v
%
% Inputs:
%   v       - Input vector (any size)
%   maxzero - Norm threshold below which the result is all zeros
%
% Outputs:
%   vn - Unit vector v/|v|, or zeros(size(v)) when |v| <= maxzero

nv = norm(v);
if nv <= maxzero
    vn = zeros(size(v));
else
    vn = v / nv;
end

end

function p = perpendicular(u)
% PERPENDICULAR Return a unit vector orthogonal to u
%
% Inputs:
%   u - Unit (or non-zero) 3-element row vector
%
% Outputs:
%   p - Unit row vector with dot(p, u) ~ 0

% Cross u with whichever axis is least aligned with it for stability.
[~, idx] = min(abs(u));
e = [0 0 0];
e(idx) = 1;
p = cross(u, e);
p = p / norm(p);

end
