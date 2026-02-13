function T = metricsToTable(results, varargin)
% METRICSTOTABLE Export graph metrics to a long-format MATLAB table
%
% Converts computeMetrics output to a MATLAB table with one row per node.
% For struct arrays (multiple groups), adds a Group column. Useful for
% downstream statistical analysis or CSV export.
%
% Syntax:
%   T = exploreFNIRS.graph.metricsToTable(result)
%   T = exploreFNIRS.graph.metricsToTable(results, 'GroupLabels', {'Rest','Task'})
%   T = exploreFNIRS.graph.metricsToTable(result, 'SavePath', 'metrics.csv')
%
% Inputs:
%   results - Single computeMetrics result struct, or struct array
%
% Name-Value Parameters:
%   GroupLabels - Cell array of group names (default: 'Group 1', ...)
%   SavePath    - File path to save as CSV (default: '')
%
% Outputs:
%   T - MATLAB table with columns:
%       Channel, Label, Degree, Strength, ClusteringCoeff, Betweenness,
%       LocalEfficiency, CommunityID, HubScore, IsHub
%       (Group column added for multi-element struct array)
%
% Example:
%   metrics = exploreFNIRS.graph.computeMetrics(conn);
%   T = exploreFNIRS.graph.metricsToTable(metrics, 'SavePath', 'metrics.csv');
%   disp(T);
%
% See also: exploreFNIRS.graph.computeMetrics, exploreFNIRS.graph.plotMetrics

    p = inputParser;
    addRequired(p, 'results');
    addParameter(p, 'GroupLabels', {}, @iscell);
    addParameter(p, 'SavePath', '', @ischar);
    parse(p, results, varargin{:});
    opts = p.Results;

    if ~isstruct(results)
        error('exploreFNIRS:graph:metricsToTable', 'Input must be a struct or struct array');
    end

    nGroups = length(results);
    multiGroup = nGroups > 1;

    if isempty(opts.GroupLabels)
        groupLabels = arrayfun(@(g) sprintf('Group %d', g), 1:nGroups, ...
            'UniformOutput', false);
    else
        groupLabels = opts.GroupLabels;
    end

    tables = cell(1, nGroups);
    for g = 1:nGroups
        r = results(g);
        N = length(r.channels);

        channels = r.channels(:);
        labels = r.labels(:);

        % Initialize with NaN/defaults
        degreeVals = nan(N, 1);
        strengthVals = nan(N, 1);
        ccVals = nan(N, 1);
        bcVals = nan(N, 1);
        localEffVals = nan(N, 1);
        commVals = nan(N, 1);
        hubScoreVals = nan(N, 1);
        isHubVals = false(N, 1);

        if isfield(r, 'degree')
            degreeVals = r.degree.degree(:);
            strengthVals = r.degree.strength(:);
        end
        if isfield(r, 'clustering')
            ccVals = r.clustering.C(:);
        end
        if isfield(r, 'betweenness')
            bcVals = r.betweenness.BC(:);
        end
        if isfield(r, 'efficiency')
            localEffVals = r.efficiency.localEfficiency(:);
        end
        if isfield(r, 'modularity')
            commVals = r.modularity.communityID(:);
        end
        if isfield(r, 'hubs')
            hubScoreVals = r.hubs.hubScore(:);
            isHubVals = r.hubs.isHub(:);
        end

        Tg = table(channels, labels, degreeVals, strengthVals, ...
            ccVals, bcVals, localEffVals, commVals, hubScoreVals, isHubVals, ...
            'VariableNames', {'Channel', 'Label', 'Degree', 'Strength', ...
            'ClusteringCoeff', 'Betweenness', 'LocalEfficiency', ...
            'CommunityID', 'HubScore', 'IsHub'});

        if multiGroup
            Tg.Group = repmat(groupLabels(g), N, 1);
        end

        tables{g} = Tg;
    end

    T = vertcat(tables{:});

    % Move Group to first column if present
    if multiGroup
        T = T(:, ['Group', setdiff(T.Properties.VariableNames, 'Group', 'stable')]);
    end

    % Save if requested
    if ~isempty(opts.SavePath)
        writetable(T, opts.SavePath);
        fprintf('Saved metrics table to %s\n', opts.SavePath);
    end
end
