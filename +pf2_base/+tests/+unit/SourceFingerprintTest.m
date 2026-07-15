classdef SourceFingerprintTest < matlab.unittest.TestCase
% SOURCEFINGERPRINTTEST Contract tests for exact source-byte identity.
%
% Run with:
%   runtests('pf2_base.tests.unit.SourceFingerprintTest')
%
% See also: pf2_base.identity.sha256File,
%           pf2_base.identity.sourceFingerprint

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
        function testSHA256FileMatchesByteHash(testCase)
            path = writeBytes(testCase.TempDir, 'abc.bin', uint8([97 98 99]));
            fromFile = pf2_base.identity.sha256File(path);
            fromBytes = pf2_base.identity.sha256Bytes(uint8([97 98 99]));

            testCase.verifyEqual(fromFile, fromBytes);
        end

        function testSourceFingerprintStructContract(testCase)
            path = writeBytes(testCase.TempDir, 'source.bin', uint8(1:8));
            fp = pf2_base.identity.sourceFingerprint({path}, ...
                'LogicalNames', {'source.bin'});

            testCase.verifyClass(fp, 'struct');
            for field = {'profile', 'algorithm', 'available', 'reason', ...
                    'digest', 'entries'}
                testCase.verifyTrue(isfield(fp, field{1}), ...
                    sprintf('Source fingerprint is missing field %s.', field{1}));
            end
            testCase.verifyEqual(lower(string(fp.algorithm)), "sha256");
            testCase.verifyTrue(fp.available);
            testCase.verifyEqual(fp.reason, '');

            % An available fingerprint must share the unavailable-source field
            % shape so mixed batches concatenate into one struct array.
            unavailable = struct( ...
                'profile', 'pf2.input.source.v1', ...
                'algorithm', 'sha256', ...
                'available', false, ...
                'reason', 'no-stable-byte-source', ...
                'digest', '', ...
                'entries', struct('logicalName', {}, ...
                    'byteLength', {}, 'byteDigest', {}));
            testCase.verifyEqual(numel([fp; unavailable]), 2);
            testCase.verifyTrue(~isempty(regexp(char(string(fp.digest)), ...
                '^sha256:[0-9a-f]{64}$', 'once')));
            testCase.verifyEqual(numel(fp.entries), 1);
            testCase.verifyEqual(fp.entries(1).logicalName, 'source.bin');
            testCase.verifyClass(fp.entries(1).byteLength, 'uint64');
            testCase.verifyEqual(fp.entries(1).byteLength, uint64(8));
            testCase.verifyTrue(~isempty(regexp( ...
                char(string(fp.entries(1).byteDigest)), ...
                '^sha256:[0-9a-f]{64}$', 'once')));
        end

        function testSourceFingerprintGoldenDigest(testCase)
            % Frozen known-answer digest for a fixed file (the NIST "abc"
            % bytes) under a fixed logical name. Anchors the durable
            % source-manifest identity across runs and releases: a silent
            % change to the manifest projection, canonical envelope, or the
            % sha256File/hashProjection wiring rewrites this digest and fails
            % here. The per-file byte digest is independently the published
            % NIST SHA-256("abc") vector, pinning the file-hash layer too.
            path = writeBytes(testCase.TempDir, 'abc.bin', uint8([97 98 99]));
            fp = pf2_base.identity.sourceFingerprint({path}, ...
                'LogicalNames', {'abc.bin'});

            manifestExpected = "sha256:e6e2be00fc87b4748cac18b8a5d8df49" + ...
                "1bd74df5bd42a96a78fea1aafb59cc0f";
            byteExpected = "sha256:ba7816bf8f01cfea414140de5dae2223" + ...
                "b00361a396177a9cb410ff61f20015ad";

            testCase.verifyEqual(string(fp.digest), manifestExpected);
            testCase.verifyEqual(string(fp.entries(1).byteDigest), ...
                byteExpected);
        end

        function testSingleFileSeparatesManifestAndByteDigests(testCase)
            path = writeBytes(testCase.TempDir, 'single.bin', uint8(0:31));
            fp = pf2_base.identity.sourceFingerprint({path}, ...
                'LogicalNames', {'single.bin'});
            rawDigest = pf2_base.identity.sha256File(path);

            testCase.verifyEqual(fp.entries(1).byteDigest, rawDigest);
            testCase.verifyNotEqual(fp.digest, rawDigest);
        end

        function testMultiFileEnumerationOrderIsInsignificant(testCase)
            first = writeBytes(testCase.TempDir, 'physical-a.bin', uint8(1:5));
            second = writeBytes(testCase.TempDir, 'physical-b.bin', uint8(6:10));

            forward = pf2_base.identity.sourceFingerprint({first, second}, ...
                'LogicalNames', {'inputs/a.bin', 'inputs/b.bin'});
            reverse = pf2_base.identity.sourceFingerprint({second, first}, ...
                'LogicalNames', {'inputs/b.bin', 'inputs/a.bin'});

            testCase.verifyEqual(forward.digest, reverse.digest);
            testCase.verifyEqual({forward.entries.logicalName}, ...
                {'inputs/a.bin', 'inputs/b.bin'});
            testCase.verifyEqual({reverse.entries.logicalName}, ...
                {'inputs/a.bin', 'inputs/b.bin'});
        end

        function testPhysicalRootAndModificationTimeAreExcluded(testCase)
            rootA = fullfile(testCase.TempDir, 'root-a');
            rootB = fullfile(testCase.TempDir, 'root-b');
            mkdir(rootA);
            mkdir(rootB);
            bytes = uint8([10 20 30 40]);
            pathA = writeBytes(rootA, 'data.bin', bytes);
            pathB = writeBytes(rootB, 'renamed-physical-file.bin', bytes);

            % Give the second copy deliberately different filesystem metadata.
            try
                javaFile = javaObject('java.io.File', pathB);
                javaFile.setLastModified(javaFile.lastModified() - 60000);
            catch
                % Identity must remain path/metadata independent even in a
                % MATLAB configuration without Java filesystem access.
            end

            first = pf2_base.identity.sourceFingerprint({pathA}, ...
                'LogicalNames', {'dataset/data.bin'});
            relocated = pf2_base.identity.sourceFingerprint({pathB}, ...
                'LogicalNames', {'dataset/data.bin'});

            testCase.verifyEqual(first.digest, relocated.digest);
        end

        function testByteMutationChangesFileAndSourceDigests(testCase)
            path = writeBytes(testCase.TempDir, 'mutable.bin', uint8([1 2 3]));
            beforeFile = pf2_base.identity.sha256File(path);
            beforeSource = pf2_base.identity.sourceFingerprint({path}, ...
                'LogicalNames', {'mutable.bin'});

            writeBytes(testCase.TempDir, 'mutable.bin', uint8([1 2 4]));
            afterFile = pf2_base.identity.sha256File(path);
            afterSource = pf2_base.identity.sourceFingerprint({path}, ...
                'LogicalNames', {'mutable.bin'});

            testCase.verifyNotEqual(beforeFile, afterFile);
            testCase.verifyNotEqual(beforeSource.digest, afterSource.digest);
        end

        function testLogicalNameParticipatesInManifestIdentity(testCase)
            path = writeBytes(testCase.TempDir, 'physical.bin', uint8([4 5 6]));
            first = pf2_base.identity.sourceFingerprint({path}, ...
                'LogicalNames', {'first.bin'});
            renamed = pf2_base.identity.sourceFingerprint({path}, ...
                'LogicalNames', {'renamed.bin'});

            testCase.verifyNotEqual(first.digest, renamed.digest);
        end

        function testLogicalSeparatorsNormalize(testCase)
            path = writeBytes(testCase.TempDir, 'physical.bin', uint8([4 5 6]));
            slash = pf2_base.identity.sourceFingerprint({path}, ...
                'LogicalNames', {'folder/data.bin'});
            backslash = pf2_base.identity.sourceFingerprint({path}, ...
                'LogicalNames', {'folder\data.bin'});

            testCase.verifyEqual(slash.digest, backslash.digest);
        end

        function testDuplicateLogicalNamesRejected(testCase)
            first = writeBytes(testCase.TempDir, 'one.bin', uint8(1));
            second = writeBytes(testCase.TempDir, 'two.bin', uint8(2));

            testCase.verifyError(@() pf2_base.identity.sourceFingerprint( ...
                {first, second}, 'LogicalNames', {'same.bin', 'same.bin'}), ...
                'pf2:identity:duplicateLogicalName');
        end

        function testDuplicateNamesAfterNormalizationRejected(testCase)
            first = writeBytes(testCase.TempDir, 'one.bin', uint8(1));
            second = writeBytes(testCase.TempDir, 'two.bin', uint8(2));

            testCase.verifyError(@() pf2_base.identity.sourceFingerprint( ...
                {first, second}, 'LogicalNames', ...
                {'folder/same.bin', 'folder\same.bin'}), ...
                'pf2:identity:duplicateLogicalName');
        end

        function testLogicalNamesUseUnicodeNFC(testCase)
            path = writeBytes(testCase.TempDir, 'source.bin', uint8(1));
            composed = ['caf' char(hex2dec('00E9')) '.bin'];
            decomposed = ['cafe' char(hex2dec('0301')) '.bin'];
            first = pf2_base.identity.sourceFingerprint({path}, ...
                'LogicalNames', {composed});
            second = pf2_base.identity.sourceFingerprint({path}, ...
                'LogicalNames', {decomposed});

            testCase.verifyEqual(first.digest, second.digest);
        end

        function testInvalidLogicalNamesRejected(testCase)
            path = writeBytes(testCase.TempDir, 'source.bin', uint8(1));
            invalidNames = {'', '/absolute/source.bin', '../source.bin', ...
                'folder/../source.bin', 'C:\absolute\source.bin'};

            for i = 1:numel(invalidNames)
                name = invalidNames{i};
                identifier = captureError(@() ...
                    pf2_base.identity.sourceFingerprint({path}, ...
                    'LogicalNames', {name}));
                testCase.verifyNotEqual(identifier, "", ...
                    sprintf('Invalid logical name "%s" was accepted.', name));
                testCase.verifyTrue(startsWith(identifier, "pf2:identity:"), ...
                    sprintf('Unexpected error identifier for "%s": %s', ...
                    name, identifier));
            end
        end

        function testMissingFileRejected(testCase)
            missing = fullfile(testCase.TempDir, 'does-not-exist.bin');
            testCase.verifyError(@() pf2_base.identity.sha256File(missing), ...
                'pf2:identity:fileNotFound');
            testCase.verifyError(@() pf2_base.identity.sourceFingerprint( ...
                {missing}, 'LogicalNames', {'missing.bin'}), ...
                'pf2:identity:fileNotFound');
        end

        function testPathAndLogicalNameCountsMustMatch(testCase)
            path = writeBytes(testCase.TempDir, 'source.bin', uint8(1));
            identifier = captureError(@() ...
                pf2_base.identity.sourceFingerprint({path}, ...
                'LogicalNames', {'one.bin', 'two.bin'}));

            testCase.verifyNotEqual(identifier, "");
            testCase.verifyTrue(startsWith(identifier, "pf2:identity:"));
        end
    end
end

function path = writeBytes(root, relativePath, bytes)
    path = fullfile(root, relativePath);
    parent = fileparts(path);
    if ~isfolder(parent)
        mkdir(parent);
    end
    fid = fopen(path, 'wb');
    if fid < 0
        error('pf2:tests:identity:cannotCreateFixture', ...
            'Could not create temporary fixture %s.', path);
    end
    cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
    fwrite(fid, bytes, 'uint8');
end

function identifier = captureError(fcn)
    try
        fcn();
        identifier = "";
    catch ME
        identifier = string(ME.identifier);
    end
end
