%% tutorial_batch_workflow.m - Directory import, CSV metadata, and batch export
%
% Demonstrates the realistic multi-subject workflow for a lab that stores
% one fNIRS file per subject in a directory tree and tracks experiment
% metadata in a single CSV:
%
%   1. Set up a fictional study directory structure
%   2. Batch-import all files with importDirectory
%   3. Merge subject metadata from a single CSV with importInfo
%   4. Process all subjects headlessly
%   5. Define blocks from markers and extract segments
%   6. Build an Experiment for group analysis
%   7. Run statistics and generate plots
%   8. Batch export processed data back to a directory tree
%
% Fictional study: "SpeechFNIRS" — a cognitive neuroscience experiment
% comparing neural responses to natural vs synthetic speech across two age
% groups (Young, Older). Each subject hears 6 blocks of speech (3 Natural,
% 3 Synthetic, interleaved) while fNIRS records prefrontal cortex activity.
%
% Study directory layout:
%
%   SpeechFNIRS/
%   ├── Young/
%   │   ├── SP01/
%   │   │   └── SP01.snirf
%   │   ├── SP02/
%   │   │   └── SP02.snirf
%   │   └── SP03/
%   │       └── SP03.snirf
%   └── Older/
%       ├── SP04/
%       │   └── SP04.snirf
%       ├── SP05/
%       │   └── SP05.snirf
%       └── SP06/
%           └── SP06.snirf
%
% Experiment CSV (one row per subject):
%
%   SubjectID, Group, Age, Sex, HearingLevel_dB, Education_yrs, MMSE
%   SP01,      Young, 23,  F,   12,              16,            30
%   SP02,      Young, 27,  M,   8,               18,            30
%   ...
%
% Requirements:
%   - processFNIRS2 on the MATLAB path
%   - Sample data: pf2.import.sampleData.fNIR2000()

cd('/Users/adriancurtin/Documents/GitHub/processFNIRS2');

studyRoot = fullfile(tempdir, 'SpeechFNIRS');
if isfolder(studyRoot), rmdir(studyRoot, 's'); end

% Uncomment to save figures and exports to disk:
% outDir = fullfile(tempdir, 'SpeechFNIRS_output');
% if isfolder(outDir), rmdir(outDir, 's'); end
% mkdir(outDir);


%% ========================================================================
%  PART 1: CREATE FICTIONAL STUDY DATA
%  ========================================================================
%
%  In a real experiment, these files already exist from your recording
%  sessions. Here we build them from sample data to make the tutorial
%  self-contained.
%
%  We export 6 subjects as individual SNIRF files, organized by group.

fprintf('=== Part 1: Create fictional study data ===\n');

% Load sample data as our template
template = pf2.import.sampleData.fNIR2000();

% Define our fictional subjects
subjects = struct( ...
    'id',    {'SP01','SP02','SP03','SP04','SP05','SP06'}, ...
    'group', {'Young','Young','Young','Older','Older','Older'});

% Marker codes for the two speech conditions
NATURAL   = 10;
SYNTHETIC = 20;

rng(42);  % reproducible randomness

for s = 1:length(subjects)
    d = template;
    d.info.SubjectID = subjects(s).id;

    % Create 6 interleaved speech blocks starting at t=60s
    codes  = [NATURAL, SYNTHETIC, NATURAL, SYNTHETIC, NATURAL, SYNTHETIC];
    onsets = 60 + (0:5) * 90 + round(3 * randn(1, 6));  % ~90s apart, jittered
    onsets = max(onsets, 30);

    d.markers = pf2_base.normalizeMarkers([onsets(:), codes(:), zeros(6,1), ones(6,1)]);

    % Add a bit of per-subject noise so data aren't identical
    d.raw = d.raw + 0.01 * randn(size(d.raw)) * s;

    % Build directory path: studyRoot / Group / SubjectID /
    subDir = fullfile(studyRoot, subjects(s).group, subjects(s).id);
    mkdir(subDir);

    % Export as SNIRF (this is what a real device would produce)
    pf2.export.asSNIRF(d, fullfile(subDir, [subjects(s).id '.snirf']));
