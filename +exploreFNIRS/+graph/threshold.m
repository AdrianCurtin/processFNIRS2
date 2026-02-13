function G = threshold(input, varargin)
% THRESHOLD Convert connectivity matrix to graph struct for graph theory analysis
%
% Thresholds a continuous coupling matrix to create a sparse adjacency
% representation. Supports absolute, proportional (density-based), and
% significance-based thresholding. The output graph struct is the standard
% input to all graph metric functions in this package.
%
% Syntax:
%   G = exploreFNIRS.graph.threshold(connResult)
%   G = exploreFNIRS.graph.threshold(connResult, 'Method', 'proportional', 'Value', 0.15)
%   G = exploreFNIRS.graph.threshold(matrix)
%   G = exploreFNIRS.graph.threshold(connResult, 'Binarize', true)
%
% Inputs:
%   input - One of:
%     - Connectivity result struct from computeMatrix (has .matrix field)
%     - Group result struct from Experiment.connectivity() (has .Mean field)
%     - Raw [N x N] numeric matrix
%
% Name-Value Parameters:
%   Method         - 'absolute' (default), 'proportional', 'significance'
%   Value          - Threshold value (default: 0.3)
%                    absolute: keep edges with |w| >= Value
%                    proportional: keep top Value fraction of edges (0-1)
%                    significance: keep edges with p < Value
%   Binarize       - Convert to binary adjacency (default: false)
%   AbsoluteWeight - Use |w| for weights (default: true)
%   ZeroDiagonal   - Set self-connections to zero (default: true)
%
% Outputs:
%   G - Graph struct with fields:
%     .W          [N x N] weighted adjacency (0 where below threshold)
%     .A          [N x N] binary adjacency
%     .N          Number of nodes
%     .channels   [1 x N] channel indices
%     .labels     {N x 1} labels
%     .directed   logical
%     .method     Threshold method used
%     .threshold  Threshold value
%     .binarized  logical
%     .density    Edge density (fraction of possible edges present)
%     .source     Struct with source connectivity metadata
%
% Example:
%   conn = exploreFNIRS.connectivity.computeMatrix(processed, 'Method', 'pearson');
%   G = exploreFNIRS.graph.threshold(conn, 'Method', 'proportional', 'Value', 0.15);
%   disp(G.density);
%
% See also: exploreFNIRS.connectivity.computeMatrix,
%   exploreFNIRS.graph.computeMetrics, exploreFNIRS.graph.degree

    p = inputParser;
    addRequired(p, 'input');
    addParameter(p, 'Method', 'absolute', ...
        @(x) ischar(x) && ismember(lower(x), {'absolute','proportional','significance'}));
    addParameter(p, 'Value', 0.3, @(x) isnumeric(x) && isscalar(x));
    addParameter(p, 'Binarize', false, @islogical);
    addParameter(p, 'AbsoluteWeight', true, @islogical);
    addParameter(p, 'ZeroDiagonal', true, @islogical);
    parse(p, input, varargin{:});
    opts = p.Results;
    threshMethod = lower(opts.Method);

    % Extract matrix and metadata from input
    [W, pmat, channels, labels, srcMeta, isDir] = parseInput(input);
    N = size(W, 1);

    % Take absolute values of weights if requested
    if opts.AbsoluteWeight
        W = abs(W);
    end

    % Zero diagonal
    if opts.ZeroDiagonal
        W(1:N+1:end) = 0;
    end

    % Replace NaN with 0
    W(isnan(W)) = 0;

    % Apply threshold
    switch threshMethod
        case 'absolute'
            mask = abs(W) >= opts.Value;

        case 'proportional'
            frac = opts.Value;
            if frac < 0 || frac > 1
                error('exploreFNIRS:graph:threshold', ...
                    'Proportional threshold must be between 0 and 1, got %.2f', frac);
            end
            % Get all unique edge weights (upper triangle for undirected)
            if isDir
                offDiag = ~eye(N, 'logical');
                edgeWeights = sort(abs(W(offDiag)), 'descend');
            else
                triMask = triu(true(N), 1);
                edgeWeights = sort(abs(W(triMask)), 'descend');
            end
            nEdges = length(edgeWeights);
            nKeep = max(1, round(frac * nEdges));
            if nKeep <= nEdges && nKeep >= 1
                cutoff = edgeWeights(nKeep);
            else
                cutoff = 0;
            end
            mask = abs(W) >= cutoff;

        case 'significance'
            if isempty(pmat)
                error('exploreFNIRS:graph:threshold', ...
                    'Significance thresholding requires p-values (.pmatrix field)');
            end
            mask = pmat < opts.Value & pmat > 0;
    end

    % Zero diagonal in mask
    if opts.ZeroDiagonal
        mask(1:N+1:end) = false;
    end

    % Apply mask
    W(~mask) = 0;

    % Binary adjacency
    A = double(mask);

    % Binarize weights if requested
    if opts.Binarize
        W = A;
    end

    % Compute density
    if isDir
        nPossible = N * (N - 1);
    else
        nPossible = N * (N - 1) / 2;
    end
    if nPossible > 0
        nEdges = nnz(A);
        if ~isDir
            nEdges = nEdges / 2;  % each edge counted twice
        end
        density = nEdges / nPossible;
    else
        density = 0;
    end

    % Build output struct
    G.W = W;
    G.A = A;
    G.N = N;
    G.channels = channels;
    G.labels = labels;
    G.directed = isDir;
    G.method = threshMethod;
    G.threshold = opts.Value;
    G.binarized = opts.Binarize;
    G.density = density;
    G.source = srcMeta;
