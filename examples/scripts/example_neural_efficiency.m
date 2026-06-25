%% example_neural_efficiency.m - Neural efficiency plots
%
% This script demonstrates neural efficiency visualizations, which plot
% brain activation (X) against behavioral performance (Y) on z-scored
% axes. The y=x identity line separates "efficient" subjects (high
% performance with low activation, above the line) from "inefficient"
% subjects (high activation relative to performance, below the line).
%
% Two interfaces are covered:
%
%   1. Experiment wrapper (plotNeuralEfficiency)
%      - Works with Experiment groups after aggregate()
%      - Extracts biomarker and info variables automatically
%
%   2. Table-based (plotNeuralEfficiencyFromTable)
%      - Accepts a MATLAB table with X, Y, Group, and Subgroup columns
%      - Full control over grouping and arrow chains
%
% Sections:
%   1. Setup: build a synthetic multi-condition dataset
%   2. Basic usage via Experiment wrapper
%   3. Z-score modes: pooled vs per-group
%   4. Arrows between condition centroids
%   5. Table-based plots with Group + Subgroup
%   6. Customization: labels, fit lines, axis reversal
%
% Requirements:
%   - processFNIRS2 on the MATLAB path
%   - Sample data: pf2.import.sampleData.fNIR2000()


%% ========================================================================
%  1. SETUP: BUILD SYNTHETIC MULTI-CONDITION DATASET
%  ========================================================================
%
%  We create a dataset with two groups (HC, Clinical), two conditions
%  (Easy, Hard), and a behavioral score per subject. The Clinical group
%  has higher activation and lower scores, mimicking a neural efficiency
%  difference.

fprintf('=== 1. Setup ===\n');

raw = pf2.import.sampleData.fNIR2000();
processed = processFNIRS2(raw, ...
    'DPFmode', 'Calc', 'defaultSubjectAge', 25, ...
    'blLength', 10, 'blStartTime', 0);

% Inject synthetic markers: Easy (10) and Hard (20)
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
    'ConditionMap', {10, 'Easy'; 20, 'Hard'}, ...
    'Embed', false);
segments = pf2.data.extractBlocks(processed, blocks, ...
    'PreTime', 5, 'PostTime', 15, ...
    'BaselineWindow', [-5, 0], 'SetT0', true);

% Build 8 subjects: 4 HC, 4 Clinical
rng(42);
allSegments = {};
subjects = {'S01','S02','S03','S04','S05','S06','S07','S08'};
groups   = {'HC','HC','HC','HC','Clinical','Clinical','Clinical','Clinical'};

% HC: higher scores, lower activation
% Clinical: lower scores, higher activation
baseScores   = [88, 92, 85, 90,   65, 70, 60, 72];
scorePenalty  = [2,  3,  2,  3,    5,  6,  4,  7];   % Hard reduces score
activationMul = [1,  1,  1,  1,  1.5, 1.4, 1.6, 1.3]; % Clinical = more activation

for s = 1:length(subjects)
    for i = 1:length(segments)
        seg = segments{i};
        seg.info.SubjectID = subjects{s};
        seg.info.Group     = groups{s};

        % Condition-dependent score
        if strcmp(seg.info.Condition, 'Hard')
            seg.info.Score = baseScores(s) - scorePenalty(s) + randn * 2;
        else
            seg.info.Score = baseScores(s) + randn * 2;
        end

        % Group-dependent activation scaling
        noise = 0.03 * randn(size(seg.HbO));
        seg.HbO = seg.HbO * activationMul(s) + noise;
        seg.HbR = seg.HbR * activationMul(s) - noise * 0.3;

        % Hard condition: boost activation
        if strcmp(seg.info.Condition, 'Hard')
            seg.HbO = seg.HbO * 1.3;
        end

        allSegments{end+1} = seg; %#ok<SAGROW>
    end
end

% Create Experiment
ex = exploreFNIRS.core.Experiment(allSegments, ...
    'Hierarchy', {'SubjectID', 'Condition'});
ex.settings.baseline     = [-5, 0];
ex.settings.taskStart    = 0;
ex.settings.taskEnd      = 30;
ex.settings.resampleRate = 1;
ex.settings.barBinSize   = 0;
ex.settings.useBaseline  = true;
ex.settings.avgMode      = 'flat';

