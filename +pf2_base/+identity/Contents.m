% PF2_BASE.IDENTITY  Internal deterministic semantic-identity primitives.
%
% These functions support the future Recipe/RunSpec executor. They are not a
% user-facing authoring API; public clients should eventually construct typed
% artifacts and let the canonical executor apply identity policy.
%
% Semantic identity:
%   canonicalBytes - Canonically encode schema-neutral MATLAB values.
%   hashProjection - Hash a canonical value in an explicit artifact domain.
%
% Input identity and fail-closed verification:
%   importedContentFingerprint - Hash normalized computation-visible input.
%   preflightImport - Verify source/imported identity before Layer-1.
%   sha256File     - Stream and hash exact file bytes.
%   sourceFingerprint - Hash a portable multi-file source manifest.
%   verifyExpected - Enforce an expected digest without warning fallback.
%
% Phase-0 proof carrier (not the future human-facing Recipe JSON format):
%   decodeJsonTransport - Decode a lossless tagged canonical-value carrier.
%   encodeJsonTransport - Encode a lossless tagged canonical-value carrier.
%
% Implementation support:
%   normalizeText  - Normalize valid text to Unicode NFC and UTF-8.
%   sha256Bytes    - Compute a lowercase prefixed SHA-256 byte digest.
