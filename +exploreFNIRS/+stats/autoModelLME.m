function results = autoModelLME(groups, groupByVars, varargin)
% AUTOMODELLME Automatic per-channel LME model selection via forward stepwise IC
%
% Discovers which factors (Group, Condition, Session, Gender, etc.) matter
% for each channel independently using forward stepwise selection with
% information criteria (AIC/BIC). ML fitting is used for model comparison;
% the final selected model is refit with REML for unbiased variance.
%
% Syntax:
%   results = exploreFNIRS.stats.autoModelLME(groups, groupByVars)
%   results = exploreFNIRS.stats.autoModelLME(groups, groupByVars, 'Criterion', 'BIC')
%   results = exploreFNIRS.stats.autoModelLME(groups, groupByVars, 'Biomarkers', {'HbO'})
%
% Inputs:
%   groups      - Struct array from Experiment.groups (after aggregate())
%   groupByVars - Cell array of grouping variable names used in groupby()
%
% Name-Value Parameters:
%   Candidates     - Cell array of predictor names to try (default: auto-discover)
%   Criterion      - 'AIC' or 'BIC' (default: 'AIC')
%   DeltaThreshold - Min IC improvement to retain a term (default: 2)
%   MaxTerms       - Max fixed-effect terms (default: floor(N/2))
%   TryInteractions - Try pairwise interactions after main effects (default: true)
%   Biomarkers     - Cell array of biomarker names (default: {'HbO','HbR','HbTotal','CBSI'})
%   Channels       - Vector of channel indices (default: all)
%   DataType       - 'fNIRS' or 'ROI' (default: 'fNIRS')
%   TimeModel      - Time handling: 'polynomial'|'discrete'|'continuous'|'none' (default: 'polynomial')
%   PolynomialOrder - Polynomial degree (default: 2)
%   AlwaysIncludeTime - Time terms in base model, not subject to selection (default: true)
%   RandomEffects  - Random effects formula (default: '1|SubjectID')
%   StatWindow     - Time bin filter [start, end] (default: [])
%   Verbose        - Print progress to console (default: true)
%   ExcludeShortSeparation - Skip short separation channels (default: true)
%   ContrastThreshold - p-value threshold for auto-contrasts (default: 0.1)
%   ResponseVar    - Info variable name to use as response (default: '')
%                    When set, the response is the named info variable (e.g.
%                    'reactionTime') and each channel's biomarker column becomes
%                    a candidate predictor. Discovers whether brain activation
%                    predicts the behavioral outcome.
%
% Outputs:
%   results - Struct with fields:
%     .bestModels       - {nBio x nCh} LinearMixedModel objects (REML)
%     .bestFormulas     - {nBio x nCh} formula strings
%     .bestAIC          - [nBio x nCh] AIC of best model
%     .bestBIC          - [nBio x nCh] BIC of best model
%     .selectedTerms    - {nBio x nCh} cell of selected term name lists
%     .selectionPath    - {nBio x nCh} struct arrays with selection history
%     .comparisonTable  - Table: Biomarker, Channel, Step, Term, AIC, BIC, DeltaIC, Selected
%     .models           - Alias for bestModels (fitLME compatibility)
%     .anova            - {nBio x nCh} ANOVA tables
%     .anova_pval       - Table of ANOVA p-values [channels x terms]
%     .anova_Fstat      - Table of ANOVA F-statistics [channels x terms]
%     .contrasts        - {nBio x nCh} contrast tables
%     .AIC              - Alias for bestAIC
%     .nullComparison   - {nBio x nCh} null model comparison
%     .formula          - 'auto' (per-channel formulas differ)
%     .responseVar      - ResponseVar name (empty in normal mode)
%     .biomarkers, .channels, .groupByVars, .mergedTable
%     .candidates       - Cell of candidate predictor names tested
%     .criterion        - 'AIC' or 'BIC'
%     .timeModel        - TimeModel string used
%     .termLabels       - Struct mapping polynomial terms to readable names
%
% Example:
%   ex = exploreFNIRS.core.Experiment(data);
%   ex.groupby({'Group'});
%   ex.aggregate();
%   results = ex.statsAutoLME('Biomarkers', {'HbO'}, 'Channels', 1:3);
%   disp(results.bestFormulas);
%   disp(results.comparisonTable);
%
%   % Compatible with existing summary pipeline
%   T = exploreFNIRS.stats.summarize(results, 'Type', 'anova');
%
% References:
%   Burnham, K. P. & Anderson, D. R. (2002). Model Selection and
%   Multimodel Inference: A Practical Information-Theoretic Approach (2nd
%   ed.). Springer. DOI: 10.1007/b97636
%
%   Pinheiro, J. C. & Bates, D. M. (2000). Mixed-Effects Models in S and
%   S-PLUS. Springer. DOI: 10.1007/b98882
%
% See also: exploreFNIRS.stats.fitLME, exploreFNIRS.stats.summarize,
%           exploreFNIRS.fx.autoContrast, fitlme

    p = inputParser;
    addRequired(p, 'groups', @isstruct);
    addRequired(p, 'groupByVars', @iscell);
    addParameter(p, 'Candidates', {}, @iscell);
    addParameter(p, 'Criterion', 'AIC', @(x) ismember(upper(x), {'AIC','BIC'}));
    addParameter(p, 'DeltaThreshold', 2, @(x) isnumeric(x) && isscalar(x) && x > 0);
    addParameter(p, 'MaxTerms', [], @(x) isnumeric(x) && isscalar(x) && x > 0);
    addParameter(p, 'TryInteractions', true, @islogical);
    addParameter(p, 'Biomarkers', {'HbO','HbR','HbTotal','CBSI'}, @iscell);
    addParameter(p, 'Channels', [], @isnumeric);
    addParameter(p, 'DataType', 'fNIRS', @ischar);
    addParameter(p, 'TimeModel', 'polynomial', @ischar);
    addParameter(p, 'PolynomialOrder', 2, @(x) isnumeric(x) && isscalar(x) && x >= 1 && x <= 5);
    addParameter(p, 'AlwaysIncludeTime', true, @islogical);
    addParameter(p, 'RandomEffects', '1|SubjectID', @ischar);
    addParameter(p, 'StatWindow', [], @isnumeric);
    addParameter(p, 'Verbose', true, @islogical);
    addParameter(p, 'ExcludeShortSeparation', true, @islogical);
    addParameter(p, 'ContrastThreshold', 0.1, @isnumeric);
    addParameter(p, 'ResponseVar', '', @ischar);
    addParameter(p, 'ForcedTerms', {}, @iscell);
    % Aux columns (aux_*) are excluded from predictors by default. Opt in by
    % naming the auxiliary signals to promote to candidate covariates (e.g.
    % {'heartRate','gsr'}); use {'all'} to admit every aux_ column.
    addParameter(p, 'AuxCovariates', {}, @iscell);
    parse(p, groups, groupByVars, varargin{:});
    opts = p.Results;
    opts.Criterion = upper(opts.Criterion);

    isROI = strcmpi(opts.DataType, 'ROI');

    nGroups = length(groups);
    nBioM = length(opts.Biomarkers);

    % Validate groups have bar-flat data
    for g = 1:nGroups
        if isempty(groups(g).gbyGrandBarFlat)
            error('exploreFNIRS:stats:autoModelLME', ...
                'Group %d has no bar-flat grand average. Call aggregate() first.', g);
        end
    end

    % Get time bins from bar-flat data
    barTimes = groups(1).gbyGrandBarFlat.time;

    % Filter time bins by StatWindow
    if ~isempty(opts.StatWindow)
        sw = opts.StatWindow;
        tMask = barTimes >= sw(1) & barTimes <= sw(2);
        barTimes = barTimes(tMask);
        if isempty(barTimes)
            error('exploreFNIRS:stats:autoModelLME:emptyWindow', ...
                'StatWindow [%.1f, %.1f] contains no time bins.', sw(1), sw(2));
        end
    end

    hasMultipleTimeBins = length(barTimes) > 1;

    % Clamp PolynomialOrder to available time bins
    if strcmpi(opts.TimeModel, 'polynomial') && hasMultipleTimeBins
        maxOrder = length(barTimes) - 1;
        if opts.PolynomialOrder > maxOrder
            if opts.Verbose
                fprintf('Clamping PolynomialOrder from %d to %d (%d time bins).\n', ...
                    opts.PolynomialOrder, maxOrder, length(barTimes));
            end
            opts.PolynomialOrder = maxOrder;
        end
    end

    if isROI
        % --- ROI mode ---
        ga = groups(1).gbyGrandBarFlat;
        if ~pf2_base.isnestedfield(ga, 'ROI.HbO.data')
            error('exploreFNIRS:stats:autoModelLME', ...
                'No ROI data. Define ROIs before aggregating.');
        end
        nTotalROIs = size(ga.ROI.(opts.Biomarkers{1}).data, 2);
        if isfield(ga.ROI, 'info') && ~isempty(ga.ROI.info)
            roiLabels = ga.ROI.info.Properties.RowNames;
        else
            roiLabels = arrayfun(@(i) sprintf('ROI%d', i), 1:nTotalROIs, ...
                'UniformOutput', false);
        end
        if isempty(opts.Channels)
            roiChannels = 1:nTotalROIs;
        else
            roiChannels = opts.Channels(opts.Channels <= nTotalROIs);
        end
        nCh = length(roiChannels);
        channels = roiChannels;
        chLabels = roiLabels(roiChannels);
    else
        % --- Standard fNIRS mode ---
        if isempty(opts.Channels)
            nCh = size(groups(1).gbyGrandBarFlat.(opts.Biomarkers{1}).data, 2);
            channels = 1:nCh;
        else
            channels = opts.Channels;
            nCh = length(channels);
        end

        % Exclude short separation channels
        if opts.ExcludeShortSeparation
            ssIdx = getShortSeparationIdx(groups);
            if ~isempty(ssIdx)
                channels = channels(~ismember(channels, ssIdx));
                nCh = length(channels);
                if opts.Verbose
                    fprintf('Excluding %d short separation channels\n', length(ssIdx));
                end
            end
        end

        chLabels = arrayfun(@(x) num2str(x), channels, 'UniformOutput', false);
    end

    % Initialize results
    results = struct();
    results.bestModels = cell(nBioM, nCh);
    results.bestFormulas = cell(nBioM, nCh);
    results.bestAIC = nan(nBioM, nCh);
    results.bestBIC = nan(nBioM, nCh);
    results.selectedTerms = cell(nBioM, nCh);
    results.selectionPath = cell(nBioM, nCh);

    % fitLME-compatible fields
    results.models = cell(nBioM, nCh);
    results.anova = cell(nBioM, nCh);
    results.anova_pval = table();
    results.anova_Fstat = table();
    results.anova_df1 = table();
    results.anova_df2 = table();
    results.contrasts = cell(nBioM, nCh);
    results.coefficients = cell(nBioM, nCh);
    results.nullComparison = cell(nBioM, nCh);
    results.AIC = nan(nBioM, nCh);
    results.coef_pval = table();
    results.coef_tstat = table();
    results.coef_df = table();
    results.modelFit = table();
    results.formula = 'auto';
    results.mergedTable = [];
    results.biomarkers = opts.Biomarkers;
    results.channels = channels;
    results.groupByVars = groupByVars;
    results.statWindow = opts.StatWindow;
    results.candidates = {};
    results.criterion = opts.Criterion;
    results.responseVar = opts.ResponseVar;
    results.timeModel = opts.TimeModel;
    results.termLabels = struct();

    % Comparison table accumulator
    compRows = {};

    for bIdx = 1:nBioM
        bioM = opts.Biomarkers{bIdx};

        for chI = 1:nCh
            ch = channels(chI);

            % Build merged long-format table (biomarker as the value column).
            % Note: mergeGbyTablesLong with exportAux=true *replaces* the
            % biomarker column with aux columns, so aux covariates are joined
            % on separately below rather than requested here.
            if isROI
                mergedTable = exploreFNIRS.export.mergeGbyTablesLong( ...
                    groups, {bioM}, ch, barTimes, false, true, chLabels(chI));
                varName = sprintf('ROI%d_%s_%s', ch, chLabels{chI}, bioM);
            else
                mergedTable = exploreFNIRS.export.mergeGbyTablesLong( ...
                    groups, {bioM}, ch, barTimes, false, false, chLabels(chI));
                varName = sprintf('Opt%s_%s', chLabels{chI}, bioM);
            end

            % Aux covariate opt-in: build an aux-bearing table over the same
            % rows and graft the whitelisted aux_ columns onto mergedTable.
            if ~isempty(opts.AuxCovariates) && ~isempty(mergedTable)
                mergedTable = appendAuxColumns(mergedTable, groups, bioM, ch, ...
                    barTimes, isROI, chLabels(chI), opts.AuxCovariates);
            end

            if isempty(mergedTable) || height(mergedTable) == 0
                if opts.Verbose
                    warning('No data for %s channel %d, skipping', bioM, ch);
                end
                continue;
            end

            % Transform Time column based on TimeModel
            mergedTable = prepareTimeColumn(mergedTable, opts, hasMultipleTimeBins);

            if ~ismember(varName, mergedTable.Properties.VariableNames)
                if opts.Verbose
                    warning('Variable %s not found in merged table, skipping', varName);
                end
                continue;
            end

            % Determine response and biomarker predictor column
            if ~isempty(opts.ResponseVar)
                % ResponseVar mode: behavioral response, biomarker as predictor
                if ~ismember(opts.ResponseVar, mergedTable.Properties.VariableNames)
                    if opts.Verbose
                        warning('ResponseVar %s not found in table, skipping', opts.ResponseVar);
                    end
                    continue;
                end
                responseCol = opts.ResponseVar;
                biomarkerCol = varName;
            else
                responseCol = varName;
                biomarkerCol = '';
            end

            if ~isfield(results, 'mergedTable') || isempty(results.mergedTable)
                results.mergedTable = mergedTable;
            end

            % Count unique subjects for parameter budget
            if ismember('SubjectID', mergedTable.Properties.VariableNames)
                nSubjects = length(unique(mergedTable.SubjectID));
            else
                nSubjects = height(mergedTable);
            end

            if isempty(opts.MaxTerms)
                maxTerms = floor(nSubjects / 2);
            else
                maxTerms = opts.MaxTerms;
            end

            % Discover or validate candidates
            candidates = discoverCandidates(mergedTable, responseCol, nSubjects, ...
                opts, hasMultipleTimeBins, biomarkerCol);

            if isempty(results.candidates)
                results.candidates = candidates;
            end

            % Build base time terms
            baseTimeTerms = {};
            if opts.AlwaysIncludeTime && hasMultipleTimeBins && ...
                    ~strcmpi(opts.TimeModel, 'none')
                if strcmpi(opts.TimeModel, 'polynomial')
                    for k = 1:opts.PolynomialOrder
                        baseTimeTerms{end+1} = sprintf('ot%d', k); %#ok<AGROW>
                    end
                elseif strcmpi(opts.TimeModel, 'discrete')
                    baseTimeTerms = {'Time'};
                elseif strcmpi(opts.TimeModel, 'continuous')
                    baseTimeTerms = {'Time'};
                end
            end

            % Prepend forced terms (always included in base model)
            forcedTerms = {};
            for fi = 1:numel(opts.ForcedTerms)
                ft = opts.ForcedTerms{fi};
                if ismember(ft, mergedTable.Properties.VariableNames)
                    forcedTerms{end+1} = ft; %#ok<AGROW>
                elseif opts.Verbose
                    warning('ForcedTerm "%s" not found in merged table, skipping', ft);
                end
            end
            baseTimeTerms = [forcedTerms, baseTimeTerms];

            randomFx = opts.RandomEffects;

            % ---- Forward stepwise selection ----
            currentTerms = {};
            baseFormula = buildFormulaFromTerms(responseCol, [baseTimeTerms, currentTerms], randomFx);

            % Fit base model with ML
            [~, baseIC] = fitModelML(mergedTable, baseFormula, opts.Criterion);
            currentIC = baseIC;

            selPath = struct('step', {}, 'termAdded', {}, 'IC', {}, ...
                'deltaIC', {}, 'formula', {}, 'converged', {});

            % Record base model in path
            selPath(end+1) = struct('step', 0, 'termAdded', 'base', ...
                'IC', baseIC, 'deltaIC', 0, ...
                'formula', baseFormula, 'converged', isfinite(baseIC));

            if opts.Verbose
                if ~isempty(opts.ResponseVar)
                    fprintf('Auto model [%s ~ %s Ch %d]: base %s=%.1f\n', ...
                        opts.ResponseVar, bioM, ch, opts.Criterion, baseIC);
                else
                    fprintf('Auto model [%s Ch %d]: base %s=%.1f\n', ...
                        bioM, ch, opts.Criterion, baseIC);
                end
            end

            % Step 1: Forward selection of main effects
            remaining = candidates;
            stepNum = 0;

            while ~isempty(remaining) && length(currentTerms) < maxTerms
                bestDelta = -Inf;
                bestIdx = 0;
                bestIC_trial = Inf;

                for ci = 1:length(remaining)
                    trialTerms = [currentTerms, remaining(ci)];
                    allTerms = [baseTimeTerms, trialTerms];

                    % Check parameter budget
                    nDf = countDf(allTerms, mergedTable);
                    if nDf >= nSubjects - 2
                        continue;
                    end

                    trialFormula = buildFormulaFromTerms(responseCol, allTerms, randomFx);
                    [~, trialIC] = fitModelML(mergedTable, trialFormula, opts.Criterion);

                    delta = currentIC - trialIC;

                    if opts.Verbose
                        convergedStr = '';
                        if ~isfinite(trialIC)
                            convergedStr = ' [failed]';
                        end
                        marker = '';
                        if delta >= opts.DeltaThreshold
                            marker = ' *';
                        end
                        fprintf('  +%-14s %s=%.1f (delta=%.1f)%s%s\n', ...
                            remaining{ci}, opts.Criterion, trialIC, delta, ...
                            marker, convergedStr);
                    end

                    if delta > bestDelta
                        bestDelta = delta;
                        bestIdx = ci;
                        bestIC_trial = trialIC;
                    end
                end

                if bestDelta >= opts.DeltaThreshold
                    stepNum = stepNum + 1;
                    selectedTerm = remaining{bestIdx};
                    currentTerms{end+1} = selectedTerm; %#ok<AGROW>
                    currentIC = bestIC_trial;
                    remaining(bestIdx) = [];

                    curFormula = buildFormulaFromTerms(responseCol, ...
                        [baseTimeTerms, currentTerms], randomFx);

                    selPath(end+1) = struct('step', stepNum, ...
                        'termAdded', selectedTerm, ...
                        'IC', bestIC_trial, 'deltaIC', bestDelta, ...
                        'formula', curFormula, 'converged', true); %#ok<AGROW>

                    if opts.Verbose
                        fprintf('  -> selected %s (%s=%.1f)\n', ...
                            selectedTerm, opts.Criterion, bestIC_trial);
                    end

                    % Add to comparison table
                    compRows{end+1} = {bioM, ch, stepNum, selectedTerm, ...
                        bestIC_trial, nan, bestDelta, true}; %#ok<AGROW>
                else
                    break;
                end
            end

            % Step 2: Forward selection of interactions
            if opts.TryInteractions && length(currentTerms) >= 2
                interactionCandidates = {};

                % Pairwise interactions among selected main effects
                for a = 1:length(currentTerms)
                    for b = (a+1):length(currentTerms)
                        interactionCandidates{end+1} = sprintf('%s:%s', ...
                            currentTerms{a}, currentTerms{b}); %#ok<AGROW>
                    end
                end

                % Interactions with time polynomial terms
                if strcmpi(opts.TimeModel, 'polynomial') && hasMultipleTimeBins
                    for a = 1:length(currentTerms)
                        for k = 1:opts.PolynomialOrder
                            interactionCandidates{end+1} = sprintf('%s:ot%d', ...
                                currentTerms{a}, k); %#ok<AGROW>
                        end
                    end
                end

                remainingInt = interactionCandidates;

                while ~isempty(remainingInt) && ...
                        (length(currentTerms) + length(baseTimeTerms)) < maxTerms
                    bestDelta = -Inf;
                    bestIdx = 0;
                    bestIC_trial = Inf;

                    for ci = 1:length(remainingInt)
                        trialTerms = [currentTerms, remainingInt(ci)];
                        allTerms = [baseTimeTerms, trialTerms];

                        nDf = countDf(allTerms, mergedTable);
                        if nDf >= nSubjects - 2
                            continue;
                        end

                        trialFormula = buildFormulaFromTerms(responseCol, allTerms, randomFx);
                        [~, trialIC] = fitModelML(mergedTable, trialFormula, opts.Criterion);

                        delta = currentIC - trialIC;

                        if opts.Verbose
                            convergedStr = '';
                            if ~isfinite(trialIC)
                                convergedStr = ' [failed]';
                            end
                            marker = '';
                            if delta >= opts.DeltaThreshold
                                marker = ' *';
                            end
                            fprintf('  +%-14s %s=%.1f (delta=%.1f)%s%s\n', ...
                                remainingInt{ci}, opts.Criterion, trialIC, delta, ...
                                marker, convergedStr);
                        end

                        if delta > bestDelta
                            bestDelta = delta;
                            bestIdx = ci;
                            bestIC_trial = trialIC;
                        end
                    end

                    if bestDelta >= opts.DeltaThreshold
                        stepNum = stepNum + 1;
                        selectedTerm = remainingInt{bestIdx};
                        currentTerms{end+1} = selectedTerm; %#ok<AGROW>
                        currentIC = bestIC_trial;
                        remainingInt(bestIdx) = [];

                        curFormula = buildFormulaFromTerms(responseCol, ...
                            [baseTimeTerms, currentTerms], randomFx);

                        selPath(end+1) = struct('step', stepNum, ...
                            'termAdded', selectedTerm, ...
                            'IC', bestIC_trial, 'deltaIC', bestDelta, ...
                            'formula', curFormula, 'converged', true); %#ok<AGROW>

                        if opts.Verbose
                            fprintf('  -> selected %s (%s=%.1f)\n', ...
                                selectedTerm, opts.Criterion, bestIC_trial);
                        end

                        compRows{end+1} = {bioM, ch, stepNum, selectedTerm, ...
                            bestIC_trial, nan, bestDelta, true}; %#ok<AGROW>
                    else
                        break;
                    end
                end
            end

            % ---- Refit final model with REML ----
            allFinalTerms = [baseTimeTerms, currentTerms];
            finalFormula = buildFormulaFromTerms(responseCol, allFinalTerms, randomFx);

            results.bestFormulas{bIdx, chI} = finalFormula;
            results.selectedTerms{bIdx, chI} = currentTerms;
            results.selectionPath{bIdx, chI} = selPath;

            if opts.Verbose
                fprintf('  Best: %s\n', finalFormula);
            end

            % Fit final model with REML
            try
                rng(2019);
                mdl = fitlme(mergedTable, finalFormula, ...
                    'FitMethod', 'REML', 'CheckHessian', true, ...
                    'DummyVarCoding', 'reference');

                results.bestModels{bIdx, chI} = mdl;
                results.models{bIdx, chI} = mdl;
                results.bestAIC(bIdx, chI) = mdl.ModelCriterion.AIC;
                results.bestBIC(bIdx, chI) = mdl.ModelCriterion.BIC;
                results.AIC(bIdx, chI) = mdl.ModelCriterion.AIC;
            catch ME
                if opts.Verbose
                    warning('pf2:stats:autoModelLME:refitFailed', ...
                        'REML refit failed for %s Ch %d: %s', bioM, ch, ME.message);
                end
                continue;
            end

            % Extract ANOVA, contrasts, null comparison (same as fitLME)
            if isROI
                chRowName = sprintf('ROI%d_%s_%s', ch, chLabels{chI}, bioM);
            else
                chRowName = sprintf('Opt%s_%s', chLabels{chI}, bioM);
            end

            results = extractModelStats(results, mergedTable, mdl, ...
                responseCol, chRowName, bIdx, chI, randomFx, finalFormula, opts);
        end
    end

    % Build comparison table
    if ~isempty(compRows)
        compData = vertcat(compRows{:});
        results.comparisonTable = table( ...
            compData(:,1), compData(:,2), compData(:,3), compData(:,4), ...
            compData(:,5), compData(:,6), compData(:,7), compData(:,8), ...
            'VariableNames', {'Biomarker','Channel','Step','Term', ...
            'AIC','BIC','DeltaIC','Selected'});
        % Convert numeric columns
        results.comparisonTable.Channel = cell2mat(results.comparisonTable.Channel);
        results.comparisonTable.Step = cell2mat(results.comparisonTable.Step);
        results.comparisonTable.AIC = cell2mat(results.comparisonTable.AIC);
        results.comparisonTable.BIC = cell2mat(results.comparisonTable.BIC);
        results.comparisonTable.DeltaIC = cell2mat(results.comparisonTable.DeltaIC);
        results.comparisonTable.Selected = cell2mat(results.comparisonTable.Selected);
    else
        results.comparisonTable = table();
    end

    % Build term labels for polynomial terms
    if strcmpi(opts.TimeModel, 'polynomial')
        results.termLabels = buildTermLabels(opts.PolynomialOrder);
    end

    % Print ANOVA summary
    if opts.Verbose && ~isempty(results.anova_pval) && height(results.anova_pval) > 0
        fprintf('\n--- ANOVA p-values ---\n');
        disp(results.anova_pval);
    end
