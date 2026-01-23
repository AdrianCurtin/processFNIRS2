function optLayout2D = buildProbeLayout(optPosX, optPosY, optPosZ)
% BUILDPROBELAYOUT Generate 2D subplot layout coordinates from optode positions
%
% Converts 3D optode positions to normalized 2D subplot coordinates for
% visualization. This function maps physical probe geometry to a layout
% suitable for MATLAB subplot positioning.
%
% Note: This functionality is now integrated into loadDeviceCfg() via the
% internal generateProbeLayout() subfunction. This wrapper is provided for
% backward compatibility and direct access when needed.
%
% Syntax:
%   optLayout2D = buildProbeLayout(optPosX, optPosY)
%   optLayout2D = buildProbeLayout(optPosX, optPosY, optPosZ)
%
% Inputs:
%   optPosX - X coordinates of optode positions [1 x N] or [N x 1]
%   optPosY - Y coordinates of optode positions [1 x N] or [N x 1]
%   optPosZ - Z coordinates of optode positions (default: zeros)
%             [1 x N] or [N x 1]. Used for 3D-to-2D projection.
%
% Outputs:
%   optLayout2D - Cell array of subplot position vectors [1 x N]
%                 Each cell contains [x, y, width, height] in normalized
%                 figure coordinates (0-1 range) for use with subplot or
%                 axes positioning.
%
% Algorithm:
%   1. Project 3D coordinates to 2D plane if Z provided
%   2. Normalize coordinates to [0, 1] range
%   3. Calculate non-overlapping subplot rectangles
%   4. Return cell array of position vectors
%
% Example:
%   % Create layout for 4 optodes in a square pattern
%   x = [0, 1, 0, 1];
%   y = [0, 0, 1, 1];
%   layout = buildProbeLayout(x, y);
%
%   % Use layout for plotting
%   for i = 1:length(layout)
%       subplot('Position', layout{i});
%       plot(data(:, i));
%   end
%
% See also: loadDeviceCfg, fitProbe2D, pf2.Probe.Plot.ArrangedValues

% Delegate to fitProbe2D which contains the actual implementation
if nargin < 3
    optLayout2D = pf2_base.fitProbe2D(optPosX, optPosY);
else
    optLayout2D = pf2_base.fitProbe2D(optPosX, optPosY, optPosZ);
end

end
