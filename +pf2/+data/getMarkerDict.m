function dict = getMarkerDict(data)
% GETMARKERDICT Resolve the canonical marker dictionary for a dataset
%
% Returns the dataset's code->label dictionary as a canonical table (Code,
% Label, + attributes). If no explicit dictionary has been set, one is
% derived from the best available source, in order:
%   1. data.info.markerDict          (explicitly set canonical dictionary)
%   2. data.info.eventTypes          (BIDS events.tsv mapping)
%   3. data.info.log_info.MarkerDict (COBI .nir Marker Dictionary)
%   4. the unique codes in data.markers (labels left blank)
%
% Syntax:
%   dict = pf2.data.getMarkerDict(data)
%
% Inputs:
%   data - fNIRS data struct, a marker table, or a cell array of structs
%          (a cell array returns the union of all element dictionaries).
%
% Outputs:
%   dict - Canonical dictionary table keyed by Code (see normalizeMarkerDict).
%
% Algorithm:
%   1. Cell array  -> recurse over elements and union the dictionaries with
%      pf2_base.mergeMarkerDict (earlier elements win on Code conflicts).
%   2. Marker table -> derive a label-less dictionary from its unique codes.
%   3. Struct       -> return the first available source in priority order:
%      info.markerDict, then info.eventTypes, then info.log_info.MarkerDict,
%      each normalized via pf2_base.normalizeMarkerDict; if none exist, derive
%      a label-less dictionary from the codes in data.markers.
%
% Notes:
%   - The function always returns a valid (possibly 0-row) canonical table; it
%     never errors on a missing dictionary. Derived dictionaries carry Code
%     values with <missing> Label, which labelMarkers/defineBlocks skip.
%   - Only the FIRST populated source is used (no merge across sources on a
%     single struct); set an explicit dictionary with setMarkerDict to override.
%
% Example:
%   dict = pf2.data.getMarkerDict(data);
%   label = dict.Label(dict.Code == 49);
%
% See also: pf2.data.setMarkerDict, pf2.data.labelMarkers,
%           pf2_base.normalizeMarkerDict

% Cell array: union dictionaries across all elements
if iscell(data)
    dict = pf2_base.normalizeMarkerDict([]);
    for ci = 1:numel(data)
        dict = pf2_base.mergeMarkerDict(dict, pf2.data.getMarkerDict(data{ci}));
    end
    return;
end

% Marker table passed directly: derive from its codes
if istable(data)
    dict = dictFromCodes(data);
    return;
end

if ~isstruct(data)
    error('pf2:getMarkerDict:badInput', ...
        'Input must be an fNIRS struct, a marker table, or a cell array.');
end

% 1. Explicit dictionary
if isfield(data, 'info') && isfield(data.info, 'markerDict') && ...
        ~isempty(data.info.markerDict)
    dict = pf2_base.normalizeMarkerDict(data.info.markerDict);
    return;
end

% 2. BIDS eventTypes
if isfield(data, 'info') && isfield(data.info, 'eventTypes') && ...
        ~isempty(data.info.eventTypes)
    dict = pf2_base.normalizeMarkerDict(data.info.eventTypes);
    return;
end

% 3. COBI .nir Marker Dictionary
if isfield(data, 'info') && isfield(data.info, 'log_info') && ...
        isstruct(data.info.log_info) && isfield(data.info.log_info, 'MarkerDict') && ...
        ~isempty(data.info.log_info.MarkerDict)
    dict = pf2_base.normalizeMarkerDict(data.info.log_info.MarkerDict);
    return;
end

% 4. Derive from the codes present in the markers
if isfield(data, 'markers')
    dict = dictFromCodes(data.markers);
else
    dict = pf2_base.normalizeMarkerDict([]);
end

end

%%_Subfunctions_________________________________________________________

function dict = dictFromCodes(markers)
% DICTFROMCODES Build a label-less dictionary from the unique marker codes
mt = pf2_base.normalizeMarkers(markers);
codes = unique(mt.Code);
labels = strings(numel(codes), 1);
labels(:) = missing;
dict = table(codes, labels, 'VariableNames', {'Code', 'Label'});
end
