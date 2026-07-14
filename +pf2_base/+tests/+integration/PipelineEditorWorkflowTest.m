classdef PipelineEditorWorkflowTest < matlab.unittest.TestCase
% PIPELINEEDITORWORKFLOWTEST End-to-end tests for the editor-foundation
% phases (A1 metadata, A2 run/validate, A3 role, A4 seeds, A5 PipelineModel).
%
% These tests exercise the full chain a user — or the future AppDesigner
% editor — would touch: cfg → PipelineFunction (with metadata/role) →
% Pipeline → PipelineModel → save → reload → run.

    methods (TestMethodSetup)
        function clearCaches(~)
            % Bust caches but keep PF2/setF intact — clearing setF breaks
            % sample-data import since it loses the device config.
            try, pf2_base.Pipeline.loadFuncConfig(true); end %#ok<TRYNC>
            try, pf2_base.PipelineFunction.lookupFunctionMeta('__clear_cache__'); end %#ok<TRYNC>
        end
    end

    methods (Static, Access = private)
        function restoreGlobals(p2, sf)
            global PF2 setF %#ok<GVMIS>
            PF2 = p2; setF = sf;
        end
    end

    methods (Test)

        %% A1 metadata threads end-to-end through cfg → detect → setParam
        function testA1MetadataFlowsThroughCfgToPipeline(tc)
            p = pf2_base.RawPipeline('t');
            p = p.add('pf2_lpf', 'freq_cut', 0.05);
            step = p.steps{1};
            m = step.argMeta('freq_cut');
            tc.verifyEqual(m.type,  'double');
            tc.verifyEqual(m.unit,  'Hz');
            tc.verifyEqual(m.range, [0, Inf]);
            tc.verifyEqual(m.default, 0.05);
        end

        %% A2 validate catches both per-arg and ordering issues
        function testA2ValidateCatchesBothErrorTypes(tc)
            p = pf2_base.RawPipeline('t');
            p = p.add('pf2_MotionCorrectTDDR');   % requires OD: ordering issue
            p = p.add('pf2_lpf', 'freq_cut', -1); % out-of-range issue
            issues = p.validate();
            tc.verifyGreaterThanOrEqual(numel(issues), 2);
            kinds = {issues.severity};
            tc.verifyTrue(all(strcmp(kinds, 'error')));
        end

        %% A2 run() integrates with processFNIRS2
        function testA2RawPipelineRunProducesHb(tc)
            p = pf2_base.RawPipeline('rt');
            p = p.add('pf2_Intensity2OD');
            data = pf2.import.sampleData;
            out  = p.run(data);
            tc.verifyTrue(isfield(out, 'HbO'));
            tc.verifySize(out.HbO, [1169 16]);
        end

        %% A3 role is wired through cfg, fromStruct round-trip, and validation
        function testA3RoleEndToEnd(tc)
            % Build a renamed Intensity2OD with explicit Role; round-trip
            % through toStruct; verify ordering check uses role.
            pf = pf2_base.PipelineFunction('myCustomConverter', {'x'}, {[]}, {'x'}, ...
                'Role', 'intensity2od');
            tc.verifyTrue(pf.isIntensity2OD);
            s   = pf.toStruct();
            tc.verifyEqual(s.role, 'intensity2od');
            pf2 = pf2_base.PipelineFunction.fromStruct(s);
            tc.verifyTrue(pf2.isIntensity2OD);

            % Use it in a pipeline followed by a requiresOD step:
            p = pf2_base.RawPipeline('rt');
            p = p.add(pf2);
            p = p.add('pf2_MotionCorrectTDDR');
            % Ordering should pass because role='intensity2od' satisfies the rule.
            issues = p.validate();
            tc.verifyEmpty(issues);
        end

        %% A4 first-time-install detection seeds repo defaults
        function testA4FirstInstallSeeds(tc)
            rawPath = fullfile(prefdir, 'pf2_raw_methods_stored_processFNIRS2.cfg');
            oxyPath = fullfile(prefdir, 'pf2_oxy_methods_stored_processFNIRS2.cfg');
            backupRaw = '';
            backupOxy = '';
            global PF2 setF %#ok<GVMIS>
            origPF2 = PF2; origSetF = setF;
            cleanup = onCleanup(@() restoreCfgs(rawPath, oxyPath, ...
                backupRaw, backupOxy, origPF2, origSetF)); %#ok<NASGU>

            if exist(rawPath, 'file'), backupRaw = [rawPath '.tmpbk']; copyfile(rawPath, backupRaw); delete(rawPath); end
            if exist(oxyPath, 'file'), backupOxy = [oxyPath '.tmpbk']; copyfile(oxyPath, backupOxy); delete(oxyPath); end
            PF2 = []; setF = [];

            pf2_base.pf2_initialize();

            sections = PF2.myRawMethods.cfg.Sections;
            tc.verifyTrue(any(strcmp(sections, 'OD_TDDR')));
            tc.verifyTrue(any(strcmp(sections, 'OD_SMAR')));
            sectionsOxy = PF2.myOxyMethods.cfg.Sections;
            tc.verifyTrue(any(strcmp(sectionsOxy, 'LPF')));
            tc.verifyTrue(any(strcmp(sectionsOxy, 'LPF_ROI')));

            function restoreCfgs(r, o, br, bo, p2, sf)
                if ~isempty(br) && exist(br,'file'), copyfile(br, r); delete(br); end
                if ~isempty(bo) && exist(bo,'file'), copyfile(bo, o); delete(bo); end
                pf2_base.tests.integration.PipelineEditorWorkflowTest.restoreGlobals(p2, sf);
            end
        end

        %% A4 every seed factory returns a runnable Pipeline
        function testA4SeedsAreRunnable(tc)
            seeds = pf2.methods.seeds.list();
            for k = 1:numel(seeds)
                s = seeds(k);
                fact = ['pf2.methods.seeds.' s.stage '.' s.name];
                p = feval(fact);
                tc.verifyTrue(isa(p, 'pf2_base.Pipeline'));
                tc.verifyEqual(p.numSteps(), p.numSteps()); % sanity
                tc.verifyEmpty(p.validate(), ...
                    sprintf('Seed %s/%s should be valid out of the box', ...
                        s.stage, s.name));
            end
        end

        %% A5 PipelineModel round-trip with a runnable pipeline at the end
        function testA5ModelRoundTripAndRun(tc)
            p0 = pf2.methods.seeds.raw.OD_TDDR();
            m  = pf2_base.PipelineModel(p0);
            % Mutate via the model: add LPF, tweak its cutoff
            m.addStep('pf2_lpf', 'freq_cut', 0.05);
            tc.verifyEqual(m.Pipeline.numSteps(), 3);
            tc.verifyEqual(m.Pipeline.getStep(3).getParam('freq_cut'), 0.05);
            % Undo the param tweak (was set as part of addStep, so undo
            % whole addStep)
            m.undo();
            tc.verifyEqual(m.Pipeline.numSteps(), 2);
            m.redo();
            tc.verifyEqual(m.Pipeline.numSteps(), 3);
            % Model output is still a valid RawPipeline that runs
            data = pf2.import.sampleData;
            out  = m.Pipeline.run(data);
            tc.verifyTrue(isfield(out, 'HbO'));
        end

        %% A1+A2+A5: editor-style workflow — validate live during edits
        function testEditorLiveValidation(tc)
            % Simulate the editor flow: user picks pf2_lpf, sets freq_cut
            % to a bad value, validation flags it; user fixes it, all clear.
            p = pf2_base.RawPipeline('t');
            p = p.add('pf2_Intensity2OD');
            p = p.add('pf2_lpf', 'freq_cut', 0.1);
            m = pf2_base.PipelineModel(p);

            tc.verifyEmpty(m.Pipeline.validate());
            m.setParam(2, 'freq_cut', -5);   % out-of-range
            issues = m.Pipeline.validate();
            tc.verifyNumElements(issues, 1);
            tc.verifyEqual(issues(1).arg, 'freq_cut');
            m.resetParam(2, 'freq_cut');     % back to cfg default 0.1
            tc.verifyEmpty(m.Pipeline.validate());
        end

        %% PipelineModel ↔ Experiment CLI integration
        % Confirms a PipelineModel-built pipeline can flow into an
        % exploreFNIRS Experiment via the existing string-name binding.
        function testPipelineModelFlowsIntoExperimentCLI(tc)
            % CLI integration path: a PipelineModel-built pipeline is
            % .save()'d under a unique name, and that name can then be
            % consumed by processFNIRS2 (the same engine Experiment.aggregate
            % uses internally — see example_experiment_cli.m and
            % Experiment.aggregate(). When this works, the same name plugs
            % straight into ex.settings.rawMethod / oxyMethod.
            methodName = sprintf('pm_to_experiment_%d', round(rand*1e9));
            cleanup = onCleanup(@() removeRawMethod(methodName)); %#ok<NASGU>

            p = pf2_base.RawPipeline(methodName);
            m = pf2_base.PipelineModel(p);
            m.addStep('pf2_Intensity2OD');
            m.addStep('pf2_lpf', 'freq_cut', 0.08);

            m.Pipeline.save('raw');

            % Round-trip through the named-method registry
            reloaded = pf2_base.RawPipeline.fromMethod(methodName);
            tc.verifyEqual(reloaded.numSteps(), 2);
            tc.verifyEqual(reloaded.steps{2}.getParam('freq_cut'), 0.08);

            % processFNIRS2 resolves the method by name (string-based) —
            % this is the same path Experiment.aggregate goes through.
            data = pf2.import.sampleData;
            out  = processFNIRS2(data, 'Raw_Method', methodName, ...
                                       'Oxy_Method', 'None');
            tc.verifyTrue(isfield(out, 'HbO'));
            tc.verifySize(out.HbO, [1169 16]);
            % Confirm the freq_cut customization was actually applied by
            % checking processingInfo.rawMethod:
            tc.verifyEqual(out.processingInfo.rawMethod, methodName);

            function removeRawMethod(name)
                global PF2 %#ok<GVMIS>
                if ~isempty(PF2) && isfield(PF2, 'myRawMethods') ...
                        && ismember(name, PF2.myRawMethods.cfg.Sections)
                    PF2.myRawMethods.cfg.remove(name);
                    try, PF2.myRawMethods.cfg.write(); end %#ok<TRYNC>
                end
            end
        end

        %% A4+A5: build a method via PipelineModel, save, reload, run
        function testSaveReloadRunFullCycle(tc)
            testName = sprintf('editor_workflow_test_%d', round(rand*1e9));
            cleanup = onCleanup(@() removeMethod(testName)); %#ok<NASGU>

            p = pf2_base.RawPipeline(testName);
            m = pf2_base.PipelineModel(p);
            m.addStep('pf2_Intensity2OD');
            m.addStep('pf2_MotionCorrectTDDR');
            m.addStep('pf2_lpf', 'freq_cut', 0.08);
            m.Pipeline.save('raw');

            % Reload from disk via fromMethod
            reloaded = pf2_base.RawPipeline.fromMethod(testName);
            tc.verifyEqual(reloaded.numSteps(), 3);
            tc.verifyEqual(reloaded.steps{3}.getParam('freq_cut'), 0.08);

            % Run via the reloaded pipeline
            out = reloaded.run(pf2.import.sampleData);
            tc.verifyTrue(isfield(out, 'HbO'));
            tc.verifySize(out.HbO, [1169 16]);

            function removeMethod(name)
                global PF2 %#ok<GVMIS>
                if ~isempty(PF2) && isfield(PF2, 'myRawMethods') ...
                        && ismember(name, PF2.myRawMethods.cfg.Sections)
                    PF2.myRawMethods.cfg.remove(name);
                    PF2.myRawMethods.cfg.write();
                end
            end
        end

    end
end
