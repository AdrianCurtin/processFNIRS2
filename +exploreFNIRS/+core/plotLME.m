function [fig, results] = plotLME(groups, groupByVars, varargin)
% PLOTLME Linear Mixed Effects analysis for grouped fNIRS data
%
% Fits LME models per channel using groupby variables as fixed effects.
% Returns fitted models, ANOVA tables, auto-generated contrasts, and
% optionally renders bar charts and topographic F-statistic maps.
%
% Syntax:
%   [fig, results] = plotLME(groups, groupByVars)
%   [fig, results] = plotLME(groups, groupByVars, 'Biomarkers', {'HbO'})
%   [fig, results] = plotLME(groups, groupByVars, 'ShowTopo', true)
%
% Inputs:
%   groups      - Struct array from Experiment.groups (after aggregate())
%   groupByVars - Cell array of grouping variable names used in groupby()
%
% Name-Value Parameters:
%   Biomarkers     - Cell array (default: {'HbO'})
%   Channels       - Vector of channel indices (default: all)
%   RandomEffects  - Random effects formula (default: '1|SubjectID')
%   UseIntercept   - Include intercept (default: true)
%   AllInteractions - Use full interaction model (default: false)
%   InfoCovariate  - Info variable as covariate (default: '')
%   CustomFormula  - Override auto-built formula (default: '')
%   ShowBar        - Show bar chart visualization (default: true)
%   ShowTopo       - Show ANOVA F-stat topo map (default: false)
%   SigThreshold   - Significance threshold (default: 0.05)
%   SigType        - 'p' (default), 'q', 'q-twostep'
%   ErrorType      - 'SEM' (default), 'SD', 'none'
%   Title          - Figure title (default: auto)
%   Visible        - 'on' (default) or 'off'
%   SavePath       - File path to save figure
%   SaveWidth      - Width in pixels (default: 800)
%   SaveHeight     - Height in pixels (default: 500)
%   SaveDPI        - Resolution (default: 150)
%
% Outputs:
%   fig     - Figure handle (empty if no visualization)
%   results - Struct with:
%     .models       - Cell array of LinearMixedModel objects per channel
%     .anova        - Cell array of ANOVA tables per channel
%     .anova_pval   - Table of ANOVA p-values [channels x terms]
%     .anova_Fstat  - Table of ANOVA F-statistics [channels x terms]
%     .coefficients - Cell array of random effects per channel
%     .contrasts    - Cell array of auto-generated contrast tables
%     .AIC          - Vector of AIC values per channel
%     .formula      - The formula string used
%     .mergedTable  - Long-format merged data table
%
% Example:
%   ex = exploreFNIRS.core.Experiment(data);
%   ex.groupby({'Group', 'Condition'});
%   ex.aggregate();
%
%   % Basic LME analysis
%   [fig, results] = ex.plotLME('Biomarkers', {'HbO'}, 'Channels', 1:5);
%   disp(results.anova_pval);
%
%   % With custom formula
%   [fig, results] = ex.plotLME('CustomFormula', ...
%       'Opt1_HbO ~ Group*Condition + (1|SubjectID)');
%
% See also: exploreFNIRS.core.Experiment, exploreFNIRS.fx.autoContrast,
%           fitlme, anova

    p = inputParser;
    addRequired(p, 'groups', @isstruct);
    addRequired(p, 'groupByVars', @iscell);
    addParameter(p, 'Biomarkers', {'HbO'}, @iscell);
    addParameter(p, 'Channels', [], @isnumeric);
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
    parse(p, groups, groupByVars, varargin{:});
    opts = p.Results;

    if ~isempty(opts.SavePath)
        opts.Visible = 'off';
    end

    nGroups = length(groups);
    nBioM = length(opts.Biomarkers);

    % Validate groups have bar-flat data
    for g = 1:nGroups
        if isempty(groups(g).gbyGrandBarFlat)
            error('exploreFNIRS:core:plotLME', ...
                'Group %d has no bar-flat grand average. Call aggregate() first.', g);
        end
    end

    % Determine channels
    if isempty(opts.Channels)
        nCh = size(groups(1).gbyGrandBarFlat.(opts.Biomarkers{1}).data, 2);
        channels = 1:nCh;
    else
        channels = opts.Channels;
        nCh = length(channels);
    end

    % Get time bins
    barTimes = groups(1).gbyGrandBarFlat.time;

    % Build channel labels
    chLabels = arrayfun(@(x) num2str(x), channels, 'UniformOutput', false);

    % Initialize results
    results = struct();
    results.models = cell(nBioM, nCh);
    results.anova = cell(nBioM, nCh);
    results.contrasts = cell(nBioM, nCh);
    results.AIC = nan(nBioM, nCh);
    results.formula = '';
    results.mergedTable = [];
    results.anova_pval = table();
    results.anova_Fstat = table();

    fig = [];

    % Process each biomarker x channel combination
    for bIdx = 1:nBioM
        bioM = opts.Biomarkers{bIdx};

        for chI = 1:nCh
            ch = channels(chI);

            % Build merged long-format table
            mergedTable = exploreFNIRS.export.mergeGbyTablesLong( ...
                groups, {bioM}, ch, barTimes, false, false, chLabels(chI));

            if isempty(mergedTable) || height(mergedTable) == 0
                warning('No data for %s channel %d, skipping', bioM, ch);
                continue;
            end

            % Convert Time to numeric if multiple time bins
            if ismember('Time', mergedTable.Properties.VariableNames)
                if iscell(mergedTable.Time) || isstring(mergedTable.Time)
                    mergedTable.Time = str2double(mergedTable.Time);
                end
            end

            % Build variable name (response)
            varName = sprintf('Opt%s_%s', chLabels{chI}, bioM);

            if ~ismember(varName, mergedTable.Properties.VariableNames)
                warning('Variable %s not found in merged table, skipping', varName);
                continue;
            end

            % Build LME formula
            if ~isempty(opts.CustomFormula)
                lmeString = opts.CustomFormula;
                dummyCodeStr = 'reference';
                if contains(lmeString, '-1+') || contains(lmeString, '~-1')
                    dummyCodeStr = 'full';
                    lmeString = strrep(lmeString, '*', ':');
                end
            else
                [lmeString, dummyCodeStr] = buildFormula(varName, ...
                    groupByVars, opts);
            end

            results.formula = lmeString;
            if bIdx == 1 && chI == 1
                results.mergedTable = mergedTable;
            end

            % Fit LME
            try
                rng(2019);
                mdl = fitlme(mergedTable, lmeString, ...
                    'FitMethod', 'REML', 'CheckHessian', true, ...
                    'DummyVarCoding', dummyCodeStr);

                results.models{bIdx, chI} = mdl;
                results.AIC(bIdx, chI) = mdl.ModelCriterion.AIC;

                % ANOVA
                anv = anova(mdl, 'DFMethod', 'satterthwaite');
                results.anova{bIdx, chI} = anv;

                % Store ANOVA results in summary tables
                chRowName = sprintf('Opt%s_%s', chLabels{chI}, bioM);
                anovaNames = sanitizeNames(anv.Term);

                results.anova_pval{chRowName, anovaNames} = anv.pValue';
                results.anova_Fstat{chRowName, anovaNames} = anv.FStat';

                % Auto contrasts
                try
                    cTable = exploreFNIRS.fx.autoContrast(mdl);
                    results.contrasts{bIdx, chI} = cTable;
                catch
                    results.contrasts{bIdx, chI} = table();
                end

                % Random effects coefficients
                try
                    [~, ~, results.coefficients{bIdx, chI}] = ...
                        randomEffects(mdl, 'DFMethod', 'satterthwaite');
                catch
                    results.coefficients{bIdx, chI} = [];
                end

                % Null model comparison
                try
                    nullStr = sprintf('%s~1+(1|SubjectID)', varName);
                    mdlML = fitlme(mergedTable, lmeString, ...
                        'FitMethod', 'ML', 'CheckHessian', true, ...
                        'DummyVarCoding', dummyCodeStr);
                    nullMdl = fitlme(mergedTable, nullStr, ...
                        'FitMethod', 'ML', 'CheckHessian', true, ...
                        'DummyVarCoding', dummyCodeStr);
                    nullComp = compare(mdlML, nullMdl);
                    results.nullComparison{bIdx, chI} = nullComp;
                catch
                    results.nullComparison{bIdx, chI} = [];
                end

                % Print summary
                fprintf('LME [%s Ch %d]: AIC=%.1f\n', bioM, ch, ...
                    results.AIC(bIdx, chI));

            catch ME
                fprintf(2, 'LME failed for %s Ch %d: %s\n', bioM, ch, ME.message);
            end
        end
    end

    % Print ANOVA summary
    if ~isempty(results.anova_pval) && height(results.anova_pval) > 0
        fprintf('\n--- ANOVA p-values ---\n');
        disp(results.anova_pval);
    end

    % Visualization
    if opts.ShowBar || opts.ShowTopo
        fig = figure('Visible', opts.Visible, ...
            'Position', [100, 100, opts.SaveWidth, opts.SaveHeight], 'Color', 'w');

        if opts.ShowBar && ~opts.ShowTopo
            plotBarSummary(fig, groups, results, opts, channels, chLabels);
        elseif opts.ShowTopo && ~opts.ShowBar
            plotTopoFstat(fig, results, opts);
        else
            % Both: bar on left, topo on right
            plotBarSummary(fig, groups, results, opts, channels, chLabels);
        end

        % Title
        if ~isempty(opts.Title)
            sgtitle(fig, opts.Title);
        else
            sgtitle(fig, sprintf('LME: %s', results.formula));
        end
    end

    % Save
    if ~isempty(opts.SavePath) && ~isempty(fig)
        if ~isempty(which('pf2_base.plot.saveFigure'))
            pf2_base.plot.saveFigure(fig, opts.SavePath, ...
                opts.SaveWidth, opts.SaveHeight, opts.SaveDPI);
        else
            set(fig, 'PaperPositionMode', 'auto');
            print(fig, opts.SavePath, '-dpng', sprintf('-r%d', opts.SaveDPI));
        end
        fprintf('Saved: %s\n', opts.SavePath);
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


