function optPos = getOptodePosition(optLayout, optNum, scale, offset)
% GETOPTODEPOSITION Calculate subplot position for probe-arranged plots
%
% Computes the normalized figure position for an optode subplot based on
% probe layout geometry. Handles the y-axis flip and applies optional
% scaling and offset adjustments.
%
% Syntax:
%   optPos = pf2_base.plot.getOptodePosition(optLayout, optNum)
%   optPos = pf2_base.plot.getOptodePosition(optLayout, optNum, scale)
%   optPos = pf2_base.plot.getOptodePosition(optLayout, optNum, scale, offset)
%
% Inputs:
%   optLayout - Cell array of subplot positions from probeInfo.OptPos
%               Each cell contains [x, y, width, height] in normalized units.
%   optNum    - Optode number (1-based index into optLayout)
%   scale     - [width, height] scale factors (default: [0.65, 0.9])
%               Applied to subplot dimensions to add spacing.
%   offset    - [x, y] offset to add to position (default: [0.03, 0])
%               Used to shift all subplots for margins.
%
% Outputs:
%   optPos - Position vector [x, y, width, height] for axes()
%            Ready to use with: axes('Position', optPos)
%            Returns empty [] if optNum exceeds layout size.
%
% Example:
%   optLayout = probeInfo.OptPos.subplot_layout_ss;
%   for i = 1:numOptodes
%       pos = pf2_base.plot.getOptodePosition(optLayout, i);
%       axes('Position', pos, 'Box', 'on');
%       plot(time, data(:, i));
%   end
%
% See also: pf2.data.plot.raw, pf2.data.plot.oxy, pf2.probe.plot.arrangedValues

% Default parameters
if nargin < 3 || isempty(scale)
    scale = [0.65, 0.9];
end

if nargin < 4 || isempty(offset)
    offset = [0.03, 0];
end

% Check bounds
if optNum > numel(optLayout)
    optPos = [];
    return;
end

% Get base position
optPos = optLayout{optNum};

% Flip y-axis (MATLAB figure coordinates have origin at bottom-left,
% but probe layouts typically have origin at top-left)
optPos(2) = 1 - optPos(2) - optPos(4);

% Apply scaling to width and height
optPos(3:4) = optPos(3:4) .* scale;

% Apply offset
optPos(1:2) = optPos(1:2) + offset;

end
