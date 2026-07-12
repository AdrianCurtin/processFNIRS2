% EXAMPLE_DOT_RECONSTRUCTION
%
% Diffuse Optical Tomography (DOT): move from channel-space topography to
% image-space reconstruction of HbO/HbR on the cortical surface.
%   1. Forward model — the photon-measurement-density (PMDF) sensitivity matrix
%   2. Montage coverage — where the probe can actually see
%   3. Honest PMDF projection of channel values (physical "banana" vs Gaussian)
%   4. Image reconstruction — depth-weighted Tikhonov minimum-norm inverse
%   5. Rendering the reconstruction on cortex, masked to the sensitivity field
%
% DOT estimates a spatial map of hemoglobin change by inverting an atlas
% forward model, rather than interpolating channel values for display. With a
% sparse single-distance montage the resolution is coarse (~2-3 cm) and the
% value is the reconstruction infrastructure; it sharpens with high-density /
% short-separation montages. See internal/DOT_ROADMAP.md.
%
% Run top-to-bottom. Outputs are written to a temp folder and the paths printed.

% -- Setup ----------------------------------------------------------------
outDir = fullfile(tempdir, 'pf2_dot');
if ~exist(outDir, 'dir'), mkdir(outDir); end
fprintf('Outputs -> %s\n', outDir);

proc = processFNIRS2(pf2.import.sampleData.fNIR2000());   % geometry-bearing

%% 1. Forward sensitivity model (PMDF)
% A(c, v) is the sensitivity of channel c to an absorption change at cortical
% vertex v — the banana-shaped photon-measurement-density of the source-
% detector pair, evaluated on the bundled MNI cortical surface.
[A, mesh] = pf2.probe.forward.sensitivity(proc);
fprintf('Forward model: %d channels x %d cortical vertices (%.2f%% filled)\n', ...
    size(A, 1), size(A, 2), 100 * nnz(A) / numel(A));

%% 2. Montage coverage — the optical-sensitivity support
% Where can this montage see? The coverage field gates honest reconstruction.
cov = pf2.probe.forward.coverage(proc);
fprintf('Cortex within coverage (>0.05): %d vertices\n', sum(cov > 0.05));

%% 3. Honest PMDF projection of channel values
% Project mean HbO onto cortex via the real sensitivity footprint (vs the
% Gaussian lateral kernel of project.biomarker 'interpolateType','sensitivity').
meanHbO = mean(proc.HbO(100:200, :), 1, 'omitnan');
pmdfPath = fullfile(outDir, 'pmdf_projection.png');
pf2.probe.project.pmdf(meanHbO, proc, ...
    'initCamPosition', 'front-left', 'savePath', pmdfPath);
fprintf('PMDF projection -> %s\n', pmdfPath);

%% 4. Image reconstruction (depth-weighted Tikhonov)
% Invert the forward model for a vertex-space map of HbO/HbR over a time window.
% Depth weighting + channel whitening sharpen localization; lambda is chosen by
% generalized cross-validation. Output is masked to the coverage support.
recon = pf2.probe.dot.reconstruct(proc, 'Time', [5 20]);
fprintf('Reconstruction: HbO/HbR [1 x %d], lambda(HbO)=%.2e\n', ...
    size(recon.HbO, 2), recon.lambda.HbO);

%% 5. Render the reconstruction on cortex
% Signed diverging map, faded by sensitivity so low-confidence cortex is faint.
tomoHbO = fullfile(outDir, 'dot_HbO.png');
pf2.probe.project.tomography(recon, 'Biomarker', 'HbO', ...
    'initCamPosition', 'front-left', 'savePath', tomoHbO);
tomoHbR = fullfile(outDir, 'dot_HbR.png');
pf2.probe.project.tomography(recon, 'Biomarker', 'HbR', ...
    'initCamPosition', 'front-left', 'savePath', tomoHbR);
fprintf('Tomography renders -> %s , %s\n', tomoHbO, tomoHbR);

%% 6. (Optional) tune the inverse
% Fixed regularization, no depth weighting, or a custom optical-property /
% scalp-offset forward model are all exposed:
%   recon = pf2.probe.dot.reconstruct(proc, 'Time', 30, ...
%       'Lambda', 1e9, 'DepthWeight', false);
%   [A, mesh] = pf2.probe.forward.sensitivity(proc, ...
%       'ScalpOffset', 14, 'MaxDistance', 40, 'mua', 0.018, 'musp', 1.0);

%% 7. Fidelity & high-density (Tier 3)

% 7a. Is this montage high-density / multi-distance? (sets expectations)
montage = pf2.probe.dot.montageInfo(proc, 'Print', true);

% 7b. Honest resolution: point-spread of the inverse operator
res = pf2.probe.dot.resolution(proc, 'NSeeds', 60);
fprintf('Resolution: median localization %.1f mm, spread %.1f mm, FWHM %.1f mm\n', ...
    res.summary.medianLocalization, res.summary.medianSpread, res.summary.medianFWHM);

% 7c. Layered head model + scalp regression + smoothness prior
reconHD = pf2.probe.dot.reconstruct(proc, 'Time', [5 20], ...
    'HeadModel', 'layered', 'ScalpRegression', true, 'Prior', 'laplacian');
hdPath = fullfile(outDir, 'dot_HbO_layered_smooth.png');
pf2.probe.project.tomography(reconHD, 'Biomarker', 'HbO', ...
    'initCamPosition', 'front-left', 'savePath', hdPath);
fprintf('Layered + scalp-regressed + smoothed reconstruction -> %s\n', hdPath);

% 7d. Time-resolved cortical movie of the reconstruction
moviePath = fullfile(outDir, 'dot_HbO_movie.mp4');
pf2.probe.plot.tomographyMovie(proc, 'Biomarker', 'HbO', ...
    'TimeRange', [0 30], 'NFrames', 40, 'FPS', 15, 'savePath', moviePath);
fprintf('Time-resolved DOT movie -> %s\n', moviePath);

fprintf('\nDone. DOT forward model, reconstruction, fidelity & resolution.\n');