function plotBarSummary(fig, groups, results, opts, channels, chLabels)
% Render bar chart summarizing significant ANOVA terms

    nBioM = length(opts.Biomarkers);
    nCh = length(channels);
    colors = exploreFNIRS.core.getGroupColors(length(groups));

    if height(results.anova_pval) == 0
        text(0.5, 0.5, 'No models fitted', ...
            'HorizontalAlignment', 'center', 'Units', 'normalized', ...
            'Parent', axes('Parent', fig));
        return;
    end

    termNames = results.anova_pval.Properties.VariableNames;
    nTerms = length(termNames);

    % One subplot per ANOVA term
    nCols = min(nTerms, 4);
    nRows = ceil(nTerms / nCols);

    for t = 1:nTerms
        ax = subplot(nRows, nCols, t, 'Parent', fig);
        hold(ax, 'on');

        fVals = results.anova_Fstat{:, t};
        pVals = results.anova_pval{:, t};

        % Bar chart of F-values
        bar(ax, 1:height(results.anova_Fstat), fVals, 0.6, ...
            'FaceColor', [0.5, 0.5, 0.8], 'EdgeColor', 'k');

        % Mark significant channels
        for i = 1:length(pVals)
            if pVals(i) < opts.SigThreshold
                text(ax, i, fVals(i), '*', ...
                    'HorizontalAlignment', 'center', ...
                    'VerticalAlignment', 'bottom', ...
                    'FontSize', 14, 'FontWeight', 'bold', 'Color', 'r');
            end
        end

        title(ax, strrep(termNames{t}, '_', ' '));
        xlabel(ax, 'Channel');
        ylabel(ax, 'F-statistic');
        grid(ax, 'on');
        box(ax, 'on');
    end
