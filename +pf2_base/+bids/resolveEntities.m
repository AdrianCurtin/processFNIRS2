function ent = resolveEntities(allData, taskOverride)
% RESOLVEENTITIES Map recordings to BIDS sub/ses/task/run entities
%
% Derives a sanitized BIDS entity set for each recording from its .info,
% then disambiguates collisions: recordings that share sub/ses/task and lack
% an explicit run are auto-numbered run-01, run-02, ... in input order. If two
% recordings in such a group carry the SAME explicit run, the later one is
% renumbered (with a pf2:asBIDS:runCollision warning) so they never resolve to
% the same path and overwrite each other.
%
% Labels are cleaned for a shareable dataset: a redundant leading entity word
% before a number is stripped ('Sub01' -> '01', avoiding sub-Sub01) and
% placeholder values (Unknown, n/a, none, ...) are treated as absent (ses is
% dropped, such subjects fall back to the index). A warning is emitted when a
% recording has no task and falls back to the generic 'task' label.
%
% Inputs:
%   allData      - cell array of fNIRS structs
%   taskOverride - char task label applied to every recording; '' to resolve
%                  each from its .info (TaskName/Task/task) with a 'task'
%                  default.
%
% Outputs:
%   ent - 1xN struct array with char fields sub, ses, task, run (ses/run may
%         be empty strings).
%
% Example:
%   ent = pf2_base.bids.resolveEntities(allData, 'rest');
%
% See also: pf2_base.bids.entityBase, pf2_base.bids.sanitizeLabel

n = numel(allData);
ent = struct('sub', cell(1, n), 'ses', '', 'task', '', 'run', '');

taskDefaulted = false;   % track whether any record fell back to the 'task' label

for i = 1:n
    info = [];
    if isstruct(allData{i}) && isfield(allData{i}, 'info')
        info = allData{i}.info;
    end

    sub = pf2_base.bids.sanitizeLabel(pf2_base.bids.infoField(info, ...
        {'SubjectID', 'SubjectId', 'Subject', 'subject', 'participant_id', 'participant'}, ''));
    sub = stripEntityPrefix(sub, 'sub');   % 'Sub01' -> '01' (avoid sub-Sub01)
    if isempty(sub) || isPlaceholder(sub)
        sub = sprintf('%02d', i);          % unknown/blank subject -> index
    end

    ses = pf2_base.bids.sanitizeLabel(pf2_base.bids.infoField(info, ...
        {'Session', 'session', 'ses'}, ''));
    ses = stripEntityPrefix(ses, 'ses');   % 'Ses2' -> '2' (avoid ses-Ses2)
    if isPlaceholder(ses)
        ses = '';                          % drop ses-Unknown / ses-n/a entirely
    end

    if ~isempty(taskOverride)
        task = taskOverride;
    else
        task = pf2_base.bids.infoField(info, {'TaskName', 'Task', 'task'}, '');
    end
    task = pf2_base.bids.sanitizeLabel(task);
    if isempty(task) || isPlaceholder(task)
        task = 'task';
        taskDefaulted = true;
    end

    run = pf2_base.bids.sanitizeLabel(pf2_base.bids.infoField(info, ...
        {'Run', 'run'}, ''));
    run = stripEntityPrefix(run, 'run');

    ent(i).sub = sub;
    ent(i).ses = ses;
    ent(i).task = task;
    ent(i).run = run;
end

% BIDS requires a task entity; warn once if we had to invent one so the user
% knows their dataset carries the generic 'task-task' label.
if taskDefaulted
    warning('pf2:asBIDS:defaultTask', ...
        ['No task label found for one or more recordings; using the ' ...
         'generic ''task-task''. Pass ''Task'', ''<label>'' (or set ' ...
         'info.TaskName) for a meaningful BIDS task entity.']);
end

% --- Disambiguate sub/ses/task collisions with run numbering ---
keys = arrayfun(@(e) sprintf('%s|%s|%s', e.sub, e.ses, e.task), ent, ...
    'UniformOutput', false);
[~, ~, grp] = unique(keys, 'stable');
runCollision = false;
for g = 1:max(grp)
    idx = find(grp == g);
    if numel(idx) <= 1
        continue;
    end
    % First, RESERVE every explicit run (first occurrence) in the group so an
    % auto-numbered member never steals a number an explicit member owns -- this
    % preserves the prior behavior for mixed empty/explicit groups regardless of
    % input order. A SECOND explicit member carrying an already-reserved value is
    % a genuine collision: it is renumbered to the next free number (the first
    % occurrence keeps its value) so two recordings never resolve to the same
    % BIDS path and silently overwrite each other.
    members = idx(:)';
    used = {};
    isDupExplicit = false(size(members));
    for t = 1:numel(members)
        r = ent(members(t)).run;
        if isempty(r)
            continue;
        end
        if ismember(r, used)
            isDupExplicit(t) = true;     % duplicate explicit -> renumber below
        else
            used{end+1} = r; %#ok<AGROW>  % reserve this explicit run
        end
    end
    % Then assign the next free number to every empty-run member and to each
    % duplicate-explicit member, in input order.
    counter = 0;
    for t = 1:numel(members)
        j = members(t);
        if ~isempty(ent(j).run) && ~isDupExplicit(t)
            continue;                    % keep this reserved explicit run
        end
        if isDupExplicit(t)
            runCollision = true;
        end
        counter = counter + 1;
        candidate = sprintf('%02d', counter);
        while ismember(candidate, used)
            counter = counter + 1;
            candidate = sprintf('%02d', counter);
        end
        ent(j).run = candidate;
        used{end+1} = candidate; %#ok<AGROW>
    end
end

if runCollision
    warning('pf2:asBIDS:runCollision', ...
        ['Two or more recordings share sub/ses/task AND the same explicit run; ' ...
         'colliding run(s) were renumbered to avoid overwriting exported files. ' ...
         'Set distinct info.Run values for a deterministic run mapping.']);
end
end

function label = stripEntityPrefix(label, prefix)
% Remove a redundant leading entity word so an ID like 'Sub01' becomes '01'
% (otherwise the filename reads 'sub-Sub01'). Only stripped when the remainder
% begins with a digit, so genuine labels like 'Subject' or 'Session' survive.
if isempty(label)
    return;
end
np = numel(prefix);
if numel(label) > np && strcmpi(label(1:np), prefix) && ...
        isstrprop(label(np+1), 'digit')
    label = label(np+1:end);
end
end

function tf = isPlaceholder(label)
% True for non-informative entity values that should not appear in a shared
% dataset (treated as "no value").
tf = ~isempty(label) && ismember(lower(label), ...
    {'unknown', 'na', 'none', 'nan', 'null', 'undefined'});
end
