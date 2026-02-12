%% tutorial_end_to_end.m - Full pipeline: Import → Process → Blocks → Experiment
%
% This tutorial walks through the complete processFNIRS2 workflow:
%
%   1. Import raw fNIRS data
%   2. Set processing options and convert to hemoglobin
%   3. Define task blocks from event markers
%   4. Extract block segments (time-locked epochs)
%   5. Create an Experiment for group analysis
%   6. Three output paths:
%      a) Scripted stats & plots (no GUI)
%      b) Export to CSV or MATLAB table
%      c) Open the exploreFNIRS GUI with settings pre-loaded
%
% The sample data has no markers, so we inject synthetic ones to
% demonstrate the block workflow. With real data you'd skip that step.
%
% Requirements:
%   - processFNIRS2 on the MATLAB path
%   - Sample data: pf2.import.sampleData.fNIR2000()

cd('/Users/adriancurtin/Documents/GitHub/processFNIRS2');
outDir = fullfile(tempdir, 'pf2_tutorial');
if ~exist(outDir, 'dir'), mkdir(outDir); end

%% ========================================================================
%  PART 1: IMPORT
%  ========================================================================
%
%  processFNIRS2 supports several device formats:
%
%    data = pf2.import.importNIR(filepath);        % fNIR Devices / Biopac (.nir)
%    data = pf2.import.importSNIRF(filepath);      % SNIRF format (.snirf)
%    data = pf2.import.importHitachiMES(filepath);  % Hitachi ETG-4000 (.mes)
%    data = pf2.import.importNIRX(filepath);        % NIRx (.hdr/.wl1/.wl2)
%
%  For this tutorial we use built-in sample data:

fprintf('=== Part 1: Import ===\n');
raw = pf2.import.sampleData.fNIR2000();

fprintf('  Channels:  %d\n', size(raw.raw, 2));
fprintf('  Samples:   %d\n', size(raw.raw, 1));
fprintf('  Rate:      %.1f Hz\n', raw.fs);
fprintf('  Duration:  %.1f seconds\n', max(raw.time) - min(raw.time));

%% ========================================================================
%  PART 2: PROCESS
%  ========================================================================
%
%  processFNIRS2 converts raw light intensity to hemoglobin concentrations
%  in three stages:
%
%    Stage 1: Raw intensity → Optical density (log transform)
%    Stage 2: OD → Hemoglobin (Modified Beer-Lambert Law)
%    Stage 3: Hemoglobin → Filtered hemoglobin
%
%  Key parameters:
%    ShowGUI         - false for headless / true for interactive
%    DPFmode         - 'Calc' (age-based), 'Fixed', or 'None'
%    defaultSubjectAge - age in years (for DPF calculation)
%    blLength        - baseline length in seconds
%    blStartTime     - baseline start (seconds from recording start)
%    Raw_Method      - name of raw-stage processing method (e.g. 'x5_TDDR')
%    Oxy_Method      - name of oxy-stage processing method (e.g. 'lpf_car')

fprintf('\n=== Part 2: Process ===\n');

processed = processFNIRS2(raw, ...
    'DPFmode', 'Calc', ...
    'defaultSubjectAge', 30, ...
    'blLength', 10, ...
    'blStartTime', 0);

fprintf('  Output fields: HbO, HbR, HbTotal, HbDiff, CBSI\n');
fprintf('  HbO size:  %d timepoints x %d channels\n', size(processed.HbO));
fprintf('  Units:     %s\n', processed.units);

%% ========================================================================
%  PART 3: DEFINE BLOCKS
%  ========================================================================
%
%  Task blocks are epochs of interest within a continuous recording.
%  They're defined by event markers embedded in the data.
%
%  Markers format: [time_sec, code, duration, amplitude]
%
%  The sample data has no markers, so we create a synthetic experiment:
%    - 6 blocks alternating between "Task A" (code 10) and "Task B" (code 20)
%    - Each block is 30 seconds long
%    - Blocks start every 60 seconds beginning at t=60

fprintf('\n=== Part 3: Define Blocks ===\n');

% Inject synthetic markers (skip this with real data that has markers)
processed.markers = [
     60, 10, 0, 1;   % Task A at 60s
    120, 20, 0, 1;   % Task B at 120s
    180, 10, 0, 1;   % Task A at 180s
    240, 20, 0, 1;   % Task B at 240s
    300, 10, 0, 1;   % Task A at 300s
    360, 20, 0, 1;   % Task B at 360s
];

% Define blocks: marker codes [10, 20], 30 seconds each
% ConditionMap labels each code with a human-readable name
blocks = pf2.data.defineBlocks(processed, ...
    'MarkerCode', [10, 20], ...
    'Duration', 30, ...
    'ConditionMap', {10, 'TaskA'; 20, 'TaskB'}, ...
    'Embed', false);

