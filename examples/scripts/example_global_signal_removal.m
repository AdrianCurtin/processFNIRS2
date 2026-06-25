%% example_global_signal_removal.m - CAR vs PCA-GSR vs short-channel regression
%
% Systemic physiology (scalp blood flow, Mayer waves ~0.1 Hz, cardiac,
% blood pressure) is spatially shared across fNIRS channels and is the main
% nuisance standing between you and the focal neural response. Three ways to
% remove it, in increasing order of how well-motivated they are:
%
%   CAR  (pf2_CAR)  - subtract the raw spatial mean across channels. One
%                     fixed component. Borrowed from EEG; blunt.
%   GSR  (pf2_GSR)  - subtract the leading principal component(s) of the
%                     across-channel covariance (a global PCA spatial filter
%                     in the spirit of Zhang et al. 2005). A data-driven,
%                     tunable generalization of CAR.
%   SSR  (pf2_SSR)  - regress out measured short-separation channels, which
%                     sample superficial tissue only. The gold standard --
%                     it *measures* the nuisance instead of assuming the
%                     spatial mean equals it. Requires short channels.
%
% CAR and GSR force a component out of every channel, which can remove real
% focal signal and inject spurious anti-correlations. This script runs all
% three on the bundled fNIR2000 recording (which has short channels) and
% then uses a ground-truth simulation to show the trade-off.
%
% Covers:
%   1. CAR / GSR / SSR on the bundled fNIR2000 sample (real short channels)
%   2. GSR as a registered pipeline step
%   3. Ground-truth simulation: recover a focal response buried in systemic
%      noise, scoring each method against the known answer
%
% Requirements:
%   - processFNIRS2 on path

cd(fileparts(mfilename('fullpath')));
cd('../..');  % project root

outDir = fullfile(tempdir, 'global_signal_removal');
if ~exist(outDir, 'dir'), mkdir(outDir); end

meanOffDiag = @(M) mean(M(triu(true(size(M,2)),1)), 'omitnan');

%% Part 1: CAR / GSR / SSR on real sample data
%
% The bundled fNIR2000 recording is 18 channels: 16 long + 2 short-separation
% (channels 17-18, SD ~1 vs ~2.5). SSR detects the short channels from the
% device geometry; CAR and GSR operate on the long-channel matrix.

fprintf('=== Part 1: CAR / GSR / SSR on fNIR2000 sample ===\n');

data = pf2.import.sampleData.fNIR2000();
proc = processFNIRS2(data);

% Short channels (from the device). CAR and GSR estimate the global term
% from the LONG channels only -- short channels carry mostly superficial
% signal and should not pollute the spatial mean / PCA basis. SSR instead
% uses the short channels as the regressor.
longCh  = find(~logical(proc.device.isShortSep()));
hboLong = proc.HbO(:, longCh);

car            = pf2_CAR(hboLong);
[gsr, gi]      = pf2_GSR(hboLong, 1);
ssrStruct      = pf2_SSR(proc, 'nearest');     % regresses short channels out
ssrLong        = ssrStruct.HbO(:, longCh);

% Global structure left behind = mean pairwise correlation across long ch
R = @(M) meanOffDiag(corr(M, 'rows','pairwise'));
fprintf('GSR removed 1 PC = %.1f%% of long-channel HbO variance.\n', 100*gi.varRemoved);
fprintf('Mean pairwise corr (long ch):  raw=%.3f  CAR=%.3f  GSR=%.3f  SSR=%.3f\n', ...
    R(hboLong), R(car), R(gsr), R(ssrLong));
% Note: driving shared correlation toward zero is good for activation/contrast
% analysis, but global removal imposes a known NEGATIVE bias on functional-
% connectivity estimates (the GSR "anti-correlation" controversy). Interpret
% connectivity computed after CAR/GSR with care; SSR is preferable there.

%% Part 2: GSR as a registered pipeline step
%
% pf2_GSR is registered in pf2_functions_default.cfg, so it slots into an
% OxyPipeline / processFNIRS2 method chain like any other oxy-stage function.

fprintf('\n=== Part 2: GSR in a pipeline ===\n');
oxy = pf2_base.OxyPipeline('gsr_demo');
oxy = oxy.add('pf2_lpf', 'freq_cut', 0.2);
oxy = oxy.add('pf2_GSR', 'nComp', 1);
fprintf('%s\n', oxy.describe());

%% Part 3: Ground-truth simulation
%
% Real data has no ground truth, so build a recording where we KNOW the
% answer: a focal task response on a few "active" long channels, a strong
% shared systemic component on ALL channels (long and short), and short
% channels carrying ONLY the systemic signal. Then score how well each
% method recovers the true focal response and how much nuisance it leaves.
%
% This setup is deliberately idealized and somewhat favors GSR/SSR; read the
% scores as illustrative, not as real-world performance:
%   - short channels carry ZERO neural (optimistic for SSR; real short
%     channels carry residual cortical + global signal)
%   - the systemic term is essentially rank-1 (one shared source x gains),
%     exactly the regime where nComp=1 GSR is ideal; real systemic
%     interference is spatially heterogeneous and multi-component
%   - cardiac (~1.1 Hz, below the 3.9 Hz Nyquist, so NOT aliased) is left in
%     to stress the spatial methods; normally a low-pass step removes it first

