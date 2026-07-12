function T = summarize(lmeResults, varargin)
% SUMMARIZE Publication-ready summary tables from LME results
%
% Formats ANOVA results, contrast tests, fixed-effect coefficients, or
% model fit statistics from exploreFNIRS.stats.fitLME into a single clean
% table. Optionally generates APA-style formatted strings.
%
% Syntax:
%   T = exploreFNIRS.stats.summarize(results)
%   T = exploreFNIRS.stats.summarize(results, 'Type', 'anova')
%   T = exploreFNIRS.stats.summarize(results, 'Type', 'contrasts', 'Format', 'apa')
%   T = exploreFNIRS.stats.summarize(results, 'Type', 'fit')
%   T = exploreFNIRS.stats.summarize(corrStats, 'Type', 'correlations')
%
% Inputs:
%   lmeResults - Struct from exploreFNIRS.stats.fitLME
%
% Name-Value Parameters:
%   Type         - Summary type (default: 'anova'):
%                  'anova'        - ANOVA F-tests per channel and term
%                  'contrasts'    - Post-hoc contrast tests
%                  'coefficients' - Fixed-effect coefficient estimates
%                  'fit'          - Model fit statistics (AIC, BIC, LRT)
%                  'correlations' - Scatter/topo correlation results
%                  'effectsize'   - Effect sizes with bootstrap CIs
%   Format       - Output format (default: 'table'):
%                  'table'   - Standard MATLAB table
%                  'console' - Prints clean formatted text to console
%                  'latex'   - Prints LaTeX tabular environment to console
%                  'apa'     - Adds APA-style formatted string column
%   SigThreshold    - Significance threshold for stars (default: 0.05)
%   OnlySignificant - Filter to rows with non-empty Sig (default: false)
%   IncludeFDR      - Apply FDR correction to ANOVA p-values (default: false)
%   Biomarkers   - Cell array of biomarker names (for 'correlations')
%   Channels     - Numeric array of channel numbers (for 'correlations')
%   Groups       - Cell array of group labels (for 'correlations')
%   CorrType     - 'Pearson' (default) or 'Spearman' (for 'correlations')
%   InfoVar      - Name of the info variable (for 'correlations')
%
% Outputs:
%   T - Table with formatted results. Columns depend on Type:
%
%     'anova':        Optode, Biomarker, Term, FStat, df1, df2, pValue, Sig
%     'contrasts':    Biomarker, Optode, Contrast, DeltaE, SD, F, df1, df2,
%                     pValue, pCorrected, Sig
%     'coefficients': Biomarker, Optode, Name, Estimate, SE, tStat, DF,
%                     pValue, Sig
%     'fit':          Biomarker, Optode, AIC, BIC, LogLik, NullChi2,
%                     NullPval, Formula
%     'correlations': Optode, N, r, p_pearson, rho, p_spearman, Sig
%                     (Group and Biomarker columns included when multiple)
%     'effectsize':   Optode, Biomarker, g, CI_lower, CI_upper, pValue, Sig
%                     (pValue included when effectSize results contain .p)
%
%     When Format='apa', an additional 'APA' column is appended with
%     formatted strings like "F(1, 23.4) = 5.67, p = .012".
%
% Example:
%   results = exploreFNIRS.stats.fitLME(groups, {'Group','Condition'}, ...
%       'Channels', 1:5);
%
%   % ANOVA summary
%   T = exploreFNIRS.stats.summarize(results);
%   disp(T);
%
%   % APA-formatted contrasts
%   T = exploreFNIRS.stats.summarize(results, 'Type', 'contrasts', ...
%       'Format', 'apa');
%   disp(T.APA);
%
%   % Model fit comparison
%   T = exploreFNIRS.stats.summarize(results, 'Type', 'fit');
%   writetable(T, 'model_fit.csv');
%
% See also: exploreFNIRS.stats.fitLME, exploreFNIRS.stats.runContrasts

    p = inputParser;
    addRequired(p, 'lmeResults', @isstruct);
    addParameter(p, 'Type', 'anova', @ischar);
    addParameter(p, 'Format', 'table', @ischar);
    addParameter(p, 'SigThreshold', 0.05, @isnumeric);
    addParameter(p, 'OnlySignificant', false, @islogical);
    addParameter(p, 'IncludeFDR', false, @islogical);
    % Metadata for correlation stats (optional, used with Type='correlations')
    addParameter(p, 'Biomarkers', {}, @iscell);
    addParameter(p, 'Channels', [], @isnumeric);
    addParameter(p, 'Groups', {}, @iscell);
    addParameter(p, 'CorrType', 'Pearson', @ischar);
    addParameter(p, 'InfoVar', '', @ischar);
    parse(p, lmeResults, varargin{:});
    opts = p.Results;

    % Extract term labels from results if available (polynomial time)
    termLabels = struct();
    if isfield(lmeResults, 'termLabels') && isstruct(lmeResults.termLabels)
        termLabels = lmeResults.termLabels;
    end

    switch lower(opts.Type)
        case 'anova'
            T = summarizeAnova(lmeResults, opts, termLabels);
        case 'contrasts'
            T = summarizeContrasts(lmeResults, opts);
        case 'coefficients'
            T = summarizeCoefficients(lmeResults, opts, termLabels);
        case 'fit'
            T = summarizeFit(lmeResults, opts);
        case 'correlations'
            T = summarizeCorrelations(lmeResults, opts);
        case 'effectsize'
            T = summarizeEffectSize(lmeResults, opts);
        otherwise
            error('exploreFNIRS:stats:summarize', ...
                'Unknown Type: ''%s''. Use ''anova'', ''contrasts'', ''coefficients'', ''fit'', ''correlations'', or ''effectsize''.', ...
                opts.Type);
    end

    % Clean up Optode/Biomarker columns for readability
    if ~isempty(T)
        if ismember('Optode', T.Properties.VariableNames)
            vals = T.Optode;
            if (isstring(vals) || iscell(vals))
                uVals = unique(string(vals));
                % Check if values look like fNIRS optode identifiers (Opt1, Opt1_HbO, etc.)
                isGenericOpt = all(~ismissing(uVals) & ...
                    ~cellfun('isempty', regexp(cellstr(uVals), '^Opt\d+')));
                if isGenericOpt
                    if numel(uVals) <= 1
                        % Single optode — uninformative, drop
                        T.Optode = [];
                    else
                        % Multiple optodes — keep as Optode, deduplicate
                        T = deduplicateColumn(T, 'Optode');
                    end
                else
                    % Non-optode values (variable names) — rename and deduplicate
                    T = renamevars(T, 'Optode', 'Variable');
                    T = deduplicateColumn(T, 'Variable');
                end
            elseif isnumeric(vals) && numel(unique(vals)) <= 1
                T.Optode = [];
            end
        end
        if ismember('Biomarker', T.Properties.VariableNames)
            vals = T.Biomarker;
            if (isstring(vals) || iscell(vals))
                uVals = unique(string(vals));
                uVals = uVals(~ismissing(uVals) & uVals ~= "");
                if numel(uVals) <= 1
                    % Single-valued or empty — always uninformative, drop
                    T.Biomarker = [];
                else
                    T = deduplicateColumn(T, 'Biomarker');
                end
            elseif isnumeric(vals) && numel(unique(vals)) <= 1
                T.Biomarker = [];
            end
        end
    end

    % Filter to significant rows only
    if opts.OnlySignificant && ~isempty(T) && ismember('Sig', T.Properties.VariableNames)
        keep = T.Sig ~= "" & ~ismissing(T.Sig);
        T = T(keep, :);
    end

    % Console format: print formatted text and return the table
    if strcmpi(opts.Format, 'console') && ~isempty(T)
        printFormattedTable(T);
    end

    % LaTeX format: print tabular environment
    if strcmpi(opts.Format, 'latex') && ~isempty(T)
        printLatexTable(T, opts.Type);
    end