fprintf('  Found %d blocks:\n', length(blocks));
for i = 1:length(blocks)
    fprintf('    Block %d: code=%d (%s), %.0f-%.0fs\n', ...
        i, blocks(i).markerCode, blocks(i).info.Condition, ...
        blocks(i).startTime, blocks(i).endTime);
end

%% ========================================================================
%  PART 4: EXTRACT SEGMENTS
%  ========================================================================
%
%  extractBlocks cuts the continuous recording into time-locked segments.
%
%  Key options:
%    PreTime         - seconds before block onset to include (for baseline)
%    PostTime        - seconds after block end to include
%    BaselineWindow  - [start, end] relative to onset for baseline correction
%    SetT0           - shift time so block onset = 0
%    CopyInfo        - merge parent .info fields into each segment

fprintf('\n=== Part 4: Extract Segments ===\n');

segments = pf2.data.extractBlocks(processed, blocks, ...
    'PreTime', 5, ...            % 5s before onset (baseline period)
    'PostTime', 2, ...           % 2s after block end
    'BaselineWindow', [-5, 0], ...  % baseline correction window
    'SetT0', true, ...           % onset = t0
    'CopyInfo', true);

fprintf('  Extracted %d segments\n', length(segments));
seg1 = segments{1};
fprintf('  Segment 1: %.1f to %.1f s, %d channels\n', ...
    min(seg1.time), max(seg1.time), size(seg1.HbO, 2));
fprintf('  Info fields: %s\n', strjoin(fieldnames(seg1.info), ', '));

%% ========================================================================
%  PART 5: BUILD MULTI-SUBJECT DATASET
%  ========================================================================
%
%  In a real experiment you'd process each subject's file separately and
%  collect all segments. Here we simulate 3 subjects by duplicating and
%  labeling the segments.

fprintf('\n=== Part 5: Build Multi-Subject Dataset ===\n');

rng(42);
allSegments = {};
subjectIDs = {'Sub01', 'Sub02', 'Sub03'};
groups = {'Young', 'Young', 'Older'};

for s = 1:length(subjectIDs)
    for i = 1:length(segments)
        seg = segments{i};

        % Label this segment
        seg.info.SubjectID = subjectIDs{s};
        seg.info.Group = groups{s};
        seg.info.Session = 'S1';
        seg.info.Trial = ceil(i / 2);  % blocks pair into trials

        % Add some subject-level variation (synthetic)
        noise = 0.05 * randn(size(seg.HbO));
        seg.HbO = seg.HbO + noise * (s * 0.3);
        seg.HbR = seg.HbR - noise * (s * 0.2);

        allSegments{end+1} = seg; %#ok<SAGROW>
    end
end

fprintf('  Total segments: %d (%d subjects x %d blocks)\n', ...
    length(allSegments), length(subjectIDs), length(segments));

%% ========================================================================
%  PART 6: CREATE AN EXPERIMENT
%  ========================================================================
%
%  The Experiment class is the bridge between single-subject processing
%  and group analysis. It organizes segments, handles filtering/grouping,
%  and manages hierarchical within-subject averaging.

fprintf('\n=== Part 6: Create Experiment ===\n');

ex = exploreFNIRS.core.Experiment(allSegments, ...
    'Hierarchy', {'SubjectID', 'Session', 'Condition', 'Trial'});

% Configure analysis settings
ex.settings.baseline = [-5, 0];     % baseline window (seconds)
ex.settings.taskStart = 0;          % task onset
ex.settings.resampleRate = 1;       % resample to 1 Hz for temporal
ex.settings.barBinSize = 10;        % 10-second bins for bar charts
ex.settings.useBaseline = true;     % apply baseline correction
ex.settings.avgMode = 'hierarchy';  % hierarchical averaging

ex.summary();

%% ========================================================================
%  PATH A: SCRIPTED ANALYSIS (no GUI)
%  ========================================================================

fprintf('\n=== Path A: Scripted Analysis ===\n');

% --- A1: Select and group ---
ex.select('Condition', {'TaskA', 'TaskB'});  % keep both conditions
ex.groupby({'Condition'});
ex.aggregate();

% --- A2: Temporal plot ---
fig = ex.plotTemporal('Biomarkers', {'HbO', 'HbR'}, 'Channels', 1:5, ...
    'Title', 'TaskA vs TaskB: HbO & HbR', ...
    'Visible', 'off', 'SavePath', fullfile(outDir, 'temporal.png'));
close(fig);
fprintf('  Saved temporal plot\n');

% --- A3: Bar chart ---
fig = ex.plotBar('Biomarker', 'HbO', 'Channels', 1:5, ...
    'TimeWindow', [5, 25], 'ShowIndividual', true, ...
    'Title', 'Mean HbO (5-25s)', ...
    'Visible', 'off', 'SavePath', fullfile(outDir, 'bar.png'));
close(fig);
fprintf('  Saved bar chart\n');

