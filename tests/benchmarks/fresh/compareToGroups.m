% COMPARETOGROUPS Compare pf2 pipeline results against FRESH group outcomes
%
% For each pipeline archetype from the FRESH study, runs the closest pf2
% equivalent and compares hypothesis pass/fail outcomes against the
% published group results. This measures processing symmetry — how closely
% pf2 replicates findings when using equivalent preprocessing steps.
%
% Covers both datasets:
%   Dataset I (Auditory): Group-level binary outcomes (H1-H7)
%   Dataset II (Motor): Individual-level pass rates (H1-H4)
%
% Comparison metrics:
%   1. Per-hypothesis agreement with FRESH consensus
%   2. Per-hypothesis agreement with specific group that used same pipeline
%   3. Overall concordance rate across all hypotheses
%   4. Sorensen-Dice similarity coefficient (like FRESH paper uses)
%   5. Per-participant pass rate correlation (Dataset II)
%
% See also: benchmarks.fresh.groundTruth, benchmarks.fresh.runDatasetI,
%           benchmarks.fresh.runDatasetII

fprintf('\n=== FRESH Processing Symmetry Comparison ===\n');
fprintf('Started: %s\n\n', datetime('now'));

% --- Setup ---
scriptDir = fileparts(mfilename('fullpath'));
benchmarkRoot = fileparts(scriptDir);
resultsDir = fullfile(benchmarkRoot, 'results');

gt = groundTruth();

% --- Check if benchmark results exist ---
dsIdir = fullfile(resultsDir, 'datasetI');
if ~isfolder(dsIdir)
    fprintf('No Dataset I results found at %s\n', dsIdir);
    fprintf('Run runDatasetI.m first.\n');
    return;
end

% --- Load pf2 pipeline results ---
pipeDirs = dir(dsIdir);
pipeDirs = pipeDirs([pipeDirs.isdir] & ~startsWith({pipeDirs.name}, '.'));
nPipelines = length(pipeDirs);

fprintf('Found %d pf2 pipeline results.\n\n', nPipelines);

pf2Results = struct();
for p = 1:nPipelines
    pipeName = pipeDirs(p).name;
    groupFile = fullfile(dsIdir, pipeName, 'group_results.mat');

    if ~isfile(groupFile)
        continue;
    end

    try
        loaded = load(groupFile, 'groupResult');
        gr = loaded.groupResult;

        if isfield(gr, 'hypotheses') && ~isempty(gr.hypotheses)
            h = zeros(1, 7);
            for hi = 1:min(7, length(gr.hypotheses))
                h(hi) = gr.hypotheses(hi).pass;
            end
            pf2Results.(pipeName).hypotheses = h;
            pf2Results.(pipeName).nSubjects = gr.nSubjects;
        end
    catch
    end
end

pf2Names = fieldnames(pf2Results);
nPf2 = length(pf2Names);

if nPf2 == 0
    fprintf('No pipeline results with hypothesis tests found.\n');
    return;
end

%% === Comparison 1: Agreement with FRESH Consensus ===
fprintf('========================================\n');
fprintf('  1. Agreement with FRESH Consensus\n');
fprintf('========================================\n\n');

consensus = gt.study1.consensus;
rates = gt.study1.rates;

fprintf('  FRESH Consensus (majority vote of %d groups):\n', gt.study1.nGroups);
for h = 1:7
    if consensus(h)
        cStr = 'Yes';
    else
        cStr = 'No';
    end
    fprintf('    %s: %s (%.0f%% agreement)\n', ...
        gt.study1.hypothesisNames{h}, cStr, rates(h)*100);
end
fprintf('\n');

fprintf('  %-30s', 'pf2 Pipeline');
for h = 1:7
    fprintf(' %4s', sprintf('H%d', h));
end
fprintf(' %6s %6s\n', 'Match', 'Dice');
fprintf('  %s\n', repmat('-', 1, 72));

