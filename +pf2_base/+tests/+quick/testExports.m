function testExports()
%TESTEXPORTS Quick validation of export functions
%
%   pf2_base.tests.quick.testExports()
%
%   Validates that export functions correctly write data to files by
%   exporting processed data to SNIRF format and verifying the output.
%
%   Example:
%       pf2_base.tests.quick.testExports()
%
%   See also: pf2.export.asSNIRF, pf2.import.importSNIRF

    fprintf('=== Testing Export Functions ===\n\n');

    passCount = 0;
    failCount = 0;

    %% Test SNIRF export
    try
        fprintf('Testing SNIRF export...\n');

        % Load and process sample data
        fprintf('  Loading and processing sample data...\n');
        data = pf2.import.sampleData.fNIR2000();
        processed = processFNIRS2(data);

        % Create temp file path
        tempDir = tempdir;
        tempFile = fullfile(tempDir, sprintf('test_export_%s.snirf', datestr(now, 'yyyymmdd_HHMMSS')));

        % Export to SNIRF
        fprintf('  Exporting to SNIRF: %s\n', tempFile);
        pf2.export.asSNIRF(processed, tempFile);

        % Verify file exists
        assert(exist(tempFile, 'file') == 2, 'SNIRF file was not created');

        % Get file info
        fileInfo = dir(tempFile);
        assert(fileInfo.bytes > 0, 'SNIRF file is empty');

        fprintf('  SNIRF export: PASS\n');
        fprintf('    - File size: %.2f KB\n', fileInfo.bytes / 1024);
        passCount = passCount + 1;

        % Clean up
        delete(tempFile);
        fprintf('  Temp file cleaned up.\n');

    catch e
        fprintf('  SNIRF export: FAIL - %s\n', e.message);
        failCount = failCount + 1;

        % Attempt cleanup even on failure
        if exist('tempFile', 'var') && exist(tempFile, 'file')
            delete(tempFile);
        end
    end

    fprintf('\n');

    %% Test SNIRF round-trip (export then import)
    try
        fprintf('Testing SNIRF round-trip (export -> import)...\n');

        % Load and process sample data
        fprintf('  Loading and processing sample data...\n');
        data = pf2.import.sampleData.fNIR2000();
        processed = processFNIRS2(data);

        % Create temp file path
        tempDir = tempdir;
        tempFile = fullfile(tempDir, sprintf('test_roundtrip_%s.snirf', datestr(now, 'yyyymmdd_HHMMSS')));

        % Export to SNIRF
        fprintf('  Exporting to SNIRF...\n');
        pf2.export.asSNIRF(processed, tempFile);

        % Import the exported file
        fprintf('  Re-importing SNIRF file...\n');
        reimported = pf2.import.importSNIRF(tempFile);

        % Verify reimported data
        assert(isstruct(reimported), 'Reimported data is not a struct');
        assert(isfield(reimported, 'raw') || isfield(reimported, 'HbO'), 'Reimported data missing expected fields');

        fprintf('  SNIRF round-trip: PASS\n');
        passCount = passCount + 1;

        % Clean up
        delete(tempFile);
        fprintf('  Temp file cleaned up.\n');

    catch e
        fprintf('  SNIRF round-trip: FAIL - %s\n', e.message);
        failCount = failCount + 1;

        % Attempt cleanup even on failure
        if exist('tempFile', 'var') && exist(tempFile, 'file')
            delete(tempFile);
        end
    end

    fprintf('\n');

    %% Test NIR export (if available)
    try
        fprintf('Testing NIR export...\n');

        % Load and process sample data
        fprintf('  Loading and processing sample data...\n');
        data = pf2.import.sampleData.fNIR2000();
        processed = processFNIRS2(data);

        % Create temp file path
        tempDir = tempdir;
        tempFile = fullfile(tempDir, sprintf('test_export_%s.nir', datestr(now, 'yyyymmdd_HHMMSS')));

        % Export to NIR
        fprintf('  Exporting to NIR: %s\n', tempFile);
        pf2.export.asNIR(processed, tempFile);

        % Verify file exists
        assert(exist(tempFile, 'file') == 2, 'NIR file was not created');

        % Get file info
        fileInfo = dir(tempFile);
        assert(fileInfo.bytes > 0, 'NIR file is empty');

        fprintf('  NIR export: PASS\n');
        fprintf('    - File size: %.2f KB\n', fileInfo.bytes / 1024);
        passCount = passCount + 1;

        % Clean up
        delete(tempFile);
        fprintf('  Temp file cleaned up.\n');

    catch e
        fprintf('  NIR export: FAIL - %s\n', e.message);
        failCount = failCount + 1;

        % Attempt cleanup even on failure
        if exist('tempFile', 'var') && exist(tempFile, 'file')
            delete(tempFile);
        end
    end

    fprintf('\n');

    %% Summary
    fprintf('=== Export Tests Summary ===\n');
    fprintf('Passed: %d\n', passCount);
    fprintf('Failed: %d\n', failCount);

    if failCount == 0
        fprintf('\nAll export tests passed!\n');
    else
        fprintf('\nSome tests failed. Review output above.\n');
    end

end
