function results = runAllTests()
%RUNALLTESTS Run all processFNIRS2 unit and integration tests
%
%   results = pf2_base.tests.runAllTests() executes all unit tests and integration
%   tests in the processFNIRS2 test suite using the MATLAB Unit Testing
%   Framework (matlab.unittest).
%
%   Syntax:
%       results = pf2_base.tests.runAllTests()
%
%   Outputs:
%       results - matlab.unittest.TestResult array containing results for
%                 all executed tests. Each element contains:
%                   .Name    - Full test name (package.class/method)
%                   .Passed  - Logical, true if test passed
%                   .Failed  - Logical, true if test failed
%                   .Incomplete - Logical, true if test did not complete
%                   .Duration - Test execution time in seconds
%
%   Description:
%       This function discovers and runs all tests in the pf2_base.tests.unit and
%       pf2_base.tests.integration packages. Tests are executed with verbose output
%       (Verbosity level 3) showing detailed progress information.
%
%       The function prints a summary showing total tests, passed count,
%       and failed count. If any tests fail, their names are listed.
%
%   Test Organization:
%       pf2_base.tests.unit        - Unit tests for individual functions
%       pf2_base.tests.integration - Integration tests for multi-component workflows
%
%   Example:
%       % Run all tests and examine results
%       results = pf2_base.tests.runAllTests();
%
%       % Check if all tests passed
%       if all([results.Passed])
%           disp('All tests passed!');
%       end
%
%       % Get failed test details
%       failedResults = results([results.Failed]);
%       for i = 1:numel(failedResults)
%           disp(failedResults(i).Details);
%       end
%
%   See also: pf2_base.tests.runQuickTests, matlab.unittest.TestSuite,
%             matlab.unittest.TestRunner

%   Author: processFNIRS2 Development Team
%   Version: 8.1
%   Last Updated: 2026-01-23

    import matlab.unittest.TestSuite;
    import matlab.unittest.TestRunner;
    import matlab.unittest.plugins.TestRunProgressPlugin;

    % Print header
    fprintf('=== processFNIRS2 Test Suite ===\n');
    fprintf('Running at: %s\n', datestr(now));
    fprintf('MATLAB Version: %s\n\n', version);

    % Build test suites from packages
    fprintf('Discovering tests...\n');

    unitSuite = TestSuite.fromPackage('pf2_base.tests.unit', 'IncludingSubpackages', true);
    integrationSuite = TestSuite.fromPackage('pf2_base.tests.integration', 'IncludingSubpackages', true);

    % Combine suites
    suite = [unitSuite, integrationSuite];

    if isempty(suite)
        fprintf('No tests found in pf2_base.tests.unit or pf2_base.tests.integration packages.\n');
        fprintf('Ensure test classes inherit from matlab.unittest.TestCase.\n');
        results = matlab.unittest.TestResult.empty;
        return;
    end

    fprintf('Found %d unit tests, %d integration tests\n', ...
        numel(unitSuite), numel(integrationSuite));
    fprintf('\n');

    % Configure runner with verbose output
    runner = TestRunner.withTextOutput('Verbosity', 3);

    % Run all tests
    fprintf('--- Running Tests ---\n\n');
    results = runner.run(suite);

    % Print summary
    fprintf('\n');
    fprintf('=== TEST SUMMARY ===\n');
    fprintf('Total:      %d\n', numel(results));
    fprintf('Passed:     %d\n', sum([results.Passed]));
    fprintf('Failed:     %d\n', sum([results.Failed]));
    fprintf('Incomplete: %d\n', sum([results.Incomplete]));
    fprintf('Duration:   %.2f seconds\n', sum([results.Duration]));

    % List failed tests if any
    if any([results.Failed])
        fprintf('\nFailed tests:\n');
        failedTests = results([results.Failed]);
        for i = 1:numel(failedTests)
            fprintf('  - %s\n', failedTests(i).Name);
        end
        fprintf('\nRun individual failed tests for detailed diagnostics.\n');
    end

    % List incomplete tests if any
    if any([results.Incomplete])
        fprintf('\nIncomplete tests:\n');
        incompleteTests = results([results.Incomplete]);
        for i = 1:numel(incompleteTests)
            fprintf('  - %s\n', incompleteTests(i).Name);
        end
    end

    % Final status
    fprintf('\n');
    if all([results.Passed]) && ~any([results.Incomplete])
        fprintf('All tests PASSED.\n');
    else
        fprintf('Some tests FAILED or were INCOMPLETE.\n');
    end
    fprintf('=== Test Run Complete ===\n');
end