for p = 1:nPf2
    pipeName = pf2Names{p};
    pf2H = pf2Results.(pipeName).hypotheses;

    fprintf('  %-30s', pipeName(1:min(30, end)));
    nMatch = 0;
    for h = 1:7
        if pf2H(h) == consensus(h)
            fprintf('  %3s', 'ok');
            nMatch = nMatch + 1;
        else
            fprintf('  %3s', 'X');
        end
    end

    matchRate = nMatch / 7 * 100;

    % Sorensen-Dice coefficient (treating Yes=1, No=0 as binary vectors)
    dice = sorensenDice(pf2H, consensus);

    fprintf(' %5.0f%% %5.2f\n', matchRate, dice);
end

%% === Comparison 2: Agreement with Specific FRESH Groups ===
fprintf('\n========================================\n');
fprintf('  2. Per-Group Pipeline Comparison\n');
fprintf('========================================\n\n');

% For each FRESH group, find matching pf2 pipeline and compare hypotheses
for gi = 1:length(gt.groupPipelines)
    grp = gt.groupPipelines(gi);
    groupID = grp.id;

    % Find this group in Study 1 results
    gIdx = find(gt.study1.groupIDs == groupID);
    if isempty(gIdx)
        continue;
    end
    groupH = gt.study1.hypotheses(gIdx, :);

    % Skip groups with all NaN results
    if all(isnan(groupH))
        continue;
    end

    % Find matching pf2 results
    matchNames = {};
    if ~isempty(grp.pf2Name) && isfield(pf2Results, grp.pf2Name)
        matchNames{end+1} = grp.pf2Name;
    end
    if ~isempty(grp.pf2GLMName) && isfield(pf2Results, grp.pf2GLMName)
        matchNames{end+1} = grp.pf2GLMName;
    end

    if isempty(matchNames)
        continue;  % skip groups with no matching pf2 results
    end

    fprintf('  Group %d [%s]: %s | %s | SSR=%d\n', ...
        groupID, grp.toolbox, grp.motion, grp.filter, grp.ssr);
    if ~isempty(grp.gap)
        fprintf('    NOTE: %s\n', grp.gap);
    end

    fprintf('    FRESH results:  ');
    for h = 1:7
        if isnan(groupH(h))
            fprintf(' -');
        elseif groupH(h)
            fprintf(' Y');
        else
            fprintf(' N');
        end
    end
    fprintf('\n');

    % Compare each matching pf2 pipeline
    for mi = 1:length(matchNames)
        pf2H = pf2Results.(matchNames{mi}).hypotheses;
        fprintf('    pf2 %-22s: ', matchNames{mi});
        nMatch = 0;
        nCompared = 0;
        for h = 1:7
            if isnan(groupH(h))
                fprintf(' -');
            elseif pf2H(h) == groupH(h)
                fprintf(' =');
                nMatch = nMatch + 1;
                nCompared = nCompared + 1;
            else
                fprintf(' X');
                nCompared = nCompared + 1;
            end
        end
        if nCompared > 0
            fprintf('  (%d/%d match)\n', nMatch, nCompared);
        else
            fprintf('  (no comparable results)\n');
        end
    end
    fprintf('\n');
end

%% === Comparison 3: Overall Summary ===
fprintf('========================================\n');
fprintf('  3. Overall Summary\n');
fprintf('========================================\n\n');

fprintf('  FRESH paper reported ~80%% group-level agreement.\n');
fprintf('  pf2 concordance with FRESH consensus:\n\n');

bestMatch = 0;
bestPipe = '';

for p = 1:nPf2
    pipeName = pf2Names{p};
    pf2H = pf2Results.(pipeName).hypotheses;
    nMatch = sum(pf2H == consensus);
    matchRate = nMatch / 7 * 100;
    dice = sorensenDice(pf2H, consensus);

    fprintf('    %-30s  %d/7 (%.0f%%)  Dice=%.2f\n', ...
        pipeName(1:min(30, end)), nMatch, matchRate, dice);

    if matchRate > bestMatch
        bestMatch = matchRate;
        bestPipe = pipeName;
    end
end

