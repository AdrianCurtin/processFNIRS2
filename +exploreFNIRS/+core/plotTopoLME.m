function [fig, results] = plotTopoLME(groups, groupByVars, varargin)
% PLOTTOPOLME Topographic map of LME ANOVA statistics (2D or 3D)
%
% Fits LME models per channel and biomarker, then renders significant
% statistics onto a 3D brain surface or 2D probe layout. Each biomarker
% gets its own row of subplots — biomarkers are never combined. One column
% per ANOVA term (including Intercept by default).
%
% Non-significant channels are always NaN-masked so they render as brain
% color (3D) or are hidden (2D). Terms with zero significant channels
% show "n.s." instead.
%
% Two visualization metrics are available via PlotMetric:
%   'F' (default) - F-statistic. Color floor = critical F from inverse CDF.
%   'p'           - -log10(p). Higher values = more significant.
%                   Floor = -log10(SigThreshold) (e.g. 1.3 for alpha=0.05).
%
% Syntax:
%   [fig, results] = plotTopoLME(groups, groupByVars)
%   [fig, results] = plotTopoLME(groups, groupByVars, 'SigType', 'q')
%   [fig, results] = plotTopoLME(groups, groupByVars, 'Projection', '2D')
%   [fig, results] = plotTopoLME(groups, groupByVars, 'SavePath', 'out.png')
%
% Inputs:
%   groups      - Struct array from Experiment.groups (after aggregate())
%   groupByVars - Cell array of grouping variable names used in groupby()
%
% Name-Value Parameters:
%   Projection      - '3D' (default) or '2D'. When '2D', renders on a flat
%                     probe layout instead of a 3D brain surface.
%   Biomarkers      - Cell array (default: {'HbO','HbR','HbTotal','CBSI'})
%                     Biomarkers not found in data are silently skipped.
%   Channels        - Vector of channel indices (default: all)
%   DataType        - 'fNIRS' (default) or 'ROI'. When 'ROI', fits per-ROI
%                     LME models and broadcasts each ROI's statistic to all
%                     its constituent channels for visualization.
%   PlotMetric      - 'F' (default) or 'p'. When 'F', renders F-statistics.
%                     When 'p', renders -log10(p) values (higher = more
%                     significant; 1.3 ~ p<0.05, 2 ~ p<0.01, 3 ~ p<0.001).
%   Interpolation   - 'none' (default) or 'natural'. 2D mode only: when
%                     'natural', interpolates a smooth surface between
%                     channels. Ignored in 3D mode.
%   ROILabels       - Show ROI names at spatial centroids (default: true).
%                     Only applies in 2D + ROI mode.
%   ROILabelSize    - Font size for ROI centroid labels (default: 9).
%   RandomEffects   - Random effects formula (default: '1|SubjectID')
%   UseIntercept    - Include intercept (default: true)
%   AllInteractions - Use full interaction model (default: false)
%   InfoCovariate   - Info variable as covariate (default: '')
%   CustomFormula   - Override auto-built formula (default: '')
%   ExcludeShortSeparation - Skip short separation channels (default: true)
%   SigThreshold    - Significance threshold (default: 0.05)
%   SigType         - 'p' (default), 'q', or 'q-twostep'
%   ShowIntercept   - Include (Intercept) term column (default: true)
%   ChannelLabels   - Show channel numbers on brain (default: true)
%   ChannelLabelSize  - Font size for channel labels (default: 6)
%   ChannelLabelColor - Color for channel labels (default: 'k')
%   ChannelLabelStyle - 'numbers' (default) or 'circles'
%   CameraPosition  - Camera angle for 3D mode (default: 'auto')
%   Visible         - 'on' (default) or 'off'
%   SavePath        - File path to save figure
%   SaveWidth       - Width in pixels (default: 900)
%   SaveHeight      - Height in pixels (default: 500)
%   SaveDPI         - Resolution (default: 150)
%
% Layout:
%   rows = biomarkers, columns = ANOVA terms (Intercept included by default)
%   Each subplot shows significant statistics projected onto the brain
%   surface (3D) or probe layout (2D). Non-significant channels are hidden.
%
% Outputs:
%   fig     - Figure handle
%   results - Struct from exploreFNIRS.stats.fitLME with added field:
%     .sigMasks - Cell array of logical [nCh x nTerms] per biomarker
%
% Example:
%   ex = exploreFNIRS.core.Experiment(data);
%   ex.groupby({'Group', 'Condition'});
%   ex.aggregate();
%
%   % Default: all biomarkers, F-statistic (3D)
%   [fig, results] = ex.plotTopoLME();
%
%   % 2D probe layout
%   [fig, results] = ex.plotTopoLME('Projection', '2D');
%
%   % 2D with interpolated surface
%   [fig, results] = ex.plotTopoLME('Projection', '2D', ...
%       'Interpolation', 'natural');
%
%   % P-value visualization (-log10 scale)
%   [fig, results] = ex.plotTopoLME('Biomarkers', {'HbO'}, ...
%       'PlotMetric', 'p');
%
%   % ROI-level with 2D labels
%   [fig, results] = ex.plotTopoLME('DataType', 'ROI', ...
%       'Projection', '2D', 'Biomarkers', {'HbO'});
%
% See also: exploreFNIRS.stats.fitLME, exploreFNIRS.core.plotLME,
%           exploreFNIRS.core.plotTopo, pf2.probe.plot.interpolateValues3D

    p = inputParser;
    addRequired(p, 'groups', @isstruct);
    addRequired(p, 'groupByVars', @iscell);
    addParameter(p, 'Projection', '3D', @(x) ismember(upper(x), {'2D', '3D'}));
    addParameter(p, 'Biomarkers', {'HbO','HbR','HbTotal','CBSI'}, @iscell);
    addParameter(p, 'Channels', [], @isnumeric);
    addParameter(p, 'RandomEffects', '1|SubjectID', @ischar);
    addParameter(p, 'UseIntercept', true, @islogical);
    addParameter(p, 'AllInteractions', false, @islogical);
    addParameter(p, 'InfoCovariate', '', @ischar);
    addParameter(p, 'CustomFormula', '', @ischar);
    addParameter(p, 'SigThreshold', 0.05, @isnumeric);
    addParameter(p, 'SigType', 'p', @ischar);
    addParameter(p, 'ShowIntercept', true, @islogical);
    addParameter(p, 'ChannelLabels', true, @islogical);
    addParameter(p, 'ChannelLabelSize', 6, @isnumeric);
    addParameter(p, 'ChannelLabelColor', '');
    addParameter(p, 'ChannelLabelStyle', 'numbers', ...
        @(x) ismember(x, {'numbers', 'circles'}));
    addParameter(p, 'ExcludeShortSeparation', true, @islogical);
    addParameter(p, 'DataType', 'fNIRS', @ischar);
    addParameter(p, 'SkipTimeFactor', false, @islogical);
    addParameter(p, 'PlotMetric', 'F', @(x) ismember(lower(x), {'f', 'p'}));
    addParameter(p, 'Interpolation', 'none', @ischar);
    addParameter(p, 'ROILabels', true, @islogical);
    addParameter(p, 'ROILabelSize', 9, @isnumeric);
    addParameter(p, 'CameraPosition', 'auto');
    addParameter(p, 'Visible', 'on', @ischar);
    addParameter(p, 'SavePath', '', @ischar);
    addParameter(p, 'SaveWidth', 900, @isnumeric);
    addParameter(p, 'SaveHeight', 500, @isnumeric);
    addParameter(p, 'SaveDPI', 150, @isnumeric);
    addParameter(p, 'TightLayout', false, @islogical);
    addParameter(p, 'Colormap', '', @(v) ischar(v) || isnumeric(v));
    addParameter(p, 'Colors', [], @(x) true);  % Accepted for API consistency, unused
    parse(p, groups, groupByVars, varargin{:});
    opts = p.Results;

    if ~isempty(opts.SavePath)
        opts.Visible = 'off';
    end

    sty = pf2_base.plot.PlotStyle.getDefault();
    fgColor = sty.ForegroundColor;
    bgColor = sty.FigureColor;

    % Default channel label color to match theme if not explicitly set
    if isempty(opts.ChannelLabelColor)
        opts.ChannelLabelColor = fgColor;
    end

    isROIMode = strcmpi(opts.DataType, 'ROI');
    usePMetric = strcmpi(opts.PlotMetric, 'p');

    % Filter biomarkers to those that exist in the data
    ga = groups(1).gbyGrandBarFlat;
    validBio = {};
    for i = 1:length(opts.Biomarkers)
        if isROIMode
            if pf2_base.isnestedfield(ga, ['ROI.' opts.Biomarkers{i}])
                validBio{end+1} = opts.Biomarkers{i}; %#ok<AGROW>
            end
        else
            if isfield(ga, opts.Biomarkers{i}) && ~isempty(ga.(opts.Biomarkers{i}))
                validBio{end+1} = opts.Biomarkers{i}; %#ok<AGROW>
            end
        end
    end
    if isempty(validBio)
        error('exploreFNIRS:core:plotTopoLME', ...
            'None of the requested biomarkers found in data.');
    end
    opts.Biomarkers = validBio;
    nBioM = length(opts.Biomarkers);

    % Delegate model fitting to stats module
    statsArgs = { ...
        'Biomarkers', opts.Biomarkers, ...
        'Channels', opts.Channels, ...
        'RandomEffects', opts.RandomEffects, ...
        'UseIntercept', opts.UseIntercept, ...
        'AllInteractions', opts.AllInteractions, ...
        'InfoCovariate', opts.InfoCovariate, ...
        'CustomFormula', opts.CustomFormula, ...
        'ExcludeShortSeparation', opts.ExcludeShortSeparation, ...
        'SkipTimeFactor', opts.SkipTimeFactor, ...
        'DataType', opts.DataType};
    results = exploreFNIRS.stats.fitLME(groups, groupByVars, statsArgs{:});

    channels = results.channels;
    nCh = length(channels);

    % Get probe struct from first subject in first group
    probeSeg = groups(1).gbyFNIRS{1};

    % Total channels in the probe (may differ from fitted channels)
    nProbeCh = size(probeSeg.HbO, 2);

    % In ROI mode, extract ROI info for broadcasting values to channels
    roiInfo = [];
    if isROIMode
        if pf2_base.isnestedfield(ga, 'ROI.info')
            roiInfo = ga.ROI.info;
        else
            error('exploreFNIRS:core:plotTopoLME', ...
                'ROI mode requires ROI.info in grand average data.');
        end
    end

    % Extract ANOVA terms
    termNames = getTermNames(results, nBioM, nCh, opts.ShowIntercept);
    if isempty(termNames)
        fig = pf2_base.plot.createFigure('Visible', opts.Visible, ...
            'Width', opts.SaveWidth, 'Height', opts.SaveHeight, ...
            'SavePath', opts.SavePath);
        ax = axes('Parent', fig);
        text(ax, 0.5, 0.5, 'No models fitted', ...
            'HorizontalAlignment', 'center', 'Units', 'normalized');
        axis(ax, 'off');
        pf2_base.plot.handleSave(fig, opts);
        return;
    end
    nTerms = length(termNames);

    % Compute significance masks per biomarker
    results.sigMasks = cell(nBioM, 1);
    for bIdx = 1:nBioM
        [~, pMatrix] = extractBiomarkerAnova(results, bIdx, nCh, termNames);
        sigMask = false(nCh, nTerms);

        for t = 1:nTerms
            pVals = pMatrix(:, t)';
            switch opts.SigType
                case 'q'
                    [corrP, ~] = exploreFNIRS.fx.performFDR(pVals, opts.SigThreshold);
                case 'q-twostep'
                    corrP = exploreFNIRS.fx.performFDR_twostep(pVals, opts.SigThreshold);
                otherwise
                    corrP = pVals;
            end
            sigMask(:, t) = corrP(:) <= opts.SigThreshold;
        end
        results.sigMasks{bIdx} = sigMask;
    end

    % Branch: 2D probe layout vs 3D brain surface
    if strcmpi(opts.Projection, '2D')
        fig = render2D(opts, results, termNames, nBioM, nCh, nProbeCh, ...
            channels, probeSeg, roiInfo, isROIMode, usePMetric, sty);
    else
        fig = render3D(opts, results, termNames, nBioM, nCh, nProbeCh, ...
            channels, probeSeg, roiInfo, isROIMode, usePMetric, sty);
    end

    pf2_base.plot.handleSave(fig, opts);