end


%% Local helper functions

function candidates = discoverCandidates(T, responseVar, nSubjects, opts, hasMultiTime, biomarkerCol)
% DISCOVERCANDIDATES Auto-detect valid predictor columns from merged table
%
% Excludes response, SubjectID, time columns, other biomarker/ROI/aux columns,
% and missingFNIRS. Validates categorical (2+ levels, levels <= N/2) and
% numeric (non-zero variance) columns.
%
% When biomarkerCol is non-empty (ResponseVar mode), the specified biomarker
% column is included as a candidate while other Opt/ROI columns are excluded.

    if nargin < 6, biomarkerCol = ''; end

    if ~isempty(opts.Candidates)
        % User-provided: validate they exist in table
        candidates = opts.Candidates;
        valid = ismember(candidates, T.Properties.VariableNames);
        if any(~valid)
            warning('pf2:stats:autoModelLME:badCandidate', ...
                'Candidate(s) not found in table: %s', ...
                strjoin(candidates(~valid), ', '));
            candidates = candidates(valid);
        end
        return;
    end

    isResponseVarMode = ~isempty(biomarkerCol);

    allVars = T.Properties.VariableNames;

    % Patterns to exclude
    excludeExact = {responseVar, 'SubjectID', 'missingFNIRS', ...
        'Time', 'TimeStart', 'TimeEnd'};

    % Exclude polynomial time columns
    for k = 1:10
        excludeExact{end+1} = sprintf('ot%d', k); %#ok<AGROW>
    end

    % Exclude by prefix patterns
    if isResponseVarMode
        % In ResponseVar mode, don't blanket-exclude Opt/ROI — handle per-var
        excludePrefixes = {'aux_'};
    else
        excludePrefixes = {'Opt', 'ROI', 'aux_'};
    end

    % Also exclude other biomarker columns
    bioNames = {'HbO','HbR','HbTotal','HbDiff','CBSI'};

    % Aux covariate opt-in: aux_ columns matching this whitelist are promoted
    % to candidate predictors instead of being excluded.
    auxWhitelist = {};
    if isfield(opts, 'AuxCovariates')
        auxWhitelist = opts.AuxCovariates;
    end

    candidates = {};
    for i = 1:length(allVars)
        vn = allVars{i};

        % Exact match exclusion
        if ismember(vn, excludeExact)
            continue;
        end

        % Aux opt-in: skip the aux_ prefix exclusion for whitelisted signals
        if startsWith(vn, 'aux_') && isAuxWhitelisted(vn, auxWhitelist)
            col = T.(vn);
            if isnumeric(col)
                vals = col(~isnan(col));
                if ~isempty(vals) && var(vals) > 0
                    candidates{end+1} = vn; %#ok<AGROW>
                end
            end
            continue;
        end

        % In ResponseVar mode: include biomarkerCol, skip other Opt/ROI columns
        if isResponseVarMode && (startsWith(vn, 'Opt') || startsWith(vn, 'ROI'))
            if ~strcmp(vn, biomarkerCol)
                continue;
            end
            % biomarkerCol passes through to validation below
        end

        % Prefix exclusion
        skip = false;
        for px = 1:length(excludePrefixes)
            if startsWith(vn, excludePrefixes{px})
                skip = true;
                break;
            end
        end
        if skip, continue; end

        % Exclude columns containing biomarker names (skip in ResponseVar mode
        % for the biomarkerCol itself, which contains a biomarker suffix)
        if ~isResponseVarMode || ~strcmp(vn, biomarkerCol)
            skipBio = false;
            for bn = 1:length(bioNames)
                if contains(vn, bioNames{bn})
                    skipBio = true;
                    break;
                end
            end
            if skipBio, continue; end
        end

        col = T.(vn);

        % Categorical or string/cell: need 2+ levels, levels <= N/2
        if iscategorical(col) || iscell(col) || isstring(col)
            if iscell(col) || isstring(col)
                uLevels = unique(string(col));
                uLevels = uLevels(~ismissing(uLevels));
            else
                uLevels = categories(col);
            end
            nLevels = length(uLevels);
            if nLevels >= 2 && nLevels <= nSubjects / 2
                candidates{end+1} = vn; %#ok<AGROW>
            end
        elseif isnumeric(col)
            % Numeric: need non-zero variance
            vals = col(~isnan(col));
            if ~isempty(vals) && var(vals) > 0
                candidates{end+1} = vn; %#ok<AGROW>
            end
        end
    end
