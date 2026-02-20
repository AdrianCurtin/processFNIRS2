function result = permutationTest(data, pairs, varargin)
% PERMUTATIONTEST Surrogate significance test for hyperscanning coupling
%
% Shuffles dyad pairings (pairing A1 with B2 instead of B1) to build a
% null distribution of coupling values under the hypothesis that
% inter-brain synchrony is spurious. Compares observed coupling against
% the null to derive permutation p-values. Uses FDR correction for
% multi-channel testing.
%
% Syntax:
%   result = exploreFNIRS.hyperscanning.permutationTest(data, pairs)
%   result = exploreFNIRS.hyperscanning.permutationTest(data, pairs, ...
%       'Permutations', 1000, 'PThreshold', 0.05, 'Method', 'pearson')
%
% Inputs:
%   data  - Cell array of processed fNIRS structs
%   pairs - Struct array from pairSubjects (with .indices)
%
% Name-Value Parameters:
%   Permutations - Number of permutations (default: 500)
%   PThreshold   - Significance threshold for FDR correction (default: 0.05)
%   Align        - Channel alignment mode for group aggregation (default: 'union')
%   All computeDyad parameters are also supported (Method, Biomarker,
%   ChannelPairing, Channels, TimeWindow, CouplingArgs).
%
% Outputs:
%   result - Struct with fields:
%     .observed    - Observed group mean coupling (from real pairings)
%     .nullDist    - [nPerms x nElements] null distribution
%     .nullMean    - Mean of null distribution
%     .nullSD      - SD of null distribution
%     .pvalue      - Permutation p-values (proportion of null >= observed)
%     .pvalueFDR   - FDR-corrected p-values
%     .significant - Logical mask of significant elements (after FDR)
%     .nPerms      - Number of permutations completed
%     .zScore      - Z-score of observed vs null
%
% Algorithm:
%   For each permutation:
%     1. Randomly re-pair subjects (shuffle which B goes with which A)
%     2. Compute group mean coupling with shuffled pairs
%     3. Store in null distribution
%   P-value = (# null >= observed + 1) / (nPerms + 1)
%
% References:
%   Phipson, B. & Smyth, G. K. (2010). Permutation P-values should never
%   be zero: calculating exact P-values when permutations are randomly
%   drawn. Statistical Applications in Genetics and Molecular Biology,
%   9(1), Article 39. DOI: 10.2202/1544-6115.1585
%
%   Benjamini, Y. & Hochberg, Y. (1995). Controlling the false discovery
%   rate: a practical and powerful approach to multiple testing. Journal of
%   the Royal Statistical Society, Series B, 57(1), 289-300.
%
% See also: exploreFNIRS.hyperscanning.computeGroup, exploreFNIRS.fx.performFDR

    ip = inputParser;
    addRequired(ip, 'data', @iscell);
    addRequired(ip, 'pairs', @isstruct);
    addParameter(ip, 'Permutations', 500, @(v) isnumeric(v) && isscalar(v) && v > 0);
    addParameter(ip, 'PThreshold', 0.05, @isnumeric);
    % Pass-through params for computeDyad
    addParameter(ip, 'Method', 'pearson', @ischar);
    addParameter(ip, 'Biomarker', 'HbO', @ischar);
    addParameter(ip, 'ChannelPairing', 'same', @ischar);
    addParameter(ip, 'Channels', [], @isnumeric);
    addParameter(ip, 'TimeWindow', [], @(v) isnumeric(v) && (isempty(v) || length(v) == 2));
    addParameter(ip, 'CouplingArgs', {}, @iscell);
    addParameter(ip, 'UseROI', false, @islogical);
    addParameter(ip, 'Accelerate', 'auto', @(x) ischar(x) && ismember(lower(x), {'auto','gpu','parfor','none'}));
    addParameter(ip, 'Align', 'union', @(x) (ischar(x) || isstring(x)) || (isnumeric(x) && isscalar(x)));
    parse(ip, data, pairs, varargin{:});
    opts = ip.Results;

    nPerms = opts.Permutations;
    nPairs = length(pairs);

    if nPairs < 2
        error('exploreFNIRS:hyperscanning:permutationTest', ...
            'Need at least 2 dyads for permutation testing (got %d)', nPairs);
    end

    % Build args for computeDyad (exclude permutation-specific params)
    dyadArgs = {'Method', opts.Method, 'Biomarker', opts.Biomarker, ...
        'ChannelPairing', opts.ChannelPairing};
    if ~isempty(opts.Channels)
        dyadArgs = [dyadArgs, 'Channels', opts.Channels];
    end
    if ~isempty(opts.TimeWindow)
        dyadArgs = [dyadArgs, 'TimeWindow', opts.TimeWindow];
    end
    if ~isempty(opts.CouplingArgs)
        dyadArgs = [dyadArgs, 'CouplingArgs', {opts.CouplingArgs}];
    end
    if opts.UseROI
        dyadArgs = [dyadArgs, 'UseROI', true];
    end
    if ~strcmpi(opts.Accelerate, 'auto')
        dyadArgs = [dyadArgs, 'Accelerate', opts.Accelerate];
    end

    % Build align args for computeGroup
    alignArgs = {'Align', opts.Align};

    % Compute observed coupling
    observedGroup = exploreFNIRS.hyperscanning.computeGroup(data, pairs, ...
        alignArgs{:}, dyadArgs{:});
    observed = observedGroup.Mean(:);
    nElements = length(observed);

    % Extract all subject indices by role (column 1 = A, column 2 = B)
    roleA = zeros(nPairs, 1);
    roleB = zeros(nPairs, 1);
    for d = 1:nPairs
        roleA(d) = pairs(d).indices(1);
        roleB(d) = pairs(d).indices(2);
    end

    % Permutation loop
    nullDist = nan(nPerms, nElements);

    % Determine whether to use parfor
    useParfor = false;
    [canUse, poolRunning] = pf2_base.accel.canParfor();
    if canUse && poolRunning && nPerms > 10
        useParfor = true;
    end

    if useParfor
        fprintf('Permutation test (%d permutations, parallel)...\n', nPerms);
        parfor perm = 1:nPerms
            shuffledB = roleB(randperm(nPairs));
            shuffledPairs = pairs;
            for d = 1:nPairs
                shuffledPairs(d).indices = [roleA(d), shuffledB(d)];
            end
            try
                shuffResult = exploreFNIRS.hyperscanning.computeGroup( ...
                    data, shuffledPairs, alignArgs{:}, dyadArgs{:});
                nullDist(perm, :) = shuffResult.Mean(:);
            catch
            end
        end
        fprintf('done.\n');
    else
        fprintf('Permutation test: ');
        for perm = 1:nPerms
            shuffledB = roleB(randperm(nPairs));
            shuffledPairs = pairs;
            for d = 1:nPairs
                shuffledPairs(d).indices = [roleA(d), shuffledB(d)];
            end
            try
                shuffResult = exploreFNIRS.hyperscanning.computeGroup( ...
                    data, shuffledPairs, alignArgs{:}, dyadArgs{:});
                nullDist(perm, :) = shuffResult.Mean(:);
            catch
            end
            if mod(perm, max(1, round(nPerms/10))) == 0
                fprintf('%d%% ', round(perm/nPerms*100));
            end
        end
        fprintf('done.\n');
    end

    % Remove failed permutations
    validPerms = ~all(isnan(nullDist), 2);
    nullDist = nullDist(validPerms, :);
    nValidPerms = size(nullDist, 1);

    % Compute permutation p-values
    % p = (# null >= observed + 1) / (nPerms + 1)
    pvalues = nan(nElements, 1);
    for e = 1:nElements
        if isnan(observed(e))
            continue;
        end
        nExceed = sum(abs(nullDist(:, e)) >= abs(observed(e)));
        pvalues(e) = (nExceed + 1) / (nValidPerms + 1);
    end

    % FDR correction
    validP = ~isnan(pvalues);
    pvalueFDR = nan(size(pvalues));
    significant = false(size(pvalues));
    if any(validP)
        [qvals, ~, passed] = exploreFNIRS.fx.performFDR(pvalues(validP), opts.PThreshold);
        pvalueFDR(validP) = qvals;
        significant(validP) = passed;
    end

    % Z-scores
    nullMean = mean(nullDist, 1, 'omitnan')';
    nullSD = std(nullDist, 0, 1, 'omitnan')';
    zScore = (observed - nullMean) ./ max(nullSD, eps);

    % Reshape back to original shape
    origShape = size(observedGroup.Mean);
    result.observed = reshape(observed, origShape);
    result.nullDist = nullDist;
    result.nullMean = reshape(nullMean, origShape);
    result.nullSD = reshape(nullSD, origShape);
    result.pvalue = reshape(pvalues, origShape);
    result.pvalueFDR = reshape(pvalueFDR, origShape);
    result.significant = reshape(significant, origShape);
    result.nPerms = nValidPerms;
    result.zScore = reshape(zScore, origShape);

    nSig = sum(significant(:));
    fprintf('Permutation test: %d/%d elements significant (FDR q < %.2f)\n', ...
        nSig, sum(~isnan(pvalues)), opts.PThreshold);
end
