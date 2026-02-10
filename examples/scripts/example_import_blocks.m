%% example_import_blocks.m - Import metadata and define blocks for Experiment
%
% Demonstrates the typical real-world workflow for setting up a group
% analysis from raw recordings and external metadata files (CSV):
%
%   1. Import raw recordings and process them
%   2. Import subject-level demographics from CSV
%   3. Define blocks from event markers
%   4. Import block-level behavioral data from CSV
%   5. Extract block segments aligned to onset
%   6. Feed into Experiment for group analysis
%
% This mirrors how a researcher would work: fNIRS recordings come from the
% device, demographics come from a screening form (one CSV), and behavioral
% data comes from the stimulus presentation software (one CSV per subject).
%
% Requirements:
%   - processFNIRS2 on path
%   - Sample data available via pf2.import.sampleData.fNIR2000()

outDir = '/tmp/import_blocks_example';
if ~exist(outDir, 'dir'), mkdir(outDir); end

%% Step 1: Create synthetic raw recordings
%
% In a real experiment you would import files from your device:
%   data = pf2.import.importNIR('subject01.nir');
%   data = pf2.import.importSNIRF('subject01.snirf');
%
% Here we build 3 subjects from the sample data with event markers.

fprintf('=== Step 1: Create raw recordings ===\n');

raw = pf2.import.sampleData.fNIR2000();
processed = processFNIRS2(raw);

EASY = 10;
HARD = 20;
REST = 30;
blockDuration = 30;  % seconds

rng(99);
subjectIDs = {'P001', 'P002', 'P003'};
nSubjects  = length(subjectIDs);

subjects = cell(1, nSubjects);
for s = 1:nSubjects
    d = processed;
    d.info.SubjectID = subjectIDs{s};

    % 6 blocks: 2 Easy, 2 Hard, 2 Rest (shuffled order)
    codes  = [EASY, EASY, HARD, HARD, REST, REST];
    codes  = codes(randperm(6));
    onsets = [60, 200, 340, 520, 700, 880] + round(5 * randn(1, 6));
    onsets = max(onsets, 20);

    d.markers = [onsets(:), codes(:), repmat(blockDuration, 6, 1)];
    subjects{s} = d;
end
fprintf('Created %d raw recordings\n\n', nSubjects);


%% Step 2: Create and import subject-level demographics
%
% pf2.data.importInfo reads a CSV and matches rows to data structs by key.
% Non-key columns are copied into each struct's .info field.
%
% The CSV has one row per subject. The key column (SubjectID) must match
% the .info.SubjectID already set on each struct.

fprintf('=== Step 2: Import subject demographics ===\n');

demoFile = fullfile(outDir, 'demographics.csv');
demoTable = table( ...
    {'P001'; 'P002'; 'P003'}, ...
    [24; 31; 58], ...
    {'Female'; 'Male'; 'Female'}, ...
    {'Young'; 'Young'; 'Older'}, ...
    {'Right'; 'Right'; 'Left'}, ...
    'VariableNames', {'SubjectID', 'Age', 'Sex', 'Group', 'Handedness'});
writetable(demoTable, demoFile);
fprintf('Wrote %s\n', demoFile);

% Import: matches by SubjectID, copies Age, Sex, Group, Handedness into .info
subjects = pf2.data.importInfo(subjects, demoFile, 'SubjectID');

% Verify
fprintf('  P001 info: Age=%d, Group=%s, Sex=%s\n', ...
    subjects{1}.info.Age, subjects{1}.info.Group, subjects{1}.info.Sex);
fprintf('  P003 info: Age=%d, Group=%s, Handedness=%s\n', ...
    subjects{3}.info.Age, subjects{3}.info.Group, subjects{3}.info.Handedness);
fprintf('\n');


%% Step 3: Define blocks from event markers
%
% pf2.data.defineBlocks parses the markers array to create block structs.
% ConditionMap assigns human-readable labels based on marker codes.
%
% Each block gets: .startTime, .endTime, .duration, .markerCode, .info

fprintf('=== Step 3: Define blocks from markers ===\n');

conditionMap = {EASY, 'Easy'; HARD, 'Hard'; REST, 'Rest'};

