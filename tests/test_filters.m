function results = test_filters()
% TEST_FILTERS Verify bpf, lpf, and hpf numerical stability and correctness
%
% Tests:
%   1. Basic passband: signal within passband passes through
%   2. Stopband: signal outside passband is attenuated
%   3. Numerical stability: extreme normalized frequencies don't amplify
%   4. NaN handling: NaN-padded data handled gracefully
%   5. Row vector input: returns row vector output
%   6. Multi-channel: filters each column independently
%
% Usage:
%   results = test_filters()    % run all tests, returns struct
%   test_filters()              % run all tests, print results

fprintf('\n=== Filter Stability Tests ===\n\n');

nPass = 0;
nFail = 0;
nTests = 0;
failures = {};

    function pass(name)
        nTests = nTests + 1;
        nPass = nPass + 1;
        fprintf('  PASS: %s\n', name);
    end

    function fail(name, msg)
        nTests = nTests + 1;
        nFail = nFail + 1;
        fprintf('  FAIL: %s — %s\n', name, msg);
        failures{end+1} = struct('name', name, 'msg', msg);
    end

% =====================================================================
%  Test parameters
% =====================================================================
fs_normal = 10;        % Normal sampling rate (Hz)
fs_slow   = 5.208;     % Dataset I sampling rate (Hz)
nSamples  = 6000;      % ~10 min at 10 Hz, ~19 min at 5.2 Hz
t_normal  = (0:nSamples-1)' / fs_normal;
t_slow    = (0:nSamples-1)' / fs_slow;
trim      = 500;       % Samples to trim from edges (filtfilt transients)

% =====================================================================
%  BPF Tests
% =====================================================================
fprintf('--- BPF (Bandpass) ---\n');

% 1. Passband signal passes through (trim edges to avoid filtfilt transients)
sig = sin(2*pi*0.1*t_normal);  % 0.1 Hz — within 0.01-0.5 Hz
filtered = bpf(sig, 4, fs_normal, 0.01, 0.5);
ratio = max(abs(filtered(trim:end-trim))) / max(abs(sig(trim:end-trim)));
if ratio > 0.5 && ratio < 1.5
    pass('BPF passband preserves signal (10 Hz fs)');
else
    fail('BPF passband preserves signal (10 Hz fs)', ...
        sprintf('amplitude ratio = %.4f, expected ~1.0', ratio));
end

% 2. Stopband signal attenuated (trim edges)
sig_fast = sin(2*pi*3*t_normal);  % 3 Hz — well above 0.5 Hz cutoff
filtered = bpf(sig_fast, 4, fs_normal, 0.01, 0.5);
ratio = max(abs(filtered(trim:end-trim))) / max(abs(sig_fast(trim:end-trim)));
if ratio < 0.2
    pass('BPF stopband attenuates signal (10 Hz fs)');
else
    fail('BPF stopband attenuates signal (10 Hz fs)', ...
        sprintf('amplitude ratio = %.4f, expected < 0.2', ratio));
end

% 3. Numerical stability at slow sampling rate (Dataset I: 5.208 Hz)
sig_slow = sin(2*pi*0.1*t_slow) + 0.5*sin(2*pi*0.05*t_slow);
filtered = bpf(sig_slow, 4, fs_slow, 0.01, 0.5);
ratio = max(abs(filtered)) / max(abs(sig_slow));
if ratio < 2.0
    pass('BPF stable at 5.2 Hz fs (0.01 Hz cutoff)');
else
    fail('BPF stable at 5.2 Hz fs (0.01 Hz cutoff)', ...
        sprintf('amplitude ratio = %.4f, expected < 2.0', ratio));
end

% 4. No amplification beyond input range (key stability test)
rng(42);
sig_noise = randn(nSamples, 1);
filtered = bpf(sig_noise, 4, fs_slow, 0.01, 0.5);
ratio = max(abs(filtered)) / max(abs(sig_noise));
if ratio < 3.0
    pass('BPF noise amplification bounded (5.2 Hz fs)');
else
    fail('BPF noise amplification bounded (5.2 Hz fs)', ...
        sprintf('amplitude ratio = %.4f, expected < 3.0', ratio));
end

% 5. Multi-channel data
sig_multi = [sin(2*pi*0.1*t_normal), cos(2*pi*0.1*t_normal), randn(nSamples,1)];
filtered = bpf(sig_multi, 4, fs_normal, 0.01, 0.5);
if size(filtered, 1) == nSamples && size(filtered, 2) == 3
    pass('BPF multi-channel preserves dimensions');
else
    fail('BPF multi-channel preserves dimensions', ...
        sprintf('got [%d,%d], expected [%d,3]', size(filtered,1), size(filtered,2), nSamples));
end

