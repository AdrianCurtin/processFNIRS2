function [fig, results] = plotLME(groups, groupByVars, varargin)
% PLOTLME Linear Mixed Effects analysis for grouped fNIRS data
%
% Fits LME models per channel and biomarker using groupby variables as
% fixed effects. Returns fitted models, ANOVA tables, auto-generated
% contrasts, and renders bar charts of F-statistics per channel. Each
% biomarker gets its own row of subplots — biomarkers are never combined.
%
% Delegates model fitting to exploreFNIRS.stats.fitLME and adds
% visualization on top. Supports fNIRS, ROI, and Aux data types.
%
% Syntax:
%   [fig, results] = plotLME(groups, groupByVars)
%   [fig, results] = plotLME(groups, groupByVars, 'Biomarkers', {'HbO'})
%   [fig, results] = plotLME(groups, groupByVars, 'ShowTopo', true)
%   [fig, results] = plotLME(groups, groupByVars, 'DataType', 'Aux', ...
%       'AuxField', 'heartRate')
%
% Inputs:
%   groups      - Struct array from Experiment.groups (after aggregate())
%   groupByVars - Cell array of grouping variable names used in groupby()
%
% Name-Value Parameters:
%   Biomarkers     - Cell array (default: {'HbO','HbR','HbTotal','CBSI'})
%                    Biomarkers not found in data are silently skipped.
%                    Ignored when DataType='Aux'.
%   Channels       - Vector of channel indices (default: all)
%   AuxField       - Aux field name (required when DataType='Aux')
%   RandomEffects  - Random effects formula (default: '1|SubjectID')
%   UseIntercept   - Include intercept (default: true)
%   AllInteractions - Use full interaction model (default: false)
%   InfoCovariate  - Info variable as covariate (default: '')
%   CustomFormula  - Override auto-built formula (default: '')
%   ShowBar        - Show bar chart visualization (default: true)
%   ShowTopo       - Show ANOVA F-stat topo map (default: false)
%                    Not available for Aux data type.
%   SigThreshold   - Significance threshold (default: 0.05)
%   SigType        - 'p' (default), 'q', 'q-twostep'
%   ErrorType      - 'SEM' (default), 'SD', 'none'
%   Title          - Figure title (default: auto)
%   Visible        - 'on' (default) or 'off'
%   SavePath       - File path to save figure
%   SaveWidth      - Width in pixels (default: 800)
%   SaveHeight     - Height in pixels (default: 500)
%   SaveDPI        - Resolution (default: 150)
%   Colors         - Bar color palette override (default: [] = biomarker palette)
%                    [N x 3] RGB matrix, colormap name (e.g. 'Set1'),
%                    or function handle @(N) returning [N x 3].
%
% Layout:
%   rows = biomarkers (or 1 row for Aux), columns = ANOVA terms
%   Each subplot shows F-statistics across channels as a bar chart.
%   Significant channels (p < SigThreshold) are marked with *.
%
% Outputs:
%   fig     - Figure handle (empty if no visualization)
%   results - Struct with:
%     .models       - Cell array of LinearMixedModel objects [nBio x nCh]
%     .anova        - Cell array of ANOVA tables [nBio x nCh]
%     .anova_pval   - Table of ANOVA p-values [channels x terms]
%     .anova_Fstat  - Table of ANOVA F-statistics [channels x terms]
%     .coefficients - Cell array of random effects per channel
%     .contrasts    - Cell array of auto-generated contrast tables
%     .AIC          - Matrix of AIC values [nBio x nCh]
%     .formula      - The formula string used
%     .mergedTable  - Long-format merged data table
%
% Example:
%   ex = exploreFNIRS.core.Experiment(data);
%   ex.groupby({'Group', 'Condition'});
%   ex.aggregate();
%
%   % Default: all 4 biomarkers
%   [fig, results] = ex.plotLME();
%   disp(results.anova_pval);
%
%   % Specific biomarkers and channels
%   [fig, results] = ex.plotLME('Biomarkers', {'HbO','HbR'}, 'Channels', 1:5);
%
%   % Auxiliary data
%   [fig, results] = ex.plotAuxLME('heartRate');
%
% See also: exploreFNIRS.stats.fitLME, exploreFNIRS.core.Experiment,
%           exploreFNIRS.fx.autoContrast, fitlme, anova

    p = inputParser;
    addRequired(p, 'groups', @isstruct);
    addRequired(p, 'groupByVars', @iscell);
    addParameter(p, 'Biomarkers', {'HbO','HbR','HbTotal','CBSI'}, @iscell);
    addParameter(p, 'Channels', [], @isnumeric);
    addParameter(p, 'AuxField', '', @ischar);
    addParameter(p, 'RandomEffects', '1|SubjectID', @ischar);
    addParameter(p, 'UseIntercept', true, @islogical);
    addParameter(p, 'AllInteractions', false, @islogical);
    addParameter(p, 'InfoCovariate', '', @ischar);
    addParameter(p, 'CustomFormula', '', @ischar);
    addParameter(p, 'ShowBar', true, @islogical);
    addParameter(p, 'ShowTopo', false, @islogical);
    addParameter(p, 'SigThreshold', 0.05, @isnumeric);
    addParameter(p, 'SigType', 'p', @ischar);
    addParameter(p, 'ErrorType', 'SEM', @ischar);
    addParameter(p, 'Title', '', @ischar);
    addParameter(p, 'Visible', 'on', @ischar);
    addParameter(p, 'SavePath', '', @ischar);
    addParameter(p, 'SaveWidth', 800, @isnumeric);
    addParameter(p, 'SaveHeight', 500, @isnumeric);
    addParameter(p, 'SaveDPI', 150, @isnumeric);
    addParameter(p, 'ExcludeShortSeparation', true, @islogical);
    addParameter(p, 'DataType', 'fNIRS', @ischar);
    addParameter(p, 'SkipTimeFactor', false, @islogical);
    addParameter(p, 'Colors', [], @(x) isempty(x) || isnumeric(x) || ischar(x) || isstring(x) || isa(x, 'function_handle') || isa(x, 'exploreFNIRS.core.ColorScheme'));
    parse(p, groups, groupByVars, varargin{:});
    opts = p.Results;

    if ~isempty(opts.SavePath)
        opts.Visible = 'off';
    end

    isROIMode = strcmpi(opts.DataType, 'ROI');
    isAuxMode = strcmpi(opts.DataType, 'Aux');

    % Aux mode: topo not available (no probe geometry)
    if isAuxMode && opts.ShowTopo
        warning('exploreFNIRS:core:plotLME', ...
            'ShowTopo not available for Aux data. Using ShowBar instead.');
        opts.ShowTopo = false;
        opts.ShowBar = true;
    end

    ga = groups(1).gbyGrandBarFlat;

    if isAuxMode
        % Aux mode: validate aux field exists
        if isempty(opts.AuxField)
            error('exploreFNIRS:core:plotLME', ...
                'AuxField is required when DataType is ''Aux''');
        end
        if ~isfield(ga, 'Aux') || ~isstruct(ga.Aux)
            error('exploreFNIRS:core:plotLME', ...
                'No Aux data in grand average.');
        end
        % Check field exists (with _data suffix fallback)
        af = opts.AuxField;
        if ~isfield(ga.Aux, af) && ~isfield(ga.Aux, [af '_data'])
            error('exploreFNIRS:core:plotLME', ...
                'Aux field "%s" not found in grand average data.', af);
        end
        % For Aux, biomarkers list is just the aux field name (1 row)
        opts.Biomarkers = {opts.AuxField};
    else
        % Filter biomarkers to those that exist in the data
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
            error('exploreFNIRS:core:plotLME', ...
                'None of the requested biomarkers found in data.');
        end
        opts.Biomarkers = validBio;
    end

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
    if isAuxMode
        statsArgs = [statsArgs, {'AuxField', opts.AuxField}];
    end
    results = exploreFNIRS.stats.fitLME(groups, groupByVars, statsArgs{:});

    channels = results.channels;
    nCh = length(channels);
    nBioM = length(opts.Biomarkers);

    fig = [];

    % Visualization
    if ~(opts.ShowBar || opts.ShowTopo)
        return;
    end

    sty = pf2_base.plot.PlotStyle.getDefault();

    if opts.ShowBar
        fig = plotBarSummary(results, opts, channels, nBioM, nCh, sty);
    elseif opts.ShowTopo
        fig = plotTopoFstat(results, opts, channels, nBioM, nCh, sty);
    end

    % Title: show full model formula (matching plotTopoLME)
    if ~isempty(fig)
        if ~isempty(opts.Title)
            pf2_base.external.suptitle(fig, opts.Title);
        else
            formulaStr = regexprep(results.formula, '^[^~]+~', 'biom ~ ');
            formulaStr = strrep(formulaStr, '+', ' + ');
            formulaStr = regexprep(formulaStr, '\s+', ' ');
            pf2_base.external.suptitle(fig, pf2_base.plot.escapeTeX(formulaStr));
        end

        sty.applyToFigure(fig);
        pf2_base.plot.handleSave(fig, opts);
    end
