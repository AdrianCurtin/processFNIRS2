% RUNDATASETI Run FRESH benchmark on Dataset I (Auditory: Speech/Noise/Silence)
%
% Processes all subjects in the FRESH Auditory dataset through each pipeline
% configuration, then runs group-level analysis using exploreFNIRS.
%
% Dataset I: Speech/noise/silence block design
% Conditions: speech, noise, silence (block design)
%
% Hypotheses (group-level):
%   H1: Speech activates bilateral Heschl's gyri (HbO increase)
%   H2: Noise activates bilateral Heschl's gyri (HbO increase)
%   H3: Speech activates left IFG (HbO increase)
%   H4: Speech > noise in left Heschl's gyrus
%   H5: Speech > noise in left IFG
%   H6: No significant activation in occipital cortex for speech
%   H7: No significant activation in occipital cortex for noise
%
% See also: benchmarks.fresh.definePipelines, benchmarks.fresh.analyzeResults

fprintf('\n=== FRESH Benchmark: Dataset I (Auditory) ===\n');
fprintf('Started: %s\n\n', datetime('now'));

% --- Setup paths ---
scriptDir = fileparts(mfilename('fullpath'));
benchmarkRoot = fileparts(scriptDir);
dataDir = fullfile(benchmarkRoot, 'data', 'dataset_I_auditory');
resultsDir = fullfile(benchmarkRoot, 'results', 'datasetI');

if ~isfolder(dataDir)
    error('Dataset I not found at %s. Run setup.m first.', dataDir);
end

if ~isfolder(resultsDir)
    mkdir(resultsDir);
end

% --- Load pipeline definitions ---
pipelines = definePipelines();
nPipelines = length(pipelines);
fprintf('Loaded %d pipeline configurations.\n', nPipelines);

% --- Find subjects ---
subDirs = dir(fullfile(dataDir, 'sub-*'));
subDirs = subDirs([subDirs.isdir]);
nSubjects = length(subDirs);
fprintf('Found %d subjects.\n\n', nSubjects);

if nSubjects == 0
    error('No subject directories found in %s', dataDir);
end

% --- Process each pipeline ---
for p = 1:nPipelines
    pipe = pipelines(p);
    fprintf('\n=== Pipeline %d/%d: %s ===\n', p, nPipelines, pipe.name);
    fprintf('  %s\n', pipe.description);

    pipeResultDir = fullfile(resultsDir, pipe.name);
    if ~isfolder(pipeResultDir)
        mkdir(pipeResultDir);
    end

    % --- Process all subjects ---
    allProcessed = {};
    subjectNames = {};

    for s = 1:nSubjects
        subName = subDirs(s).name;
        fprintf('  Subject %d/%d: %s ... ', s, nSubjects, subName);

        % Check if already processed
        resultFile = fullfile(pipeResultDir, sprintf('%s.mat', subName));
        if isfile(resultFile)
            fprintf('(cached) ');
            try
                cached = load(resultFile, 'result');
                if isfield(cached.result, 'processed')
                    allProcessed{end+1} = cached.result.processed; %#ok<AGROW>
                    subjectNames{end+1} = subName; %#ok<AGROW>
                    fprintf('OK\n');
                    continue;
                end
            catch
                % Re-process if cache is invalid
            end
        end

        % Find and import SNIRF file (BIDS: sub-XX/ses-01/nirs/)
        nirsDir = fullfile(dataDir, subName, 'ses-01', 'nirs');
        if ~isfolder(nirsDir)
            nirsDir = fullfile(dataDir, subName, 'nirs');
        end
        if ~isfolder(nirsDir)
            nirsDir = fullfile(dataDir, subName, 'func');
        end
        snirfFiles = dir(fullfile(nirsDir, '*.snirf'));

        if isempty(snirfFiles)
            fprintf('No SNIRF files. Skipping.\n');
            continue;
        end

        try
            % Import (events.tsv loaded automatically by importSNIRF)
            rawData = pf2.import.importSNIRF(fullfile(nirsDir, snirfFiles(1).name), false);
            rawData.info.SubjectID = subName;

            % Process through pipeline
            processed = processSingleSubject(rawData, pipe);

            % Save per-subject result
            result = struct();
            result.processed = processed;
            result.subjectID = subName;
            result.pipeline = pipe.name;
            save(resultFile, 'result', '-v7.3');

            allProcessed{end+1} = processed; %#ok<AGROW>
            subjectNames{end+1} = subName; %#ok<AGROW>
            fprintf('OK\n');

        catch e
            fprintf('ERROR: %s\n', e.message);
        end
    end

    if length(allProcessed) < 2
        fprintf('  Not enough subjects for group analysis (%d). Skipping.\n', length(allProcessed));
        continue;
    end

    % --- Group-level analysis ---
    fprintf('\n  Running group-level analysis (%d subjects)...\n', length(allProcessed));

    try
        groupResult = runGroupAnalysis(allProcessed, pipe);
        groupResult.pipeline = pipe.name;
        groupResult.nSubjects = length(allProcessed);
        groupResult.subjectNames = subjectNames;

        % Test hypotheses
        groupResult.hypotheses = testAuditoryHypotheses(groupResult);

        % Save group result
        groupFile = fullfile(pipeResultDir, 'group_results.mat');
        save(groupFile, 'groupResult', '-v7.3');
        fprintf('  Group results saved to: %s\n', groupFile);

        % Print hypothesis summary
        fprintf('  Hypothesis Results:\n');
        for h = 1:length(groupResult.hypotheses)
            hyp = groupResult.hypotheses(h);
            if hyp.pass
                passStr = 'PASS';
            else
                passStr = 'FAIL';
            end
            fprintf('    %s: %s (p=%.4f) - %s\n', hyp.name, passStr, hyp.pvalue, hyp.description);
        end

    catch e
        fprintf('  ERROR in group analysis: %s\n', e.message);
    end
