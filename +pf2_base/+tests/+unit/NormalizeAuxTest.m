classdef NormalizeAuxTest < matlab.unittest.TestCase
    % NORMALIZEAUXTEST Unit tests for pf2_base.normalizeAux
    %
    % Verifies the auxiliary-signal container normalizer: canonical field
    % synthesis (time/varNames/unit/type), field-name synonyms, idempotency,
    % empty handling, table- and numeric-valued signals, multi-signal
    % containers, housekeeping passthrough, and type inference.
    %
    % Run all tests:
    %   results = runtests('pf2_base.tests.unit.NormalizeAuxTest');

    methods (Test)
        function testEmptyReturnsEmpty(testCase)
            testCase.verifyEmpty(pf2_base.normalizeAux([]));
        end

        function testSynthesizesVarNamesAndUnit(testCase)
            aux.heartRate.data = (60:0.1:65)';   % no time/unit/varNames
            out = pf2_base.normalizeAux(aux, 'fs', 10);
            testCase.verifyEqual(out.heartRate.unit, 'bpm');     % from type default
            testCase.verifyEqual(out.heartRate.type, 'HR');
            testCase.verifyEqual(numel(out.heartRate.varNames), 1);
            testCase.verifyEqual(out.heartRate.varNames{1}, 'ch1');
            % time synthesized from fs
            T = numel(out.heartRate.data);
            testCase.verifyEqual(out.heartRate.time, (0:T-1)'/10, 'AbsTol', 1e-12);
        end

        function testPreservesExistingFields(testCase)
            aux.accelerometer.data = randn(50, 3);
            aux.accelerometer.time = (0:49)' / 25;
            aux.accelerometer.unit = 'g';
            aux.accelerometer.varNames = {'X', 'Y', 'Z'};
            out = pf2_base.normalizeAux(aux);
            testCase.verifyEqual(out.accelerometer.unit, 'g');
            testCase.verifyEqual(out.accelerometer.varNames, {'X', 'Y', 'Z'});
            testCase.verifyEqual(out.accelerometer.type, 'ACCEL');
        end

        function testFieldSynonyms(testCase)
            sig.values = randn(20, 1);     % 'values' -> data
            sig.t = (0:19)';               % 't' -> time
            sig.units = 'uS';              % 'units' -> unit
            sig.labels = {'eda'};          % 'labels' -> varNames
            aux.gsr = sig;
            out = pf2_base.normalizeAux(aux);
            testCase.verifyEqual(size(out.gsr.data), [20 1]);
            testCase.verifyEqual(out.gsr.time, (0:19)');
            testCase.verifyEqual(out.gsr.unit, 'uS');
            testCase.verifyEqual(out.gsr.varNames, {'eda'});
            testCase.verifyEqual(out.gsr.type, 'GSR');
        end

        function testRaggedVarNamesRepaired(testCase)
            aux.accelerometer.data = randn(30, 3);
            aux.accelerometer.varNames = {'only_one'};   % wrong length
            out = pf2_base.normalizeAux(aux);
            testCase.verifyEqual(numel(out.accelerometer.varNames), 3);
            testCase.verifyEqual(out.accelerometer.varNames, {'ch1', 'ch2', 'ch3'});
        end

        function testRowVectorBecomesColumn(testCase)
            aux.heartRate.data = 60:69;   % row vector
            aux.heartRate.time = 0:9;
            out = pf2_base.normalizeAux(aux);
            testCase.verifyEqual(size(out.heartRate.data), [10 1]);
        end

        function testTableSignal(testCase)
            T = table((0:9)', randn(10, 1), 'VariableNames', {'time', 'ppg'});
            aux.ppg = T;
            out = pf2_base.normalizeAux(aux);
            testCase.verifyEqual(out.ppg.time, (0:9)');
            testCase.verifyEqual(size(out.ppg.data), [10 1]);
            testCase.verifyEqual(out.ppg.varNames, {'ppg'});
            testCase.verifyEqual(out.ppg.type, 'PPG');
        end

        function testNumericSignal(testCase)
            aux.eeg_Cz = randn(40, 1);
            out = pf2_base.normalizeAux(aux);
            testCase.verifyEqual(size(out.eeg_Cz.data), [40 1]);
            testCase.verifyEqual(out.eeg_Cz.type, 'EEG');
            testCase.verifyEqual(out.eeg_Cz.unit, 'uV');
        end

        function testMultiSignalContainer(testCase)
            aux.heartRate.data = (60:0.5:70)';
            aux.accelerometer.data = randn(21, 3);
            out = pf2_base.normalizeAux(aux, 'fs', 5);
            testCase.verifyEqual(out.heartRate.type, 'HR');
            testCase.verifyEqual(out.accelerometer.type, 'ACCEL');
        end

        function testHousekeepingPassthrough(testCase)
            % Non-flattened container: a top-level time vector is left untouched
            % while signals are still normalized.
            aux.time = (0:9)';
            aux.heartRate.data = (60:69)';
            out = pf2_base.normalizeAux(aux);
            testCase.verifyEqual(out.time, (0:9)');       % left untouched
            testCase.verifyEqual(out.heartRate.type, 'HR');
        end

        function testFlattenedContainerUntouched(testCase)
            % A container already flattened by split/resample (flattened==true)
            % is a processed representation and must be returned unchanged.
            aux.flattened = true;
            aux.heartRate_data = (60:69)';
            aux.heartRate_time = (0:9)';
            out = pf2_base.normalizeAux(aux);
            testCase.verifyEqual(out, aux);
        end

        function testIdempotent(testCase)
            aux.heartRate.data = (60:0.5:70)';
            once = pf2_base.normalizeAux(aux, 'fs', 5);
            twice = pf2_base.normalizeAux(once, 'fs', 5);
            testCase.verifyEqual(twice, once);
        end

        function testSingleMode(testCase)
            sig.data = randn(15, 2);
            out = pf2_base.normalizeAux(sig, 'Single', true, 'Name', 'accel', 'fs', 30);
            testCase.verifyEqual(out.type, 'ACCEL');
            testCase.verifyEqual(numel(out.varNames), 2);
            testCase.verifyEqual(out.time, (0:14)'/30, 'AbsTol', 1e-12);
        end
    end
end