end


%% Summary generators

function T = summarizeAnova(results, opts, termLabels)
% Build a tidy long-format ANOVA summary table

    if isempty(results.anova_pval) || height(results.anova_pval) == 0
        T = table();
        return;
    end

    termNames = results.anova_pval.Properties.VariableNames;
    rowNames = results.anova_pval.Properties.RowNames;
    nRows = length(rowNames);
    nTerms = length(termNames);

    % Pre-allocate
    nTotal = nRows * nTerms;
    Optode = cell(nTotal, 1);
    Biomarker = cell(nTotal, 1);
    Term = cell(nTotal, 1);
    FStat = nan(nTotal, 1);
    df1 = nan(nTotal, 1);
    df2 = nan(nTotal, 1);
    pValue = nan(nTotal, 1);
    Sig = cell(nTotal, 1);

    idx = 0;
    for r = 1:nRows
        for t = 1:nTerms
            idx = idx + 1;
            Optode{idx} = rowNames{r};
            Term{idx} = applyTermLabel(termNames{t}, termLabels);
            FStat(idx) = results.anova_Fstat{r, t};
            pValue(idx) = results.anova_pval{r, t};

            if ~isempty(results.anova_df1) && height(results.anova_df1) >= r
                df1(idx) = results.anova_df1{r, t};
                df2(idx) = results.anova_df2{r, t};
            end

            % Parse biomarker from row name (format: Opt<ch>_<bio>)
            parts = strsplit(rowNames{r}, '_');
            if length(parts) >= 2
                Biomarker{idx} = parts{end};
            else
                Biomarker{idx} = '';
            end

            Sig{idx} = sigStars(pValue(idx), opts.SigThreshold);
        end
    end

    T = table(string(Optode), string(Biomarker), string(Term), ...
        FStat, df1, df2, pValue, string(Sig), ...
        'VariableNames', {'Optode','Biomarker','Term','FStat','df1','df2','pValue','Sig'});

    % FDR correction across all ANOVA p-values
    if opts.IncludeFDR
        [qvals, ~, passed] = exploreFNIRS.fx.performFDR(pValue, opts.SigThreshold);
        T.qValue = qvals;
        T.FDR_Sig = passed;
    end

    % APA format column
    if strcmpi(opts.Format, 'apa')
        apaStr = strings(height(T), 1);
        for i = 1:height(T)
            if isnan(df2(i))
                apaStr(i) = sprintf('F = %.2f, p %s', ...
                    FStat(i), formatP(pValue(i)));
            else
                apaStr(i) = sprintf('F(%d, %.1f) = %.2f, p %s', ...
                    round(df1(i)), df2(i), FStat(i), formatP(pValue(i)));
            end
        end
        T.APA = apaStr;
    end
