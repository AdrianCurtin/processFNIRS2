function str = formatStats(results, varargin)
% FORMATSTATS APA-style statistical result string from LME or GLM output
%
% Generates formatted strings like:
%   "F(1, 23.4) = 5.67, p = .018"
%   "t(45) = 2.31, p = .025, d = 0.68"
%
% Syntax:
%   str = exploreFNIRS.report.formatStats(results)
%   str = exploreFNIRS.report.formatStats(results, 'Type', 'anova')
%   str = exploreFNIRS.report.formatStats(results, 'Channel', 1, 'Term', 'Group')
%
% Inputs:
%   results - Results struct from plotLME or fitGLM:
%             LME: .anova (cell of ANOVA tables), .contrasts (cell of tables)
%             GLM: .beta, .tstat, .pval, .se, .dof
%
% Name-Value Parameters:
%   Type      - 'anova' (default), 'contrast', 'ttest', 'correlation'
%   Biomarker - Biomarker index (default: 1) for multi-biomarker results
%   Channel   - Channel index (default: 1) for multi-channel results
%   Term      - ANOVA term name or contrast row name (default: '' = first)
%   EffectSize - Include effect size (default: true for anova/contrast)
%
% Outputs:
%   str - Formatted APA string
%
% Example:
%   [~, results] = ex.plotLME('Biomarkers', {'HbO'}, 'Channels', 1:5);
%   str = exploreFNIRS.report.formatStats(results, 'Channel', 3, 'Term', 'Group');
%   % "F(1, 18.2) = 7.43, p = .014, partial eta-sq = .292"
%
% See also: exploreFNIRS.report.formatPValue, exploreFNIRS.core.plotLME

    ip = inputParser;
    addRequired(ip, 'results', @isstruct);
    addParameter(ip, 'Type', 'anova', @ischar);
    addParameter(ip, 'Biomarker', 1, @isnumeric);
    addParameter(ip, 'Channel', 1, @isnumeric);
    addParameter(ip, 'Term', '', @ischar);
    addParameter(ip, 'EffectSize', true, @islogical);
    parse(ip, results, varargin{:});
    opts = ip.Results;

    bIdx = opts.Biomarker;
    chIdx = opts.Channel;

    switch lower(opts.Type)
        case 'anova'
            str = formatAnova(results, bIdx, chIdx, opts.Term, opts.EffectSize);

        case 'contrast'
            str = formatContrast(results, bIdx, chIdx, opts.Term, opts.EffectSize);

        case 'ttest'
            str = formatTtest(results, opts.Term, opts.EffectSize);

        case 'correlation'
            str = formatCorrelation(results);

        otherwise
            error('exploreFNIRS:report:formatStats', ...
                'Unknown Type: %s. Use anova, contrast, ttest, or correlation.', opts.Type);
    end
end


%% Local helpers

function str = formatAnova(results, bIdx, chIdx, termName, showEffect)
    if ~isfield(results, 'anova') || isempty(results.anova{bIdx, chIdx})
        str = 'No ANOVA results available';
        return;
    end

    anv = results.anova{bIdx, chIdx};

    % Find requested term (works for both table and dataset objects)
    terms = anv.Term;
    if iscell(terms)
        termList = terms;
    else
        termList = cellstr(terms);
    end

    if isempty(termName)
        termIdx = 1;
        termName = termList{1};
    else
        termIdx = find(strcmp(termList, termName), 1);
        if isempty(termIdx)
            str = sprintf('Term "%s" not found', termName);
            return;
        end
    end

    F = anv.FStat(termIdx);
    p = anv.pValue(termIdx);

    % Get degrees of freedom (works for both table and dataset)
    try
        df1 = anv.DF1(termIdx);
        df2 = anv.DF2(termIdx);
    catch
        try
            df1 = anv.DF(termIdx);
            df2 = anv.DF(termIdx);
        catch
            if isfield(results, 'anova_df1') && ~isempty(results.anova_df1) ...
                    && height(results.anova_df1) >= chIdx
                df1 = results.anova_df1{chIdx, termIdx};
                df2 = results.anova_df2{chIdx, termIdx};
            else
                df1 = NaN;
                df2 = NaN;
            end
        end
    end

    pStr = exploreFNIRS.report.formatPValue(p, 'Prefix', true);

    if isnan(df1) || isnan(df2)
        str = sprintf('F = %.2f, %s', F, pStr);
    elseif df2 == round(df2)
        str = sprintf('F(%d, %d) = %.2f, %s', df1, df2, F, pStr);
    else
        str = sprintf('F(%d, %.1f) = %.2f, %s', df1, df2, F, pStr);
    end

    if showEffect && ~isnan(df1) && ~isnan(df2)
        etaSq = (F * df1) / (F * df1 + df2);
        str = sprintf('%s, partial eta-sq = %.3f', str, etaSq);
    end
end


function str = formatContrast(results, bIdx, chIdx, contrastName, showEffect)
    if ~isfield(results, 'contrasts') || isempty(results.contrasts{bIdx, chIdx})
        str = 'No contrast results available';
        return;
    end

    cTable = results.contrasts{bIdx, chIdx};
    if isempty(cTable) || height(cTable) == 0
        str = 'No contrasts computed';
        return;
    end

    % Find requested contrast
    if isempty(contrastName)
        rowIdx = 1;
    else
        rowIdx = find(strcmp(cTable.Properties.RowNames, contrastName), 1);
        if isempty(rowIdx)
            str = sprintf('Contrast "%s" not found', contrastName);
            return;
        end
    end

    deltaE = cTable.deltaE(rowIdx);
    F = cTable.F(rowIdx);
    df1 = cTable.df1(rowIdx);
    df2 = cTable.df2(rowIdx);
    p = cTable.pVal(rowIdx);

    pStr = exploreFNIRS.report.formatPValue(p, 'Prefix', true);

    if df2 == round(df2)
        str = sprintf('delta = %.3f, F(%d, %d) = %.2f, %s', ...
            deltaE, df1, df2, F, pStr);
    else
        str = sprintf('delta = %.3f, F(%d, %.1f) = %.2f, %s', ...
            deltaE, df1, df2, F, pStr);
    end

    if showEffect && df2 > 0
        d = deltaE / cTable.SD(rowIdx);
        str = sprintf('%s, d = %.2f', str, d);
    end
end


function str = formatTtest(results, varName, showEffect)
    if isfield(results, 'tstat')
        t = results.tstat;
        p = results.pval;
        df = results.dof;
    elseif ~isempty(varName) && isfield(results, varName)
        r = results.(varName);
        t = r.tstat;
        p = r.pval;
        df = r.dof;
    else
        str = 'No t-test results available';
        return;
    end

    pStr = exploreFNIRS.report.formatPValue(p, 'Prefix', true);
    str = sprintf('t(%d) = %.2f, %s', df, t, pStr);

    if showEffect && isfield(results, 'd')
        str = sprintf('%s, d = %.2f', str, results.d);
    end
end


function str = formatCorrelation(results)
    if isfield(results, 'r')
        r = results.r;
        p = results.p;
        n = results.n;
    else
        str = 'No correlation results available';
        return;
    end

    pStr = exploreFNIRS.report.formatPValue(p, 'Prefix', true);
    str = sprintf('r(%d) = %.3f, %s', n - 2, r, pStr);
end