end

fprintf('\n=== Dataset I Benchmark Complete ===\n');
fprintf('Results saved to: %s\n', resultsDir);
fprintf('Finished: %s\n', datetime('now'));

%%_Subfunctions_________________________________________________________

function processed = processSingleSubject(rawData, pipe)
% PROCESSSINGLESUBJECT Process one subject through a pipeline
%
% Inputs:
%   rawData - Raw fNIRS data struct
%   pipe    - Pipeline configuration
%
% Outputs:
%   processed - Processed fNIRS data struct

rawMethodName = determineMethodName(pipe.rawMethods, 'raw');
oxyMethodName = determineMethodName(pipe.oxyMethods, 'oxy');

processed = processFNIRS2(rawData, rawMethodName, oxyMethodName, ...
    'ShowGUI', false, 'DPFmode', pipe.dpfMode);

if pipe.useSSR && isfield(processed, 'probeinfo')
    processed = pf2_base.fnirs.shortChannelRegression(processed, ...
        'Method', pipe.ssrMethod);
end

end

function groupResult = runGroupAnalysis(allProcessed, pipe)
% RUNGROUPANALYSIS Group-level analysis across subjects
%
% Inputs:
%   allProcessed - Cell array of processed fNIRS structs
%   pipe         - Pipeline configuration
%
% Outputs:
%   groupResult - Struct with group-level statistics

groupResult = struct();

switch pipe.analysisType
    case 'blockavg'
        groupResult = runGroupBlockAvg(allProcessed, pipe);
    case 'glm'
        groupResult = runGroupGLM(allProcessed, pipe);
end

end

function groupResult = runGroupBlockAvg(allProcessed, pipe)
% RUNGROUPBLOCKAVG Group block-averaging analysis
%
% Uses exploreFNIRS.core.Experiment for group statistics on epoched data.

groupResult = struct();

% Extract epochs from each subject
allSegments = {};
for s = 1:length(allProcessed)
    processed = allProcessed{s};
    if isempty(processed.markers) || ~isfield(processed, 'HbO')
        continue;
    end

    uniqueCodes = unique(processed.markers(:, 2));
    blocks = pf2.data.defineBlocks(processed, uniqueCodes);

    if isempty(blocks)
        continue;
    end

    segments = pf2.data.extractBlocks(processed, blocks, ...
        'PreTime', pipe.epochWindow(1), 'PostTime', pipe.epochWindow(2), ...
        'BaselineWindow', pipe.baselineWindow, 'SetT0', true);

    allSegments = [allSegments, segments]; %#ok<AGROW>
end

if isempty(allSegments)
    groupResult.error = 'No segments extracted';
    return;
end

% Feed to Experiment
try
    ex = exploreFNIRS.core.Experiment(allSegments);
    groupResult.experiment = ex;
    groupResult.nSegments = length(allSegments);
catch e
    groupResult.error = sprintf('Experiment creation failed: %s', e.message);
end

end

function groupResult = runGroupGLM(allProcessed, pipe)
% RUNGROUPGLM Group GLM analysis (second-level)
%
% Runs GLM on each subject, then combines betas for group inference.

groupResult = struct();

allBetas = [];
allCondNames = {};

