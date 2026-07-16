function json = encodeJsonTransport(value, varargin)
%ENCODEJSONTRANSPORT Losslessly encode a canonical PF2 value as JSON.
%
%   json = pf2_base.identity.encodeJsonTransport(value)
%   json = pf2_base.identity.encodeJsonTransport(value, ...
%       'AllowNonFinite', true, 'PrettyPrint', true)
%
% This is the internal `pf2-canonical-json-v1` proof carrier for the deliberately small
% value language accepted by canonicalBytes. It preserves numeric classes,
% exact finite bits, array dimensions, logicals, cells, struct arrays, missing
% strings, and permitted non-finite values. It is a storage/interchange format;
% its JSON bytes are never an artifact identity. Decode and hash the semantic
% value with hashProjection instead. It is not the future public Recipe JSON
% format: that schema-owned format must remain human-readable and restore types
% and shapes from Recipe metadata rather than exposing this tagged hex carrier.
%
% Numeric payloads use lowercase hexadecimal network-order bytes so JSON number
% coercion cannot lose uint64 values or floating-point precision. Scalar
% nonmissing strings and character vectors share the schema-level text form,
% matching canonicalBytes.
%
% See also: pf2_base.identity.decodeJsonTransport,
%           pf2_base.identity.canonicalBytes,
%           pf2_base.identity.hashProjection

    options = parseOptions(varargin{:});

    % Validate the complete tree before constructing any transport output.
    pf2_base.identity.canonicalBytes(value, ...
        'AllowNonFinite', options.AllowNonFinite);

    envelope = struct( ...
        'format', 'pf2-canonical-json-v1', ...
        'root', encodeNode(value, options.AllowNonFinite));
    json = jsonencode(envelope, 'PrettyPrint', options.PrettyPrint);
end

function options = parseOptions(varargin)
    parser = inputParser;
    parser.FunctionName = 'pf2_base.identity.encodeJsonTransport';
    parser.addParameter('AllowNonFinite', false, ...
        @(x) islogical(x) && isscalar(x));
    parser.addParameter('PrettyPrint', false, ...
        @(x) islogical(x) && isscalar(x));
    parser.parse(varargin{:});
    options = parser.Results;
end

function node = encodeNode(value, allowNonFinite)
    node = emptyNode();
    if isstruct(value)
        node.kind = 'struct';
        node.dimensions = double(size(value));
        [originalNames, normalizedNames] = sortedFieldNames(fieldnames(value));
        node.fieldNames = normalizedNames(:).';
        node.children = cell(1, numel(value) * numel(originalNames));
        cursor = 1;
        for elementIndex = 1:numel(value)
            for fieldIndex = 1:numel(originalNames)
                node.children{cursor} = encodeNode( ...
                    value(elementIndex).(originalNames{fieldIndex}), ...
                    allowNonFinite);
                cursor = cursor + 1;
            end
        end
    elseif iscell(value)
        node.kind = 'cell';
        node.dimensions = double(size(value));
        node.children = cell(1, numel(value));
        for i = 1:numel(value)
            node.children{i} = encodeNode(value{i}, allowNonFinite);
        end
    elseif islogical(value)
        node.kind = 'logical';
        node.dimensions = double(size(value));
        node.dataHex = bytesToHex(uint8(value(:).'));
    elseif ischar(value)
        node.kind = 'text';
        node.text = string(pf2_base.identity.normalizeText(value(:).'));
    elseif isstring(value)
        if isscalar(value) && ~ismissing(value)
            node.kind = 'text';
            node.text = string(pf2_base.identity.normalizeText(char(value)));
        else
            node.kind = 'string-array';
            node.dimensions = double(size(value));
            node.children = cell(1, numel(value));
            for i = 1:numel(value)
                child = emptyNode();
                if ismissing(value(i))
                    child.kind = 'missing-string';
                else
                    child.kind = 'text';
                    child.text = string( ...
                        pf2_base.identity.normalizeText(char(value(i))));
                end
                node.children{i} = child;
            end
        end
    elseif isnumeric(value)
        node.kind = 'numeric';
        node.className = class(value);
        node.dimensions = double(size(value));
        node.dataHex = bytesToHex(numericNetworkBytes(value, allowNonFinite));
    else
        % canonicalBytes has already rejected this path. Keep a stable guard in
        % case encodeNode is changed independently later.
        error('pf2:identity:unsupportedType', ...
            'Values of class "%s" are not supported by the JSON transport.', ...
            class(value));
    end
end

function node = emptyNode()
    % Every node has the same fields so nested JSON arrays decode predictably.
    node = struct( ...
        'kind', '', ...
        'className', '', ...
        'dimensions', [], ...
        'text', '', ...
        'dataHex', '', ...
        'fieldNames', {cell(1, 0)}, ...
        'children', {cell(1, 0)});
end

function [originalNames, normalizedNames] = sortedFieldNames(originalNames)
    normalizedNames = cell(size(originalNames));
    utf8 = cell(size(originalNames));
    for i = 1:numel(originalNames)
        [normalizedNames{i}, utf8{i}] = ...
            pf2_base.identity.normalizeText(originalNames{i});
    end

    order = (1:numel(originalNames)).';
    for i = 2:numel(order)
        current = order(i);
        j = i - 1;
        while j >= 1 && bytesGreater(utf8{order(j)}, utf8{current})
            order(j + 1) = order(j);
            j = j - 1;
        end
        order(j + 1) = current;
    end
    originalNames = originalNames(order);
    normalizedNames = normalizedNames(order);
end

function tf = bytesGreater(left, right)
    sharedLength = min(numel(left), numel(right));
    difference = find(left(1:sharedLength) ~= right(1:sharedLength), 1);
    if isempty(difference)
        tf = numel(left) > numel(right);
    else
        tf = left(difference) > right(difference);
    end
end

function bytes = numericNetworkBytes(value, allowNonFinite)
    linear = value(:);
    if isfloat(linear)
        nonFinite = isnan(linear) | isinf(linear);
        if any(nonFinite) && ~allowNonFinite
            error('pf2:identity:nonFinite', ...
                'NaN and Inf are not allowed in this JSON transport.');
        end
        linear(linear == 0) = cast(0, class(linear));
    end

    if isLittleEndian()
        networkValues = swapbytes(linear);
    else
        networkValues = linear;
    end
    bytes = reshape(typecast(networkValues, 'uint8'), 1, []);

    if isfloat(linear) && any(isnan(linear) | isinf(linear))
        bytesPerElement = bytesPerNumericElement(class(linear));
        matrix = reshape(bytes, bytesPerElement, []);
        matrix = normalizeNonFiniteBytes(matrix, linear);
        bytes = reshape(matrix, 1, []);
    end
end

function raw = normalizeNonFiniteBytes(raw, values)
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

function count = bytesPerNumericElement(className)
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
            error('pf2:identity:unsupportedType', ...
                'Unsupported numeric class "%s".', className);
    end
end

function text = bytesToHex(bytes)
    text = lower(reshape(dec2hex(bytes, 2).', 1, []));
end

function tf = isLittleEndian()
    persistent littleEndian
    if isempty(littleEndian)
        [~, ~, endian] = computer;
        littleEndian = strcmp(endian, 'L');
    end
    tf = littleEndian;
end
