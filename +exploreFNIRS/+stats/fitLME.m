function results = fitLME(groups, groupByVars, varargin)
% FITLME Fit linear mixed-effects models per channel for grouped fNIRS data
%
% Fits LME models per channel using groupby variables as fixed effects,
% with random intercepts for subjects. Returns fitted models, ANOVA tables,
% auto-generated contrasts, and model comparison statistics.
%
% This is the pure statistical engine. For combined analysis and
% visualization, use exploreFNIRS.core.plotLME instead.
%
% Syntax:
%   results = exploreFNIRS.stats.fitLME(groups, groupByVars)
%   results = exploreFNIRS.stats.fitLME(groups, groupByVars, 'Biomarkers', {'HbO'})
%   results = exploreFNIRS.stats.fitLME(groups, groupByVars, 'Channels', 1:5)
%
% Inputs:
%   groups      - Struct array from Experiment.groups (after aggregate())
%   groupByVars - Cell array of grouping variable names used in groupby()
%
% Name-Value Parameters:
%   Biomarkers        - Cell array of biomarker names (default: {'HbO','HbR','HbTotal','CBSI'})
%   Channels          - Vector of channel indices (default: all)
%   RandomEffects     - Random effects formula (default: '1|SubjectID')
%   UseIntercept      - Include intercept (default: true)
%   AllInteractions   - Use full interaction model (default: false)
%   InfoCovariate     - Info variable name as covariate (default: '')
%   CustomFormula     - Override auto-built formula (default: '')
%   ContrastThreshold - p-value threshold for auto-contrasts (default: 0.1)
%   Verbose           - Print progress to console (default: true)
%   ExcludeShortSeparation - Skip short separation channels (default: true)
%   DataType          - 'fNIRS' (default), 'Aux', or 'ROI'
%   AuxField          - Aux field name (required when DataType='Aux')
%   TimeModel         - How to model Time when multiple bins exist (default: 'polynomial'):
%                        'polynomial'  - Orthogonal polynomial time (growth curve analysis)
%                        'discrete'    - Categorical dummy codes (one per bin)
%                        'continuous'  - Centered numeric time (linear trend)
%                        'none'        - Drop Time from model entirely
%   PolynomialOrder   - Degree for polynomial TimeModel (default: 2, range: 1-5)
%   DiscreteTime      - [Deprecated] Use TimeModel instead. true maps to
%                        'discrete', false maps to 'continuous'.
%   ModelFitTest      - Run joint coefficient test H0:all betas=0 (default: true)
%   SkipContrasts     - Skip auto-contrast generation (default: false)
%
% Outputs:
%   results - Struct with fields:
%     .models          - Cell array of LinearMixedModel objects [nBio x nCh]
%     .anova           - Cell array of ANOVA tables [nBio x nCh]
%     .anova_pval      - Table of ANOVA p-values [channels x terms]
%     .anova_Fstat     - Table of ANOVA F-statistics [channels x terms]
%     .anova_df1       - Table of numerator df [channels x terms]
%     .anova_df2       - Table of denominator df [channels x terms]
%     .contrasts       - Cell array of contrast tables [nBio x nCh]
%     .coefficients    - Cell array of random effects [nBio x nCh]
%     .AIC             - Matrix of AIC values [nBio x nCh]
%     .formula         - The formula string used
%     .mergedTable     - Long-format merged data table (first channel)
%     .nullComparison  - Cell array of null model comparisons [nBio x nCh]
%     .biomarkers      - Cell array of biomarker names used
%     .channels        - Channel indices used
%     .groupByVars     - Grouping variables used
%     .coef_pval       - Table of coefficient p-values [channels x coefficients]
%     .coef_tstat      - Table of coefficient t-statistics [channels x coefficients]
%     .coef_df         - Table of coefficient degrees of freedom [channels x coefficients]
%     .modelFit        - Table of joint coefficient test results [channels x {p,F,df1,df2}]
%     .timeModel       - TimeModel string used ('polynomial', 'discrete', etc.)
%     .termLabels      - Struct mapping polynomial terms to readable names
%                        (e.g. termLabels.ot1 = 'Time (Linear)')
%
% Example:
%   ex = exploreFNIRS.core.Experiment(data);
%   ex.groupby({'Group', 'Condition'});
%   ex.aggregate();
%
%   % Fit LME models (statistics only, no visualization)
%   results = exploreFNIRS.stats.fitLME(ex.getGroups(), {'Group','Condition'});
%   disp(results.anova_pval);
%
%   % Summarize results
%   T = exploreFNIRS.stats.summarize(results, 'Type', 'anova');
%
% References:
%   Pinheiro, J. C. & Bates, D. M. (2000). Mixed-Effects Models in S and
%   S-PLUS. Springer. DOI: 10.1007/b98882
%
%   Satterthwaite, F. E. (1946). An approximate distribution of estimates
%   of variance components. Biometrics Bulletin, 2(6), 110-114.
%
%   Mirman, D. (2017). Growth Curve Analysis and Visualization Using R.
%   Chapman and Hall/CRC. DOI: 10.1201/9781315373218
%
% See also: exploreFNIRS.stats.runContrasts, exploreFNIRS.stats.summarize,
%           exploreFNIRS.core.plotLME, exploreFNIRS.fx.autoContrast, fitlme

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
    addParameter(p, 'ContrastThreshold', 0.1, @isnumeric);
    addParameter(p, 'Verbose', true, @islogical);
    addParameter(p, 'DataType', 'fNIRS', @ischar);
    addParameter(p, 'AuxField', '', @ischar);
    addParameter(p, 'ExcludeShortSeparation', true, @islogical);
    addParameter(p, 'SkipTimeFactor', false, @islogical);
    addParameter(p, 'TimeModel', '', @ischar);
    addParameter(p, 'PolynomialOrder', 2, @(x) isnumeric(x) && isscalar(x) && x >= 1 && x <= 5);
    addParameter(p, 'DiscreteTime', [], @islogical);
    addParameter(p, 'ModelFitTest', true, @islogical);
    addParameter(p, 'SkipContrasts', false, @islogical);
    addParameter(p, 'StatWindow', [], @isnumeric);
    parse(p, groups, groupByVars, varargin{:});
    opts = p.Results;

    % Resolve TimeModel from deprecated DiscreteTime if needed
    if ~isempty(opts.DiscreteTime)
        if isempty(opts.TimeModel)
            if opts.DiscreteTime
                opts.TimeModel = 'discrete';
            else
                opts.TimeModel = 'continuous';
            end
            warning('pf2:stats:deprecatedParam', ...
                'DiscreteTime is deprecated. Use TimeModel=''%s'' instead.', ...
                opts.TimeModel);
        end
    end
    if isempty(opts.TimeModel)
        opts.TimeModel = 'polynomial';
    end

    isAux = strcmpi(opts.DataType, 'Aux');
    isROI = strcmpi(opts.DataType, 'ROI');
    if isAux && isempty(opts.AuxField)
        error('exploreFNIRS:stats:fitLME', ...
            'AuxField is required when DataType is ''Aux''');
    end

    nGroups = length(groups);
    nBioM = length(opts.Biomarkers);

    % Validate groups have bar-flat data
    for g = 1:nGroups
        if isempty(groups(g).gbyGrandBarFlat)
            error('exploreFNIRS:stats:fitLME', ...
                'Group %d has no bar-flat grand average. Call aggregate() first.', g);
        end
    end

    % Get time bins from bar-flat data
    barTimes = groups(1).gbyGrandBarFlat.time;

    % Filter time bins by StatWindow
    if ~isempty(opts.StatWindow)
        sw = opts.StatWindow;
        if ~isnumeric(sw) || numel(sw) ~= 2
            error('exploreFNIRS:stats:fitLME:invalidStatWindow', ...
                'StatWindow must be a 2-element numeric vector [start, end].');
        end
        tMask = barTimes >= sw(1) & barTimes <= sw(2);
        barTimes = barTimes(tMask);
        if isempty(barTimes)
            error('exploreFNIRS:stats:fitLME:emptyWindow', ...
                'StatWindow [%.1f, %.1f] contains no time bins. Adjust barBinSize or StatWindow.', sw(1), sw(2));
        end
    end

    if ~isempty(opts.StatWindow) && length(barTimes) == 1 && ...
            length(groups(1).gbyGrandBarFlat.time) == 1
        warning('pf2:stats:singleBin', ...
            'StatWindow has no effect with a single time bin (barBinSize=0). Set barBinSize > 0 for time-resolved analysis.');
    end

    % Auto-include Time as factor when multiple time bins exist
    % (skip for GLM betas where time bins are meaningless)
    hasMultipleTimeBins = length(barTimes) > 1;
    skipTimeInclusion = strcmpi(opts.TimeModel, 'none');
    if hasMultipleTimeBins && ~ismember('Time', groupByVars) && ~opts.SkipTimeFactor && ~skipTimeInclusion
        groupByVars = [groupByVars, {'Time'}];
        if opts.Verbose
            tmLabel = opts.TimeModel;
            if strcmpi(tmLabel, 'polynomial')
                tmLabel = sprintf('polynomial (order %d)', opts.PolynomialOrder);
            end
            fprintf('Multiple time bins (%d). Auto-including Time as %s.\n', ...
                length(barTimes), tmLabel);
        end
    end

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

    if isAux
        % --- Aux mode: iterate over aux channels ---
        auxField = opts.AuxField;

        % Determine aux channel count from grand average
        ga = groups(1).gbyGrandBarFlat;
        [auxDataField, auxVarNames, nAuxCh] = resolveAuxField(ga, auxField);

        if nAuxCh == 0
            error('exploreFNIRS:stats:fitLME', ...
                'Aux field "%s" not found in grand average data.', auxField);
        end

        % Apply Channels filter to aux channels
        if isempty(opts.Channels)
            auxChannels = 1:nAuxCh;
        else
            auxChannels = opts.Channels;
        end
        nCh = length(auxChannels);

        % Build merged table with aux data (use minimal biomarker)
        mergedTable = exploreFNIRS.export.mergeGbyTablesLong( ...
            groups, opts.Biomarkers(1), 1, barTimes, true, false, {'1'});

        if isempty(mergedTable) || height(mergedTable) == 0
            error('exploreFNIRS:stats:fitLME', ...
                'Empty merged table for aux data');
        end

        % Transform Time column based on TimeModel
        mergedTable = prepareTimeColumn(mergedTable, opts, hasMultipleTimeBins);

        % Build aux column names (matching mergeGbyTablesLong convention)
        % Use the resolved field name (may have _data suffix) for column matching
        auxColNames = cell(1, nAuxCh);
        for ch = 1:nAuxCh
            if nAuxCh == 1
                auxColNames{ch} = sprintf('aux_%s', auxDataField);
            elseif ~isempty(auxVarNames)
                auxColNames{ch} = sprintf('aux_%s_%s', auxDataField, auxVarNames{ch});
            else
                auxColNames{ch} = sprintf('aux_%s_%d', auxDataField, ch);
            end
        end

        % If resolved column names not found, try user-friendly names (non-flattened)
        if ~isempty(mergedTable) && ~ismember(auxColNames{1}, mergedTable.Properties.VariableNames)
            for ch = 1:nAuxCh
                if nAuxCh == 1
                    auxColNames{ch} = sprintf('aux_%s', auxField);
                elseif ~isempty(auxVarNames)
                    auxColNames{ch} = sprintf('aux_%s_%s', auxField, auxVarNames{ch});
                else
                    auxColNames{ch} = sprintf('aux_%s_%d', auxField, ch);
                end
            end
        end

        % Initialize results (1 x nAuxCh)
        results = initResults(1, nCh, {auxField}, auxChannels, groupByVars);
        results.mergedTable = mergedTable;

        for chI = 1:nCh
            ch = auxChannels(chI);
            varName = auxColNames{ch};

            if ~ismember(varName, mergedTable.Properties.VariableNames)
                if opts.Verbose
                    warning('Aux variable %s not found in merged table, skipping', varName);
                end
                continue;
            end

            chRowName = varName;
            results = fitOneModel(results, mergedTable, varName, chRowName, ...
                1, chI, groupByVars, opts);

            if opts.Verbose && ~isnan(results.AIC(1, chI))
                fprintf('LME [%s ch %d]: AIC=%.1f\n', auxField, ch, ...
                    results.AIC(1, chI));
            end
        end

    elseif isROI
        % --- ROI mode: iterate over biomarkers x ROIs ---
        ga = groups(1).gbyGrandBarFlat;

        if ~pf2_base.isnestedfield(ga, 'ROI.HbO.data')
            error('exploreFNIRS:stats:fitLME', ...
                'No ROI data in grand average. Define ROIs before aggregating.');
        end

        % Get ROI count and names
        nTotalROIs = size(ga.ROI.(opts.Biomarkers{1}).data, 2);
        if isfield(ga.ROI, 'info') && ~isempty(ga.ROI.info)
            roiLabels = ga.ROI.info.Properties.RowNames;
        else
            roiLabels = arrayfun(@(i) sprintf('ROI%d', i), 1:nTotalROIs, ...
                'UniformOutput', false);
        end

        % Apply Channels filter to ROI indices
        if isempty(opts.Channels)
            roiChannels = 1:nTotalROIs;
        else
            roiChannels = opts.Channels(opts.Channels <= nTotalROIs);
        end
        nROI = length(roiChannels);

        % Initialize results (nBioM x nROI)
        roiChLabels = roiLabels(roiChannels);
        results = initResults(nBioM, nROI, opts.Biomarkers, roiChannels, groupByVars);

        for bIdx = 1:nBioM
            bioM = opts.Biomarkers{bIdx};

            for rI = 1:nROI
                roiIdx = roiChannels(rI);
                roiLabel = roiLabels{roiIdx};

                % Build merged long-format table with ROI data
                mergedTable = exploreFNIRS.export.mergeGbyTablesLong( ...
                    groups, {bioM}, roiIdx, barTimes, false, true, roiChLabels(rI));

                if isempty(mergedTable) || height(mergedTable) == 0
                    if opts.Verbose
                        warning('No data for %s ROI %d (%s), skipping', ...
                            bioM, roiIdx, roiLabel);
                    end
                    continue;
                end

                % Transform Time column based on TimeModel
                mergedTable = prepareTimeColumn(mergedTable, opts, hasMultipleTimeBins);

                % Build response variable name (matches mergeGbyTablesLong ROI convention)
                varName = sprintf('ROI%d_%s_%s', roiIdx, roiLabel, bioM);

                if ~ismember(varName, mergedTable.Properties.VariableNames)
                    if opts.Verbose
                        warning('Variable %s not found in merged table, skipping', varName);
                    end
                    continue;
                end

                chRowName = sprintf('ROI%d_%s_%s', roiIdx, roiLabel, bioM);

                if bIdx == 1 && rI == 1
                    results.mergedTable = mergedTable;
                end

                results = fitOneModel(results, mergedTable, varName, chRowName, ...
                    bIdx, rI, groupByVars, opts);

                if opts.Verbose && ~isnan(results.AIC(bIdx, rI))
                    fprintf('LME [%s ROI %d %s]: AIC=%.1f\n', bioM, roiIdx, ...
                        roiLabel, results.AIC(bIdx, rI));
                end
            end
        end

    else
        % --- Standard fNIRS mode ---

        % Determine channels
        if isempty(opts.Channels)
            nCh = size(groups(1).gbyGrandBarFlat.(opts.Biomarkers{1}).data, 2);
            channels = 1:nCh;
        else
            channels = opts.Channels;
            nCh = length(channels);
        end

        % Exclude short separation channels if requested
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

        % Build channel labels
        chLabels = arrayfun(@(x) num2str(x), channels, 'UniformOutput', false);

        % Initialize results
        results = initResults(nBioM, nCh, opts.Biomarkers, channels, groupByVars);

        % Determine whether to use parfor for channel loop
        nTotal = nBioM * nCh;
        useParfor = false;
        if nTotal > 4
            [canUse, poolRunning] = pf2_base.accel.canParfor();
            useParfor = canUse && poolRunning;
        end

        if useParfor && nBioM == 1
            % Single-biomarker parallel path: parfor over channels
            bioM = opts.Biomarkers{1};
            parResults = cell(nCh, 1);
            firstTable = [];

            parfor chI = 1:nCh
                ch = channels(chI);
                mTable = exploreFNIRS.export.mergeGbyTablesLong( ...
                    groups, {bioM}, ch, barTimes, false, false, chLabels(chI));
                if isempty(mTable) || height(mTable) == 0
                    continue;
                end
                mTable = prepareTimeColumn(mTable, opts, hasMultipleTimeBins);
                varName = sprintf('Opt%s_%s', chLabels{chI}, bioM);
                if ~ismember(varName, mTable.Properties.VariableNames)
                    continue;
                end
                chRowName = sprintf('Opt%s_%s', chLabels{chI}, bioM);
                tmpRes = initResults(1, 1, {bioM}, ch, groupByVars);
                tmpRes = fitOneModel(tmpRes, mTable, varName, chRowName, ...
                    1, 1, groupByVars, opts);
                parResults{chI} = struct('tmpRes', tmpRes, 'mTable', mTable, ...
                    'chRowName', chRowName);
            end

            % Merge parallel results back
            for chI = 1:nCh
                if isempty(parResults{chI}), continue; end
                pr = parResults{chI};
                results.models{1, chI} = pr.tmpRes.models{1, 1};
                results.anova{1, chI} = pr.tmpRes.anova{1, 1};
                results.contrasts{1, chI} = pr.tmpRes.contrasts{1, 1};
                results.coefficients{1, chI} = pr.tmpRes.coefficients{1, 1};
                results.nullComparison{1, chI} = pr.tmpRes.nullComparison{1, 1};
                results.AIC(1, chI) = pr.tmpRes.AIC(1, 1);
                if ~isempty(pr.tmpRes.anova_pval) && height(pr.tmpRes.anova_pval) > 0
                    aCols = pr.tmpRes.anova_pval.Properties.VariableNames;
                    results.anova_pval{pr.chRowName, aCols} = pr.tmpRes.anova_pval{1, :};
                    results.anova_Fstat{pr.chRowName, aCols} = pr.tmpRes.anova_Fstat{1, :};
                    if height(pr.tmpRes.anova_df1) > 0
                        results.anova_df1{pr.chRowName, aCols} = pr.tmpRes.anova_df1{1, :};
                        results.anova_df2{pr.chRowName, aCols} = pr.tmpRes.anova_df2{1, :};
                    end
                end
                if ~isempty(pr.tmpRes.coef_pval) && height(pr.tmpRes.coef_pval) > 0
                    cCols = pr.tmpRes.coef_pval.Properties.VariableNames;
                    results.coef_pval{pr.chRowName, cCols} = pr.tmpRes.coef_pval{1, :};
                    results.coef_tstat{pr.chRowName, cCols} = pr.tmpRes.coef_tstat{1, :};
                    results.coef_df{pr.chRowName, cCols} = pr.tmpRes.coef_df{1, :};
                end
                if ~isempty(pr.tmpRes.modelFit) && height(pr.tmpRes.modelFit) > 0
                    results.modelFit{pr.chRowName, pr.tmpRes.modelFit.Properties.VariableNames} = ...
                        pr.tmpRes.modelFit{1, :};
                end
                if isempty(firstTable)
                    firstTable = pr.mTable;
                end
                if opts.Verbose && ~isnan(results.AIC(1, chI))
                    fprintf('LME [%s Ch %d]: AIC=%.1f\n', bioM, channels(chI), ...
                        results.AIC(1, chI));
                end
            end
            if ~isempty(firstTable)
                results.mergedTable = firstTable;
            end
        else
            % Serial path (or multi-biomarker)
            for bIdx = 1:nBioM
                bioM = opts.Biomarkers{bIdx};

                for chI = 1:nCh
                    ch = channels(chI);

                    % Build merged long-format table
                    mergedTable = exploreFNIRS.export.mergeGbyTablesLong( ...
                        groups, {bioM}, ch, barTimes, false, false, chLabels(chI));

                    if isempty(mergedTable) || height(mergedTable) == 0
                        if opts.Verbose
                            warning('No data for %s channel %d, skipping', bioM, ch);
                        end
                        continue;
                    end

                    % Transform Time column based on TimeModel
                    mergedTable = prepareTimeColumn(mergedTable, opts, hasMultipleTimeBins);

                    % Build variable name (response)
                    varName = sprintf('Opt%s_%s', chLabels{chI}, bioM);

                    if ~ismember(varName, mergedTable.Properties.VariableNames)
                        if opts.Verbose
                            warning('Variable %s not found in merged table, skipping', varName);
                        end
                        continue;
                    end

                    chRowName = sprintf('Opt%s_%s', chLabels{chI}, bioM);

                    if bIdx == 1 && chI == 1
                        results.mergedTable = mergedTable;
                    end

                    results = fitOneModel(results, mergedTable, varName, chRowName, ...
                        bIdx, chI, groupByVars, opts);

                    if opts.Verbose && ~isnan(results.AIC(bIdx, chI))
                        fprintf('LME [%s Ch %d]: AIC=%.1f\n', bioM, ch, ...
                            results.AIC(bIdx, chI));
                    end
                end
            end
        end
    end

    results.statWindow = opts.StatWindow;
    results.timeModel = opts.TimeModel;

    % Build readable term labels for polynomial terms
    if strcmpi(opts.TimeModel, 'polynomial')
        results.termLabels = buildTermLabels(opts.PolynomialOrder);
    end

    % Print ANOVA summary
    if opts.Verbose && ~isempty(results.anova_pval) && height(results.anova_pval) > 0
        fprintf('\n--- ANOVA p-values ---\n');
        disp(results.anova_pval);
    end
