function value = decodeJsonTransport(json)
%DECODEJSONTRANSPORT Decode the lossless PF2 canonical JSON transport.
%
%   value = pf2_base.identity.decodeJsonTransport(json)
%
% JSON must carry the internal `pf2-canonical-json-v1` envelope produced by
% encodeJsonTransport. The decoder validates every node and rejects unknown
% kinds, fields, classes, dimensions, noncanonical hexadecimal, and ignored
% payloads. The result belongs to canonicalBytes' schema-neutral value language.
%
% This function restores semantic values, not artifact classes. Recipe,
% RunSpec, and RunRecord schemas remain responsible for validating their own
% fields and versions after transport decoding. This proof carrier is not the
% future public, human-readable Recipe JSON format.
%
% See also: pf2_base.identity.encodeJsonTransport,
%           pf2_base.identity.canonicalBytes

    json = scalarText(json);
    try
        envelope = jsondecode(json);
        validateEnvelope(envelope);
        value = decodeNode(envelope.root);
    catch cause
        if strcmp(cause.identifier, 'pf2:identity:invalidJsonTransport')
            rethrow(cause);
        end
        exception = MException('pf2:identity:invalidJsonTransport', ...
            'The input is not a valid pf2-canonical-json-v1 transport.');
        exception = addCause(exception, cause);
        throw(exception);
    end
end

function validateEnvelope(envelope)
    if ~isstruct(envelope) || ~isscalar(envelope) || ...
            ~sameFields(envelope, {'format', 'root'})
        invalid('The JSON root must contain exactly format and root.');
    end
    format = scalarText(envelope.format);
    if ~strcmp(format, 'pf2-canonical-json-v1')
        invalid('Unsupported canonical JSON transport format "%s".', format);
    end
end

function value = decodeNode(node)
    required = {'kind', 'className', 'dimensions', 'text', 'dataHex', ...
        'fieldNames', 'children'};
    if ~isstruct(node) || ~isscalar(node) || ~sameFields(node, required)
        invalid('Every transport node must contain exactly the v1 node fields.');
    end

    kind = scalarText(node.kind);
    switch kind
        case 'struct'
            requireEmpty(node.className, 'struct className');
            requireEmpty(node.text, 'struct text');
            requireEmpty(node.dataHex, 'struct dataHex');
            dimensions = decodeDimensions(node.dimensions);
            fieldNames = decodeTextList(node.fieldNames);
            children = decodeChildren(node.children);
            expected = arrayElementCount(dimensions) * numel(fieldNames);
            if numel(children) ~= expected
                invalid('Struct child count does not match dimensions and fields.');
            end
            value = buildStruct(dimensions, fieldNames, children);

        case 'cell'
            requireEmpty(node.className, 'cell className');
            requireEmpty(node.text, 'cell text');
            requireEmpty(node.dataHex, 'cell dataHex');
            requireEmpty(node.fieldNames, 'cell fieldNames');
            dimensions = decodeDimensions(node.dimensions);
            children = decodeChildren(node.children);
            if numel(children) ~= arrayElementCount(dimensions)
                invalid('Cell child count does not match its dimensions.');
            end
            value = cell(dimensions);
            for i = 1:numel(children)
                value{i} = decodeNode(children{i});
            end

        case 'logical'
            requireEmpty(node.className, 'logical className');
            requireEmpty(node.text, 'logical text');
            requireEmpty(node.fieldNames, 'logical fieldNames');
            requireEmpty(node.children, 'logical children');
            dimensions = decodeDimensions(node.dimensions);
            bytes = decodeHex(node.dataHex);
            if numel(bytes) ~= arrayElementCount(dimensions) || ...
                    any(bytes ~= 0 & bytes ~= 1)
                invalid('Logical data must contain one 00 or 01 byte per element.');
            end
            value = reshape(logical(bytes), dimensions);

        case 'numeric'
            requireEmpty(node.text, 'numeric text');
            requireEmpty(node.fieldNames, 'numeric fieldNames');
            requireEmpty(node.children, 'numeric children');
            className = scalarText(node.className);
            bytesPerElement = numericClassSize(className);
            dimensions = decodeDimensions(node.dimensions);
            bytes = decodeHex(node.dataHex);
            expected = arrayElementCount(dimensions) * bytesPerElement;
            if numel(bytes) ~= expected
                invalid('Numeric payload length does not match class and dimensions.');
            end
            value = numericFromNetworkBytes(bytes, className, dimensions);

        case 'text'
            requireEmpty(node.className, 'text className');
            requireEmpty(node.dimensions, 'text dimensions');
            requireEmpty(node.dataHex, 'text dataHex');
            requireEmpty(node.fieldNames, 'text fieldNames');
            requireEmpty(node.children, 'text children');
            value = pf2_base.identity.normalizeText(scalarText(node.text));

        case 'string-array'
            requireEmpty(node.className, 'string-array className');
            requireEmpty(node.text, 'string-array text');
            requireEmpty(node.dataHex, 'string-array dataHex');
            requireEmpty(node.fieldNames, 'string-array fieldNames');
            dimensions = decodeDimensions(node.dimensions);
            children = decodeChildren(node.children);
            if numel(children) ~= arrayElementCount(dimensions)
                invalid('String-array child count does not match its dimensions.');
            end
            value = repmat("", dimensions);
            for i = 1:numel(children)
                child = children{i};
                childKind = nodeKind(child);
                if strcmp(childKind, 'missing-string')
                    validateMissingString(child);
                    value(i) = string(missing);
                elseif strcmp(childKind, 'text')
                    decoded = decodeNode(child);
                    value(i) = string(decoded);
                else
                    invalid('String-array children must be text or missing-string nodes.');
                end
            end

        case 'missing-string'
            invalid('A missing-string node is valid only inside a string array.');

        otherwise
            invalid('Unknown canonical JSON node kind "%s".', kind);
    end
