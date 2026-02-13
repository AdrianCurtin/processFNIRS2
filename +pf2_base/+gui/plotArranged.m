function plotArranged(data, time, timeInd, topoPlotInfo, viewSettings, dpfMode, deviceInfo, varargin)
% PLOTARRANGED Plot per-optode arranged topographic view
%
% Shared helper for GUI arranged views. Creates a figure per probe with
% each optode plotted in its topographic position. Supports both raw/OD
% (wavelength-based colors) and hemoglobin (biomarker-based colors) modes.
%
% Syntax:
%   pf2_base.gui.plotArranged(data, time, timeInd, topoPlotInfo, ...
%       viewSettings, dpfMode, deviceInfo)
%   pf2_base.gui.plotArranged(..., 'Name', Value)
%
% Inputs:
%   data         - Raw: [T x C] matrix, Hb: struct with HbO/HbR/etc. fields
%   time         - [T x 1] Time vector
%   timeInd      - Logical index for visible time window
%   topoPlotInfo - Cell array of probe OptPos tables
%   viewSettings - Struct with axis limit fields
%   dpfMode      - DPF mode string for y-axis label (Hb mode only)
%   deviceInfo   - Struct with RawMax, TimeIsSampleCount
%
% Name-Value Arguments:
%   colorScheme     - 'wavelength' (raw) or 'biomarker' (Hb) (default: 'wavelength')
%   figureBase      - Base figure number (default: 100)
%   titlePrefix     - Annotation prefix string (default: 'Raw')
%   figureHandles   - Cell array of existing figure handles to reuse
%   figureField     - Name for returning handles (default: 'rawTopo')
%   curConc         - Selected biomarker indices (biomarker mode, default: 1:5)
%   curWv           - Selected wavelengths (wavelength mode)
%   curChSet        - Full channel set vector (wavelength mode)
%   curWvSet        - Full wavelength set vector (wavelength mode)
%   LightColorAuto  - Use auto wavelength coloring (default: true)
%
% See also: processFNIRS2_GUI, pf2_base.gui.plotStageRaw, pf2_base.gui.plotStageHb

p = inputParser;
addParameter(p, 'colorScheme', 'wavelength', @ischar);
addParameter(p, 'figureBase', 100);
addParameter(p, 'titlePrefix', 'Raw', @ischar);
addParameter(p, 'figureHandles', {}, @iscell);
addParameter(p, 'figureField', 'rawTopo', @ischar);
addParameter(p, 'curConc', 1:5);
addParameter(p, 'curWv', []);
addParameter(p, 'curChSet', []);
addParameter(p, 'curWvSet', []);
addParameter(p, 'LightColorAuto', true);
parse(p, varargin{:});
opts = p.Results;

if isempty(data)
    return;
end

isBiomarker = strcmp(opts.colorScheme, 'biomarker');

% Get biomarker colors if needed
if isBiomarker
    colorsTable = pf2_base.getBioColors();
    bioM = colorsTable.Properties.VariableNames;
    bioMclr = table2cell(colorsTable);
end

% Precompute wavelength filter for raw mode
if ~isBiomarker && ~isempty(opts.curWvSet)
    plotIdx2 = ismember(opts.curWvSet, opts.curWv);
end

for prb = 1:length(topoPlotInfo)
    curTopoInfo = topoPlotInfo{prb};

    figNum = opts.figureBase + prb;
    figH = figure(figNum);
    clf(figH);
    annotstr = sprintf('Probe %i: %s', prb, opts.titlePrefix);
    annotation(figH, 'textbox', [0, 1, 0, 0], 'String', annotstr, 'FitBoxToText', 'on');

    numOptodes = size(curTopoInfo, 1);

    % Create subplot axes at topographic positions
    h = cell(1, numOptodes);
    for optIdx = 1:numOptodes
        h{optIdx} = axes('Parent', figH, 'Position', [0 0 .001 .001], 'Box', 'on');
        h{optIdx}.OuterPosition = curTopoInfo.subplot_layout_ss{optIdx};
    end

    for optIdx = 1:numOptodes
        axes(h{optIdx}); %#ok<LAXES>
        cla;

        if isBiomarker
            % Hemoglobin mode: plot each selected biomarker
            plotIdx = find(ismember(data.channels, optIdx));

            hasData = false;
            for b = 1:length(bioM)
                if any(ismember(opts.curConc, b))
                    for i = 1:length(plotIdx)
                        plot(data.time(timeInd), data.(bioM{b})(timeInd, plotIdx(i)), 'color', bioMclr{b});
                        hold on;
                        hasData = true;
                    end
                end
            end

            if ~hasData && isempty(plotIdx)
                text(0.5, 0.5, 'X', 'FontSize', 40, 'color', [1, 0, 0]);
                axis off;
            end

            % Y-axis limits
            if isfield(viewSettings, 'OxyAuto') && ~viewSettings.OxyAuto
                ylim([viewSettings.OxyMin, viewSettings.OxyMax]);
            end

            % Zero line
            if ~isempty(plotIdx)
                plot(data.time(timeInd), data.time(timeInd) * 0, '--k', 'linewidth', 1);
            end

            % Y-label
            if strcmp(dpfMode, 'None')
                ylabel('\Delta[X] (mM*mm)');
            else
                ylabel('\Delta[X] (\muM)');
            end
        else
            % Raw/OD mode: plot each selected wavelength
            plotIdx = find(ismember(opts.curChSet, optIdx) .* plotIdx2);
            num2Plot = length(plotIdx);

            if opts.LightColorAuto && num2Plot > 0
                [cIndex, ~] = pf2_base.gui.getWavelengthColors(opts.curWvSet, plotIdx);
            else
                cIndex = lines(max(num2Plot, 1));
            end

            for i = 1:num2Plot
                plot(time(timeInd), data(timeInd, plotIdx(i)), 'color', cIndex(i, :));
                hold on;
            end

            % Y-axis limits
            if isfield(viewSettings, 'LightAuto') && ~viewSettings.LightAuto
                ylim([viewSettings.LightMin, viewSettings.LightMax]);
            end

            % Saturation line
            if ~isempty(plotIdx)
                yl = ylim;
                if max(yl) > 0.95 * deviceInfo.RawMax
                    plot(time(timeInd), time(timeInd) * 0 + deviceInfo.RawMax, '--r', 'linewidth', 2);
                end
            end

            % Y-label
            if isfield(viewSettings, 'isOD') && viewSettings.isOD
                ylabel('\Delta OD');
            else
                ylabel('Intensity (I_in)');
            end
        end

        hold off;

        if deviceInfo.TimeIsSampleCount
            xlabel('Time (samples)');
        else
            xlabel('Time (s)');
        end

        title(sprintf('P%i: Opt%i', prb, optIdx));
    end
end
end