end


%% Local helpers

function [lmeString, dummyCodeStr] = buildFormula(varName, groupByVars, opts)
% Build LME formula string from groupby variables and options

    dummyCodeStr = 'reference';
    isPolyTime = strcmpi(opts.TimeModel, 'polynomial') && any(strcmpi(groupByVars, 'Time'));

    % Separate polynomial time terms from regular groupby vars
    if isPolyTime
        nonTimeVars = groupByVars(~strcmpi(groupByVars, 'Time'));
    else
        nonTimeVars = groupByVars;
    end

    % Build fixed effects part
    basicParts = {};
    if ~isempty(opts.InfoCovariate)
        basicParts{end+1} = opts.InfoCovariate;
    end

    mdlPrtString = strjoin(basicParts, '*');
    if isempty(mdlPrtString)
        mdlPrtString = '1';
    end

    % Add groupby variables (excluding Time for polynomial mode)
    if opts.AllInteractions
        curLMEGbyString = mdlPrtString;
        for i = 1:length(nonTimeVars)
            curLMEGbyString = sprintf('%s*%s', curLMEGbyString, nonTimeVars{i});
        end
    else
        parts = {};
        for i = 1:length(nonTimeVars)
            if strcmp(mdlPrtString, '1')
                parts{end+1} = nonTimeVars{i}; %#ok<AGROW>
            else
                parts{end+1} = sprintf('%s*%s', mdlPrtString, nonTimeVars{i}); %#ok<AGROW>
            end
        end
        curLMEGbyString = strjoin(parts, '+');
    end

    % Append polynomial time terms and interactions
    if isPolyTime
        polyOrder = opts.PolynomialOrder;
        otTerms = arrayfun(@(k) sprintf('ot%d', k), 1:polyOrder, ...
            'UniformOutput', false);

        % Main effects: ot1 + ot2 + ot3
        polyMain = strjoin(otTerms, '+');

        % Interactions: each non-Time groupby var x each ot term
        polyInteract = {};
        for i = 1:length(nonTimeVars)
            for k = 1:polyOrder
                polyInteract{end+1} = sprintf('%s:ot%d', nonTimeVars{i}, k); %#ok<AGROW>
            end
        end
        polyInteractStr = strjoin(polyInteract, '+');

        if isempty(curLMEGbyString) || strcmp(curLMEGbyString, '1')
            curLMEGbyString = polyMain;
        else
            curLMEGbyString = sprintf('%s+%s', curLMEGbyString, polyMain);
        end
        if ~isempty(polyInteractStr)
            curLMEGbyString = sprintf('%s+%s', curLMEGbyString, polyInteractStr);
        end
    end

    % Random effects: upgrade to random slope for polynomial time
    randomFx = opts.RandomEffects;
    if isPolyTime && strcmp(randomFx, '1|SubjectID')
        randomFx = '1+ot1|SubjectID';
    end

    % Build full formula
    if opts.UseIntercept
        if isempty(curLMEGbyString) || strcmp(curLMEGbyString, '1')
            lmeString = sprintf('%s~1+(%s)', varName, randomFx);
        else
            lmeString = sprintf('%s~%s+(%s)', varName, curLMEGbyString, ...
                randomFx);
        end
    else
        dummyCodeStr = 'full';
        lmeString = sprintf('%s~-1+%s+(%s)', varName, ...
            strrep(curLMEGbyString, '*', ':'), randomFx);
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