end


function T = summarizeContrasts(results, opts)
% Build a tidy contrast summary table

    [nBioM, nCh] = size(results.contrasts);

    allRows = {};

    for bIdx = 1:nBioM
        for chI = 1:nCh
            cTable = results.contrasts{bIdx, chI};
            if isempty(cTable) || height(cTable) == 0, continue; end

            bioM = results.biomarkers{bIdx};
            ch = results.channels(chI);

            for r = 1:height(cTable)
                row = struct();
                row.Biomarker = bioM;
                row.Optode = ch;
                row.Contrast = cTable.Properties.RowNames{r};
                row.DeltaE = cTable.deltaE(r);
                row.SD = cTable.SD(r);
                row.F = cTable.F(r);
                row.df1 = cTable.df1(r);
                row.df2 = cTable.df2(r);
                row.pValue = cTable.pVal(r);
                row.pCorrected = cTable.pVal_corr(r);
                row.Sig = strtrim(char(cTable.sig(r)));
                allRows{end+1} = row; %#ok<AGROW>
            end
        end
    end

    if isempty(allRows)
        T = table();
        return;
    end

    T = struct2table([allRows{:}]);
    T = cellColumnsToString(T);

    if strcmpi(opts.Format, 'apa')
        apaStr = strings(height(T), 1);
        for i = 1:height(T)
            apaStr(i) = sprintf('%s: delta = %.3f, F(%d, %.1f) = %.2f, p %s', ...
                T.Contrast(i), T.DeltaE(i), ...
                round(T.df1(i)), T.df2(i), T.F(i), ...
                formatP(T.pValue(i)));
        end
        T.APA = apaStr;
    end
end


function T = summarizeCoefficients(results, opts, termLabels)
% Build a tidy fixed-effect coefficient table

    [nBioM, nCh] = size(results.models);

    allRows = {};

    for bIdx = 1:nBioM
        for chI = 1:nCh
            mdl = results.models{bIdx, chI};
            if isempty(mdl), continue; end

            bioM = results.biomarkers{bIdx};
            ch = results.channels(chI);
            coefs = mdl.Coefficients;

            for r = 1:height(coefs)
                row = struct();
                row.Biomarker = bioM;
                row.Optode = ch;
                row.Name = applyTermLabel(coefs.Name{r}, termLabels);
                row.Estimate = coefs.Estimate(r);
                row.SE = coefs.SE(r);
                row.tStat = coefs.tStat(r);
                row.DF = coefs.DF(r);
                row.pValue = coefs.pValue(r);
                row.Sig = sigStars(coefs.pValue(r), opts.SigThreshold);
                allRows{end+1} = row; %#ok<AGROW>
            end
        end
    end

    if isempty(allRows)
        T = table();
        return;
    end

    T = struct2table([allRows{:}]);
    T = cellColumnsToString(T);
