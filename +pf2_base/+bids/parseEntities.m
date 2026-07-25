function ent = parseEntities(name)
% PARSEENTITIES Parse BIDS sub/ses/task/run entities from a filename
%
% Reverse of pf2_base.bids.resolveEntities: given a BIDS-style filename (or
% basename, with or without directory and extension), extract the key-value
% entities encoded as `key-value` tokens joined by underscores, e.g.
%   sub-01_ses-1_task-rest_run-02_nirs.snirf
% Only the standard NIRS entities are returned (sub, ses, task, run); any
% other tokens are ignored. Values are returned verbatim (not sanitized).
%
% Inputs:
%   name - Filename, basename, or path [char | string]. Directory parts and
%          the extension are stripped before parsing.
%
% Outputs:
%   ent  - struct with char fields:
%            .sub    - subject label   (e.g. '01'), '' if absent
%            .ses    - session label   (e.g. '1'),  '' if absent
%            .task   - task label       (e.g. 'rest'), '' if absent
%            .run    - run index label  (e.g. '02'), '' if absent
%            .isBIDS - true when a sub- entity is present (the minimum marker
%                      of a BIDS-named file)
%
% Example:
%   ent = pf2_base.bids.parseEntities('sub-01_ses-1_task-rest_nirs.snirf');
%   % ent.sub = '01', ent.ses = '1', ent.task = 'rest', ent.run = '',
%   % ent.isBIDS = true
%
% See also: pf2_base.bids.resolveEntities, pf2.import.importDirectory

ent = struct('sub', '', 'ses', '', 'task', '', 'run', '', 'isBIDS', false);

if isempty(name)
    return;
end
name = char(name);

% Strip directory and extension so only the entity string is parsed.
[~, base, ~] = fileparts(name);
if isempty(base)
    base = name;
end

ent.sub  = grabEntity(base, 'sub');
ent.ses  = grabEntity(base, 'ses');
ent.task = grabEntity(base, 'task');
ent.run  = grabEntity(base, 'run');
ent.isBIDS = ~isempty(ent.sub);
end

function val = grabEntity(base, key)
% Match `key-value` at the start of the string or after an underscore, where
% value runs to the next underscore. Alphanumeric labels only (BIDS-legal).
tok = regexp(base, ['(?:^|_)' key '-([A-Za-z0-9]+)'], 'tokens', 'once');
if isempty(tok)
    val = '';
else
    val = tok{1};
end
end