end


%% Local helpers


function fig = plotBarSummary(results, opts, channels, nBioM, nCh, sty)
% Render bar chart: rows = biomarkers, columns = ANOVA terms
% Each subplot shows F-statistics across channels

    % Extract ANOVA terms from the first fitted model (exclude Intercept)
    termNames = getTermNames(results, nBioM, nCh);
    if isempty(termNames)
        fig = [];
        return;
    end

    nTerms = length(termNames);

    % Layout: rows = biomarkers, cols = ANOVA terms
    nRows = nBioM;
    nCols = nTerms;

    figW = opts.SaveWidth * min(nCols, 4);
    figH = opts.SaveHeight * max(nRows * 0.6, 1);

    fig = pf2_base.plot.createFigure('Visible', opts.Visible, ...
        'Width', figW, 'Height', figH, 'SavePath', opts.SavePath);

    if ~isempty(opts.Colors) && ~isa(opts.Colors, 'exploreFNIRS.core.ColorScheme')
        bioColors = exploreFNIRS.core.getGroupColors(nBioM, opts.Colors);
    else
        bioColors = getBarColors(nBioM);
    end

    for bIdx = 1:nBioM
        bioM = opts.Biomarkers{bIdx};

        % Extract F-stats and p-values for this biomarker across channels
        [fMatrix, pMatrix] = extractBiomarkerAnova(results, bIdx, nCh, termNames);

        for t = 1:nTerms
            spIdx = (bIdx - 1) * nCols + t;
            ax = subplot(nRows, nCols, spIdx, 'Parent', fig);
            hold(ax, 'on');

            fVals = fMatrix(:, t);
            pVals = pMatrix(:, t);

            % Bar chart of F-values using actual channel numbers as x
            bar(ax, channels, fVals, 0.6, ...
                'FaceColor', bioColors(bIdx,:), 'EdgeColor', 'k', ...
                'FaceAlpha', 0.7);

            % Mark significant channels
            for i = 1:nCh
                if ~isnan(pVals(i)) && pVals(i) < opts.SigThreshold
                    text(ax, channels(i), fVals(i), '*', ...
                        'HorizontalAlignment', 'center', ...
                        'VerticalAlignment', 'bottom', ...
                        'FontSize', 14, 'FontWeight', 'bold', 'Color', 'r');
                end
            end

            % Labels
            if bIdx == 1
                title(ax, pf2_base.plot.escapeTeX(termNames{t}));
            end
            if bIdx == nBioM
                if strcmpi(opts.DataType, 'ROI')
                    xlabel(ax, 'ROI');
                elseif strcmpi(opts.DataType, 'Aux')
                    xlabel(ax, 'Aux Channel');
                else
                    xlabel(ax, 'Channel');
                end
            end
            if t == 1
                ylabel(ax, sprintf('%s F-stat', bioM));
            end

            set(ax, 'XTick', channels);
            grid(ax, 'on');
            box(ax, 'on');
        end
    end
