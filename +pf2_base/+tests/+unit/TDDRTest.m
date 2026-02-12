classdef TDDRTest < matlab.unittest.TestCase
    % TDDRTEST Unit tests for TDDR motion correction algorithm
    %
    % Tests the Temporal Derivative Distribution Repair (TDDR) algorithm
    % implemented in pf2_MotionCorrectTDDR.m. TDDR corrects motion artifacts
    % by computing temporal derivatives, applying robust regression to
    % downweight outliers, then integrating to reconstruct the signal.
    %
    % Reference:
    %   Fishburn, F.A. et al. (2019). Temporal Derivative Distribution Repair
    %   (TDDR): A motion correction method for fNIRS. NeuroImage, 184, 171-179.
    %   DOI: 10.1016/j.neuroimage.2018.09.025
    %
    % Run all tests:
    %   results = runtests('pf2_base.tests.unit.TDDRTest');
    %
    % Run specific test:
    %   results = runtests('pf2_base.tests.unit.TDDRTest/testTDDRReducesStepArtifacts');

    properties
        fs = 10;           % Sampling frequency (Hz)
        duration = 60;     % Signal duration (seconds)
        nChannels = 4;     % Number of channels for multi-channel tests
        seed = 42;         % Random seed for reproducibility
    end

    methods (TestClassSetup)
        function addPaths(testCase)
            % Ensure processFNIRS2 is on the path
            rootPath = fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))));
            addpath(rootPath);
            addpath(fullfile(rootPath, 'functions'));
        end
    end

    %% Helper Methods
    methods (Access = private)
        function signal = generateCleanSinusoid(testCase, freq, amplitude, duration)
            % Generate a clean sinusoidal signal at specified frequency
            %
            % Inputs:
            %   freq      - Frequency in Hz (default: 0.1)
            %   amplitude - Signal amplitude (default: 1)
            %   duration  - Duration in seconds (default: testCase.duration)
            %
            % Outputs:
            %   signal - Clean sinusoidal signal [nSamples x 1]

            if nargin < 4, duration = testCase.duration; end
            if nargin < 3, amplitude = 1; end
            if nargin < 2, freq = 0.1; end

            nSamples = duration * testCase.fs;
            t = (0:nSamples-1)' / testCase.fs;
            signal = amplitude * sin(2*pi*freq*t);
        end

        function signal = addStepArtifact(~, signal, stepIdx, stepAmplitude)
            % Add a step artifact (baseline shift) to the signal
            %
            % Inputs:
            %   signal        - Input signal
            %   stepIdx       - Sample index where step occurs
            %   stepAmplitude - Magnitude of the step change
            %
            % Outputs:
            %   signal - Signal with step artifact added

            signal(stepIdx:end) = signal(stepIdx:end) + stepAmplitude;
        end

        function signal = addSpikeArtifact(~, signal, spikeIdx, spikeAmplitude, spikeWidth)
            % Add a spike artifact (transient) to the signal
            %
            % Inputs:
            %   signal         - Input signal
            %   spikeIdx       - Sample index for spike center
            %   spikeAmplitude - Peak amplitude of spike
            %   spikeWidth     - Width of spike in samples (default: 3)
            %
            % Outputs:
            %   signal - Signal with spike artifact added

            if nargin < 5, spikeWidth = 3; end

            sigma = spikeWidth / 2;
            halfWidth = ceil(3 * sigma);
            startIdx = max(1, spikeIdx - halfWidth);
            endIdx = min(length(signal), spikeIdx + halfWidth);
            indices = startIdx:endIdx;

            spike = spikeAmplitude * exp(-((indices - spikeIdx).^2) / (2 * sigma^2));
            signal(indices) = signal(indices) + spike';
        end

        function maxDeriv = computeMaxDerivative(testCase, signal)
            % Compute the maximum absolute temporal derivative
            %
            % Inputs:
            %   signal - Input signal
            %
            % Outputs:
            %   maxDeriv - Maximum absolute value of derivative

            deriv = diff(signal);
            maxDeriv = max(abs(deriv));
        end
    end

    %% Basic Functionality Tests
    methods (Test)
        function testTDDRPreservesSize(testCase)
            % Test that TDDR output dimensions match input dimensions
            %
            % TDDR should preserve the size of the input signal regardless
            % of the number of samples or channels.

            % Single channel test
            nSamples = testCase.duration * testCase.fs;
            signal1ch = randn(nSamples, 1);
            corrected1ch = pf2_MotionCorrectTDDR(signal1ch, testCase.fs);
            testCase.verifySize(corrected1ch, size(signal1ch), ...
                'TDDR output size does not match single channel input size');

            % Multi-channel test
            signalMulti = randn(nSamples, testCase.nChannels);
            correctedMulti = pf2_MotionCorrectTDDR(signalMulti, testCase.fs);
            testCase.verifySize(correctedMulti, size(signalMulti), ...
                'TDDR output size does not match multi-channel input size');

            % Short signal test
            signalShort = randn(100, 2);
            correctedShort = pf2_MotionCorrectTDDR(signalShort, testCase.fs);
            testCase.verifySize(correctedShort, size(signalShort), ...
                'TDDR output size does not match short signal input size');
        end

        function testTDDRReducesStepArtifacts(testCase)
            % Test that TDDR reduces amplitude of step artifacts (baseline shifts)
            %
            % Step artifacts cause large derivatives at the transition point.
            % TDDR should identify and downweight these outlying derivatives,
            % resulting in reduced step amplitude after integration.
            %
            % Note: TDDR uses a 0.5 Hz filter internally. The algorithm corrects
            % only the low-frequency component (<0.5 Hz). The correction amount
            % depends on how much the step derivative deviates from the robust
            % mean of all derivatives.

            % Generate clean signal
            cleanSignal = testCase.generateCleanSinusoid(0.1, 1);

            % Add step artifact (baseline shift)
            stepIdx = 300;
            stepAmplitude = 5;  % Large step
            dirtySignal = testCase.addStepArtifact(cleanSignal, stepIdx, stepAmplitude);

            % Apply TDDR
            corrected = pf2_MotionCorrectTDDR(dirtySignal, testCase.fs);

            % Signal range should be reduced (artifacts corrected)
            dirtyRange = max(dirtySignal) - min(dirtySignal);
            correctedRange = max(corrected) - min(corrected);
            testCase.verifyLessThan(correctedRange, dirtyRange, ...
                'TDDR did not reduce signal range from step artifact');

            % Maximum derivative should be reduced (step artifact downweighted)
            maxDerivDirty = testCase.computeMaxDerivative(dirtySignal);
            maxDerivCorrected = testCase.computeMaxDerivative(corrected);
            testCase.verifyLessThan(maxDerivCorrected, maxDerivDirty, ...
                'TDDR did not reduce maximum derivative from step artifact');
        end

        function testTDDRPreservesCleanData(testCase)
            % Test that clean sinusoidal data passes through mostly unchanged
            %
            % For clean low-frequency signals without artifacts, TDDR should
            % preserve the signal shape with high correlation to the original.

            % Generate clean HRF-like sinusoid (0.1 Hz is in hemodynamic range)
            freq = 0.1;  % Hz
            cleanSignal = testCase.generateCleanSinusoid(freq, 1);

            % Apply TDDR
            corrected = pf2_MotionCorrectTDDR(cleanSignal, testCase.fs);

            % Normalize both signals for correlation
            cleanNorm = cleanSignal - mean(cleanSignal);
            correctedNorm = corrected - mean(corrected);

            % Correlation should be high (>0.9)
            correlation = corr(cleanNorm, correctedNorm);
            testCase.verifyGreaterThan(correlation, 0.9, ...
                sprintf('TDDR corrupted clean signal. Correlation: %.3f', correlation));
        end

        function testTDDRHandlesSingleChannel(testCase)
            % Test that TDDR works correctly with single channel input

            % Generate single channel signal with artifact
            signal = testCase.generateCleanSinusoid(0.1, 1);
            signal = testCase.addStepArtifact(signal, 200, 3);

            % Apply TDDR
            corrected = pf2_MotionCorrectTDDR(signal, testCase.fs);

            % Verify size
            testCase.verifySize(corrected, size(signal), ...
                'TDDR did not preserve single channel signal size');

            % Verify no NaN in output for valid input
            testCase.verifyFalse(any(isnan(corrected)), ...
                'TDDR produced NaN values for valid single channel input');

            % Verify correction occurred (step reduced)
            dirtyRange = max(signal) - min(signal);
            correctedRange = max(corrected) - min(corrected);
            testCase.verifyLessThan(correctedRange, dirtyRange, ...
                'TDDR did not correct single channel signal');
        end

        function testTDDRHandlesMultiChannel(testCase)
            % Test that TDDR works correctly with multiple channels
            %
            % Each channel should be processed independently.

            nSamples = testCase.duration * testCase.fs;
            nCh = testCase.nChannels;

            % Generate multi-channel signal with different artifacts
            signal = zeros(nSamples, nCh);
            for ch = 1:nCh
                signal(:, ch) = testCase.generateCleanSinusoid(0.1, 1);
                % Add step at different locations for each channel
                stepIdx = 100 + ch * 50;
                signal(:, ch) = testCase.addStepArtifact(signal(:, ch), stepIdx, 4);
            end

            % Apply TDDR
            corrected = pf2_MotionCorrectTDDR(signal, testCase.fs);

            % Verify size
            testCase.verifySize(corrected, [nSamples, nCh], ...
                'TDDR did not preserve multi-channel signal size');

            % Verify each channel was corrected
            for ch = 1:nCh
                dirtyRange = max(signal(:, ch)) - min(signal(:, ch));
                correctedRange = max(corrected(:, ch)) - min(corrected(:, ch));
                testCase.verifyLessThan(correctedRange, dirtyRange, ...
                    sprintf('TDDR did not correct channel %d', ch));
            end
        end

        function testTDDRHandlesNaN(testCase)
            % Test that TDDR handles NaN values in input via piecewise processing
            %
            % NaN values may be present from channel masking or device timing
            % mismatch. TDDR processes each contiguous non-NaN segment
            % independently and preserves NaN at original positions.

            % Generate signal with NaN gap in the middle
            signal = testCase.generateCleanSinusoid(0.1, 1);
            signal = testCase.addStepArtifact(signal, 300, 5);
            nanIdx = 200:210;
            signal(nanIdx) = NaN;

            % Apply TDDR - should not error
            corrected = pf2_MotionCorrectTDDR(signal, testCase.fs);

            % Verify output size is preserved
            testCase.verifySize(corrected, size(signal), ...
                'TDDR did not preserve signal size with NaN input');

            % NaN positions must be preserved
            testCase.verifyTrue(all(isnan(corrected(nanIdx))), ...
                'TDDR did not preserve NaN at original positions');

            % Valid segments must not become NaN
            validBefore = 1:199;
            validAfter  = 211:length(signal);
            testCase.verifyFalse(any(isnan(corrected(validBefore))), ...
                'TDDR introduced NaN in valid segment before gap');
            testCase.verifyFalse(any(isnan(corrected(validAfter))), ...
                'TDDR introduced NaN in valid segment after gap');
        end

        function testTDDRHandlesLeadingTrailingNaN(testCase)
            % Test piecewise TDDR with leading/trailing NaN (device merge scenario)
            %
            % When merging two fNIRS devices with different recording lengths,
            % channels from the shorter device have leading or trailing NaN.
            % TDDR must process the valid interior without destroying it.

            nSamples = testCase.duration * testCase.fs;
            signal = testCase.generateCleanSinusoid(0.1, 1);
            signal = testCase.addStepArtifact(signal, 300, 4);

            % Simulate 50-sample leading + 30-sample trailing NaN
            leadN = 50;
            trailN = 30;
            signal(1:leadN) = NaN;
            signal(end-trailN+1:end) = NaN;

            corrected = pf2_MotionCorrectTDDR(signal, testCase.fs);

            % Size preserved
            testCase.verifySize(corrected, size(signal));

            % Leading/trailing NaN preserved
            testCase.verifyTrue(all(isnan(corrected(1:leadN))), ...
                'Leading NaN not preserved');
            testCase.verifyTrue(all(isnan(corrected(end-trailN+1:end))), ...
                'Trailing NaN not preserved');

            % Valid interior must not be NaN
            validIdx = (leadN+1):(nSamples-trailN);
            testCase.verifyFalse(any(isnan(corrected(validIdx))), ...
                'TDDR introduced NaN in valid interior with leading/trailing NaN');

            % Step artifact should still be corrected in valid region
            origRange = max(signal(validIdx)) - min(signal(validIdx));
            corrRange = max(corrected(validIdx)) - min(corrected(validIdx));
            testCase.verifyLessThan(corrRange, origRange, ...
                'TDDR did not correct step artifact in valid region');
        end

        function testTDDRReducesSpikeArtifacts(testCase)
            % Test that TDDR reduces spike artifacts (transient motion)
            %
            % Spike artifacts create large positive and negative derivatives.
            % TDDR should downweight these outliers in the low-frequency band.
            %
            % Note: TDDR separates signal into low (<0.5 Hz) and high (>0.5 Hz)
            % components. Gaussian spikes have significant high-frequency content
            % that passes through unchanged. TDDR primarily corrects the
            % low-frequency component of artifacts.

            % Generate clean signal
            cleanSignal = testCase.generateCleanSinusoid(0.1, 1);

            % Add spike artifact
            spikeIdx = 300;
            spikeAmplitude = 10;  % Large spike
            dirtySignal = testCase.addSpikeArtifact(cleanSignal, spikeIdx, spikeAmplitude, 5);

            % Apply TDDR
            corrected = pf2_MotionCorrectTDDR(dirtySignal, testCase.fs);

            % Verify output dimensions preserved
            testCase.verifySize(corrected, size(dirtySignal), ...
                'TDDR did not preserve signal size with spike artifact');

            % Verify signal is modified (TDDR did something)
            % Compare variance of derivatives - should be reduced overall
            derivDirty = diff(dirtySignal);
            derivCorrected = diff(corrected);

            % TDDR should reduce derivative variance (outliers downweighted)
            testCase.verifyLessThan(var(derivCorrected), var(derivDirty), ...
                'TDDR did not reduce derivative variance from spike artifact');
        end

        function testTDDRPreservesLowFrequency(testCase)
            % Test that TDDR preserves low frequency content (HRF-like signals)
            %
            % TDDR uses a 0.5 Hz filter to separate high and low frequencies.
            % Low frequency content (<0.5 Hz) should be preserved if not
            % contaminated by motion artifacts.

            % Generate low frequency signal (typical HRF range)
            freq = 0.05;  % 0.05 Hz - well within hemodynamic range
            cleanSignal = testCase.generateCleanSinusoid(freq, 1);

            % Apply TDDR
            corrected = pf2_MotionCorrectTDDR(cleanSignal, testCase.fs);

            % Normalize for comparison
            cleanNorm = cleanSignal - mean(cleanSignal);
            correctedNorm = corrected - mean(corrected);

            % Scale normalized signals to same amplitude for shape comparison
            if std(cleanNorm) > 0 && std(correctedNorm) > 0
                cleanNorm = cleanNorm / std(cleanNorm);
                correctedNorm = correctedNorm / std(correctedNorm);
            end

            % Correlation should be high (shape preserved)
            correlation = corr(cleanNorm, correctedNorm);
            testCase.verifyGreaterThan(correlation, 0.9, ...
                sprintf('TDDR did not preserve low frequency content. Correlation: %.3f', correlation));

            % Verify frequency content is similar by comparing power spectrum
            Y_clean = fft(cleanSignal);
            Y_corrected = fft(corrected);
            N = length(cleanSignal);
            freqs = testCase.fs * (0:(N/2))/N;

            % Find index for target frequency
            [~, freqIdx] = min(abs(freqs - freq));

            % Power at target frequency should be similar
            powerClean = abs(Y_clean(freqIdx))^2;
            powerCorrected = abs(Y_corrected(freqIdx))^2;

            if powerClean > 0
                powerRatio = powerCorrected / powerClean;
                testCase.verifyGreaterThan(powerRatio, 0.5, ...
                    sprintf('TDDR reduced low frequency power too much. Ratio: %.3f', powerRatio));
            end
        end
    end

    %% Tests Using Synthetic Data Generators
    methods (Test)
        function testTDDRWithSyntheticFNIRS(testCase)
            % Test TDDR with synthetic fNIRS data from generator
            %
            % Uses pf2_base.tests.synthetic.generateFNIRS to create
            % realistic synthetic data with motion artifacts.

            % Generate synthetic fNIRS data with motion artifacts
            % Use larger motion amplitude to ensure detectable artifacts
            data = pf2_base.tests.synthetic.generateFNIRS(...
                'duration', testCase.duration, ...
                'fs', testCase.fs, ...
                'nChannels', 4, ...
                'addHRF', true, ...
                'hrfOnsets', [15, 35], ...
                'addMotion', true, ...
                'motionTimes', [20, 45], ...
                'motionAmplitude', 0.3, ...  % Larger amplitude for clear artifacts
                'noiseLevel', 0.001, ...     % Lower noise for cleaner test
                'seed', testCase.seed);

            % Get a single channel of raw data (first wavelength)
            rawSignal = data.raw(:, 1);

            % Apply TDDR
            corrected = pf2_MotionCorrectTDDR(rawSignal, testCase.fs);

            % Verify output size
            testCase.verifySize(corrected, size(rawSignal), ...
                'TDDR output size mismatch with synthetic fNIRS data');

            % Verify no NaN introduced
            testCase.verifyFalse(any(isnan(corrected)), ...
                'TDDR introduced NaN in synthetic fNIRS data');

            % Verify derivative variance is reduced (TDDR effect on outliers)
            derivRaw = diff(rawSignal);
            derivCorrected = diff(corrected);

            testCase.verifyLessThanOrEqual(var(derivCorrected), var(derivRaw) * 1.1, ...
                'TDDR should not significantly increase derivative variance');
        end

        function testTDDRWithBaselineShiftArtifacts(testCase)
            % Test TDDR with synthetic baseline shift artifacts
            %
            % Uses pf2_base.tests.synthetic.generateArtifacts to create
            % controlled baseline shift artifacts.

            nSamples = testCase.duration * testCase.fs;

            % Generate clean signal
            cleanSignal = testCase.generateCleanSinusoid(0.1, 1);

            % Generate baseline shift artifacts
            [artifacts, ~] = pf2_base.tests.synthetic.generateArtifacts(...
                nSamples, 1, ...
                'type', 'baseline_shift', ...
                'times', [200, 400], ...
                'amplitude', 3, ...
                'seed', testCase.seed);

            % Add artifacts to clean signal
            dirtySignal = cleanSignal + artifacts;

            % Apply TDDR
            corrected = pf2_MotionCorrectTDDR(dirtySignal, testCase.fs);

            % Verify signal range is reduced (baseline shifts corrected)
            dirtyRange = max(dirtySignal) - min(dirtySignal);
            correctedRange = max(corrected) - min(corrected);

            testCase.verifyLessThan(correctedRange, dirtyRange, ...
                'TDDR did not reduce signal range from baseline shift artifacts');
        end

        function testTDDRWithSpikeArtifacts(testCase)
            % Test TDDR with synthetic spike artifacts
            %
            % Uses pf2_base.tests.synthetic.generateArtifacts to create
            % controlled spike artifacts.
            %
            % Note: TDDR primarily corrects low-frequency (<0.5 Hz) artifacts.
            % Gaussian spikes have significant high-frequency content that
            % passes through unchanged.

            nSamples = testCase.duration * testCase.fs;

            % Generate clean signal
            cleanSignal = testCase.generateCleanSinusoid(0.1, 1);

            % Generate spike artifacts
            [artifacts, ~] = pf2_base.tests.synthetic.generateArtifacts(...
                nSamples, 1, ...
                'type', 'spike', ...
                'times', [150, 350, 450], ...
                'amplitude', 8, ...
                'duration', 5, ...
                'seed', testCase.seed);

            % Add artifacts to clean signal
            dirtySignal = cleanSignal + artifacts;

            % Apply TDDR
            corrected = pf2_MotionCorrectTDDR(dirtySignal, testCase.fs);

            % Verify output size preserved
            testCase.verifySize(corrected, size(dirtySignal), ...
                'TDDR did not preserve signal size with spike artifacts');

            % Verify no NaN introduced
            testCase.verifyFalse(any(isnan(corrected)), ...
                'TDDR introduced NaN when processing spike artifacts');

            % Derivative variance should be reduced or similar (robust regression effect)
            derivDirty = diff(dirtySignal);
            derivCorrected = diff(corrected);

            testCase.verifyLessThanOrEqual(var(derivCorrected), var(derivDirty) * 1.1, ...
                'TDDR should not significantly increase derivative variance');
        end
    end

    %% Edge Case Tests
    methods (Test)
        function testTDDRWithConstantSignal(testCase)
            % Test TDDR with constant (DC) signal

            nSamples = 500;
            constantSignal = ones(nSamples, 1) * 5;

            corrected = pf2_MotionCorrectTDDR(constantSignal, testCase.fs);

            % Output should be near-constant (centered around zero due to TDDR)
            testCase.verifySize(corrected, size(constantSignal), ...
                'TDDR did not preserve constant signal size');

            % Variance should be very small
            testCase.verifyLessThan(var(corrected), 1e-10, ...
                'TDDR should preserve constant signal (near-zero variance)');
        end

        function testTDDRWithDifferentSamplingRates(testCase)
            % Test TDDR with different sampling frequencies
            %
            % TDDR uses fs for the internal filter; verify it works
            % at different sampling rates.

            samplingRates = [5, 10, 25, 50];

            for fs = samplingRates
                % Generate signal at this sampling rate
                duration = 30;  % seconds
                nSamples = duration * fs;
                t = (0:nSamples-1)' / fs;
                signal = sin(2*pi*0.1*t);  % 0.1 Hz sinusoid

                % Add step artifact
                signal(floor(nSamples/2):end) = signal(floor(nSamples/2):end) + 3;

                % Apply TDDR
                corrected = pf2_MotionCorrectTDDR(signal, fs);

                % Verify output size
                testCase.verifySize(corrected, size(signal), ...
                    sprintf('TDDR output size mismatch at fs=%d Hz', fs));

                % Verify correction occurred
                dirtyRange = max(signal) - min(signal);
                correctedRange = max(corrected) - min(corrected);
                testCase.verifyLessThan(correctedRange, dirtyRange, ...
                    sprintf('TDDR did not correct signal at fs=%d Hz', fs));
            end
        end

        function testTDDRWithHighSamplingRate(testCase)
            % Test TDDR behavior when sampling rate makes Fc >= 1
            %
            % When fs <= 1 Hz, the filter cutoff Fc = 0.5 * 2/fs >= 1,
            % which bypasses the filter and uses signal directly.

            % Use very low sampling rate to trigger Fc >= 1 condition
            fs_low = 0.5;  % Hz
            duration = 60;  % seconds
            nSamples = duration * fs_low;
            t = (0:nSamples-1)' / fs_low;
            signal = sin(2*pi*0.01*t);  % Very low frequency signal

            % Add step artifact
            signal(floor(nSamples/2):end) = signal(floor(nSamples/2):end) + 2;

            % Apply TDDR (should handle Fc >= 1 gracefully)
            corrected = pf2_MotionCorrectTDDR(signal, fs_low);

            % Verify output size
            testCase.verifySize(corrected, size(signal), ...
                'TDDR did not preserve size with low sampling rate');
        end

        function testTDDRMultipleArtifactsReduction(testCase)
            % Test TDDR with multiple sequential artifacts
            %
            % Multiple step artifacts test the robustness of TDDR when
            % there are several outlying derivatives in the signal.

            % Generate clean signal
            cleanSignal = testCase.generateCleanSinusoid(0.08, 1);

            % Add multiple step artifacts
            dirtySignal = cleanSignal;
            dirtySignal = testCase.addStepArtifact(dirtySignal, 100, 3);
            dirtySignal = testCase.addStepArtifact(dirtySignal, 250, -2);
            dirtySignal = testCase.addStepArtifact(dirtySignal, 400, 4);
            dirtySignal = testCase.addStepArtifact(dirtySignal, 500, -3);

            % Apply TDDR
            corrected = pf2_MotionCorrectTDDR(dirtySignal, testCase.fs);

            % The cumulative effect of steps creates large range
            dirtyRange = max(dirtySignal) - min(dirtySignal);
            correctedRange = max(corrected) - min(corrected);

            % TDDR should reduce the range (artifacts corrected)
            testCase.verifyLessThan(correctedRange, dirtyRange, ...
                'TDDR did not reduce signal range from multiple artifacts');

            % Verify output is valid (no NaN, correct size)
            testCase.verifySize(corrected, size(dirtySignal), ...
                'TDDR did not preserve signal size with multiple artifacts');
            testCase.verifyFalse(any(isnan(corrected)), ...
                'TDDR introduced NaN when processing multiple artifacts');
        end
    end
end
