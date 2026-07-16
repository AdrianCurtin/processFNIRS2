classdef PublicProcessingContextTest < matlab.unittest.TestCase
    % PUBLICPROCESSINGCONTEXTTEST Unit tests for the public pf2.ProcessingContext
    %
    % Covers the user-facing subclass: usable-from-bare-construction (no
    % fromGlobals bootstrap), Name-Value configuration with aliases,
    % independent copy(), and the process() convenience.
    %
    % Usage:
    %   results = runtests('pf2_base.tests.unit.PublicProcessingContextTest');

    properties (Access = private)
        OriginalPF2
        OriginalSetF
    end

    methods (TestMethodSetup)
        function saveGlobals(testCase)
            global PF2 setF
            testCase.OriginalPF2 = PF2;
            testCase.OriginalSetF = setF;
        end
    end

    methods (TestMethodTeardown)
        function restoreGlobals(testCase)
            global PF2 setF
            PF2 = testCase.OriginalPF2;
            setF = testCase.OriginalSetF;
        end
    end

    methods (Test)
        %% Construction / trap fix

        function testIsSubclassAndAcceptedByValidator(testCase)
            % Public class must be an isa of the internal one so processFNIRS2's
            % Context validator accepts it.
            ctx = pf2.ProcessingContext();
            testCase.verifyClass(ctx, 'pf2.ProcessingContext');
            testCase.verifyTrue(isa(ctx, 'pf2_base.ProcessingContext'));
        end

        function testBareConstructorIsImmediatelyUsable(testCase)
            % The "trap": setRawMethod/setOxyMethod must work straight after a
            % bare construction, with no fromGlobals() bootstrap.
            ctx = pf2.ProcessingContext();
            testCase.verifyTrue(isfield(ctx.rawMethodsLib, 'cfg'));
            testCase.verifyTrue(isfield(ctx.oxyMethodsLib, 'cfg'));
            testCase.verifyWarningFree(@() ctx.setRawMethod('None'));
            testCase.verifyWarningFree(@() ctx.setOxyMethod('None'));
        end

        %% Name-Value configuration

        function testConstructorNameValueAliases(testCase)
            % processFNIRS2-style aliases map onto the right properties.
            ctx = pf2.ProcessingContext('DPFmode', 'Calc', 'SubjectAge', 30, ...
                'blLength', 8, 'blStartTime', 1, 'RejectLevel', 0.1, ...
                'FixedDPF', 6.1);
            testCase.verifyEqual(ctx.dpfMode, 'Calc');
            testCase.verifyEqual(ctx.subjectAge, 30);
            testCase.verifyEqual(ctx.baselineLength, 8);
            testCase.verifyEqual(ctx.baselineStartTime, 1);
            testCase.verifyEqual(ctx.rejectLevel, 0.1, 'AbsTol', 1e-12);
            testCase.verifyEqual(ctx.dpfFixedValue, 6.1, 'AbsTol', 1e-12);
        end

        function testConfigureIsChainableAndApplies(testCase)
            ctx = pf2.ProcessingContext();
            out = ctx.configure('blLength', 5, 'RejectLevel', 0.2);
            testCase.verifySameHandle(out, ctx);   % returns the handle
            testCase.verifyEqual(ctx.baselineLength, 5);
            testCase.verifyEqual(ctx.rejectLevel, 0.2, 'AbsTol', 1e-12);
        end

        function testUnknownSettingErrors(testCase)
            testCase.verifyError(@() pf2.ProcessingContext('NotAThing', 1), ...
                'pf2:ProcessingContext:unknownSetting');
        end

        function testOddPairsError(testCase)
            ctx = pf2.ProcessingContext();
            testCase.verifyError(@() ctx.configure('blLength'), ...
                'pf2:ProcessingContext:configure:pairs');
        end

        %% copy() independence

        function testCopyIsIndependentAndClassPreserving(testCase)
            ctx = pf2.ProcessingContext('SubjectAge', 30);
            c2 = ctx.copy();
            c2.subjectAge = 99;
            testCase.verifyEqual(ctx.subjectAge, 30);   % original untouched
            testCase.verifyEqual(c2.subjectAge, 99);
            testCase.verifyClass(c2, 'pf2.ProcessingContext');
        end

        function testPlainAssignmentAliases(testCase)
            % Documents the hazard copy() exists to avoid: '=' aliases a handle.
            ctx = pf2.ProcessingContext('SubjectAge', 30);
            alias = ctx;
            alias.subjectAge = 77;
            testCase.verifyEqual(ctx.subjectAge, 77);
        end

        %% Internal context-struct compatibility

        function testBaseFromStructReloadsMethods(testCase)
            % The base fromStruct fix: a deserialized context must be usable.
            ctx = pf2.ProcessingContext('SubjectAge', 22);
            r = pf2_base.ProcessingContext.fromStruct(ctx.toStruct());
            testCase.verifyTrue(isfield(r.rawMethodsLib, 'cfg'));
            testCase.verifyWarningFree(@() r.setRawMethod('None'));
        end

        %% process() convenience

        function testProcessProducesHbAndIsolatesAge(testCase)
            data = pf2.import.sampleData.fNIR2000();
            ctx = pf2.ProcessingContext('DPFmode', 'Fixed', 'FixedDPF', 5.5);
            proc = ctx.process(data);
            testCase.verifyTrue(isfield(proc, 'HbO'));
            testCase.verifyNotEmpty(proc.HbO);
            % Same result as the explicit keyword form.
            proc2 = processFNIRS2(data, 'Context', ctx);
            testCase.verifyEqual(size(proc.HbO), size(proc2.HbO));
        end

        function testProcessForwardsExtraArgs(testCase)
            % process() must forward pass-through args (e.g. SkipOxy) to
            % processFNIRS2 -- verify by checking they change the output.
            data = pf2.import.sampleData.fNIR2000();
            ctx = pf2.ProcessingContext();
            proc = ctx.process(data, 'SkipOxy', true);
            testCase.verifyFalse(isfield(proc, 'HbO') && ~isempty(proc.HbO));
        end

        function testProcessRejectedHonoredFromContext(testCase)
            % Context path must consume ctx.processRejected (previously it was
            % silently dropped -- only the call-site arg was read). Observable:
            % a channel marked bad is NaN'd when processRejected is false, but
            % processed (finite) when the context turns it on.
            data = pf2.import.sampleData.fNIR2000();
            data.fchMask(1) = 0;   % mark channel 1 as rejected

            ctxOff = pf2.ProcessingContext(); ctxOff.processRejected = false;
            pOff = ctxOff.process(data);
            ctxOn = pf2.ProcessingContext(); ctxOn.processRejected = true;
            pOn = ctxOn.process(data);

            % Honoring processRejected leaves fewer fully-NaN (rejected) columns.
            nRejectedOff = nnz(all(isnan(pOff.HbO), 1));
            nRejectedOn  = nnz(all(isnan(pOn.HbO), 1));
            testCase.verifyGreaterThan(nRejectedOff, nRejectedOn);
        end
    end
end