end

fprintf('  Created %d SNIRF files in %s\n', length(subjects), studyRoot);

% --- Create the experiment CSV ---
%
% This is the kind of spreadsheet a lab manager maintains: one row per
% subject, with demographics and screening scores.

csvPath = fullfile(studyRoot, 'experiment_metadata.csv');
metaTable = table( ...
    {'SP01'; 'SP02'; 'SP03'; 'SP04'; 'SP05'; 'SP06'}, ...
    {'Young'; 'Young'; 'Young'; 'Older'; 'Older'; 'Older'}, ...
    [23; 27; 25; 62; 68; 71], ...
    {'F'; 'M'; 'F'; 'M'; 'F'; 'M'}, ...
    [12; 8; 10; 22; 18; 25], ...
    [16; 18; 17; 14; 12; 16], ...
    [30; 30; 30; 28; 29; 27], ...
    'VariableNames', {'SubjectID','Group','Age','Sex', ...
                      'HearingLevel_dB','Education_yrs','MMSE'});
writetable(metaTable, csvPath);
fprintf('  Wrote experiment CSV: %s\n\n', csvPath);


%% ========================================================================
%  PART 2: BATCH IMPORT
%  ========================================================================
%
%  importDirectory recursively finds all .snirf files and imports them.
%  Dir1 and Dir2 map the two directory levels (Group, SubjectID) into
%  each struct's .info field automatically.
%
%  After this step every struct has:
%    .info.Group      = 'Young' or 'Older'   (from directory name)
%    .info.SubjectID  = 'SP01', 'SP02', ...  (from directory name)

fprintf('=== Part 2: Batch import with importDirectory ===\n');

allData = pf2.import.importDirectory(studyRoot, '*.snirf', ...
    'Dir1', 'Group', ...
    'Dir2', 'SubjectID');

fprintf('\n  Imported %d subjects\n', numel(allData));
fprintf('  First subject: Group=%s, SubjectID=%s\n', ...
    allData{1}.info.Group, allData{1}.info.SubjectID);


%% ========================================================================
%  PART 3: MERGE EXPERIMENT METADATA FROM CSV
%  ========================================================================
%
%  importInfo reads the CSV and matches each struct by SubjectID. All
%  non-key columns (Age, Sex, HearingLevel_dB, etc.) are copied into
%  each struct's .info field.
%
%  This is a single call — no per-subject loop needed.

fprintf('\n=== Part 3: Merge metadata from CSV ===\n');

allData = pf2.data.importInfo(allData, csvPath, 'SubjectID');

% Verify the merge
for i = 1:numel(allData)
    d = allData{i};
    fprintf('  %s: Group=%s, Age=%d, Sex=%s, Hearing=%ddB, MMSE=%d\n', ...
        d.info.SubjectID, d.info.Group, d.info.Age, d.info.Sex, ...
        d.info.HearingLevel_dB, d.info.MMSE);
end


%% ========================================================================
%  PART 4: BATCH PROCESS
%  ========================================================================
%
%  processFNIRS2 accepts a cell array and processes each element.
%  All subjects get the same processing pipeline.

fprintf('\n=== Part 4: Batch process ===\n');

allProcessed = processFNIRS2(allData, ...
    'DPFmode', 'Calc', ...
    'blLength', 10, ...
    'blStartTime', 0);

fprintf('  Processed %d subjects\n', numel(allProcessed));
fprintf('  Output fields: HbO [%d x %d], units=%s\n', ...
    size(allProcessed{1}.HbO), allProcessed{1}.units);


%% ========================================================================
%  PART 5: DEFINE BLOCKS AND EXTRACT SEGMENTS
%  ========================================================================
%
%  For each subject:
%    1. defineBlocks converts markers into block structs
%    2. extractBlocks cuts the continuous recording into epochs
%    3. CopyInfo inherits all .info fields (Group, Age, Sex, etc.)

