%% example_bids_to_csv.m - End-to-end benchmark recipe: directory in -> CSV out
%
% A single self-contained path from a folder of recordings to analysis-ready
% CSVs, using the one-call results-to-table helpers. This is the recipe to
% reach for when comparing pf2 against other toolboxes (Homer3, MNE-NIRS,
% Cedalion, AnalyzIR): import -> QC -> process (explicit ProcessingContext)
% -> block average AND GLM -> tidy per-subject/per-channel CSV.
%
% Covers:
%   1. Import a directory of recordings (SNIRF/BIDS tree or the bundled sample)
%   2. Programmatic QC (assess -> apply) with an explicit SCI threshold
%   3. Reproducible processing via an explicit pf2.ProcessingContext
%   4a. Block averaging  -> pf2.export.blockAvgToTable -> CSV
%   4b. First-level GLM  -> pf2.export.glmToTable      -> CSV
%   5. Group second level via GLMExperiment.groupStats -> CSV
%
% The output CSVs carry an S#_D# channel_label so channels can be matched
% across toolboxes.
%
% Requirements:
%   - processFNIRS2 on path
%   - Sample data via pf2.import.sampleData.experiment('blocks')
%
% See also: example_glm_analysis.m, pf2.export.blockAvgToTable,
%           pf2.export.glmToTable, exploreFNIRS.core.GLMExperiment/groupStats

outDir = tempname;            % swap for a real directory to keep the CSVs
if ~exist(outDir, 'dir'), mkdir(outDir); end
fprintf('Output directory: %s\n', outDir);

%% Step 1: Import a directory of recordings
%
% For a real SNIRF/BIDS dataset, point importDirectory at the tree:
%   allData = pf2.import.importDirectory('data/', '*.snirf', ...
%       'Dir1', 'Group', 'Filename', 'SubjectID');
% BIDS events.tsv sidecars are auto-loaded by importSNIRF. Here we use the
% bundled synthetic recordings (continuous, with Easy/Hard/Rest markers).

fprintf('\n=== Step 1: Import ===\n');
[subjects, blockDefs] = pf2.import.sampleData.experiment('blocks');
fprintf('  %d subjects, %d blocks each\n', numel(subjects), numel(blockDefs{1}));

[rawMethod, oxyMethod] = pf2_base.examples.addDemoPipelines();

%% Step 2: Reproducible processing context
%
% Always pass an explicit ProcessingContext for batch runs so the DPF mode,
% baseline, and methods are pinned regardless of any prior GUI/global state
% (a bare processFNIRS2(data) inherits the global PF2.dpf_mode).

fprintf('\n=== Step 2: Build ProcessingContext ===\n');
ctx = pf2.ProcessingContext( ...
    'RawMethod', rawMethod, ...      % motion correction + OD
    'OxyMethod', oxyMethod, ...      % Hb-stage filtering
    'DPFmode',   'Calc', ...         % age/wavelength-dependent DPF
    'blLength',  10);
fprintf('  Raw=%s  Oxy=%s  DPFmode=%s\n', rawMethod, oxyMethod, ctx.dpfMode);

%% Step 3: QC -> process -> epoch, per subject
%
% assess() flags bad channels (SCI 0.75 here); apply() writes them into the
% channel mask before processing. extractBlocks cuts the epochs used for the
% block-average table.

