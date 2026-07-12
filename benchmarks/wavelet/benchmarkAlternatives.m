function results = benchmarkAlternatives(varargin)
% BENCHMARKALTERNATIVES Compare current wavelet impl vs optimization candidates
%
% Benchmarks the current shift-invariant DWT implementation against
% potential faster alternatives using MATLAB's built-in wavelet functions.
% Tests whether swt/iswt, wavedec/waverec, or modwt/imodwt can replace
% the hand-rolled nested-loop approach.
%
% The goal is to find a drop-in replacement that produces equivalent
% artifact correction with significantly less wall time.
%
% Syntax:
%   results = benchmarkAlternatives()
%   results = benchmarkAlternatives('Reps', 5)
%   results = benchmarkAlternatives('Samples', 8000)
%
% Inputs (name-value):
%   Reps    - Repetitions per measurement (default: 5)
%   Samples - Signal length (default: 6000)
%
% Outputs:
%   results - Struct with timing data and numerical comparison
%
% See also: benchmarkWavelet, pf2_MotionCorrectWavelet

    p = inputParser;
    addParameter(p, 'Reps', 5, @isscalar);
    addParameter(p, 'Samples', 6000, @isscalar);
    parse(p, varargin{:});
    opts = p.Results;

    fprintf('\n');
    fprintf('========================================================\n');
    fprintf('  WAVELET ALTERNATIVES BENCHMARK\n');
    fprintf('========================================================\n');
    fprintf('  Signal: %d samples, single channel\n', opts.Samples);
    fprintf('  Reps:   %d\n', opts.Reps);
    fprintf('========================================================\n\n');

    % Setup
    global WAVELABPATH
    if isempty(WAVELABPATH)
        pf2_base.toolboxes.setup_wavelab();
    end

    rng(42);
    nSamples = opts.Samples;
    signal = 0.3 + 0.01 * randn(nSamples, 1);
    signal = signal + 0.005 * sin(2*pi*1.0*(0:nSamples-1)'/100);
    % Add a spike artifact
    signal(3000) = signal(3000) + 0.15;
    signal(2999:3001) = signal(2999:3001) + 0.1;

    wavename = 'db2';
    iqr_mult = 1.5;
    [qmf, ~, ~] = pf2_base.wavelet.resolveWavelet(wavename);

    N = ceil(log2(nSamples));
    L = 4;

    % ================================================================
    %  Method A: Current implementation (shift-invariant nested loop)
    % ================================================================
    fprintf('A) Current: shift-invariant DWT (WT_inv/IWT_inv loop)\n');
    t_current = runTimed(opts.Reps, @() currentImpl(signal, qmf, wavename, iqr_mult, N, L));
    result_current = currentImpl(signal, qmf, wavename, iqr_mult, N, L);
    fprintf('   Time: %.4f s\n\n', median(t_current));

    % ================================================================
    %  Method B: MATLAB wavedec/waverec with IQR thresholding
    % ================================================================
    fprintf('B) wavedec/waverec (standard DWT, NOT shift-invariant)\n');
    hasWT = ~isempty(which('wavedec'));
    if hasWT
        t_wavedec = runTimed(opts.Reps, @() wavedecImpl(signal, wavename, iqr_mult, N, L));
        result_wavedec = wavedecImpl(signal, wavename, iqr_mult, N, L);
        fprintf('   Time: %.4f s  (%.1fx speedup)\n', median(t_wavedec), median(t_current)/median(t_wavedec));
        fprintf('   Max abs diff from current: %.6f\n', max(abs(result_current - result_wavedec)));
        fprintf('   Correlation with current:  %.6f\n', corr(result_current, result_wavedec));
        fprintf('   NOTE: Not shift-invariant — results will differ from current.\n\n');
    else
        t_wavedec = NaN;
        result_wavedec = NaN;
        fprintf('   SKIP: Wavelet Toolbox (wavedec) not available.\n\n');
    end

    % ================================================================
    %  Method C: Stationary Wavelet Transform (swt/iswt)
    % ================================================================
    fprintf('C) swt/iswt (Stationary WT — shift-invariant, single call)\n');
    hasSWT = ~isempty(which('swt'));
    if hasSWT
        t_swt = runTimed(opts.Reps, @() swtImpl(signal, wavename, iqr_mult, N, L));
        result_swt = swtImpl(signal, wavename, iqr_mult, N, L);
        fprintf('   Time: %.4f s  (%.1fx speedup)\n', median(t_swt), median(t_current)/median(t_swt));
        fprintf('   Max abs diff from current: %.6f\n', max(abs(result_current - result_swt)));
        fprintf('   Correlation with current:  %.6f\n', corr(result_current, result_swt));
        fprintf('   NOTE: Shift-invariant — closest equivalent to current approach.\n\n');
    else
        t_swt = NaN;
        result_swt = NaN;
        fprintf('   SKIP: Wavelet Toolbox (swt) not available.\n\n');
    end

    % ================================================================
    %  Method D: MODWT (Maximum Overlap DWT — shift-invariant)
    % ================================================================
    fprintf('D) modwt/imodwt (Maximum Overlap DWT — shift-invariant)\n');
    hasMODWT = ~isempty(which('modwt'));
    if hasMODWT
        t_modwt = runTimed(opts.Reps, @() modwtImpl(signal, wavename, iqr_mult, N, L));
        result_modwt = modwtImpl(signal, wavename, iqr_mult, N, L);
        fprintf('   Time: %.4f s  (%.1fx speedup)\n', median(t_modwt), median(t_current)/median(t_modwt));
        fprintf('   Max abs diff from current: %.6f\n', max(abs(result_current - result_modwt)));
        fprintf('   Correlation with current:  %.6f\n', corr(result_current, result_modwt));
        fprintf('   NOTE: Shift-invariant, no power-of-2 length requirement.\n\n');
    else
        t_modwt = NaN;
        result_modwt = NaN;
        fprintf('   SKIP: Wavelet Toolbox (modwt) not available.\n\n');
    end

    % ================================================================
    %  Method E: WaveLab FWT_PO/IWT_PO (non-shift-invariant, like kbWF)
    % ================================================================
    fprintf('E) WaveLab FWT_PO/IWT_PO (orthogonal, single-pass)\n');
    t_wavelab = runTimed(opts.Reps, @() wavelabImpl(signal, qmf, iqr_mult, N, L));
    result_wavelab = wavelabImpl(signal, qmf, iqr_mult, N, L);
    fprintf('   Time: %.4f s  (%.1fx speedup)\n', median(t_wavelab), median(t_current)/median(t_wavelab));
    fprintf('   Max abs diff from current: %.6f\n', max(abs(result_current - result_wavelab)));
    fprintf('   Correlation with current:  %.6f\n', corr(result_current, result_wavelab));
    fprintf('   NOTE: Not shift-invariant.\n\n');

    % ================================================================
    %  Summary table
    % ================================================================
    fprintf('========================================================\n');
    fprintf('  SUMMARY (single channel, %d samples)\n', nSamples);
    fprintf('========================================================\n');
    fprintf('  %-40s  %10s  %8s\n', 'Method', 'Time(s)', 'Speedup');
    fprintf('  %s\n', repmat('-', 1, 62));

    printRow('A) Current (shift-inv nested loop)', t_current, t_current);
    if ~isnan(t_wavedec), printRow('B) wavedec/waverec', t_wavedec, t_current); end
    if ~isnan(t_swt),     printRow('C) swt/iswt (shift-invariant)', t_swt, t_current); end
    if ~isnan(t_modwt),   printRow('D) modwt/imodwt (shift-invariant)', t_modwt, t_current); end
    printRow('E) WaveLab FWT_PO/IWT_PO', t_wavelab, t_current);
    fprintf('\n');

    fprintf('  Recommendation:\n');
    fprintf('    For equivalent shift-invariant behavior: swt/iswt (C) or modwt (D)\n');
    fprintf('    For maximum speed (non-shift-invariant OK): wavedec (B) or FWT_PO (E)\n');
    fprintf('    Projected 18-channel speedup with best method: %.0fx faster\n', ...
        median(t_current) / min([nonnan(t_wavedec), nonnan(t_swt), nonnan(t_modwt), nonnan(t_wavelab)]));
    fprintf('\n');

    % Pack results
    results.nSamples = nSamples;
    results.t_current = t_current;
    results.t_wavedec = t_wavedec;
    results.t_swt = t_swt;
    results.t_modwt = t_modwt;
    results.t_wavelab = t_wavelab;
end


%% =====================================================================
%  IMPLEMENTATION VARIANTS
%  =====================================================================

function out = currentImpl(signal, qmf, wavename, iqr_mult, N, L)
% Mirrors pf2_MotionCorrectWavelet processChannel exactly
    nSamples = length(signal);
    DataPadded = zeros(2^N, 1);
    DataPadded(1:nSamples) = signal;
    DCVal = mean(DataPadded);
    DataPadded = DataPadded - DCVal;

    % NormalizationNoise
    c = cconv(DataPadded', qmf, length(DataPadded));
    y_ds = dyaddown(c);
    madVal = mad(y_ds);
    if madVal ~= 0
        yn = (1/1.4826) .* DataPadded' ./ madVal;
        NormCoef = 1 / (1.4826 * madVal);
    else
        yn = DataPadded';
        NormCoef = 1;
    end

    % WT_inv
    D = N - L;
    n = length(yn);
    wp = zeros(n, D+1);
    dwtmode('per', 'nodisp');
    wp(:,1) = yn';
    for d = 0:(D-1)
        l_blocks = n / (2^d);
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

    % WaveletAnalysis (IQR thresholding)
    SignalLength_tmp = nSamples;
    for j = 1:N-L-1
        SignalLength_tmp = fix(SignalLength_tmp / 2);
        l_blocks = n / (2^j);
        for b = 0:(2^j - 1)
            sr = wp(b*l_blocks+1:b*l_blocks+l_blocks, j+1);
            sr_temp = sr(1:SignalLength_tmp);
            quants = quantile(sr_temp, [.25 .50 .75]);
            IQR = quants(3) - quants(1);
            prob1 = quants(3) + IQR * iqr_mult;
            prob2 = quants(1) - IQR * iqr_mult;
            sr(sr > prob1) = 0;
            sr(sr < prob2) = 0;
            wp(b*l_blocks+1:b*l_blocks+l_blocks, j+1) = sr;
        end
    end

    % IWT_inv
    [~, D2] = size(wp);
    D2 = D2 - 1;
    approx = wp(:,1)';
    for d = D2-1:-1:0
        l_blocks = n / (2^d);
        for b = 0:(2^d - 1)
            cD2 = wp(b*l_blocks+1:b*l_blocks+l_blocks/2, d+2)';
            cD_shift2 = wp(b*l_blocks+l_blocks/2+1:b*l_blocks+l_blocks, d+2)';
            cA2 = approx(b*l_blocks+1:b*l_blocks+l_blocks/2);
            cA_shift2 = approx(b*l_blocks+l_blocks/2+1:b*l_blocks+l_blocks);
            s1 = idwt(cA2, cD2, wavename);
            s_sh = idwt(cA_shift2, cD_shift2, wavename);
            s2 = [s_sh(2:end) s_sh(1)];
            approx(b*l_blocks+1:b*l_blocks+l_blocks) = (s1 + s2) / 2;
        end
    end

    ARSignal = approx / NormCoef + DCVal;
    out = ARSignal(1:nSamples)';
end


function out = wavedecImpl(signal, wavename, iqr_mult, N, L)
% Standard multi-level DWT via wavedec (NOT shift-invariant)
    nSamples = length(signal);
    DataPadded = zeros(2^N, 1);
    DataPadded(1:nSamples) = signal;
    DCVal = mean(DataPadded);
    DataPadded = DataPadded - DCVal;

    nLevels = N - L;
    [C, Lengths] = wavedec(DataPadded, nLevels, wavename);

    % IQR thresholding on detail coefficients
    idx = Lengths(1) + 1;  % skip approximation
    for j = 1:nLevels
        len = Lengths(j + 1);
        coeffs = C(idx:idx+len-1);
        quants = quantile(coeffs, [.25 .75]);
        IQR = quants(2) - quants(1);
        hi = quants(2) + IQR * iqr_mult;
        lo = quants(1) - IQR * iqr_mult;
        coeffs(coeffs > hi | coeffs < lo) = 0;
        C(idx:idx+len-1) = coeffs;
        idx = idx + len;
    end

    recon = waverec(C, Lengths, wavename);
    recon = recon + DCVal;
    out = recon(1:nSamples);
end


function out = swtImpl(signal, wavename, iqr_mult, N, L)
% Stationary Wavelet Transform — shift-invariant, single call
    nSamples = length(signal);
    % swt requires power-of-2 length
    DataPadded = zeros(2^N, 1);
    DataPadded(1:nSamples) = signal;
    DCVal = mean(DataPadded);
    DataPadded = DataPadded - DCVal;

    nLevels = N - L;
    [swa, swd] = swt(DataPadded, nLevels, wavename);

    % IQR thresholding on detail coefficients at each level
    for j = 1:nLevels
        coeffs = swd(j, :);
        quants = quantile(coeffs, [.25 .75]);
        IQR = quants(2) - quants(1);
        hi = quants(2) + IQR * iqr_mult;
        lo = quants(1) - IQR * iqr_mult;
        coeffs(coeffs > hi | coeffs < lo) = 0;
        swd(j, :) = coeffs;
    end

    recon = iswt(swa, swd, wavename);
    recon = recon(:) + DCVal;
    out = recon(1:nSamples);
end


function out = modwtImpl(signal, wavename, iqr_mult, N, L)
% MODWT — shift-invariant, no power-of-2 requirement
    nSamples = length(signal);
    DCVal = mean(signal);
    centered = signal - DCVal;

    nLevels = N - L;
    w = modwt(centered, wavename, nLevels);
    % w is (nLevels+1) x nSamples: rows 1..nLevels are details, last is approx

    for j = 1:nLevels
        coeffs = w(j, :);
        quants = quantile(coeffs, [.25 .75]);
        IQR = quants(2) - quants(1);
        hi = quants(2) + IQR * iqr_mult;
        lo = quants(1) - IQR * iqr_mult;
        coeffs(coeffs > hi | coeffs < lo) = 0;
        w(j, :) = coeffs;
    end

    recon = imodwt(w, wavename);
    out = recon(:) + DCVal;
end


function out = wavelabImpl(signal, qmf, iqr_mult, N, L)
% WaveLab orthogonal DWT (same as used in kbWF) — single-pass, fast
    nSamples = length(signal);
    DataPadded = zeros(2^N, 1);
    DataPadded(1:nSamples) = signal;
    DCVal = mean(DataPadded);
    DataPadded = DataPadded - DCVal;

    wc = FWT_PO(DataPadded, L, qmf);

    % IQR thresholding on detail coefficients
    for j = L:(N-1)
        idx = (2^j + 1):(2^(j+1));
        coeffs = wc(idx);
        quants = quantile(coeffs, [.25 .75]);
        IQR = quants(2) - quants(1);
        hi = quants(2) + IQR * iqr_mult;
        lo = quants(1) - IQR * iqr_mult;
        coeffs(coeffs > hi | coeffs < lo) = 0;
        wc(idx) = coeffs;
    end

    recon = IWT_PO(wc, L, qmf);
    recon = recon(:) + DCVal;
    out = recon(1:nSamples);
end


%% =====================================================================
%  UTILITIES
%  =====================================================================

function times = runTimed(nReps, fn)
    fn();  % warmup
    times = zeros(1, nReps);
    for r = 1:nReps
        t0 = tic;
        fn();
        times(r) = toc(t0);
    end
end

function printRow(name, times, baseline)
    med = median(times);
    speedup = median(baseline) / med;
    fprintf('  %-40s  %10.4f  %7.1fx\n', name, med, speedup);
end

function v = nonnan(x)
    if isnan(x), v = Inf; else, v = median(x); end
end
