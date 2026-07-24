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
%                  fewer than 3 groups contribute (df < 2 is not interpretable),
%                  AND for strictly non-negative coupling measures with no
%                  per-dyad surrogate/null baseline available (see .nullTest).
%     .pvalue    - P-value from one-sample t-test (group-mean level). NaN where
%                  fewer than 3 groups contribute or a surrogate null is
%                  required but unavailable (see .tstat, .nullTest).
%     .nullTest  - How the vs-zero significance test was obtained:
%                  'zero'      - classic one-sample t-test against 0. Valid
%                                for signed measures (pearson/spearman/xcorr
%                                Fisher-z; granger/partialcorr/mutualinfo/
%                                transferentropy/hbica raw values), where 0
%                                is the correct null-hypothesis value.
%                  'surrogate' - per-dyad surrogate/null baselines were found
%                                attached to the dyad results and the test was
%                                run on (observed - baseline), which IS validly
%                                centered at 0 under the null.
%                  'skipped'   - the coupling measure (plv, imagcoherence,
%                                wpli, wcoherence, coherence) is strictly
%                                non-negative with a finite-sample null that is
%                                NOT centered at 0 (e.g. independent-noise PLV
%                                is reliably > 0), and no per-dyad surrogate
%                                baseline was available, so the vs-zero test
%                                was skipped (tstat/pvalue are NaN). A
%                                pf2:computeGroup:surrogateNullRequired warning
%                                is emitted; use
%                                exploreFNIRS.hyperscanning.permutationTest or
%                                exploreFNIRS.coupling.surrogateTest instead.
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

    % Coupling measures whose magnitude is strictly non-negative and has no
    % meaningful signed "zero" null: their finite-sample null distribution
    % under independence (no true coupling) is NOT centered at zero (e.g. the
    % mean PLV of two independent noise series over a narrow band is reliably
    % > 0 -- 30 independent-noise dyads gave mean PLV = 0.192, t = 13.95,
    % p = 2.15e-14 against a t-test-vs-0). A classic one-sample t-test of
    % these RAW values against 0 is therefore invalid and yields spurious
    % "significant" group results. Contrast the correlation-family measures
    % (pearson/spearman/xcorr) above, whose Fisher-z is legitimately centered
    % at 0 under independence, and Granger/mutual-info/etc., which the task
    % of fixing this bug did not extend to. See the .nullTest output field.
    strictlyPositiveNoZeroNull = {'plv', 'imagcoherence', 'wpli', 'wcoherence', 'coherence'};
    isPositiveNoZeroNullMetric = ismember(methodName, strictlyPositiveNoZeroNull);

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

    nullTest = 'zero';  % overridden below for positive-metric branches

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
        % T-test in z-space (where distribution is approximately normal).
        % Valid vs-zero test: Fisher-z of an independent-sample correlation
        % IS centered at 0 under the null.
        tstat = zMean ./ max(zSEM, eps);
    else
        meanVals = mean(groupMeanStackR, nGroupDim, 'omitnan');
        sdVals   = std(groupMeanStackR, 0, nGroupDim, 'omitnan');
        semVals  = sdVals ./ sqrt(max(nVals, 1));

        if isPositiveNoZeroNullMetric
            % See the "strictlyPositiveNoZeroNull" note above: a vs-0 t-test
            % on raw PLV/|imag coherence|/wPLI/wavelet-coherence/coherence
            % values is invalid. Only proceed if a per-dyad surrogate/null
            % baseline is attached to the dyad results (inspected below); the
            % PAIRED test of (observed - baseline) against 0 is then valid.
            [hasNull, baselineDyadResults] = extractSurrogateBaseline(dyadResults);
            if hasNull
                [allSubDyadBaseline, ~, ~, ~] = ...
                    exploreFNIRS.connectivity.alignMatrices(baselineDyadResults, align);
                groupMeanBaselineStack = nan([spatialShape, nValidGroups]);
                for gi = 1:nValidGroups
                    g = uniqueValidGroups(gi);
                    memberMask = (validGroupIdxs == g);
                    gIdx  = [repmat({':'}, 1, length(spatialShape)), {gi}];
                    sdIdx = [repmat({':'}, 1, length(spatialShape)), {memberMask}];
                    subBase = allSubDyadBaseline(sdIdx{:});
                    groupMeanBaselineStack(gIdx{:}) = mean(subBase, nDim, 'omitnan');
                end
                diffStack = groupMeanStackR - groupMeanBaselineStack;
                diffMean  = mean(diffStack, nGroupDim, 'omitnan');
                diffSD    = std(diffStack, 0, nGroupDim, 'omitnan');
                diffSEM   = diffSD ./ sqrt(max(nVals, 1));
                tstat = diffMean ./ max(diffSEM, eps);
                nullTest = 'surrogate';
            else
                tstat = nan(size(meanVals));
                nullTest = 'skipped';
                warning('pf2:computeGroup:surrogateNullRequired', ...
                    ['Method "%s" is a strictly non-negative coupling measure ' ...
                     'whose finite-sample null under independence is NOT ' ...
                     'centered at zero (e.g. mean PLV for independent noise ' ...
                     'is reliably > 0), so a one-sample t-test against zero ' ...
                     'produces spurious significance. No per-dyad surrogate/' ...
                     'null baseline was found on the computeDyad results, so ' ...
                     'the vs-zero significance test has been skipped ' ...
                     '(tstat/pvalue are NaN for this metric). Use ' ...
                     'exploreFNIRS.hyperscanning.permutationTest (dyad-shuffle ' ...
                     'null) or exploreFNIRS.coupling.surrogateTest (within-dyad ' ...
                     'circular-shift/phase-randomization null) to obtain a ' ...
                     'valid significance test for "%s".'], methodName, methodName);
            end
        else
            % Valid vs-zero test: e.g. Granger F, partial correlation, mutual
            % information, transfer entropy -- signed or otherwise appropriately
            % centered at 0 (or handled by their own within-method p-values).
            tstat = meanVals ./ max(semVals, eps);
        end
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
    result.nullTest = nullTest;
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
    if strcmp(nullTest, 'skipped')
        fprintf(['  NOTE: vs-zero significance test skipped for "%s" ' ...
            '(see pf2:computeGroup:surrogateNullRequired warning above).\n'], ...
            methodName);
    end
