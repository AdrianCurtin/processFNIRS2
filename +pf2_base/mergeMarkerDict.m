function d = mergeMarkerDict(a, b)
% MERGEMARKERDICT Merge two marker dictionaries, unioning codes and columns
%
% Combines two code->label dictionaries into one canonical dictionary. Rows
% are keyed by Code; on a Code conflict the entry from the FIRST argument (a)
% wins. Attribute columns present in only one input are retained, with
% missing entries filled by a type-appropriate blank.
%
% Syntax:
%   d = pf2_base.mergeMarkerDict(a, b)
%
% Inputs:
%   a - Dictionary (table/cell/Map/[]). Wins on Code conflicts.
%   b - Dictionary (table/cell/Map/[]).
%
% Outputs:
%   d - Canonical dictionary table keyed by Code (see normalizeMarkerDict).
%
% Notes:
%   - Both inputs are normalized first, so any supported dictionary form is
%     accepted; an empty side returns the other unchanged.
%   - On a Code present in both inputs, a's whole row wins (Label and every
%     attribute column); b contributes only codes a lacks.
%   - Attribute columns unique to one side are filled for the other side with a
%     type-appropriate blank (NaN / false / <missing> / '' / <undefined>).
%
% See also: pf2_base.normalizeMarkerDict, pf2.data.setMarkerDict

a = pf2_base.normalizeMarkerDict(a);
b = pf2_base.normalizeMarkerDict(b);

if height(a) == 0; d = b; return; end
if height(b) == 0; d = a; return; end

a = addMissingVars(a, b);
b = addMissingVars(b, a);
b = b(:, a.Properties.VariableNames);

d = [a; b];
[~, ia] = unique(d.Code, 'stable');   % a's rows precede b's -> a wins
d = d(ia, :);

end

%%_Subfunctions_________________________________________________________

function T = addMissingVars(T, ref)
% ADDMISSINGVARS Add variables present in ref but missing from T (filled blank)
miss = setdiff(ref.Properties.VariableNames, T.Properties.VariableNames, 'stable');
n = height(T);
for k = 1:numel(miss)
    name = miss{k};
    proto = ref.(name);
    if isnumeric(proto)
        T.(name) = nan(n, size(proto, 2));
    elseif islogical(proto)
        T.(name) = false(n, size(proto, 2));
    elseif isstring(proto)
        T.(name) = repmat(string(missing), n, size(proto, 2)); %#ok<*AGROW>
    elseif iscell(proto)
        T.(name) = repmat({''}, n, size(proto, 2));
    elseif iscategorical(proto)
        T.(name) = categorical(nan(n, size(proto, 2)));
    elseif isdatetime(proto)
        T.(name) = NaT(n, size(proto, 2));
    elseif isduration(proto)
        T.(name) = seconds(nan(n, size(proto, 2)));
    else
        T.(name) = nan(n, 1);
    end
end
end