end


function plotTopoFstat(fig, results, opts)
% Render topographic F-statistic maps

    if height(results.anova_Fstat) == 0
        return;
    end

    termNames = results.anova_Fstat.Properties.VariableNames;
    nTerms = length(termNames);
    nBioM = length(opts.Biomarkers);

    nCols = nTerms;
    nRows = nBioM;

    for t = 1:nTerms
        for bIdx = 1:nBioM
            spIdx = (bIdx - 1) * nCols + t;
            ax = subplot(nRows, nCols, spIdx, 'Parent', fig);

            fVals = results.anova_Fstat{:, t}';
            pVals = results.anova_pval{:, t}';

            % FDR correction
            [curQ, curK] = exploreFNIRS.fx.performFDR(pVals, opts.SigThreshold);

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
                        termNames{t}, 'F-val', 'bufferDistance', 1);
                else
                    bar(ax, fVals, 'FaceColor', 'flat');
                    ylabel(ax, 'F-stat');
                    title(ax, termNames{t});
                end
            else
                text(ax, 0.5, 0.5, sprintf('%s\nn.s.', termNames{t}), ...
                    'HorizontalAlignment', 'center', 'Units', 'normalized');
                axis(ax, 'off');
            end
        end
    end

    sigStr = sprintf('Thresholded at %s=%.2f', opts.SigType, opts.SigThreshold);
    annotation(fig, 'textbox', [0, 0.97, 0.3, 0.03], 'String', sigStr, ...
        'FitBoxToText', 'on', 'EdgeColor', 'none', 'FontSize', 7);
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
