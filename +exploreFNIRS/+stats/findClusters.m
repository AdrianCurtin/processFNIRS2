function clusters = findClusters(statMap, adjacency, threshold, clusterStatType, tail)
% FINDCLUSTERS Find spatially contiguous clusters in a thresholded stat map
%
% Identifies connected components in a statistical map after thresholding,
% using a spatial adjacency matrix to define connectivity. Each cluster is
% characterized by its member channels and a summary statistic.
%
% Syntax:
%   clusters = exploreFNIRS.stats.findClusters(statMap, adjacency, threshold)
%   clusters = exploreFNIRS.stats.findClusters(..., clusterStatType, tail)
%
% Inputs:
%   statMap         - [1 x nCh] vector of test statistics (t or F values)
%   adjacency       - [nCh x nCh] sparse logical adjacency matrix
%   threshold       - Scalar threshold for cluster formation
%   clusterStatType - 'sumstat' (default), 'maxstat', or 'extent'
%   tail            - 'both' (default), 'positive', or 'negative'
%
% Outputs:
%   clusters - Struct array with fields:
%     .channels - Indices of channels in the cluster
%     .stat     - Cluster-level statistic
%     .polarity - 'positive' or 'negative'
%
% See also: exploreFNIRS.stats.clusterPermutation, pf2.probe.computeAdjacency

if nargin < 4 || isempty(clusterStatType)
    clusterStatType = 'sumstat';
end
if nargin < 5 || isempty(tail)
    tail = 'both';
end

clusters = struct('channels', {}, 'stat', {}, 'polarity', {});

nCh = length(statMap);

% Process positive tail
if ismember(tail, {'both', 'positive'})
    posMask = statMap > threshold;
    posClusters = findConnectedComponents(posMask, adjacency, statMap, clusterStatType, 'positive');
    clusters = [clusters, posClusters];
end

% Process negative tail
if ismember(tail, {'both', 'negative'})
    negMask = statMap < -threshold;
    negClusters = findConnectedComponents(negMask, adjacency, statMap, clusterStatType, 'negative');
    clusters = [clusters, negClusters];
end

end


function clusters = findConnectedComponents(mask, adjacency, statMap, clusterStatType, polarity)
% BFS-based connected component labeling on the masked adjacency graph

clusters = struct('channels', {}, 'stat', {}, 'polarity', {});

candidates = find(mask);
if isempty(candidates)
    return;
end

visited = false(size(mask));
adj = adjacency;

for startIdx = 1:length(candidates)
    node = candidates(startIdx);
    if visited(node)
        continue;
    end

    % BFS from this node
    component = [];
    queue = node;
    visited(node) = true;

    while ~isempty(queue)
        current = queue(1);
        queue(1) = [];
        component(end+1) = current; %#ok<AGROW>

        % Find adjacent nodes that are also in the mask
        neighbors = find(adj(current, :));
        for ni = 1:length(neighbors)
            nb = neighbors(ni);
            if mask(nb) && ~visited(nb)
                visited(nb) = true;
                queue(end+1) = nb; %#ok<AGROW>
            end
        end
    end

    % Compute cluster statistic
    clusterStats = statMap(component);
    switch lower(clusterStatType)
        case 'sumstat'
            cStat = sum(clusterStats);
        case 'maxstat'
            if strcmp(polarity, 'positive')
                cStat = max(clusterStats);
            else
                cStat = min(clusterStats);
            end
        case 'extent'
            cStat = length(component);
        otherwise
            cStat = sum(clusterStats);
    end

    clusters(end+1).channels = sort(component); %#ok<AGROW>
    clusters(end).stat = cStat;
    clusters(end).polarity = polarity;
end

end
