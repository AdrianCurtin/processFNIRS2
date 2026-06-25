function data = fromTable(T, varargin)
% FROMTABLE Build fNIRS-shaped segment structs from a long-format data table
%
% Adapts a plain long-format (tidy) table of repeated-measures data into the
% cell array of segment structs that the rest of the toolbox consumes, so the
% Experiment class, trajectory/bar plotting, and the LME engine can be used on
% data that did not come from an fNIRS device (survey waves, longitudinal test
% scores, daily diary measures, any subject x time x measure design).
%
% Each subject (the 'Subject' column) becomes one segment. The repeated
% measure ('Time' column) becomes the segment time axis, and each measured
% outcome ('Value' column) becomes a pseudo-channel. The value is copied into
% all five hemoglobin biomarker fields (HbO/HbR/HbTotal/HbDiff/CBSI) because
% the group-averaging and splitting routines expect them to exist. Those five
% fields are therefore IDENTICAL copies: analyze a single biomarker ('HbO').
% Requesting several (e.g. statsAutoLME's default {'HbO','HbR','HbTotal','CBSI'})
% just re-runs the same data and inflates any multiple-comparison correction,
% and multivariate methods over the five columns are meaningless. Remaining
% columns that are constant within a subject are carried into .info so they are
% available as grouping factors / covariates.
%
% No device, probe geometry, wavelengths, or markers are required. Spatial
% visualizations (topo, project.*, 3D renders) need real optode coordinates
% and are therefore not available for tables built this way; the temporal /
% bar / scatter plots and the LME stats are.
%
% All subjects share one canonical time grid (the sorted unique levels of the
% Time column across the whole table), so group averaging never sees the
% "shared sampling rate but not a common time grid" NaN explosion. Missing
% subject x time cells are NaN-filled.
%
% Reference:
%   Internal pf2 adapter (no published algorithm). Companion to the naive-data
%   onboarding path; see also pf2.import.importInfo / pf2.data.infoFromTable.
%
% Syntax:
%   data = pf2.import.fromTable(T, 'Subject','SubjectID', 'Time','Week', 'Value','Score')
%   data = pf2.import.fromTable(T, 'Subject','id', 'Time','wave', ...
%              'Value',{'wellbeing','stress'}, 'Info',{'condition','age'})
%   data = pf2.import.fromTable(T, 'Subject','id', 'Value','score')   % cross-sectional
%
% Inputs:
%   T - Long-format table (or anything readtable returns), one row per
%       Subject x Time observation. Use readtable(file) first for CSV/Excel.
%
% Name-Value Parameters:
%   'Subject'   - (required) Column name identifying the unit of repeated
%                 measurement. Stored as info.SubjectID (and under its own
%                 name too, if different) so the Experiment hierarchy works.
%   'Value'     - (required) Column name, or cell array of column names, of
%                 the measured outcome(s). Each becomes a pseudo-channel.
%   'Time'      - Column name for the repeated-measures axis (e.g. wave, week,
%                 day, session). Omit for cross-sectional data (one row per
%                 subject) -> a single timepoint.
%   'Info'      - Cell array of column names to carry into .info as
%                 grouping factors / covariates. Default: every column that is
%                 neither Subject/Time/Value and is constant within subject.
%   'TimeMode'  - 'index' (default) maps the sorted unique levels to 1..K so
%                 the grid is uniform and group averaging never NaN-fills
%                 intermediate points; 'value' uses the real Time values as
%                 .time (honest spacing, but non-uniform levels such as weeks
%                 [1 6 12] get resampled onto a dense grid by grand averaging,
%                 producing mostly-NaN averages). The real levels are always
%                 kept in seg.timeLevels regardless of mode. NOTE: under 'index'
%                 a fitted time slope/growth-curve coefficient is "change per
%                 measurement occasion", NOT per real time unit (per week/day);
%                 use 'value' when the slope must carry real-time units.
%   'Units'     - Units string for the measured value (default: the Value
%                 column name, or 'value' for multiple values).
%   'SubjectField' - Info field name for the subject id (default 'SubjectID').
%   'Duplicates'   - How to combine multiple rows that map to the same
%                    Subject x Time x Value cell: 'mean' (default), 'first',
%                    or 'error'. For longitudinal data where each Subject x Time
%                    cell should be unique, 'error' surfaces unexpected
%                    duplicates (likely join/data-entry issues) instead of
%                    silently averaging them.
%
% Outputs:
%   data - 1 x nSubjects cell array of segment structs, each with:
%            .HbO/.HbR/.HbTotal/.HbDiff/.CBSI - [K x nValue] (value copied into
%                                               every biomarker field)
%            .time       - [K x 1] canonical time grid
%            .timeLevels - [K x 1] real Time values (== .time unless 'index')
%            .fs         - sampling rate (1/median spacing, or 1)
%            .units      - units string
%            .fchMask    - true(1, nValue)
%            .valueNames - the Value column names (channel labels)
%            .info       - SubjectID + carried factor/covariate fields
%
% Algorithm:
%   1. Validate the Subject/Value/Time columns exist in T.
%   2. Build the canonical time grid from the sorted unique Time levels across
%      all rows (a single shared grid; index or real values per TimeMode).
%   3. Auto-select info columns (constant-within-subject) unless given.
%   4. For each subject: place each value column onto the grid (NaN-filling
%      missing levels, combining duplicates per 'Duplicates'), copy into the
%      five biomarker fields, and pack the constant info fields.
%   5. Warn on non-uniform spacing (value mode), within-subject-varying info
%      columns, missing levels, and combined duplicates.
%
% Example:
%   % Longitudinal student scores -> Experiment + trajectory plot + LME
%   T = readtable('student_scores.csv');
%   data = pf2.import.fromTable(T, 'Subject','StudentID', 'Time','Week', ...
%              'Value','Score', 'Info',{'Class','Intervention'});
%   ex = exploreFNIRS.core.Experiment(data);
%   ex.settings.useBaseline = false;   % no pre-stimulus baseline to subtract
%   ex.settings.resampleRate = 0;      % keep the native grid
%   ex.groupby({'Intervention'});
%   ex.aggregate();
%   ex.plotTemporal('Biomarkers', {'HbO'});   % score trajectories by group
%   % LME. With the default barBinSize=0 each subject collapses to one bar, so
%   % statsFitLME fits the time-AVERAGED model  score ~ Intervention + (1|Subject).
%   res = ex.statsFitLME('Biomarkers', {'HbO'}, 'Channels', 1);
%   % For a time-RESOLVED  score ~ time*group  model, keep each timepoint as an
%   % observation, then re-aggregate and fit:
%   ex.settings.barBinSize = 1;
%   ex.settings.taskEnd = numel(data{1}.time);   % number of time levels (K)
%   ex.aggregate();
%   res = ex.statsFitLME('Biomarkers', {'HbO'}, 'Channels', 1);  % ~ Intervention*ot1
%
% See also: pf2.import.importInfo, pf2.data.infoFromTable,
%           exploreFNIRS.core.Experiment, pf2.import.sampleData.experiment

% ----------------------------- parse inputs -----------------------------
if ~istable(T)
    error('pf2:fromTable:notTable', ...
        'T must be a table. Use readtable(file) to load a CSV/Excel file first.');
end

p = inputParser;
p.FunctionName = 'pf2.import.fromTable';
addRequired(p, 'T', @istable);
addParameter(p, 'Subject', '', @(x) ischar(x) || isStringScalar(x));
addParameter(p, 'Value', {}, @(x) ischar(x) || isstring(x) || iscell(x));
addParameter(p, 'Time', '', @(x) ischar(x) || isStringScalar(x));
addParameter(p, 'Info', {}, @(x) ischar(x) || isstring(x) || iscell(x));
addParameter(p, 'TimeMode', 'index', @(x) any(strcmpi(x, {'value','index'})));
addParameter(p, 'Units', '', @(x) ischar(x) || isStringScalar(x));
addParameter(p, 'SubjectField', 'SubjectID', @(x) ischar(x) || isStringScalar(x));
addParameter(p, 'Duplicates', 'mean', @(x) any(strcmpi(x, {'mean','first','error'})));
parse(p, T, varargin{:});

subjectCol   = char(p.Results.Subject);
timeCol      = char(p.Results.Time);
valueCols    = cellstr(p.Results.Value);
infoCols     = cellstr(p.Results.Info);
timeMode     = lower(p.Results.TimeMode);
subjectField = char(p.Results.SubjectField);
dupRule      = lower(p.Results.Duplicates);
vars         = T.Properties.VariableNames;

if isempty(subjectCol)
    error('pf2:fromTable:noSubject', ...
        '''Subject'' is required: the column naming the repeated-measures unit.');
end
if isempty(valueCols) || all(cellfun(@isempty, valueCols))
    error('pf2:fromTable:noValue', ...
        '''Value'' is required: the column(s) holding the measured outcome.');
end
assertColumn(subjectCol, vars, 'Subject');
for k = 1:numel(valueCols)
    assertColumn(valueCols{k}, vars, 'Value');
    if ~isnumeric(T.(valueCols{k}))
        error('pf2:fromTable:valueNotNumeric', ...
            'Value column ''%s'' must be numeric.', valueCols{k});
    end
end
hasTime = ~isempty(timeCol);
if hasTime
    assertColumn(timeCol, vars, 'Time');
end

% ------------------------- canonical time grid --------------------------
if hasTime
    timeLevels = unique(T.(timeCol));        % sorted unique levels (shared grid)
    timeLevels = timeLevels(:);
    if ~isnumeric(timeLevels)
        % Non-numeric time (categorical/string waves): order of appearance.
        [~, ia] = unique(T.(timeCol), 'stable');
        timeLevels = T.(timeCol)(sort(ia));
    end
else
    timeLevels = 1;                          % cross-sectional: single timepoint
end
K = numel(timeLevels);

% Time axis the segments actually carry
if strcmp(timeMode, 'index') || ~isnumeric(timeLevels)
    timeAxis = (1:K)';
else
    timeAxis = double(timeLevels);
    if K > 2 && strcmp(timeMode, 'value')
        d = diff(timeAxis);
        if max(abs(d - d(1))) > 1e-9 * max(1, abs(d(1)))
            warning('pf2:fromTable:nonUniformTime', ...
                ['Time levels are non-uniformly spaced ([%s]). Group averaging ', ...
                 'keeps the real spacing, but if you resample set ', ...
                 'ex.settings.resampleRate = 0, or pass ''TimeMode'',''index''.'], ...
                num2str(timeAxis'));
        end
    end
end

% sampling rate from the carried axis
if K > 1
    dt = median(diff(timeAxis));
    if dt <= 0, dt = 1; end
    fs = 1 / dt;
else
    fs = 1;
end

% units / channel labels
nCh = numel(valueCols);
if ~isempty(char(p.Results.Units))
    units = char(p.Results.Units);
elseif nCh == 1
    units = valueCols{1};
else
    units = 'value';
end

% ------------------------- info column selection ------------------------
reserved = [{subjectCol}, valueCols];
if hasTime, reserved = [reserved, {timeCol}]; end
if isempty(infoCols) || all(cellfun(@isempty, infoCols))
    infoCols = setdiff(vars, reserved, 'stable');
else
    for k = 1:numel(infoCols)
        assertColumn(infoCols{k}, vars, 'Info');
    end
end

% ------------------------------ build segments --------------------------
subjCol = T.(subjectCol);
[subjKeys, ~, subjIdx] = uniqueStable(subjCol);
nSub = numel(subjKeys);
data = cell(1, nSub);

variedInfo = {};         % info cols that varied within a subject (warn once)
combinedAny = false;     % any duplicate cells combined
missingLevelAny = false; % any subject missing a whole time level (not just NaN data)

for s = 1:nSub
    rows = find(subjIdx == s);
    sub = T(rows, :);

    % ---- value matrix [K x nCh] on the canonical grid ----
    M = nan(K, nCh);
    if hasTime
        [tf, loc] = ismemberLevels(sub.(timeCol), timeLevels);
        seen = false(K, 1);   % which levels this subject contributes a row to
        for c = 1:nCh
            col = sub.(valueCols{c});
            ssum = zeros(K, 1);   % sum of non-NaN values per cell (for 'mean')
            ncnt = zeros(K, 1);   % count of non-NaN values per cell (for 'mean')
            cellSeen = false(K, 1);
            for r = 1:numel(loc)
                if ~tf(r), continue; end
                kk = loc(r);
                v = col(r);
                if cellSeen(kk)
                    % duplicate (subject,time) cell
                    combinedAny = true;
                    if strcmp(dupRule, 'error')
                        error('pf2:fromTable:duplicate', ...
                            ['Subject ''%s'' has multiple rows at the same ', ...
                             'Time level for ''%s''. Set ''Duplicates'' to ', ...
                             '''mean'' or ''first''.'], asText(subjKeys(s)), valueCols{c});
                    end
                end
                switch dupRule
                    case 'first'
                        if ~cellSeen(kk), M(kk, c) = v; end
                    otherwise   % 'mean' (and the no-duplicate 'error' case)
                        if ~isnan(v)
                            ssum(kk) = ssum(kk) + v;
                            ncnt(kk) = ncnt(kk) + 1;
                        end
                end
                cellSeen(kk) = true;
            end
            if ~strcmp(dupRule, 'first')
                m = ssum ./ ncnt;            % true mean of all values; NaN where ncnt==0
                M(:, c) = m;
            end
            seen = seen | cellSeen;
        end
        if any(~seen), missingLevelAny = true; end   % a level with no row at all
    else
        for c = 1:nCh
            col = sub.(valueCols{c});
            M(1, c) = mean(col, 'omitnan');   % cross-sectional: collapse rows
            if numel(col) > 1, combinedAny = true; end
        end
    end

    % ---- assemble struct ----
    seg = struct();
    seg.HbO     = M;
    seg.HbR     = M;
    seg.HbTotal = M;
    seg.HbDiff  = M;
    seg.CBSI    = M;
    seg.time       = timeAxis;
    seg.timeLevels = timeLevels;
    seg.fs         = fs;
    seg.units      = units;
    seg.fchMask    = true(1, nCh);
    seg.valueNames = valueCols;

    % ---- info ----
    % Carry factor/covariate columns first, then stamp the subject identifier
    % LAST so an Info column that happens to share subjectField's name cannot
    % overwrite the authoritative subject id.
    info = struct();
    for k = 1:numel(infoCols)
        ic = infoCols{k};
        vcol = sub.(ic);
        uv = uniqueStable(vcol);
        if numel(uv) > 1
            variedInfo{end+1} = ic; %#ok<AGROW>
        end
        info.(matlab.lang.makeValidName(ic)) = scalarValue(firstValue(vcol));
    end
    subjValidName = matlab.lang.makeValidName(subjectCol);
    if ~strcmp(subjectField, subjectCol) && ~strcmp(subjValidName, subjectField)
        info.(subjValidName) = scalarValue(subjKeys(s));   % keep under original name too
    end
    info.(subjectField) = scalarValue(subjKeys(s));         % authoritative; stamped last
    seg.info = info;

    data{s} = seg;
end

% ------------------------------ warnings --------------------------------
if ~isempty(variedInfo)
    variedInfo = unique(variedInfo, 'stable');
    warning('pf2:fromTable:variedInfo', ...
        ['These Info column(s) vary within a subject; only the first value per ', ...
         'subject was kept: %s. Info fields are per-segment (subject-constant) ', ...
         'covariates. To use a time-varying predictor in an LME, fit it directly ', ...
         'with fitlme on the original long table (it cannot be threaded through ', ...
         '.info); to visualize it, pass it as an additional ''Value'' channel.'], ...
        strjoin(variedInfo, ', '));
end
if missingLevelAny
    warning('pf2:fromTable:missingLevels', ...
        ['Some subjects have no row at one or more Time levels; those cells were ', ...
         'NaN-filled (group averaging ignores them).']);
end
if combinedAny && strcmp(dupRule, 'mean')
    warning('pf2:fromTable:combinedDuplicates', ...
        'Multiple rows mapped to the same cell were averaged (Duplicates=''mean'').');
end

end

% =========================== local helpers ==============================

function assertColumn(name, vars, role)
% Error if NAME is not a variable of the table.
if ~ismember(name, vars)
    error('pf2:fromTable:missingColumn', ...
        '%s column ''%s'' not found in the table. Available: %s', ...
        role, name, strjoin(vars, ', '));
end
end

function [keys, ia, idx] = uniqueStable(col)
% UNIQUE in order of first appearance, working for numeric/cell/string/categorical.
[keys, ia, idx] = unique(col, 'stable');
end

function [tf, loc] = ismemberLevels(vals, levels)
% ISMEMBER tolerant of numeric/string/categorical level vectors.
[tf, loc] = ismember(vals, levels);
end

function v = firstValue(col)
% First element of a table column, preserving type.
if iscell(col)
    v = col{1};
else
    v = col(1);
end
end

function v = scalarValue(x)
% Coerce a unique-key / cell element to a scalar info value (char for text).
if iscell(x)
    x = x{1};
end
if isstring(x)
    v = char(x);
elseif ischar(x)
    v = x;
elseif iscategorical(x)
    v = char(x);
else
    v = x;
end
end

function s = asText(x)
% Best-effort text rendering of a subject key for messages.
v = scalarValue(x);
if ischar(v)
    s = v;
elseif isnumeric(v)
    s = num2str(v);
else
    s = '?';
end
end