for s = 1:length(allProcessed)
    processed = allProcessed{s};
    if isempty(processed.markers) || ~isfield(processed, 'HbO')
        continue;
    end

    % Build events from markers
    uniqueCodes = unique(processed.markers(:, 2));
    events = [];
    for ci = 1:length(uniqueCodes)
        code = uniqueCodes(ci);
        codeMask = processed.markers(:, 2) == code;
        ev.name = sprintf('cond_%d', code);
        ev.onsets = processed.markers(codeMask, 1)';
        if size(processed.markers, 2) >= 3
            durations = processed.markers(codeMask, 3)';
            if all(durations == 0)
                durations = 20;  % Default block duration for auditory
            end
            ev.duration = durations;
        else
            ev.duration = 20;
        end
        if isempty(events)
            events = ev;
        else
            events(end+1) = ev; %#ok<AGROW>
        end
    end

    % Build design matrix and fit
    [X, names] = pf2_base.fnirs.buildDesignMatrix(processed.time, processed.fs, events, ...
        'DriftOrder', pipe.glmDriftOrder);

    % Get long channels only
    if isfield(processed, 'probeinfo') && isfield(processed.probeinfo, 'Probe')
        probe = processed.probeinfo.Probe{1};
        if isfield(probe, 'IsShortSeparation')
            longIdx = find(~probe.IsShortSeparation);
        else
            longIdx = 1:size(processed.HbO, 2);
        end
    else
        longIdx = 1:size(processed.HbO, 2);
    end

    Y = processed.HbO(:, longIdx);
    glmResult = pf2_base.fnirs.fitGLM(Y, X, names, 'Method', pipe.glmMethod);

    % Store condition betas (first nCond rows)
    nCond = length(events);
    condBetas = glmResult.beta(1:nCond, :);  % [nCond x nLongCh]

    if isempty(allBetas)
        allBetas = condBetas;
        allBetas = reshape(allBetas, [1, size(condBetas)]);
        allCondNames = {events.name};
    else
        allBetas(end+1, :, :) = condBetas; %#ok<AGROW>
    end
end

if isempty(allBetas)
    groupResult.error = 'No valid GLM results';
    return;
end

% Second-level statistics: one-sample t-test on betas
nSub = size(allBetas, 1);
nCond = size(allBetas, 2);
nCh = size(allBetas, 3);

groupResult.conditions = allCondNames;
groupResult.groupBeta = squeeze(mean(allBetas, 1));  % [nCond x nCh]
groupResult.groupTstat = zeros(nCond, nCh);
groupResult.groupPval = zeros(nCond, nCh);

for ci = 1:nCond
    for ch = 1:nCh
        betaVals = squeeze(allBetas(:, ci, ch));
        [~, pval, ~, stats] = ttest(betaVals);
        groupResult.groupTstat(ci, ch) = stats.tstat;
        groupResult.groupPval(ci, ch) = pval;
    end
end

groupResult.nSubjects = nSub;

end

function hypotheses = testAuditoryHypotheses(groupResult)
% TESTAUDITORYHYPOTHESES Test FRESH auditory dataset hypotheses
%
% Tests the 7 group-level hypotheses from the FRESH paper based on
% available group results.

hypotheses = struct('name', {}, 'description', {}, 'pass', {}, 'pvalue', {});

% Note: These are placeholder implementations that will need to be refined
% based on actual channel-to-ROI mappings from the specific probe layout.
% The FRESH paper uses specific anatomical ROI definitions.

if isfield(groupResult, 'error')
    for h = 1:7
        hypotheses(h).name = sprintf('H%d', h);
        hypotheses(h).description = 'Could not test - group analysis error';
        hypotheses(h).pass = false;
        hypotheses(h).pvalue = 1.0;
    end
    return;
end

alpha = 0.05;

% For block-averaging results, use Experiment-based group stats
if isfield(groupResult, 'experiment')
    for h = 1:7
        hypotheses(h).name = sprintf('H%d', h);
        hypotheses(h).description = getHypothesisDescription(h);
        hypotheses(h).pass = false;
        hypotheses(h).pvalue = 1.0;
    end
    return;
end

% For GLM results, use second-level t-tests
if isfield(groupResult, 'groupPval')
    nCond = size(groupResult.groupPval, 1);
    nCh = size(groupResult.groupPval, 2);

    for h = 1:7
        hypotheses(h).name = sprintf('H%d', h);
        hypotheses(h).description = getHypothesisDescription(h);

        % Simplified hypothesis testing based on available channels
        % In practice, ROI channels would be defined from probe geometry
        switch h
            case {1, 2}  % Activation in Heschl's gyri
                % Use condition 1 (speech) or 2 (noise)
                condIdx = min(h, nCond);
                pvals = groupResult.groupPval(condIdx, :);
                minP = min(pvals);
                hypotheses(h).pvalue = minP;
                hypotheses(h).pass = minP < alpha;

            case 3  % Speech activates left IFG
                if nCond >= 1
                    pvals = groupResult.groupPval(1, :);
                    minP = min(pvals);
                    hypotheses(h).pvalue = minP;
                    hypotheses(h).pass = minP < alpha;
                end

            case {4, 5}  % Speech > noise contrasts
                if nCond >= 2
                    % Compute difference of betas at group level
                    diff_beta = groupResult.groupBeta(1, :) - groupResult.groupBeta(2, :);
                    % Simple test: is mean difference positive?
                    hypotheses(h).pvalue = 0.5;  % Placeholder
                    hypotheses(h).pass = mean(diff_beta, 'omitnan') > 0;
                end

            case {6, 7}  % No activation in occipital cortex
                % These are null hypotheses - expect non-significance
                if nCond >= min(h-5, nCond)
                    condIdx = min(h-5, nCond);
                    pvals = groupResult.groupPval(condIdx, :);
                    % Pass if NO channels are significant (null hypothesis)
                    hypotheses(h).pvalue = min(pvals);
                    hypotheses(h).pass = all(pvals > alpha);
                end
        end
    end