% 6. NaN handling
sig_nan = sig;
sig_nan(1:100) = NaN;
sig_nan(end-50:end) = NaN;
filtered = bpf(sig_nan, 4, fs_normal, 0.01, 0.5);
if all(isnan(filtered(1:100))) && all(isnan(filtered(end-50:end)))
    pass('BPF preserves NaN regions');
else
    fail('BPF preserves NaN regions', 'NaN regions not preserved');
end

% 7. Row vector input
sig_row = sin(2*pi*0.1*t_normal)';
filtered = bpf(sig_row, 4, fs_normal, 0.01, 0.5);
if size(filtered, 1) == 1 && size(filtered, 2) == nSamples
    pass('BPF row vector returns row vector');
else
    fail('BPF row vector returns row vector', ...
        sprintf('got [%d,%d]', size(filtered,1), size(filtered,2)));
end

% 8. Extreme case: very low highpass on very slow fs
sig_slow2 = sin(2*pi*0.05*t_slow) + 0.1*randn(nSamples, 1);
filtered = bpf(sig_slow2, 4, fs_slow, 0.005, 0.3);
max_out = max(abs(filtered));
max_in = max(abs(sig_slow2));
if max_out < 5 * max_in
    pass('BPF extreme low-freq stable (0.005 Hz on 5.2 Hz fs)');
else
    fail('BPF extreme low-freq stable (0.005 Hz on 5.2 Hz fs)', ...
        sprintf('max output %.2f vs input %.2f (ratio %.1f)', max_out, max_in, max_out/max_in));
end

% =====================================================================
%  LPF Tests
% =====================================================================
fprintf('\n--- LPF (Lowpass) ---\n');

% Test Butterworth mode (ft=3) — this is the one that was unstable
% 1. Passband signal passes through
sig = sin(2*pi*0.05*t_normal);  % 0.05 Hz — well below 0.1 Hz cutoff
filtered = lpf(sig, 3, fs_normal, 0.1, 4);
ratio = max(abs(filtered)) / max(abs(sig));
if ratio > 0.5 && ratio < 1.5
    pass('LPF(butter) passband preserves signal');
else
    fail('LPF(butter) passband preserves signal', ...
        sprintf('amplitude ratio = %.4f', ratio));
end

% 2. Stopband attenuation (trim edges)
sig_fast = sin(2*pi*2*t_normal);  % 2 Hz — above 0.1 Hz cutoff
filtered = lpf(sig_fast, 3, fs_normal, 0.1, 4);
ratio = max(abs(filtered(trim:end-trim))) / max(abs(sig_fast(trim:end-trim)));
if ratio < 0.1
    pass('LPF(butter) stopband attenuates signal');
else
    fail('LPF(butter) stopband attenuates signal', ...
        sprintf('amplitude ratio = %.4f', ratio));
end

% 3. Stability at slow sampling rate
sig_slow = sin(2*pi*0.03*t_slow);
filtered = lpf(sig_slow, 3, fs_slow, 0.1, 4);
ratio = max(abs(filtered)) / max(abs(sig_slow));
if ratio < 2.0
    pass('LPF(butter) stable at 5.2 Hz fs');
else
    fail('LPF(butter) stable at 5.2 Hz fs', ...
        sprintf('amplitude ratio = %.4f', ratio));
end

% 4. Noise amplification bounded
rng(42);
sig_noise = randn(nSamples, 1);
filtered = lpf(sig_noise, 3, fs_slow, 0.1, 4);
ratio = max(abs(filtered)) / max(abs(sig_noise));
if ratio < 3.0
    pass('LPF(butter) noise amplification bounded');
else
    fail('LPF(butter) noise amplification bounded', ...
        sprintf('amplitude ratio = %.4f', ratio));
end

% 5. FIR mode (ft=1) still works
sig = sin(2*pi*0.05*t_normal);
filtered = lpf(sig, 1, fs_normal, 0.5, 30);
if all(isfinite(filtered))
    pass('LPF(FIR) produces finite output');
else
    fail('LPF(FIR) produces finite output', 'NaN/Inf in output');
end

% 6. NaN handling (Butterworth)
sig_nan = sin(2*pi*0.05*t_normal);
sig_nan(1:50) = NaN;
filtered = lpf(sig_nan, 3, fs_normal, 0.1, 4);
if all(isnan(filtered(1:50)))
    pass('LPF NaN regions preserved');
else
    fail('LPF NaN regions preserved', 'NaN regions not preserved');
end

% =====================================================================
%  HPF Tests
% =====================================================================
fprintf('\n--- HPF (Highpass) ---\n');

% 1. Passband signal passes through (trim edges for filtfilt transients)
sig = sin(2*pi*0.5*t_normal);  % 0.5 Hz — well above 0.01 Hz cutoff
filtered = hpf(sig, 4, fs_normal, 0.01);
ratio = max(abs(filtered(trim:end-trim))) / max(abs(sig(trim:end-trim)));
if ratio > 0.5 && ratio < 1.5
    pass('HPF passband preserves signal (10 Hz fs)');
