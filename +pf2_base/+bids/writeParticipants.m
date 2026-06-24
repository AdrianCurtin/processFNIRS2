function writeParticipants(bidsRoot, participantRows, requested)
% WRITEPARTICIPANTS Write participants.tsv (+ participants.json)
%
% Emits one row per unique subject with participant_id and the union of all
% demographic columns collected across recordings. Missing values render as
% 'n/a'. A companion participants.json gives each column a short description.
%
% Inputs:
%   bidsRoot        - dataset root directory
%   participantRows - struct array with fields participant_id (char) and
%                     fields (struct of column->value)
%   requested       - the user's requested column list (for ordering; may be {})
%
% Outputs:
%   (none) - Writes participants.tsv and participants.json.
%
% Example:
%   pf2_base.bids.writeParticipants(root, rows, {'sex','age'});
%
% See also: pf2_base.bids.participantFields, pf2.export.asBIDS

if isempty(participantRows)
    return;
end

% Column union across all subjects. Honor the user's requested order first
% (transformed to match the keys participantFields produces), then append any
% remaining columns in first-seen order.
present = {};
for i = 1:numel(participantRows)
    fn = fieldnames(participantRows(i).fields);
    for j = 1:numel(fn)
        if ~ismember(fn{j}, present)
            present{end+1} = fn{j}; %#ok<AGROW>
        end
    end
end

cols = {};
for i = 1:numel(requested)
    key = matlab.lang.makeValidName(lower(char(string(requested{i}))));
    if any(strcmpi(key, {'sex', 'gender'}))
        key = 'sex';
    end
    if ismember(key, present) && ~ismember(key, cols)
        cols{end+1} = key; %#ok<AGROW>
    end
end
for i = 1:numel(present)
    if ~ismember(present{i}, cols)
        cols{end+1} = present{i}; %#ok<AGROW>
    end
end

headers = [{'participant_id'}, cols];
nRow = numel(participantRows);
rows = cell(nRow, numel(headers));
for i = 1:nRow
    rows{i, 1} = participantRows(i).participant_id;
    flds = participantRows(i).fields;
    for c = 1:numel(cols)
        if isfield(flds, cols{c})
            rows{i, c + 1} = flds.(cols{c});
        else
            rows{i, c + 1} = 'n/a';
        end
    end
end

pf2_base.bids.writeTsv(fullfile(bidsRoot, 'participants.tsv'), headers, rows);

% Sidecar describing the columns (participant_id is implied by BIDS).
desc = struct();
for c = 1:numel(cols)
    desc.(cols{c}) = struct('Description', ...
        sprintf('%s of the participant.', cols{c}));
end
if ~isempty(fieldnames(desc))
    pf2_base.bids.writeJson(fullfile(bidsRoot, 'participants.json'), desc);
end
end
