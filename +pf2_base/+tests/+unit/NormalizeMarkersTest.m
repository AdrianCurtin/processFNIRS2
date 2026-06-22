classdef NormalizeMarkersTest < matlab.unittest.TestCase
    % NORMALIZEMARKERSTEST Unit tests for pf2_base.normalizeMarkers
    %
    % Verifies that marker arrays are correctly normalized into the canonical
    % marker TABLE (variables Time, Code, Duration, Amplitude, plus any extra
    % columns named Data5..DataN), with appropriate defaults (duration=0,
    % amplitude=1).

    methods (Test)
        function testTwoColumnInput(testCase)
            % 2-col input should get duration=0 and amplitude=1
            mrk = [1.0, 50; 2.5, 51];
            result = pf2_base.normalizeMarkers(mrk);

            testCase.verifyTrue(istable(result));
            testCase.verifySize(result, [2, 4]);
            testCase.verifyEqual(result.Time, mrk(:,1));
            testCase.verifyEqual(result.Code, mrk(:,2));
            testCase.verifyEqual(result.Duration, [0; 0], 'Duration should default to 0');
            testCase.verifyEqual(result.Amplitude, [1; 1], 'Amplitude should default to 1');
        end

        function testThreeColumnInput(testCase)
            % 3-col input should get amplitude=1
            mrk = [1.0, 50, 5; 2.5, 51, 10];
            result = pf2_base.normalizeMarkers(mrk);

            testCase.verifyTrue(istable(result));
            testCase.verifySize(result, [2, 4]);
            testCase.verifyEqual(result{:,1:3}, mrk);
            testCase.verifyEqual(result.Amplitude, [1; 1], 'Amplitude should default to 1');
        end

        function testFourColumnPassthrough(testCase)
            % 4-col input should map directly onto the canonical columns
            mrk = [1.0, 50, 5, 0.8; 2.5, 51, 10, 1.5];
            result = pf2_base.normalizeMarkers(mrk);

            testCase.verifyTrue(istable(result));
            testCase.verifyEqual(table2array(result), mrk);
        end

        function testEmptyInput(testCase)
            % Empty input should return zeros(0,4)
            result = pf2_base.normalizeMarkers([]);

            testCase.verifySize(result, [0, 4]);
            testCase.verifyTrue(isempty(result));
        end

        function testAmplitudePreserved(testCase)
            % Custom amplitude values should be preserved
            mrk = [1.0, 50, 0, 2.0; 3.0, 51, 0, 0.5];
            result = pf2_base.normalizeMarkers(mrk);

            testCase.verifyEqual(result.Amplitude, [2.0; 0.5]);
        end

        function testSingleRow(testCase)
            % Single-row marker should work
            result = pf2_base.normalizeMarkers([5.0, 1]);

            testCase.verifyTrue(istable(result));
            testCase.verifySize(result, [1, 4]);
            testCase.verifyEqual(table2array(result), [5.0, 1, 0, 1]);
        end

        function testFiveColumnPassthrough(testCase)
            % 5+ column input: extra column retained as Data5
            mrk = [1.0, 50, 5, 1, 99];
            result = pf2_base.normalizeMarkers(mrk);

            testCase.verifyTrue(istable(result));
            testCase.verifyEqual(table2array(result), mrk);
            testCase.verifyTrue(ismember('Data5', result.Properties.VariableNames));
        end
    end
end
