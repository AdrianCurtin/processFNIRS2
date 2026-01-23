# Golden Files for Regression Testing

Golden files store known-good outputs from processFNIRS2 processing pipelines. Tests compare current outputs against these reference files to detect unintended changes in behavior.

## Directory Structure

```
golden/
├── README.md           # This file
├── candidates/         # New outputs awaiting promotion to golden
├── processFNIRS2/      # Golden outputs from main processing pipeline
│   ├── fNIR2000_default.mat
│   └── ...
└── functions/          # Golden outputs from individual functions
    ├── pf2_SMAR.mat
    └── ...
```

## Golden File Contents

Each `.mat` file contains:

| Field | Description |
|-------|-------------|
| `output` | The function/pipeline output to verify |
| `inputHash` | SHA-256 hash of input data for validation |
| `version` | processFNIRS2 version that generated the file |
| `timestamp` | Generation timestamp (ISO 8601) |
| `params` | Parameters used (method names, settings) |
| `matlabVersion` | MATLAB version used for generation |

## Generating Golden Files

### Generate from sample data

```matlab
% Load sample data
data = pf2.import.sampleData();

% Process with specific method configuration
pf2.methods.raw.setMethod('x2_lpf_smar');
pf2.methods.oxy.setMethod('takizawa_easy');
processed = processFNIRS2(data);

% Create golden file
golden = struct();
golden.output = processed;
golden.inputHash = computeHash(data);
golden.version = pf2_base.pf2version();
golden.timestamp = datetime('now', 'Format', 'yyyy-MM-dd''T''HH:mm:ss');
golden.params = struct('rawMethod', 'x2_lpf_smar', 'oxyMethod', 'takizawa_easy');
golden.matlabVersion = version();

% Save to candidates directory first
save('golden/candidates/processFNIRS2_sampleNIR_x2_lpf_smar.mat', '-struct', 'golden');
```

### Generate for a specific function

```matlab
% Test pf2_SMAR in isolation
data = pf2.import.sampleData();
[corrected, mask] = pf2_SMAR(data.raw, data.fs);

golden = struct();
golden.output = struct('corrected', corrected, 'mask', mask);
golden.inputHash = computeHash(data.raw);
golden.version = pf2_base.pf2version();
golden.timestamp = datetime('now', 'Format', 'yyyy-MM-dd''T''HH:mm:ss');
golden.params = struct('fs', data.fs);
golden.matlabVersion = version();

save('golden/candidates/pf2_SMAR_sampleNIR.mat', '-struct', 'golden');
```

## Verifying Against Golden Files

### Basic verification

```matlab
function result = verifyGolden(goldenPath, actualOutput, tolerance)
    % VERIFYGOLDEN Compare output against golden file
    %
    %   result = verifyGolden(goldenPath, actualOutput)
    %   result = verifyGolden(goldenPath, actualOutput, tolerance)
    %
    %   tolerance defaults to 1e-10 for floating point comparisons

    if nargin < 3
        tolerance = 1e-10;
    end

    golden = load(goldenPath);
    result = struct('passed', true, 'failures', {{}});

    % Compare numeric fields
    fields = fieldnames(golden.output);
    for i = 1:length(fields)
        fname = fields{i};
        if ~isfield(actualOutput, fname)
            result.passed = false;
            result.failures{end+1} = sprintf('Missing field: %s', fname);
            continue;
        end

        expected = golden.output.(fname);
        actual = actualOutput.(fname);

        if isnumeric(expected) && isnumeric(actual)
            maxDiff = max(abs(expected(:) - actual(:)), [], 'omitnan');
            if maxDiff > tolerance
                result.passed = false;
                result.failures{end+1} = sprintf('%s: max diff %.2e exceeds tolerance %.2e', ...
                    fname, maxDiff, tolerance);
            end
        elseif ~isequal(expected, actual)
            result.passed = false;
            result.failures{end+1} = sprintf('%s: values do not match', fname);
        end
    end
end
```

### Integration with MATLAB unit tests

```matlab
classdef ProcessingGoldenTest < matlab.unittest.TestCase

    properties (TestParameter)
        goldenFile = getGoldenFiles('golden/processFNIRS2');
    end

    methods (Test)
        function testAgainstGolden(testCase, goldenFile)
            golden = load(goldenFile);

            % Reproduce the processing
            data = pf2.import.sampleData();
            testCase.verifyEqual(computeHash(data), golden.inputHash, ...
                'Input data has changed - golden file may need regeneration');

            % Apply same parameters
            pf2.methods.raw.setMethod(golden.params.rawMethod);
            pf2.methods.oxy.setMethod(golden.params.oxyMethod);
            actual = processFNIRS2(data);

            % Compare outputs
            result = verifyGolden(goldenFile, actual);
            testCase.verifyTrue(result.passed, strjoin(result.failures, '\n'));
        end
    end
end

function files = getGoldenFiles(directory)
    listing = dir(fullfile(directory, '*.mat'));
    files = fullfile({listing.folder}, {listing.name});
end
```

