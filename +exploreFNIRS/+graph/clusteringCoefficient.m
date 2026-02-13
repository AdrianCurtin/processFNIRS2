function result = clusteringCoefficient(G)
% CLUSTERINGCOEFFICIENT Weighted clustering coefficient and transitivity
%
% Computes the weighted clustering coefficient for each node using the
% Onnela et al. (2005) formula. Weights are normalized to [0, 1] before
% computation. Also returns the network-level transitivity (ratio of
% triangles to triples).
%
% For binary graphs (or binarized graph structs), reduces to the standard
% binary clustering coefficient.
%
% Reference:
%   Onnela, J.-P., Saramaki, J., Kertesz, J. & Kaski, K. (2005).
%   Intensity and coherence of motifs in weighted complex networks.
%   Physical Review E, 71(6), 065103. DOI: 10.1103/PhysRevE.71.065103
%
% Syntax:
%   result = exploreFNIRS.graph.clusteringCoefficient(G)
%
% Inputs:
%   G - Graph struct from exploreFNIRS.graph.threshold
%
% Outputs:
%   result - Struct with fields:
%     .C            [1 x N] weighted clustering coefficient per node
%     .meanC        Scalar mean clustering coefficient
%     .transitivity Network transitivity (3*triangles / triples)
%
% Example:
%   G = exploreFNIRS.graph.threshold(conn);
%   cc = exploreFNIRS.graph.clusteringCoefficient(G);
%   fprintf('Mean clustering = %.3f, Transitivity = %.3f\n', cc.meanC, cc.transitivity);
%
% See also: exploreFNIRS.graph.threshold, exploreFNIRS.graph.efficiency

    validateGraph(G);

    if isfield(G, 'directed') && G.directed
        warning('exploreFNIRS:graph:clusteringCoefficient:directed', ...
            'Clustering coefficient uses the undirected Onnela formula. Input graph is directed; results may be inaccurate.');
        % Symmetrize for undirected formula
        G.A = double(G.A | G.A');
        G.W = (G.W + G.W') / 2;
    end

    N = G.N;
    A = G.A;
    W = G.W;

    % Normalize weights to [0, 1]
    maxW = max(W(:));
    if maxW > 0
        Wn = W / maxW;
    else
        Wn = W;
    end

    % Onnela clustering coefficient:
    % C_i = 1/(k_i*(k_i-1)) * sum_{j,h} (w_ij * w_ih * w_jh)^(1/3)
    %
    % Matrix form: C_i = (W^(1/3) * W^(1/3) * W^(1/3))_ii / (k_i*(k_i-1))
    % where W^(1/3) is element-wise cube root

    W_third = Wn .^ (1/3);
    triCount = diag(W_third * W_third * W_third);  % [N x 1]

    k = sum(A, 2);  % degree of each node [N x 1]
    denom = k .* (k - 1);

    C = zeros(N, 1);
    valid = denom > 0;
    C(valid) = triCount(valid) ./ denom(valid);

    % Transitivity: 3 * triangles / triples
    % triangles = trace(A^3) / 6 (each triangle counted 6 times)
    % triples = sum_i k_i*(k_i-1) / 2
    nTriangles = trace(A * A * A) / 6;
    nTriples = sum(k .* (k - 1)) / 2;

    if nTriples > 0
        transitivity = 3 * nTriangles / nTriples;
    else
        transitivity = 0;
    end

    result.C = C';
    result.meanC = mean(C);
    result.transitivity = transitivity;
end


function validateGraph(G)
    if ~isstruct(G) || ~isfield(G, 'W') || ~isfield(G, 'A') || ~isfield(G, 'N')
        error('exploreFNIRS:graph:clusteringCoefficient', ...
            'Input must be a graph struct from threshold()');
    end
end
