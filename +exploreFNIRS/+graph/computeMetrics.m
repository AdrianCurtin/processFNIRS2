function result = computeMetrics(input, varargin)
% COMPUTEMETRICS Compute graph theory metrics from a connectivity matrix
%
% Convenience dispatcher that thresholds a connectivity matrix and computes
% selected graph theory metrics. Accepts a connectivity result struct, a
% group result, or a raw matrix.
%
% By default computes all metrics except smallWorld (which is slow).
% Use 'Metrics', {'all'} to include smallWorld, or select specific metrics
% with 'Metrics', {'degree', 'clustering', 'modularity'}.
%
% Reference:
%   Rubinov, M. & Sporns, O. (2010). Complex network measures of brain
%   connectivity: Uses and interpretations. NeuroImage, 52(3), 1059-1069.
%   DOI: 10.1016/j.neuroimage.2009.10.003
%
% Syntax:
%   result = exploreFNIRS.graph.computeMetrics(connResult)
%   result = exploreFNIRS.graph.computeMetrics(connResult, 'Threshold', 0.3)
%   result = exploreFNIRS.graph.computeMetrics(connResult, 'Metrics', {'degree', 'modularity'})
%
% Inputs:
%   input - One of:
%     - Connectivity result struct from computeMatrix
%     - Group result struct from Experiment.connectivity() (with .Mean)
%     - Graph struct from threshold() (if already thresholded)
%     - Raw [N x N] numeric matrix
%
% Name-Value Parameters:
%   Threshold       - Threshold value (default: 0.3). Ignored if input is a graph struct.
%   ThresholdMethod - 'absolute' (default), 'proportional', 'significance'
%   Binarize        - Binarize graph (default: false)
%   AbsoluteWeight  - Use |w| (default: true)
%   Metrics         - Cell array of metric names to compute:
%                     'degree', 'clustering', 'betweenness', 'efficiency',
%                     'pathLength', 'modularity', 'smallWorld', 'hubs'
%                     Use {'all'} for everything including smallWorld.
%                     Default: all except 'smallWorld'.
%   Gamma           - Modularity resolution parameter (default: 1)
%   NReplicates     - Modularity replicates (default: 100)
%   NRandom         - Small-world null networks (default: 100)
%
% Outputs:
%   result - Struct with fields:
%     .graph        Graph struct from threshold()
%     .degree       Struct from degree()
%     .clustering   Struct from clusteringCoefficient()
%     .betweenness  Struct from betweenness()
%     .efficiency   Struct from efficiency()
%     .pathLength   Struct from charPathLength()
%     .modularity   Struct from modularity()
%     .smallWorld   Struct from smallWorld() (only if requested)
%     .hubs         Struct from detectHubs()
%     .channels     [1 x N] channel indices
%     .labels       {N x 1} labels
%
% Example:
%   conn = exploreFNIRS.connectivity.computeMatrix(processed, 'Method', 'pearson');
%   metrics = exploreFNIRS.graph.computeMetrics(conn, ...
%       'ThresholdMethod', 'proportional', 'Threshold', 0.15);
%   disp(metrics.modularity.Q);
%   disp(metrics.efficiency.globalEfficiency);
%
% See also: exploreFNIRS.graph.threshold, exploreFNIRS.graph.plotNetwork,
%   exploreFNIRS.graph.metricsToTable

    allMetricNames = {'degree','clustering','betweenness','efficiency', ...
        'pathLength','modularity','smallWorld','hubs'};
    defaultMetrics = setdiff(allMetricNames, {'smallWorld'});

    p = inputParser;
    addRequired(p, 'input');
    addParameter(p, 'Threshold', 0.3, @(x) isnumeric(x) && isscalar(x));
    addParameter(p, 'ThresholdMethod', 'absolute', @ischar);
    addParameter(p, 'Binarize', false, @islogical);
    addParameter(p, 'AbsoluteWeight', true, @islogical);
    addParameter(p, 'Metrics', defaultMetrics, @(x) iscell(x) || ischar(x));
    addParameter(p, 'Gamma', 1, @isnumeric);
    addParameter(p, 'NReplicates', 100, @isnumeric);
    addParameter(p, 'NRandom', 100, @isnumeric);
    parse(p, input, varargin{:});
    opts = p.Results;

    % Resolve metric list
    if ischar(opts.Metrics)
        opts.Metrics = {opts.Metrics};
    end
    if any(strcmpi(opts.Metrics, 'all'))
        metrics = allMetricNames;
    else
        metrics = lower(opts.Metrics);
        allLower = lower(allMetricNames);
        invalid = setdiff(metrics, allLower);
        if ~isempty(invalid)
            error('exploreFNIRS:graph:computeMetrics', ...
                'Unknown metric(s): %s. Valid: %s', ...
                strjoin(invalid, ', '), strjoin(allMetricNames, ', '));
        end
    end
    doMetric = @(name) any(strcmpi(metrics, name));

    % Threshold if needed (skip if already a graph struct)
    if isstruct(input) && isfield(input, 'W') && isfield(input, 'A') && isfield(input, 'N')
        G = input;
    else
        G = exploreFNIRS.graph.threshold(input, ...
            'Method', opts.ThresholdMethod, ...
            'Value', opts.Threshold, ...
            'Binarize', opts.Binarize, ...
            'AbsoluteWeight', opts.AbsoluteWeight);
    end

    result.graph = G;
    result.channels = G.channels;
    result.labels = G.labels;

    % Compute requested metrics
    if doMetric('degree')
        result.degree = exploreFNIRS.graph.degree(G);
    end

    if doMetric('clustering')
        result.clustering = exploreFNIRS.graph.clusteringCoefficient(G);
    end

    if doMetric('betweenness')
        result.betweenness = exploreFNIRS.graph.betweenness(G);
    end

    if doMetric('efficiency')
        result.efficiency = exploreFNIRS.graph.efficiency(G);
    end

    if doMetric('pathlength')
        result.pathLength = exploreFNIRS.graph.charPathLength(G);
    end

    if doMetric('modularity')
        result.modularity = exploreFNIRS.graph.modularity(G, ...
            'Gamma', opts.Gamma, 'NReplicates', opts.NReplicates);
    end

    if doMetric('smallworld')
        result.smallWorld = exploreFNIRS.graph.smallWorld(G, ...
            'NRandom', opts.NRandom);
    end

    if doMetric('hubs')
        % Ensure prerequisite metrics are available
        if ~isfield(result, 'modularity')
            modArg = [];
        else
            modArg = result.modularity;
        end
        result.hubs = exploreFNIRS.graph.detectHubs(G, 'Modularity', modArg);
    end
end