end


function T = appendAuxColumns(T, groups, bioM, ch, barTimes, isROI, chLabel, whitelist)
% APPENDAUXCOLUMNS Graft whitelisted aux_ columns onto a biomarker long-table
%
% Builds an aux-bearing long table over the same grouping/channel/time rows
% (mergeGbyTablesLong with exportAux=true) and copies the aux_ columns matching
% the AuxCovariates whitelist into T. Rows are matched on the shared identifier
% columns (grouping/channel/time) via a key, NOT by row position, so each
% covariate value lands on the correct outcome row even if the two tables are
% ordered differently. Skips quietly if it cannot align (so model selection
% proceeds on the biomarker table).
    try
        auxT = exploreFNIRS.export.mergeGbyTablesLong( ...
            groups, {bioM}, ch, barTimes, true, isROI, chLabel);
    catch
        return;
    end
    if isempty(auxT)
        return;
    end

    % Which aux_ columns to copy: whitelisted, not an aux time column, and not
    % already present in T.
    avn = auxT.Properties.VariableNames;
    isAux = startsWith(avn, 'aux_') & ~endsWith(lower(avn), '_time');
    auxCols = avn(isAux);
    keep = false(1, numel(auxCols));
    for i = 1:numel(auxCols)
        keep(i) = isAuxWhitelisted(auxCols{i}, whitelist) ...
            && ~ismember(auxCols{i}, T.Properties.VariableNames);
    end
    auxCols = auxCols(keep);
    if isempty(auxCols)
        return;
    end

    % Identifier columns = columns shared by both tables that are neither aux_
    % columns nor the biomarker value columns (which end in _<bioM> and carry
    % NaNs that defeat equality matching). Build a per-row string key from them.
    shared = intersect(T.Properties.VariableNames, avn, 'stable');
    isId = ~startsWith(shared, 'aux_') & ~endsWith(shared, ['_' bioM]);
    keyCols = shared(isId);

    keyT = buildRowKey(T, keyCols);
    keyA = buildRowKey(auxT, keyCols);

    % Use the key only when it is complete and unambiguous: every aux row has a
    % unique key and every T row maps to one. Otherwise fall back to a
    % positional copy when the heights already match.
    if ~isempty(keyCols) && numel(unique(keyA)) == numel(keyA)
        [tf, loc] = ismember(keyT, keyA);
        if all(tf)
            for i = 1:numel(auxCols)
                col = auxT.(auxCols{i});
                T.(auxCols{i}) = col(loc, :);
            end
            return;
        end
    end

    if height(auxT) == height(T)
        for i = 1:numel(auxCols)
            T.(auxCols{i}) = auxT.(auxCols{i});
        end
    end
