%% example_qc_pipeline.m - Quality Control Pipeline Tutorial
%
% Demonstrates the fNIRS channel quality assessment tools across different
% devices and sampling rates. Covers:
%
%   1. Loading sample data at different sampling rates
%   2. Individual QC metrics: SCI, cardiac peaks, CoV, Takizawa
%   3. Full pipeline assessment with pf2.qc.pipeline.assess
%   4. What happens at low sampling rates (graceful degradation)
%   5. Applying QC results to reject channels
%   6. Visualization and reporting
%
% Key concept: Not all QC checks work at all sampling rates. SCI and
% cardiac peak detection require cardiac-frequency content (>0.5 Hz),
% which needs at least ~5 Hz sampling. Devices like the fNIR 1200 at
% ~2 Hz cannot resolve cardiac pulsations, so these checks are
% automatically skipped. CoV and Takizawa rules work at any rate >= 2 Hz.
%
% Devices used:
%   fNIR 2000   — 10.0 Hz, 18 channels (full QC suite)
%   fNIR 1200   — 1.96 Hz, 16 channels (low-fs, limited QC)
%   Hitachi 3x5 — 10.0 Hz, 22 channels (demonstrates explicit wavelengths)
%
% Requirements:
%   - processFNIRS2 on path

outDir = '/tmp/qc_pipeline_example';
if ~exist(outDir, 'dir'), mkdir(outDir); end

%% Section 1: Load sample data
%
% We load three different device types to demonstrate how QC adapts.

fprintf('\n========================================\n');
fprintf('Section 1: Load sample data\n');
fprintf('========================================\n\n');

data_2000 = pf2.import.sampleData.fNIR2000();
fprintf('fNIR 2000: fs=%.1f Hz, %d raw columns, %d channels\n', ...
    data_2000.fs, size(data_2000.raw, 2), numel(data_2000.fchMask));

data_1200 = pf2.import.sampleData.fNIR1200();
fprintf('fNIR 1200: fs=%.2f Hz, %d raw columns, %d channels\n', ...
    data_1200.fs, size(data_1200.raw, 2), numel(data_1200.fchMask));

data_hitachi = pf2.import.sampleData.Hitachi_ETG4000_3x5();
fprintf('Hitachi 3x5: fs=%.1f Hz, %d raw columns, %d channels\n', ...
    data_hitachi.fs, size(data_hitachi.raw, 2), numel(data_hitachi.fchMask));

%% Section 2: Scalp Coupling Index (SCI)
%
% SCI measures optode-scalp coupling by cross-correlating cardiac
% pulsations across two wavelengths at each channel. Good contact means
% both wavelengths detect the same heartbeat waveform.
%
% Reference: Pollonini et al. (2014). DOI: 10.1016/j.hearres.2013.11.007
%
% Requirements:
%   - Two wavelength columns per channel (raw intensity data)
%   - Sampling rate high enough to capture cardiac band (default 0.5-2.5 Hz)
%   - Minimum practical fs: ~5 Hz (Nyquist must exceed cardiac band upper limit)
%
% At 2 Hz (Nyquist = 0.98 Hz), the cardiac band cannot be resolved and
% SCI is automatically skipped with a warning.

fprintf('\n========================================\n');
fprintf('Section 2: Scalp Coupling Index (SCI)\n');
fprintf('========================================\n\n');

% --- 2a. SCI on 10 Hz device (works normally) ---
fprintf('--- fNIR 2000 (10 Hz) ---\n');
sciResult_2000 = pf2.qc.sci(data_2000);
fprintf('SCI computed: %d channels, %d good (threshold=%.2f)\n', ...
    numel(sciResult_2000.channels), sum(sciResult_2000.isGood), sciResult_2000.threshold);
fprintf('SCI values: %s\n', mat2str(round(sciResult_2000.sci, 2)));
fprintf('Skipped: %s\n\n', string(sciResult_2000.skipped));

