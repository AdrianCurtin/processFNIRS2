function result = computeGroup(data, pairs, varargin)
% COMPUTEGROUP Aggregate inter-brain coupling across all dyads
%
% Iterates over paired subjects from pairSubjects, computes dyad-level
% coupling for each pair, and aggregates into group-level statistics
% (Mean, SD, SEM, N) with one-sample t-tests against zero.
%
% Uses alignMatrices to handle dyads with different valid channels,
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
%     .Mean     - Mean coupling across dyads (same shape as dyad values)
%     .SD       - Standard deviation
%     .SEM      - Standard error of the mean
%     .N        - Number of valid dyads per element
%     .nValid   - Per-cell count of non-NaN values
%     .tstat    - One-sample t-statistic (vs 0)
%     .pvalue   - P-value from one-sample t-test
%     .dyads    - Cell array of individual dyad results
%     .dyadIDs  - Cell array of dyad ID strings
%     .method   - Coupling method used
%     .biomarker - Biomarker used
%     .pairing  - Channel pairing mode
%     .channels - Channels used (master channel set)
%
% Example:
%   pairs = exploreFNIRS.hyperscanning.pairSubjects(data);
%   result = exploreFNIRS.hyperscanning.computeGroup(data, pairs, ...
%       'Method', 'pearson', 'Biomarker', 'HbO');
%   fprintf('Mean coupling: %.3f (p = %.4f)\n', ...
%       mean(result.Mean, 'omitnan'), mean(result.pvalue, 'omitnan'));
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

    nPairs = length(pairs);
    if nPairs == 0
        error('exploreFNIRS:hyperscanning:computeGroup', 'No pairs provided');
    end

    % Compute each dyad
    dyadResults = cell(nPairs, 1);
    dyadIDs = cell(nPairs, 1);
    validDyads = true(nPairs, 1);

    for d = 1:nPairs
        dyadIDs{d} = pairs(d).dyadID;
    end

    % Determine whether to use parfor
    useParfor = false;
    if nPairs > 2
        [canUse, poolRunning] = pf2_base.accel.canParfor();
        useParfor = canUse && poolRunning;
    end

    % Pre-extract indices for parfor compatibility
    pairIndices = zeros(nPairs, 2);
    for d = 1:nPairs
        pairIndices(d, :) = pairs(d).indices;
    end

    if useParfor
        fprintf('Computing %d dyads (parallel)...\n', nPairs);
        parfor d = 1:nPairs
            try
                dyadResults{d} = exploreFNIRS.hyperscanning.computeDyad( ...
                    data{pairIndices(d,1)}, data{pairIndices(d,2)}, dyadArgs{:});
            catch
                validDyads(d) = false;
            end
        end
        % Print summary after parallel completion
        for d = 1:nPairs
            if validDyads(d)
                fprintf('  [%d/%d] %s: mean r = %.3f\n', d, nPairs, dyadIDs{d}, ...
                    mean(dyadResults{d}.values(:), 'omitnan'));
            else
                warning('pf2:hyperscanning:dyadFailed', ...
                    'Dyad [%d/%d] %s: FAILED', d, nPairs, dyadIDs{d});
            end
        end
    else
        fprintf('Computing %d dyads...\n', nPairs);
        for d = 1:nPairs
            try
                dyadResults{d} = exploreFNIRS.hyperscanning.computeDyad( ...
                    data{pairIndices(d,1)}, data{pairIndices(d,2)}, dyadArgs{:});
                fprintf('  [%d/%d] %s: mean r = %.3f\n', d, nPairs, dyadIDs{d}, ...
                    mean(dyadResults{d}.values(:), 'omitnan'));
            catch ME
                warning('exploreFNIRS:hyperscanning:computeGroup', ...
                    'Dyad "%s" failed: %s', dyadIDs{d}, ME.message);
                validDyads(d) = false;
            end
        end
    end

    dyadResults = dyadResults(validDyads);
    dyadIDs = dyadIDs(validDyads);
    nValid = sum(validDyads);

    if nValid == 0
        error('exploreFNIRS:hyperscanning:computeGroup', 'All dyads failed');
    end

    % Align dyad values using channel-identity-aware stacking
    [allValues, masterCh, ~, nValidMat] = ...
        exploreFNIRS.connectivity.alignMatrices(dyadResults, align);

    % Aggregate
    dim = ndims(allValues);  % last dimension = dyads

    % Fisher z-transform for correlation-based methods before averaging
    methodName = lower(dyadResults{1}.method);
    useFisherZ = ismember(methodName, {'pearson', 'spearman', 'xcorr'});

    nVals = sum(~isnan(allValues), dim);

    if useFisherZ
        zValues = atanh(max(min(allValues, 0.9999), -0.9999));
        zMean = mean(zValues, dim, 'omitnan');
        zSD = std(zValues, 0, dim, 'omitnan');
        zSEM = zSD ./ sqrt(max(nVals, 1));
        meanVals = tanh(zMean);
        % Back-transform SD/SEM to original scale (delta method approximation)
        sdVals = zSD .* (1 - meanVals.^2);
        semVals = zSEM .* (1 - meanVals.^2);
        % T-test in z-space (where distribution is approximately normal)
        tstat = zMean ./ zSEM;
    else
        meanVals = mean(allValues, dim, 'omitnan');
        sdVals = std(allValues, 0, dim, 'omitnan');
        semVals = sdVals ./ sqrt(max(nVals, 1));
        tstat = meanVals ./ semVals;
    end

    df = max(nVals - 1, 1);
    % Two-tailed p-value from t-distribution
    pvalue = 2 * (1 - tcdf(abs(tstat), df));
    % Handle edge cases
    pvalue(nVals < 2) = NaN;

    % Suppress cells with too few valid dyads (need at least 3 for
    % meaningful group statistics; with fewer the Fisher z-mean is
    % dominated by individual extreme values)
    minDyads = min(3, max(nVals(:)));
    tooFew = nVals < minDyads;
    meanVals(tooFew) = NaN;
    sdVals(tooFew)   = NaN;
    semVals(tooFew)  = NaN;
    tstat(tooFew)    = NaN;
    pvalue(tooFew)   = NaN;

    result.Mean = squeeze(meanVals);
    result.SD = squeeze(sdVals);
    result.SEM = squeeze(semVals);
    result.N = squeeze(nVals);
    result.nValid = squeeze(nValidMat);
    result.tstat = squeeze(tstat);
    result.pvalue = squeeze(pvalue);
    result.dyads = dyadResults;
    result.dyadIDs = dyadIDs;
    result.method = dyadResults{1}.method;
    result.biomarker = dyadResults{1}.biomarker;
    result.pairing = dyadResults{1}.pairing;

    % Dyad-level summary: mean coupling per dyad, then average across dyads
    % (more robust than averaging the Fisher z group matrix)
    dyadMeans = nan(nValid, 1);
    for d = 1:nValid
        dyadMeans(d) = mean(dyadResults{d}.values(:), 'omitnan');
    end
    result.dyadMeans = dyadMeans;

    % Use master channels from alignment
    if iscell(masterCh)
        result.channels = masterCh{1};
        result.channelsB = masterCh{2};
    else
        result.channels = masterCh;
    end

    % Report dyad-level summary (robust to sparse channel coverage)
    fprintf('Group result: %d valid dyads, mean coupling = %.3f (dyad-level), median = %.3f\n', ...
        nValid, mean(dyadMeans, 'omitnan'), median(dyadMeans, 'omitnan'));
end
