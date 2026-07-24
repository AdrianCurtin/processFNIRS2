function result = surrogateTest(couplingFn, x, y, fs, varargin)
% SURROGATETEST Within-subject surrogate significance test for coupling measures
%
% Builds a null distribution for a scalar coupling measure via circular
% time-shift surrogates of one signal. Each surrogate is constructed by
% randomly shifting y in time by an amount exceeding its autocorrelation
% length (so the surrogate has the same power spectrum but scrambled phase
% relations with x). The observed coupling is then compared against the null
% distribution to derive a one-tailed p-value.
%
% This is DISTINCT from exploreFNIRS.hyperscanning.permutationTest, which
% tests inter-brain coupling by shuffling dyad pairings (assigning different
% participant pairs). surrogateTest operates on a single pair of channels or
% signals and tests whether the within-session coupling exceeds what would
% be expected from the autocorrelation structure of the signals alone. Use
% surrogateTest for within-subject or single-dyad analyses; use
% permutationTest for group-level inter-brain analyses.
%
% When couplingFn is exploreFNIRS.coupling.wcoherence, the surrogates are
% automatically masked by the same cone-of-influence (COI) that the
% original result used, ensuring the null distribution is not inflated by
% COI-excluded edge artifacts.
%
% The shift must exceed the autocorrelation length of y (estimated as
% MinShift in samples). By default MinShift is set to the lag at which the
% autocorrelation of y drops below 1/e (~37%), with a floor of 1 second.
%
% Syntax:
%   result = exploreFNIRS.coupling.surrogateTest(couplingFn, x, y, fs)
%   result = exploreFNIRS.coupling.surrogateTest(couplingFn, x, y, fs, ...
%       'Permutations', 500, 'Alpha', 0.05)
%   result = exploreFNIRS.coupling.surrogateTest(couplingFn, x, y, fs, ...
%       'Permutations', 1000, 'CouplingArgs', {'FreqRange', [0.01 0.1]})
%
% Inputs:
%   couplingFn  - Function handle: fn(x, y, fs, couplingArgs{:}) -> struct
%                 The function must return a struct with a scalar .value field.
%                 Compatible with all exploreFNIRS.coupling.* functions.
%   x           - [T x 1] first time series (column vector)
%   y           - [T x 1] second time series (column vector; will be shifted)
%   fs          - Sampling frequency (Hz), positive scalar
%
% Name-Value Parameters:
%   Permutations - Number of circular shift surrogates (default: 500)
%                  Use 1000 or more for reliable p-values at alpha = 0.05.
%   Alpha        - Significance threshold for the one-tailed test (default: 0.05)
%   CouplingArgs - Cell array of extra arguments passed to couplingFn after fs
%                  (default: {}). Example: {'FreqRange', [0.01, 0.1]}
%   MinShift     - Minimum shift in seconds (default: auto, lag at which
%                  autocorrelation of y drops below 1/e, floored at 1 s)
%                  Set explicitly if auto-detection is unreliable. Only used by
%                  the 'circshift' surrogate.
%   SurrogateType- How surrogates are generated (default: 'auto'):
%                    'circshift' - circular time-shift of y (valid for
%                       lag-sensitive measures: imaginary coherence, wPLI,
%                       wavelet coherence).
%                    'phaserand' - FT (Theiler) phase-randomization of y,
%                       preserving its power spectrum. REQUIRED for measures
%                       invariant to a constant phase offset (PLV): a circular
%                       shift only adds a ~constant band phase offset, which PLV
%                       discards, so its shift-null is invalid.
%                    'auto' - 'phaserand' for PLV, 'circshift' otherwise.
%   Tail         - 'right' (default, observed > null) or 'both' (two-tailed)
%
% Outputs:
%   result - Struct with fields:
%     .pvalue      - Permutation p-value (one-tailed by default)
%     .observed    - Observed coupling value (scalar)
%     .nullDist    - [nPerms x 1] coupling values from surrogate runs
%     .nullMean    - Mean of null distribution
%     .nullSD      - SD of null distribution
%     .zScore      - (observed - nullMean) / nullSD
%     .significant - Logical: pvalue < Alpha
%     .alpha       - Alpha threshold used
%     .nPerms      - Number of surrogates completed
%     .minShift    - Minimum shift used (samples)
%     .method      - Method name from couplingFn result (or 'unknown')
%
% Algorithm:
%   1. Fill NaN values in x and y via linear interpolation (matches the
%      sibling measures: plv.m, imagCoherence.m, wpli.m), BEFORE any other
%      step. A single missing sample left in place would otherwise poison
%      every downstream FFT (autocorrelation-length estimate, phase
%      randomization) and the observed-statistic computation with NaN.
%   2. Compute the observed coupling: observedVal = couplingFn(x, y, ...).value
%   3. Estimate the autocorrelation length of y: minShift = first lag where
%      acf(y, lag) < 1/e, floored at 1*fs samples.
%   4. Draw nPerms random circular shifts in [minShift, T - minShift].
%   5. For each shift, circularly shift y, compute coupling, record .value.
%   6. p-value = (# null values >= observed + 1) / (nPerms + 1)  [Phipson 2010]
%
% Example:
%   data = pf2.import.sampleData.fNIR2000();
%   proc = processFNIRS2(data);
%   x = proc.HbO(:, 1);
%   y = proc.HbO(:, 2);
%   fn = @exploreFNIRS.coupling.imagCoherence;
%   sr = exploreFNIRS.coupling.surrogateTest(fn, x, y, proc.fs, ...
%       'CouplingArgs', {'FreqRange', [0.01 0.1]}, 'Permutations', 200);
%   fprintf('imagCoh = %.3f,  p = %.3f,  significant = %d\n', ...
%       sr.observed, sr.pvalue, sr.significant);
%
%   % wcoherence surrogate test (COI masking applied automatically)
%   fn2 = @exploreFNIRS.coupling.wcoherence;
%   sr2 = exploreFNIRS.coupling.surrogateTest(fn2, x, y, proc.fs, ...
%       'CouplingArgs', {'FreqRange', [0.01 0.1]}, 'Permutations', 200);
%   fprintf('wcoherence: p = %.3f\n', sr2.pvalue);
%
% Notes:
%   - x and y are NaN-filled (linear interpolation) before ANY computation --
%     including the observed-statistic call, the autocorrelation-length FFT,
%     and phase randomization -- so a single interior NaN sample cannot make
%     the whole null distribution (and therefore the p-value) come back NaN.
%   - Circular shifting preserves the exact power spectrum (autocorrelation
%     structure) of y while randomizing the phase relationship with x. This
%     is the appropriate null model when the autocorrelation of the signals
%     must be preserved (the default for fNIRS data, which has strong 1/f
%     structure). For signals with a specific spectral structure that must be
%     matched more precisely, IAAFT surrogates should be used instead.
%   - p-values are computed using the formula from Phipson & Smyth (2010) to
%     ensure they are never exactly zero with finite permutations.
%   - This function shifts y. If your coupling measure is asymmetric
%     (e.g. Granger causality direction), consider also shifting x and
%     reporting both.
%
% References:
%   Phipson, B. & Smyth, G. K. (2010). Permutation P-values should never
%   be zero: calculating exact P-values when permutations are randomly
%   drawn. Statistical Applications in Genetics and Molecular Biology,
%   9(1), Article 39. DOI: 10.2202/1544-6115.1585
%
% See also: exploreFNIRS.coupling.imagCoherence, exploreFNIRS.coupling.wpli,
%   exploreFNIRS.coupling.plv, exploreFNIRS.coupling.wcoherence,
%   exploreFNIRS.hyperscanning.permutationTest

    p = inputParser;
    addRequired(p, 'couplingFn',  @(v) isa(v, 'function_handle'));
    addRequired(p, 'x',           @(v) isnumeric(v) && isvector(v));
    addRequired(p, 'y',           @(v) isnumeric(v) && isvector(v));
    addRequired(p, 'fs',          @(v) isnumeric(v) && isscalar(v) && v > 0);
    addParameter(p, 'Permutations', 500,  @(v) isnumeric(v) && isscalar(v) && v > 0);
    addParameter(p, 'Alpha',        0.05, @(v) isnumeric(v) && isscalar(v) && v > 0 && v < 1);
    addParameter(p, 'CouplingArgs', {},   @iscell);
    addParameter(p, 'MinShift',     -1,   @(v) isnumeric(v) && isscalar(v));
    addParameter(p, 'SurrogateType','auto', @(v) ischar(v) || isstring(v));
    addParameter(p, 'Tail',        'right', @(v) ischar(v) || isstring(v));
    parse(p, couplingFn, x, y, fs, varargin{:});
    opts = p.Results;

    x = x(:);
    y = y(:);
    T = length(x);

    if length(y) ~= T
        error('exploreFNIRS:coupling:surrogateTest', 'x and y must have equal length.');
    end
    if T < 4
        error('exploreFNIRS:coupling:surrogateTest', ...
            'Signals too short for surrogate testing (T = %d).', T);
    end

    tail = lower(char(opts.Tail));
    if ~ismember(tail, {'right', 'both'})
        error('exploreFNIRS:coupling:surrogateTest', ...
            'Tail must be ''right'' or ''both'' (got ''%s'').', tail);
    end

    % NaN handling: linear interpolation (matches plv.m / imagCoherence.m /
    % wpli.m). This MUST happen before the observed statistic is computed and
    % before any FFT-based step below (autoCorrelationLength, phaseRandomize):
    % fft() of a signal that still contains NaN returns an all-NaN spectrum,
    % which otherwise silently poisons every surrogate draw (and the observed
    % value passed to couplingFn), making the p-value come back NaN even when
    % only a single sample was missing.
    x = fillNaN(x);
    y = fillNaN(y);

    % Observed coupling
    obsResult = couplingFn(x, y, fs, opts.CouplingArgs{:});
    observedVal = obsResult.value;

    % Determine method name
    if isstruct(obsResult) && isfield(obsResult, 'method')
        methodName = obsResult.method;
    else
        methodName = 'unknown';
    end

    % Resolve the surrogate type. PLV discards a constant phase difference, so a
    % circular time-shift can produce an INVALID null for it: for narrowband /
    % near-stationary phase coupling a shift only adds a ~constant band phase
    % offset, leaving the surrogate PLV ~equal to the observed. (For a pure tone
    % PLV is deterministically ~1 and no spectrum-preserving surrogate can break
    % it; for broadband time-varying phase a shift does decorrelate and is
    % valid.) The robust, literature-standard PLV null is an FT (Theiler)
    % phase-randomization surrogate, so use it for PLV. Circular shift remains
    % valid and preferred for lag-sensitive measures (imaginary coherence, wPLI,
    % wavelet coherence).
    surrType = lower(char(opts.SurrogateType));
    if strcmp(surrType, 'auto')
        if ismember(methodName, {'plv'})
            surrType = 'phaserand';
        else
            surrType = 'circshift';
        end
    end
    if ~ismember(surrType, {'circshift', 'phaserand'})
        error('exploreFNIRS:coupling:surrogateTest', ...
            'SurrogateType must be ''auto'', ''circshift'', or ''phaserand''.');
    end

    % Shift bookkeeping is only meaningful for the circular-shift surrogate;
    % phase-randomization ignores it entirely, so skip it (and its warnings) for
    % 'phaserand'. minShift is reported as NaN in that case.
    minShift = NaN; maxShift = NaN; shifts = [];
    if strcmp(surrType, 'circshift')
        % Minimum shift: autocorrelation length of y
        if opts.MinShift < 0
            minShift = autoCorrelationLength(y, fs);
        else
            minShift = round(opts.MinShift * fs);
            minShift = max(minShift, 1);
        end

        % Need at least minShift samples of room on each side
        maxShift = T - minShift;
        if maxShift <= minShift
            warning('exploreFNIRS:coupling:surrogateTest:shiftRange', ...
                ['Signal length (%d samples) is too short to allow shifts ' ...
                 'exceeding the autocorrelation length (%d samples). ' ...
                 'Reducing minimum shift to T/4.'], T, minShift);
            minShift = max(1, round(T / 4));
            maxShift = T - minShift;
        end

        if maxShift <= minShift
            error('exploreFNIRS:coupling:surrogateTest', ...
                'Signal is too short for surrogate testing with the current minimum shift.');
        end
    end

    % Is this a wcoherence call? If so, capture COI info from the observed
    % result to mask surrogates consistently.
    isWcoh = strcmp(methodName, 'wcoherence') && ...
             isfield(obsResult, 'coi') && isfield(obsResult, 'freqs');

    nPerms = round(opts.Permutations);
    nullDist = nan(nPerms, 1);

    % Draw random shifts (circshift only): integers in [minShift, maxShift]
    if strcmp(surrType, 'circshift')
        shifts = randi([minShift, maxShift], nPerms, 1);
    end

    for k = 1:nPerms
        if strcmp(surrType, 'phaserand')
            ySurr = phaseRandomize(y);          % FT surrogate (valid for PLV)
        else
            ySurr = circshift(y, shifts(k));    % circular time-shift
        end

        if isWcoh
            % For wcoherence surrogates, pass pre-extracted COI args so the
            % scalar .value uses the same COI mask as the observed result.
            surr = couplingFn(x, ySurr, fs, opts.CouplingArgs{:});
            % The wcoherence function already applies COI internally, so
            % the .value field is already COI-masked.
            nullDist(k) = surr.value;
        else
            surr = couplingFn(x, ySurr, fs, opts.CouplingArgs{:});
            nullDist(k) = surr.value;
        end
    end

    % Drop NaN surrogate values (can occur with very noisy/short segments)
    validSurr = ~isnan(nullDist);
    nValid = sum(validSurr);
    if nValid == 0
        warning('exploreFNIRS:coupling:surrogateTest:allNaN', ...
            'All surrogate values are NaN. Cannot compute p-value.');
        pval = NaN;
    else
        nullValid = nullDist(validSurr);
        % Phipson & Smyth (2010): p = (# null >= obs + 1) / (n + 1)
        % avoids p = 0 with finite permutations.
        switch tail
            case 'right'
                pval = (sum(nullValid >= observedVal) + 1) / (nValid + 1);
            case 'both'
                nullCentered = nullValid - mean(nullValid);
                obsCentered  = observedVal - mean(nullValid);
                pval = (sum(abs(nullCentered) >= abs(obsCentered)) + 1) / (nValid + 1);
        end
    end

    result.pvalue      = pval;
    result.observed    = observedVal;
    result.nullDist    = nullDist;
    result.nullMean    = mean(nullDist, 'omitnan');
    result.nullSD      = std(nullDist, 'omitnan');
    if result.nullSD > 0
        result.zScore  = (observedVal - result.nullMean) / result.nullSD;
    else
        result.zScore  = NaN;
    end
    result.significant = ~isnan(pval) && pval < opts.Alpha;
    result.alpha       = opts.Alpha;
    result.nPerms      = nPerms;
    result.minShift    = minShift;
    result.method      = methodName;
    result.surrogateType = surrType;
end


%%_Subfunctions_________________________________________________________

function s = phaseRandomize(y)
% PHASERANDOMIZE FT (Theiler 1992) surrogate: preserve the power spectrum,
% randomize the Fourier phases. Destroys any phase relationship with another
% signal (a valid null for phase-locking measures such as PLV that a circular
% shift cannot provide), while keeping the amplitude spectrum of y.
    y = y(:);
    n = numel(y);
    Y = fft(y);
    mag = abs(Y);
    ph  = angle(Y);
    k = floor((n - 1) / 2);              % # freqs to randomize (exclude DC and, if n even, Nyquist)
    rp = 2*pi*rand(k, 1) - pi;
    newph = ph;
    newph(2:k+1)       = rp;             % positive frequencies
    newph(n:-1:n-k+1)  = -rp;           % conjugate-symmetric negative frequencies
    s = real(ifft(mag .* exp(1i * newph)));
end

function minShift = autoCorrelationLength(y, fs)
% AUTOCORRELATIONLENGTH Estimate autocorrelation decay length
%
% Returns the lag (in samples) at which the normalized autocorrelation of y
% drops below 1/e (~0.368), with a floor of 1 second.
%
% Inputs:
%   y  - [T x 1] signal
%   fs - Sampling frequency (Hz)
%
% Outputs:
%   minShift - Minimum shift in samples (integer)

    y = y - mean(y, 'omitnan');
    T = length(y);

    % Compute normalized autocorrelation via FFT (full-length, circular)
    maxLag = min(round(T / 2), round(30 * fs));  % search up to 30 s or T/2
    nfft   = 2^nextpow2(2 * T - 1);
    Yf     = fft(y, nfft);
    acf    = real(ifft(Yf .* conj(Yf)));
    acf    = acf(1:maxLag+1);
    if acf(1) > 0
        acf = acf / acf(1);  % normalize to 1 at lag 0
    end

    % Find first lag where acf drops below 1/e
    threshold = exp(-1);
    below = find(acf < threshold, 1, 'first');

    if isempty(below)
        % Never drops below threshold; use half the search range
        minShift = round(maxLag / 2);
    else
        minShift = below - 1;  % convert 1-indexed to lag in samples
    end

    % Floor: at least 1 second
    minShift = max(minShift, round(fs));
    % Ceiling: no more than T/3
    minShift = min(minShift, round(T / 3));
    minShift = max(minShift, 1);
end

function v = fillNaN(v)
% FILLNAN Linear interpolation of NaN values
%
% Matches the identical helper in plv.m / imagCoherence.m / wpli.m so NaN
% handling is consistent across all exploreFNIRS.coupling measures.
%
% Inputs:
%   v - [T x 1] signal possibly containing NaN values
%
% Outputs:
%   v - [T x 1] signal with NaNs replaced by linear interpolation
    nanIdx = isnan(v);
    if ~any(nanIdx), return; end
    if all(nanIdx), v(:) = 0; return; end
    t = (1:length(v))';
    v(nanIdx) = interp1(t(~nanIdx), v(~nanIdx), t(nanIdx), 'linear', 'extrap');
end
