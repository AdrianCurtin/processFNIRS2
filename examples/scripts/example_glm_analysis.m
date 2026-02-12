%% example_glm_analysis.m - GLM analysis tutorial
%
% Demonstrates a general linear model (GLM) approach to fNIRS analysis
% using GLMExperiment. The class encapsulates the full pipeline: processing
% continuous recordings, building design matrices, fitting per-subject GLMs,
% packaging betas, and group-level statistics.
%
% GLM vs Epoch Approach:
%   The standard fNIRS workflow (defineBlocks -> extractBlocks -> Experiment)
%   cuts continuous recordings into epochs around events, then averages.
%   The GLM approach keeps the full continuous recording intact and fits a
%   linear model with HRF-convolved regressors. Advantages:
%     - Handles overlapping events and irregular timing naturally
%     - Drift and nuisance regressors modeled explicitly
%     - Amplitude/parametric modulation support
%     - Produces beta weights as summary statistics for group analysis
%
% Covers:
%   1. Synthetic continuous data with event markers
%   2. GLMExperiment setup and configuration
%   3. First-level fitting and result inspection
%   4. Group-level analysis (bar plots, LME, aux, export)
%   5. Direct beta table for R/Python export
%
% See also: example_glm_advanced.m for the manual step-by-step pipeline
%   (design matrix construction, per-subject fitting, contrasts, beta
%   packaging) when you need full control over each stage.
%
% Requirements:
%   - processFNIRS2 on path
%   - Sample data available via pf2.import.sampleData.fNIR2000()

outDir = '/tmp/glm_examples';
if ~exist(outDir, 'dir'), mkdir(outDir); end

%% Step 1: Generate synthetic continuous recordings
%
% We use the sample data generator at the 'blocks' stage to get 4 subjects
% with continuous recordings (~1118s each) and pre-defined block structs.
% Each recording has 6 event markers (2 Easy, 2 Hard, 2 Rest) with 30s
% block durations.

fprintf('=== Step 1: Generate synthetic continuous data ===\n');

[subjects, blockDefs] = pf2.import.sampleData.experiment('blocks');
fprintf('  %d subjects, %d blocks each\n', length(subjects), length(blockDefs{1}));
fprintf('  Recording duration: %.0fs\n', max(subjects{1}.time) - min(subjects{1}.time));

% Register demo pipelines
[rawMethod, oxyMethod] = pf2.import.sampleData.addDemoPipelines();

%% Step 2: Create and configure GLMExperiment
%
% GLMExperiment takes raw subjects and block definitions. It extends
% Experiment, so all plotting, stats, export, and connectivity methods
% are available after fit().
%
% Key configuration:
%   settings.rawMethod/oxyMethod - processing pipeline (applied before GLM)
%   glm.conditions  - which regressors to include (empty = auto-detect)
%   glm.driftOrder   - polynomial drift order (default: 3)
%   glm.biomarkers   - which hemoglobin signals to fit (default: HbO, HbR)
%   glm.auxFields    - auxiliary signals to also fit GLM on
%   glm.fitMethod    - 'OLS' (default) or 'AR-IRLS'

fprintf('\n=== Step 2: Create and configure GLMExperiment ===\n');

gx = exploreFNIRS.core.GLMExperiment(subjects, blockDefs);

% Processing pipeline
gx.settings.rawMethod = rawMethod;
gx.settings.oxyMethod = oxyMethod;

% GLM model configuration
gx.glm.conditions = {'Easy', 'Hard'};   % exclude Rest from analysis
gx.glm.auxFields = {'heartRate'};       % also fit GLM on heart rate

fprintf('  Raw method: %s\n', rawMethod);
fprintf('  Oxy method: %s\n', oxyMethod);
fprintf('  Conditions: %s\n', strjoin(gx.glm.conditions, ', '));
fprintf('  Biomarkers: %s\n', strjoin(gx.glm.biomarkers, ', '));

%% Step 3: Fit first-level GLMs
%
% fit() runs the entire pipeline per subject:
%   1. Reprocess with rawMethod/oxyMethod
%   2. Convert blocks -> GLM events (via blocksToEvents)
%   3. Build design matrix (HRF convolution, drift regressors)
%   4. Fit GLM per biomarker (and per aux field)
%   5. Package betas into Experiment-compatible pseudo-segments
%   6. Aggregate block-level behavioral data onto segments

