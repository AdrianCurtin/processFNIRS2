function bytes = canonicalBytes(value, varargin)
% CANONICALBYTES Encode schema-neutral MATLAB values deterministically.
%
%   bytes = pf2_base.identity.canonicalBytes(value)
%   bytes = pf2_base.identity.canonicalBytes(value, ...
%       'AllowNonFinite', true)
%
% Produces a row vector of UINT8 bytes using the
% "pf2-canonical-binary-v1" profile. The encoding is independent of struct
% field insertion order and host byte order. It preserves MATLAB value type
% and visible array dimensions, visits array elements in column-major order,
% and normalizes all text to Unicode NFC before UTF-8 encoding.
%
% Supported values may be nested arbitrarily and are limited to:
%   - scalar or array structs;
%   - cell arrays;
%   - real, full arrays of the built-in numeric classes;
%   - logical arrays;
%   - character vectors; and
%   - string arrays (including missing string elements). A character vector
%     and an equivalent nonmissing scalar string share one text identity.
%
% Name-value options:
%   AllowNonFinite - Scalar logical, default false. When false, NaN and
%                    positive/negative Inf are rejected. When true, each is
%                    encoded with one profile-defined IEEE bit pattern.
%
% Floating-point negative zero is always normalized to positive zero.
% Sparse and complex arrays, character matrices, tables, other objects, and
% function handles are rejected. This deliberately small value language is
% the common semantic carrier for durable MAT and JSON representations; it
% is not a serialization of arbitrary MATLAB runtime state.
%
% Binary profile (version 1):
%   document := ASCII "PF2-CANONICAL", NUL, version-byte, framed-value
%   framed-value := type-tag, uint64(payload-byte-count), payload
%
% All integer metadata and numeric payloads use big-endian/network byte
% order. Array payloads begin with a uint64 dimension count followed by
% uint64 dimension lengths. Struct field names are sorted by normalized
% UTF-8 bytes; values are then emitted element-first and field-second.
%
% See also: pf2_base.identity.hashProjection,
%           pf2_base.identity.sha256Bytes

allowNonFinite = parseOptions(varargin{:});

profileHeader = [uint8('PF2-CANONICAL'), uint8(0), uint8(1)];
bytes = [profileHeader, encodeValue(value, allowNonFinite)];

end


function allowNonFinite = parseOptions(varargin)
allowNonFinite = false;

if mod(numel(varargin), 2) ~= 0
    error('pf2:identity:invalidArguments', ...
        'Options must be supplied as name-value pairs.');
end

seen = false;
for i = 1:2:numel(varargin)
    name = optionName(varargin{i});
    if ~strcmpi(name, 'AllowNonFinite')
        error('pf2:identity:unknownOption', ...
            'Unknown option "%s".', name);
    end
    if seen
        error('pf2:identity:duplicateOption', ...
            'Option "AllowNonFinite" may be supplied only once.');
    end

    candidate = varargin{i + 1};
    if ~islogical(candidate) || ~isscalar(candidate)
        error('pf2:identity:invalidAllowNonFinite', ...
            'AllowNonFinite must be a scalar logical.');
    end
    allowNonFinite = candidate;
    seen = true;
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


function bytes = encodeValue(value, allowNonFinite)
if issparse(value)
    error('pf2:identity:unsupportedType', ...
        'Sparse arrays are not supported by the canonical value language.');
end

if isa(value, 'function_handle')
    error('pf2:identity:unsupportedType', ...
        'Function handles are not supported by the canonical value language.');
end

if isstruct(value)
    bytes = encodeStruct(value, allowNonFinite);
elseif iscell(value)
    bytes = encodeCell(value, allowNonFinite);
