function result = efficiency(G)
% EFFICIENCY Global and local network efficiency
%
% Global efficiency is the average inverse shortest path distance across
% all node pairs, providing a measure of how efficiently information can
% be exchanged across the whole network. Disconnected pairs contribute
% zero (since 1/Inf = 0), making this metric robust to fragmented graphs.
%
% Local efficiency of a node is the global efficiency of its neighborhood
% subgraph, measuring fault tolerance and local integration.
%
% Reference:
%   Latora, V. & Marchiori, M. (2001). Efficient behavior of small-world
%   networks. Physical Review Letters, 87(19), 198701.
%   DOI: 10.1103/PhysRevLett.87.198701
%
% Syntax:
%   result = exploreFNIRS.graph.efficiency(G)
%
% Inputs:
%   G - Graph struct from exploreFNIRS.graph.threshold
%
% Outputs:
%   result - Struct with fields:
%     .globalEfficiency  Scalar global efficiency
%     .localEfficiency   [1 x N] local efficiency per node
%     .meanLocalEff      Mean local efficiency
%
% Example:
%   G = exploreFNIRS.graph.threshold(conn);
%   eff = exploreFNIRS.graph.efficiency(G);
%   fprintf('Global = %.3f, Mean local = %.3f\n', eff.globalEfficiency, eff.meanLocalEff);
%
% See also: exploreFNIRS.graph.threshold, exploreFNIRS.graph.charPathLength

    validateGraph(G);

    N = G.N;
    W = G.W;

    if N <= 1
        result.globalEfficiency = 0;
        result.localEfficiency = zeros(1, N);
        result.meanLocalEff = 0;
        return;
    end

    % Compute distance matrix (1/weight)
    D = zeros(N);
    D(W > 0) = 1 ./ W(W > 0);

    % Shortest path distances via MATLAB graph
    if G.directed
        gObj = digraph(D);
    else
        D = max(D, D');
        gObj = graph(D);
    end
    distMatrix = distances(gObj);

    % Global efficiency: mean of 1/d_ij for all i ≠ j
    offDiag = ~eye(N, 'logical');
    invD = zeros(N);
    finiteMask = isfinite(distMatrix) & offDiag;
    invD(finiteMask) = 1 ./ distMatrix(finiteMask);

    globalEff = sum(invD(:)) / (N * (N - 1));

    % Local efficiency: efficiency of each node's neighborhood subgraph
    localEff = zeros(1, N);
    for i = 1:N
        % Find neighbors of node i
        neighbors = find(G.A(i, :) | G.A(:, i)');
        nNeighbors = length(neighbors);

        if nNeighbors < 2
            localEff(i) = 0;
            continue;
        end

        % Extract subgraph of neighbors
        Wsub = W(neighbors, neighbors);

        % Compute distances in subgraph
        Dsub = zeros(nNeighbors);
        Dsub(Wsub > 0) = 1 ./ Wsub(Wsub > 0);

        if G.directed
            gSub = digraph(Dsub);
        else
            Dsub = max(Dsub, Dsub');
            gSub = graph(Dsub);
        end
        distSub = distances(gSub);

        % Efficiency of subgraph
        offDiagSub = ~eye(nNeighbors, 'logical');
        invDsub = zeros(nNeighbors);
        finiteSub = isfinite(distSub) & offDiagSub;
        invDsub(finiteSub) = 1 ./ distSub(finiteSub);

        localEff(i) = sum(invDsub(:)) / (nNeighbors * (nNeighbors - 1));
    end

    result.globalEfficiency = globalEff;
    result.localEfficiency = localEff;
    result.meanLocalEff = mean(localEff);
end


function validateGraph(G)
    if ~isstruct(G) || ~isfield(G, 'W') || ~isfield(G, 'A') || ~isfield(G, 'N')
        error('exploreFNIRS:graph:efficiency', ...
            'Input must be a graph struct from threshold()');
    end
end