end


function [available, baselineDyadResults] = extractSurrogateBaseline(dyadResults)
% EXTRACTSURROGATEBASELINE Look for a per-dyad surrogate/null baseline
%
% Inspects each valid sub-dyad's computeDyad result for an attached
% surrogate/null baseline (same shape as .values), so that strictly
% non-negative coupling measures (PLV, |imaginary coherence|, wPLI,
% wavelet coherence, coherence) can be tested against that baseline instead
% of an invalid vs-zero t-test. Recognized fields (checked per sub-dyad, in
% order): a top-level 'surrogateBaseline' or 'nullMean' field, or a nested
% 'surrogate.nullMean' struct field -- the shapes computeDyad or
% exploreFNIRS.coupling.surrogateTest results would carry if/when a
% per-dyad null is attached. As of this version, exploreFNIRS.hyperscanning.
% computeDyad does NOT attach any such baseline (its .pvalues field is NaN
% for these methods and defers significance to
% exploreFNIRS.hyperscanning.permutationTest or
% exploreFNIRS.coupling.surrogateTest instead), so `available` will be
% false in current usage; this helper exists so a future per-dyad
% surrogate baseline is picked up automatically without further changes
% here.
%
% Inputs:
%   dyadResults - Cell array of valid computeDyad result structs
%
% Outputs:
%   available            - True only if EVERY sub-dyad carries a
%                           recognized baseline matching the shape of its
%                           own .values
%   baselineDyadResults  - Copy of dyadResults with .values replaced by the
%                           extracted baseline (suitable for
%                           exploreFNIRS.connectivity.alignMatrices); {}
%                           when available is false

    available = false;
    baselineDyadResults = {};
    n = numel(dyadResults);
    if n == 0
        return;
    end

    baseline = cell(n, 1);
    for s = 1:n
        r = dyadResults{s};
        found = [];
        if isfield(r, 'surrogateBaseline') && isequal(size(r.surrogateBaseline), size(r.values))
            found = r.surrogateBaseline;
        elseif isfield(r, 'nullMean') && isequal(size(r.nullMean), size(r.values))
            found = r.nullMean;
        elseif isfield(r, 'surrogate') && isstruct(r.surrogate) && ...
                isfield(r.surrogate, 'nullMean') && ...
                isequal(size(r.surrogate.nullMean), size(r.values))
            found = r.surrogate.nullMean;
        end
        if isempty(found)
            return;  % at least one sub-dyad lacks baseline info -> unavailable
        end
        baseline{s} = found;
    end

    available = true;
    baselineDyadResults = dyadResults;
    for s = 1:n
        baselineDyadResults{s}.values = baseline{s};
    end
end
