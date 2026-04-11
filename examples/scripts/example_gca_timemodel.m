%% example_gca_timemodel.m - Growth Curve Analysis with TimeModel
%
% Demonstrates how to use the TimeModel parameter in exploreFNIRS to
% perform Growth Curve Analysis (GCA) on block-averaged fNIRS data.
%
% Growth Curve Analysis models the *shape* of the hemodynamic response
% over time using orthogonal polynomials within a linear mixed-effects
% framework. Instead of collapsing each block into a single mean value,
% GCA preserves temporal information and tests whether conditions or
% groups differ in how their responses unfold.
%
% Key concepts:
%   - barBinSize controls the temporal resolution of the analysis
%   - TimeModel='polynomial' adds orthogonal polynomial time terms
%   - ot1 (linear) captures overall slope (rise or fall)
%   - ot2 (quadratic) captures curvature (rise-peak-decline shape)
%   - Group:ot1, Group:ot2 interactions test whether groups differ in
%     the linear trend or curvature of their response
%
% When to use GCA vs other approaches:
%   - GCA:  "Do groups differ in response *shape* over a block?"
%   - GLM:  "Does this condition produce a response at all?"
%   - Mean: "Do groups differ in average response amplitude?"
%
% Choosing barBinSize:
%   The hemodynamic response changes slowly (~5-10s timescale), so bins
%   smaller than ~3s add noise without meaningful temporal information.
%
%   | Bin size | 30s block | 90s block | Suitability              |
%   |----------|-----------|-----------|--------------------------|
%   | 1s       | 30 bins   | 90 bins   | Too many: overfits noise |
%   | 5s       | 6 bins    | 18 bins   | Good                     |
%   | 10s      | 3 bins    | 9 bins    | Good (recommended start) |
%   | 15-30s   | 1-2 bins  | 3-6 bins  | Coarse but stable        |
%
%   Rule of thumb: aim for 4-15 time bins per block. With fewer than 3
%   bins, polynomial terms are automatically clamped (2 bins = linear
%   only; 1 bin = no polynomial, standard mean-based LME).
%
% PolynomialOrder:
%   Default is 2 (linear + quadratic). This captures the two main
%   features of a hemodynamic block response: the rise (linear) and
%   the peak/return (quadratic). Cubic (order 3) can capture asymmetry
%   in the rise vs fall, but requires more time bins and larger samples
%   to avoid overfitting.
%
% References:
%   Mirman, D. (2017). Growth Curve Analysis and Visualization Using R.
%   Chapman and Hall/CRC. DOI: 10.1201/9781315373218
%
% Requirements:
%   - processFNIRS2 on the MATLAB path
%   - Sample data: pf2.import.sampleData.fNIR2000()

% Uncomment to save figures instead of displaying them:
% outDir = '/tmp/gca_examples';
% if ~exist(outDir, 'dir'), mkdir(outDir); end


%% ========================================================================
%  1. SETUP: BUILD SYNTHETIC MULTI-SUBJECT DATASET
%  ========================================================================

fprintf('=== 1. Setup ===\n');

raw = pf2.import.sampleData.fNIR2000();
processed = processFNIRS2(raw, ...
    'DPFmode', 'Calc', 'defaultSubjectAge', 25, ...
    'blLength', 10, 'blStartTime', 0);

% Inject synthetic markers: alternating Task (10) and Rest (20)
% Each block is 60s long to give enough temporal structure for GCA
processed.markers = [
     60, 10, 0, 1;
    180, 20, 0, 1;
    300, 10, 0, 1;
    420, 20, 0, 1;
    540, 10, 0, 1;
    660, 20, 0, 1;
];

blocks = pf2.data.defineBlocks(processed, ...
    'MarkerCode', [10, 20], 'Duration', 60, ...
    'ConditionMap', {10, 'Task'; 20, 'Rest'}, ...
    'Embed', false);
segments = pf2.data.extractBlocks(processed, blocks, ...
    'PreTime', 5, 'PostTime', 5, 'BaselineWindow', [-5, 0], 'SetT0', true);

% Build 6 subjects (3 GroupA, 3 GroupB) with different response shapes
rng(42);
allSegments = {};
subjects = {'S01','S02','S03','S04','S05','S06'};
groups   = {'GroupA','GroupA','GroupA','GroupB','GroupB','GroupB'};

for i = 1:6
    for s = 1:length(segments)
        seg = segments{s};
        % GroupA: stronger sustained response
        % GroupB: faster rise but earlier return to baseline
        scale = 0.8 + 0.4 * rand();
        seg.HbO = seg.HbO * scale;
        seg.HbR = seg.HbR * scale;
        seg.HbTotal = seg.HbTotal * scale;
        seg.CBSI = seg.CBSI * scale;
        seg.info.SubjectID = subjects{i};
        seg.info.Group = groups{i};
        allSegments{end+1} = seg; %#ok<SAGROW>
    end
end

fprintf('  %d segments from %d subjects\n', length(allSegments), length(subjects));


