classdef IdentityNamedHashTest < matlab.unittest.TestCase
% IDENTITYNAMEDHASHTEST Contract tests for SHA-256 and named hash domains.
%
% Run with:
%   runtests('pf2_base.tests.unit.IdentityNamedHashTest')
%
% See also: pf2_base.identity.sha256Bytes,
%           pf2_base.identity.hashProjection,
%           pf2_base.identity.verifyExpected

    methods (Test)
        function testKnownSHA256Vectors(testCase)
            emptyExpected = "sha256:e3b0c44298fc1c149afbf4c8996fb924" + ...
                "27ae41e4649b934ca495991b7852b855";
            abcExpected = "sha256:ba7816bf8f01cfea414140de5dae2223" + ...
                "b00361a396177a9cb410ff61f20015ad";

            testCase.verifyEqual(string(pf2_base.identity.sha256Bytes( ...
                zeros(1, 0, 'uint8'))), emptyExpected);
            testCase.verifyEqual(string(pf2_base.identity.sha256Bytes( ...
                uint8([97 98 99]))), abcExpected);
        end

        function testHashProjectionGoldenVector(testCase)
            % Frozen known-answer digest for a fixed value in a fixed artifact
            % domain. Unlike the self-consistency tests below, this anchors the
            % exact canonical envelope and domain-separation format across runs
            % and releases: any accidental change to canonicalBytes, the
            % hashProjection envelope, or a domain string rewrites this digest
            % and fails here. If this changes intentionally, it is a durable
            % identity break and the constant must be regenerated deliberately.
            value = struct('label', 'golden', 'count', uint32(3));
            expected = "sha256:054b34ea43bd16a032a0d659b4a652ec" + ...
                "60fb3b12ee723f06fa828396a2417990";

            digest = pf2_base.identity.hashProjection(value, ...
                'ArtifactKind', 'pf2.processing.recipe', ...
                'SchemaVersion', uint64(1), ...
                'Projection', 'scientific-content-v1');

            testCase.verifyEqual(string(digest), expected);
        end

        function testDigestWireForm(testCase)
            digest = string(project(struct('method', 'lpf')));

            testCase.verifyTrue(~isempty(regexp(char(digest), ...
                '^sha256:[0-9a-f]{64}$', 'once')), ...
                'Digest must use the lowercase, algorithm-prefixed wire form.');
        end

        function testProjectionIgnoresStructFieldOrder(testCase)
            first = struct('method', 'lpf', 'cutoff', 0.1);
            second = struct('cutoff', 0.1, 'method', 'lpf');

            testCase.verifyEqual(project(first), project(second));
        end

        function testArtifactKindSeparatesDomains(testCase)
            payload = struct('value', uint16(42));
            kinds = { ...
                'pf2.processing.recipe', ...
                'pf2.processing.run-spec', ...
                'pf2.processing.run-record', ...
                'pf2.study.manifest'};
            digests = cellfun(@(kind) project(payload, ...
                'ArtifactKind', kind), kinds, 'UniformOutput', false);

            testCase.verifyEqual(numel(unique(digests)), numel(kinds));
        end

        function testSchemaVersionSeparatesDomains(testCase)
            payload = struct('value', uint16(42));
            version1 = project(payload, 'SchemaVersion', uint64(1));
            version2 = project(payload, 'SchemaVersion', uint64(2));

            testCase.verifyNotEqual(version1, version2);
        end

        function testProjectionNameSeparatesDomains(testCase)
            payload = struct('value', uint16(42));
            requested = project(payload, 'Projection', 'requested-recipe-v1');
            effective = project(payload, 'Projection', 'effective-recipe-v1');

            testCase.verifyNotEqual(requested, effective);
            testCase.verifyEqual(requested, ...
                project(payload, 'Projection', 'requested-recipe-v1'));
            testCase.verifyEqual(effective, ...
                project(payload, 'Projection', 'effective-recipe-v1'));
        end

        function testScientificMutationChangesDigest(testCase)
            baseline = struct( ...
                'methodId', 'pf2.raw.tddr', ...
                'methodVersion', uint64(1), ...
                'parameters', struct('cutoffHz', 0.1), ...
                'units', 'Hz');
            changedParameter = baseline;
            changedParameter.parameters.cutoffHz = 0.11;
            changedMethod = baseline;
            changedMethod.methodId = 'pf2.raw.spline';
            changedUnits = baseline;
            changedUnits.units = 'rad/s';

            original = project(baseline);
            testCase.verifyNotEqual(original, project(changedParameter));
            testCase.verifyNotEqual(original, project(changedMethod));
            testCase.verifyNotEqual(original, project(changedUnits));
        end

        function testProjectionNormalizesSignedZero(testCase)
            negativeZero = typecast(bitshift(uint64(1), 63), 'double');
            testCase.verifyEqual(project(struct('x', 0.0)), ...
                project(struct('x', negativeZero)));
        end

        function testProjectionControlsNonFiniteValues(testCase)
            payload = struct('threshold', Inf);
            testCase.verifyError(@() project(payload), ...
                'pf2:identity:nonFinite');

            allowed = project(payload, 'AllowNonFinite', true);
            testCase.verifyTrue(startsWith(string(allowed), "sha256:"));
        end

        function testInvalidHashDomainMetadataRejected(testCase)
            payload = struct('value', 1);
            testCase.verifyError(@() project(payload, ...
                'ArtifactKind', 'bad kind'), ...
                'pf2:identity:invalidArtifactKind');
            testCase.verifyError(@() project(payload, ...
                'SchemaVersion', uint64(0)), ...
                'pf2:identity:invalidSchemaVersion');
            testCase.verifyError(@() project(payload, ...
                'Projection', ''), ...
                'pf2:identity:invalidProjection');
        end

        function testVerifyExpectedAcceptsExactDigest(testCase)
            digest = project(struct('value', 1));
            testCase.verifyWarningFree(@() ...
                pf2_base.identity.verifyExpected(digest, digest, ...
                'Kind', 'recipe'));
        end

        function testVerifyExpectedFailsClosedOnMismatch(testCase)
            expected = project(struct('value', 1));
            observed = project(struct('value', 2));

            testCase.verifyError(@() pf2_base.identity.verifyExpected( ...
                expected, observed, 'Kind', 'source'), ...
                'pf2:identity:fingerprintMismatch');
        end

        function testVerifyExpectedRejectsMalformedDigest(testCase)
            observed = project(struct('value', 1));
            testCase.verifyError(@() pf2_base.identity.verifyExpected( ...
                'not-a-digest', observed, 'Kind', 'source'), ...
                'pf2:identity:invalidHash');
        end
    end
end

function digest = project(value, varargin)
    defaults = { ...
        'ArtifactKind', 'pf2.processing.recipe', ...
        'SchemaVersion', uint64(1), ...
        'Projection', 'scientific-content-v1', ...
        'AllowNonFinite', false};
    names = string(defaults(1:2:end));
    suppliedNames = string(varargin(1:2:end));
    for i = 1:numel(suppliedNames)
        idx = find(strcmpi(names, suppliedNames(i)), 1);
        if ~isempty(idx)
            defaults{2 * idx} = varargin{2 * i};
        else
            defaults(end + 1:end + 2) = varargin(2 * i - 1:2 * i); %#ok<AGROW>
        end
    end
    digest = pf2_base.identity.hashProjection(value, defaults{:});
end
