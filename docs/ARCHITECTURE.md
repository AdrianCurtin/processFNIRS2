# Architecture

A tour of how processFNIRS2 is put together — enough to understand the data
flow, find your way around the packages, and know where new code belongs. For
the public API see [API_REFERENCE.md](API_REFERENCE.md); for the processing
methods see [PROCESSING_PIPELINE.md](PROCESSING_PIPELINE.md).

## Two layers

processFNIRS2 is organized as two layers with a deliberately simple boundary
between them:

```mermaid
flowchart TB
    files[("Device files<br/>.nir · .snirf · .oxy3 · Hitachi MES")]

    subgraph L1["LAYER 1: Single-subject processing &nbsp;(+pf2)"]
        direction TB
        imp["pf2.import.*<br/><i>importNIR · importSNIRF · importOxy3</i>"]
        proc["processFNIRS2<br/><i>3-stage pipeline</i>"]
        epoch["pf2.data.*<br/><i>defineBlocks → extractBlocks → blockAverage</i>"]
        qc["pf2.qc.*<br/><i>assess / apply · ChannelCheck</i>"]
        imp --> proc
        proc --> epoch
        proc -.-> qc
    end

    struct{{"data struct: the interface<br/><b>raw · HbO/HbR · markers · device · info</b>"}}

    subgraph L2["LAYER 2: Group analysis &nbsp;(+exploreFNIRS)"]
        direction TB
        ex["Experiment / GLMExperiment"]
        agg["groupby → aggregate"]
        ana["+stats &nbsp;LME · contrasts · FDR<br/>+connectivity · +coupling · +hyperscanning"]
        viz["plot* · +probe.plot<br/><i>topo · 3D · connectome</i>"]
        ex --> agg --> ana
        agg --> viz
    end

    exp["pf2.export.*<br/><i>SNIRF · BIDS · tensor (.h5)</i>"]

    files --> imp
    proc --> struct
    epoch --> struct
    struct -->|"cell array of<br/>processed structs"| ex
    struct --> exp

    classDef contract fill:#eef,stroke:#557,stroke-width:2px;
    class struct contract;
```

The contract between the layers is **a plain MATLAB struct** (one per
recording) — not a class hierarchy or a database. Layer 1 produces it; Layer 2
consumes a cell array of them. This is what makes the whole toolbox scriptable
and testable, and lets external tools interoperate by producing/consuming the
same struct.

## End-to-end call flow

A single recording travels through the toolbox like this:

1. **Import** — `pf2.import.importNIR` / `importSNIRF` / `importOxy3` / … reads a
   device file and returns the data struct: `raw`, `time`, `fs`, `fchMask`, a
   `markers` table, `info`, and a `device` object (auto-attached via
   `pf2_base.loadDeviceCfg`). SNIRF import also folds BIDS `events.tsv` into the
   marker dictionary.

2. **Process** — `processFNIRS2(data)` runs three stages (below) and returns the
   same struct with `HbO`, `HbR`, `HbTotal`, `HbDiff`, `CBSI`, plus `units`,
   `DPF_factor`, and a `processingInfo` record for reproducibility.

3. **Epoch (single-subject)** — `pf2.data.defineBlocks` turns marker codes into
   block definitions; `pf2.data.extractBlocks` cuts time-locked segments;
   `pf2.data.blockAverage` / `grandAverage` produce trial-averaged waveforms.

4. **Group analysis (Layer 2)** — a cell array of processed structs becomes an
   `exploreFNIRS.core.Experiment`; `groupby` + `aggregate` build the group
   tensors; `plot*` and the `+stats` engine produce figures and LME results.

5. **Export** — `pf2.export.asSNIRF` / `asBIDS` / `asTensor` serialize the struct
   for sharing or downstream ML.

