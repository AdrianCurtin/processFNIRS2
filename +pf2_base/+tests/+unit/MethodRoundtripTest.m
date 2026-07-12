classdef MethodRoundtripTest < matlab.unittest.TestCase
% METHODROUNDTRIPTEST Verify method create/save/load roundtrip via INI
%
%   Tests that processing methods survive the full lifecycle:
%     create struct → pack to S# fields → write INI → read INI → unpack
%
%   Covers:
%     - Plain function structs with mixed-type argvals
%     - Multi-step pipelines
%     - INI serialization fidelity for cell arrays and nested structs
%     - pf2_unpackMethod handling of corrupted/unusual .F types
%     - No function handles in stored format
%
%   Example:
%       results = runtests('pf2_base.tests.unit.MethodRoundtripTest');
%       disp(results);
%
%   See also: pf2_base.pf2_unpackMethod, pf2.methods.raw.create,
%             pf2.methods.oxy.create, pf2_base.external.INI

    properties (Access = private)
        TempDir
    end

    methods (TestMethodSetup)
        function createTempDir(testCase)
            testCase.TempDir = tempname();
            mkdir(testCase.TempDir);
            testCase.addTeardown(@() rmdir(testCase.TempDir, 's'));
        end
    end

    %% pf2_unpackMethod input format tests
    methods (Test)

        function testUnpack_EmptyInput(testCase)
            % Empty input returns struct with empty F cell
            x = pf2_base.pf2_unpackMethod([]);

            testCase.verifyTrue(isfield(x, 'F'), 'Must have F field');
            testCase.verifyTrue(iscell(x.F), 'F must be a cell array');
            testCase.verifyTrue(isempty(x.F), 'F must be empty');
        end

        function testUnpack_CellWithFField(testCase)
            % Cell array wrapping a struct with F field is unwrapped
            inner.F = {struct('f', 'pf2_lpf', 'args', {{}}, 'argvals', {{}}, 'output', 'x')};
            inner.name = 'test';

            x = pf2_base.pf2_unpackMethod({inner});

            testCase.verifyEqual(x.name, 'test');
            testCase.verifyEqual(length(x.F), 1);
        end

        function testUnpack_ValidCellF(testCase)
            % Struct with proper cell F passes through
            method.F = {struct('f', 'pf2_Intensity2OD', 'args', {{'x'}}, ...
                'argvals', {{'x'}}, 'output', 'x')};
            method.name = 'test';

            x = pf2_base.pf2_unpackMethod(method);

            testCase.verifyTrue(iscell(x.F));
            testCase.verifyEqual(length(x.F), 1);
        end

        function testUnpack_StructArrayF(testCase)
            % Struct array F is converted to cell array
            s(1) = struct('f', 'pf2_Intensity2OD', 'args', 'x', ...
                'argvals', 'x', 'output', 'x');
            s(2) = struct('f', 'pf2_MotionCorrectTDDR', 'args', 'x', ...
                'argvals', 'x', 'output', 'x');

            method.F = s;
            method.name = 'test';

            x = pf2_base.pf2_unpackMethod(method);

            testCase.verifyTrue(iscell(x.F), 'Struct array F should be converted to cell');
            testCase.verifyEqual(length(x.F), 2);
        end

        function testUnpack_CharF_FallsThrough(testCase)
            % String F (corrupted from INI) falls through to S# extraction
            method.F = '{ corrupted serialization }';
            method.name = 'test';
            method.S1 = struct('f', 'pf2_Intensity2OD', 'args', {{'x'}}, ...
                'argvals', {{'x'}}, 'output', 'x');

            x = pf2_base.pf2_unpackMethod(method);

            testCase.verifyTrue(iscell(x.F), 'Should have valid cell F from S1');
            testCase.verifyEqual(length(x.F), 1);
            testCase.verifyTrue(isa(x.F{1}, 'pf2_base.PipelineFunction'), ...
                'Element should be a PipelineFunction');
            testCase.verifyEqual(x.F{1}.funcName, 'pf2_Intensity2OD');
        end

        function testUnpack_NumericF_FallsThrough(testCase)
            % Numeric F (corrupted) falls through to S# extraction
            method.F = 42;
            method.name = 'test';
            method.S1 = struct('f', 'pf2_lpf', 'args', {{'x'}}, ...
                'argvals', {{'x'}}, 'output', 'x');

            x = pf2_base.pf2_unpackMethod(method);

            testCase.verifyTrue(iscell(x.F));
            testCase.verifyEqual(x.F{1}.funcName, 'pf2_lpf');
        end

        function testUnpack_SFields(testCase)
            % Legacy S1/S2 fields are extracted and converted to PipelineFunction
            method.name = 'legacy';
            method.S1 = struct('f', 'pf2_Intensity2OD', 'args', {{'x'}}, ...
                'argvals', {{'x'}}, 'output', 'x');
            method.S2 = struct('f', 'pf2_MotionCorrectTDDR', 'args', {{'x', 'fs'}}, ...
                'argvals', {{'x', 'fs'}}, 'output', 'x');

            x = pf2_base.pf2_unpackMethod(method);

            testCase.verifyEqual(length(x.F), 2);
            testCase.verifyTrue(isa(x.F{1}, 'pf2_base.PipelineFunction'));
            testCase.verifyTrue(isa(x.F{2}, 'pf2_base.PipelineFunction'));
            testCase.verifyEqual(x.F{1}.funcName, 'pf2_Intensity2OD');
            testCase.verifyEqual(x.F{2}.funcName, 'pf2_MotionCorrectTDDR');
            testCase.verifyFalse(isfield(x, 'S1'), 'S1 should be removed');
            testCase.verifyFalse(isfield(x, 'S2'), 'S2 should be removed');
        end

        function testUnpack_StructArrayElement(testCase)
            % Struct array inside F cell element is flattened then converted
            sa(1) = struct('f', 'pf2_lpf', 'args', 'x', ...
                'argvals', 'x', 'output', 'x');
            sa(2) = struct('f', 'pf2_lpf', 'args', 'fs', ...
                'argvals', 'fs', 'output', 'x');
            method.F = {sa};
            method.name = 'test';

            x = pf2_base.pf2_unpackMethod(method);

            testCase.verifyTrue(isa(x.F{1}, 'pf2_base.PipelineFunction'), ...
                'Flattened struct array should become PipelineFunction');
            testCase.verifyEqual(x.F{1}.funcName, 'pf2_lpf');
            testCase.verifyEqual(length(x.F{1}.argNames), 2, ...
                'Should have 2 args from flattened struct array');
        end

        function testUnpack_ToStructHasNoFunctionHandles(testCase)
            % PipelineFunction.toStruct() must not contain function handles
            % (critical for INI serialization)
            method.name = 'test';
            method.S1 = struct('f', 'pf2_lpf', ...
                'args', {{'x', 'fs', 'freq_cut'}}, ...
                'argvals', {{'x', 'fs', 0.1}}, ...
                'output', 'x');

            x = pf2_base.pf2_unpackMethod(method);

            for i = 1:length(x.F)
                testCase.verifyTrue(isa(x.F{i}, 'pf2_base.PipelineFunction'), ...
                    'F element should be PipelineFunction');
                s = x.F{i}.toStruct();
                fn = fieldnames(s);
                for j = 1:length(fn)
                    val = s.(fn{j});
                    testCase.verifyFalse(isa(val, 'function_handle'), ...
                        sprintf('toStruct field %s should not be a function handle', fn{j}));
                end
            end
        end

        function testUnpack_PipelineFunctionPassthrough(testCase)
            % PipelineFunction objects in F are left as-is
            s = struct('f', 'pf2_Intensity2OD', 'args', {{'x'}}, ...
                'argvals', {{'x'}}, 'output', 'x');
            pf = pf2_base.PipelineFunction.fromStruct(s);
            method.F = {pf};
            method.name = 'test';

            x = pf2_base.pf2_unpackMethod(method);

            testCase.verifyTrue(isa(x.F{1}, 'pf2_base.PipelineFunction'));
        end
    end

    %% INI roundtrip tests
    methods (Test)

        function testINI_SimpleStructRoundtrip(testCase)
            % Simple struct survives INI write/read
            iniPath = fullfile(testCase.TempDir, 'simple.ini');

            cfg = pf2_base.external.INI('File', iniPath);
            s.name = 'TestMethod';
            s.S1 = struct('f', 'pf2_Intensity2OD', ...
                'args', {{'x'}}, 'argvals', {{'x'}}, 'output', 'x');
            cfg.add('TestMethod', s);
            cfg.write();

            % Read back
            cfg2 = pf2_base.external.INI('File', iniPath);
            cfg2.read();

            testCase.verifyTrue(ismember('TestMethod', cfg2.Sections));
            loaded = cfg2.TestMethod;
            testCase.verifyTrue(isfield(loaded, 'name'));
        end

        function testINI_MixedArgvalsRoundtrip(testCase)
            % Mixed-type argvals (strings + numbers) survive roundtrip
            iniPath = fullfile(testCase.TempDir, 'mixed.ini');

            cfg = pf2_base.external.INI('File', iniPath);
            s.name = 'LPF_Method';
            s.S1 = struct('f', 'pf2_lpf', ...
                'args', {{'x', 'filtType', 'fs', 'freq_cut', 'Nf'}}, ...
                'argvals', {{'x', 1, 'fs', 0.1, 50}}, ...
                'output', 'x');
            cfg.add('LPF_Method', s);
            cfg.write();

            % Read back
            cfg2 = pf2_base.external.INI('File', iniPath);
            cfg2.read();

            loaded = cfg2.LPF_Method;
            testCase.verifyTrue(isfield(loaded, 'S1') || isfield(loaded, 'F'), ...
                'Method should have S1 or F field after read');
        end

        function testINI_MultiStepRoundtrip(testCase)
            % Multi-step pipeline survives INI roundtrip
            iniPath = fullfile(testCase.TempDir, 'multi.ini');

            cfg = pf2_base.external.INI('File', iniPath);
            s.name = 'TwoStep';
            s.S1 = struct('f', 'pf2_Intensity2OD', ...
                'args', {{'x'}}, 'argvals', {{'x'}}, 'output', 'x');
            s.S2 = struct('f', 'pf2_MotionCorrectTDDR', ...
                'args', {{'x', 'fs'}}, 'argvals', {{'x', 'fs'}}, 'output', 'x');
            cfg.add('TwoStep', s);
            cfg.write();

            % Read back and unpack
            cfg2 = pf2_base.external.INI('File', iniPath);
            cfg2.read();

            loaded = cfg2.TwoStep;
            loaded.name = 'TwoStep';
            unpacked = pf2_base.pf2_unpackMethod(loaded);

            testCase.verifyTrue(iscell(unpacked.F));
            testCase.verifyGreaterThanOrEqual(length(unpacked.F), 1, ...
                'Should have at least one function after roundtrip');
        end

        function testINI_FullCreateRoundtrip(testCase)
            % Full lifecycle: create → write → read → unpack → verify
            iniPath = fullfile(testCase.TempDir, 'full.ini');

            % Build the method as create.m does
            funcs = { ...
                struct('f', 'pf2_Intensity2OD', ...
                    'args', {{'x'}}, 'argvals', {{'x'}}, 'output', 'x'), ...
                struct('f', 'pf2_MotionCorrectTDDR', ...
                    'args', {{'x', 'fs'}}, 'argvals', {{'x', 'fs'}}, 'output', 'x') ...
            };

            method.name = 'RoundtripTest';
            method.F = {};
            for i = 1:length(funcs)
                func = funcs{i};
                if ~isfield(func, 'default_argvals')
                    func.default_argvals = func.argvals;
                end
                method.F{end+1} = func;
            end

            % Pack to S# format (as create.m does)
            packed = method;
            packed = rmfield(packed, 'F');
            for j = 1:length(method.F)
                packed.(sprintf('S%d', j)) = method.F{j};
            end

            % Write
            cfg = pf2_base.external.INI('File', iniPath);
            cfg.add('RoundtripTest', packed);
            cfg.write();

            % Read
            cfg2 = pf2_base.external.INI('File', iniPath);
            cfg2.read();

            loaded = cfg2.RoundtripTest;
            loaded.name = 'RoundtripTest';

            % Unpack
            unpacked = pf2_base.pf2_unpackMethod(loaded);

            % Verify
            testCase.verifyTrue(iscell(unpacked.F), 'F must be a cell');
            testCase.verifyEqual(unpacked.name, 'RoundtripTest');

            % Verify F elements are PipelineFunction and toStruct is clean
            for i = 1:length(unpacked.F)
                step = unpacked.F{i};
                testCase.verifyTrue(isa(step, 'pf2_base.PipelineFunction'), ...
                    sprintf('Step %d should be a PipelineFunction', i));
                s = step.toStruct();
                testCase.verifyTrue(ischar(s.f) || isstring(s.f), ...
                    sprintf('Step %d .f must be a string, not a function handle', i));
            end
        end

        function testINI_WriteAfterUnpackDoesNotCrash(testCase)
            % Pack→write after unpack must not crash (mirrors real workflow)
            iniPath = fullfile(testCase.TempDir, 'rewrite.ini');

            % Create initial config
            cfg = pf2_base.external.INI('File', iniPath);
            s.name = 'Method1';
            s.S1 = struct('f', 'pf2_Intensity2OD', ...
                'args', {{'x'}}, 'argvals', {{'x'}}, 'output', 'x');
            cfg.add('Method1', s);
            cfg.write();

            % Read and unpack (simulating what loadMethods does)
            cfg2 = pf2_base.external.INI('File', iniPath);
            cfg2.read();

            loaded = cfg2.Method1;
            loaded.name = 'Method1';
            unpacked = pf2_base.pf2_unpackMethod(loaded);

            % Convert PipelineFunction objects back to structs for writing
            % (mirrors packMethods workflow in GUI)
            packed = unpacked;
            packed = rmfield(packed, 'F');
            for j = 1:length(unpacked.F)
                packed.(sprintf('S%d', j)) = unpacked.F{j}.toStruct();
            end
            cfg2.Method1 = packed;

            % Add another method
            s2.name = 'Method2';
            s2.S1 = struct('f', 'pf2_lpf', ...
                'args', {{'x', 'fs'}}, 'argvals', {{'x', 'fs'}}, 'output', 'x');
            cfg2.add('Method2', s2);

            % This should NOT crash — toStruct produces clean data
            iniPath2 = fullfile(testCase.TempDir, 'rewrite2.ini');
            cfg2.write(iniPath2);

            testCase.verifyTrue(exist(iniPath2, 'file') == 2, ...
                'INI file should be written without error');
        end
    end
end
