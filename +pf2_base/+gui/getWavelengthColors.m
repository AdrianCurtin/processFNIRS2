function [cIndex, wvUnique] = getWavelengthColors(wavelengths, plotIdx)
% GETWAVELENGTHCOLORS Get color matrix for plotting by wavelength
%
% Returns a color matrix where each row corresponds to a channel in plotIdx,
% with colors assigned based on wavelength. Channels with the same wavelength
% get the same color.
%
% This helper reduces code duplication in processFNIRS2_GUI where similar
% color-by-wavelength logic is repeated in multiple stage plotting blocks.
%
% Syntax:
%   [cIndex, wvUnique] = pf2_base.gui.getWavelengthColors(wavelengths, plotIdx)
%
% Inputs:
%   wavelengths - Full wavelength vector [1 x C] for all channels
%   plotIdx     - Indices of channels to plot [1 x N]
%
% Outputs:
%   cIndex   - Color matrix [N x 3] RGB colors for each channel in plotIdx
%   wvUnique - Unique wavelengths found [1 x W]
%
% Example:
%   wavelengths = [730, 850, 730, 850, 730, 850];  % 6 channels, 2 wavelengths
%   plotIdx = [1, 3, 5];  % Plot channels 1, 3, 5 (all 730nm)
%   [colors, wvs] = pf2_base.gui.getWavelengthColors(wavelengths, plotIdx);
%   % colors will be [3 x 3], all same color since all 730nm
%
% See also: processFNIRS2_GUI, pf2_base.getBioColors

% Get unique wavelengths (excluding NaN)
[wvUnique] = sort(unique(round(wavelengths)));
wvUnique(isnan(wvUnique)) = [];

% Handle empty case
if isempty(wvUnique) || isempty(plotIdx)
    cIndex = [];
    return;
end

% Generate color palette using MATLAB's lines colormap
cc = lines(length(wvUnique));

% Map each channel in plotIdx to its wavelength color
num2Plot = length(plotIdx);
rInd = zeros(1, num2Plot);

for i = 1:length(wvUnique)
    rInd = rInd + (wavelengths(plotIdx) == wvUnique(i)) .* i;
end

% Handle any channels with unmatched wavelengths
rInd(rInd == 0) = 1;

cIndex = cc(rInd, :);
end
