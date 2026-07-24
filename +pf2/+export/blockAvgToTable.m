function T = blockAvgToTable(segments, varargin)
% BLOCKAVGTOTABLE Export block-averaged fNIRS epochs to a flat benchmark table
%
% Converts a cell array of epoched fNIRS segments (from pf2.data.extractBlocks
% or similar) into a unified, per-subject per-channel per-condition flat
% table. The schema is designed for cross-toolbox reproducibility benchmarks
% (FRESH pipeline), direct export to CSV/Excel, and downstream statistics.
%
% The function accepts raw epoch segments (preferred) and calls
% pf2.data.blockAverage internally, or accepts a pre-computed grand-average
% struct for single-condition workflows. Subject, session, and condition are
% pulled from each segment's .info struct; they degrade gracefully to
% '<unknown>' when absent.
%
% Reference:
%   Internal pf2 implementation. Column schema follows the FRESH fNIRS
%   benchmark interoperability convention.
%
% Syntax:
%   T = pf2.export.blockAvgToTable(segments)
%   T = pf2.export.blockAvgToTable(segments, 'SavePath', 'results.csv')
%   T = pf2.export.blockAvgToTable(segments, 'Channels', 1:8)
%   T = pf2.export.blockAvgToTable(segments, 'Biomarkers', {'HbO','HbR'})
%   T = pf2.export.blockAvgToTable(ga, ...)   % pre-computed grand-average
%
% Inputs:
%   segments - One of:
%     (a) Cell array {1 x N} of epoched fNIRS structs from
%         pf2.data.extractBlocks. Each element carries a .time vector, Hb
%         biomarker fields, and an .info struct with SubjectID / Session /
%         Condition. blockAverage is called internally; each unique
%         (SubjectID, Session, Condition) combination yields one averaged
%         row per channel. Preferred form: allows per-trial SE and N.
%     (b) Cell array of cell arrays: {subj}{cond} -> segment cells for
%         multi-subject / multi-condition workflows. Each inner cell is
%         averaged independently and its .info from the first non-empty
%         element is used for subject/session/condition metadata.
%     (c) A pre-computed grand-average struct from pf2.data.blockAverage
%         (contains .HbO.Mean, .HbO.SEM, .HbO.N, .time, etc.). In this
%         form subject/session/condition are taken from opts.Subject /
%         opts.Session / opts.Condition. Only the time-mean (mean over the
%         task window) is used; specify 'TimeWindow' to restrict the mean.
%
% Name-Value Parameters:
%   'Channels'    - Numeric vector of channel indices to include (default: all).
%                   Must be positive integers; an index that exceeds the
%                   available channel count for a given group errors with
%                   'pf2:export:blockAvgToTable:badChannel' rather than being
%                   silently dropped.
%   'Biomarkers'  - Cell array of biomarkers to export (default: {'HbO','HbR'})
%   'TimeWindow'  - [t_start, t_end] in seconds; time-mean is computed over
%                   this window (default: [] = mean over all positive time,
%                   i.e., the task epoch after t=0). Only applied when
%                   computing the mean from segments or from a ga struct.
%                   Must satisfy t_start < t_end, else errors with
%                   'pf2:export:blockAvgToTable:badWindow'.
%   'Subject'     - Subject label for pre-computed ga input (default: '<unknown>')
%   'Session'     - Session label for pre-computed ga input (default: '<none>')
%   'Condition'   - Condition label for pre-computed ga input (default: '<unknown>')
%   'SavePath'    - File path to write the table (default: '', no write).
%                   Extension selects format: .csv, .xlsx, .txt, .tsv.
%
% Outputs:
%   T - Table with one row per (subject x session x condition x channel).
%       Columns:
%         subject        - Subject ID [string]; from .info.SubjectID or '<unknown>'
%         session        - Session [string]; from .info.Session or '<none>'
%         channel        - Numeric channel index [double]
%         channel_label  - 'S#_D#' or 'Ch#' label [string]; consistent with
%                          pf2.probe.montage() ChannelLabel column
%         condition      - Condition name [string]; from .info.Condition or
%                          .info.markerCode as string, else '<unknown>'
%         mean_hbo       - Mean HbO over the time window [double] (uM)
%         mean_hbr       - Mean HbR over the time window [double] (uM)
%         se_hbo         - Standard error of the HbO mean across trials [double]
%         se_hbr         - Standard error of the HbR mean across trials [double]
%         n_trials       - Number of trials (segments) averaged [double]
%       Additional biomarkers (HbTotal, HbDiff, CBSI) produce mean_* / se_*
%       columns when present and requested.
%
% Algorithm:
%   1. Classify input (raw segments, nested cell, or pre-computed ga).
%   2. For raw segments: group by (SubjectID, Session, Condition); for each
%      group call pf2.data.blockAverage, then take the time-mean over the
%      specified window from ga.(bio).Mean and ga.(bio).SEM.
%   3. Resolve channel labels via pf2.probe.channelLabels (from segment.device)
%      or 'Ch#' fallback.
%   4. Assemble and optionally write the output table.
%
% Example:
%   data     = pf2.import.sampleData();
%   proc     = processFNIRS2(data);
%   blocks   = pf2.data.defineBlocks(proc, 50, 15, 'Embed', false);
%   segments = pf2.data.extractBlocks(proc, blocks, ...
%                  'PreTime', 5, 'PostTime', 15, 'SetT0', true);
%
%   T = pf2.export.blockAvgToTable(segments, 'SavePath', 'block_avg.csv');
%   disp(T(:, {'subject','channel','channel_label','condition','mean_hbo','n_trials'}))
%
%   % Multi-subject: pass a flat cell array; subjects are distinguished by
%   % SubjectID in each segment's .info
%   allSegs  = [segsSubj1, segsSubj2, segsSubj3];   % horizontal concat
%   T = pf2.export.blockAvgToTable(allSegs, 'TimeWindow', [0 10]);
%
% Notes:
%   - The time-mean default uses t > 0 (task epoch). Set 'TimeWindow' to
%     include a different interval (e.g. [2 8] for a 2-8 s post-onset mean).
%   - SE is the inter-trial SEM (ga.(bio).SEM) from blockAverage, which
%     reflects variability across trials, not measurement noise.
%   - For a pre-computed ga input the se_* columns reflect the same SEM.
%     When N_trials = 1, SE is NaN (single-trial, no spread estimable).
%   - Channel labels match pf2.probe.montage() output; 'Ch#' is used when
%     no device information is attached to the segments.
%
% See also: pf2.data.blockAverage, pf2.data.extractBlocks,
%           pf2.data.defineBlocks, pf2.export.glmToTable,
%           pf2.probe.channelLabels, pf2.probe.montage

