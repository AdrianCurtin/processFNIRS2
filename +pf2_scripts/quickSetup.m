function quickSetup()
% QUICKSETUP Interactive wizard that generates a complete fNIRS analysis script
%
% Collects dataset information through a series of command-line prompts,
% then writes a complete .m script using existing pf2 and exploreFNIRS APIs.
% The wizard does NOT import or process data -- it only scans the filesystem
% and generates code. The user edits and runs the generated script.
%
% Prompts cover four stages:
%   1. Import setup:      data directory, file format, channel check, directory mapping
%   2. Demographics:      optional CSV merge via importInfo
%   3. Marker dictionary: condition codes from CSV/manual entry, or skip
%   4. Processing:        raw/oxy methods, baseline, export format, script name
%
% Syntax:
%   pf2_scripts.quickSetup()
%
% Example:
%   pf2_scripts.quickSetup()
%   % Follow the prompts, then run the generated script.
%
% See also: processFNIRS2, pf2.import.importDirectory, pf2.data.defineBlocks

    fprintf('\n');
    fprintf('  ========================================\n');
    fprintf('  processFNIRS2 - Quick Setup Wizard\n');
    fprintf('  ========================================\n');
    fprintf('  Generates a ready-to-run analysis script\n');
    fprintf('  from your dataset.\n\n');

    cfg = struct();

    % --- Stage 1: Import ---
    cfg = stageImport(cfg);

    % --- Stage 2: Demographics ---
    cfg = stageDemographics(cfg);

    % --- Stage 3: Markers ---
    cfg = stageMarkers(cfg);

    % --- Stage 4: Processing options ---
    cfg = stageProcessing(cfg);

    % --- Generate script ---
    generateScript(cfg);

    fprintf('\n  Setup complete.\n\n');
end


% =========================================================================
%  STAGE FUNCTIONS
% =========================================================================

function cfg = stageImport(cfg)
% STAGEIMPORT Prompts for data directory, format, channel check, dir mapping.

    fprintf('--- Stage 1: Import Setup ---\n\n');

    % 1. Data directory
    while true
        dataDir = promptText('Data directory path', pwd);
        if isfolder(dataDir)
            break;
        end
        fprintf('  Directory not found: %s\n', dataDir);
    end
    cfg.dataDir = dataDir;

    % 2. File format
    formatLabels = {'SNIRF (.snirf)', 'NIR (.nir)', 'Hitachi CSV (.csv)', 'NIRx HDR (.hdr)'};
    formatPatterns = {'*.snirf', '*.nir', '*.csv', '*.hdr'};
    fmtIdx = promptMenu('File format', formatLabels, 1);
    cfg.filePattern = formatPatterns{fmtIdx};
    cfg.formatLabel = formatLabels{fmtIdx};

    % 3. Channel check (SCI)
    doSCI = promptMenu('Run Scalp Coupling Index (SCI) channel check?', {'Yes', 'No'}, 2);
    cfg.doSCI = (doSCI == 1);
    if cfg.doSCI
        cfg.sciThreshold = promptNumber('SCI threshold (0-1)', 0.75);
    else
        cfg.sciThreshold = 0.75;
    end

    % 4. Scan filesystem
    fprintf('\n  Scanning %s for %s ...\n', dataDir, cfg.filePattern);
    files = scanFiles(dataDir, cfg.filePattern);
    if isempty(files)
        fprintf('  WARNING: No files matching %s found in %s\n', cfg.filePattern, dataDir);
        fprintf('  The generated script will use this path but may fail at runtime.\n');
        cfg.fileCount = 0;
        cfg.dirMappings = {};
        return;
    end
    cfg.fileCount = numel(files);
    fprintf('  Found %d file(s).\n\n', cfg.fileCount);

    % 5. Directory mapping
    levels = analyzeDirectoryLevels(files, dataDir);
    cfg.dirMappings = {};

    if isempty(levels)
        fprintf('  All files are in the root directory (no subdirectories).\n');
    else
        fprintf('  Directory structure detected (%d level(s) below root):\n', numel(levels));
        defaultNames = {'Group', 'SubjectID', 'Session', 'Run'};
        for k = 1:min(numel(levels), 4)
            vals = levels{k};
            nShow = min(numel(vals), 6);
            preview = strjoin(vals(1:nShow), ', ');
            if numel(vals) > nShow
                preview = [preview, sprintf(' ... (%d total)', numel(vals))]; %#ok<AGROW>
            end
            fprintf('    Level %d: %s\n', k, preview);

            defaultName = '';
            if k <= numel(defaultNames)
                defaultName = defaultNames{k};
            end
            fieldName = promptText(sprintf('  Info field name for level %d (blank to skip)', k), defaultName);
            if ~isempty(strtrim(fieldName))
                cfg.dirMappings{end+1} = strtrim(fieldName);
            else
                cfg.dirMappings{end+1} = '';
            end
        end
    end
end


function cfg = stageDemographics(cfg)
% STAGEDEMOGRAPHICS Prompts for optional demographics file (CSV or Excel).

    fprintf('\n--- Stage 2: Demographics ---\n\n');

    choice = promptMenu('Do you have a demographics/metadata file (CSV or Excel)?', {'Yes', 'No'}, 2);
    cfg.hasDemographics = (choice == 1);

    if cfg.hasDemographics
        needsTemplate = false;
        while true
            csvPath = promptText('Demographics file path');
            if isfile(csvPath)
                break;
            end
            create = promptMenu('  File not found. Create a template?', ...
                {'Yes, create template', 'No, enter a different path'}, 1);
            if create == 1
                needsTemplate = true;
                break;
            end
        end
        cfg.demographicsPath = csvPath;

        % Ask which field to match on
        if ~isempty(cfg.dirMappings)
            validMappings = cfg.dirMappings(~cellfun('isempty', cfg.dirMappings));
            if ~isempty(validMappings)
                fprintf('  Available info fields from directory mapping:\n');
                for k = 1:numel(validMappings)
                    fprintf('    %d. %s\n', k, validMappings{k});
                end
            end
        end
        cfg.demographicsKey = promptText('Info field to match CSV rows on', 'SubjectID');

        if needsTemplate
            cols = unique({cfg.demographicsKey, 'SubjectID', 'Group', 'Subgroup', 'Age', 'Sex'}, 'stable');
            createTemplateFile(csvPath, cols);
            fprintf('  Fill in one row per subject, then run the generated script.\n');
        end
    else
        cfg.demographicsPath = '';
        cfg.demographicsKey = '';
    end
end


function cfg = stageMarkers(cfg)
% STAGEMARKERS Prompts for marker/condition configuration.

    fprintf('\n--- Stage 3: Marker / Condition Setup ---\n\n');

    choice = promptMenu('How are task conditions defined?', ...
        {'Marker dictionary file (CSV/Excel)', 'Enter codes manually', 'Skip (no block analysis)'}, 3);

    cfg.markerMode = choice;  % 1=file, 2=manual, 3=skip

    if choice == 1
        % --- Dictionary file ---
        cfg = readMarkerDictionary(cfg);

    elseif choice == 2
        % --- Manual entry ---
        cfg = enterMarkersManually(cfg);

    else
        % --- Skip ---
        cfg.conditions = {};
    end

    % --- Per-trial behavioral data ---
    if ~isempty(cfg.conditions)
        cfg = promptBlockInfo(cfg);
    else
        cfg.hasBlockInfo = false;
        cfg.blockInfoPath = '';
        cfg.blockInfoKeys = {};
    end
