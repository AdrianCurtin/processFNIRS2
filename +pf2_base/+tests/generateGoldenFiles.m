function generateGoldenFiles(varargin)
% GENERATEGOLDENFILES Generate golden reference files for regression testing
%
% Creates golden .mat files from deterministic sample data using specific
% processing configurations. Files are saved to golden/candidates/ for
% review before promotion to golden/.
%
% Syntax:
%   pf2_base.tests.generateGoldenFiles()
%   pf2_base.tests.generateGoldenFiles('Promote', true)
%
% Options (Name-Value):
%   'Promote' - If true, save directly to golden/ instead of candidates/
%               (default: false)
%
% Example:
%   pf2_base.tests.generateGoldenFiles();
%   pf2_base.tests.generateGoldenFiles('Promote', true);
%
% See also: pf2_base.tests.integration.GoldenFileTest,
%           pf2_base.tests.golden.computeHash

p = inputParser;
addParameter(p, 'Promote', false, @islogical);
parse(p, varargin{:});

promote = p.Results.Promote;

% Get project root
thisFile = mfilename('fullpath');
projectRoot = fileparts(fileparts(fileparts(thisFile)));

if promote
    pipelineDir = fullfile(projectRoot, 'tests', 'golden', 'processFNIRS2');
    functionDir = fullfile(projectRoot, 'tests', 'golden', 'functions');
else
    pipelineDir = fullfile(projectRoot, 'tests', 'golden', 'candidates');
    functionDir = fullfile(projectRoot, 'tests', 'golden', 'candidates');
end

% Ensure directories exist
if ~isfolder(pipelineDir), mkdir(pipelineDir); end
if ~isfolder(functionDir), mkdir(functionDir); end

% Load sample data
fprintf('Loading sample data...\n');
data = pf2.import.sampleData.fNIR2000();
inputHash = pf2_base.tests.golden.computeHash(data.raw);

[~, pf2ver] = pf2_base.pf2version();
verStr = sprintf('%.1f', pf2ver);

% --- Golden 1: Default processing (no raw method, no oxy method) ---
fprintf('Generating: fNIR2000_default...\n');
pf2.methods.raw.setMethod('None');
pf2.methods.oxy.setMethod('None');
processed = processFNIRS2(data);

golden = struct();
golden.output = extractOutput(processed);
golden.inputHash = inputHash;
golden.version = verStr;
golden.timestamp = char(datetime('now', 'Format', 'yyyy-MM-dd''T''HH:mm:ss'));
golden.params = struct('rawMethod', 'None', 'oxyMethod', 'None');
golden.matlabVersion = version();

outFile = fullfile(pipelineDir, 'fNIR2000_default.mat');
save(outFile, '-struct', 'golden');
fprintf('  Saved: %s\n', outFile);

% --- Golden 2: TDDR raw, no oxy ---
fprintf('Generating: fNIR2000_TDDR_None...\n');

% Check if x5_TDDR method exists
global PF2
rawMethods = PF2.myRawMethods.cfg.Sections;
if ismember('x5_TDDR', rawMethods)
    pf2.methods.raw.setMethod('x5_TDDR');
    rawMethodName = 'x5_TDDR';
else
    % Create a temporary TDDR method
    pf2.methods.raw.create('golden_TDDR', ...
        {struct('f', 'pf2_MotionCorrectTDDR', 'args', {{'x', 'fs'}}, ...
                'argvals', {{'x', 'fs'}}, 'output', 'x')}, ...
        'Replace', true);
    pf2.methods.raw.setMethod('golden_TDDR');
    rawMethodName = 'golden_TDDR';
end
pf2.methods.oxy.setMethod('None');
processed = processFNIRS2(data);

golden = struct();
golden.output = extractOutput(processed);
golden.inputHash = inputHash;
golden.version = verStr;
golden.timestamp = char(datetime('now', 'Format', 'yyyy-MM-dd''T''HH:mm:ss'));
golden.params = struct('rawMethod', rawMethodName, 'oxyMethod', 'None');
golden.matlabVersion = version();

outFile = fullfile(pipelineDir, 'fNIR2000_TDDR_None.mat');
save(outFile, '-struct', 'golden');
fprintf('  Saved: %s\n', outFile);

% Clean up temp method if created
if strcmp(rawMethodName, 'golden_TDDR')
    pf2.methods.raw.delete('golden_TDDR');
end

% --- Golden 3: TDDR function in isolation ---
fprintf('Generating: pf2_TDDR_fNIR2000...\n');
od = pf2_Intensity2OD(data.raw);
tddrOutput = pf2_MotionCorrectTDDR(od, data.fs);

golden = struct();
golden.output = struct('corrected', tddrOutput);
golden.inputHash = pf2_base.tests.golden.computeHash(od);
golden.version = verStr;
golden.timestamp = char(datetime('now', 'Format', 'yyyy-MM-dd''T''HH:mm:ss'));
golden.params = struct('fs', data.fs, 'function', 'pf2_MotionCorrectTDDR');
golden.matlabVersion = version();

outFile = fullfile(functionDir, 'pf2_TDDR_fNIR2000.mat');
save(outFile, '-struct', 'golden');
fprintf('  Saved: %s\n', outFile);

% Reset methods
pf2.methods.raw.setMethod('None');
pf2.methods.oxy.setMethod('None');

fprintf('Golden file generation complete.\n');
if ~promote
    fprintf('Files saved to tests/golden/candidates/. Review and promote with:\n');
    fprintf('  movefile(''tests/golden/candidates/file.mat'', ''tests/golden/processFNIRS2/file.mat'')\n');
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
