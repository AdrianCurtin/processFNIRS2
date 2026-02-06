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

            if contains(goldenFile, fullfile('golden', 'processFNIRS2'))
                % Pipeline golden test
                testCase.runPipelineGolden(golden, fileName);
            elseif contains(goldenFile, fullfile('golden', 'functions'))
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

            % Set methods from params
            if isfield(golden.params, 'rawMethod')
                rawMethod = golden.params.rawMethod;
                % Handle temp methods that may not exist
                global PF2
                if ~ismember(rawMethod, PF2.myRawMethods.cfg.Sections) && ~strcmp(rawMethod, 'None')
                    testCase.assumeFail(sprintf('Raw method ''%s'' not available', rawMethod));
                end
                pf2.methods.raw.setMethod(rawMethod);
            end
            if isfield(golden.params, 'oxyMethod')
                pf2.methods.oxy.setMethod(golden.params.oxyMethod);
            end

            % Process
            processed = processFNIRS2(data, 'ShowGUI', false);

            % Compare output
            result = compareOutputs(golden.output, extractOutput(processed), 1e-10);
            testCase.verifyTrue(result.passed, ...
                sprintf('Golden file mismatch for %s:\n%s', fileName, strjoin(result.failures, '\n')));
        end

        function runFunctionGolden(testCase, golden, fileName)
            % Load sample data
            data = pf2.import.sampleData.fNIR2000();
            od = pf2_Intensity2OD(data.raw);

            % Verify input hash
            if isfield(golden, 'inputHash')
                actualHash = pf2_base.tests.golden.computeHash(od);
                testCase.assertEqual(actualHash, golden.inputHash, ...
                    'Input data has changed - golden file may need regeneration');
            end

            % Run function based on params
            if isfield(golden.params, 'function')
                funcName = golden.params.function;
                switch funcName
                    case 'pf2_MotionCorrectTDDR'
                        actualOutput = struct('corrected', pf2_MotionCorrectTDDR(od, golden.params.fs));
                    case 'pf2_SMAR'
                        actualOutput = struct('corrected', pf2_SMAR(od, 10));
                    otherwise
                        testCase.assumeFail(sprintf('Unknown function: %s', funcName));
                end
            else
                testCase.assumeFail('Golden file params missing ''function'' field');
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
            dirs = {fullfile(projectRoot, 'golden', 'processFNIRS2'), ...
                    fullfile(projectRoot, 'golden', 'functions')};

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
