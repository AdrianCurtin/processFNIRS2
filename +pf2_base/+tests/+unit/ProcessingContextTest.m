classdef ProcessingContextTest < matlab.unittest.TestCase
    % PROCESSINGCONTEXTTEST Unit tests for ProcessingContext class
    %
    % Tests the ProcessingContext class which encapsulates processing
    % settings as an alternative to global variables.
    %
    % Usage:
    %   results = runtests('pf2_base.tests.unit.ProcessingContextTest');

    properties (Access = private)
        OriginalPF2
        OriginalSetF
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
            % Restore original globals after each test
            global PF2 setF
            PF2 = testCase.OriginalPF2;
            setF = testCase.OriginalSetF;
        end
    end

    methods (Test)
        %% Constructor Tests

        function testDefaultConstructor(testCase)
            % TESTDEFAULTCONSTRUCTOR Verify default context creation
            ctx = pf2_base.ProcessingContext();

            testCase.verifyClass(ctx, 'pf2_base.ProcessingContext');
        end

        function testDefaultDPFSettings(testCase)
            % TESTDEFAULTDPFSETTINGS Verify default DPF values
            ctx = pf2_base.ProcessingContext();

            testCase.verifyEqual(ctx.dpfMode, 'Calc');
            testCase.verifyEqual(ctx.dpfFixedValue, 5.93);
            testCase.verifyEqual(ctx.subjectAge, 25);
        end

        function testDefaultBaselineSettings(testCase)
            % TESTDEFAULTBASELINESETTINGS Verify default baseline values
            ctx = pf2_base.ProcessingContext();

            testCase.verifyEqual(ctx.baselineStartTime, 0);
            testCase.verifyEqual(ctx.baselineLength, 10);
            testCase.verifyFalse(ctx.useAbsoluteTime);
            testCase.verifyFalse(ctx.dirtyBaseline);
        end

        function testDefaultMethodSettings(testCase)
            % TESTDEFAULTMETHODSETTINGS Verify default method values
            ctx = pf2_base.ProcessingContext();

            testCase.verifyEqual(ctx.rawMethodName, 'None');
            testCase.verifyEqual(ctx.oxyMethodName, 'None');
        end

        function testDefaultQualitySettings(testCase)
            % TESTDEFAULTQUALITYSETTINGS Verify default quality values
            ctx = pf2_base.ProcessingContext();

            testCase.verifyEqual(ctx.rejectLevel, 0);
            testCase.verifyFalse(ctx.processRejected);
        end

        %% Property Validation Tests

        function testDPFModeValidation(testCase)
            % TESTDPFMODEVALIDATION Verify DPF mode accepts only valid values
            ctx = pf2_base.ProcessingContext();

            % Valid values should work
            ctx.dpfMode = 'None';
            testCase.verifyEqual(ctx.dpfMode, 'None');

            ctx.dpfMode = 'Fixed';
            testCase.verifyEqual(ctx.dpfMode, 'Fixed');

            ctx.dpfMode = 'Calc';
            testCase.verifyEqual(ctx.dpfMode, 'Calc');

            % Invalid value should error
            testCase.verifyError(@() setfield(ctx, 'dpfMode', 'Invalid'), ...
                'MATLAB:validators:mustBeMember');
        end

        function testDPFFixedValueValidation(testCase)
            % TESTDPFFIXEDVALUEVALIDATION Verify positive value required
            ctx = pf2_base.ProcessingContext();

            ctx.dpfFixedValue = 6.0;
            testCase.verifyEqual(ctx.dpfFixedValue, 6.0);

            % Negative should error
            testCase.verifyError(@() setfield(ctx, 'dpfFixedValue', -1), ...
                'MATLAB:validators:mustBePositive');
        end

        function testRejectLevelValidation(testCase)
            % TESTREJECTLEVELVALIDATION Verify reject level in [0, 1]
            ctx = pf2_base.ProcessingContext();

            ctx.rejectLevel = 0.5;
            testCase.verifyEqual(ctx.rejectLevel, 0.5);

            ctx.rejectLevel = 0;
            testCase.verifyEqual(ctx.rejectLevel, 0);

            ctx.rejectLevel = 1;
            testCase.verifyEqual(ctx.rejectLevel, 1);
        end

        %% fromGlobals Tests

        function testFromGlobalsCreatesContext(testCase)
            % TESTFROMGLOBALSCREATESCONTEXT Verify fromGlobals works
            global PF2
            pf2_base.pf2_initialize();

            ctx = pf2_base.ProcessingContext.fromGlobals();

            testCase.verifyClass(ctx, 'pf2_base.ProcessingContext');
        end

        function testFromGlobalsCopiesDPFSettings(testCase)
            % TESTFROMGLOBALSCOPIESDPFSETTINGS Verify DPF settings copied
            global PF2
            pf2_base.pf2_initialize();

            PF2.dpf_mode = 'Fixed';
            PF2.curDPF_fixed = 6.5;
            PF2.curDPF_age = 30;

            ctx = pf2_base.ProcessingContext.fromGlobals();

            testCase.verifyEqual(ctx.dpfMode, 'Fixed');
            testCase.verifyEqual(ctx.dpfFixedValue, 6.5);
            testCase.verifyEqual(ctx.subjectAge, 30);
        end

        function testFromGlobalsCopiesBaselineSettings(testCase)
            % TESTFROMGLOBALSCOPIESBASELINESETTINGS Verify baseline copied
            global PF2
            pf2_base.pf2_initialize();

            PF2.baseline.startTime = 5;
            PF2.baseline.blLength = 15;

            ctx = pf2_base.ProcessingContext.fromGlobals();

            testCase.verifyEqual(ctx.baselineStartTime, 5);
            testCase.verifyEqual(ctx.baselineLength, 15);
        end

        function testFromGlobalsCopiesMethodLibraries(testCase)
            % TESTFROMGLOBALSCOPIESMETHODLIBRARIES Verify methods copied
            global PF2
            pf2_base.pf2_initialize();

            ctx = pf2_base.ProcessingContext.fromGlobals();

            testCase.verifyTrue(isfield(ctx.rawMethodsLib, 'cfg'));
            testCase.verifyTrue(isfield(ctx.oxyMethodsLib, 'cfg'));
        end

        %% applyToGlobals Tests

        function testApplyToGlobalsWritesDPF(testCase)
            % TESTAPPLYTOGLOBALSWRITESDPF Verify DPF written to globals
            global PF2
            pf2_base.pf2_initialize();

            ctx = pf2_base.ProcessingContext();
            ctx.dpfMode = 'Fixed';
            ctx.dpfFixedValue = 7.0;
            ctx.subjectAge = 35;

            ctx.applyToGlobals();

            testCase.verifyEqual(PF2.dpf_mode, 'Fixed');
            testCase.verifyEqual(PF2.curDPF_fixed, 7.0);
            testCase.verifyEqual(PF2.curDPF_age, 35);
        end

        function testApplyToGlobalsWritesBaseline(testCase)
            % TESTAPPLYTOGLOBALSWRITESBASELINE Verify baseline written
            global PF2
            pf2_base.pf2_initialize();

            ctx = pf2_base.ProcessingContext();
            ctx.baselineStartTime = 2;
            ctx.baselineLength = 8;

            ctx.applyToGlobals();

            testCase.verifyEqual(PF2.baseline.startTime, 2);
            testCase.verifyEqual(PF2.baseline.blLength, 8);
        end

        %% Roundtrip Tests

        function testFromGlobalsApplyRoundtrip(testCase)
            % TESTFROMGLOBALSAPPLYROUNDTRIP Verify globals -> context -> globals
            global PF2
            pf2_base.pf2_initialize();

            % Set specific values
            PF2.dpf_mode = 'Fixed';
            PF2.curDPF_fixed = 6.2;
            PF2.curDPF_age = 28;
            PF2.baseline.startTime = 3;
            PF2.baseline.blLength = 12;

            % Roundtrip
            ctx = pf2_base.ProcessingContext.fromGlobals();

            % Clear globals
            PF2.dpf_mode = 'None';
            PF2.curDPF_fixed = 0;

            % Apply back
            ctx.applyToGlobals();

            % Verify restored
            testCase.verifyEqual(PF2.dpf_mode, 'Fixed');
            testCase.verifyEqual(PF2.curDPF_fixed, 6.2);
            testCase.verifyEqual(PF2.curDPF_age, 28);
        end

        %% toStruct / fromStruct Tests

        function testToStructCreatesStruct(testCase)
            % TESTTOSTRUCTCREATESSTRUCT Verify toStruct returns struct
            ctx = pf2_base.ProcessingContext();
            ctx.dpfMode = 'Fixed';
            ctx.baselineLength = 7;

            s = ctx.toStruct();

            testCase.verifyClass(s, 'struct');
            testCase.verifyEqual(s.dpfMode, 'Fixed');
            testCase.verifyEqual(s.baselineLength, 7);
        end

        function testFromStructRestoresSettings(testCase)
            % TESTFROMSTRUCTRESTORESSETTINGS Verify fromStruct restores values
            s = struct();
            s.dpfMode = 'Fixed';
            s.dpfFixedValue = 6.0;
            s.subjectAge = 40;
            s.baselineStartTime = 1;
            s.baselineLength = 5;
            s.rejectLevel = 0.2;

            ctx = pf2_base.ProcessingContext.fromStruct(s);

            testCase.verifyEqual(ctx.dpfMode, 'Fixed');
            testCase.verifyEqual(ctx.dpfFixedValue, 6.0);
            testCase.verifyEqual(ctx.subjectAge, 40);
            testCase.verifyEqual(ctx.baselineStartTime, 1);
            testCase.verifyEqual(ctx.baselineLength, 5);
            testCase.verifyEqual(ctx.rejectLevel, 0.2);
        end

        function testStructRoundtrip(testCase)
            % TESTSTRUCTROUNDTRIP Verify context -> struct -> context
            ctx1 = pf2_base.ProcessingContext();
            ctx1.dpfMode = 'Fixed';
            ctx1.dpfFixedValue = 5.5;
            ctx1.subjectAge = 32;
            ctx1.baselineStartTime = 2;
            ctx1.baselineLength = 6;

            s = ctx1.toStruct();
            ctx2 = pf2_base.ProcessingContext.fromStruct(s);

            testCase.verifyEqual(ctx2.dpfMode, ctx1.dpfMode);
            testCase.verifyEqual(ctx2.dpfFixedValue, ctx1.dpfFixedValue);
            testCase.verifyEqual(ctx2.subjectAge, ctx1.subjectAge);
            testCase.verifyEqual(ctx2.baselineStartTime, ctx1.baselineStartTime);
            testCase.verifyEqual(ctx2.baselineLength, ctx1.baselineLength);
        end

        %% Method Setting Tests

        function testSetRawMethodWithLibrary(testCase)
            % TESTSETRAWMETHODWITHLIBRARY Verify setRawMethod works
            global PF2
            pf2_base.pf2_initialize();

            ctx = pf2_base.ProcessingContext.fromGlobals();

            % Should work with 'None' which always exists
            ctx.setRawMethod('None');

            testCase.verifyEqual(ctx.rawMethodName, 'None');
            testCase.verifyTrue(isfield(ctx.rawMethod, 'name'));
        end

        function testSetOxyMethodWithLibrary(testCase)
            % TESTSETOXYMETHODWITHLIBRARY Verify setOxyMethod works
            global PF2
            pf2_base.pf2_initialize();

            ctx = pf2_base.ProcessingContext.fromGlobals();

            % Should work with 'None' which always exists
            ctx.setOxyMethod('None');

            testCase.verifyEqual(ctx.oxyMethodName, 'None');
            testCase.verifyTrue(isfield(ctx.oxyMethod, 'name'));
        end

        function testSetRawMethodInvalidErrors(testCase)
            % TESTSETRAWMETHODINVALIDERRORS Verify error on invalid method
            global PF2
            pf2_base.pf2_initialize();

            ctx = pf2_base.ProcessingContext.fromGlobals();

            testCase.verifyError(@() ctx.setRawMethod('NonExistentMethod'), ...
                'ProcessingContext:InvalidMethod');
        end

        function testSetMethodWithoutLibraryErrors(testCase)
            % TESTSETMETHODWITHOUTLIBRARYERRORS Verify error without library
            ctx = pf2_base.ProcessingContext();

            testCase.verifyError(@() ctx.setRawMethod('None'), ...
                'ProcessingContext:NoMethodsLoaded');
        end

        %% Isolation Tests

        function testContextsAreIsolated(testCase)
            % TESTCONTEXTSAREISOLATED Verify changes to one don't affect another
            ctx1 = pf2_base.ProcessingContext();
            ctx2 = pf2_base.ProcessingContext();

            ctx1.dpfMode = 'Fixed';
            ctx1.subjectAge = 30;

            ctx2.dpfMode = 'None';
            ctx2.subjectAge = 50;

            % Verify isolation
            testCase.verifyEqual(ctx1.dpfMode, 'Fixed');
            testCase.verifyEqual(ctx1.subjectAge, 30);
            testCase.verifyEqual(ctx2.dpfMode, 'None');
            testCase.verifyEqual(ctx2.subjectAge, 50);
        end

        function testFromGlobalsCreatesIndependentCopy(testCase)
            % TESTFROMGLOBALSCREATESINDEPENDENTCOPY Verify copy is independent
            global PF2
            pf2_base.pf2_initialize();

            PF2.dpf_mode = 'Calc';
            ctx = pf2_base.ProcessingContext.fromGlobals();

            % Modify global
            PF2.dpf_mode = 'None';

            % Context should be unchanged
            testCase.verifyEqual(ctx.dpfMode, 'Calc');
        end

        %% Handle Semantics Tests

        function testHandleSemantics(testCase)
            % TESTHANDLESEMANTICS Verify handle class behavior
            ctx1 = pf2_base.ProcessingContext();
            ctx2 = ctx1;  % Same object

            ctx1.subjectAge = 99;

            % Both should see the change
            testCase.verifyEqual(ctx2.subjectAge, 99);
        end

        function testCopyMethodForValueSemantics(testCase)
            % TESTCOPYMETHODFORVALUESEMANTICS Verify copy creates new object
            ctx1 = pf2_base.ProcessingContext();
            ctx1.subjectAge = 25;

            % To get value semantics, use toStruct/fromStruct
            s = ctx1.toStruct();
            ctx2 = pf2_base.ProcessingContext.fromStruct(s);

            ctx1.subjectAge = 99;

            % ctx2 should be unchanged
            testCase.verifyEqual(ctx2.subjectAge, 25);
        end
    end
end

function result = setfield(obj, fieldName, value)
    % Helper to test property assignment errors
    obj.(fieldName) = value;
    result = obj;
end
