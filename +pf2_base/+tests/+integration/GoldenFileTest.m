classdef GoldenFileTest < matlab.unittest.TestCase
% GOLDENFILETEST Regression tests comparing outputs against golden reference files
%
% Parameterized test class that loads golden .mat files, reproduces
% processing with the same parameters, and verifies outputs match
% within tolerance.
%
% Example:
%   results = runtests('pf2_base.tests.integration.GoldenFileTest');
%
% See also: pf2_base.tests.generateGoldenFiles,
%           pf2_base.tests.golden.verifyGolden

    properties (TestParameter)
        goldenFile = pf2_base.tests.integration.GoldenFileTest.findGoldenFiles();
    end

    methods (Test)
        function testAgainstGolden(testCase, goldenFile)
            % Load golden reference
            golden = load(goldenFile);

            % Verify required fields exist
            testCase.assertThat(golden, ...
                matlab.unittest.constraints.HasField('output'), ...
                'Golden file missing output field');
            testCase.assertThat(golden, ...
                matlab.unittest.constraints.HasField('params'), ...
                'Golden file missing params field');

            % Determine test type based on path
            [~, fileName] = fileparts(goldenFile);

            if contains(goldenFile, fullfile('tests', 'golden', 'processFNIRS2'))
                % Pipeline golden test
                testCase.runPipelineGolden(golden, fileName);
            elseif contains(goldenFile, fullfile('tests', 'golden', 'functions'))
                % Function golden test
                testCase.runFunctionGolden(golden, fileName);
            else
                testCase.assertFail(sprintf('Unknown golden file location: %s', goldenFile));
            end
        end
    end

    methods (Access = private)
        function runPipelineGolden(testCase, golden, fileName)
            % Load sample data
            data = pf2.import.sampleData.fNIR2000();

            % Verify input hash
            if isfield(golden, 'inputHash')
                actualHash = pf2_base.tests.golden.computeHash(data.raw);
                testCase.assertEqual(actualHash, golden.inputHash, ...
                    'Input data has changed - golden file may need regeneration');
            end

            % Resolve methods from params. Shipped methods are rebuilt from
            % their seed factories, so the golden checks the shipped
            % definition regardless of the stored methods (which a user or
            % a test-isolated prefdir may have edited or not seeded).
            ctx = pf2.ProcessingContext();
            if isfield(golden.params, 'rawMethod')
                m = testCase.resolveMethod(golden.params.rawMethod, 'raw');
                if ischar(m), ctx.setRawMethod(m); else, ctx.rawMethod = m; end
            end
            if isfield(golden.params, 'oxyMethod')
                m = testCase.resolveMethod(golden.params.oxyMethod, 'oxy');
                if ischar(m), ctx.setOxyMethod(m); else, ctx.oxyMethod = m; end
            end

            % Process
            processed = ctx.process(data);

            % Compare output
            result = compareOutputs(golden.output, extractOutput(processed), 1e-10);
            testCase.verifyTrue(result.passed, ...
                sprintf('Golden file mismatch for %s:\n%s', fileName, strjoin(result.failures, '\n')));
        end

        function method = resolveMethod(testCase, name, stage)
            % Shipped seed -> method struct; any other name (including
            % 'None') is returned for the context to resolve, and must
            % exist in the stored method library
            name = char(name);
            if strcmp(name, 'None')
                method = name;
                return
            end
            seedFcn = sprintf('pf2_base.methods.seeds.%s.%s', stage, name);
            if exist(seedFcn, 'file')
                method = feval(seedFcn).toMethod();
                return
            end
            lib = pf2_base.resolveMethodsLib(stage);
            testCase.assumeTrue(ismember(name, lib.cfg.Sections), ...
                sprintf('%s method ''%s'' is neither a shipped seed nor stored', stage, name));
            method = name;
        end

        function runFunctionGolden(testCase, golden, fileName)
            % Load sample data
            data = pf2.import.sampleData.fNIR2000();
            testCase.assumeTrue(isfield(golden.params, 'function'), ...
                'Golden file params missing ''function'' field');
            funcName = golden.params.function;

            % Each function's golden is generated from its valid input
            % domain: SMAR on raw intensity, everything else on OD
            switch funcName
                case 'pf2_SMAR'
                    input = data.raw;
                otherwise
                    input = pf2_Intensity2OD(data.raw);
            end

            % Verify input hash
            if isfield(golden, 'inputHash')
                actualHash = pf2_base.tests.golden.computeHash(input);
                testCase.assertEqual(actualHash, golden.inputHash, ...
                    'Input data has changed - golden file may need regeneration');
            end

            % Run function based on params
            switch funcName
                case 'pf2_MotionCorrectTDDR'
                    actualOutput = struct('corrected', pf2_MotionCorrectTDDR(input, golden.params.fs));
                case 'pf2_SMAR'
                    actualOutput = struct('corrected', pf2_SMAR(input, 10));
                otherwise
                    testCase.assumeFail(sprintf('Unknown function: %s', funcName));
            end

            % Compare output
            result = compareOutputs(golden.output, actualOutput, 1e-10);
            testCase.verifyTrue(result.passed, ...
                sprintf('Golden file mismatch for %s:\n%s', fileName, strjoin(result.failures, '\n')));
        end
    end

    methods (Static)
        function files = findGoldenFiles()
            % Find all golden .mat files
            thisFile = mfilename('fullpath');
            projectRoot = fileparts(fileparts(fileparts(fileparts(thisFile))));

            files = {};
            dirs = {fullfile(projectRoot, 'tests', 'golden', 'processFNIRS2'), ...
                    fullfile(projectRoot, 'tests', 'golden', 'functions')};

            for d = 1:length(dirs)
                if isfolder(dirs{d})
                    listing = dir(fullfile(dirs{d}, '*.mat'));
                    for f = 1:length(listing)
                        files{end+1} = fullfile(listing(f).folder, listing(f).name); %#ok<AGROW>
                    end
                end
            end

            if isempty(files)
                % Return a placeholder so the test class can still be instantiated
                files = {'__no_golden_files__'};
            end
        end
    end
