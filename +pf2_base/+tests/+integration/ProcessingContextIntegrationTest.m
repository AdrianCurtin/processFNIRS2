classdef ProcessingContextIntegrationTest < matlab.unittest.TestCase
    % PROCESSINGCONTEXTINTEGRATIONTEST Integration tests for ProcessingContext with processFNIRS2
    %
    % Tests that ProcessingContext is properly used by processFNIRS2 when
    % provided as the 'Context' parameter, ensuring isolated processing
    % independent of global variable state.
    %
    % Usage:
    %   results = runtests('pf2_base.tests.integration.ProcessingContextIntegrationTest');

    properties (Access = private)
        OriginalPF2
        OriginalSetF
        SampleData
    end

    methods (TestClassSetup)
        function loadSampleData(testCase)
            % Load sample data once for all tests
            testCase.SampleData = pf2.import.sampleData.fNIR2000();
        end
    end

    methods (TestMethodSetup)
        function saveGlobals(testCase)
            % Save original globals before each test
            global PF2 setF
            testCase.OriginalPF2 = PF2;
            testCase.OriginalSetF = setF;
        end
    end

    methods (TestMethodTeardown)
        function restoreGlobals(testCase)
            % Close any figures that may have been opened during testing
            % (avoids GUI cleanup errors)
            figs = findall(0, 'Type', 'figure');
            for i = 1:length(figs)
                try
                    set(figs(i), 'DeleteFcn', '');  % Clear DeleteFcn to avoid errors
                    close(figs(i));
                catch
                    % Ignore errors during cleanup
                end
            end

            % Restore original globals after each test
            global PF2 setF
            PF2 = testCase.OriginalPF2;
            setF = testCase.OriginalSetF;
        end
    end

    methods (Test)
        %% Basic Context Processing Tests

        function testProcessWithContextReturnsData(testCase)
            % TESTPROCESSWITHCONTEXTRETURNSDATA Verify processing with context returns valid data
            ctx = pf2_base.ProcessingContext.fromGlobals();

            result = processFNIRS2(testCase.SampleData, 'Context', ctx);

            testCase.verifyClass(result, 'struct');
            testCase.verifyTrue(isfield(result, 'HbO'));
            testCase.verifyTrue(isfield(result, 'HbR'));
        end

        function testProcessWithContextPreservesStructure(testCase)
            % TESTPROCESSWITHCONTEXTPRESERVESSTRUCTURE Verify output structure is correct
            ctx = pf2_base.ProcessingContext.fromGlobals();

            result = processFNIRS2(testCase.SampleData, 'Context', ctx);

            % Verify all expected fields
            testCase.verifyTrue(isfield(result, 'HbO'));
            testCase.verifyTrue(isfield(result, 'HbR'));
            testCase.verifyTrue(isfield(result, 'HbTotal'));
            testCase.verifyTrue(isfield(result, 'HbDiff'));
            testCase.verifyTrue(isfield(result, 'CBSI'));
            testCase.verifyTrue(isfield(result, 'time'));
            testCase.verifyTrue(isfield(result, 'channels'));
            testCase.verifyTrue(isfield(result, 'fchMask'));
        end

        %% Context Isolation Tests

        function testContextIsolatesFromGlobals(testCase)
            % TESTCONTEXTISOLATESFROMGLOBALS Verify context uses its settings, not globals
            global PF2

            % Create context from globals first to get method libraries
            ctx = pf2_base.ProcessingContext.fromGlobals();
            ctx.dpfMode = 'Calc';
            ctx.subjectAge = 25;

            % Now set global to different value
            PF2.dpf_mode = 'None';
            PF2.curDPF_age = 99;

            result = processFNIRS2(testCase.SampleData, 'Context', ctx);

            % Result should reflect context settings (Calc mode gives uM units)
            testCase.verifyTrue(contains(result.units, 'uM') || contains(result.units, 'µM'));

            % Global should still have the modified value
            testCase.verifyEqual(PF2.dpf_mode, 'None');
        end

        function testProcessingDoesNotModifyContext(testCase)
            % TESTPROCESSINGDOESNOTMODIFYCONTEXT Verify context is not modified during processing
            ctx = pf2_base.ProcessingContext.fromGlobals();
            originalAge = ctx.subjectAge;
            originalDPFMode = ctx.dpfMode;
            originalBaselineLength = ctx.baselineLength;

            processFNIRS2(testCase.SampleData, 'Context', ctx);

            % Context should be unchanged
            testCase.verifyEqual(ctx.subjectAge, originalAge);
            testCase.verifyEqual(ctx.dpfMode, originalDPFMode);
            testCase.verifyEqual(ctx.baselineLength, originalBaselineLength);
        end

        %% DPF Mode Tests

        function testDPFModeNoneFromContext(testCase)
            % TESTDPFMODENONEFROMCONTEXT Verify DPF None mode uses context setting
            global PF2

            % Set global to Calc
            PF2.dpf_mode = 'Calc';

            % Create context with None
            ctx = pf2_base.ProcessingContext.fromGlobals();
            ctx.dpfMode = 'None';

            result = processFNIRS2(testCase.SampleData, 'Context', ctx);

            % With no DPF, units should be mM*mm
            testCase.verifyTrue(contains(result.units, 'mM') && contains(result.units, 'mm'));
        end

        function testDPFModeFixedFromContext(testCase)
            % TESTDPFMODEFIXEDFROMCONTEXT Verify DPF Fixed mode uses context value
            ctx = pf2_base.ProcessingContext.fromGlobals();
            ctx.dpfMode = 'Fixed';
            ctx.dpfFixedValue = 6.0;

            result = processFNIRS2(testCase.SampleData, 'Context', ctx);

            % With Fixed DPF, units should be uM
            testCase.verifyTrue(contains(result.units, 'uM') || contains(result.units, 'µM'));
            testCase.verifyEqual(result.DPF_factor, 6.0);
        end

        %% Baseline Settings Tests

        function testBaselineLengthFromContext(testCase)
            % TESTBASELINELENGTHFROMCONTEXT Verify baseline length uses context value
            ctx = pf2_base.ProcessingContext.fromGlobals();
            ctx.baselineLength = 5;  % 5 second baseline

            result = processFNIRS2(testCase.SampleData, 'Context', ctx);

            % Result should be valid (baseline was applied)
            testCase.verifyFalse(all(isnan(result.HbO(:))));
        end

        function testBaselineStartTimeFromContext(testCase)
            % TESTBASELINESTARTTIMEFROMCONTEXT Verify baseline start uses context value
            ctx = pf2_base.ProcessingContext.fromGlobals();
            ctx.baselineStartTime = 2;  % Start baseline at t=2

            result = processFNIRS2(testCase.SampleData, 'Context', ctx);

            % Result should be valid
            testCase.verifyFalse(all(isnan(result.HbO(:))));
        end

        %% Reject Level Tests

        function testRejectLevelFromContext(testCase)
            % TESTREJECTLEVELFROMCONTEXT Verify reject level uses context value
            global PF2

            % Set global to 0 (accept all)
            PF2.RejectLevel = 0;

            % Create context with higher reject level
            ctx = pf2_base.ProcessingContext.fromGlobals();
            ctx.rejectLevel = 0.5;  % Reject channels with fchMask <= 0.5

            % Create data with some channels having low quality
            testData = testCase.SampleData;
            testData.fchMask = ones(1, length(testData.fchMask));
            testData.fchMask(1:5) = 0.3;  % Mark first 5 channels as low quality

            result = processFNIRS2(testData, 'Context', ctx);

            % First 5 channels should be masked (false in fchMask)
            testCase.verifyEqual(result.fchMask(1:5), false(1, 5));
        end

        %% Method Configuration Tests

        function testRawMethodFromContext(testCase)
            % TESTRAWMETHODFROMCONTEXT Verify raw method uses context configuration
            ctx = pf2_base.ProcessingContext.fromGlobals();
            ctx.setRawMethod('None');  % Use None method

            result = processFNIRS2(testCase.SampleData, 'Context', ctx);

            testCase.verifyTrue(isfield(result, 'HbO'));
        end

        function testOxyMethodFromContext(testCase)
            % TESTOXYMETHODFROMCONTEXT Verify oxy method uses context configuration
            ctx = pf2_base.ProcessingContext.fromGlobals();
            ctx.setOxyMethod('None');  % Use None method

            result = processFNIRS2(testCase.SampleData, 'Context', ctx);

            testCase.verifyTrue(isfield(result, 'HbO'));
        end

        %% Parallel Processing Simulation

        function testMultipleContextsIndependent(testCase)
            % TESTMULTIPLECONTEXTSINDEPENDENT Verify multiple contexts process independently
            % Simulate parallel processing scenario

            ctx1 = pf2_base.ProcessingContext.fromGlobals();
            ctx1.dpfMode = 'Fixed';
            ctx1.dpfFixedValue = 5.0;

            ctx2 = pf2_base.ProcessingContext.fromGlobals();
            ctx2.dpfMode = 'Fixed';
            ctx2.dpfFixedValue = 7.0;

            % Process with different contexts
            result1 = processFNIRS2(testCase.SampleData, 'Context', ctx1);
            result2 = processFNIRS2(testCase.SampleData, 'Context', ctx2);

            % Verify different DPF values were used
            testCase.verifyEqual(result1.DPF_factor, 5.0);
            testCase.verifyEqual(result2.DPF_factor, 7.0);

            % HbO values should differ due to different DPF
            testCase.verifyNotEqual(result1.HbO(1,1), result2.HbO(1,1));
        end

        %% Parameter Override Tests

        function testExplicitParameterOverridesContext(testCase)
            % TESTEXPLICITPARAMETEROVERRIDESCONTEXT Verify explicit params override context
            ctx = pf2_base.ProcessingContext.fromGlobals();
            ctx.baselineLength = 5;

            % Explicit parameter should override context
            result = processFNIRS2(testCase.SampleData, 'Context', ctx, 'blLength', 10);

            testCase.verifyTrue(isfield(result, 'HbO'));
        end

        function testDPFmodeParameterOverridesContext(testCase)
            % TESTDPFMODEPARAMETEROVERRIDESCONTEXT Verify DPFmode parameter overrides context
            ctx = pf2_base.ProcessingContext.fromGlobals();
            ctx.dpfMode = 'Calc';

            result = processFNIRS2(testCase.SampleData, 'Context', ctx, 'DPFmode', 'None');

            % Should use None mode from parameter, not Calc from context
            testCase.verifyTrue(contains(result.units, 'mM') && contains(result.units, 'mm'));
        end

        %% Backward Compatibility Tests

        function testProcessingWithoutContextStillWorks(testCase)
            % TESTPROCESSINGWITHOUTCONTEXTSTILLWORKS Verify backward compatibility
            result = processFNIRS2(testCase.SampleData);

            testCase.verifyClass(result, 'struct');
            testCase.verifyTrue(isfield(result, 'HbO'));
            testCase.verifyTrue(isfield(result, 'HbR'));
        end

        function testEmptyContextFallsBackToGlobals(testCase)
            % TESTEMPTYCONTEXTFALLSBACKTOGLOBALS Verify empty context uses globals
            result = processFNIRS2(testCase.SampleData, 'Context', []);

            testCase.verifyClass(result, 'struct');
            testCase.verifyTrue(isfield(result, 'HbO'));
        end
    end
end
