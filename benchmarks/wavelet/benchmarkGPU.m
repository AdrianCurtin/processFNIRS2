function results = benchmarkGPU(varargin)
% BENCHMARKGPU Benchmark GPU-accelerated wavelet processing paths
%
% Tests whether GPU acceleration (via gpuArray) can speed up the wavelet
% motion correction pipeline. Benchmarks individual operations (filter,
% conv, dwt) on CPU vs GPU, and tests full-pipeline GPU strategies.
%
% GPU acceleration opportunities in wavelet processing:
%   1. Batch all channels as a matrix operation (GPU excels at wide GEMM)
%   2. Replace scalar dwt/idwt loop with matrix convolution on GPU
%   3. Use cwtft (continuous WT on GPU) as alternative approach
%   4. Vectorize IQR thresholding across all channels simultaneously
%
% Syntax:
%   results = benchmarkGPU()
%   results = benchmarkGPU('Reps', 5)
%   results = benchmarkGPU('Channels', 54)
%
% Inputs (name-value):
%   Reps     - Repetitions per measurement (default: 5)
%   Samples  - Signal length (default: 6000)
%   Channels - Number of channels (default: 18)
%
% Outputs:
%   results - Struct with GPU vs CPU timing comparisons
%
% See also: benchmarkWavelet, benchmarkAlternatives, pf2_base.accel.isGPUAvailable

    p = inputParser;
    addParameter(p, 'Reps', 5, @isscalar);
    addParameter(p, 'Samples', 6000, @isscalar);
    addParameter(p, 'Channels', 18, @isscalar);
    parse(p, varargin{:});
    opts = p.Results;

    fprintf('\n');
    fprintf('========================================================\n');
    fprintf('  GPU WAVELET BENCHMARK\n');
    fprintf('========================================================\n');
    fprintf('  Signal: %d samples x %d channels\n', opts.Samples, opts.Channels);
    fprintf('  Reps:   %d\n', opts.Reps);
    fprintf('========================================================\n\n');

    % Check GPU availability
    gpuInfo = pf2_base.accel.isGPUAvailable();
    if ~gpuInfo.available
        fprintf('  NO GPU AVAILABLE.\n');
        fprintf('  This benchmark requires a GPU (Metal on Apple Silicon or CUDA).\n');
        fprintf('  GPU info: backend=%s, device=%s\n', gpuInfo.backend, gpuInfo.deviceName);
        fprintf('\n  Skipping GPU benchmarks. Running CPU-only baseline.\n\n');
        results = benchCPUOnly(opts);
        return;
    end

    fprintf('  GPU: %s (%s backend, %.0f MB)\n', ...
        gpuInfo.deviceName, gpuInfo.backend, gpuInfo.totalMemory / 1e6);
    fprintf('\n');

    % Setup
    global WAVELABPATH
    if isempty(WAVELABPATH)
        pf2_base.toolboxes.setup_wavelab();
    end

    rng(42);
    nS = opts.Samples;
    nCh = opts.Channels;
    od = generateOD(nS, nCh);

    results = struct();
    results.gpuInfo = gpuInfo;
    results.nSamples = nS;
    results.nChannels = nCh;

    % ================================================================
    %  Test 1: Basic operations — CPU vs GPU transfer overhead
    % ================================================================
    fprintf('--- Test 1: Transfer Overhead & Basic Operations ---\n');

    % Transfer cost
    t_toGPU = runTimed(opts.Reps, @() gpuArray(od));
    t_fromGPU = runTimed(opts.Reps, @() gather(gpuArray(od)));
    fprintf('  gpuArray transfer (%dx%d):  %.4f s\n', nS, nCh, median(t_toGPU));
    fprintf('  gather back:               %.4f s\n', median(t_fromGPU));

    % Matrix multiply (GPU sweet spot)
    t_cpu_mm = runTimed(opts.Reps, @() od' * od);
    odGPU = gpuArray(od);
    t_gpu_mm = runTimed(opts.Reps, @() gather(odGPU' * odGPU));
    fprintf('  Matrix multiply (C''*C):\n');
    fprintf('    CPU: %.4f s   GPU: %.4f s   speedup: %.1fx\n', ...
        median(t_cpu_mm), median(t_gpu_mm), median(t_cpu_mm)/median(t_gpu_mm));

    % 1D convolution (core of FWT_PO)
    filter_len = 8;  % db4 filter length
    filt = randn(1, filter_len);
    x = od(:, 1)';
    xGPU = gpuArray(x);
    filtGPU = gpuArray(filt);
    t_cpu_conv = runTimed(opts.Reps * 10, @() filter(filt, 1, x));
    t_gpu_conv = runTimed(opts.Reps * 10, @() gather(filter(filtGPU, 1, xGPU)));
    fprintf('  1D filter (%d samples):\n', nS);
    fprintf('    CPU: %.6f s   GPU: %.6f s   speedup: %.1fx\n', ...
        median(t_cpu_conv), median(t_gpu_conv), median(t_cpu_conv)/median(t_gpu_conv));
    fprintf('\n');

    results.transfer_toGPU = t_toGPU;
    results.transfer_fromGPU = t_fromGPU;
    results.matmul_cpu = t_cpu_mm;
    results.matmul_gpu = t_gpu_mm;
    results.conv1d_cpu = t_cpu_conv;
    results.conv1d_gpu = t_gpu_conv;

    % ================================================================
    %  Test 2: Batch-vectorized wavelet (all channels at once on GPU)
    % ================================================================
    fprintf('--- Test 2: Batch Wavelet (all channels simultaneously) ---\n');
    fprintf('  Strategy: vectorize FWT_PO across channels via matrix ops\n');

    [qmf, ~, ~] = pf2_base.wavelet.resolveWavelet('db2');
    N = ceil(log2(nS));
    L = 4;

    % CPU: WaveLab FWT_PO per channel (baseline)
    DataPadded = zeros(2^N, nCh);
    DataPadded(1:nS, :) = od;
    t_cpu_fwt = runTimed(opts.Reps, @() fwtAllChannelsCPU(DataPadded, L, qmf));
    fprintf('  FWT_PO per channel (serial CPU):   %.4f s\n', median(t_cpu_fwt));

    % GPU: batch convolution approach
    DataPaddedGPU = gpuArray(DataPadded);
    qmfGPU = gpuArray(qmf);
    t_gpu_fwt = runTimed(opts.Reps, @() gather(fwtBatchGPU(DataPaddedGPU, L, qmfGPU)));
    fprintf('  FWT batch (GPU matrix conv):       %.4f s  (%.1fx)\n', ...
        median(t_gpu_fwt), median(t_cpu_fwt)/median(t_gpu_fwt));

    % Verify correctness
    cpu_result = fwtAllChannelsCPU(DataPadded, L, qmf);
    gpu_result = gather(fwtBatchGPU(DataPaddedGPU, L, qmfGPU));
    maxDiff = max(abs(cpu_result(:) - gpu_result(:)));
    fprintf('  Max abs diff (CPU vs GPU): %.2e\n', maxDiff);
    fprintf('\n');

    results.fwt_cpu = t_cpu_fwt;
    results.fwt_gpu = t_gpu_fwt;
    results.fwt_maxDiff = maxDiff;

    % ================================================================
    %  Test 3: IQR thresholding vectorized across channels
    % ================================================================
    fprintf('--- Test 3: Vectorized IQR Thresholding ---\n');

    % Generate wavelet coefficients to threshold
    wc_all = randn(2^N, nCh);
    iqr_mult = 1.5;

    t_cpu_iqr = runTimed(opts.Reps, @() iqrThresholdSerial(wc_all, iqr_mult));
    wcGPU = gpuArray(wc_all);
    t_gpu_iqr = runTimed(opts.Reps, @() gather(iqrThresholdBatch(wcGPU, iqr_mult)));
    fprintf('  IQR threshold (serial CPU):     %.4f s\n', median(t_cpu_iqr));
    fprintf('  IQR threshold (GPU vectorized): %.4f s  (%.1fx)\n', ...
        median(t_gpu_iqr), median(t_cpu_iqr)/median(t_gpu_iqr));
    fprintf('\n');

    results.iqr_cpu = t_cpu_iqr;
    results.iqr_gpu = t_gpu_iqr;

    % ================================================================
    %  Test 4: Full pipeline comparison
    % ================================================================
    fprintf('--- Test 4: Full Pipeline (all channels, end to end) ---\n');

    % A) Current implementation (serial, per-channel)
    t_current = runTimed(opts.Reps, @() pf2_MotionCorrectWavelet(od, 1.5, 1, 'db2', 'none'));
    fprintf('  A) Current (serial per-channel):    %.3f s\n', median(t_current));

    % B) kbWF with WaveLab (serial)
    t_kbwf = runTimed(opts.Reps, @() pf2_kbWF(od, 3.3, 3, 'db6', 'none'));
    fprintf('  B) kbWF (WaveLab serial):           %.3f s  (%.1fx vs A)\n', ...
        median(t_kbwf), median(t_current)/median(t_kbwf));

    % C) TDDR (reference)
    t_tddr = runTimed(opts.Reps, @() pf2_MotionCorrectTDDR(od, 1));
    fprintf('  C) TDDR (reference):                %.3f s  (%.1fx vs A)\n', ...
        median(t_tddr), median(t_current)/median(t_tddr));

    % D) Batch GPU pipeline prototype
    t_batch_gpu = runTimed(opts.Reps, @() batchGPUPipeline(od, qmf, L, N, iqr_mult));
    fprintf('  D) Batch GPU prototype:             %.3f s  (%.1fx vs A)\n', ...
        median(t_batch_gpu), median(t_current)/median(t_batch_gpu));

    fprintf('\n');

    results.pipeline_current = t_current;
    results.pipeline_kbwf = t_kbwf;
    results.pipeline_tddr = t_tddr;
    results.pipeline_batchGPU = t_batch_gpu;

    % ================================================================
    %  Test 5: GPU scaling with channel count
    % ================================================================
    fprintf('--- Test 5: GPU Scaling with Channel Count ---\n');

    channelCounts = [8, 18, 36, 54, 108];
    gpu_scale_times = NaN(length(channelCounts), 2);  % [cpu, gpu]

    for ci = 1:length(channelCounts)
        nc = channelCounts(ci);
        testOD = generateOD(nS, nc);
        testQmf = qmf;

        t_cpu = runTimed(max(2, opts.Reps), @() pf2_kbWF(testOD, 3.3, 3, 'db6', 'none'));
        t_gpu = runTimed(max(2, opts.Reps), @() batchGPUPipeline(testOD, testQmf, L, N, iqr_mult));

        gpu_scale_times(ci, :) = [median(t_cpu), median(t_gpu)];
        fprintf('  %3d ch: CPU=%.3fs  GPU=%.3fs  speedup=%.1fx\n', ...
            nc, median(t_cpu), median(t_gpu), median(t_cpu)/median(t_gpu));
    end
    fprintf('\n');

    results.gpuScaling.channelCounts = channelCounts;
    results.gpuScaling.times = gpu_scale_times;

    % ================================================================
    %  Summary
    % ================================================================
    fprintf('========================================================\n');
    fprintf('  GPU BENCHMARK SUMMARY\n');
    fprintf('========================================================\n');
    fprintf('  GPU: %s (%s)\n', gpuInfo.deviceName, gpuInfo.backend);
    fprintf('  Transfer overhead: %.1f ms (%.0f MB/s)\n', ...
        median(t_toGPU)*1000, numel(od)*8/median(t_toGPU)/1e6);
    fprintf('\n');
    fprintf('  GPU is beneficial when:\n');
    fprintf('    - Processing >8 channels simultaneously\n');
    fprintf('    - Operations are vectorized (batch FWT, batch threshold)\n');
    fprintf('    - Data stays on GPU between steps (no round-trip)\n');
    fprintf('\n');
    fprintf('  GPU is NOT beneficial when:\n');
    fprintf('    - Per-channel scalar loops (current WT_inv approach)\n');
    fprintf('    - Small signals (<1000 samples) — transfer dominates\n');
    fprintf('    - Operations that can''t be vectorized (iterative kurtosis)\n');
    fprintf('\n');
