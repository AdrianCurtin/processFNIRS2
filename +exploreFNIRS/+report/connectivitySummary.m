function T = connectivitySummary(connResult, varargin)
% CONNECTIVITYSUMMARY Summary statistics from connectivity analysis
%
% Extracts key metrics from Experiment.connectivity() output and formats
% as a publication-ready table.
%
% Syntax:
%   T = exploreFNIRS.report.connectivitySummary(result)
%   T = exploreFNIRS.report.connectivitySummary(result, 'Metric', 'global')
%
% Inputs:
%   connResult - Struct array from Experiment.connectivity() (one per group)
%
% Name-Value Parameters:
%   Metric    - 'global' (default): mean of all edges
%               'diagonal': mean self-connections (if applicable)
%               'threshold': count of edges above threshold
%   Threshold - Coupling threshold for 'threshold' metric (default: 0.3)
%   Precision - Decimal places (default: 3)
%
% Outputs:
%   T - Table with Group, N, Mean, SD, SEM, Method, Biomarker columns
%
% Example:
%   result = ex.connectivity('Method', 'pearson');
%   T = exploreFNIRS.report.connectivitySummary(result);
%   disp(T);
%
% See also: exploreFNIRS.connectivity.computeMatrix

    ip = inputParser;
    addRequired(ip, 'connResult', @isstruct);
    addParameter(ip, 'Metric', 'global', @ischar);
    addParameter(ip, 'Threshold', 0.3, @isnumeric);
    addParameter(ip, 'Precision', 3, @isnumeric);
    parse(ip, connResult, varargin{:});
    opts = ip.Results;

    nGroups = length(connResult);
    prec = opts.Precision;

    Group = cell(nGroups, 1);
    N = nan(nGroups, 1);
    MeanStr = cell(nGroups, 1);
    SDStr = cell(nGroups, 1);
    SEMStr = cell(nGroups, 1);
    Method = cell(nGroups, 1);
    Biomarker = cell(nGroups, 1);

    for g = 1:nGroups
        cr = connResult(g);
        Group{g} = cr.label;
        N(g) = cr.N;
        Method{g} = cr.method;
        Biomarker{g} = cr.biomarker;

        switch lower(opts.Metric)
            case 'global'
                % Mean of upper triangle (exclude diagonal)
                mask = triu(true(size(cr.Mean)), 1);
                vals = cr.Mean(mask);
                sdVals = cr.SD(mask);
                semVals = cr.SEM(mask);
                MeanStr{g} = sprintf('%.*f', prec, mean(vals, 'omitnan'));
                SDStr{g} = sprintf('%.*f', prec, mean(sdVals, 'omitnan'));
                SEMStr{g} = sprintf('%.*f', prec, mean(semVals, 'omitnan'));

            case 'threshold'
                mask = triu(true(size(cr.Mean)), 1);
                vals = cr.Mean(mask);
                nAbove = sum(vals > opts.Threshold);
                nTotal = sum(mask(:));
                MeanStr{g} = sprintf('%d/%d (%.0f%%)', nAbove, nTotal, ...
                    100 * nAbove / max(nTotal, 1));
                SDStr{g} = '-';
                SEMStr{g} = '-';

            otherwise
                MeanStr{g} = '-';
                SDStr{g} = '-';
                SEMStr{g} = '-';
        end
    end

    T = table(Group, N, MeanStr, SDStr, SEMStr, Method, Biomarker, ...
        'VariableNames', {'Group', 'N', 'Mean', 'SD', 'SEM', 'Method', 'Biomarker'});
end
