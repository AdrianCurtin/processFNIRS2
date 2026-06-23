function bidsRoot = asBIDS(allData, rootDir, varargin)
% ASBIDS Export fNIRS recordings as a BIDS-NIRS dataset
%
% Writes a complete, validator-oriented BIDS dataset for functional NIRS
% (the SNIRF-based "BIDS-NIRS" specification). Each recording is laid out as
%   sub-<label>/[ses-<label>/]nirs/sub-<label>[_ses-<label>]_task-<label>[_run-<index>]_nirs.snirf
% accompanied by its required sidecars (_nirs.json, _channels.tsv,
% _optodes.tsv, _coordsystem.json) and, when markers are present, _events.tsv.
% Dataset-level files (dataset_description.json, participants.tsv, README) are
% generated once for the whole tree.
%
% The SNIRF data file and its probe geometry are produced by
% pf2.export.asSNIRF; the sidecars are derived from the SNIRF structure that
% call returns (so optode positions, the measurement list and wavelengths stay
% consistent with the .snirf) plus the original data struct (markers, fs,
% device, metadata).
%
% Reference:
%   BIDS NIRS specification:
%   https://bids-specification.readthedocs.io/en/stable/modality-specific-files/near-infrared-spectroscopy.html
%
% Syntax:
%   bidsRoot = pf2.export.asBIDS(data, rootDir)
%   bidsRoot = pf2.export.asBIDS(allData, rootDir)
%   bidsRoot = pf2.export.asBIDS(allData, rootDir, 'Task', 'stroop')
%   bidsRoot = pf2.export.asBIDS(allData, rootDir, 'Name', 'My Study', ...
%                  'Authors', {'Doe J','Roe R'}, 'Participants', {'sex','age'})
%
% Inputs:
%   allData  - fNIRS data struct or cell array of structs (one per recording).
%              Each is exported as one BIDS recording. Subject/session/task/run
%              are resolved from each struct's .info (see below).
%   rootDir  - Output BIDS dataset root directory (created if absent).
%
% Name-Value Parameters:
%   'Task'         - Task label for every recording, overriding any per-record
%                    info field. BIDS requires a task entity on NIRS files.
%                    Default: '' (resolve per record from info, else 'task').
%   'Name'         - Dataset name for dataset_description.json
%                    (default: folder name of rootDir).
%   'BIDSVersion'  - BIDS spec version string (default: '1.10.0').
%   'Authors'      - Cell array of author name strings (default: {}).
%   'Participants' - Cell array of .info field names to emit as columns in
%                    participants.tsv (default: auto — sex/age/group when any
%                    record carries them).
%   'License'      - License string for dataset_description.json (default: '').
%   'Overwrite'    - Overwrite an existing dataset root (default: false; a
%                    non-empty existing rootDir errors unless true).
%   'Verbose'      - Print progress (default: true).
%
% Entity resolution (per recording, from .info, case-insensitive):
%   sub  - SubjectID | SubjectId | Subject | subject; else sub-padded index.
%   ses  - Session | session | ses (optional).
%   task - 'Task' parameter; else TaskName | Task | task; else 'task'.
%   run  - Run | run (optional). Recordings that would otherwise collide on
%          sub/ses/task get auto-numbered run-01, run-02, ... in input order.
%   All labels are sanitized to BIDS-legal alphanumerics.
%
% Outputs:
%   bidsRoot - Absolute path to the BIDS dataset root.
%
% Files written:
%   dataset_description.json, README, participants.tsv, participants.json,
%   and per recording: *_nirs.snirf, *_nirs.json, *_channels.tsv,
%   *_optodes.tsv, *_coordsystem.json, [*_events.tsv].
%
% Example:
%   [ex, allData] = pf2.import.sampleData.group();
%   pf2.export.asBIDS(allData, 'bids_out', 'Task', 'rest', ...
%       'Name', 'Sample group', 'Participants', {'sex','age','Group'});
%
% Notes:
%   - Validate the result with the official bids-validator (deno/npx) before
%     sharing; this writer targets the required fields but does not itself
%     validate.
%   - Processed hemoglobin (HbO/HbR/...) is not part of raw BIDS-NIRS; the
%     .snirf carries raw intensity, matching pf2.export.asSNIRF.
%
% See also: pf2.export.asSNIRF, pf2.import.importSNIRF, pf2.probe.montage,
%           pf2.data.infoToTable