end


%% 3D rendering (original path)


function fig = render3D(opts, results, termNames, nBioM, nCh, nProbeCh, ...
        channels, probeSeg, roiInfo, isROIMode, usePMetric, sty)

    fgColor = sty.ForegroundColor;
    bgColor = sty.FigureColor;

    nRows = nBioM;
    nCols = length(termNames);
    nTerms = nCols;

    figW = opts.SaveWidth * min(nCols, 4);
    figH = opts.SaveHeight * max(nRows, 1);

    fig = pf2_base.plot.createFigure('Visible', opts.Visible, ...
        'Width', figW, 'Height', figH, 'SavePath', opts.SavePath);
    set(fig, 'Color', bgColor);

    gridLeft = 0.06;
    gridTop = 0.10;
    gridRight = 0.08;
    gridBottom = 0.06;
    cellW = (1 - gridLeft - gridRight) / nCols;
    cellH = (1 - gridTop - gridBottom) / nRows;
    cellPad = 0.02;

    cbarW = 0.015;
    cbarGap = 0.008;
    cbarTickSpace = 0.045;
    cbarSpace = cbarW + cbarGap + cbarTickSpace;

    hotCroppedMap = resolveColormap(opts);

    cbarHFrac = 0.75;

    subAxes = gobjects(nBioM, nTerms);
    cellCbs = cell(nBioM, nTerms);
    cellCbAxes = cell(nBioM, nTerms);
    cellCbParams = cell(nBioM, nTerms);

    for bIdx = 1:nBioM
        [fMatrix, pMatrix] = extractBiomarkerAnova(results, bIdx, nCh, termNames);
        sigMask = results.sigMasks{bIdx};

        for t = 1:nTerms
            xPos = gridLeft + (t - 1) * cellW + cellPad;
            yPos = gridBottom + (nRows - bIdx) * cellH + cellPad;
            w = cellW - 2 * cellPad - cbarSpace;
            h = cellH - 2 * cellPad;

            ax = axes('Parent', fig, 'Position', [xPos, yPos, w, h], ...
                'PositionConstraint', 'innerposition');
            subAxes(bIdx, t) = ax;

            fVals = fMatrix(:, t);
            mask = sigMask(:, t);
            nSig = sum(mask);

            if nSig == 0
                set(ax, 'Color', bgColor);
                title(ax, pf2_base.plot.escapeTeX(termNames{t}), ...
                    'FontSize', 11, 'FontWeight', 'bold', 'Color', fgColor);
                text(ax, 0.5, 0.45, 'n.s.', ...
                    'HorizontalAlignment', 'center', 'Units', 'normalized', ...
                    'FontSize', 12, 'Color', [0.5 0.5 0.5]);
                set(ax, 'XTick', [], 'YTick', [], 'Box', 'off', ...
                    'XColor', 'none', 'YColor', 'none');
                disableDefaultInteractivity(ax);
                ax.Toolbar.Visible = 'off';
                ax.HitTest = 'off';
                ax.PickableParts = 'none';
                continue;
            end

            titleStr = pf2_base.plot.escapeTeX(termNames{t});

            [plotVals, colorFloor, colorCeil, cbTitle] = computeCellValues( ...
                fVals, pMatrix(:, t), mask, channels, nProbeCh, ...
                isROIMode, roiInfo, usePMetric, opts, results, bIdx, nCh, termNames{t});

            % Build channel label display options
            labelArgs = {'ChannelLabels', opts.ChannelLabels, ...
                'labelfontsize', opts.ChannelLabelSize, ...
                'labelfontcolor', opts.ChannelLabelColor};
            if strcmp(opts.ChannelLabelStyle, 'numbers')
                noSpheres = [NaN NaN NaN; NaN NaN NaN; NaN NaN NaN];
                labelArgs = [labelArgs, {'labelspherecolors', noSpheres}];
            end

            pf2.probe.plot.interpolateValues3D(ax, plotVals, probeSeg, ...
                colorFloor, colorCeil, titleStr, cbTitle, ...
                'initCamPosition', opts.CameraPosition, ...
                labelArgs{:}, ...
                'showColorbar', false);

            title(ax, titleStr, 'Color', fgColor);
            cellCbParams{bIdx, t} = {[colorFloor, colorCeil], cbTitle};

            xlabel(ax, ''); ylabel(ax, ''); zlabel(ax, '');
            set(ax, 'XTick', [], 'YTick', [], 'ZTick', []);
            set(ax, 'XColor', 'none', 'YColor', 'none', 'ZColor', 'none');
        end
    end

    % Create colorbars on separate axes (deferred to avoid layout fighting)
    for bIdx = 1:nBioM
        for t = 1:nTerms
            if ~isvalid(subAxes(bIdx, t))
                continue;
            end
            xPos = gridLeft + (t - 1) * cellW + cellPad;
            yPos = gridBottom + (nRows - bIdx) * cellH + cellPad;
            w = cellW - 2 * cellPad - cbarSpace;
            h = cellH - 2 * cellPad;
            set(subAxes(bIdx, t), 'Position', [xPos, yPos, w, h]);

            if ~isempty(cellCbParams{bIdx, t})
                cbLims = cellCbParams{bIdx, t}{1};
                cbTitleStr = cellCbParams{bIdx, t}{2};
                cbH = h * cbarHFrac;
                cbY = yPos + (h - cbH) / 2;
                cbAx = axes('Parent', fig, ...
                    'Position', [xPos + w + cbarGap, cbY, cbarW, cbH], ...
                    'Visible', 'off', 'PositionConstraint', 'innerposition');
                colormap(cbAx, hotCroppedMap);
                caxis(cbAx, cbLims);
                cb = colorbar(cbAx);
                cb.Position = [xPos + w + cbarGap, cbY, cbarW, cbH];
                cb.AxisLocation = 'out';
                title(cb, cbTitleStr);
                cellCbs{bIdx, t} = cb;
                cellCbAxes{bIdx, t} = cbAx;
            end
        end
    end

    % Figure annotations
    addFigureAnnotations(fig, opts, results, isROIMode, nBioM, ...
        gridBottom, cellH, nRows, fgColor, bgColor, sty);

    % Final positioning pass
    for bIdx = 1:nBioM
        for t = 1:nTerms
            if ~isvalid(subAxes(bIdx, t))
                continue;
            end
            xPos = gridLeft + (t - 1) * cellW + cellPad;
            yPos = gridBottom + (nRows - bIdx) * cellH + cellPad;
            w = cellW - 2 * cellPad - cbarSpace;
            h = cellH - 2 * cellPad;
            set(subAxes(bIdx, t), 'Position', [xPos, yPos, w, h], ...
                'PositionConstraint', 'innerposition');

            if ~isempty(cellCbs{bIdx, t}) && isvalid(cellCbs{bIdx, t})
                cbH = h * cbarHFrac;
                cbY = yPos + (h - cbH) / 2;
                cellCbs{bIdx, t}.Position = [xPos + w + cbarGap, cbY, cbarW, cbH];
                cellCbs{bIdx, t}.AxisLocation = 'out';
                set(cellCbs{bIdx, t}, 'Color', fgColor);
                set(cellCbs{bIdx, t}.Label, 'Color', fgColor);
                set(cellCbs{bIdx, t}.Title, 'Color', fgColor);
                if ~isempty(cellCbAxes{bIdx, t}) && isvalid(cellCbAxes{bIdx, t})
                    set(cellCbAxes{bIdx, t}, 'PositionConstraint', 'innerposition');
                end
            end
        end
    end

    annotation(fig, 'line', [0 1], [0.001 0.001], 'Color', fig.Color);
    annotation(fig, 'line', [0.999 0.999], [0 1], 'Color', fig.Color);
