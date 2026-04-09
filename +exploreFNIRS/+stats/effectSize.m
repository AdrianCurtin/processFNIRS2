function results = effectSize(groups, groupByVars, varargin)
% EFFECTSIZE Effect size with bootstrap confidence intervals for fNIRS data
%
% Computes effect sizes (Hedges' g, Cohen's d, or Glass's delta) between
% two conditions with bootstrap confidence intervals. Designed for small-N
% fNIRS studies where parametric CIs may be unreliable.
%
% Syntax:
%   results = exploreFNIRS.stats.effectSize(groups, groupByVars)
%   results = exploreFNIRS.stats.effectSize(groups, groupByVars, 'CI', 0.95)
%   results = exploreFNIRS.stats.effectSize(groups, groupByVars, ...
%       'Method', 'hedges_g', 'NumBoot', 5000)
%
% Inputs:
%   groups      - Struct array from Experiment.groups (after aggregate())
%   groupByVars - Cell array of grouping variable names
%
% Name-Value Parameters:
%   Method      - 'hedges_g' (default), 'cohens_d', or 'glass_delta'
%   CI          - Confidence level (default: 0.95)
%   NumBoot     - Number of bootstrap resamples (default: 5000)
%   Seed        - Random seed for reproducibility (default: 2024)
%   Biomarkers  - Cell array of biomarker names (default: {'HbO','HbR','HbTotal','CBSI'})
%   Channels    - Channel indices (default: all)
%   StatWindow  - [start, end] seconds to filter time bins (default: [])
%   Verbose     - Print progress (default: true)
%   ExcludeShortSeparation - Skip short-sep channels (default: true)
%
% Outputs:
%   results - Struct with fields:
%     .observed       - [nBio x nCh] effect size values
%     .ci_lower       - [nBio x nCh] lower CI bound
%     .ci_upper       - [nBio x nCh] upper CI bound
%     .bootstrap_dist - {nBio x nCh} cell of bootstrap distributions
%     .method         - Effect size method used
%     .ci_level       - Confidence level used
%     .nBoot          - Number of bootstrap resamples
%     .biomarkers     - Biomarker names
%     .channels       - Channel indices
%     .conditions     - {2 x 1} cell of condition labels
%     .nPerGroup      - [1 x 2] sample sizes
%
% Example:
%   ex = exploreFNIRS.core.Experiment(data);
%   ex.select('Condition', {'Easy','Hard'});
%   ex.groupby('Condition');
%   ex.aggregate();
%   es = ex.statsEffectSize('Biomarkers', {'HbO'}, 'NumBoot', 2000);
%   fprintf('Hedges'' g = %.2f [%.2f, %.2f]\n', ...
%       es.observed(1,1), es.ci_lower(1,1), es.ci_upper(1,1));
%
% References:
%   Hedges, L. V. & Olkin, I. (1985). Statistical Methods for
%   Meta-Analysis. Academic Press.
%
%   Efron, B. & Tibshirani, R. J. (1993). An Introduction to the
%   Bootstrap. Chapman and Hall/CRC. DOI: 10.1201/9780429246593
%
% See also: exploreFNIRS.stats.fitLME, exploreFNIRS.stats.permTest,
%           exploreFNIRS.fx.autoContrast

    p = inputParser;
    addRequired(p, 'groups', @isstruct);
    addRequired(p, 'groupByVars', @iscell);
    addParameter(p, 'Method', 'hedges_g', @ischar);
    addParameter(p, 'CI', 0.95, @(x) isnumeric(x) && x > 0 && x < 1);
    addParameter(p, 'NumBoot', 5000, @(x) isnumeric(x) && x > 0);
    addParameter(p, 'Seed', 2024, @isnumeric);
    addParameter(p, 'Biomarkers', {'HbO','HbR','HbTotal','CBSI'}, @iscell);
    addParameter(p, 'Channels', [], @isnumeric);
    addParameter(p, 'StatWindow', [], @isnumeric);
    addParameter(p, 'Verbose', true, @islogical);
    addParameter(p, 'ExcludeShortSeparation', true, @islogical);
    parse(p, groups, groupByVars, varargin{:});
    opts = p.Results;

    % Validate method
    validMethods = {'hedges_g', 'cohens_d', 'glass_delta'};
    if ~ismember(lower(opts.Method), validMethods)
        error('exploreFNIRS:stats:effectSize:invalidMethod', ...
            'Unknown method: ''%s''. Use ''hedges_g'', ''cohens_d'', or ''glass_delta''.', ...
            opts.Method);
    end

    % Must have exactly 2 groups
    nGroups = length(groups);
    if nGroups ~= 2
        error('exploreFNIRS:stats:effectSize:needTwoGroups', ...
            'Effect size requires exactly 2 groups (got %d). Use select() to choose 2 conditions.', ...
            nGroups);
    end

    nBioM = length(opts.Biomarkers);

    % Get time bins and apply StatWindow mask
    barTimes = groups(1).gbyGrandBarFlat.time;
    if ~isempty(opts.StatWindow)
        sw = opts.StatWindow;
        if ~isnumeric(sw) || numel(sw) ~= 2
            error('exploreFNIRS:stats:effectSize:invalidStatWindow', ...
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

    % Initialize results
    results = struct();
    results.observed = nan(nBioM, nCh);
    results.ci_lower = nan(nBioM, nCh);
    results.ci_upper = nan(nBioM, nCh);
    results.bootstrap_dist = cell(nBioM, nCh);
    results.method = opts.Method;
    results.ci_level = opts.CI;
    results.nBoot = opts.NumBoot;
    results.biomarkers = opts.Biomarkers;
    results.channels = channels;
    results.conditions = {groups(1).label, groups(2).label};

    % Get per-group sample sizes from 3rd dim of data
    nA = size(groups(1).gbyGrandBarFlat.(firstBio).data, 3);
    nB = size(groups(2).gbyGrandBarFlat.(firstBio).data, 3);
    results.nPerGroup = [nA, nB];

    rng(opts.Seed);
    alpha = 1 - opts.CI;

    for bIdx = 1:nBioM
        bioM = opts.Biomarkers{bIdx};

        for chI = 1:nCh
            ch = channels(chI);

            % Extract per-subject means from gbyGrandBarFlat
            % Data is [time x channels x subjects]
            dataA = groups(1).gbyGrandBarFlat.(bioM).data(tMask, ch, :);
            dataB = groups(2).gbyGrandBarFlat.(bioM).data(tMask, ch, :);

            % Average across time bins -> [1 x 1 x nSub] -> [nSub x 1]
            meansA = squeeze(mean(dataA, 1, 'omitnan'));
            meansB = squeeze(mean(dataB, 1, 'omitnan'));

            % Handle case where squeeze removes dimensions
            meansA = meansA(:);
            meansB = meansB(:);

            % Remove NaN subjects
            meansA = meansA(~isnan(meansA));
            meansB = meansB(~isnan(meansB));

            if isempty(meansA) || isempty(meansB)
                continue;
            end

            % Compute observed effect size
            results.observed(bIdx, chI) = computeES(meansA, meansB, opts.Method);

            % Bootstrap CI
            bootDist = nan(opts.NumBoot, 1);
            nAval = length(meansA);
            nBval = length(meansB);

            for b = 1:opts.NumBoot
                idxA = randi(nAval, nAval, 1);
                idxB = randi(nBval, nBval, 1);
                bootDist(b) = computeES(meansA(idxA), meansB(idxB), opts.Method);
            end

            results.bootstrap_dist{bIdx, chI} = bootDist;
            results.ci_lower(bIdx, chI) = quantile(bootDist, alpha / 2);
            results.ci_upper(bIdx, chI) = quantile(bootDist, 1 - alpha / 2);
        end

        if opts.Verbose
            sigCount = sum(~isnan(results.observed(bIdx, :)));
            fprintf('Effect size [%s]: computed for %d/%d channels\n', ...
                bioM, sigCount, nCh);
        end
    end
end


function es = computeES(meansA, meansB, method)
% COMPUTEES Compute effect size between two groups

    diff = mean(meansA) - mean(meansB);
    nA = length(meansA);
    nB = length(meansB);

    switch lower(method)
        case 'cohens_d'
            sp = sqrt(((nA - 1) * var(meansA) + (nB - 1) * var(meansB)) / (nA + nB - 2));
            if sp == 0
                es = 0;
            else
                es = diff / sp;
            end

        case 'hedges_g'
            sp = sqrt(((nA - 1) * var(meansA) + (nB - 1) * var(meansB)) / (nA + nB - 2));
            if sp == 0
                es = 0;
            else
                d = diff / sp;
                df = nA + nB - 2;
                J = 1 - 3 / (4 * df - 1);
                es = d * J;
            end

        case 'glass_delta'
            sdB = std(meansB);
            if sdB == 0
                es = 0;
            else
                es = diff / sdB;
            end
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
