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
%   DiscreteTime      - Convert Time to categorical (default: true). When false,
%                        Time remains numeric for continuous regression.
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
    addParameter(p, 'DiscreteTime', true, @islogical);
    addParameter(p, 'ModelFitTest', true, @islogical);
    addParameter(p, 'SkipContrasts', false, @islogical);
    parse(p, groups, groupByVars, varargin{:});
    opts = p.Results;

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

    % Auto-include Time as factor when multiple time bins exist
    % (skip for GLM betas where time bins are meaningless)
    hasMultipleTimeBins = length(barTimes) > 1;
    if hasMultipleTimeBins && ~ismember('Time', groupByVars) && ~opts.SkipTimeFactor
        groupByVars = [groupByVars, {'Time'}];
        if opts.Verbose
            fprintf('Multiple time bins (%d). Auto-including Time as fixed effect.\n', ...
                length(barTimes));
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

        % Convert Time to categorical for use as factor
        if ismember('Time', mergedTable.Properties.VariableNames)
            if iscell(mergedTable.Time) || isstring(mergedTable.Time)
                mergedTable.Time = str2double(mergedTable.Time);
            end
            if hasMultipleTimeBins && opts.DiscreteTime
                mergedTable.Time = categorical(mergedTable.Time);
            end
        end

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

                % Convert Time to categorical for use as factor
                if ismember('Time', mergedTable.Properties.VariableNames)
                    if iscell(mergedTable.Time) || isstring(mergedTable.Time)
                        mergedTable.Time = str2double(mergedTable.Time);
                    end
                    if hasMultipleTimeBins && opts.DiscreteTime
                        mergedTable.Time = categorical(mergedTable.Time);
                    end
                end

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
                if ismember('Time', mTable.Properties.VariableNames)
                    if iscell(mTable.Time) || isstring(mTable.Time)
                        mTable.Time = str2double(mTable.Time);
                    end
                    if hasMultipleTimeBins && opts.DiscreteTime
                        mTable.Time = categorical(mTable.Time);
                    end
                end
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

                    % Convert Time to categorical for use as factor
                    if ismember('Time', mergedTable.Properties.VariableNames)
                        if iscell(mergedTable.Time) || isstring(mergedTable.Time)
                            mergedTable.Time = str2double(mergedTable.Time);
                        end
                        if hasMultipleTimeBins && opts.DiscreteTime
                            mergedTable.Time = categorical(mergedTable.Time);
                        end
                    end

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

    try
        rng(2019);
        mdl = fitlme(mergedTable, lmeString, ...
            'FitMethod', 'REML', 'CheckHessian', true, ...
            'DummyVarCoding', dummyCodeStr);

        results.models{bIdx, chI} = mdl;
        results.AIC(bIdx, chI) = mdl.ModelCriterion.AIC;

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
            fprintf(2, 'LME failed for %s: %s\n', varName, ME.message);
        end
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
