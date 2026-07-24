function T = glmToTable(glmResults, varargin) %#ok<*AGROW>
% GLMTOTABLE Export GLM first-level results to a flat benchmark-schema table
%
% Converts first-level GLM beta weights and statistics from a fitted
% GLMExperiment (or a pre-built beta table) into a unified, per-subject
% per-channel per-condition flat table. The schema is designed for
% cross-toolbox reproducibility benchmarks (FRESH pipeline), direct export
% to CSV/Excel, and feeding into statistical software (R, Python).
%
% This is a thin wrapper over GLMExperiment.betaTable('IncludeStats', true)
% that (1) standardises column names to lowercase underscore, (2) adds a
% channel_label column consistent with pf2.probe.montage output, and (3)
% optionally writes the result to disk.
%
% Reference:
%   Internal pf2 implementation. Column schema follows the FRESH fNIRS
%   benchmark interoperability convention.
%
% Syntax:
%   T = pf2.export.glmToTable(gx)
%   T = pf2.export.glmToTable(gx, 'SavePath', 'results.csv')
%   T = pf2.export.glmToTable(gx, 'Channels', 1:8)
%   T = pf2.export.glmToTable(gx, 'Biomarkers', {'HbO', 'HbR'})
%
% Inputs:
%   glmResults - A fitted exploreFNIRS.core.GLMExperiment object. Must have
%                had fit() called. Also accepts a pre-built table from
%                GLMExperiment.betaTable('IncludeStats', true) -- the wrapper
%                will normalize column names and return it.
%
% Name-Value Parameters:
%   'Channels'   - Numeric vector of channel indices to include (default: all)
%   'Biomarkers' - Cell array of biomarkers to export, e.g. {'HbO', 'HbR'}
%                  (default: all biomarkers fitted in gx.glm.biomarkers).
%                  Biomarkers not present in the fit are silently skipped.
%   'SavePath'   - File path to write the table (default: '', no write).
%                  Extension selects format: .csv, .xlsx, .txt, .tsv.
%
% Outputs:
%   T - Table with one row per (subject x condition x channel). Columns:
%         subject         - Subject ID [string]
%         session         - Session identifier from .info.Session [string];
%                           '<none>' when not present in data.info
%         channel         - Numeric channel index [double]
%         channel_label   - 'S#_D#' or 'Ch#' label [string]; matches
%                           pf2.probe.montage() ChannelLabel column
%         condition       - Condition/regressor name [string]
%         beta_hbo        - First-level HbO beta weight [double] (uM or units
%                           from gx.glm.units); absent when HbO not fitted
%         beta_hbr        - First-level HbR beta weight [double]
%         tstat_hbo       - t-statistic for HbO beta vs 0 [double]
%         tstat_hbr       - t-statistic for HbR beta vs 0 [double]
%         pval_hbo        - Uncorrected p-value for HbO t-test [double]
%         pval_hbr        - Uncorrected p-value for HbR t-test [double]
%       Additional biomarkers (HbTotal, HbDiff, CBSI) produce analogous
%       beta_*/tstat_*/pval_* columns when present and requested. Info
%       fields (Group, Age, etc.) from each subject's .info struct are
%       appended as extra columns after channel_label.
%
% Algorithm:
%   1. Call glmResults.betaTable('IncludeStats', true, 'Channels', channels)
%      which already includes channel_label when a device is attached.
%   2. Rename columns from CamelCase to lowercase underscore to match the
%      benchmark schema (SubjectID -> subject, beta_HbO -> beta_hbo, etc.).
%   3. Inject session column from .info.Session (or '<none>').
%   4. Reorder columns to the canonical schema order.
%   5. Optionally write to disk.
%
% Example:
%   % Build a GLMExperiment from sample data
%   [subjects, blockDefs] = pf2.import.sampleData.experiment('blocks');
%   gx = exploreFNIRS.core.GLMExperiment(subjects, blockDefs);
%   gx.fit();
%
%   % Export to table and save
%   T = pf2.export.glmToTable(gx, 'SavePath', 'glm_results.csv');
%   disp(T(1:3, {'subject','channel','channel_label','condition','beta_hbo'}))
%
%   % Verify round-trip: one row per (subject, channel, condition)
%   gx2 = pf2.import.sampleData.group();    % or your own group
%   T2 = pf2.export.glmToTable(gx2);
%   assert(height(T2) == numel(unique(T2.subject)) * ...
%       numel(unique(T2.channel)) * numel(unique(T2.condition)));
%
% Notes:
%   - p-values in this table are first-level (per-subject) estimates from
%     the design matrix fit and reflect within-subject noise only. For group
%     inference use gx.groupStats() or gx.statsFitLME().
%   - Session defaults to '<none>' rather than NaN so the column stays a
%     consistent string type across subjects.
%   - Channel labels match pf2.probe.montage() ChannelLabel output; when the
%     device has no src/det info, both will show 'Ch#'.
%
% See also: exploreFNIRS.core.GLMExperiment.betaTable,
%           exploreFNIRS.core.GLMExperiment.groupStats,
%           pf2.export.blockAvgToTable,
%           pf2.probe.montage, pf2.probe.channelLabels

