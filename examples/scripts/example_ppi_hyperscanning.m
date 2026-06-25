%% example_ppi_hyperscanning.m - PPI hyperscanning: speaker-listener, HRV, triad
%
% Demonstrates psychophysiological interaction (PPI) analysis for
% hyperscanning study designs, using the generalized PPI (gPPI) engine in
% exploreFNIRS.connectivity.computePPI together with an external/cross-brain
% seed and triad-aware group aggregation.
%
% Covers:
%   1. Speaker -> listener cross-brain PPI: the speaker's brain signal is the
%      seed (via 'SeedData'); each listener's channels are tested for
%      condition-dependent coupling to the speaker.
%   2. HRV-derived PPI: an EKG-derived heart-rate-variability series is the
%      physiological seed (via 'SeedSignal'), built with pf2.data.aux.hrvSeries
%      and aligned onto the fNIRS grid with pf2.data.auxOnGrid.
%   3. Triad coupling: three simultaneously recorded participants aggregated
%      with pairSubjects('GroupSize', 3) + computeGroup, which expands the
%      triad into its pairwise sub-dyads and runs inference across independent
%      groups.
%   4. Group-level PPI modeling: carry each subject's first-level PPI contrast
%      to a group model with GLMExperiment.ppiTable (tidy subject x channel
%      table) and ppiLME (pooled LME PPI ~ Group + (1|SubjectID) plus a
%      per-channel map ready for pf2.probe.project).
%
% PPI primer: gPPI fits, per target channel, a GLM with (a) one HRF task
% regressor per condition, (b) the seed time course, and (c) one
% seed x condition interaction per condition. The effect of interest is a
% contrast across the interaction terms (e.g. TaskA vs TaskB), i.e. does
% seed->target coupling change with task context.
%
% Requirements:
%   - processFNIRS2 on path
%   - Sample data available via pf2.import.sampleData.fNIR2000()
%
% NOTE: this script SYNTHESIZES a speaker/listeners set, an EKG signal, and a
% triad from the single-subject sample recording so it is self-contained and
% runnable. Replace the synthetic blocks with your own imported recordings.

% Uncomment to save figures instead of displaying them:
% outDir = '/tmp/ppi_hyperscanning_examples';
% if ~exist(outDir, 'dir'), mkdir(outDir); end

%% Step 0: Process the sample recording and define two task conditions
fprintf('=== Step 0: Process sample data, define blocks ===\n');

data = pf2.import.sampleData.fNIR2000();   % synthesized TaskA/TaskB markers
proc = processFNIRS2(data);

codes  = unique(proc.markers.Code).';
blocks = pf2.data.defineBlocks(proc, codes(1:2), 20, ...
    'ConditionMap', {codes(1), 'TaskA'; codes(2), 'TaskB'}, 'Embed', false);
fprintf('Defined %d blocks (TaskA/TaskB).\n', numel(blocks));

%% Step 1: Speaker -> listener cross-brain PPI
% One recorded speaker, several listeners. The speaker's prefrontal channels
% are the seed; we ask whether each listener's channels couple to the speaker
% more during TaskA than TaskB. The speaker is passed via 'SeedData' so no
% channel-splicing hack is needed -- the seed comes from a *different* brain.
fprintf('\n=== Step 1: Speaker -> listener cross-brain PPI ===\n');

speaker   = proc;                                  % the recorded speaker
listeners = {addJitter(proc, 1), addJitter(proc, 2), addJitter(proc, 3)};
seedCh    = 1:3;                                   % speaker seed channels

listenerPPI = cell(1, numel(listeners));
for L = 1:numel(listeners)
    r = exploreFNIRS.connectivity.computePPI(listeners{L}, blocks, seedCh, ...
        'SeedData', speaker, 'Contrast', {'TaskA', 'TaskB'}, 'Biomarker', 'HbO');
    listenerPPI{L} = r;
    fprintf('  Listener %d: seedSource=%s, mean PPI beta=%+.4g, %d/%d ch p<.05\n', ...
        L, r.seedSource, mean(r.ppi_beta), nnz(r.ppi_pval < 0.05), numel(r.ppi_pval));
