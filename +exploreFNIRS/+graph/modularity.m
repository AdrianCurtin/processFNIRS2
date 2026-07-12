function result = modularity(G, varargin)
% MODULARITY Community detection via the Louvain algorithm
%
% Detects network communities by optimizing the modularity quality function
% Q using the Louvain algorithm (Blondel et al., 2008). Runs multiple
% random restarts and returns the partition with highest Q. Also computes
% the participation coefficient for each node, measuring the diversity of
% inter-community connections.
%
% Reference:
%   Blondel, V. D., Guillaume, J.-L., Lambiotte, R. & Lefebvre, E. (2008).
%   Fast unfolding of communities in large networks.
%   Journal of Statistical Mechanics, P10008.
%   DOI: 10.1088/1742-5468/2008/10/P10008
%
% Syntax:
%   result = exploreFNIRS.graph.modularity(G)
%   result = exploreFNIRS.graph.modularity(G, 'Gamma', 1.5, 'NReplicates', 200)
%
% Inputs:
%   G - Graph struct from exploreFNIRS.graph.threshold
%
% Name-Value Parameters:
%   Gamma       - Resolution parameter (default: 1). Higher = more/smaller communities
%   NReplicates - Number of random restarts (default: 100)
%
% Outputs:
%   result - Struct with fields:
%     .communityID        [1 x N] community assignment (1-indexed)
%     .Q                  Modularity value Q
%     .nCommunities       Number of communities detected
%     .participationCoeff [1 x N] participation coefficient per node
%
% Example:
%   G = exploreFNIRS.graph.threshold(conn, 'Method', 'proportional', 'Value', 0.2);
%   mod = exploreFNIRS.graph.modularity(G, 'Gamma', 1);
%   fprintf('Q = %.3f, %d communities\n', mod.Q, mod.nCommunities);
%
% See also: exploreFNIRS.graph.threshold, exploreFNIRS.graph.smallWorld,
%   exploreFNIRS.graph.detectHubs

    p = inputParser;
    addRequired(p, 'G', @isstruct);
    addParameter(p, 'Gamma', 1, @(x) isnumeric(x) && isscalar(x) && x > 0);
    addParameter(p, 'NReplicates', 100, @(x) isnumeric(x) && isscalar(x) && x >= 1);
    parse(p, G, varargin{:});
    gamma = p.Results.Gamma;
    nReps = round(p.Results.NReplicates);

    validateGraph(G);

    N = G.N;
    W = G.W;

    if N <= 1
        result.communityID = ones(1, N);
        result.Q = 0;
        result.nCommunities = 1;
        result.participationCoeff = zeros(1, N);
        return;
    end

    % Run Louvain multiple times, keep best Q
    bestQ = -Inf;
    bestCI = [];

    for rep = 1:nReps
        [ci, Q] = louvain(W, gamma);
        if Q > bestQ
            bestQ = Q;
            bestCI = ci;
        end
    end

    % Relabel communities to be contiguous 1:K
    [~, ~, bestCI] = unique(bestCI);
    bestCI = bestCI';

    nComm = max(bestCI);

    % Participation coefficient
    pc = participationCoefficient(G.A, bestCI);

    result.communityID = bestCI;
    result.Q = bestQ;
    result.nCommunities = nComm;
    result.participationCoeff = pc;
end


function [ciOrig, Q] = louvain(W, gamma)
% LOUVAIN Single run of the Louvain community detection algorithm
%
% Phase 1: Greedily move nodes to neighboring communities to maximize dQ.
% Phase 2: Aggregate communities into super-nodes and repeat.

    Norig = size(W, 1);
    N = Norig;
    m = sum(W(:)) / 2;

    if m == 0
        ciOrig = (1:Norig)';
        Q = 0;
        return;
    end

    k = sum(W, 2);
    ci = (1:N)';

    % Track mapping from original nodes to current super-nodes
    origMap = (1:Norig)';

    nodeOrder = randperm(N);

    improved = true;
    while improved
        improved = false;

        % Phase 1: local moves
        localImproved = true;
        while localImproved
            localImproved = false;
            for idx = 1:N
                i = nodeOrder(idx);
                ci_i = ci(i);

                neighbors = find(W(i, :) > 0);
                neighborComms = unique(ci(neighbors));

                if ~ismember(ci_i, neighborComms)
                    neighborComms = [ci_i; neighborComms(:)]; %#ok<AGROW>
                end

                bestDQ = 0;
                bestComm = ci_i;

                for c = neighborComms'
                    if c == ci_i, continue; end
                    dQ = moveDeltaQ(W, k, m, gamma, i, ci, ci_i, c);
                    if dQ > bestDQ
                        bestDQ = dQ;
                        bestComm = c;
                    end
                end

                if bestComm ~= ci_i
                    ci(i) = bestComm;
                    localImproved = true;
                    improved = true;
                end
            end
        end

        % Phase 2: aggregate communities into super-nodes
        [~, ~, ciNew] = unique(ci);
        nComm = max(ciNew);

        if nComm == N
            break;
        end

        % Update original-to-supernode mapping
        origMap = ciNew(origMap);

        % Build super-node weight matrix
        Wnew = zeros(nComm);
        for a = 1:nComm
            for b = a:nComm
                w = sum(sum(W(ciNew == a, ciNew == b)));
                Wnew(a, b) = w;
                Wnew(b, a) = w;
            end
        end

        N = nComm;
        W = Wnew;
        k = sum(W, 2);
        m = sum(W(:)) / 2;
        nodeOrder = randperm(N);
        ci = (1:N)';
    end

    % Map final super-node communities back to original nodes
    ciOrig = ci(origMap);

    Q = computeModularity(W, k, m, gamma, ci);
end


function dQ = moveDeltaQ(W, k, m, gamma, i, ci, fromComm, toComm)
% Compute the change in modularity from moving node i from fromComm to toComm

    ki = k(i);

    inTo = ci == toComm;
    ki_to = sum(W(i, inTo));
    Sigma_to = sum(k(inTo));

    inFrom = ci == fromComm;
    inFrom(i) = false;
    ki_from = sum(W(i, inFrom));
    Sigma_from = sum(k(inFrom)) + ki;

    dQ = (ki_to - ki_from) / m + ...
         gamma * ki * (Sigma_from - ki - Sigma_to) / (2 * m^2);
end


function Q = computeModularity(W, k, m, gamma, ci)
% Compute Newman-Girvan modularity Q
    N = length(ci);
    Q = 0;
    for i = 1:N
        for j = 1:N
            if ci(i) == ci(j)
                Q = Q + W(i, j) - gamma * k(i) * k(j) / (2 * m);
            end
        end
    end
    Q = Q / (2 * m);
end


function pc = participationCoefficient(A, ci)
% Participation coefficient: diversity of inter-community connections
%   PC_i = 1 - sum_s (k_is / k_i)^2
% where k_is is the number of connections from i to community s

    N = size(A, 1);
    k = sum(A, 2)';
    comms = unique(ci);
    pc = ones(1, N);

    for s = comms(:)'
        inComm = ci == s;
        ks = sum(A(:, inComm), 2)';
        pc = pc - (ks ./ max(k, eps)) .^ 2;
    end

    pc(k == 0) = 0;
end


function validateGraph(G)
    if ~isstruct(G) || ~isfield(G, 'W') || ~isfield(G, 'A') || ~isfield(G, 'N')
        error('exploreFNIRS:graph:modularity', ...
            'Input must be a graph struct from threshold()');
    end
end
