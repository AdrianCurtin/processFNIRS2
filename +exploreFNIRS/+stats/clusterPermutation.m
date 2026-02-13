function results = clusterPermutation(lmeResults, data, varargin)
% CLUSTERPERMUTATION Cluster-based permutation testing for fNIRS channel statistics
%
% Performs nonparametric cluster-based permutation testing to correct for
% multiple comparisons while preserving spatial structure. Identifies
% spatially contiguous clusters of channels showing significant effects,
% then tests those clusters against a null distribution built by permuting
% condition labels across subjects.
%
% This method controls the family-wise error rate (FWER) at the cluster
% level and is more sensitive than channel-wise FDR when effects are
% spatially extended.
%
% Reference:
%   Maris, E. & Oostenveld, R. (2007). Nonparametric statistical testing
%   of EEG- and MEG-data. Journal of Neuroscience Methods, 164(1), 177-190.
%   DOI: 10.1016/j.jneumeth.2007.03.024
%
% Syntax:
%   results = exploreFNIRS.stats.clusterPermutation(lmeResults, data)
%   results = exploreFNIRS.stats.clusterPermutation(lmeResults, data, Name, Value)
%
% Inputs:
%   lmeResults - Struct from exploreFNIRS.stats.fitLME with fields:
%                .anova_Fstat, .anova_pval, .models, .channels, .biomarkers,
%                .groupByVars, .formula
%   data       - Cell array of processed fNIRS structs (for device info
%                and label permutation)
%
% Name-Value Parameters:
%   Permutations    - Number of permutations (default: 1000)
%   ClusterAlpha    - Threshold for initial cluster formation (default: 0.05)
%   Alpha           - Cluster-level significance threshold (default: 0.05)
%   MaxDistance      - Adjacency distance in mm (default: 30)
%   ClusterStat     - 'sumstat' (default), 'maxstat', or 'extent'
%   Tail            - 'both' (default), 'positive', or 'negative'
%   Biomarker       - Which biomarker to test (default: first in lmeResults)
%   Term            - ANOVA term to test (default: first non-intercept)
%   Verbose         - Print progress (default: true)
%
% Outputs:
%   results - Struct with fields:
%     .clusters       - Struct array of significant clusters, each with:
%                       .channels, .stat, .pvalue, .significant, .polarity
%     .allClusters    - All observed clusters (before significance filter)
%     .adjacency      - Adjacency matrix used
%     .nullDist       - [1 x nPerm] max cluster stat null distribution
%     .observedStats  - [1 x nCh] observed test statistics per channel
%     .params         - Struct of parameters used
%     .biomarker      - Biomarker tested
%     .term           - ANOVA term tested
%
% Example:
%   % After fitting LME models
%   ex = exploreFNIRS.core.Experiment(allData);
%   ex.groupby({'Condition'});
%   ex.aggregate();
%   lme = ex.statsFitLME('Biomarkers', {'HbO'});
%
%   % Run cluster permutation (reduced permutations for speed)
%   cp = exploreFNIRS.stats.clusterPermutation(lme, allData, ...
%       'Permutations', 500, 'Verbose', true);
%
%   % Examine significant clusters
%   for k = 1:length(cp.clusters)
%       fprintf('Cluster %d: channels [%s], p=%.4f\n', k, ...
%           num2str(cp.clusters(k).channels), cp.clusters(k).pvalue);
%   end
%
% See also: exploreFNIRS.stats.fitLME, exploreFNIRS.stats.findClusters,
%           pf2.probe.computeAdjacency, exploreFNIRS.stats.runContrasts

%% Parse inputs
p = inputParser;
addRequired(p, 'lmeResults', @isstruct);
addRequired(p, 'data', @iscell);
addParameter(p, 'Permutations', 1000, @(x) isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, 'ClusterAlpha', 0.05, @(x) isnumeric(x) && x > 0 && x < 1);
addParameter(p, 'Alpha', 0.05, @(x) isnumeric(x) && x > 0 && x < 1);
addParameter(p, 'MaxDistance', 30, @(x) isnumeric(x) && x > 0);
addParameter(p, 'ClusterStat', 'sumstat', @(x) ismember(x, {'sumstat','maxstat','extent'}));
addParameter(p, 'Tail', 'both', @(x) ismember(x, {'both','positive','negative'}));
addParameter(p, 'Biomarker', '', @(x) ischar(x) || isstring(x));
addParameter(p, 'Term', '', @(x) ischar(x) || isstring(x));
addParameter(p, 'Verbose', true, @islogical);
parse(p, lmeResults, data, varargin{:});

