%% example_pipeline_custom_function.m - Add custom functions to the pipeline
%
% Demonstrates how to discover, register, and use custom processing
% functions with the Pipeline system. PipelineFunction.detect() parses
% function signatures automatically; register() persists them to the
% function library so Pipeline.add() can find them.
%
% Covers:
%   1. Detect an existing function (config vs source-parse paths)
%   2. Build from call string (fromString, addFromString)
%   3. Register a new function to the library
%   4. Use the registered function in a pipeline
%   5. Clean up (remove registered function)
%   6. Summary
%
% Requirements:
%   - processFNIRS2 on path

cd(fileparts(mfilename('fullpath')));
cd('../..');  % project root

outDir = fullfile(tempdir, 'pipeline_custom');
if ~exist(outDir, 'dir'), mkdir(outDir); end

%% Part 1: Detect an Existing Function
%
% PipelineFunction.detect() auto-discovers a function's signature.
% If the function is in pf2_functions_default.cfg, it reads from config.
% Otherwise it parses the source file's function line.

fprintf('=== Part 1: Detect Function Signatures ===\n');

% Config path: pf2_lpf is defined in pf2_functions_default.cfg
pf_lpf = pf2_base.PipelineFunction.detect('pf2_lpf');
fprintf('pf2_lpf (from config):\n');
disp(pf_lpf);

% Source-parse path: detrend_3rd_order is NOT in config
pf_det = pf2_base.PipelineFunction.detect('detrend_3rd_order');
fprintf('detrend_3rd_order (from source parse):\n');
disp(pf_det);

% The .args() table shows which arguments are context (injected at runtime)
% vs parameters (tunable defaults)
fprintf('detrend_3rd_order argument table:\n');
disp(pf_det.args());

% The .params() struct gives just the tunable parameters
fprintf('detrend_3rd_order params: ');
disp(pf_det.params());
fprintf('\n');

%% Part 2: Build from Call String
%
% PipelineFunction.fromString() parses a MATLAB call-syntax string.
% Context args (x, fs, fchMask, etc.) keep [] defaults regardless of
% what appears in the string. Parameter values are extracted from the string.

fprintf('=== Part 2: Build from Call String ===\n');

% Parse a call string — context args (x, fs) get [] defaults
pf_from_str = pf2_base.PipelineFunction.fromString('[x]=pf2_lpf(x,1,fs,0.2,100)');
fprintf('fromString result:\n');
disp(pf_from_str);
fprintf('  freq_cut = %.1f (from call string)\n', pf_from_str.getParam('freq_cut'));
fprintf('  Nf = %d (from call string)\n\n', pf_from_str.getParam('Nf'));

% addFromString on a Pipeline — rapid composition
p = pf2_base.Pipeline('from_strings');
p = p.addFromString('pf2_Intensity2OD(x)');
p = p.addFromString('[x]=pf2_MotionCorrectTDDR(x,fs)');
p = p.addFromString('[x]=pf2_lpf(x,1,fs,0.15,80)');
fprintf('Pipeline built from call strings:\n%s\n\n', p.describe());

%% Part 3: Register a New Function
%
% detect() finds detrend_3rd_order from source, but Pipeline.add() won't
% find it because it's not in the config. register() persists the function
% definition so add() and the GUI can discover it.

fprintf('=== Part 3: Register a New Function ===\n');

% detect and configure
pf_custom = pf2_base.PipelineFunction.detect('detrend_3rd_order');
fprintf('Detected: %s\n', pf_custom.funcName);
fprintf('  Args before registration: ');
disp(pf_custom.args());

% Register to persist in pf2_functions_default.cfg
pf2_base.PipelineFunction.register(pf_custom);

% Verify: now Pipeline.add() can find it without warnings
testPipe = pf2_base.Pipeline('verify_register');
testPipe = testPipe.add('detrend_3rd_order');  % no warning
fprintf('Added detrend_3rd_order via Pipeline.add() after registration.\n');
fprintf('%s\n\n', testPipe.describe());

%% Part 4: Use in a Pipeline
%
% Build a complete pipeline using the newly registered function alongside
% standard functions. Save, process, and verify.

fprintf('=== Part 4: Use in a Pipeline ===\n');

raw = pf2_base.RawPipeline('example_custom_raw');
raw = raw.add('pf2_Intensity2OD');
raw = raw.add('detrend_3rd_order');
raw = raw.add('pf2_MotionCorrectTDDR');

oxy = pf2_base.OxyPipeline('example_custom_oxy');
oxy = oxy.add('pf2_lpf', 'freq_cut', 0.1);

fprintf('Raw pipeline:\n%s\n\n', raw.describe());
fprintf('Oxy pipeline:\n%s\n\n', oxy.describe());

% Save and process
raw.save('raw', 'Replace', true);
oxy.save('oxy', 'Replace', true);

data = pf2.import.sampleData.fNIR2000();
processed = processFNIRS2(data, 'example_custom_raw', 'example_custom_oxy');
fprintf('Processed: %d timepoints x %d channels\n\n', size(processed.HbO));

%% Part 5: Clean Up
%
% Remove the registered function and saved methods to leave the config
% unchanged. This makes the script fully re-runnable.

fprintf('=== Part 5: Clean Up ===\n');

% Remove saved processing methods
pf2.methods.raw.delete('example_custom_raw');
pf2.methods.oxy.delete('example_custom_oxy');
fprintf('Deleted processing methods.\n');

% Remove detrend_3rd_order from the function library
unregisterFunction('detrend_3rd_order');
fprintf('Unregistered detrend_3rd_order from function library.\n\n');

%% Summary
fprintf('\n=== Summary ===\n');
fprintf('PipelineFunction methods demonstrated:\n');
fprintf('  .detect(funcName)     - auto-discover signature from config or source\n');
fprintf('  .fromString(str)      - parse MATLAB call syntax into PipelineFunction\n');
fprintf('  .register(pf)         - persist to pf2_functions_default.cfg\n');
fprintf('  .args()               - table showing context vs parameter classification\n');
fprintf('  .params()             - struct of tunable parameter defaults\n');
fprintf('Pipeline methods demonstrated:\n');
fprintf('  .addFromString(str)   - parse and append in one call\n');
fprintf('  .add(funcName)        - look up registered function by name\n');
fprintf('\nOutput dir: %s\n', outDir);


%% --- Local functions ---

function unregisterFunction(funcName)
% Remove a function section from pf2_functions_default.cfg

    rootPath = pf2_base.pf2_defaultRootPath();
    cfgPath = fullfile(rootPath, 'prefs', 'pf2_functions_default.cfg');
    ini = pf2_base.external.INI('File', cfgPath);
    ini.read();
    if ismember(funcName, ini.Sections)
        ini.remove(funcName);
        ini.write();
    end
    % Clear cached configs
    pf2_base.PipelineFunction.clearFunctionConfigCache();
    pf2_base.Pipeline.loadFuncConfig(true);
end