% --- Parse inputs ---
ip = inputParser;
addParameter(ip, 'Channels',   [],           @isnumeric);
addParameter(ip, 'Biomarkers', {'HbO','HbR'}, @iscell);
addParameter(ip, 'TimeWindow', [],            @isnumeric);
addParameter(ip, 'Subject',    '<unknown>',   @(x) ischar(x) || isstring(x));
addParameter(ip, 'Session',    '<none>',      @(x) ischar(x) || isstring(x));
addParameter(ip, 'Condition',  '<unknown>',   @(x) ischar(x) || isstring(x));
addParameter(ip, 'SavePath',   '',            @(x) ischar(x) || isstring(x));
parse(ip, varargin{:});

channels   = ip.Results.Channels;
biomarkers = ip.Results.Biomarkers;
timeWin    = ip.Results.TimeWindow;
savePath   = char(ip.Results.SavePath);

% --- Validate Channels/TimeWindow up front (clear error, not a low-level
% indexing crash or a silently-garbage result) ---
if ~isempty(channels) && (any(mod(channels, 1) ~= 0) || any(channels < 1))
    error('pf2:export:blockAvgToTable:badChannel', ...
        'Channels must be positive integer indices (>= 1); got [%s].', ...
        num2str(channels));
end
if ~isempty(timeWin) && (numel(timeWin) ~= 2 || ~isnumeric(timeWin) || timeWin(1) >= timeWin(2))
    error('pf2:export:blockAvgToTable:badWindow', ...
        'TimeWindow must be a 2-element [start end] vector with start < end; got [%s].', ...
        num2str(timeWin));
