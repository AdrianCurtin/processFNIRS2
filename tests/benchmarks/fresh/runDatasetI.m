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

    % Register methods once per pipeline
    rawMethodName = determineMethodName(pipe.rawMethods, 'raw');
    oxyMethodName = determineMethodName(pipe.oxyMethods, 'oxy');

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
            processed = processSingleSubject(rawData, pipe, rawMethodName, oxyMethodName);

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
            for ei = 1:numel(e.stack)
                fprintf('  in %s (line %d)\n', e.stack(ei).name, e.stack(ei).line);
            end
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

function processed = processSingleSubject(rawData, pipe, rawMethodName, oxyMethodName)
% PROCESSSINGLESUBJECT Process one subject through a pipeline
%
% Inputs:
%   rawData       - Raw fNIRS data struct
%   pipe          - Pipeline configuration
%   rawMethodName - Pre-registered raw method name
%   oxyMethodName - Pre-registered oxy method name
%
% Outputs:
%   processed - Processed fNIRS data struct

% Step 0: QC channel rejection (before any processing)
if pipe.useQC && ~isempty(pipe.qcChecks)
    qcArgs = {'Checks', pipe.qcChecks};
    % Unpack qcParams struct into name-value pairs
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

processed = processFNIRS2(rawData, rawMethodName, oxyMethodName, ...
    'DPFmode', pipe.dpfMode);

if pipe.useSSR && isfield(processed, 'probeinfo')
    processed = pf2_base.fnirs.shortChannelRegression(processed, ...
        'Method', pipe.ssrMethod);
end

% Persist QC report if available
if exist('qcReport', 'var')
    processed.qcReport = qcReport;
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
% Computes per-subject condition-averaged activation, then runs group-level
% one-sample t-tests per condition per channel (same output format as GLM).

groupResult = struct();
bioField = pipe.biomarker;

% Discover common conditions and channel count
allCodes = [];
nCh = 0;
for s = 1:length(allProcessed)
    processed = allProcessed{s};
    if ~isempty(processed.markers) && isfield(processed, bioField)
        allCodes = union(allCodes, unique(processed.markers(:, 2)));
        if nCh == 0
            nCh = size(processed.(bioField), 2);
        end
    end
end

if isempty(allCodes) || nCh == 0
    groupResult.error = 'No markers or biomarker data found';
    return;
end