```mermaid
flowchart LR
    imp[import] --> ds[("data<br/>struct")]
    ds --> proc[processFNIRS2] --> ps[("processed<br/>struct")]
    ps --> db[defineBlocks] --> eb[extractBlocks]
    eb --> ba[blockAverage] --> wf["averaged waveform<br/>(single subject)"]
    eb -->|segments| exptl["Experiment"]
    ps -.->|"cell array of<br/>processed structs"| exptl
    ps --> exp["export<br/>SNIRF · BIDS · tensor"]
    exptl --> gb[groupby] --> ag[aggregate] --> ps2["plot / stats"]
```

## The data struct is the interface

Because every stage reads and writes the same struct, its fields are the most
important contract in the codebase. Treat them as stable.

| Field | Meaning |
|-------|---------|
| `raw` `[T×C]` | Raw light intensity (input). |
| `time` `[T×1]`, `fs` | Time vector (s) and sampling rate (Hz). |
| `fchMask` `[1×C]` | Channel mask (1 = good, 0 = bad). |
| `markers` (table) | `Time, Code, Duration, Amplitude` (+ any extra columns you add). Read by name. |
| `info` | Metadata; `info.markerDict` (code→label), `info.eventTypes` (BIDS), subject fields. |
| `device` | `pf2.Device` value object — geometry, wavelengths, saturation bounds. |
| `Aux` | Optional typed auxiliary signals (HR, EKG, accel, …). |
| `HbO` `HbR` `HbTotal` `HbDiff` `CBSI` `[T×C]` | Hemoglobin biomarkers (output). |
| `units`, `DPF_factor`, `processingInfo` | Units, DPF used, and the full processing record. |

Two sub-contracts worth calling out:

- **Markers are a table**, not a matrix — `data.markers.Code`, never column
  indexing. Extra columns (e.g. `RT`, `Label`) survive `setT0`, `split`,
  `extractBlocks`, and processing. Helpers: `pf2_base.normalizeMarkers`,
  `markersToArray`, `mergeMarkers`.
- **The marker dictionary** `info.markerDict` gives codes meaning and is the
  unifying target for source formats (BIDS `events.tsv`, COBI logs).
  `defineBlocks` and `labelMarkers` read it.

## The three-stage processing pipeline

`processFNIRS2` converts raw intensity to filtered hemoglobin in three stages,
implemented in `+pf2_base/+fnirs`:

| Stage | Engine | Transform |
|-------|--------|-----------|
| 1 | `processStageRaw2OD` | Raw intensity → optical density (motion correction, filtering, CAR — the configurable **raw** method chain). |
| 2 | `processStageOD2Hb` / `bvoxy` | Optical density → `HbO`/`HbR`/… via the modified Beer-Lambert law, with DPF correction (None / Fixed / age-dependent Calc). |
| 3 | `processStageFilterHb` | Hemoglobin → filtered hemoglobin (the configurable **oxy** method chain). |

Stages 1 and 3 are **method chains**: ordered lists of step functions (from
`functions/`) whose arguments are bound *by name* from the processing context
(`x`, `fs`, `fTime`, `fchMask`, …). The same chains are also expressible as
first-class `RawPipeline` / `OxyPipeline` value objects (see below).

## Package map

