classdef AddFeatureTest < matlab.unittest.TestCase
    % ADDFEATURETEST Unit tests for pf2.data.aux.addFeature
    %
    % Verifies a derived signal is stored as a typed Aux signal, with Time /
    % VarNames overrides, multichannel labels, and the flattened-Aux warning.
    %
    % Run all tests:
    %   results = runtests('pf2_base.tests.unit.AddFeatureTest');

    methods (Test)
        function testDefaults(testCase)
            d.time = (0:0.1:9.9)';
            hr = 70 + sin(d.time);
            d = pf2.data.aux.addFeature(d, 'heartRate', hr);
            testCase.verifyEqual(d.Aux.heartRate.type, 'HR');
            testCase.verifyEqual(d.Aux.heartRate.unit, 'bpm');     % from type
            testCase.verifyEqual(d.Aux.heartRate.time, d.time);
        end

        function testTimeAndVarNames(testCase)
            d.time = (0:0.1:9.9)';
            tFeat = (0:0.05:9.95)';                % different grid
            vals = [sin(tFeat), cos(tFeat)];
            d = pf2.data.aux.addFeature(d, 'custom', vals, ...
                'Time', tFeat, 'Unit', 'au', 'VarNames', {'a', 'b'});
            testCase.verifyEqual(d.Aux.custom.time, tFeat);
            testCase.verifyEqual(d.Aux.custom.unit, 'au');
            testCase.verifyEqual(d.Aux.custom.varNames, {'a', 'b'});
            testCase.verifyEqual(size(d.Aux.custom.data, 2), 2);
        end

        function testNoTimeErrors(testCase)
            d.time = [];
            testCase.verifyError(@() pf2.data.aux.addFeature(d, 'x', (1:10)'), ...
                'pf2:addFeature:noTime');
        end

        function testFlattenedAuxWarns(testCase)
            d.time = (0:0.1:9.9)';
            d.Aux.flattened = true;
            testCase.verifyWarning(@() pf2.data.aux.addFeature(d, 'heartRate', ...
                70 + sin(d.time)), 'pf2:addFeature:flattenedAux');
        end
    end
end
