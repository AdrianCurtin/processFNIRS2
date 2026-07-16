function [digest, byteLength] = sha256File(filePath)
% SHA256FILE Compute the SHA-256 digest of a file's exact bytes.
%
% Syntax:
%   digest = pf2_base.identity.sha256File(filePath)
%   [digest, byteLength] = pf2_base.identity.sha256File(filePath)
%
% Inputs:
%   filePath - Explicit path to one existing regular file, supplied as a
%              character vector or scalar string.
%
% Outputs:
%   digest     - Lowercase wire digest, `sha256:<64 hexadecimal digits>`.
%   byteLength - Number of bytes read, as a uint64 scalar.
%
% The file is streamed in bounded chunks. Its path, timestamps, permissions,
% and other filesystem metadata are deliberately excluded from the digest.
% Missing, unreadable, and interrupted files fail with stable identifiers in
% the `pf2:identity:*` namespace; no partial digest is returned.
% Errors: `invalidSource`, `fileNotFound`, `fileReadFailed`, and
% `hashUnavailable`.
%
% See also: pf2_base.identity.sourceFingerprint,
%           pf2_base.identity.sha256Bytes

filePath = localScalarText(filePath, 'file path');
if isempty(filePath)
    error('pf2:identity:invalidSource', ...
        'The file path must not be empty.');
end
if exist(filePath, 'file') ~= 2
    error('pf2:identity:fileNotFound', ...
        'The fingerprint source is not an existing regular file: %s', ...
        filePath);
end

[fid, openMessage] = fopen(filePath, 'rb');
if fid < 0
    error('pf2:identity:fileReadFailed', ...
        'Could not open fingerprint source "%s": %s', ...
        filePath, openMessage);
end
closeFile = onCleanup(@() fclose(fid)); %#ok<NASGU>

try
    md = javaMethod('getInstance', ...
        'java.security.MessageDigest', 'SHA-256');
catch cause
    exception = MException('pf2:identity:hashUnavailable', ...
        'A SHA-256 implementation is unavailable.');
    exception = addCause(exception, cause);
    throw(exception);
end

chunkSize = 1024 * 1024;
byteLength = uint64(0);
while true
    [bytes, count] = fread(fid, chunkSize, '*uint8');
    if count == 0
        break;
    end
    md.update(typecast(bytes(:), 'int8'));
    byteLength = byteLength + uint64(count);
end

[readMessage, readError] = ferror(fid);
% MATLAB reports EOF as status -1; only positive status values are errors.
if readError > 0
    error('pf2:identity:fileReadFailed', ...
        'Could not read fingerprint source "%s": %s', ...
        filePath, readMessage);
end

hashBytes = reshape(typecast(md.digest(), 'uint8'), 1, []);
digest = ['sha256:' sprintf('%02x', hashBytes)];

end

function value = localScalarText(value, label)
% Convert one character vector or scalar string without lossy coercion.

if isstring(value)
    if ~isscalar(value) || ismissing(value)
        error('pf2:identity:invalidSource', ...
            'The %s must be a character vector or nonmissing scalar string.', ...
            label);
    end
    value = char(value);
elseif ~(ischar(value) && isrow(value))
    error('pf2:identity:invalidSource', ...
        'The %s must be a character vector or nonmissing scalar string.', ...
        label);
end
end
