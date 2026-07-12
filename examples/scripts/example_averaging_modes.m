%% example_averaging_modes.m - Hierarchical vs Flat vs None Averaging
%
% This script demonstrates how the avgMode setting in the Experiment class
% controls within-subject data aggregation before group-level statistics
% and plotting. The three modes are:
%
%   'hierarchy'  - Averages bottom-up through hierarchy levels
%                  (Trial -> Condition -> Session -> Subject).
%                  Each subject contributes equally to the group mean,
%                  regardless of how many trials they have.
%                  ** Recommended for most analyses **
%
%   'flat'       - Averages all observations per subject into one value.
%                  Conditions and trials are pooled within each subject.
%                  Useful for a single "overall response" per subject.
%
%   'none'       - No within-subject averaging. Each trial/segment is
%                  treated as an independent observation. Preserves
%                  trial-level variability but risks pseudoreplication.
%
% The practical difference matters most when subjects contribute unequal
% numbers of trials or when within-subject variability is high.
%
% Requirements:
%   - processFNIRS2 on the MATLAB path
%   - Sample data: pf2.import.sampleData.fNIR2000()


%% ========================================================================
%  1. SETUP: BUILD SYNTHETIC MULTI-SUBJECT DATASET
%  ========================================================================

fprintf('=== 1. Setup ===\n');

raw = pf2.import.sampleData.fNIR2000();
processed = processFNIRS2(raw, ...
    'DPFmode', 'Calc', 'defaultSubjectAge', 25, ...
    'blLength', 10, 'blStartTime', 0);

% Inject synthetic markers: alternating Task (10) and Rest (20)
processed.markers = pf2_base.normalizeMarkers([
     60, 10, 0, 1;
    120, 20, 0, 1;
    180, 10, 0, 1;
    240, 20, 0, 1;
    300, 10, 0, 1;
    360, 20, 0, 1;
]);

blocks = pf2.data.defineBlocks(processed, ...
    'MarkerCode', [10, 20], 'Duration', 30, ...
    'ConditionMap', {10, 'Task'; 20, 'Rest'}, ...
    'Embed', false);
segments = pf2.data.extractBlocks(processed, blocks, ...
    'PreTime', 5, 'PostTime', 5, 'BaselineWindow', [-5, 0], 'SetT0', true);

% Build 6 subjects (3 Young, 3 Older) with subject-specific scaling
rng(42);
allSegments = {};
subjects = {'S01','S02','S03','S04','S05','S06'};
groups   = {'Young','Young','Young','Older','Older','Older'};
ages     = [22, 24, 21, 55, 60, 58];
scores   = [85, 92, 78, 70, 65, 72];

for s = 1:length(subjects)
    for i = 1:length(segments)
        seg = segments{i};
        seg.info.SubjectID = subjects{s};
        seg.info.Group     = groups{s};
        seg.info.Age       = ages(s);
        seg.info.Score     = scores(s) + randn * 5;

        noise = 0.05 * randn(size(seg.HbO));
        if strcmp(groups{s}, 'Older')
            seg.HbO = seg.HbO * 0.7 + noise;
            seg.HbR = seg.HbR * 0.8 - noise * 0.5;
        else
            seg.HbO = seg.HbO + noise;
            seg.HbR = seg.HbR - noise * 0.5;
        end
        allSegments{end+1} = seg; %#ok<SAGROW>
    end
end

fprintf('  Built: %d subjects x %d segments = %d total\n', ...
    length(subjects), length(segments), length(allSegments));


%% ========================================================================
%  2. HIERARCHY MODE (default)
%  ========================================================================
%
%  Hierarchical averaging prevents pseudoreplication by averaging within
%  each level before moving up:
%
%    Trial 1 ─┐                           Trial 1 ─┐
%    Trial 2 ─┼─> mean(S01, Task) ─┐     Trial 2 ─┼─> mean(S02, Task) ─┐
%    Trial 3 ─┘                    │                ─┘                   │
%                                  ├─> Group Mean                       │
%    Trial 1 ─┐                    │                                    ├─> ...
%    Trial 2 ─┼─> mean(S01, Rest) ─┘     ...                           │
%    Trial 3 ─┘                                                        ─┘
%
%  Each subject contributes equally, regardless of trial count.
%  Error bands reflect between-subject variability.

fprintf('\n=== 2. Hierarchy Mode ===\n');

ex = exploreFNIRS.core.Experiment(allSegments, ...
    'Hierarchy', {'SubjectID', 'Condition'});
ex.settings.baseline     = [-5, 0];
ex.settings.taskStart    = 0;
ex.settings.taskEnd      = 30;
ex.settings.resampleRate = 1;
ex.settings.barBinSize   = 0;
ex.settings.useBaseline  = true;

ex.select('Condition', {'Task', 'Rest'});
ex.groupby({'Group', 'Condition'});

% Aggregate with hierarchy mode
ex.aggregate('hierarchy');

fig1 = ex.plotTemporal('Biomarkers', {'HbO'}, 'Channels', 1:4, ...
    'Title', 'Hierarchy Mode: Temporal (error = between-subject SEM)');

fig2 = ex.plotBar('Biomarker', 'HbO', 'Channels', 1:4, ...
    'ShowIndividual', true, ...
    'Title', 'Hierarchy Mode: Bar Chart');

% The grand average has nSub = number of unique subjects per group.
% Error bands reflect how much subjects differ from each other.
fprintf('  Hierarchy: error bands reflect between-subject variability\n');
fprintf('  Each subject = one data point (mean of their trials)\n');