fprintf('\n=== Step 3: Fit first-level GLMs ===\n');
gx.fit();

% Inspect per-subject results
r1 = gx.getSubjectResult(1);
fprintf('  Sub01 mean R2 (HbO): %.3f\n', mean(r1.results.HbO.R2));
fprintf('  Regressors: %s\n', strjoin(r1.regressorNames, ', '));

% Visualize design matrix
fig = gx.plotDesignMatrix(1, 'Visible', 'off', ...
    'SavePath', fullfile(outDir, 'step3_design_matrix.png'));
close(fig);
fprintf('  Saved design matrix figure\n');

% Behavioral data flows through from blocks
fprintf('  Sub01 Easy RT: %.1f ms\n', gx.data{1}.info.reactionTime);
fprintf('  Sub01 Easy accuracy: %.2f\n', gx.data{1}.info.accuracy);

%% Step 4: Group-level analysis
%
% After fit(), gx.data contains beta pseudo-segments and all Experiment
% methods work normally. Beta-appropriate defaults are set automatically:
%   useBaseline = false, resampleRate = 0, barBinSize = 0

fprintf('\n=== Step 4: Group-level analysis ===\n');

gx.groupby({'Condition'});
gx.aggregate();
gx.summary();

% 4a. Bar chart of betas
fig = gx.plotBar('Biomarker', 'HbO', 'Channels', 1:4, ...
    'ShowIndividual', true, ...
    'Title', 'GLM Beta Weights: Easy vs Hard (HbO)', ...
    'Visible', 'off', 'SavePath', fullfile(outDir, 'step4a_beta_bar.png'));
close(fig);
fprintf('  Saved beta bar chart\n');

% 4b. LME on betas
[fig, lmeResults] = gx.plotLME('Biomarkers', {'HbO'}, 'Channels', 1:4, ...
    'Visible', 'off', 'SavePath', fullfile(outDir, 'step4b_beta_lme.png'));
if ~isempty(fig), close(fig); end
fprintf('  LME formula: %s\n', lmeResults.formula);
fprintf('  LME ANOVA p-values:\n');
disp(lmeResults.anova_pval);

% 4c. Aux GLM: heart rate betas by condition
fig = gx.plotAuxBar('heartRate', ...
    'Visible', 'off', 'SavePath', fullfile(outDir, 'step4c_aux_bar.png'));
close(fig);
fprintf('  Saved aux bar chart\n');

% 4d. Topographic LME: F-statistics on 3D brain surface
[fig, topoResults] = gx.plotTopoLME('Biomarkers', {'HbO'}, ...
    'SigType', 'p', 'SigThreshold', 0.05, ...
    'ShowIntercept', false, ...
    'Visible', 'off', 'SavePath', fullfile(outDir, 'step4d_topo_lme.png'));
if ~isempty(fig), close(fig); end
fprintf('  Saved topographic LME figure\n');

% 4e. Export to long table
longT = gx.toLongTable({'HbO', 'HbR'}, 1:4);
writetable(longT, fullfile(outDir, 'step4e_beta_long.csv'));
fprintf('  Exported long table: %d rows x %d cols\n', height(longT), width(longT));

%% Step 5: Direct beta table export
%
% betaTable() exports beta weights directly, bypassing the Experiment
% pipeline. Useful for analysis in R or Python.

fprintf('\n=== Step 5: Direct beta table export ===\n');

T = gx.betaTable('Channels', 1:4, 'IncludeStats', true);
writetable(T, fullfile(outDir, 'step5_beta_table.csv'));
fprintf('  Beta table: %d rows x %d cols\n', height(T), width(T));
fprintf('  Columns: %s\n', strjoin(T.Properties.VariableNames, ', '));

%% Summary

fprintf('\n=== GLM tutorial complete ===\n');
fprintf('Output files in: %s\n', outDir);
d = dir(fullfile(outDir, 'step*'));
for i = 1:length(d)
    fprintf('  %s (%.1f KB)\n', d(i).name, d(i).bytes/1024);
end
fprintf('\nFor the manual step-by-step pipeline, see example_glm_advanced.m\n');
