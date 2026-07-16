function hash = hashProjection(value, varargin)
% HASHPROJECTION Hash a canonical value in an explicit PF2 artifact domain.
%
%   hash = pf2_base.identity.hashProjection(value, ...
%       'ArtifactKind', kind, ...
%       'SchemaVersion', version, ...
%       'Projection', projection)
%
%   hash = pf2_base.identity.hashProjection(value, ..., ...
%       'AllowNonFinite', true)
%
% Required name-value options:
%   ArtifactKind  - Nonempty character vector or string scalar containing
%                   the stable wire name, for example
%                   "pf2.processing.recipe".
%   SchemaVersion - Positive integer schema version.
%   Projection    - Nonempty character vector or string scalar naming the
%                   semantic projection, for example
%                   "scientific-content-v1" or "requested-recipe-v1".
%
% Optional name-value option:
%   AllowNonFinite - Scalar logical, default false; forwarded to
%                    canonicalBytes for both the domain envelope and value.
%
% The digest input is a canonical envelope containing a fixed PF2 marker,
% the canonical-encoding profile, ArtifactKind, SchemaVersion, Projection,
% and the supplied value. Consequently, identical payload values in two
% artifact kinds, schema versions, or projections cannot share a digest by
% accident. The output is "sha256:" plus 64 lowercase hexadecimal digits.
%
% Hash semantic projections rather than MAT-file or JSON-file bytes. Storage
% formatting, struct insertion order, and host endianness then do not define
% durable scientific identity.
%
% See also: pf2_base.identity.canonicalBytes,
%           pf2_base.identity.sha256Bytes

options = parseOptions(varargin{:});

envelope = struct();
envelope.marker = 'PF2-HASH-PROJECTION';
envelope.encodingProfile = 'pf2-canonical-binary-v1';
envelope.artifactKind = options.ArtifactKind;
envelope.schemaVersion = options.SchemaVersion;
envelope.projection = options.Projection;
envelope.value = value;

bytes = pf2_base.identity.canonicalBytes(envelope, ...
    'AllowNonFinite', options.AllowNonFinite);
hash = pf2_base.identity.sha256Bytes(bytes);

end


function options = parseOptions(varargin)
options = struct( ...
    'ArtifactKind', '', ...
    'SchemaVersion', uint64(0), ...
    'Projection', '', ...
    'AllowNonFinite', false);
seen = struct( ...
    'ArtifactKind', false, ...
    'SchemaVersion', false, ...
    'Projection', false, ...
    'AllowNonFinite', false);

if mod(numel(varargin), 2) ~= 0
    error('pf2:identity:invalidArguments', ...
        'Options must be supplied as name-value pairs.');
end

for i = 1:2:numel(varargin)
    suppliedName = optionName(varargin{i});
    fieldName = canonicalOptionName(suppliedName);
    if seen.(fieldName)
        error('pf2:identity:duplicateOption', ...
            'Option "%s" may be supplied only once.', fieldName);
    end

    candidate = varargin{i + 1};
    switch fieldName
        case 'ArtifactKind'
            options.ArtifactKind = artifactKind(candidate);
        case 'SchemaVersion'
            options.SchemaVersion = schemaVersion(candidate);
        case 'Projection'
            options.Projection = projectionName(candidate);
        case 'AllowNonFinite'
            if ~islogical(candidate) || ~isscalar(candidate)
                error('pf2:identity:invalidAllowNonFinite', ...
                    'AllowNonFinite must be a scalar logical.');
            end
            options.AllowNonFinite = candidate;
    end
    seen.(fieldName) = true;
end

required = {'ArtifactKind', 'SchemaVersion', 'Projection'};
for i = 1:numel(required)
    if ~seen.(required{i})
        error('pf2:identity:missingOption', ...
            'Required option "%s" was not supplied.', required{i});
    end
end
end


function name = optionName(value)
if ischar(value) && isrow(value)
    name = value;
elseif isstring(value) && isscalar(value) && ~ismissing(value)
    name = char(value);
else
    error('pf2:identity:invalidOptionName', ...
        'Option names must be character vectors or nonmissing string scalars.');
end
end


function canonical = canonicalOptionName(name)
known = {'ArtifactKind', 'SchemaVersion', 'Projection', 'AllowNonFinite'};
match = find(strcmpi(name, known), 1);
if isempty(match)
    error('pf2:identity:unknownOption', 'Unknown option "%s".', name);
end
canonical = known{match};
end


function text = artifactKind(value)
text = requiredText(value, ...
    'pf2:identity:invalidArtifactKind', 'ArtifactKind');
if isempty(regexp(text, ...
        '^[a-z][a-z0-9]*(\.[a-z][a-z0-9-]*)+$', 'once'))
    error('pf2:identity:invalidArtifactKind', ...
        ['ArtifactKind must be a lowercase dotted wire name such as ', ...
         '"pf2.processing.recipe".']);
end
end


function text = projectionName(value)
text = requiredText(value, ...
    'pf2:identity:invalidProjection', 'Projection');
if isempty(regexp(text, '^[a-z][a-z0-9]*([.-][a-z0-9]+)*$', 'once'))
    error('pf2:identity:invalidProjection', ...
        ['Projection must be a lowercase stable name using letters, digits, ', ...
         'dots, and hyphens.']);
end
end


function text = requiredText(value, identifier, label)
if ischar(value) && isrow(value)
    text = value;
elseif isstring(value) && isscalar(value) && ~ismissing(value)
    text = char(value);
else
    error(identifier, ...
        '%s must be a character vector or nonmissing string scalar.', label);
end

if isempty(text)
    error(identifier, '%s must not be empty.', label);
end
end


function version = schemaVersion(value)
validClass = isnumeric(value) && ~islogical(value);
validShape = isscalar(value) && isreal(value) && ~issparse(value);
if ~validClass || ~validShape
    error('pf2:identity:invalidSchemaVersion', ...
        'SchemaVersion must be a positive integer scalar.');
end

if isfloat(value)
    validValue = isfinite(value) && value >= 1 && fix(value) == value && ...
        value <= flintmax(class(value));
else
    validValue = value >= 1;
end
if ~validValue
    error('pf2:identity:invalidSchemaVersion', ...
        'SchemaVersion must be a positive integer scalar.');
end

version = uint64(value);
end