% --- A4: LME statistics ---
results = ex.statsFitLME('Biomarkers', {'HbO'}, 'Channels', 1:5);
fprintf('  LME formula: %s\n', results.formula);
fprintf('  ANOVA p-values (Condition effect, channels 1-5):\n');
disp(results.anova_pval);

% --- A5: Summarize for publication ---
T_anova = ex.statsSummarize(results, 'Type', 'anova');
fprintf('  ANOVA summary table (%d rows):\n', height(T_anova));
disp(T_anova);

% --- A6: Group x Condition (reset and regroup) ---
ex.reset();
ex.select('Condition', {'TaskA', 'TaskB'});
ex.groupby({'Group', 'Condition'});
ex.aggregate();

fig = ex.plotBar('Biomarker', 'HbO', 'Channels', 1:5, ...
    'TimeWindow', [5, 25], 'ShowIndividual', true, ...
    'Title', 'Group x Condition: HbO', ...
    'Visible', 'off', 'SavePath', fullfile(outDir, 'bar_group_x_cond.png'));
close(fig);
fprintf('  Saved Group x Condition bar chart\n');

%% ========================================================================
%  PATH B: EXPORT DATA
%  ========================================================================

fprintf('\n=== Path B: Export Data ===\n');

% Make sure we have aggregated data
ex.reset();
ex.select('Condition', {'TaskA', 'TaskB'});
ex.groupby({'Group', 'Condition'});
ex.aggregate();

% --- B1: Export to CSV (long format, for R / Python / SPSS) ---
ex.writeCSV(fullfile(outDir, 'export_long.csv'), ...
    'Format', 'long', ...
    'Biomarkers', {'HbO', 'HbR'}, ...
    'Channels', 1:10);

% --- B2: Export to CSV (wide format) ---
ex.writeCSV(fullfile(outDir, 'export_wide.csv'), ...
    'Format', 'wide', ...
    'Biomarkers', {'HbO'}, ...
    'Channels', 1:10);

% --- B3: Get as MATLAB table (for further scripting) ---
T = ex.toLongTable({'HbO', 'HbR'}, 1:5);
fprintf('  MATLAB table: %d rows x %d columns\n', height(T), width(T));
fprintf('  Columns: %s\n', strjoin(T.Properties.VariableNames, ', '));

% --- B4: Save MATLAB table to .mat ---
save(fullfile(outDir, 'results_table.mat'), 'T');
fprintf('  Saved MATLAB table to results_table.mat\n');

% --- B5: Batch export fNIRS structs to SNIRF files ---
%  Use asSNIRF or asNIR with a cell array and a directory path.
%  Dir1-Dir4 map .info field values to subdirectories (inverse of importDirectory).
%  Prefix builds filenames from .info field values.
snirfOutDir = fullfile(outDir, 'snirf_export');
pf2.export.asSNIRF(allSegments, snirfOutDir, ...
    'Dir1', 'Group', 'Prefix', {'SubjectID', 'Condition'});
fprintf('  Batch exported %d segments to %s\n', length(allSegments), snirfOutDir);

%% ========================================================================
%  PATH C: OPEN THE GUI
%  ========================================================================
%
%  Pass the Experiment directly into the exploreFNIRS GUI.
%  All settings (baseline, resample rate, hierarchy, avg mode) are
%  pre-populated. You can then interactively adjust, re-group, plot,
%  and export from the GUI.
%
%  Uncomment the line below to open:

fprintf('\n=== Path C: GUI ===\n');
fprintf('  To open the GUI with this Experiment:\n');
fprintf('    exploreFNIRS(ex)\n');
fprintf('  Settings will be pre-loaded from the Experiment object.\n');

% exploreFNIRS(ex);   % <-- uncomment to open

%% ========================================================================
%  SUMMARY
%  ========================================================================

fprintf('\n=== Tutorial complete ===\n');
fprintf('Output files in: %s\n', outDir);
d = dir(fullfile(outDir, '*'));
d = d(~[d.isdir]);
for i = 1:length(d)
    fprintf('  %s (%.1f KB)\n', d(i).name, d(i).bytes/1024);
end

fprintf('\nPipeline recap:\n');
fprintf('  1. pf2.import.*()                    → raw fNIRS struct\n');
fprintf('  2. processFNIRS2()                    → hemoglobin concentrations\n');
fprintf('  3. pf2.data.defineBlocks()            → block definitions\n');
fprintf('  4. pf2.data.extractBlocks()           → time-locked segments\n');
fprintf('  5. exploreFNIRS.core.Experiment()     → group analysis container\n');
fprintf('  6. ex.groupby() → ex.aggregate()      → averaged data\n');
fprintf('  7a. ex.plot.* / ex.statsFitLME()      → scripted analysis\n');
fprintf('  7b. ex.writeCSV() / ex.toLongTable()  → tabular export\n');
fprintf('  7c. pf2.export.asSNIRF(cells, dir)    → batch file export\n');
fprintf('  7d. exploreFNIRS(ex)                  → GUI exploration\n');