end


function cfg = readMarkerDictionary(cfg)
% READMARKERDICTIONARY Read and validate a marker dictionary CSV/Excel file.

    needsTemplate = false;
    while true
        dictPath = promptText('Marker dictionary file path');
        if isfile(dictPath)
            break;
        end
        create = promptMenu('  File not found. Create a template?', ...
            {'Yes, create template', 'No, enter a different path'}, 1);
        if create == 1
            needsTemplate = true;
            break;
        end
    end

    if needsTemplate
        createTemplateFile(dictPath, {'StartCode', 'EndCode', 'Duration', 'Condition'});
        fprintf('  Fill in the marker dictionary, then re-run the wizard to load it.\n');
        fprintf('  Switching to manual entry for now.\n\n');
        cfg.markerDictPath = dictPath;
        cfg = enterMarkersManually(cfg);
        return;
    end

    try
        T = readtable(dictPath, 'TextType', 'string');
    catch ME
        fprintf('  Error reading file: %s\n', ME.message);
        fprintf('  Falling back to manual entry.\n');
        cfg = enterMarkersManually(cfg);
        return;
    end

    % Validate required columns
    colNames = T.Properties.VariableNames;
    if ~any(strcmpi(colNames, 'StartCode'))
        fprintf('  ERROR: Dictionary must have a StartCode column.\n');
        fprintf('  Found columns: %s\n', strjoin(colNames, ', '));
        fprintf('  Falling back to manual entry.\n');
        cfg = enterMarkersManually(cfg);
        return;
    end

    hasEndCode = any(strcmpi(colNames, 'EndCode'));
    hasDuration = any(strcmpi(colNames, 'Duration'));

    if ~hasEndCode && ~hasDuration
        fprintf('  ERROR: Dictionary must have EndCode or Duration column.\n');
        fprintf('  Falling back to manual entry.\n');
        cfg = enterMarkersManually(cfg);
        return;
    end

    % Build conditions struct array
    conditions = struct('startCode', {}, 'endCode', {}, 'duration', {}, 'labels', {}, 'labelFields', {});
    % Identify label columns (everything except StartCode, EndCode, Duration)
    labelCols = colNames(~ismember(lower(colNames), {'startcode', 'endcode', 'duration'}));

    for r = 1:height(T)
        c = struct();
        c.startCode = T.StartCode(r);

        if hasEndCode && ~ismissing(T.EndCode(r)) && T.EndCode(r) ~= 0
            c.endCode = T.EndCode(r);
        else
            c.endCode = [];
        end

        if hasDuration && ~ismissing(T.Duration(r)) && T.Duration(r) > 0
            c.duration = T.Duration(r);
        else
            c.duration = [];
        end

        if isempty(c.endCode) && isempty(c.duration)
            fprintf('  WARNING: Row %d has neither EndCode nor Duration, skipping.\n', r);
            continue;
        end

        c.labels = {};
        c.labelFields = labelCols;
        for lc = 1:numel(labelCols)
            val = T.(labelCols{lc})(r);
            if isstring(val) || ischar(val)
                c.labels{end+1} = char(val);
            else
                c.labels{end+1} = num2str(val);
            end
        end

        conditions(end+1) = c; %#ok<AGROW>
    end

    cfg.conditions = conditions;
    cfg.markerDictPath = dictPath;
    fprintf('  Loaded %d conditions from dictionary.\n', numel(conditions));
end


function cfg = enterMarkersManually(cfg)
% ENTERMARKERSMANUALLY Prompt for marker codes and save a template file.

    fprintf('\n  Enter marker codes one condition at a time.\n');
    fprintf('  Type "done" when finished.\n\n');

    conditions = struct('startCode', {}, 'endCode', {}, 'duration', {}, 'labels', {}, 'labelFields', {});
    condIdx = 0;

    while true
        condIdx = condIdx + 1;
        codeStr = promptText(sprintf('  Condition %d start code (or "done")', condIdx));
        if strcmpi(strtrim(codeStr), 'done')
            break;
        end

        startCode = str2double(codeStr);
        if isnan(startCode)
            fprintf('  Invalid number. Try again.\n');
            condIdx = condIdx - 1;
            continue;
        end

        label = promptText(sprintf('  Condition %d label', condIdx), sprintf('Cond%d', condIdx));

        durMode = promptMenu(sprintf('  Condition %d: how is block end defined?', condIdx), ...
            {'Fixed duration (seconds)', 'End marker code'}, 1);

        c = struct();
        c.startCode = startCode;
        c.labelFields = {'Condition'};
        c.labels = {label};

        if durMode == 1
            c.duration = promptNumber('  Duration (seconds)', 30);
            c.endCode = [];
        else
            c.endCode = promptNumber('  End marker code');
            c.duration = [];
        end

        conditions(end+1) = c; %#ok<AGROW>
    end

    cfg.conditions = conditions;

    if ~isempty(conditions)
        % Offer to save a template CSV
        saveCsv = promptMenu('Save marker dictionary as a template file?', {'Yes', 'No'}, 1);
        if saveCsv == 1
            csvPath = promptText('Template file path', fullfile(pwd, 'marker_dictionary.csv'));
            saveMarkerTemplate(conditions, csvPath);
            cfg.markerDictPath = csvPath;
        end
    end
end


function saveMarkerTemplate(conditions, csvPath)
% SAVEMARKERTEMPLATE Write conditions to a file for later editing.

    nRows = numel(conditions);
    StartCode = zeros(nRows, 1);
    EndCode = zeros(nRows, 1);
    Duration = zeros(nRows, 1);
    Condition = cell(nRows, 1);

    for k = 1:nRows
        StartCode(k) = conditions(k).startCode;
        if ~isempty(conditions(k).endCode)
            EndCode(k) = conditions(k).endCode;
        end
        if ~isempty(conditions(k).duration)
            Duration(k) = conditions(k).duration;
        end
        if ~isempty(conditions(k).labels)
            Condition{k} = conditions(k).labels{1};
        else
            Condition{k} = sprintf('Cond%d', k);
        end
    end

    T = table(StartCode, EndCode, Duration, Condition);
    writetable(T, csvPath);
    fprintf('  Saved marker template: %s\n', csvPath);
end