fprintf('  Built dataset: %d subjects, %d segments\n', ...
    length(subjects), length(allSegments));


%% ========================================================================
%  2. BASIC USAGE VIA EXPERIMENT WRAPPER
%  ========================================================================
%
%  The simplest call: group by diagnosis and plot HbO (X) vs Score (Y).
%  Points above the identity line are "neurally efficient" — high
%  performance with relatively low activation.

fprintf('\n=== 2. Basic Neural Efficiency Plot ===\n');

ex.reset();
ex.select('Condition', {'Easy'});
ex.groupby({'Group'});
ex.aggregate();

% Basic plot: HbO (X) vs Score (Y), averaged across channels 1-5
[fig1, stats1] = ex.plotNeuralEfficiency('Score', ...
    'Channels', 1:5, 'Averaging', 'flat');

for si = 1:length(stats1)
    fprintf('  %s: r=%.2f, p=%.3f, N=%d\n', ...
        stats1(si).label, stats1(si).r, stats1(si).p, stats1(si).N);
end


%% ========================================================================
%  3. Z-SCORE MODES: POOLED VS PER-GROUP
%  ========================================================================
%
%  'pooled' (default): z-score using the combined mean/std across all
%  groups. Groups are directly comparable on the same scale.
%
%  'pergroup': z-score each group independently. Shows within-group
%  patterns when groups have very different baselines.

fprintf('\n=== 3. Z-Score Modes ===\n');

ex.reset();
ex.select('Condition', {'Easy'});
ex.groupby({'Group'});
ex.aggregate();

% 3a: Pooled (default) — HC and Clinical on the same z-scale
[fig2a, ~] = ex.plotNeuralEfficiency('Score', ...
    'Channels', 1:5, 'Averaging', 'flat', ...
    'Title', 'Pooled z-scoring (default)');

% 3b: Per-group — each group centered at its own zero
[fig2b, ~] = ex.plotNeuralEfficiency('Score', ...
    'Channels', 1:5, 'Averaging', 'flat', ...
    'ZScoreMode', 'pergroup', ...
    'Title', 'Per-group z-scoring');


%% ========================================================================
%  4. ARROWS BETWEEN CONDITION CENTROIDS
%  ========================================================================
%
%  When groups represent ordered levels (e.g., Easy -> Hard), arrows
%  connect group centroids to show the trajectory of change. The groups
%  are connected in their array order.

fprintf('\n=== 4. Arrows Between Conditions ===\n');

% Group by Condition (ordered: Easy, then Hard)
ex.reset();
ex.select('Group', {'HC'});
ex.groupby({'Condition'});
ex.aggregate();

% Arrows show Easy -> Hard trajectory for HC subjects
[fig3, ~] = ex.plotNeuralEfficiency('Score', ...
    'Channels', 1:5, 'Averaging', 'flat', ...
    'ShowArrows', true, ...
    'FitLine', true, ...
    'Title', 'HC: Easy -> Hard trajectory');


%% ========================================================================
%  5. TABLE-BASED PLOTS WITH GROUP + SUBGROUP
%  ========================================================================
%
%  plotNeuralEfficiencyFromTable accepts a MATLAB table and lets you
%  specify columns for X, Y, Group, and Subgroup. When SubgroupVar is
%  provided, same-group subgroups share a color and get arrow-connected.

fprintf('\n=== 5. Table-Based Plots ===\n');

% Build a summary table (one row per subject per condition)
nSubj = length(subjects);
nCond = 2;
conditions = {'Easy', 'Hard'};

