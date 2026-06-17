%% example_snirf_export.m - Exporting fNIRS data to SNIRF format
%
% This script demonstrates how to prepare and export fNIRS data to the
% SNIRF format (Shared Near Infrared Spectroscopy Format), a standardized
% HDF5-based file format for interoperability with other fNIRS tools like
% Homer3, MNE-Python, and FieldTrip.
%
% What this script covers:
%
%   1. Import sample data and inspect its structure
%   2. Add subject metadata (.info fields)
%   3. Inject event markers for a block design
%   4. Trim the recording to a region of interest
%   5. Export to SNIRF
%   6. Re-import the SNIRF file to verify the roundtrip
%   7. Compare what was preserved and what was lost
%
% The SNIRF specification lives at https://github.com/fNIRS/snirf
%
% Requirements:
%   - processFNIRS2 on the MATLAB path
%   - Sample data: pf2.import.sampleData.fNIR2000()

%% ========================================================================
%  1. IMPORT AND INSPECT
%  ========================================================================

fprintf('=== 1. Import and Inspect ===\n');

data = pf2.import.sampleData.fNIR2000();

fprintf('  Raw data:     %d timepoints x %d columns\n', size(data.raw));
fprintf('  Time range:   %.1f to %.1f seconds (%.1f min)\n', ...
    min(data.time), max(data.time), (max(data.time) - min(data.time)) / 60);
fprintf('  Sample rate:  %.1f Hz\n', data.fs);
fprintf('  Device:       %s\n', data.device.name);
fprintf('  Has markers:  %s (%d events)\n', ...
    mat2str(~isempty(data.markers)), size(data.markers, 1));

% The .info struct holds metadata that travels with the data.
% After import it typically has device-related fields but minimal
% subject-level information.
fprintf('\n  Current info fields:\n');
infoFields = fieldnames(data.info);
for i = 1:length(infoFields)
    val = data.info.(infoFields{i});
    if ischar(val) || isstring(val)
        fprintf('    .info.%-20s = ''%s''\n', infoFields{i}, val);
    elseif isnumeric(val) && isscalar(val)
        fprintf('    .info.%-20s = %g\n', infoFields{i}, val);
    else
        fprintf('    .info.%-20s = [%s]\n', infoFields{i}, class(val));
    end
end


%% ========================================================================
%  2. ADD SUBJECT METADATA
%  ========================================================================
%
% The SNIRF format has a metaDataTags section for subject and session info.
% The exporter maps .info fields to SNIRF metadata automatically. Any field
% you add to .info will be written to the file.
%
% Some fields have special SNIRF mappings:
%   .info.SubjectID     -> /metaDataTags/SubjectID
%   .info.SubjectName   -> /metaDataTags/SubjectName
%   .info.manufacturer  -> /metaDataTags/ManufacturerName
%   .info.DateOfBirth   -> /metaDataTags/DateOfBirth
%   .info.StudyID       -> /metaDataTags/StudyID
%   .info.sex           -> /metaDataTags/sex
%
% Any unrecognized field names are stored verbatim.

fprintf('\n=== 2. Add Subject Metadata ===\n');

data.info.SubjectID   = 'SUB-001';
data.info.SubjectName = 'Doe, Jane';
data.info.sex         = 'F';
data.info.Age         = 28;
data.info.Group       = 'Control';
data.info.StudyID     = 'PFC-PILOT-2026';
data.info.Session     = 'baseline';
data.info.Notes       = 'Good signal quality, cooperative participant';

fprintf('  Added subject metadata:\n');
fprintf('    SubjectID:   %s\n', data.info.SubjectID);
fprintf('    SubjectName: %s\n', data.info.SubjectName);
fprintf('    Age:         %d\n', data.info.Age);
fprintf('    Group:       %s\n', data.info.Group);
fprintf('    StudyID:     %s\n', data.info.StudyID);
fprintf('    Session:     %s\n', data.info.Session);


%% ========================================================================
%  3. ADD EVENT MARKERS
%  ========================================================================
%
% The sample data has no event markers, so we inject a typical block design:
%   Code 10 = Task onset (e.g. cognitive task)
%   Code 20 = Rest onset
%
% Markers are stored as [time, code, duration, amplitude]:
%   Column 1: time in seconds
%   Column 2: marker code (numeric)
%   Column 3: duration (0 for instantaneous events)
%   Column 4: amplitude (optional, defaults to 1)
%
% In SNIRF, markers are stored in /stim groups, one per unique code.
% Each group is named 'mrk<code>' (e.g., 'mrk10', 'mrk20') and contains
% a data matrix of [time, duration, value] per event.

fprintf('\n=== 3. Add Event Markers ===\n');

data.markers = pf2_base.normalizeMarkers([
     60, 10, 0;    % Task onset at 60s
    120, 20, 0;    % Rest onset at 120s
    180, 10, 0;    % Task onset at 180s
    240, 20, 0;    % Rest onset at 240s
    300, 10, 0;    % Task onset at 300s
    360, 20, 0;    % Rest onset at 360s
    420, 10, 0;    % Task onset at 420s
    480, 20, 0;    % Rest onset at 480s
    540, 10, 0;    % Task onset at 540s
    600, 20, 0;    % Rest onset at 600s
]);