fprintf('\n=== Part 5: Define blocks and extract segments ===\n');

conditionMap = {NATURAL, 'Natural'; SYNTHETIC, 'Synthetic'};
blockDuration = 30;  % seconds

allSegments = {};
for i = 1:numel(allProcessed)
    d = allProcessed{i};

    % Define blocks from markers
    blocks = pf2.data.defineBlocks(d, ...
        'MarkerCode', [NATURAL, SYNTHETIC], ...
        'Duration', blockDuration, ...
        'ConditionMap', conditionMap, ...
        'Embed', false);

    % Extract segments: 5s baseline before, 15s HRF tail after
    segs = pf2.data.extractBlocks(d, blocks, ...
        'PreTime', 5, ...
        'PostTime', 15, ...
        'SetT0', true, ...
        'CopyInfo', true);

    allSegments = [allSegments, segs]; %#ok<AGROW>

    fprintf('  %s: %d blocks -> %d segments\n', ...
        d.info.SubjectID, numel(blocks), numel(segs));
end

fprintf('  Total segments: %d\n', numel(allSegments));

% Verify a segment carries all metadata
seg = allSegments{1};
fprintf('  Example segment info: SubjectID=%s, Group=%s, Age=%d, Condition=%s\n', ...
    seg.info.SubjectID, seg.info.Group, seg.info.Age, seg.info.Condition);


%% ========================================================================
%  PART 6: BUILD EXPERIMENT
%  ========================================================================
%
%  The Experiment class organizes segments for group analysis. We group
%  by Group and Condition to compare Young vs Older x Natural vs Synthetic.

fprintf('\n=== Part 6: Build Experiment ===\n');

ex = exploreFNIRS.core.Experiment(allSegments);

% Configure analysis settings
ex.settings.baseline = [-5, 0];     % baseline window (seconds)
ex.settings.taskStart = 0;          % task onset
ex.settings.taskEnd = blockDuration;
ex.settings.resampleRate = 1;       % 1 Hz for temporal plots
ex.settings.barBinSize = 15;        % 15s bins for bar charts
ex.settings.useBaseline = true;
ex.settings.avgMode = 'hierarchy';

% Select, group, aggregate
ex.select('Condition', {'Natural', 'Synthetic'});
ex.groupby({'Group', 'Condition'});
ex.aggregate();

ex.summary();


%% ========================================================================
%  PART 7: ANALYSIS — PLOTS AND STATISTICS
%  ========================================================================

fprintf('\n=== Part 7: Analysis ===\n');

% --- Temporal plot: HbO across conditions ---
fig = ex.plotTemporal('Biomarkers', {'HbO', 'HbR'}, 'Channels', 1:4, ...
    'PlotBy', 'Condition', ...
    'Title', 'Speech Processing: Group x Condition');
% fig = ex.plotTemporal('Biomarkers', {'HbO', 'HbR'}, 'Channels', 1:4, ...
%     'PlotBy', 'Condition', ...
%     'Title', 'Speech Processing: Group x Condition', ...
%     'Visible', 'off', 'SavePath', fullfile(outDir, 'temporal_speech.png'));
% close(fig);

% --- Bar chart ---
fig = ex.plotBar('Biomarker', 'HbO', 'Channels', 1:4, ...
    'PlotBy', 'Condition', 'ShowIndividual', true, ...
    'Title', 'Mean HbO: Group x Condition');
% fig = ex.plotBar('Biomarker', 'HbO', 'Channels', 1:4, ...
%     'PlotBy', 'Condition', 'ShowIndividual', true, ...
%     'Title', 'Mean HbO: Group x Condition', ...
%     'Visible', 'off', 'SavePath', fullfile(outDir, 'bar_speech.png'));
% close(fig);

