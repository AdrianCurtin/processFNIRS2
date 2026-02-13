function plotStageRaw(ax, data, time, timeInd, optTable, selectedIdx, curChSet, curWvSet, curWv, viewSettings, deviceInfo, varargin)
% PLOTSTAGERAW Plot raw intensity or optical density stage data
%
% Shared plotting helper for GUI stages 1 and 2 (raw intensity and
% processed raw/OD). Filters the optode table, assigns wavelength-based
% colors, and plots selected channels.
%
% Syntax:
%   pf2_base.gui.plotStageRaw(ax, data, time, timeInd, optTable, ...
%       selectedIdx, curChSet, curWvSet, curWv, viewSettings, deviceInfo)
%   pf2_base.gui.plotStageRaw(..., 'Name', Value)
%
% Inputs:
%   ax           - Axes handle to plot into
%   data         - [T x C] Raw/OD data matrix
%   time         - [T x 1] Time vector
%   timeInd      - Logical index for visible time window
%   optTable     - Full optode table from GUI
%   selectedIdx  - Selected listbox indices
%   curChSet     - Full channel set vector
%   curWvSet     - Full wavelength set vector
%   curWv        - Selected wavelengths
%   viewSettings - Struct with fields: LightColorAuto, LightAuto,
%                  LightMin, LightMax, startTime, endTime
%   deviceInfo   - Struct with fields: RawMax, TimeIsSampleCount
%
% Name-Value Arguments:
%   excludeManualRej - Exclude manually rejected channels (default: false)
%   excludeAutoRej   - Exclude auto-rejected channels (default: false)
%   yLabel           - Y-axis label string (default: 'Intensity -  I_i_n')
%   showSaturationLine - Show max raw value line (default: true)
%   axTag            - Tag to set on axes (default: '')
%
% See also: pf2_base.gui.plotStageHb, pf2_base.gui.filterOptodeTable

p = inputParser;
addParameter(p, 'excludeManualRej', false, @islogical);
addParameter(p, 'excludeAutoRej', false, @islogical);
addParameter(p, 'yLabel', 'Intensity -  I_i_n', @ischar);
addParameter(p, 'showSaturationLine', true, @islogical);
addParameter(p, 'axTag', '', @ischar);
parse(p, varargin{:});
opts = p.Results;

if isempty(data)
    return;
end

% Filter optode table
[plotSingleTable, ~, ~] = pf2_base.gui.filterOptodeTable(optTable, selectedIdx, ...
    'excludeManualRej', opts.excludeManualRej, 'excludeAutoRej', opts.excludeAutoRej);

% Build plot indices from channel/wavelength sets
if ~isempty(plotSingleTable) && height(plotSingleTable) > 0
    plotIdx = ismember(curChSet, plotSingleTable.Optode);
else
    plotIdx = false(size(curChSet));
end
plotIdx2 = ismember(curWvSet, curWv);
plotIdx = find(plotIdx .* plotIdx2);
num2Plot = length(plotIdx);

if num2Plot == 0
    cla(ax);
    return;
end

% Get colors
if viewSettings.LightColorAuto
    [cIndex, ~] = pf2_base.gui.getWavelengthColors(curWvSet, plotIdx);
else
    cc = lines(num2Plot);
    cIndex = cc;
end

% Plot
cla(ax);
for i = 1:num2Plot
    h = plot(ax, time(timeInd), data(timeInd, plotIdx(i)), 'color', cIndex(i, :));
    set(h, 'Tag', sprintf('Ch%i_%inm', curChSet(plotIdx(i)), curWvSet(plotIdx(i))));
    hold(ax, 'on');
end

% Y-axis limits
if ~viewSettings.LightAuto
    ylim(ax, [viewSettings.LightMin, viewSettings.LightMax]);
end

% Saturation line
if opts.showSaturationLine && ~isempty(plotIdx)
    yl = ylim(ax);
    if max(yl) > 0.95 * deviceInfo.RawMax
        plot(ax, time(timeInd), time(timeInd) * 0 + deviceInfo.RawMax, '--r', 'linewidth', 2);
    end
end

% Axis config
xl = [viewSettings.startTime, viewSettings.endTime];
xlim(ax, xl);
hold(ax, 'off');

if deviceInfo.TimeIsSampleCount
    xlabel(ax, 'Time (samples)');
else
    xlabel(ax, 'Time (s)');
end

ylabel(ax, opts.yLabel);

if ~isempty(opts.axTag)
    set(ax, 'Tag', opts.axTag);
end
end
