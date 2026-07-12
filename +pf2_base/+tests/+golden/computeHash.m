function hash = computeHash(data)
% COMPUTEHASH Generate SHA-256 hash of input data for golden file validation
%
% Serializes input data to bytes and computes a SHA-256 hash. Used to
% verify that input data has not changed when comparing against golden files.
%
% Syntax:
%   hash = pf2_base.tests.golden.computeHash(data)
%
% Inputs:
%   data - Any MATLAB variable (struct, array, etc.) to hash
%
% Outputs:
%   hash - SHA-256 hex string (64 characters)
%
% Example:
%   data = pf2.import.sampleData.fNIR2000();
%   hash = pf2_base.tests.golden.computeHash(data.raw);
%
% See also: pf2_base.tests.golden.verifyGolden

% Serialize to bytes
bytes = getByteStreamFromArray(data);

% Compute SHA-256
md = java.security.MessageDigest.getInstance('SHA-256');
md.update(bytes);
hashBytes = md.digest();

% Convert to hex string
hash = sprintf('%02x', typecast(hashBytes, 'uint8'));

end
