function result = computeGroup(data, pairs, varargin)
% COMPUTEGROUP Aggregate inter-brain coupling across all dyads
%
% Iterates over paired subjects from pairSubjects, computes dyad-level
% coupling for each pair, and aggregates into group-level statistics
% (Mean, SD, SEM, N) with one-sample t-tests against zero.
%
% Syntax:
%   result = exploreFNIRS.hyperscanning.computeGroup(data, pairs)
%   result = exploreFNIRS.hyperscanning.computeGroup(data, pairs, ...
%       'Method', 'pearson', 'Biomarker', 'HbO')
%
% Inputs:
%   data  - Cell array of processed fNIRS structs
%   pairs - Struct array from pairSubjects (with .indices, .dyadID, etc.)
%
% Name-Value Parameters:
%   All parameters from computeDyad are supported (Method, Biomarker,
%   ChannelPairing, Channels, TimeWindow, CouplingArgs).
%
% Outputs:
%   result - Struct with fields:
%     .Mean     - Mean coupling across dyads (same shape as dyad values)
%     .SD       - Standard deviation
%     .SEM      - Standard error of the mean
%     .N        - Number of valid dyads per element
%     .tstat    - One-sample t-statistic (vs 0)
%     .pvalue   - P-value from one-sample t-test
%     .dyads    - Cell array of individual dyad results
%     .dyadIDs  - Cell array of dyad ID strings
%     .method   - Coupling method used
%     .biomarker - Biomarker used
%     .pairing  - Channel pairing mode
%     .channels - Channels used
%
% Example:
%   pairs = exploreFNIRS.hyperscanning.pairSubjects(data);
%   result = exploreFNIRS.hyperscanning.computeGroup(data, pairs, ...
%       'Method', 'pearson', 'Biomarker', 'HbO');
%   fprintf('Mean coupling: %.3f (p = %.4f)\n', ...
%       mean(result.Mean, 'omitnan'), mean(result.pvalue, 'omitnan'));
%
% See also: exploreFNIRS.hyperscanning.pairSubjects, exploreFNIRS.hyperscanning.computeDyad

    % Pass through all name-value params to computeDyad
    dyadArgs = varargin;

    nPairs = length(pairs);
    if nPairs == 0
        error('exploreFNIRS:hyperscanning:computeGroup', 'No pairs provided');
    end

    % Compute each dyad
    dyadResults = cell(nPairs, 1);
    dyadIDs = cell(nPairs, 1);
    validDyads = true(nPairs, 1);

    fprintf('Computing %d dyads...\n', nPairs);
    for d = 1:nPairs
        idx = pairs(d).indices;
        dyadIDs{d} = pairs(d).dyadID;

        try
            dyadResults{d} = exploreFNIRS.hyperscanning.computeDyad( ...
                data{idx(1)}, data{idx(2)}, dyadArgs{:});
            fprintf('  [%d/%d] %s: mean r = %.3f\n', d, nPairs, dyadIDs{d}, ...
                mean(dyadResults{d}.values(:), 'omitnan'));
        catch ME
            warning('exploreFNIRS:hyperscanning:computeGroup', ...
                'Dyad "%s" failed: %s', dyadIDs{d}, ME.message);
            validDyads(d) = false;
        end
    end

    dyadResults = dyadResults(validDyads);
    dyadIDs = dyadIDs(validDyads);
    nValid = sum(validDyads);

    if nValid == 0
        error('exploreFNIRS:hyperscanning:computeGroup', 'All dyads failed');
    end

    % Stack dyad values into 3D array for aggregation
    refSize = size(dyadResults{1}.values);
    allValues = nan([refSize, nValid]);

    for d = 1:nValid
        dVals = dyadResults{d}.values;
        % Handle size mismatch by trimming to common size
        sz = min(size(dVals), refSize);
        if length(sz) == 1
            allValues(1:sz(1), d) = dVals(1:sz(1));
        else
            allValues(1:sz(1), 1:sz(2), d) = dVals(1:sz(1), 1:sz(2));
        end
    end

    % Aggregate
    dim = length(refSize) + 1;  % last dimension = dyads
    meanVals = mean(allValues, dim, 'omitnan');
    sdVals = std(allValues, 0, dim, 'omitnan');
    nVals = sum(~isnan(allValues), dim);
    semVals = sdVals ./ sqrt(max(nVals, 1));

    % One-sample t-test against zero
    tstat = meanVals ./ semVals;
    df = max(nVals - 1, 1);
    % Two-tailed p-value from t-distribution
    pvalue = 2 * (1 - tcdf(abs(tstat), df));
    % Handle edge cases
    pvalue(nVals < 2) = NaN;

    result.Mean = squeeze(meanVals);
    result.SD = squeeze(sdVals);
    result.SEM = squeeze(semVals);
    result.N = squeeze(nVals);
    result.tstat = squeeze(tstat);
    result.pvalue = squeeze(pvalue);
    result.dyads = dyadResults;
    result.dyadIDs = dyadIDs;
    result.method = dyadResults{1}.method;
    result.biomarker = dyadResults{1}.biomarker;
    result.pairing = dyadResults{1}.pairing;
    result.channels = dyadResults{1}.channelsA;

    fprintf('Group result: %d valid dyads, mean coupling = %.3f\n', ...
        nValid, mean(result.Mean(:), 'omitnan'));
end