end


function T = summarizeFit(results, opts) %#ok<INUSD>
% Build a model fit statistics table

    [nBioM, nCh] = size(results.models);

    Biomarker = {};
    Optode = [];
    AIC = [];
    BIC = [];
    LogLik = [];
    NullPval = [];
    NullChi2 = [];
    Formula = {};

    for bIdx = 1:nBioM
        for chI = 1:nCh
            mdl = results.models{bIdx, chI};
            if isempty(mdl), continue; end

            Biomarker{end+1, 1} = results.biomarkers{bIdx}; %#ok<AGROW>
            Optode(end+1, 1) = results.channels(chI); %#ok<AGROW>
            AIC(end+1, 1) = mdl.ModelCriterion.AIC; %#ok<AGROW>
            BIC(end+1, 1) = mdl.ModelCriterion.BIC; %#ok<AGROW>
            LogLik(end+1, 1) = mdl.LogLikelihood; %#ok<AGROW>
            Formula{end+1, 1} = char(mdl.Formula); %#ok<AGROW>

            nc = results.nullComparison{bIdx, chI};
            if ~isempty(nc)
                NullPval(end+1, 1) = nc.pValue(end); %#ok<AGROW>
                NullChi2(end+1, 1) = nc.LRStat(end); %#ok<AGROW>
            else
                NullPval(end+1, 1) = NaN; %#ok<AGROW>
                NullChi2(end+1, 1) = NaN; %#ok<AGROW>
            end
        end
    end

    if isempty(Biomarker)
        T = table();
        return;
    end

    T = table(string(Biomarker), Optode, AIC, BIC, LogLik, NullChi2, NullPval, string(Formula), ...
        'VariableNames', {'Biomarker','Optode','AIC','BIC','LogLik','NullChi2','NullPval','Formula'});
end


function T = summarizeEffectSize(results, opts)
% Build a tidy effect size summary table from effectSize results

    if ~isfield(results, 'observed') || ~isfield(results, 'ci_lower')
        error('exploreFNIRS:stats:summarize:invalidEffectSize', ...
            'Input does not look like effectSize results. Expected .observed, .ci_lower, .ci_upper fields.');
    end

    [nBioM, nCh] = size(results.observed);
    bioNames = results.biomarkers;
    channels = results.channels;

    % Method display name
    switch lower(results.method)
        case 'hedges_g',    methodStr = 'g';   methodFull = 'Hedges'' g';
        case 'cohens_d',    methodStr = 'd';   methodFull = 'Cohen''s d';
        case 'glass_delta', methodStr = 'delta'; methodFull = 'Glass''s delta';
        otherwise,          methodStr = 'ES';  methodFull = results.method;
    end

    allRows = {};
    for bIdx = 1:nBioM
        for chI = 1:nCh
            g = results.observed(bIdx, chI);
            if isnan(g), continue; end

            row = struct();
            row.Optode = channels(chI);
            if nBioM > 1
                row.Biomarker = bioNames{bIdx};
            end
            row.g = g;
            row.CI_lower = results.ci_lower(bIdx, chI);
            row.CI_upper = results.ci_upper(bIdx, chI);

            % Raw p-value from parametric t-test (if available)
            if isfield(results, 'p')
                row.pValue = results.p(bIdx, chI);
            end

            % Significance: CI excludes zero
            lo = results.ci_lower(bIdx, chI);
            hi = results.ci_upper(bIdx, chI);
            if lo > 0 || hi < 0
                row.Sig = '*';
            else
                row.Sig = '';
            end

            allRows{end+1} = row; %#ok<AGROW>
        end
    end

    if isempty(allRows)
        T = table();
        return;
    end

    T = struct2table([allRows{:}]);
    T = cellColumnsToString(T);

    % Rename 'g' column to match the method
    if ismember('g', T.Properties.VariableNames) && ~strcmp(methodStr, 'g')
        T.Properties.VariableNames{strcmp(T.Properties.VariableNames, 'g')} = methodStr;
    end

    % FDR correction on raw p-values
    if opts.IncludeFDR && ismember('pValue', T.Properties.VariableNames)
        [qvals, ~, passed] = exploreFNIRS.fx.performFDR(T.pValue, opts.SigThreshold);
        T.pCorrected = qvals;
        T.FDR_Sig = passed;
    end

    % Store method info for latex/console output
    T.Properties.UserData = struct('methodStr', methodStr, 'methodFull', methodFull, ...
        'ciLevel', results.ci_level, 'nBoot', results.nBoot, ...
        'conditions', {results.conditions}, 'nPerGroup', results.nPerGroup);

    if strcmpi(opts.Format, 'apa')
        esCol = methodStr;
        if ~ismember(esCol, T.Properties.VariableNames)
            esCol = 'g';
        end
        hasP = ismember('pValue', T.Properties.VariableNames);
        apaStr = strings(height(T), 1);
        for i = 1:height(T)
            base = sprintf('%s = %.3f, %d%% CI [%.3f, %.3f]', ...
                methodStr, T.(esCol)(i), ...
                round(results.ci_level * 100), ...
                T.CI_lower(i), T.CI_upper(i));
            if hasP
                apaStr(i) = sprintf('%s, p %s', base, formatP(T.pValue(i)));
            else
                apaStr(i) = base;
            end
        end
        T.APA = apaStr;
    end
