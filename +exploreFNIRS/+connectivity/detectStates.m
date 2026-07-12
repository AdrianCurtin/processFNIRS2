function states = detectStates(dynamicResult, varargin)
% DETECTSTATES K-means clustering of dynamic connectivity states
%
% Identifies recurring connectivity patterns (states) from a time series
% of connectivity matrices produced by computeDynamicFC. Each time window
% is assigned to its nearest centroid state.
%
% Syntax:
%   states = exploreFNIRS.connectivity.detectStates(dynamicResult)
%   states = exploreFNIRS.connectivity.detectStates(dynamicResult, 'K', 4)
%   states = exploreFNIRS.connectivity.detectStates(dynamicResult, ...
%       'Replicates', 20, 'Distance', 'sqeuclidean')
%
% Inputs:
%   dynamicResult - Output from computeDynamicFC with:
%                   .matrices [C x C x W], .windowTimes [W x 1]
%
% Name-Value Parameters:
%   K          - Number of states (default: 3)
%   Replicates - Number of k-means replicates (default: 10)
%   Distance   - Distance metric for kmeans: 'correlation' (default),
%                'sqeuclidean', 'cityblock', 'cosine'
%
% Outputs:
%   states - Struct with fields:
%     .assignments      - [W x 1] state label per window (1..K)
%     .centroidMatrices - {1 x K} cell array, each [C x C] centroid matrix
%     .silhouette       - [W x 1] silhouette values per window
%     .K                - Number of states used
%     .centroids        - [K x features] raw centroid vectors
%     .windowTimes      - [W x 1] center times from dynamicResult
%
% Example:
%   dfc = exploreFNIRS.connectivity.computeDynamicFC(processed);
%   states = exploreFNIRS.connectivity.detectStates(dfc, 'K', 3);
%   disp(states.assignments');
%
% References:
%   Allen, E. A., Damaraju, E., Plis, S. M., Erhardt, E. B., Eichele, T.
%   & Calhoun, V. D. (2014). Tracking whole-brain connectivity dynamics in
%   the resting state. Cerebral Cortex, 24(3), 663-676.
%   DOI: 10.1093/cercor/bhs352
%
% See also: exploreFNIRS.connectivity.computeDynamicFC,
%   exploreFNIRS.connectivity.plotDynamicFC

    p = inputParser;
    addRequired(p, 'dynamicResult', @isstruct);
    addParameter(p, 'K', 3, @(v) isnumeric(v) && isscalar(v) && v >= 2);
    addParameter(p, 'Replicates', 10, @(v) isnumeric(v) && isscalar(v) && v >= 1);
    addParameter(p, 'Distance', 'correlation', @ischar);
    parse(p, dynamicResult, varargin{:});
    opts = p.Results;

    matrices = dynamicResult.matrices;  % [C x C x W]
    [nCh, ~, nWin] = size(matrices);

    if nWin < opts.K
        error('exploreFNIRS:connectivity:detectStates', ...
            'Number of windows (%d) must be >= K (%d)', nWin, opts.K);
    end

    % Check if matrices are asymmetric (directed method)
    testMat = matrices(:, :, 1);
    isAsymmetric = any(abs(testMat - testMat') > 1e-10, 'all');

    if isAsymmetric
        % Directed methods: use full matrix excluding diagonal
        triMask = ~eye(nCh, 'logical');
    else
        % Symmetric: use upper triangle only
        triMask = triu(true(nCh), 1);
    end
    nFeatures = sum(triMask(:));
    features = zeros(nWin, nFeatures);

    for w = 1:nWin
        mat = matrices(:, :, w);
        features(w, :) = mat(triMask)';
    end

    % Replace NaN features with 0 for clustering
    features(isnan(features)) = 0;

    % Run k-means
    [assignments, centroids] = kmeans(features, opts.K, ...
        'Replicates', opts.Replicates, ...
        'Distance', opts.Distance, ...
        'MaxIter', 500);

    % Compute silhouette values
    silVals = silhouette(features, assignments, opts.Distance);

    % Reconstruct centroid matrices
    centroidMatrices = cell(1, opts.K);
    for k = 1:opts.K
        if isAsymmetric
            % Directed: assign off-diagonal directly, diagonal = 0
            mat = zeros(nCh);
            mat(triMask) = centroids(k, :);
        else
            % Symmetric: fill upper triangle and mirror to lower
            mat = nan(nCh);
            mat(triMask) = centroids(k, :);
            mat = mat';
            mat(triMask) = centroids(k, :);
            mat = mat';
            for c = 1:nCh
                mat(c, c) = 1;
            end
        end
        centroidMatrices{k} = mat;
    end

    states.assignments = assignments;
    states.centroidMatrices = centroidMatrices;
    states.silhouette = silVals;
    states.K = opts.K;
    states.centroids = centroids;
    states.windowTimes = dynamicResult.windowTimes;
end