% --- Parse inputs ---
ip = inputParser;
addRequired( ip, 'glmResults');
addParameter(ip, 'Channels',   [],  @isnumeric);
addParameter(ip, 'Biomarkers', {},  @iscell);
addParameter(ip, 'SavePath',   '',  @(x) ischar(x) || isstring(x));
parse(ip, glmResults, varargin{:});

glmResults = ip.Results.glmResults;
channels   = ip.Results.Channels;
biomarkers = ip.Results.Biomarkers;
savePath   = char(ip.Results.SavePath);

% --- Build raw beta table from the GLMExperiment ---
if isa(glmResults, 'exploreFNIRS.core.GLMExperiment')
    btArgs = {'IncludeStats', true};
    if ~isempty(channels)
        btArgs = [btArgs, {'Channels', channels}];
    end
    raw = glmResults.betaTable(btArgs{:});

    % Determine which biomarkers were fitted
    fittedBios = glmResults.glm.biomarkers;
    if isempty(biomarkers)
        biomarkers = fittedBios;
    else
        % Keep only those actually fitted
        biomarkers = biomarkers(ismember(biomarkers, fittedBios));
    end
elseif istable(glmResults)
    % Accept a pre-built betaTable (already has CamelCase columns)
    raw = glmResults;
    % Infer biomarkers from column names
    if isempty(biomarkers)
        biomarkers = inferBiomarkersFromTable(raw);
    end
    % Honor 'Channels' for the table path too: filter rows by the channel column.
    if ~isempty(channels)
        vn = raw.Properties.VariableNames;
        chIdx = find(strcmpi(vn, 'channel'), 1);
        if ~isempty(chIdx)
            raw = raw(ismember(raw.(vn{chIdx}), channels), :);
        end
    end
else
    error('pf2:export:glmToTable:badInput', ...
        ['glmResults must be a fitted exploreFNIRS.core.GLMExperiment ', ...
         'or a table from betaTable(''IncludeStats'', true).']);
end

if isempty(raw) || height(raw) == 0
    T = table();
    return;
end

% --- Normalize column names to lowercase underscore schema ---
T = renameColumns(raw, biomarkers);

% --- Inject session column ---
T = injectSession(T, glmResults);

% --- Enforce canonical column order ---
T = reorderColumns(T, biomarkers);

% --- Optional write ---
if ~isempty(savePath)
    writeTable(T, savePath);
end

end

%%_Subfunctions_________________________________________________________

function T = renameColumns(raw, biomarkers)
% RENAMECOLUMNS Map CamelCase betaTable columns to lowercase underscore schema
%
% Inputs:
%   raw        - Table from betaTable('IncludeStats', true)
%   biomarkers - Cell array of biomarker names fitted (e.g. {'HbO','HbR'})
%
% Outputs:
%   T - Table with renamed columns

T = raw;
varNames = T.Properties.VariableNames;

% Core renames (applied unconditionally when present)
coreMap = { ...
    'SubjectID',  'subject'; ...
    'Condition',  'condition'; ...
    'Channel',    'channel'; ...
    'channel_label', 'channel_label' ...  % already lowercase; keep
};

for k = 1:size(coreMap, 1)
    src = coreMap{k, 1};
    dst = coreMap{k, 2};
    if ismember(src, varNames) && ~strcmp(src, dst)
        T.Properties.VariableNames{src} = dst;
        varNames = T.Properties.VariableNames;
    end
end

% Biomarker-specific renames: beta_HbO -> beta_hbo, etc.
for b = 1:numel(biomarkers)
    bio = biomarkers{b};
    bioLow = lower(bio);
    for pfx = {'beta_', 'tstat_', 'pval_'}
        src = [pfx{1}, bio];
        dst = [pfx{1}, bioLow];
        if ismember(src, varNames) && ~strcmp(src, dst)
            T.Properties.VariableNames{src} = dst;
            varNames = T.Properties.VariableNames;
        end
    end
end

end