```mermaid
flowchart TB
    subgraph PF2["+pf2: user-facing API (Layer 1)"]
        direction LR
        p_import["+import"]
        p_data["+data<br/>(+plot)"]
        p_process["+process"]
        p_methods["+methods<br/>+raw/+oxy/+seeds"]
        p_probe["+probe<br/>+plot/+roi/+project<br/>+forward/+dot"]
        p_qc["+qc"]
        p_export["+export"]
        p_dev["Device"]
    end

    subgraph BASE["+pf2_base: infrastructure & algorithms"]
        direction LR
        b_ctx["ProcessingContext"]
        b_pipe["Pipeline ·<br/>Raw/Oxy/<br/>PipelineFunction"]
        b_fnirs["+fnirs<br/>stage engines<br/>bvoxy · GLM"]
        b_sig["+signal<br/>+wavelet<br/>+accel"]
        b_io["+bids · +dot<br/>+plot · +external"]
        b_init["pf2_initialize<br/>loadDeviceCfg<br/>normalize*"]
    end

    subgraph EX["+exploreFNIRS: group analysis (Layer 2)"]
        direction LR
        e_core["+core<br/>Experiment ·<br/>GLMExperiment"]
        e_conn["+connectivity<br/>+coupling<br/>+hyperscanning"]
        e_stats["+stats · LME<br/>contrasts · FDR<br/>+graph"]
        e_rep["+report · +dataset<br/>+export · +fx"]
    end

    FUNS["functions/: step implementations<br/>TDDR · SMAR · wavelet · Butterworth · Takizawa · CAR · SSR · GSR"]
    DEVS[("devices/*.cfg")]

    %% invisible chains keep each package's nodes on one row
    p_import ~~~ p_data ~~~ p_process ~~~ p_methods ~~~ p_probe ~~~ p_qc ~~~ p_export ~~~ p_dev
    b_ctx ~~~ b_pipe ~~~ b_fnirs ~~~ b_sig ~~~ b_io ~~~ b_init
    e_core ~~~ e_conn ~~~ e_stats ~~~ e_rep

    PF2 ==>|builds on| BASE
    BASE ==> FUNS
    PF2 ==> DEVS
    PF2 -.->|processed structs| EX
    FUNS ~~~ EX
```

### `+pf2/` — user-facing API (Layer 1)
| Subpackage | Responsibility |
|------------|----------------|
| `+import` | Device readers (`importNIR`, `importSNIRF`, `importOxy3`, …), `importDirectory`, `fromTable`, `sampleData`. |
| `+data` | Struct manipulation (`setT0`, `resample`, `split`), epoching (`defineBlocks`, `extractBlocks`, `blockAverage`), markers, metadata; `+plot` for time series. |
| `+process` | Stage-level entry points (`processRaw`, `processOxy`). |
| `+methods` | Method registry — `+raw`, `+oxy`, `+seeds` (list/set/create/edit). |
| `+probe` | Anatomy & spatial viz — `+plot` (topo, 3D, movies, connectome), `+roi`, `+project`, `+forward` & `+dot` (diffuse optical tomography), `canonicalize`, `montage`. |
| `+qc` | Quality control — `pipeline.assess/apply`, `snapshot`, `ChannelCheck` GUI. |
| `+export` | `asNIR`, `asSNIRF`, `asBIDS`, `asTensor`, `export`. |
| `+settings`, `+GUI` | Processing settings and GUI glue. `Device.m` (top level) is the device value class. |

### `+pf2_base/` — advanced and internal infrastructure & algorithms

This package serves two roles: documented low-level interfaces for advanced
users, and implementation machinery used by the primary `pf2` workflow. Those
roles are distinguished by the API catalog and documentation tier; package
membership alone is not a support promise.

Top-level: `ProcessingContext`, the pipeline classes (`Pipeline`,
`RawPipeline`, `OxyPipeline`, `PipelineFunction`), `pf2_initialize`,
`loadDeviceCfg`, `normalizeMarkers`/`normalizeAux`, `hierarchicalAverage`.
Subpackages include `+fnirs` (the stage engines, `bvoxy`, GLM), `+dot`, `+bids`,
`+accel`, `+signal`, `+wavelet` (first-party transforms), `+plot`, `+external`
(vendored helpers), and `+tests`.

### `+exploreFNIRS/` — group analysis (Layer 2)
`+core` holds the scriptable `Experiment` and `GLMExperiment` classes plus their
plotting methods. Analysis subpackages: `+connectivity`, `+coupling`,
`+hyperscanning`, `+stats` (LME, contrasts, FDR), `+graph`, `+report`,
`+dataset`, `+export`, `+fx`.

