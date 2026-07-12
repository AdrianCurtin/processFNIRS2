% EXAMPLE_STAT_VISUALIZATIONS
%
% Demonstrates pf2.probe.project.* — five stat-specific 3D projections onto
% the cortical surface. Each wrapper handles colormap, range, significance
% thresholding, and transparency of non-significant regions for you.
%
% Run top-to-bottom. Each section produces a figure.

% -- Setup ----------------------------------------------------------------
raw = pf2.import.sampleData.fNIR2000();
processed = processFNIRS2(raw);
K = size(processed.HbO, 2);

rng(42);
% Synthetic stat inputs (in real use these come from LME / GLM / FDR):
pvals = rand(1, K);
pvals([1 3 5 9]) = 0.002;          % strongly significant
pvals([7 11])    = 0.03;            % marginally significant
Fvals = abs(randn(1, K)) * 2 + 1;
Fvals([1 3 5 9]) = Fvals([1 3 5 9]) + 8;
rho = 2 * rand(1, K) - 1;
rho([1 3 9])  = 0.8;
rho([4 6 12]) = -0.75;
Nvals = randi([5 30], 1, K);
HbO_t = processed.HbO(100, :);

% -- §1  p-values ---------------------------------------------------------
% -log10 colorbar ticked at raw p thresholds. Non-sig channels transparent.
fig1 = figure('Color', 'w', 'Position', [0 0 900 700]);
pf2.probe.project.pvalues(pvals, processed, ...
    'pThreshold', 0.05, ...
    'PTicks', [0.05 0.01 0.001], ...
    'ForceLightMode', true, ...
    'initCamPosition', 'front');

% -- §2  p-values with FDR correction ------------------------------------
fig2 = figure('Color', 'w', 'Position', [0 0 900 700]);
pf2.probe.project.pvalues(pvals, processed, ...
    'pThreshold', 0.05, 'FDR', true, ...
    'ForceLightMode', true, 'initCamPosition', 'front');

% -- §3  F-statistics, thresholded by companion p-values -----------------
fig3 = figure('Color', 'w', 'Position', [0 0 900 700]);
pf2.probe.project.fstats(Fvals, processed, ...
    'pvalues', pvals, 'pThreshold', 0.05, ...
    'ForceLightMode', true, 'initCamPosition', 'front');

% -- §4  F-statistics, thresholded by F critical (no pvalues) ------------
fig4 = figure('Color', 'w', 'Position', [0 0 900 700]);
pf2.probe.project.fstats(Fvals, processed, ...
    'Fcritical', 3.84, ...   % χ²(1) = 3.84 at α=0.05
    'ForceLightMode', true, 'initCamPosition', 'front');

% -- §5  Correlation (signed rho) with pvalues ---------------------------
% Two colorbars (warm positive, cool negative), transparent when non-sig.
fig5 = figure('Color', 'w', 'Position', [0 0 900 700]);
pf2.probe.project.correlation(rho, processed, ...
    'pvalues', pvals, 'pThreshold', 0.05, ...
    'ForceLightMode', true, 'initCamPosition', 'front');

% -- §6  Biomarker (signed HbO) with pvalues -----------------------------
fig6 = figure('Color', 'w', 'Position', [0 0 900 700]);
pf2.probe.project.biomarker(HbO_t, processed, ...
    'Range', [-1 1], ...
    'pvalues', pvals, 'pThreshold', 0.05, ...
    'ForceLightMode', true, 'initCamPosition', 'front');

% -- §7  Biomarker without significance (blend mode, two colorbars) ------
fig7 = figure('Color', 'w', 'Position', [0 0 900 700]);
pf2.probe.project.biomarker(HbO_t, processed, ...
    'Range', [-1 1], 'DeadZone', 0.2, ...   % |HbO|<0.2 → brain color
    'ForceLightMode', true, 'initCamPosition', 'front');

% -- §8  Sample counts (N per channel) -----------------------------------
fig8 = figure('Color', 'w', 'Position', [0 0 900 700]);
pf2.probe.project.counts(Nvals, processed, ...
    'ForceLightMode', true, 'initCamPosition', 'front');

% -- Done -----------------------------------------------------------------
disp('example_stat_visualizations done.');
