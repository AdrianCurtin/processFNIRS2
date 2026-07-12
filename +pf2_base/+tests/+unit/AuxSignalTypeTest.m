classdef AuxSignalTypeTest < matlab.unittest.TestCase
    % AUXSIGNALTYPETEST Unit tests for pf2_base.auxSignalType type registry
    %
    % Verifies name/unit -> type resolution for the known auxiliary signal
    % families (HR, EKG, PPG, ACCEL, GSR, EEG), the generic fallback for
    % unknown signals, role/band/kind defaults, and that EEG is typed
    % separately from the slow physiological families.
    %
    % Run all tests:
    %   results = runtests('pf2_base.tests.unit.AuxSignalTypeTest');

    methods (Test)
        function testHeartRateAliases(testCase)
            for nm = {'heartRate', 'HR', 'hr', 'pulse', 'heart_rate', 'Subj1_HeartRate'}
                info = pf2_base.auxSignalType(nm{1});
                testCase.verifyEqual(info.type, 'HR', ...
                    sprintf('%s should map to HR', nm{1}));
            end
            info = pf2_base.auxSignalType('heartRate');
            testCase.verifyEqual(info.kind, 'feature');
            testCase.verifyEqual(info.role, 'covariate');
            testCase.verifyEqual(info.defaultUnit, 'bpm');
        end

        function testEkgAliases(testCase)
            for nm = {'ekg', 'ECG', 'electrocardiogram', 'cardiac'}
                info = pf2_base.auxSignalType(nm{1});
                testCase.verifyEqual(info.type, 'EKG', ...
                    sprintf('%s should map to EKG', nm{1}));
            end
            info = pf2_base.auxSignalType('ekg');
            testCase.verifyEqual(info.kind, 'waveform');
            testCase.verifyTrue(ismember('source', info.roles));
        end

        function testPpgAliases(testCase)
            for nm = {'ppg', 'pleth', 'plethysmography', 'pulseOx'}
                info = pf2_base.auxSignalType(nm{1});
                testCase.verifyEqual(info.type, 'PPG', ...
                    sprintf('%s should map to PPG', nm{1}));
            end
        end

        function testAccelAliases(testCase)
            for nm = {'accel', 'acc', 'accelerometer', 'IMU', 'motion', 'accelX'}
                info = pf2_base.auxSignalType(nm{1});
                testCase.verifyEqual(info.type, 'ACCEL', ...
                    sprintf('%s should map to ACCEL', nm{1}));
            end
            info = pf2_base.auxSignalType('accelerometer');
            testCase.verifyEqual(info.role, 'motion');
            testCase.verifyTrue(ismember('nuisance', info.roles));
        end

        function testGsrAliases(testCase)
            for nm = {'gsr', 'eda', 'EDA', 'scl', 'scr', 'electrodermal'}
                info = pf2_base.auxSignalType(nm{1});
                testCase.verifyEqual(info.type, 'GSR', ...
                    sprintf('%s should map to GSR', nm{1}));
            end
            info = pf2_base.auxSignalType('gsr');
            testCase.verifyEqual(info.role, 'covariate');
        end

        function testRespAliases(testCase)
            for nm = {'resp', 'respiration', 'breathing', 'RIP', 'respBelt'}
                info = pf2_base.auxSignalType(nm{1});
                testCase.verifyEqual(info.type, 'RESP', ...
                    sprintf('%s should map to RESP', nm{1}));
            end
            info = pf2_base.auxSignalType('respiration');
            testCase.verifyEqual(info.kind, 'waveform');
            testCase.verifyTrue(ismember('nuisance', info.roles));
            testCase.verifyEqual(info.band, [0.1 0.5]);
        end

        function testTempAliases(testCase)
            for nm = {'temp', 'temperature', 'skinTemp', 'thermistor'}
                info = pf2_base.auxSignalType(nm{1});
                testCase.verifyEqual(info.type, 'TEMP', ...
                    sprintf('%s should map to TEMP', nm{1}));
            end
            info = pf2_base.auxSignalType('temperature');
            testCase.verifyEqual(info.kind, 'feature');
            testCase.verifyEqual(info.role, 'covariate');
            testCase.verifyEqual(info.defaultUnit, 'degC');
            % Unit tie-breaker
            tempByUnit = pf2_base.auxSignalType('chan1', 'degC');
            testCase.verifyEqual(tempByUnit.type, 'TEMP');
            testCase.verifyEqual(tempByUnit.matchedBy, 'unit');
        end

        function testShortTokensDoNotOvermatch(testCase)
            % Short alias tokens (resp, temp, rip, ...) must not substring-match
            % unrelated English words; only exact / long-token matches count.
            for nm = {'correspondence', 'response', 'attempt', 'temporary', 'corresponding'}
                testCase.verifyEqual(pf2_base.auxSignalType(nm{1}).type, '', ...
                    sprintf('%s should not be typed', nm{1}));
            end
            % But genuine compound names still resolve via the long token
            testCase.verifyEqual(pf2_base.auxSignalType('subj1_respiration').type, 'RESP');
        end

        function testEegTypedSeparately(testCase)
            for nm = {'eeg', 'EEG', 'eeg_Cz', 'eegFp1', 'electroencephalogram'}
                info = pf2_base.auxSignalType(nm{1});
                testCase.verifyEqual(info.type, 'EEG', ...
                    sprintf('%s should map to EEG', nm{1}));
            end
            info = pf2_base.auxSignalType('eeg_Cz');
            % EEG must NOT collapse into a physiological family
            testCase.verifyFalse(ismember(info.type, {'EKG', 'PPG', 'HR', 'GSR'}));
            testCase.verifyTrue(ismember('fusion', info.roles));
            testCase.verifyTrue(isstruct(info.bands));
            testCase.verifyEqual(info.bands.alpha, [8 13]);
        end

        function testUnknownIsGeneric(testCase)
            info = pf2_base.auxSignalType('mysteryChannel');
            testCase.verifyEqual(info.type, '');
            testCase.verifyEqual(info.kind, '');
            testCase.verifyEqual(info.matchedBy, 'none');
            testCase.verifyEmpty(info.band);
        end

        function testUnitTieBreaker(testCase)
            % Ambiguous name resolved by unit
            testCase.verifyEqual(pf2_base.auxSignalType('chan1', 'uS').type, 'GSR');
            testCase.verifyEqual(pf2_base.auxSignalType('chan1', 'bpm').type, 'HR');
            testCase.verifyEqual(pf2_base.auxSignalType('chan1', 'mV').type, 'EKG');
            info = pf2_base.auxSignalType('chan1', 'uS');
            testCase.verifyEqual(info.matchedBy, 'unit');
        end

        function testNameBeatsUnit(testCase)
            % Explicit name wins over a conflicting unit
            info = pf2_base.auxSignalType('heartRate', 'uS');
            testCase.verifyEqual(info.type, 'HR');
            testCase.verifyEqual(info.matchedBy, 'name');
        end

        function testFindAuxByType(testCase)
            % Nested container with several typed signals
            d.Aux.heartRate.data = (60:69)';
            d.Aux.ppg.data = randn(10, 1);
            d.Aux.accelerometer.data = randn(10, 3);
            testCase.verifyEqual(pf2_base.fnirs.findAuxByType(d, 'ACCEL'), 'accelerometer');
            testCase.verifyEqual(pf2_base.fnirs.findAuxByType(d, 'HR'), 'heartRate');
            testCase.verifyEqual(pf2_base.fnirs.findAuxByType(d, 'PPG'), 'ppg');
            % Absent type -> fallback
            testCase.verifyEqual(pf2_base.fnirs.findAuxByType(d, 'EKG', ''), '');
            testCase.verifyEqual(pf2_base.fnirs.findAuxByType(d, 'GSR', 'none'), 'none');
            % Flattened container resolves to the base name
            f.Aux.flattened = true;
            f.Aux.heartRate_data = (60:69)';
            f.Aux.heartRate_time = (0:9)';
            testCase.verifyEqual(pf2_base.fnirs.findAuxByType(f, 'HR'), 'heartRate');
        end
    end
end