end


function key = buildRowKey(T, keyCols)
% BUILDROWKEY Per-row string key built from the given identifier columns
    n = height(T);
    if isempty(keyCols)
        key = strings(n, 1);
        return;
    end
    parts = strings(n, numel(keyCols));
    for c = 1:numel(keyCols)
        col = T.(keyCols{c});
        if isnumeric(col) || islogical(col)
            parts(:, c) = string(num2str(col(:), '%.10g'));
        else
            parts(:, c) = string(col(:));
        end
    end
    key = join(parts, char(31), 2);   % unit-separator-joined composite key
end


function tf = isAuxWhitelisted(vn, whitelist)
% ISAUXWHITELISTED True if an aux_ column is opted in as a candidate covariate
%   Matches when the whitelist contains 'all'/'*', the exact column name, or a
%   token contained in the column name (e.g. 'heartRate' matches
%   'aux_heartRate_HR').
    tf = false;
    if isempty(whitelist)
        return;
    end
    if any(strcmpi(whitelist, 'all')) || any(strcmp(whitelist, '*'))
        tf = true;
        return;
    end
    for k = 1:numel(whitelist)
        tok = whitelist{k};
        if isempty(tok)
            continue;
        end
        if strcmpi(vn, tok) || contains(lower(vn), lower(tok))
            tf = true;
            return;
        end
    end
