% RUNDATASETII Run FRESH benchmark on Dataset II (Motor: Finger Tapping)
%
% Processes all subjects in the FRESH Motor dataset through each pipeline
% configuration and saves per-subject results for later analysis.
%
% Dataset II structure (BIDS with sessions):
%   sub-XX/ses-left2s/nirs/*.snirf   - Left hand, 2s tapping blocks
%   sub-XX/ses-left3s/nirs/*.snirf   - Left hand, 3s tapping blocks
%   sub-XX/ses-right2s/nirs/*.snirf  - Right hand, 2s tapping blocks
%   sub-XX/ses-right3s/nirs/*.snirf  - Right hand, 3s tapping blocks
%
% Each session has 25 trials of finger tapping (single condition per run).
% The events.tsv contains onset, duration, trial_type='motor', value=1.
%
% Hypotheses (individual-level):
%   H1: Left tapping activates right motor cortex (HbO increase)
%   H2: Right tapping activates left motor cortex (HbO increase)
%   H3: Contralateral > ipsilateral activation
%   H4: 3s blocks produce larger responses than 2s blocks
%
% See also: benchmarks.fresh.definePipelines, benchmarks.fresh.analyzeResults

fprintf('\n=== FRESH Benchmark: Dataset II (Motor) ===\n');
fprintf('Started: %s\n\n', datetime('now'));

% --- Setup paths ---
scriptDir = fileparts(mfilename('fullpath'));
benchmarkRoot = fileparts(scriptDir);
dataDir = fullfile(benchmarkRoot, 'data', 'dataset_II_motor');
resultsDir = fullfile(benchmarkRoot, 'results', 'datasetII');

if ~isfolder(dataDir)
    error('Dataset II not found at %s. Run setup.m first.', dataDir);
end

if ~isfolder(resultsDir)
    mkdir(resultsDir);
end

% --- Load pipeline definitions ---
pipelines = definePipelines();
nPipelines = length(pipelines);
fprintf('Loaded %d pipeline configurations.\n', nPipelines);

% --- Find subjects and sessions ---
subDirs = dir(fullfile(dataDir, 'sub-*'));
subDirs = subDirs([subDirs.isdir]);
nSubjects = length(subDirs);
fprintf('Found %d subjects.\n', nSubjects);

% Session definitions (each is a separate condition)
sessionDefs = {
    'ses-left2s',  'Left hand 2s tapping'
    'ses-left3s',  'Left hand 3s tapping'
    'ses-right2s', 'Right hand 2s tapping'
    'ses-right3s', 'Right hand 3s tapping'
};
nSessions = size(sessionDefs, 1);
fprintf('Sessions per subject: %d\n\n', nSessions);

if nSubjects == 0
    error('No subject directories found in %s', dataDir);
end

% --- Pre-register methods for all pipelines ---
pipeMethodNames = struct();
for p = 1:nPipelines
    pipe = pipelines(p);
    pipeMethodNames(p).raw = determineMethodName(pipe.rawMethods, 'raw');
    pipeMethodNames(p).oxy = determineMethodName(pipe.oxyMethods, 'oxy');
end

% --- Process each subject x session x pipeline ---
for s = 1:nSubjects
    subName = subDirs(s).name;
    fprintf('--- Subject %d/%d: %s ---\n', s, nSubjects, subName);

    for p = 1:nPipelines
        pipe = pipelines(p);
        pipeResultDir = fullfile(resultsDir, pipe.name);
        if ~isfolder(pipeResultDir)
            mkdir(pipeResultDir);
        end

        resultFile = fullfile(pipeResultDir, sprintf('%s.mat', subName));

        % Skip if already processed
        if isfile(resultFile)
            fprintf('  [%s] already exists, skipping.\n', pipe.name);
            continue;
        end

        fprintf('  Pipeline: %s\n', pipe.name);

        subjectResult = struct();
        subjectResult.subjectID = subName;
        subjectResult.pipeline = pipe.name;
        subjectResult.sessions = struct();

        for si = 1:nSessions
            sesName = sessionDefs{si, 1};
            sesDesc = sessionDefs{si, 2};
            nirsDir = fullfile(dataDir, subName, sesName, 'nirs');

            if ~isfolder(nirsDir)
                fprintf('    %s: NOT FOUND\n', sesName);
                continue;
            end

            snirfFiles = dir(fullfile(nirsDir, '*.snirf'));
            if isempty(snirfFiles)
                fprintf('    %s: no SNIRF file\n', sesName);
                continue;
            end

            filepath = fullfile(nirsDir, snirfFiles(1).name);
            fprintf('    %s ... ', sesName);

            try
                % Import (events.tsv loaded automatically by importSNIRF)
                rawData = pf2.import.importSNIRF(filepath, false);
                rawData.info.SubjectID = subName;
                rawData.info.Session = sesName;
                rawData.info.Condition = sesDesc;

                % Process through pipeline
                sesResult = runSingleSession(rawData, pipe, pipeMethodNames(p).raw, pipeMethodNames(p).oxy);
                sesResult.session = sesName;
                sesResult.condition = sesDesc;

                subjectResult.sessions.(strrep(sesName, '-', '_')) = sesResult;
                fprintf('OK\n');

            catch e
                fprintf('ERROR: %s\n', e.message);
            end
        end

        % Save per-subject result (all sessions)
        try
            result = subjectResult;
            save(resultFile, 'result', '-v7.3');
        catch e
            fprintf('  Save error: %s\n', e.message);
        end
    end

    fprintf('\n');
end

fprintf('\n=== Dataset II Benchmark Complete ===\n');
fprintf('Results saved to: %s\n', resultsDir);
fprintf('Finished: %s\n', datetime('now'));

%%_Subfunctions_________________________________________________________

function result = runSingleSession(rawData, pipe, rawMethodName, oxyMethodName)
% RUNSINGLESESSION Process one session through a pipeline
%
% Inputs:
%   rawData       - Raw fNIRS data struct (with markers from events.tsv)
%   pipe          - Pipeline configuration struct
%   rawMethodName - Pre-registered raw method name
%   oxyMethodName - Pre-registered oxy method name
%
% Outputs:
%   result - Struct with processed data and analysis results

% Step 0: QC channel rejection (before any processing)
if pipe.useQC && ~isempty(pipe.qcChecks)
    qcArgs = {'Checks', pipe.qcChecks};
    if ~isempty(fieldnames(pipe.qcParams))
        paramNames = fieldnames(pipe.qcParams);
        for qi = 1:numel(paramNames)
            qcArgs{end+1} = paramNames{qi}; %#ok<AGROW>
            qcArgs{end+1} = pipe.qcParams.(paramNames{qi}); %#ok<AGROW>
        end
    end
    qcReport = pf2.qc.pipeline.assess(rawData, qcArgs{:});
    rawData = pf2.qc.pipeline.apply(rawData, qcReport);
    fprintf('[QC: %d/%d pass] ', sum(qcReport.pass), numel(qcReport.pass));
end

% Process
processed = processFNIRS2(rawData, rawMethodName, oxyMethodName, ...
    'DPFmode', pipe.dpfMode);

% Apply SSR if configured
if pipe.useSSR && isfield(processed, 'probeinfo')
    processed = pf2_base.fnirs.shortChannelRegression(processed, ...
        'Method', pipe.ssrMethod);
end

% Run analysis
switch pipe.analysisType
    case 'blockavg'
        result = runBlockAvg(processed, pipe);
    case 'glm'
        result = runGLM(processed, pipe);
end

% Persist QC report if available
if exist('qcReport', 'var')
    result.qcReport = qcReport;
end

end

function result = runBlockAvg(processed, pipe)
% RUNBLOCKAVG Block averaging analysis for a single session

result = struct();

bioField = pipe.biomarker;
if ~isfield(processed, bioField) || isempty(processed.markers)
    result.error = sprintf('No %s or markers', bioField);
    return;
end

uniqueCodes = unique(processed.markers(:, 2));
blocks = pf2.data.defineBlocks(processed, uniqueCodes, 'Embed', false);

if isempty(blocks)
    result.error = 'No blocks defined';
    return;
end

segments = pf2.data.extractBlocks(processed, blocks, ...
    'PreTime', pipe.epochWindow(1), 'PostTime', pipe.epochWindow(2), ...
    'BaselineWindow', pipe.baselineWindow, 'SetT0', true);

if isempty(segments)
    result.error = 'No valid segments';
    return;
end

% Average biomarker across all trials (single condition per session)
nCh = size(segments{1}.(bioField), 2);
trialMeans = zeros(length(segments), nCh);
for t = 1:length(segments)
    trialMeans(t, :) = mean(segments{t}.(bioField), 1, 'omitnan');
end

result.meanHbO = mean(trialMeans, 1, 'omitnan');
result.seHbO = std(trialMeans, 0, 1, 'omitnan') / sqrt(length(segments));
result.nTrials = length(segments);
result.nChannels = nCh;

end

function result = runGLM(processed, pipe)
% RUNGLM GLM analysis for a single session

result = struct();

bioField = pipe.biomarker;
if ~isfield(processed, bioField) || isempty(processed.markers)
    result.error = sprintf('No %s or markers', bioField);
    return;
end

% Build events from markers (single condition per session)
uniqueCodes = unique(processed.markers(:, 2));
events = struct([]);
for ci = 1:length(uniqueCodes)
    code = uniqueCodes(ci);
    codeMask = processed.markers(:, 2) == code;
    events(ci).name = sprintf('cond_%d', code);
    events(ci).onsets = processed.markers(codeMask, 1)';
    durations = processed.markers(codeMask, 3)';
    if all(durations == 0)
        durations = 2;  % Default for motor task
    end
    events(ci).duration = durations;
end

[X, names] = pf2_base.fnirs.buildDesignMatrix(processed.time, processed.fs, events, ...
    'DriftOrder', pipe.glmDriftOrder);

% Get long channels only
bioData = processed.(bioField);
if isfield(processed, 'probeinfo') && isfield(processed.probeinfo, 'Probe')
    probe = processed.probeinfo.Probe{1};
    if isfield(probe, 'IsShortSeparation')
        longIdx = find(~probe.IsShortSeparation);
    else
        longIdx = 1:size(bioData, 2);
    end
else
    longIdx = 1:size(bioData, 2);
end

Y = bioData(:, longIdx);

glmResult = pf2_base.fnirs.fitGLM(Y, X, names, 'Method', pipe.glmMethod);

result.glm = glmResult;
result.longChannelIdx = longIdx;
result.nChannels = length(longIdx);

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
    'pf2_MotionCorrectSpline', 'Spline', ...
    'pf2_MotionCorrectSplineSG', 'SplineSG', ...
    'pf2_sSMART', 'sSMART', ...
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
            case 'pf2_sSMART'
                funcStruct.args = {'x', 'fs', 'chNum', 'tauArtifact'};
                funcStruct.argvals = {'x', 'fs', [], 4.5};
            case 'pf2_MotionCorrectWavelet'
                funcStruct.args = {'x', 'fs'};
                funcStruct.argvals = {'x', 'fs'};
            case 'pf2_MotionCorrectSpline'
                funcStruct.args = {'x', 'fs'};
                funcStruct.argvals = {'x', 'fs'};
            case 'pf2_MotionCorrectSplineSG'
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