elseif islogical(value)
    bytes = frame(uint8(3), ...
        [encodeDimensions(size(value)), uint8(value(:).')]);
elseif ischar(value)
    bytes = encodeChar(value);
elseif isstring(value)
    bytes = encodeString(value);
elseif isnumeric(value)
    if ~isreal(value)
        error('pf2:identity:unsupportedType', ...
            'Complex numeric arrays are not supported by the canonical value language.');
    end
    bytes = encodeNumeric(value, allowNonFinite);
elseif isa(value, 'table') || isa(value, 'timetable')
    error('pf2:identity:unsupportedType', ...
        'Tables and timetables are not supported by the canonical value language.');
elseif isobject(value)
    error('pf2:identity:unsupportedType', ...
        'Objects of class "%s" are not supported by the canonical value language.', ...
        class(value));
else
    error('pf2:identity:unsupportedType', ...
        'Values of class "%s" are not supported by the canonical value language.', ...
        class(value));
end
end


function bytes = encodeStruct(value, allowNonFinite)
% Tag 1: dimensions, sorted field-name table, then framed field values.
originalNames = fieldnames(value);
[originalNames, normalizedNames, normalizedUtf8] = ...
    sortFieldNames(originalNames);

parts = cell(1, 2 + numel(normalizedNames) + ...
    numel(value) * numel(normalizedNames));
cursor = 1;
parts{cursor} = encodeDimensions(size(value));
cursor = cursor + 1;
parts{cursor} = encodeUint64(numel(normalizedNames));
cursor = cursor + 1;

for fieldIndex = 1:numel(normalizedNames)
    parts{cursor} = lengthDelimited(normalizedUtf8{fieldIndex});
    cursor = cursor + 1;
end

for elementIndex = 1:numel(value)
    for fieldIndex = 1:numel(originalNames)
        fieldValue = value(elementIndex).(originalNames{fieldIndex});
        parts{cursor} = encodeValue(fieldValue, allowNonFinite);
        cursor = cursor + 1;
    end
end

payload = concatenate(parts);
bytes = frame(uint8(1), payload);
end


function [originalNames, normalizedNames, normalizedUtf8] = ...
        sortFieldNames(originalNames)
fieldCount = numel(originalNames);
normalizedNames = cell(fieldCount, 1);
normalizedUtf8 = cell(fieldCount, 1);
sortKeys = cell(fieldCount, 1);

for i = 1:fieldCount
    [normalizedNames{i}, normalizedUtf8{i}] = ...
        pf2_base.identity.normalizeText(originalNames{i});
    sortKeys{i} = lower(reshape(dec2hex(normalizedUtf8{i}, 2).', 1, []));
end

for i = 1:fieldCount
    for j = i + 1:fieldCount
        if strcmp(normalizedNames{i}, normalizedNames{j})
            error('pf2:identity:invalidText', ...
                ['Struct fields "%s" and "%s" have the same Unicode NFC ' ...
                 'spelling.'], originalNames{i}, originalNames{j});
        end
    end
end

[~, order] = sort(sortKeys);
originalNames = originalNames(order);
normalizedNames = normalizedNames(order);
normalizedUtf8 = normalizedUtf8(order);
end


function bytes = encodeCell(value, allowNonFinite)
% Tag 2: dimensions followed by framed values in column-major order.
parts = cell(1, numel(value) + 1);
parts{1} = encodeDimensions(size(value));
for i = 1:numel(value)
    parts{i + 1} = encodeValue(value{i}, allowNonFinite);
end
bytes = frame(uint8(2), concatenate(parts));
end


function bytes = encodeChar(value)
% Tag 4: one schema-level text scalar, independent of MATLAB char shape.
if ndims(value) ~= 2 || ...
        ~(size(value, 1) == 1 || size(value, 2) == 1 || ...
          isequal(size(value), [0 0]))
    error('pf2:identity:unsupportedType', ...
        'Character inputs must be vectors; character matrices are unsupported.');
end

bytes = encodeTextScalar(value(:).');
end


function bytes = encodeString(value)
% A nonmissing scalar string is the same schema text scalar as char.
if isscalar(value) && ~ismissing(value)
    bytes = encodeTextScalar(char(value));
    return;
end

% Tag 5: dimensions and column-major missing/present string-array elements.
parts = cell(1, numel(value) + 1);
parts{1} = encodeDimensions(size(value));
for i = 1:numel(value)
    if ismissing(value(i))
        parts{i + 1} = uint8(0);
    else
        [~, utf8] = pf2_base.identity.normalizeText(char(value(i)));
        parts{i + 1} = [uint8(1), lengthDelimited(utf8)];
    end
end
bytes = frame(uint8(5), concatenate(parts));
end


function bytes = encodeTextScalar(value)
[~, utf8] = pf2_base.identity.normalizeText(value);
bytes = frame(uint8(4), lengthDelimited(utf8));
end


function bytes = encodeNumeric(value, allowNonFinite)
[tag, bytesPerElement] = numericProfile(class(value));
linear = value(:);

if isfloat(linear)
    nonFinite = isnan(linear) | isinf(linear);
    if any(nonFinite) && ~allowNonFinite
        error('pf2:identity:nonFinite', ...
            ['NaN and Inf require the explicit name-value option ' ...
             '''AllowNonFinite'', true.']);
    end

    % Assignment of a typed +0 removes the IEEE sign bit from both zero forms.
    linear(linear == 0) = cast(0, class(linear));
end

if isLittleEndian()
    networkValues = swapbytes(linear);
else
    networkValues = linear;
end
raw = reshape(typecast(networkValues, 'uint8'), bytesPerElement, []);

if isfloat(linear) && any(isnan(linear) | isinf(linear))
    raw = normalizeNonFiniteBytes(raw, linear);
end

payload = [encodeDimensions(size(value)), reshape(raw, 1, [])];
bytes = frame(tag, payload);
end


function [tag, bytesPerElement] = numericProfile(className)
switch className
    case 'double'
        tag = uint8(16); bytesPerElement = 8;
    case 'single'
        tag = uint8(17); bytesPerElement = 4;
    case 'int8'
        tag = uint8(18); bytesPerElement = 1;
    case 'uint8'
        tag = uint8(19); bytesPerElement = 1;
    case 'int16'
        tag = uint8(20); bytesPerElement = 2;
    case 'uint16'
        tag = uint8(21); bytesPerElement = 2;
    case 'int32'
        tag = uint8(22); bytesPerElement = 4;
    case 'uint32'
        tag = uint8(23); bytesPerElement = 4;
    case 'int64'
        tag = uint8(24); bytesPerElement = 8;
    case 'uint64'
        tag = uint8(25); bytesPerElement = 8;
    otherwise
        error('pf2:identity:unsupportedType', ...
            'Numeric class "%s" is not a supported built-in numeric type.', ...
            className);
end
end


function raw = normalizeNonFiniteBytes(raw, values)
% Fixed quiet-NaN and infinity encodings from IEEE 754, in network order.
if isa(values, 'double')
    nanBytes = uint8([127 248 0 0 0 0 0 0]);
    positiveInfBytes = uint8([127 240 0 0 0 0 0 0]);
    negativeInfBytes = uint8([255 240 0 0 0 0 0 0]);
else
    nanBytes = uint8([127 192 0 0]);
    positiveInfBytes = uint8([127 128 0 0]);
    negativeInfBytes = uint8([255 128 0 0]);
end

for i = 1:numel(values)
    if isnan(values(i))
        raw(:, i) = nanBytes(:);
    elseif isinf(values(i)) && values(i) > 0
        raw(:, i) = positiveInfBytes(:);
    elseif isinf(values(i))
        raw(:, i) = negativeInfBytes(:);
    end
end
end


function bytes = encodeDimensions(dimensions)
parts = cell(1, numel(dimensions) + 1);
parts{1} = encodeUint64(numel(dimensions));
for i = 1:numel(dimensions)
    parts{i + 1} = encodeUint64(dimensions(i));
end
bytes = concatenate(parts);
end


function bytes = frame(tag, payload)
bytes = [tag, encodeUint64(numel(payload)), payload];
end


function bytes = lengthDelimited(payload)
bytes = [encodeUint64(numel(payload)), payload];
end


function bytes = encodeUint64(value)
if ~isscalar(value) || ~isreal(value) || value < 0 || ...
        (isfloat(value) && (~isfinite(value) || fix(value) ~= value))
    error('pf2:identity:internalLengthError', ...
        'Canonical lengths and dimensions must be finite nonnegative integers.');
end

networkValue = uint64(value);
if isLittleEndian()
    networkValue = swapbytes(networkValue);
end
bytes = reshape(typecast(networkValue, 'uint8'), 1, []);
end


function tf = isLittleEndian()
persistent littleEndian
if isempty(littleEndian)
    [~, ~, endian] = computer;
    littleEndian = strcmp(endian, 'L');
end
tf = littleEndian;
end


function bytes = concatenate(parts)
if isempty(parts)
    bytes = zeros(1, 0, 'uint8');
else
    bytes = [parts{:}];
end
end