end


function formula = buildFormulaFromTerms(response, terms, randomEffects)
% BUILDFORMULAFROMTERMS Assemble formula string from term list and random effects

    if isempty(terms)
        fixedStr = '1';
    else
        fixedStr = strjoin(terms, '+');
    end

    formula = sprintf('%s~%s+(%s)', response, fixedStr, randomEffects);
end


function nDf = countDf(terms, T)
% COUNTDF Estimate total fixed-effect parameters from term list
%
% For categorical variables, df = nLevels - 1 (reference coding).
% For numeric, df = 1. For interactions A:B, df = product of component dfs.

    nDf = 1; % intercept

    for i = 1:length(terms)
        termStr = terms{i};
        parts = strsplit(termStr, ':');

        termDf = 1;
        for j = 1:length(parts)
            pName = parts{j};
            if ismember(pName, T.Properties.VariableNames)
                col = T.(pName);
                if iscategorical(col) || iscell(col) || isstring(col)
                    if iscell(col) || isstring(col)
                        nLevels = length(unique(string(col(~ismissing(col)))));
                    else
                        nLevels = length(categories(col));
                    end
                    termDf = termDf * max(nLevels - 1, 1);
                else
                    termDf = termDf * 1;
                end
            else
                % Unknown column (e.g. ot1 numeric) — 1 df
                termDf = termDf * 1;
            end
        end

        nDf = nDf + termDf;
    end
