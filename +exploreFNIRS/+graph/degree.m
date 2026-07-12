function result = degree(G)
% DEGREE Compute node degree and strength from a graph struct
%
% Calculates binary degree (number of connections) and weighted strength
% (sum of connection weights) for each node. For directed graphs, computes
% separate in-degree/in-strength and out-degree/out-strength.
%
% Syntax:
%   result = exploreFNIRS.graph.degree(G)
%
% Inputs:
%   G - Graph struct from exploreFNIRS.graph.threshold
%
% Outputs:
%   result - Struct with fields:
%     .degree     [1 x N] binary degree (total for directed)
%     .strength   [1 x N] weighted strength (total for directed)
%     For directed graphs, additionally:
%     .inDegree   [1 x N] in-degree (column sum of A)
%     .outDegree  [1 x N] out-degree (row sum of A)
%     .inStrength [1 x N] in-strength (column sum of W)
%     .outStrength[1 x N] out-strength (row sum of W)
%
% Reference:
%   Rubinov, M. & Sporns, O. (2010). Complex network measures of brain
%   connectivity: Uses and interpretations. NeuroImage, 52(3), 1059-1069.
%   DOI: 10.1016/j.neuroimage.2009.10.003
%
% Example:
%   G = exploreFNIRS.graph.threshold(conn);
%   d = exploreFNIRS.graph.degree(G);
%   disp(d.degree);
%
% See also: exploreFNIRS.graph.threshold, exploreFNIRS.graph.betweenness

    validateGraph(G);

    if G.directed
        % In-degree: connections coming in (column sums)
        result.inDegree = sum(G.A, 1);
        % Out-degree: connections going out (row sums)
        result.outDegree = sum(G.A, 2)';
        % Total degree
        result.degree = result.inDegree + result.outDegree;

        % Weighted strength
        result.inStrength = sum(G.W, 1);
        result.outStrength = sum(G.W, 2)';
        result.strength = result.inStrength + result.outStrength;
    else
        % Undirected: row sum = column sum
        result.degree = sum(G.A, 2)';
        result.strength = sum(G.W, 2)';
    end
end


function validateGraph(G)
    if ~isstruct(G) || ~isfield(G, 'W') || ~isfield(G, 'A') || ~isfield(G, 'N')
        error('exploreFNIRS:graph:degree', ...
            'Input must be a graph struct from threshold()');
    end
end
