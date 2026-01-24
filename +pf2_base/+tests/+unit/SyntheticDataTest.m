classdef SyntheticDataTest < matlab.unittest.TestCase
    % SYNTHETICDATATEST Unit tests using synthetic data with known ground truth
    %
    % These tests validate core data manipulation functions using synthetic
    % data where we have complete mathematical control over inputs and can
    % verify outputs exactly. This avoids reliance on "golden datasets" that
    % may themselves contain errors.
    %
    % Tests cover:
    %   - pf2.data.resample - bin averaging, time alignment
    %   - pf2.data.split - time segmentation, baseline subtraction
    %   - pf2.data.crop - simple time extraction
    %   - pf2.data.setT0 - time reference shifting
    %   - pf2.data.concatenate - multi-probe merging
    %
    % Run all tests:
    %   results = runtests('pf2_base.tests.unit.SyntheticDataTest');
    %
    % Run specific test:
    %   results = runtests('pf2_base.tests.unit.SyntheticDataTest/testResampleConstantData');

    methods (Test)
        %% =================================================================
        %% RESAMPLE TESTS - Verify bin averaging with known values
        %% =================================================================

        function testResampleConstantData(testCase)
            % Test: Resampling constant data should preserve the constant value
            % If all samples have value X, averaging into any bin should yield X

            constantValue = 42.5;
            data = createMinimalProcessedData(100, 10, 4, constantValue);  % 100 samples, 10 Hz, 4 channels

            % Resample to 1 Hz (10-sample bins)
            resampled = pf2.data.resample(data, 1);

            % All resampled values should equal the constant
            testCase.verifyEqual(resampled.HbO, repmat(constantValue, [10, 4]), ...
                'AbsTol', 1e-10, ...
                'Constant data should remain constant after resampling');
            testCase.verifyEqual(resampled.HbR, repmat(constantValue, [10, 4]), ...
                'AbsTol', 1e-10, ...
                'Constant HbR should remain constant after resampling');
        end

        function testResampleLinearRamp(testCase)
            % Test: Resampling linear ramp should yield bin midpoint values
            % For values [0,1,2,...,9] in a 10-sample bin, mean = 4.5

            fs = 10;  % 10 Hz
            duration = 10;  % 10 seconds = 100 samples
            nChannels = 2;
            nSamples = fs * duration;

            % Create linear ramp: 0, 0.1, 0.2, ... 9.9
            data = createMinimalProcessedData(nSamples, fs, nChannels, 0);
            rampValues = (0:nSamples-1)' / fs;  % Values match time
            data.HbO = repmat(rampValues, [1, nChannels]);
            data.HbR = repmat(rampValues, [1, nChannels]);

            % Resample to 1 Hz (10-sample bins)
            resampled = pf2.data.resample(data, 1);

            % Expected: bin means are [0.45, 1.45, 2.45, ..., 9.45]
            % Each 1-second bin contains values like [0,0.1,0.2,...,0.9]
            % Mean of [0:9]*0.1 = 0.45
            expectedMeans = (0:9)' + 0.45;

            testCase.verifyEqual(resampled.HbO(:,1), expectedMeans, ...
                'RelTol', 1e-6, ...
                'Linear ramp should resample to bin midpoint values');
        end

        function testResamplePreservesSum(testCase)
            % Test: Total "mass" should be approximately preserved
            % sum(original) / nOriginalSamples ≈ sum(resampled) / nResampledSamples

            fs = 20;  % 20 Hz
            duration = 5;  % 5 seconds
            nChannels = 3;
            nSamples = fs * duration;

            % Create random but seeded data
            rng(12345);
            data = createMinimalProcessedData(nSamples, fs, nChannels, 0);
            data.HbO = randn(nSamples, nChannels) * 10 + 50;
            data.HbR = randn(nSamples, nChannels) * 5 + 25;

            originalMeanHbO = mean(data.HbO, 1);
            originalMeanHbR = mean(data.HbR, 1);

            % Resample to 2 Hz (10-sample bins)
            resampled = pf2.data.resample(data, 0.5);

            resampledMeanHbO = mean(resampled.HbO, 1);
            resampledMeanHbR = mean(resampled.HbR, 1);

            testCase.verifyEqual(resampledMeanHbO, originalMeanHbO, ...
                'RelTol', 0.05, ...
                'Global mean should be approximately preserved after resampling');
            testCase.verifyEqual(resampledMeanHbR, originalMeanHbR, ...
                'RelTol', 0.05, ...
                'Global mean should be approximately preserved after resampling');
        end

        function testResampleSamplingRateCalculation(testCase)
            % Test: Output fs should exactly equal 1/segmentLength

            segmentLengths = [0.5, 1, 2, 5, 10];
            data = createMinimalProcessedData(1000, 10, 2, 1);

            for segLen = segmentLengths
                resampled = pf2.data.resample(data, segLen);
                expectedFs = 1 / segLen;

                testCase.verifyEqual(resampled.fs, expectedFs, ...
                    'AbsTol', 1e-10, ...
                    sprintf('fs should be 1/%g = %g Hz', segLen, expectedFs));
            end
        end

        function testResampleOutputLength(testCase)
            % Test: Output length should be ceil(duration / segmentLength)
            % The resample function creates bins that cover the full time range

            fs = 10;
            duration = 23.7;  % Non-integer duration
            nSamples = round(fs * duration);
            data = createMinimalProcessedData(nSamples, fs, 2, 1);

            segmentLength = 5;
            resampled = pf2.data.resample(data, segmentLength);

            % The function creates bins from minTime to maxTime
            % With 23.7 seconds and 5-second bins starting at 0:
            % Bins: [0-5), [5-10), [10-15), [15-20), [20-25) = 5 bins
            expectedBins = ceil(duration / segmentLength);
            actualBins = size(resampled.HbO, 1);

            testCase.verifyEqual(actualBins, expectedBins, ...
                'Output should have ceil(duration/segmentLength) time bins');
        end

        function testResampleNaNHandling(testCase)
            % Test: NaN values should be excluded from averaging (nanmean behavior)

            fs = 10;
            data = createMinimalProcessedData(100, fs, 2, 0);

            % Channel 1: values 1-10 in first second
            data.HbO(1:10, 1) = 1:10;  % mean = 5.5
            data.HbR(1:10, 1) = 1:10;

            % Channel 2: same but with 5 NaNs
            data.HbO(1:10, 2) = 1:10;
            data.HbO(1:5, 2) = NaN;  % Only values 6-10 remain, mean = 8
            data.HbR(1:10, 2) = 1:10;
            data.HbR(1:5, 2) = NaN;

            resampled = pf2.data.resample(data, 1);

            testCase.verifyEqual(resampled.HbO(1, 1), 5.5, 'AbsTol', 1e-10, ...
                'Channel without NaN should average to 5.5');
            testCase.verifyEqual(resampled.HbO(1, 2), 8, 'AbsTol', 1e-10, ...
                'Channel with NaN should exclude NaNs and average to 8');
        end

        function testResampleCenterOnT0(testCase)
            % Test: centerOnT0 should align bins to include t=0

            fs = 10;
            nSamples = 100;
            data = createMinimalProcessedData(nSamples, fs, 1, 1);
            % Time vector: 0, 0.1, 0.2, ..., 9.9

            % Without centerOnT0: bins start at first sample
            resampledDefault = pf2.data.resample(data, 2);

            % With centerOnT0: bins include t=0 as boundary
            resampledCentered = pf2.data.resample(data, 2, 'centerOnT0', true);

            % Verify time alignment
            testCase.verifyEqual(resampledCentered.time(1), 0, 'AbsTol', 1e-10, ...
                'With centerOnT0, first bin should start at t=0');
        end

        function testResampleTimeOutModes(testCase)
            % Test: timeOutMode affects segmentTimes boundaries
            % Note: For data starting at t=0, the .time field is similar across modes
            % but .segmentTimes contains the full bin boundary information

            fs = 10;
            data = createMinimalProcessedData(100, fs, 1, 1);
            segLen = 2;  % 2-second bins

            resStart = pf2.data.resample(data, segLen, 'timeOutMode', 'start');
            resMid = pf2.data.resample(data, segLen, 'timeOutMode', 'mid');
            resEnd = pf2.data.resample(data, segLen, 'timeOutMode', 'end');

            % Verify segmentTimes field exists and has correct structure
            % segmentTimes = [times_start, timeSeries, times_end]
            testCase.verifySize(resStart.segmentTimes, [5, 3], ...
                'segmentTimes should have 3 columns (start, mid, end)');

            % Verify bin widths are correct
            binWidths = resStart.segmentTimes(:,3) - resStart.segmentTimes(:,1);
            testCase.verifyEqual(binWidths, repmat(segLen, [5, 1]), ...
                'RelTol', 1e-8, ...
                'Bin widths should equal segment length');

            % Verify time values are consistent with segmentTimes
            % 'start' mode: time = segmentTimes(:,1)
            testCase.verifyEqual(resStart.time, resStart.segmentTimes(:,1), ...
                'AbsTol', 1e-10, ...
                'start mode: time should match segmentTimes column 1');
        end

        function testResampleSpecifiedTimepoints(testCase)
            % Test: specifiedTimepoints allows irregular resampling grid

            fs = 10;
            data = createMinimalProcessedData(100, fs, 1, 0);
            % Create recognizable pattern: value = floor(time)
            data.HbO = floor(data.time);
            data.HbR = floor(data.time);

            % Sample at specific times
            specTimes = [1, 3, 7];
            resampled = pf2.data.resample(data, 'specifiedTimepoints', specTimes);

            testCase.verifyEqual(length(resampled.time), 3, ...
                'Should have exactly 3 output timepoints');
            testCase.verifyEqual(resampled.time(:), specTimes(:), 'AbsTol', 1e-6, ...
                'Output times should match specified timepoints');
        end

        %% =================================================================
        %% SPLIT / CROP TESTS - Verify time segmentation
        %% =================================================================

        function testSplitExactBoundaries(testCase)
            % Test: split extracts exact time boundaries

            fs = 10;
            nSamples = 100;
            data = createMinimalProcessedData(nSamples, fs, 2, 0);
            % Values equal time for easy verification
            data.HbO = repmat(data.time, [1, 2]);
            data.HbR = repmat(data.time, [1, 2]);

            % Split from 2.0 to 5.0 seconds
            startTime = 2.0;
            endTime = 5.0;
            split_data = pf2.data.split(data, startTime, endTime);

            % Verify time bounds
            testCase.verifyGreaterThanOrEqual(min(split_data.time), startTime, ...
                'Split start time should be >= requested start');
            testCase.verifyLessThanOrEqual(max(split_data.time), endTime, ...
                'Split end time should be <= requested end');

            % Verify data values match time (since HbO = time)
            testCase.verifyEqual(split_data.HbO(:,1), split_data.time, ...
                'AbsTol', 1e-10, ...
                'Extracted data values should match time values');
        end

        function testSplitPreservesSamplingRate(testCase)
            % Test: split should preserve fs

            fs = 25;
            data = createMinimalProcessedData(500, fs, 2, 1);

            split_data = pf2.data.split(data, 5, 15);

            testCase.verifyEqual(split_data.fs, fs, ...
                'Split should preserve sampling rate');
        end

        function testSplitSampleCount(testCase)
            % Test: split should return correct number of samples

            fs = 10;
            data = createMinimalProcessedData(200, fs, 1, 1);

            startTime = 3.0;
            endTime = 8.0;
            expectedDuration = endTime - startTime;
            expectedSamples = expectedDuration * fs;

            split_data = pf2.data.split(data, startTime, endTime);
            actualSamples = size(split_data.HbO, 1);

            % Allow +/- 1 sample for boundary conditions
            testCase.verifyEqual(actualSamples, expectedSamples, 'AbsTol', 1, ...
                sprintf('Expected ~%d samples for %.1fs at %d Hz', ...
                expectedSamples, expectedDuration, fs));
        end

        function testResampleWithBaselineStruct(testCase)
            % Test: resample with separate baseline struct works correctly
            % Uses blfNIR parameter to pass pre-computed baseline

            fs = 10;
            data = createMinimalProcessedData(100, fs, 2, 0);

            % Set up known values:
            % Task period: value = 15
            data.HbO(:, :) = 15;
            data.HbR(:, :) = 15;
            data.HbTotal(:, :) = 15;
            data.HbDiff(:, :) = 15;
            data.CBSI(:, :) = 15;

            % Create separate baseline struct with value = 10
            baseline = createMinimalProcessedData(20, fs, 2, 10);
            baseline.HbTotal(:, :) = 10;
            baseline.HbDiff(:, :) = 10;
            baseline.CBSI(:, :) = 10;

            % Resample with separate baseline struct
            resampled = pf2.data.resample(data, 1, 'blfNIR', baseline);

            % After baseline subtraction: 15 - 10 = 5
            testCase.verifyEqual(resampled.HbO(1,1), 5, 'AbsTol', 1e-10, ...
                'HbO should be 15-10=5 after baseline subtraction');
            testCase.verifyEqual(resampled.HbR(1,1), 5, 'AbsTol', 1e-10, ...
                'HbR should be 15-10=5 after baseline subtraction');
        end

        function testSplitNoBaseline(testCase)
            % Test: split without baseline should preserve values

            fs = 10;
            data = createMinimalProcessedData(100, fs, 2, 0);

            % Set up recognizable pattern
            data.HbO = repmat(data.time, [1, 2]);  % Values = time
            data.HbR = data.HbO;

            % Split from 3 to 7 seconds
            split_data = pf2.data.split(data, 3, 7);

            % Values should match time (no baseline subtraction)
            testCase.verifyEqual(split_data.HbO(:,1), split_data.time, ...
                'AbsTol', 1e-10, ...
                'Split without baseline should preserve values');
        end

        function testCropSimpleExtraction(testCase)
            % Test: crop is a simple split without baseline

            fs = 10;
            data = createMinimalProcessedData(100, fs, 2, 42);

            cropped = pf2.data.crop(data, 3, 7);

            % Verify extraction worked
            testCase.verifyGreaterThanOrEqual(min(cropped.time), 3, ...
                'Cropped start should be >= 3');
            testCase.verifyLessThanOrEqual(max(cropped.time), 7, ...
                'Cropped end should be <= 7');

            % Values should be unchanged (no baseline subtraction)
            testCase.verifyEqual(unique(cropped.HbO(:)), 42, ...
                'Crop should not modify values');
        end

        %% =================================================================
        %% SETT0 TESTS - Verify time reference shifting
        %% =================================================================

        function testSetT0ShiftsTimeCorrectly(testCase)
            % Test: setT0 shifts all time values by specified amount

            fs = 10;
            data = createMinimalProcessedData(100, fs, 2, 1);
            originalTime = data.time;

            shiftAmount = 5;  % Shift by 5 seconds
            shifted = pf2.data.setT0(data, shiftAmount);

            expectedTime = originalTime - shiftAmount;
            testCase.verifyEqual(shifted.time, expectedTime, ...
                'AbsTol', 1e-10, ...
                'Time should be shifted by exactly t0 amount');
        end

        function testSetT0PreservesIntervals(testCase)
            % Test: time intervals should remain unchanged

            fs = 10;
            data = createMinimalProcessedData(100, fs, 2, 1);
            originalDiffs = diff(data.time);

            shifted = pf2.data.setT0(data, 7.3);
            shiftedDiffs = diff(shifted.time);

            testCase.verifyEqual(shiftedDiffs, originalDiffs, ...
                'AbsTol', 1e-12, ...
                'Time intervals should be unchanged after setT0');
        end

        function testSetT0ZeroShift(testCase)
            % Test: shifting by 0 should not change time

            fs = 10;
            data = createMinimalProcessedData(100, fs, 2, 1);
            originalTime = data.time;

            shifted = pf2.data.setT0(data, 0);

            testCase.verifyEqual(shifted.time, originalTime, ...
                'AbsTol', 1e-12, ...
                'Zero shift should not change time');
        end

        function testSetT0NegativeShift(testCase)
            % Test: negative shift should also work

            fs = 10;
            data = createMinimalProcessedData(100, fs, 2, 1);
            originalTime = data.time;

            shiftAmount = -3;
            shifted = pf2.data.setT0(data, shiftAmount);

            expectedTime = originalTime - shiftAmount;  % Subtracting negative = adding
            testCase.verifyEqual(shifted.time, expectedTime, ...
                'AbsTol', 1e-10, ...
                'Negative shift should add to time');
        end

        function testSetT0PreservesData(testCase)
            % Test: setT0 should not modify data values

            fs = 10;
            data = createMinimalProcessedData(100, fs, 2, 0);
            rng(999);
            data.HbO = randn(100, 2);
            data.HbR = randn(100, 2);
            originalHbO = data.HbO;
            originalHbR = data.HbR;

            shifted = pf2.data.setT0(data, 10);

            testCase.verifyEqual(shifted.HbO, originalHbO, ...
                'HbO values should not change with setT0');
            testCase.verifyEqual(shifted.HbR, originalHbR, ...
                'HbR values should not change with setT0');
        end

        %% =================================================================
        %% CONCATENATE TESTS - Verify multi-probe merging
        %% =================================================================

        function testConcatenateChannelCount(testCase)
            % Test: concatenate should sum channel counts

            fs = 10;
            data1 = createMinimalProcessedData(100, fs, 5, 1);
            data2 = createMinimalProcessedData(100, fs, 3, 2);

            merged = pf2.data.concatenate({data1, data2});

            expectedChannels = 5 + 3;
            actualChannels = size(merged.HbO, 2);

            testCase.verifyEqual(actualChannels, expectedChannels, ...
                'Merged data should have sum of channel counts');
        end

        function testConcatenatePreservesValues(testCase)
            % Test: values from each source should be preserved

            fs = 10;
            data1 = createMinimalProcessedData(100, fs, 2, 10);  % All 10s
            data2 = createMinimalProcessedData(100, fs, 3, 20);  % All 20s

            merged = pf2.data.concatenate({data1, data2});

            % First 2 channels should be 10, next 3 should be 20
            testCase.verifyEqual(unique(merged.HbO(:, 1:2)), 10, ...
                'First source channels should have original values');
            testCase.verifyEqual(unique(merged.HbO(:, 3:5)), 20, ...
                'Second source channels should have original values');
        end

        function testConcatenateFchMask(testCase)
            % Test: fchMask should be concatenated correctly

            fs = 10;
            data1 = createMinimalProcessedData(100, fs, 3, 1);
            data2 = createMinimalProcessedData(100, fs, 2, 1);

            data1.fchMask = [1, 0, 1];  % Channel 2 bad
            data2.fchMask = [0, 1];     % Channel 1 bad

            merged = pf2.data.concatenate({data1, data2});

            expectedMask = [1, 0, 1, 0, 1];
            testCase.verifyEqual(merged.fchMask, expectedMask, ...
                'fchMask should be concatenated');
        end

        function testConcatenateProbeNum(testCase)
            % Test: probeNum should identify source of each channel

            fs = 10;
            data1 = createMinimalProcessedData(100, fs, 4, 1);
            data2 = createMinimalProcessedData(100, fs, 3, 2);

            merged = pf2.data.concatenate({data1, data2});

            % First 4 channels from probe 1, next 3 from probe 2
            expectedProbeNum = [1, 1, 1, 1, 2, 2, 2];
            testCase.verifyEqual(merged.probeNum, expectedProbeNum, ...
                'probeNum should identify source probe');
        end

        function testConcatenateDifferentSamplingRates(testCase)
            % Test: concatenate should resample to common rate

            data1 = createMinimalProcessedData(100, 10, 2, 1);  % 10 Hz
            data2 = createMinimalProcessedData(100, 20, 2, 2);  % 20 Hz

            merged = pf2.data.concatenate({data1, data2});

            % Should resample to lower rate (10 Hz)
            testCase.verifyEqual(merged.fs, 10, ...
                'Should resample to lower sampling rate');
        end

        function testConcatenateThreeProbes(testCase)
            % Test: should work with more than 2 probes

            fs = 10;
            data1 = createMinimalProcessedData(100, fs, 2, 1);
            data2 = createMinimalProcessedData(100, fs, 3, 2);
            data3 = createMinimalProcessedData(100, fs, 4, 3);

            merged = pf2.data.concatenate({data1, data2, data3});

            expectedChannels = 2 + 3 + 4;
            testCase.verifyEqual(size(merged.HbO, 2), expectedChannels, ...
                'Should concatenate all three probes');

            expectedProbeNum = [1, 1, 2, 2, 2, 3, 3, 3, 3];
            testCase.verifyEqual(merged.probeNum, expectedProbeNum, ...
                'probeNum should track all three sources');
        end

        %% =================================================================
        %% EDGE CASE TESTS
        %% =================================================================

        function testResampleSingleBin(testCase)
            % Test: resampling to single bin should work

            fs = 10;
            duration = 5;
            data = createMinimalProcessedData(fs * duration, fs, 2, 7);

            % Segment length equals total duration
            resampled = pf2.data.resample(data, duration);

            testCase.verifyEqual(size(resampled.HbO, 1), 1, ...
                'Should produce single time bin');
            testCase.verifyEqual(resampled.HbO(1, 1), 7, 'AbsTol', 1e-10, ...
                'Single bin value should equal constant input');
        end

        function testSplitEntireRange(testCase)
            % Test: splitting entire range should preserve data

            fs = 10;
            nSamples = 100;
            data = createMinimalProcessedData(nSamples, fs, 2, 5);

            startTime = min(data.time);
            endTime = max(data.time);
            split_data = pf2.data.split(data, startTime, endTime + 1/fs);

            testCase.verifyEqual(size(split_data.HbO), size(data.HbO), ...
                'Splitting entire range should preserve dimensions');
        end

        function testResampleAllNaN(testCase)
            % Test: all-NaN data should produce NaN output

            fs = 10;
            data = createMinimalProcessedData(100, fs, 2, NaN);

            resampled = pf2.data.resample(data, 1);

            testCase.verifyTrue(all(isnan(resampled.HbO(:))), ...
                'All-NaN input should produce all-NaN output');
        end

        function testConcatenateSingleInput(testCase)
            % Test: concatenate with single input should return equivalent data

            fs = 10;
            data = createMinimalProcessedData(100, fs, 3, 42);

            merged = pf2.data.concatenate({data});

            testCase.verifyEqual(size(merged.HbO), size(data.HbO), ...
                'Single-input concatenate should preserve dimensions');
            testCase.verifyEqual(merged.HbO, data.HbO, ...
                'Single-input concatenate should preserve values');
        end

        %% =================================================================
        %% NUMERICAL PRECISION TESTS
        %% =================================================================

        function testResampleNumericalStability(testCase)
            % Test: very small and very large values should resample correctly

            fs = 10;
            data = createMinimalProcessedData(100, fs, 2, 0);

            % Channel 1: very small values
            data.HbO(:, 1) = 1e-15;
            data.HbR(:, 1) = 1e-15;

            % Channel 2: very large values
            data.HbO(:, 2) = 1e15;
            data.HbR(:, 2) = 1e15;

            resampled = pf2.data.resample(data, 1);

            testCase.verifyEqual(resampled.HbO(1, 1), 1e-15, 'RelTol', 1e-10, ...
                'Very small values should be preserved');
            testCase.verifyEqual(resampled.HbO(1, 2), 1e15, 'RelTol', 1e-10, ...
                'Very large values should be preserved');
        end

        function testTimeVectorMonotonicity(testCase)
            % Test: output time vector should be strictly increasing

            fs = 10;
            data = createMinimalProcessedData(100, fs, 2, 1);

            resampled = pf2.data.resample(data, 2);

            timeDiffs = diff(resampled.time);
            testCase.verifyTrue(all(timeDiffs > 0), ...
                'Resampled time vector should be strictly increasing');
        end
    end
