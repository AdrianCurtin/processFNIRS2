function pairs = pairSubjects(data, varargin)
% PAIRSUBJECTS Match subjects into dyads or groups from .info metadata
%
% Reads .info.DyadID and .info.Role from each fNIRS struct to create
% matched pairs for hyperscanning analysis. Each dyad must have exactly
% the expected number of members.
%
% Syntax:
%   pairs = exploreFNIRS.hyperscanning.pairSubjects(data)
%   pairs = exploreFNIRS.hyperscanning.pairSubjects(data, 'ManualPairs', {{1,2},{3,4}})
%   pairs = exploreFNIRS.hyperscanning.pairSubjects(data, 'GroupSize', 3)
%
% Inputs:
%   data - Cell array of processed fNIRS structs with .info.DyadID and .info.Role
%
% Name-Value Parameters:
%   ManualPairs - Cell array of cell arrays with indices into data (overrides auto-pairing)
%                 e.g., {{1,2}, {3,4}} pairs data{1} with data{2}, etc.
%   GroupSize   - Expected members per group (default: 2 for dyads)
%   DyadField   - Info field for dyad/group ID (default: 'DyadID')
%   RoleField   - Info field for role label (default: 'Role')
%
% Outputs:
%   pairs - Struct array with fields:
%     .dyadID     - Dyad/group identifier string
%     .indices    - [1 x GroupSize] indices into data cell array
%     .roles      - {1 x GroupSize} cell array of role labels
%     .subjectIDs - {1 x GroupSize} cell array of subject IDs
%
% Example:
%   % Automatic pairing by DyadID
%   pairs = exploreFNIRS.hyperscanning.pairSubjects(data);
%   fprintf('Found %d dyads\n', length(pairs));
%
%   % Manual pairing
%   pairs = exploreFNIRS.hyperscanning.pairSubjects(data, ...
%       'ManualPairs', {{1,2}, {3,4}, {5,6}});
%
% See also: exploreFNIRS.hyperscanning.computeDyad, exploreFNIRS.hyperscanning.computeGroup

    p = inputParser;
    addRequired(p, 'data', @iscell);
    addParameter(p, 'ManualPairs', {}, @iscell);
    addParameter(p, 'GroupSize', 2, @(v) isnumeric(v) && isscalar(v) && v >= 2);
    addParameter(p, 'DyadField', 'DyadID', @ischar);
    addParameter(p, 'RoleField', 'Role', @ischar);
    parse(p, data, varargin{:});
    opts = p.Results;

    nData = length(data);

    if ~isempty(opts.ManualPairs)
        % Manual pairing
        pairs = buildManualPairs(data, opts.ManualPairs);
        return;
    end

    % Auto-pair by DyadID
    dyadField = opts.DyadField;
    roleField = opts.RoleField;
    groupSize = opts.GroupSize;

    % Extract metadata
    dyadIDs = cell(nData, 1);
    roles = cell(nData, 1);
    subjectIDs = cell(nData, 1);

    for i = 1:nData
        if ~isfield(data{i}, 'info')
            error('exploreFNIRS:hyperscanning:pairSubjects', ...
                'data{%d} has no .info field', i);
        end
        info = data{i}.info;

        if ~isfield(info, dyadField)
            error('exploreFNIRS:hyperscanning:pairSubjects', ...
                'data{%d}.info has no .%s field. Set DyadField or use ManualPairs.', ...
                i, dyadField);
        end
        dyadIDs{i} = char(string(info.(dyadField)));

        if isfield(info, roleField)
            roles{i} = char(string(info.(roleField)));
        else
            roles{i} = sprintf('Member%d', i);
        end

        if isfield(info, 'SubjectID')
            subjectIDs{i} = char(string(info.SubjectID));
        else
            subjectIDs{i} = sprintf('S%d', i);
        end
    end

    % Group by DyadID
    uniqueDyads = unique(dyadIDs, 'stable');
    nDyads = length(uniqueDyads);
    pairs = struct([]);

    for d = 1:nDyads
        dID = uniqueDyads{d};
        members = find(strcmp(dyadIDs, dID));

        if length(members) ~= groupSize
            warning('exploreFNIRS:hyperscanning:pairSubjects', ...
                'Dyad "%s" has %d members (expected %d). Skipping.', ...
                dID, length(members), groupSize);
            continue;
        end

        idx = length(pairs) + 1;
        pairs(idx).dyadID = dID;
        pairs(idx).indices = members(:)';
        pairs(idx).roles = roles(members)';
        pairs(idx).subjectIDs = subjectIDs(members)';
    end

    if isempty(pairs)
        warning('exploreFNIRS:hyperscanning:pairSubjects', ...
            'No valid dyads found. Check .info.%s values.', dyadField);
        pairs = struct('dyadID', {}, 'indices', {}, 'roles', {}, 'subjectIDs', {});
    end

    fprintf('Found %d dyads from %d subjects\n', length(pairs), nData);
end


function pairs = buildManualPairs(data, manualPairs)
% Build pairs struct from manual index specification
    nPairs = length(manualPairs);
    pairs = struct([]);

    for d = 1:nPairs
        mp = manualPairs{d};
        if ~iscell(mp)
            mp = num2cell(mp);
        end
        indices = [mp{:}];

        pairs(d).dyadID = sprintf('Pair%02d', d);
        pairs(d).indices = indices;

        roles = cell(1, length(indices));
        subjectIDs = cell(1, length(indices));
        for m = 1:length(indices)
            idx = indices(m);
            if isfield(data{idx}, 'info')
                if isfield(data{idx}.info, 'Role')
                    roles{m} = char(string(data{idx}.info.Role));
                else
                    roles{m} = sprintf('Member%d', m);
                end
                if isfield(data{idx}.info, 'SubjectID')
                    subjectIDs{m} = char(string(data{idx}.info.SubjectID));
                else
                    subjectIDs{m} = sprintf('S%d', idx);
                end
            else
                roles{m} = sprintf('Member%d', m);
                subjectIDs{m} = sprintf('S%d', idx);
            end
        end
        pairs(d).roles = roles;
        pairs(d).subjectIDs = subjectIDs;
    end
end