% --- LME statistics ---
% Pass 'AllInteractions', true so the model includes the Group x Condition
% interaction (the default fits an additive Group + Condition main-effects
% model). The section title above promises the interaction.
results = ex.statsFitLME('Biomarkers', {'HbO'}, 'Channels', 1:4, ...
    'AllInteractions', true);
fprintf('  LME formula: %s\n', results.formula);
T_anova = ex.statsSummarize(results, 'Type', 'anova');
fprintf('  ANOVA summary:\n');
disp(T_anova);


%% ========================================================================
%  PART 8: EXPORT
%  ========================================================================
%
%  Three export paths:
%
%  A) Tabular export (CSV) — for R, Python, SPSS
%  B) Batch file export (SNIRF) — processed data back to directory tree
%  C) Batch file export (NIR) — same data in legacy format

fprintf('=== Part 8: Export ===\n');

% --- A: Tabular export for external stats ---
longT = ex.toLongTable({'HbO', 'HbR'}, 1:4);
fprintf('  Long table: %d rows x %d cols\n', height(longT), width(longT));
fprintf('  Columns: %s\n', strjoin(longT.Properties.VariableNames, ', '));
% writetable(longT, fullfile(outDir, 'speech_results_long.csv'));

% --- B: Batch export processed SNIRF files ---
%
%  This is the inverse of importDirectory. Dir1 recreates the Group
%  subdirectories, and Prefix builds filenames from SubjectID.
%  The output mirrors the original study layout:
%
%    output/snirf/Young/SP01.snirf
%    output/snirf/Young/SP02.snirf
%    output/snirf/Older/SP04.snirf
%    ...

% pf2.export.asSNIRF(allProcessed, fullfile(outDir, 'snirf'), ...
%     'Dir1', 'Group', ...
%     'Prefix', {'SubjectID'});
% fprintf('  Batch exported %d SNIRF files\n', numel(allProcessed));

% --- C: Batch export segments with richer naming ---
%
%  Export each segment with Group subdirectory and a filename built from
%  SubjectID + Condition. Useful for sharing individual epochs.

% pf2.export.asSNIRF(allSegments, fullfile(outDir, 'segments'), ...
%     'Dir1', 'Group', ...
%     'Prefix', {'SubjectID', 'Condition'});
% fprintf('  Batch exported %d segment SNIRF files\n', numel(allSegments));


%% ========================================================================
%  SUMMARY
%  ========================================================================

fprintf('\n=== Tutorial complete ===\n');
fprintf('Study root:  %s\n', studyRoot);

fprintf('\nWorkflow recap:\n');
fprintf('  1. pf2.import.importDirectory(dir, pat, ''Dir1'', ''Group'', ...)\n');
fprintf('     -> cell array with .info.Group, .info.SubjectID from folders\n');
fprintf('  2. pf2.data.importInfo(allData, ''metadata.csv'', ''SubjectID'')\n');
fprintf('     -> merges Age, Sex, MMSE, etc. into .info from one CSV\n');
fprintf('  3. processFNIRS2(allData, ...)  -> batch headless processing\n');
fprintf('  4. defineBlocks + extractBlocks -> time-locked segments\n');
fprintf('  5. Experiment -> select, groupby, aggregate -> stats & plots\n');
fprintf('  6. pf2.export.asSNIRF(allData, dir, ''Dir1'',''Group'', ...)\n');
fprintf('     -> batch export back to directory tree (inverse of import)\n');


function listDir(dirPath, rootPath)
% Recursively list directory contents with relative paths
    items = dir(dirPath);
    items = items(~ismember({items.name}, {'.', '..'}));
    for i = 1:numel(items)
        relPath = strrep(fullfile(items(i).folder, items(i).name), ...
            [rootPath filesep], '');
        if items(i).isdir
            fprintf('  %s/\n', relPath);
            listDir(fullfile(items(i).folder, items(i).name), rootPath);
        else
            fprintf('  %s (%.1f KB)\n', relPath, items(i).bytes/1024);
        end
    end
end