%% ========================================================================
%  2. GCA WITH POLYNOMIAL TIME (DEFAULT)
%  ========================================================================
%
% The key setting is barBinSize: it controls how many time bins the
% block is divided into. With 60s blocks and 10s bins, we get 6 time
% points per block — enough for linear + quadratic polynomial terms.
%
% When barBinSize > 0 and there are multiple time bins, fitLME
% automatically adds Time to the model using orthogonal polynomials.

fprintf('\n=== 2. GCA with polynomial time (default) ===\n');

ex = exploreFNIRS.core.Experiment(allSegments, ...
    'Hierarchy', {'SubjectID', 'Condition', 'Trial'});

ex.settings.baseline = [-5, 0];
ex.settings.taskStart = 0;
ex.settings.taskEnd = 60;
ex.settings.resampleRate = 1;
ex.settings.barBinSize = 10;         % 10s bins -> 6 time points
ex.settings.avgMode = 'hierarchy';

ex.select('Condition', {'Task', 'Rest'});
ex.groupby({'Condition'});
ex.aggregate();

% Fit LME with default TimeModel='polynomial', PolynomialOrder=2
% This produces a formula like:
%   HbO ~ Condition + ot1 + ot2 + Condition:ot1 + Condition:ot2 + (1+ot1|SubjectID)
%
% Key terms to interpret:
%   Condition        - Do conditions differ in overall amplitude?
%   ot1              - Is there a linear time trend (across conditions)?
%   ot2              - Is there curvature (across conditions)?
%   Condition:ot1    - Do conditions differ in linear slope?
%   Condition:ot2    - Do conditions differ in curvature?

results = ex.statsFitLME('Biomarkers', {'HbO'}, 'Channels', 1:5);

fprintf('  Formula: %s\n', results.formula);
fprintf('  TimeModel: %s\n', results.timeModel);
fprintf('\n  ANOVA p-values:\n');
disp(results.anova_pval);

% The termLabels field maps polynomial codes to readable names
if ~isempty(fieldnames(results.termLabels))
    fprintf('  Term labels:\n');
    labels = fieldnames(results.termLabels);
    for i = 1:length(labels)
        fprintf('    %s = %s\n', labels{i}, results.termLabels.(labels{i}));
    end
end


%% ========================================================================
%  3. COMPARE TIMEMODEL OPTIONS
%  ========================================================================
%
% exploreFNIRS supports four TimeModel settings:
%
%   'polynomial' (default) - Orthogonal polynomial coding. Best for
%        modeling smooth response shapes. Terms: ot1, ot2, ...
%
%   'discrete'  - Treats each time bin as an independent category.
%        Captures arbitrary patterns but uses more degrees of freedom.
%        Equivalent to the old DiscreteTime=true behavior.
%
%   'continuous' - Centers time as a single numeric predictor. Tests
%        for a linear time trend only (no curvature). Simplest model.
%
%   'none' - Drops Time from the model entirely. Pools all time bins
%        into one observation per subject*condition. Equivalent to
%        setting barBinSize=0.

fprintf('\n=== 3. Compare TimeModel options ===\n');

models = {'polynomial', 'discrete', 'continuous', 'none'};
for i = 1:length(models)
    tm = models{i};
    r = ex.statsFitLME('Biomarkers', {'HbO'}, 'Channels', 1, ...
        'TimeModel', tm, 'Verbose', false);
    fprintf('  TimeModel=%-12s  formula: %s\n', ...
        [tm ','], regexprep(r.formula, '^[^~]+~', '~ '));
end


%% ========================================================================
%  4. GROUP x TIME INTERACTIONS
%  ========================================================================
%
% The most common GCA use case: testing whether two groups have
% different hemodynamic response shapes. The Group:ot1 and Group:ot2
% interactions are the key tests.
%
% Group:ot1 significant  -> groups differ in linear slope
%   (e.g., one group has a steeper rise)
%
% Group:ot2 significant  -> groups differ in curvature
%   (e.g., one group peaks earlier, or one sustains longer)

fprintf('\n=== 4. Group x Time interactions ===\n');

ex.reset();
ex.select('Condition', 'Task');
ex.groupby({'Group'});
ex.aggregate();

results = ex.statsFitLME('Biomarkers', {'HbO'}, 'Channels', 1:5);

fprintf('  Formula: %s\n', results.formula);
fprintf('\n  ANOVA p-values:\n');
disp(results.anova_pval);

% The temporal plot shows the actual time courses that GCA is modeling
fig = ex.plotTemporal('Biomarkers', {'HbO'}, 'Channels', 1:3, ...
    'Title', 'GroupA vs GroupB: HbO time course');
% Uncomment to save:
% fig = ex.plotTemporal('Biomarkers', {'HbO'}, 'Channels', 1:3, ...
%     'Title', 'GroupA vs GroupB: HbO time course', ...
%     'Visible', 'off', 'SavePath', fullfile(outDir, 'gca_temporal.png'));
% close(fig);