end

% --- Dispatch on input type ---
if isstruct(segments)
    % Pre-computed grand-average struct
    T = gaStructToTable(segments, biomarkers, channels, timeWin, ...
        char(ip.Results.Subject), char(ip.Results.Session), ...
        char(ip.Results.Condition));

elseif iscell(segments) && ~isempty(segments) && iscell(segments{1})
    % Nested cell array: {subj}{cond} -> segment cells
    T = nestedCellToTable(segments, biomarkers, channels, timeWin);

elseif iscell(segments)
    % Flat cell array of fNIRS segment structs (standard form)
    T = flatCellToTable(segments, biomarkers, channels, timeWin);

else
    error('pf2:export:blockAvgToTable:badInput', ...
        ['segments must be a cell array of fNIRS structs (from ', ...
         'extractBlocks) or a pre-computed blockAverage struct.']);
end

% --- Optional write ---
if ~isempty(savePath) && ~isempty(T) && height(T) > 0
    writeTable(T, savePath);
end

end

%%_Subfunctions_________________________________________________________

function T = flatCellToTable(segments, biomarkers, channels, timeWin)
% FLATCELLTOTABLE Convert a flat cell array of segments to the output table
%
% Groups segments by (SubjectID, Session, Condition) and averages each group
% via pf2.data.blockAverage. Takes the time-mean over the task window.
%
% Inputs:
%   segments   - {1 x N} cell array of fNIRS epoch structs
%   biomarkers - Cell array of biomarker names
%   channels   - Numeric channel indices ([] = all)
%   timeWin    - [t_start, t_end] or [] (default: t >= 0)
%
% Outputs:
%   T - Output table

% Drop empties
keep = ~cellfun(@isempty, segments);
segments = segments(keep);

if isempty(segments)
    T = table();
    return;
end

% Group segments by (SubjectID, Session, Condition)
[keys, groups] = groupByMeta(segments);

rows = {};
for g = 1:numel(keys)
    k = keys{g};
    segs = groups{g};

    % Resolve channel labels from THIS group's own device, so mixed montages
    % across subjects/groups are labeled correctly rather than reusing the
    % first group's labels for everyone.
    chanLabels = resolveChannelLabels(segs);

    % Call blockAverage on this group
    try
        ga = pf2.data.blockAverage(segs);
    catch ME
        warning('pf2:export:blockAvgToTable:avgFailed', ...
            'blockAverage failed for group %s: %s. Skipping.', ...
            k.label, ME.message);
        continue;
    end
    if isempty(ga)
        continue;
    end

    % Determine channel list
    bio1 = firstAvailableBio(ga, biomarkers);
    if isempty(bio1)
        continue;
    end
    nChAll = size(ga.(bio1).Mean, 2);
    if isempty(channels)
        chList = 1:nChAll;
    else
        badCh = channels(channels > nChAll);
        if ~isempty(badCh)
            error('pf2:export:blockAvgToTable:badChannel', ...
                'Requested channel(s) [%s] exceed the available channel count (%d) for group %s.', ...
                num2str(badCh), nChAll, k.label);
        end
        chList = channels;
    end

    % Determine time-mean window mask
    timeMask = buildTimeMask(ga.time, timeWin);

    % Build one row per channel
    for ch = chList
        r = struct();
        r.subject  = string(k.subject);
        r.session  = string(k.session);
        r.channel  = ch;
        if ch <= numel(chanLabels)
            r.channel_label = chanLabels(ch);
        else
            r.channel_label = string(sprintf('Ch%d', ch));
        end
        r.condition = string(k.condition);

        % Exported values are the mean of the time-window mean over trials, and
        % the SEM ACROSS TRIALS of that window mean. The per-trial window means
        % come from ga.(bio).data [T x C x N]; averaging the pointwise SEM
        % (ga.SEM) would not be the SEM of the window mean. n_trials is the
        % count of trials that actually contribute a finite window mean, taken
        % from the reference biomarker so it matches the SE's valid set.
        [mRef, seRef, nRef] = trialWindowStats(ga, bio1, timeMask, ch);
        r.n_trials = nRef;

        for b = 1:numel(biomarkers)
            bio = biomarkers{b};
            bioLow = lower(bio);
            if strcmp(bio, bio1)
                r.(['mean_' bioLow]) = mRef;
                r.(['se_'   bioLow]) = seRef;
            elseif isfield(ga, bio) && isfield(ga.(bio), 'Mean')
                [mb, seb] = trialWindowStats(ga, bio, timeMask, ch);
                r.(['mean_' bioLow]) = mb;
                r.(['se_'   bioLow]) = seb;
            else
                r.(['mean_' bioLow]) = NaN;
                r.(['se_'   bioLow]) = NaN;
            end
        end

        rows{end+1} = r; %#ok<AGROW>
    end