function cfg = stageProcessing(cfg)
% STAGEPROCESSING Prompts for processing method, baseline, export, script name.

    fprintf('\n--- Stage 4: Processing Options ---\n\n');

    % Raw method
    rawLabels = {'TDDR - motion correction (recommended)', ...
                 'Low-pass filter + SMAR', ...
                 'Band-pass filter (0.008-0.1 Hz)', ...
                 'Low-pass filter only', ...
                 'None'};
    rawValues = {'tddr', 'lpf_smar', 'bpf', 'lpf', 'None'};
    rawIdx = promptMenu('Raw processing method', rawLabels, 1);
    cfg.rawMethod = rawValues{rawIdx};

    % Oxy method
    oxyLabels = {'None (recommended)', ...
                 'Takizawa rejection (lenient)', ...
                 'Takizawa rejection (strict)'};
    oxyValues = {'None', 'takizawa_easy', 'takizawa_hard'};
    oxyIdx = promptMenu('Oxy processing method', oxyLabels, 1);
    cfg.oxyMethod = oxyValues{oxyIdx};

    % Baseline
    cfg.baselineLength = promptNumber('Baseline length (seconds)', 10);

    % Export format
    expLabels = {'SNIRF', 'NIR', 'None'};
    expIdx = promptMenu('Export format for processed data', expLabels, 3);
    cfg.exportFormat = expLabels{expIdx};

    % Script name
    cfg.scriptName = promptText('Script name (without .m)', 'my_analysis');
    if endsWith(cfg.scriptName, '.m')
        cfg.scriptName = cfg.scriptName(1:end-2);
    end
end


function cfg = promptBlockInfo(cfg)
% PROMPTBLOCKINFO Ask whether per-trial behavioral data should be imported.
%   Only called when cfg.conditions is non-empty. Sets cfg.hasBlockInfo,
%   cfg.blockInfoPath, and cfg.blockInfoKeys.

    choice = promptMenu('Do you have per-trial behavioral data (accuracy, reaction time, etc.)?', ...
        {'No', 'Yes'}, 1);

    if choice == 1
        cfg.hasBlockInfo = false;
        cfg.blockInfoPath = '';
        cfg.blockInfoKeys = {};
        return;
    end

    cfg.hasBlockInfo = true;

    % File path
    needsTemplate = false;
    while true
        csvPath = promptText('Behavioral data file path (CSV or Excel)');
        if isfile(csvPath)
            break;
        end
        create = promptMenu('  File not found. Create a template?', ...
            {'Yes, create template', 'No, enter a different path'}, 1);
        if create == 1
            needsTemplate = true;
            break;
        end
    end
    cfg.blockInfoPath = csvPath;

    % Auto-suggest key fields from directory mappings + condition label fields + BlockNumber
    suggestedKeys = {};

    % Directory-mapped fields (e.g. Group, SubjectID)
    if isfield(cfg, 'dirMappings') && ~isempty(cfg.dirMappings)
        validMappings = cfg.dirMappings(~cellfun('isempty', cfg.dirMappings));
        suggestedKeys = [suggestedKeys, validMappings];
    end

    % Condition label fields from first condition
    if ~isempty(cfg.conditions) && ~isempty(cfg.conditions(1).labelFields)
        for k = 1:numel(cfg.conditions(1).labelFields)
            fld = cfg.conditions(1).labelFields{k};
            if ~any(strcmpi(suggestedKeys, fld))
                suggestedKeys{end+1} = fld; %#ok<AGROW>
            end
        end
    end

    % Always include BlockNumber
    if ~any(strcmpi(suggestedKeys, 'BlockNumber'))
        suggestedKeys{end+1} = 'BlockNumber';
    end

    defaultStr = strjoin(suggestedKeys, ', ');
    keysRaw = promptText(sprintf('Key fields [%s]', defaultStr), defaultStr);

    % Parse comma-separated key fields
    parts = strsplit(keysRaw, ',');
    cfg.blockInfoKeys = cellfun(@strtrim, parts, 'UniformOutput', false);
    cfg.blockInfoKeys = cfg.blockInfoKeys(~cellfun('isempty', cfg.blockInfoKeys));

    if needsTemplate
        cols = [cfg.blockInfoKeys, {'Accuracy', 'RT'}];
        createTemplateFile(csvPath, cols);
        fprintf('  Fill in one row per block per subject, then run the generated script.\n');
    end
end


% =========================================================================
%  SCRIPT GENERATION
% =========================================================================

