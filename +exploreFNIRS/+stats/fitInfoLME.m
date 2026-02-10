function results = fitInfoLME(dataTable, infoVar, groupByVars, varargin)
% FITINFOLME Fit a linear mixed-effects model for an info/behavioral variable
%
% Fits a single LME model using an info variable as the response and groupby
% variables as fixed effects, with random intercepts for subjects. Returns
% fitted model, ANOVA table, auto-generated contrasts, and model comparison.
%
% Unlike fitLME (which iterates over channels), this fits one model since
% the response is a scalar info variable per observation.
%
% Syntax:
%   results = exploreFNIRS.stats.fitInfoLME(dataTable, 'reactionTime', {'Condition'})
%   results = exploreFNIRS.stats.fitInfoLME(dataTable, 'accuracy', {'Group','Condition'}, ...
%       'AllInteractions', true)
%
% Inputs:
%   dataTable   - Table from Experiment.getSelectedTable() (one row per segment)
%   infoVar     - Response variable name (must be numeric column in dataTable)
%   groupByVars - Cell array of fixed-effect variable names
%
% Name-Value Parameters:
%   RandomEffects     - Random effects formula (default: '1|SubjectID')
%   UseIntercept      - Include intercept (default: true)
%   AllInteractions   - Use full interaction model (default: false)
%   InfoCovariate     - Additional numeric covariate (default: '')
%   CustomFormula     - Override auto-built formula (default: '')
%   ContrastThreshold - p-value threshold for auto-contrasts (default: 0.1)
%   Verbose           - Print progress to console (default: true)
%
% Outputs:
%   results - Struct with fields (compatible with runContrasts/summarize):
%     .model           - LinearMixedModel object
%     .models          - {1x1} cell (for pipeline compatibility)
%     .anova           - {1x1} cell of ANOVA table
%     .anova_pval      - Table of ANOVA p-values
%     .anova_Fstat     - Table of ANOVA F-statistics
%     .anova_df1       - Table of numerator df
%     .anova_df2       - Table of denominator df
%     .contrasts       - {1x1} cell of contrast table
%     .coefficients    - {1x1} cell of random effects
%     .AIC             - Scalar AIC value
%     .formula         - Formula string used
%     .mergedTable     - The dataTable used for fitting
%     .nullComparison  - {1x1} cell of null model comparison
%     .biomarkers      - {infoVar}
%     .channels        - []
%     .groupByVars     - groupByVars
%     .responseVar     - infoVar
%
% Example:
%   ex = exploreFNIRS.core.Experiment(data);
%   ex.groupby({'Condition'});
%   results = ex.statsInfoLME('reactionTime');
%   T = ex.statsSummarize(results, 'Type', 'anova');
%
% See also: exploreFNIRS.stats.fitLME, exploreFNIRS.stats.runContrasts,
%           exploreFNIRS.stats.summarize, exploreFNIRS.core.Experiment

    p = inputParser;
    addRequired(p, 'dataTable', @istable);
    addRequired(p, 'infoVar', @ischar);
    addRequired(p, 'groupByVars', @iscell);
    addParameter(p, 'RandomEffects', '1|SubjectID', @ischar);
    addParameter(p, 'UseIntercept', true, @islogical);
    addParameter(p, 'AllInteractions', false, @islogical);
    addParameter(p, 'InfoCovariate', '', @ischar);
    addParameter(p, 'CustomFormula', '', @ischar);
    addParameter(p, 'ContrastThreshold', 0.1, @isnumeric);
    addParameter(p, 'Verbose', true, @islogical);
    parse(p, dataTable, infoVar, groupByVars, varargin{:});
    opts = p.Results;

    % Validate infoVar exists and is numeric
    if ~ismember(infoVar, dataTable.Properties.VariableNames)
        error('exploreFNIRS:stats:fitInfoLME', ...
            'Variable "%s" not found in dataTable. Available: %s', ...
            infoVar, strjoin(dataTable.Properties.VariableNames, ', '));
    end

    testCol = dataTable.(infoVar);
    if ~isnumeric(testCol)
        error('exploreFNIRS:stats:fitInfoLME', ...
            'Variable "%s" must be numeric (got %s)', infoVar, class(testCol));
    end

    % Remove rows with NaN response
    validRows = ~isnan(dataTable.(infoVar));
    fitTable = dataTable(validRows, :);

    if height(fitTable) < 3
        error('exploreFNIRS:stats:fitInfoLME', ...
            'Too few valid observations (%d) for LME fitting', height(fitTable));
    end

    if opts.Verbose
        fprintf('fitInfoLME: %d valid observations (removed %d NaN)\n', ...
            height(fitTable), sum(~validRows));
    end

    % Initialize results (compatible with fitLME output format)
    results = struct();
    results.model = [];
    results.models = cell(1, 1);
    results.anova = cell(1, 1);
    results.contrasts = cell(1, 1);
    results.AIC = NaN;
    results.formula = '';
    results.mergedTable = fitTable;
    results.anova_pval = table();
    results.anova_Fstat = table();
    results.anova_df1 = table();
    results.anova_df2 = table();
    results.coefficients = cell(1, 1);
    results.nullComparison = cell(1, 1);
    results.biomarkers = {infoVar};
    results.channels = [];
    results.groupByVars = groupByVars;
    results.responseVar = infoVar;

    % Build LME formula
    if ~isempty(opts.CustomFormula)
        lmeString = opts.CustomFormula;
        dummyCodeStr = 'reference';
        if contains(lmeString, '-1+') || contains(lmeString, '~-1')
            dummyCodeStr = 'full';
            lmeString = strrep(lmeString, '*', ':');
        end
    else
        [lmeString, dummyCodeStr] = buildFormula(infoVar, groupByVars, opts);
    end

    results.formula = lmeString;

    % Fit LME
    try
        rng(2019);
        mdl = fitlme(fitTable, lmeString, ...
            'FitMethod', 'REML', 'CheckHessian', true, ...
            'DummyVarCoding', dummyCodeStr);

        results.model = mdl;
        results.models{1, 1} = mdl;
        results.AIC = mdl.ModelCriterion.AIC;

        % ANOVA with Satterthwaite degrees of freedom
        anv = anova(mdl, 'DFMethod', 'satterthwaite');
        results.anova{1, 1} = anv;

        % Store ANOVA results in summary tables
        rowName = infoVar;
        anovaNames = sanitizeNames(anv.Term);

        results.anova_pval{rowName, anovaNames} = anv.pValue(:)';
        results.anova_Fstat{rowName, anovaNames} = anv.FStat(:)';

        try
            results.anova_df1{rowName, anovaNames} = anv.DF1(:)';
            results.anova_df2{rowName, anovaNames} = anv.DF2(:)';
        catch
            results.anova_df1{rowName, anovaNames} = anv.DF(:)';
            results.anova_df2{rowName, anovaNames} = anv.DF(:)';
        end

        % Auto contrasts
        try
            cTable = exploreFNIRS.fx.autoContrast(mdl, opts.ContrastThreshold);
            results.contrasts{1, 1} = cTable;
        catch
            results.contrasts{1, 1} = table();
        end

        % Random effects coefficients
        try
            [~, ~, results.coefficients{1, 1}] = ...
                randomEffects(mdl, 'DFMethod', 'satterthwaite');
        catch
            results.coefficients{1, 1} = [];
        end

        % Null model comparison (ML required for LRT)
        try
            nullStr = sprintf('%s~1+(%s)', infoVar, opts.RandomEffects);
            mdlML = fitlme(fitTable, lmeString, ...
                'FitMethod', 'ML', 'CheckHessian', true, ...
                'DummyVarCoding', dummyCodeStr);
            nullMdl = fitlme(fitTable, nullStr, ...
                'FitMethod', 'ML', 'CheckHessian', true, ...
                'DummyVarCoding', dummyCodeStr);
            results.nullComparison{1, 1} = compare(nullMdl, mdlML);
        catch
            results.nullComparison{1, 1} = [];
        end

        if opts.Verbose
            fprintf('LME [%s]: AIC=%.1f, formula=%s\n', infoVar, results.AIC, lmeString);
            fprintf('\n--- ANOVA p-values ---\n');
            disp(results.anova_pval);
        end

    catch ME
        if opts.Verbose
            fprintf(2, 'LME failed for %s: %s\n', infoVar, ME.message);
        end
    end