end


%% 2D rendering


function fig = render2D(opts, results, termNames, nBioM, nCh, nProbeCh, ...
        channels, probeSeg, roiInfo, isROIMode, usePMetric, sty)

    fgColor = sty.ForegroundColor;
    bgColor = sty.FigureColor;

    nTerms = length(termNames);
    nRows = nBioM;
    nCols = nTerms;

    % Resolve probe 2D layout
    dev = [];
    if isfield(probeSeg, 'device') && isa(probeSeg.device, 'pf2.Device')
        dev = probeSeg.device;
    else
        try
            dev = pf2_base.resolveDeviceFromData(probeSeg);
        catch
        end
    end
    [probeXY, chMask, chNums] = resolveProbeLayout(dev);

    hotCroppedMap = resolveColormap(opts);

    figW = opts.SaveWidth * min(nCols, 4);
    figH = opts.SaveHeight * max(nRows, 1);

    fig = pf2_base.plot.createFigure('Visible', opts.Visible, ...
        'Width', figW, 'Height', figH, 'SavePath', opts.SavePath);
    set(fig, 'Color', bgColor);

    gridLeft = 0.06;
    gridTop = 0.10;
    gridRight = 0.02;
    gridBottom = 0.06;
    cellW = (1 - gridLeft - gridRight) / nCols;
    cellH = (1 - gridTop - gridBottom) / nRows;
    cellPad = 0.02;

    for bIdx = 1:nBioM
        [fMatrix, pMatrix] = extractBiomarkerAnova(results, bIdx, nCh, termNames);
        sigMask = results.sigMasks{bIdx};

        for t = 1:nTerms
            xPos = gridLeft + (t - 1) * cellW + cellPad;
            yPos = gridBottom + (nRows - bIdx) * cellH + cellPad;
            w = cellW - 2 * cellPad;
            h = cellH - 2 * cellPad;

            ax = axes('Parent', fig, 'Position', [xPos, yPos, w, h]);
            mask = sigMask(:, t);
            nSig = sum(mask);

            if nSig == 0
                set(ax, 'Color', bgColor);
                title(ax, pf2_base.plot.escapeTeX(termNames{t}), ...
                    'FontSize', 11, 'FontWeight', 'bold', 'Color', fgColor);
                text(ax, 0.5, 0.45, 'n.s.', ...
                    'HorizontalAlignment', 'center', 'Units', 'normalized', ...
                    'FontSize', 12, 'Color', [0.5 0.5 0.5]);
                set(ax, 'XTick', [], 'YTick', [], 'Box', 'off', ...
                    'XColor', 'none', 'YColor', 'none');
                continue;
            end

            [plotVals, colorFloor, colorCeil, cbTitle] = computeCellValues( ...
                fMatrix(:, t), pMatrix(:, t), mask, channels, nProbeCh, ...
                isROIMode, roiInfo, usePMetric, opts, results, bIdx, nCh, termNames{t});

            % Filter to standard channels (exclude short-sep)
            if ~isempty(chMask)
                stdVals = plotVals(chMask);
            else
                stdVals = plotVals;
            end

            renderCell2D(ax, stdVals, probeXY, chNums, ...
                [colorFloor, colorCeil], hotCroppedMap, opts, fgColor);

            title(ax, pf2_base.plot.escapeTeX(termNames{t}), ...
                'FontSize', 11, 'FontWeight', 'bold', 'Color', fgColor);

            % ROI labels
            if isROIMode && opts.ROILabels && ~isempty(roiInfo)
                addROILabels2D(ax, roiInfo, channels, mask, ...
                    probeXY, chMask, opts, fgColor);
            end
        end
    end

    % Figure annotations
    addFigureAnnotations(fig, opts, results, isROIMode, nBioM, ...
        gridBottom, cellH, nRows, fgColor, bgColor, sty);