tbl_subj = repmat(subjects', nCond, 1);
tbl_group = repmat(groups', nCond, 1);
tbl_cond = [repmat({'Easy'}, nSubj, 1); repmat({'Hard'}, nSubj, 1)];

% Simulate summary values
rng(42);
tbl_score = zeros(nSubj * nCond, 1);
tbl_hbo = zeros(nSubj * nCond, 1);
for c = 1:nCond
    for s = 1:nSubj
        idx = (c - 1) * nSubj + s;
        if strcmp(conditions{c}, 'Hard')
            tbl_score(idx) = baseScores(s) - scorePenalty(s) + randn * 2;
            tbl_hbo(idx) = 0.4 * activationMul(s) * 1.3 + randn * 0.05;
        else
            tbl_score(idx) = baseScores(s) + randn * 2;
            tbl_hbo(idx) = 0.4 * activationMul(s) + randn * 0.05;
        end
    end
end

T = table(tbl_score, tbl_hbo, tbl_group, tbl_cond, tbl_subj, ...
    'VariableNames', {'Score', 'HbO', 'Group', 'Condition', 'SubjectID'});

disp(T(1:4, :));

% 5a: Group only (HC vs Clinical)
[fig4a, ~] = exploreFNIRS.core.plotNeuralEfficiencyFromTable(T, ...
    'XVar', 'HbO', 'YVar', 'Score', ...
    'GroupVar', 'Group', ...
    'FitLine', true, ...
    'Title', 'Table-based: HC vs Clinical');

% 5b: Group + Subgroup with arrows
%     Each group gets arrows connecting Easy -> Hard centroids
[fig4b, stats4b] = exploreFNIRS.core.plotNeuralEfficiencyFromTable(T, ...
    'XVar', 'HbO', 'YVar', 'Score', ...
    'GroupVar', 'Group', 'SubgroupVar', 'Condition', ...
    'ShowArrows', true, ...
    'Title', 'HC vs Clinical: Easy -> Hard');

% 5c: Subgroup only (no group split, all subjects together)
[fig4c, ~] = exploreFNIRS.core.plotNeuralEfficiencyFromTable(T, ...
    'XVar', 'HbO', 'YVar', 'Score', ...
    'SubgroupVar', 'Condition', ...
    'ShowArrows', true, ...
    'Title', 'All subjects: Easy -> Hard');


%% ========================================================================
%  6. CUSTOMIZATION: LABELS, FIT LINES, AXIS REVERSAL
%  ========================================================================
%
%  Additional options for presentation-ready figures.

fprintf('\n=== 6. Customization ===\n');

% 6a: Subject labels and custom axis labels
[fig5a, ~] = exploreFNIRS.core.plotNeuralEfficiencyFromTable(T, ...
    'XVar', 'HbO', 'YVar', 'Score', ...
    'GroupVar', 'Group', ...
    'SubjectVar', 'SubjectID', ...
    'ShowLabels', true, ...
    'XLabel', 'Prefrontal HbO (z)', ...
    'YLabel', 'Behavioral Score (z)', ...
    'Title', 'Neural Efficiency with Subject Labels');

% 6b: InvertX negates z-scored X (activation axis)
%     Useful when higher activation values mean less engagement
[fig5b, ~] = exploreFNIRS.core.plotNeuralEfficiencyFromTable(T, ...
    'XVar', 'HbO', 'YVar', 'Score', ...
    'GroupVar', 'Group', ...
    'InvertX', true, ...
    'Title', 'Inverted X (lower raw = better)');

% 6c: ReverseAxes — reverses X direction
%     Low activation at right, high activation at left
[fig5c, ~] = exploreFNIRS.core.plotNeuralEfficiencyFromTable(T, ...
    'XVar', 'HbO', 'YVar', 'Score', ...
    'GroupVar', 'Group', ...
    'ReverseAxes', true, ...
    'FitLine', true, ...
    'Title', 'Reversed axes (high at top-left)');

% 6d: Custom colors and saving
outDir = fullfile(tempdir, 'pf2_neural_efficiency');
if ~exist(outDir, 'dir'), mkdir(outDir); end

[fig5d, ~] = exploreFNIRS.core.plotNeuralEfficiencyFromTable(T, ...
    'XVar', 'HbO', 'YVar', 'Score', ...
    'GroupVar', 'Group', 'SubgroupVar', 'Condition', ...
    'ShowArrows', true, ...
    'ArrowColor', [0.1 0.1 0.1], ...
    'Colors', [0.2 0.6 0.9; 0.9 0.3 0.2], ...
    'FitLine', true, ...
    'Title', 'Publication-ready', ...
    'SavePath', fullfile(outDir, 'neural_efficiency.png'), ...
    'SaveDPI', 300);

fprintf('  Saved to: %s\n', outDir);

fprintf('\nDone.\n');
