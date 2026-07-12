%% example_basic_viewing.m - Viewing raw & processed data, markers, and segments
%
% This script walks through the everyday tasks of inspecting fNIRS data:
%
%   1. Import and inspect the data structure
%   2. View raw light intensity (all channels, single channel, by wavelength)
%   3. Process the data and view hemoglobin timeseries
%   4. View the probe layout on a 3D brain surface
%   5. View topographic maps of channel values
%   6. Inspect event markers
%   7. Split data into time segments
%   8. Define blocks from markers and extract epochs
%   9. Look up anatomical regions for each channel
%  10. Preview a color scheme for group plots
%
% The sample data is a continuous prefrontal recording from an fNIR 2000
% device (18 channels, 10 Hz, ~18 minutes). It has no event markers, so
% we inject synthetic ones to demonstrate marker-based workflows.
%
% Requirements:
%   - processFNIRS2 on the MATLAB path
%   - Sample data: pf2.import.sampleData.fNIR2000()

%% ========================================================================
%  1. IMPORT AND INSPECT
%  ========================================================================
%
% After importing, the data struct contains:
%   .raw      - [T x C] raw light intensity (multiple wavelengths per channel)
%   .time     - [T x 1] time vector in seconds
%   .fs       - sampling frequency (Hz)
%   .fchMask  - [1 x C] channel quality mask (1 = good, 0 = rejected)
%   .markers  - [M x 3+] event markers [time, code, duration, ...]
%   .info     - metadata (filename, subject ID, etc.)

fprintf('=== 1. Import and Inspect ===\n');

data = pf2.import.sampleData.fNIR2000();

fprintf('  Raw data:     %d timepoints x %d columns\n', size(data.raw));
fprintf('  Time range:   %.1f to %.1f seconds (%.1f min)\n', ...
    min(data.time), max(data.time), (max(data.time) - min(data.time)) / 60);
fprintf('  Sample rate:  %.1f Hz\n', data.fs);
fprintf('  Channels:     %d\n', numel(unique(data.fchMask)));
fprintf('  Markers:      %d events\n', size(data.markers, 1));
fprintf('  Device:       %s\n', data.device.name);

% The .info struct holds metadata that travels with the data
fprintf('  Info fields:  %s\n', strjoin(fieldnames(data.info), ', '));


%% ========================================================================
%  2. VIEW RAW DATA
%  ========================================================================
%
% pf2.data.plot.raw() shows the raw light intensity before any processing.
% This is useful for checking signal quality, saturation, and optode contact.
%
% When called with no channel argument, it shows all channels arranged
% according to the probe geometry (spatial layout on the head).

fprintf('\n=== 2. View Raw Data ===\n');

% --- 2a: All channels, arranged by probe geometry ---
% Each subplot shows one channel with both wavelengths overlaid.
% The dashed lines mark the device intensity range (min/max).
figure('Name', 'Raw: All Channels (Arranged)');
pf2.data.plot.raw(data);

% --- 2b: A few channels as stacked subplots ---
% Pass a numeric vector to select specific channels.
figure('Name', 'Raw: Channels 1-4');
pf2.data.plot.raw(data, 1:4);

% --- 2c: Single channel ---
figure('Name', 'Raw: Channel 5');
pf2.data.plot.raw(data, 5);

% --- 2d: Filter by wavelength ---
% Show only one wavelength across all channels. Useful for comparing
% the two wavelengths separately or checking ambient light.
figure('Name', 'Raw: 730nm Only');
pf2.data.plot.raw(data, 'wavelengths', 730);

% --- 2e: Hide markers ---
% If the recording has many markers and the plot is cluttered:
figure('Name', 'Raw: No Markers');
pf2.data.plot.raw(data, 1:4, 'markers', false);

fprintf('  Plotted raw data (5 figures)\n');


%% ========================================================================
%  3. PROCESS AND VIEW HEMOGLOBIN
%  ========================================================================
%
% processFNIRS2 converts raw intensity to hemoglobin concentrations:
%   Stage 1: Raw -> Optical Density (log transform)
%   Stage 2: OD -> Hemoglobin (Modified Beer-Lambert Law)
%   Stage 3: Hemoglobin -> Filtered hemoglobin
%
% Assigning an output variable runs headless (no GUI).

fprintf('\n=== 3. Process and View Hemoglobin ===\n');

processed = processFNIRS2(data, ...
    'DPFmode', 'Calc', ...
    'defaultSubjectAge', 25, ...
    'blLength', 10, ...
    'blStartTime', 0);

fprintf('  HbO size: %d x %d\n', size(processed.HbO));
fprintf('  Units:    %s\n', processed.units);

