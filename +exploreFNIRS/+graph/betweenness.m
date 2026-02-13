function result = betweenness(G)
% BETWEENNESS Betweenness centrality for each node
%
% Computes betweenness centrality using MATLAB's built-in graph object.
% Betweenness centrality of a node v is the fraction of all shortest
% paths between pairs of other nodes that pass through v. Values are
% normalized to [0, 1] by dividing by (N-1)*(N-2)/2 for undirected
% or (N-1)*(N-2) for directed graphs.
%
% Reference:
%   Brandes, U. (2001). A faster algorithm for betweenness centrality.
%   Journal of Mathematical Sociology, 25(2), 163-177.
%   DOI: 10.1080/0022250X.2001.9990249
%
% Syntax:
%   result = exploreFNIRS.graph.betweenness(G)
%
% Inputs:
%   G - Graph struct from exploreFNIRS.graph.threshold
%
% Outputs:
%   result - Struct with fields:
%     .BC       [1 x N] normalized betweenness centrality
%     .BCraw    [1 x N] raw (unnormalized) betweenness centrality
%
% Example:
%   G = exploreFNIRS.graph.threshold(conn);
%   bc = exploreFNIRS.graph.betweenness(G);
%   [~, hub] = max(bc.BC);
%   fprintf('Most central node: %d (BC = %.3f)\n', hub, bc.BC(hub));
%
% See also: exploreFNIRS.graph.threshold, exploreFNIRS.graph.degree

    validateGraph(G);

    N = G.N;
    W = G.W;

    if N <= 2
        result.BC = zeros(1, N);
        result.BCraw = zeros(1, N);
        return;
    end

    % Convert weights to distances (stronger = shorter)
    D = zeros(N);
    D(W > 0) = 1 ./ W(W > 0);

    % Build MATLAB graph and compute betweenness
    if G.directed
        gObj = digraph(D);
        BCraw = centrality(gObj, 'betweenness');
        normFactor = (N - 1) * (N - 2);
    else
        D_sym = max(D, D');
        gObj = graph(D_sym);
        BCraw = centrality(gObj, 'betweenness');
        normFactor = (N - 1) * (N - 2) / 2;
    end

    BCraw = BCraw';  % column → row

    if normFactor > 0
        BC = BCraw / normFactor;
    else
        BC = BCraw;
    end

    result.BC = BC;
    result.BCraw = BCraw;
end


function validateGraph(G)
    if ~isstruct(G) || ~isfield(G, 'W') || ~isfield(G, 'A') || ~isfield(G, 'N')
        error('exploreFNIRS:graph:betweenness', ...
            'Input must be a graph struct from threshold()');
    end
end
