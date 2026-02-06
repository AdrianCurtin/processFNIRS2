% SETUP Validate FRESH benchmark data is downloaded and accessible
%
% Checks that FRESH fNIRS datasets (Yuecel et al. 2025) are downloaded to
% benchmarks/data/ in BIDS format. Prints summary of available subjects
% and verifies SNIRF files are loadable.
%
% Manual download required from: https://osf.io/b4wck/
%
% Expected directory structure:
%   benchmarks/data/
%   ├── dataset_I_auditory/     (BIDS: sub-XX/nirs/*.snirf)
%   └── dataset_II_motor/       (BIDS: sub-XX/nirs/*.snirf)
%
% Reference:
%   Yuecel, M. A. et al. (2025). fNIRS Reproducibility and Estimation of
%   Statistical power from a Harmonized study (FRESH). Communications
%   Biology. DOI: 10.1038/s42003-025-08412-1
%
% See also: benchmarks.fresh.definePipelines, benchmarks.fresh.runDatasetII

fprintf('\n=== FRESH Benchmark Data Setup ===\n\n');

% Determine paths
scriptDir = fileparts(mfilename('fullpath'));
benchmarkRoot = fileparts(scriptDir);
dataDir = fullfile(benchmarkRoot, 'data');

% Check if data directory exists
if ~isfolder(dataDir)
    fprintf('ERROR: Data directory not found: %s\n\n', dataDir);
    fprintf('Please download the FRESH datasets from:\n');
    fprintf('  https://osf.io/b4wck/\n\n');
    fprintf('Extract into:\n');
    fprintf('  %s/dataset_I_auditory/\n', dataDir);
    fprintf('  %s/dataset_II_motor/\n\n', dataDir);
    fprintf('The data should be in BIDS format with SNIRF files:\n');
    fprintf('  dataset_*/sub-XX/nirs/*.snirf\n\n');
    return;
end

% --- Dataset I: Auditory ---
fprintf('--- Dataset I: Auditory (Speech/Noise/Silence) ---\n');
auditoryDir = fullfile(dataDir, 'dataset_I_auditory');
checkDataset(auditoryDir, 'Auditory');

% --- Dataset II: Motor ---
fprintf('\n--- Dataset II: Motor (Finger Tapping) ---\n');
motorDir = fullfile(dataDir, 'dataset_II_motor');
checkDataset(motorDir, 'Motor');

fprintf('\n=== Setup Complete ===\n');

%%_Subfunctions_________________________________________________________

function checkDataset(datasetDir, name)
% CHECKDATASET Validate a single FRESH dataset directory
%
% Inputs:
%   datasetDir - Path to dataset directory
%   name       - Display name for the dataset

if ~isfolder(datasetDir)
    fprintf('  NOT FOUND: %s\n', datasetDir);
    fprintf('  Download from https://osf.io/b4wck/ and extract here.\n');
    return;
end

% Find subject directories
subDirs = dir(fullfile(datasetDir, 'sub-*'));
subDirs = subDirs([subDirs.isdir]);

if isempty(subDirs)
    fprintf('  EMPTY: No subject directories found in %s\n', datasetDir);
    return;
end

fprintf('  Found %d subjects: ', length(subDirs));
subNames = {subDirs.name};
fprintf('%s ', subNames{1:min(5, end)});
if length(subNames) > 5
    fprintf('... +%d more', length(subNames) - 5);
end
fprintf('\n');

% Check for SNIRF files (handles sub/nirs/ and sub/ses/nirs/ layouts)
nFilesTotal = 0;
nLoadable = 0;
testLimit = 2;  % Only test-load first N files to save time

% Find all sessions
allSessions = {};
for s = 1:length(subDirs)
    subPath = fullfile(datasetDir, subDirs(s).name);

    % Check for session directories (BIDS: sub-XX/ses-XX/nirs/)
    sesDirs = dir(fullfile(subPath, 'ses-*'));
    sesDirs = sesDirs([sesDirs.isdir]);

    if ~isempty(sesDirs)
        for si = 1:length(sesDirs)
            nirsDir = fullfile(subPath, sesDirs(si).name, 'nirs');
            if isfolder(nirsDir)
                allSessions{end+1} = struct('sub', subDirs(s).name, ...
                    'ses', sesDirs(si).name, 'nirsDir', nirsDir); %#ok<AGROW>
            end
        end
    else
        % No sessions: sub-XX/nirs/ layout
        nirsDir = fullfile(subPath, 'nirs');
        if isfolder(nirsDir)
            allSessions{end+1} = struct('sub', subDirs(s).name, ...
                'ses', '', 'nirsDir', nirsDir); %#ok<AGROW>
        end
    end
end

fprintf('  Sessions/runs found: %d\n', length(allSessions));

for si = 1:length(allSessions)
    nirsDir = allSessions{si}.nirsDir;
    snirfFiles = dir(fullfile(nirsDir, '*.snirf'));
    nFilesTotal = nFilesTotal + length(snirfFiles);

    % Test-load a few files
    for f = 1:min(length(snirfFiles), max(0, testLimit - nLoadable))
        sesLabel = allSessions{si}.ses;
        filepath = fullfile(nirsDir, snirfFiles(f).name);
        try
            testData = pf2.import.importSNIRF(filepath, false);
            if isfield(testData, 'raw') && ~isempty(testData.raw)
                nLoadable = nLoadable + 1;
                if nLoadable <= 1
                    fprintf('  Sample: %s/%s/%s\n', allSessions{si}.sub, sesLabel, snirfFiles(f).name);
                    fprintf('    Channels: %d, Samples: %d, Rate: %.1f Hz\n', ...
                        size(testData.raw, 2), size(testData.raw, 1), testData.fs);
                    if ~isempty(testData.markers)
                        fprintf('    Markers: %d events\n', size(testData.markers, 1));
                        uniqueCodes = unique(testData.markers(:, 2));
                        fprintf('    Unique codes: %s\n', mat2str(uniqueCodes'));
                    end
                    % Check for short channels
                    if isfield(testData, 'probeinfo') && isfield(testData.probeinfo, 'Probe')
                        probe = testData.probeinfo.Probe{1};
                        if isfield(probe, 'IsShortSeparation')
                            nSS = sum(probe.IsShortSeparation);
                            fprintf('    Short-separation channels: %d\n', nSS);
                        end
                    end
                end
            end
        catch e
            fprintf('  WARNING: Failed to load %s: %s\n', snirfFiles(f).name, e.message);
        end
    end
end

fprintf('  Total SNIRF files: %d\n', nFilesTotal);
if nLoadable > 0
    fprintf('  Loadable: %d/%d tested OK\n', nLoadable, min(nFilesTotal, testLimit));
end

% Check for events.tsv (BIDS sidecar)
eventFiles = dir(fullfile(datasetDir, '**', '*events.tsv'));
if ~isempty(eventFiles)
    fprintf('  BIDS events.tsv files: %d (may contain stimulus timing)\n', length(eventFiles));
end

end