% --- 3a: All channels arranged by probe layout ---
figure('Name', 'Oxy: All Channels (Arranged)');
pf2.data.plot.oxy(processed);

% --- 3b: Specific channels as subplots ---
figure('Name', 'Oxy: Channels 1-4');
pf2.data.plot.oxy(processed, 1:4);

% --- 3c: Single channel with all biomarkers ---
% 'all' shows HbO, HbR, HbDiff, HbTotal, and CBSI on the same axis.
figure('Name', 'Oxy: Channel 5, All Biomarkers');
pf2.data.plot.oxy(processed, 5, 'biomarkers', 'all');

% --- 3d: With baseline subtraction ---
% Subtract the mean of the first 10 seconds from each channel.
% Useful for seeing relative changes from a resting baseline.
figure('Name', 'Oxy: Baseline-Corrected (10s)');
pf2.data.plot.oxy(processed, 1:4, 'baseline', 10);

% --- 3e: Fixed y-axis limits ---
% Useful when comparing across channels or conditions.
figure('Name', 'Oxy: Fixed Y-Axis');
pf2.data.plot.oxy(processed, 1:4, 'ylim', [-5 5]);

% --- 3f: Save to file (headless) ---
% When savePath is set, the figure is created off-screen and saved.
fig = pf2.data.plot.oxy(processed, 1:4, ...
    'savePath', fullfile(tempdir, 'oxy_channels_1_4.png'), ...
    'saveWidth', 800, 'saveHeight', 400, 'saveDPI', 150);
close(fig);
fprintf('  Saved oxy plot to %s\n', fullfile(tempdir, 'oxy_channels_1_4.png'));


%% ========================================================================
%  4. VIEW PROBE ON 3D BRAIN
%  ========================================================================
%
% If the device configuration has MNI coordinates (most built-in configs
% do), you can visualize where the channels sit on a brain surface.

fprintf('\n=== 4. Probe on 3D Brain ===\n');

% --- 4a: Basic probe layout ---
figure('Name', '3D Probe');
pf2.probe.plot.showProbe3D(processed);

% --- 4b: Different camera angles ---
% Options: 'top', 'front', 'top-left', 'top-right', 'front-left', etc.
figure('Name', '3D Probe: Top View');
pf2.probe.plot.showProbe3D(processed, 'initCamPosition', 'top');

fprintf('  Plotted 3D probe views\n');


%% ========================================================================
%  5. TOPOGRAPHIC MAPS
%  ========================================================================
%
% Interpolated color maps show spatial patterns of activation across the
% probe. Pass a [1 x nChannels] vector of values.

fprintf('\n=== 5. Topographic Maps ===\n');

% --- 5a: 2D heatmap of mean HbO ---
meanHbO = mean(processed.HbO, 1);
figure('Name', 'Topo: Mean HbO');
pf2.probe.plot.imageValues(meanHbO, processed, [], [], 'Mean HbO', '\DeltaHbO');

% --- 5b: 2D heatmap at a specific timepoint ---
% Find the timepoint closest to t = 500 seconds
[~, tIdx] = min(abs(processed.time - 500));
snapshot = processed.HbO(tIdx, :);
figure('Name', 'Topo: HbO at t=500s');
pf2.probe.plot.imageValues(snapshot, processed, [], [], ...
    sprintf('HbO at t=%.0fs', processed.time(tIdx)), '\DeltaHbO');

% --- 5c: 3D brain surface with data overlay ---
figure('Name', '3D Topo: Mean HbO');
pf2.probe.plot.interpolateValues3D(meanHbO, processed, [], [], ...
    'Mean HbO', '\DeltaHbO');

fprintf('  Plotted topographic maps\n');


%% ========================================================================
%  6. INSPECT EVENT MARKERS
%  ========================================================================
%
% Markers record events during the experiment (stimulus onsets, button
% presses, block starts, etc.). The markers field is an [M x 3+] matrix:
%   Column 1: time (seconds)
%   Column 2: code (numeric event identifier)
%   Column 3: duration (seconds, often 0 for instantaneous events)
%
% The sample data may not have many markers, so we'll inject some to
% demonstrate the querying functions.

fprintf('\n=== 6. Inspect Event Markers ===\n');

% Inject synthetic markers for demonstration
processed.markers = pf2_base.normalizeMarkers([
     60, 10, 0;    % Task onset at 60s (code 10)
    120, 20, 0;    % Rest onset at 120s (code 20)
    180, 10, 0;    % Task onset at 180s
    240, 20, 0;    % Rest onset at 240s
    300, 10, 0;    % Task onset at 300s
    360, 20, 0;    % Rest onset at 360s
    420, 10, 0;    % Task onset at 420s
    480, 20, 0;    % Rest onset at 480s
]);
fprintf('  Injected %d synthetic markers\n', size(processed.markers, 1));

