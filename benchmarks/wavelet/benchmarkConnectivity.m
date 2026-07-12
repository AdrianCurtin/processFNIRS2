function results = benchmarkConnectivity(varargin)
% BENCHMARKCONNECTIVITY Benchmark wavelet coherence connectivity performance
%
% Compares the batch CWT approach (pre-compute CWT once per channel) against
% the per-pair approach for wavelet coherence connectivity matrices. Tests
% with varying channel counts to demonstrate the scaling advantage.
%
% Syntax:
%   results = benchmarkConnectivity()
%   results = benchmarkConnectivity('Reps', 3)
%   results = benchmarkConnectivity('Quick', true)
%
% Inputs (name-value):
%   Reps     - Repetitions per measurement (default: 3)
%   SavePath - Path to save results .mat file (default: '' = don't save)
%   Quick    - Skip larger channel counts (default: false)
%   Plot     - Generate figures (default: true)
%
% Outputs:
%   results - Struct with timing data for each benchmark section
%
% See also: exploreFNIRS.connectivity.computeMatrix, pf2_base.wavelet.cwt,
%   pf2_base.wavelet.wcoherence, benchmarkWavelet

    p = inputParser;
    addParameter(p, 'Reps', 3, @isscalar);
    addParameter(p, 'SavePath', '', @ischar);
    addParameter(p, 'Quick', false, @islogical);
    addParameter(p, 'Plot', true, @islogical);
    parse(p, varargin{:});
    opts = p.Results;

    fprintf('\n');
    fprintf('========================================================\n');
    fprintf('  WAVELET COHERENCE CONNECTIVITY BENCHMARK\n');
    fprintf('========================================================\n');
    fprintf('  Date:  %s\n', datestr(now));
    fprintf('  Reps:  %d\n', opts.Reps);
    fprintf('  Mode:  %s\n', ternary(opts.Quick, 'Quick', 'Full'));
    fprintf('========================================================\n\n');

    results = struct();
    results.timestamp = datetime('now');
    results.reps = opts.Reps;

    % ================================================================
    %  SECTION 1: Single-pair CWT vs batch CWT overhead
    % ================================================================
    results.cwtOverhead = benchSection_CwtOverhead(opts);

    % ================================================================
    %  SECTION 2: Connectivity matrix scaling with channel count
    % ================================================================
    results.channelScaling = benchSection_ChannelScaling(opts);

    % ================================================================
    %  SECTION 3: Hyperscanning dyad scaling
    % ================================================================
    if ~opts.Quick
        results.dyadScaling = benchSection_DyadScaling(opts);
    end

    % ================================================================
    %  Summary
    % ================================================================
    printSummary(results);

    % ================================================================
    %  Plots
    % ================================================================
    if opts.Plot
        plotResults(results, opts);
    end

    if ~isempty(opts.SavePath)
        save(opts.SavePath, 'results');
        fprintf('Results saved to: %s\n', opts.SavePath);
    end
end


%% =====================================================================
%  BENCHMARK SECTIONS
%  =====================================================================

function out = benchSection_CwtOverhead(opts)
    fprintf('--- Section 1: CWT Overhead (single vs batch) ---\n');

    nSamples = 4000;
    fs = 10;

    % Generate two test signals
    rng(42);
    x = randn(nSamples, 1) + 0.5 * sin(2*pi*0.05*(1:nSamples)'/fs);
    y = randn(nSamples, 1) + 0.3 * sin(2*pi*0.05*(1:nSamples)'/fs);

    nReps = max(opts.Reps, 3);

    % Warmup
    pf2_base.wavelet.cwt(x, fs);
    pf2_base.wavelet.wcoherence(x, y, fs);

    % Time: individual CWT calls
    t_cwt_single = zeros(1, nReps);
    for r = 1:nReps
        t0 = tic;
        pf2_base.wavelet.cwt(x, fs);
        pf2_base.wavelet.cwt(y, fs);
        t_cwt_single(r) = toc(t0);
    end

    % Time: batch CWT (both signals at once)
    XY = [x, y];
    t_cwt_batch = zeros(1, nReps);
    for r = 1:nReps
        t0 = tic;
        pf2_base.wavelet.cwt(XY, fs);
        t_cwt_batch(r) = toc(t0);
    end

    % Time: full wcoherence (including internal CWT)
    t_wcoh_fresh = zeros(1, nReps);
    for r = 1:nReps
        t0 = tic;
        pf2_base.wavelet.wcoherence(x, y, fs);
        t_wcoh_fresh(r) = toc(t0);
    end

    % Time: wcoherence with pre-computed CWT
    cwtAll = pf2_base.wavelet.cwt(XY, fs);
    baseCwt = struct('freqs', cwtAll.freqs, 'scales', cwtAll.scales, ...
                     'coi', cwtAll.coi, 'fs', cwtAll.fs, 'omega0', cwtAll.omega0);
    cwtX = baseCwt; cwtX.coeffs = cwtAll.coeffs(:,:,1);
    cwtY = baseCwt; cwtY.coeffs = cwtAll.coeffs(:,:,2);

    t_wcoh_precomp = zeros(1, nReps);
    for r = 1:nReps
        t0 = tic;
        pf2_base.wavelet.wcoherence(x, y, fs, 'CwtX', cwtX, 'CwtY', cwtY);
        t_wcoh_precomp(r) = toc(t0);
    end

    fprintf('  CWT (2 individual calls):     %8.4f s\n', median(t_cwt_single));
    fprintf('  CWT (batch [T x 2]):          %8.4f s  (%.1fx)\n', ...
        median(t_cwt_batch), median(t_cwt_single)/median(t_cwt_batch));
    fprintf('  Wcoherence (fresh):           %8.4f s\n', median(t_wcoh_fresh));
    fprintf('  Wcoherence (pre-computed):    %8.4f s  (%.1fx)\n', ...
        median(t_wcoh_precomp), median(t_wcoh_fresh)/median(t_wcoh_precomp));
    fprintf('\n');

    out.t_cwt_single = t_cwt_single;
    out.t_cwt_batch = t_cwt_batch;
    out.t_wcoh_fresh = t_wcoh_fresh;
    out.t_wcoh_precomp = t_wcoh_precomp;
    out.nSamples = nSamples;
    out.fs = fs;
end


function out = benchSection_ChannelScaling(opts)
    fprintf('--- Section 2: Connectivity Matrix — Channel Count Scaling ---\n');

    nSamples = 2000;
    fs = 10;

    if opts.Quick
        channelCounts = [4, 8, 12];
    else
        channelCounts = [4, 8, 12, 18, 24];
    end

    batch_times = NaN(length(channelCounts), opts.Reps);
    perpair_times = NaN(length(channelCounts), opts.Reps);

    for ci = 1:length(channelCounts)
        nCh = channelCounts(ci);
        nPairs = nCh * (nCh - 1) / 2;

        data = generateTestProcessed(nSamples, nCh, fs);
        fprintf('  nCh=%3d (%3d pairs): ', nCh, nPairs);

        % Warmup batch path
        try
            exploreFNIRS.connectivity.computeMatrix(data, ...
                'Method', 'wcoherence', 'Accelerate', 'none');
        catch ME
            fprintf('ERROR: %s\n', ME.message);
            continue;
        end

        % Batch CWT path (default for wcoherence now)
        for r = 1:opts.Reps
            t0 = tic;
            exploreFNIRS.connectivity.computeMatrix(data, ...
                'Method', 'wcoherence', 'Accelerate', 'none');
            batch_times(ci, r) = toc(t0);
        end

        % Per-pair path: call coupling function individually
        for r = 1:opts.Reps
            t0 = tic;
            computePerPairWcoherence(data, nCh, fs);
            perpair_times(ci, r) = toc(t0);
        end

        bmed = median(batch_times(ci, :));
        pmed = median(perpair_times(ci, :));
        fprintf('batch=%7.3fs  per-pair=%7.3fs  speedup=%.1fx\n', bmed, pmed, pmed/bmed);
    end
    fprintf('\n');

    out.channelCounts = channelCounts;
    out.batch_times = batch_times;
    out.perpair_times = perpair_times;
    out.nSamples = nSamples;
    out.fs = fs;
end


function out = benchSection_DyadScaling(opts)
    fprintf('--- Section 3: Hyperscanning Dyad — Channel Count Scaling ---\n');

    nSamples = 2000;
    fs = 10;
    channelCounts = [4, 8, 12, 18];

    batch_times = NaN(length(channelCounts), opts.Reps);
    perpair_times = NaN(length(channelCounts), opts.Reps);

    for ci = 1:length(channelCounts)
        nCh = channelCounts(ci);
        dataA = generateTestProcessed(nSamples, nCh, fs);
        dataB = generateTestProcessed(nSamples, nCh, fs);
        fprintf('  nCh=%3d: ', nCh);

        % Warmup
        try
            exploreFNIRS.hyperscanning.computeDyad(dataA, dataB, ...
                'Method', 'wcoherence', 'ChannelPairing', 'same', 'Accelerate', 'none');
        catch ME
            fprintf('ERROR: %s\n', ME.message);
            continue;
        end

        % Batch (uses pre-computed CWT)
        for r = 1:opts.Reps
            t0 = tic;
            exploreFNIRS.hyperscanning.computeDyad(dataA, dataB, ...
                'Method', 'wcoherence', 'ChannelPairing', 'same', 'Accelerate', 'none');
            batch_times(ci, r) = toc(t0);
        end

        % Per-pair (bypass batch by calling coupling directly)
        for r = 1:opts.Reps
            t0 = tic;
            for c = 1:nCh
                exploreFNIRS.coupling.wcoherence(dataA.HbO(:,c), dataB.HbO(:,c), fs);
            end
            perpair_times(ci, r) = toc(t0);
        end

        bmed = median(batch_times(ci, :));
        pmed = median(perpair_times(ci, :));
        fprintf('batch=%7.3fs  per-pair=%7.3fs  speedup=%.1fx\n', bmed, pmed, pmed/bmed);
    end
    fprintf('\n');

    out.channelCounts = channelCounts;
    out.batch_times = batch_times;
    out.perpair_times = perpair_times;
    out.nSamples = nSamples;
    out.fs = fs;
end


%% =====================================================================
%  SUMMARY
%  =====================================================================

function printSummary(results)
    fprintf('========================================================\n');
    fprintf('  SUMMARY\n');
    fprintf('========================================================\n\n');

    co = results.cwtOverhead;
    fprintf('  CWT overhead:\n');
    fprintf('    Fresh wcoherence:       %.4f s\n', median(co.t_wcoh_fresh));
    fprintf('    Pre-computed wcoherence: %.4f s  (%.1fx speedup)\n', ...
        median(co.t_wcoh_precomp), median(co.t_wcoh_fresh)/median(co.t_wcoh_precomp));
    fprintf('\n');

    cs = results.channelScaling;
    fprintf('  Connectivity matrix scaling:\n');
    fprintf('  %5s  %10s  %12s  %8s\n', 'nCh', 'Batch(s)', 'PerPair(s)', 'Speedup');
    for ci = 1:length(cs.channelCounts)
        bmed = median(cs.batch_times(ci, :));
        pmed = median(cs.perpair_times(ci, :));
        if isnan(bmed) || isnan(pmed), continue; end
        fprintf('  %5d  %10.3f  %12.3f  %7.1fx\n', ...
            cs.channelCounts(ci), bmed, pmed, pmed/bmed);
    end
    fprintf('\n');
end


%% =====================================================================
%  PLOTTING
%  =====================================================================

function plotResults(results, opts)
    cs = results.channelScaling;

    fig = figure('Name', 'Wavelet Coherence Connectivity Benchmark', 'Visible', 'on');

    batch_med = zeros(length(cs.channelCounts), 1);
    perpair_med = zeros(length(cs.channelCounts), 1);
    for ci = 1:length(cs.channelCounts)
        batch_med(ci) = median(cs.batch_times(ci, :));
        perpair_med(ci) = median(cs.perpair_times(ci, :));
    end

    bar(cs.channelCounts, [batch_med, perpair_med]);
    legend({'Batch CWT', 'Per-pair'}, 'Location', 'northwest');
    xlabel('Number of channels');
    ylabel('Time (s)');
    title('Wavelet Coherence Connectivity Matrix');
    grid on;

    if ~isempty(opts.SavePath)
        [savedir, ~, ~] = fileparts(opts.SavePath);
        if ~isempty(savedir)
            saveas(fig, fullfile(savedir, 'connectivity_scaling.png'));
        end
    end
end


%% =====================================================================
%  HELPER FUNCTIONS
%  =====================================================================

function data = generateTestProcessed(nSamples, nCh, fs)
% Generate a synthetic processed fNIRS struct
    rng('shuffle');
    t = (0:nSamples-1)' / fs;

    HbO = 0.01 * randn(nSamples, nCh);
    HbR = -0.005 * randn(nSamples, nCh);

    % Add hemodynamic-like signals
    for ch = 1:nCh
        phase = 2*pi*rand;
        HbO(:, ch) = HbO(:, ch) + 0.02 * sin(2*pi*0.05*t + phase);
        HbR(:, ch) = HbR(:, ch) - 0.01 * sin(2*pi*0.05*t + phase + 0.3);
    end

    data.HbO = HbO;
    data.HbR = HbR;
    data.time = t;
    data.fs = fs;
    data.fchMask = ones(1, nCh);
end


function computePerPairWcoherence(data, nCh, fs)
% Simulate per-pair wcoherence without batch CWT (the old approach)
    channels = find(data.fchMask);
    nCh = length(channels);
    for i = 1:nCh
        for j = (i+1):nCh
            pf2_base.wavelet.wcoherence(data.HbO(:, channels(i)), ...
                data.HbO(:, channels(j)), fs);
        end
    end
end


function v = ternary(cond, a, b)
    if cond, v = a; else, v = b; end
end
