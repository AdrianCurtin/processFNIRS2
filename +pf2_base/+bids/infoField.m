function v = infoField(info, names, default)
% INFOFIELD First non-empty .info field matching any candidate name
%
% Case-insensitive lookup across an .info struct. Returns the value of the
% first candidate name that exists and is non-empty, else the supplied
% default.
%
% Inputs:
%   info    - .info struct (or [] / non-struct, treated as no match)
%   names   - cell array of candidate field names (checked in order)
%   default - value returned when no candidate matches
%
% Outputs:
%   v       - the matched field value, or default
%
% Example:
%   sub = pf2_base.bids.infoField(data.info, {'SubjectID','Subject'}, '');
%
% See also: pf2_base.bids.resolveEntities

v = default;
if ~isstruct(info)
    return;
end
fn = fieldnames(info);
low = lower(fn);
for i = 1:numel(names)
    idx = find(strcmp(low, lower(names{i})), 1);
    if ~isempty(idx)
        cand = info.(fn{idx});
        if ~isempty(cand)
            v = cand;
            return;
        end
    end
end
end
