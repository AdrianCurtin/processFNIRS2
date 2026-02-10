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
%   Format       - Output format (default: 'table'):
%                  'table' - Standard MATLAB table
%                  'apa'   - Adds APA-style formatted string column
%   SigThreshold - Significance threshold for stars (default: 0.05)
%   IncludeFDR   - Apply FDR correction to ANOVA p-values (default: false)
%
% Outputs:
%   T - Table with formatted results. Columns depend on Type:
%
%     'anova':        Channel, Biomarker, Term, FStat, df1, df2, pValue, Sig
%     'contrasts':    Biomarker, Channel, Contrast, DeltaE, SD, F, df1, df2,
%                     pValue, pCorrected, Sig
%     'coefficients': Biomarker, Channel, Name, Estimate, SE, tStat, DF,
%                     pValue, Sig
%     'fit':          Biomarker, Channel, AIC, BIC, LogLik, NullChi2,
%                     NullPval, Formula
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
    addParameter(p, 'IncludeFDR', false, @islogical);
    parse(p, lmeResults, varargin{:});
    opts = p.Results;

    switch lower(opts.Type)
        case 'anova'
            T = summarizeAnova(lmeResults, opts);
        case 'contrasts'
            T = summarizeContrasts(lmeResults, opts);
        case 'coefficients'
            T = summarizeCoefficients(lmeResults, opts);
        case 'fit'
            T = summarizeFit(lmeResults, opts);
        otherwise
            error('exploreFNIRS:stats:summarize', ...
                'Unknown Type: ''%s''. Use ''anova'', ''contrasts'', ''coefficients'', or ''fit''.', ...
                opts.Type);
    end
end


%% Summary generators

function T = summarizeAnova(results, opts)
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
    Channel = cell(nTotal, 1);
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
            Channel{idx} = rowNames{r};
            Term{idx} = termNames{t};
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

    T = table(Channel, Biomarker, Term, FStat, df1, df2, pValue, Sig);

    % FDR correction across all ANOVA p-values
    if opts.IncludeFDR
        [qvals, ~, passed] = exploreFNIRS.fx.performFDR(pValue, opts.SigThreshold);
        T.qValue = qvals;
        T.FDR_Sig = passed;
    end

    % APA format column
    if strcmpi(opts.Format, 'apa')
        apaStr = cell(height(T), 1);
        for i = 1:height(T)
            if isnan(df2(i))
                apaStr{i} = sprintf('F = %.2f, p %s', ...
                    FStat(i), formatP(pValue(i)));
            else
                apaStr{i} = sprintf('F(%d, %.1f) = %.2f, p %s', ...
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
                row.Channel = ch;
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

    if strcmpi(opts.Format, 'apa')
        apaStr = cell(height(T), 1);
        for i = 1:height(T)
            apaStr{i} = sprintf('%s: delta = %.3f, F(%d, %.1f) = %.2f, p %s', ...
                T.Contrast{i}, T.DeltaE(i), ...
                round(T.df1(i)), T.df2(i), T.F(i), ...
                formatP(T.pValue(i)));
        end
        T.APA = apaStr;
    end
end


function T = summarizeCoefficients(results, opts)
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
                row.Channel = ch;
                row.Name = coefs.Name{r};
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
end


function T = summarizeFit(results, opts) %#ok<INUSD>
% Build a model fit statistics table

    [nBioM, nCh] = size(results.models);

    Biomarker = {};
    Channel = [];
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
            Channel(end+1, 1) = results.channels(chI); %#ok<AGROW>
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

    T = table(Biomarker, Channel, AIC, BIC, LogLik, NullChi2, NullPval, Formula);
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
