function result = charPathLength(G)
% CHARPATHLENGTH Characteristic path length and distance matrix
%
% Computes shortest path distances between all node pairs using MATLAB's
% built-in graph/digraph objects. Distance is defined as 1/weight, so
% stronger connections correspond to shorter paths. Returns characteristic
% path length (lambda), eccentricity, radius, and diameter.
%
% Disconnected components are handled gracefully: Inf distances between
% unreachable pairs are excluded from the mean path length calculation.
%
% Syntax:
%   result = exploreFNIRS.graph.charPathLength(G)
%
% Inputs:
%   G - Graph struct from exploreFNIRS.graph.threshold
%
% Outputs:
%   result - Struct with fields:
%     .lambda      Characteristic path length (mean finite distance)
%     .distMatrix  [N x N] shortest path distance matrix
%     .eccentricity [1 x N] max finite distance from each node
%     .radius      Min eccentricity across nodes
%     .diameter    Max eccentricity across nodes
%     .nComponents Number of connected components
%
% Reference:
%   Rubinov, M. & Sporns, O. (2010). Complex network measures of brain
%   connectivity: Uses and interpretations. NeuroImage, 52(3), 1059-1069.
%   DOI: 10.1016/j.neuroimage.2009.10.003
%
% Example:
%   G = exploreFNIRS.graph.threshold(conn);
%   pl = exploreFNIRS.graph.charPathLength(G);
%   fprintf('Lambda = %.3f, Components = %d\n', pl.lambda, pl.nComponents);
%
% See also: exploreFNIRS.graph.threshold, exploreFNIRS.graph.efficiency

    validateGraph(G);

    N = G.N;
    W = G.W;

    if N <= 1
        result.lambda = 0;
        result.distMatrix = zeros(N);
        result.eccentricity = zeros(1, N);
        result.radius = 0;
        result.diameter = 0;
        result.nComponents = N;
        return;
    end

    % Convert weights to distances: stronger connection = shorter path
    % Distance = 1/weight for positive weights
    D = zeros(N);
    D(W > 0) = 1 ./ W(W > 0);

    % Build MATLAB graph object for shortest paths
    if G.directed
        gObj = digraph(D);
        distMatrix = distances(gObj);
    else
        % Symmetrize (take upper triangle)
        D_sym = max(D, D');
        gObj = graph(D_sym);
        distMatrix = distances(gObj);
    end

    % Characteristic path length: mean of all finite off-diagonal distances
    offDiag = ~eye(N, 'logical');
    finiteD = distMatrix(offDiag);
    finiteD = finiteD(isfinite(finiteD));

    if isempty(finiteD)
        lambda = Inf;
    else
        lambda = mean(finiteD);
    end

    % Eccentricity: max finite distance from each node
    ecc = zeros(1, N);
    for i = 1:N
        dists = distMatrix(i, :);
        dists(i) = [];
        finiteDists = dists(isfinite(dists));
        if isempty(finiteDists)
            ecc(i) = Inf;
        else
            ecc(i) = max(finiteDists);
        end
    end

    % Radius and diameter (from finite eccentricities)
    finiteEcc = ecc(isfinite(ecc));
    if isempty(finiteEcc)
        radius = Inf;
        diameter = Inf;
    else
        radius = min(finiteEcc);
        diameter = max(finiteEcc);
    end

    % Number of connected components
    if G.directed
        % Use undirected version for component count
        gUnd = graph(max(G.A, G.A'));
    else
        gUnd = graph(G.A);
    end
    bins = conncomp(gUnd);
    nComponents = max(bins);

    result.lambda = lambda;
    result.distMatrix = distMatrix;
    result.eccentricity = ecc;
    result.radius = radius;
    result.diameter = diameter;
    result.nComponents = nComponents;
end


function validateGraph(G)
    if ~isstruct(G) || ~isfield(G, 'W') || ~isfield(G, 'A') || ~isfield(G, 'N')
        error('exploreFNIRS:graph:charPathLength', ...
            'Input must be a graph struct from threshold()');
    end
end
