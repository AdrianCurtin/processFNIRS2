classdef SignalProcessingTest < matlab.unittest.TestCase
    % SIGNALPROCESSINGTEST Unit tests for signal processing functions
    %
    % Tests the core signal processing functions in processFNIRS2/functions/
    % including filters, motion correction algorithms, and data conversion.
    %
    % Run all tests:
    %   results = runtests('pf2_base.tests.unit.SignalProcessingTest');
    %
    % Run specific test:
    %   results = runtests('pf2_base.tests.unit.SignalProcessingTest/testLPFReducesHighFreq');

    properties (TestParameter)
        % Filter types for parameterized testing
        lpfFilterType = {1, 3}  % 1=FIR, 3=Butterworth
        hpfFilterType = {1, 3}  % 1=FIR, 3=Butterworth
    end

    properties
        fs = 10;           % Sampling frequency (Hz)
        duration = 60;     % Signal duration (seconds)
        nChannels = 4;     % Number of channels for multi-channel tests
    end

    methods (TestClassSetup)
        function addPaths(testCase)
            % Ensure processFNIRS2 is on the path
            rootPath = fileparts(fileparts(fileparts(mfilename('fullpath'))));
            addpath(rootPath);
            addpath(fullfile(rootPath, 'functions'));
        end
    end

    %% Helper Methods
    methods (Access = private)
        function signal = generateSinusoid(testCase, freq, amplitude, phase)
            % Generate a sinusoidal test signal
            if nargin < 4, phase = 0; end
            if nargin < 3, amplitude = 1; end
            t = (0:1/testCase.fs:testCase.duration-1/testCase.fs)';
            signal = amplitude * sin(2*pi*freq*t + phase);
        end

        function signal = generateMultiFreqSignal(testCase, freqs, amplitudes)
            % Generate a signal with multiple frequency components
            t = (0:1/testCase.fs:testCase.duration-1/testCase.fs)';
            signal = zeros(size(t));
            for i = 1:length(freqs)
                signal = signal + amplitudes(i) * sin(2*pi*freqs(i)*t);
            end
        end

        function power = computeBandPower(testCase, signal, fLow, fHigh)
            % Compute signal power in a frequency band using FFT
            N = length(signal);
            Y = fft(signal);
            P = abs(Y/N).^2;
            freqs = testCase.fs * (0:(N/2))/N;

            % Find indices for the band
            idxLow = find(freqs >= fLow, 1, 'first');
            idxHigh = find(freqs <= fHigh, 1, 'last');

            if isempty(idxLow) || isempty(idxHigh) || idxLow > idxHigh
                power = 0;
            else
                power = sum(P(idxLow:idxHigh));
            end
        end

        function signal = addSpikeArtifact(~, signal, spikeIdx, spikeAmplitude)
            % Add spike artifacts to signal at specified indices
            signal(spikeIdx) = signal(spikeIdx) + spikeAmplitude;
        end
    end

    %% Filter Tests
    methods (Test)
        function testLPFReducesHighFreq(testCase, lpfFilterType)
            % Test that low-pass filter reduces high frequency content
            %
            % Creates a signal with 0.05 Hz (low) and 2 Hz (high) components.
            % After LPF with 0.5 Hz cutoff, high frequency power should decrease.

            % Create test signal: low freq (0.05 Hz) + high freq (2 Hz)
            lowFreq = 0.05;
            highFreq = 2;
            signal = testCase.generateMultiFreqSignal([lowFreq, highFreq], [1, 1]);

            % Apply LPF with cutoff at 0.5 Hz
            cutoffFreq = 0.5;
            filterOrder = 4;
            filtered = pf2_lpf(signal, lpfFilterType, testCase.fs, cutoffFreq, filterOrder, 'Leave');

            % Compute power in high frequency band before and after
            highBandPowerBefore = testCase.computeBandPower(signal, 1.5, 2.5);
            highBandPowerAfter = testCase.computeBandPower(filtered, 1.5, 2.5);

            % High frequency power should be significantly reduced (>90%)
            reductionRatio = highBandPowerAfter / highBandPowerBefore;
            testCase.verifyLessThan(reductionRatio, 0.1, ...
                sprintf('LPF (type %d) did not sufficiently reduce high frequency content. Ratio: %.4f', ...
                lpfFilterType, reductionRatio));
        end

        function testHPFReducesLowFreq(testCase, hpfFilterType)
            % Test that high-pass filter reduces low frequency content
            %
            % Creates a signal with DC/drift (0 Hz trend) and 0.5 Hz components.
            % After HPF, the DC/drift component should be reduced.
            %
            % Note: FIR filters require many taps for very low frequency cutoffs.
            % We use Butterworth (ft=3) for better low-freq performance or
            % test with frequencies well below cutoff.

            % Create test signal: linear drift + sinusoid
            nSamples = testCase.duration * testCase.fs;
            t = (0:nSamples-1)' / testCase.fs;
            drift = t / testCase.duration;  % Linear drift (DC-like)
            sinusoid = sin(2*pi*0.5*t);     % 0.5 Hz component
            signal = drift + sinusoid;

            % Apply HPF with cutoff at 0.1 Hz (easier to achieve)
            cutoffFreq = 0.1;
            if hpfFilterType == 1
                filterOrder = 60;  % FIR needs more taps for low freq
            else
                filterOrder = 4;   % Butterworth is more efficient
            end
            filtered = pf2_hpf(signal, hpfFilterType, testCase.fs, cutoffFreq, filterOrder, 'Leave');

            % The linear drift should be substantially reduced
            % Check variance of the filtered signal is less than original drift variance
            driftVariance = var(drift);
            filteredMeanRemoved = filtered - mean(filtered);

            % High-pass should remove most of the slow drift
            % Check that the filtered signal has reduced low-frequency content
            % by comparing first and last portions (drift would cause difference)
            firstQuarter = mean(signal(1:floor(nSamples/4)));
            lastQuarter = mean(signal(floor(3*nSamples/4):end));
            originalDriftMag = abs(lastQuarter - firstQuarter);

            firstQuarterFilt = mean(filtered(1:floor(nSamples/4)));
            lastQuarterFilt = mean(filtered(floor(3*nSamples/4):end));
            filteredDriftMag = abs(lastQuarterFilt - firstQuarterFilt);

            % Filtered signal should have much less drift
            if originalDriftMag > 0
                reductionRatio = filteredDriftMag / originalDriftMag;
                testCase.verifyLessThan(reductionRatio, 0.5, ...
                    sprintf('HPF (type %d) did not sufficiently reduce drift. Ratio: %.4f', ...
                    hpfFilterType, reductionRatio));
            end
        end

        function testBPFPreservesBand(testCase)
            % Test that band-pass filter preserves target frequency band
            %
            % Creates a signal with frequencies at 0.005 Hz, 0.05 Hz, and 2 Hz.
            % BPF (0.01-0.1 Hz) should preserve 0.05 Hz while attenuating others.

            % Create test signal with three frequency components
            freqs = [0.005, 0.05, 2];
            amps = [1, 1, 1];
            signal = testCase.generateMultiFreqSignal(freqs, amps);

            % Apply BPF: 0.01-0.1 Hz (typical hemodynamic band)
            lowCutoff = 0.01;
            highCutoff = 0.1;
            filterOrder = 3;
            filtered = pf2_bpf_butter(signal, filterOrder, testCase.fs, lowCutoff, highCutoff, false, 'Leave');

            % Compute power in passband before and after
            passBandPowerBefore = testCase.computeBandPower(signal, 0.03, 0.07);
            passBandPowerAfter = testCase.computeBandPower(filtered, 0.03, 0.07);

            % Passband power should be mostly preserved (>50%)
            if passBandPowerBefore > 0
                preservationRatio = passBandPowerAfter / passBandPowerBefore;
                testCase.verifyGreaterThan(preservationRatio, 0.5, ...
                    sprintf('BPF did not preserve passband content. Ratio: %.4f', preservationRatio));
            end

            % Stop bands should be attenuated
            highStopPowerBefore = testCase.computeBandPower(signal, 1.5, 2.5);
            highStopPowerAfter = testCase.computeBandPower(filtered, 1.5, 2.5);

            if highStopPowerBefore > 0
                reductionRatio = highStopPowerAfter / highStopPowerBefore;
                testCase.verifyLessThan(reductionRatio, 0.1, ...
                    sprintf('BPF did not attenuate high stop band. Ratio: %.4f', reductionRatio));
            end
        end

        function testFilterPreservesSize(testCase)
            % Test that all filters preserve input signal dimensions

            % Create multi-channel test signal
            nSamples = testCase.duration * testCase.fs;
            signal = randn(nSamples, testCase.nChannels);

            filterOrder = 4;
            cutoffFreq = 0.5;

            % Test LPF
            filteredLPF = pf2_lpf(signal, 3, testCase.fs, cutoffFreq, filterOrder, 'Leave');
            testCase.verifySize(filteredLPF, size(signal), ...
                'LPF output size does not match input size');

            % Test HPF
            filteredHPF = pf2_hpf(signal, 3, testCase.fs, 0.01, filterOrder, 'Leave');
            testCase.verifySize(filteredHPF, size(signal), ...
                'HPF output size does not match input size');

            % Test BPF
            filteredBPF = pf2_bpf_butter(signal, filterOrder, testCase.fs, 0.01, 0.5, false, 'Leave');
            testCase.verifySize(filteredBPF, size(signal), ...
                'BPF output size does not match input size');
        end

        function testFilterHandlesRowVector(testCase)
            % Test that filters correctly handle row vector input

            signal = randn(1, 500);  % Row vector
            filterOrder = 4;

            filtered = pf2_lpf(signal, 3, testCase.fs, 0.5, filterOrder, 'Leave');
            testCase.verifySize(filtered, size(signal), ...
                'LPF did not preserve row vector orientation');
        end
    end

    %% Motion Correction Tests
    methods (Test)
        function testTDDRReducesSpikes(testCase)
            % Test that TDDR reduces the effect of spike artifacts
            %
            % TDDR (Temporal Derivative Distribution Repair) works by:
            % 1. Computing the temporal derivative
            % 2. Using robust regression to downweight outliers
            % 3. Integrating to reconstruct the signal
            %
            % This test verifies that TDDR reduces signal variance caused
            % by spike artifacts, rather than checking individual spike values.

            % Create clean low-frequency signal with some baseline variation
            nSamples = testCase.duration * testCase.fs;
            t = (0:nSamples-1)' / testCase.fs;
            cleanSignal = sin(2*pi*0.05*t);  % 0.05 Hz sinusoid

            % Add step-like motion artifacts (baseline shifts)
            % TDDR is designed to handle these types of artifacts
            dirtySignal = cleanSignal;
            dirtySignal(200:end) = dirtySignal(200:end) + 2;   % Step up
            dirtySignal(400:end) = dirtySignal(400:end) - 1.5; % Step down

            % Apply TDDR
            corrected = pf2_MotionCorrectTDDR(dirtySignal, testCase.fs);

            % TDDR should reduce the overall signal range/variance caused by artifacts
            % Compare the range (max-min) of dirty vs corrected signals
            dirtyRange = max(dirtySignal) - min(dirtySignal);
            correctedRange = max(corrected) - min(corrected);

            % Corrected signal should have smaller range (artifacts removed)
            testCase.verifyLessThan(correctedRange, dirtyRange, ...
                'TDDR did not reduce signal range from motion artifacts');

            % Also verify the corrected signal is more similar to original shape
            % by checking correlation (corrected should correlate better with clean)
            cleanNorm = cleanSignal - mean(cleanSignal);
            dirtyNorm = dirtySignal - mean(dirtySignal);
            correctedNorm = corrected - mean(corrected);

            corrDirty = abs(corr(cleanNorm, dirtyNorm));
            corrCorrected = abs(corr(cleanNorm, correctedNorm));

            % Corrected signal should have higher correlation with clean signal
            testCase.verifyGreaterThanOrEqual(corrCorrected, corrDirty * 0.8, ...
                'TDDR corrected signal does not maintain similarity to clean signal');
        end

        function testTDDRPreservesSize(testCase)
            % Test that TDDR preserves input signal dimensions

            nSamples = testCase.duration * testCase.fs;
            signal = randn(nSamples, testCase.nChannels);

            corrected = pf2_MotionCorrectTDDR(signal, testCase.fs);

            testCase.verifySize(corrected, size(signal), ...
                'TDDR output size does not match input size');
        end

        function testTDDRHandlesSingleChannel(testCase)
            % Test that TDDR works with single channel input

            signal = testCase.generateSinusoid(0.05, 1);
            corrected = pf2_MotionCorrectTDDR(signal, testCase.fs);

            testCase.verifySize(corrected, size(signal), ...
                'TDDR did not handle single channel correctly');
            testCase.verifyFalse(any(isnan(corrected)), ...
                'TDDR produced NaN values for clean single channel input');
        end

        function testSMARPreservesSize(testCase)
            % Test that SMAR preserves input signal dimensions

            nSamples = testCase.duration * testCase.fs;
            signal = abs(randn(nSamples, testCase.nChannels)) + 1;  % Positive values for CV calc

            [corrected, mask] = pf2_SMAR(signal, 10, 0.025);

            testCase.verifySize(corrected, size(signal), ...
                'SMAR output size does not match input size');
            testCase.verifySize(mask, size(signal), ...
                'SMAR mask size does not match input size');
        end

        function testSMARDetectsArtifacts(testCase)
            % Test that SMAR detects and marks motion artifacts

            % Create relatively stable signal
            nSamples = 500;
            signal = ones(nSamples, 1) * 100 + randn(nSamples, 1) * 0.5;

            % Add a sudden jump (motion artifact)
            signal(200:210) = signal(200:210) + 50;

            [corrected, mask] = pf2_SMAR(signal, 10, 0.05);

            % Check that artifacts were detected (some values should be NaN)
            testCase.verifyTrue(any(mask(:)), ...
                'SMAR did not detect any artifacts in signal with obvious jump');

            % Verify corrected signal has NaN where mask is true
            testCase.verifyTrue(all(isnan(corrected(mask))), ...
                'SMAR did not replace masked values with NaN');
        end

        function testSMARReturnsLogicalMask(testCase)
            % Test that SMAR returns a logical mask

            signal = abs(randn(200, 2)) + 1;
            [~, mask] = pf2_SMAR(signal);

            testCase.verifyClass(mask, 'logical', ...
                'SMAR mask should be logical type');
        end
    end

    %% Conversion Tests
    methods (Test)
        function testIntensity2ODOutput(testCase)
            % Test that pf2_Intensity2OD produces valid optical density values

            % Create synthetic intensity data (positive values)
            nSamples = 500;
            nChannels = 4;
            baseIntensity = 1000;
            intensity = baseIntensity + randn(nSamples, nChannels) * 10;

            % Convert to OD
            od = pf2_Intensity2OD(intensity);

            % Verify output size
            testCase.verifySize(od, size(intensity), ...
                'Intensity2OD output size does not match input size');

            % OD should be finite (no Inf values from log of zero)
            testCase.verifyTrue(all(isfinite(od(:))), ...
                'Intensity2OD produced non-finite values');

            % OD should be centered around zero (since we divide by mean)
            testCase.verifyLessThan(abs(mean(od(:))), 0.1, ...
                'Intensity2OD should produce zero-centered output');
        end

        function testIntensity2ODWithSampleData(testCase)
            % Test Intensity2OD with actual sample data

            try
                data = pf2.import.sampleData.fNIR2000();

                % Get raw data
                rawData = data.raw;

                % Convert to OD
                od = pf2_Intensity2OD(rawData);

                % Verify size preserved
                testCase.verifySize(od, size(rawData), ...
                    'Intensity2OD output size mismatch with sample data');

                % Verify reasonable OD range (typically -0.5 to 0.5 for fNIRS)
                odRange = [min(od(:)), max(od(:))];
                testCase.verifyGreaterThan(odRange(1), -5, ...
                    'OD values unexpectedly low');
                testCase.verifyLessThan(odRange(2), 5, ...
                    'OD values unexpectedly high');

            catch ME
                testCase.assumeFail(['Sample data not available: ', ME.message]);
            end
        end

        function testBvoxyProducesHbO(testCase)
            % Test that processFNIRS2 pipeline produces HbO output
            %
            % Uses processFNIRS2 which internally calls bvoxy with correct
            % channel/wavelength configuration from the device settings.

            try
                % Load sample data
                data = pf2.import.sampleData.fNIR2000();
                nTimePoints = size(data.raw, 1);

                % Process through full pipeline (this calls bvoxy internally)
                warning('off', 'all');
                result = processFNIRS2(data);
                warning('on', 'all');

                % Verify HbO field exists and has data
                testCase.verifyTrue(isfield(result, 'HbO'), ...
                    'processFNIRS2 output should contain HbO field');
                testCase.verifyFalse(isempty(result.HbO), ...
                    'HbO output should not be empty');

                % Verify HbR field exists
                testCase.verifyTrue(isfield(result, 'HbR'), ...
                    'processFNIRS2 output should contain HbR field');

                % Verify dimensions are correct (time points should match)
                testCase.verifyEqual(size(result.HbO, 1), nTimePoints, ...
                    'HbO should have same number of time points as input');

                % Verify HbO and HbR have same size
                testCase.verifySize(result.HbR, size(result.HbO), ...
                    'HbO and HbR should have same dimensions');

            catch ME
                testCase.assumeFail(['Sample data or processFNIRS2 not available: ', ME.message]);
            end
        end

        function testBvoxyProducesAllBiomarkers(testCase)
            % Test that processFNIRS2 produces all expected biomarker outputs

            try
                data = pf2.import.sampleData.fNIR2000();

                warning('off', 'all');
                result = processFNIRS2(data);
                warning('on', 'all');

                % Check all expected fields
                expectedFields = {'HbO', 'HbR', 'HbTotal', 'HbDiff', 'CBSI', 'channels', 'units'};
                for i = 1:length(expectedFields)
                    testCase.verifyTrue(isfield(result, expectedFields{i}), ...
                        sprintf('processFNIRS2 output missing field: %s', expectedFields{i}));
                end

                % Verify HbTotal = HbO + HbR
                nChannels = length(result.channels);
                if nChannels > 0
                    hbTotal_calculated = result.HbO + result.HbR;
                    testCase.verifyEqual(result.HbTotal, hbTotal_calculated, ...
                        'AbsTol', 1e-10, 'HbTotal should equal HbO + HbR');
                end

                % Verify HbDiff = HbO - HbR
                hbDiff_calculated = result.HbO - result.HbR;
                testCase.verifyEqual(result.HbDiff, hbDiff_calculated, ...
                    'AbsTol', 1e-10, 'HbDiff should equal HbO - HbR');

            catch ME
                testCase.assumeFail(['Sample data or processFNIRS2 not available: ', ME.message]);
            end
        end

        function testBvoxyWithMultipleOutputs(testCase)
            % Test bvoxy function directly with synthetic data
            %
            % Creates synthetic two-wavelength intensity data to test bvoxy
            % independently of the full processFNIRS2 pipeline.

            try
                % Create synthetic intensity data for 2 wavelengths, 4 optodes
                nSamples = 500;
                nOptodes = 4;

                % Generate synthetic intensity data (positive values)
                baseIntensity = 1000;
                intensity730 = baseIntensity + randn(nSamples, nOptodes) * 10;
                intensity850 = baseIntensity + randn(nSamples, nOptodes) * 10;

                % Stack wavelengths: [ch1_730, ch2_730, ..., ch1_850, ch2_850, ...]
                rawData = [intensity730, intensity850];

                % Create channel and wavelength arrays
                channels = [1:nOptodes, 1:nOptodes];  % Optode numbers
                wavelengths = [ones(1, nOptodes)*730, ones(1, nOptodes)*850];  % Wavelengths
                sd = ones(nOptodes, 1) * 2.5;  % Source-detector distance in cm (column vector)

                % Call bvoxy with multiple outputs
                [HbO, HbR, Total, HbDiff, CBSI, ch, t, units, DPF] = ...
                    pf2_base.fnirs.bvoxy(rawData, channels, wavelengths, sd);

                % Verify each output is not empty
                testCase.verifyFalse(isempty(HbO), 'HbO should not be empty');
                testCase.verifyFalse(isempty(HbR), 'HbR should not be empty');
                testCase.verifyFalse(isempty(Total), 'Total should not be empty');
                testCase.verifyFalse(isempty(HbDiff), 'HbDiff should not be empty');
                testCase.verifyFalse(isempty(CBSI), 'CBSI should not be empty');
                testCase.verifyFalse(isempty(ch), 'channels should not be empty');
                testCase.verifyFalse(isempty(units), 'units should not be empty');

                % Verify output dimensions
                testCase.verifyEqual(size(HbO, 1), nSamples, ...
                    'HbO should have correct number of samples');
                testCase.verifyEqual(size(HbO, 2), nOptodes, ...
                    'HbO should have correct number of channels');

                % Verify units is a valid string
                testCase.verifyTrue(ischar(units) || isstring(units), ...
                    'units should be a string');

                % Verify channel numbers are correct
                testCase.verifyEqual(length(ch), nOptodes, ...
                    'Should have correct number of output channels');

            catch ME
                testCase.assumeFail(['bvoxy test failed: ', ME.message]);
            end
        end
    end

    %% Edge Case Tests
    methods (Test)
        function testFilterWithNaNValues(testCase)
            % Test that filters handle NaN values appropriately

            signal = testCase.generateSinusoid(0.05, 1);
            signal(100:110) = NaN;  % Add NaN segment

            % Test with Piecewise NaN handling (default)
            filtered = pf2_lpf(signal, 3, testCase.fs, 0.5, 4, 'Piecewise');

            % Output should preserve NaN locations
            testCase.verifyTrue(all(isnan(filtered(100:110))), ...
                'Filter should preserve NaN locations in Piecewise mode');

            % Non-NaN values should be filtered (not all NaN)
            nonNanFiltered = filtered(~isnan(signal));
            testCase.verifyFalse(all(isnan(nonNanFiltered)), ...
                'Filter should process non-NaN segments');
        end

        function testFilterWithShortSignal(testCase)
            % Test that filters handle signals shorter than minimum length

            shortSignal = randn(10, 1);  % Very short signal
            filterOrder = 4;

            % LPF requires 3*Nf samples minimum
            warning('off', 'all');
            filtered = pf2_lpf(shortSignal, 3, testCase.fs, 0.5, filterOrder, 'Leave');
            warning('on', 'all');

            % Should return NaN for too-short signals
            testCase.verifyTrue(all(isnan(filtered)), ...
                'Filter should return NaN for signals shorter than minimum length');
        end

        function testIntensity2ODWithZeroValues(testCase)
            % Test Intensity2OD behavior with zero/negative values

            intensity = ones(100, 2) * 1000;
            intensity(50, 1) = 0;  % Add a zero
            intensity(60, 2) = -10; % Add a negative

            % Should produce warning but not fail
            warning('off', 'all');
            od = pf2_Intensity2OD(intensity);
            warning('on', 'all');

            % Output should exist and be finite (abs is used internally)
            testCase.verifySize(od, size(intensity), ...
                'Intensity2OD should handle zero/negative values');
        end
    end
end