fprintf('  Injected %d markers (5 task + 5 rest blocks)\n', size(data.markers, 1));
fprintf('  Marker codes: %s\n', mat2str(unique(data.markers.Code)'));


%% ========================================================================
%  4. TRIM THE RECORDING
%  ========================================================================
%
% The full recording is ~18 minutes. We trim to a 10-minute window that
% captures all our markers (30s before first marker through 60s after last).
%
% pf2.data.split extracts a time window. It preserves all fields including
% .raw, .time, .markers, .info, .fchMask, .device, and .Aux (if present).
% Markers outside the trimmed window are automatically removed.

fprintf('\n=== 4. Trim the Recording ===\n');

fprintf('  Before trim: %.1f to %.1f seconds (%d samples)\n', ...
    min(data.time), max(data.time), length(data.time));

trimmed = pf2.data.split(data, 30, 660);

fprintf('  After trim:  %.1f to %.1f seconds (%d samples)\n', ...
    min(trimmed.time), max(trimmed.time), length(trimmed.time));
fprintf('  Markers remaining: %d\n', size(trimmed.markers, 1));


%% ========================================================================
%  5. EXPORT TO SNIRF
%  ========================================================================
%
% pf2.export.asSNIRF writes the data to a SNIRF-compliant HDF5 file.
%
% What gets exported:
%   /nirs/data/dataTimeSeries  <- trimmed.raw (raw light intensity only)
%   /nirs/data/time            <- trimmed.time
%   /nirs/data/measurementList <- channel-wavelength-source-detector mapping
%   /nirs/probe/               <- full probe geometry (2D, 3D, wavelengths)
%   /nirs/stim/                <- markers, grouped by unique code
%   /nirs/metaDataTags/        <- subject and session metadata from .info

fprintf('\n=== 5. Export to SNIRF ===\n');

outDir = fullfile(tempdir, 'pf2_snirf_example');
if ~exist(outDir, 'dir')
    mkdir(outDir);
end

outPath = fullfile(outDir, 'example_export.snirf');
snirfStruct = pf2.export.asSNIRF(trimmed, outPath);

fprintf('  Saved to: %s\n', outPath);

% Inspect the SNIRF structure that was generated
fprintf('\n  SNIRF structure overview:\n');
fprintf('    formatVersion: %s\n', snirfStruct.formatVersion);
fprintf('    Data:   %d timepoints x %d measurement channels\n', ...
    size(snirfStruct.nirs.data.dataTimeSeries));
fprintf('    Probe:  %d wavelengths, %d sources, %d detectors\n', ...
    length(snirfStruct.nirs.probe.wavelengths), ...
    size(snirfStruct.nirs.probe.sourcePos3D, 1), ...
    size(snirfStruct.nirs.probe.detectorPos3D, 1));
fprintf('    Stim:   %d event groups\n', length(snirfStruct.nirs.stim));
for s = 1:length(snirfStruct.nirs.stim)
    fprintf('      %s: %d events\n', ...
        snirfStruct.nirs.stim(s).name, size(snirfStruct.nirs.stim(s).data, 1));
end

% Show metadata that was written
fprintf('\n  MetaData tags written:\n');
metaFields = fieldnames(snirfStruct.nirs.metaDataTags);
for i = 1:length(metaFields)
    val = snirfStruct.nirs.metaDataTags.(metaFields{i});
    if ischar(val) || isstring(val)
        fprintf('    %-25s = %s\n', metaFields{i}, val);
    end
end


%% ========================================================================
%  6. RE-IMPORT AND VERIFY ROUNDTRIP
%  ========================================================================
%
% Import the SNIRF file we just wrote and compare it against the original
% trimmed data.

fprintf('\n=== 6. Re-import and Verify Roundtrip ===\n');

reimported = pf2.import.importSNIRF(outPath);

fprintf('  Re-imported successfully.\n');
fprintf('  Raw data:  %d x %d (original: %d x %d)\n', ...
    size(reimported.raw), size(trimmed.raw));
fprintf('  Time:      %.1f to %.1fs (original: %.1f to %.1fs)\n', ...
    min(reimported.time), max(reimported.time), ...
    min(trimmed.time), max(trimmed.time));
fprintf('  Fs:        %.1f Hz (original: %.1f Hz)\n', ...
    reimported.fs, trimmed.fs);
fprintf('  Markers:   %d events (original: %d)\n', ...
    size(reimported.markers, 1), size(trimmed.markers, 1));


%% ========================================================================
%  7. WHAT IS PRESERVED AND WHAT IS LOST
%  ========================================================================
%
% SNIRF is a raw-data interchange format. It was designed for sharing data
% across tools before processing, not for storing processed results.
%
% PRESERVED in SNIRF roundtrip:
%   - Raw light intensity data (.raw)
%   - Time vector (.time)
%   - Sampling rate (.fs)
%   - Probe geometry (source/detector positions, wavelengths, SD pairs)
%   - Event markers (.markers) — reorganized by unique code
%   - Subject metadata (.info fields → metaDataTags)
%   - Auxiliary data (.Aux) if present
%   - Device manufacturer and model info
%
% NOT PRESERVED (dropped during export):
%   - Processed hemoglobin data (.HbO, .HbR, .HbTotal, .HbDiff, .CBSI)
%   - Channel quality mask (.fchMask) — not part of SNIRF spec
%   - Processing settings (.processingInfo)
%   - pf2.Device object (.device) — re-created on import if probe matches
%   - Internal pf2 fields (.OD, .segmentTimes, etc.)
%
% This means: after exporting to SNIRF and re-importing, you must
% reprocess the data with processFNIRS2 to get hemoglobin values again.

fprintf('\n=== 7. What Is Preserved vs Lost ===\n');

% --- Verify raw data fidelity ---
% The raw columns in SNIRF only include measurement channels (no time or
% marker columns that some devices embed in the raw matrix). The column
% count may differ, but the measurement data should match.
nColsOrig = size(trimmed.raw, 2);
nColsReimp = size(reimported.raw, 2);
fprintf('\n  [RAW DATA]\n');
fprintf('    Original columns:    %d\n', nColsOrig);
fprintf('    Re-imported columns: %d\n', nColsReimp);
if nColsOrig ~= nColsReimp
    fprintf('    Column count differs — SNIRF strips non-measurement columns\n');
    fprintf('    (time/marker columns embedded in raw by some devices are removed)\n');
else
    maxDiff = max(abs(trimmed.raw(:) - reimported.raw(:)));
    fprintf('    Max absolute difference: %e (should be ~0)\n', maxDiff);
end

% --- Verify markers ---
fprintf('\n  [MARKERS]\n');
if size(reimported.markers, 1) == size(trimmed.markers, 1)
    timeDiffs = abs(reimported.markers.Time - trimmed.markers.Time);
    fprintf('    Count matches: %d events\n', size(reimported.markers, 1));
    fprintf('    Max time difference: %.6f seconds\n', max(timeDiffs));
else
    fprintf('    Original: %d, Re-imported: %d\n', ...
        size(trimmed.markers, 1), size(reimported.markers, 1));
    fprintf('    Note: marker count may differ due to SNIRF grouping\n');
end

% --- Verify metadata ---
fprintf('\n  [METADATA]\n');
metaCheck = {'SubjectID', 'StudyID', 'Group', 'Notes'};
for i = 1:length(metaCheck)
    field = metaCheck{i};
    if isfield(reimported.info, field)
        fprintf('    .info.%-15s = ''%s'' (preserved)\n', field, reimported.info.(field));
    else
        fprintf('    .info.%-15s   (not found — may be under different name)\n', field);
    end
end

% --- Check what's missing ---
fprintf('\n  [NOT IN SNIRF]\n');
missingFields = {'HbO', 'HbR', 'HbTotal', 'HbDiff', 'CBSI', ...
    'processingInfo', 'fchMask'};
for i = 1:length(missingFields)
    field = missingFields{i};
    inOrig = isfield(trimmed, field);
    inReimp = isfield(reimported, field);
    if inOrig && ~inReimp
        fprintf('    .%-18s present in original, absent after roundtrip\n', field);
    elseif ~inOrig && ~inReimp
        fprintf('    .%-18s not present (data was not processed)\n', field);
    elseif inOrig && inReimp
        fprintf('    .%-18s present in both (unexpected)\n', field);
    end
end


%% ========================================================================
%  8. REPROCESS AFTER ROUNDTRIP
%  ========================================================================
%
% Since SNIRF only stores raw data, reprocess to get hemoglobin values.

fprintf('\n=== 8. Reprocess After Roundtrip ===\n');

reprocessed = processFNIRS2(reimported, ...
    'DPFmode', 'Calc', ...
    'defaultSubjectAge', 28, ...
    'blLength', 10);

fprintf('  Reprocessed successfully.\n');
fprintf('  HbO size:   %d x %d\n', size(reprocessed.HbO));
fprintf('  Units:      %s\n', reprocessed.units);
fprintf('  Has device: %s\n', mat2str(isfield(reprocessed, 'device')));


%% ========================================================================
%  SUMMARY
%  ========================================================================

fprintf('\n=== Quick Reference: SNIRF Export ===\n');
fprintf('  pf2.export.asSNIRF(data, path)          Export single file\n');
fprintf('  pf2.export.asSNIRF({d1,d2}, path)       Multiple runs in one file\n');
fprintf('  pf2.export.asSNIRF(cells, dir)           Batch export to directory\n');
fprintf('  pf2.export.asSNIRF(cells, dir, ...       Batch with Dir/Prefix opts\n');
fprintf('    ''Dir1'',''Group'', ''Prefix'',{''SubjectID''})\n');
fprintf('  pf2.import.importSNIRF(path)             Re-import SNIRF file\n');
fprintf('\n');
fprintf('  Preserved: raw, time, fs, probe, markers, metadata, aux\n');
fprintf('  Lost:      HbO/HbR, fchMask, processingInfo, pf2.Device\n');
fprintf('  After roundtrip: reprocess with processFNIRS2() to get Hb data\n');