### Supporting directories
`functions/` — flat signal-processing step implementations (TDDR, SMAR,
wavelet, Butterworth, Takizawa, …), dispatched by name from the method chains.
`devices/` — device `.cfg` files. `sampledata/` — bundled datasets.
`examples/scripts/` — runnable tutorials.

### Entry points & legacy zones
- `processFNIRS2.m` — the processing engine (handles cell arrays, `parfor`, and
  the `Context` bypass).
- `pf2.m` — convenience wrapper that self-heals the path.
- `exploreFNIRS.m` — the GUIDE-based group-analysis GUI.
- `base_functions/`, `GUI/`, `compat_shims/` — **legacy / compatibility code
  outside the package structure.** Kept working, but new code should not be added
  here.

## Analysis approaches

Once a recording is processed, the choice of analysis approach depends on the
experimental design. They share the same processed struct and converge on the
Layer-2 `Experiment` for group statistics.

```mermaid
flowchart TB
    proc["Processed recording<br/>HbO/HbR · markers"]
    proc --> q{"Analysis goal?"}

    q -->|"Event-related amplitude<br/>(clean, spaced trials)"| EPOCH
    q -->|"Continuous / overlapping<br/>or irregular events"| GLM
    q -->|"Resting / dynamic FC<br/>(no events)"| SLIDE
    q -->|"Functional connectivity"| CONN

    subgraph EPOCH["Epoch / block-averaging"]
        direction TB
        e1["defineBlocks(code, dur)"] --> e2["extractBlocks<br/>(PreTime / PostTime)"]
    end
    subgraph GLM["GLM (continuous)"]
        direction TB
        g1["buildDesignMatrix<br/>HRF ⊛ boxcar + drift"] --> g2["fitGLM (OLS / AR-IRLS)"] --> g3["betas /<br/>first-level contrasts"]
    end
    subgraph SLIDE["Sliding windows"]
        direction TB
        s1["slidingWindows<br/>(Length, Overlap)"] --> s2["extractBlocks"]
    end
    subgraph CONN["Connectivity"]
        direction TB
        c1["computeMatrix<br/>pearson · partial · ..."]
    end

    e2 -->|segments| GRP
    s2 -->|segments| GRP
    g3 -->|"betas (betasToSegments)"| GRP
    GRP["exploreFNIRS.core.Experiment<br/>groupby → aggregate<br/>· group-level averaging ·"] --> OUT["Group stats (LME / FDR)<br/>plots · export"]
    CONN --> COUT["connectome · plotChord<br/>group connectivity"]
```

### GLM pipeline

`GLMExperiment` automates the manual chain below (process → design → fit →
contrasts → package → group). Reach for the manual path when you need control
over the design matrix or first-level contrasts.

```mermaid
flowchart TB
    rec["Continuous recordings<br/>(raw subjects)"]
    blk["block definitions<br/>(markers → conditions)"]

    rec --> proc["processFNIRS2<br/><i>GLM convention: skip bandpass:<br/>drift regressors model trends</i>"]
    blk --> ev["blocksToEvents"]

    proc --> dm
    ev --> dm["buildDesignMatrix<br/>HRF ⊛ boxcar · drift (Legendre/DCT)<br/>± derivative/dispersion · short-channels"]
    dm --> fit["fitGLM &nbsp;<i>per subject × biomarker</i><br/>OLS (default) / AR-IRLS · betas · t / p · R²"]
    fit --> con["First-level contrasts<br/>C·β &nbsp;(e.g. Hard &gt; Easy)"]
    con --> pack["betasToSegments<br/><i>β as pseudo-segments</i>"]
    pack --> grp["Experiment (group)<br/>aggregate"]
    grp --> lme["statsFitLME · plotLME · plotTopoLME"]
    grp --> tbl["betaTable &nbsp;<i>(GLMExperiment)</i><br/>R / Python export"]

    subgraph AUTO["GLMExperiment: wraps the whole chain"]
        direction TB
        a1["GLMExperiment(subjects, blockDefs) → fit() → plot/stats"]
        a2["betaSeriesConnectivity · ppi / ppiTable / ppiLME"]
    end
```