function generateScript(cfg)
% GENERATESCRIPT Write the complete analysis .m script.

    outPath = fullfile(pwd, [cfg.scriptName '.m']);

    % Check for overwrite
    if isfile(outPath)
        ow = promptMenu(sprintf('File %s already exists. Overwrite?', outPath), ...
            {'Yes', 'No'}, 2);
        if ow == 2
            fprintf('  Aborted. Script not written.\n');
            return;
        end
    end

    fid = fopen(outPath, 'w');
    if fid == -1
        error('pf2_scripts:quickSetup:cannotWrite', 'Cannot open %s for writing.', outPath);
    end

    cleanupObj = onCleanup(@() fclose(fid));

    hasConditions = ~isempty(cfg.conditions);

    % --- Header ---
    writeSection(fid, 0, cfg.scriptName, ...
        sprintf('Generated by pf2_scripts.quickSetup on %s', char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm'))), {});

    % --- PART 1: IMPORT ---
    codeLines = {};
    codeLines{end+1} = sprintf('dataDir = %s;', escapeStr(cfg.dataDir));
    codeLines{end+1} = '';

    % Build importDirectory call
    importArgs = sprintf('allData = pf2.import.importDirectory(dataDir, %s', escapeStr(cfg.filePattern));
    dirArgCount = 0;
    for k = 1:numel(cfg.dirMappings)
        if ~isempty(cfg.dirMappings{k})
            dirArgCount = dirArgCount + 1;
            importArgs = sprintf('%s, ...\n    ''Dir%d'', %s', importArgs, k, escapeStr(cfg.dirMappings{k}));
        end
    end
    importArgs = [importArgs, ');'];
    codeLines{end+1} = importArgs;
    codeLines{end+1} = '';
    codeLines{end+1} = 'fprintf(''Imported %d file(s).\n'', numel(allData));';

    writeSection(fid, 1, 'IMPORT', ...
        sprintf('Import all %s files from the data directory.\n%%  Directory mappings populate .info fields for downstream grouping.', cfg.formatLabel), ...
        codeLines);

    % --- PART 2: CHANNEL QUALITY (conditional) ---
    if cfg.doSCI
        codeLines = {};
        codeLines{end+1} = sprintf('sciThreshold = %.2f;', cfg.sciThreshold);
        codeLines{end+1} = '';
        codeLines{end+1} = 'for i = 1:numel(allData)';
        codeLines{end+1} = '    result = pf2.qc.sci(allData{i}, ''Threshold'', sciThreshold);';
        codeLines{end+1} = '    allData{i}.fchMask = allData{i}.fchMask & result.isGood;';
        codeLines{end+1} = '    nBad = sum(~result.isGood);';
        codeLines{end+1} = '    if nBad > 0';
        codeLines{end+1} = '        fprintf(''  Subject %d: rejected %d/%d channels (SCI < %.2f)\n'', ...';
        codeLines{end+1} = '            i, nBad, numel(result.isGood), sciThreshold);';
        codeLines{end+1} = '    end';
        codeLines{end+1} = 'end';

        writeSection(fid, 2, 'CHANNEL QUALITY', ...
            'Scalp Coupling Index: reject channels with poor optode contact.', ...
            codeLines);
    end

    % --- PART 3: DEMOGRAPHICS ---
    partNum = 2 + cfg.doSCI;
    if cfg.hasDemographics
        codeLines = {};
        codeLines{end+1} = sprintf('csvPath = %s;', escapeStr(cfg.demographicsPath));
        codeLines{end+1} = '';
        codeLines{end+1} = 'if ~isfile(csvPath)';
        codeLines{end+1} = '    % Auto-generate a template pre-populated with info from imported data.';
        codeLines{end+1} = '    % Includes directory-mapped fields and ensures SubjectID/Group/Subgroup columns.';
        codeLines{end+1} = '    T = pf2.data.infoToTable(allData);';
        codeLines{end+1} = '    for col = {''SubjectID'', ''Group'', ''Subgroup'', ''Age'', ''Sex''}';
        codeLines{end+1} = '        if ~ismember(col{1}, T.Properties.VariableNames)';
        codeLines{end+1} = '            T.(col{1}) = repmat({''''}, height(T), 1);';
        codeLines{end+1} = '        end';
        codeLines{end+1} = '    end';
        codeLines{end+1} = '    writetable(T, csvPath);';
        codeLines{end+1} = '    fprintf(''Created demographics template: %s (%d subjects)\n'', csvPath, height(T));';
        codeLines{end+1} = '    fprintf(''Fill in the template, then re-run this script.\n'');';
        codeLines{end+1} = '    return;';
        codeLines{end+1} = 'end';
        codeLines{end+1} = '';
        codeLines{end+1} = sprintf('allData = pf2.data.importInfo(allData, csvPath, %s);', escapeStr(cfg.demographicsKey));
        codeLines{end+1} = '';
        codeLines{end+1} = '% Verify the merge';
        codeLines{end+1} = 'T = pf2.data.infoToTable(allData);';
        codeLines{end+1} = 'disp(T);';

        writeSection(fid, partNum, 'DEMOGRAPHICS', ...
            'Merge subject metadata from file into .info fields.', ...
            codeLines);
    else
        codeLines = {};
        codeLines{end+1} = '% No demographics file was specified during setup.';
        codeLines{end+1} = '% To add metadata later, create a CSV/Excel file with one row per subject and run:';
        codeLines{end+1} = '%';
        codeLines{end+1} = '%   allData = pf2.data.importInfo(allData, ''demographics.csv'', ''SubjectID'');';
        codeLines{end+1} = '%';
        codeLines{end+1} = '% To export current .info fields as a template for editing:';
        codeLines{end+1} = '%';
        codeLines{end+1} = '%   pf2.data.infoToTable(allData, ''SavePath'', ''info_template.xlsx'');';

        writeSection(fid, partNum, 'DEMOGRAPHICS', ...
            'Metadata merge placeholder (uncomment and edit as needed).', ...
            codeLines);
    end

    % --- PART N: ENSURE METHODS ---
    % Generate code to create processing methods if they don't exist yet.
    % Sets rawMethodName / oxyMethodName variables for the PROCESS section.
    ensureLines = buildEnsureMethodsCode(cfg.rawMethod, cfg.oxyMethod);
    hasEnsureRaw = ~strcmpi(cfg.rawMethod, 'None');
    hasEnsureOxy = ~strcmpi(cfg.oxyMethod, 'None');
    if ~isempty(ensureLines)
        partNum = partNum + 1;
        writeSection(fid, partNum, 'ENSURE METHODS', ...
            'Create processing methods if they do not exist in this installation.', ...
            ensureLines);
    end

    % --- PART N+1: PROCESS ---
    partNum = partNum + 1;
    codeLines = {};

    % Use rawMethodName/oxyMethodName variables (set by ENSURE METHODS) when
    % the method is not 'None'; otherwise use the literal string 'None'.
    if hasEnsureRaw
        rawArg = 'rawMethodName';
    else
        rawArg = escapeStr('None');
    end
    if hasEnsureOxy
        oxyArg = 'oxyMethodName';
    else
        oxyArg = escapeStr('None');
    end

    codeLines{end+1} = sprintf('allProcessed = processFNIRS2(allData, %s, %s, ...', rawArg, oxyArg);
    codeLines{end+1} = '    ''DPFmode'', ''Calc'', ...';
    codeLines{end+1} = sprintf('    ''blLength'', %g, ...', cfg.baselineLength);
    codeLines{end+1} = '    ''blStartTime'', 0);';
    codeLines{end+1} = '';
    codeLines{end+1} = 'fprintf(''Processed %d subjects.\n'', numel(allProcessed));';

    writeSection(fid, partNum, 'PROCESS', ...
        sprintf('Convert raw data to hemoglobin concentrations.\n%%  Raw method: %s  |  Oxy method: %s  |  Baseline: %gs', ...
        cfg.rawMethod, cfg.oxyMethod, cfg.baselineLength), ...
        codeLines);

    % --- PARTS 5-7: Block analysis (conditional) ---
    if hasConditions
        % --- PART 5: DEFINE BLOCKS ---
        partNum = partNum + 1;
        codeLines = buildDefineBlocksCode(cfg);
        writeSection(fid, partNum, 'DEFINE BLOCKS', ...
            'Convert event markers into block definitions with condition labels.', ...
            codeLines);

        % --- IMPORT BLOCK DATA (conditional) ---
        if cfg.hasBlockInfo
            partNum = partNum + 1;
            codeLines = buildBlockInfoCode(cfg);
            writeSection(fid, partNum, 'IMPORT BLOCK DATA', ...
                'Merge per-trial behavioral data into block .info fields.', ...
                codeLines);
        end

        % --- EXTRACT SEGMENTS ---
        partNum = partNum + 1;
        codeLines = {};
        codeLines{end+1} = sprintf('preTime  = %g;  %% seconds before block onset (baseline period)', cfg.baselineLength);
        codeLines{end+1} = 'postTime = 15;  % seconds after block end (capture the HRF tail)';
        codeLines{end+1} = '';
        codeLines{end+1} = 'allSegments = {};';
        codeLines{end+1} = 'for i = 1:numel(allProcessed)';
        codeLines{end+1} = '    segs = pf2.data.extractBlocks(allProcessed{i}, blocks, ...';
        codeLines{end+1} = '        ''PreTime'', preTime, ...';
        codeLines{end+1} = '        ''PostTime'', postTime, ...';
        codeLines{end+1} = '        ''SetT0'', true);';
        codeLines{end+1} = '    allSegments = [allSegments, segs]; %#ok<AGROW>';
        codeLines{end+1} = 'end';
        codeLines{end+1} = '';
        codeLines{end+1} = 'fprintf(''Extracted %d segments from %d subjects.\n'', ...';
        codeLines{end+1} = '    numel(allSegments), numel(allProcessed));';

        writeSection(fid, partNum, 'EXTRACT SEGMENTS', ...
            'Cut continuous recordings into time-locked epochs around each block.', ...
            codeLines);

        % --- PART 7: GROUP ANALYSIS ---
        partNum = partNum + 1;
        codeLines = buildGroupAnalysisCode(cfg);
        writeSection(fid, partNum, 'GROUP ANALYSIS', ...
            'Build Experiment, group data, aggregate, plot, and run statistics.', ...
            codeLines);
    end

    % --- PART N: EXPORT ---
    if ~strcmpi(cfg.exportFormat, 'None')
        partNum = partNum + 1;
        codeLines = buildExportCode(cfg, hasConditions);
        writeSection(fid, partNum, 'EXPORT', ...
            'Export processed data and results.', ...
            codeLines);
    elseif hasConditions
        % Even without file export, offer tabular export
        partNum = partNum + 1;
        codeLines = {};
        codeLines{end+1} = '% Export group results to CSV for external statistics (R, Python, SPSS)';
        codeLines{end+1} = 'longT = ex.toLongTable({''HbO'', ''HbR''}, 1:size(allSegments{1}.HbO, 2));';
        codeLines{end+1} = 'writetable(longT, ''results_long.csv'');';
        codeLines{end+1} = 'fprintf(''Exported %d rows to results_long.csv\n'', height(longT));';

        writeSection(fid, partNum, 'EXPORT', ...
            'Export group results to CSV.', ...
            codeLines);
    end

    fprintf('\n  Script written: %s\n', outPath);
end


function codeLines = buildEnsureMethodsCode(rawMethod, oxyMethod)
% BUILDENSUREMETHODSCODE Generate code that creates methods if missing.
%   Checks both the clean name and legacy alias before creating.
%   Sets rawMethodName / oxyMethodName variables for use by the PROCESS section.

    codeLines = {};

    knownRaw = getKnownRawMethods();
    knownOxy = getKnownOxyMethods();

    if ~strcmpi(rawMethod, 'None') && isKey(knownRaw, rawMethod)
        def = knownRaw(rawMethod);
        codeLines = [codeLines, methodCheckBlock(rawMethod, 'raw', def.funcs, def.legacy)];
    end

    if ~strcmpi(oxyMethod, 'None') && isKey(knownOxy, oxyMethod)
        def = knownOxy(oxyMethod);
        if ~isempty(codeLines)
            codeLines{end+1} = '';
        end
        codeLines = [codeLines, methodCheckBlock(oxyMethod, 'oxy', def.funcs, def.legacy)];
    end
end


function lines = methodCheckBlock(methodName, stage, funcsDef, legacyAlias)
% METHODCHECKBLOCK Generate an if-block that creates a method when missing.
%   Checks both clean name and legacy alias. Sets a variable (rawMethodName
%   or oxyMethodName) to whichever name actually exists.

    lines = {};
    lines{end+1} = 'global PF2';
    lines{end+1} = 'if isempty(PF2), pf2_base.pf2_initialize(); end';

    if strcmpi(stage, 'raw')
        varName = 'rawMethodName';
        sectionsExpr = 'PF2.myRawMethods.cfg.Sections';
    else
        varName = 'oxyMethodName';
        sectionsExpr = 'PF2.myOxyMethods.cfg.Sections';
    end

    hasLegacy = ~isempty(legacyAlias);

    lines{end+1} = sprintf('if ismember(''%s'', %s)', methodName, sectionsExpr);
    lines{end+1} = sprintf('    %s = ''%s'';', varName, methodName);
    if hasLegacy
        lines{end+1} = sprintf('elseif ismember(''%s'', %s)', legacyAlias, sectionsExpr);
        lines{end+1} = sprintf('    %s = ''%s'';', varName, legacyAlias);
    end
    lines{end+1} = 'else';
    lines{end+1} = sprintf('    fprintf(''Creating %s method: %s\\n'');', stage, methodName);
    lines{end+1} = sprintf('    pf2.methods.%s.create(''%s'', { ...', stage, methodName);

    for k = 1:numel(funcsDef)
        fd = funcsDef{k};
        argsStr = cellToStr(fd.args);
        argvalsStr = cellToStr(fd.argvals);
        if k < numel(funcsDef)
            trail = '}, ...';
        else
            trail = '}';
        end
        lines{end+1} = sprintf('        struct(''f'', ''%s'', ''args'', {{%s}}, ''argvals'', {{%s}}, ''output'', ''%s'')%s', ...
            fd.f, argsStr, argvalsStr, fd.output, trail); %#ok<AGROW>
    end
    lines{end+1} = '    });';
    lines{end+1} = sprintf('    %s = ''%s'';', varName, methodName);
    lines{end+1} = 'end';
end


function s = cellToStr(c)
% CELLTOSTR Format a cell array as MATLAB source: 'a', 'b', 3, 0.1
    parts = cell(1, numel(c));
    for ci = 1:numel(c)
        v = c{ci};
        if ischar(v) || isstring(v)
            parts{ci} = ['''' char(v) ''''];
        elseif isnumeric(v) && isscalar(v)
            parts{ci} = num2str(v, '%.6g');
        else
            parts{ci} = mat2str(v);
        end
    end
    s = strjoin(parts, ', ');
end


function m = getKnownRawMethods()
% GETKNOWNRAWMETHODS Return a map of raw method name -> struct with funcs and legacy alias.
%   argvals: string values ('x','fs') are resolved by the pipeline engine
%   to the data matrix and sampling rate. Numeric values are passed literally.
    m = containers.Map();

    % tddr: Temporal Derivative Distribution Repair
    m('tddr') = struct('funcs', {{ ...
        struct('f','pf2_MotionCorrectTDDR', 'args',{{'x','fs'}}, ...
               'argvals',{{'x','fs'}}, 'output','x') ...
    }}, 'legacy', 'x5_TDDR');

    % lpf: Low-pass filter only (FIR1, 0.1 Hz cutoff)
    m('lpf') = struct('funcs', {{ ...
        struct('f','pf2_lpf', 'args',{{'x','filtType','fs','freq_cut','Nf'}}, ...
               'argvals',{{'x',1,'fs',0.1,50}}, 'output','x') ...
    }}, 'legacy', 'x1_lpf');

    % lpf_smar: Low-pass filter + SMAR motion correction
    m('lpf_smar') = struct('funcs', {{ ...
        struct('f','pf2_lpf', 'args',{{'x','filtType','fs','freq_cut','Nf'}}, ...
               'argvals',{{'x',1,'fs',0.1,50}}, 'output','x'), ...
        struct('f','pf2_SMAR', 'args',{{'x','N','tauUp','tauLow'}}, ...
               'argvals',{{'x',10,0.025,-1}}, 'output','x') ...
    }}, 'legacy', 'x2_lpf_smar');

    % bpf: Band-pass filter (Butterworth, 0.008-0.1 Hz)
    m('bpf') = struct('funcs', {{ ...
        struct('f','pf2_bpf_butter', 'args',{{'x','filtOrder','fs','lowF','highF','restoreMean'}}, ...
               'argvals',{{'x',3,'fs',0.008,0.1,0}}, 'output','x') ...
    }}, 'legacy', 'x3_bpf');
end


function m = getKnownOxyMethods()
% GETKNOWNOXYMETHODS Return a map of oxy method name -> struct with funcs and legacy alias.
    m = containers.Map();

    % takizawa_easy: Lenient artifact rejection (strictCriteria=0)
    m('takizawa_easy') = struct('funcs', {{ ...
        struct('f','pf2_TakizawaRejection', 'args',{{'fNIRstruct','strictCriteria'}}, ...
               'argvals',{{'fNIRstruct',0}}, 'output','fchMask') ...
    }}, 'legacy', '');

    % takizawa_hard: Strict artifact rejection (strictCriteria=1)
    m('takizawa_hard') = struct('funcs', {{ ...
        struct('f','pf2_TakizawaRejection', 'args',{{'fNIRstruct','strictCriteria'}}, ...
               'argvals',{{'fNIRstruct',1}}, 'output','fchMask') ...
    }}, 'legacy', '');
end


function codeLines = buildDefineBlocksCode(cfg)
% BUILDDEFINEBLOCKSCODE Generate defineBlocks code from conditions.

    codeLines = {};
    conditions = cfg.conditions;

    % Determine if all conditions use fixed duration or end markers
    allFixedDur = all(arrayfun(@(c) ~isempty(c.duration) && isempty(c.endCode), conditions));
    allEndMarker = all(arrayfun(@(c) ~isempty(c.endCode) && isempty(c.duration), conditions));

    % Collect start codes
    startCodes = arrayfun(@(c) c.startCode, conditions);

    % Build ConditionMap
    labelFields = conditions(1).labelFields;
    if isempty(labelFields)
        labelFields = {'Condition'};
    end

    codeLines{end+1} = '% Condition map: {markerCode, label; ...}';
    codeLines{end+1} = 'conditionMap = { ...';
    for k = 1:numel(conditions)
        c = conditions(k);
        parts = sprintf('%g', c.startCode);
        for lk = 1:numel(c.labels)
            parts = sprintf('%s, %s', parts, escapeStr(c.labels{lk}));
        end
        if k < numel(conditions)
            codeLines{end+1} = sprintf('    %s; ...', parts);
        else
            codeLines{end+1} = sprintf('    %s ...', parts);
        end
    end
    codeLines{end+1} = '};';
    codeLines{end+1} = '';

    % Build ConditionField string
    if numel(labelFields) == 1
        condFieldStr = escapeStr(labelFields{1});
    else
        condFieldStr = '{';
        for k = 1:numel(labelFields)
            if k > 1
                condFieldStr = [condFieldStr, ', ']; %#ok<AGROW>
            end
            condFieldStr = [condFieldStr, escapeStr(labelFields{k})]; %#ok<AGROW>
        end
        condFieldStr = [condFieldStr, '}'];
    end

    % Start codes vector
    codeStr = sprintf('[%s]', strjoin(arrayfun(@(x) sprintf('%g', x), startCodes, 'UniformOutput', false), ', '));

    if allFixedDur
        % All fixed duration -- check if they're all the same
        durations = arrayfun(@(c) c.duration, conditions);
        if all(durations == durations(1))
            codeLines{end+1} = sprintf('blockDuration = %g;  %% seconds', durations(1));
            codeLines{end+1} = '';
            codeLines{end+1} = 'blocks = pf2.data.defineBlocks(allProcessed{1}, ...';
            codeLines{end+1} = sprintf('    ''MarkerCode'', %s, ...', codeStr);
            codeLines{end+1} = '    ''Duration'', blockDuration, ...';
        else
            % Mixed durations: need per-condition loops
            codeLines{end+1} = '% Note: conditions have different durations. Using a loop.';
            codeLines{end+1} = 'blocks = [];';
            for k = 1:numel(conditions)
                c = conditions(k);
                codeLines{end+1} = sprintf('b%d = pf2.data.defineBlocks(allProcessed{1}, ...', k);
                codeLines{end+1} = sprintf('    ''MarkerCode'', %g, ''Duration'', %g, ...', c.startCode, c.duration);
                codeLines{end+1} = sprintf('    ''ConditionMap'', conditionMap(%d,:), ''ConditionField'', %s, ...', k, condFieldStr);
                codeLines{end+1} = '    ''Embed'', false);';
                codeLines{end+1} = sprintf('blocks = [blocks, b%d];', k);
            end
            codeLines{end+1} = '% Sort by time';
            codeLines{end+1} = '[~, idx] = sort([blocks.startTime]);';
            codeLines{end+1} = 'blocks = blocks(idx);';
            return;
        end
    elseif allEndMarker
        endCodes = arrayfun(@(c) c.endCode, conditions);
        endStr = sprintf('[%s]', strjoin(arrayfun(@(x) sprintf('%g', x), endCodes, 'UniformOutput', false), ', '));

        codeLines{end+1} = 'blocks = pf2.data.defineBlocks(allProcessed{1}, ...';
        codeLines{end+1} = sprintf('    ''MarkerCode'', %s, ...', codeStr);
        codeLines{end+1} = sprintf('    ''EndMarker'', %s, ...', endStr);
    else
        % Mixed: some have duration, some have end codes. Use per-condition loop.
        codeLines{end+1} = '% Note: conditions use a mix of durations and end markers. Using a loop.';
        codeLines{end+1} = 'blocks = [];';
        for k = 1:numel(conditions)
            c = conditions(k);
            codeLines{end+1} = sprintf('b%d = pf2.data.defineBlocks(allProcessed{1}, ...', k);
            codeLines{end+1} = sprintf('    ''MarkerCode'', %g, ...', c.startCode);
            if ~isempty(c.duration)
                codeLines{end+1} = sprintf('    ''Duration'', %g, ...', c.duration);
            else
                codeLines{end+1} = sprintf('    ''EndMarker'', %g, ...', c.endCode);
            end
            codeLines{end+1} = sprintf('    ''ConditionMap'', conditionMap(%d,:), ''ConditionField'', %s, ...', k, condFieldStr);
            codeLines{end+1} = '    ''Embed'', false);';
            codeLines{end+1} = sprintf('blocks = [blocks, b%d];', k);
        end
        codeLines{end+1} = '[~, idx] = sort([blocks.startTime]);';
        codeLines{end+1} = 'blocks = blocks(idx);';
        return;
    end

    % Common tail for simple cases
    codeLines{end+1} = sprintf('    ''ConditionMap'', conditionMap, ''ConditionField'', %s, ...', condFieldStr);
    codeLines{end+1} = '    ''Embed'', false);';
    codeLines{end+1} = '';
    codeLines{end+1} = 'fprintf(''Defined %d blocks.\n'', numel(blocks));';
end


function codeLines = buildBlockInfoCode(cfg)
% BUILDBLOCKINFOCODE Generate the IMPORT BLOCK DATA section.
%   Builds a pf2.data.importBlockInfo call with the user's file path and keys.
%   Includes an if-~isfile guard that auto-creates a pre-populated template.

    codeLines = {};
    codeLines{end+1} = sprintf('behavPath = %s;', escapeStr(cfg.blockInfoPath));
    codeLines{end+1} = '';

    % Build 'Keys' argument
    if numel(cfg.blockInfoKeys) == 1
        keysStr = escapeStr(cfg.blockInfoKeys{1});
    else
        parts = cellfun(@(s) escapeStr(s), cfg.blockInfoKeys, 'UniformOutput', false);
        keysStr = ['{' strjoin(parts, ', ') '}'];
    end

    % Auto-create template if file does not exist
    codeLines{end+1} = 'if ~isfile(behavPath)';
    codeLines{end+1} = '    % Build a pre-populated template with one row per block per subject.';
    codeLines{end+1} = '    % Key columns are filled from block .info and subject .info fields.';
    codeLines{end+1} = '    rows = {};';
    codeLines{end+1} = '    for i = 1:numel(allProcessed)';
    codeLines{end+1} = '        for b = 1:numel(blocks)';
    codeLines{end+1} = '            row = blocks(b).info;';
    codeLines{end+1} = '            fns = fieldnames(allProcessed{i}.info);';
    codeLines{end+1} = '            for f = 1:numel(fns)';
    codeLines{end+1} = '                if ~isfield(row, fns{f})';
    codeLines{end+1} = '                    row.(fns{f}) = allProcessed{i}.info.(fns{f});';
    codeLines{end+1} = '                end';
    codeLines{end+1} = '            end';
    codeLines{end+1} = '            rows{end+1} = row; %#ok<AGROW>';
    codeLines{end+1} = '        end';
    codeLines{end+1} = '    end';
    codeLines{end+1} = '    T = struct2table([rows{:}]);';
    codeLines{end+1} = '    writetable(T, behavPath);';
    codeLines{end+1} = '    fprintf(''Created behavioral data template: %s (%d rows)\n'', behavPath, height(T));';
    codeLines{end+1} = '    fprintf(''Add data columns (e.g. Accuracy, RT), then re-run this script.\n'');';
    codeLines{end+1} = '    return;';
    codeLines{end+1} = 'end';
    codeLines{end+1} = '';

    codeLines{end+1} = sprintf('blocks = pf2.data.importBlockInfo(blocks, behavPath, ...');
    codeLines{end+1} = sprintf('    ''Keys'', %s);', keysStr);
    codeLines{end+1} = 'fprintf(''Imported behavioral data into %d blocks.\n'', numel(blocks));';
end


function codeLines = buildGroupAnalysisCode(cfg)
% BUILDGROUPANALYSISCODE Generate Experiment, groupby, aggregate, plot, stats code.

    codeLines = {};

    % Experiment constructor
    codeLines{end+1} = 'ex = exploreFNIRS.core.Experiment(allSegments);';
    codeLines{end+1} = '';

    % Settings
    codeLines{end+1} = '% Configure analysis settings';
    codeLines{end+1} = sprintf('ex.settings.baseline = [-%g, 0];', cfg.baselineLength);
    codeLines{end+1} = 'ex.settings.taskStart = 0;';
    codeLines{end+1} = 'ex.settings.resampleRate = 1;       % 1 Hz for temporal plots';
    codeLines{end+1} = 'ex.settings.barBinSize = 15;        % seconds per bar-chart bin';
    codeLines{end+1} = 'ex.settings.useBaseline = true;';
    codeLines{end+1} = 'ex.settings.avgMode = ''hierarchy'';';
    codeLines{end+1} = '';

    % Determine task end from conditions
    durations = arrayfun(@(c) c.duration, cfg.conditions, 'UniformOutput', false);
    hasDurs = ~cellfun('isempty', durations);
    if any(hasDurs)
        maxDur = max([durations{hasDurs}]);
        codeLines{end+1} = sprintf('ex.settings.taskEnd = %g;', maxDur);
    else
        codeLines{end+1} = '% ex.settings.taskEnd = 30;  % Adjust to your block duration';
    end
    codeLines{end+1} = '';

    % Build groupby vars: Condition is always present, add Group if dir-mapped
    gbyVars = {};
    validMappings = cfg.dirMappings(~cellfun('isempty', cfg.dirMappings));
    if any(strcmpi(validMappings, 'Group'))
        gbyVars{end+1} = 'Group';
    end
    % Add first condition label field
    if ~isempty(cfg.conditions) && ~isempty(cfg.conditions(1).labelFields)
        condField = cfg.conditions(1).labelFields{1};
        if ~any(strcmpi(gbyVars, condField))
            gbyVars{end+1} = condField;
        end
    else
        gbyVars{end+1} = 'Condition';
    end

    gbyStr = strjoin(cellfun(@(s) ['''' s ''''], gbyVars, 'UniformOutput', false), ', ');

    % Condition labels for select
    condLabels = {};
    for k = 1:numel(cfg.conditions)
        if ~isempty(cfg.conditions(k).labels)
            condLabels{end+1} = cfg.conditions(k).labels{1}; %#ok<AGROW>
        end
    end
    condField = 'Condition';
    if ~isempty(cfg.conditions) && ~isempty(cfg.conditions(1).labelFields)
        condField = cfg.conditions(1).labelFields{1};
    end

    if ~isempty(condLabels)
        selectStr = strjoin(cellfun(@(s) ['''' s ''''], condLabels, 'UniformOutput', false), ', ');
        codeLines{end+1} = sprintf('ex.select(''%s'', {%s});', condField, selectStr);
    end
    codeLines{end+1} = sprintf('ex.groupby({%s});', gbyStr);
    codeLines{end+1} = 'ex.aggregate();';
    codeLines{end+1} = '';
    codeLines{end+1} = 'ex.summary();';
    codeLines{end+1} = '';

    % Temporal plot
    codeLines{end+1} = '% --- Temporal plot ---';
    codeLines{end+1} = 'fig = ex.plotTemporal(''Biomarkers'', {''HbO'', ''HbR''}, ...';
    codeLines{end+1} = sprintf('    ''PlotBy'', ''%s'', ...', condField);
    codeLines{end+1} = '    ''Title'', ''Group Average Temporal Response'');';
    codeLines{end+1} = '';

    % Bar chart
    codeLines{end+1} = '% --- Bar chart ---';
    codeLines{end+1} = 'fig = ex.plotBar(''Biomarker'', ''HbO'', ...';
    codeLines{end+1} = sprintf('    ''PlotBy'', ''%s'', ''ShowIndividual'', true, ...', condField);
    codeLines{end+1} = '    ''Title'', ''Mean HbO by Condition'');';
    codeLines{end+1} = '';

    % LME statistics
    codeLines{end+1} = '% --- LME statistics ---';
    codeLines{end+1} = 'results = ex.statsFitLME(''Biomarkers'', {''HbO''});';
    codeLines{end+1} = 'fprintf(''LME formula: %s\n'', results.formula);';
    codeLines{end+1} = '';
    codeLines{end+1} = 'T_anova = ex.statsSummarize(results, ''Type'', ''anova'');';
    codeLines{end+1} = 'disp(T_anova);';
end


function codeLines = buildExportCode(cfg, hasConditions)
% BUILDEXPORTCODE Generate export section code.

    codeLines = {};

    % Tabular export if we have conditions
    if hasConditions
        codeLines{end+1} = '% --- Tabular export (for R, Python, SPSS) ---';
        codeLines{end+1} = 'longT = ex.toLongTable({''HbO'', ''HbR''}, 1:size(allSegments{1}.HbO, 2));';
        codeLines{end+1} = 'writetable(longT, ''results_long.csv'');';
        codeLines{end+1} = 'fprintf(''Exported %d rows to results_long.csv\n'', height(longT));';
        codeLines{end+1} = '';
    end

    % File export
    if strcmpi(cfg.exportFormat, 'SNIRF')
        exportFn = 'pf2.export.asSNIRF';
        ext = 'snirf';
    elseif strcmpi(cfg.exportFormat, 'NIR')
        exportFn = 'pf2.export.asNIR';
        ext = 'nir';
    else
        return;
    end

    codeLines{end+1} = sprintf('% --- Batch export processed data as %s ---', upper(ext));
    codeLines{end+1} = sprintf('outDir = fullfile(pwd, ''processed_%s'');', ext);

    % Build export call with dir mappings
    exportCall = sprintf('%s(allProcessed, outDir', exportFn);
    validMappings = cfg.dirMappings(~cellfun('isempty', cfg.dirMappings));
    for k = 1:min(numel(validMappings), 4)
        exportCall = sprintf('%s, ...\n    ''Dir%d'', %s', exportCall, k, escapeStr(validMappings{k}));
    end
    exportCall = [exportCall, ');'];
    codeLines{end+1} = exportCall;
    codeLines{end+1} = 'fprintf(''Exported %d files to %s\n'', numel(allProcessed), outDir);';
end


% =========================================================================
%  PROMPT HELPERS
% =========================================================================

function idx = promptMenu(msg, options, defaultIdx)
% PROMPTMENU Display a numbered menu and return the selected index.
%   Retries up to 3 times on invalid input, then uses default.

    fprintf('  %s\n', msg);
    for k = 1:numel(options)
        if k == defaultIdx
            fprintf('    %d. %s  [default]\n', k, options{k});
        else
            fprintf('    %d. %s\n', k, options{k});
        end
    end

    for attempt = 1:3
        raw = input(sprintf('  Choice [%d]: ', defaultIdx), 's');
        raw = strtrim(raw);
        if isempty(raw)
            idx = defaultIdx;
            return;
        end
        val = str2double(raw);
        if ~isnan(val) && val >= 1 && val <= numel(options) && val == round(val)
            idx = val;
            return;
        end
        fprintf('  Invalid choice. Enter a number 1-%d.\n', numel(options));
    end
    fprintf('  Using default: %d\n', defaultIdx);
    idx = defaultIdx;
end


function result = promptText(msg, default)
% PROMPTTEXT Prompt for a text string with optional default.

    if nargin < 2 || isempty(default)
        raw = input(sprintf('  %s: ', msg), 's');
        result = strtrim(raw);
    else
        raw = input(sprintf('  %s [%s]: ', msg, default), 's');
        raw = strtrim(raw);
        if isempty(raw)
            result = default;
        else
            result = raw;
        end
    end
end


function result = promptNumber(msg, default)
% PROMPTNUMBER Prompt for a numeric value with validation.

    for attempt = 1:3
        if nargin >= 2 && ~isempty(default)
            raw = input(sprintf('  %s [%g]: ', msg, default), 's');
            raw = strtrim(raw);
            if isempty(raw)
                result = default;
                return;
            end
        else
            raw = input(sprintf('  %s: ', msg), 's');
            raw = strtrim(raw);
        end

        val = str2double(raw);
        if ~isnan(val) && isfinite(val)
            result = val;
            return;
        end
        fprintf('  Invalid number. Try again.\n');
    end

    if nargin >= 2 && ~isempty(default)
        fprintf('  Using default: %g\n', default);
        result = default;
    else
        error('pf2_scripts:quickSetup:invalidInput', 'Failed to get valid number for: %s', msg);
    end
end


% =========================================================================
%  FILE SYSTEM HELPERS
% =========================================================================

function createTemplateFile(filepath, columns)
% CREATETEMPLATEFILE Write an empty file with the given column headers.
%   Format (CSV or Excel) is auto-detected from the file extension.

    T = cell2table(cell(0, numel(columns)), 'VariableNames', columns);
    writetable(T, filepath);
    fprintf('  Created template: %s\n', filepath);
    fprintf('  Columns: %s\n', strjoin(columns, ', '));
end


function matches = scanFiles(dataDir, pattern)
% SCANFILES Recursively find files matching a glob pattern.

    matches = []; % Initialize the main window so that it can run with differing MATLAB versions without error
    stack = {dataDir};
    while ~isempty(stack)
        current = stack{end};
        stack(end) = [];
        found = dir(fullfile(current, pattern));
        found = found(~[found.isdir]);
        if ~isempty(found)
            matches = [matches; found]; %#ok<AGROW>
        end
        entries = dir(current);
        for k = 1:numel(entries)
            if entries(k).isdir && entries(k).name(1) ~= '.'
                stack{end+1} = fullfile(current, entries(k).name); %#ok<AGROW>
            end
        end
    end
end


function levels = analyzeDirectoryLevels(files, rootPath)
% ANALYZEDIRECTORYLEVELS Extract unique directory names at each depth level.

    % Make both rootPath and file folders absolute so strrep always matches.
    % Use MATLAB's pwd (not Java's working dir, which can diverge from pwd).
    if ~java.io.File(rootPath).isAbsolute()
        rootPath = fullfile(pwd, rootPath);
    end

    allParts = {};
    for k = 1:numel(files)
        folder = files(k).folder;
        if ~java.io.File(folder).isAbsolute()
            folder = fullfile(pwd, folder);
        end
        rel = strrep(folder, [rootPath filesep], '');
        if strcmp(rel, folder) || isempty(rel)
            continue;
        end
        parts = strsplit(rel, filesep);
        parts = parts(~cellfun('isempty', parts));
        allParts{end+1} = parts; %#ok<AGROW>
    end

    if isempty(allParts)
        levels = {};
        return;
    end

    maxDepth = max(cellfun(@numel, allParts));
    levels = cell(1, maxDepth);
    for d = 1:maxDepth
        vals = {};
        for k = 1:numel(allParts)
            if numel(allParts{k}) >= d
                vals{end+1} = allParts{k}{d}; %#ok<AGROW>
            end
        end
        levels{d} = unique(vals);
    end
end


% =========================================================================
%  CODE GENERATION HELPERS
% =========================================================================

function writeSection(fid, partNum, title, comment, codeLines)
% WRITESECTION Write a formatted %% section to the script file.

    if partNum == 0
        % Header section
        fprintf(fid, '%%%% %s\n', title);
        fprintf(fid, '%%  %s\n', comment);
        fprintf(fid, '\n');
        return;
    end

    fprintf(fid, '\n');
    fprintf(fid, '%%%% ========================================================================\n');
    fprintf(fid, '%%  PART %d: %s\n', partNum, upper(title));
    fprintf(fid, '%%  ========================================================================\n');

    % Write comment lines
    commentLines = strsplit(comment, '\n');
    for k = 1:numel(commentLines)
        fprintf(fid, '%%  %s\n', commentLines{k});
    end
    fprintf(fid, '\n');

    fprintf(fid, 'fprintf(''=== Part %d: %s ===\\n'');\n', partNum, title);
    fprintf(fid, '\n');

    for k = 1:numel(codeLines)
        fprintf(fid, '%s\n', codeLines{k});
    end
    fprintf(fid, '\n');
end


function s = escapeStr(str)
% ESCAPESTR Wrap a string in single quotes, escaping internal quotes.

    str = char(str);
    str = strrep(str, '''', '''''');
    s = ['''' str ''''];
end