fprintf('\n  Best performing pipeline: %s (%.0f%% match)\n', bestPipe, bestMatch);

%% === Dataset II (Motor): Per-Participant Comparison ===
fprintf('\n\n');
fprintf('%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%\n');
fprintf('  DATASET II (Motor) COMPARISON\n');
fprintf('%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%\n\n');

dsIIdir = fullfile(resultsDir, 'datasetII');
if ~isfolder(dsIIdir)
    fprintf('No Dataset II results found at %s\n', dsIIdir);
    fprintf('Run runDatasetII.m first.\n');
else

% --- Load pf2 Dataset II pipeline results ---
pipeDirsII = dir(dsIIdir);
pipeDirsII = pipeDirsII([pipeDirsII.isdir] & ~startsWith({pipeDirsII.name}, '.'));
nPipelinesII = length(pipeDirsII);

fprintf('Found %d pf2 Dataset II pipeline results.\n\n', nPipelinesII);

pf2ResultsII = struct();
for p = 1:nPipelinesII
    pipeName = pipeDirsII(p).name;
    groupFile = fullfile(dsIIdir, pipeName, 'group_results.mat');

    if ~isfile(groupFile)
        continue;
    end

    try
        loaded = load(groupFile, 'groupResult');
        gr = loaded.groupResult;

        if isfield(gr, 'hypotheses') && ~isempty(gr.hypotheses)
            h = NaN(1, 4);
            for hi = 1:min(4, length(gr.hypotheses))
                if isfield(gr.hypotheses(hi), 'passRate')
                    h(hi) = gr.hypotheses(hi).passRate;
                elseif isfield(gr.hypotheses(hi), 'pass')
                    h(hi) = gr.hypotheses(hi).pass;
                end
            end
            pf2ResultsII.(pipeName).passRates = h;
            pf2ResultsII.(pipeName).nSubjects = gr.nSubjects;
        end
    catch
    end
end

pf2NamesII = fieldnames(pf2ResultsII);
nPf2II = length(pf2NamesII);

if nPf2II == 0
    fprintf('No Dataset II pipeline results with hypothesis tests found.\n');
else

%% === DS-II Comparison 1: Pass Rate vs FRESH Mean ===
fprintf('========================================\n');
fprintf('  4. Dataset II: Pass Rates vs FRESH Mean\n');
fprintf('========================================\n\n');

fprintf('  FRESH Mean Pass Rates (across %d groups):\n', gt.study2.nGroups);
for h = 1:4
    fprintf('    %s: %.0f%%\n', ...
        gt.study2.hypothesisNames{h}, gt.study2.meanRates(h)*100);
end
fprintf('\n');

fprintf('  %-30s', 'pf2 Pipeline');
for h = 1:4
    fprintf(' %6s', sprintf('H%d', h));
end
fprintf(' %8s\n', 'MeanDiff');
fprintf('  %s\n', repmat('-', 1, 62));

for p = 1:nPf2II
    pipeName = pf2NamesII{p};
    pf2H = pf2ResultsII.(pipeName).passRates;

    fprintf('  %-30s', pipeName(1:min(30, end)));
    diffs = [];
    for h = 1:4
        if ~isnan(pf2H(h))
            fprintf(' %5.0f%%', pf2H(h)*100);
            if ~isnan(gt.study2.meanRates(h))
                diffs(end+1) = abs(pf2H(h) - gt.study2.meanRates(h));
            end
        else
            fprintf(' %6s', '-');
        end
    end
    if ~isempty(diffs)
        fprintf(' %7.1f%%', mean(diffs)*100);
    else
        fprintf(' %8s', '-');
    end
    fprintf('\n');
end

%% === DS-II Comparison 2: Agreement with Specific Groups ===
fprintf('\n========================================\n');
fprintf('  5. Dataset II: Per-Group Comparison\n');
fprintf('========================================\n\n');