% --- 2b. SCI on 2 Hz device (auto-skipped) ---
fprintf('--- fNIR 1200 (1.96 Hz) ---\n');
sciResult_1200 = pf2.qc.sci(data_1200);
fprintf('Skipped: %s\n', string(sciResult_1200.skipped));
if sciResult_1200.skipped
    fprintf('Reason: %s\n', sciResult_1200.skipReason);
    fprintf('All channels marked as good (not penalized): %s\n\n', ...
        string(all(sciResult_1200.isGood)));
end

% --- 2c. SCI with custom thresholds ---
fprintf('--- Custom thresholds (fNIR 2000) ---\n');
sciStrict = pf2.qc.sci(data_2000, 'Threshold', 0.9);
sciLenient = pf2.qc.sci(data_2000, 'Threshold', 0.5);
fprintf('Strict (0.9):  %d/%d good\n', sum(sciStrict.isGood), numel(sciStrict.channels));
fprintf('Lenient (0.5): %d/%d good\n\n', sum(sciLenient.isGood), numel(sciLenient.channels));

%% Section 3: Power Spectrum & Cardiac Peak Detection
%
% Computes PSD via Welch's method and looks for physiological peaks:
%   - Cardiac:      0.5 - 2.5 Hz  (~60-150 bpm heart rate)
%   - Respiratory:  0.1 - 0.5 Hz  (~6-30 breaths/min)
%   - Mayer wave:   0.05 - 0.15 Hz (blood pressure oscillation)
%
% A clear cardiac peak in the PSD confirms the channel is measuring real
% hemodynamic signal, not noise. At low sampling rates, cardiac frequencies
% are above Nyquist and cannot be detected.

fprintf('\n========================================\n');
fprintf('Section 3: Power Spectrum Analysis\n');
fprintf('========================================\n\n');

% --- 3a. PSD on 10 Hz device ---
fprintf('--- fNIR 2000 (10 Hz) ---\n');
psdResult_2000 = pf2.qc.powerSpectrum(data_2000, 'Signal', 'raw');
fprintf('PSD computed: %d channels, freq range [%.2f, %.2f] Hz\n', ...
    numel(psdResult_2000.channels), min(psdResult_2000.freqs), max(psdResult_2000.freqs));
fprintf('Cardiac detected: %d/%d channels\n', ...
    sum(psdResult_2000.cardiac.detected), numel(psdResult_2000.channels));
fprintf('Respiratory detected: %d/%d channels\n', ...
    sum(psdResult_2000.respiratory.detected), numel(psdResult_2000.channels));
fprintf('Mayer detected: %d/%d channels\n\n', ...
    sum(psdResult_2000.mayer.detected), numel(psdResult_2000.channels));

% --- 3b. PSD on 2 Hz device ---
fprintf('--- fNIR 1200 (1.96 Hz) ---\n');
psdResult_1200 = pf2.qc.powerSpectrum(data_1200, 'Signal', 'raw');
fprintf('PSD computed: %d channels, freq range [%.2f, %.2f] Hz\n', ...
    numel(psdResult_1200.channels), min(psdResult_1200.freqs), max(psdResult_1200.freqs));
fprintf('Cardiac detected: %d/%d channels\n', ...
    sum(psdResult_1200.cardiac.detected), numel(psdResult_1200.channels));
fprintf('Note: Cardiac band [0.5, 2.5] Hz is capped at Nyquist (%.2f Hz).\n', ...
    data_1200.fs / 2);
fprintf('At this rate, cardiac frequency (~1 Hz) is near or above Nyquist.\n');
fprintf('Respiratory and Mayer wave bands are still detectable:\n');
fprintf('  Respiratory detected: %d/%d channels\n', ...
    sum(psdResult_1200.respiratory.detected), numel(psdResult_1200.channels));
fprintf('  Mayer detected: %d/%d channels\n\n', ...
    sum(psdResult_1200.mayer.detected), numel(psdResult_1200.channels));

