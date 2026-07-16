%% example_glm_advanced.m - Manual GLM pipeline tutorial
%
% Demonstrates the manual step-by-step GLM workflow for fNIRS analysis.
% Use this when you need full control over design matrix construction,
% per-subject fitting, first-level contrasts, or custom beta packaging.
%
% For the standard workflow, see example_glm_analysis.m which uses
% GLMExperiment to automate all of these steps.
%
% Covers:
%   1. Synthetic continuous data with event markers
%   2. Design matrix construction (HRF convolution, drift regressors)
%   3. Per-subject GLM fitting
%   4. First-level contrasts (Hard > Easy)
%   5. Beta packaging into Experiment for group analysis
%
% Requirements:
%   - processFNIRS2 on path
%   - Sample data available via pf2.import.sampleData.fNIR2000()

% Uncomment to save figures instead of displaying them:
% outDir = '/tmp/glm_advanced';
% if ~exist(outDir, 'dir'), mkdir(outDir); end

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

% Register demo pipelines and process all subjects
[rawMethod, oxyMethod] = pf2_base.examples.addDemoPipelines();

nSubjects = length(subjects);
for s = 1:nSubjects
    subjects{s} = processFNIRS2(subjects{s}, rawMethod, oxyMethod);
end
fprintf('  Processed %d subjects\n', nSubjects);

%% Step 2: Design matrix construction
%
% blocksToEvents groups blocks by condition. buildDesignMatrix convolves
% each condition's boxcar with the HRF and adds drift regressors.
%
% No bandpass filtering is applied before GLM fitting. Drift regressors
% model low-frequency trends explicitly (replacing a high-pass filter),
% and AR-IRLS handles serial correlation (replacing a low-pass filter).
% Pre-filtering can distort the HRF peak shape and remove variance that
% the model should capture.
%
% buildDesignMatrix options:
%   'DriftOrder'        - Legendre polynomial order (default: 3)
%   'DriftType'         - 'legendre' or 'dct' (SPM-style)
%   'HRF'              - Custom HRF vector (default: canonical double-gamma)
%   'IncludeDerivative' - Temporal derivative of HRF (default: false)
%   'IncludeDispersion' - Dispersion derivative (default: false)
%   'ShortChannels'     - Short-channel regressors for systemic removal

fprintf('\n=== Step 2: Design matrix construction ===\n');

events = pf2.data.blocksToEvents(blockDefs{1});
d = subjects{1};
[X, regressorNames] = pf2_base.fnirs.buildDesignMatrix(d.time, d.fs, events, ...
    'DriftOrder', 3);

fprintf('  Design matrix: %d timepoints x %d regressors\n', size(X, 1), size(X, 2));
fprintf('  Regressors: %s\n', strjoin(regressorNames, ', '));

%% Step 3: Per-subject GLM fitting

fprintf('\n=== Step 3: Per-subject GLM fitting ===\n');

biomarkers = {'HbO', 'HbR'};
glmPerSubject = cell(1, nSubjects);

for s = 1:nSubjects
    d = subjects{s};
    subEvents = pf2.data.blocksToEvents(blockDefs{s});
    [Xs, names] = pf2_base.fnirs.buildDesignMatrix(d.time, d.fs, subEvents, ...
        'DriftOrder', 3);

    bioResults = struct();
    for b = 1:length(biomarkers)
        bio = biomarkers{b};
        if isfield(d, bio)
            bioResults.(bio) = pf2_base.fnirs.fitGLM(d.(bio), Xs, names);
        end
    end

    glmPerSubject{s} = struct('results', bioResults, 'names', {names}, ...
        'data', d, 'events', subEvents);
    fprintf('  Subject %s: mean R2=%.3f (HbO)\n', ...
        d.info.SubjectID, mean(bioResults.HbO.R2));
end

%% Step 4: First-level contrasts (Hard > Easy)
%
% Contrasts test linear combinations of regressors within a single subject.
% Here we test whether Hard blocks produce larger activation than Easy.

fprintf('\n=== Step 4: Contrasts (Hard > Easy) ===\n');

d = subjects{1};
subEvents = pf2.data.blocksToEvents(blockDefs{1});
[Xs, names] = pf2_base.fnirs.buildDesignMatrix(d.time, d.fs, subEvents, ...
    'DriftOrder', 3);

easyIdx = find(strcmp(names, 'Easy'));
hardIdx = find(strcmp(names, 'Hard'));
C = zeros(1, length(names));
C(hardIdx) = 1;
C(easyIdx) = -1;

results = pf2_base.fnirs.fitGLM(d.HbO, Xs, names, ...
    'Contrasts', C, 'ContrastNames', {'Hard > Easy'});

fprintf('  Hard > Easy contrast (Subject 1):\n');
fprintf('    Channel 1: beta=%.4f, t=%.2f, p=%.4f\n', ...
    results.contrast.beta(1,1), results.contrast.tstat(1,1), ...
    results.contrast.pval(1,1));
nSigCh = sum(results.contrast.pval(1,:) < 0.05);
fprintf('    Significant channels (p<0.05): %d/%d\n', ...
    nSigCh, size(results.contrast.pval, 2));

%% Step 5: Beta packaging and Experiment
%
% betasToSegments converts per-condition GLM betas into pseudo-segments
% compatible with Experiment. Each segment has [1 x C] beta values
% (single timepoint), units set to '\beta', and all biomarker results
% attached.

fprintf('\n=== Step 5: Beta packaging and Experiment ===\n');

stimConds = {'Easy', 'Hard'};
allSegments = {};
for s = 1:nSubjects
    gr = glmPerSubject{s};
    segs = pf2.data.betasToSegments(gr.results.HbO, gr.data, ...
        'Conditions', stimConds, ...
        'BiomarkerResults', gr.results);
    allSegments = [allSegments, segs]; %#ok<AGROW>
end

ex = exploreFNIRS.core.Experiment(allSegments);
ex.settings.useBaseline = false;
ex.settings.resampleRate = 0;
ex.settings.barBinSize = 0;
ex.groupby({'Condition'});
ex.aggregate();

fig = ex.plotBar('Biomarker', 'HbO', 'Channels', 1:4, ...
    'ShowIndividual', true);
% fig = ex.plotBar('Biomarker', 'HbO', 'Channels', 1:4, ...
%     'ShowIndividual', true, ...
%     'Visible', 'off', 'SavePath', fullfile(outDir, 'step5_manual_bar.png'));
% close(fig);

% Topographic LME: F-statistics on 3D brain surface
[fig, topoResults] = ex.plotTopoLME('Biomarkers', {'HbO'}, ...
    'SigType', 'p', 'SigThreshold', 0.05, ...
    'ShowIntercept', false);
% [fig, topoResults] = ex.plotTopoLME('Biomarkers', {'HbO'}, ...
%     'SigType', 'p', 'SigThreshold', 0.05, ...
%     'ShowIntercept', false, ...
%     'Visible', 'off', 'SavePath', fullfile(outDir, 'step5_topo_lme.png'));
% if ~isempty(fig), close(fig); end

%% Summary

fprintf('\n=== Advanced GLM tutorial complete ===\n');