%% ========================================================================
%  3. FLAT MODE
%  ========================================================================
%
%  Flat mode averages everything within each subject into one value,
%  ignoring condition/trial structure:
%
%    Trial 1 (Task)  ─┐
%    Trial 2 (Task)  ─┤
%    Trial 3 (Task)  ─┼─> mean(S01, all) ─┐
%    Trial 1 (Rest)  ─┤                    ├─> Group Mean
%    Trial 2 (Rest)  ─┤                    │
%    Trial 3 (Rest)  ─┘   mean(S02, all) ─┘
%
%  Conditions are pooled within each subject. Useful when you want a
%  single "overall activation" per subject without condition structure.

fprintf('\n=== 3. Flat Mode ===\n');

ex.aggregate('flat');

fig3 = ex.plotTemporal('Biomarkers', {'HbO'}, 'Channels', 1:4, ...
    'Title', 'Flat Mode: Temporal (conditions pooled within subject)');

fig4 = ex.plotBar('Biomarker', 'HbO', 'Channels', 1:4, ...
    'ShowIndividual', true, ...
    'Title', 'Flat Mode: Bar Chart');

fprintf('  Flat: each subject''s trials pooled into one value\n');
fprintf('  Condition differences are averaged away within subjects\n');


%% ========================================================================
%  4. NONE MODE
%  ========================================================================
%
%  No within-subject averaging. Every segment is treated independently:
%
%    Trial 1 (S01, Task) ─┐
%    Trial 2 (S01, Task) ─┤
%    Trial 3 (S01, Task) ─┼─> Group Mean
%    Trial 1 (S02, Task) ─┤
%    Trial 2 (S02, Task) ─┤
%    Trial 3 (S02, Task) ─┘
%
%  More data points, but subjects with more trials have more influence.
%  Error bands reflect trial-to-trial + between-subject variability.
%
%  WARNING: Treats repeated measures as independent observations.
%  Use this for exploratory visualization, not statistical inference.

fprintf('\n=== 4. None Mode ===\n');

ex.aggregate('none');

fig5 = ex.plotTemporal('Biomarkers', {'HbO'}, 'Channels', 1:4, ...
    'Title', 'None Mode: Temporal (every trial independent)');

fig6 = ex.plotBar('Biomarker', 'HbO', 'Channels', 1:4, ...
    'ShowIndividual', true, ...
    'Title', 'None Mode: Bar Chart (more individual points)');

fprintf('  None: each trial is a separate observation\n');
fprintf('  Error bands reflect trial-level + between-subject variability\n');


%% ========================================================================
%  5. SIDE-BY-SIDE COMPARISON ON SCATTER PLOTS
%  ========================================================================
%
%  Scatter plots are where the difference is most visible: hierarchy
%  produces one point per subject, none shows every trial.

fprintf('\n=== 5. Scatter Plot Comparison ===\n');

% --- 5a: Hierarchy (one point per subject) ---
ex.reset();
ex.groupby({'Group'});
ex.aggregate('hierarchy');

fig7 = ex.plotScatter('Score', ...
    'Biomarkers', {'HbO'}, 'Channels', 1:4, ...
    'ErrorBand', true, 'ErrorBandType', '95%CI', ...
    'Title', 'Scatter (Hierarchy): 1 point per subject');

% --- 5b: None (one point per trial) ---
ex.aggregate('none');

fig8 = ex.plotScatter('Score', ...
    'Biomarkers', {'HbO'}, 'Channels', 1:4, ...
    'ErrorBand', true, 'ErrorBandType', '95%CI', ...
    'Title', 'Scatter (None): 1 point per trial');

fprintf('  Hierarchy scatter: %d subjects = %d points\n', ...
    length(subjects), length(subjects));
fprintf('  None scatter: %d subjects x %d segments = %d points\n', ...
    length(subjects), length(segments), length(allSegments));


%% ========================================================================
%  6. WHEN TO USE EACH MODE
%  ========================================================================
%
%  Choosing the right averaging mode depends on your analysis goal:
%
%  ┌──────────────┬────────────────────────────────────────────────────┐
%  │ Mode         │ Use when...                                       │
%  ├──────────────┼────────────────────────────────────────────────────┤
%  │ 'hierarchy'  │ Standard group analysis with repeated measures.   │
%  │ (default)    │ Prevents pseudoreplication. Required for valid    │
%  │              │ between-group statistics (t-tests, ANOVA, LME).   │
%  ├──────────────┼────────────────────────────────────────────────────┤
%  │ 'flat'       │ You want one value per subject, ignoring          │
%  │              │ conditions. Useful for overall activation level   │
%  │              │ or when conditions are not meaningful.            │
%  ├──────────────┼────────────────────────────────────────────────────┤
%  │ 'none'       │ Exploratory visualization of trial-level data.   │
%  │              │ DO NOT use for statistical inference without      │
%  │              │ accounting for repeated measures (e.g., use LME). │
%  └──────────────┴────────────────────────────────────────────────────┘
%
%  Key concept: pseudoreplication
%  ─────────────────────────────
%  If Subject A has 20 trials and Subject B has 5, 'none' mode gives
%  Subject A 4x the influence on the group mean. 'hierarchy' mode
%  gives both subjects equal weight by averaging trials first.
%
%  For LME models (plotLME / statsFitLME), the bar-chart data always
%  uses flat mode internally, and the LME formula handles repeated
%  measures via the random-effects term (1|SubjectID).

fprintf('\n=== Summary ===\n');
fprintf('  hierarchy: subject-level means first, then group mean (default)\n');
fprintf('  flat:      pool all trials per subject into one value\n');
fprintf('  none:      every trial is independent (exploratory only)\n');
