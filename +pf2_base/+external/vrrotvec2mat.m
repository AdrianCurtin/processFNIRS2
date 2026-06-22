function m = vrrotvec2mat(r, options)
% VRROTVEC2MAT Convert an axis-angle rotation to a 3x3 rotation matrix
%
% Builds the 3-by-3 rotation matrix corresponding to the axis-angle rotation
% vector R = [x y z theta], where [x y z] is the rotation axis and theta the
% rotation angle in radians. The matrix is formed directly from Rodrigues'
% rotation formula. This is a clean-room implementation replacing the
% third-party Simulink 3D Animation function of the same name so the toolbox
% has no external dependency. A column vector v is rotated by M*v; a row
% vector by v*M.'.
%
% Reference:
%   Rodrigues' rotation formula: R = I + sin(theta) K + (1 - cos(theta)) K^2,
%   where K is the cross-product (skew-symmetric) matrix of the unit axis.
%   (Standard result; see any rigid-body kinematics text.)
%
% Syntax:
%   m = vrrotvec2mat(r)
%   m = vrrotvec2mat(r, options)
%
% Inputs:
%   r       - Axis-angle rotation [1 x 4] = [x y z theta]. The axis need not
%             be pre-normalized; theta is in radians.
%   options - Optional struct with field 'epsilon', the magnitude below which
%             the axis is treated as zero (default: 1e-12). A zero axis yields
%             the identity matrix.
%
% Outputs:
%   m - 3-by-3 rotation matrix (orthonormal, det = +1).
%
% Algorithm:
%   1. Normalize the axis n = [x y z]/|[x y z]|.
%   2. Form the skew-symmetric cross-product matrix K of n.
%   3. Apply Rodrigues' formula M = I + sin(theta)*K + (1-cos(theta))*K^2.
%
% Example:
%   M = pf2_base.external.vrrotvec2mat([0 0 1 pi/2]);  % +90 deg about z
%   v = M * [1; 0; 0];                                  % -> [0; 1; 0]
%
% Notes:
%   - The expanded entry-wise form used below is algebraically identical to
%     I + s*K + (1-c)*K^2 and avoids forming K explicitly.
%
% See also: pf2_base.external.vrrotvec

if nargin < 1
    error('pf2_base:vrrotvec2mat:nargin', 'A rotation vector is required.');
end

if ~isnumeric(r) || ~isreal(r) || numel(r) ~= 4
    error('pf2_base:vrrotvec2mat:badInput', ...
        'R must be a real 4-element axis-angle vector.');
end

epsilon = 1e-12;
if nargin == 2
    if ~isstruct(options) || ~isfield(options, 'epsilon')
        error('pf2_base:vrrotvec2mat:badOptions', ...
            'OPTIONS must be a struct with an ''epsilon'' field.');
    end
    if ~isnumeric(options.epsilon) || ~isreal(options.epsilon) || options.epsilon < 0
        error('pf2_base:vrrotvec2mat:badOptions', 'OPTIONS.epsilon must be real >= 0.');
    end
    epsilon = options.epsilon;
end

axis = r(1:3);
theta = r(4);

na = norm(axis);
if na <= epsilon
    % Degenerate axis: no rotation.
    m = eye(3);
    return;
end
n = axis(:).' / na;

s = sin(theta);
c = cos(theta);
t = 1 - c;
x = n(1);
y = n(2);
z = n(3);

% Rodrigues' formula written out entry-wise (== I + s*K + t*K^2).
m = [ t*x*x + c,    t*x*y - s*z,  t*x*z + s*y; ...
      t*x*y + s*z,  t*y*y + c,    t*y*z - s*x; ...
      t*x*z - s*y,  t*y*z + s*x,  t*z*z + c ];

end