end

% Group the listeners' PPI contrast maps (one-sample across listeners).
betaCell  = cellfun(@(r) r.ppi_beta, listenerPPI, 'UniformOutput', false);
betaStack = cat(1, betaCell{:});
[~, pGroup] = ttest(betaStack);
fprintf('  Listener-group PPI: %d/%d channels significant (p<.05, uncorrected)\n', ...
    nnz(pGroup < 0.05), numel(pGroup));

%% Step 2: HRV-derived PPI (EKG -> HRV -> physiological seed)
% Here the psychophysiological term is cardiac: an EKG-derived RMSSD series.
% pf2.data.aux.hrvSeries gives a time-resolved HRV signal; addFeature stores
% it as a typed aux signal; auxOnGrid aligns it to the fNIRS grid; then it is
% the PPI seed via 'SeedSignal'.
fprintf('\n=== Step 2: HRV-derived PPI ===\n');

% Synthesize an EKG waveform for this subject (replace with your real EKG aux).
fsEKG = 200;
tEKG  = (0:1/fsEKG:proc.time(end)).';
beats = synthBeats(proc.time(end));
ekg   = zeros(size(tEKG));
for k = 1:numel(beats)
    ekg = ekg + exp(-0.5 * ((tEKG - beats(k)) / 0.02).^2);   % QRS-like peaks
end

hrv = pf2.data.aux.hrvSeries(ekg, fsEKG, 'Window', 30, 'Step', 5, ...
    'Metric', {'RMSSD', 'meanHR'});
fprintf('  hrvSeries: %d windows, RMSSD median=%.1f ms\n', ...
    numel(hrv.time), median(hrv.RMSSD, 'omitnan'));

procHRV = pf2.data.aux.addFeature(proc, 'hrvRMSSD', hrv.RMSSD, ...
    'Time', hrv.time, 'Unit', 'ms');
hrvGrid = pf2.data.auxOnGrid(procHRV, 'hrvRMSSD');         % [T x 1] on fNIRS grid

rHRV = exploreFNIRS.connectivity.computePPI(proc, blocks, [], ...
    'SeedSignal', hrvGrid, 'Contrast', {'TaskA', 'TaskB'}, 'Biomarker', 'HbO');
fprintf('  HRV-seed PPI: seedSource=%s, %d/%d channels p<.05\n', ...
    rHRV.seedSource, nnz(rHRV.ppi_pval < 0.05), numel(rHRV.ppi_pval));

%% Step 3: Triad coupling (three participants at once)
% Three simultaneously recorded participants. pairSubjects with 'GroupSize', 3
% forms the triad; computeGroup expands it into the AB/AC/BC pairwise
% sub-dyads, averages within the triad, and runs inference across independent
% triads (here just one, so results are exploratory).
fprintf('\n=== Step 3: Triad coupling ===\n');

triad = { tagSubject(addJitter(proc, 4), 'T1', 'A'), ...
          tagSubject(addJitter(proc, 5), 'T1', 'B'), ...
          tagSubject(addJitter(proc, 6), 'T1', 'C') };
pairs = exploreFNIRS.hyperscanning.pairSubjects(triad, 'GroupSize', 3);
grp   = exploreFNIRS.hyperscanning.computeGroup(triad, pairs, ...
    'Method', 'pearson', 'Biomarker', 'HbO');
fprintf('  Triad: %d sub-dyads (%s), %d independent group(s), mean r=%.3f\n', ...
    numel(grp.dyads), strjoin(grp.dyadIDs, ', '), grp.N(1), grp.groupMeans(1));

