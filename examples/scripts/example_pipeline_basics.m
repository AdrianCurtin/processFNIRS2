%% example_pipeline_basics.m - Build, inspect, and run processing pipelines
%
% Demonstrates the Pipeline API for composing fNIRS processing chains
% programmatically. Pipelines replace the old struct-based method format
% with a readable, chainable, value-semantics interface.
%
% Covers:
%   1. Build a Raw Pipeline (RawPipeline, .add(), .describe())
%   2. Build an Oxy Pipeline (OxyPipeline, .add(), .swapROI())
%   3. Inspect & Tune (.params() table, .getStep(), .setParam(), .setParams())
%   4. Modify Structure (.insert(), .remove(), .swapStep(), name-based addressing)
%   5. Run the Pipeline (.save(), processFNIRS2 headless)
%   6. Summary
%
% Requirements:
%   - processFNIRS2 on path

cd(fileparts(mfilename('fullpath')));
cd('../..');  % project root

outDir = fullfile(tempdir, 'pipeline_basics');
if ~exist(outDir, 'dir'), mkdir(outDir); end

%% Part 1: Build a Raw Pipeline
%
% RawPipeline handles Stage 1 (raw intensity -> optical density).
% Each .add() call appends a step and returns a new pipeline (value semantics).

fprintf('=== Part 1: Build a Raw Pipeline ===\n');

raw = pf2_base.RawPipeline('example_raw', ...
    'Description', 'OD conversion + TDDR motion correction');

% Add steps by function name — args/defaults are loaded from config
raw = raw.add('pf2_Intensity2OD');
raw = raw.add('pf2_MotionCorrectTDDR');

% Human-readable overview
fprintf('%s\n\n', raw.describe());

% RawPipeline knows about the OD conversion step
fprintf('Has Intensity2OD: %d\n', raw.hasIntensity2OD());
fprintf('Step count: %d\n\n', raw.numSteps());

%% Part 2: Build an Oxy Pipeline
%
% OxyPipeline handles Stage 3 (hemoglobin filtering) and has ROI helpers.

fprintf('=== Part 2: Build an Oxy Pipeline ===\n');

oxy = pf2_base.OxyPipeline('example_oxy');

% Override default parameters inline with name-value pairs
oxy = oxy.add('pf2_lpf', 'freq_cut', 0.08, 'Nf', 80);
oxy = oxy.add('pf2_build_nanmean_ROI');

fprintf('%s\n\n', oxy.describe());

% swapROI replaces the ROI builder step (or appends if none exists)
oxy2 = oxy.swapROI('pf2_build_pca_ROI', 'ComponentNumber', 2);
fprintf('After swapROI:\n%s\n\n', oxy2.describe());

% Value semantics: original is unchanged
fprintf('Original still has nanmean ROI: %s\n\n', ...
    oxy.getStep('pf2_build_nanmean_ROI').funcName);

%% Part 3: Inspect & Tune
%
% The params() table gives a quick audit of all tunable parameters.
% getStep() retrieves individual steps for detailed inspection.

fprintf('=== Part 3: Inspect & Tune ===\n');

% Aggregate parameter table across all steps
tbl = oxy.params();
disp(tbl);

% Get a single step and inspect its full argument table
lpf = oxy.getStep('pf2_lpf');
fprintf('LPF arguments:\n');
disp(lpf.args());

% Read a single parameter value
fprintf('Current freq_cut: %.3f\n', lpf.getParam('freq_cut'));

% Update a parameter on the pipeline (by function name)
oxy = oxy.setParam('pf2_lpf', 'freq_cut', 0.12);
fprintf('Updated freq_cut: %.3f\n\n', oxy.getStep('pf2_lpf').getParam('freq_cut'));