end

end

function desc = getHypothesisDescription(h)
% GETHYPOTHESISDESCRIPTION Return description for hypothesis number

descriptions = {
    'Speech activates bilateral Heschl''s gyri (HbO increase)'
    'Noise activates bilateral Heschl''s gyri (HbO increase)'
    'Speech activates left IFG (HbO increase)'
    'Speech > noise in left Heschl''s gyrus'
    'Speech > noise in left IFG'
    'No significant activation in occipital cortex (speech)'
    'No significant activation in occipital cortex (noise)'
};

if h >= 1 && h <= 7
    desc = descriptions{h};
else
    desc = sprintf('Hypothesis %d', h);
end

end

function methodName = determineMethodName(methodSpecs, methodType)
% DETERMINEMETHODNAME Create a processing method from pipeline spec
%
% Always creates the method via pf2.methods.raw/oxy.create() so it is
% guaranteed to exist when processFNIRS2 validates the method name.

if isempty(methodSpecs)
    methodName = 'None';
    return;
end

% Build a readable name from the function specs
knownNames = struct(...
    'pf2_MotionCorrectTDDR', 'TDDR', ...
    'pf2_MotionCorrectWavelet', 'Wavelet', ...
    'pf2_SMAR', 'SMAR', ...
    'pf2_TakizawaRejection', 'Takizawa', ...
    'bpf', 'BPF', ...
    'lpf', 'LPF');

nameparts = cellfun(@(x) x{1}, methodSpecs, 'UniformOutput', false);
for i = 1:length(nameparts)
    if isfield(knownNames, nameparts{i})
        nameparts{i} = knownNames.(nameparts{i});
    end
end
methodName = strjoin(nameparts, '_');
methodName = pf2_base.cleanNameForINI(methodName);

funcs = {};
for i = 1:length(methodSpecs)
    spec = methodSpecs{i};
    funcStruct = struct();
    funcStruct.f = spec{1};

    if length(spec) > 1 && ~isempty(spec{2})
        funcStruct.args = spec{2};
        funcStruct.argvals = spec{2};
    else
        switch spec{1}
            case 'pf2_MotionCorrectTDDR'
                funcStruct.args = {'x', 'fs'};
                funcStruct.argvals = {'x', 'fs'};
            case 'pf2_SMAR'
                funcStruct.args = {'x'};
                funcStruct.argvals = {'x'};
            case 'pf2_MotionCorrectWavelet'
                funcStruct.args = {'x', 'fs'};
                funcStruct.argvals = {'x', 'fs'};
            case 'bpf'
                funcStruct.args = {'x', 'filtOrder', 'fs', 'lowF', 'highF'};
                funcStruct.argvals = {'x', 4, 'fs', 0.01, 0.5};
            case 'lpf'
                funcStruct.args = {'x', 'ft', 'fs', 'freq_cut', 'Nf'};
                funcStruct.argvals = {'x', 3, 'fs', 0.1, 4};
            case 'pf2_TakizawaRejection'
                funcStruct.args = {'fNIRstruct'};
                funcStruct.argvals = {'fNIRstruct'};
                funcStruct.output = 'fchMask';
            otherwise
                funcStruct.args = {'x'};
                funcStruct.argvals = {'x'};
        end
    end
    funcStruct.default_argvals = funcStruct.argvals;
    if ~isfield(funcStruct, 'output')
        funcStruct.output = 'x';
    end
    funcs{end+1} = funcStruct; %#ok<AGROW>
end

try
    switch methodType
        case 'raw'
            pf2.methods.raw.create(methodName, funcs, 'Replace', true);
        case 'oxy'
            pf2.methods.oxy.create(methodName, funcs, 'Replace', true);
    end
catch e
    fprintf('  Warning creating method %s: %s\n', methodName, e.message);
    methodName = 'None';
end

end