end

function value = buildStruct(dimensions, fieldNames, children)
    for i = 1:numel(fieldNames)
        normalized = pf2_base.identity.normalizeText(fieldNames{i});
        if ~strcmp(normalized, fieldNames{i})
            invalid('Struct field names must already be Unicode NFC.');
        end
        for j = 1:i-1
            if strcmp(fieldNames{i}, fieldNames{j})
                invalid('Struct field names must be unique.');
            end
        end
    end

    try
        if isempty(fieldNames)
            template = struct();
        else
            template = cell2struct(cell(1, numel(fieldNames)), ...
                fieldNames, 2);
        end
        value = repmat(template, dimensions);
        cursor = 1;
        for elementIndex = 1:numel(value)
            for fieldIndex = 1:numel(fieldNames)
                value(elementIndex).(fieldNames{fieldIndex}) = ...
                    decodeNode(children{cursor});
                cursor = cursor + 1;
            end
        end
    catch cause
        exception = MException('pf2:identity:invalidJsonTransport', ...
            'The transport contains an invalid MATLAB struct representation.');
        exception = addCause(exception, cause);
        throw(exception);
    end
end

function validateMissingString(node)
    if ~isstruct(node) || ~isscalar(node) || ...
            ~sameFields(node, {'kind', 'className', 'dimensions', 'text', ...
            'dataHex', 'fieldNames', 'children'})
        invalid('Invalid missing-string node.');
    end
    requireEmpty(node.className, 'missing-string className');
    requireEmpty(node.dimensions, 'missing-string dimensions');
    requireEmpty(node.text, 'missing-string text');
    requireEmpty(node.dataHex, 'missing-string dataHex');
    requireEmpty(node.fieldNames, 'missing-string fieldNames');
    requireEmpty(node.children, 'missing-string children');
end