% --- Normalize inputs ---
if nargin < 2 || isempty(rootDir)
    error('pf2:asBIDS:noRoot', 'An output dataset root directory is required.');
end
if isstruct(allData)
    allData = {allData};
elseif ~iscell(allData) || isempty(allData)
    error('pf2:asBIDS:invalidInput', ...
        'allData must be an fNIRS struct or non-empty cell array of structs.');
end
rootDir = char(rootDir);

p = inputParser;
p.addParameter('Task', '', @(x) ischar(x) || isstring(x));
p.addParameter('Name', '', @(x) ischar(x) || isstring(x));
p.addParameter('BIDSVersion', '1.10.0', @(x) ischar(x) || isstring(x));
p.addParameter('Authors', {}, @iscell);
p.addParameter('Participants', {}, @iscell);
p.addParameter('License', '', @(x) ischar(x) || isstring(x));
p.addParameter('Overwrite', false, @(x) islogical(x) || isnumeric(x));
p.addParameter('Verbose', true, @(x) islogical(x) || isnumeric(x));
p.parse(varargin{:});
opts = p.Results;
opts.Task = char(opts.Task);
verbose = logical(opts.Verbose);

% --- Prepare root directory ---
if exist(rootDir, 'dir') == 7
    existing = dir(rootDir);
    existing = existing(~ismember({existing.name}, {'.', '..'}));
    if ~isempty(existing) && ~opts.Overwrite
        error('pf2:asBIDS:rootNotEmpty', ...
            ['Output root ''%s'' exists and is not empty. Pass ' ...
             '''Overwrite'', true to write into it.'], rootDir);
    end
else
    mkdir(rootDir);
end
bidsRoot = pf2_base.bids.absPath(rootDir);

% --- Resolve BIDS entities for every recording ---
entities = pf2_base.bids.resolveEntities(allData, opts.Task);

% --- Per-recording export ---
nRec = numel(allData);
participantRows = struct('participant_id', {}, 'fields', {});
for i = 1:nRec
    ent = entities(i);
    data = allData{i};

    relDir = fullfile(['sub-' ent.sub]);
    if ~isempty(ent.ses)
        relDir = fullfile(relDir, ['ses-' ent.ses]);
    end
    relDir = fullfile(relDir, 'nirs');
    outDir = fullfile(bidsRoot, relDir);
    if exist(outDir, 'dir') ~= 7
        mkdir(outDir);
    end

    base = pf2_base.bids.entityBase(ent);
    snirfPath = fullfile(outDir, [base '_nirs.snirf']);

    if verbose
        fprintf('  [%d/%d] %s\n', i, nRec, fullfile(relDir, [base '_nirs.snirf']));
    end

    % asSNIRF writes the .snirf and returns the structure we derive from.
    snirf = pf2.export.asSNIRF(data, snirfPath);
    nirs = snirf.nirs;   % single-recording export always uses /nirs

    % Required and recommended sidecars
    pf2_base.bids.writeNirsJson(fullfile(outDir, [base '_nirs.json']), ...
        data, nirs, ent.task);
    pf2_base.bids.writeChannelsTsv(fullfile(outDir, [base '_channels.tsv']), ...
        data, nirs);
    pf2_base.bids.writeOptodesTsv(fullfile(outDir, [base '_optodes.tsv']), nirs);
    pf2_base.bids.writeCoordsystemJson( ...
        fullfile(outDir, [base '_coordsystem.json']), data, nirs);
    pf2_base.bids.writeEventsTsv(fullfile(outDir, [base '_events.tsv']), data);

    % Collect participant-level metadata (one row per subject, first wins)
    pid = ['sub-' ent.sub];
    if ~any(strcmp({participantRows.participant_id}, pid))
        participantRows(end+1).participant_id = pid; %#ok<AGROW>
        participantRows(end).fields = pf2_base.bids.participantFields(data, opts.Participants);
    end
end

% --- Dataset-level files ---
pf2_base.bids.writeDatasetDescription(bidsRoot, opts);
pf2_base.bids.writeReadme(bidsRoot, opts, nRec, numel(participantRows));
pf2_base.bids.writeParticipants(bidsRoot, participantRows, opts.Participants);

if verbose
    fprintf('BIDS-NIRS dataset written: %s (%d recordings, %d participants)\n', ...
        bidsRoot, nRec, numel(participantRows));
end
end