% --- 6a: See all markers in the data ---
fprintf('\n  All markers:\n');
fprintf('    Time(s)   Code\n');
for i = 1:size(processed.markers, 1)
    fprintf('    %7.1f   %4d\n', processed.markers.Time(i), processed.markers.Code(i));
end

% --- 6b: Find specific marker times ---
% getMarkers returns the times where a specific code appears.
taskOnsets = pf2.data.getMarkers(processed, 10);
restOnsets = pf2.data.getMarkers(processed, 20);
fprintf('\n  Task onsets (code 10): %s seconds\n', mat2str(taskOnsets(:, 1)'));
fprintf('  Rest onsets (code 20): %s seconds\n', mat2str(restOnsets(:, 1)'));

% --- 6c: Find markers matching multiple codes (OR) ---
% Column vector = OR logic (any of these codes)
allOnsets = pf2.data.getMarkers(processed, [10; 20]);
fprintf('  All onsets (10 or 20): %d events found\n', size(allOnsets, 1));

% --- 6d: View data with only specific markers shown ---
figure('Name', 'Oxy: Only Task Markers');
pf2.data.plot.oxy(processed, 1:4, 'markers', 10);

figure('Name', 'Oxy: All Markers');
pf2.data.plot.oxy(processed, 1:4, 'markers', [10, 20]);


%% ========================================================================
%  7. SPLIT DATA INTO TIME SEGMENTS
%  ========================================================================
%
% pf2.data.split extracts a time window from the continuous recording.
% This is useful for isolating a period of interest without using markers.
%
% Unlike extractBlocks (Section 8), split works with absolute time values
% and doesn't require marker-defined blocks.

fprintf('\n=== 7. Split Data by Time ===\n');

% --- 7a: Extract a specific time window ---
segment1 = pf2.data.split(processed, 100, 200);
fprintf('  Segment 100-200s: %d timepoints, %.1f to %.1fs\n', ...
    length(segment1.time), min(segment1.time), max(segment1.time));

% --- 7b: Extract from a start time to the end ---
tail = pf2.data.split(processed, 500);
fprintf('  From 500s to end: %d timepoints, %.1f to %.1fs\n', ...
    length(tail.time), min(tail.time), max(tail.time));

% --- 7c: Extract with a fixed segment length ---
segment2 = pf2.data.split(processed, 300, 'segmentLength', 60);
fprintf('  60s from t=300:   %d timepoints, %.1f to %.1fs\n', ...
    length(segment2.time), min(segment2.time), max(segment2.time));

% --- 7d: View a split segment ---
figure('Name', 'Split: 100-200s');
pf2.data.plot.oxy(segment1, 1:4);
title('Segment: 100-200 seconds');


%% ========================================================================
%  8. DEFINE BLOCKS AND EXTRACT EPOCHS
%  ========================================================================
%
% For event-related designs, you want to cut the recording into epochs
% aligned to event markers. This is a two-step process:
%
%   1. defineBlocks  - parse markers into block definitions
%   2. extractBlocks - cut the continuous data into segments
%
% Each extracted segment is a standalone fNIRS struct that can be plotted,
% processed further, or fed into group analysis.

fprintf('\n=== 8. Marker-Based Block Extraction ===\n');

% --- 8a: Define blocks from task markers (code 10), 60 seconds each ---
blocks = pf2.data.defineBlocks(processed, ...
    'MarkerCode', 10, ...
    'Duration', 60, ...
    'ConditionMap', {10, 'Task'}, ...
    'Embed', false);

fprintf('  Defined %d blocks:\n', length(blocks));
for i = 1:length(blocks)
    fprintf('    Block %d: %s, %.0f-%.0fs (%.0fs)\n', ...
        i, blocks(i).info.Condition, ...
        blocks(i).startTime, blocks(i).endTime, blocks(i).duration);
end

% --- 8b: Define blocks with paired start/end markers ---
% Code 10 = block start, code 20 = block end
pairedBlocks = pf2.data.defineBlocks(processed, ...
    'StartMarker', 10, ...
    'EndMarker', 20, ...
    'Embed', false);

fprintf('\n  Paired blocks (10->20): %d blocks\n', length(pairedBlocks));
for i = 1:length(pairedBlocks)
    fprintf('    Block %d: %.0f-%.0fs (%.0fs)\n', ...
        i, pairedBlocks(i).startTime, pairedBlocks(i).endTime, ...
        pairedBlocks(i).duration);
end

% --- 8c: Extract block segments ---
% PreTime adds a baseline period before each block onset.
% SetT0 shifts time so each block starts at t=0.
segments = pf2.data.extractBlocks(processed, blocks, ...
    'PreTime', 5, ...       % 5 seconds before block onset (baseline)
    'PostTime', 15, ...     % 15 seconds after block end (HRF tail)
    'SetT0', true);         % block onset = t=0

fprintf('\n  Extracted %d segments\n', length(segments));
seg1 = segments{1};
fprintf('  Segment 1: %.1f to %.1f seconds, %d channels\n', ...
    min(seg1.time), max(seg1.time), size(seg1.HbO, 2));

% --- 8d: View extracted segments ---
figure('Name', 'Block 1: Channels 1-4');
pf2.data.plot.oxy(segments{1}, 1:4);
title('Block 1 (aligned to onset)');

figure('Name', 'Block 2: Channels 1-4');
pf2.data.plot.oxy(segments{2}, 1:4);
title('Block 2 (aligned to onset)');

% --- 8e: Extract with baseline correction ---
% BaselineWindow subtracts the mean of the specified time window from
% each channel. [-5, 0] means the 5 seconds before block onset.
% PreTime/PostTime control how much surrounding data to include.
correctedSegments = pf2.data.extractBlocks(processed, blocks, ...
    'PreTime', 5, ...
    'PostTime', 15, ...
    'BaselineWindow', [-5, 0], ...
    'SetT0', true);

figure('Name', 'Block 1: Baseline-Corrected');
pf2.data.plot.oxy(correctedSegments{1}, 1:4);
title('Block 1 (baseline-corrected)');


%% ========================================================================
%  9. ANATOMICAL LOOKUP
%  ========================================================================
%
% If the device has MNI coordinates, you can look up which Brodmann areas
% each channel is near. This maps channels to cortical regions.

fprintf('\n=== 9. Anatomical Lookup ===\n');

tbl = pf2.probe.nearestBrodmann(processed, 'N', 1);
fprintf('  Nearest Brodmann area per channel:\n');
disp(tbl);


%% ========================================================================
%  10. PREVIEW A COLOR SCHEME
%  ========================================================================
%
% When using exploreFNIRS for group analysis, you can define color schemes
% that map factor values to colors. The preview() method lets you visualize
% the resolved colors without needing real experiment data.

fprintf('\n=== 10. Preview a Color Scheme ===\n');

cs = exploreFNIRS.core.ColorScheme();
cs = cs.set('Group', 'Patient', [0.85, 0.2, 0.2]);   % Red base
cs = cs.set('Group', 'Healthy', [0.2, 0.65, 0.3]);    % Green base
cs = cs.set('Condition', 'Easy', 'lighten', 0.25);     % Lighter variant
cs = cs.set('Condition', 'Hard', 'darken', 0.15);      % Darker variant

% Preview shows a horizontal bar chart with resolved colors and hex codes
fig = cs.preview();
fprintf('  ColorScheme with %d rules, %d combinations\n', ...
    length(cs.rules), 4);

% Save headless
fig2 = cs.preview('SavePath', fullfile(tempdir, 'colorscheme_preview.png'));
close(fig2);
fprintf('  Saved preview to %s\n', fullfile(tempdir, 'colorscheme_preview.png'));


%% ========================================================================
%  SUMMARY
%  ========================================================================

fprintf('\n=== Quick Reference ===\n');
fprintf('  pf2.data.plot.raw(data)              View raw light intensity\n');
fprintf('  pf2.data.plot.raw(data, 1:5)         Select channels\n');
fprintf('  pf2.data.plot.oxy(data)              View hemoglobin timeseries\n');
fprintf('  pf2.data.plot.oxy(data, ''baseline'', 10)  With baseline correction\n');
fprintf('  pf2.data.plot.oxy(data, ''biomarkers'', ''all'')  All biomarkers\n');
fprintf('  pf2.data.plot.oxy(data, ''markers'', 10)   Show only marker code 10\n');
fprintf('  pf2.probe.plot.showProbe3D(data)     3D probe on brain\n');
fprintf('  pf2.probe.plot.imageValues(vals, data)  2D topographic map\n');
fprintf('  pf2.data.getMarkers(data, code)      Find marker times\n');
fprintf('  pf2.data.split(data, t1, t2)         Extract time window\n');
fprintf('  pf2.data.defineBlocks(data, ...)      Define blocks from markers\n');
fprintf('  pf2.data.extractBlocks(data, blocks)  Cut epochs from recording\n');
fprintf('  pf2.probe.nearestBrodmann(data)       Anatomical channel labels\n');
