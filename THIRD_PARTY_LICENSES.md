# Third-Party Licenses

processFNIRS2 is licensed under the **GNU General Public License, Version 3
(GPLv3)**. The full license text is in the [`LICENSE`](LICENSE) file at the
root of this repository.

This document lists the third-party code that is bundled (vendored) inside
the processFNIRS2 source tree, together with each component's author/origin,
version, upstream URL, license, the location of the code within this
repository, the bundled license text, and how processFNIRS2 uses it.

All bundled components are GPL-compatible. Where a component is offered by
its author under more than one license, processFNIRS2 redistributes it under
the **GPLv3 option** so that the combined work remains a coherent GPLv3
distribution. Components offered under permissive licenses (BSD-3-Clause,
Apache-2.0) are compatible with the GPLv3 and are redistributed in
compliance with their terms.

---

## 1. EasyH5

| Field | Value |
|-------|-------|
| **Component** | EasyH5 Toolbox (HDF5 data interface — `loadh5` / `saveh5`) |
| **Author / Origin** | Qianqian Fang, Department of Bioengineering, Northeastern University, as part of the NeuroJSON project |
| **Version** | 0.9 (code name "Daseot"); per-file copyright marked 2019, 2022 |
| **Upstream URL** | https://github.com/NeuroJSON/easyh5 |
| **License** | Dual-licensed: GPLv3 (`GPL-3.0-or-later`) **OR** BSD-3-Clause. processFNIRS2 redistributes it under the **GPLv3 option**. |
| **Path in this repo** | `+pf2_base/+external/+easyh5/` |
| **Bundled license text** | `+pf2_base/+external/+easyh5/LICENSE_GPLv3.txt` (and BSD-3 alternative in `LICENSE_BSD-3.txt`) |
| **How it is used** | Provides HDF5 read/write used by SNIRF import/export, via the bundled JSNIRF toolbox. |

## 2. JSNIRF Toolbox

| Field | Value |
|-------|-------|
| **Component** | JSNIRF Toolbox (parses SNIRF (HDF5) and JSNIRF (JSON) fNIRS files) |
| **Author / Origin** | Qianqian Fang, Department of Bioengineering, Northeastern University, as part of the NeuroJData/OpenJData project |
| **Version** | 0.4 (code name "Amygdala – alpha"); per-file copyright marked 2019 |
| **Upstream URL** | https://github.com/fangq/jsnirf |
| **License** | Dual-licensed: GPLv3 (`GPL-3.0-or-later`) **OR** Apache-2.0. processFNIRS2 redistributes it under the **GPLv3 option**. |
| **Path in this repo** | `+pf2_base/+external/+jsnirfy/` |
| **Bundled license text** | `+pf2_base/+external/+jsnirfy/LICENSE_GPLv3.txt` (and Apache-2.0 alternative in `LICENSE_Apache-2.0.txt`) |
| **How it is used** | Backs `pf2.import.importSNIRF` and `pf2.export.asSNIRF` for reading/writing SNIRF v1.0 files. Depends on the bundled EasyH5 toolbox. |

## 3. Perceptually-Uniform Colormaps + BrewerMap

| Field | Value |
|-------|-------|
| **Component** | MatPlotLib Perceptually Uniform Colormaps (viridis, magma, inferno, plasma, cividis, twilight, tab10/20/...) and `brewermap` (ColorBrewer colorschemes) |
| **Author / Origin** | Stephen Cobeldick (code and MATLAB ports). The ColorBrewer **color values** used by `brewermap` are by Cynthia Brewer, Mark Harrower, and The Pennsylvania State University. |
| **Version** | Not version-tagged in the bundled files; copyright dates 2014–2022 (`brewermap`) and 2022 (matplotlib colormaps). |
| **Upstream URL** | https://www.mathworks.com/matlabcentral/fileexchange/62729 (matplotlib colormaps); ColorBrewer color data: http://colorbrewer.org/ |
| **License** | matplotlib colormaps and `brewermap` code/implementation: **BSD-3-Clause** (`BSD-3-Clause`), © Stephen Cobeldick. The embedded ColorBrewer color values are under the **Apache-2.0**-style ColorBrewer license, © Cynthia Brewer et al. Both are GPL-compatible. |
| **Path in this repo** | `+pf2_base/+external/+colormaps/` (`brewermap.m` and `+matplotlib/`) |
| **Bundled license text** | `+pf2_base/+external/+colormaps/+matplotlib/license.txt` (BSD-3, Cobeldick). The ColorBrewer terms are reproduced in the license block at the bottom of `brewermap.m`. |
| **How it is used** | Colormap selection for plotting in exploreFNIRS (`+exploreFNIRS/+helper/getColormap.m`, `listColormaps.m`), which invokes `brewermap`. |

