# MATLAB Command-Line Execution

## MATLAB Installation Path
```bash
/Applications/MATLAB_R2025b.app/bin/matlab
```

## Recommended: Use `-batch` Flag

```bash
matlab -batch "command"
```

**Why `-batch` is preferred over `-r`:**
- Automatically exits when done (no need for `exit` command)
- Returns non-zero exit code on error (critical for automation)
- Suppresses startup messages
- Treats errors as failures

## ⚠️ Multi-line commands: prefer a script file

A literal newline inside the quoted `-batch "..."` string is fragile: depending
on the shell and how the command is dispatched it can be split so MATLAB sees
no command at all, failing with:

```
No MATLAB command specified for -batch command line argument.
```

For anything beyond one or two statements, **write a `.m` file and run it** —
this always works and is far easier to debug:

```bash
# reliable: put the workflow in a script, then run it
matlab -batch "run('/abs/path/to/analysis.m')"
```

If you must inline multiple statements, keep them on **one line** separated by
`;` (or `,`):

```bash
matlab -batch "data = pf2.import.sampleData.fNIR2000(); proc = processFNIRS2(data); disp('done')"
```

The multi-line `matlab -batch "..."` snippets below are shown for readability;
if one fails with the error above, move the body into a script and use the
`run('script.m')` form.

## Common Execution Patterns

**Running a script:**
```bash
matlab -batch "run('path/to/script.m')"
# or if in the right directory:
matlab -batch "script_name"
```

**Running a function with arguments:**
```bash
matlab -batch "result = my_function(42, 'hello'); disp(result)"
```

**Changing directory first:**
```bash
matlab -batch "cd('/path/to/project'); my_script"
```

**Multiple commands:**
```bash
matlab -batch "addpath('utils'); load('data.mat'); process_data"
```

## processFNIRS2 Specific Examples

> **Reproducible batch runs: pass an explicit `pf2.ProcessingContext`.** A bare
> `processFNIRS2(data)` with no context inherits the DPF mode (and other
> settings) from the global `PF2` state, which a prior GUI session may have
> changed - so an unattended script can silently get a different `DPFmode` than
> intended. For reproducibility, pin the settings in a context and pass it:
> ```matlab
> ctx = pf2.ProcessingContext('DPFmode','Calc', 'SubjectAge',25, ...
>     'RawMethod','x2_lpf', 'blLength',10);
> processed = processFNIRS2(data, 'Context', ctx);   % globals never read/written
> ```
> In a headless session, if `DPFmode` was inherited from a non-default global,
> `processFNIRS2` emits a one-time `pf2:processFNIRS2:batchGlobalDPF` warning.

**Process a single file:**
```bash
cd /Users/adriancurtin/Documents/GitHub/processFNIRS2 && \
matlab -batch "
    data = pf2.import.importNIR('path/to/file.nir');
    processed = processFNIRS2(data);
    save('output.mat', 'processed');
"
```

**Import and export SNIRF:**
```bash
matlab -batch "
    cd('/Users/adriancurtin/Documents/GitHub/processFNIRS2');
    data = pf2.import.importSNIRF('input.snirf');
    processed = processFNIRS2(data);
    pf2.export.asSNIRF(processed, 'output.snirf');
"
```

**Export an HDF5 tensor for foundation-model training (headless):**
```bash
cd /Users/adriancurtin/Documents/GitHub/processFNIRS2 && \
matlab -batch "
    data = pf2.import.sampleData.fNIR2000();
    proc = processFNIRS2(data);
    out  = pf2.export.asTensor(proc, 'sub-01.h5', ...
        'Features', {'HbO','HbR'}, 'QC', true);
    fprintf('Wrote tensor: %s\n', out);
"
```

**Batch process a directory:**
```bash
matlab -batch "
    cd('/Users/adriancurtin/Documents/GitHub/processFNIRS2');
    allData = pf2.import.importDirectory('data/', '*.nir', ...
        'Dir1', 'Group', 'Dir2', 'SubjectID');
    allData = processFNIRS2(allData);
    save('output/all_processed.mat', 'allData');
"
```

**Batch process files individually (manual loop):**
```bash
matlab -batch "
    cd('/Users/adriancurtin/Documents/GitHub/processFNIRS2');
    files = dir('data/*.nir');
    for i = 1:length(files)
        data = pf2.import.importNIR(fullfile(files(i).folder, files(i).name));
        processed = processFNIRS2(data);
        [~, name] = fileparts(files(i).name);
        save(['output/' name '_processed.mat'], 'processed');
    end
"
```

## Full Pattern with Error Handling

```bash
cd /Users/adriancurtin/Documents/GitHub/processFNIRS2 && \
/Applications/MATLAB_R2025b.app/bin/matlab -batch "
    try
        data = pf2.import.importNIR('input.nir');
        processed = processFNIRS2(data);
        save('output.mat', 'processed');
        fprintf('Success: processed %d channels\n', size(processed.HbO, 2));
    catch e
        fprintf(2, 'Error: %s\n', e.message);
        exit(1);
    end
"
```

## Headless Graphics (Saving Plots)

```matlab
% Use invisible figures for headless plotting
fig = figure('Visible', 'off');
pf2.data.plot.oxy(processed);
saveas(fig, 'timeseries.png');
close(fig);

% Or use print directly
print('-dpng', 'output.png');
```

## Passing Complex Parameters

**Via environment variables:**
```bash
export SUBJECT_AGE=25
export DPF_MODE="Calc"
matlab -batch "
    age = str2double(getenv('SUBJECT_AGE'));
    dpfMode = getenv('DPF_MODE');
    processed = processFNIRS2(data, 'defaultSubjectAge', age, 'DPFmode', dpfMode);
"
```

**Via JSON file:**
```bash
echo '{"age": 25, "baseline_length": 10, "dpf_mode": "Calc"}' > params.json
matlab -batch "
    params = jsondecode(fileread('params.json'));
    processed = processFNIRS2(data, ...
        'defaultSubjectAge', params.age, ...
        'blLength', params.baseline_length, ...
        'DPFmode', params.dpf_mode);
"
```

## Timeout Handling

```bash
# 5 minute timeout for long-running processing
timeout 300 matlab -batch "long_running_analysis"
```

## Checking Success

```bash
matlab -batch "my_processing_script"
if [ $? -eq 0 ]; then
    echo "MATLAB processing succeeded"
else
    echo "MATLAB processing failed"
fi
```

## Common Issues and Solutions

| Issue | Cause | Solution |
|-------|-------|----------|
| Exit code always 0 | Using `-r` instead of `-batch` | Use `-batch` |
| Script not found | Working directory wrong | Use `cd()` first or full path |
| License error | No license available | Check `matlab -batch "license"` |
| Hangs forever | Script waiting for input | Ensure no `input()` or `keyboard` calls |
| No output visible | Buffered stdout | Add `diary('log.txt')` or flush with `drawnow` |
| GUI function errors | Headless mode | Use `figure('Visible', 'off')` |

## Key Takeaways

1. **Always use `-batch` over `-r`** for proper error codes
2. **Write results to files** rather than parsing stdout
3. **Handle working directory explicitly** with `cd()` or full paths
4. **Use invisible figures** for any plotting in headless mode
5. **Wrap in try-catch** for detailed error reporting