end


function [mdl, ic] = fitModelML(T, formula, criterion)
% FITMODELML Fit LME with ML and return model + IC value (Inf on failure)

    mdl = [];
    ic = Inf;

    try
        rng(2019);
        mdl = fitlme(T, formula, 'FitMethod', 'ML', ...
            'CheckHessian', true, 'DummyVarCoding', 'reference');

        if strcmp(criterion, 'AIC')
            ic = mdl.ModelCriterion.AIC;
        else
            ic = mdl.ModelCriterion.BIC;
        end
    catch
        % Convergence failure — return Inf
    end
end


function results = extractModelStats(results, mergedTable, mdl, ...
    varName, chRowName, bIdx, chI, randomEffects, finalFormula, opts)
% EXTRACTMODELSTATS Extract ANOVA, contrasts, coefficients, null comparison

    try
        anv = anova(mdl, 'DFMethod', 'satterthwaite');
        results.anova{bIdx, chI} = anv;

        anovaNames = sanitizeNames(anv.Term);

        results.anova_pval{chRowName, anovaNames} = anv.pValue(:)';
        results.anova_Fstat{chRowName, anovaNames} = anv.FStat(:)';

        try
            results.anova_df1{chRowName, anovaNames} = anv.DF1(:)';
            results.anova_df2{chRowName, anovaNames} = anv.DF2(:)';
        catch
            results.anova_df1{chRowName, anovaNames} = anv.DF(:)';
            results.anova_df2{chRowName, anovaNames} = anv.DF(:)';
        end

        % Auto contrasts
        try
            cTable = exploreFNIRS.fx.autoContrast(mdl, opts.ContrastThreshold);
            results.contrasts{bIdx, chI} = cTable;
        catch
            results.contrasts{bIdx, chI} = table();
        end

        % Random effects coefficients
        try
            [~, ~, reCoefs] = randomEffects(mdl, 'DFMethod', 'satterthwaite');
            results.coefficients{bIdx, chI} = reCoefs;

            coefNames = reCoefs.Name;
            cleanCoefNames = sanitizeNames(coefNames);
            results.coef_pval{chRowName, cleanCoefNames} = reCoefs.pValue(:)';
            results.coef_tstat{chRowName, cleanCoefNames} = reCoefs.tStat(:)';
            results.coef_df{chRowName, cleanCoefNames} = reCoefs.DF(:)';
        catch
            results.coefficients{bIdx, chI} = [];
        end

        % Model fit test
        try
            mdlTest = eye(length(mdl.Coefficients.Name));
            mdlTest = mdlTest(2:end,:);
            if ~isempty(mdlTest)
                [mfP, mfF, mfDF1, mfDF2] = coefTest(mdl, mdlTest, ...
                    zeros(size(mdlTest,1),1), 'DFMethod', 'satterthwaite');
                results.modelFit{chRowName, {'p','F','df1','df2'}} = ...
                    [mfP, mfF, mfDF1, mfDF2];
            end
        catch
        end

        % Null model comparison (ML for LRT)
        try
            nullStr = sprintf('%s~1+(%s)', varName, randomEffects);
            mdlML = fitlme(mergedTable, finalFormula, ...
                'FitMethod', 'ML', 'CheckHessian', true, ...
                'DummyVarCoding', 'reference');
            nullMdl = fitlme(mergedTable, nullStr, ...
                'FitMethod', 'ML', 'CheckHessian', true, ...
                'DummyVarCoding', 'reference');
            results.nullComparison{bIdx, chI} = compare(nullMdl, mdlML);
        catch
            results.nullComparison{bIdx, chI} = [];
        end

    catch ME
        if opts.Verbose
            warning('pf2:stats:autoModelLME', ...
                'Stats extraction failed for %s: %s', chRowName, ME.message);
        end
    end