allBlocks = cell(1, nSubjects);
for s = 1:nSubjects
    blk = pf2.data.defineBlocks(subjects{s}, [EASY, HARD, REST], blockDuration, ...
        'ConditionMap', conditionMap);
    allBlocks{s} = blk;
    fprintf('  %s: %d blocks defined\n', subjectIDs{s}, length(blk));
end

% Inspect one block
b1 = allBlocks{1}(1);
fprintf('\n  Block 1 of P001:\n');
fprintf('    Marker code:  %d\n', b1.markerCode);
fprintf('    Condition:    %s\n', b1.info.Condition);
fprintf('    Time:         %.1f - %.1fs (%.1fs)\n', b1.startTime, b1.endTime, b1.duration);
fprintf('    BlockNumber:  %d\n', b1.info.BlockNumber);
fprintf('\n');

% Alternative: use EndMarker instead of fixed duration
%
% When your paradigm uses a terminating marker (e.g. a "rest" marker ends
% each task block), use EndMarker to derive block duration from the markers
% themselves instead of specifying a fixed number:
%
%   % Single shared end marker for all start codes
%   blocks = pf2.data.defineBlocks(data, [EASY, HARD], 'EndMarker', REST);
%
%   % Per-code end markers: EASY->60, HARD->70
%   blocks = pf2.data.defineBlocks(data, [EASY, HARD], 'EndMarker', [60, 70]);
%
% This is equivalent to using StartMarker/EndMarker pairs but uses the
% simpler positional API for specifying start codes.


%% Step 4: Create and import block-level behavioral data
%
% pf2.data.importBlockInfo reads per-trial data from CSV and attaches it
% to block .info structs. Supports positional matching (row order) or
% key-based matching.
%
% Common pattern: one CSV per subject from the stimulus software, with
% one row per trial. Use 'MarkerCode' filter to skip blocks that don't
% have behavioral data (e.g., Rest blocks).

fprintf('=== Step 4: Import block-level behavioral data ===\n');

for s = 1:nSubjects
    nBlk = length(allBlocks{s});

    % Build behavioral data for task blocks only (not Rest)
    taskIdx = find(arrayfun(@(b) b.markerCode ~= REST, allBlocks{s}));
    nTask = length(taskIdx);

    rt  = nan(nTask, 1);
    acc = nan(nTask, 1);
    for t = 1:nTask
        blk = allBlocks{s}(taskIdx(t));
        if blk.markerCode == HARD
            rt(t)  = 420 + randn * 40;
            acc(t) = 0.72 + randn * 0.06;
        else  % EASY
            rt(t)  = 280 + randn * 25;
            acc(t) = 0.94 + randn * 0.03;
        end
    end

    % Write CSV for this subject
    behavFile = fullfile(outDir, sprintf('%s_behavior.csv', subjectIDs{s}));
    behavTable = table(rt, acc, 'VariableNames', {'reactionTime', 'accuracy'});
    writetable(behavTable, behavFile);

    % Import: positional matching to task blocks only (skip Rest via MarkerCode filter)
    allBlocks{s} = pf2.data.importBlockInfo(allBlocks{s}, behavFile, ...
        'MarkerCode', [EASY, HARD]);

    fprintf('  %s: imported %d rows from %s_behavior.csv\n', ...
        subjectIDs{s}, nTask, subjectIDs{s});
end

% Verify: task block should have RT, rest block should not
taskBlk = allBlocks{1}(find(arrayfun(@(b) b.markerCode == HARD, allBlocks{1}), 1));
restBlk = allBlocks{1}(find(arrayfun(@(b) b.markerCode == REST, allBlocks{1}), 1));
fprintf('\n  Hard block info fields: %s\n', strjoin(fieldnames(taskBlk.info), ', '));
fprintf('  Rest block info fields: %s\n', strjoin(fieldnames(restBlk.info), ', '));
fprintf('  Hard block RT=%.1f, acc=%.2f\n', taskBlk.info.reactionTime, taskBlk.info.accuracy);
fprintf('\n');


%% Step 5: Extract block segments
%
% pf2.data.extractBlocks cuts each block from the continuous recording.
% PreTime gives us a baseline period before the block onset.
% SetT0 shifts time so block onset = 0 (standard for event-related designs).
% CopyInfo merges the parent subject .info into each segment's .info.

