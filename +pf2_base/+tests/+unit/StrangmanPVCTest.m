classdef StrangmanPVCTest < matlab.unittest.TestCase
    % STRANGMANPVCTEST Unit tests for the Strangman 2014 PVC / sensitivity model
    %
    %   Verifies pf2_base.fnirs.strangmanPVC returns PVC = 1/sensitivity from
    %   the Colin27 Monte Carlo tables (per-location lookup, scalp/skull
    %   regression, head-wide default), with correct separation dependence and
    %   input validation.
    %
    %   Example:
    %       results = runtests('pf2_base.tests.unit.StrangmanPVCTest');
    %
    %   See also: pf2_base.fnirs.strangmanPVC, pf2_base.fnirs.bvoxy

    methods (Test)
        function locationLookupMatchesTable(testCase)
            % C3 at 30 mm has tabulated sensitivity 0.136 -> PVC = 1/0.136.
            [pvc, s] = pf2_base.fnirs.strangmanPVC(30, 'Location', 'C3');
            testCase.verifyEqual(s, 0.136, 'AbsTol', 1e-9);
            testCase.verifyEqual(pvc, 1/0.136, 'RelTol', 1e-9);
            % O1 at 20 mm -> 0.139
            [~, s2] = pf2_base.fnirs.strangmanPVC(20, 'Location', 'O1');
            testCase.verifyEqual(s2, 0.139, 'AbsTol', 1e-9);
        end

        function pvcIsReciprocalOfSensitivity(testCase)
            [pvc, s] = pf2_base.fnirs.strangmanPVC(30);
            testCase.verifyEqual(pvc, 1/s, 'RelTol', 1e-12);
            testCase.verifyGreaterThan(pvc, 1);            % sensitivity < 1
            testCase.verifyGreaterThan(s, 0);
            testCase.verifyLessThan(s, 1);
        end

        function sensitivityRisesWithSeparation(testCase)
            % For C3, sensitivity increases (PVC decreases) from 20 to 50 mm.
            [~, s20] = pf2_base.fnirs.strangmanPVC(20, 'Location', 'C3');
            [~, s50] = pf2_base.fnirs.strangmanPVC(50, 'Location', 'C3');
            testCase.verifyGreaterThan(s50, s20);
        end

        function scalpSkullRegression(testCase)
            [pvc, s, pplGM] = pf2_base.fnirs.strangmanPVC(30, 'Scalp', 4, 'Skull', 5);
            testCase.verifyGreaterThan(s, 0);
            testCase.verifyLessThan(s, 1);
            testCase.verifyEqual(pvc, 1/s, 'RelTol', 1e-12);
            % Absolute gray-matter partial pathlength (mm) is positive and finite
            testCase.verifyGreaterThan(pplGM, 0);
            testCase.verifyTrue(isfinite(pplGM));
        end

        function pplGMNaNWithoutThickness(testCase)
            [~, ~, pplGM] = pf2_base.fnirs.strangmanPVC(30, 'Location', 'C3');
            testCase.verifyTrue(isnan(pplGM));
        end

        function unknownLocationErrors(testCase)
            testCase.verifyError(@() pf2_base.fnirs.strangmanPVC(30, 'Location', 'ZZ9'), ...
                'pf2_base:fnirs:strangmanPVC:unknownLocation');
        end

        function extrapolationWarns(testCase)
            testCase.verifyWarning(@() pf2_base.fnirs.strangmanPVC(65), ...
                'pf2_base:fnirs:strangmanPVC:extrapolate');
        end

        function headWidePVCInPlausibleRange(testCase)
            % A conventional 30 mm channel should give PVC roughly 6-12.
            pvc = pf2_base.fnirs.strangmanPVC(30);
            testCase.verifyGreaterThan(pvc, 5);
            testCase.verifyLessThan(pvc, 13);
        end
    end
end
