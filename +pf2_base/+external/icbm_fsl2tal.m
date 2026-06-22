function outpoints = icbm_fsl2tal(inpoints)
% ICBM_FSL2TAL Convert FSL-normalized MNI coordinates to Talairach space
%
% Applies the ICBM-152 (FSL flavor) MNI-to-Talairach affine transform of
% Lancaster et al. (2007). The transform corrects the systematic bias
% between coordinates reported in MNI space (when spatial normalization was
% performed with FSL/FLIRT against the ICBM-152 template) and the Talairach
% atlas. The affine is a fixed 4x4 published constant; this function simply
% applies it to a set of 3D coordinates.
%
% Reference:
%   Lancaster, J. L., Tordesillas-Gutierrez, D., Martinez, M., Salinas, F.,
%   Evans, A., Zilles, K., Mazziotta, J. C., & Fox, P. T. (2007). Bias
%   between MNI and Talairach coordinates analyzed using the ICBM-152 brain
%   template. Human Brain Mapping, 28(11), 1194-1205.
%   DOI: 10.1002/hbm.20345
%
% Syntax:
%   outpoints = icbm_fsl2tal(inpoints)
%
% Inputs:
%   inpoints - Coordinate array [N x 3] or [3 x N] in MNI (FSL) space.
%              Each point is an (x, y, z) triplet in millimeters. A single
%              point may be supplied as a [1 x 3] row vector. For an
%              ambiguous [3 x 3] input, coordinates are assumed to be rows.
%
% Outputs:
%   outpoints - Transformed coordinates in Talairach space, same orientation
%               and size as inpoints ([N x 3] or [3 x N]), in millimeters.
%
% Algorithm:
%   1. Determine which dimension has size 3 and orient points as columns.
%   2. Append a row of ones to form homogeneous coordinates [x; y; z; 1].
%   3. Left-multiply by the fixed ICBM-152 (FSL) MNI-to-Talairach affine.
%   4. Drop the homogeneous row and restore the input orientation.
%
% Example:
%   % Convert a single MNI coordinate to Talairach
%   tal = pf2_base.external.icbm_fsl2tal([-42 18 24]);
%
%   % Convert a set of channel positions [N x 3]
%   talPos = pf2_base.external.icbm_fsl2tal(mniPos);
%
% Notes:
%   - Use the FSL variant only when normalization used FSL/FLIRT. The SPM
%     variant uses a slightly different affine.
%   - An exact [3 x 3] input is ambiguous; rows are assumed to be points.
%
% See also: pf2_base.external

% Locate the dimension of size 3.
dimdim = find(size(inpoints) == 3);
if isempty(dimdim)
    error('input must be a N by 3 or 3 by N matrix');
end

% A 3x3 input is ambiguous; assume coordinates are stored as row vectors.
if isequal(dimdim, [1 2])
    dimdim = 2;
end

% Orient so that each column is a single (x, y, z) coordinate.
if dimdim == 2
    inpoints = inpoints';
end

% Fixed ICBM-152 (FSL) MNI-to-Talairach affine (Lancaster et al., 2007).
icbm_fsl = [ 0.9464  0.0034 -0.0026 -1.0680; ...
            -0.0083  0.9479 -0.0580 -1.0239; ...
             0.0053  0.0617  0.9010  3.1883; ...
             0.0000  0.0000  0.0000  1.0000];

% Apply the affine in homogeneous coordinates.
nPoints = size(inpoints, 2);
homogeneous = [inpoints; ones(1, nPoints)];
transformed = icbm_fsl * homogeneous;

% Drop the homogeneous row and restore the input orientation.
outpoints = transformed(1:3, :);
if dimdim == 2
    outpoints = outpoints';
end

end
