function ent = resolveEntities(allData, taskOverride)
% RESOLVEENTITIES Map recordings to BIDS sub/ses/task/run entities
%
% Derives a sanitized BIDS entity set for each recording from its .info,
% then disambiguates collisions: recordings that share sub/ses/task and lack
% an explicit run are auto-numbered run-01, run-02, ... in input order.
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

for i = 1:n
    info = [];
    if isstruct(allData{i}) && isfield(allData{i}, 'info')
        info = allData{i}.info;
    end

    sub = pf2_base.bids.sanitizeLabel(pf2_base.bids.infoField(info, ...
        {'SubjectID', 'SubjectId', 'Subject', 'subject', 'participant_id', 'participant'}, ''));
    if isempty(sub)
        sub = sprintf('%02d', i);
    end

    ses = pf2_base.bids.sanitizeLabel(pf2_base.bids.infoField(info, ...
        {'Session', 'session', 'ses'}, ''));

    if ~isempty(taskOverride)
        task = taskOverride;
    else
        task = pf2_base.bids.infoField(info, {'TaskName', 'Task', 'task'}, 'task');
    end
    task = pf2_base.bids.sanitizeLabel(task);
    if isempty(task)
        task = 'task';
    end

    run = pf2_base.bids.sanitizeLabel(pf2_base.bids.infoField(info, ...
        {'Run', 'run'}, ''));

    ent(i).sub = sub;
    ent(i).ses = ses;
    ent(i).task = task;
    ent(i).run = run;
end

% --- Disambiguate sub/ses/task collisions with run numbering ---
keys = arrayfun(@(e) sprintf('%s|%s|%s', e.sub, e.ses, e.task), ent, ...
    'UniformOutput', false);
[~, ~, grp] = unique(keys, 'stable');
for g = 1:max(grp)
    idx = find(grp == g);
    if numel(idx) <= 1
        continue;
    end
    % Assign sequential runs to members lacking an explicit run, skipping
    % numbers already claimed by explicit runs in the same group.
    explicit = {ent(idx).run};
    used = explicit(~cellfun(@isempty, explicit));
    counter = 0;
    for j = idx(:)'
        if isempty(ent(j).run)
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
end
end