% --- 3c. Visualize PSD comparison ---
fig1 = figure('Visible', 'off', 'Position', [100, 100, 900, 400]);

subplot(1,2,1);
plot(psdResult_2000.freqs, 10*log10(psdResult_2000.psd(:,1)), 'b-', 'LineWidth', 1.2);
xlabel('Frequency (Hz)'); ylabel('Power (dB)');
title(sprintf('fNIR 2000 (10 Hz) — Ch 1'));
xline(0.5, '--r', 'Cardiac band', 'LabelOrientation', 'horizontal');
xline(2.5, '--r'); xlim([0, 5]);

subplot(1,2,2);
plot(psdResult_1200.freqs, 10*log10(psdResult_1200.psd(:,1)), 'r-', 'LineWidth', 1.2);
xlabel('Frequency (Hz)'); ylabel('Power (dB)');
title(sprintf('fNIR 1200 (2 Hz) — Ch 1'));
xline(0.5, '--r', 'Cardiac band', 'LabelOrientation', 'horizontal');
xlim([0, 1]);

sgtitle('PSD Comparison: 10 Hz vs 2 Hz Sampling');
saveas(fig1, fullfile(outDir, 'psd_comparison.png'));
close(fig1);
fprintf('Saved PSD comparison to %s\n\n', fullfile(outDir, 'psd_comparison.png'));

%% Section 4: Coefficient of Variation (CoV)
%
% CoV = std(signal) / |mean(signal)| per channel wavelength.
%
% High CoV means noisy or unstable signal. This metric works at ANY
% sampling rate since it only depends on signal amplitude, not frequency.
%
% Default threshold: 0.10 (10% variation relative to mean intensity).

fprintf('\n========================================\n');
fprintf('Section 4: Coefficient of Variation\n');
fprintf('========================================\n\n');

% CoV is computed inside assess(), but we can demonstrate the concept:
nCh_2000 = numel(data_2000.fchMask);
nCh_1200 = numel(data_1200.fchMask);

fprintf('--- fNIR 2000 (10 Hz) ---\n');
cov_2000 = zeros(1, nCh_2000);
for ch = 1:nCh_2000
    cols = (ch-1)*2 + (1:2);
    cols = cols(cols <= size(data_2000.raw, 2));
    chMeans = mean(data_2000.raw(:, cols), 1);
    chStds = std(data_2000.raw(:, cols), 0, 1);
    chMeans(chMeans == 0) = 1;
    cov_2000(ch) = mean(chStds ./ abs(chMeans));
end
fprintf('CoV range: [%.4f, %.4f]\n', min(cov_2000), max(cov_2000));
fprintf('Channels above 0.10: %d/%d\n\n', sum(cov_2000 > 0.1), nCh_2000);

fprintf('--- fNIR 1200 (1.96 Hz) ---\n');
cov_1200 = zeros(1, nCh_1200);
nWl_1200 = floor(size(data_1200.raw, 2) / nCh_1200);
for ch = 1:nCh_1200
    cols = (ch-1)*nWl_1200 + (1:nWl_1200);
    cols = cols(cols <= size(data_1200.raw, 2));
    chMeans = mean(data_1200.raw(:, cols), 1);
    chStds = std(data_1200.raw(:, cols), 0, 1);
    chMeans(chMeans == 0) = 1;
    cov_1200(ch) = mean(chStds ./ abs(chMeans));
end
fprintf('CoV range: [%.4f, %.4f]\n', min(cov_1200), max(cov_1200));
fprintf('Channels above 0.10: %d/%d\n\n', sum(cov_1200 > 0.1), nCh_1200);