end


function [W, pmat, channels, labels, srcMeta, isDirected] = parseInput(input)
% Parse various input formats into a consistent representation

    pmat = [];
    channels = [];
    labels = {};
    srcMeta = struct();
    isDirected = false;

    if isnumeric(input)
        % Raw matrix
        W = double(input);
        N = size(W, 1);
        channels = 1:N;
        labels = arrayfun(@(c) sprintf('Ch%d', c), 1:N, 'UniformOutput', false);
        isDirected = checkDirected(W);
    elseif isstruct(input)
        % Normalize group results (.Mean → .matrix)
        if ~isfield(input, 'matrix') && isfield(input, 'Mean')
            input.matrix = input.Mean;
        end

        if isfield(input, 'matrix')
            W = double(input.matrix);
        else
            error('exploreFNIRS:graph:threshold', ...
                'Input struct must have .matrix or .Mean field');
        end

        N = size(W, 1);

        if isfield(input, 'pmatrix') && ~isempty(input.pmatrix)
            pmat = input.pmatrix;
        end
        if isfield(input, 'channels') && ~isempty(input.channels)
            channels = input.channels;
        else
            channels = 1:N;
        end
        if isfield(input, 'labels') && ~isempty(input.labels)
            labels = input.labels;
        else
            labels = arrayfun(@(c) sprintf('Ch%d', c), channels, ...
                'UniformOutput', false);
        end

        % Source metadata
        if isfield(input, 'method')
            srcMeta.method = input.method;
        end
        if isfield(input, 'biomarker')
            srcMeta.biomarker = input.biomarker;
        end

        % Detect directed by asymmetry
        isDirected = checkDirected(W);
    else
        error('exploreFNIRS:graph:threshold', ...
            'Input must be a numeric matrix or connectivity result struct');
    end

    if size(W, 1) ~= size(W, 2)
        error('exploreFNIRS:graph:threshold', ...
            'Input matrix must be square, got [%d x %d]', size(W, 1), size(W, 2));
    end
end


function tf = checkDirected(W)
% Check if matrix is directed (asymmetric)
    W_clean = W;
    W_clean(isnan(W_clean)) = 0;
    tf = ~isequal(W_clean, W_clean');
end