end


function T = summarizeCorrelations(stats, opts)
% Build a tidy correlation summary table from plotScatter stats output
%
% Handles two formats:
%   1. Struct array stats(nGroups, nBioM, nCh) — per-channel scatter
%   2. Struct array stats(nGroups, nBioM) with vector fields — topo mode

    isTopo = isfield(stats, 'r') && isvector(stats(1).r) && length(stats(1).r) > 1;

    if isTopo
        T = summarizeCorrelationsTopo(stats, opts);
    else
        T = summarizeCorrelationsPerChannel(stats, opts);
    end
end


function T = summarizeCorrelationsPerChannel(stats, opts)
% Per-channel scatter stats: stats(nGroups, nBioM, nCh)

    sz = size(stats);
    nGroups = sz(1);
    nBioM = max(sz(2), 1);
    nCh = max(1, prod(sz(3:end)));

    bioNames = opts.Biomarkers;
    chNums = opts.Channels;
    groupNames = opts.Groups;

    allRows = {};
    for g = 1:nGroups
        for bIdx = 1:nBioM
            for chI = 1:nCh
                s = stats(g, bIdx, chI);
                if isnan(s.r) && s.N == 0, continue; end

                row = struct();
                if ~isempty(groupNames) && g <= length(groupNames)
                    row.Group = groupNames{g};
                elseif nGroups > 1
                    row.Group = sprintf('Group %d', g);
                end
                if ~isempty(bioNames) && bIdx <= length(bioNames)
                    row.Biomarker = bioNames{bIdx};
                elseif nBioM > 1
                    row.Biomarker = sprintf('Bio %d', bIdx);
                end
                if ~isempty(chNums) && chI <= length(chNums)
                    row.Optode = chNums(chI);
                else
                    row.Optode = chI;
                end
                row.N = s.N;
                row.r = s.r;
                row.p_pearson = s.p;
                row.rho = s.rho;
                row.p_spearman = s.pval;
                row.Sig = sigStars(selectP(s, opts.CorrType), opts.SigThreshold);
                allRows{end+1} = row; %#ok<AGROW>
            end
        end
    end

    if isempty(allRows)
        T = table();
        return;
    end

    T = struct2table([allRows{:}]);
    T = cellColumnsToString(T);

    % Remove single-valued columns
    if nGroups == 1 && ismember('Group', T.Properties.VariableNames)
        T.Group = [];
    end
    if nBioM == 1 && ismember('Biomarker', T.Properties.VariableNames)
        T.Biomarker = [];
    end

    if strcmpi(opts.Format, 'apa')
        T.APA = buildCorrAPA(T, opts.CorrType);
    end
end


