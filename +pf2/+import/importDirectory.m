function allData = importDirectory(dirPath, pattern, opts)
% IMPORTDIRECTORY Batch-import fNIRS files from a directory tree
%
% Recursively scans a directory for fNIRS files matching a glob pattern,
% auto-detects the file format from the extension, and imports each file
% using the appropriate importer. Optionally maps directory hierarchy
% levels into .info fields for downstream grouping in exploreFNIRS.
%
% Doubles as a BIDS-NIRS importer: when the directory is a BIDS dataset (it
% has a dataset_description.json / participants.tsv, or every matched file is
% BIDS-named), the sub/ses/task/run entities in each filename are mapped to
% standard .info fields (SubjectID/Session/Task/Run + participant_id), and
% participants.tsv demographics are merged into each subject's .info. Per-file
% BIDS sidecars (events.tsv, coordsystem.json) are already read by importSNIRF.
%
% Syntax:
%   allData = pf2.import.importDirectory()                  % pick dir, *.snirf
%   allData = pf2.import.importDirectory(dirPath)           % pattern -> *.snirf
%   allData = pf2.import.importDirectory(dirPath, pattern)
%   allData = pf2.import.importDirectory(dirPath, pattern, Name, Value)
%
% Inputs:
%   dirPath  - Root directory to scan [char | string]
%              Must be an existing directory. If omitted or empty, a directory
%              picker opens.
%   pattern  - Glob pattern for file matching [char | string]
%              Examples: '*.snirf', 'valid*.nir', '*.hdr'
%              Extension determines the importer used.
%              Defaults to '*.snirf' (the BIDS-NIRS file format) when omitted.
%
% Name-Value Parameters:
%   'Dir1'            - Info field name for 1st folder level below dirPath
%                       (default: 'dir1' if subdirectories exist)
%   'Dir2'            - Info field name for 2nd folder level (default: 'dir2')
%   'Dir3'            - Info field name for 3rd folder level (default: 'dir3')
%   'Dir4'            - Info field name for 4th folder level (default: 'dir4')
%   'Filename'        - Info field name populated from each file's name
%                       (without extension), e.g. 'Filename', 'SubjectID'.
%                       Use for flat directories where the importer-embedded
%                       SubjectID is identical across files. Opt-in: when
%                       omitted, no field is overwritten.
%   'ChannelCheck'    - Show interactive channel quality GUI (default: false)
%   'ContinueOnError' - Skip failed files instead of stopping (default: true)
%   'Verbose'         - Print progress and summary messages (default: true)
%
% Outputs:
%   allData - Cell array of imported fNIRS data structs {1 x N}
%             Each struct has .info fields populated from directory levels,
%             plus .info.sourcePath (the imported file path). Failed imports
%             are omitted when ContinueOnError is true.
%
% Notes:
%   If more than one imported file carries the same .info.SubjectID, a
%   warning is issued: duplicate SubjectIDs break per-subject grouping and
%   pf2.data.importInfo (which keys on SubjectID). Supply 'Filename',
%   'SubjectID' or a 'DirN', 'SubjectID' mapping to assign unique IDs.
%
% Algorithm:
%   1. Validate dirPath and resolve to absolute path
%   2. Extract extension from pattern to select importer
%   3. Recursively search for matching files
%   4. Import each file, mapping directory levels to .info fields
%   5. Return cell array of imported data
%
% Example:
%   % Import all SNIRF files from a flat directory
%   allData = pf2.import.importDirectory('data/', '*.snirf');
%
%   % Import with directory-to-info mapping
%   allData = pf2.import.importDirectory('data/', '*.snirf', ...
%       'Dir1', 'Group', 'Dir2', 'SubjectID');
%
%   % NIRx folder-based format
%   allData = pf2.import.importDirectory('data/', '*.hdr', ...
%       'Dir1', 'Group', 'Dir2', 'SubjectID');
%
%   % Flat folder: use each file's name as the SubjectID
%   allData = pf2.import.importDirectory('data/', '*.snirf', ...
%       'Filename', 'SubjectID');
%
%   % Feed directly into experiment
%   ex = exploreFNIRS.core.Experiment(allData);
%
% See also: pf2.import.importNIR, pf2.import.importSNIRF,
%           pf2.import.importHitachiMES, pf2.import.importNIRX

    % --- Parse inputs ---
    arguments
        dirPath {mustBeText} = ''
        pattern {mustBeText} = '*.snirf'
        opts.Dir1 {mustBeText} = ''
        opts.Dir2 {mustBeText} = ''
        opts.Dir3 {mustBeText} = ''
        opts.Dir4 {mustBeText} = ''
        opts.Filename {mustBeText} = ''
        opts.ChannelCheck (1,1) logical = false
        opts.ContinueOnError (1,1) logical = true
        opts.Verbose (1,1) logical = true
    end

    dirPath = char(dirPath);
    pattern = char(pattern);

    % --- Prompt for a directory when none was given ---
    if isempty(dirPath)
        dirPath = uigetdir('', 'Select directory to import fNIRS data from');
        if isequal(dirPath, 0)   % selection cancelled
            allData = {};
            return;
        end
    end

    % Default the glob to SNIRF (the BIDS-NIRS file format) when unspecified.
    if isempty(pattern)
        pattern = '*.snirf';
    end

    % --- Validate directory ---
    if ~isfolder(dirPath)
        error('pf2:importDirectory:notADirectory', ...
            'Directory not found: %s', dirPath);
    end

    % Resolve to a canonical absolute path. Only prepend pwd when the path
    % is relative -- java.io.File(pwd, dirPath) treats its second argument as
    % a child even when it is already absolute, which would turn '/data/x'
    % into '<pwd>/data/x' on macOS/Linux.
    jf = java.io.File(dirPath);
    if ~jf.isAbsolute()
        jf = java.io.File(pwd, dirPath);
    end
    dirPath = char(jf.getCanonicalPath());

    % --- Determine importer from pattern extension ---
    [~, ~, ext] = fileparts(pattern);
    ext = lower(ext);
    if isempty(ext)
        error('pf2:importDirectory:noExtension', ...
            'Pattern must include a file extension (e.g. ''*.snirf'').');
    end

    importFn = getImporterForExtension(ext, opts.ChannelCheck);
    formatName = getFormatName(ext);

    % --- Build Dir field names ---
    dirFieldNames = {opts.Dir1, opts.Dir2, opts.Dir3, opts.Dir4};
    for k = 1:4
        if isempty(dirFieldNames{k})
            dirFieldNames{k} = sprintf('dir%d', k);
        else
            dirFieldNames{k} = char(dirFieldNames{k});
        end
    end
    filenameField = char(opts.Filename);

    % --- Find matching files ---
    matches = recursiveDir(dirPath, pattern);

    if isempty(matches)
        error('pf2:importDirectory:noFilesFound', ...
            'No files matching ''%s'' found in %s', pattern, dirPath);
    end

    nFiles = numel(matches);
    if opts.Verbose
        fprintf('Found %d %s file(s) in %s\n', nFiles, formatName, dirPath);
    end

    % --- Pre-compute paths for loop (required for parfor: no struct indexing) ---
    fullPaths = cell(1, nFiles);
    relParts = cell(1, nFiles);
    fileBasenames = cell(1, nFiles);
    for i = 1:nFiles
        fullPaths{i} = fullfile(matches(i).folder, matches(i).name);
        relParts{i} = getRelativeParts(matches(i).folder, dirPath);
        [~, fileBasenames{i}, ~] = fileparts(matches(i).name);
    end

    % --- BIDS awareness: parse filename entities + detect a BIDS dataset ---
    % A BIDS-NIRS tree encodes sub/ses/task/run in each filename and lays out
    % dataset-level sidecars (dataset_description.json, participants.tsv). When
    % detected, the filename entities are mapped to standard .info fields
    % (SubjectID/Session/Task/Run) so the data groups without a manual DirN map.
    bidsEnt = cell(1, nFiles);
    nBidsNamed = 0;
    for i = 1:nFiles
        bidsEnt{i} = pf2_base.bids.parseEntities(fileBasenames{i});
        if bidsEnt{i}.isBIDS
            nBidsNamed = nBidsNamed + 1;
        end
    end
    participantsFile = fullfile(dirPath, 'participants.tsv');
    hasParticipants = isfile(participantsFile);
    isBIDS = isfile(fullfile(dirPath, 'dataset_description.json')) ...
        || hasParticipants || (nFiles > 0 && nBidsNamed == nFiles);

    % Standard fields the user explicitly claimed via Dir*/Filename mapping.
    % BIDS entity mapping never overrides these (the user's mapping wins).
    explicitDirs = {char(opts.Dir1), char(opts.Dir2), char(opts.Dir3), char(opts.Dir4)};
    userTargets = lower([explicitDirs, {filenameField}]);
    userTargets = userTargets(~cellfun(@isempty, userTargets));

    % --- Import loop (parallel when pool available) ---
    allData = cell(1, nFiles);
    allErrors = cell(1, nFiles);

    [canPar, poolOn] = pf2_base.accel.canParfor();
    useParfor = canPar && poolOn && nFiles > 2;

    if useParfor
        if opts.Verbose
            fprintf('  Importing %d files in parallel...\n', nFiles);
        end

        continueOnError = opts.ContinueOnError;

        bidsMode = isBIDS;
        parfor i = 1:nFiles
            try
                data = importFn(fullPaths{i});
                data = applyInfoFields(data, relParts{i}, dirFieldNames, ...
                    filenameField, fileBasenames{i}, fullPaths{i});
                if bidsMode
                    data = applyBIDSInfo(data, bidsEnt{i}, userTargets);
                end
                allData{i} = data;
            catch ME
                if ~continueOnError
                    rethrow(ME);
                end
                allErrors{i} = ME.message;
            end
        end
    else
        % Sequential fallback (keeps verbose progress output)
        for i = 1:nFiles
            if opts.Verbose
                relDisplay = strrep(fullPaths{i}, [dirPath filesep], '');
                fprintf('  Importing %d/%d: %s\n', i, nFiles, relDisplay);
            end

            try
                data = importFn(fullPaths{i});
                data = applyInfoFields(data, relParts{i}, dirFieldNames, ...
                    filenameField, fileBasenames{i}, fullPaths{i});
                if isBIDS
                    data = applyBIDSInfo(data, bidsEnt{i}, userTargets);
                end
                allData{i} = data;

            catch ME
                if opts.Verbose
                    relDisplay = strrep(fullPaths{i}, [dirPath filesep], '');
                    fprintf('  ** Failed: %s (%s)\n', relDisplay, ME.message);
                end
                if ~opts.ContinueOnError
                    rethrow(ME);
                end
                allErrors{i} = ME.message;
            end
        end
    end

    % --- Filter out failed imports (empty cells) ---
    emptyMask = cellfun(@isempty, allData);
    nFailed = sum(emptyMask);
    nImported = sum(~emptyMask);
    allData = allData(~emptyMask);

    % Print errors from parfor run
    if useParfor && opts.Verbose
        failIdx = find(~cellfun(@isempty, allErrors));
        for k = 1:length(failIdx)
            fprintf('  ** Failed: %s (%s)\n', ...
                strrep(fullPaths{failIdx(k)}, [dirPath filesep], ''), allErrors{failIdx(k)});
        end
    end

    if opts.Verbose
        fprintf('Import complete: %d imported, %d failed, %d total\n', ...
            nImported, nFailed, nFiles);
    end

    if nImported == 0
        warning('pf2:importDirectory:allFailed', ...
            'All %d files failed to import.', nFiles);
    end

    % --- BIDS: merge participants.tsv demographics into each subject's .info ---
    nMergedCols = 0;
    if isBIDS && hasParticipants && nImported > 0
        [allData, nMergedCols] = mergeParticipants(allData, participantsFile);
    end

    % --- Guidance: how to turn directory / BIDS structure into grouping ---
    if opts.Verbose && nImported > 0
        printMappingAdvice(isBIDS, bidsEnt, relParts, userTargets, nMergedCols);
    end

    % --- Warn if SubjectIDs collide (breaks grouping / importInfo) ---
    % Skip the plain SubjectID check in BIDS mode: repeated sub- across sessions
    % and runs is normal BIDS structure, so a bare duplicate-SubjectID warning
    % would be spurious there and its "use filenames as SubjectID" hint would
    % erase participant identity. Instead, in BIDS mode apply the stricter check
    % below -- it flags only recordings that collide on the FULL entity tuple
    % (sub/ses/task/run), which are genuinely indistinguishable. (Note: unlike
    % the export path in asBIDS, import does NOT auto-number colliding entities,
    % so a malformed tree can otherwise produce identical subjects silently.)
    if nImported > 1
        if isBIDS
            warnDuplicateBIDSEntities(allData);
        else
            warnDuplicateSubjectIDs(allData, filenameField);
        end
    end
end


% =========================================================================
% Local helper functions
% =========================================================================

function data = applyInfoFields(data, parts, dirFieldNames, filenameField, basename, fullPath)
% APPLYINFOFIELDS Populate .info from directory levels, filename, and source path.
%   Shared by the parfor and sequential import branches so the two paths
%   cannot drift. Defined as a subfunction (not nested) to stay parfor-safe.
    for k = 1:min(numel(parts), numel(dirFieldNames))
        data.info.(dirFieldNames{k}) = parts{k};
    end
    data.info.sourcePath = fullPath;
    if ~isempty(filenameField)
        data.info.(filenameField) = basename;
    end
end


function data = applyBIDSInfo(data, ent, userTargets)
% APPLYBIDSINFO Map parsed BIDS filename entities to standard .info fields.
%   Sets SubjectID/Session/Task/Run (and participant_id) from the sub/ses/
%   task/run entities so a BIDS-NIRS tree groups without a manual DirN map.
%   A field the user explicitly claimed via a Dir*/Filename mapping (listed in
%   userTargets) is left untouched -- the user's mapping always wins. For the
%   remaining fields the filename entity is authoritative (it overrides any
%   value an importer embedded from the file's own metadata). Parfor-safe.
    if ~ent.isBIDS
        return;
    end
    % participant_id mirrors the BIDS 'sub-<label>' id used to join
    % participants.tsv; SubjectID gets the same value for downstream grouping.
    pid = ['sub-' ent.sub];
    data = setInfoIfUnclaimed(data, 'participant_id', pid, userTargets);
    data = setInfoIfUnclaimed(data, 'SubjectID', pid, userTargets);
    if ~isempty(ent.ses)
        data = setInfoIfUnclaimed(data, 'Session', ent.ses, userTargets);
    end
    if ~isempty(ent.task)
        data = setInfoIfUnclaimed(data, 'Task', ent.task, userTargets);
    end
    if ~isempty(ent.run)
        data = setInfoIfUnclaimed(data, 'Run', ent.run, userTargets);
    end
end


function data = setInfoIfUnclaimed(data, field, value, userTargets)
% Set data.info.(field) unless the user explicitly mapped that field name via
% a Dir*/Filename option (case-insensitive match against userTargets).
    if ismember(lower(field), userTargets)
        return;
    end
    data.info.(field) = value;
end


function [allData, nCols] = mergeParticipants(allData, participantsFile)
% MERGEPARTICIPANTS Fold participants.tsv demographic columns into .info.
%   Rows are keyed by participant_id (e.g. 'sub-01'); each recording's row is
%   matched on its .info.participant_id (or .info.SubjectID) and its columns
%   (other than participant_id) are copied into .info, filling only fields that
%   are missing or empty so importer-provided values are never clobbered.
    nCols = 0;
    try
        T = readtable(participantsFile, 'FileType', 'text', 'Delimiter', '\t');
    catch ME
        warning('pf2:importDirectory:participantsReadFailed', ...
            'Could not read %s: %s', participantsFile, ME.message);
        return;
    end
    vn = T.Properties.VariableNames;
    keyCol = find(strcmpi(vn, 'participant_id'), 1);
    if isempty(keyCol)
        return;   % not a usable participants table
    end
    keys = string(T{:, keyCol});
    dataCols = setdiff(1:numel(vn), keyCol);
    nCols = numel(dataCols);
    if nCols == 0
        return;
    end

    for i = 1:numel(allData)
        d = allData{i};
        pid = '';
        if isfield(d, 'info') && isfield(d.info, 'participant_id')
            pid = char(string(d.info.participant_id));
        elseif isfield(d, 'info') && isfield(d.info, 'SubjectID')
            pid = char(string(d.info.SubjectID));
        end
        if isempty(pid)
            continue;
        end
        row = find(keys == string(pid), 1);
        if isempty(row)
            continue;
        end
        for c = dataCols
            fld = vn{c};
            if isfield(d.info, fld) && ~isempty(d.info.(fld))
                continue;   % keep existing value
            end
            val = T{row, c};
            if iscell(val); val = val{1}; end
            if isstring(val); val = char(val); end
            d.info.(fld) = val;
        end
        allData{i} = d;
    end
end


function printMappingAdvice(isBIDS, bidsEnt, relParts, userTargets, nMergedCols)
% PRINTMAPPINGADVICE Guide the user on turning structure into grouping fields.
%   In BIDS mode: report which filename entities were mapped to .info fields
%   (and any participants.tsv columns merged). Otherwise, when files sit in
%   unmapped sub-folders, suggest a DirN->field remapping so the folder levels
%   become grouping variables (SubjectID, Session, ...).
    if isBIDS
        % Summarize the entities that were actually applied.
        applied = {};
        if entityPresent(bidsEnt, 'sub') && ~ismember('subjectid', userTargets)
            applied{end+1} = sprintf('    sub-  -> SubjectID  (e.g. ''%s'')', ...
                ['sub-' firstEntity(bidsEnt, 'sub')]);
        end
        if entityPresent(bidsEnt, 'ses') && ~ismember('session', userTargets)
            applied{end+1} = sprintf('    ses-  -> Session    (e.g. ''%s'')', ...
                firstEntity(bidsEnt, 'ses'));
        end
        if entityPresent(bidsEnt, 'task') && ~ismember('task', userTargets)
            applied{end+1} = sprintf('    task- -> Task       (e.g. ''%s'')', ...
                firstEntity(bidsEnt, 'task'));
        end
        if entityPresent(bidsEnt, 'run') && ~ismember('run', userTargets)
            applied{end+1} = '    run-  -> Run';
        end
        if isempty(applied) && nMergedCols == 0
            return;
        end
        fprintf('BIDS dataset detected.\n');
        if ~isempty(applied)
            fprintf('  Mapped filename entities to .info:\n');
            fprintf('%s\n', applied{:});
        end
        if nMergedCols > 0
            fprintf('  Merged %d column(s) from participants.tsv into .info.\n', ...
                nMergedCols);
        end
        return;
    end

    % Non-BIDS: advise only when sub-folders were captured but not named.
    if ~isempty(userTargets)
        return;   % user already mapped something -- assume they know the layout
    end
    depth = max(cellfun(@numel, relParts));
    if isempty(depth) || depth < 1
        return;   % flat directory, nothing to remap
    end
    fprintf(['Note: files sit in %d sub-folder level(s), captured as ' ...
        'dir1..dir%d but not named.\n'], depth, depth);
    fprintf('  Remap them to grouping fields, e.g.:\n');
    ex1 = exampleLevel(relParts, 1);
    fprintf('    ''Dir1'', ''SubjectID''%s\n', ex1);
    if depth >= 2
        ex2 = exampleLevel(relParts, 2);
        fprintf('    ''Dir2'', ''Session''%s\n', ex2);
    end
end


function tf = entityPresent(bidsEnt, field)
% True when any parsed entity carries a non-empty value for `field`.
    tf = any(cellfun(@(e) ~isempty(e.(field)), bidsEnt));
end


function v = firstEntity(bidsEnt, field)
% First non-empty value for `field` across parsed entities ('' if none).
    v = '';
    for i = 1:numel(bidsEnt)
        if ~isempty(bidsEnt{i}.(field))
            v = bidsEnt{i}.(field);
            return;
        end
    end
end


function s = exampleLevel(relParts, level)
% Format a ' (e.g. ''value'')' hint from the first file that has `level`.
    s = '';
    for i = 1:numel(relParts)
        if numel(relParts{i}) >= level
            s = sprintf(' (e.g. dir%d = ''%s'')', level, relParts{i}{level});
            return;
        end
    end
end


function warnDuplicateSubjectIDs(allData, filenameField)
% WARNDUPLICATESUBJECTIDS Warn when imported files share a SubjectID value.
%   Duplicate SubjectIDs break per-subject grouping and pf2.data.importInfo
%   (which keys on SubjectID). Silent when the field is absent on all files
%   or when every present ID is unique.
    ids = strings(1, numel(allData));
    hasField = false;
    for i = 1:numel(allData)
        d = allData{i};
        if isfield(d, 'info') && isfield(d.info, 'SubjectID') && ~isempty(d.info.SubjectID)
            ids(i) = string(d.info.SubjectID);
            hasField = true;
        end
    end
    if ~hasField
        return;
    end
    nonEmpty = ids(strlength(ids) > 0);
    nUnique = numel(unique(nonEmpty));
    if nUnique < numel(nonEmpty)
        if strcmpi(filenameField, 'SubjectID')
            hint = 'Check that filenames are unique.';
        else
            hint = ['Supply ''Filename'', ''SubjectID'' (use the filename as ID) ' ...
                    'or a ''DirN'', ''SubjectID'' mapping to assign unique IDs.'];
        end
        warning('pf2:importDirectory:duplicateSubjectID', ...
            ['%d imported file(s) share a SubjectID (%d unique value(s)). ' ...
             'Per-subject grouping and pf2.data.importInfo keyed on SubjectID ' ...
             'will fail. %s'], numel(nonEmpty), nUnique, hint);
    end
end


function warnDuplicateBIDSEntities(allData)
% WARNDUPLICATEBIDSENTITIES Warn when BIDS recordings share a full entity tuple.
%   In BIDS mode a repeated sub- is expected across sessions/runs, so the plain
%   SubjectID check is too aggressive. This stricter check flags only records
%   that collide on the entire (SubjectID, Session, Task, Run) tuple -- the only
%   entities import maps into .info -- because those recordings are truly
%   indistinguishable by any downstream grouping field. That happens when a tree
%   is malformed (e.g. a multi-site merge or copy-paste duplicates a file) or
%   when files differ only by an entity pf2 does not track (acq-, dir-, echo-).
%   Import, unlike asBIDS export, does not auto-number such collisions.
    keys = strings(1, numel(allData));
    for i = 1:numel(allData)
        d = allData{i};
        if ~isfield(d, 'info'), continue; end
        keys(i) = strjoin([ ...
            infoStr(d.info, 'SubjectID'), infoStr(d.info, 'Session'), ...
            infoStr(d.info, 'Task'),      infoStr(d.info, 'Run')], '|');
    end
    [uniqKeys, ~, grp] = unique(keys);
    counts = accumarray(grp(:), 1);
    dupMask = counts > 1;
    if any(dupMask)
        nDup = sum(counts(dupMask));
        warning('pf2:importDirectory:duplicateBIDSEntities', ...
            ['%d imported recording(s) share an identical BIDS entity tuple ' ...
             '(sub/ses/task/run) and are indistinguishable by .info grouping ' ...
             'fields. The tree may be malformed (duplicated file) or use an ' ...
             'entity pf2 does not track (acq-, dir-, echo-). Add a run- (or the ' ...
             'missing entity) so each recording is unique.'], nDup);
    end
end


function s = infoStr(info, field)
% Return an .info field as a scalar string ('' if absent/empty), for key-building
    if isfield(info, field) && ~isempty(info.(field))
        s = string(info.(field));
        if ~isscalar(s), s = strjoin(s(:)', ','); end
    else
        s = "";
    end
end


function fn = getImporterForExtension(ext, channelCheck)
% GETIMPORTERFOREXTENSION Return import function handle for a file extension
    switch ext
        case '.nir'
            fn = @(f) pf2.import.importNIR(f, true, channelCheck);
        case '.snirf'
            fn = @(f) pf2.import.importSNIRF(f, channelCheck);
        case '.csv'
            fn = @(f) pf2.import.importHitachiMES(f, [], channelCheck);
        case {'.hdr', '.wl1', '.wl2'}
            fn = @(f) pf2.import.importNIRX(f, channelCheck);
        case '.oxy3'
            fn = @(f) pf2.import.importOxy3(f, channelCheck);
        otherwise
            error('pf2:importDirectory:unsupportedFormat', ...
                'Unsupported file extension ''%s''. Supported: .nir, .snirf, .csv, .hdr, .oxy3', ext);
    end
end


function parts = getRelativeParts(fullFolder, rootPath)
% GETRELATIVEPARTS Return cell array of directory names between root and file
    rel = strrep(fullFolder, [rootPath filesep], '');
    if strcmp(rel, rootPath) || isempty(rel)
        parts = {};
    else
        parts = strsplit(rel, filesep);
        % Remove empty entries
        parts = parts(~cellfun('isempty', parts));
    end
end


function matches = recursiveDir(dirPath, pattern)
% RECURSIVEDIR Recursively find files matching a pattern in all subdirectories
%   Walks the directory tree manually to avoid genpath filtering (which
%   skips +, @, private, and hidden dirs) and dir('**') platform issues.
    matches = struct('name',{},'folder',{},'date',{},'bytes',{},'isdir',{},'datenum',{});
    stack = {dirPath};
    while ~isempty(stack)
        current = stack{end};
        stack(end) = [];
        % Search for matching files in current directory
        found = dir(fullfile(current, pattern));
        found = found(~[found.isdir]);
        if ~isempty(found)
            matches = [matches; found]; %#ok<AGROW>
        end
        % Find all subdirectories and push onto stack
        entries = dir(current);
        for k = 1:numel(entries)
            if entries(k).isdir && entries(k).name(1) ~= '.'
                stack{end+1} = fullfile(current, entries(k).name); %#ok<AGROW>
            end
        end
    end
end


function name = getFormatName(ext)
% GETFORMATNAME Return human-readable format label for file extension
    switch ext
        case '.nir'
            name = 'fNIR Devices (.nir)';
        case '.snirf'
            name = 'SNIRF (.snirf)';
        case '.csv'
            name = 'Hitachi MES (.csv)';
        case {'.hdr', '.wl1', '.wl2'}
            name = 'NIRx (.hdr)';
        case '.oxy3'
            name = 'Artinis OxySoft (.oxy3)';
        otherwise
            name = ext;
    end
end