%% Section 5: Takizawa Rejection Rules
%
% Four empirical rules from Takizawa et al. (2008, 2014) for identifying
% bad channels based on hemoglobin signal characteristics:
%
%   Rule 1 (High-freq noise): SD of HbO/HbR >> SD of HbTotal in 15s window
%   Rule 2 (Low-freq noise):  High anti-correlation + similar amplitude
%   Rule 3 (Zero variance):   Flat HbO and HbR (dead channel)
%   Rule 4 (Body movement):   Large sudden jumps in HbO/HbTotal over 2s
%
% Requirements:
%   - Needs HbO, HbR, HbTotal (internally computed from raw inside assess)
%   - Minimum ~10 seconds of data
%   - Works at any sampling rate >= 2 Hz (window sizes adapt to fs)
%
% The assess pipeline internally converts raw -> OD -> Hb before running
% Takizawa, so you don't need to process the data first.

fprintf('\n========================================\n');
fprintf('Section 5: Takizawa Rejection Rules\n');
fprintf('========================================\n\n');

% Takizawa is run as part of the pipeline; we demonstrate by running
% assess() with just the Takizawa check.

fprintf('--- fNIR 2000 (10 Hz) ---\n');
rpt_tk_2000 = pf2.qc.pipeline.assess(data_2000, 'Checks', {'takizawa'});
fprintf('Takizawa pass: %d/%d channels\n', sum(rpt_tk_2000.takizawa.pass), ...
    numel(rpt_tk_2000.channels));
ruleNames = rpt_tk_2000.takizawa.ruleNames;
for ri = 1:4
    nFail = sum(~rpt_tk_2000.takizawa.rules(ri, :));
    fprintf('  Rule %d (%s): %d failures\n', ri, ruleNames{ri}, nFail);
end
fprintf('\n');

fprintf('--- fNIR 1200 (1.96 Hz) ---\n');
rpt_tk_1200 = pf2.qc.pipeline.assess(data_1200, 'Checks', {'takizawa'});
fprintf('Takizawa pass: %d/%d channels\n', sum(rpt_tk_1200.takizawa.pass), ...
    numel(rpt_tk_1200.channels));
for ri = 1:4
    nFail = sum(~rpt_tk_1200.takizawa.rules(ri, :));
    fprintf('  Rule %d (%s): %d failures\n', ri, ruleNames{ri}, nFail);
end
fprintf('\n');

%% Section 6: Full Pipeline Assessment
%
% pf2.qc.pipeline.assess() runs all applicable checks at once and
% produces a comprehensive report. It automatically handles low sampling
% rates by skipping checks that cannot be computed.
%
% Default checks: {'sci', 'cardiac', 'cov', 'takizawa'}
%
% At 10 Hz: all four checks run.
% At 2 Hz:  SCI and cardiac are skipped; CoV and Takizawa still run.

fprintf('\n========================================\n');
fprintf('Section 6: Full Pipeline Assessment\n');
fprintf('========================================\n\n');

% --- 6a. Full assessment on 10 Hz data ---
fprintf('--- fNIR 2000 (10 Hz): Full assessment ---\n');
report_2000 = pf2.qc.pipeline.assess(data_2000);
fprintf('Overall: %d/%d channels passed\n', sum(report_2000.pass), ...
    numel(report_2000.channels));

% Print structured report
pf2.qc.pipeline.report(report_2000);

% --- 6b. Full assessment on 2 Hz data ---
fprintf('--- fNIR 1200 (1.96 Hz): Full assessment ---\n');
report_1200 = pf2.qc.pipeline.assess(data_1200);
fprintf('Overall: %d/%d channels passed\n', sum(report_1200.pass), ...
    numel(report_1200.channels));

pf2.qc.pipeline.report(report_1200);

%% Section 7: Applying QC Results
%
% pf2.qc.pipeline.apply() updates data.fchMask based on the QC report:
%   - Channels failing QC → fchMask set to 0 (rejected)
%   - Previously rejected channels stay rejected (AND logic, never promotes)
%   - Optionally: 'MarkNoisy', true → marginal channels set to 0.5
%
% You can also select which checks to apply:
%   apply(data, report, 'Checks', {'sci', 'cov'})  — only these two

