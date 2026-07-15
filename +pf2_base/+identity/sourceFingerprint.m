function fingerprint = sourceFingerprint(paths, varargin)
% SOURCEFINGERPRINT Fingerprint the exact bytes of an input source manifest.
%
% Syntax:
%   fingerprint = pf2_base.identity.sourceFingerprint(paths)
%   fingerprint = pf2_base.identity.sourceFingerprint( ...
%       paths, 'LogicalNames', names)
%
% Inputs:
%   paths - One or more explicit paths to existing regular files. Accepts a
%           character vector, string array, or cell array of text scalars.
%
% Name-value Parameters:
%   LogicalNames - Portable relative names for the files. Defaults to each
%                  path's basename, including its extension. Backslashes are
%                  canonicalized to `/` and text is normalized to Unicode
%                  NFC. Names must be unique and may not be absolute, empty,
%                  contain empty or `.` components, or traverse with `..`.
%
% Outputs:
%   fingerprint - Scalar struct with fields:
%       profile   - `pf2.input.source.v1`
%       algorithm - `sha256`
%       available - Always true here; a matching field is present so this
%                   struct concatenates with the unavailable-source form
%                   emitted for in-memory inputs (see preflightImport).
%       reason    - Empty for an available source; carries a structured
%                   reason string only in the unavailable-source form.
%       digest    - Hash of the canonical source-manifest projection
%       entries   - Logical name, uint64 byte length, and byte digest for
%                   every file, sorted deterministically by logical name
%
% Physical roots, enumeration order, modification times, permissions, and
% all other filesystem metadata are excluded. Changing a logical name, byte
% length, or file byte changes the manifest identity. Invalid paths, unsafe
% logical names, and duplicate normalized names fail with stable identifiers
% in the `pf2:identity:*` namespace; incomplete manifests are never returned.
% Validation errors use `invalidSource`, `invalidLogicalName`, or
% `duplicateLogicalName`; file-reading errors are forwarded by sha256File.
%
% See also: pf2_base.identity.sha256File,
%           pf2_base.identity.hashProjection,
%           pf2_base.identity.verifyExpected

pathList = localTextList(paths, 'paths', 'pf2:identity:invalidSource');
if isempty(pathList)
    error('pf2:identity:invalidSource', ...
        'At least one fingerprint source path is required.');
end

[logicalNames, logicalNamesSupplied] = localParseOptions(varargin{:});
if logicalNamesSupplied
    logicalNames = localTextList(logicalNames, 'LogicalNames', ...
        'pf2:identity:invalidLogicalName');
    if numel(logicalNames) ~= numel(pathList)
        error('pf2:identity:invalidLogicalName', ...
            ['LogicalNames must contain exactly one name for each source ' ...
             'path.']);
    end
else
    logicalNames = cell(size(pathList));
    for i = 1:numel(pathList)
        [~, base, extension] = fileparts(pathList{i});
        logicalNames{i} = [base extension];
    end
end

for i = 1:numel(logicalNames)
    logicalNames{i} = localNormalizeLogicalName(logicalNames{i});
end
localRejectDuplicates(logicalNames);

order = localUtf8SortOrder(logicalNames);
pathList = pathList(order);
logicalNames = logicalNames(order);

template = struct( ...
    'logicalName', '', ...
    'byteLength', uint64(0), ...
    'byteDigest', '');
entries = repmat(template, numel(pathList), 1);
for i = 1:numel(pathList)
    [byteDigest, byteLength] = ...
        pf2_base.identity.sha256File(pathList{i});
    entries(i).logicalName = logicalNames{i};
    entries(i).byteLength = byteLength;
    entries(i).byteDigest = byteDigest;
end

digest = pf2_base.identity.hashProjection(entries, ...
    'ArtifactKind', 'pf2.input.source', ...
    'SchemaVersion', 1, ...
    'Projection', 'source-manifest-v1');

fingerprint = struct( ...
    'profile', 'pf2.input.source.v1', ...
    'algorithm', 'sha256', ...
    'available', true, ...
    'reason', '', ...
    'digest', digest, ...
    'entries', entries);

end

function [logicalNames, supplied] = localParseOptions(varargin)
% Parse the deliberately small public name-value surface with stable errors.

logicalNames = [];
supplied = false;
if mod(numel(varargin), 2) ~= 0
    error('pf2:identity:invalidSource', ...
        'Options must be supplied as name-value pairs.');
