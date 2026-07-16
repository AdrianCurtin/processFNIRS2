function fingerprint = importedContentFingerprint(projection, varargin)
%IMPORTEDCONTENTFINGERPRINT Fingerprint a schema-normalized imported input.
%
%   fingerprint = pf2_base.identity.importedContentFingerprint(projection)
%   computes the Decision-5 imported-content identity for an explicit,
%   canonicalizable projection. PROJECTION must already contain every value
%   visible to Layer-1 processing, expressed only with the types accepted by
%   pf2_base.identity.canonicalBytes.
%
%   This function deliberately does not guess which fields of an arbitrary
%   fNIRS struct matter. Processing functions may request the complete
%   fNIRstruct, so the Recipe/import schema or canonical executor must build
%   the projection and either include that complete computation-visible state
%   or enforce declared field dependencies before calling this function.
%
%   Name-value options:
%     'AllowNonFinite' - Permit canonical NaN/+Inf/-Inf values (default true).
%                        Imported arrays commonly use NaN masks; the owning
%                        schema remains responsible for deciding where such
%                        values are valid.
%
%   The returned struct contains:
%     .profile   - 'pf2.input.imported.v1'
%     .algorithm - 'sha256'
%     .digest    - domain-separated sha256:<hex> identity
%
%   See also pf2_base.identity.preflightImport,
%            pf2_base.identity.hashProjection,
%            pf2_base.identity.canonicalBytes

    parser = inputParser;
    parser.FunctionName = 'pf2_base.identity.importedContentFingerprint';
    parser.addParameter('AllowNonFinite', true, ...
        @(x) islogical(x) && isscalar(x));
    parser.parse(varargin{:});

    digest = pf2_base.identity.hashProjection(projection, ...
        'ArtifactKind', 'pf2.input.imported', ...
        'SchemaVersion', 1, ...
        'Projection', 'imported-content-v1', ...
        'AllowNonFinite', parser.Results.AllowNonFinite);

    fingerprint = struct( ...
        'profile', 'pf2.input.imported.v1', ...
        'algorithm', 'sha256', ...
        'digest', digest);
end
