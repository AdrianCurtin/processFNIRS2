function results = permTest(groups, groupByVars, varargin)
% PERMTEST Non-parametric permutation test for paired fNIRS comparisons
%
% Performs sign-flip permutation testing for 2-condition within-subject
% comparisons. Critical for small-N (N=5-7) studies where LME assumptions
% may not hold. Supports exact enumeration or Monte Carlo approximation.
%
% Syntax:
%   results = exploreFNIRS.stats.permTest(groups, groupByVars)
%   results = exploreFNIRS.stats.permTest(groups, groupByVars, 'NumPerm', 5000)
%   results = exploreFNIRS.stats.permTest(groups, groupByVars, ...
%       'Statistic', 'tstat', 'Tail', 'right')
%
% Inputs:
%   groups      - Struct array from Experiment.groups (after aggregate())
%   groupByVars - Cell array of grouping variable names
%
% Name-Value Parameters:
%   Biomarkers  - Cell array of biomarker names (default: {'HbO','HbR','HbTotal','CBSI'})
%   Channels    - Channel indices (default: all)
%   StatWindow  - [start, end] seconds to filter time bins (default: [])
%   NumPerm     - Number of permutations (default: 5000), or 'exact'
%   Paired      - Paired (sign-flip) test (default: true)
%   Statistic   - 'mean_diff' (default) or 'tstat'
%   Tail        - 'both' (default), 'right', or 'left'
%   Seed        - Random seed for reproducibility (default: 2024)
%   Verbose     - Print progress (default: true)
%   ExcludeShortSeparation - Skip short-sep channels (default: true)
%   FDRThreshold - FDR threshold across channels (default: 0.05)
%   FDRMethod   - 'bh' (default) or 'twostep'
%
% Outputs:
%   results - Struct with fields:
%     .observed     - [nBio x nCh] observed test statistic
%     .nullDist     - {nBio x nCh} cell of null distributions
%     .pvalue       - [nBio x nCh] uncorrected p-values
%     .pvalueFDR    - [nBio x nCh] FDR-corrected p-values
%     .significant  - [nBio x nCh] logical significance after FDR
%     .effectSize   - [nBio x nCh] Hedges' g effect size
%     .nPerms       - Number of permutations used
%     .isExact      - Whether exact enumeration was used
%     .statistic    - Test statistic used
%     .tail         - Tail direction
%     .biomarkers   - Biomarker names
%     .channels     - Channel indices
%     .conditions   - {2 x 1} cell of condition labels
%     .nSubjects    - Number of paired subjects
%
% Example:
%   ex = exploreFNIRS.core.Experiment(data);
%   ex.select('Condition', {'Easy','Hard'});
%   ex.groupby('Condition');
%   ex.aggregate();
%   perm = ex.statsPermTest('Biomarkers', {'HbO'}, 'NumPerm', 1000);
%   fprintf('Channel 1 p = %.4f (FDR q = %.4f)\n', ...
%       perm.pvalue(1,1), perm.pvalueFDR(1,1));
%
% References:
%   Phipson, B. & Smyth, G. K. (2010). Permutation P-values should never
%   be zero: calculating exact P-values when permutations are randomly
%   drawn. Statistical Applications in Genetics and Molecular Biology,
%   9(1), Article 39. DOI: 10.2202/1544-6115.1585
%
%   Nichols, T. E. & Holmes, A. P. (2002). Nonparametric permutation tests
%   for functional neuroimaging: a primer with examples. Human Brain
%   Mapping, 15(1), 1-25. DOI: 10.1002/hbm.1058
%
% See also: exploreFNIRS.stats.fitLME, exploreFNIRS.stats.effectSize,
%           exploreFNIRS.fx.performFDR

    p = inputParser;
    addRequired(p, 'groups', @isstruct);
    addRequired(p, 'groupByVars', @iscell);
    addParameter(p, 'Biomarkers', {'HbO','HbR','HbTotal','CBSI'}, @iscell);
    addParameter(p, 'Channels', [], @isnumeric);
    addParameter(p, 'StatWindow', [], @isnumeric);
    addParameter(p, 'NumPerm', 5000, @(x) (isnumeric(x) && x > 0) || (ischar(x) && strcmpi(x, 'exact')));
    addParameter(p, 'Paired', true, @islogical);
    addParameter(p, 'Statistic', 'mean_diff', @ischar);
    addParameter(p, 'Tail', 'both', @ischar);
    addParameter(p, 'Seed', 2024, @isnumeric);
    addParameter(p, 'Verbose', true, @islogical);
    addParameter(p, 'ExcludeShortSeparation', true, @islogical);
    addParameter(p, 'FDRThreshold', 0.05, @isnumeric);
    addParameter(p, 'FDRMethod', 'bh', @ischar);
    parse(p, groups, groupByVars, varargin{:});
    opts = p.Results;

    % Must have exactly 2 groups
    nGroups = length(groups);
    if nGroups ~= 2
        error('exploreFNIRS:stats:permTest:needTwoGroups', ...
            'Permutation test requires exactly 2 groups (got %d). Use select() to choose 2 conditions.', ...
            nGroups);
    end

    if ~opts.Paired
        error('exploreFNIRS:stats:permTest:unpairedNotSupported', ...
            'Unpaired permutation test is not yet supported. Use ''Paired'', true.');
    end

    nBioM = length(opts.Biomarkers);

    % Get time bins and apply StatWindow mask
    barTimes = groups(1).gbyGrandBarFlat.time;
    if ~isempty(opts.StatWindow)
        sw = opts.StatWindow;
        if ~isnumeric(sw) || numel(sw) ~= 2
            error('exploreFNIRS:stats:permTest:invalidStatWindow', ...
                'StatWindow must be a 2-element numeric vector [start, end].');
        end
        tMask = barTimes >= sw(1) & barTimes <= sw(2);
    else
        tMask = true(size(barTimes));
    end

    % Determine channels
    firstBio = opts.Biomarkers{1};
    if isempty(opts.Channels)
        nCh = size(groups(1).gbyGrandBarFlat.(firstBio).data, 2);
        channels = 1:nCh;
    else
        channels = opts.Channels;
        nCh = length(channels);
    end

    % Exclude short separation channels
    if opts.ExcludeShortSeparation
        ssIdx = getShortSeparationIdx(groups);
        if ~isempty(ssIdx)
            channels = channels(~ismember(channels, ssIdx));
            nCh = length(channels);
            if opts.Verbose
                fprintf('Excluding %d short separation channels\n', length(ssIdx));
            end
        end
    end

    % Number of subjects per group (paired: must be equal)
    nSubA = size(groups(1).gbyGrandBarFlat.(firstBio).data, 3);
    nSubB = size(groups(2).gbyGrandBarFlat.(firstBio).data, 3);
    nSub = min(nSubA, nSubB);

    if nSub < 2
        error('exploreFNIRS:stats:permTest:tooFewSubjects', ...
            'Need at least 2 subjects per group for permutation test (got %d, %d).', ...
            nSubA, nSubB);
    end

    if nSubA ~= nSubB
        warning('exploreFNIRS:stats:permTest:unequalGroups', ...
            'Unequal group sizes (%d vs %d). Truncating to %d paired subjects.', ...
            nSubA, nSubB, nSub);
    end

    % Determine permutation mode
    requestedExact = ischar(opts.NumPerm) && strcmpi(opts.NumPerm, 'exact');
    if requestedExact
        useExact = true;
        nPerms = 2^nSub;
    elseif 2^nSub <= opts.NumPerm
        useExact = true;
        nPerms = 2^nSub;
    else
        useExact = false;
        if isnumeric(opts.NumPerm)
            nPerms = opts.NumPerm;
        else
            nPerms = 5000;
        end
    end

    % Initialize results
    results = struct();
    results.observed = nan(nBioM, nCh);
    results.nullDist = cell(nBioM, nCh);
    results.pvalue = nan(nBioM, nCh);
    results.pvalueFDR = nan(nBioM, nCh);
    results.significant = false(nBioM, nCh);
    results.effectSize = nan(nBioM, nCh);
    results.nPerms = nPerms;
    results.isExact = useExact;
    results.statistic = opts.Statistic;
    results.tail = opts.Tail;
    results.biomarkers = opts.Biomarkers;
    results.channels = channels;
    results.conditions = {groups(1).label, groups(2).label};
    results.nSubjects = nSub;

    rng(opts.Seed);

    for bIdx = 1:nBioM
        bioM = opts.Biomarkers{bIdx};

        for chI = 1:nCh
            ch = channels(chI);

            % Extract per-subject means from gbyGrandBarFlat
            % Data is [time x channels x subjects]
            dataA = groups(1).gbyGrandBarFlat.(bioM).data(tMask, ch, :);
            dataB = groups(2).gbyGrandBarFlat.(bioM).data(tMask, ch, :);

            % Average across time -> [1 x 1 x nSub] -> [nSub x 1]
            meansA = squeeze(mean(dataA, 1, 'omitnan'));
            meansB = squeeze(mean(dataB, 1, 'omitnan'));
            meansA = meansA(:);
            meansB = meansB(:);

            % Truncate to common length (paired)
            n = min(length(meansA), length(meansB));
            meansA = meansA(1:n);
            meansB = meansB(1:n);

            % Paired differences
            diffs = meansA - meansB;

            % Remove NaN pairs
            valid = ~isnan(diffs);
            diffs = diffs(valid);
            n = length(diffs);

            if n < 2, continue; end

            % Observed test statistic
            obsT = computeStat(diffs, opts.Statistic);
            results.observed(bIdx, chI) = obsT;

            % Hedges' g effect size for paired differences
            meanDiff = mean(diffs);
            sdDiff = std(diffs);
            if sdDiff > 0
                d = meanDiff / sdDiff;
                J = 1 - 3 / (4 * (n - 1) - 1);
                results.effectSize(bIdx, chI) = d * J;
            else
                results.effectSize(bIdx, chI) = 0;
            end

            % Generate null distribution via sign flips
            nullDist = nan(nPerms, 1);
            if useExact
                actualPerms = 2^n;
                for pIdx = 1:actualPerms
                    signs = 2 * de2bi(pIdx - 1, n) - 1;
                    nullDist(pIdx) = computeStat(diffs .* signs(:), opts.Statistic);
                end
                nullDist = nullDist(1:actualPerms);
            else
                for pIdx = 1:nPerms
                    signs = 2 * (rand(n, 1) > 0.5) - 1;
                    nullDist(pIdx) = computeStat(diffs .* signs, opts.Statistic);
                end
            end

            results.nullDist{bIdx, chI} = nullDist;

            % P-value (Phipson & Smyth 2010)
            switch lower(opts.Tail)
                case 'both'
                    count = sum(abs(nullDist) >= abs(obsT));
                case 'right'
                    count = sum(nullDist >= obsT);
                case 'left'
                    count = sum(nullDist <= obsT);
            end
            results.pvalue(bIdx, chI) = (count + 1) / (length(nullDist) + 1);
        end

        % FDR correction across channels
        pVals = results.pvalue(bIdx, :);
        if ~all(isnan(pVals))
            switch lower(opts.FDRMethod)
                case 'bh'
                    [qVals, ~, sig] = exploreFNIRS.fx.performFDR( ...
                        pVals, opts.FDRThreshold);
                case 'twostep'
                    [qVals, ~, sig] = exploreFNIRS.fx.performFDR_twostep( ...
                        pVals, opts.FDRThreshold);
                otherwise
                    [qVals, ~, sig] = exploreFNIRS.fx.performFDR( ...
                        pVals, opts.FDRThreshold);
            end
            results.pvalueFDR(bIdx, :) = qVals;
            results.significant(bIdx, :) = sig;
        end

        if opts.Verbose
            nSig = sum(results.significant(bIdx, :));
            nValid = sum(~isnan(results.pvalue(bIdx, :)));
            fprintf('PermTest [%s]: %d/%d channels significant (FDR < %.2f)\n', ...
                bioM, nSig, nValid, opts.FDRThreshold);
        end
    end
