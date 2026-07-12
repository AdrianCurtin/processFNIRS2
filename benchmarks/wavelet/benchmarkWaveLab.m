function results = benchmarkWaveLab(varargin)
% BENCHMARKWAVELAB Profile WaveLab850 internals vs MATLAB Wavelet Toolbox
%
% WaveLab850 (2006) is pure MATLAB M-code using filter() for convolution.
% MATLAB's Wavelet Toolbox uses optimized C/MEX implementations.
% This benchmark quantifies the difference at every level of the stack:
%   - Raw convolution: WaveLab aconv/iconv vs MATLAB conv/filter
%   - Single-level DWT: FWT_PO level vs dwt()
%   - Full multi-level: FWT_PO vs wavedec
%   - Overhead: function call overhead, ShapeAsRow, dyadlength, etc.
%
% Syntax:
%   results = benchmarkWaveLab()
%   results = benchmarkWaveLab('Reps', 10)
%   results = benchmarkWaveLab('Samples', 8192)
%
% Inputs (name-value):
%   Reps    - Repetitions per measurement (default: 10)
%   Samples - Signal length, should be power of 2 (default: 8192)
%
% Outputs:
%   results - Struct with detailed timing breakdown
%
% See also: benchmarkWavelet, benchmarkAlternatives, benchmarkGPU

    p = inputParser;
    addParameter(p, 'Reps', 10, @isscalar);
    addParameter(p, 'Samples', 8192, @isscalar);
    parse(p, varargin{:});
    opts = p.Results;

    fprintf('\n');
    fprintf('========================================================\n');
    fprintf('  WAVELAB850 INTERNALS BENCHMARK\n');
    fprintf('  WaveLab850 (2006 M-code) vs MATLAB Wavelet Toolbox\n');
    fprintf('========================================================\n');
    fprintf('  Signal: %d samples (2^%.0f)\n', opts.Samples, log2(opts.Samples));
    fprintf('  Reps:   %d\n', opts.Reps);
    fprintf('========================================================\n\n');

    % Setup
    global WAVELABPATH
    if isempty(WAVELABPATH)
        pf2_base.toolboxes.setup_wavelab();
    end

    rng(42);
    n = opts.Samples;
    x = randn(1, n);
    x_col = x(:);

    [qmf, wavename, ~] = pf2_base.wavelet.resolveWavelet('db4');
    L = 1;  % coarsest level for full decomposition comparison
    L4 = 4; % typical level for motion correction

    hasWT = ~isempty(which('wavedec'));
    results = struct();

    % ================================================================
    %  Level 1: Raw convolution primitives
    % ================================================================
    fprintf('--- Level 1: Convolution Primitives ---\n');

    filt_rev = fliplr(qmf);

    % WaveLab aconv (periodic convolution with time-reversed filter)
    t_aconv = runTimed(opts.Reps * 10, @() aconv(qmf, x));
    fprintf('  WaveLab aconv:     %.6f s\n', median(t_aconv));

    % WaveLab iconv (periodic convolution)
    mirfilt = MirrorFilt(qmf);
    t_iconv = runTimed(opts.Reps * 10, @() iconv(mirfilt, x));
    fprintf('  WaveLab iconv:     %.6f s\n', median(t_iconv));

    % MATLAB filter (what WaveLab uses internally)
    t_filter = runTimed(opts.Reps * 10, @() filter(filt_rev, 1, x));
    fprintf('  MATLAB filter:     %.6f s\n', median(t_filter));

    % MATLAB conv (built-in)
    t_conv = runTimed(opts.Reps * 10, @() conv(x, qmf, 'same'));
    fprintf('  MATLAB conv:       %.6f s\n', median(t_conv));

    % MATLAB cconv (circular)
    t_cconv = runTimed(opts.Reps * 10, @() cconv(x, qmf, n));
    fprintf('  MATLAB cconv:      %.6f s\n', median(t_cconv));

    overhead_aconv = median(t_aconv) / median(t_filter);
    fprintf('  aconv overhead vs raw filter: %.1fx\n', overhead_aconv);
    fprintf('\n');

    results.conv.t_aconv = t_aconv;
    results.conv.t_iconv = t_iconv;
    results.conv.t_filter = t_filter;
    results.conv.t_conv = t_conv;
    results.conv.t_cconv = t_cconv;

    % ================================================================
    %  Level 2: Single decomposition step
    % ================================================================
    fprintf('--- Level 2: Single Decomposition Step ---\n');

    % WaveLab: DownDyadLo + DownDyadHi (one level of FWT_PO)
    t_downdyad = runTimed(opts.Reps * 5, @() singleLevelWaveLab(x, qmf));
    fprintf('  WaveLab (DownDyadLo+Hi):  %.6f s\n', median(t_downdyad));

    % MATLAB dwt (if available)
    if hasWT
        dwtmode('per', 'nodisp');
        t_dwt = runTimed(opts.Reps * 5, @() dwt(x_col, wavename));
        fprintf('  MATLAB dwt:               %.6f s\n', median(t_dwt));
        fprintf('  WaveLab / dwt ratio:      %.1fx\n', median(t_downdyad)/median(t_dwt));
    else
        t_dwt = NaN;
        fprintf('  MATLAB dwt:               [not available]\n');
    end
    fprintf('\n');

    results.singleLevel.t_wavelab = t_downdyad;
    results.singleLevel.t_dwt = t_dwt;

    % ================================================================
    %  Level 3: Full multi-level decomposition
    % ================================================================
    fprintf('--- Level 3: Full Multi-Level DWT ---\n');

    J = round(log2(n));
    nLevels = J - L4;
    fprintf('  Levels: %d (J=%d, L=%d)\n', nLevels, J, L4);

    % WaveLab FWT_PO
    t_fwt = runTimed(opts.Reps, @() FWT_PO(x, L4, qmf));
    fprintf('  WaveLab FWT_PO:    %.6f s\n', median(t_fwt));

    % WaveLab IWT_PO
    wc = FWT_PO(x, L4, qmf);
    t_iwt = runTimed(opts.Reps, @() IWT_PO(wc, L4, qmf));
    fprintf('  WaveLab IWT_PO:    %.6f s\n', median(t_iwt));

    % WaveLab round-trip
    t_fwt_iwt = runTimed(opts.Reps, @() IWT_PO(FWT_PO(x, L4, qmf), L4, qmf));
    fprintf('  WaveLab FWT+IWT:   %.6f s\n', median(t_fwt_iwt));

    if hasWT
        % MATLAB wavedec/waverec
        t_wavedec = runTimed(opts.Reps, @() wavedec(x_col, nLevels, wavename));
        [C, Ls] = wavedec(x_col, nLevels, wavename);
        t_waverec = runTimed(opts.Reps, @() waverec(C, Ls, wavename));
        t_wavedec_rec = runTimed(opts.Reps, @() waverec(wavedec(x_col, nLevels, wavename)));

        fprintf('  MATLAB wavedec:    %.6f s\n', median(t_wavedec));
        fprintf('  MATLAB waverec:    %.6f s\n', median(t_waverec));
        fprintf('  MATLAB dec+rec:    %.6f s\n', median(t_wavedec_rec));
        fprintf('  WaveLab / MATLAB ratio (fwd):     %.1fx\n', median(t_fwt)/median(t_wavedec));
        fprintf('  WaveLab / MATLAB ratio (roundtr): %.1fx\n', median(t_fwt_iwt)/median(t_wavedec_rec));

        % SWT (shift-invariant, the theoretical equivalent of MotionCorrectWavelet's approach)
        if ~isempty(which('swt'))
            t_swt = runTimed(opts.Reps, @() swt(x_col, nLevels, wavename));
            [swa, swd] = swt(x_col, nLevels, wavename);
            t_iswt = runTimed(opts.Reps, @() iswt(swa, swd, wavename));
            fprintf('  MATLAB swt:        %.6f s\n', median(t_swt));
            fprintf('  MATLAB iswt:       %.6f s\n', median(t_iswt));
        end

        % MODWT (shift-invariant, no power-of-2 requirement)
        if ~isempty(which('modwt'))
            t_modwt = runTimed(opts.Reps, @() modwt(x_col, wavename, nLevels));
            w = modwt(x_col, wavename, nLevels);
            t_imodwt = runTimed(opts.Reps, @() imodwt(w, wavename));
            fprintf('  MATLAB modwt:      %.6f s\n', median(t_modwt));
            fprintf('  MATLAB imodwt:     %.6f s\n', median(t_imodwt));
        end
    end
    fprintf('\n');

    results.multiLevel.t_fwt = t_fwt;
    results.multiLevel.t_iwt = t_iwt;
    results.multiLevel.nLevels = nLevels;

    % ================================================================
    %  Level 4: Function call overhead analysis
    % ================================================================
    fprintf('--- Level 4: WaveLab Function Call Overhead ---\n');

    % Count function calls in one FWT_PO pass
    % FWT_PO calls: ShapeAsRow, dyadlength, DownDyadHi, DownDyadLo, dyad, ShapeLike
    % DownDyadHi calls: iconv, MirrorFilt, lshift
    % DownDyadLo calls: aconv
    % aconv/iconv call: filter, reverse/reshape

    % Measure overhead of helper functions
    t_shapeAsRow = runTimed(opts.Reps * 20, @() ShapeAsRow(x));
    t_dyadlength = runTimed(opts.Reps * 20, @() dyadlength(x));
    t_mirrorFilt = runTimed(opts.Reps * 20, @() MirrorFilt(qmf));

    fprintf('  ShapeAsRow:     %.6f s per call\n', median(t_shapeAsRow));
    fprintf('  dyadlength:     %.6f s per call\n', median(t_dyadlength));
    fprintf('  MirrorFilt:     %.6f s per call\n', median(t_mirrorFilt));

    % Estimate total function call overhead in FWT_PO
    nLevelsFWT = J - L4;
    % Per level: 1x DownDyadHi + 1x DownDyadLo + 1x dyad
    % DownDyadHi: iconv + MirrorFilt + lshift  (3 calls)
    % DownDyadLo: aconv                         (1 call)
    % aconv: reverse + filter                   (2 calls)
    % iconv: filter                             (1 call)
    callsPerLevel = 1 + 1 + 1 + 3 + 1 + 2 + 1;  % ~10 function calls per level
    totalCalls = nLevelsFWT * callsPerLevel + 3;  % +ShapeAsRow, dyadlength, ShapeLike
    fprintf('  Estimated function calls per FWT_PO: ~%d\n', totalCalls);
    fprintf('  MATLAB function call overhead: ~%.1f us per call\n', ...
        median(t_shapeAsRow) * 1e6);  % rough estimate
    fprintf('  Overhead fraction of FWT_PO: ~%.0f%%\n', ...
        totalCalls * median(t_shapeAsRow) / median(t_fwt) * 100);
    fprintf('\n');

    results.overhead.t_shapeAsRow = t_shapeAsRow;
    results.overhead.t_dyadlength = t_dyadlength;
    results.overhead.t_mirrorFilt = t_mirrorFilt;
    results.overhead.totalCalls = totalCalls;

    % ================================================================
    %  Level 5: Signal size scaling
    % ================================================================
    fprintf('--- Level 5: Scaling with Signal Length ---\n');
    fprintf('  %-8s  %10s  %10s', 'Length', 'FWT_PO', 'IWT_PO');
    if hasWT
        fprintf('  %10s  %10s  %10s', 'wavedec', 'modwt', 'Ratio');
    end
    fprintf('\n');

    sizes = [512, 1024, 2048, 4096, 8192, 16384, 32768];
    scale_times = NaN(length(sizes), 5);

    for si = 1:length(sizes)
        sz = sizes(si);
        xs = randn(1, sz);
        xs_col = xs(:);
        Js = round(log2(sz));
        Ls = max(1, Js - 9);  % keep ~9 levels max

        t_f = runTimed(opts.Reps, @() FWT_PO(xs, Ls, qmf));
        wcs = FWT_PO(xs, Ls, qmf);
        t_i = runTimed(opts.Reps, @() IWT_PO(wcs, Ls, qmf));
        scale_times(si, 1) = median(t_f);
        scale_times(si, 2) = median(t_i);

        fprintf('  %7d  %10.6f  %10.6f', sz, median(t_f), median(t_i));

        if hasWT
            nLev = Js - Ls;
            t_wd = runTimed(opts.Reps, @() wavedec(xs_col, nLev, wavename));
            scale_times(si, 3) = median(t_wd);
            if ~isempty(which('modwt'))
                t_m = runTimed(opts.Reps, @() modwt(xs_col, wavename, nLev));
                scale_times(si, 4) = median(t_m);
            end
            scale_times(si, 5) = median(t_f) / median(t_wd);
            fprintf('  %10.6f  %10.6f  %9.1fx', median(t_wd), scale_times(si, 4), scale_times(si, 5));
        end
        fprintf('\n');
    end
    fprintf('\n');

    results.scaling.sizes = sizes;
    results.scaling.times = scale_times;

    % ================================================================
    %  Summary
    % ================================================================
    fprintf('========================================================\n');
    fprintf('  SUMMARY\n');
    fprintf('========================================================\n');
    fprintf('  WaveLab850 is pure M-code from 2006.\n');
    fprintf('  Every FWT_PO call involves ~%d nested function calls.\n', totalCalls);
    fprintf('  The dominant cost is function call overhead + interpreted loops.\n\n');

    fprintf('  Optimization paths:\n');
    fprintf('    1. Replace FWT_PO/IWT_PO with MATLAB wavedec/waverec\n');
    fprintf('       Expected speedup: ~%.0fx per transform\n', median(t_fwt)/median(t_wavedec));
    fprintf('    2. For shift-invariant: use swt/iswt or modwt/imodwt\n');
    fprintf('       Replaces entire WT_inv nested loop (~2000 dwt calls → 1 swt call)\n');
    fprintf('    3. Batch channels as matrix ops (eliminates per-channel overhead)\n');
    fprintf('    4. GPU acceleration for large channel counts (>16 channels)\n');
    fprintf('\n');
end


%% =====================================================================
%  HELPERS
%  =====================================================================

function [lo, hi] = singleLevelWaveLab(x, qmf)
    lo = DownDyadLo(x, qmf);
    hi = DownDyadHi(x, qmf);
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
