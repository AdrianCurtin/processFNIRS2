function [data, identity] = preflightImport(importer, sourcePaths, projectionFcn, varargin)
%PREFLIGHTIMPORT Fail-closed source/imported identity gate before Layer-1.
%
%   [data, identity] = pf2_base.identity.preflightImport( ...
%       importer, sourcePaths, projectionFcn)
%
%   performs the canonical input-identity sequence around an existing importer:
%     1. Fingerprint the explicit source manifest.
%     2. Verify an expected source fingerprint, if supplied.
%     3. Invoke IMPORTER exactly once.
%     4. Re-fingerprint the manifest and fail if any source changed mid-import.
%     5. Convert imported DATA with PROJECTIONFCN.
%     6. Fingerprint and verify the normalized imported projection.
%
%   The function returns only after both identity gates pass. A canonical
%   executor can therefore call Layer-1 processing after this function without
%   offering a warning-only escape hatch.
%
%   Inputs:
%     importer      - Zero-argument function handle returning imported data.
%     sourcePaths   - File path or cell/string array of every consumed source.
%                     Pass [] for an in-memory/streaming source with no stable
%                     byte representation.
%     projectionFcn - Function handle mapping DATA to a schema-normalized,
%                     canonicalizable computation-visible projection.
%
%   Name-value options:
%     'LogicalNames'     - Portable logical relative names corresponding to
%                          sourcePaths. Absolute roots never enter identity.
%     'ExpectedSource'   - Expected source digest or fingerprint struct.
%     'ExpectedImported' - Expected imported digest or fingerprint struct.
%     'AllowNonFinite'   - Permit canonical non-finite values in the imported
%                          projection (default true).
%
%   Output IDENTITY contains the observed source/imported fingerprints and
%   validation outcomes. For an in-memory source, identity.source.available is
%   false with a structured reason; imported identity remains mandatory.
%
%   IMPORTANT: sourcePaths must be the complete set actually consumed by the
%   importer, including marker, mask, BIDS, NIRx, device, or other sidecars.
%   Omitting a consumed source creates incomplete provenance and is an error in
%   the calling import adapter, even though this generic function cannot detect
%   an undeclared file access itself.
%
%   See also pf2_base.identity.sourceFingerprint,
%            pf2_base.identity.importedContentFingerprint,
%            pf2_base.identity.verifyExpected

    if ~isa(importer, 'function_handle')
        error('pf2:identity:invalidImporter', ...
            'Importer must be a zero-argument function handle.');
    end
    if ~isa(projectionFcn, 'function_handle')
        error('pf2:identity:invalidProjectionFunction', ...
            'ProjectionFcn must be a function handle.');
    end

    parser = inputParser;
    parser.FunctionName = 'pf2_base.identity.preflightImport';
    parser.addParameter('LogicalNames', {}, ...
        @(x) ischar(x) || isstring(x) || iscellstr(x));
    parser.addParameter('ExpectedSource', '', ...
        @(x) isempty(x) || ischar(x) || (isstring(x) && isscalar(x)) || isstruct(x));
    parser.addParameter('ExpectedImported', '', ...
        @(x) isempty(x) || ischar(x) || (isstring(x) && isscalar(x)) || isstruct(x));
    parser.addParameter('AllowNonFinite', true, ...
        @(x) islogical(x) && isscalar(x));
    parser.parse(varargin{:});

    expectedSource = parser.Results.ExpectedSource;
    expectedImported = parser.Results.ExpectedImported;
    logicalNames = parser.Results.LogicalNames;

    hasStableSource = ~isempty(sourcePaths);
    if hasStableSource
        before = fingerprintSources(sourcePaths, logicalNames);
        sourceValidation = pf2_base.identity.verifyExpected( ...
            expectedSource, before, 'Kind', 'source');
    else
        if hasExpectation(expectedSource)
            error('pf2:identity:sourceUnavailable', ...
                ['An expected source fingerprint was supplied, but this input ', ...
                 'has no stable byte source to verify.']);
        end
        before = unavailableSource();
        sourceValidation = struct( ...
            'kind', 'source', ...
            'expected', '', ...
            'observed', '', ...
            'status', 'unavailable');
    end

    % The source expectation is verified before the importer can run.
    data = importer();

    if hasStableSource
        after = fingerprintSources(sourcePaths, logicalNames);
        pf2_base.identity.verifyExpected(before, after, ...
            'Kind', 'source-stability');
        sourceFingerprint = after;
    else
        sourceFingerprint = before;
    end

    projection = projectionFcn(data);
    importedFingerprint = pf2_base.identity.importedContentFingerprint( ...
        projection, 'AllowNonFinite', parser.Results.AllowNonFinite);
    importedValidation = pf2_base.identity.verifyExpected( ...
        expectedImported, importedFingerprint, 'Kind', 'imported-content');

    identity = struct();
    identity.profile = 'pf2.input.preflight.v1';
    identity.source = sourceFingerprint;
    identity.sourceValidation = sourceValidation;
    identity.imported = importedFingerprint;
    identity.importedValidation = importedValidation;
end

function tf = hasExpectation(value)
    % Match verifyExpected's definition of an omitted expectation.
    tf = true;
    if (isnumeric(value) || islogical(value) || ischar(value)) && isempty(value)
        tf = false;
    elseif isstring(value) && (isempty(value) || ...
            (isscalar(value) && ~ismissing(value) && strlength(value) == 0))
        tf = false;
    end
end

function fingerprint = fingerprintSources(sourcePaths, logicalNames)
    if isempty(logicalNames)
        fingerprint = pf2_base.identity.sourceFingerprint(sourcePaths);
    else
        fingerprint = pf2_base.identity.sourceFingerprint(sourcePaths, ...
            'LogicalNames', logicalNames);
    end
end

function source = unavailableSource()
    source = struct();
    source.profile = 'pf2.input.source.v1';
    source.algorithm = 'sha256';
    source.available = false;
    source.reason = 'no-stable-byte-source';
    source.digest = '';
    source.entries = struct( ...
        'logicalName', {}, 'byteLength', {}, 'byteDigest', {});
end
