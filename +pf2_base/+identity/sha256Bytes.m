function hash = sha256Bytes(bytes)
% SHA256BYTES Compute a lowercase, prefixed SHA-256 digest of bytes.
%
%   hash = pf2_base.identity.sha256Bytes(bytes)
%
% Input:
%   bytes - Real, full UINT8 vector. Row and column vectors are equivalent.
%           An empty UINT8 array computes the standard SHA-256 empty digest.
%
% Output:
%   hash  - Character row vector of the form "sha256:" followed by exactly
%           64 lowercase hexadecimal digits.
%
% This function hashes the supplied bytes exactly. For durable PF2 artifact
% identity, use hashProjection, which adds artifact-domain separation and
% canonical value encoding.
%
% See also: pf2_base.identity.canonicalBytes,
%           pf2_base.identity.hashProjection

if ~isa(bytes, 'uint8') || issparse(bytes) || ~isreal(bytes) || ...
        ndims(bytes) ~= 2 || (~isempty(bytes) && ~isvector(bytes))
    error('pf2:identity:invalidBytes', ...
        'Input must be a real, full UINT8 vector.');
end

try
    digestEngine = javaMethod('getInstance', ...
        'java.security.MessageDigest', 'SHA-256');
    if ~isempty(bytes)
        digestEngine.update(typecast(bytes(:), 'int8'));
    end
    digest = reshape(typecast(digestEngine.digest(), 'uint8'), 1, []);
catch cause
    error('pf2:identity:hashUnavailable', ...
        'The Java SHA-256 implementation is unavailable: %s', cause.message);
end

hash = ['sha256:', lower(reshape(dec2hex(digest, 2).', 1, []))];

end
