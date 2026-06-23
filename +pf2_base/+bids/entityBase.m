function base = entityBase(ent)
% ENTITYBASE Build a BIDS filename stem from resolved entities
%
% Assembles the entity prefix shared by a recording's files, e.g.
% 'sub-01_ses-1_task-rest_run-02'. The '_nirs.snirf' / '_events.tsv' suffix
% is appended by the caller.
%
% Inputs:
%   ent - struct with fields sub, ses, task, run (ses/run may be empty)
%
% Outputs:
%   base - char filename stem (no suffix, no extension)
%
% Example:
%   pf2_base.bids.entityBase(struct('sub','01','ses','','task','rest','run',''))
%   % 'sub-01_task-rest'
%
% See also: pf2_base.bids.resolveEntities

base = ['sub-' ent.sub];
if isfield(ent, 'ses') && ~isempty(ent.ses)
    base = [base '_ses-' ent.ses];
end
base = [base '_task-' ent.task];
if isfield(ent, 'run') && ~isempty(ent.run)
    base = [base '_run-' ent.run];
end
end