function results = initResults(nBioM, nCh, biomarkers, channels, groupByVars)
% Initialize an empty results struct with correct dimensions
    results = struct();
    results.models = cell(nBioM, nCh);
    results.anova = cell(nBioM, nCh);
    results.contrasts = cell(nBioM, nCh);
    results.AIC = nan(nBioM, nCh);
    results.formula = '';
    results.mergedTable = [];
    results.anova_pval = table();
    results.anova_Fstat = table();
    results.anova_df1 = table();
    results.anova_df2 = table();
    results.coefficients = cell(nBioM, nCh);
    results.nullComparison = cell(nBioM, nCh);
    results.coef_pval = table();
    results.coef_tstat = table();
    results.coef_df = table();
    results.modelFit = table();
    results.biomarkers = biomarkers;
    results.channels = channels;
    results.groupByVars = groupByVars;
    results.statWindow = [];
    results.termLabels = struct();
end


function results = fitOneModel(results, mergedTable, varName, chRowName, ...
    bIdx, chI, groupByVars, opts)
% Fit a single LME model and store results
%
% Extracted from the channel loop to share between fNIRS and Aux modes.

    % Build LME formula
    if ~isempty(opts.CustomFormula)
        lmeString = opts.CustomFormula;
        dummyCodeStr = 'reference';
        if contains(lmeString, '-1+') || contains(lmeString, '~-1')
            dummyCodeStr = 'full';
            lmeString = strrep(lmeString, '*', ':');
        end
    else
        [lmeString, dummyCodeStr] = buildFormula(varName, groupByVars, opts);
    end

    results.formula = lmeString;

    % Suppress MATLAB's own fitlme rank/Hessian spam when not verbose.
    % Scoped to the specific LME identifiers (not a blanket off-all), so
    % unrelated warnings still surface; restored when cleanupObj clears.
    if ~opts.Verbose
        cleanupObj = exploreFNIRS.stats.suppressLMEWarnings(); %#ok<NASGU>
    end

    try
        rng(2019);
        mdl = fitlme(mergedTable, lmeString, ...
            'FitMethod', 'REML', 'CheckHessian', true, ...
            'DummyVarCoding', dummyCodeStr);

        results.models{bIdx, chI} = mdl;
        results.AIC(bIdx, chI) = mdl.ModelCriterion.AIC;
    catch ME_fit
        % Convergence fallback: if polynomial random slope failed, retry
        % with intercept-only random effects
        if contains(lmeString, '1+ot1|SubjectID')
            fallbackFormula = strrep(lmeString, '1+ot1|SubjectID', '1|SubjectID');
            try
                if opts.Verbose
                    warning('pf2:stats:polyFallback', ...
                        'Random slope model failed for %s. Falling back to (1|SubjectID).', ...
                        varName);
                end
                rng(2019);
                mdl = fitlme(mergedTable, fallbackFormula, ...
                    'FitMethod', 'REML', 'CheckHessian', true, ...
                    'DummyVarCoding', dummyCodeStr);
                lmeString = fallbackFormula;
                results.formula = lmeString;
                results.models{bIdx, chI} = mdl;
                results.AIC(bIdx, chI) = mdl.ModelCriterion.AIC;
            catch ME_fallback
                if opts.Verbose
                    warning('pf2:stats:lmeFailed', ...
                        'LME failed for %s (fallback also failed): %s', ...
                        varName, ME_fallback.message);
                end
                return;
            end
        else
            if opts.Verbose
                warning('pf2:stats:lmeFailed', ...
                    'LME failed for %s: %s', varName, ME_fit.message);
            end
            return;
        end
    end

    try
        % ANOVA with Satterthwaite degrees of freedom
        anv = anova(mdl, 'DFMethod', 'satterthwaite');
        results.anova{bIdx, chI} = anv;

        % Store ANOVA results in summary tables
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
        if ~opts.SkipContrasts
            try
                cTable = exploreFNIRS.fx.autoContrast(mdl, opts.ContrastThreshold);
                results.contrasts{bIdx, chI} = cTable;
            catch
                results.contrasts{bIdx, chI} = table();
            end
        end

        % Random effects coefficients
        try
            [~, ~, reCoefs] = randomEffects(mdl, 'DFMethod', 'satterthwaite');
            results.coefficients{bIdx, chI} = reCoefs;

            % Store coefficient summary tables
            coefNames = reCoefs.Name;
            cleanCoefNames = sanitizeNames(coefNames);
            results.coef_pval{chRowName, cleanCoefNames} = reCoefs.pValue(:)';
            results.coef_tstat{chRowName, cleanCoefNames} = reCoefs.tStat(:)';
            results.coef_df{chRowName, cleanCoefNames} = reCoefs.DF(:)';
        catch
            results.coefficients{bIdx, chI} = [];
        end

        % Model fit test (joint H0: all fixed-effect betas = 0)
        if opts.ModelFitTest
            try
                mdlTest = eye(length(mdl.Coefficients.Name));
                if opts.UseIntercept
                    mdlTest = mdlTest(2:end,:);
                end
                [mfP, mfF, mfDF1, mfDF2] = coefTest(mdl, mdlTest, ...
                    zeros(size(mdlTest,1),1), 'DFMethod', 'satterthwaite');
                results.modelFit{chRowName, {'p','F','df1','df2'}} = ...
                    [mfP, mfF, mfDF1, mfDF2];
            catch
            end
        end

        % Null model comparison (ML required for LRT)
        try
            nullStr = sprintf('%s~1+(%s)', varName, opts.RandomEffects);
            mdlML = fitlme(mergedTable, lmeString, ...
                'FitMethod', 'ML', 'CheckHessian', true, ...
                'DummyVarCoding', dummyCodeStr);
            nullMdl = fitlme(mergedTable, nullStr, ...
                'FitMethod', 'ML', 'CheckHessian', true, ...
                'DummyVarCoding', dummyCodeStr);
            results.nullComparison{bIdx, chI} = compare(nullMdl, mdlML);
        catch
            results.nullComparison{bIdx, chI} = [];
        end

    catch ME
        if opts.Verbose
            warning('pf2:stats:lmeFailed', ...
                'LME failed for %s: %s', varName, ME.message);
        end
    end
