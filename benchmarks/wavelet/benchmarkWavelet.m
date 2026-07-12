function results = benchmarkWavelet(varargin)
% BENCHMARKWAVELET Comprehensive wavelet motion correction benchmarks
%
% Profiles all three wavelet-based motion correction functions in pf2
% and compares them against TDDR. Measures wall time across signal sizes,
% channel counts, and wavelet families. Identifies the hot path.
%
% Syntax:
%   results = benchmarkWavelet()
%   results = benchmarkWavelet('Reps', 3)
%   results = benchmarkWavelet('SavePath', 'benchmarks/wavelet/results.mat')
%   results = benchmarkWavelet('Quick', true)
%
% Inputs (name-value):
%   Reps     - Repetitions per measurement for stable timing (default: 3)
%   SavePath - Path to save results .mat file (default: '' = don't save)
%   Quick    - Skip the slow scaling tests (default: false)
%   Plot     - Generate figures (default: true)
%
% Outputs:
%   results - Struct with timing data for each benchmark section
%
% Example:
%   % Full benchmark
%   results = benchmarkWavelet('Reps', 5, 'SavePath', 'wavelet_bench.mat');
%
%   % Quick sanity check
%   results = benchmarkWavelet('Quick', true);
%
% See also: pf2_MotionCorrectWavelet, pf2_kbWF, waveClean, pf2_MotionCorrectTDDR

    p = inputParser;
    addParameter(p, 'Reps', 3, @isscalar);
    addParameter(p, 'SavePath', '', @ischar);
    addParameter(p, 'Quick', false, @islogical);
    addParameter(p, 'Plot', true, @islogical);
    parse(p, varargin{:});
    opts = p.Results;

    fprintf('\n');
    fprintf('========================================================\n');
    fprintf('  WAVELET MOTION CORRECTION BENCHMARK SUITE\n');
    fprintf('========================================================\n');
    fprintf('  Date:  %s\n', datestr(now));
    fprintf('  Reps:  %d\n', opts.Reps);
    fprintf('  Mode:  %s\n', ternary(opts.Quick, 'Quick', 'Full'));
    fprintf('========================================================\n\n');

    % Initialize WaveLab once (don't count setup time)
    fprintf('Initializing WaveLab... ');
    global WAVELABPATH
    if isempty(WAVELABPATH)
        pf2_base.toolboxes.setup_wavelab();
    end
    fprintf('done.\n\n');

    % Generate test data
    rng(42);  % Reproducible

    results = struct();
    results.timestamp = datetime('now');
    results.reps = opts.Reps;
    results.matlabVersion = version;
    results.platform = computer;

    % ================================================================
    %  SECTION 1: Method comparison (fixed data size)
    % ================================================================
    results.methodComparison = benchSection_MethodComparison(opts);

    % ================================================================
    %  SECTION 2: Signal length scaling
    % ================================================================
    if ~opts.Quick
        results.signalScaling = benchSection_SignalScaling(opts);
    end

    % ================================================================
    %  SECTION 3: Channel count scaling
    % ================================================================
    if ~opts.Quick
        results.channelScaling = benchSection_ChannelScaling(opts);
    end

    % ================================================================
    %  SECTION 4: Wavelet family comparison
    % ================================================================
    results.waveletFamilies = benchSection_WaveletFamilies(opts);

    % ================================================================
    %  SECTION 5: Inner-loop profiling for MotionCorrectWavelet
    % ================================================================
    results.innerProfile = benchSection_InnerProfile(opts);

    % ================================================================
    %  SECTION 6: Parfor scaling (if available)
    % ================================================================
    [canPar, ~] = pf2_base.accel.canParfor();
    if canPar
        results.parforScaling = benchSection_ParforScaling(opts);
    else
        fprintf('[SKIP] Parallel Computing Toolbox not available.\n\n');
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

    % Save
    if ~isempty(opts.SavePath)
        save(opts.SavePath, 'results');
        fprintf('Results saved to: %s\n', opts.SavePath);
    end
end


%% =====================================================================
%  BENCHMARK SECTIONS
%  =====================================================================

function out = benchSection_MethodComparison(opts)
    fprintf('--- Section 1: Method Comparison (18ch, ~6000 samples) ---\n');

    % Realistic fNIRS data: 18 channels, ~60s at 100 Hz
    nSamples = 6000;
    nCh = 18;
    od = generateTestOD(nSamples, nCh);

    methods = {
        'pf2_MotionCorrectWavelet',  @() pf2_MotionCorrectWavelet(od, 1.5, 1, 'db2', 'none');
        'pf2_kbWF',                  @() pf2_kbWF(od, 3.3, 3, 'db6', 'none');
        'waveClean',                 @() waveClean(od, 5, 0.1, 0, false, 'db10', 'none');
        'pf2_MotionCorrectTDDR',     @() pf2_MotionCorrectTDDR(od, 1);
    };

    nMethods = size(methods, 1);
    times = zeros(nMethods, opts.Reps);

    for m = 1:nMethods
        name = methods{m, 1};
        fn = methods{m, 2};
        fprintf('  %-35s ', name);

        % Warmup
        try
            fn();
        catch ME
            fprintf('ERROR: %s\n', ME.message);
            times(m, :) = NaN;
            continue;
        end

        for r = 1:opts.Reps
            t0 = tic;
            fn();
            times(m, r) = toc(t0);
        end
        med = median(times(m, :));
        fprintf('%8.3f s  (per-ch: %6.1f ms)\n', med, med / nCh * 1000);
    end
    fprintf('\n');

    out.methods = methods(:, 1);
    out.times = times;
    out.nSamples = nSamples;
    out.nChannels = nCh;
end


function out = benchSection_SignalScaling(opts)
    fprintf('--- Section 2: Signal Length Scaling ---\n');

    nCh = 4;  % Keep channels small to isolate signal-length effect
    lengths = [500, 1000, 2000, 4000, 8000, 16000, 32000];

    methodNames = {'MotionCorrectWavelet', 'kbWF', 'waveClean', 'TDDR'};
    times = NaN(length(lengths), length(methodNames), opts.Reps);

    for li = 1:length(lengths)
        nS = lengths(li);
        od = generateTestOD(nS, nCh);
        fprintf('  nSamples=%6d: ', nS);

        fnList = {
            @() pf2_MotionCorrectWavelet(od, 1.5, 1, 'db2', 'none'),
            @() pf2_kbWF(od, 3.3, 3, 'db6', 'none'),
            @() waveClean(od, min(5, floor(log2(nS))-1), 0.1, 0, false, 'db10', 'none'),
            @() pf2_MotionCorrectTDDR(od, 1)
        };

        for m = 1:length(fnList)
            try
                fnList{m}();  % warmup
                for r = 1:opts.Reps
                    t0 = tic;
                    fnList{m}();
                    times(li, m, r) = toc(t0);
                end
                fprintf('%7.3f  ', median(times(li, m, :)));
            catch
                fprintf('  err   ');
            end
        end
        fprintf('\n');
    end
    fprintf('\n');

    out.lengths = lengths;
    out.methodNames = methodNames;
    out.times = times;
    out.nChannels = nCh;
end


function out = benchSection_ChannelScaling(opts)
    fprintf('--- Section 3: Channel Count Scaling ---\n');

    nSamples = 4000;
    channelCounts = [4, 8, 16, 32, 54, 108];

    methodNames = {'MotionCorrectWavelet', 'kbWF', 'TDDR'};
    times = NaN(length(channelCounts), length(methodNames), opts.Reps);

    for ci = 1:length(channelCounts)
        nCh = channelCounts(ci);
        od = generateTestOD(nSamples, nCh);
        fprintf('  nChannels=%4d: ', nCh);

        fnList = {
            @() pf2_MotionCorrectWavelet(od, 1.5, 1, 'db2', 'none'),
            @() pf2_kbWF(od, 3.3, 3, 'db6', 'none'),
            @() pf2_MotionCorrectTDDR(od, 1)
        };

        for m = 1:length(fnList)
            try
                fnList{m}();
                for r = 1:opts.Reps
                    t0 = tic;
                    fnList{m}();
                    times(ci, m, r) = toc(t0);
                end
                fprintf('%7.3f  ', median(times(ci, m, :)));
            catch
                fprintf('  err   ');
            end
        end
        fprintf('\n');
    end
    fprintf('\n');

    out.channelCounts = channelCounts;
    out.methodNames = methodNames;
    out.times = times;
    out.nSamples = nSamples;
end


function out = benchSection_WaveletFamilies(opts)
    fprintf('--- Section 4: Wavelet Family Comparison ---\n');

    nSamples = 4000;
    nCh = 8;
    od = generateTestOD(nSamples, nCh);

    families = {'haar', 'db2', 'db4', 'db6', 'db8', 'db10', 'sym4', 'sym8', 'coif2', 'coif4'};
    times = NaN(length(families), opts.Reps);

    for fi = 1:length(families)
        wv = families{fi};
        fprintf('  %-12s ', wv);

        try
            pf2_MotionCorrectWavelet(od, 1.5, 1, wv, 'none');  % warmup
            for r = 1:opts.Reps
                t0 = tic;
                pf2_MotionCorrectWavelet(od, 1.5, 1, wv, 'none');
                times(fi, r) = toc(t0);
            end
            fprintf('%8.3f s\n', median(times(fi, :)));
        catch ME
            fprintf('ERROR: %s\n', ME.message);
        end
    end
    fprintf('\n');

    out.families = families;
    out.times = times;
    out.nSamples = nSamples;
    out.nChannels = nCh;
end


function out = benchSection_InnerProfile(opts)
    fprintf('--- Section 5: Inner-Loop Profiling (MotionCorrectWavelet) ---\n');
    fprintf('  Profiling a single channel to find the hot path...\n');

    nSamples = 6000;
    signal = generateTestOD(nSamples, 1);
    signal(isinf(signal)) = nan;

    [qmf, wavename, ~] = pf2_base.wavelet.resolveWavelet('db2');

    N = ceil(log2(nSamples));
    L = 4;
    D = N - L;

    % Prepare padded signal
    DataPadded = zeros(2^N, 1);
    DataPadded(1:nSamples) = signal;
    DCVal = mean(DataPadded);
    DataPadded = DataPadded - DCVal;

    % Profile NormalizationNoise
    nReps = max(opts.Reps, 5);
    t_norm = zeros(1, nReps);
    for r = 1:nReps
        t0 = tic;
        [yn, NormCoef] = NormalizationNoise_bench(DataPadded', qmf);
        t_norm(r) = toc(t0);
    end

    % Profile WT_inv (forward shift-invariant DWT)
    t_wt = zeros(1, nReps);
    for r = 1:nReps
        t0 = tic;
        StatWT = WT_inv_bench(yn, L, N, wavename);
        t_wt(r) = toc(t0);
    end

    % Profile WaveletAnalysis (thresholding + inverse)
    t_wa = zeros(1, nReps);
    for r = 1:nReps
        StatWT_copy = WT_inv_bench(yn, L, N, wavename);
        t0 = tic;
        [~, ~] = WaveletAnalysis_bench(StatWT_copy, L, wavename, 1.5, nSamples);
        t_wa(r) = toc(t0);
    end

    % Count dwt/idwt calls
    nDwtCalls = 0;
    nIdwtCalls = 0;
    for d = 0:(D-1)
        nDwtCalls = nDwtCalls + 2 * (2^d);  % 2 per block (signal + shifted)
    end
    for d = (D-1):-1:0
        nIdwtCalls = nIdwtCalls + 2 * (2^d);
    end

    med_norm = median(t_norm);
    med_wt = median(t_wt);
    med_wa = median(t_wa);
    total = med_norm + med_wt + med_wa;

    fprintf('  Signal length: %d (padded to 2^%d = %d)\n', nSamples, N, 2^N);
    fprintf('  Levels: %d (L=%d, N=%d)\n', D, L, N);
    fprintf('  dwt calls (WT_inv):   %d\n', nDwtCalls);
    fprintf('  idwt calls (IWT_inv): %d\n', nIdwtCalls);
    fprintf('  Total dwt+idwt calls: %d\n', nDwtCalls + nIdwtCalls);
    fprintf('\n');
    fprintf('  Per-channel breakdown:\n');
    fprintf('    NormalizationNoise: %8.4f s  (%5.1f%%)\n', med_norm, med_norm/total*100);
    fprintf('    WT_inv (fwd DWT):   %8.4f s  (%5.1f%%)\n', med_wt, med_wt/total*100);
    fprintf('    WaveletAnalysis:    %8.4f s  (%5.1f%%)\n', med_wa, med_wa/total*100);
    fprintf('    TOTAL per channel:  %8.4f s\n', total);
    fprintf('    Estimated 18 ch:    %8.4f s\n', total * 18);
    fprintf('\n');

    out.nSamples = nSamples;
    out.paddedLength = 2^N;
    out.nLevels = D;
    out.nDwtCalls = nDwtCalls;
    out.nIdwtCalls = nIdwtCalls;
    out.t_normalization = t_norm;
    out.t_WT_inv = t_wt;
    out.t_WaveletAnalysis = t_wa;
end


function out = benchSection_ParforScaling(opts)
    fprintf('--- Section 6: Parfor Scaling ---\n');

    nSamples = 6000;
    channelCounts = [8, 18, 36, 54];

    serial_times = NaN(length(channelCounts), opts.Reps);
    parfor_times = NaN(length(channelCounts), opts.Reps);

    % Ensure pool is started
    pool = gcp('nocreate');
    if isempty(pool)
        fprintf('  Starting parallel pool... ');
        pool = parpool('local');
        fprintf('(%d workers)\n', pool.NumWorkers);
    else
        fprintf('  Using existing pool (%d workers)\n', pool.NumWorkers);
    end

    for ci = 1:length(channelCounts)
        nCh = channelCounts(ci);
        od = generateTestOD(nSamples, nCh);
        fprintf('  nCh=%3d: ', nCh);

        % Serial
        pf2_MotionCorrectWavelet(od, 1.5, 1, 'db2', 'none');
        for r = 1:opts.Reps
            t0 = tic;
            pf2_MotionCorrectWavelet(od, 1.5, 1, 'db2', 'none');
            serial_times(ci, r) = toc(t0);
        end

        % Parfor
        pf2_MotionCorrectWavelet(od, 1.5, 1, 'db2', 'parfor');
        for r = 1:opts.Reps
            t0 = tic;
            pf2_MotionCorrectWavelet(od, 1.5, 1, 'db2', 'parfor');
            parfor_times(ci, r) = toc(t0);
        end

        smed = median(serial_times(ci, :));
        pmed = median(parfor_times(ci, :));
        fprintf('serial=%6.3fs  parfor=%6.3fs  speedup=%.1fx\n', smed, pmed, smed/pmed);
    end
    fprintf('\n');

    out.channelCounts = channelCounts;
    out.serial_times = serial_times;
    out.parfor_times = parfor_times;
    out.nSamples = nSamples;
    out.nWorkers = pool.NumWorkers;
end


%% =====================================================================
%  SUMMARY
%  =====================================================================

function printSummary(results)
    fprintf('========================================================\n');
    fprintf('  SUMMARY\n');
    fprintf('========================================================\n\n');

    mc = results.methodComparison;
    fprintf('  Method comparison (%d samples, %d channels):\n', mc.nSamples, mc.nChannels);
    fprintf('  %-35s  %10s  %12s  %8s\n', 'Method', 'Median(s)', 'Per-ch(ms)', 'vs TDDR');

    tddr_time = median(mc.times(end, :));
    for m = 1:length(mc.methods)
        med = median(mc.times(m, :));
        if isnan(med), continue; end
        ratio = med / tddr_time;
        fprintf('  %-35s  %10.3f  %12.1f  %7.1fx\n', ...
            mc.methods{m}, med, med / mc.nChannels * 1000, ratio);
    end
    fprintf('\n');

    ip = results.innerProfile;
    fprintf('  Hot path (MotionCorrectWavelet, single channel):\n');
    fprintf('    %d dwt + %d idwt = %d total wavelet transforms\n', ...
        ip.nDwtCalls, ip.nIdwtCalls, ip.nDwtCalls + ip.nIdwtCalls);
    med_wt = median(ip.t_WT_inv);
    med_wa = median(ip.t_WaveletAnalysis);
    fprintf('    WT_inv (fwd):  %.4f s  ← shift-invariant DWT (exponential block loop)\n', med_wt);
    fprintf('    WaveletAnalysis (thresh+inv): %.4f s\n', med_wa);
    total = median(ip.t_normalization) + med_wt + med_wa;
    fprintf('    Per-channel total: %.4f s\n', total);
    fprintf('    Extrapolated 18ch: %.3f s\n', total * 18);
    fprintf('\n');

    fprintf('  Optimization opportunities:\n');
    fprintf('    1. Replace shift-invariant DWT loop with MATLAB wavedec/waverec\n');
    fprintf('       (single call replaces ~%d nested dwt calls)\n', ip.nDwtCalls);
    fprintf('    2. Vectorize IQR thresholding across levels\n');
    fprintf('    3. Consider stationary wavelet transform (swt/iswt) for shift-invariance\n');
    fprintf('    4. GPU acceleration for large channel counts (gpuArray + dwt)\n');
    fprintf('    5. Pre-allocate and reuse padded buffer across channels\n');
    fprintf('\n');
end


%% =====================================================================
%  PLOTTING
%  =====================================================================

function plotResults(results, opts)

    % --- Figure 1: Method comparison bar chart ---
    mc = results.methodComparison;
    fig1 = figure('Name', 'Wavelet Benchmark: Method Comparison', 'Visible', 'on');
    medians = zeros(length(mc.methods), 1);
    for m = 1:length(mc.methods)
        medians(m) = median(mc.times(m, :));
    end
    bar(medians);
    set(gca, 'XTickLabel', mc.methods, 'XTickLabelRotation', 30);
    ylabel('Time (s)');
    title(sprintf('Motion Correction Methods (%d samples, %d ch)', mc.nSamples, mc.nChannels));
    grid on;

    % --- Figure 2: Inner profile pie chart ---
    ip = results.innerProfile;
    fig2 = figure('Name', 'Wavelet Benchmark: Per-Channel Profile', 'Visible', 'on');
    vals = [median(ip.t_normalization), median(ip.t_WT_inv), median(ip.t_WaveletAnalysis)];
    labels = {'NormalizationNoise', 'WT\_inv (fwd DWT)', 'WaveletAnalysis (thresh+inv)'};
    pie(vals, labels);
    title('Per-Channel Time Breakdown (pf2\_MotionCorrectWavelet)');

    % --- Figure 3: Signal scaling (if available) ---
    if isfield(results, 'signalScaling')
        ss = results.signalScaling;
        fig3 = figure('Name', 'Wavelet Benchmark: Signal Length Scaling', 'Visible', 'on');
        hold on;
        colors = lines(size(ss.times, 2));
        for m = 1:size(ss.times, 2)
            med = squeeze(median(ss.times(:, m, :), 3));
            plot(ss.lengths, med, '-o', 'LineWidth', 1.5, 'Color', colors(m,:));
        end
        hold off;
        xlabel('Signal Length (samples)');
        ylabel('Time (s)');
        legend(ss.methodNames, 'Location', 'northwest');
        title(sprintf('Scaling with Signal Length (%d ch)', ss.nChannels));
        set(gca, 'XScale', 'log', 'YScale', 'log');
        grid on;
    end

    % --- Figure 4: Wavelet family comparison ---
    wf = results.waveletFamilies;
    fig4 = figure('Name', 'Wavelet Benchmark: Wavelet Families', 'Visible', 'on');
    medians_wf = zeros(length(wf.families), 1);
    for fi = 1:length(wf.families)
        medians_wf(fi) = median(wf.times(fi, :));
    end
    bar(medians_wf);
    set(gca, 'XTickLabel', wf.families, 'XTickLabelRotation', 30);
    ylabel('Time (s)');
    title('pf2\_MotionCorrectWavelet by Wavelet Family');
    grid on;

    % Save if requested
    if ~isempty(opts.SavePath)
        [savedir, ~, ~] = fileparts(opts.SavePath);
        if ~isempty(savedir)
            saveas(fig1, fullfile(savedir, 'method_comparison.png'));
            saveas(fig2, fullfile(savedir, 'inner_profile.png'));
            if isfield(results, 'signalScaling')
                saveas(fig3, fullfile(savedir, 'signal_scaling.png'));
            end
            saveas(fig4, fullfile(savedir, 'wavelet_families.png'));
        end
    end
end


%% =====================================================================
%  HELPER FUNCTIONS
%  =====================================================================

function od = generateTestOD(nSamples, nCh)
% Generate synthetic optical density data with realistic noise + artifacts
    fs = 100;
    t = (0:nSamples-1)' / fs;

    % Baseline + slow drift
    od = 0.3 + 0.01 * randn(nSamples, nCh);

    % Add cardiac component (~1 Hz)
    for ch = 1:nCh
        phase = 2 * pi * rand;
        od(:, ch) = od(:, ch) + 0.005 * sin(2*pi*1.0*t + phase);
    end

    % Add motion artifacts (spikes) on random channels
    nArtifacts = max(2, round(nSamples / 2000));
    for a = 1:nArtifacts
        ch = randi(nCh);
        idx = randi(nSamples);
        width = randi([5, 30]);
        amp = 0.05 + 0.1 * rand;
        idxRange = max(1, idx-width):min(nSamples, idx+width);
        od(idxRange, ch) = od(idxRange, ch) + amp * exp(-((idxRange - idx).^2) / (2*(width/3)^2))';
    end
end


function v = ternary(cond, a, b)
    if cond, v = a; else, v = b; end
end


%% =====================================================================
%  LOCAL COPIES OF INNER FUNCTIONS (for isolated profiling)
%  These mirror the functions inside pf2_MotionCorrectWavelet exactly.
%  =====================================================================

function [y_norm, coeff] = NormalizationNoise_bench(y, qmf)
    c = cconv(y, qmf, length(y));
    y_downsampled = dyaddown(c);
    medianAbsDev = mad(y_downsampled);
    if medianAbsDev ~= 0
        y_norm = (1/1.4826) .* y ./ medianAbsDev;
        coeff = 1 / (1.4826 * medianAbsDev);
    else
        y_norm = y;
        coeff = 1;
    end
end

function wp = WT_inv_bench(x, L, N, wavename)
    D = N - L;
    n = length(x);
    wp = zeros(n, D+1);
    dwtmode('per', 'nodisp');
    wp(:,1) = x';
    for d = 0:(D-1)
        n_blocks = 2^d;
        l_blocks = n / n_blocks;
        for b = 0:(2^d - 1)
            s = wp(b*l_blocks+1:b*l_blocks+l_blocks, 1)';
            s_shift = [s(end) s(1:end-1)];
            [cA, cD] = dwt(s, wavename);
            [cA_shift, cD_shift] = dwt(s_shift, wavename);
            wp(b*l_blocks+1:b*l_blocks+l_blocks/2, 1) = cA;
            wp(b*l_blocks+l_blocks/2+1:b*l_blocks+l_blocks, 1) = cA_shift;
            wp(b*l_blocks+1:b*l_blocks+l_blocks/2, d+2) = cD;
            wp(b*l_blocks+l_blocks/2+1:b*l_blocks+l_blocks, d+2) = cD_shift;
        end
    end
end

function [ARSignal, StatWT] = WaveletAnalysis_bench(StatWT, L, wavename, iqr_mult, SignalLength)
    n = size(StatWT, 1);
    N = log2(size(StatWT, 1));
    SignalLength_tmp = SignalLength;
    for j = 1:N-L-1
        SignalLength_tmp = fix(SignalLength_tmp / 2);
        n_blocks = 2^j;
        l_blocks = n / n_blocks;
        for b = 0:(2^j - 1)
            sr = StatWT(b*l_blocks+1:b*l_blocks+l_blocks, j+1);
            sr_temp = sr(1:SignalLength_tmp);
            quants = quantile(sr_temp, [.25 .50 .75]);
            IQR = quants(3) - quants(1);
            prob1 = quants(3) + IQR * iqr_mult;
            prob2 = quants(1) - IQR * iqr_mult;
            outliers_1 = find(sr > prob1);
            outliers_2 = find(sr < prob2);
            outliers = [outliers_1' outliers_2'];
            sr(outliers) = 0;
            StatWT(b*l_blocks+1:b*l_blocks+l_blocks, j+1) = sr;
        end
    end
    ARSignal = IWT_inv_bench(StatWT, wavename);
end

function x = IWT_inv_bench(StatWT, wavename)
    [n, D] = size(StatWT);
    D = D - 1;
    wp = StatWT;
    dwtmode('per', 'nodisp');
    approx = wp(:,1)';
    for d = D-1:-1:0
        n_blocks = 2^d;
        l_blocks = n / n_blocks;
        for b = 0:(2^d - 1)
            cD = wp(b*l_blocks+1:b*l_blocks+l_blocks/2, d+2)';
            cD_shift = wp(b*l_blocks+l_blocks/2+1:b*l_blocks+l_blocks, d+2)';
            cA = approx(b*l_blocks+1:b*l_blocks+l_blocks/2);
            cA_shift = approx(b*l_blocks+l_blocks/2+1:b*l_blocks+l_blocks);
            s1 = idwt(cA, cD, wavename);
            s_shift = idwt(cA_shift, cD_shift, wavename);
            s2 = [s_shift(2:end) s_shift(1)];
            approx(b*l_blocks+1:b*l_blocks+l_blocks) = (s1 + s2) / 2;
        end
    end
    x = approx;
end