end

if isempty(rows)
    T = table();
    return;
end
T = struct2table([rows{:}]);

end


function [m, se, n] = trialWindowStats(ga, bio, timeMask, ch)
% TRIALWINDOWSTATS Mean and SEM across trials of the time-window mean
%
% Averages each trial's data over the time window (from ga.(bio).data
% [T x C x nTrials]) to one value per trial, then returns the mean and the
% standard error of the mean ACROSS those per-trial window means. n is the
% number of trials with a finite window mean. Falls back to the summary
% fields when per-trial data is unavailable.
m = NaN; se = NaN; n = 0;
if ~isfield(ga, bio), return; end
B = ga.(bio);
if isfield(B, 'data') && ~isempty(B.data) && ndims(B.data) == 3
    trialData = B.data(timeMask, ch, :);                  % [Twin x 1 x nTrials]
    trialMeans = squeeze(mean(trialData, 1, 'omitnan'));  % [nTrials x 1]
    trialMeans = trialMeans(:);
    valid = ~isnan(trialMeans);
    n = sum(valid);
    if n >= 1, m = mean(trialMeans(valid)); end
    if n >= 2, se = std(trialMeans(valid)) / sqrt(n); end
elseif isfield(B, 'Mean')
    m = mean(B.Mean(timeMask, ch), 'omitnan');            % per-trial data absent
    if isfield(B, 'N'), n = max(B.N(timeMask, ch), [], 'omitnan'); end
    if n >= 2 && isfield(B, 'SEM')
        se = mean(B.SEM(timeMask, ch), 'omitnan');        % approximate (no per-trial data)
    else
        se = NaN;                                         % single trial: no spread estimable
    end
end
end


function T = gaStructToTable(ga, biomarkers, channels, timeWin, subject, session, condition)
% GASTRUCTTOTABLE Convert a pre-computed grand-average struct to the table
%
% Inputs:
%   ga         - Grand-average struct from pf2.data.blockAverage
%   biomarkers - Cell array of biomarker names
%   channels   - Numeric channel indices ([] = all)
%   timeWin    - [t_start, t_end] or []
%   subject    - Subject label [char]
%   session    - Session label [char]
%   condition  - Condition label [char]
%
% Outputs:
%   T - Output table

bio1 = firstAvailableBio(ga, biomarkers);
if isempty(bio1)
    T = table();
    return;
end

nChAll = size(ga.(bio1).Mean, 2);
if isempty(channels)
    chList = 1:nChAll;