end


%% Local helpers

function [lmeString, dummyCodeStr] = buildFormula(varName, groupByVars, opts)
% Build LME formula string from groupby variables and options

    dummyCodeStr = 'reference';

    % Build fixed effects part
    basicParts = {};
    if ~isempty(opts.InfoCovariate)
        basicParts{end+1} = opts.InfoCovariate;
    end

    mdlPrtString = strjoin(basicParts, '*');
    if isempty(mdlPrtString)
        mdlPrtString = '1';
    end

    % Add groupby variables
    if opts.AllInteractions
        curLMEGbyString = mdlPrtString;
        for i = 1:length(groupByVars)
            curLMEGbyString = sprintf('%s*%s', curLMEGbyString, groupByVars{i});
        end
    else
        parts = {};
        for i = 1:length(groupByVars)
            if strcmp(mdlPrtString, '1')
                parts{end+1} = groupByVars{i}; %#ok<AGROW>
            else
                parts{end+1} = sprintf('%s*%s', mdlPrtString, groupByVars{i}); %#ok<AGROW>
            end
        end
        curLMEGbyString = strjoin(parts, '+');
    end

    % Build full formula
    if opts.UseIntercept
        if isempty(curLMEGbyString) || strcmp(curLMEGbyString, '1')
            lmeString = sprintf('%s~1+(%s)', varName, opts.RandomEffects);
        else
            lmeString = sprintf('%s~%s+(%s)', varName, curLMEGbyString, ...
                opts.RandomEffects);
        end
    else
        dummyCodeStr = 'full';
        lmeString = sprintf('%s~-1+%s+(%s)', varName, ...
            strrep(curLMEGbyString, '*', ':'), opts.RandomEffects);
    end
end


function cleanNames = sanitizeNames(names)
% Clean ANOVA term names for use as table variable names
    cleanNames = cell(size(names));
    for i = 1:length(names)
        str = names{i};
        str(str == '(' | str == ')') = '';
        str(str == ':' | str == '_') = '';
        str(str == ' ' | str == '-') = '';
        cleanNames{i} = str;
    end
end
