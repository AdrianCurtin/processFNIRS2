classdef IdentityTransportRoundtripTest < matlab.unittest.TestCase
%IDENTITYTRANSPORTROUNDTRIPTEST Phase-0 MAT/JSON identity proof spike.

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
        function testCanonicalLanguageRoundTripsLosslessly(testCase)
            missingScalar = string(missing);
            value = struct( ...
                'uint64Value', intmax('uint64'), ...
                'singleMatrix', reshape(single([0.1 0.2 0.3 0.4]), [2 2]), ...
                'logicalColumn', logical([1; 0]), ...
                'shapedEmpty', zeros(0, 2, 'int16'), ...
                'cellValue', {{uint8(1), 'two'}}, ...
                'strings', ["", missingScalar, "near infrared"]);

            json = pf2_base.identity.encodeJsonTransport(value);
            decoded = pf2_base.identity.decodeJsonTransport(json);

            testCase.verifyEqual(canonical(decoded), canonical(value));
            testCase.verifyClass(decoded.uint64Value, 'uint64');
            testCase.verifyClass(decoded.singleMatrix, 'single');
            testCase.verifySize(decoded.shapedEmpty, [0 2]);
            testCase.verifyTrue(ismissing(decoded.strings(2)));
            testCase.verifyEqual(decoded.strings(1), "");
        end

        function testCompactAndPrettyJsonHaveOneSemanticIdentity(testCase)
            recipe = pf2_base.tests.fixtures.identityRecipeSpike();
            compact = pf2_base.identity.encodeJsonTransport(recipe);
            pretty = pf2_base.identity.encodeJsonTransport(recipe, ...
                'PrettyPrint', true);

            testCase.verifyNotEqual(compact, pretty);
            compactRecipe = pf2_base.identity.decodeJsonTransport(compact);
            prettyRecipe = pf2_base.identity.decodeJsonTransport(pretty);
            testCase.verifyEqual(recipeHash(compactRecipe), ...
                recipeHash(prettyRecipe));
            testCase.verifyEqual(recipeHash(compactRecipe), recipeHash(recipe));
        end

        function testPermittedNonFiniteValuesRoundTripCanonically(testCase)
            value = [NaN, Inf, -Inf];

            testCase.verifyError(@() ...
                pf2_base.identity.encodeJsonTransport(value), ...
                'pf2:identity:nonFinite');
            json = pf2_base.identity.encodeJsonTransport(value, ...
                'AllowNonFinite', true);
            decoded = pf2_base.identity.decodeJsonTransport(json);
            testCase.verifyEqual( ...
                pf2_base.identity.canonicalBytes(decoded, ...
                    'AllowNonFinite', true), ...
                pf2_base.identity.canonicalBytes(value, ...
                    'AllowNonFinite', true));
        end

        function testSignedZeroRoundTripsThroughJsonAsPositiveZero(testCase)
            % Negative zero is finite, so it must round-trip through the
            % default JSON transport with no AllowNonFinite escape and
            % normalize to +0, mirroring canonicalBytes' signed-zero
            % contract. This is deliberately separate from the non-finite
            % path above, where -0 was previously (and misleadingly) bundled
            % in with NaN/Inf despite being finite.
            negativeZero = typecast(bitshift(uint64(1), 63), 'double');
            testCase.assertEqual(negativeZero, 0);

            json = pf2_base.identity.encodeJsonTransport(negativeZero);
            decoded = pf2_base.identity.decodeJsonTransport(json);

            testCase.verifyEqual( ...
                pf2_base.identity.canonicalBytes(decoded), ...
                pf2_base.identity.canonicalBytes(0.0));
        end

        function testMatAndJsonRoundTripToSameRecipeHash(testCase)
            artifact = pf2_base.tests.fixtures.identityRecipeSpike(); %#ok<NASGU>
            compressedPath = fullfile(testCase.TempDir, 'compressed.mat');
            plainPath = fullfile(testCase.TempDir, 'plain.mat');
            save(compressedPath, 'artifact', '-v7');
            save(plainPath, 'artifact', '-v7', '-nocompression');

            fromCompressed = load(compressedPath, 'artifact');
            fromPlain = load(plainPath, 'artifact');
            fromJson = pf2_base.identity.decodeJsonTransport( ...
                pf2_base.identity.encodeJsonTransport(artifact));

            expected = recipeHash(artifact);
            testCase.verifyEqual(recipeHash(fromCompressed.artifact), expected);
            testCase.verifyEqual(recipeHash(fromPlain.artifact), expected);
            testCase.verifyEqual(recipeHash(fromJson), expected);
            testCase.verifyEqual(canonical(fromCompressed.artifact), ...
                canonical(fromJson));
        end

        function testAuthorshipAndDisplayMetadataAreOutsideScientificHash(testCase)
            recipe = pf2_base.tests.fixtures.identityRecipeSpike();
            changed = recipe;
            changed.artifactId = 'different-draft-id';
            changed.displayName = 'Different display name';
            changed.authoredFrom.rawName = 'renamed-origin';
            changed.authoringDelta{end + 1} = 'GUI-only note';
            changed.citations = {'Different descriptive citation text'};

            testCase.verifyNotEqual(canonical(recipe), canonical(changed));
            testCase.verifyEqual(recipeHash(recipe), recipeHash(changed));
        end

        function testScientificMutationsChangeHash(testCase)
            recipe = pf2_base.tests.fixtures.identityRecipeSpike();
            variants = cell(1, 6);
            variants{1} = recipe;
            variants{1}.scientific.context.fixedDpf = 6.0;
            variants{2} = recipe;
            variants{2}.scientific.rawSteps = flipud( ...
                variants{2}.scientific.rawSteps);
            variants{3} = recipe;
            variants{3}.scientific.oxySteps.parameters.value = 0.11;
            variants{4} = recipe;
            variants{4}.scientific.oxySteps.parameters.unit = 'rad/s';
            variants{5} = recipe;
            variants{5}.scientific.qcPolicy.enabled = false;
            variants{6} = recipe;
            variants{6}.scientific.inputContract.wavelengthsNm(2) = uint16(850);

            original = recipeHash(recipe);
            for i = 1:numel(variants)
                testCase.verifyNotEqual(recipeHash(variants{i}), original, ...
                    sprintf('Scientific mutation %d did not change identity.', i));
            end
        end

        function testInvalidOrTamperedJsonFailsClosed(testCase)
            recipe = pf2_base.tests.fixtures.identityRecipeSpike();
            json = pf2_base.identity.encodeJsonTransport(recipe);
            decoded = jsondecode(json);
            decoded.format = 'unknown-format';

            testCase.verifyError(@() ...
                pf2_base.identity.decodeJsonTransport(jsonencode(decoded)), ...
                'pf2:identity:invalidJsonTransport');
            testCase.verifyError(@() ...
                pf2_base.identity.decodeJsonTransport('{"format":"pf2-canonical-json-v1"}'), ...
                'pf2:identity:invalidJsonTransport');
        end
    end
end

function bytes = canonical(value)
    bytes = pf2_base.identity.canonicalBytes(value);
end

function digest = recipeHash(recipe)
    digest = pf2_base.identity.hashProjection(recipe.scientific, ...
        'ArtifactKind', 'pf2.processing.recipe', ...
        'SchemaVersion', recipe.schemaVersion, ...
        'Projection', 'scientific-content-v1');
end