end


function cleanNames = sanitizeNames(names)
% SANITIZENAMES Clean ANOVA term names for use as table variable names
    cleanNames = cell(size(names));
    for i = 1:length(names)
        str = names{i};
        str(str == '(' | str == ')') = '';
        str(str == ':' | str == '_') = '';
        str(str == ' ' | str == '-') = '';
        cleanNames{i} = str;
    end
end


function T = prepareTimeColumn(T, opts, hasMultipleTimeBins)
% PREPARETIMECOLUMN Transform Time column based on TimeModel setting

    if ~ismember('Time', T.Properties.VariableNames)
        return;
    end

    % Ensure numeric
    if iscell(T.Time) || isstring(T.Time)
        T.Time = str2double(T.Time);
    end

    if ~hasMultipleTimeBins
        return;
    end

    switch lower(opts.TimeModel)
        case 'polynomial'
            timeVals = T.Time;
            uTime = unique(timeVals);
            nBins = length(uTime);
            polyOrder = min(opts.PolynomialOrder, nBins - 1);

            tMin = min(uTime);
            tMax = max(uTime);
            if tMax == tMin
                tNorm = zeros(size(uTime));
            else
                tNorm = 2 * (uTime - tMin) / (tMax - tMin) - 1;
            end

            rawPoly = zeros(nBins, polyOrder);
            for k = 1:polyOrder
                rawPoly(:, k) = tNorm .^ k;
            end
            [Q, ~] = qr(rawPoly, 0);

            [~, binIdx] = ismember(timeVals, uTime);
            for k = 1:polyOrder
                colName = sprintf('ot%d', k);
                T.(colName) = Q(binIdx, k);
            end

            T.Time = [];

        case 'discrete'
            T.Time = categorical(T.Time);

        case 'continuous'
            T.Time = T.Time - mean(T.Time);

        case 'none'
            T.Time = [];
    end
