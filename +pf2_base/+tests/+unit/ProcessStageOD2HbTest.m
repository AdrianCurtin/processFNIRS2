classdef ProcessStageOD2HbTest < matlab.unittest.TestCase
    % PROCESSSTAGEOD2HBTEST Unit tests for processStageOD2Hb function
    %
    % Tests the Beer-Lambert conversion from optical density to hemoglobin
    % concentrations.
    %
    % Usage:
    %   results = runtests('pf2_base.tests.unit.ProcessStageOD2HbTest');

    properties (Access = private)
        SampleData
        CurProbe
        ODData
    end

    methods (TestClassSetup)
        function loadSampleData(testCase)
            % Load sample data and prepare OD data for testing
            testCase.SampleData = pf2.import.sampleData.fNIR2000();

            global setF
            pf2_base.pf2_initialize();
            pf2_base.loadDeviceCfg('fNIR_Devices_fNIR2000.cfg');
            testCase.CurProbe = setF.device.Probe{1};

            % Generate synthetic OD data for testing
            numTimepoints = 1000;
            numChannels = size(testCase.CurProbe.TableCh, 1);
            testCase.ODData = randn(numTimepoints, numChannels) * 0.01;
        end
    end

    methods (Test)
        %% Basic Functionality Tests

        function testReturnsStruct(testCase)
            % TESTRETURNSSTRUCT Verify function returns a struct
            time = (0:999)' / 10;
            baseline = struct('startTime', 0, 'blLength', 10);

            result = pf2_base.fnirs.processStageOD2Hb(testCase.ODData, time, 25, false, ...
                testCase.CurProbe, baseline, 'Calc', 5.93, 25);

            testCase.verifyClass(result, 'struct');
        end

        function testOutputHasRequiredFields(testCase)
            % TESTOUTPUTHASREQUIREDFIELDS Verify all expected output fields exist
            time = (0:999)' / 10;
            baseline = struct('startTime', 0, 'blLength', 10);

            result = pf2_base.fnirs.processStageOD2Hb(testCase.ODData, time, 25, false, ...
                testCase.CurProbe, baseline, 'Calc', 5.93, 25);

            testCase.verifyTrue(isfield(result, 'HbO'));
            testCase.verifyTrue(isfield(result, 'HbR'));
            testCase.verifyTrue(isfield(result, 'HbTotal'));
            testCase.verifyTrue(isfield(result, 'HbDiff'));
            testCase.verifyTrue(isfield(result, 'CBSI'));
            testCase.verifyTrue(isfield(result, 'channels'));
            testCase.verifyTrue(isfield(result, 'units'));
            testCase.verifyTrue(isfield(result, 'DPF_factor'));
            testCase.verifyTrue(isfield(result, 'time'));
        end

        function testOutputDimensions(testCase)
            % TESTOUTPUTDIMENSIONS Verify output dimensions are correct
            time = (0:999)' / 10;
            baseline = struct('startTime', 0, 'blLength', 10);

            result = pf2_base.fnirs.processStageOD2Hb(testCase.ODData, time, 25, false, ...
                testCase.CurProbe, baseline, 'Calc', 5.93, 25);

            % Time dimension should match
            testCase.verifyEqual(size(result.HbO, 1), 1000);
            testCase.verifyEqual(size(result.HbR, 1), 1000);

            % Time vector should be preserved
            testCase.verifyEqual(result.time, time);
        end

        function testHbTotalIsSum(testCase)
            % TESTHBTOTALISSUM Verify HbTotal = HbO + HbR
            time = (0:999)' / 10;
            baseline = struct('startTime', 0, 'blLength', 10);

            result = pf2_base.fnirs.processStageOD2Hb(testCase.ODData, time, 25, false, ...
                testCase.CurProbe, baseline, 'Calc', 5.93, 25);

            testCase.verifyEqual(result.HbTotal, result.HbO + result.HbR, 'AbsTol', 1e-10);
        end

        function testHbDiffIsDifference(testCase)
            % TESTHBDIFFISDIFFERENCE Verify HbDiff = HbO - HbR
            time = (0:999)' / 10;
            baseline = struct('startTime', 0, 'blLength', 10);

            result = pf2_base.fnirs.processStageOD2Hb(testCase.ODData, time, 25, false, ...
                testCase.CurProbe, baseline, 'Calc', 5.93, 25);

            testCase.verifyEqual(result.HbDiff, result.HbO - result.HbR, 'AbsTol', 1e-10);
        end

        %% DPF Mode Tests

        function testDPFModeNone(testCase)
            % TESTDPFMODENONE Verify 'None' DPF mode gives mM*mm units
            time = (0:999)' / 10;
            baseline = struct('startTime', 0, 'blLength', 10);

            result = pf2_base.fnirs.processStageOD2Hb(testCase.ODData, time, 25, false, ...
                testCase.CurProbe, baseline, 'None', 5.93, 25);

            testCase.verifyTrue(contains(result.units, 'mM') && contains(result.units, 'mm'));
        end

        function testDPFModeFixed(testCase)
            % TESTDPFMODEFIXED Verify 'Fixed' DPF mode uses provided value
            time = (0:999)' / 10;
            baseline = struct('startTime', 0, 'blLength', 10);
            fixedDPF = 6.0;

            result = pf2_base.fnirs.processStageOD2Hb(testCase.ODData, time, 25, false, ...
                testCase.CurProbe, baseline, 'Fixed', fixedDPF, 25);

            testCase.verifyEqual(result.DPF_factor, fixedDPF);
            testCase.verifyTrue(contains(result.units, 'uM') || contains(result.units, 'µM'));
        end

        function testDPFModeCalc(testCase)
            % TESTDPFMODECALC Verify 'Calc' DPF mode calculates age-dependent value
            time = (0:999)' / 10;
            baseline = struct('startTime', 0, 'blLength', 10);

            result = pf2_base.fnirs.processStageOD2Hb(testCase.ODData, time, 25, false, ...
                testCase.CurProbe, baseline, 'Calc', 5.93, 25);

            testCase.verifyTrue(contains(result.units, 'uM') || contains(result.units, 'µM'));
            % DPF should be calculated (not exactly the default)
            testCase.verifyGreaterThan(result.DPF_factor, 0);
        end

        function testDifferentAgesGiveDifferentDPF(testCase)
            % TESTDIFFERENTAGESGIVEDIFFERENTDPF Verify age affects Calc mode DPF
            time = (0:999)' / 10;
            baseline = struct('startTime', 0, 'blLength', 10);

            result25 = pf2_base.fnirs.processStageOD2Hb(testCase.ODData, time, 25, false, ...
                testCase.CurProbe, baseline, 'Calc', 5.93, 25);

            result60 = pf2_base.fnirs.processStageOD2Hb(testCase.ODData, time, 60, false, ...
                testCase.CurProbe, baseline, 'Calc', 5.93, 60);

            % Different ages should give different DPF values
            testCase.verifyNotEqual(result25.DPF_factor, result60.DPF_factor);
        end

        %% Baseline Tests

        function testDirtyBaselineUsesEntireSignal(testCase)
            % TESTDIRTYBASELINEUSESENTIRESIGNAL Verify DirtyBaseline=true uses all data
            time = (0:999)' / 10;
            baseline = struct('startTime', 0, 'blLength', 10);

            % With DirtyBaseline, baseline struct values should be ignored
            result = pf2_base.fnirs.processStageOD2Hb(testCase.ODData, time, 25, true, ...
                testCase.CurProbe, baseline, 'Calc', 5.93, 25);

            testCase.verifyFalse(all(isnan(result.HbO(:))));
        end

        function testBaselineStartTimeAffectsResult(testCase)
            % TESTBASELINESTARTTIMEAFFECTSRESULT Verify baseline start time is used
            time = (0:999)' / 10;

            baseline1 = struct('startTime', 0, 'blLength', 10);
            baseline2 = struct('startTime', 20, 'blLength', 10);

            result1 = pf2_base.fnirs.processStageOD2Hb(testCase.ODData, time, 25, false, ...
                testCase.CurProbe, baseline1, 'Calc', 5.93, 25);

            result2 = pf2_base.fnirs.processStageOD2Hb(testCase.ODData, time, 25, false, ...
                testCase.CurProbe, baseline2, 'Calc', 5.93, 25);

            % Different baseline periods should give different results
            testCase.verifyNotEqual(result1.HbO(500, 1), result2.HbO(500, 1));
        end

        function testBaselineLengthAffectsResult(testCase)
            % TESTBASELINELENGTHAFFECTSRESULT Verify baseline length is used
            time = (0:999)' / 10;

            baseline1 = struct('startTime', 0, 'blLength', 5);
            baseline2 = struct('startTime', 0, 'blLength', 20);

            result1 = pf2_base.fnirs.processStageOD2Hb(testCase.ODData, time, 25, false, ...
                testCase.CurProbe, baseline1, 'Calc', 5.93, 25);

            result2 = pf2_base.fnirs.processStageOD2Hb(testCase.ODData, time, 25, false, ...
                testCase.CurProbe, baseline2, 'Calc', 5.93, 25);

            % Different baseline lengths should give different results
            testCase.verifyNotEqual(result1.HbO(500, 1), result2.HbO(500, 1));
        end

        %% Default Age Fallback Tests

        function testEmptyAgeUsesDefault(testCase)
            % TESTEMPTYAGEUSESDEFAULT Verify empty subjectAge falls back to default
            time = (0:999)' / 10;
            baseline = struct('startTime', 0, 'blLength', 10);
            defaultAge = 30;

            % Pass empty age, should use defaultAge
            result = pf2_base.fnirs.processStageOD2Hb(testCase.ODData, time, [], false, ...
                testCase.CurProbe, baseline, 'Calc', 5.93, defaultAge);

            % Result should be valid
            testCase.verifyFalse(all(isnan(result.HbO(:))));
        end

        %% Channel Filtering Tests

        function testOutputChannelsMatch(testCase)
            % TESTOUTPUTCHANNELSMATCH Verify channels output matches probe config
            time = (0:999)' / 10;
            baseline = struct('startTime', 0, 'blLength', 10);

            result = pf2_base.fnirs.processStageOD2Hb(testCase.ODData, time, 25, false, ...
                testCase.CurProbe, baseline, 'Calc', 5.93, 25);

            % Channels should be the optode numbers that are actual channels
            testCase.verifyTrue(~isempty(result.channels));
            testCase.verifyEqual(length(result.channels), size(result.HbO, 2));
        end

        %% Edge Case Tests

        function testShortTimeVector(testCase)
            % TESTSHORTTIMEVECTOR Verify function handles short data
            shortOD = testCase.ODData(1:100, :);
            time = (0:99)' / 10;  % 10 seconds at 10 Hz
            baseline = struct('startTime', 0, 'blLength', 5);

            result = pf2_base.fnirs.processStageOD2Hb(shortOD, time, 25, false, ...
                testCase.CurProbe, baseline, 'Calc', 5.93, 25);

            testCase.verifyEqual(size(result.HbO, 1), 100);
        end

        function testBaselineAtEnd(testCase)
            % TESTBASELINEATEND Verify baseline can be at end of signal
            time = (0:999)' / 10;  % 100 seconds
            baseline = struct('startTime', 80, 'blLength', 10);  % Last 10 seconds

            result = pf2_base.fnirs.processStageOD2Hb(testCase.ODData, time, 25, false, ...
                testCase.CurProbe, baseline, 'Calc', 5.93, 25);

            testCase.verifyFalse(all(isnan(result.HbO(:))));
        end
    end
end
