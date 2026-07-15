function status = verifyExpected(expected, observed, varargin)
% VERIFYEXPECTED Enforce an expected identity digest without warning fallback.
%
% Syntax:
%   status = pf2_base.identity.verifyExpected(expected, observed)
%   status = pf2_base.identity.verifyExpected( ...
%       expected, observed, 'Kind', kind)
%
% Inputs:
%   expected - Empty when no expectation was supplied, or a lowercase SHA-256
%              wire digest / scalar struct containing a `digest` field.
%   observed - Lowercase SHA-256 wire digest or scalar struct containing a
%              `digest` field. The observed value is always required.
%
% Name-value Parameters:
%   Kind - Human-readable fingerprint kind used in status and diagnostics.
%          Default: `input`.
%
% Outputs:
%   status - Scalar struct with `kind`, `expected`, `observed`, and `status`
%            fields. Status is `not-requested` when expected is empty and
%            `matched` when the two supplied digests are equal.
%
% A supplied mismatch always throws `pf2:identity:fingerprintMismatch`.
% Callers that intentionally accept changed input must create a new RunSpec;
% this function has no warning or proceed-on-mismatch mode.
% Malformed digests or options throw `pf2:identity:invalidHash`.
%
% See also: pf2_base.identity.sourceFingerprint

kind = localParseKind(varargin{:});
observedDigest = localDigest(observed, 'observed', false);

expectationProvided = ~localIsEmptyExpectation(expected);
if expectationProvided
    expectedDigest = localDigest(expected, 'expected', false);
else
    expectedDigest = '';
end

status = struct( ...
    'kind', kind, ...
    'expected', expectedDigest, ...
    'observed', observedDigest, ...
    'status', 'not-requested');

if ~expectationProvided
    return;
end
if ~strcmp(expectedDigest, observedDigest)
    error('pf2:identity:fingerprintMismatch', ...
        ['The expected %s fingerprint does not match the observed input. ' ...
         'Expected %s; observed %s. Processing must not continue with this ' ...
         'RunSpec.'], kind, expectedDigest, observedDigest);
end
status.status = 'matched';

end

function kind = localParseKind(varargin)
% Parse the single optional name-value pair with stable errors.

kind = 'input';
if mod(numel(varargin), 2) ~= 0
    error('pf2:identity:invalidHash', ...
        'Options must be supplied as name-value pairs.');
end
supplied = false;
for i = 1:2:numel(varargin)
    optionName = localScalarText(varargin{i}, 'option name', ...
        'pf2:identity:invalidHash');
    if strcmpi(optionName, 'Kind')
        if supplied
            error('pf2:identity:invalidHash', ...
                'Kind may be supplied only once.');
        end
        kind = localScalarText(varargin{i + 1}, 'Kind', ...
            'pf2:identity:invalidHash');
        if isempty(kind) || any(uint16(kind) < 32) || any(uint16(kind) == 127)
            error('pf2:identity:invalidHash', ...
                'Kind must be nonempty text without control characters.');
        end
        supplied = true;
    else
        error('pf2:identity:invalidHash', ...
            'Unknown verifyExpected option: %s', optionName);
    end
end
end

function digest = localDigest(value, label, allowEmpty)
% Extract and validate one exact lowercase SHA-256 wire digest.

if isstruct(value)
    if ~isscalar(value) || ~isfield(value, 'digest')
        error('pf2:identity:invalidHash', ...
            'The %s fingerprint struct must be scalar and contain digest.', ...
            label);
    end
    value = value.digest;
end
digest = localScalarText(value, [label ' digest'], ...
    'pf2:identity:invalidHash');
if allowEmpty && isempty(digest)
    return;
end
if isempty(regexp(digest, '^sha256:[0-9a-f]{64}$', 'once'))
    error('pf2:identity:invalidHash', ...
        ['The %s fingerprint must use the exact lowercase wire form ' ...
         '`sha256:<64 hexadecimal digits>`.'], label);
end
end

function tf = localIsEmptyExpectation(value)
% Only a genuinely absent top-level value means "not requested".

tf = (isnumeric(value) || islogical(value)) && isempty(value);
if ischar(value)
    tf = isempty(value);
elseif isstring(value)
    tf = isempty(value) || ...
        (isscalar(value) && ~ismissing(value) && strlength(value) == 0);
end
end

function value = localScalarText(value, label, identifier)
% Convert one character vector or scalar string without lossy coercion.

if isstring(value)
    if ~isscalar(value) || ismissing(value)
        error(identifier, ...
            '%s must be a character vector or nonmissing scalar string.', ...
            label);
    end
    value = char(value);
elseif ~(ischar(value) && isrow(value))
    error(identifier, ...
        '%s must be a character vector or nonmissing scalar string.', label);
end
end
