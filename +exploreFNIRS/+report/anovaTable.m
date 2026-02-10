function T = anovaTable(results, varargin)
% ANOVATABLE Formatted ANOVA table with df, F, p, and partial eta-squared
%
% Extracts LME ANOVA results per channel and formats for publication.
%
% Syntax:
%   T = exploreFNIRS.report.anovaTable(results)
%   T = exploreFNIRS.report.anovaTable(results, 'Channel', 3)
%   T = exploreFNIRS.report.anovaTable(results, 'AllChannels', true)
%
% Inputs:
%   results - Results struct from plotLME (with .anova field)
%
% Name-Value Parameters:
%   Biomarker    - Biomarker index (default: 1)
%   Channel      - Channel index for single-channel table (default: 1)
%   AllChannels  - Create multi-channel summary (default: false)
%                  When true, returns one row per channel x term combination
%   SigThreshold - Significance threshold for stars (default: 0.05)
%
% Outputs:
%   T - Table with columns: Term, df1, df2, F, p, etaSq, sig
%       (AllChannels adds a Channel column)
%
% Example:
%   [~, results] = ex.plotLME('Channels', 1:16);
%   T = exploreFNIRS.report.anovaTable(results, 'AllChannels', true);
%   disp(T);
%
% See also: exploreFNIRS.report.formatPValue, exploreFNIRS.core.plotLME

    ip = inputParser;
    addRequired(ip, 'results', @isstruct);
    addParameter(ip, 'Biomarker', 1, @isnumeric);
    addParameter(ip, 'Channel', 1, @isnumeric);
    addParameter(ip, 'AllChannels', false, @islogical);
    addParameter(ip, 'SigThreshold', 0.05, @isnumeric);
    parse(ip, results, varargin{:});
    opts = ip.Results;

    bIdx = opts.Biomarker;

    if opts.AllChannels
        T = buildMultiChannelTable(results, bIdx, opts.SigThreshold);
    else
        T = buildSingleChannelTable(results, bIdx, opts.Channel, opts.SigThreshold);
    end
end


function T = buildSingleChannelTable(results, bIdx, chIdx, sigThresh)
    if ~isfield(results, 'anova') || isempty(results.anova{bIdx, chIdx})
        T = table();
        return;
    end

    anv = results.anova{bIdx, chIdx};
    nTerms = size(anv.FStat, 1);

    Term = cell(nTerms, 1);
    df1_col = nan(nTerms, 1);
    df2_col = nan(nTerms, 1);
    F_col = nan(nTerms, 1);
    p_col = cell(nTerms, 1);
    etaSq_col = nan(nTerms, 1);
    sig_col = cell(nTerms, 1);

    for i = 1:nTerms
        Term{i} = getTermName(anv, i);

        F_col(i) = anv.FStat(i);
        p = anv.pValue(i);
        p_col{i} = exploreFNIRS.report.formatPValue(p);

        % Degrees of freedom
        [d1, d2] = getDF(anv, results, bIdx, chIdx, i);
        df1_col(i) = d1;
        df2_col(i) = d2;

        % Partial eta-squared
        if ~isnan(d1) && ~isnan(d2) && F_col(i) > 0
            etaSq_col(i) = (F_col(i) * d1) / (F_col(i) * d1 + d2);
        end

        sig_col{i} = getStars(p, sigThresh);
    end

    T = table(Term, df1_col, df2_col, F_col, p_col, etaSq_col, sig_col, ...
        'VariableNames', {'Term', 'df1', 'df2', 'F', 'p', 'partialEtaSq', 'Sig'});
end


function T = buildMultiChannelTable(results, bIdx, sigThresh)
    nCh = size(results.anova, 2);

    rows = {};
    for chIdx = 1:nCh
        if isempty(results.anova{bIdx, chIdx})
            continue;
        end

        anv = results.anova{bIdx, chIdx};
        nTerms = size(anv.FStat, 1);

        for i = 1:nTerms
            row = struct();
            if isfield(results, 'channels') && chIdx <= length(results.channels)
                row.Channel = results.channels(chIdx);
            else
                row.Channel = chIdx;
            end
            row.Term = getTermName(anv, i);

            row.F = anv.FStat(i);
            p = anv.pValue(i);
            row.p = exploreFNIRS.report.formatPValue(p);

            [d1, d2] = getDF(anv, results, bIdx, chIdx, i);
            row.df1 = d1;
            row.df2 = d2;

            if ~isnan(d1) && ~isnan(d2) && row.F > 0
                row.partialEtaSq = (row.F * d1) / (row.F * d1 + d2);
            else
                row.partialEtaSq = NaN;
            end

            row.Sig = getStars(p, sigThresh);
            rows{end+1} = row; %#ok<AGROW>
        end
    end

    if isempty(rows)
        T = table();
        return;
    end

    T = struct2table([rows{:}]);
end


function [df1, df2] = getDF(anv, results, bIdx, chIdx, termIdx)
    % Try direct access (works for both dataset and table)
    try
        df1 = anv.DF1(termIdx);
        df2 = anv.DF2(termIdx);
        return;
    catch
    end
    try
        df1 = anv.DF(termIdx);
        df2 = anv.DF(termIdx);
        return;
    catch
    end
    % Fall back to summary tables
    if isfield(results, 'anova_df1') && ~isempty(results.anova_df1) ...
            && height(results.anova_df1) >= chIdx ...
            && width(results.anova_df1) >= termIdx
        df1 = results.anova_df1{chIdx, termIdx};
        df2 = results.anova_df2{chIdx, termIdx};
    else
        df1 = NaN;
        df2 = NaN;
    end
end


function name = getTermName(anv, idx)
    % Extract term name from ANOVA result (works for table or dataset)
    try
        t = anv.Term(idx);
        if iscell(t)
            name = t{1};
        else
            name = char(t);
        end
    catch
        name = sprintf('Term%d', idx);
    end
end


function s = getStars(p, thresh)
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
