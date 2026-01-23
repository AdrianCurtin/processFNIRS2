function colorsTable=getBioColors()
% GETBIOCOLORS Return standard RGB colors for fNIRS biomarker plotting
%
% Returns a table of RGB color triplets used throughout processFNIRS2 for
% consistent visualization of hemoglobin biomarkers. Colors are chosen for
% visual distinction and follow common fNIRS conventions (red for HbO,
% blue for HbR).
%
% Reference:
%   Internal pf2 implementation. Color choices follow common fNIRS
%   visualization conventions in the literature.
%
% Syntax:
%   colorsTable = getBioColors()
%
% Inputs:
%   None
%
% Outputs:
%   colorsTable - Table with RGB color triplets as columns {1 x 5 table}
%                 Variable names: 'HbO', 'HbR', 'HbDiff', 'HbTotal', 'CBSI'
%                 Each column contains [R, G, B] values in range [0, 1].
%
% Color Definitions:
%   HbO     - Red [0.797, 0.145, 0.160] - oxygenated hemoglobin
%   HbR     - Blue [0.223, 0.414, 0.691] - deoxygenated hemoglobin
%   HbDiff  - Dark gray [0.2, 0.2, 0.2] - differential (HbO - HbR)
%   HbTotal - Purple [0.418, 0.297, 0.602] - total (HbO + HbR)
%   CBSI    - Cyan [0, 0.7, 0.7] - correlation-based signal improvement
%
% Example:
%   % Get colors for plotting
%   colors = pf2_base.getBioColors();
%
%   % Use HbO color for a plot
%   plot(time, HbO, 'Color', colors.HbO, 'LineWidth', 1.5);
%   hold on;
%   plot(time, HbR, 'Color', colors.HbR, 'LineWidth', 1.5);
%
%   % Access specific color
%   hboColor = colors.HbO;  % [0.797, 0.145, 0.160]
%
% See also: pf2_getFNIRSbiomFields, pf2.data.plot.oxy, pf2_plotArranged

colorsTable=table([204/256,37/256,41/256],[57/256,106/256,177/256],[0.2,0.2,0.2],[107/256,76/256,154/256],[0,0.7,0.7],'VariableNames',{'HbO','HbR','HbDiff','HbTotal','CBSI'});