function T = summarizeCorrelationsTopo(stats, opts)
% Topo correlation stats: stats(nGroups, nBioM) with vector fields

    sz = size(stats);
    nGroups = sz(1);
    nBioM = max(sz(2), 1);

    bioNames = opts.Biomarkers;
    chNums = opts.Channels;
    groupNames = opts.Groups;

    allRows = {};
    for g = 1:nGroups
        for bIdx = 1:nBioM
            s = stats(g, bIdx);
            nCh = length(s.r);

            for chI = 1:nCh
                if isnan(s.r(chI)), continue; end

                row = struct();
                if ~isempty(groupNames) && g <= length(groupNames)
                    row.Group = groupNames{g};
                elseif nGroups > 1
                    row.Group = sprintf('Group %d', g);
                end
                if ~isempty(bioNames) && bIdx <= length(bioNames)
                    row.Biomarker = bioNames{bIdx};
                elseif nBioM > 1
                    row.Biomarker = sprintf('Bio %d', bIdx);
                end
                if ~isempty(chNums) && chI <= length(chNums)
                    row.Optode = chNums(chI);
                else
                    row.Optode = chI;
                end
                row.N = s.N(chI);
                row.r = s.r(chI);
                row.p_pearson = s.p(chI);
                row.rho = s.rho(chI);
                row.p_spearman = s.pval(chI);
                if ~isempty(s.q) && chI <= length(s.q)
                    row.q = s.q(chI);
                end
                row.Sig = sigStars(selectPScalar(s, chI, opts.CorrType), ...
                    opts.SigThreshold);
                allRows{end+1} = row; %#ok<AGROW>
            end
        end
    end

    if isempty(allRows)
        T = table();
        return;
    end

    T = struct2table([allRows{:}]);
    T = cellColumnsToString(T);

    % Remove single-valued columns
    if nGroups == 1 && ismember('Group', T.Properties.VariableNames)
        T.Group = [];
    end
    if nBioM == 1 && ismember('Biomarker', T.Properties.VariableNames)
        T.Biomarker = [];
    end

    if strcmpi(opts.Format, 'apa')
        T.APA = buildCorrAPA(T, opts.CorrType);
    end
end


function pVal = selectP(s, corrType)
% Select p-value based on correlation type
    if strcmpi(corrType, 'Spearman')
        pVal = s.pval;
    else
        pVal = s.p;
    end
end


function pVal = selectPScalar(s, idx, corrType)
% Select p-value from vector fields
    if strcmpi(corrType, 'Spearman')
        pVal = s.pval(idx);
    else
        pVal = s.p(idx);
    end
end


function apaStr = buildCorrAPA(T, corrType)
% Build APA-formatted correlation strings
    apaStr = strings(height(T), 1);
    for i = 1:height(T)
        N = T.N(i);
        df = N - 2;
        if strcmpi(corrType, 'Spearman')
            rVal = T.rho(i);
            pVal = T.p_spearman(i);
            sym = 'r_s';
        else
            rVal = T.r(i);
            pVal = T.p_pearson(i);
            sym = 'r';
        end
        apaStr(i) = sprintf('%s(%d) = %.3f, p %s', sym, df, rVal, formatP(pVal));
    end
end


%% Formatting helpers

function s = sigStars(p, thresh)
    if p < 0.001
        s = '***';
    elseif p < 0.01
        s = '**';
    elseif p < thresh
        s = '*';
    elseif p < 0.1
        s = '+';
    else
        s = '';
    end
end


function s = formatP(p)
    if p < 0.001
        s = '< .001';
    else
        s = sprintf('= %.3f', p);
    end
end


function T = cellColumnsToString(T)
% Convert cell columns to string arrays for clean display
    for v = 1:width(T)
        if iscell(T{:, v})
            T.(T.Properties.VariableNames{v}) = string(T{:, v});
        end
    end
end