end


function fig = plotTopoFstat(results, opts, channels, nBioM, nCh, sty)
% Render topographic F-statistic maps: rows = biomarkers, cols = terms

    termNames = getTermNames(results, nBioM, nCh);
    if isempty(termNames)
        fig = [];
        return;
    end

    nTerms = length(termNames);
    nRows = nBioM;
    nCols = nTerms;

    figW = opts.SaveWidth * min(nCols, 4);
    figH = opts.SaveHeight * max(nRows * 0.6, 1);

    fig = pf2_base.plot.createFigure('Visible', opts.Visible, ...
        'Width', figW, 'Height', figH, 'SavePath', opts.SavePath);

    for bIdx = 1:nBioM
        bioM = opts.Biomarkers{bIdx};
        [fMatrix, pMatrix] = extractBiomarkerAnova(results, bIdx, nCh, termNames);

        for t = 1:nTerms
            spIdx = (bIdx - 1) * nCols + t;
            ax = subplot(nRows, nCols, spIdx, 'Parent', fig);

            fVals = fMatrix(:, t)';
            pVals = pMatrix(:, t)';

            % FDR correction
            [curQ, ~] = exploreFNIRS.fx.performFDR(pVals, opts.SigThreshold);

            switch opts.SigType
                case 'q'
                    sigP = curQ;
                case 'q-twostep'
                    sigP = exploreFNIRS.fx.performFDR_twostep(pVals, opts.SigThreshold);
                otherwise
                    sigP = pVals;
            end

            sigMask = sigP <= opts.SigThreshold;

            if any(sigMask)
                minF = min(fVals(sigMask));
                if ~isempty(which('pf2.probe.plot.interpolateValues3D'))
                    axes(ax); %#ok<LAXES>
                    pf2.probe.plot.interpolateValues3D(fVals, [], minF, [], ...
                        sprintf('%s: %s', bioM, termNames{t}), 'F-val', ...
                        'bufferDistance', 1);
                else
                    bar(ax, channels, fVals, 'FaceColor', 'flat');
                    set(ax, 'XTick', channels);
                    ylabel(ax, 'F-stat');
                    title(ax, sprintf('%s: %s', bioM, termNames{t}));
                end
            else
                text(ax, 0.5, 0.5, sprintf('%s: %s\nn.s.', bioM, termNames{t}), ...
                    'HorizontalAlignment', 'center', 'Units', 'normalized');
                axis(ax, 'off');
            end
        end
    end

    sigStr = sprintf('Thresholded at %s=%.2f', opts.SigType, opts.SigThreshold);
    annotation(fig, 'textbox', [0, 0.97, 0.3, 0.03], 'String', sigStr, ...
        'FitBoxToText', 'on', 'EdgeColor', 'none', 'FontSize', 7, ...
        'Color', sty.DimColor);
end


function termNames = getTermNames(results, nBioM, nCh)
% Extract ANOVA term names from the first fitted model (including Intercept)

    termNames = {};

    for bIdx = 1:nBioM
        for chI = 1:nCh
            anv = results.anova{bIdx, chI};
            if ~isempty(anv)
                termNames = anv.Term;
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


function colors = getBarColors(nBioM)
% Distinct colors for each biomarker row

    palette = [
        0.2  0.6  0.9   % HbO  - blue
        0.9  0.3  0.3   % HbR  - red
        0.5  0.7  0.4   % HbTotal - green
        0.7  0.5  0.8   % CBSI - purple
    ];

    if nBioM <= size(palette, 1)
        colors = palette(1:nBioM, :);
    else
        colors = exploreFNIRS.core.getGroupColors(nBioM);
    end
end