fprintf('\n=== Step 3: QC, process, epoch ===\n');
segments = {};
qcSubjects = cell(1, numel(subjects));   % QC-applied raw, reused by the GLM
for s = 1:numel(subjects)
    raw = subjects{s};

    % --- QC ---
    report = pf2.qc.pipeline.assess(raw, 'SCIThreshold', 0.75);
    raw    = pf2.qc.pipeline.apply(raw, report);
    qcSubjects{s} = raw;   % keep the QC-masked raw so the GLM sees the same masks

    % --- Process (explicit context; ctx.copy() per worker in a parfor) ---
    proc = processFNIRS2(raw, 'Context', ctx);

    % --- Epoch around the task conditions (blockDefs{s} is already a block
    %     array from sampleData.experiment('blocks')) ---
    seg    = pf2.data.extractBlocks(proc, blockDefs{s}, 'PreTime', 5, 'PostTime', 15, 'SetT0', true);
    segments = [segments, seg(:)']; %#ok<AGROW>
end
fprintf('  Collected %d epochs across %d subjects\n', numel(segments), numel(subjects));

% Parallel variant (independent context per worker; copy(), not '='):
%   parfor s = 1:numel(subjects)
%       c = ctx.copy();
%       proc = processFNIRS2(subjects{s}, 'Context', c);
%       ...
%   end

%% Step 4a: Block-average table -> CSV
fprintf('\n=== Step 4a: Block-average table ===\n');
baT = pf2.export.blockAvgToTable(segments);
baPath = fullfile(outDir, 'block_average.csv');
writetable(baT, baPath);
fprintf('  %d rows x %d cols -> %s\n', height(baT), width(baT), baPath);
fprintf('  Columns: %s\n', strjoin(baT.Properties.VariableNames, ', '));

%% Step 4b: First-level GLM table -> CSV
%
% GLMExperiment keeps the continuous recording intact and fits HRF-convolved
% regressors. glmToTable emits one row per (subject, channel, condition) with
% betas + t/p, in the same channel_label-keyed schema as blockAvgToTable.
%
% IMPORTANT (consistency): GLMExperiment.fit() REPROCESSES each subject from raw
% via the global (no-Context) path, passing only the raw/oxy method names -- it
% does not take a ProcessingContext. So to keep the two CSVs comparable we
% (a) build the GLM from the SAME QC-masked raw subjects the block-average path
% used (qcSubjects, so channel rejection matches), (b) hand it the SAME raw/oxy
% methods, and (c) pin the global DPF mode to match ctx before fitting.
%
% CAVEAT: only the method names and DPF *mode* are aligned to fit()'s global
% path. Other ctx settings -- blLength/blStartTime, SubjectAge, RejectLevel,
% FixedDPF, and PVC/PPF -- are NOT propagated (a ProcessingContext never writes
% globals back). They match here only because this ctx leaves them at their
% toolbox defaults (blLength=10 equals the default baseline). If you change any
% of them on ctx, mirror the same value into the global settings before fit()
% (or the block-average and GLM tables will silently diverge).

fprintf('\n=== Step 4b: First-level GLM table ===\n');
pf2.settings.dpf.setDPFmode(ctx.dpfMode);   % align the global DPF fit() will read
gx = exploreFNIRS.core.GLMExperiment(qcSubjects, blockDefs);
gx.settings.rawMethod = rawMethod;
gx.settings.oxyMethod = oxyMethod;
gx.glm.conditions = {'Easy', 'Hard'};
gx.fit();

glmT = pf2.export.glmToTable(gx);
glmPath = fullfile(outDir, 'glm_betas.csv');
writetable(glmT, glmPath);
fprintf('  %d rows x %d cols -> %s\n', height(glmT), width(glmT), glmPath);

%% Step 5: Group second level (one-sample t on betas) -> CSV
%
% groupStats is the standard second level: a one-sample t-test of first-level
% betas vs 0 per channel per condition with FDR correction. Lighter than the
% LME path (gx.statsFitLME) for the common one-beta-per-subject case.

fprintf('\n=== Step 5: Group stats ===\n');
grpT = gx.groupStats('Correction', 'fdr');
grpPath = fullfile(outDir, 'group_stats.csv');
writetable(grpT, grpPath);
fprintf('  %d rows x %d cols -> %s\n', height(grpT), width(grpT), grpPath);
nSig = sum(grpT.pval_corrected < 0.05);
fprintf('  %d channel-condition effects significant at FDR q<0.05\n', nSig);

fprintf('\n=== Recipe complete. CSVs in %s ===\n', outDir);
