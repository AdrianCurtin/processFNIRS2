function [normalized, utf8] = normalizeText(value, varargin)
%NORMALIZETEXT Normalize one MATLAB text scalar to Unicode NFC and UTF-8.
%
%   normalized = pf2_base.identity.normalizeText(value)
%   [normalized, utf8] = pf2_base.identity.normalizeText(value)
%   ... = normalizeText(value, 'ErrorIdentifier', identifier)
%
% VALUE must be a character row vector or a nonmissing scalar string. Invalid
% UTF-16, including unpaired surrogate code units, is rejected before Java can
% silently substitute a replacement character. UTF8 is a row vector of UINT8.

    parser = inputParser;
    parser.FunctionName = 'pf2_base.identity.normalizeText';
    parser.addParameter('ErrorIdentifier', 'pf2:identity:invalidText', ...
        @(x) ischar(x) && isrow(x) && ~isempty(x));
    parser.parse(varargin{:});
    identifier = parser.Results.ErrorIdentifier;

    if isstring(value)
        if ~isscalar(value) || ismissing(value)
            error(identifier, ...
                'Text must be a character vector or nonmissing scalar string.');
        end
        value = char(value);
    elseif ~(ischar(value) && (isrow(value) || isequal(size(value), [0 0])))
        error(identifier, ...
            'Text must be a character vector or nonmissing scalar string.');
    end

    validateUtf16(value, identifier);
    try
        form = javaMethod('valueOf', 'java.text.Normalizer$Form', 'NFC');
        javaText = javaObject('java.lang.String', value);
        normalized = char(javaMethod('normalize', 'java.text.Normalizer', ...
            javaText, form));
        utf8 = reshape(unicode2native(normalized, 'UTF-8'), 1, []);
    catch cause
        exception = MException(identifier, ...
            'Text could not be normalized to Unicode NFC UTF-8.');
        exception = addCause(exception, cause);
        throw(exception);
    end
end

function validateUtf16(value, identifier)
    units = uint16(value);
    i = 1;
    while i <= numel(units)
        if units(i) >= hex2dec('D800') && units(i) <= hex2dec('DBFF')
            if i == numel(units) || units(i + 1) < hex2dec('DC00') || ...
                    units(i + 1) > hex2dec('DFFF')
                error(identifier, ...
                    'Text contains an unpaired UTF-16 high surrogate.');
            end
            i = i + 2;
        elseif units(i) >= hex2dec('DC00') && units(i) <= hex2dec('DFFF')
            error(identifier, ...
                'Text contains an unpaired UTF-16 low surrogate.');
        else
            i = i + 1;
        end
    end
end