end


%% Shared helpers


function [plotVals, colorFloor, colorCeil, cbTitle] = computeCellValues( ...
        fVals, pVals, mask, channels, nProbeCh, ...
        isROIMode, roiInfo, usePMetric, opts, results, bIdx, nCh, termName)
% Compute plot values and color range for one grid cell (shared by 2D/3D)

    if usePMetric
        logpData = -log10(pVals);

        plotVals = nan(1, nProbeCh);
        if isROIMode
            sigIdx = find(mask);
            for sI = 1:length(sigIdx)
                roiIdx = channels(sigIdx(sI));
                memberCh = roiInfo.Optodes{roiIdx};
                plotVals(memberCh) = logpData(sigIdx(sI));
            end
        else
            plotVals(channels(mask)) = logpData(mask);
        end

        colorFloor = -log10(opts.SigThreshold);
        colorCeil = max(logpData(mask));
        if colorFloor >= colorCeil
            colorCeil = colorFloor + 1;
        end
        cbTitle = '-log_{10}(p)';
    else
        plotVals = nan(1, nProbeCh);
        if isROIMode
            sigIdx = find(mask);
            for sI = 1:length(sigIdx)
                roiIdx = channels(sigIdx(sI));
                memberCh = roiInfo.Optodes{roiIdx};
                plotVals(memberCh) = fVals(sigIdx(sI));
            end
        else
            plotVals(channels(mask)) = fVals(mask);
        end

        minF = min(fVals(mask));
        maxF = max(fVals(mask));
        if minF == maxF
            maxF = minF + 1;
        end

        validP = pVals(~isnan(pVals));
        if ~isempty(validP)
            [df1, df2] = getTermDF(results, bIdx, nCh, termName);
            if ~isnan(df1) && ~isnan(df2)
                fCrit = finv(1 - opts.SigThreshold, df1, df2);
            else
                fCrit = minF;
            end
        else
            fCrit = minF;
        end

        if fCrit >= maxF
            fCrit = minF;
        end
        if fCrit == maxF
            maxF = fCrit + 1;
        end

        colorFloor = fCrit;
        colorCeil = maxF;
        cbTitle = 'F-stat';
    end
