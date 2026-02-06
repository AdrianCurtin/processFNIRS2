function result = verifyGolden(goldenPath, actualOutput, tolerance)
% VERIFYGOLDEN Compare actual output against a golden reference file
%
% Loads a golden .mat file and compares each numeric field in the output
% struct against the actual output with a specified tolerance. Non-numeric
% fields are compared with isequal.
%
% Syntax:
%   result = pf2_base.tests.golden.verifyGolden(goldenPath, actualOutput)
%   result = pf2_base.tests.golden.verifyGolden(goldenPath, actualOutput, tolerance)
%
% Inputs:
%   goldenPath   - Path to golden .mat file
%   actualOutput - Struct with same fields as golden output
%   tolerance    - Maximum allowed difference (default: 1e-10)
%
% Outputs:
%   result - Struct with fields:
%            .passed   - Logical, true if all comparisons pass
%            .failures - Cell array of failure description strings
%
% Example:
%   data = pf2.import.sampleData.fNIR2000();
%   processed = processFNIRS2(data, 'ShowGUI', false);
%   result = pf2_base.tests.golden.verifyGolden('golden/processFNIRS2/fNIR2000_default.mat', processed);
%
% See also: pf2_base.tests.golden.computeHash

if nargin < 3
    tolerance = 1e-10;
end

golden = load(goldenPath);
result = struct('passed', true, 'failures', {{}});

% Check output field exists
if ~isfield(golden, 'output')
    result.passed = false;
    result.failures{end+1} = 'Golden file missing ''output'' field';
    return;
end

goldenOutput = golden.output;

% Compare numeric fields
fields = fieldnames(goldenOutput);
for i = 1:length(fields)
    fname = fields{i};
    if ~isfield(actualOutput, fname)
        result.passed = false;
        result.failures{end+1} = sprintf('Missing field: %s', fname);
        continue;
    end

    expected = goldenOutput.(fname);
    actual = actualOutput.(fname);

    if isnumeric(expected) && isnumeric(actual)
        if ~isequal(size(expected), size(actual))
            result.passed = false;
            result.failures{end+1} = sprintf('%s: size mismatch [%s] vs [%s]', ...
                fname, mat2str(size(expected)), mat2str(size(actual)));
            continue;
        end
        maxDiff = max(abs(expected(:) - actual(:)), [], 'omitnan');
        if maxDiff > tolerance
            result.passed = false;
            result.failures{end+1} = sprintf('%s: max diff %.2e exceeds tolerance %.2e', ...
                fname, maxDiff, tolerance);
        end
    elseif ischar(expected) && ischar(actual)
        if ~strcmp(expected, actual)
            result.passed = false;
            result.failures{end+1} = sprintf('%s: string mismatch ''%s'' vs ''%s''', ...
                fname, expected, actual);
        end
    elseif ~isequal(expected, actual)
        result.passed = false;
        result.failures{end+1} = sprintf('%s: values do not match', fname);
    end
end

end
