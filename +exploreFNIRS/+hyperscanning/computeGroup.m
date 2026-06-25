function result = computeGroup(data, pairs, varargin)
% COMPUTEGROUP Aggregate inter-brain coupling across dyads or N-person groups
%
% Iterates over paired subjects from pairSubjects, computes pairwise dyad-
% level coupling for all within-group subject pairs, and aggregates into
% group-level statistics (Mean, SD, SEM, N) with one-sample t-tests against
% zero.
%
% For groups with more than 2 members (triads, etc.) each group of m members
% is expanded into nchoosek(m,2) pairwise sub-dyads. Because within-group
% sub-dyads share members they are NOT independent observations. To preserve
% statistical honesty, the function first averages sub-dyad values within each
% parent group (Fisher-z domain for correlation methods), then runs statistics
% across independent groups. N in the output therefore reflects the number of
% independent groups, not sub-dyads.
%
% For classic 2-member dyads the behavior is identical to the previous version:
% one sub-dyad per group, N = number of dyads.
%
% Uses alignMatrices to handle groups/dyads with different valid channels,
% ensuring channel identity is preserved during group aggregation.
%
% Syntax:
%   result = exploreFNIRS.hyperscanning.computeGroup(data, pairs)
%   result = exploreFNIRS.hyperscanning.computeGroup(data, pairs, ...
%       'Method', 'pearson', 'Biomarker', 'HbO')
%   result = exploreFNIRS.hyperscanning.computeGroup(data, pairs, ...
%       'Align', 'intersection')
%
% Inputs:
%   data  - Cell array of processed fNIRS structs
%   pairs - Struct array from pairSubjects (with .indices, .dyadID, etc.)
%           .indices may have length 2 (dyad) or >= 3 (triad/N-group).
%
% Name-Value Parameters:
%   Align - Channel alignment mode for group aggregation:
%           'union' (default) - all channels, NaN where missing
%           'intersection' - only channels in all dyads
%           numeric 0-1 - channels in >= threshold fraction of dyads
%   All parameters from computeDyad are supported (Method, Biomarker,
%   ChannelPairing, Channels, TimeWindow, CouplingArgs).
%
% Outputs:
%   result - Struct with fields:
%     .Mean      - Mean coupling across groups [same shape as dyad values]
%     .SD        - Standard deviation across group means
%     .SEM       - Standard error of the mean
%     .N         - Number of independent groups contributing each element
%     .nValid    - Per-cell count of non-NaN values (group-mean level)
%     .tstat     - One-sample t-statistic vs 0 (group-mean level). NaN where
%                  fewer than 3 groups contribute (df < 2 is not interpretable).
%     .pvalue    - P-value from one-sample t-test (group-mean level). NaN where
%                  fewer than 3 groups contribute (see .tstat).
%     .dyads     - Cell array of individual sub-dyad results
%     .dyadIDs   - Cell array of sub-dyad ID strings
%     .groupIDs  - Cell array of parent group ID strings (one per pairs entry)
%     .groupMeans - [nGroups x 1] scalar per-group mean coupling
%     .method    - Coupling method used
%     .biomarker - Biomarker used
%     .pairing   - Channel pairing mode
%     .channels  - Channels used (master channel set)
%
% Example:
%   % Dyad (2-member) case — behavior unchanged
%   pairs = exploreFNIRS.hyperscanning.pairSubjects(data);
%   result = exploreFNIRS.hyperscanning.computeGroup(data, pairs, ...
%       'Method', 'pearson', 'Biomarker', 'HbO');
%   fprintf('Mean coupling: %.3f (p = %.4f)\n', ...
%       mean(result.Mean, 'omitnan'), mean(result.pvalue, 'omitnan'));
%
%   % Triad (3-member) case
%   pairs = exploreFNIRS.hyperscanning.pairSubjects(triadData, 'GroupSize', 3);
%   result = exploreFNIRS.hyperscanning.computeGroup(triadData, pairs, ...
%       'Method', 'pearson', 'Biomarker', 'HbO');
%   fprintf('N groups = %d, N sub-dyads = %d\n', ...
%       length(result.groupIDs), length(result.dyadIDs));
%
% References:
%   Czeszumski, A., Ebers, S., Greshake Tzovaras, B., Gianotti, L. R. R.,
%   Kosonogov, V., et al. (2020). Hyperscanning: A Valid Method to Study
%   Neural Inter-brain Underpinnings of Social Interaction. Frontiers in
%   Human Neuroscience, 14, 39. DOI: 10.3389/fnhum.2020.00039
%
%   Silver, D. L. (1998). Fisher z-transformation. In Encyclopedia of
%   Biostatistics (pp. 1544-1545). Wiley.
%
% See also: exploreFNIRS.hyperscanning.pairSubjects,
%   exploreFNIRS.hyperscanning.computeDyad,
%   exploreFNIRS.connectivity.alignMatrices

    % Extract Align parameter before forwarding rest to computeDyad
    align = 'union';
    dyadArgs = {};
    k = 1;
    while k <= length(varargin)
        if ischar(varargin{k}) && strcmpi(varargin{k}, 'Align')
            align = varargin{k+1};
            k = k + 2;
        else
            dyadArgs = [dyadArgs, varargin(k)]; %#ok<AGROW>
            k = k + 1;
        end
    end

    nGroups = length(pairs);
    if nGroups == 0
        error('exploreFNIRS:hyperscanning:computeGroup', 'No pairs provided');
    end

    % Determine method name early (needed for Fisher-z decision in aggregation)
    methodName = 'pearson';
    for k2 = 1:2:length(dyadArgs)
        if ischar(dyadArgs{k2}) && strcmpi(dyadArgs{k2}, 'Method')
            methodName = lower(dyadArgs{k2+1});
            break;
        end
    end
    useFisherZ = ismember(methodName, {'pearson', 'spearman', 'xcorr'});

    % -----------------------------------------------------------------------
    % Expand each group into pairwise sub-dyads
    % -----------------------------------------------------------------------
    % subDyads(s).idxA, .idxB  : indices into data cell array
    % subDyads(s).dyadID        : label string, e.g. 'Triad01_AB'
    % subDyads(s).groupIdx      : index into pairs (parent group)
    % groupIDs{g}               : parent group ID string

    subDyads = struct('idxA', {}, 'idxB', {}, 'dyadID', {}, 'groupIdx', {});
    groupIDs = cell(nGroups, 1);

    for g = 1:nGroups
        indices = pairs(g).indices(:)';  % row vector of data indices
        m = length(indices);
        groupIDs{g} = pairs(g).dyadID;

        if m == 2
            % Classic dyad: single sub-dyad, ID unchanged
            s = length(subDyads) + 1;
            subDyads(s).idxA     = indices(1);
            subDyads(s).idxB     = indices(2);
            subDyads(s).dyadID   = pairs(g).dyadID;
            subDyads(s).groupIdx = g;
        else
            % N-person group: expand to nchoosek(m,2) sub-dyads
            % Assign role labels A=1st member, B=2nd, C=3rd, ...
            roleLetters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
            combos = nchoosek(1:m, 2);  % [nchoosek(m,2) x 2] index pairs
            for c = 1:size(combos, 1)
                iA = combos(c, 1);
                iB = combos(c, 2);
                labelA = roleLetters(iA);
                labelB = roleLetters(iB);
                s = length(subDyads) + 1;
                subDyads(s).idxA   = indices(iA);
                subDyads(s).idxB   = indices(iB);
                subDyads(s).dyadID = sprintf('%s_%s%s', pairs(g).dyadID, labelA, labelB);
                subDyads(s).groupIdx = g;
            end
        end
    end

    nSubDyads = length(subDyads);

    % Announce group/sub-dyad structure
    hasTriads = any(arrayfun(@(g) length(pairs(g).indices) > 2, 1:nGroups));
    if hasTriads
        fprintf('Computing %d sub-dyads from %d groups (triad/N-group mode).\n', ...
            nSubDyads, nGroups);
        fprintf('  Statistical inference will use N = %d independent groups.\n', nGroups);
    else
        fprintf('Computing %d dyads...\n', nSubDyads);
    end

    % -----------------------------------------------------------------------
    % Compute each sub-dyad
    % -----------------------------------------------------------------------
    dyadResults = cell(nSubDyads, 1);
    dyadIDs = cell(nSubDyads, 1);
    validDyads = true(nSubDyads, 1);

    for s = 1:nSubDyads
        dyadIDs{s} = subDyads(s).dyadID;
    end

    % Pre-extract indices for parfor compatibility (fixed-size matrix approach
    % cannot be used for variable group sizes, so use simple arrays)
    sdIdxA = zeros(nSubDyads, 1);
    sdIdxB = zeros(nSubDyads, 1);
    for s = 1:nSubDyads
        sdIdxA(s) = subDyads(s).idxA;
        sdIdxB(s) = subDyads(s).idxB;
    end

    % Determine whether to use parfor
    useParfor = false;
    if nSubDyads > 2
        [canUse, poolRunning] = pf2_base.accel.canParfor();
        useParfor = canUse && poolRunning;
    end

    if useParfor
        fprintf('  Running %d sub-dyad computations (parallel)...\n', nSubDyads);
        parfor s = 1:nSubDyads
            try
                dyadResults{s} = exploreFNIRS.hyperscanning.computeDyad( ...
                    data{sdIdxA(s)}, data{sdIdxB(s)}, dyadArgs{:});
            catch
                validDyads(s) = false;
            end
        end
        % Print summary after parallel completion
        for s = 1:nSubDyads
            if validDyads(s)
                fprintf('  [%d/%d] %s: mean r = %.3f\n', s, nSubDyads, dyadIDs{s}, ...
                    mean(dyadResults{s}.values(:), 'omitnan'));
            else
                warning('pf2:hyperscanning:dyadFailed', ...
                    'Sub-dyad [%d/%d] %s: FAILED', s, nSubDyads, dyadIDs{s});
            end
        end
    else
        for s = 1:nSubDyads
            try
                dyadResults{s} = exploreFNIRS.hyperscanning.computeDyad( ...
                    data{sdIdxA(s)}, data{sdIdxB(s)}, dyadArgs{:});
                fprintf('  [%d/%d] %s: mean r = %.3f\n', s, nSubDyads, dyadIDs{s}, ...
                    mean(dyadResults{s}.values(:), 'omitnan'));
            catch ME
                warning('exploreFNIRS:hyperscanning:computeGroup', ...
                    'Sub-dyad "%s" failed: %s', dyadIDs{s}, ME.message);
                validDyads(s) = false;
            end
        end
    end

    dyadResults = dyadResults(validDyads);
    dyadIDs = dyadIDs(validDyads);
    validSubDyads = subDyads(validDyads);
    nValidSubDyads = sum(validDyads);

    if nValidSubDyads == 0
        error('exploreFNIRS:hyperscanning:computeGroup', 'All sub-dyads failed');
    end

    % -----------------------------------------------------------------------
    % Align sub-dyad values onto a common channel grid
    % -----------------------------------------------------------------------
    [allSubDyadValues, masterCh, ~, ~] = ...
        exploreFNIRS.connectivity.alignMatrices(dyadResults, align);

    % Shape: [M x 1 x nValidSubDyads] for 'same', [Ma x Mb x nValidSubDyads] for 'all'
    valShape = size(allSubDyadValues);  % e.g. [M 1 nSub] or [Ma Mb nSub]
    % Use explicit dimension count rather than ndims() to avoid MATLAB's
    % trailing-singleton collapsing (e.g. ndims(nan(M,M,1)) == 2, not 3).
    nDim = length(valShape);  % sub-dyad dimension is last

    % -----------------------------------------------------------------------
    % Per-group aggregation: average within-group sub-dyads (Fisher-z domain)
    % then use per-group means for inference — preserving independence.
    % -----------------------------------------------------------------------
    % Map valid sub-dyads back to their parent group
    validGroupIdxs = [validSubDyads.groupIdx];  % [1 x nValidSubDyads]

    % Find which groups have at least one valid sub-dyad
    uniqueValidGroups = unique(validGroupIdxs, 'stable');
    nValidGroups = length(uniqueValidGroups);

    % Stack shape: spatialShape x nValidGroups.
    % The group dimension is always dimension length(spatialShape)+1. Use that
    % explicitly to avoid ndims() trailing-singleton collapsing (e.g.
    % ndims(nan(M,M,1)) == 2 in MATLAB, not 3).
    spatialShape = valShape(1:end-1);   % e.g. [M 1] or [Ma Mb]
    nGroupDim = length(spatialShape) + 1;  % explicit group dimension index
    groupMeanStackZ = nan([spatialShape, nValidGroups]);  % z-space (or raw)

    for gi = 1:nValidGroups
        g = uniqueValidGroups(gi);
        % Find sub-dyad indices (in the valid list) that belong to this group
        memberMask = (validGroupIdxs == g);
        memberCount = sum(memberMask);

        % Build index expressions: spatially colon-indexed, group dimension gi
        % or logical mask. Using subsref-style index cell for n-D compatibility.
        sdIdx = [repmat({':'}, 1, length(spatialShape)), {memberMask}];
        gIdx  = [repmat({':'}, 1, length(spatialShape)), {gi}];

        if memberCount == 1
            % Single sub-dyad (standard dyad): no within-group averaging needed
            sdSingleIdx = [repmat({':'}, 1, length(spatialShape)), {find(memberMask,1)}];
            if useFisherZ
                groupMeanStackZ(gIdx{:}) = ...
                    atanh(max(min(allSubDyadValues(sdSingleIdx{:}), 0.9999), -0.9999));
            else
                groupMeanStackZ(gIdx{:}) = allSubDyadValues(sdSingleIdx{:});
            end
        else
            % Multiple sub-dyads: aggregate in Fisher-z domain for correlations
            subVals = allSubDyadValues(sdIdx{:});  % [..., memberCount]
            if useFisherZ
                zSub = atanh(max(min(subVals, 0.9999), -0.9999));
                groupMeanStackZ(gIdx{:}) = mean(zSub, nDim, 'omitnan');
            else
                groupMeanStackZ(gIdx{:}) = mean(subVals, nDim, 'omitnan');
            end
        end
    end

    % groupMeanStackZ is in Fisher-z space (for correlation methods) or raw
    % values (for non-correlation methods). Compute r-space for output.
    if useFisherZ
        groupMeanStackR = tanh(groupMeanStackZ);  % r-space for output
    else
        groupMeanStackR = groupMeanStackZ;
    end

    % -----------------------------------------------------------------------
    % Group-level statistics (across independent group means)
    % -----------------------------------------------------------------------
    nGroupsForInference = nValidGroups;

    nVals = sum(~isnan(groupMeanStackR), nGroupDim);

    if useFisherZ
        % groupMeanStackZ holds within-group Fisher-z means; run group
        % statistics in z-space (approximately Gaussian), then back-transform.
        zMean = mean(groupMeanStackZ, nGroupDim, 'omitnan');
        zSD   = std(groupMeanStackZ, 0, nGroupDim, 'omitnan');
        zSEM  = zSD ./ sqrt(max(nVals, 1));
        meanVals = tanh(zMean);
        % Back-transform SD/SEM to original scale (delta method approximation)
        sdVals  = zSD  .* (1 - meanVals.^2);
        semVals = zSEM .* (1 - meanVals.^2);
        % T-test in z-space (where distribution is approximately normal)
        tstat = zMean ./ max(zSEM, eps);
    else
        meanVals = mean(groupMeanStackR, nGroupDim, 'omitnan');
        sdVals   = std(groupMeanStackR, 0, nGroupDim, 'omitnan');
        semVals  = sdVals ./ sqrt(max(nVals, 1));
        tstat = meanVals ./ max(semVals, eps);
    end

    df = max(nVals - 1, 1);
    pvalue = 2 * (1 - pf2_base.compat.tcdf(abs(tstat), df));
    % A one-sample t needs df >= 2 (>= 3 groups) to be meaningful; with only 1-2
    % groups the df=1 p-value is degenerate (nearly useless dispersion). NaN both
    % the statistic and its p-value so a t(1) is never reported as if it carried
    % inferential weight. Mean/SD/SEM for small studies are still returned,
    % governed by the `tooFew` display threshold below.
    degenerate = nVals < 3;
    tstat(degenerate)  = NaN;
    pvalue(degenerate) = NaN;

    % Suppress cells seen in fewer groups than the rest. Three independent
    % groups is the target for stable group statistics, but the threshold is
    % clamped to the number actually available so small studies (1-2 groups)
    % still return a Mean; their pvalue is NaN'd below (nVals < 2) and the
    % "exploratory only" note is printed for fewer than 3 groups.
    minGroups = min(3, max(nVals(:)));
    tooFew = nVals < minGroups;
    meanVals(tooFew) = NaN;
    sdVals(tooFew)   = NaN;
    semVals(tooFew)  = NaN;
    tstat(tooFew)    = NaN;
    pvalue(tooFew)   = NaN;

    result.Mean    = squeeze(meanVals);
    result.SD      = squeeze(sdVals);
    result.SEM     = squeeze(semVals);
    result.N       = squeeze(nVals);
    result.nValid  = squeeze(nVals);   % group-level count (matches N; documented)
    result.tstat   = squeeze(tstat);
    result.pvalue  = squeeze(pvalue);
    result.dyads   = dyadResults;
    result.dyadIDs = dyadIDs;

    % Group-level metadata
    result.groupIDs = groupIDs(uniqueValidGroups);
    % Per-group scalar mean coupling (mean over spatial elements, r-space)
    result.groupMeans = zeros(nValidGroups, 1);
    for gi = 1:nValidGroups
        gIdx = [repmat({':'}, 1, length(spatialShape)), {gi}];
        slice = groupMeanStackR(gIdx{:});
        result.groupMeans(gi) = mean(slice(:), 'omitnan');
    end

    % Retain legacy dyadMeans field for backward compatibility (equals groupMeans)
    result.dyadMeans = result.groupMeans;

    result.method    = dyadResults{1}.method;
    result.biomarker = dyadResults{1}.biomarker;
    result.pairing   = dyadResults{1}.pairing;

    % Use master channels from alignment
    if iscell(masterCh)
        result.channels  = masterCh{1};
        result.channelsB = masterCh{2};
    else
        result.channels = masterCh;
    end

    % Report group-level summary
    fprintf('Group result: %d valid groups (%d sub-dyads total), ', ...
        nValidGroups, nValidSubDyads);
    fprintf('mean coupling = %.3f (group-mean level), median = %.3f\n', ...
        mean(result.groupMeans, 'omitnan'), median(result.groupMeans, 'omitnan'));
    if nGroupsForInference < 3
        fprintf(['  NOTE: Only %d independent groups for inference. ', ...
            'Statistics are exploratory only.\n'], nGroupsForInference);
    end
end