end


function cmap = resolveColormap(opts)
% Resolve colormap from options (hot-cropped default for LME stats)
    if ~isempty(opts.Colormap)
        if ischar(opts.Colormap)
            cmapFn = exploreFNIRS.helper.getColormap(opts.Colormap);
            cmap = cmapFn(256);
        else
            cmap = opts.Colormap;
        end
    else
        cropFn = @(var,n) var(end-n+1:end,:);
        cmap = cropFn(hot(ceil(256*1.25)), 256);
    end
end


function addFigureAnnotations(fig, opts, results, isROIMode, nBioM, ...
        gridBottom, cellH, nRows, fgColor, bgColor, sty)
% Add formula title, significance annotation, and biomarker row labels

    formulaStr = regexprep(results.formula, '^[^~]+~', 'biom ~ ');
    formulaStr = strrep(formulaStr, '+', ' + ');
    formulaStr = regexprep(formulaStr, '\s+', ' ');
    if isROIMode
        formulaStr = [formulaStr ' (ROI-level)'];
    end
    sgtitle(fig, pf2_base.plot.escapeTeX(formulaStr), 'Color', fgColor);

    sigStr = sprintf('Thresholded at %s <= %.2f', opts.SigType, opts.SigThreshold);
    annotation(fig, 'textbox', [0, 0.97, 0.3, 0.03], 'String', sigStr, ...
        'FitBoxToText', 'on', 'EdgeColor', 'none', 'FontSize', 7, 'Color', fgColor);

    labelAx = axes('Parent', fig, 'Position', [0 0 1 1], 'Visible', 'off', ...
        'HandleVisibility', 'off', 'PickableParts', 'none');
    set(labelAx, 'XLim', [0 1], 'YLim', [0 1]);
    for bIdx = 1:nBioM
        yCenter = gridBottom + (nRows - bIdx + 0.5) * cellH;
        text(labelAx, 0.02, yCenter, opts.Biomarkers{bIdx}, ...
            'Units', 'normalized', 'Rotation', 90, ...
            'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', ...
            'FontSize', 13, 'FontWeight', 'bold', 'Color', fgColor, ...
            'PickableParts', 'none', 'HitTest', 'off');
    end

    sty.applyToFigure(fig);
    set(fig, 'Color', bgColor);
