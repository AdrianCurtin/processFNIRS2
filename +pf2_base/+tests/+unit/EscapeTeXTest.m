classdef EscapeTeXTest < matlab.unittest.TestCase
%ESCAPETEXTEST Unit tests for pf2_base.plot.escapeTeX

    methods (Test)

        function testCharSingleUnderscore(testCase)
            testCase.verifyEqual(pf2_base.plot.escapeTeX('DLPFC_L'), 'DLPFC\_L');
        end

        function testCharMultipleUnderscores(testCase)
            testCase.verifyEqual(pf2_base.plot.escapeTeX('a_b_c_d'), 'a\_b\_c\_d');
        end

        function testCharNoUnderscore(testCase)
            testCase.verifyEqual(pf2_base.plot.escapeTeX('hello'), 'hello');
        end

        function testCharEmpty(testCase)
            testCase.verifyEqual(pf2_base.plot.escapeTeX(''), '');
        end

        function testCharAlreadyEscaped(testCase)
            testCase.verifyEqual(pf2_base.plot.escapeTeX('already\_ok'), 'already\_ok');
        end

        function testCharMixedEscaped(testCase)
            testCase.verifyEqual(pf2_base.plot.escapeTeX('a\_b_c'), 'a\_b\_c');
        end

        function testStringSingleUnderscore(testCase)
            testCase.verifyEqual(pf2_base.plot.escapeTeX("DLPFC_L"), "DLPFC\_L");
        end

        function testStringMultiple(testCase)
            testCase.verifyEqual(pf2_base.plot.escapeTeX("a_b_c"), "a\_b\_c");
        end

        function testStringEmpty(testCase)
            testCase.verifyEqual(pf2_base.plot.escapeTeX(""), "");
        end

        function testStringAlreadyEscaped(testCase)
            testCase.verifyEqual(pf2_base.plot.escapeTeX("ok\_fine"), "ok\_fine");
        end

        function testCellArray(testCase)
            in  = {'a_b', 'c_d', 'no'};
            exp = {'a\_b', 'c\_d', 'no'};
            testCase.verifyEqual(pf2_base.plot.escapeTeX(in), exp);
        end

        function testCellArrayEmpty(testCase)
            testCase.verifyEqual(pf2_base.plot.escapeTeX({}), {});
        end

        function testCellArrayMixed(testCase)
            in  = {'a\_b', 'c_d'};
            exp = {'a\_b', 'c\_d'};
            testCase.verifyEqual(pf2_base.plot.escapeTeX(in), exp);
        end

        function testNumericPassthrough(testCase)
            testCase.verifyEqual(pf2_base.plot.escapeTeX(42), 42);
        end

        function testLeadingUnderscore(testCase)
            testCase.verifyEqual(pf2_base.plot.escapeTeX('_start'), '\_start');
        end

        function testTrailingUnderscore(testCase)
            testCase.verifyEqual(pf2_base.plot.escapeTeX('end_'), 'end\_');
        end

        function testConsecutiveUnderscores(testCase)
            testCase.verifyEqual(pf2_base.plot.escapeTeX('a__b'), 'a\_\_b');
        end

    end
end
