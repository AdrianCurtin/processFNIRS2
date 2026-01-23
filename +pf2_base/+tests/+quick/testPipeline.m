function testPipeline()
%TESTPIPELINE Quick validation of processing pipeline
%
%   pf2_base.tests.quick.testPipeline()
%
%   Validates that the processFNIRS2 pipeline correctly processes sample
%   data and produces the expected output fields (HbO, HbR, etc.).
%
%   Example:
%       pf2_base.tests.quick.testPipeline()
%
%   See also: processFNIRS2, pf2.import.sampleData

    fprintf('=== Testing Processing Pipeline ===\n\n');

    passCount = 0;
    failCount = 0;

    %% Test basic pipeline with fNIR2000 data
    try
        fprintf('Testing pipeline with fNIR2000 data...\n');

        % Load sample data
        fprintf('  Loading sample data...\n');
        data = pf2.import.sampleData.fNIR2000();
        assert(isstruct(data), 'Failed to load sample data');

        % Process data
        fprintf('  Running processFNIRS2...\n');
        processed = processFNIRS2(data);

        % Verify output structure
        fprintf('  Verifying output fields...\n');
        assert(isstruct(processed), 'processFNIRS2 did not return a struct');
        assert(isfield(processed, 'HbO'), 'Missing HbO field');
        assert(isfield(processed, 'HbR'), 'Missing HbR field');
        assert(isfield(processed, 'HbTotal'), 'Missing HbTotal field');
        assert(isfield(processed, 'HbDiff'), 'Missing HbDiff field');
        assert(isfield(processed, 'time'), 'Missing time field');
        assert(isfield(processed, 'channels'), 'Missing channels field');

        % Verify data dimensions
        assert(size(processed.HbO, 1) > 0, 'HbO data is empty');
        assert(size(processed.HbR, 1) > 0, 'HbR data is empty');
        assert(size(processed.HbO, 1) == size(processed.HbR, 1), 'HbO and HbR time dimensions do not match');
        assert(size(processed.HbO, 2) == size(processed.HbR, 2), 'HbO and HbR channel dimensions do not match');
        assert(length(processed.time) == size(processed.HbO, 1), 'Time vector length does not match data');

        % Verify data is not all NaN
        assert(~all(isnan(processed.HbO(:))), 'HbO is all NaN');
        assert(~all(isnan(processed.HbR(:))), 'HbR is all NaN');

        fprintf('  fNIR2000 pipeline: PASS\n');
        fprintf('    - Output size: %d timepoints x %d channels\n', size(processed.HbO, 1), size(processed.HbO, 2));
        fprintf('    - HbO range: [%.4f, %.4f]\n', min(processed.HbO(:), [], 'omitnan'), max(processed.HbO(:), [], 'omitnan'));
        fprintf('    - HbR range: [%.4f, %.4f]\n', min(processed.HbR(:), [], 'omitnan'), max(processed.HbR(:), [], 'omitnan'));
        passCount = passCount + 1;

    catch e
        fprintf('  fNIR2000 pipeline: FAIL - %s\n', e.message);
        failCount = failCount + 1;
    end

    fprintf('\n');

    %% Test pipeline with Hitachi data
    try
        fprintf('Testing pipeline with Hitachi ETG-4000 3x5 data...\n');

        % Load sample data
        fprintf('  Loading sample data...\n');
        data = pf2.import.sampleData.Hitachi_ETG4000_3x5();
        assert(isstruct(data), 'Failed to load sample data');

        % Process data
        fprintf('  Running processFNIRS2...\n');
        processed = processFNIRS2(data);

        % Verify output structure
        fprintf('  Verifying output fields...\n');
        assert(isstruct(processed), 'processFNIRS2 did not return a struct');
        assert(isfield(processed, 'HbO'), 'Missing HbO field');
        assert(isfield(processed, 'HbR'), 'Missing HbR field');
        assert(size(processed.HbO, 1) > 0, 'HbO data is empty');

        fprintf('  Hitachi ETG-4000 3x5 pipeline: PASS\n');
        fprintf('    - Output size: %d timepoints x %d channels\n', size(processed.HbO, 1), size(processed.HbO, 2));
        passCount = passCount + 1;

    catch e
        fprintf('  Hitachi ETG-4000 3x5 pipeline: FAIL - %s\n', e.message);
        failCount = failCount + 1;
    end

    fprintf('\n');

    %% Test pipeline preserves original data
    try
        fprintf('Testing that pipeline preserves original raw data...\n');

        data = pf2.import.sampleData.fNIR2000();
        originalRaw = data.raw;

        processed = processFNIRS2(data);

        assert(isfield(processed, 'raw'), 'Raw field not preserved in output');
        assert(isequal(size(processed.raw), size(originalRaw)), 'Raw data dimensions changed');

        fprintf('  Raw data preservation: PASS\n');
        passCount = passCount + 1;

    catch e
        fprintf('  Raw data preservation: FAIL - %s\n', e.message);
        failCount = failCount + 1;
    end

    fprintf('\n');

    %% Summary
    fprintf('=== Pipeline Tests Summary ===\n');
    fprintf('Passed: %d\n', passCount);
    fprintf('Failed: %d\n', failCount);

    if failCount == 0
        fprintf('\nAll pipeline tests passed!\n');
    else
        fprintf('\nSome tests failed. Review output above.\n');
    end

end
