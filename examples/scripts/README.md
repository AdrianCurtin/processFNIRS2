# processFNIRS2 Examples

Runnable, copy-pasteable scripts that demonstrate the toolbox end to end. Each
script is self-contained: open it in MATLAB and run it (most use the bundled
`pf2.import.sampleData*` so they work out of the box). New to the toolbox? Work
through them in roughly the order below.

## Start here
| Script | What it covers |
|--------|----------------|
| [tutorial_end_to_end.m](tutorial_end_to_end.m) | Single subject: import → process → blocks → Experiment → stats/export. The best first script. |
| [tutorial_batch_workflow.m](tutorial_batch_workflow.m) | Multi-subject: directory import, CSV metadata, batch process, LME, batch export. |
| [example_basic_viewing.m](example_basic_viewing.m) | Viewing raw & processed data, markers, and segments. |

## Processing & pipelines
| Script | What it covers |
|--------|----------------|
| [example_pipeline_basics.m](example_pipeline_basics.m) | Build, inspect, tune, and run processing pipelines (the Pipeline API). |
| [example_pipeline_custom_function.m](example_pipeline_custom_function.m) | Write and integrate a custom processing step. |
| [example_global_signal_removal.m](example_global_signal_removal.m) | Remove systemic/global interference: CAR vs PCA-GSR vs short-channel regression, compared against ground truth. |
| [example_qc_pipeline.m](example_qc_pipeline.m) | Quality-control pipeline: checks, thresholds, applying recommendations. |

## Blocks, averaging & GLM
| Script | What it covers |
|--------|----------------|
| [example_import_blocks.m](example_import_blocks.m) | CSV metadata import, block definition, BIDS events, per-trial behavioral data. |
| [example_averaging_modes.m](example_averaging_modes.m) | Hierarchy vs flat vs none averaging; pseudoreplication. |
| [example_gca_timemodel.m](example_gca_timemodel.m) | Growth Curve Analysis with a polynomial TimeModel. |
| [example_glm_analysis.m](example_glm_analysis.m) | GLMExperiment workflow from continuous recordings. |
| [example_glm_advanced.m](example_glm_advanced.m) | Manual GLM pipeline with design matrix and first-level contrasts. |
| [example_glm_connectivity.m](example_glm_connectivity.m) | GLM-based connectivity (two methods). |
| [example_experiment_cli.m](example_experiment_cli.m) | Experiment class CLI: grouping, behavioral vars, aux signals, ROI, LME. |
| [example_neural_efficiency.m](example_neural_efficiency.m) | Neural efficiency: brain activation vs behavioral performance. |
| [example_group_stats_bridge.m](example_group_stats_bridge.m) | Bridge group LME results to a brain projection. |

## Connectivity & hyperscanning
| Script | What it covers |
|--------|----------------|
| [example_connectivity.m](example_connectivity.m) | Within-subject functional connectivity. |
| [example_hyperscanning.m](example_hyperscanning.m) | Inter-brain synchrony for paired recordings. |
| [example_ppi_hyperscanning.m](example_ppi_hyperscanning.m) | Cross-brain PPI: speaker→listener, HRV-derived, triad coupling, group PPI. |
| [example_hbica.m](example_hbica.m) | HB-ICA hyperscanning: dyad, group, block-wise, visualization. |

## Visualization
| Script | What it covers |
|--------|----------------|
| [example_plot_options.m](example_plot_options.m) | Plot types: error bands, scatter, heatmap, topo, LME, composite, saving. |
| [example_spatial_visualizations.m](example_spatial_visualizations.m) | Time-animation movies, sensitivity kernel, parcel projection, connectome, dual-brain synchrony. |
| [example_stat_visualizations.m](example_stat_visualizations.m) | 3D stat projections: p-values, F-stats, correlations, biomarkers. |
| [example_brain_render_styles.m](example_brain_render_styles.m) | High-quality 3D rendering styles, materials, colormaps, and the Explore3D explorer. |
| [SampleInterpolateValues3D.m](SampleInterpolateValues3D.m) · [SampleInterpolateValues3D_Animation.m](SampleInterpolateValues3D_Animation.m) | Lower-level 3D surface interpolation primitives. |

## Diffuse Optical Tomography & export
| Script | What it covers |
|--------|----------------|
| [example_dot_reconstruction.m](example_dot_reconstruction.m) | DOT: PMDF forward model, coverage, banana projection, image reconstruction, cortical render. |
| [example_snirf_export.m](example_snirf_export.m) | Exporting fNIRS data to SNIRF format. |

## Notebook templates
The [`../notebooks/`](../notebooks) directory holds longer analysis templates
(task block design, resting state, hyperscanning, longitudinal, sample-report
generation). These are scaffolds for structuring a full analysis — adapt the
data paths to your own dataset.

---

See the [project README](../../README.md) for installation and a quick start,
and [`docs/`](../../docs) for the reference documentation.