opts = p.Results;
nPerm = opts.Permutations;

%% Resolve biomarker
if isempty(opts.Biomarker)
    biomarker = lmeResults.biomarkers{1};
else
    biomarker = opts.Biomarker;
end

bIdx = find(strcmp(lmeResults.biomarkers, biomarker), 1);
if isempty(bIdx)
    error('exploreFNIRS:stats:clusterPermutation', ...
        'Biomarker ''%s'' not found in LME results.', biomarker);
end

%% Resolve ANOVA term
termNames = lmeResults.anova_Fstat.Properties.VariableNames;
if isempty(opts.Term)
    % Use first non-intercept term
    nonIntercept = termNames(~strcmpi(termNames, 'Intercept'));
    if isempty(nonIntercept)
        error('exploreFNIRS:stats:clusterPermutation', ...
            'No non-intercept ANOVA terms found.');
    end
    termName = nonIntercept{1};
else
    termName = opts.Term;
    if ~ismember(termName, termNames)
        error('exploreFNIRS:stats:clusterPermutation', ...
            'Term ''%s'' not found. Available: %s', termName, strjoin(termNames, ', '));
    end
end

%% Extract observed test statistics
channels = lmeResults.channels;
nCh = length(channels);

% Get F-statistics for the chosen term across channels
% Row names in anova_Fstat are like 'Opt1_HbO', 'Opt2_HbO', etc.
observedF = nan(1, nCh);
observedP = nan(1, nCh);

for chI = 1:nCh
    ch = channels(chI);
    rowName = sprintf('Opt%d_%s', ch, biomarker);

    if ismember(rowName, lmeResults.anova_Fstat.Properties.RowNames)
        observedF(chI) = lmeResults.anova_Fstat{rowName, termName};
        observedP(chI) = lmeResults.anova_pval{rowName, termName};
    end
end

%% Convert F to signed statistics using coefficient direction
% F-statistics are always positive. To get direction (for two-tailed
% clustering), we use the sign of the corresponding fixed-effect coefficient.
observedStat = sqrt(observedF);  % sqrt(F) approximates |t| for single-df effects
for chI = 1:nCh
    mdl = lmeResults.models{bIdx, chI};
    if isempty(mdl), continue; end

    try
        coeffs = mdl.Coefficients;
        % Find the coefficient matching this term
        termRows = strcmp(coeffs.Name, termName);
        if ~any(termRows)
            % Try prefix match for categorical levels (e.g., 'Condition_2')
            termRows = strncmp(coeffs.Name, termName, length(termName));
        end
        if any(termRows)
            coefVal = coeffs.Estimate(find(termRows, 1));
            if coefVal < 0
                observedStat(chI) = -observedStat(chI);
            end
        end
    catch
        % Keep positive if we can't determine sign
    end
end

%% Build adjacency matrix
if opts.Verbose
    fprintf('Building channel adjacency (MaxDistance = %d mm)...\n', opts.MaxDistance);
end

adj = pf2.probe.computeAdjacency(data{1}, 'MaxDistance', opts.MaxDistance);

% Subset adjacency to channels used in analysis
adjFull = adj;
adj = adj(channels, channels);

%% Compute cluster-forming threshold
% Convert ClusterAlpha to F-stat threshold using the observed distribution
% Use the ANOVA p-values: channels with p < ClusterAlpha form candidate clusters
fThreshold = getStatThreshold(observedF, observedP, opts.ClusterAlpha);
if opts.Verbose
    fprintf('Cluster-forming threshold: F > %.2f (alpha=%.3f)\n', ...
        fThreshold^2, opts.ClusterAlpha);
end

%% Find observed clusters
observedClusters = exploreFNIRS.stats.findClusters( ...
    observedStat, adj, fThreshold, opts.ClusterStat, opts.Tail);

if opts.Verbose
    fprintf('Found %d observed cluster(s)\n', length(observedClusters));
    for k = 1:length(observedClusters)
        fprintf('  Cluster %d: %d channels, stat=%.2f (%s)\n', k, ...
            length(observedClusters(k).channels), ...
            observedClusters(k).stat, observedClusters(k).polarity);
    end