function printFormattedTable(T)
% Print a table with clean formatting (no quotes, no braces)
    names = T.Properties.VariableNames;
    nCols = width(T);
    nRows = height(T);

    % Format each column as strings
    colStrs = cell(1, nCols);
    for c = 1:nCols
        col = T{:, c};
        if isstring(col) || iscell(col)
            colStrs{c} = string(col);
        elseif isnumeric(col)
            strs = strings(nRows, 1);
            for r = 1:nRows
                if isnan(col(r))
                    strs(r) = "";
                elseif col(r) == round(col(r)) && abs(col(r)) < 1e6
                    strs(r) = sprintf('%d', col(r));
                elseif abs(col(r)) < 0.001 && col(r) ~= 0
                    strs(r) = sprintf('%.1e', col(r));
                else
                    strs(r) = sprintf('%.4f', col(r));
                end
            end
            colStrs{c} = strs;
        elseif islogical(col)
            colStrs{c} = string(col);
        else
            colStrs{c} = string(col);
        end
    end

    % Compute column widths
    colWidths = zeros(1, nCols);
    for c = 1:nCols
        colWidths(c) = max(strlength(names{c}), max(strlength(colStrs{c})));
    end

    % Print header
    headerParts = strings(1, nCols);
    divParts = strings(1, nCols);
    for c = 1:nCols
        w = colWidths(c);
        headerParts(c) = pad(names{c}, w);
        divParts(c) = repmat('-', 1, w);
    end
    fprintf('  %s\n', join(headerParts, '   '));
    fprintf('  %s\n', join(divParts, '   '));

    % Print rows
    for r = 1:nRows
        parts = strings(1, nCols);
        for c = 1:nCols
            w = colWidths(c);
            s = colStrs{c}(r);
            % Right-align numbers, left-align text
            col = T{r, c};
            if isnumeric(col) || islogical(col)
                parts(c) = pad(s, w, 'left');
            else
                parts(c) = pad(s, w);
            end
        end
        fprintf('  %s\n', join(parts, '   '));
    end
    fprintf('\n');
end


function printLatexTable(T, tableType)
% Print a LaTeX tabular environment for the table
    names = T.Properties.VariableNames;
    nCols = width(T);
    nRows = height(T);

    % Column alignment: l for text, r for numbers
    alignStr = '';
    for c = 1:nCols
        col = T{:, c};
        if isnumeric(col) || islogical(col)
            alignStr = [alignStr, 'r']; %#ok<AGROW>
        else
            alignStr = [alignStr, 'l']; %#ok<AGROW>
        end
    end

    % Map nice header names per table type
    headerNames = latexHeaders(names, tableType);

    fprintf('\\begin{table}[htbp]\n');
    fprintf('\\centering\n');
    fprintf('\\caption{%s}\n', latexCaption(tableType));
    fprintf('\\begin{tabular}{%s}\n', alignStr);
    fprintf('\\toprule\n');

    % Header row
    fprintf('%s', headerNames{1});
    for c = 2:nCols
        fprintf(' & %s', headerNames{c});
    end
    fprintf(' \\\\\n');
    fprintf('\\midrule\n');

    % Data rows
    for r = 1:nRows
        parts = strings(1, nCols);
        for c = 1:nCols
            col = T{r, c};
            if isnumeric(col)
                if isnan(col)
                    parts(c) = "";
                elseif col == round(col) && abs(col) < 1e6
                    parts(c) = sprintf('%d', col);
                elseif abs(col) < 0.001 && col ~= 0
                    parts(c) = sprintf('$<$ .001');
                else
                    parts(c) = sprintf('%.3f', col);
                end
            elseif islogical(col)
                if col
                    parts(c) = "Yes";
                else
                    parts(c) = "";
                end
            elseif isstring(col) || iscell(col)
                s = string(col);
                % Escape underscores and add italic for significance stars
                s = strrep(s, '_', '\_');
                if s == "*" || s == "**" || s == "***" || s == "+"
                    parts(c) = sprintf('$%s$', s);
                else
                    parts(c) = s;
                end
            else
                parts(c) = string(col);
            end
        end
        fprintf('%s', parts(1));
        for c = 2:nCols
            fprintf(' & %s', parts(c));
        end
        fprintf(' \\\\\n');
    end

    fprintf('\\bottomrule\n');
    fprintf('\\end{tabular}\n');

    % Notes
    notes = latexNotes(tableType);
    if ~isempty(notes)
        fprintf('\\par\\smallskip\\footnotesize\\textit{Note.} %s\n', notes);
    end

    fprintf('\\end{table}\n');
end


