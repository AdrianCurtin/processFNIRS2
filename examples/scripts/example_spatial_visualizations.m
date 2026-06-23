% EXAMPLE_SPATIAL_VISUALIZATIONS
%
% Demonstrates the spatial visualization additions for projecting activation,
% anatomy, and connectivity onto the probe / cortical surface:
%   1. Time-animation movies of a biomarker (MP4 / GIF)
%   2. Sensitivity-weighted cortical interpolation kernel
%   3. Anatomical (Brodmann) parcel projection
%   4. Brain-anchored connectome (edges drawn on the cortex / probe)
%   5. Dual-brain inter-brain synchrony with a linked wavelet panel
%
% Run top-to-bottom. File outputs are written to a temp folder and the paths
% are printed; figures are also left open for interactive inspection.

% -- Setup ----------------------------------------------------------------
outDir = fullfile(tempdir, 'pf2_spatial_viz');
if ~exist(outDir, 'dir'), mkdir(outDir); end
fprintf('Outputs -> %s\n', outDir);

procMrk = processFNIRS2(pf2.import.sampleData());          % WITH markers
proc    = processFNIRS2(pf2.import.sampleData.fNIR2000()); % no markers

%% 1. Time-animation movie (3D cortex)
% Sweep HbO over time; one global color scale; time + marker stamp per frame.
mp4Path = fullfile(outDir, 'hbo_movie.mp4');
pf2.probe.plot.movie(procMrk, 'HbO', ...
    'TimeRange', [0 40], 'NFrames', 80, 'FPS', 20, ...
    'initCamPosition', 'front', 'savePath', mp4Path);

% 2D heatmap movie as an animated GIF
gifPath = fullfile(outDir, 'hbo_movie.gif');
pf2.probe.plot.movie(procMrk, 'HbO', 'View', '2d', ...
    'TimeRange', [0 40], 'NFrames', 60, 'FPS', 15, 'savePath', gifPath);

% Same thing via the topo shortcut (delegates to movie):
pf2.probe.plot.topo(procMrk, 'HbO', 'View', 'movie', ...
    'Time', [0 40], 'NFrames', 60, 'savePath', fullfile(outDir, 'topo_movie.mp4'));

%% 2. Sensitivity-weighted interpolation kernel
% Gaussian optical-sensitivity falloff (smooth) vs the default nearest/IDW.
meanHbO = mean(proc.HbO, 1, 'omitnan');
figure('Color', 'w', 'Position', [0 0 900 700]);
pf2.probe.project.biomarker(meanHbO, proc, ...
    'interpolateType', 'sensitivity', ...
    'initCamPosition', 'front', 'ForceLightMode', true);
title('HbO — sensitivity kernel');

%% 3. Anatomical parcel projection
% Canonicalize to a Brodmann-region axis, then flat-fill each parcel.
procC = pf2.probe.canonicalize(proc, 'MaxDistance', 25);
figure('Color', 'w', 'Position', [0 0 900 700]);
pf2.probe.project.regions('HbO', procC, ...      % biomarker name -> time mean
    'initCamPosition', 'front');
title('HbO — Brodmann parcels');

%% 4. Brain-anchored connectome
% Channel-level Pearson connectivity drawn at real optode positions.
conn = exploreFNIRS.connectivity.computeMatrix(proc, ...
    'Method', 'pearson', 'Biomarker', 'HbO');

figure('Color', 'w', 'Position', [0 0 900 700]);
pf2.probe.plot.connectome(conn, proc, 'View', '3d', ...
    'TopN', 30, 'initCamPosition', 'front');

figure('Color', 'w', 'Position', [0 0 1000 500]);
pf2.probe.plot.connectome(conn, proc, 'View', '2d', 'Threshold', 0.5);

%% 5. Dual-brain inter-brain synchrony
% Cross-brain coupling between two subjects (here the same recording twice),
% with a linked wavelet-coherence time-frequency panel.
A = proc; B = processFNIRS2(pf2.import.sampleData.fNIR2000());
dyad = exploreFNIRS.hyperscanning.computeDyad(A, B, ...
    'Method', 'pearson', 'ChannelPairing', 'all');

% A wavelet-coherence panel for one homologous channel pair (channel 1).
wc = exploreFNIRS.coupling.wcoherence(A.HbO(:,1), B.HbO(:,1), A.fs);

exploreFNIRS.hyperscanning.plotDualBrain(dyad, A, B, ...
    'TopN', 30, 'Wcoherence', wc, ...
    'BrainLabels', {'Child', 'Parent'}, ...
    'SavePath', fullfile(outDir, 'dualbrain.png'));

fprintf('Done. Movie/GIF/PNG outputs are in %s\n', outDir);