fprintf('\n=== Part 3: ground-truth recovery ===\n');

rng(0);
fs   = 7.8125;                 % Hz (fNIR-like)
T    = round(300*fs);          % 5 min
t    = (0:T-1)'/fs;
nLong = 12; nShort = 4; nOpt = nLong + nShort;
shortIdx = nLong + (1:nShort);
activeCh = [3 4 9 10];         % long channels with a real response

% Shared systemic nuisance: Mayer wave + slow drift + cardiac
systemic = 1.2*sin(2*pi*0.10*t) + 0.8*sin(2*pi*0.04*t + 1) + ...
           0.4*sin(2*pi*1.10*t) + 0.5*cumsum(randn(T,1))/sqrt(T);

% Focal neural response: 20 s on / 20 s off blocks convolved with an HRF
boxcar = double(mod(floor(t/20), 2) == 0);
hrf = (t.^6.*exp(-t)); hrf = hrf(1:round(20*fs)); hrf = hrf/max(hrf);
neuralProto = conv(boxcar, hrf); neuralProto = neuralProto(1:T);
neuralProto = neuralProto / max(neuralProto);

% Observed HbO [T x nOpt]; short channels get systemic only, no neural
sysGain   = 0.8 + 0.4*rand(1, nOpt);
HbO = sysGain .* systemic + 0.15*randn(T, nOpt);
trueNeural = zeros(T, nOpt);
trueNeural(:, activeCh) = neuralProto * (0.6 + 0.2*rand(1, numel(activeCh)));
HbO = HbO + trueNeural;

% Minimal struct the real SSR code path understands
sim = struct();
sim.HbO = HbO; sim.HbR = -0.4*HbO;
pos = [ (1:nLong)'*30, zeros(nLong,1), zeros(nLong,1); ...
        (1:nShort)'*30*(nLong/nShort), 8*ones(nShort,1), zeros(nShort,1) ];
isShortSim = false(1, nOpt); isShortSim(shortIdx) = true;
sim.probeinfo.Probe = { struct('IsShortSeparation', isShortSim, 'OptPos3D', pos) };

% Apply the three methods
car = pf2_CAR(sim.HbO);
gsr = pf2_GSR(sim.HbO, 1);
ssr = pf2_base.fnirs.shortChannelRegression(sim, 'Method','all', ...
    'Biomarkers', {'HbO'}).HbO;

% Score: correlation of recovered vs TRUE neural on active channels
recover = @(M) mean(arrayfun(@(c) corr(M(:,c), trueNeural(:,c)), activeCh));
fprintf('Recovery of focal response (corr w/ ground truth):\n');
fprintf('  raw=%.3f  CAR=%.3f  GSR=%.3f  SSR=%.3f\n', ...
    recover(sim.HbO), recover(car), recover(gsr), recover(ssr));

% Residual systemic leakage on a non-active long channel (lower = better)
quietCh = 6;
leak = @(M) abs(corr(M(:,quietCh), systemic));
fprintf('Residual systemic on a quiet channel (|corr w/ nuisance|):\n');
fprintf('  raw=%.3f  CAR=%.3f  GSR=%.3f  SSR=%.3f\n', ...
    leak(sim.HbO), leak(car), leak(gsr), leak(ssr));

% Spurious focal leakage onto a channel with NO true response: the zero-sum
% cost. CAR/GSR stamp a negative copy of the focal response onto inactive
% channels (~0 ideal; negative = injected anti-correlation). This is the
% concrete face of the "forced anti-correlation" caveat -- SSR avoids it
% because it regresses a MEASURED signal, not a spatial summary of the data.
inject = @(M) corr(M(:,quietCh), neuralProto);
fprintf('Injected focal leakage on a quiet channel (corr w/ neural, ~0 ideal):\n');
fprintf('  raw=%.3f  CAR=%.3f  GSR=%.3f  SSR=%.3f\n', ...
    inject(sim.HbO), inject(car), inject(gsr), inject(ssr));

% Figure: true vs recovered on one active channel
fig = figure('Visible','off','Position',[100 100 900 500]);
c = activeCh(1);
plot(t, trueNeural(:,c), 'k', 'LineWidth', 2); hold on;
plot(t, detrend(car(:,c)), 'Color',[.85 .4 .4]);
plot(t, detrend(gsr(:,c)), 'Color',[.4 .6 .85]);
plot(t, detrend(ssr(:,c)), 'Color',[.3 .7 .4], 'LineWidth',1.3);
legend({'true neural','CAR','GSR','SSR'}, 'Location','best'); box off;
xlabel('time (s)'); ylabel('HbO (a.u.)');
title(sprintf('Channel %d: focal response recovery', c)); xlim([0 120]);
saveas(fig, fullfile(outDir, 'recovery.png')); close(fig);

%% Notes
%
% On real recordings with short channels, just call SSR after processing:
%   proc = pf2_SSR(proc, 'nearest');     % or 'pca' / 'all'
% No short channels? Use GSR as a proxy (1 PC ~ CAR, but tunable):
%   proc.HbO = pf2_GSR(proc.HbO, 1);  proc.HbR = pf2_GSR(proc.HbR, 1);

fprintf('\nSaved recovery figure: %s\nDONE\n', fullfile(outDir, 'recovery.png'));