## Promoting Candidates to Golden

After verifying a candidate file is correct:

```matlab
function promoteCandidate(candidateName, targetDir)
    % PROMOTECANDIDATE Move verified candidate to golden directory
    %
    %   promoteCandidate('processFNIRS2_sampleNIR_x2_lpf_smar.mat', 'processFNIRS2')

    candidatePath = fullfile('golden', 'candidates', candidateName);
    targetPath = fullfile('golden', targetDir, candidateName);

    % Verify candidate exists
    if ~isfile(candidatePath)
        error('Candidate file not found: %s', candidatePath);
    end

    % Create target directory if needed
    if ~isfolder(fullfile('golden', targetDir))
        mkdir(fullfile('golden', targetDir));
    end

    % Move file
    movefile(candidatePath, targetPath);
    fprintf('Promoted: %s -> %s\n', candidatePath, targetPath);
end
```

## Workflow for Intentional Changes

When algorithm changes are intentional and golden files need updating:

1. **Document the change**: Add a comment in the commit explaining why outputs changed

2. **Generate new candidates**:
   ```matlab
   % Regenerate affected golden files
   generateGoldenFile('processFNIRS2', 'sampleNIR', 'x2_lpf_smar');
   ```

3. **Review the differences**:
   ```matlab
   compareGolden('golden/processFNIRS2/file.mat', 'golden/candidates/file.mat');
   ```

4. **Promote after review**:
   ```matlab
   promoteCandidate('file.mat', 'processFNIRS2');
   ```

5. **Commit both code and golden files** together so the history shows the relationship

## Utility Functions

### Compute input hash

```matlab
function hash = computeHash(data)
    % COMPUTEHASH Generate SHA-256 hash of input data
    %
    %   Used to verify input data hasn't changed when comparing against golden files

    % Serialize struct to bytes
    bytes = getByteStreamFromArray(data);

    % Compute SHA-256
    md = java.security.MessageDigest.getInstance('SHA-256');
    md.update(bytes);
    hashBytes = md.digest();

    % Convert to hex string
    hash = sprintf('%02x', typecast(hashBytes, 'uint8'));
end
```

### Compare two golden files

```matlab
function compareGolden(goldenPath, candidatePath)
    % COMPAREGOLDEN Show differences between golden and candidate files

    golden = load(goldenPath);
    candidate = load(candidatePath);

    fprintf('Golden:    %s (v%s, %s)\n', goldenPath, golden.version, golden.timestamp);
    fprintf('Candidate: %s (v%s, %s)\n', candidatePath, candidate.version, candidate.timestamp);
    fprintf('\n');

    fields = fieldnames(golden.output);
    for i = 1:length(fields)
        fname = fields{i};
        g = golden.output.(fname);
        c = candidate.output.(fname);

        if isnumeric(g) && isnumeric(c)
            maxDiff = max(abs(g(:) - c(:)), [], 'omitnan');
            meanDiff = mean(abs(g(:) - c(:)), 'omitnan');
            fprintf('%s: max=%.2e, mean=%.2e\n', fname, maxDiff, meanDiff);
        else
            if isequal(g, c)
                fprintf('%s: identical\n', fname);
            else
                fprintf('%s: DIFFERENT\n', fname);
            end
        end
    end
end
```

## Best Practices

1. **Use deterministic inputs**: Always use `pf2.import.sampleData()` or other fixed test data
2. **Pin method configurations**: Explicitly set methods rather than relying on defaults
3. **Include version info**: Always store the processFNIRS2 version in golden files
4. **Review before promoting**: Never blindly promote candidates to golden
5. **One golden per configuration**: Separate files for different method combinations
6. **Keep candidates clean**: Delete rejected candidates promptly

## Naming Convention

```
{pipeline}_{dataset}_{rawMethod}_{oxyMethod}.mat
```

Examples:
- `processFNIRS2_sampleNIR_x2_lpf_smar_takizawa_easy.mat`
- `pf2_SMAR_sampleNIR.mat`
- `bvoxy_synthetic_DPFcalc.mat`
