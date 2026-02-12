function T = contrastTable(results, varargin)
% CONTRASTTABLE Formatted contrast table with significance stars and CI
%
% Extracts LME contrasts from plotLME results and formats for publication.
%
% Syntax:
%   T = exploreFNIRS.report.contrastTable(results)
%   T = exploreFNIRS.report.contrastTable(results, 'Channel', 3, 'CI', true)
%
% Inputs:
%   results - Results struct from plotLME (with .contrasts field)
%
% Name-Value Parameters:
%   Biomarker  - Biomarker index (default: 1)
%   Channel    - Channel index (default: 1)
%   CI         - Include 95% CI column (default: false)
%   Alpha      - Confidence level (default: 0.05 -> 95% CI)
%   UseCorrected - Use corrected p-values if available (default: true)
%
% Outputs:
%   T - Formatted table with columns: Contrast, Delta, SD, F, df, p, sig
%       If CI=true: adds CI column "[lower, upper]"
%
% Example:
%   [~, results] = ex.plotLME('Channels', 1:5);
%   T = exploreFNIRS.report.contrastTable(results, 'Channel', 1, 'CI', true);
%   disp(T);
%
% See also: exploreFNIRS.report.formatPValue, exploreFNIRS.fx.autoContrast

    ip = inputParser;
    addRequired(ip, 'results', @isstruct);
    addParameter(ip, 'Biomarker', 1, @isnumeric);
    addParameter(ip, 'Channel', 1, @isnumeric);
    addParameter(ip, 'CI', false, @islogical);
    addParameter(ip, 'Alpha', 0.05, @isnumeric);
    addParameter(ip, 'UseCorrected', true, @islogical);
    parse(ip, results, varargin{:});
    opts = ip.Results;

    bIdx = opts.Biomarker;
    chIdx = opts.Channel;

    if ~isfield(results, 'contrasts') || isempty(results.contrasts{bIdx, chIdx})
        T = table();
        return;
    end

    cTable = results.contrasts{bIdx, chIdx};
    if isempty(cTable) || height(cTable) == 0
        T = table();
        return;
    end

    nRows = height(cTable);

    Contrast = cTable.Properties.RowNames;
    Delta = arrayfun(@(x) sprintf('%.3f', x), cTable.deltaE, 'UniformOutput', false);
    SD = arrayfun(@(x) sprintf('%.3f', x), cTable.SD, 'UniformOutput', false);
    F_str = arrayfun(@(x) sprintf('%.2f', x), cTable.F, 'UniformOutput', false);

    % Format df
    df = cell(nRows, 1);
    for i = 1:nRows
        if cTable.df2(i) == round(cTable.df2(i))
            df{i} = sprintf('%d, %d', cTable.df1(i), cTable.df2(i));
        else
            df{i} = sprintf('%d, %.1f', cTable.df1(i), cTable.df2(i));
        end
    end

    % P-values
    if opts.UseCorrected && ismember('pVal_corr', cTable.Properties.VariableNames)
        pVals = cTable.pVal_corr;
    else
        pVals = cTable.pVal;
    end

    p_str = cell(nRows, 1);
    sig = cell(nRows, 1);
    for i = 1:nRows
        p_str{i} = exploreFNIRS.report.formatPValue(pVals(i));
        sig{i} = strtrim(string(getStars(pVals(i))));
    end

    T = table(Contrast, Delta, SD, F_str, df, p_str, sig, ...
        'VariableNames', {'Contrast', 'Delta', 'SD', 'F', 'df', 'p', 'Sig'});

    % Optional CI
    if opts.CI
        tCrit = tinv(1 - opts.Alpha/2, cTable.df2);
        ciLow = cTable.deltaE - tCrit .* cTable.SD;
        ciHigh = cTable.deltaE + tCrit .* cTable.SD;
        CI = cell(nRows, 1);
        for i = 1:nRows
            CI{i} = sprintf('[%.3f, %.3f]', ciLow(i), ciHigh(i));
        end
        T.CI = CI;
    end
end


function s = getStars(p)
    if p < 0.001
        s = '***';
    elseif p < 0.01
        s = '**';
    elseif p < 0.05
        s = '*';
    elseif p < 0.1
        s = '+';
    else
        s = '';
    end
end