nCond = numel(allCodes);
nSub = length(allProcessed);
condNames = arrayfun(@(c) sprintf('cond_%d', c), allCodes(:)', 'UniformOutput', false);

% Per-subject condition means: [nSub x nCond x nCh]
subjectMeans = NaN(nSub, nCond, nCh);

for s = 1:nSub
    processed = allProcessed{s};
    if isempty(processed.markers) || ~isfield(processed, bioField)
        continue;
    end

    for ci = 1:nCond
        code = allCodes(ci);
        blocks = pf2.data.defineBlocks(processed, code, 'Embed', false);
        if isempty(blocks), continue; end

        segments = pf2.data.extractBlocks(processed, blocks, ...
            'PreTime', pipe.epochWindow(1), 'PostTime', pipe.epochWindow(2), ...
            'BaselineWindow', pipe.baselineWindow, 'SetT0', true);

        if isempty(segments), continue; end

        % Average activation across segments for this subject+condition
        segMeans = [];
        for si = 1:length(segments)
            seg = segments{si};
            if ~isfield(seg, bioField), continue; end

            bioData = seg.(bioField);
            t = seg.time;

            % Response window: post-stimulus onset (t >= 0)
            respMask = t >= 0;
            if sum(respMask) < 2, continue; end

            segMean = mean(bioData(respMask, :), 1, 'omitnan');
            nSegCh = min(numel(segMean), nCh);
            segMeans(end+1, 1:nSegCh) = segMean(1:nSegCh); %#ok<AGROW>
        end

        if ~isempty(segMeans)
            subjectMeans(s, ci, 1:size(segMeans, 2)) = mean(segMeans, 1, 'omitnan');
        end
    end
end

% Remove subjects with all NaN
validSub = squeeze(any(~isnan(subjectMeans), [2, 3]));
subjectMeans = subjectMeans(validSub, :, :);
nSub = size(subjectMeans, 1);

if nSub < 2
    groupResult.error = sprintf('Only %d valid subjects for block averaging', nSub);
    return;
end

% Group statistics: one-sample t-test per condition per channel
groupResult.conditions = condNames;
groupResult.groupBeta = squeeze(mean(subjectMeans, 1, 'omitnan'));  % [nCond x nCh]
groupResult.groupTstat = zeros(nCond, nCh);
groupResult.groupPval = ones(nCond, nCh);

for ci = 1:nCond
    for ch = 1:nCh
        vals = squeeze(subjectMeans(:, ci, ch));
        vals = vals(~isnan(vals));
        if numel(vals) >= 2
            [~, pval, ~, stats] = ttest(vals);
            groupResult.groupTstat(ci, ch) = stats.tstat;
            groupResult.groupPval(ci, ch) = pval;
        end
    end
end

groupResult.nSubjects = nSub;
groupResult.subjectMeans = subjectMeans;
groupResult.channelMap = 1:nCh;  % block-avg uses all channels

end

function groupResult = runGroupGLM(allProcessed, pipe)
% RUNGROUPGLM Group GLM analysis (second-level)
%
% Runs GLM on each subject, then combines betas for group inference.

groupResult = struct();

allBetas = [];
allCondNames = {};
glmChannelMap = [];

for s = 1:length(allProcessed)
    processed = allProcessed{s};
    bioField = pipe.biomarker;
    if isempty(processed.markers) || ~isfield(processed, bioField)
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

    if isempty(glmChannelMap)
        glmChannelMap = longIdx;
    end

    Y = bioData(:, longIdx);
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
groupResult.allBetas = allBetas;
groupResult.channelMap = glmChannelMap;

end

function hypotheses = testAuditoryHypotheses(groupResult)
% TESTAUDITORYHYPOTHESES Test FRESH auditory dataset hypotheses
%
% Tests the 7 group-level hypotheses from the FRESH paper using
% ROI-specific channel subsets derived from the probe geometry.
%
% ROI definitions (from CapTrak coordinates, source-detector midpoints):
%   Left IFG:            channels [1, 3, 4, 6]  — left frontal (y > 0.05)
%   Left Heschl's/STG:   channels [7, 8, 9, 11, 12, 13, 14] — left temporal
%   Right Heschl's/STG:  channels [26, 27, 28, 29, 31, 32] — right temporal
%   Posterior/Occipital:  channels [16, 17, 19, 20, 21, 22, 23, 24]
%   Short-separation:    channels [2, 5, 10, 15, 18, 25, 30, 33] — excluded

hypotheses = struct('name', {}, 'description', {}, 'pass', {}, 'pvalue', {});

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

if ~isfield(groupResult, 'groupPval')
    return;
end

nCond = size(groupResult.groupPval, 1);

% ROI definitions in full 33-channel space
roi = getAuditoryROIs();

% Map ROI indices to result columns via channelMap
if isfield(groupResult, 'channelMap')
    cmap = groupResult.channelMap;
else
    cmap = 1:size(groupResult.groupPval, 2);
end

for h = 1:7
    hypotheses(h).name = sprintf('H%d', h);
    hypotheses(h).description = getHypothesisDescription(h);
    hypotheses(h).pass = false;
    hypotheses(h).pvalue = 1.0;

    switch h
        case 1  % Speech activates bilateral Heschl's gyri
            cols = mapROI(roi.bilateralHeschl, cmap);
            if ~isempty(cols) && nCond >= 1
                pvals = groupResult.groupPval(1, cols);
                hypotheses(h).pvalue = min(pvals);
                hypotheses(h).pass = any(pvals < alpha);
            end

        case 2  % Noise activates bilateral Heschl's gyri
            cols = mapROI(roi.bilateralHeschl, cmap);
            if ~isempty(cols) && nCond >= 2
                pvals = groupResult.groupPval(2, cols);
                hypotheses(h).pvalue = min(pvals);
                hypotheses(h).pass = any(pvals < alpha);
            end

        case 3  % Speech activates left IFG
            cols = mapROI(roi.leftIFG, cmap);
            if ~isempty(cols) && nCond >= 1
                pvals = groupResult.groupPval(1, cols);
                hypotheses(h).pvalue = min(pvals);
                hypotheses(h).pass = any(pvals < alpha);
            end

        case 4  % Speech > noise in left Heschl's gyrus
            cols = mapROI(roi.leftHeschl, cmap);
            if ~isempty(cols) && nCond >= 2
                hypotheses(h).pvalue = contrastPval(groupResult, 1, 2, cols);
                hypotheses(h).pass = hypotheses(h).pvalue < alpha;
            end

        case 5  % Speech > noise in left IFG
            cols = mapROI(roi.leftIFG, cmap);
            if ~isempty(cols) && nCond >= 2
                hypotheses(h).pvalue = contrastPval(groupResult, 1, 2, cols);
                hypotheses(h).pass = hypotheses(h).pvalue < alpha;
            end

        case 6  % No significant activation in occipital (speech)
            cols = mapROI(roi.occipital, cmap);
            if ~isempty(cols) && nCond >= 1
                pvals = groupResult.groupPval(1, cols);
                hypotheses(h).pvalue = min(pvals);
                % PASS if no occipital channel is significant
                hypotheses(h).pass = all(pvals > alpha);
            end

        case 7  % No significant activation in occipital (noise)
            cols = mapROI(roi.occipital, cmap);
            if ~isempty(cols) && nCond >= 2
                pvals = groupResult.groupPval(2, cols);
                hypotheses(h).pvalue = min(pvals);
                % PASS if no occipital channel is significant
                hypotheses(h).pass = all(pvals > alpha);
            end
    end
end

end

function roi = getAuditoryROIs()
% GETAUDITORYROIS Channel-to-ROI mapping for FRESH auditory probe
%
% Derived from CapTrak (RAS) coordinates of the 33-channel montage:
%   12 sources (S1-S12), 20 detectors (D1-D12 long, D13-D20 short-sep)
%
% Classification uses source-detector midpoint coordinates:
%   Left IFG:     x < -0.05, y > 0.05  (left anterior = inferior frontal)
%   Left Heschl:  x < -0.05, |y| < 0.05 (left lateral = auditory cortex)
%   Right Heschl: x > 0.05,  |y| < 0.05 (right lateral = auditory cortex)
%   Occipital:    y < -0.06  (posterior = visual cortex control)

roi.leftIFG = [1, 3, 4, 6];
roi.leftHeschl = [7, 8, 9, 11, 12, 13, 14];
roi.rightHeschl = [26, 27, 28, 29, 31, 32];
roi.bilateralHeschl = [roi.leftHeschl, roi.rightHeschl];
roi.occipital = [16, 17, 19, 20, 21, 22, 23, 24];
roi.shortSep = [2, 5, 10, 15, 18, 25, 30, 33];

end

function cols = mapROI(roiIndices, channelMap)
% MAPROI Find result columns that correspond to ROI channel indices
%
% roiIndices  - channel indices in full 33-channel space
% channelMap  - maps result columns to full channel indices

cols = find(ismember(channelMap, roiIndices));

end

function pval = contrastPval(groupResult, cond1, cond2, cols)
% CONTRASTPVAL One-sided paired t-test on condition difference within ROI
%
% Tests H0: cond1 <= cond2 (i.e., right-tailed test on cond1 - cond2)

perSub = getPerSubjectData(groupResult);
if isempty(perSub)
    pval = 1.0;
    return;
end

% Difference per subject per channel: [nSub x nCols]
diffVals = squeeze(perSub(:, cond1, cols) - perSub(:, cond2, cols));
if isvector(diffVals)
    diffVals = diffVals(:);  % ensure column for single-channel case
end

bestP = 1.0;
for ch = 1:size(diffVals, 2)
    d = diffVals(:, ch);
    d = d(~isnan(d));
    if numel(d) >= 2
        [~, pv] = ttest(d, 0, 'Tail', 'right');
        bestP = min(bestP, pv);
    end
end
pval = bestP;

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

function perSub = getPerSubjectData(groupResult)
% GETPERSUBJECTDATA Extract [nSub x nCond x nCh] array from group result

if isfield(groupResult, 'subjectMeans')
    perSub = groupResult.subjectMeans;
elseif isfield(groupResult, 'allBetas')
    perSub = groupResult.allBetas;
else
    perSub = [];
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

