function f = participantFields(data, requested)
% PARTICIPANTFIELDS Collect participant-level columns from a recording
%
% Pulls demographic/grouping values from a recording's .info for the
% participants.tsv row. With no explicit request, auto-collects the common
% sex/age/group fields when present. Otherwise each requested .info field is
% read (case-insensitive) into a column named by its sanitized lower-case
% form.
%
% Inputs:
%   data      - fNIRS data struct
%   requested - cell array of .info field names ({} for auto mode)
%
% Outputs:
%   f - struct mapping column name -> value (empty struct when nothing found)
%
% Example:
%   f = pf2_base.bids.participantFields(data, {'sex','age','Group'});
%
% See also: pf2_base.bids.writeParticipants

info = [];
if isstruct(data) && isfield(data, 'info')
    info = data.info;
end

f = struct();

if isempty(requested)
    age = pf2_base.bids.infoField(info, {'Age', 'age'}, []);
    if ~isempty(age)
        f.age = age;
    end
    sex = pf2_base.bids.infoField(info, {'sex', 'gender', 'Sex', 'Gender'}, []);
    if ~isempty(sex)
        f.sex = normSex(sex);
    end
    grp = pf2_base.bids.infoField(info, {'Group', 'group'}, []);
    if ~isempty(grp)
        f.group = grp;
    end
else
    for i = 1:numel(requested)
        name = requested{i};
        val = pf2_base.bids.infoField(info, {name}, []);
        if isempty(val)
            continue;
        end
        col = matlab.lang.makeValidName(lower(char(string(name))));
        if strcmpi(col, 'sex') || strcmpi(col, 'gender')
            val = normSex(val);
            col = 'sex';
        end
        f.(col) = val;
    end
end
end

function s = normSex(val)
% Normalize common sex encodings to BIDS-friendly M/F (else pass through).
key = lower(strtrim(char(string(val))));
switch key
    case {'m', 'male'}
        s = 'M';
    case {'f', 'female'}
        s = 'F';
    otherwise
        s = char(string(val));
end
end