end


function labels = buildTermLabels(polyOrder)
% BUILDTERMLABELS Map polynomial term names to readable labels
%
% Returns a struct where field names are the sanitized ANOVA term names
% (e.g. 'ot1') and values are readable strings (e.g. 'Time (Linear)').

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


function T = prepareTimeColumn(T, opts, hasMultipleTimeBins)
% PREPARETIMECOLUMN Transform Time column based on TimeModel setting
%
% Handles conversion from raw time values to the representation needed
% for the selected TimeModel: polynomial, discrete, continuous, or none.

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
            % Orthogonal polynomial coding via QR decomposition
            % Center time to [-1, 1] then compute ot1..otK
            timeVals = T.Time;
            uTime = unique(timeVals);
            nBins = length(uTime);
            polyOrder = min(opts.PolynomialOrder, nBins - 1);

            % Map to [-1, 1]
            tMin = min(uTime);
            tMax = max(uTime);
            if tMax == tMin
                tNorm = zeros(size(uTime));
            else
                tNorm = 2 * (uTime - tMin) / (tMax - tMin) - 1;
            end

            % Build raw polynomial matrix and orthogonalize via QR
            rawPoly = zeros(nBins, polyOrder);
            for k = 1:polyOrder
                rawPoly(:, k) = tNorm .^ k;
            end
            [Q, ~] = qr(rawPoly, 0);

            % Map each observation's time bin to its orthogonal polynomial values
            [~, binIdx] = ismember(timeVals, uTime);
            for k = 1:polyOrder
                colName = sprintf('ot%d', k);
                T.(colName) = Q(binIdx, k);
            end

            % Remove Time column (polynomial terms replace it)
            T.Time = [];

        case 'discrete'
            % Categorical dummy codes (original DiscreteTime=true behavior)
            T.Time = categorical(T.Time);

        case 'continuous'
            % Center numeric time around mean
            T.Time = T.Time - mean(T.Time);

        case 'none'
            % Drop Time entirely
            T.Time = [];
    end
