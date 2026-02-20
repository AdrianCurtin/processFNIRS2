function result = smallWorld(G, varargin)
% SMALLWORLD Small-world indices via comparison to random null networks
%
% Computes the sigma and omega small-world indices by comparing the
% network's clustering coefficient and path length to ensembles of
% degree-preserving random networks (Maslov & Sneppen rewiring).
%
% Sigma = (C/C_rand) / (L/L_rand)    [Humphries & Gurney 2008]
%   sigma > 1 indicates small-world organization
%
% Omega = L_rand/L - C/C_lattice     [Telesford et al. 2011]
%   omega near 0 = small-world, near -1 = lattice-like, near +1 = random
%
% This function is computationally expensive due to null network generation
% and is excluded from computeMetrics by default. Users must opt in.
%
% Reference:
%   Humphries, M. D. & Gurney, K. (2008). Network 'small-world-ness':
%   a quantitative method for determining canonical network equivalence.
%   PLoS One, 3(4), e0002051. DOI: 10.1371/journal.pone.0002051
%
%   Maslov, S. & Sneppen, K. (2002). Specificity and stability in
%   topology of protein networks. Science, 296(5569), 910-913.
%   DOI: 10.1126/science.1065103
%
% Syntax:
%   result = exploreFNIRS.graph.smallWorld(G)
%   result = exploreFNIRS.graph.smallWorld(G, 'NRandom', 50)
%
% Inputs:
%   G - Graph struct from exploreFNIRS.graph.threshold
%
% Name-Value Parameters:
%   NRandom - Number of random null networks (default: 100)
%
% Outputs:
%   result - Struct with fields:
%     .sigma    Small-world sigma index
%     .omega    Small-world omega index
%     .C        Network clustering coefficient
%     .C_rand   Mean clustering of random nulls
%     .C_lattice Clustering of equivalent ring lattice
%     .L        Network characteristic path length
%     .L_rand   Mean path length of random nulls
%
% Example:
%   G = exploreFNIRS.graph.threshold(conn, 'Method', 'proportional', 'Value', 0.2);
%   sw = exploreFNIRS.graph.smallWorld(G, 'NRandom', 50);
%   fprintf('Sigma = %.3f, Omega = %.3f\n', sw.sigma, sw.omega);
%
% See also: exploreFNIRS.graph.threshold, exploreFNIRS.graph.clusteringCoefficient,
%   exploreFNIRS.graph.charPathLength

    p = inputParser;
    addRequired(p, 'G', @isstruct);
    addParameter(p, 'NRandom', 100, @(x) isnumeric(x) && isscalar(x) && x >= 1);
    parse(p, G, varargin{:});
    nRand = round(p.Results.NRandom);

    validateGraph(G);

    N = G.N;

    % Check connectivity
    pl = exploreFNIRS.graph.charPathLength(G);
    if pl.nComponents > 1
        warning('exploreFNIRS:graph:smallWorld:disconnected', ...
            'Graph has %d components. Small-world indices may be unreliable.', ...
            pl.nComponents);
    end

    % Network clustering and path length
    cc = exploreFNIRS.graph.clusteringCoefficient(G);
    C = cc.meanC;
    L = pl.lambda;

    if ~isfinite(L) || L == 0
        result.sigma = NaN;
        result.omega = NaN;
        result.C = C;
        result.C_rand = NaN;
        result.C_lattice = NaN;
        result.L = L;
        result.L_rand = NaN;
        return;
    end

    % Generate random null networks via Maslov-Sneppen rewiring
    C_rands = zeros(1, nRand);
    L_rands = zeros(1, nRand);

    useParfor = false;
    if nRand > 10
        [canUse, poolRunning] = pf2_base.accel.canParfor();
        useParfor = canUse && poolRunning;
    end

    Wref = G.W;
    isDir = G.directed;

    if useParfor
        parfor r = 1:nRand
            Wrand = maslovSneppen(Wref, isDir);
            Grand = struct('W', Wrand, 'A', double(Wrand > 0), 'N', N, 'directed', isDir);
            ccRand = exploreFNIRS.graph.clusteringCoefficient(Grand);
            plRand = exploreFNIRS.graph.charPathLength(Grand);
            C_rands(r) = ccRand.meanC;
            L_rands(r) = plRand.lambda;
        end
    else
        for r = 1:nRand
            Wrand = maslovSneppen(Wref, isDir);
            Grand = struct('W', Wrand, 'A', double(Wrand > 0), 'N', N, 'directed', isDir);
            ccRand = exploreFNIRS.graph.clusteringCoefficient(Grand);
            plRand = exploreFNIRS.graph.charPathLength(Grand);
            C_rands(r) = ccRand.meanC;
            L_rands(r) = plRand.lambda;
        end
    end

    C_rand = mean(C_rands);
    L_rand = mean(L_rands);

    % Sigma = (C/C_rand) / (L/L_rand)
    if C_rand > 0 && L_rand > 0
        sigma = (C / C_rand) / (L / L_rand);
    else
        sigma = NaN;
    end

    % Ring lattice clustering for omega
    C_lattice = ringLatticeClustering(G);

    % Omega = L_rand/L - C/C_lattice
    if L > 0 && C_lattice > 0
        omega = L_rand / L - C / C_lattice;
    else
        omega = NaN;
    end

    result.sigma = sigma;
    result.omega = omega;
    result.C = C;
    result.C_rand = C_rand;
    result.C_lattice = C_lattice;
    result.L = L;
    result.L_rand = L_rand;