end


function out = extractOutput(processed)
% Extract key output fields for golden comparison
out = struct();
fields = {'HbO', 'HbR', 'HbTotal', 'HbDiff', 'CBSI', 'units', 'DPF_factor'};
for i = 1:length(fields)
    f = fields{i};
    if isfield(processed, f)
        out.(f) = processed.(f);
    end
end
end


function result = compareOutputs(expected, actual, tolerance)
% Compare two output structs field by field
result = struct('passed', true, 'failures', {{}});

fields = fieldnames(expected);
for i = 1:length(fields)
    fname = fields{i};
    if ~isfield(actual, fname)
        result.passed = false;
        result.failures{end+1} = sprintf('Missing field: %s', fname);
        continue;
    end

    exp = expected.(fname);
    act = actual.(fname);

    if isnumeric(exp) && isnumeric(act)
        if ~isequal(size(exp), size(act))
            result.passed = false;
            result.failures{end+1} = sprintf('%s: size mismatch [%s] vs [%s]', ...
                fname, mat2str(size(exp)), mat2str(size(act)));
            continue;
        end
        maxDiff = max(abs(exp(:) - act(:)), [], 'omitnan');
        if maxDiff > tolerance
            result.passed = false;
            result.failures{end+1} = sprintf('%s: max diff %.2e exceeds tolerance %.2e', ...
                fname, maxDiff, tolerance);
        end
    elseif ischar(exp) && ischar(act)
        if ~strcmp(exp, act)
            result.passed = false;
            result.failures{end+1} = sprintf('%s: string mismatch', fname);
        end
    elseif ~isequal(exp, act)
        result.passed = false;
        result.failures{end+1} = sprintf('%s: values do not match', fname);
    end
end
end
