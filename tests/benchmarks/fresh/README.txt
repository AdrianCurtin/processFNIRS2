FRESH fNIRS Reproducibility Benchmark
======================================

Reproduces the FRESH study (Yuecel et al. 2025, Communications Biology)
within processFNIRS2, running the same SNIRF datasets through multiple
pipeline configurations and comparing results.

Reference:
  Yuecel, M. A. et al. (2025). fNIRS Reproducibility and Estimation of
  Statistical power from a Harmonized study (FRESH). Communications Biology.
  DOI: 10.1038/s42003-025-08412-1

Data Source:
  https://osf.io/b4wck/

Setup
-----

1. Download both datasets from OSF (https://osf.io/b4wck/)

2. Extract into tests/benchmarks/data/:

   tests/benchmarks/data/
   ├── dataset_I_auditory/     BIDS structure: sub-XX/nirs/*.snirf
   └── dataset_II_motor/       BIDS structure: sub-XX/nirs/*.snirf

3. Validate setup:

   >> run('tests/benchmarks/fresh/setup.m')

Running Benchmarks
------------------

Dataset II (Motor, simpler - start here):

   >> run('tests/benchmarks/fresh/runDatasetII.m')

Dataset I (Auditory, group-level):

   >> run('tests/benchmarks/fresh/runDatasetI.m')

Analyze and compare results:

   >> run('tests/benchmarks/fresh/analyzeResults.m')

Pipeline Configurations
-----------------------

10 pipelines covering key combinations from the FRESH paper:

  1. minimal          - No preprocessing, baseline only
  2. tddr_only        - TDDR motion correction
  3. tddr_bpf         - TDDR + bandpass (0.01-0.5 Hz)
  4. smar_lpf         - SMAR + lowpass (0.1 Hz)
  5. wavelet_bpf      - Wavelet + bandpass
  6. tddr_ssr_blockavg - TDDR + short-channel regression
  7. tddr_glm_ols     - TDDR + GLM (OLS)
  8. tddr_ssr_glm     - TDDR + SSR + GLM (OLS)
  9. tddr_ssr_glm_arirls - TDDR + SSR + GLM (AR-IRLS)
 10. takizawa_bpf     - Takizawa rejection + bandpass

Datasets
--------

Dataset I (Auditory):
  - Speech/noise/silence block design
  - 7 group-level hypotheses (Heschl's gyri, IFG, occipital cortex)

Dataset II (Motor):
  - 10 subjects, 64 channels + 4 short channels, 8.9 Hz
  - Left/right finger tapping (2s/3s blocks)
  - 4 individual-level hypotheses (contralateral motor cortex)

Output
------

Results are saved to tests/benchmarks/results/ (gitignored).

Files
-----

  setup.m           - Validates data download
  definePipelines.m - Pipeline configuration definitions
  runDatasetII.m    - Motor dataset benchmark runner
  runDatasetI.m     - Auditory dataset benchmark runner
  analyzeResults.m  - Cross-pipeline comparison and visualization