for gi = 1:length(gt.groupPipelines)
    grp = gt.groupPipelines(gi);
    groupID = grp.id;

    % Find this group in Study 2 results
    gIdx = find(gt.study2.groupIDs == groupID);
    if isempty(gIdx)
        continue;
    end
    groupRates = gt.study2.passRates(gIdx, :);
    if all(isnan(groupRates))
        continue;
    end

    % Find matching pf2 results
    matchNamesII = {};
    if ~isempty(grp.pf2Name) && isfield(pf2ResultsII, grp.pf2Name)
        matchNamesII{end+1} = grp.pf2Name;
    end
    if ~isempty(grp.pf2GLMName) && isfield(pf2ResultsII, grp.pf2GLMName)
        matchNamesII{end+1} = grp.pf2GLMName;
    end

    if isempty(matchNamesII)
        continue;
    end

    fprintf('  Group %d [%s | %s]: ', groupID, grp.motion, grp.filter);
    fprintf('FRESH rates:');
    for h = 1:4
        if isnan(groupRates(h))
            fprintf(' %5s', '-');
        else
            fprintf(' %4.0f%%', groupRates(h)*100);
        end
    end
    fprintf('\n');

    for mi = 1:length(matchNamesII)
        pf2H = pf2ResultsII.(matchNamesII{mi}).passRates;
        fprintf('    pf2 %-22s: ', matchNamesII{mi});
        diffs = [];
        for h = 1:4
            if isnan(groupRates(h)) || isnan(pf2H(h))
                fprintf(' %5s', '-');
            else
                diff = abs(pf2H(h) - groupRates(h));
                diffs(end+1) = diff;
                if diff <= 0.10
                    fprintf(' %4.0f%%', pf2H(h)*100);
                else
                    fprintf(' [%2.0f]', pf2H(h)*100);
                end
            end
        end
        if ~isempty(diffs)
            fprintf('  (mean diff: %.0f%%)\n', mean(diffs)*100);
        else
            fprintf('  (no comparable results)\n');
        end
    end
    fprintf('\n');
end

%% === DS-II Comparison 3: Overall Summary ===
fprintf('========================================\n');
fprintf('  6. Dataset II: Overall Summary\n');
fprintf('========================================\n\n');

fprintf('  FRESH paper reported high individual-level variability.\n');
fprintf('  pf2 pass rate deviation from FRESH group means:\n\n');

bestDiffII = Inf;
bestPipeII = '';

for p = 1:nPf2II
    pipeName = pf2NamesII{p};
    pf2H = pf2ResultsII.(pipeName).passRates;

    validH = ~isnan(pf2H) & ~isnan(gt.study2.meanRates);
    if ~any(validH)
        continue;
    end

    meanDiff = mean(abs(pf2H(validH) - gt.study2.meanRates(validH)));
    r = corrcoef(pf2H(validH), gt.study2.meanRates(validH));
    if numel(r) > 1
        rval = r(1,2);
    else
        rval = NaN;
    end

    fprintf('    %-30s  MeanDiff=%.0f%%  r=%.2f\n', ...
        pipeName(1:min(30, end)), meanDiff*100, rval);

    if meanDiff < bestDiffII
        bestDiffII = meanDiff;
        bestPipeII = pipeName;
    end
end

if ~isempty(bestPipeII)
    fprintf('\n  Closest to FRESH mean: %s (%.0f%% avg deviation)\n', ...
        bestPipeII, bestDiffII*100);
end

end  % nPf2II > 0
end  % isfolder(dsIIdir)

fprintf('\n=== Comparison Complete ===\n');
fprintf('Finished: %s\n', datetime('now'));

%%_Subfunctions_________________________________________________________

function d = sorensenDice(a, b)
% SORENSENDICE Compute Sorensen-Dice similarity coefficient
%
% For two binary vectors a and b:
%   Dice = 2 * |a AND b| / (|a| + |b|)
%
% Range: 0 (no overlap) to 1 (identical)

a = logical(a);
b = logical(b);
intersection = sum(a & b);
d = 2 * intersection / (sum(a) + sum(b));
if isnan(d)
    d = 0;
end

end
