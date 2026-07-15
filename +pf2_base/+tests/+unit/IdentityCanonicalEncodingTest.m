classdef IdentityCanonicalEncodingTest < matlab.unittest.TestCase
% IDENTITYCANONICALENCODINGTEST Contract tests for canonical identity bytes.
%
% These tests deliberately exercise semantic properties rather than MAT or
% JSON transport bytes.  The encoder receives an already schema-normalized
% value and must produce release- and platform-independent bytes.
%
% Run with:
%   runtests('pf2_base.tests.unit.IdentityCanonicalEncodingTest')
%
% See also: pf2_base.identity.canonicalBytes

    methods (Test)
        function testReturnsBytes(testCase)
            bytes = pf2_base.identity.canonicalBytes(struct('value', 1));

            testCase.verifyClass(bytes, 'uint8');
            testCase.verifyNotEmpty(bytes);
        end

        function testKnownCanonicalVector(testCase)
            % pf2-canonical-binary-v1: profile header, UINT8 tag, framed
            % payload length, [1 x 1] dimensions, then scalar value 42.
            expectedHex = [ ...
                '5046322d43414e4f4e4943414c0001' ...
                '13' ...
                '0000000000000019' ...
                '0000000000000002' ...
                '0000000000000001' ...
                '0000000000000001' ...
                '2a'];
            expected = uint8(sscanf(expectedHex, '%2x').');

            testCase.verifyEqual(encode(uint8(42)), expected);
        end

        function testFieldOrderIsInsignificant(testCase)
            first = struct();
            first.zeta = uint16(2);
            first.alpha = 'near infrared';
            first.nested = struct('right', true, 'left', single(0.5));

            second = struct();
            second.nested = struct('left', single(0.5), 'right', true);
            second.alpha = 'near infrared';
            second.zeta = uint16(2);

            testCase.verifyEqual(encode(first), encode(second));
        end

        function testArrayOrderAndShapeAreSignificant(testCase)
            row = uint16([1 2 3]);
            column = row.';
            reordered = uint16([1 3 2]);

            testCase.verifyNotEqual(encode(row), encode(column));
            testCase.verifyNotEqual(encode(row), encode(reordered));
            testCase.verifyNotEqual(encode(reshape(1:6, [1 2 3])), ...
                encode(reshape(1:6, [1 3 2])));
        end

        function testCellShapeIsSignificant(testCase)
            row = {uint8(1), 'two'};
            column = row.';

            testCase.verifyNotEqual(encode(row), encode(column));
        end

        function testStringArrayShapeAndContentAreSignificant(testCase)
            row = ["one", "two"];
            column = row.';
            changed = ["one", "too"];

            testCase.verifyNotEqual(encode(row), encode(column));
            testCase.verifyNotEqual(encode(row), encode(changed));
        end

        function testMissingAndEmptyStringsAreDistinct(testCase)
            emptyString = "";
            missingString = string(missing);

            testCase.verifyNotEqual(encode(emptyString), encode(missingString));
            testCase.verifyNotEqual(encode(["", "value"]), ...
                encode([missingString, "value"]));
        end

        function testNumericAndLogicalTypesAreSignificant(testCase)
            values = { ...
                logical(1), uint8(1), int8(1), uint16(1), int16(1), ...
                uint32(1), int32(1), uint64(1), int64(1), ...
                single(1), double(1)};
            encodings = cellfun(@encode, values, 'UniformOutput', false);

            for i = 1:numel(encodings)
                for j = i + 1:numel(encodings)
                    testCase.verifyNotEqual(encodings{i}, encodings{j}, ...
                        sprintf('Types %s and %s were conflated.', ...
                        class(values{i}), class(values{j})));
                end
            end
        end

        function testFiniteBitChangesAreSignificant(testCase)
            testCase.verifyNotEqual(encode(1.0), encode(1.0 + eps(1.0)));
            testCase.verifyNotEqual(encode(single(1.0)), ...
                encode(single(1.0) + eps(single(1.0))));
            testCase.verifyNotEqual(encode(realmin), encode(realmin * eps));
        end

        function testSignedZeroNormalizes(testCase)
            negativeZero = typecast(bitshift(uint64(1), 63), 'double');
            testCase.assertEqual(negativeZero, 0);
            testCase.verifyEqual(encode(0.0), encode(negativeZero));

            negativeZeroSingle = typecast(bitshift(uint32(1), 31), 'single');
            testCase.assertEqual(negativeZeroSingle, single(0));
            testCase.verifyEqual(encode(single(0)), encode(negativeZeroSingle));
        end

        function testNonFiniteRejectedByDefault(testCase)
            testCase.verifyError(@() encode(NaN), 'pf2:identity:nonFinite');
            testCase.verifyError(@() encode(Inf), 'pf2:identity:nonFinite');
            testCase.verifyError(@() encode(-Inf), 'pf2:identity:nonFinite');
        end

        function testAllowedNonFiniteHasCanonicalTokens(testCase)
            quietNaNBits1 = bitor(bitshift(uint64(2047), 52), ...
                bitshift(uint64(1), 51));
            quietNaNBits2 = bitor(quietNaNBits1, uint64(12345));
            nan1 = typecast(quietNaNBits1, 'double');
            nan2 = typecast(quietNaNBits2, 'double');

            first = encode(nan1, 'AllowNonFinite', true);
            second = encode(nan2, 'AllowNonFinite', true);
            positiveInfinity = encode(Inf, 'AllowNonFinite', true);
            negativeInfinity = encode(-Inf, 'AllowNonFinite', true);

            testCase.verifyEqual(first, second, ...
                'NaN payload bits must not enter canonical identity.');
            testCase.verifyNotEqual(first, positiveInfinity);
            testCase.verifyNotEqual(positiveInfinity, negativeInfinity);
        end

        function testTextUsesNFCAndUTF8(testCase)
            composed = char(hex2dec('00E9'));             % e-acute
            decomposed = ['e' char(hex2dec('0301'))];    % e + combining acute
            chinese = char([hex2dec('8FD1'), hex2dec('7EA2'), hex2dec('5916')]);
            japanese = char([hex2dec('8FD1'), hex2dec('8D64'), hex2dec('5916')]);

            testCase.verifyEqual(encode(composed), encode(decomposed));
            testCase.verifyEqual(encode(chinese), encode(string(chinese)));
            testCase.verifyEqual(encode(japanese), encode(string(japanese)));
            testCase.verifyNotEqual(encode(chinese), encode(japanese));
        end

        function testInvalidUnicodeRejected(testCase)
            loneHighSurrogate = char(uint16(hex2dec('D800')));
            testCase.verifyError(@() encode(loneHighSurrogate), ...
                'pf2:identity:invalidText');
        end

        function testEmptyArrayShapesAreDistinct(testCase)
            empty00 = zeros(0, 0, 'uint8');
            empty01 = zeros(0, 1, 'uint8');
            empty10 = zeros(1, 0, 'uint8');

            testCase.verifyNotEqual(encode(empty00), encode(empty01));
            testCase.verifyNotEqual(encode(empty00), encode(empty10));
            testCase.verifyNotEqual(encode(empty01), encode(empty10));
        end

        function testUnsupportedRuntimeTypesFailClosed(testCase)
            unsupported = { ...
                @sin, ...
                table((1:2).'), ...
                sparse(eye(2)), ...
                1 + 2i, ...
                containers.Map({'a'}, {1})};

            for i = 1:numel(unsupported)
                value = unsupported{i};
                testCase.verifyError(@() encode(value), ...
                    'pf2:identity:unsupportedType', ...
                    sprintf('Unsupported class %s did not fail closed.', class(value)));
            end
        end
    end
end

function bytes = encode(value, varargin)
    bytes = pf2_base.identity.canonicalBytes(value, varargin{:});
end