fprintf('\n========================================\n');
fprintf('Section 7: Applying QC Results\n');
fprintf('========================================\n\n');

% --- 7a. Apply all checks ---
fprintf('--- Before QC ---\n');
fprintf('fchMask: %s\n', mat2str(data_2000.fchMask));

data_qc = pf2.qc.pipeline.apply(data_2000, report_2000);
fprintf('\n--- After QC (all checks) ---\n');
fprintf('fchMask: %s\n', mat2str(data_qc.fchMask));
fprintf('Rejected: %d channels\n', sum(data_qc.fchMask == 0));

% --- 7b. Apply only selected checks ---
data_sci_only = pf2.qc.pipeline.apply(data_2000, report_2000, 'Checks', {'sci'});
fprintf('\n--- After QC (SCI only) ---\n');
fprintf('fchMask: %s\n', mat2str(data_sci_only.fchMask));
fprintf('Rejected: %d channels\n', sum(data_sci_only.fchMask == 0));

% --- 7c. Mark noisy (0.5) instead of rejecting (0) ---
data_noisy = pf2.qc.pipeline.apply(data_2000, report_2000, 'MarkNoisy', true);
nNoisy = sum(data_noisy.fchMask == 0.5);
nRejected = sum(data_noisy.fchMask == 0);
fprintf('\n--- After QC (MarkNoisy mode) ---\n');
fprintf('Good: %d, Noisy: %d, Rejected: %d\n', ...
    sum(data_noisy.fchMask == 1), nNoisy, nRejected);