end


function Wrand = maslovSneppen(W, isDirected)
% MASLOVSNEPPEN Degree-preserving random rewiring
%
% Pick two random edges (a-b, c-d), swap to (a-d, c-b) if no multi-edge
% or self-loop is created. Repeat for nSwaps = 5 * nEdges iterations.

    N = size(W, 1);
    Wrand = W;

    if isDirected
        [rows, cols] = find(Wrand);
    else
        [rows, cols] = find(triu(Wrand));
    end
    nEdges = length(rows);

    if nEdges < 2
        return;
    end

    nSwaps = 5 * nEdges;
    weights = zeros(nEdges, 1);
    for e = 1:nEdges
        weights(e) = Wrand(rows(e), cols(e));
    end

    for s = 1:nSwaps
        % Pick two random edges
        e1 = randi(nEdges);
        e2 = randi(nEdges);
        if e1 == e2, continue; end

        a = rows(e1); b = cols(e1);
        c = rows(e2); d = cols(e2);

        % Check no self-loops
        if a == d || c == b, continue; end

        % Check no multi-edges
        if Wrand(a, d) > 0 || Wrand(c, b) > 0, continue; end

        % Perform swap
        w1 = weights(e1);
        w2 = weights(e2);

        Wrand(a, b) = 0; Wrand(c, d) = 0;
        Wrand(a, d) = w1; Wrand(c, b) = w2;

        if ~isDirected
            Wrand(b, a) = 0; Wrand(d, c) = 0;
            Wrand(d, a) = w1; Wrand(b, c) = w2;
        end

        rows(e1) = a; cols(e1) = d;
        rows(e2) = c; cols(e2) = b;
    end
end


function C_lat = ringLatticeClustering(G)
% Approximate clustering coefficient of a ring lattice with same N and mean degree
    N = G.N;
    k = mean(sum(G.A, 2));
    halfK = floor(k / 2);

    if halfK < 2 || N < 4
        C_lat = 0;
        return;
    end

    % For a regular ring lattice with N nodes and each connected to K nearest:
    % C = 3*(K-2) / (4*(K-1)) for even K
    C_lat = 3 * (2 * halfK - 2) / (4 * (2 * halfK - 1));
    C_lat = max(C_lat, 0);
end


function validateGraph(G)
    if ~isstruct(G) || ~isfield(G, 'W') || ~isfield(G, 'A') || ~isfield(G, 'N')
        error('exploreFNIRS:graph:smallWorld', ...
            'Input must be a graph struct from threshold()');
    end
end
