# Contributing to processFNIRS2

Thanks for your interest in improving processFNIRS2. This guide covers how to
set up the toolbox for development, run the tests, and follow the project's
coding and documentation conventions.

## Ways to contribute

- **Report a bug** — open an issue with a minimal reproduction (ideally using
  `pf2.import.sampleData*`), the MATLAB version, and the full error text.
- **Request a feature** — open an issue describing the use case.
- **Submit a change** — fork, branch, implement with tests and documentation,
  and open a pull request against `master`.

## Development setup

1. Clone your fork and add the repository root to the MATLAB path:
   ```matlab
   addpath('/path/to/processFNIRS2');
   ```
   The package folders resolve automatically; the loose folders
   (`base_functions`, `functions`, `GUI`) are added on the first call to
   `processFNIRS2`/`pf2`.
2. Verify the install with the smoke test:
   ```matlab
   data = pf2.import.sampleData.fNIR2000(); processed = processFNIRS2(data); disp('Done')
   ```

This project targets **MATLAB R2025b**. The Statistics and Machine Learning
Toolbox is required for LME-based group statistics. Signal-processing, wavelet,
Savitzky-Golay, and median-filter routines are implemented first-party (in
`+pf2_base/+external` and `+pf2_base/+wavelet`), so the default pipeline does not
depend on the Signal Processing or Wavelet toolboxes. Keep new code toolbox-free
where practical — prefer the `pf2_base.external.*` equivalents (`butter`, `fir1`,
`filtfilt_classic`, `zp2sos`, `sgolayfilt`, `medfilt1`, …) over toolbox calls.

## Running the tests

```matlab
pf2_base.tests.runAllTests()     % full suite
pf2_base.tests.runQuickTests()   % fast subset for iterating
```

Add or update tests in `+pf2_base/+tests` for any behavior you change. New
features should ship with coverage; bug fixes should add a regression test.

## Where code belongs

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for the package map and the
"Where does X go?" table. In short: processing steps live in `functions/`,
device configs in `devices/`, the user API under `+pf2/`, shared internals under
`+pf2_base/`, and group-analysis code under `+exploreFNIRS/`. Do not add new
code to the legacy `base_functions/`, `GUI/`, or `compat_shims/` directories.

## Coding conventions

### Function headers
Every function needs a documented header. Public API and algorithm functions
require all sections; internal helpers need at least a summary, inputs, and
outputs. The header format is:

- **H1 line** — function name in UPPERCASE with a brief (< 80 char) description.
- **Inputs / Outputs** — dimensions, units, defaults, and valid ranges.
- **References** — academic citations (with DOI) for any published algorithm.
- **Examples** — at least one runnable example (use sample data) for public and
  algorithm functions.

`functions/pf2_SMAR.m` is the gold-standard example to model new headers on.

### Citing algorithms
When you implement or adapt a published method, cite the original paper in the
function's `References` section with the full reference and DOI. Verify each
citation against CrossRef rather than writing it from memory.

### Line endings
All MATLAB files must use **Unix-style line endings (LF, `\n`)**. Some legacy
files have Mac Classic (`\r`) endings, which break editors, string matching, and
diffs.

```bash
file myfunction.m                       # check (look for "CR line terminators")
sed -i '' $'s/\r/\n/g' myfunction.m     # fix (macOS)
```
Configure your editor to use LF for `.m` files.

### Documentation
User-facing documentation (README, `docs/`, release notes) should be factual,
concise, and written for researchers and developers working with fNIRS in
MATLAB. Avoid marketing language, decorative emoji, and filler statistics (line
counts, file counts, and similar). Prefer working code examples over prose, and
keep version numbers consistent across `README.md`, `CITATION.cff`, and the
changelog. Test every code example you add.

## Pull requests

- Branch from `master`; keep each PR focused on one change.
- Include tests and documentation updates with the code.
- Describe the change and its motivation in the PR; note any breaking changes
  and migration steps.
- Ensure `pf2_base.tests.runAllTests()` passes before requesting review.

## License

processFNIRS2 is licensed under the GNU General Public License v3.0 (GPLv3). By
contributing, you agree that your contributions are licensed under the same
terms. See [LICENSE](LICENSE), and record any bundled third-party code in
[THIRD_PARTY_LICENSES.md](THIRD_PARTY_LICENSES.md).