end
for i = 1:2:numel(varargin)
    optionName = localTextScalar(varargin{i}, 'option name', ...
        'pf2:identity:invalidSource');
    if strcmpi(optionName, 'LogicalNames')
        if supplied
            error('pf2:identity:invalidSource', ...
                'LogicalNames may be supplied only once.');
        end
        logicalNames = varargin{i + 1};
        supplied = true;
    else
        error('pf2:identity:invalidSource', ...
            'Unknown sourceFingerprint option: %s', optionName);
    end
end
end

function values = localTextList(value, label, identifier)
% Normalize supported text-container shapes to a column cell array.

if ischar(value)
    if ~isrow(value)
        error(identifier, ...
            '%s must contain character vectors or scalar strings.', label);
    end
    values = {value};
elseif isstring(value)
    if any(ismissing(value(:)))
        error(identifier, '%s must not contain missing strings.', label);
    end
    values = cellstr(value(:));
elseif iscell(value)
    values = cell(numel(value), 1);
    for i = 1:numel(value)
        values{i} = localTextScalar(value{i}, label, identifier);
    end
else
    error(identifier, ...
        '%s must be text or a cell array of text scalars.', label);
end
values = values(:);
end

function value = localTextScalar(value, label, identifier)
% Convert one character vector or scalar string without lossy coercion.

if isstring(value)
    if ~isscalar(value) || ismissing(value)
        error(identifier, ...
            '%s values must be character vectors or nonmissing scalar strings.', ...
            label);
    end
    value = char(value);
elseif ~(ischar(value) && isrow(value))
    error(identifier, ...
        '%s values must be character vectors or nonmissing scalar strings.', ...
        label);
end
end

function name = localNormalizeLogicalName(name)
% Produce one portable NFC logical path and reject aliases/traversal.

name = localTextScalar(name, 'LogicalNames', ...
    'pf2:identity:invalidLogicalName');
try
    name = pf2_base.identity.normalizeText(name, ...
        'ErrorIdentifier', 'pf2:identity:invalidLogicalName');
catch cause
    exception = MException('pf2:identity:invalidLogicalName', ...
        'Unicode NFC normalization is unavailable.');
    exception = addCause(exception, cause);
    throw(exception);
end

name = strrep(name, '\', '/');
if isempty(name)
    error('pf2:identity:invalidLogicalName', ...
        'Logical source names must not be empty.');
end
if name(1) == '/' || ~isempty(regexp(name, '^[A-Za-z]:', 'once'))
    error('pf2:identity:invalidLogicalName', ...
        'Logical source names must be relative: %s', name);
end
if any(uint16(name) < 32) || any(uint16(name) == 127)
    error('pf2:identity:invalidLogicalName', ...
        'Logical source names must not contain control characters.');
end

components = regexp(name, '/', 'split');
if any(cellfun('isempty', components)) || ...
        any(strcmp(components, '.')) || any(strcmp(components, '..'))
    error('pf2:identity:invalidLogicalName', ...
        ['Logical source names must not contain empty, `.`, or `..` path ' ...
         'components: %s'], name);
end
end

function localRejectDuplicates(names)
% Compare normalized names exactly; logical names are case-sensitive.

for i = 1:numel(names)
    for j = 1:i-1
        if strcmp(names{i}, names{j})
            error('pf2:identity:duplicateLogicalName', ...
                'Logical source name appears more than once: %s', names{i});
        end
    end
end
end

function order = localUtf8SortOrder(names)
% Sort by NFC UTF-8 bytes, independent of locale and filesystem collation.

order = (1:numel(names)).';
encoded = cellfun(@(x) unicode2native(x, 'UTF-8'), names, ...
    'UniformOutput', false);
for i = 2:numel(order)
    current = order(i);
    j = i - 1;
    while j >= 1 && localBytesGreater(encoded{order(j)}, encoded{current})
        order(j + 1) = order(j);
        j = j - 1;
    end
    order(j + 1) = current;
end
end

function tf = localBytesGreater(left, right)
% True when left follows right under unsigned lexicographic byte ordering.

sharedLength = min(numel(left), numel(right));
difference = find(left(1:sharedLength) ~= right(1:sharedLength), 1);
if isempty(difference)
    tf = numel(left) > numel(right);
else
    tf = left(difference) > right(difference);
end
end
