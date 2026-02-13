function plotStageHb(ax, data, time, timeInd, optTable, selectedIdx, curConc, viewSettings, dpfMode, varargin)
% PLOTSTAGEHB Plot hemoglobin stage data
%
% Shared plotting helper for GUI stages 3 and 4 (pre-filter and filtered
% hemoglobin). Filters the optode table, uses biomarker colors, and plots
% selected channels for each selected biomarker.
%
% Syntax:
%   pf2_base.gui.plotStageHb(ax, data, time, timeInd, optTable, ...
%       selectedIdx, curConc, viewSettings, dpfMode)
%   pf2_base.gui.plotStageHb(..., 'Name', Value)
%
% Inputs:
%   ax           - Axes handle to plot into
%   data         - Struct with HbO, HbR, HbDiff, HbTotal, CBSI fields
%   time         - [T x 1] Time vector
%   timeInd      - Logical index for visible time window
%   optTable     - Full optode table from GUI
%   selectedIdx  - Selected listbox indices
%   curConc      - Selected biomarker indices (1=HbO, 2=HbR, etc.)
%   viewSettings - Struct with fields: OxyAuto, OxyMin, OxyMax,
%                  startTime, endTime
%   dpfMode      - DPF mode string ('None', 'Fixed', or 'Calc')
%
% Name-Value Arguments:
%   excludeManualRej - Exclude manually rejected channels (default: true)
%   excludeAutoRej   - Exclude auto-rejected channels (default: false)
%   plotROI          - Plot ROI overlays if available (default: false)
%   axTag            - Tag to set on axes (default: '')
%   deviceInfo       - Device info struct (needs TimeIsSampleCount)
%
% See also: pf2_base.gui.plotStageRaw, pf2_base.gui.filterOptodeTable

p = inputParser;
addParameter(p, 'excludeManualRej', true, @islogical);
addParameter(p, 'excludeAutoRej', false, @islogical);
addParameter(p, 'plotROI', false, @islogical);
addParameter(p, 'axTag', '', @ischar);
addParameter(p, 'deviceInfo', struct('TimeIsSampleCount', false), @isstruct);
parse(p, varargin{:});
opts = p.Results;

if isempty(data)
    return;
end

% Filter optode table
[plotSingleTable, plotROITable, ~] = pf2_base.gui.filterOptodeTable(optTable, selectedIdx, ...
    'excludeManualRej', opts.excludeManualRej, 'excludeAutoRej', opts.excludeAutoRej);

% Get biomarker colors
colorsTable = pf2_base.getBioColors();
bioM = colorsTable.Properties.VariableNames;
bioMclr = table2cell(colorsTable);
numBioM = length(bioM);

% Plot
cla(ax);
pf2_base.gui.forceLightAxes(ax);

for b = 1:numBioM
    if any(ismember(curConc, b))
        if ~isempty(plotSingleTable) && height(plotSingleTable) > 0
            for i = 1:height(plotSingleTable)
                h = plot(ax, time(timeInd), data.(bioM{b})(timeInd, plotSingleTable.OptIndex(i)), 'color', bioMclr{b});
                set(h, 'Tag', sprintf('Opt%i_%s', plotSingleTable.Optode(i), bioM{b}));
                hold(ax, 'on');
            end
        end
    end
end

% ROI overlay
if opts.plotROI && ~isempty(plotROITable) && height(plotROITable) > 0
    for i = 1:height(plotROITable)
        if pf2_base.isnestedfield(data, 'ROI.HbO')
            for b = 1:numBioM
                if any(ismember(curConc, b))
                    h = plot(ax, time(timeInd), data.ROI.(bioM{b})(timeInd, plotROITable.Optode(i)), 'color', bioMclr{b} * 0.8, 'linewidth', 1);
                    set(h, 'Tag', sprintf('%s_%s', plotROITable.Label{i}, bioM{b}));
                    hold(ax, 'on');
                end
            end
        else
            fprintf(2, 'ROIs have not been built, use a function in Oxy Stage to build ROIs\n');
        end
    end
end

% Y-axis limits
if ~viewSettings.OxyAuto
    ylim(ax, [viewSettings.OxyMin, viewSettings.OxyMax]);
end

% Zero line
if (~isempty(plotSingleTable) && height(plotSingleTable) > 0) || ...
   (~isempty(plotROITable) && height(plotROITable) > 0)
    plot(ax, time(timeInd), time(timeInd) * 0, '--k', 'linewidth', 1);
end

% Axis config
xl = [viewSettings.startTime, viewSettings.endTime];
xlim(ax, xl);
hold(ax, 'off');

if opts.deviceInfo.TimeIsSampleCount
    xlabel(ax, 'Time (samples)');
else
    xlabel(ax, 'Time (s)');
end

if strcmp(dpfMode, 'None')
    ylabel(ax, '\Delta[X] (mM*mm)');
else
    ylabel(ax, '\Delta[X] (\muM)');
end

if ~isempty(opts.axTag)
    set(ax, 'Tag', opts.axTag);
end
end
