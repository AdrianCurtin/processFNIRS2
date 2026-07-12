function result = detectHubs(G, varargin)
% DETECTHUBS Identify hub nodes via composite z-score
%
% Computes a composite hub score from normalized degree, betweenness,
% and clustering (inverted). Nodes with z-score above a threshold are
% classified as hubs. When modularity results are provided, hubs are
% further classified as provincial (high within-module degree) or
% connector (high participation coefficient).
%
% Hub score = z(degree) + z(betweenness) - z(clustering)
%
% Reference:
%   Rubinov, M. & Sporns, O. (2010). Complex network measures of brain
%   connectivity: Uses and interpretations. NeuroImage, 52(3), 1059-1069.
%   DOI: 10.1016/j.neuroimage.2009.10.003
%
% Syntax:
%   result = exploreFNIRS.graph.detectHubs(G)
%   result = exploreFNIRS.graph.detectHubs(G, 'Threshold', 1.5)
%   result = exploreFNIRS.graph.detectHubs(G, 'Modularity', modResult)
%
% Inputs:
%   G - Graph struct from exploreFNIRS.graph.threshold
%
% Name-Value Parameters:
%   Threshold  - Z-score threshold for hub classification (default: 1)
%   Modularity - Modularity result struct from exploreFNIRS.graph.modularity
%                When provided, classifies hubs as 'provincial' or 'connector'
%
% Outputs:
%   result - Struct with fields:
%     .hubScore   [1 x N] composite hub z-score
%     .isHub      [1 x N] logical hub classification
%     .hubType    {1 x N} cell: 'provincial', 'connector', or '' (non-hub)
%     .degree     [1 x N] degree values used
%     .betweenness [1 x N] betweenness values used
%     .clustering [1 x N] clustering values used
%
% Example:
%   G = exploreFNIRS.graph.threshold(conn);
%   hubs = exploreFNIRS.graph.detectHubs(G);
%   fprintf('Hubs: %s\n', strjoin(G.labels(hubs.isHub), ', '));
%
% See also: exploreFNIRS.graph.degree, exploreFNIRS.graph.betweenness,
%   exploreFNIRS.graph.modularity

    p = inputParser;
    addRequired(p, 'G', @isstruct);
    addParameter(p, 'Threshold', 1, @(x) isnumeric(x) && isscalar(x));
    addParameter(p, 'Modularity', [], @(x) isempty(x) || isstruct(x));
    parse(p, G, varargin{:});
    thresh = p.Results.Threshold;
    modResult = p.Results.Modularity;

    validateGraph(G);

    N = G.N;

    if N <= 2
        result.hubScore = zeros(1, N);
        result.isHub = false(1, N);
        result.hubType = repmat({''}, 1, N);
        result.degree = zeros(1, N);
        result.betweenness = zeros(1, N);
        result.clustering = zeros(1, N);
        return;
    end

    % Compute component metrics
    deg = exploreFNIRS.graph.degree(G);
    bc = exploreFNIRS.graph.betweenness(G);
    cc = exploreFNIRS.graph.clusteringCoefficient(G);

    degVals = deg.strength;
    bcVals = bc.BC;
    ccVals = cc.C;

    % Z-score each metric
    zDeg = zscore_safe(degVals);
    zBC = zscore_safe(bcVals);
    zCC = zscore_safe(ccVals);

    % Composite score: high degree + high betweenness - high clustering
    hubScore = zDeg + zBC - zCC;

    % Classify hubs
    isHub = hubScore > thresh;

    % Hub type classification (requires modularity)
    hubType = repmat({''}, 1, N);
    if ~isempty(modResult) && isfield(modResult, 'participationCoeff')
        pc = modResult.participationCoeff;
        for i = 1:N
            if isHub(i)
                if pc(i) > 0.3
                    hubType{i} = 'connector';
                else
                    hubType{i} = 'provincial';
                end
            end
        end
    else
        for i = 1:N
            if isHub(i)
                hubType{i} = 'hub';
            end
        end
    end

    result.hubScore = hubScore;
    result.isHub = isHub;
    result.hubType = hubType;
    result.degree = degVals;
    result.betweenness = bcVals;
    result.clustering = ccVals;
end


function z = zscore_safe(x)
% Z-score that handles constant vectors (returns zeros)
    s = std(x);
    if s < eps
        z = zeros(size(x));
    else
        z = (x - mean(x)) / s;
    end
end


function validateGraph(G)
    if ~isstruct(G) || ~isfield(G, 'W') || ~isfield(G, 'A') || ~isfield(G, 'N')
        error('exploreFNIRS:graph:detectHubs', ...
            'Input must be a graph struct from threshold()');
    end
end