function kind = nodeKind(node)
    if ~isstruct(node) || ~isscalar(node) || ~isfield(node, 'kind')
        invalid('A child is not a valid transport node.');
    end
    kind = scalarText(node.kind);
end

function dimensions = decodeDimensions(value)
    if ~isnumeric(value) || ~isreal(value) || issparse(value) || ...
            ~isvector(value) || numel(value) < 2
        invalid('Dimensions must be a JSON numeric vector with at least two values.');
    end
    dimensions = double(value(:).');
    if any(~isfinite(dimensions)) || any(dimensions < 0) || ...
            any(fix(dimensions) ~= dimensions) || any(dimensions > flintmax)
        invalid('Dimensions must be finite nonnegative integers.');
    end
end

function count = arrayElementCount(dimensions)
    count = prod(dimensions);
    if ~isfinite(count) || count > flintmax
        invalid('The declared dimensions exceed the supported array size.');
    end
end

function names = decodeTextList(value)
    if isempty(value)
        names = cell(1, 0);
    elseif ischar(value) && isrow(value)
        names = {value};
    elseif isstring(value) && all(~ismissing(value(:)))
        names = cellstr(value(:)).';
    elseif iscell(value)
        names = cell(1, numel(value));
        for i = 1:numel(value)
            names{i} = scalarText(value{i});
        end
    else
        invalid('fieldNames must be a JSON array of strings.');
    end
end

function children = decodeChildren(value)
    if isempty(value)
        children = cell(1, 0);
    elseif isstruct(value)
        children = num2cell(value(:).');
    elseif iscell(value)
        children = value(:).';
        if ~all(cellfun(@(x) isstruct(x) && isscalar(x), children))
            invalid('children must contain only JSON node objects.');
        end
    else
        invalid('children must be a JSON array of node objects.');
    end
end

function bytes = decodeHex(value)
    value = scalarText(value);
    if mod(numel(value), 2) ~= 0 || ...
            ~isempty(regexp(value, '[^0-9a-f]', 'once'))
        invalid('dataHex must contain an even number of lowercase hexadecimal digits.');
    end
    if isempty(value)
        bytes = zeros(1, 0, 'uint8');
    else
        bytes = uint8(sscanf(value, '%2x').');
        if numel(bytes) * 2 ~= numel(value)
            invalid('dataHex could not be decoded completely.');
        end
    end
end

function count = numericClassSize(className)
    switch className
        case {'double', 'int64', 'uint64'}
            count = 8;
        case {'single', 'int32', 'uint32'}
            count = 4;
        case {'int16', 'uint16'}
            count = 2;
        case {'int8', 'uint8'}
            count = 1;
        otherwise
            invalid('Unsupported numeric class "%s".', className);
    end
end

function value = numericFromNetworkBytes(bytes, className, dimensions)
    if isempty(bytes)
        linear = zeros(0, 1, className);
    else
        linear = typecast(bytes, className);
        if isLittleEndian()
            linear = swapbytes(linear);
        end
    end
    value = reshape(linear, dimensions);
end

function tf = isLittleEndian()
    persistent littleEndian
    if isempty(littleEndian)
        [~, ~, endian] = computer;
        littleEndian = strcmp(endian, 'L');
    end
    tf = littleEndian;
end

function requireEmpty(value, label)
    if ~isempty(value)
        invalid('The %s field must be empty.', label);
    end
end

function tf = sameFields(value, expected)
    actual = sort(fieldnames(value));
    expected = sort(expected(:));
    tf = isequal(actual, expected);
end

function value = scalarText(value)
    if isstring(value)
        if ~isscalar(value) || ismissing(value)
            invalid('Expected a nonmissing JSON string scalar.');
        end
        value = char(value);
    elseif ~(ischar(value) && (isrow(value) || isequal(size(value), [0 0])))
        invalid('Expected a character vector or nonmissing string scalar.');
    end
end

function invalid(message, varargin)
    error('pf2:identity:invalidJsonTransport', message, varargin{:});
end