end

%% Build null distribution by permuting condition labels
if opts.Verbose
    fprintf('Running %d permutations...\n', nPerm);
end

nullDist = zeros(1, nPerm);

% Extract merged table and determine permutation strategy
mergedTable = lmeResults.mergedTable;
groupByVars = lmeResults.groupByVars;
formula = lmeResults.formula;

% Identify the permutation variable (first groupby var that isn't Time)
permVar = '';
for vi = 1:length(groupByVars)
    if ~strcmpi(groupByVars{vi}, 'Time')
        permVar = groupByVars{vi};
        break;
    end
end

if isempty(permVar)
    error('exploreFNIRS:stats:clusterPermutation', ...
        'No suitable grouping variable found for permutation.');
end

% Get unique subjects and their condition assignments
if ismember('SubjectID', mergedTable.Properties.VariableNames)
    subjects = unique(mergedTable.SubjectID);
else
    % Fall back: permute all rows
    subjects = {};
end

% Extract the dependent variable from the formula for replacement
formulaDV = strtrim(extractBefore(formula, '~'));

for iPerm = 1:nPerm
    % Shuffle condition labels
    rng(2019 + iPerm);
    permTable = shuffleLabels(mergedTable, permVar, subjects);

    % Re-fit models for all channels and extract statistics
    permStat = nan(1, nCh);
    for chI = 1:nCh
        ch = channels(chI);
        varName = sprintf('Opt%d_%s', ch, biomarker);

        if ~ismember(varName, permTable.Properties.VariableNames)
            continue;
        end

        try
            % Rewrite formula with this channel's dependent variable
            chFormula = strrep(formula, formulaDV, varName);

            mdl = fitlme(permTable, chFormula, ...
                'FitMethod', 'REML', 'CheckHessian', false);

            anv = anova(mdl, 'DFMethod', 'satterthwaite');
            termIdx = find(strcmp(anv.Term, termName), 1);
            if isempty(termIdx)
                % Try sanitized name match
                for ti = 1:height(anv)
                    cleanTerm = anv.Term{ti};
                    cleanTerm(cleanTerm == '(' | cleanTerm == ')') = '';
                    cleanTerm(cleanTerm == ':' | cleanTerm == '_') = '';
                    cleanTerm(cleanTerm == ' ' | cleanTerm == '-') = '';
                    if strcmp(cleanTerm, termName)
                        termIdx = ti;
                        break;
                    end
                end
            end

            if ~isempty(termIdx)
                fVal = anv.FStat(termIdx);
                tVal = sqrt(fVal);

                % Get sign from coefficient
                coeffs = mdl.Coefficients;
                termRows = strcmp(coeffs.Name, termName);
                if ~any(termRows)
                    % Try prefix match for categorical levels (e.g., 'Condition_2')
                    termRows = strncmp(coeffs.Name, termName, length(termName));
                end
                if any(termRows)
                    coefVal = coeffs.Estimate(find(termRows, 1));
                    if coefVal < 0
                        tVal = -tVal;
                    end
                end
                permStat(chI) = tVal;
            end
        catch
            % Skip failed models
        end
    end

    % Find clusters in permuted data
    permClusters = exploreFNIRS.stats.findClusters( ...
        permStat, adj, fThreshold, opts.ClusterStat, opts.Tail);

    % Record max cluster statistic
    if ~isempty(permClusters)
        allStats = [permClusters.stat];
        nullDist(iPerm) = max(abs(allStats));
    end

    if opts.Verbose && mod(iPerm, max(1, floor(nPerm/10))) == 0
        fprintf('  Permutation %d/%d\n', iPerm, nPerm);
    end
end

%% Compute cluster p-values
sigClusters = struct('channels', {}, 'stat', {}, 'pvalue', {}, ...
    'significant', {}, 'polarity', {});

for k = 1:length(observedClusters)
    cl = observedClusters(k);
    pval = mean(nullDist >= abs(cl.stat));
    cl.pvalue = pval;
    cl.significant = pval < opts.Alpha;

    % Map cluster channel indices back to original channel numbers
    cl.channels = channels(cl.channels);

    if cl.significant
        sigClusters(end+1) = cl; %#ok<AGROW>
    end
end

% Also map allClusters back
allClusters = observedClusters;
for k = 1:length(allClusters)
    pval = mean(nullDist >= abs(allClusters(k).stat));
    allClusters(k).pvalue = pval;
    allClusters(k).significant = pval < opts.Alpha;
    allClusters(k).channels = channels(allClusters(k).channels);
end

%% Assemble output
results = struct();
results.clusters = sigClusters;
results.allClusters = allClusters;
results.adjacency = adjFull;
results.nullDist = nullDist;
results.observedStats = observedStat;
results.params = struct( ...
    'Permutations', nPerm, ...
    'ClusterAlpha', opts.ClusterAlpha, ...
    'Alpha', opts.Alpha, ...
    'MaxDistance', opts.MaxDistance, ...
    'ClusterStat', opts.ClusterStat, ...
    'Tail', opts.Tail);
results.biomarker = biomarker;
results.term = termName;

if opts.Verbose
    fprintf('\nCluster permutation complete.\n');
    fprintf('Significant clusters: %d (alpha=%.3f)\n', length(sigClusters), opts.Alpha);
    for k = 1:length(sigClusters)
        fprintf('  Cluster %d: channels [%s], stat=%.2f, p=%.4f\n', k, ...
            num2str(sigClusters(k).channels), sigClusters(k).stat, sigClusters(k).pvalue);
    end
end

end


%% Local helper functions

function threshold = getStatThreshold(fStats, pVals, alpha)
% Convert alpha threshold to a signed-statistic threshold.
% Uses the observed F/p relationship: find the F value closest to alpha.

validIdx = ~isnan(fStats) & ~isnan(pVals);
if ~any(validIdx)
    threshold = 2;  % Default fallback
    return;
end

fValid = fStats(validIdx);
pValid = pVals(validIdx);

% Find the F-value that corresponds to p=alpha by interpolation
% Sort by p-value
[pSorted, sortIdx] = sort(pValid);
fSorted = fValid(sortIdx);

% Find where p crosses alpha
crossIdx = find(pSorted <= alpha, 1, 'last');
if isempty(crossIdx)
    % No channels below alpha; use the minimum F as threshold
    threshold = sqrt(min(fValid));
elseif crossIdx == length(pSorted)
    threshold = sqrt(min(fSorted));
else
    % Interpolate between the two bracketing F values
    threshold = sqrt(fSorted(crossIdx));
end

end


function permTable = shuffleLabels(tbl, permVar, subjects)
% Shuffle condition labels across subjects (between-subject permutation)
% or within subjects (within-subject sign-flip).

permTable = tbl;

if isempty(subjects)
    % No subject structure: shuffle all labels
    idx = randperm(height(tbl));
    permTable.(permVar) = tbl.(permVar)(idx);
    return;
end

% Determine if design is within-subject or between-subject
% Within-subject: each subject has multiple levels of permVar
isWithin = false;
nSubjects = length(subjects);

if nSubjects > 1 && iscategorical(tbl.(permVar))
    levels = categories(tbl.(permVar));
    for si = 1:min(nSubjects, 5)  % Check first 5 subjects
        subRows = tbl.SubjectID == subjects(si);
        subLevels = unique(tbl.(permVar)(subRows));
        if length(subLevels) > 1
            isWithin = true;
            break;
        end
    end
end

if isWithin
    % Within-subject: permute condition labels within each subject
    for si = 1:nSubjects
        subRows = find(tbl.SubjectID == subjects(si));
        if isempty(subRows), continue; end

        % Random permutation of the condition labels for this subject
        subLabels = tbl.(permVar)(subRows);
        permTable.(permVar)(subRows) = subLabels(randperm(length(subLabels)));
    end
else
    % Between-subject: shuffle subject-to-condition assignment
    subjectConditions = cell(nSubjects, 1);
    for si = 1:nSubjects
        subRows = tbl.SubjectID == subjects(si);
        vals = unique(tbl.(permVar)(subRows));
        subjectConditions{si} = vals(1);
    end

    % Permute the assignment
    permIdx = randperm(nSubjects);
    permConditions = subjectConditions(permIdx);

    for si = 1:nSubjects
        subRows = find(tbl.SubjectID == subjects(si));
        permTable.(permVar)(subRows) = repmat(permConditions{si}, length(subRows), 1);
    end
end

end
