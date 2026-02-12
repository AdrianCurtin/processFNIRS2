classdef WaveletResolveTest < matlab.unittest.TestCase
% WAVELETRESOLVETEST Unit tests for pf2_base.wavelet.resolveWavelet
%
% Validates that wavelet shorthand names resolve to the correct
% MakeONFilter outputs and MATLAB Wavelet Toolbox names.

    methods (Test)

        %% --- Daubechies family ---

        function testDb2(testCase)
            [qmf, wn, desc] = pf2_base.wavelet.resolveWavelet('db2');
            expected = MakeONFilter('Daubechies', 4);
            testCase.verifyEqual(qmf, expected, 'AbsTol', 1e-12);
            testCase.verifyEqual(wn, 'db2');
            testCase.verifySubstring(desc, 'Daubechies');
        end

        function testDb4(testCase)
            [qmf, wn, ~] = pf2_base.wavelet.resolveWavelet('db4');
            expected = MakeONFilter('Daubechies', 8);
            testCase.verifyEqual(qmf, expected, 'AbsTol', 1e-12);
            testCase.verifyEqual(wn, 'db4');
        end

        function testDb6(testCase)
            [qmf, wn, ~] = pf2_base.wavelet.resolveWavelet('db6');
            expected = MakeONFilter('Daubechies', 12);
            testCase.verifyEqual(qmf, expected, 'AbsTol', 1e-12);
            testCase.verifyEqual(wn, 'db6');
        end

        function testDb10(testCase)
            [qmf, wn, ~] = pf2_base.wavelet.resolveWavelet('db10');
            expected = MakeONFilter('Daubechies', 20);
            testCase.verifyEqual(qmf, expected, 'AbsTol', 1e-12);
            testCase.verifyEqual(wn, 'db10');
        end

        function testAllDaubechies(testCase)
            for vm = 2:10
                [qmf, ~, ~] = pf2_base.wavelet.resolveWavelet(sprintf('db%d', vm));
                expected = MakeONFilter('Daubechies', vm*2);
                testCase.verifyEqual(qmf, expected, 'AbsTol', 1e-12);
            end
        end

        %% --- Symmlet family ---

        function testSym4(testCase)
            [qmf, wn, ~] = pf2_base.wavelet.resolveWavelet('sym4');
            expected = MakeONFilter('Symmlet', 4);
            testCase.verifyEqual(qmf, expected, 'AbsTol', 1e-12);
            testCase.verifyEqual(wn, 'sym4');
        end

        function testSym8(testCase)
            [qmf, wn, ~] = pf2_base.wavelet.resolveWavelet('sym8');
            expected = MakeONFilter('Symmlet', 8);
            testCase.verifyEqual(qmf, expected, 'AbsTol', 1e-12);
            testCase.verifyEqual(wn, 'sym8');
        end

        function testAllSymmlets(testCase)
            for par = 4:10
                [qmf, ~, ~] = pf2_base.wavelet.resolveWavelet(sprintf('sym%d', par));
                expected = MakeONFilter('Symmlet', par);
                testCase.verifyEqual(qmf, expected, 'AbsTol', 1e-12);
            end
        end

        %% --- Coiflet family ---

        function testCoif1(testCase)
            [qmf, wn, ~] = pf2_base.wavelet.resolveWavelet('coif1');
            expected = MakeONFilter('Coiflet', 1);
            testCase.verifyEqual(qmf, expected, 'AbsTol', 1e-12);
            testCase.verifyEqual(wn, 'coif1');
        end

        function testCoif3(testCase)
            [qmf, wn, desc] = pf2_base.wavelet.resolveWavelet('coif3');
            expected = MakeONFilter('Coiflet', 3);
            testCase.verifyEqual(qmf, expected, 'AbsTol', 1e-12);
            testCase.verifyEqual(wn, 'coif3');
            testCase.verifySubstring(desc, 'Coiflet');
        end

        function testAllCoiflets(testCase)
            for par = 1:5
                [qmf, ~, ~] = pf2_base.wavelet.resolveWavelet(sprintf('coif%d', par));
                expected = MakeONFilter('Coiflet', par);
                testCase.verifyEqual(qmf, expected, 'AbsTol', 1e-12);
            end
        end

        %% --- Haar ---

        function testHaar(testCase)
            [qmf, wn, desc] = pf2_base.wavelet.resolveWavelet('haar');
            expected = MakeONFilter('Haar');
            testCase.verifyEqual(qmf, expected, 'AbsTol', 1e-12);
            testCase.verifyEqual(wn, 'haar');
            testCase.verifySubstring(desc, 'Haar');
        end

        %% --- Beylkin ---

        function testBeylkin(testCase)
            [qmf, wn, ~] = pf2_base.wavelet.resolveWavelet('beylkin');
            expected = MakeONFilter('Beylkin');
            testCase.verifyEqual(qmf, expected, 'AbsTol', 1e-12);
            testCase.verifyEqual(wn, '');
        end

        %% --- Vaidyanathan ---

        function testVaidyanathan(testCase)
            [qmf, wn, ~] = pf2_base.wavelet.resolveWavelet('vaidyanathan');
            expected = MakeONFilter('Vaidyanathan');
            testCase.verifyEqual(qmf, expected, 'AbsTol', 1e-12);
            testCase.verifyEqual(wn, '');
        end

        %% --- Battle-Lemarie ---

        function testBattle1(testCase)
            [qmf, wn, ~] = pf2_base.wavelet.resolveWavelet('battle1');
            expected = MakeONFilter('Battle', 1);
            testCase.verifyEqual(qmf, expected, 'AbsTol', 1e-12);
            testCase.verifyEqual(wn, '');
        end

        function testBattle3(testCase)
            [qmf, ~, ~] = pf2_base.wavelet.resolveWavelet('battle3');
            expected = MakeONFilter('Battle', 3);
            testCase.verifyEqual(qmf, expected, 'AbsTol', 1e-12);
        end

        function testBattle5(testCase)
            [qmf, ~, desc] = pf2_base.wavelet.resolveWavelet('battle5');
            expected = MakeONFilter('Battle', 5);
            testCase.verifyEqual(qmf, expected, 'AbsTol', 1e-12);
            testCase.verifySubstring(desc, 'Battle');
        end

        %% --- Case insensitivity ---

        function testCaseInsensitive(testCase)
            [qmf1, ~, ~] = pf2_base.wavelet.resolveWavelet('DB4');
            [qmf2, ~, ~] = pf2_base.wavelet.resolveWavelet('db4');
            testCase.verifyEqual(qmf1, qmf2, 'AbsTol', 1e-12);
        end

        function testCaseInsensitiveHaar(testCase)
            [qmf1, ~, ~] = pf2_base.wavelet.resolveWavelet('HAAR');
            [qmf2, ~, ~] = pf2_base.wavelet.resolveWavelet('haar');
            testCase.verifyEqual(qmf1, qmf2, 'AbsTol', 1e-12);
        end

        function testCaseInsensitiveBeylkin(testCase)
            [qmf1, ~, ~] = pf2_base.wavelet.resolveWavelet('BEYLKIN');
            [qmf2, ~, ~] = pf2_base.wavelet.resolveWavelet('beylkin');
            testCase.verifyEqual(qmf1, qmf2, 'AbsTol', 1e-12);
        end

        function testWhitespaceHandling(testCase)
            [qmf1, ~, ~] = pf2_base.wavelet.resolveWavelet('  db4  ');
            [qmf2, ~, ~] = pf2_base.wavelet.resolveWavelet('db4');
            testCase.verifyEqual(qmf1, qmf2, 'AbsTol', 1e-12);
        end

        %% --- Error cases ---

        function testInvalidName(testCase)
            testCase.verifyError(@() pf2_base.wavelet.resolveWavelet('invalid'), ...
                'pf2_base:wavelet:unknownWavelet');
        end

        function testInvalidDaubechies(testCase)
            testCase.verifyError(@() pf2_base.wavelet.resolveWavelet('db1'), ...
                'pf2_base:wavelet:invalidWavelet');
        end

        function testInvalidSymmlet(testCase)
            testCase.verifyError(@() pf2_base.wavelet.resolveWavelet('sym3'), ...
                'pf2_base:wavelet:invalidWavelet');
        end

        function testInvalidCoiflet(testCase)
            testCase.verifyError(@() pf2_base.wavelet.resolveWavelet('coif6'), ...
                'pf2_base:wavelet:invalidWavelet');
        end

        function testInvalidBattle(testCase)
            testCase.verifyError(@() pf2_base.wavelet.resolveWavelet('battle2'), ...
                'pf2_base:wavelet:invalidWavelet');
        end

        function testEmptyString(testCase)
            testCase.verifyError(@() pf2_base.wavelet.resolveWavelet(''), ...
                'pf2_base:wavelet:unknownWavelet');
        end

        %% --- Filter output shape ---

        function testFilterIsRowVector(testCase)
            [qmf, ~, ~] = pf2_base.wavelet.resolveWavelet('db4');
            testCase.verifyEqual(size(qmf, 1), 1, 'QMF filter should be a row vector');
            testCase.verifyGreaterThan(size(qmf, 2), 1, 'QMF filter should have multiple coefficients');
        end

        function testFilterLengthDb(testCase)
            % Daubechies filter length = Par (= 2*vanishing_moments)
            [qmf, ~, ~] = pf2_base.wavelet.resolveWavelet('db4');
            testCase.verifyEqual(length(qmf), 8);
        end

    end
end
