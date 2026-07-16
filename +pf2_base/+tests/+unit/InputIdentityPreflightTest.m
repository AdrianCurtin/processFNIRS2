classdef InputIdentityPreflightTest < matlab.unittest.TestCase
%INPUTIDENTITYPREFLIGHTTEST Fail-closed import/content identity contracts.

    properties (Access = private)
        TempDir char = ''
    end

    methods (TestMethodSetup)
        function createTemporaryDirectory(testCase)
            testCase.TempDir = tempname;
            mkdir(testCase.TempDir);
        end
    end

    methods (TestMethodTeardown)
        function removeTemporaryDirectory(testCase)
            if ~isempty(testCase.TempDir) && isfolder(testCase.TempDir)
                rmdir(testCase.TempDir, 's');
            end
        end
    end

    methods (Test)
        function testSourceMismatchPreventsImporterInvocation(testCase)
            source = writeBytes(testCase.TempDir, 'input.bin', uint8(1:8));
            spy = pf2_base.tests.fixtures.IdentityImportSpy(sampleProjection());
            wrong = ['sha256:' repmat('0', 1, 64)];

            testCase.verifyError(@() pf2_base.identity.preflightImport( ...
                @() spy.invoke(), {source}, @(data) data, ...
                'LogicalNames', {'input.bin'}, ...
                'ExpectedSource', wrong), ...
                'pf2:identity:fingerprintMismatch');
            testCase.verifyEqual(spy.CallCount, 0, ...
                'The importer ran before source identity was verified.');
        end

        function testImportedMismatchStopsAfterOneImport(testCase)
            source = writeBytes(testCase.TempDir, 'input.bin', uint8(1:8));
            spy = pf2_base.tests.fixtures.IdentityImportSpy(sampleProjection());
            wrong = ['sha256:' repmat('0', 1, 64)];

            testCase.verifyError(@() pf2_base.identity.preflightImport( ...
                @() spy.invoke(), {source}, @(data) data, ...
                'LogicalNames', {'input.bin'}, ...
                'ExpectedImported', wrong), ...
                'pf2:identity:fingerprintMismatch');
            testCase.verifyEqual(spy.CallCount, 1, ...
                'Imported identity must be checked after exactly one import.');
        end

        function testMatchingExpectationsReturnIdentityEnvelope(testCase)
            source = writeBytes(testCase.TempDir, 'input.bin', uint8(1:8));
            data = sampleProjection();
            sourceIdentity = pf2_base.identity.sourceFingerprint({source}, ...
                'LogicalNames', {'input.bin'});
            importedIdentity = ...
                pf2_base.identity.importedContentFingerprint(data);
            spy = pf2_base.tests.fixtures.IdentityImportSpy(data);

            [actual, identity] = pf2_base.identity.preflightImport( ...
                @() spy.invoke(), {source}, @(value) value, ...
                'LogicalNames', {'input.bin'}, ...
                'ExpectedSource', sourceIdentity, ...
                'ExpectedImported', importedIdentity);

            testCase.verifyEqual(actual, data);
            testCase.verifyEqual(spy.CallCount, 1);
            testCase.verifyEqual(identity.source.digest, sourceIdentity.digest);
            testCase.verifyEqual(identity.imported.digest, importedIdentity.digest);
            testCase.verifyEqual(identity.sourceValidation.status, 'matched');
            testCase.verifyEqual(identity.importedValidation.status, 'matched');
        end

        function testSourceMutationDuringImportFails(testCase)
            source = writeBytes(testCase.TempDir, 'input.bin', uint8(1:8));
            spy = pf2_base.tests.fixtures.IdentityImportSpy(sampleProjection());
            spy.OnRun = @() overwriteBytes(source, uint8(2:9));

            testCase.verifyError(@() pf2_base.identity.preflightImport( ...
                @() spy.invoke(), {source}, @(data) data, ...
                'LogicalNames', {'input.bin'}), ...
                'pf2:identity:fingerprintMismatch');
            testCase.verifyEqual(spy.CallCount, 1);
        end

        function testInMemoryInputStillGetsImportedFingerprint(testCase)
            data = sampleProjection();
            spy = pf2_base.tests.fixtures.IdentityImportSpy(data);

            [~, identity] = pf2_base.identity.preflightImport( ...
                @() spy.invoke(), {}, @(value) value);

            testCase.verifyFalse(identity.source.available);
            testCase.verifyEqual(identity.source.reason, ...
                'no-stable-byte-source');
            testCase.verifyTrue(startsWith(string(identity.imported.digest), ...
                "sha256:"));
            testCase.verifyEqual(spy.CallCount, 1);
        end

        function testExpectedSourceCannotBeVerifiedForInMemoryInput(testCase)
            spy = pf2_base.tests.fixtures.IdentityImportSpy(sampleProjection());
            expected = ['sha256:' repmat('0', 1, 64)];

            testCase.verifyError(@() pf2_base.identity.preflightImport( ...
                @() spy.invoke(), {}, @(value) value, ...
                'ExpectedSource', expected), ...
                'pf2:identity:sourceUnavailable');
            testCase.verifyEqual(spy.CallCount, 0);
        end

        function testEmptyStringSourceExpectationMeansNotRequested(testCase)
            spy = pf2_base.tests.fixtures.IdentityImportSpy(sampleProjection());

            [~, identity] = pf2_base.identity.preflightImport( ...
                @() spy.invoke(), {}, @(value) value, ...
                'ExpectedSource', "");

            testCase.verifyEqual(identity.sourceValidation.status, 'unavailable');
            testCase.verifyEqual(spy.CallCount, 1);
        end

        function testImportedScientificMutationChangesDigest(testCase)
            original = sampleProjection();
            changed = original;
            changed.raw(2, 2) = changed.raw(2, 2) + eps(changed.raw(2, 2));

            first = pf2_base.identity.importedContentFingerprint(original);
            second = pf2_base.identity.importedContentFingerprint(changed);
            testCase.verifyNotEqual(first.digest, second.digest);
        end

        function testImportedFingerprintAllowsCanonicalNaN(testCase)
            projection = sampleProjection();
            projection.raw(1) = NaN;

            identity = pf2_base.identity.importedContentFingerprint(projection);
            testCase.verifyTrue(startsWith(string(identity.digest), "sha256:"));
            testCase.verifyError(@() ...
                pf2_base.identity.importedContentFingerprint(projection, ...
                    'AllowNonFinite', false), ...
                'pf2:identity:nonFinite');
        end
    end
end

function data = sampleProjection()
    data = struct();
    data.raw = reshape(1:12, [4 3]);
    data.time = (0:3).';
    data.fs = 1;
    data.fchMask = logical([1 1 0]);
    data.channels = uint16([1 2 3]);
    data.units = 'intensity';
end

function path = writeBytes(root, name, bytes)
    path = fullfile(root, name);
    overwriteBytes(path, bytes);
end

function overwriteBytes(path, bytes)
    fid = fopen(path, 'wb');
    if fid < 0
        error('pf2:tests:identity:cannotCreateFixture', ...
            'Could not write temporary fixture %s.', path);
    end
    cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
    fwrite(fid, bytes, 'uint8');
end
