function runQuickTests()
%RUNQUICKTESTS Run quick validation scripts for processFNIRS2
%
%   pf2_base.tests.runQuickTests() executes lightweight validation scripts that
%   verify core functionality without the full unit testing framework.
%   These scripts are designed for rapid sanity checks during development.
%
%   Syntax:
%       pf2_base.tests.runQuickTests()
%
%   Description:
%       This function runs a series of quick validation scripts located in
%       the pf2_base.tests.quick package. Each script tests a specific functional
%       area:
%
%       testImports  - Validates data import functions for supported formats
%       testPipeline - Validates the core processing pipeline
%       testExports  - Validates data export functions
%
%       Unlike the full test suite (runAllTests), these scripts:
%       - Do not require matlab.unittest framework knowledge
%       - Run faster (typically < 30 seconds total)
%       - Provide pass/fail status without detailed assertions
%       - Are suitable for quick pre-commit validation
%
%       Each test is wrapped in try-catch, so a failure in one test does
%       not prevent subsequent tests from running.
%
%   Quick Test Requirements:
%       Each function in pf2_base.tests.quick should:
%       - Take no input arguments
%       - Throw an error if validation fails
%       - Print 'PASSED' on success
%       - Complete within a reasonable time (< 10 seconds)
%
%   Example:
%       % Run quick validation before committing changes
%       pf2_base.tests.runQuickTests()
%
%       % Typical output:
%       %   === Quick Validation Tests ===
%       %
%       %   [1/3] Running testImports...
%       %   testImports PASSED (1.23s)
%       %
%       %   [2/3] Running testPipeline...
%       %   testPipeline PASSED (2.45s)
%       %
%       %   [3/3] Running testExports...
%       %   testExports PASSED (0.89s)
%       %
%       %   === Quick Tests Complete ===
%       %   All 3 tests passed.
%
%   See also: pf2_base.tests.runAllTests, pf2_base.tests.quick.testImports,
%             pf2_base.tests.quick.testPipeline, pf2_base.tests.quick.testExports

%   Author: processFNIRS2 Development Team
%   Version: 8.1
%   Last Updated: 2026-01-23

    % Print header
    fprintf('=== Quick Validation Tests ===\n');
    fprintf('Running at: %s\n\n', datestr(now));

    % Define quick tests to run
    quickTests = {
        'testImports',  'Data import functions';
        'testPipeline', 'Core processing pipeline';
        'testExports',  'Data export functions'
    };

    numTests = size(quickTests, 1);
    passCount = 0;
    failCount = 0;
    results = cell(numTests, 1);

    % Run each quick test
    for i = 1:numTests
        testName = quickTests{i, 1};
        testDesc = quickTests{i, 2};

        fprintf('[%d/%d] Running %s (%s)...\n', i, numTests, testName, testDesc);

        tic;
        try
            % Dynamically call the test function
            testFcn = str2func(['pf2_base.tests.quick.' testName]);
            testFcn();

            elapsed = toc;
            fprintf('      %s PASSED (%.2fs)\n\n', testName, elapsed);
            passCount = passCount + 1;
            results{i} = struct('name', testName, 'passed', true, 'duration', elapsed, 'error', '');

        catch e
            elapsed = toc;
            fprintf('      %s FAILED (%.2fs)\n', testName, elapsed);
            fprintf('      Error: %s\n\n', e.message);
            failCount = failCount + 1;
            results{i} = struct('name', testName, 'passed', false, 'duration', elapsed, 'error', e.message);
        end
    end

    % Print summary
    fprintf('=== Quick Tests Complete ===\n');
    totalDuration = sum(cellfun(@(r) r.duration, results));
    fprintf('Total duration: %.2f seconds\n', totalDuration);

    if failCount == 0
        fprintf('All %d tests passed.\n', passCount);
    else
        fprintf('Results: %d passed, %d failed\n', passCount, failCount);

        % List failed tests
        fprintf('\nFailed tests:\n');
        for i = 1:numTests
            if ~results{i}.passed
                fprintf('  - %s: %s\n', results{i}.name, results{i}.error);
            end
        end

        fprintf('\nRun individual tests for more details:\n');
        fprintf('  pf2_base.tests.quick.testName()\n');
    end
end
