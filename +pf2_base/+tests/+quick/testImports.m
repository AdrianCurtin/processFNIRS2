function testImports()
%TESTIMPORTS Quick validation of import functions
%
%   pf2_base.tests.quick.testImports()
%
%   Validates that sample data import functions work correctly by loading
%   each available sample dataset and checking for required fields.
%
%   Example:
%       pf2_base.tests.quick.testImports()
%
%   See also: pf2.import.sampleData

    fprintf('=== Testing Import Functions ===\n\n');

    passCount = 0;
    failCount = 0;

    %% Test fNIR2000 import
    try
        fprintf('Testing fNIR2000 import...\n');
        data = pf2.import.sampleData.fNIR2000();
        assert(isstruct(data), 'fNIR2000 import did not return a struct');
        assert(isfield(data, 'raw'), 'Missing raw field');
        assert(isfield(data, 'time'), 'Missing time field');
        assert(isfield(data, 'fs'), 'Missing fs field');
        assert(isfield(data, 'markers'), 'Missing markers field');
        assert(size(data.raw, 1) > 0, 'Raw data is empty');
        fprintf('  fNIR2000 import: PASS\n');
        fprintf('    - Raw data size: %d x %d\n', size(data.raw, 1), size(data.raw, 2));
        fprintf('    - Sampling rate: %.2f Hz\n', data.fs);
        passCount = passCount + 1;
    catch e
        fprintf('  fNIR2000 import: FAIL - %s\n', e.message);
        failCount = failCount + 1;
    end

    fprintf('\n');

    %% Test Hitachi ETG-4000 3x5 import
    try
        fprintf('Testing Hitachi ETG-4000 3x5 import...\n');
        data = pf2.import.sampleData.Hitachi_ETG4000_3x5();
        assert(isstruct(data), 'Hitachi import did not return a struct');
        assert(isfield(data, 'raw'), 'Missing raw field');
        assert(isfield(data, 'time'), 'Missing time field');
        assert(isfield(data, 'fs'), 'Missing fs field');
        assert(size(data.raw, 1) > 0, 'Raw data is empty');
        fprintf('  Hitachi ETG-4000 3x5 import: PASS\n');
        fprintf('    - Raw data size: %d x %d\n', size(data.raw, 1), size(data.raw, 2));
        fprintf('    - Sampling rate: %.2f Hz\n', data.fs);
        passCount = passCount + 1;
    catch e
        fprintf('  Hitachi ETG-4000 3x5 import: FAIL - %s\n', e.message);
        failCount = failCount + 1;
    end

    fprintf('\n');

    %% Test Hitachi ETG-4000 3x11 import
    try
        fprintf('Testing Hitachi ETG-4000 3x11 import...\n');
        data = pf2.import.sampleData.Hitachi_ETG4000_3x11();
        assert(isstruct(data), 'Hitachi 3x11 import did not return a struct');
        assert(isfield(data, 'raw'), 'Missing raw field');
        assert(isfield(data, 'time'), 'Missing time field');
        assert(size(data.raw, 1) > 0, 'Raw data is empty');
        fprintf('  Hitachi ETG-4000 3x11 import: PASS\n');
        fprintf('    - Raw data size: %d x %d\n', size(data.raw, 1), size(data.raw, 2));
        fprintf('    - Sampling rate: %.2f Hz\n', data.fs);
        passCount = passCount + 1;
    catch e
        fprintf('  Hitachi ETG-4000 3x11 import: FAIL - %s\n', e.message);
        failCount = failCount + 1;
    end

    fprintf('\n');

    %% Summary
    fprintf('=== Import Tests Summary ===\n');
    fprintf('Passed: %d\n', passCount);
    fprintf('Failed: %d\n', failCount);

    if failCount == 0
        fprintf('\nAll import tests passed!\n');
    else
        fprintf('\nSome tests failed. Review output above.\n');
    end

end