end


function stat = computeStat(diffs, statType)
% COMPUTESTAT Compute test statistic from paired differences

    switch lower(statType)
        case 'mean_diff'
            stat = mean(diffs);
        case 'tstat'
            n = length(diffs);
            stat = mean(diffs) / (std(diffs) / sqrt(n));
            if isnan(stat), stat = 0; end
        otherwise
            error('exploreFNIRS:stats:permTest:invalidStatistic', ...
                'Unknown statistic type: ''%s''. Use ''mean_diff'' or ''tstat''.', statType);
    end
end


function bits = de2bi(n, nBits)
% DE2BI Convert decimal to binary vector (no Communications Toolbox needed)

    bits = zeros(1, nBits);
    for i = 1:nBits
        bits(i) = mod(n, 2);
        n = floor(n / 2);
    end
end


function ssIdx = getShortSeparationIdx(groups)
% GETSHORTSEPARATIONIDX Get indices of short separation channels from probe info

    ssIdx = [];

    if isempty(groups) || isempty(groups(1).gbyFNIRS)
        return;
    end

    fNIR = groups(1).gbyFNIRS{1};

    probeInfo = [];
    if isfield(fNIR, 'probeinfo') && isfield(fNIR.probeinfo, 'Probe') ...
            && iscell(fNIR.probeinfo.Probe) && ~isempty(fNIR.probeinfo.Probe)
        probeInfo = fNIR.probeinfo.Probe{1};
    elseif isfield(fNIR, 'info') && isfield(fNIR.info, 'probename') ...
            && ~isempty(fNIR.info.probename) && ~contains(fNIR.info.probename, 'Unknown')
        try
            device = pf2_base.loadDeviceCfg(fNIR.info.probename);
            if isstruct(device) && isfield(device, 'Probe') ...
                    && iscell(device.Probe) && ~isempty(device.Probe)
                probeInfo = device.Probe{1};
            end
        catch
            return;
        end
    end

    if isempty(probeInfo)
        return;
    end

    if isfield(probeInfo, 'TableOpt') && istable(probeInfo.TableOpt) ...
            && ismember('IsShortSeparation', probeInfo.TableOpt.Properties.VariableNames)
        ssIdx = find(probeInfo.TableOpt.IsShortSeparation(:)');
    elseif isfield(probeInfo, 'NumShortSeparation') && probeInfo.NumShortSeparation > 0 ...
            && isfield(probeInfo, 'TableOpt') && istable(probeInfo.TableOpt) ...
            && ismember('SD', probeInfo.TableOpt.Properties.VariableNames)
        ssIdx = find(probeInfo.TableOpt.SD(:)' < 2);
    end
end