### Hyperscanning (inter-brain synchrony)

Paired (or grouped) recordings are coupled channel-by-channel, then tested for
inter-brain synchrony and modeled at the group level.

```mermaid
flowchart TB
    A["Subject A<br/>processed"]
    B["Subject B<br/>processed"]
    A --> pair["pairSubjects<br/><i>align dyads / groups</i>"]
    B --> pair

    pair --> dyad["computeDyad<br/><i>ChannelPairing: same / all</i>"]
    pair --> group["computeGroup<br/><i>n-way coupling</i>"]

    subgraph COUP["+coupling: per-pair metric"]
        direction LR
        m1["wcoherence ·<br/>coherence"]
        m2["pearson · spearman ·<br/>xcorr"]
        m3["granger · transferEntropy ·<br/>mutualInfo"]
        m4["partialCoherence /<br/>partialCorr<br/><i>control shared physio</i>"]
    end
    dyad --> COUP
    group --> COUP

    pair --> qc["physioConfoundQC<br/><i>LFO/VLFO shared-aux flag</i>"]
    COUP --> perm["permutationTest<br/><i>vs pseudo-pairs</i>"]
    perm --> viz["plotDualBrain · plotDyadMatrix<br/>plotInterBrainTopo · plotGroup"]
    perm --> stats

    pair --> xppi["cross-brain PPI (gPPI)<br/><i>computePPI · seed = other brain</i>"]
    xppi --> stats["Group LME<br/><i>Experiment · GLMExperiment.ppi /<br/>ppiTable / ppiLME</i>"]

    A2["HB-ICA<br/><i>hbica · shared inter-brain components</i>"]
    pair --> A2 --> hviz["plotHBICA"]
```

## Key abstractions

- **`pf2.Device`** — an immutable value object describing a probe (geometry,
  wavelengths, MNI positions, saturation bounds), loaded from a `.cfg` and
  attached as `data.device`.
- **Method / Pipeline system** — a method is a named, ordered chain of step
  functions. `RawPipeline`/`OxyPipeline` expose this as value objects (every
  mutating call returns a copy); `.toMethod()`/`.save()` convert to the registry
  format, `.fromMethod()` reloads.
- **`ProcessingContext`** — bypasses the `PF2`/`setF` globals so settings,
  methods, and device are threaded as locals. This is what makes processing
  isolated, reproducible, and `parfor`-safe (`processFNIRS2(data, 'Context', ctx)`).
- **`Experiment` / `GLMExperiment`** — the Layer-2 group objects: ingest
  processed structs, `groupby`/`aggregate` into group tensors, and expose
  `plot*` and statistics. `GLMExperiment` wraps processing + GLM + group analysis.

## Where does X go?

| You want to add… | Put it here |
|------------------|-------------|
| A processing algorithm / step | `functions/` (a plain function bound by name), then register it in a method chain or add it to a `RawPipeline`/`OxyPipeline`. |
| A device | A `.cfg` in `devices/` (or generate one with `pf2.probe.saveCfg`). |
| An importer / exporter | `+pf2/+import` / `+pf2/+export`. |
| A plot or spatial visualization | `+pf2/+probe/+plot` (or `+project` for cortical projections). |
| A QC check | `+pf2/+qc` (wire it into `pipeline.assess`). |
| Group-level analysis or statistics | `+exploreFNIRS/+core` (Experiment methods) or the relevant analysis subpackage (`+connectivity`, `+stats`, `+graph`, …). |
| Internal infrastructure / shared utility | `+pf2_base` (the right subpackage). |
| Tests | `+pf2_base/+tests`. |

See [CONTRIBUTING.md](https://github.com/AdrianCurtin/processFNIRS2/blob/master/CONTRIBUTING.md)
for setup, tests, and coding conventions.