end


function [auxDataField, auxVarNames, nAuxCh] = resolveAuxField(ga, auxField)
% Resolve aux field name in grand average, handling _data suffix convention

    auxDataField = '';
    auxVarNames = {};
    nAuxCh = 0;

    if ~isfield(ga, 'Aux') || ~isstruct(ga.Aux)
        return;
    end

    % Try direct field name first, then _data suffix
    if isfield(ga.Aux, auxField)
        actualField = auxField;
    elseif isfield(ga.Aux, [auxField '_data'])
        actualField = [auxField '_data'];
    else
        return;
    end

    auxData = ga.Aux.(actualField);
    if ~isstruct(auxData) || ~isfield(auxData, 'data')
        return;
    end

    auxDataField = actualField;
    nAuxCh = size(auxData.data, 2);

    if isfield(auxData, 'varNames')
        auxVarNames = auxData.varNames;
    end
end


function ssIdx = getShortSeparationIdx(groups)
% GETSHORTSEPARATIONIDX Get indices of short separation channels from probe info

    ssIdx = [];

    % Try first subject in first group
    if isempty(groups) || isempty(groups(1).gbyFNIRS)
        return;
    end

    fNIR = groups(1).gbyFNIRS{1};

    % First check if probeinfo is directly on the struct
    probeInfo = [];
    if isfield(fNIR, 'probeinfo') && isfield(fNIR.probeinfo, 'Probe') ...
            && iscell(fNIR.probeinfo.Probe) && ~isempty(fNIR.probeinfo.Probe)
        probeInfo = fNIR.probeinfo.Probe{1};
    elseif isfield(fNIR, 'info') && isfield(fNIR.info, 'probename') ...
            && ~isempty(fNIR.info.probename) && ~contains(fNIR.info.probename, 'Unknown')
        % Load probe info from device config file
        try
            device = pf2_base.loadDeviceCfg(fNIR.info.probename);
            if isstruct(device) && isfield(device, 'Probe') ...
                    && iscell(device.Probe) && ~isempty(device.Probe)
                probeInfo = device.Probe{1};
            end
        catch ME
            warning('exploreFNIRS:stats:fitLME', ...
                'Could not load probe config for "%s": %s', ...
                fNIR.info.probename, ME.message);
            return;
        end
    end

    if isempty(probeInfo)
        return;
    end

    % TableOpt is a MATLAB table, not a struct — use ismember for variable check
    if isfield(probeInfo, 'TableOpt') && istable(probeInfo.TableOpt) ...
            && ismember('IsShortSeparation', probeInfo.TableOpt.Properties.VariableNames)
        ssIdx = find(probeInfo.TableOpt.IsShortSeparation(:)');
    elseif isfield(probeInfo, 'NumShortSeparation') && probeInfo.NumShortSeparation > 0 ...
            && isfield(probeInfo, 'TableOpt') && istable(probeInfo.TableOpt) ...
            && ismember('SD', probeInfo.TableOpt.Properties.VariableNames)
        % Fallback: use SD distance < 2 cm
        ssIdx = find(probeInfo.TableOpt.SD(:)' < 2);
    end
end
