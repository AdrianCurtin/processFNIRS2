function colors = getGroupColors(n)
% GETGROUPCOLORS Return distinguishable colors for group plotting
%
% Returns an [n x 3] matrix of RGB colors for use in grouped plots.
% Uses a perceptually distinct 8-color palette for n <= 8, and falls
% back to MATLAB's lines() colormap for larger n.
%
% Syntax:
%   colors = exploreFNIRS.core.getGroupColors(n)
%
% Inputs:
%   n - Number of groups (positive integer)
%
% Outputs:
%   colors - [n x 3] matrix of RGB values in [0,1]
%
% Example:
%   colors = exploreFNIRS.core.getGroupColors(4);
%   % colors is [4 x 3] with blue, red-orange, green, purple
%
% See also: exploreFNIRS.core.plotBar, exploreFNIRS.core.plotTemporal

    baseColors = [
        0.0000, 0.4470, 0.7410;  % blue
        0.8500, 0.3250, 0.0980;  % red-orange
        0.4660, 0.6740, 0.1880;  % green
        0.4940, 0.1840, 0.5560;  % purple
        0.9290, 0.6940, 0.1250;  % yellow
        0.3010, 0.7450, 0.9330;  % cyan
        0.6350, 0.0780, 0.1840;  % dark red
        0.0000, 0.0000, 0.0000;  % black
    ];
    if n <= size(baseColors, 1)
        colors = baseColors(1:n, :);
    else
        colors = lines(n);
    end
end