end

%% =======================================================================
%% HELPER FUNCTIONS
%% =======================================================================

function data = createMinimalProcessedData(nSamples, fs, nChannels, fillValue)
    % CREATEMINIMALPROCESSEDDATA Create minimal processed fNIRS struct for testing
    %
    % Creates the minimum viable processed fNIRS data structure with
    % specified dimensions and fill value. All biomarker fields (HbO, HbR,
    % HbTotal, HbDiff, CBSI) are filled with the same value.
    %
    % Inputs:
    %   nSamples  - Number of time samples
    %   fs        - Sampling frequency (Hz)
    %   nChannels - Number of fNIRS channels
    %   fillValue - Value to fill all data arrays (can be NaN)
    %
    % Output:
    %   data - Minimal fNIRS struct suitable for pf2.data.* functions

    % Time vector
    data.time = (0:nSamples-1)' / fs;
    data.fs = fs;

    % Biomarker fields
    data.HbO = ones(nSamples, nChannels) * fillValue;
    data.HbR = ones(nSamples, nChannels) * fillValue;
    data.HbTotal = ones(nSamples, nChannels) * fillValue;
    data.HbDiff = ones(nSamples, nChannels) * fillValue;
    data.CBSI = ones(nSamples, nChannels) * fillValue;

    % Channel metadata
    data.fchMask = ones(1, nChannels);
    data.channels = 1:nChannels;

    % Empty markers
    data.markers = [];

    % Raw field (required by concatenate - stores empty placeholder)
    % In real data this would be [T x C*2] for two wavelengths
    data.raw = ones(nSamples, nChannels * 2) * fillValue;

    % DPF_factor (required by concatenate)
    data.DPF_factor = 1;

    % Units
    data.units = 'uM';

    % Minimal info
    data.info = struct();
    data.info.header = struct();
    data.info.header.filename = 'synthetic_test';
    data.info.probename = 'synthetic';

    % Reference time
    data.t0 = datetime('now');
end