% Bulk-set multiple parameters at once
oxy = oxy.setParams('pf2_lpf', 'freq_cut', 0.1, 'Nf', 50);
fprintf('After setParams: freq_cut=%.2f, Nf=%d\n\n', ...
    oxy.getStep('pf2_lpf').getParam('freq_cut'), ...
    oxy.getStep('pf2_lpf').getParam('Nf'));

%% Part 4: Modify Structure
%
% insert(), remove(), and swapStep() restructure the pipeline.
% Steps can be addressed by index (1-based) or function name.

fprintf('=== Part 4: Modify Structure ===\n');

% Start with a 3-step oxy pipeline
p = pf2_base.OxyPipeline('modify_demo');
p = p.add('detrend');
p = p.add('pf2_lpf', 'freq_cut', 0.1);
p = p.add('pf2_build_nanmean_ROI');
fprintf('Initial:\n%s\n\n', p.describe());

% Insert a high-pass filter at position 2 (between detrend and lpf)
p = p.insert(2, 'pf2_hpf', 'freq_cut', 0.01);
fprintf('After insert at 2:\n%s\n\n', p.describe());

% Remove the detrend step by name
p = p.remove('detrend');
fprintf('After remove detrend:\n%s\n\n', p.describe());

% Swap the high-pass for a bandpass (by name)
p = p.swapStep('pf2_hpf', 'pf2_bpf_butter', 'lowF', 0.01, 'highF', 0.08);
fprintf('After swapStep hpf -> bpf:\n%s\n\n', p.describe());

% Find a step index (returns 0 if not found)
idx = p.findStep('pf2_bpf_butter');
fprintf('pf2_bpf_butter is at index: %d\n\n', idx);

%% Part 5: Run the Pipeline
%
% Save pipelines as named methods, then run processFNIRS2 headless.
% 'Replace', true makes this idempotent (safe to re-run).

fprintf('=== Part 5: Run the Pipeline ===\n');

% Rebuild clean pipelines for processing
raw = pf2_base.RawPipeline('example_basics_raw');
raw = raw.add('pf2_Intensity2OD');
raw = raw.add('pf2_MotionCorrectTDDR');

oxy = pf2_base.OxyPipeline('example_basics_oxy');
oxy = oxy.add('pf2_lpf', 'freq_cut', 0.1);

% Save to the method library
raw.save('raw', 'Replace', true);
oxy.save('oxy', 'Replace', true);
fprintf('Saved raw method: %s\n', raw.name);
fprintf('Saved oxy method: %s\n', oxy.name);

% Load sample data and process
data = pf2.import.sampleData.fNIR2000();
processed = processFNIRS2(data, 'example_basics_raw', 'example_basics_oxy');
fprintf('Processed: %d timepoints x %d channels\n', size(processed.HbO));

% Verify the pipeline round-trips: load back from method library
rawLoaded = pf2_base.RawPipeline.fromMethod('example_basics_raw');
fprintf('Loaded back: %s (%d steps)\n', rawLoaded.name, rawLoaded.numSteps());

% Clean up saved methods
pf2.methods.raw.delete('example_basics_raw');
pf2.methods.oxy.delete('example_basics_oxy');
fprintf('Cleaned up saved methods.\n\n');

%% Summary
fprintf('\n=== Summary ===\n');
fprintf('Pipeline API methods demonstrated:\n');
fprintf('  Construction:  RawPipeline(), OxyPipeline(), .add()\n');
fprintf('  Inspection:    .describe(), .params(), .getStep(), .args()\n');
fprintf('  Tuning:        .setParam(), .setParams(), .getParam()\n');
fprintf('  Structure:     .insert(), .remove(), .swapStep(), .swapROI()\n');
fprintf('  Query:         .numSteps(), .findStep(), .hasIntensity2OD(), .hasROI()\n');
fprintf('  Execution:     .save(), .toMethod(), Pipeline.fromMethod()\n');
fprintf('  Value semantics: all methods return new objects (originals unchanged)\n');
fprintf('\nOutput dir: %s\n', outDir);