% --- 7d. Apply on low-fs data (skipped checks don't penalize) ---
fprintf('\n--- fNIR 1200 (2 Hz) after QC ---\n');
data_1200_qc = pf2.qc.pipeline.apply(data_1200, report_1200);
fprintf('fchMask: %s\n', mat2str(data_1200_qc.fchMask));
fprintf('Rejected: %d channels (only from CoV + Takizawa)\n', ...
    sum(data_1200_qc.fchMask == 0));

%% Section 8: Visualization
%
% pf2.qc.pipeline.plotReport() creates a 4-panel dashboard:
%   Top-left:     SCI bar chart (or "Skipped" for low-fs)
%   Top-right:    Cardiac SNR bar chart (or "Skipped")
%   Bottom-left:  CoV bar chart
%   Bottom-right: Takizawa rule heatmap
%
% pf2.qc.plotQuality() can also plot individual metrics.

fprintf('\n========================================\n');
fprintf('Section 8: Visualization\n');
fprintf('========================================\n\n');

% --- 8a. Full dashboard — 10 Hz device ---
fig2 = pf2.qc.pipeline.plotReport(report_2000, 'Visible', 'off', ...
    'Title', 'fNIR 2000 (10 Hz)', ...
    'SavePath', fullfile(outDir, 'qc_dashboard_10hz.png'));
close(fig2);
fprintf('Saved 10 Hz dashboard to %s\n', fullfile(outDir, 'qc_dashboard_10hz.png'));

% --- 8b. Full dashboard — 2 Hz device ---
fig3 = pf2.qc.pipeline.plotReport(report_1200, 'Visible', 'off', ...
    'Title', 'fNIR 1200 (2 Hz)', ...
    'SavePath', fullfile(outDir, 'qc_dashboard_2hz.png'));
close(fig3);
fprintf('Saved 2 Hz dashboard to %s\n', fullfile(outDir, 'qc_dashboard_2hz.png'));

% --- 8c. Individual SCI bar chart ---
fig4 = pf2.qc.plotQuality(data_2000, 'Type', 'sci', 'Visible', 'off');
saveas(fig4, fullfile(outDir, 'sci_barchart.png'));
close(fig4);
fprintf('Saved SCI bar chart to %s\n', fullfile(outDir, 'sci_barchart.png'));

% --- 8d. PSD overlay plot ---
fig5 = pf2.qc.plotQuality(data_2000, 'Type', 'psd', 'Visible', 'off');
saveas(fig5, fullfile(outDir, 'psd_overlay.png'));
close(fig5);
fprintf('Saved PSD overlay to %s\n', fullfile(outDir, 'psd_overlay.png'));

%% Section 9: Customizing for Your Experiment
%
% Default thresholds work well for typical lab recordings, but you may
% need to adjust for your specific setup:
%
%   SCIThreshold   — Lower (0.5) for noisy environments, higher (0.9)
%                    for strict quality. Default: 0.75
%   CardiacSNR     — Lower (2) catches weak cardiac peaks.
%                    Higher (5) requires strong signal. Default: 3
%   CoVThreshold   — Higher (0.2) for variable-intensity devices.
%                    Lower (0.05) for clinical quality. Default: 0.10
%   CardiacBand    — Narrow [0.8, 1.5] for known resting-state HR.
%                    Wide [0.5, 3.0] for exercising subjects. Default: [0.5, 2.5]
%
% For low-frequency devices (< 5 Hz):
%   - SCI and cardiac checks are automatically skipped
%   - CoV and Takizawa still provide channel quality information
%   - Consider using 'Checks', {'cov', 'takizawa'} to run only what applies

fprintf('\n========================================\n');
fprintf('Section 9: Custom Thresholds\n');
fprintf('========================================\n\n');

% Strict QC for publication-quality data
reportStrict = pf2.qc.pipeline.assess(data_2000, ...
    'SCIThreshold', 0.85, ...
    'CardiacSNR', 5, ...
    'CoVThreshold', 0.05);
fprintf('Strict thresholds: %d/%d pass\n', ...
    sum(reportStrict.pass), numel(reportStrict.channels));

% Lenient QC for exploratory analysis
reportLenient = pf2.qc.pipeline.assess(data_2000, ...
    'SCIThreshold', 0.5, ...
    'CardiacSNR', 2, ...
    'CoVThreshold', 0.2);
fprintf('Lenient thresholds: %d/%d pass\n', ...
    sum(reportLenient.pass), numel(reportLenient.channels));

% Low-fs device: only run applicable checks
reportLowFs = pf2.qc.pipeline.assess(data_1200, ...
    'Checks', {'cov', 'takizawa'}, ...
    'CoVThreshold', 0.15);
fprintf('Low-fs (CoV+Takizawa only): %d/%d pass\n', ...
    sum(reportLowFs.pass), numel(reportLowFs.channels));

%% Section 10: QC in a Processing Workflow
%
% Typical workflow: import → QC → process → analyze.
% QC is done on raw data BEFORE signal processing.

fprintf('\n========================================\n');
fprintf('Section 10: Full Workflow Example\n');
fprintf('========================================\n\n');

% Step 1: Import
raw = pf2.import.sampleData.fNIR2000();
fprintf('1. Imported: %d channels, fs=%.0f Hz\n', numel(raw.fchMask), raw.fs);

% Step 2: QC assessment
qcReport = pf2.qc.pipeline.assess(raw);
fprintf('2. QC: %d/%d channels passed\n', sum(qcReport.pass), numel(qcReport.channels));

% Step 3: Apply QC (reject bad channels)
raw = pf2.qc.pipeline.apply(raw, qcReport);
fprintf('3. Applied: fchMask now has %d good channels\n', sum(raw.fchMask > 0));

% Step 4: Process
processed = processFNIRS2(raw);
fprintf('4. Processed successfully\n');

% Step 5: The QC report is stored on the data for traceability
fprintf('5. QC report stored: data.qcReport.checkNames = %s\n', ...
    strjoin(raw.qcReport.checkNames, ', '));

fprintf('\n=== QC Pipeline Tutorial Complete ===\n');
fprintf('Output saved to: %s\n', outDir);