end


%% 2D-specific helpers


function renderCell2D(ax, vals, probeXY, chNums, cLim, cmap, opts, fgColor)
% Render a single 2D topo cell with scatter or interpolated surface

    nCh = length(vals);

    % Determine channel positions
    if ~isempty(probeXY) && size(probeXY, 1) == nCh
        xPos = probeXY(:, 1)';
        yPos = probeXY(:, 2)';
        labels = chNums;
    else
        nGridCols = ceil(sqrt(nCh));
        nGridRows = ceil(nCh / nGridCols);
        xPos = zeros(1, nCh);
        yPos = zeros(1, nCh);
        for c = 1:nCh
            row = ceil(c / nGridCols);
            col = mod(c - 1, nGridCols) + 1;
            xPos(c) = col;
            yPos(c) = nGridRows - row + 1;
        end
        if ~isempty(chNums) && length(chNums) == nCh
            labels = chNums;
        else
            labels = 1:nCh;
        end
    end

    % Separate valid (non-NaN) and NaN channels
    validMask = ~isnan(vals);

    if strcmpi(opts.Interpolation, 'natural') && sum(validMask) > 3
        % Interpolated surface
        padX = 0.05 * (max(xPos) - min(xPos) + eps);
        padY = 0.05 * (max(yPos) - min(yPos) + eps);
        xq = linspace(min(xPos) - padX, max(xPos) + padX, 80);
        yq = linspace(min(yPos) - padY, max(yPos) + padY, 80);
        [XQ, YQ] = meshgrid(xq, yq);

        F = scatteredInterpolant(xPos(validMask)', yPos(validMask)', ...
            vals(validMask)', 'natural', 'none');
        ZQ = F(XQ, YQ);

        imagesc(ax, xq, yq, ZQ, cLim);
        set(ax, 'YDir', 'normal');
        hold(ax, 'on');
        % Significant channels: filled markers
        scatter(ax, xPos(validMask), yPos(validMask), 30, ...
            vals(validMask), 'filled', 'MarkerEdgeColor', 'k');
        % Non-significant channels: hollow gray
        scatter(ax, xPos(~validMask), yPos(~validMask), 20, ...
            'MarkerEdgeColor', [0.7 0.7 0.7], 'LineWidth', 0.5);
        hold(ax, 'off');
    else
        % Discrete circles
        hold(ax, 'on');
        % Non-significant channels: hollow gray circles (plot first, behind)
        scatter(ax, xPos(~validMask), yPos(~validMask), 80, ...
            'MarkerEdgeColor', [0.7 0.7 0.7], 'LineWidth', 0.5);
        % Significant channels: filled colored circles
        if any(validMask)
            scatter(ax, xPos(validMask), yPos(validMask), 200, ...
                vals(validMask), 'filled', 'MarkerEdgeColor', 'k');
        end
        set(ax, 'CLim', cLim);

        % Channel labels
        if opts.ChannelLabels
            for c = 1:nCh
                if iscell(labels)
                    lbl = char(labels{c});
                else
                    lbl = sprintf('%d', labels(c));
                end
                text(ax, xPos(c), yPos(c), lbl, ...
                    'HorizontalAlignment', 'center', ...
                    'FontSize', opts.ChannelLabelSize, 'Color', fgColor);
            end
        end
        hold(ax, 'off');
    end

    axis(ax, 'equal');
    padX = 0.08 * (max(xPos) - min(xPos) + eps);
    padY = 0.08 * (max(yPos) - min(yPos) + eps);
    xlim(ax, [min(xPos) - padX, max(xPos) + padX]);
    ylim(ax, [min(yPos) - padY, max(yPos) + padY]);
    set(ax, 'XTick', [], 'YTick', [], 'Box', 'off', ...
        'XColor', 'none', 'YColor', 'none');

    colormap(ax, cmap);
    cb = colorbar(ax);
    set(cb, 'Color', fgColor);
    if ~isempty(cb.Title)
        set(cb.Title, 'Color', fgColor);
    end
end


function addROILabels2D(ax, roiInfo, channels, mask, probeXY, chMask, opts, fgColor)
% Add ROI name labels at spatial centroids for significant ROIs

    if isempty(probeXY)
        return;
    end

    sigIdx = find(mask);
    if isempty(sigIdx)
        return;
    end

    hold(ax, 'on');
    for sI = 1:length(sigIdx)
        roiIdx = channels(sigIdx(sI));
        if roiIdx > length(roiInfo.Names)
            continue;
        end
        roiName = roiInfo.Names{roiIdx};
        memberCh = roiInfo.Optodes{roiIdx};

        % Map member channels to standard-channel indices
        if ~isempty(chMask)
            stdIdx = find(chMask);
            [~, posIdx] = ismember(memberCh, stdIdx);
            posIdx = posIdx(posIdx > 0);
        else
            posIdx = memberCh;
            posIdx = posIdx(posIdx <= size(probeXY, 1));
        end

        if isempty(posIdx)
            continue;
        end

        cx = mean(probeXY(posIdx, 1));
        cy = mean(probeXY(posIdx, 2));

        text(ax, cx, cy, roiName, ...
            'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', ...
            'FontSize', opts.ROILabelSize, 'FontWeight', 'bold', ...
            'Color', fgColor, 'BackgroundColor', [1 1 1 0.7], ...
            'EdgeColor', [0.5 0.5 0.5], 'Margin', 2);
    end
    hold(ax, 'off');
end


function [probeXY, chMask, chNums] = resolveProbeLayout(dev)
% Extract 2D spatial positions and short-sep mask from Device
%   probeXY - [nStd x 2] (x,y) positions for standard channels
%   chMask  - [1 x nTotal] logical, true for standard channels
%   chNums  - [1 x nStd] channel numbers for labels

    probeXY = [];
    chMask  = [];
    chNums  = [];

    if isempty(dev)
        return;
    end

    ssMask = dev.isShortSep();
    chMask = ~ssMask;
    stdIdx = find(chMask);
    chNums = stdIdx(:)';

    if dev.hasMNI()
        mni = dev.mniPositions();
        probeXY = [mni(stdIdx, 1), mni(stdIdx, 3)];
        return;
    end

    tbl = dev.optodeTable();
    if ismember('Pos2D_x', tbl.Properties.VariableNames) && ...
            ismember('Pos2D_y', tbl.Properties.VariableNames)
        px = tbl.Pos2D_x(stdIdx);
        py = tbl.Pos2D_y(stdIdx);
        if any(px ~= 0) || any(py ~= 0)
            probeXY = [px(:), py(:)];
            probeXY(:, 2) = max(probeXY(:, 2)) - probeXY(:, 2) + min(probeXY(:, 2));
            return;
        end
    end

    lay = dev.layout2D();
    if isempty(lay)
        return;
    end

    probeXY = zeros(length(stdIdx), 2);
    for i = 1:length(stdIdx)
        pos = lay{stdIdx(i)};
        if isempty(pos)
            probeXY(i, :) = [i, 1];
        else
            probeXY(i, 1) = pos(1) + pos(3) / 2;
            probeXY(i, 2) = pos(2) + pos(4) / 2;
        end
    end
    probeXY(:, 2) = 1 - probeXY(:, 2);
end


%% ANOVA extraction helpers


function termNames = getTermNames(results, nBioM, nCh, includeIntercept)
% Extract ANOVA term names from the first fitted model

    termNames = {};

    for bIdx = 1:nBioM
        for chI = 1:nCh
            anv = results.anova{bIdx, chI};
            if ~isempty(anv)
                allTerms = anv.Term;
                if ~includeIntercept
                    allTerms = allTerms(~strcmpi(allTerms, '(Intercept)'));
                end
                termNames = allTerms;
                return;
            end
        end
    end
end


function [df1, df2] = getTermDF(results, bIdx, nCh, termName)
% Get degrees of freedom for a specific ANOVA term from the first valid model

    df1 = NaN;
    df2 = NaN;

    for chI = 1:nCh
        anv = results.anova{bIdx, chI};
        if ~isempty(anv)
            tIdx = find(strcmpi(anv.Term, termName), 1);
            if ~isempty(tIdx)
                df1 = anv.DF1(tIdx);
                df2 = anv.DF2(tIdx);
                return;
            end
        end
    end
end


function [fMatrix, pMatrix] = extractBiomarkerAnova(results, bIdx, nCh, termNames)
% Extract F-stats and p-values for one biomarker across all channels
% Returns [nCh x nTerms] matrices

    nTerms = length(termNames);
    fMatrix = nan(nCh, nTerms);
    pMatrix = nan(nCh, nTerms);

    for chI = 1:nCh
        anv = results.anova{bIdx, chI};
        if isempty(anv)
            continue;
        end

        for t = 1:nTerms
            tIdx = find(strcmpi(anv.Term, termNames{t}), 1);
            if ~isempty(tIdx)
                fMatrix(chI, t) = anv.FStat(tIdx);
                pMatrix(chI, t) = anv.pValue(tIdx);
            end
        end
    end
end