end


function labels = buildTermLabels(polyOrder)
% BUILDTERMLABELS Map polynomial term names to readable labels
    ordinalNames = {'Linear', 'Quadratic', 'Cubic', 'Quartic', 'Quintic'};
    labels = struct();
    for k = 1:polyOrder
        termName = sprintf('ot%d', k);
        if k <= length(ordinalNames)
            labels.(termName) = sprintf('Time (%s)', ordinalNames{k});
        else
            labels.(termName) = sprintf('Time (Order %d)', k);
        end
    end
end


function ssIdx = getShortSeparationIdx(groups)
% GETSHORTSEPARATIONIDX Get indices of short separation channels from probe info

    ssIdx = [];

    if isempty(groups) || isempty(groups(1).gbyFNIRS)
        return;
    end

    fNIR = groups(1).gbyFNIRS{1};

    probeInfo = [];
    if isfield(fNIR, 'probeinfo') && isfield(fNIR.probeinfo, 'Probe') ...
            && iscell(fNIR.probeinfo.Probe) && ~isempty(fNIR.probeinfo.Probe)
        probeInfo = fNIR.probeinfo.Probe{1};
    elseif isfield(fNIR, 'info') && isfield(fNIR.info, 'probename') ...
            && ~isempty(fNIR.info.probename) && ~contains(fNIR.info.probename, 'Unknown')
        try
            device = pf2_base.loadDeviceCfg(fNIR.info.probename);
            if isstruct(device) && isfield(device, 'Probe') ...
                    && iscell(device.Probe) && ~isempty(device.Probe)
                probeInfo = device.Probe{1};
            end
        catch
            return;
        end
    end

    if isempty(probeInfo)
        return;
    end

    if isfield(probeInfo, 'TableOpt') && istable(probeInfo.TableOpt) ...
            && ismember('IsShortSeparation', probeInfo.TableOpt.Properties.VariableNames)
        ssIdx = find(probeInfo.TableOpt.IsShortSeparation(:)');
    elseif isfield(probeInfo, 'NumShortSeparation') && probeInfo.NumShortSeparation > 0 ...
            && isfield(probeInfo, 'TableOpt') && istable(probeInfo.TableOpt) ...
            && ismember('SD', probeInfo.TableOpt.Properties.VariableNames)
        ssIdx = find(probeInfo.TableOpt.SD(:)' < 2);
    end
end
