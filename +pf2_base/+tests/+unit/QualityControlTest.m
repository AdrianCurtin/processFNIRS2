classdef QualityControlTest < matlab.unittest.TestCase
    % QUALITYCONTROLTEST Unit tests for pf2.qc signal quality functions
    %
    %   Tests cover:
    %     - SCI (Scalp Coupling Index): cardiac correlation, dead channels,
    %       threshold classification, explicit wavelength params, output dims
    %     - Power Spectrum: known sinusoid peaks, cardiac/respiratory detection,
    %       noise-only, HbO signal, channel subset, output dimensions
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
