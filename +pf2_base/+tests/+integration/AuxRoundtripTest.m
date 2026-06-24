classdef AuxRoundtripTest < matlab.unittest.TestCase
    % AUXROUNDTRIPTEST Derived auxiliary features survive SNIRF export/import
    %
    % Verifies that a derived feature written via pf2.data.aux.addFeature
    % round-trips through pf2.export.asSNIRF -> pf2.import.importSNIRF with its
    % samples, time base, and unit intact.
    %
    % Run all tests:
    %   results = runtests('pf2_base.tests.integration.AuxRoundtripTest');

    properties
        proc   % processed sample data with a derived HR feature
        hr     % the planted HR series
    end

    methods (TestClassSetup)
        function build(testCase)
            warning('off', 'all');
            d = pf2.import.sampleData();
            p = processFNIRS2(d);
            testCase.hr = 70 + 5*sin(2*pi*0.1*p.time);
            testCase.proc = pf2.data.aux.addFeature(p, 'heartRate', testCase.hr, ...
                'Unit', 'bpm');
        end
    end

    methods (Test)
        function testAddFeatureTypesSignal(testCase)
            sig = testCase.proc.Aux.heartRate;
            testCase.verifyEqual(sig.type, 'HR');
            testCase.verifyEqual(sig.unit, 'bpm');
            testCase.verifyEqual(numel(sig.varNames), 1);
        end

        function testDerivedFeatureSnirfRoundtrip(testCase)
            tmp = [tempname '.snirf'];
            c = onCleanup(@() deleteIfExists(tmp));
            pf2.export.asSNIRF(testCase.proc, tmp);
            re = pf2.import.importSNIRF(tmp, false);

            testCase.verifyTrue(isfield(re.Aux, 'heartRate'), ...
                'Derived HR feature should survive the SNIRF round-trip');
            rv = re.Aux.heartRate;
            testCase.verifyEqual(rv.data(:), testCase.hr(:), 'AbsTol', 1e-9);
            testCase.verifyEqual(numel(rv.time), numel(testCase.hr));
            testCase.verifyEqual(char(string(rv.unit)), 'bpm');
        end
    end
end

function deleteIfExists(f)
    if exist(f, 'file'), delete(f); end
end
