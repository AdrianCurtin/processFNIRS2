function [fig, results] = plotInfoLME(dataTable, infoVar, groupByVars, varargin)
% PLOTINFOLME Linear Mixed Effects analysis for info/behavioral variables
%
% Fits a single LME model using an info variable as the response and
% groupby variables as fixed effects. Renders a bar chart of F-statistics
% per ANOVA term. Unlike plotLME, this fits one model (no channel
% iteration) since the response is a scalar info variable per observation.
%
% Delegates model fitting to exploreFNIRS.stats.fitInfoLME and adds
% visualization on top.
%
% Syntax:
%   [fig, results] = plotInfoLME(dataTable, 'reactionTime', {'Condition'})
%   [fig, results] = plotInfoLME(dataTable, 'accuracy', {'Group','Condition'})
%   [fig, results] = plotInfoLME(dataTable, 'score', {'Group'}, ...
%       'AllInteractions', true, 'SavePath', 'info_lme.png')
%
% Inputs:
%   dataTable   - Table from Experiment.getSelectedTable() (one row per segment)
%   infoVar     - Response variable name (must be numeric column in dataTable)
%   groupByVars - Cell array of fixed-effect variable names
%
% Name-Value Parameters:
%   RandomEffects  - Random effects formula (default: '1|SubjectID')
%   UseIntercept   - Include intercept (default: true)
%   AllInteractions - Use full interaction model (default: false)
%   InfoCovariate  - Additional numeric covariate (default: '')
%   CustomFormula  - Override auto-built formula (default: '')
%   ShowBar        - Show bar chart visualization (default: true)
%   SigThreshold   - Significance threshold (default: 0.05)
%   Title          - Figure title (default: auto)
%   Visible        - 'on' (default) or 'off'
%   SavePath       - File path to save figure
%   SaveWidth      - Width in pixels (default: 600)
%   SaveHeight     - Height in pixels (default: 400)
%   SaveDPI        - Resolution (default: 150)
%
% Layout:
%   Single row of bars: one bar per ANOVA term showing F-statistics.
%   Significant terms (p < SigThreshold) are marked with *.
%
% Outputs:
%   fig     - Figure handle (empty if ShowBar=false)
%   results - Struct from fitInfoLME with:
%     .model        - LinearMixedModel object
%     .models       - {1x1} cell (for pipeline compatibility)
%     .anova        - {1x1} cell of ANOVA table
%     .anova_pval   - Table of ANOVA p-values
%     .anova_Fstat  - Table of ANOVA F-statistics
%     .contrasts    - {1x1} cell of contrast table
%     .AIC          - Scalar AIC value
%     .formula      - Formula string used
%     .mergedTable  - The dataTable used for fitting
%     .responseVar  - infoVar
%
% Example:
%   ex = exploreFNIRS.core.Experiment(data);
%   ex.groupby({'Group', 'Condition'});
%   [fig, results] = ex.plotInfoLME('reactionTime');
%
% See also: exploreFNIRS.stats.fitInfoLME, exploreFNIRS.core.plotLME,
%           exploreFNIRS.core.Experiment

    p = inputParser;
    addRequired(p, 'dataTable', @istable);
    addRequired(p, 'infoVar', @ischar);
    addRequired(p, 'groupByVars', @iscell);
    addParameter(p, 'RandomEffects', '1|SubjectID', @ischar);
    addParameter(p, 'UseIntercept', true, @islogical);
    addParameter(p, 'AllInteractions', false, @islogical);
    addParameter(p, 'InfoCovariate', '', @ischar);
    addParameter(p, 'CustomFormula', '', @ischar);
    addParameter(p, 'ShowBar', true, @islogical);
    addParameter(p, 'SigThreshold', 0.05, @isnumeric);
    addParameter(p, 'Title', '', @ischar);
    addParameter(p, 'Visible', 'on', @ischar);
    addParameter(p, 'SavePath', '', @ischar);
    addParameter(p, 'SaveWidth', 600, @isnumeric);
    addParameter(p, 'SaveHeight', 400, @isnumeric);
    addParameter(p, 'SaveDPI', 150, @isnumeric);
    addParameter(p, 'TightLayout', false, @islogical);
    addParameter(p, 'Colors', [], @(x) true);  % Accepted for API consistency, unused
    parse(p, dataTable, infoVar, groupByVars, varargin{:});
    opts = p.Results;

    if ~isempty(opts.SavePath)
        opts.Visible = 'off';
    end

    % Delegate model fitting to stats module
    statsArgs = { ...
        'RandomEffects', opts.RandomEffects, ...
        'UseIntercept', opts.UseIntercept, ...
        'AllInteractions', opts.AllInteractions, ...
        'InfoCovariate', opts.InfoCovariate, ...
        'CustomFormula', opts.CustomFormula};
    results = exploreFNIRS.stats.fitInfoLME(dataTable, infoVar, ...
        groupByVars, statsArgs{:});

    fig = [];

    if ~opts.ShowBar
        return;
    end

    % Extract ANOVA terms
    anv = results.anova{1, 1};
    if isempty(anv)
        return;
    end

    termNames = anv.Term;
    fVals = anv.FStat;
    pVals = anv.pValue;
    nTerms = length(termNames);

    sty = pf2_base.plot.PlotStyle.getDefault();

    fig = pf2_base.plot.createFigure('Visible', opts.Visible, ...
        'Width', opts.SaveWidth, 'Height', opts.SaveHeight, ...
        'SavePath', opts.SavePath);

    ax = axes('Parent', fig);
    hold(ax, 'on');

    % Bar chart of F-values per term
    colors = getTermColors(nTerms);
    for t = 1:nTerms
        bar(ax, t, fVals(t), 0.6, ...
            'FaceColor', colors(t,:), 'EdgeColor', 'k', ...
            'FaceAlpha', 0.7);
    end

    % Mark significant terms
    for t = 1:nTerms
        if ~isnan(pVals(t)) && pVals(t) < opts.SigThreshold
            text(ax, t, fVals(t), sprintf('*\np=%.3f', pVals(t)), ...
                'HorizontalAlignment', 'center', ...
                'VerticalAlignment', 'bottom', ...
                'FontSize', 12, 'FontWeight', 'bold', 'Color', 'r');
        else
            text(ax, t, fVals(t), sprintf('\np=%.3f', pVals(t)), ...
                'HorizontalAlignment', 'center', ...
                'VerticalAlignment', 'bottom', ...
                'FontSize', 9, 'Color', sty.DimColor);
        end
    end

    % Clean term labels
    cleanLabels = pf2_base.plot.escapeTeX(termNames);
    set(ax, 'XTick', 1:nTerms, 'XTickLabel', cleanLabels);
    if nTerms > 3
        set(ax, 'XTickLabelRotation', 30);
    end

    ylabel(ax, 'F-statistic');
    xlabel(ax, 'ANOVA Term');
    grid(ax, 'on');
    box(ax, 'on');

    % Title
    if ~isempty(opts.Title)
        pf2_base.external.suptitle(fig, pf2_base.plot.escapeTeX(opts.Title));
    else
        formulaStr = regexprep(results.formula, '^[^~]+~', ...
            [infoVar ' ~ ']);
        formulaStr = strrep(formulaStr, '+', ' + ');
        formulaStr = regexprep(formulaStr, '\s+', ' ');
        pf2_base.external.suptitle(fig, pf2_base.plot.escapeTeX(formulaStr));
    end

    sty.applyToFigure(fig);
    pf2_base.plot.handleSave(fig, opts);
end


function colors = getTermColors(nTerms)
% Distinct colors for ANOVA terms

    palette = [
        0.3  0.5  0.7   % blue-grey
        0.8  0.4  0.3   % warm red
        0.4  0.7  0.5   % green
        0.7  0.5  0.7   % purple
        0.8  0.7  0.3   % gold
        0.5  0.6  0.8   % light blue
    ];

    if nTerms <= size(palette, 1)
        colors = palette(1:nTerms, :);
    else
        colors = lines(nTerms);
    end
end
