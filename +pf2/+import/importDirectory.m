function allData = importDirectory(dirPath, pattern, opts)
% IMPORTDIRECTORY Batch-import fNIRS files from a directory tree
%
% Recursively scans a directory for fNIRS files matching a glob pattern,
% auto-detects the file format from the extension, and imports each file
% using the appropriate importer. Optionally maps directory hierarchy
% levels into .info fields for downstream grouping in exploreFNIRS.
%
% Syntax:
%   allData = pf2.import.importDirectory(dirPath, pattern)
%   allData = pf2.import.importDirectory(dirPath, pattern, Name, Value)
%
% Inputs:
%   dirPath  - Root directory to scan [char | string]
%              Must be an existing directory.
%   pattern  - Glob pattern for file matching [char | string]
%              Examples: '*.snirf', 'valid*.nir', '*.hdr'
%              Extension determines the importer used.
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
        dirPath {mustBeText}
        pattern {mustBeText}
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

        parfor i = 1:nFiles
            try
                data = importFn(fullPaths{i});
                data = applyInfoFields(data, relParts{i}, dirFieldNames, ...
                    filenameField, fileBasenames{i}, fullPaths{i});
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

    % --- Warn if SubjectIDs collide (breaks grouping / importInfo) ---
    if nImported > 1
        warnDuplicateSubjectIDs(allData, filenameField);
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