function h = latexHeaders(names, tableType)
% Map variable names to publication-style LaTeX headers
    map = containers.Map('KeyType', 'char', 'ValueType', 'char');
    map('Optode')     = 'Optode';
    map('Variable')   = 'Variable';
    map('Biomarker')  = 'Biomarker';
    map('Term')       = 'Term';
    map('FStat')      = '$F$';
    map('df1')        = '$df_1$';
    map('df2')        = '$df_2$';
    map('pValue')     = '$p$';
    map('Sig')        = '';
    map('qValue')     = '$q$';
    map('FDR_Sig')    = 'FDR';
    map('Contrast')   = 'Contrast';
    map('DeltaE')     = '$\Delta$';
    map('SD')         = 'SE';
    map('F')          = '$F$';
    map('pCorrected') = '$p_\mathrm{corr}$';
    map('Name')       = 'Coefficient';
    map('Estimate')   = '$\beta$';
    map('SE')         = 'SE';
    map('tStat')      = '$t$';
    map('DF')         = '$df$';
    map('AIC')        = 'AIC';
    map('BIC')        = 'BIC';
    map('LogLik')     = 'Log-Lik';
    map('NullChi2')   = '$\chi^2$';
    map('NullPval')   = '$p_\mathrm{null}$';
    map('Formula')    = 'Formula';
    map('APA')        = 'APA';
    map('r')           = '$r$';
    map('rho')         = '$\rho$';
    map('p_pearson')   = '$p_\mathrm{Pearson}$';
    map('p_spearman')  = '$p_\mathrm{Spearman}$';
    map('N')           = '$N$';
    map('q')           = '$q$';
    map('Group')       = 'Group';
    map('g')           = '$g$';
    map('d')           = '$d$';
    map('delta')       = '$\delta$';
    map('ES')          = 'ES';
    map('CI_lower')    = 'CI Lower';
    map('CI_upper')    = 'CI Upper';

    h = cell(1, length(names));
    for i = 1:length(names)
        if map.isKey(names{i})
            h{i} = map(names{i});
        else
            h{i} = strrep(names{i}, '_', '\_');
        end
    end

    % Suppress unused arg warning
    if isempty(tableType), return; end
end


function c = latexCaption(tableType)
% Default caption per table type
    switch lower(tableType)
        case 'anova'
            c = 'ANOVA Results for Fixed Effects';
        case 'contrasts'
            c = 'Post-Hoc Contrast Tests';
        case 'coefficients'
            c = 'Fixed-Effect Coefficient Estimates';
        case 'fit'
            c = 'Model Fit Statistics';
        case 'correlations'
            c = 'Correlation Results';
        case 'effectsize'
            c = 'Effect Sizes with Bootstrap Confidence Intervals';
        otherwise
            c = 'Summary';
    end
end


function n = latexNotes(tableType)
% Footnote text per table type
    switch lower(tableType)
        case 'anova'
            n = '$^{*}p < .05$, $^{**}p < .01$, $^{***}p < .001$, $^{+}p < .10$.';
        case 'contrasts'
            n = '$p_\mathrm{corr}$ = FDR-corrected $p$-value. $^{*}p < .05$, $^{**}p < .01$, $^{***}p < .001$.';
        case 'coefficients'
            n = '$^{*}p < .05$, $^{**}p < .01$, $^{***}p < .001$.';
        case 'correlations'
            n = '$r$ = Pearson, $\rho$ = Spearman. $^{*}p < .05$, $^{**}p < .01$, $^{***}p < .001$.';
        case 'effectsize'
            n = '$^{*}$CI excludes zero. $p$ = two-sample $t$-test.';
        otherwise
            n = '';
    end
end


function label = applyTermLabel(termName, termLabels)
% APPLYTERMLABEL Map sanitized term name to readable label
%
% Handles direct matches (e.g. 'ot1' -> 'Time (Linear)') and interaction
% terms (e.g. 'Condition:ot1' -> 'Condition x Time (Linear)').

    if isempty(fieldnames(termLabels))
        label = termName;
        return;
    end

    % Direct match
    if isfield(termLabels, termName)
        label = termLabels.(termName);
        return;
    end

    % Check for interaction terms containing polynomial components
    % e.g. 'Conditionot1' (sanitized from 'Condition:ot1')
    % or 'Condition:ot1' (raw ANOVA term)
    label = termName;
    fnames = fieldnames(termLabels);
    for i = 1:length(fnames)
        otName = fnames{i};
        % Match both 'Var:otN' and sanitized 'VarotN' patterns
        if contains(termName, otName)
            prefix = strrep(termName, otName, '');
            prefix = strrep(prefix, ':', '');
            if ~isempty(prefix)
                label = sprintf('%s x %s', prefix, termLabels.(otName));
            else
                label = termLabels.(otName);
            end
            return;
        end
    end
end


function T = deduplicateColumn(T, colName)
% DEDUPLICATECOLUMN Show value only on first row of each consecutive group
%   Replaces repeated consecutive values with "" for cleaner display.
    vals = string(T.(colName));
    for i = 2:numel(vals)
        if vals(i) == vals(i-1)
            vals(i) = "";
        end
    end
    T.(colName) = vals;
end