end


%% =====================================================================
%  GPU PIPELINE IMPLEMENTATIONS
%  =====================================================================

function wc_all = fwtAllChannelsCPU(X, L, qmf)
% Apply FWT_PO to each column of X
    [n, nCh] = size(X);
    wc_all = zeros(n, nCh);
    for ch = 1:nCh
        wc_all(:, ch) = FWT_PO(X(:, ch), L, qmf)';
    end
end


function wc_all = fwtBatchGPU(X, L, qmf)
% Batch FWT using matrix convolution on GPU
% Replaces per-channel FWT_PO with vectorized filter operations
    [n, nCh] = size(X);
    [~, J] = log2(n);  % J = log2(n)
    J = round(log2(n));

    wc_all = zeros(n, nCh, 'like', X);
    beta = X;  % all channels as columns

    qmf_row = reshape(qmf, 1, []);
    hqmf = fliplr(qmf_row) .* (-1).^(0:length(qmf_row)-1);  % mirror filter

    for j = J-1:-1:L
        len = 2^(j+1);
        beta_j = beta(1:len, :);

        % Periodic convolution + downsample for all channels at once
        pLen = length(qmf_row);
        padded = [beta_j(end-pLen+1:end, :); beta_j];

        % Lo-pass: convolve with qmf (time-reversed)
        lo = zeros(len, nCh, 'like', X);
        for k = 1:len
            lo(k, :) = sum(padded(k:k+pLen-1, :) .* fliplr(qmf_row)', 1);
        end
        lo = lo(1:2:end, :);  % downsample

        % Hi-pass: convolve with mirror filter
        beta_shifted = [beta_j(2:end, :); beta_j(1, :)];
        padded_hi = [beta_shifted(end-pLen+1:end, :); beta_shifted];
        hi = zeros(len, nCh, 'like', X);
        for k = 1:len
            hi(k, :) = sum(padded_hi(k:k+pLen-1, :) .* qmf_row', 1);
        end
        hi = hi(1:2:end, :);  % downsample

        wc_all(2^j+1:2^(j+1), :) = hi;
        beta(1:2^j, :) = lo;
    end
    wc_all(1:2^L, :) = beta(1:2^L, :);
end


function out = iqrThresholdSerial(wc, iqr_mult)
% Per-channel IQR thresholding (current approach)
    out = wc;
    for ch = 1:size(wc, 2)
        coeffs = wc(:, ch);
        quants = quantile(coeffs, [.25 .75]);
        IQR = quants(2) - quants(1);
        hi = quants(2) + IQR * iqr_mult;
        lo = quants(1) - IQR * iqr_mult;
        coeffs(coeffs > hi | coeffs < lo) = 0;
        out(:, ch) = coeffs;
    end
end


function out = iqrThresholdBatch(wc, iqr_mult)
% Vectorized IQR thresholding across all channels simultaneously
    q25 = quantile(wc, 0.25, 1);  % [1 x nCh]
    q75 = quantile(wc, 0.75, 1);
    IQR = q75 - q25;
    hi = q75 + IQR * iqr_mult;
    lo = q25 - IQR * iqr_mult;
    mask = (wc > hi) | (wc < lo);
    out = wc;
    out(mask) = 0;
end


function result = batchGPUPipeline(od, qmf, L, N, iqr_mult)
% Full batch GPU pipeline: FWT + threshold + IWT for all channels
    [nSamples, nCh] = size(od);

    % Pad and move to GPU
    DataPadded = zeros(2^N, nCh);
    DataPadded(1:nSamples, :) = od;
    DCVals = mean(DataPadded, 1);
    DataPadded = DataPadded - DCVals;

    [DataPadded, onGPU] = pf2_base.accel.toGPU(DataPadded, 'Force', true);
    qmfGPU = gpuArray(qmf);

    % Batch FWT
    wc = fwtBatchGPU(DataPadded, L, qmfGPU);

    % Batch IQR thresholding on detail coefficients
    J = round(log2(size(wc, 1)));
    for j = L:(J-1)
        idx = (2^j + 1):(2^(j+1));
        block = wc(idx, :);
        q25 = quantile(block, 0.25, 1);
        q75 = quantile(block, 0.75, 1);
        IQR = q75 - q25;
        hi = q75 + IQR * iqr_mult;
        lo = q25 - IQR * iqr_mult;
        mask = (block > hi) | (block < lo);
        block(mask) = 0;
        wc(idx, :) = block;
    end

    % Batch IWT
    recon = iwtBatchGPU(wc, L, qmfGPU);

    % Restore DC and truncate
    recon = recon + DCVals;
    result = gather(recon(1:nSamples, :));
end


function X = iwtBatchGPU(wc, L, qmf)
% Batch IWT for all channels via matrix operations on GPU
    [n, nCh] = size(wc);
    J = round(log2(n));
    pLen = length(qmf);

    qmf_row = reshape(qmf, 1, []);
    hqmf = fliplr(qmf_row) .* (-1).^(0:length(qmf_row)-1);

    x = wc(1:2^L, :);

    for j = L:J-1
        detail = wc(2^j+1:2^(j+1), :);
        len_out = 2^(j+1);
        len_in = 2^j;

        % Upsample (insert zeros)
        x_up = zeros(len_out, nCh, 'like', wc);
        x_up(1:2:end, :) = x;
        d_up = zeros(len_out, nCh, 'like', wc);
        d_up(1:2:end, :) = detail;

        % Periodic convolution (lo-pass reconstruction)
        x_shifted = circshift(x_up, 1, 1);
        padded_lo = [x_shifted(end-pLen+1:end, :); x_shifted];
        lo = zeros(len_out, nCh, 'like', wc);
        for k = 1:len_out
            lo(k, :) = sum(padded_lo(k:k+pLen-1, :) .* qmf_row', 1);
        end

        % Periodic convolution (hi-pass reconstruction)
        d_shifted = circshift(d_up, 1, 1);
        padded_hi = [d_shifted(end-pLen+1:end, :); d_shifted];
        hi = zeros(len_out, nCh, 'like', wc);
        for k = 1:len_out
            hi(k, :) = sum(padded_hi(k:k+pLen-1, :) .* fliplr(qmf_row)' .* ((-1).^(0:pLen-1))', 1);
        end

        x = lo + hi;
    end
    X = x;
end


%% =====================================================================
%  CPU-ONLY FALLBACK
%  =====================================================================

function results = benchCPUOnly(opts)
    global WAVELABPATH
    if isempty(WAVELABPATH)
        pf2_base.toolboxes.setup_wavelab();
    end

    rng(42);
    nS = opts.Samples;
    nCh = opts.Channels;
    od = generateOD(nS, nCh);

    fprintf('--- CPU-Only Baseline ---\n');

    t_current = runTimed(opts.Reps, @() pf2_MotionCorrectWavelet(od, 1.5, 1, 'db2', 'none'));
    fprintf('  MotionCorrectWavelet: %.3f s\n', median(t_current));

    t_kbwf = runTimed(opts.Reps, @() pf2_kbWF(od, 3.3, 3, 'db6', 'none'));
    fprintf('  kbWF:                 %.3f s  (%.1fx faster)\n', ...
        median(t_kbwf), median(t_current)/median(t_kbwf));

    t_tddr = runTimed(opts.Reps, @() pf2_MotionCorrectTDDR(od, 1));
    fprintf('  TDDR:                 %.3f s  (%.1fx faster)\n', ...
        median(t_tddr), median(t_current)/median(t_tddr));
    fprintf('\n');

    results.gpuInfo = pf2_base.accel.isGPUAvailable();
    results.pipeline_current = t_current;
    results.pipeline_kbwf = t_kbwf;
    results.pipeline_tddr = t_tddr;
end


%% =====================================================================
%  UTILITIES
%  =====================================================================

function od = generateOD(nSamples, nCh)
    fs = 100;
    t = (0:nSamples-1)' / fs;
    od = 0.3 + 0.01 * randn(nSamples, nCh);
    for ch = 1:nCh
        od(:, ch) = od(:, ch) + 0.005 * sin(2*pi*1.0*t + 2*pi*rand);
    end
    nArt = max(2, round(nSamples / 2000));
    for a = 1:nArt
        ch = randi(nCh);
        idx = randi(nSamples);
        w = randi([5, 30]);
        amp = 0.05 + 0.1 * rand;
        r = max(1, idx-w):min(nSamples, idx+w);
        od(r, ch) = od(r, ch) + amp * exp(-((r - idx).^2) / (2*(w/3)^2))';
    end
end


function times = runTimed(nReps, fn)
    fn();  % warmup
    times = zeros(1, nReps);
    for r = 1:nReps
        t0 = tic;
        fn();
        times(r) = toc(t0);
    end
end