else
    badCh = channels(channels > nChAll);
    if ~isempty(badCh)
        error('pf2:export:blockAvgToTable:badChannel', ...
            'Requested channel(s) [%s] exceed the available channel count (%d).', ...
            num2str(badCh), nChAll);
    end
    chList = channels;
end

timeMask = buildTimeMask(ga.time, timeWin);

rows = {};
for ch = chList
    r = struct();
    r.subject       = string(subject);
    r.session       = string(session);
    r.channel       = ch;
    r.channel_label = string(sprintf('Ch%d', ch));
    r.condition     = string(condition);

    % Same trial-window statistics as the flat-cell path: SEM ACROSS TRIALS of
    % the window mean (from ga.(bio).data), not the mean of the pointwise SEM.
    [mRef, seRef, nRef] = trialWindowStats(ga, bio1, timeMask, ch);
    r.n_trials = nRef;

    for b = 1:numel(biomarkers)
        bio = biomarkers{b};
        bioLow = lower(bio);
        if strcmp(bio, bio1)
            r.(['mean_' bioLow]) = mRef;
            r.(['se_'   bioLow]) = seRef;
        elseif isfield(ga, bio) && isfield(ga.(bio), 'Mean')
            [mb, seb] = trialWindowStats(ga, bio, timeMask, ch);
            r.(['mean_' bioLow]) = mb;
            r.(['se_'   bioLow]) = seb;
        else
            r.(['mean_' bioLow]) = NaN;
            r.(['se_'   bioLow]) = NaN;
        end
    end

    rows{end+1} = r; %#ok<AGROW>
end

if isempty(rows)
    T = table();
    return;
end
T = struct2table([rows{:}]);

end


function T = nestedCellToTable(nested, biomarkers, channels, timeWin)
% NESTEDCELLTOTABLE Convert a nested {subj}{cond} cell array to the table
%
% Inputs:
%   nested     - Cell array of cell arrays: nested{s}{c} = segment cell array
%   biomarkers - Cell array of biomarker names
%   channels   - Numeric channel indices ([] = all)
%   timeWin    - [t_start, t_end] or []
%
% Outputs:
%   T - Output table

allRows = {};
for s = 1:numel(nested)
    subCell = nested{s};
    if ~iscell(subCell)
        subCell = {subCell};
    end
    for c = 1:numel(subCell)
        segs = subCell{c};
        if ~iscell(segs)
            segs = {segs};
        end
        % Delegate to the flat cell path -- each inner group becomes one flat set
        Tsub = flatCellToTable(segs, biomarkers, channels, timeWin);
        if ~isempty(Tsub) && height(Tsub) > 0
            % In the positional {subj}{cond} form the subject/condition identity
            % is the s/c index. Segments that carried no .info collapse to
            % "<unknown>" in flatCellToTable; restore identity from the indices
            % so the groups stay distinguishable (real .info labels are kept).
            unkSubj = string(Tsub.subject) == "<unknown>";
            if any(unkSubj), Tsub.subject(unkSubj) = string(sprintf('subj%02d', s)); end
            unkCond = string(Tsub.condition) == "<unknown>";
            if any(unkCond), Tsub.condition(unkCond) = string(sprintf('cond%02d', c)); end
            allRows{end+1} = Tsub; %#ok<AGROW>
        end
    end
end

if isempty(allRows)
    T = table();
else
    T = vertcat(allRows{:});
end

end


function [keys, groups] = groupByMeta(segments)
% GROUPBYMETA Partition segments by (SubjectID, Session, Condition)
%
% Inputs:
%   segments - Non-empty cell array of fNIRS structs with .info
%
% Outputs:
%   keys   - Cell array of structs: .subject, .session, .condition, .label
%   groups - Cell array of segment subsets (one per key)

n = numel(segments);
labels = strings(n, 1);
metas  = cell(n, 1);

