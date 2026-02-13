classdef PipelineTest < matlab.unittest.TestCase
% PIPELINETEST Unit tests for Pipeline, RawPipeline, and OxyPipeline

    methods (Test)

        %% ============================================================
        %%  Base Pipeline: construction
        %% ============================================================

        function testEmptyConstruction(tc)
            p = pf2_base.Pipeline();
            tc.verifyEqual(p.numSteps(), 0);
            tc.verifyEqual(p.name, '');
        end

        function testNamedConstruction(tc)
            p = pf2_base.Pipeline('myPipe', 'Description', 'A test');
            tc.verifyEqual(p.name, 'myPipe');
            tc.verifyEqual(p.description, 'A test');
        end

        %% ============================================================
        %%  Base Pipeline: add / insert / remove
        %% ============================================================

        function testAddByFuncName(tc)
            p = pf2_base.Pipeline('test');
            p = p.add('pf2_lpf');
            tc.verifyEqual(p.numSteps(), 1);
            tc.verifyEqual(p.getStep(1).funcName, 'pf2_lpf');
        end

        function testAddByPipelineFunction(tc)
            pf = pf2_base.PipelineFunction('sum', {'x','dim'}, {[],1}, {'x'});
            p = pf2_base.Pipeline('test');
            p = p.add(pf);
            tc.verifyEqual(p.numSteps(), 1);
            tc.verifyEqual(p.getStep(1).funcName, 'sum');
        end

        function testAddWithOverrides(tc)
            p = pf2_base.Pipeline('test');
            p = p.add('pf2_lpf', 'freq_cut', 0.2, 'Nf', 100);
            tc.verifyEqual(p.getStep(1).getParam('freq_cut'), 0.2);
            tc.verifyEqual(p.getStep(1).getParam('Nf'), 100);
        end

        function testAddWithExplicitSignature(tc)
            p = pf2_base.Pipeline('test');
            p = p.add('myCustomFunc', {'x','fs','alpha'}, {[],[],0.5}, {'x'});
            tc.verifyEqual(p.numSteps(), 1);
            tc.verifyEqual(p.getStep(1).funcName, 'myCustomFunc');
            tc.verifyEqual(p.getStep(1).getParam('alpha'), 0.5);
        end

        function testAddUnknownFuncWarns(tc)
            p = pf2_base.Pipeline('test');
            tc.verifyWarning(@() p.add('totallyUnknownFunc_xyz123'), ...
                'pf2:Pipeline:unknownFunc');
        end

        function testInsertAtBeginning(tc)
            p = pf2_base.Pipeline('test');
            p = p.add('pf2_lpf');
            p = p.insert(1, 'pf2_hpf');
            tc.verifyEqual(p.numSteps(), 2);
            tc.verifyEqual(p.getStep(1).funcName, 'pf2_hpf');
            tc.verifyEqual(p.getStep(2).funcName, 'pf2_lpf');
        end

        function testInsertAtEnd(tc)
            p = pf2_base.Pipeline('test');
            p = p.add('pf2_lpf');
            p = p.insert(99, 'pf2_hpf');  % beyond range, clamps to end
            tc.verifyEqual(p.numSteps(), 2);
            tc.verifyEqual(p.getStep(2).funcName, 'pf2_hpf');
        end

        function testRemove(tc)
            p = pf2_base.Pipeline('test');
            p = p.add('pf2_lpf');
            p = p.add('pf2_hpf');
            p = p.remove(1);
            tc.verifyEqual(p.numSteps(), 1);
            tc.verifyEqual(p.getStep(1).funcName, 'pf2_hpf');
        end

        function testRemoveOutOfRange(tc)
            p = pf2_base.Pipeline('test');
            p = p.add('pf2_lpf');
            tc.verifyError(@() p.remove(5), 'pf2:Pipeline:badIndex');
        end

        %% ============================================================
        %%  Base Pipeline: setParam / findStep / swapStep
        %% ============================================================

        function testSetParam(tc)
            p = pf2_base.Pipeline('test');
            p = p.add('pf2_lpf');
            p = p.setParam(1, 'freq_cut', 0.3);
            tc.verifyEqual(p.getStep(1).getParam('freq_cut'), 0.3);
        end

        function testFindStep(tc)
            p = pf2_base.Pipeline('test');
            p = p.add('pf2_lpf');
            p = p.add('pf2_hpf');
            tc.verifyEqual(p.findStep('pf2_hpf'), 2);
            tc.verifyEqual(p.findStep('nonexistent'), 0);
        end

        function testSwapStep(tc)
            p = pf2_base.Pipeline('test');
            p = p.add('pf2_lpf');
            p = p.swapStep(1, 'pf2_hpf');
            tc.verifyEqual(p.numSteps(), 1);
            tc.verifyEqual(p.getStep(1).funcName, 'pf2_hpf');
        end

        %% ============================================================
        %%  Base Pipeline: toMethod
        %% ============================================================

        function testToMethodStructure(tc)
            p = pf2_base.Pipeline('test');
            p = p.add('pf2_lpf');
            p = p.add('pf2_hpf');
            m = p.toMethod();
            tc.verifyTrue(isfield(m, 'name'));
            tc.verifyTrue(isfield(m, 'F'));
            tc.verifyEqual(m.name, 'test');
            tc.verifyEqual(numel(m.F), 2);
            tc.verifyTrue(isa(m.F{1}, 'pf2_base.PipelineFunction'));
        end

        function testToMethodEmpty(tc)
            p = pf2_base.Pipeline('empty');
            m = p.toMethod();
            tc.verifyEqual(numel(m.F), 0);
        end

        %% ============================================================
        %%  Base Pipeline: describe / disp
        %% ============================================================

        function testDescribe(tc)
            p = pf2_base.Pipeline('test', 'Description', 'My desc');
            p = p.add('pf2_lpf', 'freq_cut', 0.2);
            s = p.describe();
            tc.verifyTrue(contains(s, 'test'));
            tc.verifyTrue(contains(s, 'My desc'));
            tc.verifyTrue(contains(s, 'pf2_lpf'));
            tc.verifyTrue(contains(s, 'freq_cut'));
        end

        function testDispNoError(tc)
            p = pf2_base.Pipeline('test');
            p = p.add('pf2_lpf');
            disp(p);  % should not error
        end

        %% ============================================================
        %%  Base Pipeline: fromSteps
        %% ============================================================

        function testFromSteps(tc)
            pf1 = pf2_base.PipelineFunction('sum', {'x','dim'}, {[],1}, {'x'});
            pf2 = pf2_base.PipelineFunction('detrend', {'x','type'}, {[],'linear'}, {'x'});
            p = pf2_base.Pipeline.fromSteps('myPipe', {pf1, pf2});
            tc.verifyEqual(p.numSteps(), 2);
            tc.verifyEqual(p.getStep(1).funcName, 'sum');
            tc.verifyEqual(p.getStep(2).funcName, 'detrend');
        end

        %% ============================================================
        %%  Base Pipeline: value semantics
        %% ============================================================

        function testValueSemantics(tc)
            p1 = pf2_base.Pipeline('orig');
            p1 = p1.add('pf2_lpf');
            p2 = p1.add('pf2_hpf');  % new copy
            tc.verifyEqual(p1.numSteps(), 1);
            tc.verifyEqual(p2.numSteps(), 2);
        end

        %% ============================================================
        %%  RawPipeline
        %% ============================================================

        function testRawPipelineConstruction(tc)
            raw = pf2_base.RawPipeline('myRaw');
            tc.verifyEqual(raw.name, 'myRaw');
            tc.verifyEqual(raw.numSteps(), 0);
            tc.verifyTrue(isa(raw, 'pf2_base.Pipeline'));
        end

        function testRawPipelineAddSteps(tc)
            raw = pf2_base.RawPipeline('myRaw');
            raw = raw.add('pf2_Intensity2OD');
            raw = raw.add('pf2_MotionCorrectTDDR');
            tc.verifyEqual(raw.numSteps(), 2);
            tc.verifyEqual(raw.getStep(1).funcName, 'pf2_Intensity2OD');
            tc.verifyTrue(raw.getStep(1).isIntensity2OD);
        end

        function testRawPipelineHasIntensity2OD(tc)
            raw = pf2_base.RawPipeline('myRaw');
            tc.verifyFalse(raw.hasIntensity2OD());
            raw = raw.add('pf2_Intensity2OD');
            tc.verifyTrue(raw.hasIntensity2OD());
        end

        function testRawPipelineToMethod(tc)
            raw = pf2_base.RawPipeline('myRaw');
            raw = raw.add('pf2_Intensity2OD');
            raw = raw.add('pf2_MotionCorrectTDDR');
            m = raw.toMethod();
            tc.verifyEqual(m.name, 'myRaw');
            tc.verifyEqual(numel(m.F), 2);
        end

        %% ============================================================
        %%  OxyPipeline
        %% ============================================================

        function testOxyPipelineConstruction(tc)
            oxy = pf2_base.OxyPipeline('myOxy');
            tc.verifyEqual(oxy.name, 'myOxy');
            tc.verifyTrue(isa(oxy, 'pf2_base.Pipeline'));
        end

        function testOxyPipelineHasROI(tc)
            oxy = pf2_base.OxyPipeline('myOxy');
            tc.verifyFalse(oxy.hasROI());
            oxy = oxy.add('pf2_build_nanmean_ROI');
            tc.verifyTrue(oxy.hasROI());
        end

        function testOxyPipelineSwapROI(tc)
            oxy = pf2_base.OxyPipeline('myOxy');
            oxy = oxy.add('pf2_lpf', 'freq_cut', 0.1);
            oxy = oxy.add('pf2_build_nanmean_ROI');
            tc.verifyTrue(oxy.hasROI());
            tc.verifyEqual(oxy.getStep(2).funcName, 'pf2_build_nanmean_ROI');

            oxy = oxy.swapROI('pf2_build_pca_ROI', 'ComponentNumber', 2);
            tc.verifyEqual(oxy.numSteps(), 2);
            tc.verifyEqual(oxy.getStep(2).funcName, 'pf2_build_pca_ROI');
            tc.verifyEqual(oxy.getStep(2).getParam('ComponentNumber'), 2);
        end

        function testOxyPipelineSwapROIAppendsIfMissing(tc)
            oxy = pf2_base.OxyPipeline('myOxy');
            oxy = oxy.add('pf2_lpf');
            tc.verifyFalse(oxy.hasROI());
            oxy = oxy.swapROI('pf2_build_pca_ROI');
            tc.verifyEqual(oxy.numSteps(), 2);
            tc.verifyTrue(oxy.hasROI());
        end

        function testOxyPipelineRemoveROI(tc)
            oxy = pf2_base.OxyPipeline('myOxy');
            oxy = oxy.add('pf2_lpf');
            oxy = oxy.add('pf2_build_nanmean_ROI');
            tc.verifyTrue(oxy.hasROI());
            oxy = oxy.removeROI();
            tc.verifyFalse(oxy.hasROI());
            tc.verifyEqual(oxy.numSteps(), 1);
        end

        function testOxyPipelineRemoveROINoOp(tc)
            oxy = pf2_base.OxyPipeline('myOxy');
            oxy = oxy.add('pf2_lpf');
            oxy2 = oxy.removeROI();
            tc.verifyEqual(oxy2.numSteps(), 1);
        end

        function testOxyPipelineToMethod(tc)
            oxy = pf2_base.OxyPipeline('myOxy');
            oxy = oxy.add('pf2_lpf', 'freq_cut', 0.1);
            oxy = oxy.add('pf2_build_nanmean_ROI');
            m = oxy.toMethod();
            tc.verifyEqual(m.name, 'myOxy');
            tc.verifyEqual(numel(m.F), 2);
        end

        %% ============================================================
        %%  Custom / Unknown functions
        %% ============================================================

        function testAddCustomFunctionWithExplicitSignature(tc)
            p = pf2_base.Pipeline('test');
            p = p.add('myCustomAnalysis', ...
                {'x', 'fs', 'windowSize', 'overlap'}, ...
                {[], [], 256, 0.5}, ...
                {'x'});
            tc.verifyEqual(p.numSteps(), 1);
            pf = p.getStep(1);
            tc.verifyEqual(pf.funcName, 'myCustomAnalysis');
            tc.verifyEqual(pf.getParam('windowSize'), 256);
            tc.verifyEqual(pf.getParam('overlap'), 0.5);
        end

        function testAddCustomFunctionWithOverrides(tc)
            p = pf2_base.Pipeline('test');
            p = p.add('myCustomFilter', ...
                {'x', 'fs', 'cutoff'}, {[], [], 0.1}, {'x'}, ...
                'cutoff', 0.3);
            tc.verifyEqual(p.getStep(1).getParam('cutoff'), 0.3);
        end

        function testAddCustomFunctionMaskOutput(tc)
            p = pf2_base.Pipeline('test');
            p = p.add('myRejector', ...
                {'x', 'threshold'}, {[], 3.0}, {'fchMask'});
            pf = p.getStep(1);
            tc.verifyEqual(pf.maskOutIdx, 1);
            tc.verifyEqual(pf.xOutIdx, 0);
        end

        %% ============================================================
        %%  Multiple adds, mixed known and unknown
        %% ============================================================

        function testMixedPipeline(tc)
            p = pf2_base.Pipeline('mixed');
            p = p.add('pf2_Intensity2OD');             % known
            p = p.add('myMotionCorrect', ...           % custom
                {'x','fs','sensitivity'}, {[],[],0.8}, {'x'});
            p = p.add('pf2_lpf', 'freq_cut', 0.15);   % known with override
            tc.verifyEqual(p.numSteps(), 3);
            tc.verifyEqual(p.getStep(1).funcName, 'pf2_Intensity2OD');
            tc.verifyEqual(p.getStep(2).funcName, 'myMotionCorrect');
            tc.verifyEqual(p.getStep(2).getParam('sensitivity'), 0.8);
            tc.verifyEqual(p.getStep(3).getParam('freq_cut'), 0.15);
        end

        %% ============================================================
        %%  Incremental argument editing (addArg / removeArg / addOutput)
        %% ============================================================

        function testPipelineAddArgNewParam(tc)
            % Build a bare function then add arguments one by one
            p = pf2_base.Pipeline('test');
            p = p.add('myFunc', {'x'}, {[]}, {'x'});
            p = p.addArg(1, 'threshold', 0.5);
            p = p.addArg(1, 'windowSize', 256);

            pf = p.getStep(1);
            tc.verifyEqual(pf.getParam('threshold'), 0.5);
            tc.verifyEqual(pf.getParam('windowSize'), 256);
            tc.verifyEqual(numel(pf.argNames), 3);  % x + 2 custom
        end

        function testPipelineAddArgSpecial(tc)
            % Add a special arg like 'fs'
            p = pf2_base.Pipeline('test');
            p = p.add('myFunc', {'x'}, {[]}, {'x'});
            p = p.addArg(1, 'fs');

            pf = p.getStep(1);
            tc.verifyTrue(pf.hasSpecialArg('fs'));
            tc.verifyEqual(numel(pf.argNames), 2);  % x, fs
        end

        function testPipelineAddArgDuplicateUpdates(tc)
            % Adding an arg that already exists updates its value
            p = pf2_base.Pipeline('test');
            p = p.add('myFunc', {'x','alpha'}, {[],0.1}, {'x'});
            p = p.addArg(1, 'alpha', 0.9);

            pf = p.getStep(1);
            tc.verifyEqual(pf.getParam('alpha'), 0.9);
            tc.verifyEqual(numel(pf.argNames), 2);  % no duplication
        end

        function testPipelineRemoveArg(tc)
            p = pf2_base.Pipeline('test');
            p = p.add('pf2_lpf');  % has filtType, freq_cut, Nf
            p = p.removeArg(1, 'Nf');

            pf = p.getStep(1);
            tc.verifyFalse(ismember('Nf', pf.customNames));
            tc.verifyTrue(ismember('freq_cut', pf.customNames));
        end

        function testPipelineRemoveArgError(tc)
            p = pf2_base.Pipeline('test');
            p = p.add('pf2_lpf');
            tc.verifyError(@() p.removeArg(1, 'nonexistent'), ...
                'pf2:PipelineFunction:unknownArg');
        end

        function testPipelineAddOutput(tc)
            p = pf2_base.Pipeline('test');
            p = p.add('myFunc', {'x'}, {[]}, {'x'});
            p = p.addOutput(1, 'fchMask');

            pf = p.getStep(1);
            tc.verifyEqual(pf.nOutputs, 2);
            tc.verifyEqual(pf.xOutIdx, 1);
            tc.verifyEqual(pf.maskOutIdx, 2);
        end

        function testPipelineAddOutputDuplicateNoOp(tc)
            p = pf2_base.Pipeline('test');
            p = p.add('myFunc', {'x'}, {[]}, {'x'});
            p = p.addOutput(1, 'x');  % already exists

            pf = p.getStep(1);
            tc.verifyEqual(pf.nOutputs, 1);
        end

        function testIncrementalBuildWorkflow(tc)
            % Full workflow: start empty, build up signature piece by piece
            p = pf2_base.Pipeline('incremental');
            p = p.add('myAnalysis', {'x'}, {[]}, {'x'});

            % Add special args
            p = p.addArg(1, 'fs');
            p = p.addArg(1, 'fchMask');

            % Add custom params
            p = p.addArg(1, 'smoothing', 5);
            p = p.addArg(1, 'method', 'gaussian');

            % Add a mask output
            p = p.addOutput(1, 'fchMask');

            pf = p.getStep(1);
            tc.verifyTrue(pf.hasSpecialArg('x'));
            tc.verifyTrue(pf.hasSpecialArg('fs'));
            tc.verifyTrue(pf.hasSpecialArg('fchMask'));
            tc.verifyEqual(pf.getParam('smoothing'), 5);
            tc.verifyEqual(pf.getParam('method'), 'gaussian');
            tc.verifyEqual(pf.nOutputs, 2);
            tc.verifyEqual(pf.maskOutIdx, 2);

            % Edit a param value
            p = p.setParam(1, 'smoothing', 10);
            tc.verifyEqual(p.getStep(1).getParam('smoothing'), 10);

            % Produces valid method struct
            m = p.toMethod();
            tc.verifyTrue(isa(m.F{1}, 'pf2_base.PipelineFunction'));
        end

        %% ============================================================
        %%  PipelineFunction-level addArg / removeArg / addOutput
        %% ============================================================

        function testPFAddArg(tc)
            pf = pf2_base.PipelineFunction('myFunc', {'x'}, {[]}, {'x'});
            pf = pf.addArg('cutoff', 0.1);
            tc.verifyEqual(pf.getParam('cutoff'), 0.1);
            tc.verifyEqual(numel(pf.argNames), 2);
        end

        function testPFRemoveArg(tc)
            pf = pf2_base.PipelineFunction('myFunc', ...
                {'x','alpha','beta'}, {[],0.1,0.2}, {'x'});
            pf = pf.removeArg('beta');
            tc.verifyEqual(numel(pf.argNames), 2);
            tc.verifyEqual(pf.getParam('alpha'), 0.1);
            tc.verifyError(@() pf.getParam('beta'), 'pf2:PipelineFunction:unknownParam');
        end

        function testPFAddOutput(tc)
            pf = pf2_base.PipelineFunction('myFunc', {'x'}, {[]}, {'x'});
            pf = pf.addOutput('ROI');
            tc.verifyEqual(pf.nOutputs, 2);
            tc.verifyEqual(pf.roiOutIdx, 2);
        end

        %% ============================================================
        %%  Integration: Pipeline-generated method struct round-trip
        %% ============================================================

        function testMethodRoundTrip(tc)
            % Build a pipeline, convert to method, verify structure matches
            % what processStageRaw2OD/processStageFilterHb expect
            p = pf2_base.Pipeline('roundTrip');
            p = p.add('pf2_lpf', 'freq_cut', 0.1);
            p = p.add('pf2_hpf', 'freq_cut', 0.008);

            m = p.toMethod();

            % Must have .name and .F
            tc.verifyTrue(isfield(m, 'name'));
            tc.verifyTrue(isfield(m, 'F'));
            tc.verifyTrue(iscell(m.F));

            % Each F{i} must be a PipelineFunction
            for k = 1:numel(m.F)
                tc.verifyTrue(isa(m.F{k}, 'pf2_base.PipelineFunction'));
            end

            % Verify function names preserved
            tc.verifyEqual(m.F{1}.funcName, 'pf2_lpf');
            tc.verifyEqual(m.F{2}.funcName, 'pf2_hpf');
        end

        %% ============================================================
        %%  Name-based step addressing
        %% ============================================================

        function testSetParamByName(tc)
            p = pf2_base.Pipeline('test');
            p = p.add('pf2_lpf');
            p = p.add('pf2_hpf');
            p = p.setParam('pf2_lpf', 'freq_cut', 0.25);
            tc.verifyEqual(p.getStep(1).getParam('freq_cut'), 0.25);
        end

        function testGetStepByName(tc)
            p = pf2_base.Pipeline('test');
            p = p.add('pf2_lpf');
            p = p.add('pf2_hpf');
            pf = p.getStep('pf2_hpf');
            tc.verifyEqual(pf.funcName, 'pf2_hpf');
        end

        function testRemoveByName(tc)
            p = pf2_base.Pipeline('test');
            p = p.add('pf2_lpf');
            p = p.add('pf2_hpf');
            p = p.remove('pf2_lpf');
            tc.verifyEqual(p.numSteps(), 1);
            tc.verifyEqual(p.getStep(1).funcName, 'pf2_hpf');
        end

        function testNameNotFound(tc)
            p = pf2_base.Pipeline('test');
            p = p.add('pf2_lpf');
            tc.verifyError(@() p.getStep('nonexistent'), ...
                'pf2:Pipeline:stepNotFound');
        end

        function testSwapStepByName(tc)
            p = pf2_base.Pipeline('test');
            p = p.add('pf2_lpf');
            p = p.add('pf2_hpf');
            p = p.swapStep('pf2_lpf', 'pf2_bpf_butter');
            tc.verifyEqual(p.numSteps(), 2);
            tc.verifyEqual(p.getStep(1).funcName, 'pf2_bpf_butter');
        end

        function testAddArgByName(tc)
            p = pf2_base.Pipeline('test');
            p = p.add('myFunc', {'x'}, {[]}, {'x'});
            p = p.addArg('myFunc', 'alpha', 0.5);
            tc.verifyEqual(p.getStep('myFunc').getParam('alpha'), 0.5);
        end

        function testRemoveArgByName(tc)
            p = pf2_base.Pipeline('test');
            p = p.add('pf2_lpf');
            p = p.removeArg('pf2_lpf', 'Nf');
            tc.verifyFalse(ismember('Nf', p.getStep('pf2_lpf').customNames));
        end

        function testAddOutputByName(tc)
            p = pf2_base.Pipeline('test');
            p = p.add('myFunc', {'x'}, {[]}, {'x'});
            p = p.addOutput('myFunc', 'fchMask');
            tc.verifyEqual(p.getStep('myFunc').maskOutIdx, 2);
        end

        %% ============================================================
        %%  Bulk setParams on Pipeline
        %% ============================================================

        function testSetParamsNVPairs(tc)
            p = pf2_base.Pipeline('test');
            p = p.add('pf2_lpf');
            p = p.setParams(1, 'freq_cut', 0.2, 'Nf', 100);
            tc.verifyEqual(p.getStep(1).getParam('freq_cut'), 0.2);
            tc.verifyEqual(p.getStep(1).getParam('Nf'), 100);
        end

        function testSetParamsStruct(tc)
            p = pf2_base.Pipeline('test');
            p = p.add('pf2_lpf');
            s = p.getStep(1).params();
            s.freq_cut = 0.3;
            s.Nf = 75;
            p = p.setParams('pf2_lpf', s);
            tc.verifyEqual(p.getStep(1).getParam('freq_cut'), 0.3);
            tc.verifyEqual(p.getStep(1).getParam('Nf'), 75);
        end

        function testSetParamsByName(tc)
            p = pf2_base.Pipeline('test');
            p = p.add('pf2_lpf');
            p = p.add('pf2_hpf');
            p = p.setParams('pf2_hpf', 'freq_cut', 0.01, 'Nf', 300);
            tc.verifyEqual(p.getStep('pf2_hpf').getParam('freq_cut'), 0.01);
            tc.verifyEqual(p.getStep('pf2_hpf').getParam('Nf'), 300);
            % First step unchanged
            tc.verifyEqual(p.getStep(1).getParam('freq_cut'), 0.1);
        end

        %% ============================================================
        %%  Pipeline-level params table
        %% ============================================================

        function testPipelineParams(tc)
            p = pf2_base.Pipeline('test');
            p = p.add('pf2_Intensity2OD');
            p = p.add('pf2_lpf', 'freq_cut', 0.2);

            tbl = p.params();
            tc.verifyTrue(istable(tbl));
            tc.verifyTrue(all(ismember({'Step','Function','Parameter','Value'}, ...
                tbl.Properties.VariableNames)));

            % Step 1 has no params → shows (none)
            row1 = tbl(tbl.Step == 1, :);
            tc.verifyEqual(row1.Parameter{1}, '(none)');

            % Step 2 has params
            row2 = tbl(tbl.Step == 2, :);
            tc.verifyTrue(height(row2) >= 2);  % at least freq_cut, Nf
            tc.verifyTrue(any(strcmp(row2.Parameter, 'freq_cut')));
        end

        function testPipelineParamsEmpty(tc)
            p = pf2_base.Pipeline('empty');
            tbl = p.params();
            tc.verifyTrue(istable(tbl));
            tc.verifyEqual(height(tbl), 0);
        end

        %% ============================================================
        %%  addFromString
        %% ============================================================

        function testAddFromString(tc)
            p = pf2_base.Pipeline('test');
            p = p.addFromString('[x]=pf2_lpf(x,1,fs,0.2,100)');
            tc.verifyEqual(p.numSteps(), 1);
            tc.verifyEqual(p.getStep(1).funcName, 'pf2_lpf');
            tc.verifyEqual(p.getStep(1).getParam('freq_cut'), 0.2);
            tc.verifyEqual(p.getStep(1).getParam('Nf'), 100);
        end

        function testAddFromStringChained(tc)
            p = pf2_base.Pipeline('test');
            p = p.addFromString('pf2_Intensity2OD(x)');
            p = p.addFromString('[x]=pf2_lpf(x,1,fs,0.1,50)');
            tc.verifyEqual(p.numSteps(), 2);
            tc.verifyEqual(p.getStep(1).funcName, 'pf2_Intensity2OD');
            tc.verifyEqual(p.getStep(2).funcName, 'pf2_lpf');
        end

    end
end