> **Note (uncertain field):** the bundled colormap files do not carry an
> explicit upstream version string; the listed dates are the copyright years
> found in the files. The matplotlib license file (`+matplotlib/license.txt`)
> is a standard BSD-3-Clause text whose "name of ___" organization line was
> left blank in the bundled copy.

## 4. FastICA

| Field | Value |
|-------|-------|
| **Component** | FastICA for MATLAB (fast fixed-point algorithm for Independent Component Analysis) |
| **Author / Origin** | Hugo Gavert, Jarmo Hurri, Jaakko Sarela, and Aapo Hyvarinen — Laboratory of Computer and Information Science, Helsinki University of Technology (now Aalto University), Finland |
| **Version** | 2.5 (October 19, 2005) |
| **Upstream URL** | https://research.ics.aalto.fi/ica/fastica/ (formerly http://www.cis.hut.fi/projects/ica/fastica/) |
| **License** | GNU General Public License, **version 2 or any later version** (`GPL-2.0-or-later`), © 1996–2005 the authors above. Redistributed here under the **GPLv3** terms of this project, as permitted by the "or any later version" clause. |
| **Path in this repo** | `OtherToolboxes/FastICA_25/` |
| **Bundled license text** | `OtherToolboxes/FastICA_25/LICENSE.txt` (license notice added by processFNIRS2; the copyright statement is in the upstream `Contents.m`). |
| **How it is used** | Optional ICA backend for `functions/icaClean.m` (and referenced by `functions/pf2_ambient_ICA_clean.m`); used only when FastICA is selected/available on the MATLAB path. |

> **Note (provenance):** the bundled FastICA copy states its copyright in
> `Contents.m` but the individual `.m` source files do not carry per-file
> license headers. A `LICENSE.txt` notice has been added to make the
> applicable GPL terms explicit; the upstream license (GPLv2-or-later) was
> confirmed against the official FastICA distribution.

---

## Formerly-bundled components replaced by original implementations

During a licensing cleanup, several utilities that were previously vendored
into processFNIRS2 were removed and rewritten as original processFNIRS2
code under the project's GPLv3 license. This is noted here so that reviewers
understand the provenance of the affected functionality and do not expect to
find third-party license obligations attached to it.

The removed-and-rewritten material fell into three groups:

- **MathWorks-proprietary helpers** that had been copied into the tree
  (signal-filtering and figure/geometry helpers such as `filtfilt`,
  `suptitle`, `vrrotvec`, and `vrrotvec2mat`). These were re-implemented from
  scratch so the toolbox no longer redistributes MathWorks-proprietary code.

- **Unlicensed or license-unclear File Exchange / community snippets**
  (INI-file handling, grouped bar charts, vertical-line plotting, parametric
  confidence-interval helpers, histogram helpers, and an ICBM FSL-to-Talairach
  coordinate transform). These were replaced with clean original
  implementations.

- **The Wavelab850 wavelet library**, which was removed entirely; the wavelet
  functionality processFNIRS2 relies on was rewritten as original GPLv3 code.

All replacement code is original to processFNIRS2 and is covered by the
project's GPLv3 license; it carries no separate third-party license
obligations.
