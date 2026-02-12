function [fig, results] = plotTopoLME(groups, groupByVars, varargin)
% PLOTTOPOLME 3D brain topographic map of LME ANOVA statistics
%
% Fits LME models per channel and biomarker, then renders significant
% statistics onto a 3D brain surface using interpolateValues3D. Each
% biomarker gets its own row of subplots — biomarkers are never combined.
% One column per ANOVA term (including Intercept by default).
%
% Non-significant channels are always NaN-masked so they render as brain
% color. Terms with zero significant channels show "n.s." instead.
%
% Two visualization metrics are available via PlotMetric:
%   'F' (default) - F-statistic. Color floor = critical F from inverse CDF.
%   'p'           - -log10(p). Higher values = more significant.
%                   Floor = -log10(SigThreshold) (e.g. 1.3 for alpha=0.05).
%
% Syntax:
%   [fig, results] = plotTopoLME(groups, groupByVars)
%   [fig, results] = plotTopoLME(groups, groupByVars, 'SigType', 'q')
%   [fig, results] = plotTopoLME(groups, groupByVars, 'PlotMetric', 'p')
%   [fig, results] = plotTopoLME(groups, groupByVars, 'SavePath', 'out.png')
%
% Inputs:
%   groups      - Struct array from Experiment.groups (after aggregate())
%   groupByVars - Cell array of grouping variable names used in groupby()
%
% Name-Value Parameters:
%   Biomarkers      - Cell array (default: {'HbO','HbR','HbTotal','CBSI'})
%                     Biomarkers not found in data are silently skipped.
%   Channels        - Vector of channel indices (default: all)
%   DataType        - 'fNIRS' (default) or 'ROI'. When 'ROI', fits per-ROI
%                     LME models and broadcasts each ROI's statistic to all
%                     its constituent channels for 3D visualization.
%   PlotMetric      - 'F' (default) or 'p'. When 'F', renders F-statistics.
%                     When 'p', renders -log10(p) values (higher = more
%                     significant; 1.3 ~ p<0.05, 2 ~ p<0.01, 3 ~ p<0.001).
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
%   CameraPosition  - Camera angle (default: 'auto')
%   Visible         - 'on' (default) or 'off'
%   SavePath        - File path to save figure
%   SaveWidth       - Width in pixels (default: 900)
%   SaveHeight      - Height in pixels (default: 500)
%   SaveDPI         - Resolution (default: 150)
%
% Layout:
%   rows = biomarkers, columns = ANOVA terms (Intercept included by default)
%   Each subplot shows significant statistics projected onto the 3D brain
%   surface. Non-significant channels are hidden.
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
%   % Default: all biomarkers, F-statistic
%   [fig, results] = ex.plotTopoLME();
%
%   % P-value visualization (-log10 scale)
%   [fig, results] = ex.plotTopoLME('Biomarkers', {'HbO'}, ...
%       'PlotMetric', 'p');
%
%   % Specific biomarkers with FDR correction
%   [fig, results] = ex.plotTopoLME('Biomarkers', {'HbO','HbR'}, ...
%       'SigType', 'q', 'SigThreshold', 0.05);
%
%   % ROI-level: broadcast ROI statistics to constituent channels
%   [fig, results] = ex.plotTopoLME('DataType', 'ROI', ...
%       'Biomarkers', {'HbO'});
%
% See also: exploreFNIRS.stats.fitLME, exploreFNIRS.core.plotLME,
%           pf2.probe.plot.interpolateValues3D

    p = inputParser;
    addRequired(p, 'groups', @isstruct);
    addRequired(p, 'groupByVars', @iscell);
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
    addParameter(p, 'CameraPosition', 'auto');
    addParameter(p, 'Visible', 'on', @ischar);
    addParameter(p, 'SavePath', '', @ischar);
    addParameter(p, 'SaveWidth', 900, @isnumeric);
    addParameter(p, 'SaveHeight', 500, @isnumeric);
    addParameter(p, 'SaveDPI', 150, @isnumeric);
    addParameter(p, 'Colormap', '', @(v) ischar(v) || isnumeric(v));
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

    % Layout: rows = biomarkers, cols = ANOVA terms
    nRows = nBioM;
    nCols = nTerms;

    figW = opts.SaveWidth * min(nCols, 4);
    figH = opts.SaveHeight * max(nRows, 1);

    fig = pf2_base.plot.createFigure('Visible', opts.Visible, ...
        'Width', figW, 'Height', figH, 'SavePath', opts.SavePath);
    set(fig, 'Color', bgColor);

    % Pre-compute grid cell positions (normalized figure coords)
    % Leave margins: left for labels, top for title
    gridLeft = 0.06;
    gridTop = 0.10;
    gridRight = 0.08;
    gridBottom = 0.06;
    cellW = (1 - gridLeft - gridRight) / nCols;
    cellH = (1 - gridTop - gridBottom) / nRows;
    cellPad = 0.02;

    % Colorbar dimensions (normalized figure coords)
    cbarW = 0.015;
    cbarGap = 0.008;
    cbarTickSpace = 0.045;  % room for tick labels + title overhang
    cbarSpace = cbarW + cbarGap + cbarTickSpace;

    % Colormap for manual colorbars (matches interpolateValues3D default)
    if ~isempty(opts.Colormap)
        if ischar(opts.Colormap)
            cmapFn = exploreFNIRS.helper.getColormap(opts.Colormap);
            hotCroppedMap = cmapFn(256);
        else
            hotCroppedMap = opts.Colormap;
        end
    else
        cropFn = @(var,n) var(end-n+1:end,:);
        hotCroppedMap = cropFn(hot(ceil(256*1.25)), 256);
    end

    % Colorbar height fraction (shorter than full cell, vertically centered)
    cbarHFrac = 0.75;

    subAxes = gobjects(nBioM, nTerms);
    cellCbs = cell(nBioM, nTerms);
    cellCbAxes = cell(nBioM, nTerms);
    cellCbParams = cell(nBioM, nTerms);

    for bIdx = 1:nBioM
        bioM = opts.Biomarkers{bIdx};
        [fMatrix, pMatrix] = extractBiomarkerAnova(results, bIdx, nCh, termNames);
        sigMask = results.sigMasks{bIdx};

        for t = 1:nTerms
            % Compute this cell's position (reserve space for colorbar)
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

            if usePMetric
                % -log10(p) visualization
                pVals = pMatrix(:, t);
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
                % F-statistic visualization (default)
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

                % Compute dynamic colorbar floor from inverse F-CDF
                pVals = pMatrix(:, t);
                validP = pVals(~isnan(pVals));
                if ~isempty(validP)
                    [df1, df2] = getTermDF(results, bIdx, nCh, termNames{t});
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

            % Override title color for theme consistency
            title(ax, titleStr, 'Color', fgColor);

            % Store colorbar parameters and title for deferred creation
            cellCbParams{bIdx, t} = {[colorFloor, colorCeil], cbTitle};

            % Hide coordinate axes, keep brain surface visible
            xlabel(ax, ''); ylabel(ax, ''); zlabel(ax, '');
            set(ax, 'XTick', [], 'YTick', [], 'ZTick', []);
            set(ax, 'XColor', 'none', 'YColor', 'none', 'ZColor', 'none');
        end
    end

    % Re-enforce grid positions and create colorbars on separate axes
    % (deferred creation avoids MATLAB auto-layout fighting with 3D axes)
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

            % Create colorbar on a dedicated invisible axes
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

    % Figure title: show model formula
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

    % Biomarker row labels (hidden from handle list so clicks can't select it)
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

    % Apply style and save (re-enforce background after style application)
    sty.applyToFigure(fig);
    set(fig, 'Color', bgColor);

    % Final positioning pass (after style application to ensure positions stick)
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

    % Add invisible border to prevent exportgraphics from cropping whitespace
    annotation(fig, 'line', [0 1], [0.001 0.001], 'Color', fig.Color);  % bottom
    annotation(fig, 'line', [0.999 0.999], [0 1], 'Color', fig.Color);  % right

    pf2_base.plot.handleSave(fig, opts);
end


%% Local helpers


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


