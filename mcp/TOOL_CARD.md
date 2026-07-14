# processFNIRS2 — MCP Session Tool Card

Condensed operating instructions for an AI agent driving processFNIRS2 through
the MATLAB MCP Server. Read this before generating pf2 code. It is a
session-oriented subset of the toolbox's processing conventions; for full API
detail use MATLAB `help` (e.g. `help processFNIRS2`) and the `docs/` reference.

## Session setup (first call)

Point MATLAB at the repo. Use the path for your OS (forward slashes work in
MATLAB on Windows too, but the drive prefix differs):

```matlab
% macOS / Linux
cd /Users/adriancurtin/Documents/GitHub/processFNIRS2   % or addpath(genpath(pwd))

% Windows (either form works)
cd 'C:\Users\YOU\Documents\GitHub\processFNIRS2'
% cd C:/Users/YOU/Documents/GitHub/processFNIRS2
```

`pf2.*`, `exploreFNIRS.*`, and `processFNIRS2` must resolve before anything else.
Prefer `fullfile(...)` when building paths in generated scripts so they stay
OS-portable, and write outputs to `tempdir` rather than a hard-coded `/tmp`.

## GUI / headless rule (critical for MCP)

`processFNIRS2` opens a **blocking GUI** unless you capture an output. In an MCP
session always capture output:

```matlab
processed = processFNIRS2(data);          % headless — correct for MCP
% processFNIRS2(data);                      % opens GUI — WILL HANG the session
```

Never pass `'ShowGUI', false`; capturing an output already suppresses it.

## Canonical single-subject recipe

```matlab
data   = pf2.import.sampleData();                       % or pf2.import.importSNIRF(path)
proc   = processFNIRS2(data);                            % -> HbO/HbR/HbTotal/HbDiff/CBSI
blocks = pf2.data.defineBlocks(proc, 50, 15, 'Embed', false);
seg    = pf2.data.extractBlocks(proc, blocks, 'PreTime', 5, 'PostTime', 15, 'SetT0', true);
ga     = pf2.data.blockAverage(seg);                     % ga.HbO.Mean(:,ch), ga.time
```

Always set `PreTime`/`PostTime` explicitly on `extractBlocks`.

## Batch / group

```matlab
allData = pf2.import.importDirectory('data/', '*.snirf', 'Dir1', 'Group', 'Dir2', 'SubjectID');
allData = processFNIRS2(allData);                        % processes each element
ex = exploreFNIRS.core.Experiment(allData);
ex.groupby({'Group'}); ex.aggregate(); ex.plotTemporal('Biomarkers', {'HbO'});
```

## Headless QC (unattended runs)

Importers default to "all channels good" when the channel-check GUI is
suppressed, so run the programmatic QC pipeline explicitly:

```matlab
report = pf2.qc.pipeline.assess(data);
data   = pf2.qc.pipeline.apply(data, report);
report = pf2.qc.snapshot(data, 'SaveDir', 'qc_out');    % dashboard + PSD + SCI PNGs
```

## Plots / renders (save, don't display)

```matlab
pf2.data.plot.oxy(proc, 5, 'savePath', 'ch5.png');                       % 2D: savePath ok
pf2.probe.plot.topo(proc, 'HbO', 'View', '3d', 'savePath', 'topo.png');  % 3D: MUST use savePath
```

Do **not** use `figure('Visible','off')` + `saveas`/`exportgraphics` for 3D
renders (`interpolateValues3D`, `topo 'View','3d'`, `project.*`) — unreliable
headless. Use the built-in `'savePath'`.

## Export (incl. foundation-model tensor)

```matlab
pf2.export.asSNIRF(proc, 'out.snirf');
pf2.export.asBIDS(allData, 'bids_out/', 'Task', 'rest');
pf2.export.asTensor(proc, 'rec.h5', 'Features', {'HbO','HbR'}, 'QC', true);
```

## Running tests via MCP

Use the server's `run_matlab_test_file` tool on files in `+pf2_base/+tests/`, or:

```matlab
pf2_base.tests.runQuickTests()
```

## Gotchas

- `data.markers` is a **table** — read `data.markers.Code`, not by column index.
- `-batch`/`evaluate_matlab_code` code must be valid; prefer writing a `.m` file
  and `run_matlab_file` for anything multi-statement or long-running.
- Reproducible/parallel runs: pass a public `pf2.ProcessingContext` as
  `'Context'` (e.g. `processFNIRS2(data, 'Context', pf2.ProcessingContext())`)
  to avoid touching the `PF2`/`setF` globals; use `ctx.copy()` per `parfor` worker.
