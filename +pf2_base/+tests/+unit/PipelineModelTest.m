classdef PipelineModelTest < matlab.unittest.TestCase
% PIPELINEMODELTEST Unit tests for pf2_base.PipelineModel and listAvailable.

    methods (TestMethodSetup)
        function clearCaches(~)
            pf2_base.Pipeline.loadFuncConfig(true);
            pf2_base.PipelineFunction.lookupFunctionMeta('__clear_cache__');
        end
    end

    methods (Test)

        %% Construction
        function testConstructionRequiresPipeline(tc)
            tc.verifyError(@() pf2_base.PipelineModel(), ...
                'pf2:PipelineModel:badInput');
            tc.verifyError(@() pf2_base.PipelineModel(struct()), ...
                'pf2:PipelineModel:badInput');
        end

        function testConstructionFromRawPipeline(tc)
            p = pf2_base.RawPipeline('t').add('pf2_Intensity2OD');
            m = pf2_base.PipelineModel(p);
            tc.verifyClass(m.Pipeline, 'pf2_base.RawPipeline');
            tc.verifyEqual(m.Pipeline.numSteps(), 1);
        end

        %% Mutators
        function testAddStep(tc)
            m = pf2_base.PipelineModel(pf2_base.RawPipeline('t'));
            m.addStep('pf2_Intensity2OD');
            m.addStep('pf2_lpf', 'freq_cut', 0.05);
            tc.verifyEqual(m.Pipeline.numSteps(), 2);
            tc.verifyEqual(m.Pipeline.getStep(2).getParam('freq_cut'), 0.05);
        end

        function testInsertStep(tc)
            m = pf2_base.PipelineModel(pf2_base.RawPipeline('t').add('pf2_lpf'));
            m.insertStep(1, 'pf2_Intensity2OD');
            tc.verifyEqual(m.Pipeline.steps{1}.funcName, 'pf2_Intensity2OD');
            tc.verifyEqual(m.Pipeline.steps{2}.funcName, 'pf2_lpf');
        end

        function testRemoveStep(tc)
            m = pf2_base.PipelineModel( ...
                pf2_base.RawPipeline('t') ...
                    .add('pf2_Intensity2OD') ...
                    .add('pf2_lpf'));
            m.removeStep(2);
            tc.verifyEqual(m.Pipeline.numSteps(), 1);
            tc.verifyEqual(m.Pipeline.steps{1}.funcName, 'pf2_Intensity2OD');
        end

        function testSetParam(tc)
            m = pf2_base.PipelineModel( ...
                pf2_base.RawPipeline('t').add('pf2_lpf', 'freq_cut', 0.1));
            m.setParam(1, 'freq_cut', 0.05);
            tc.verifyEqual(m.Pipeline.getStep(1).getParam('freq_cut'), 0.05);
        end

        function testMoveStepPreservesSubclass(tc)
            m = pf2_base.PipelineModel( ...
                pf2_base.RawPipeline('t') ...
                    .add('pf2_Intensity2OD') ...
                    .add('pf2_MotionCorrectTDDR') ...
                    .add('pf2_lpf'));
            m.moveStep(3, 1);
            tc.verifyEqual(m.Pipeline.steps{1}.funcName, 'pf2_lpf');
            tc.verifyClass(m.Pipeline, 'pf2_base.RawPipeline');
        end

        function testSwapStep(tc)
            m = pf2_base.PipelineModel( ...
                pf2_base.OxyPipeline('t').add('pf2_lpf'));
            m.swapStep(1, 'pf2_hpf');
            tc.verifyEqual(m.Pipeline.steps{1}.funcName, 'pf2_hpf');
        end

        %% Undo / Redo
        function testUndoSimple(tc)
            m = pf2_base.PipelineModel( ...
                pf2_base.RawPipeline('t').add('pf2_Intensity2OD'));
            m.addStep('pf2_lpf');
            tc.verifyEqual(m.Pipeline.numSteps(), 2);
            tc.verifyTrue(m.canUndo());
            m.undo();
            tc.verifyEqual(m.Pipeline.numSteps(), 1);
            tc.verifyTrue(m.canRedo());
        end

        function testRedoAfterUndo(tc)
            m = pf2_base.PipelineModel(pf2_base.RawPipeline('t'));
            m.addStep('pf2_Intensity2OD');
            m.undo();
            m.redo();
            tc.verifyEqual(m.Pipeline.numSteps(), 1);
        end

        function testNewActionInvalidatesRedoStack(tc)
            m = pf2_base.PipelineModel(pf2_base.RawPipeline('t'));
            m.addStep('pf2_Intensity2OD');
            m.undo();
            tc.verifyTrue(m.canRedo());
            m.addStep('pf2_lpf');
            tc.verifyFalse(m.canRedo(), ...
                'New action should clear the redo stack');
        end

        function testUndoOnEmptyStackIsNoop(tc)
            m = pf2_base.PipelineModel(pf2_base.RawPipeline('t'));
            n0 = m.Pipeline.numSteps();
            m.undo(); % should not error
            tc.verifyEqual(m.Pipeline.numSteps(), n0);
        end

        function testClearHistory(tc)
            m = pf2_base.PipelineModel(pf2_base.RawPipeline('t'));
            m.addStep('pf2_Intensity2OD');
            tc.verifyTrue(m.canUndo());
            m.clearHistory();
            tc.verifyFalse(m.canUndo());
        end

        %% Events
        function testEventFiresOnEveryMutation(tc)
            m = pf2_base.PipelineModel(pf2_base.RawPipeline('t'));
            assignin('base', 'pmt_eventLog', {});
            lh = listener(m, 'PipelineChanged', ...
                @(s,e) assignin('base','pmt_eventLog', ...
                    [evalin('base','pmt_eventLog'), {e.kind}])); %#ok<NASGU>
            m.addStep('pf2_Intensity2OD');
            m.addStep('pf2_lpf', 'freq_cut', 0.05);
            m.setParam(2, 'freq_cut', 0.02);
            m.undo();
            log = evalin('base', 'pmt_eventLog');
            evalin('base', 'clear pmt_eventLog');
            tc.verifyEqual(log, {'addStep','addStep','setParam','undo'});
        end

        %% resetParam
        function testResetParamRestoresCfgDefault(tc)
            % pf2_lpf cfg default freq_cut = 0.1
            m = pf2_base.PipelineModel( ...
                pf2_base.RawPipeline('t').add('pf2_lpf'));
            m.setParam(1, 'freq_cut', 0.999);
            m.resetParam(1, 'freq_cut');
            tc.verifyEqual(m.Pipeline.getStep(1).getParam('freq_cut'), 0.1);
        end

        %% listAvailable
        function testListAvailableReturnsTable(tc)
            T = pf2_base.PipelineFunction.listAvailable();
            tc.verifyClass(T, 'table');
            cols = T.Properties.VariableNames;
            tc.verifyTrue(all(ismember( ...
                {'funcName','displayName','description','role','validStages','requiresOD'}, ...
                cols)));
        end

        function testListAvailableHasCanonicalFunctions(tc)
            T = pf2_base.PipelineFunction.listAvailable();
            tc.verifyTrue(any(T.funcName == "pf2_Intensity2OD"));
            tc.verifyTrue(any(T.funcName == "pf2_lpf"));
        end

        function testListAvailableStageFilter(tc)
            T_raw = pf2_base.PipelineFunction.listAvailable('raw');
            % All raw-stage functions must include stage 1.
            for k = 1:height(T_raw)
                tc.verifyTrue(ismember(1, T_raw.validStages{k}), ...
                    sprintf('Raw filter included %s without stage 1', T_raw.funcName(k)));
            end
        end

    end
end