fprintf('=== Step 5: Extract block segments ===\n');

allSegments = {};
for s = 1:nSubjects
    segs = pf2.data.extractBlocks(subjects{s}, allBlocks{s}, ...
        'PreTime', 10, ...     % 10s before block onset for baseline
        'SetT0', true, ...     % block onset = t=0
        'CopyInfo', true);     % inherit SubjectID, Age, Group, etc.
    allSegments = [allSegments, segs]; %#ok<AGROW>
end

fprintf('Extracted %d segments\n', length(allSegments));

% Verify segment .info has both subject-level and block-level fields
seg1 = allSegments{1};
fprintf('  Segment 1 info fields: %s\n', strjoin(fieldnames(seg1.info), ', '));
fprintf('  SubjectID=%s, Group=%s, Age=%d, Condition=%s\n', ...
    seg1.info.SubjectID, seg1.info.Group, seg1.info.Age, seg1.info.Condition);
fprintf('  Time range: [%.1f, %.1f]s (onset at t=0)\n', ...
    min(seg1.time), max(seg1.time));
fprintf('\n');


%% Step 6: Feed into Experiment for analysis
%
% Segments are ready for Experiment. All .info fields (from subject CSV,
% block CSV, and ConditionMap) are available for select/groupby/stats.

fprintf('=== Step 6: Experiment analysis ===\n');

ex = exploreFNIRS.core.Experiment(allSegments);

% Exclude Rest blocks (no behavioral data)
ex.select('Condition', {'Easy', 'Hard'});
ex.groupby({'Group', 'Condition'});

% Configure preprocessing
ex.settings.baseline = [-5, 0];
ex.settings.taskStart = 0;
ex.settings.taskEnd = 30;
ex.settings.resampleRate = 1;
ex.settings.useBaseline = true;

% Visualize settings
fig = ex.plotExperimentTimeline('Visible', 'off', ...
    'SavePath', fullfile(outDir, 'timeline.png'));
close(fig);

% Aggregate and plot
ex.aggregate();
ex.summary();

% Temporal plot
fig = ex.plotTemporal('Biomarkers', {'HbO'}, 'Channels', 1:2, ...
    'ErrorType', 'SEM', ...
    'Title', 'Group x Condition: HbO', ...
    'Visible', 'off', 'SavePath', fullfile(outDir, 'temporal.png'));
close(fig);

% Bar chart
fig = ex.plotBar('Biomarker', 'HbO', 'Channels', 1:2, ...
    'PlotBy', 'Condition', 'ShowIndividual', true, ...
    'Title', 'Group x Condition: Mean HbO', ...
    'Visible', 'off', 'SavePath', fullfile(outDir, 'bar.png'));
close(fig);

% Behavioral bar (no aggregate needed for info variables)
fig = ex.plotInfoBar('reactionTime', ...
    'YLabel', 'RT (ms)', ...
    'Title', 'Reaction Time by Group x Condition', ...
    'Visible', 'off', 'SavePath', fullfile(outDir, 'rt_bar.png'));
close(fig);

fprintf('\n');


%% Step 7: Export for external statistics
%
% The long table includes all .info fields plus binned fNIRS data,
% ready for R (lme4), Python (statsmodels), or SPSS.

fprintf('=== Step 7: Export ===\n');

longT = ex.toLongTable({'HbO', 'HbR'}, 1:3);
writetable(longT, fullfile(outDir, 'results_long.csv'));
fprintf('Long table: %d rows x %d cols\n', height(longT), width(longT));
fprintf('Columns: %s\n', strjoin(longT.Properties.VariableNames, ', '));

% Also export info table (behavioral data only)
infoT = ex.infoTable();
writetable(infoT, fullfile(outDir, 'info_table.csv'));
fprintf('Info table: %d rows x %d cols\n', height(infoT), width(infoT));


%% Summary
fprintf('\n=== All steps complete ===\n');
fprintf('Output files in: %s\n', outDir);
d = dir(fullfile(outDir, '*'));
d = d(~[d.isdir]);
for i = 1:length(d)
    fprintf('  %s (%.1f KB)\n', d(i).name, d(i).bytes/1024);
end