else
    fail('HPF passband preserves signal (10 Hz fs)', ...
        sprintf('amplitude ratio = %.4f', ratio));
end

% 2. Stopband signal attenuated (DC / very low freq)
sig_dc = ones(nSamples, 1) + 0.001*sin(2*pi*0.001*t_normal);
filtered = hpf(sig_dc, 4, fs_normal, 0.01);
ratio = max(abs(filtered)) / max(abs(sig_dc));
if ratio < 0.1
    pass('HPF removes DC offset');
else
    fail('HPF removes DC offset', ...
        sprintf('amplitude ratio = %.4f, expected < 0.1', ratio));
end

% 3. Numerical stability at slow sampling rate (trim edges)
sig_slow = sin(2*pi*0.1*t_slow);
filtered = hpf(sig_slow, 4, fs_slow, 0.01);
ratio = max(abs(filtered(trim:end-trim))) / max(abs(sig_slow(trim:end-trim)));
if ratio < 2.0
    pass('HPF stable at 5.2 Hz fs (0.01 Hz cutoff)');
else
    fail('HPF stable at 5.2 Hz fs (0.01 Hz cutoff)', ...
        sprintf('amplitude ratio = %.4f', ratio));
end

% 4. Noise amplification bounded
rng(42);
sig_noise = randn(nSamples, 1);
filtered = hpf(sig_noise, 4, fs_slow, 0.01);
ratio = max(abs(filtered)) / max(abs(sig_noise));
if ratio < 3.0
    pass('HPF noise amplification bounded (5.2 Hz fs)');
else
    fail('HPF noise amplification bounded (5.2 Hz fs)', ...
        sprintf('amplitude ratio = %.4f', ratio));
end

% 5. Multi-channel
sig_multi = [sin(2*pi*0.5*t_normal), cos(2*pi*0.5*t_normal)];
filtered = hpf(sig_multi, 4, fs_normal, 0.01);
if size(filtered, 1) == nSamples && size(filtered, 2) == 2
    pass('HPF multi-channel preserves dimensions');
else
    fail('HPF multi-channel preserves dimensions', ...
        sprintf('got [%d,%d]', size(filtered,1), size(filtered,2)));
end

% 6. Row vector input
sig_row = sin(2*pi*0.5*t_normal)';
filtered = hpf(sig_row, 4, fs_normal, 0.01);
if size(filtered, 1) == 1 && size(filtered, 2) == nSamples
    pass('HPF row vector returns row vector');
else
    fail('HPF row vector returns row vector', ...
        sprintf('got [%d,%d]', size(filtered,1), size(filtered,2)));
end

% 7. NaN handling
sig_nan = sin(2*pi*0.5*t_normal);
sig_nan(end-100:end) = NaN;
filtered = hpf(sig_nan, 4, fs_normal, 0.01);
if all(isnan(filtered(end-100:end)))
    pass('HPF NaN regions preserved');
else
    fail('HPF NaN regions preserved', 'NaN regions not preserved');
end

% =====================================================================
%  Cross-filter consistency test
% =====================================================================
fprintf('\n--- Cross-filter consistency ---\n');

% BPF(0.01-0.5) should approximate HPF(0.01) + LPF(0.5) for in-band signal
sig = sin(2*pi*0.1*t_normal) + 0.3*sin(2*pi*0.2*t_normal);
bp_out = bpf(sig, 4, fs_normal, 0.01, 0.5);
hp_out = hpf(sig, 4, fs_normal, 0.01);
lp_out = lpf(hp_out, 3, fs_normal, 0.5, 4);
% Trim edges (transient effects)
trim = 500;
bp_trim = bp_out(trim:end-trim);
lp_trim = lp_out(trim:end-trim);
corr_val = corrcoef(bp_trim, lp_trim);
r = corr_val(1,2);
if r > 0.95
    pass(sprintf('BPF ≈ HPF+LPF for in-band signal (r=%.4f)', r));
else
    fail('BPF ≈ HPF+LPF for in-band signal', ...
        sprintf('correlation r = %.4f, expected > 0.95', r));
end

% =====================================================================
%  Summary
% =====================================================================
fprintf('\n=== Results: %d/%d passed', nPass, nTests);
if nFail > 0
    fprintf(', %d FAILED', nFail);
end
fprintf(' ===\n\n');

if nFail > 0
    fprintf('Failures:\n');
    for i = 1:length(failures)
        fprintf('  %d. %s: %s\n', i, failures{i}.name, failures{i}.msg);
    end
    fprintf('\n');
end

if nargout > 0
    results.nPass = nPass;
    results.nFail = nFail;
    results.nTests = nTests;
    results.failures = failures;
end

end
