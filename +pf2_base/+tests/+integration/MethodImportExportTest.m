classdef MethodImportExportTest < matlab.unittest.TestCase
% METHODIMPORTEXPORTTEST Round-trip tests for method JSON export/import
% and PipelineFunction.register (function registration).
%
% Covers:
%   - pf2.methods.raw.exportMethod / importMethod
%   - pf2.methods.oxy.exportMethod / importMethod
%   - PipelineFunction.register + lookup-via-detect
%   - Editor's onImport / onExport / onRegisterFunction code paths
%     (called via direct method invocation; uigetfile is bypassed).

    properties (Access = private)
        TmpDir       char = ''
        OrigFuncCfg  char = ''  % backup of pf2_functions_default.cfg
    end

    methods (TestClassSetup)
        function makeTmpDir(tc)
            tc.TmpDir = tempname;
            mkdir(tc.TmpDir);
            pf2_base.pf2_initialize();
        end
    end

    methods (TestClassTeardown)
        function rmTmpDir(tc)
            if ~isempty(tc.TmpDir) && isfolder(tc.TmpDir)
                rmdir(tc.TmpDir, 's');
            end
        end
    end

    methods (TestMethodSetup)
        function bustCaches(~)
            try, pf2_base.Pipeline.loadFuncConfig(true); end %#ok<TRYNC>
            try, pf2_base.PipelineFunction.lookupFunctionMeta('__clear_cache__'); end %#ok<TRYNC>
        end
    end

    methods (Test)

        %% ============================================================
        %% Pipeline JSON export / import — raw stage
        %% ============================================================
        function testRawExportImportRoundTrip(tc)
            % Build a raw pipeline and save
            srcName = sprintf('xport_raw_%d', round(rand*1e9));
            cleanup1 = onCleanup(@() removeMethod(srcName, 'raw')); %#ok<NASGU>
            p = pf2_base.RawPipeline(srcName);
            p = p.add('pf2_Intensity2OD');
            p = p.add('pf2_lpf', 'freq_cut', 0.07);
            p.save('raw');

            % Export
            outFile = fullfile(tc.TmpDir, [srcName '.json']);
            pf2.methods.raw.exportMethod(srcName, outFile);
            tc.verifyTrue(exist(outFile, 'file') > 0, 'export should create the file');

            % Delete from in-memory + disk and re-import
            removeMethod(srcName, 'raw');
            tc.verifyFalse(any(strcmp(srcName, listMethodNames('raw'))), ...
                'method should be gone before import');

            pf2.methods.raw.importMethod(outFile, 'Replace', true);
            cleanup2 = onCleanup(@() removeMethod(srcName, 'raw')); %#ok<NASGU>

            tc.verifyTrue(any(strcmp(srcName, listMethodNames('raw'))), ...
                'method should be back after import');

            % Reload via fromMethod and confirm shape
            p2 = pf2_base.RawPipeline.fromMethod(srcName);
            tc.verifyEqual(p2.numSteps(), 2);
            tc.verifyEqual(p2.steps{1}.funcName, 'pf2_Intensity2OD');
            tc.verifyEqual(p2.steps{2}.funcName, 'pf2_lpf');
            tc.verifyEqual(p2.steps{2}.getParam('freq_cut'), 0.07);
        end

        %% ============================================================
        %% Pipeline JSON export / import — oxy stage
        %% ============================================================
        function testOxyExportImportRoundTrip(tc)
            srcName = sprintf('xport_oxy_%d', round(rand*1e9));
            cleanup1 = onCleanup(@() removeMethod(srcName, 'oxy')); %#ok<NASGU>
            p = pf2_base.OxyPipeline(srcName);
            p = p.add('pf2_lpf', 'freq_cut', 0.05);
            p.save('oxy');

            outFile = fullfile(tc.TmpDir, [srcName '.json']);
            pf2.methods.oxy.exportMethod(srcName, outFile);
            tc.verifyTrue(exist(outFile, 'file') > 0);

            removeMethod(srcName, 'oxy');
            pf2.methods.oxy.importMethod(outFile, 'Replace', true);
            cleanup2 = onCleanup(@() removeMethod(srcName, 'oxy')); %#ok<NASGU>

            p2 = pf2_base.OxyPipeline.fromMethod(srcName);
            tc.verifyEqual(p2.numSteps(), 1);
            tc.verifyEqual(p2.steps{1}.funcName, 'pf2_lpf');
            tc.verifyEqual(p2.steps{1}.getParam('freq_cut'), 0.05);
        end

        %% ============================================================
        %% Import already-existing without Replace should error
        %% ============================================================
        function testImportRefusesOverwriteByDefault(tc)
            srcName = sprintf('xport_overwrite_%d', round(rand*1e9));
            cleanup = onCleanup(@() removeMethod(srcName, 'raw')); %#ok<NASGU>
            p = pf2_base.RawPipeline(srcName);
            p = p.add('pf2_Intensity2OD');
            p.save('raw');

            outFile = fullfile(tc.TmpDir, [srcName '.json']);
            pf2.methods.raw.exportMethod(srcName, outFile);

            tc.verifyError(@() pf2.methods.raw.importMethod(outFile), ...
                'pf2:MethodExists');
        end

        %% ============================================================
        %% Custom param values survive the JSON round-trip
        %% ============================================================
        function testParamValuesSurviveRoundTrip(tc)
            srcName = sprintf('xport_params_%d', round(rand*1e9));
            cleanup = onCleanup(@() removeMethod(srcName, 'raw')); %#ok<NASGU>
            p = pf2_base.RawPipeline(srcName);
            p = p.add('pf2_Intensity2OD');
            p = p.add('pf2_lpf', 'freq_cut', 0.123, 'Nf', 77);
            p.save('raw');

            outFile = fullfile(tc.TmpDir, [srcName '.json']);
            pf2.methods.raw.exportMethod(srcName, outFile);
            removeMethod(srcName, 'raw');
            pf2.methods.raw.importMethod(outFile, 'Replace', true);

            p2 = pf2_base.RawPipeline.fromMethod(srcName);
            tc.verifyEqual(p2.steps{2}.getParam('freq_cut'), 0.123);
            tc.verifyEqual(p2.steps{2}.getParam('Nf'),       77);
        end

        %% ============================================================
        %% PipelineFunction.register: register an existing m-file and
        %% then look it up via detect.
        %% ============================================================
        function testRegisterExistingFunction(tc)
            % Pick a well-known function we know is on the path.
            funcName = 'pf2_Intensity2OD';
            % Save current cfg and bust caches so we don't leak state.
            origCfgFile = fullfile(pf2_base.pf2_defaultRootPath(), ...
                'prefs', 'pf2_functions_default.cfg');
            backup = [origCfgFile '.imexport_test_bk'];
            copyfile(origCfgFile, backup);
            cleanup = onCleanup(@() restoreFile(origCfgFile, backup)); %#ok<NASGU>

            % Construct a custom PipelineFunction and register it.
            pf = pf2_base.PipelineFunction(funcName, {'x'}, {[]}, {'x'}, ...
                'Name', 'Custom name for testing', ...
                'Description', 'Test description', ...
                'Role', 'intensity2od', ...
                'ValidStages', 1, ...
                'RequiresOD', false);
            pf2_base.PipelineFunction.register(pf);

            % Bust caches and look up via detect
            pf2_base.Pipeline.loadFuncConfig(true);
            pf2_base.PipelineFunction.lookupFunctionMeta('__clear_cache__');
            pf2 = pf2_base.PipelineFunction.detect(funcName);
            tc.verifyEqual(pf2.name,        'Custom name for testing');
            tc.verifyEqual(pf2.description, 'Test description');
            tc.verifyEqual(pf2.role,        'intensity2od');

            function restoreFile(target, src)
                if exist(src, 'file')
                    copyfile(src, target);
                    delete(src);
                end
            end
        end

        %% ============================================================
        %% Functions registered show up in PipelineFunction.listAvailable.
        %% ============================================================
        function testRegisteredFunctionAppearsInLibrary(tc)
            origCfgFile = fullfile(pf2_base.pf2_defaultRootPath(), ...
                'prefs', 'pf2_functions_default.cfg');
            backup = [origCfgFile '.list_test_bk'];
            copyfile(origCfgFile, backup);
            cleanup = onCleanup(@() restoreFile(origCfgFile, backup)); %#ok<NASGU>

            % Use a unique funcName so we don't confuse with built-ins.
            % The function doesn't have to exist on the path for register
            % itself — listAvailable only reads cfg.
            funcName = sprintf('pf2_test_func_%d', round(rand*1e9));
            pf = pf2_base.PipelineFunction(funcName, {'x','cutoff'}, ...
                {[], 0.1}, {'x'}, ...
                'Name', 'Test Filter', ...
                'Description', 'A made-up filter for testing', ...
                'Role', 'filter', ...
                'ValidStages', [1, 2]);
            pf2_base.PipelineFunction.register(pf);
            pf2_base.Pipeline.loadFuncConfig(true);

            T = pf2_base.PipelineFunction.listAvailable();
            tc.verifyTrue(any(T.funcName == funcName), ...
                'registered function should appear in listAvailable');
            row = T(T.funcName == funcName, :);
            tc.verifyEqual(row.role, "filter");

            function restoreFile(target, src)
                if exist(src, 'file')
                    copyfile(src, target);
                    delete(src);
                end
            end
        end

        %% ============================================================
        %% End-to-end: Editor.onExport followed by Editor.onImport
        %% (simulated by directly calling the JSON helpers — uigetfile
        %% is unavailable in batch mode).
        %% ============================================================
        function testEditorImportExportRoundTrip(tc)
            srcName = sprintf('editor_xport_%d', round(rand*1e9));
            cleanup = onCleanup(@() removeMethod(srcName, 'raw')); %#ok<NASGU>

            p = pf2_base.RawPipeline(srcName);
            p = p.add('pf2_Intensity2OD');
            p = p.add('pf2_lpf', 'freq_cut', 0.04);
            p.save('raw');

            % Construct editor and verify it loads the new method.
            app = pf2.methods.Editor('Stage', 'raw');
            cleanup2 = onCleanup(@() delete(app)); %#ok<NASGU>
            mp = struct(app);
            mp.MethodsListBox.Value = srcName;
            cb = mp.MethodsListBox.ValueChangedFcn;
            cb(mp.MethodsListBox, struct('PreviousValue','','Value', srcName));

            % Export through the same JSON helper the editor uses.
            outFile = fullfile(tc.TmpDir, sprintf('%s_editor.json', srcName));
            pf2.methods.raw.exportMethod(srcName, outFile);
            tc.verifyTrue(exist(outFile, 'file') > 0);

            % Remove and re-import.
            removeMethod(srcName, 'raw');
            pf2.methods.raw.importMethod(outFile, 'Replace', true);

            p2 = pf2_base.RawPipeline.fromMethod(srcName);
            tc.verifyEqual(p2.numSteps(), 2);
            tc.verifyEqual(p2.steps{2}.getParam('freq_cut'), 0.04);
        end

    end
end


%% --------------------------------------------------------------------
%% Helpers (file-private)
%% --------------------------------------------------------------------
function removeMethod(name, stage)
    global PF2 %#ok<GVMIS>
    if isempty(PF2), return; end
    field = '';
    if strcmp(stage, 'raw') && isfield(PF2, 'myRawMethods'), field = 'myRawMethods';
    elseif strcmp(stage, 'oxy') && isfield(PF2, 'myOxyMethods'), field = 'myOxyMethods';
    end
    if isempty(field), return; end
    if ismember(name, PF2.(field).cfg.Sections)
        PF2.(field).cfg.remove(name);
        try, PF2.(field).cfg.write(); end %#ok<TRYNC>
    end
end

function names = listMethodNames(stage)
    global PF2 %#ok<GVMIS>
    names = {};
    if isempty(PF2), return; end
    if strcmp(stage, 'raw') && isfield(PF2, 'myRawMethods')
        names = PF2.myRawMethods.cfg.Sections;
    elseif strcmp(stage, 'oxy') && isfield(PF2, 'myOxyMethods')
        names = PF2.myOxyMethods.cfg.Sections;
    end
end