%% Step 4: Group-level modeling of the PPI (between-group LME)
% With a cohort of subjects, each subject's first-level PPI contrast beta is a
% second-level observation. GLMExperiment.ppiTable reshapes them into a tidy
% subject x channel table (the bridge artifact); ppiLME fits a pooled mixed
% model (PPI ~ Group + Channel + (1|SubjectID)) and a per-channel second-level
% map whose F/p tables feed pf2.probe.project directly.
fprintf('\n=== Step 4: Group-level PPI modeling (LME) ===\n');

% TaskA boxcar -> a seed x TaskA term we can inject so a group effect exists.
taskA = zeros(numel(proc.time), 1);
for b = 1:numel(blocks)
    if strcmp(blocks(b).info.Condition, 'TaskA')
        m = proc.time >= blocks(b).startTime & ...
            proc.time < blocks(b).startTime + blocks(b).duration;
        taskA(m) = 1;
    end
end
seed0    = mean(proc.HbO(:,1:3), 2);
seedTerm = (seed0 - mean(seed0)) .* taskA;

% Build a two-group cohort (Patient/Control). Patients get an injected
% seed->target coupling during TaskA, so the PPI should differ by group.
cohort = {}; cohortBlocks = {};
for s = 1:6
    d = addJitter(proc, 10 + s);
    grpLabel = 'Control';
    if s <= 3
        grpLabel = 'Patient';
        d.HbO = d.HbO + 0.8 * seedTerm;
    end
    d.info = struct('SubjectID', sprintf('P%02d', s), 'Group', grpLabel);
    cohort{end+1} = d;            %#ok<SAGROW>
    cohortBlocks{end+1} = blocks; %#ok<SAGROW>
end
gx = exploreFNIRS.core.GLMExperiment(cohort, cohortBlocks);

% Tidy long table of per-subject PPI contrast betas + subject covariates
Tppi = gx.ppiTable(1:3, 'Contrast', {'TaskA','TaskB'}, 'Covariates', {'Group'});
fprintf('  ppiTable: %d rows (%d subjects x %d channels)\n', ...
    height(Tppi), numel(unique(string(Tppi.SubjectID))), ...
    numel(unique(string(Tppi.Channel))));

% Pooled group LME + per-channel second-level map
ppiRes = gx.ppiLME(1:3, 'Contrast', {'TaskA','TaskB'}, 'Predictors', {'Group'}, ...
    'Verbose', false);
disp(ppiRes.anova);
gpval = ppiRes.anova_pval.Group(:)';     % [1 x nCh] per-channel Group p-values
fprintf('  Per-channel Group effect: %d/%d channels p<.05\n', ...
    nnz(gpval < 0.05), numel(gpval));

% The per-channel F map drops straight into the brain-projection bridge
% (needs a montage with MNI coordinates; commented out for headless runs):
%   pf2.probe.project.fstats(ppiRes.anova_Fstat.Group', cohort{1}, ...
%       'savePath', 'ppi_group_F.png');

fprintf('\n=== Done ===\n');

%% Local helpers (synthetic-data construction only)
function d = addJitter(d, seedval)
    % Add small reproducible noise so synthetic "subjects" are not identical.
    rng(seedval);
    d.HbO = d.HbO + 0.02 * std(d.HbO(:)) * randn(size(d.HbO));
    d.HbR = d.HbR + 0.02 * std(d.HbR(:)) * randn(size(d.HbR));
end

function d = tagSubject(d, dyadID, role)
    d.info.DyadID    = dyadID;
    d.info.Role      = role;
    d.info.SubjectID = [dyadID '_' role];
end

function bt = synthBeats(tEnd)
    % Beat onset times with a slowly varying RR interval.
    rng(0);
    bt = []; t = 0;
    while t < tEnd
        bt(end+1) = t; %#ok<AGROW>
        t = t + 0.85 + 0.04 * sin(2*pi*0.02*t) + 0.01 * randn;
    end
end
