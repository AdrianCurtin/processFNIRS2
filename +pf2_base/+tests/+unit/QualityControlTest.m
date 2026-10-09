classdef QualityControlTest < matlab.unittest.TestCase
    % QUALITYCONTROLTEST Unit tests for pf2.qc signal quality functions
    %
    %   Tests cover:
    %     - SCI (Scalp Coupling Index): cardiac correlation, dead channels,
    %       threshold classification, explicit wavelength params, output dims
    %     - Power Spectrum: known sinusoid peaks, cardiac/respiratory detection,
    %       noise-only, HbO signal, channel subset, output dimensions,
    %       all channels masked, short recordings, device raw-column mapping
    %     - plotQuality: SCI bar chart, PSD overlay, PSD tiled
    %
    %   Example:
    %       results = runtests('pf2_base.tests.unit.QualityControlTest');
    %       disp(results);

    properties
        dataWithHeart     % Synthetic data with heartbeat
        dataNoHeart       % Synthetic data without heartbeat
        dataWithResp      % Synthetic data with heartbeat + respiration
    end

    methods (TestClassSetup)
        function createTestData(testCase)
            % Ensure functions/ is on the path (for bpf, etc.)
            % mfilename path: +pf2_base/+tests/+unit/QualityControlTest
            % Need 4 fileparts to get to repo root
            rootPath = fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))));
            addpath(rootPath);
            addpath(fullfile(rootPath, 'functions'));

            % Generate synthetic data with known properties
            testCase.dataWithHeart = pf2_base.tests.synthetic.generateFNIRS( ...
                'duration', 60, ...
                'fs', 10, ...
                'nChannels', 4, ...
                'addHeartbeat', true, ...
                'heartRate', 70, ...
                'heartAmplitude', 0.01, ...
                'noiseLevel', 0.001, ...
                'seed', 42);

            testCase.dataNoHeart = pf2_base.tests.synthetic.generateFNIRS( ...
                'duration', 60, ...
                'fs', 10, ...
                'nChannels', 4, ...
                'addHeartbeat', false, ...
                'noiseLevel', 0.02, ...
                'seed', 43);

            testCase.dataWithResp = pf2_base.tests.synthetic.generateFNIRS( ...
                'duration', 120, ...
                'fs', 10, ...
                'nChannels', 4, ...
                'addHeartbeat', true, ...
                'heartRate', 70, ...
                'heartAmplitude', 0.01, ...
                'addRespiration', true, ...
                'respRate', 15, ...
                'respAmplitude', 0.01, ...
                'noiseLevel', 0.001, ...
                'seed', 44);
        end
    end


    %% SCI Tests
    methods (Test)

        function testSCIWithCardiacSignal(testCase)
            % Synthetic data with heartbeat should yield high SCI
            result = pf2.qc.sci(testCase.dataWithHeart);

            testCase.verifyGreaterThan(mean(result.sci), 0.7, ...
                'Mean SCI should be high (>0.7) when heartbeat is present.');
        end

        function testSCIWithoutCardiacSignal(testCase)
            % Noise-only data should yield low SCI
            result = pf2.qc.sci(testCase.dataNoHeart);

            testCase.verifyLessThan(mean(result.sci), 0.5, ...
                'Mean SCI should be low (<0.5) without heartbeat.');
        end

        function testSCIDeadChannel(testCase)
            % Set one channel to constant — SCI should be 0
            data = testCase.dataWithHeart;
            % Channel 1 uses columns 1 and 2 (alternating wavelengths)
            data.raw(:, 1) = 1000;
            data.raw(:, 2) = 1000;

            result = pf2.qc.sci(data);

            testCase.verifyEqual(result.sci(1), 0, ...
                'Dead channel (constant signal) should have SCI = 0.');
            % Other channels should still have valid SCI
            testCase.verifyGreaterThan(result.sci(2), 0, ...
                'Non-dead channels should have SCI > 0.');
        end

        function testSCIThresholdClassification(testCase)
            % Verify isGood matches sci >= threshold
            threshold = 0.6;
            result = pf2.qc.sci(testCase.dataWithHeart, 'Threshold', threshold);

            expected = result.sci >= threshold;
            testCase.verifyEqual(result.isGood, expected, ...
                'isGood should match sci >= threshold.');
            testCase.verifyEqual(result.threshold, threshold);
        end

        function testSCIExplicitWavelengthParams(testCase)
            % Pass Wavelengths and ChannelNumbers manually
            data = testCase.dataWithHeart;
            nCh = data.info.synthetic.nChannels;
            wl = repmat([730, 850], 1, nCh);
            chNums = repelem(1:nCh, 2);

            result = pf2.qc.sci(data, 'Wavelengths', wl, 'ChannelNumbers', chNums);

            testCase.verifyEqual(numel(result.sci), nCh);
            testCase.verifyGreaterThan(mean(result.sci), 0.7);
        end

        function testSCIOutputDimensions(testCase)
            % Verify output shapes
            result = pf2.qc.sci(testCase.dataWithHeart);
            nCh = testCase.dataWithHeart.info.synthetic.nChannels;

            testCase.verifySize(result.sci, [1, nCh]);
            testCase.verifySize(result.isGood, [1, nCh]);
            testCase.verifySize(result.channels, [1, nCh]);
            testCase.verifyEqual(result.fs, testCase.dataWithHeart.fs);
        end

    end


    %% Power Spectrum Tests
    methods (Test)

        function testPSDKnownSinusoid(testCase)
            % Single-frequency signal should have peak at correct frequency
            fs = 100;
            t = (0:1/fs:30)';
            targetFreq = 2.5;
            sig = sin(2 * pi * targetFreq * t);

            % Build minimal data struct
            data = struct();
            data.fs = fs;
            data.HbO = sig;
            data.fchMask = 1;

            result = pf2.qc.powerSpectrum(data, 'Signal', 'HbO', ...
                'FreqRange', [0, fs/2], 'DetectPeaks', false);

            % Find peak frequency in PSD
            [~, peakIdx] = max(result.psd);
            peakFreq = result.freqs(peakIdx);

            testCase.verifyEqual(peakFreq, targetFreq, 'AbsTol', 0.2, ...
                'Peak frequency should match the injected sinusoid.');
        end

        function testPSDCardiacPeakDetection(testCase)
            % Data with heartbeat should show cardiac peak near 1 Hz
            result = pf2.qc.powerSpectrum(testCase.dataWithHeart, ...
                'Signal', 'raw', 'DetectPeaks', true);

            expectedFreq = testCase.dataWithHeart.info.synthetic.heartRate / 60;

            % At least some channels should have cardiac detected
            testCase.verifyTrue(any(result.cardiac.detected), ...
                'Cardiac peak should be detected in at least one channel.');

            % Detected frequency should be near the known heart rate
            detectedIdx = find(result.cardiac.detected, 1);
            if ~isempty(detectedIdx)
                testCase.verifyEqual(result.cardiac.freq(detectedIdx), ...
                    expectedFreq, 'AbsTol', 0.7, ...
                    'Detected cardiac frequency should be near heart rate.');
            end
        end

        function testPSDNoCardiacInNoise(testCase)
            % White noise should not reliably show cardiac peak
            % Use high noise to drown out any structure
            data = pf2_base.tests.synthetic.generateFNIRS( ...
                'duration', 60, 'fs', 10, 'nChannels', 4, ...
                'addHeartbeat', false, 'noiseLevel', 0.05, 'seed', 99);

            result = pf2.qc.powerSpectrum(data, 'Signal', 'raw', ...
                'DetectPeaks', true);

            % Most channels should not have cardiac detected
            fractionDetected = sum(result.cardiac.detected) / numel(result.channels);
            testCase.verifyLessThanOrEqual(fractionDetected, 0.75, ...
                'Noise-only data should not reliably show cardiac peaks.');
        end

        function testPSDRespiratoryPeakDetection(testCase)
            % Signal with known respiratory frequency should show peak
            fs = 100;
            t = (0:1/fs:120)';
            respFreq = 0.25;  % 15 breaths/min
            nCh = 2;
            sig = repmat(sin(2 * pi * respFreq * t) + 0.1 * randn(size(t)), 1, nCh);

            data = struct('fs', fs, 'HbO', sig, 'fchMask', ones(1, nCh));
            result = pf2.qc.powerSpectrum(data, 'Signal', 'HbO', 'DetectPeaks', true);

            testCase.verifyTrue(any(result.respiratory.detected), ...
                'Respiratory peak should be detected when respiration is present.');
            detIdx = find(result.respiratory.detected, 1);
            if ~isempty(detIdx)
                testCase.verifyEqual(result.respiratory.freq(detIdx), ...
                    respFreq, 'AbsTol', 0.05, ...
                    'Detected respiratory frequency should be near 0.25 Hz.');
            end
        end

        function testPSDOnHbOSignal(testCase)
            % Verify PSD works on processed (HbO) data
            data = struct();
            data.fs = 10;
            t = (0:1/data.fs:60)';
            nCh = 4;
            data.HbO = randn(numel(t), nCh) * 0.01;
            data.fchMask = ones(1, nCh);

            result = pf2.qc.powerSpectrum(data, 'Signal', 'HbO');

            testCase.verifyEqual(result.signal, 'HbO');
            testCase.verifyEqual(size(result.psd, 2), nCh);
        end

        function testPSDChannelSubset(testCase)
            % 'Channels' parameter should select only those channels
            data = struct();
            data.fs = 10;
            t = (0:1/data.fs:60)';
            data.HbO = randn(numel(t), 6);
            data.fchMask = ones(1, 6);

            result = pf2.qc.powerSpectrum(data, 'Signal', 'HbO', ...
                'Channels', [1, 3]);

            testCase.verifyEqual(numel(result.channels), 2);
            testCase.verifyEqual(result.channels, [1, 3]);
            testCase.verifyEqual(size(result.psd, 2), 2);
        end

        function testPSDOutputDimensions(testCase)
            % Verify [F x C] shape and freqs within FreqRange
            freqRange = [0, 3];
            result = pf2.qc.powerSpectrum(testCase.dataWithHeart, ...
                'Signal', 'raw', 'FreqRange', freqRange, 'DetectPeaks', false);

            nCh = numel(result.channels);
            nFreqs = numel(result.freqs);

            testCase.verifySize(result.psd, [nFreqs, nCh]);
            testCase.verifyGreaterThanOrEqual(min(result.freqs), freqRange(1));
            testCase.verifyLessThanOrEqual(max(result.freqs), freqRange(2));
        end

        function testPSDAllChannelsMasked(testCase)
            % Every channel masked bad: empty result, no index error
            data = testCase.dataWithHeart;
            data.fchMask(:) = 0;
            result = pf2.qc.powerSpectrum(data, 'Signal', 'raw');
            testCase.verifyEmpty(result.channels, ...
                'No channels should be analyzed when all are masked.');
            testCase.verifySize(result.psd, [numel(result.freqs), 0], ...
                'PSD should have zero columns when all channels are masked.');
            testCase.verifySize(result.cardiac.detected, [1, 0], ...
                'Cardiac detection should be empty when all channels are masked.');

            report = pf2.qc.pipeline.assess(data, 'Checks', {'cardiac'});
            testCase.verifySize(report.cardiac.pass, [1, 4], ...
                'assess should still report one cardiac result per channel.');
            testCase.verifyFalse(any(report.cardiac.pass), ...
                'Masked channels should fail the cardiac check.');

            fig = pf2.qc.plotQuality(result, 'Visible', 'off', 'Layout', 'tiled');
            testCase.addTeardown(@() close(fig));
            testCase.verifyTrue(ishandle(fig), ...
                'plotQuality tiled should render an empty PSD result.');
        end

        function testPSDShortRecording(testCase)
            % Recording shorter than WindowLength: window is clamped
            data = pf2_base.tests.synthetic.generateFNIRS( ...
                'duration', 5, 'fs', 10, 'nChannels', 4, ...
                'addHeartbeat', true, 'seed', 1);
            result = pf2.qc.powerSpectrum(data, 'Signal', 'raw', ...
                'WindowLength', 10, 'Overlap', 0.99);
            testCase.verifyEqual(result.channels, 1:4, ...
                'All channels should be analyzed on a short recording.');
            testCase.verifyFalse(any(isnan(result.psd(:))), ...
                'Short-recording PSD should be finite.');

            % Window shorter than 3 samples is raised to 3
            result = pf2.qc.powerSpectrum(data, 'Signal', 'raw', ...
                'WindowLength', 0.05);
            testCase.verifyFalse(any(isnan(result.psd(:))), ...
                'A sub-3-sample window should be raised, not error or NaN.');
            testCase.verifyGreaterThan(max(result.psd(:)), 0, ...
                'A raised 3-sample window should still yield power.');
        end

        function testPSDTooFewSamples(testCase)
            % Under 3 samples: zero PSD with per-channel results, no error
            data = pf2_base.tests.synthetic.generateFNIRS( ...
                'duration', 60, 'fs', 10, 'nChannels', 4, 'seed', 1);
            data.raw = data.raw(1:2, :);
            data.time = data.time(1:2);
            result = pf2.qc.powerSpectrum(data, 'Signal', 'raw');
            testCase.verifyEqual(result.channels, 1:4, ...
                'Channels should be kept when there are too few samples.');
            testCase.verifySize(result.psd, [numel(result.freqs), 4], ...
                'PSD should keep one column per channel.');
            testCase.verifyEqual(result.cardiac.detected, false(1, 4), ...
                'No cardiac peak should be detected from 2 samples.');

            % An all-zero spectrum has no positive power for the log axis
            fig = pf2.qc.plotQuality(result, 'Visible', 'off', 'Layout', 'tiled');
            testCase.addTeardown(@() close(fig));
            testCase.verifyTrue(ishandle(fig), ...
                'plotQuality should render an all-zero PSD.');
        end

        function testPSDBandsSkippedOnShortRecording(testCase)
            % Bands are skipped when the recording spans fewer than 5
            % cycles of the band's lower edge (10/50/100 s)
            result = pf2.qc.powerSpectrum(testCase.dataWithHeart, ...
                'Signal', 'raw');   % 60 s recording
            testCase.verifyFalse(result.cardiac.skipped, ...
                'Cardiac band should be assessed on 60 s of data.');
            testCase.verifyFalse(result.respiratory.skipped, ...
                'Respiratory band should be assessed on 60 s of data.');
            testCase.verifyTrue(result.mayer.skipped, ...
                'Mayer band needs 100 s and should be skipped on 60 s of data.');
            testCase.verifyFalse(any(result.mayer.detected), ...
                'A skipped band should report no detections.');
            testCase.verifyNotEmpty(result.mayer.skipReason, ...
                'A skipped band should say why.');
        end

        function testAssessSkipsCardiacChecksOnShortRecording(testCase)
            % Under 10 s, SCI and cardiac are skipped, not failed
            data = pf2_base.tests.synthetic.generateFNIRS( ...
                'duration', 5, 'fs', 10, 'nChannels', 4, ...
                'addHeartbeat', true, 'seed', 1);
            report = pf2.qc.pipeline.assess(data, 'Checks', {'sci', 'cardiac'});
            for c = {'sci', 'cardiac'}
                testCase.verifyTrue(report.(c{1}).skipped, ...
                    sprintf('%s should be skipped on a 5 s recording.', c{1}));
                testCase.verifyTrue(all(report.(c{1}).pass), ...
                    sprintf('A skipped %s check should not penalize channels.', c{1}));
                testCase.verifySubstring(report.(c{1}).skipReason, 'too short', ...
                    sprintf('%s skipReason should name the short recording.', c{1}));
            end

            % 2 s used to error inside the SCI bandpass filter
            data = pf2_base.tests.synthetic.generateFNIRS( ...
                'duration', 2, 'fs', 10, 'nChannels', 4, 'seed', 1);
            result = pf2.qc.sci(data);
            testCase.verifyTrue(result.skipped, ...
                'SCI should skip, not error, on a 2 s recording.');
        end

        function testPSDRawUsesDeviceColumns(testCase)
            % fNIR2000 has a dark column per channel; PSD must read the
            % first real wavelength column of each channel
            data = pf2.import.sampleData.fNIR2000();
            dev = data.device;
            chNums = dev.channelNumbers();
            wl = dev.wavelengths();
            expectedCol = find(chNums == 2 & wl > 0, 1);
            % Pin the layout: the old interleaved guess, (2-1)*2+1 = 3,
            % must differ from the real column for this test to discriminate
            testCase.assumeNotEqual(expectedCol, 3, ...
                'fNIR2000 layout changed; test no longer discriminates.');
            ref = pf2.qc.powerSpectrum(struct('raw', data.raw(:, expectedCol), ...
                'fs', data.fs, 'fchMask', 1), 'Signal', 'raw', 'DetectPeaks', false);
            result = pf2.qc.powerSpectrum(data, 'Signal', 'raw', ...
                'Channels', 2, 'DetectPeaks', false);
            testCase.verifyEqual(result.psd, ref.psd, 'AbsTol', 1e-12, ...
                'Channel 2 PSD should come from its first non-dark column.');
        end

        function testPSDRawDeviceWithPartialMask(testCase)
            % Masked channels are skipped and the rest stay aligned with
            % their own device columns
            data = pf2.import.sampleData.fNIR2000();
            data.fchMask(:) = 1;
            data.fchMask([1 5]) = 0;
            result = pf2.qc.powerSpectrum(data, 'Signal', 'raw', ...
                'DetectPeaks', false);
            expectedCh = find(data.fchMask);
            testCase.verifyEqual(result.channels, expectedCh, ...
                'Only unmasked channels should be analyzed, in order.');

            chNums = data.device.channelNumbers();
            wl = data.device.wavelengths();
            k = find(expectedCh == 6);
            col = find(chNums == 6 & wl > 0, 1);
            ref = pf2.qc.powerSpectrum(struct('raw', data.raw(:, col), ...
                'fs', data.fs, 'fchMask', 1), 'Signal', 'raw', 'DetectPeaks', false);
            testCase.verifyEqual(result.psd(:, k), ref.psd, 'AbsTol', 1e-12, ...
                'Channel 6 PSD should come from its own device column.');
        end

        function testPSDRawNonDeviceStructFallsBack(testCase)
            % A .device that is not a pf2.Device is ignored, not called
            data = testCase.dataWithHeart;
            data.device = struct('name', 'x');
            result = pf2.qc.powerSpectrum(data, 'Signal', 'raw');
            testCase.verifyEqual(result.channels, 1:4, ...
                'A non-pf2.Device .device should fall back to the interleaved layout.');
        end

        function testPSDRawNonContiguousChannelNumbers(testCase)
            % Merged probes number channels non-contiguously; channel k
            % must map to the k-th entry of the device channel list, as
            % processFNIRS2 does
            [data, dev, chList] = mergedHitachiData(testCase);
            result = pf2.qc.powerSpectrum(data, 'Signal', 'raw', ...
                'DetectPeaks', false);
            testCase.verifyEqual(result.channels, 1:dev.nChannels, ...
                'Every channel position should map to a device channel.');

            chNums = dev.channelNumbers();
            col = find(chNums == chList(end) & dev.wavelengths() > 0, 1);
            ref = pf2.qc.powerSpectrum(struct('raw', data.raw(:, col), ...
                'fs', data.fs, 'fchMask', 1), 'Signal', 'raw', 'DetectPeaks', false);
            testCase.verifyEqual(result.psd(:, end), ref.psd, 'AbsTol', 1e-12, ...
                'The last channel should read the last listed channel''s column.');
        end

        function testSCIUsesDeviceChannelList(testCase)
            % SCI returns one value per listed device channel
            [data, dev] = mergedHitachiData(testCase);
            result = pf2.qc.sci(data);
            testCase.verifyEqual(numel(result.sci), dev.nChannels, ...
                'SCI should return one value per device channel.');
        end

        function testAssessUsesDeviceChannelList(testCase)
            % A channel that is flat in the raw data must be flagged at its
            % own position in the report
            [data, dev, chList] = mergedHitachiData(testCase);
            k = dev.nChannels;
            cols = dev.channelNumbers() == chList(k) & dev.wavelengths() > 0;
            data.raw(:, cols) = 100;
            report = pf2.qc.pipeline.assess(data, 'Checks', {'cov'});
            testCase.verifyEqual(numel(report.cov.values), dev.nChannels, ...
                'assess should report one CoV value per device channel.');
            testCase.verifyEqual(report.cov.values(k), 0, 'AbsTol', 1e-12, ...
                'The flat channel should have zero CoV at its own position.');
        end

    end


    %% Plot Tests
    methods (Test)

        function testPlotSCI(testCase)
            % plotQuality with SCI result should create a figure
            result = pf2.qc.sci(testCase.dataWithHeart);
            fig = pf2.qc.plotQuality(result, 'Visible', 'off');

            testCase.addTeardown(@() close(fig));
            testCase.verifyTrue(ishandle(fig), ...
                'plotQuality should return a valid figure handle for SCI.');
        end

        function testPlotPSDOverlay(testCase)
            % plotQuality with PSD result in overlay mode
            result = pf2.qc.powerSpectrum(testCase.dataWithHeart, ...
                'Signal', 'raw');
            fig = pf2.qc.plotQuality(result, 'Visible', 'off', ...
                'Layout', 'overlay');

            testCase.addTeardown(@() close(fig));
            testCase.verifyTrue(ishandle(fig), ...
                'plotQuality should return a valid figure handle for PSD overlay.');
        end

        function testPlotPSDTiled(testCase)
            % plotQuality with PSD result in tiled mode
            result = pf2.qc.powerSpectrum(testCase.dataWithHeart, ...
                'Signal', 'raw');
            fig = pf2.qc.plotQuality(result, 'Visible', 'off', ...
                'Layout', 'tiled');

            testCase.addTeardown(@() close(fig));
            testCase.verifyTrue(ishandle(fig), ...
                'plotQuality should return a valid figure handle for PSD tiled.');
        end

    end

end


function [data, dev, chList] = mergedHitachiData(testCase)
% MERGEDHITACHIDATA Random raw data on the merged Hitachi + fNIR probe,
% whose channel list (5-16, 21-42) differs from its raw channel numbers
dev = pf2.Device.load('fNIR_Hitachi_3x5_merged');
chList = dev.channelList();
testCase.assumeFalse(isequal(chList, 1:dev.nChannels), ...
    'Merged Hitachi cfg is now contiguous; test no longer discriminates.');
rng(1);
nRaw = numel(dev.channelNumbers());
data = struct('raw', randn(300, nRaw) + 100, 'fs', 10, ...
    'time', (0:299)' / 10, 'fchMask', ones(1, dev.nChannels), 'device', dev);
end