function T = injectSession(T, glmResults) %#ok<INUSD>
% INJECTSESSION Canonicalize the session column name, preserving per-row values
%
% Inputs:
%   T          - Table with 'subject' column. For the GLMExperiment path,
%                betaTable() already copies each recording's OWN
%                .info.Session onto its rows (see
%                exploreFNIRS.core.GLMExperiment.betaTable's per-row info-field
%                copy), so a genuine per-recording session value is normally
%                already present here.
%   glmResults - GLMExperiment object or pre-built table (unused: kept for
%                interface stability / future extensibility)
%
% Outputs:
%   T - Table with a lowercase 'session' column, one value per row

existingVars = T.Properties.VariableNames;
sessIdx = find(strcmpi(existingVars, 'session'), 1);

% PRESERVE any real per-row session already carried on T; just canonicalize
% the column name to lowercase. Do NOT rebuild it from a subject-ID-only
% lookup: two recordings for the SAME participant in different sessions
% (e.g. ses-1 and ses-2) each carry their own correct per-row Session value
% here already, and collapsing them onto a single per-subject map would make
% both recordings report the same (last-writer-wins) session.
if ~isempty(sessIdx)
    if ~strcmp(existingVars{sessIdx}, 'session')
        T.Properties.VariableNames{sessIdx} = 'session';
    end
    return;
end

% No session column at all (no subject's .info carried a Session field):
% synthesize a placeholder so the column stays a consistent string type.
T.session = repmat("<none>", height(T), 1);

end


function T = reorderColumns(T, biomarkers)
% REORDERCOLUMNS Enforce canonical column order for the benchmark schema
%
% Inputs:
%   T          - Table with renamed columns
%   biomarkers - Cell array of biomarkers present (e.g. {'HbO','HbR'})
%
% Outputs:
%   T - Table with columns in canonical order

varNames = T.Properties.VariableNames;

% Core prefix columns (always first)
coreFirst = {'subject', 'session', 'channel', 'channel_label', 'condition'};

% Biomarker data columns
bioColumns = {};
for b = 1:numel(biomarkers)
    bioLow = lower(biomarkers{b});
    for pfx = {'beta_', 'tstat_', 'pval_'}
        col = [pfx{1}, bioLow];
        if ismember(col, varNames)
            bioColumns{end+1} = col; %#ok<AGROW>
        end
    end
end

% Everything else (info fields, etc.) goes at the end
usedCols = [coreFirst, bioColumns];
remaining = setdiff(varNames, usedCols, 'stable');

% Drop biomarker data columns for biomarkers that were NOT selected (e.g.
% beta_hbr / tstat_hbr / pval_hbr when Biomarkers={'HbO'}); genuine info
% columns (subject, n_trials, ...) do not carry these prefixes and are kept.
isUnselectedBio = cellfun(@(c) ...
    (startsWith(c,'beta_') || startsWith(c,'tstat_') || startsWith(c,'pval_')) ...
    && ~ismember(c, bioColumns), remaining);
remaining = remaining(~isUnselectedBio);

% Filter to only columns that actually exist
orderedCols = {};
for k = 1:numel(coreFirst)
    if ismember(coreFirst{k}, varNames)
        orderedCols{end+1} = coreFirst{k}; %#ok<AGROW>
    end
end
orderedCols = [orderedCols, bioColumns, remaining];
orderedCols = orderedCols(ismember(orderedCols, varNames));

T = T(:, orderedCols);

end


function bios = inferBiomarkersFromTable(T)
% INFERBIOMARKERSFROMETABLE Detect biomarker names from beta_* column names
%
% Inputs:
%   T - betaTable output
%
% Outputs:
%   bios - Cell array of biomarker names (e.g. {'HbO','HbR'})

bios = {};
varNames = T.Properties.VariableNames;
for k = 1:numel(varNames)
    tok = regexp(varNames{k}, '^beta_(.+)$', 'tokens');
    if ~isempty(tok)
        bios{end+1} = tok{1}{1}; %#ok<AGROW>
    end
end

end


function writeTable(T, savePath)
% WRITETABLE Write the results table to disk in format inferred from extension
%
% Inputs:
%   T        - Table to write
%   savePath - Output file path
%
% Outputs:
%   (none) - Writes the file to disk

[outDir, ~, ext] = fileparts(savePath);
if ~isempty(outDir) && exist(outDir, 'dir') ~= 7
    [ok, msg] = mkdir(outDir);
    if ~ok
        error('pf2:export:glmToTable:mkdirFailed', ...
            'Could not create directory %s: %s', outDir, msg);
    end
end

switch lower(ext)
    case {'.csv', '.txt', '.tsv'}
        writetable(T, savePath);
    case {'.xlsx', '.xls'}
        writetable(T, savePath);
    otherwise
        % Default to CSV
        writetable(T, [savePath '.csv']);
end

fprintf('pf2.export.glmToTable: wrote %d rows x %d columns to %s\n', ...
    height(T), width(T), savePath);

end