%% ========================================================================
%  5. ADJUSTING POLYNOMIAL ORDER
%  ========================================================================
%
% PolynomialOrder controls how many polynomial terms are included:
%   1 = linear only (ot1)
%   2 = linear + quadratic (ot1, ot2)  <- default
%   3 = linear + quadratic + cubic (ot1, ot2, ot3)
%
% Higher orders capture more complex shapes but need more time bins
% and larger sample sizes. The order is automatically clamped to
% (number of time bins - 1), so with 3 bins you get at most order 2.
%
% Guidelines:
%   - Order 2 is sufficient for most fNIRS block designs
%   - Order 3 needs ~8+ time bins and ~15+ subjects per group
%   - Order 1 is appropriate when you only care about the trend

fprintf('\n=== 5. Adjusting PolynomialOrder ===\n');

for order = 1:3
    r = ex.statsFitLME('Biomarkers', {'HbO'}, 'Channels', 1, ...
        'PolynomialOrder', order, 'Verbose', false);
    nTerms = height(r.anova{1,1});
    fprintf('  Order %d: %d ANOVA terms, formula: %s\n', ...
        order, nTerms, regexprep(r.formula, '^[^~]+~', '~ '));
end


%% ========================================================================
%  6. AUTOMATIC CLAMPING WITH FEW TIME BINS
%  ========================================================================
%
% When barBinSize is large relative to the block duration, you get
% fewer time bins. The polynomial order is automatically clamped:
%   - 1 time bin  -> no polynomial (standard mean-based LME)
%   - 2 time bins -> max order 1 (linear only)
%   - 3 time bins -> max order 2 (linear + quadratic)
%
% This means you can safely leave PolynomialOrder at the default (2)
% and the system adapts to your data.

fprintf('\n=== 6. Automatic clamping with few bins ===\n');

% Recreate with different bin sizes
binSizes = [0, 30, 10];
binLabels = {'0 (single bar)', '30 (2 bins)', '10 (6 bins)'};

for i = 1:length(binSizes)
    ex2 = exploreFNIRS.core.Experiment(allSegments, ...
        'Hierarchy', {'SubjectID', 'Condition', 'Trial'});
    ex2.settings.baseline = [-5, 0];
    ex2.settings.taskStart = 0;
    ex2.settings.taskEnd = 60;
    ex2.settings.resampleRate = 1;
    ex2.settings.barBinSize = binSizes(i);
    ex2.settings.avgMode = 'hierarchy';
    ex2.select('Condition', {'Task', 'Rest'});
    ex2.groupby({'Condition'});
    ex2.aggregate();

    r = ex2.statsFitLME('Biomarkers', {'HbO'}, 'Channels', 1, ...
        'Verbose', false);
    fprintf('  barBinSize=%-16s  formula: %s\n', ...
        binLabels{i}, regexprep(r.formula, '^[^~]+~', '~ '));
end


%% ========================================================================
%  7. STAT WINDOW: FOCUS ON A TIME RANGE
%  ========================================================================
%
% StatWindow restricts the LME analysis to a subset of time bins.
% Useful when your block has a known response window and you want to
% exclude early onset or late recovery periods.

fprintf('\n=== 7. StatWindow ===\n');

ex.reset();
ex.select('Condition', {'Task', 'Rest'});
ex.groupby({'Condition'});
ex.aggregate();

% Full block: 0-60s in 10s bins
r_full = ex.statsFitLME('Biomarkers', {'HbO'}, 'Channels', 1, ...
    'Verbose', false);

% Focus on 10-50s (skip onset and offset)
r_win = ex.statsFitLME('Biomarkers', {'HbO'}, 'Channels', 1, ...
    'StatWindow', [10, 50], 'Verbose', false);

fprintf('  Full block:    %d ANOVA terms, formula: %s\n', ...
    height(r_full.anova{1,1}), regexprep(r_full.formula, '^[^~]+~', '~ '));
fprintf('  StatWindow:    %d ANOVA terms, formula: %s\n', ...
    height(r_win.anova{1,1}), regexprep(r_win.formula, '^[^~]+~', '~ '));


%% ========================================================================
%  8. EXPERIMENT-LEVEL SETTINGS
%  ========================================================================
%
% Instead of passing TimeModel and PolynomialOrder to every plotLME or
% statsFitLME call, you can set them once on the Experiment object.
% These are automatically injected into all LME calls.

fprintf('\n=== 8. Experiment-level settings ===\n');

ex.settings.timeModel = 'polynomial';
ex.settings.polyOrder = 2;

fprintf('  ex.settings.timeModel = ''%s''\n', ex.settings.timeModel);
fprintf('  ex.settings.polyOrder = %d\n', ex.settings.polyOrder);
fprintf('  These are auto-injected into plotLME/statsFitLME calls.\n');

% Per-call overrides still work:
r = ex.statsFitLME('Biomarkers', {'HbO'}, 'Channels', 1, ...
    'TimeModel', 'discrete', 'Verbose', false);
fprintf('  Override: TimeModel=''discrete'' -> formula: %s\n', ...
    regexprep(r.formula, '^[^~]+~', '~ '));

fprintf('\n=== Done ===\n');