for i = 1:n
    seg = segments{i};
    subj = '<unknown>';
    sess = '<none>';
    cond = '<unknown>';

    if isfield(seg, 'info')
        info = seg.info;
        if isfield(info, 'SubjectID') && ~isempty(info.SubjectID)
            subj = char(string(info.SubjectID));
        end
        if isfield(info, 'Session') && ~isempty(info.Session)
            sess = char(string(info.Session));
        end
        % Condition: try Condition, then markerCode, then BlockCondition
        for cf = {'Condition', 'BlockCondition', 'markerCode', 'MarkerCode'}
            if isfield(info, cf{1}) && ~isempty(info.(cf{1}))
                cv = info.(cf{1});
                if isnumeric(cv)
                    cond = num2str(cv);
                else
                    cond = char(string(cv));
                end
                break;
            end
        end
    end

    labels(i) = sprintf('%s|%s|%s', subj, sess, cond);
    metas{i}  = struct('subject', subj, 'session', sess, 'condition', cond, ...
                       'label', char(labels(i)));
end

uniqueLabels = unique(labels, 'stable');
keys   = cell(1, numel(uniqueLabels));
groups = cell(1, numel(uniqueLabels));

for g = 1:numel(uniqueLabels)
    mask = labels == uniqueLabels(g);
    keys{g}   = metas{find(mask, 1)};
    groups{g} = segments(mask);
end

end


function mask = buildTimeMask(timeVec, timeWin)
% BUILDTIMEMASK Build a logical index into a time vector
%
% Inputs:
%   timeVec - [T x 1] time vector
%   timeWin - [t_start, t_end] or []
%
% Outputs:
%   mask - [T x 1] logical (true = include in average)

if isempty(timeWin)
    % Default: task epoch (t >= 0)
    mask = timeVec >= 0;
    if ~any(mask)
        mask = true(size(timeVec));   % fallback: use all
    end
else
    mask = timeVec >= timeWin(1) & timeVec <= timeWin(2);
    if ~any(mask)
        warning('pf2:export:blockAvgToTable:emptyWindow', ...
            'TimeWindow [%.2f %.2f] contains no time points; using all.', ...
            timeWin(1), timeWin(2));
        mask = true(size(timeVec));
    end
end

end


function bio = firstAvailableBio(ga, biomarkers)
% FIRSTAVAILABLEBIO Find the first biomarker present in a grand-average struct
%
% Inputs:
%   ga         - Grand-average struct
%   biomarkers - Cell array of candidate biomarker names
%
% Outputs:
%   bio - First available biomarker name, or '' if none found

bio = '';
for b = 1:numel(biomarkers)
    if isfield(ga, biomarkers{b}) && isfield(ga.(biomarkers{b}), 'Mean')
        bio = biomarkers{b};
        return;
    end
end

end


function chanLabels = resolveChannelLabels(segments)
% RESOLVECHANNELLABELS Extract channel labels from the first device-bearing segment
%
% Inputs:
%   segments - Non-empty cell array of fNIRS structs
%
% Outputs:
%   chanLabels - [nCh x 1] string array; empty if no device found

chanLabels = [];
for i = 1:numel(segments)
    seg = segments{i};
    if isfield(seg, 'device') && isa(seg.device, 'pf2.Device')
        try
            chanLabels = pf2.probe.channelLabels(seg);
        catch
            chanLabels = [];
        end
        return;
    end
end

end


function writeTable(T, savePath)
% WRITETABLE Write the results table to disk in format from extension
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
        error('pf2:export:blockAvgToTable:mkdirFailed', ...
            'Could not create directory %s: %s', outDir, msg);
    end
end

switch lower(ext)
    case {'.csv', '.txt', '.tsv'}
        writetable(T, savePath);
    case {'.xlsx', '.xls'}
        writetable(T, savePath);
    otherwise
        writetable(T, [savePath '.csv']);
end

fprintf('pf2.export.blockAvgToTable: wrote %d rows x %d columns to %s\n', ...
    height(T), width(T), savePath);

end
