classdef DataManipulationTest < matlab.unittest.TestCase
    % DATAMANIPULATIONTEST Unit tests for pf2.data functions
    %
    % Tests functions in +pf2/+data/ including:
    %   - pf2.data.resample
    %   - pf2.data.setT0
    %   - pf2.data.concatenate
    %   - pf2.data.getMarkers
    %
    % Run all tests:
    %   results = runtests('pf2_base.tests.unit.DataManipulationTest');
    %
    % Run specific test:
    %   results = runtests('pf2_base.tests.unit.DataManipulationTest/testResampleChangesFs');

    properties (TestParameter)
        % Test parameters can be defined here for parameterized tests
    end

    properties
        sampleData      % Processed fNIRS sample data
        rawData         % Raw (unprocessed) fNIRS sample data
        dataWithMarkers % Processed fNIRS sample data with synthetic markers
    end

    methods (TestClassSetup)
        function loadSampleData(testCase)
            % Load sample data once for all tests
            % Load raw data and process it to get hemoglobin values
            testCase.rawData = pf2.import.sampleData.fNIR2000();
            testCase.sampleData = processFNIRS2(testCase.rawData);

            % Create a version with synthetic markers for getMarkers tests
            testCase.dataWithMarkers = testCase.sampleData;
            % Create markers: [time, code, duration]
            % Marker codes: 49 (baseline), 50 (task start), 51 (task end)
            timeVec = testCase.sampleData.time;
            minT = min(timeVec);
            maxT = max(timeVec);
            duration = maxT - minT;

            % Create evenly spaced markers
            testCase.dataWithMarkers.markers = [
                minT + duration*0.05, 49, 0;   % Baseline marker
                minT + duration*0.10, 50, 0;   % Task start 1
                minT + duration*0.20, 51, 0;   % Task end 1
                minT + duration*0.30, 50, 0;   % Task start 2
                minT + duration*0.40, 51, 0;   % Task end 2
                minT + duration*0.50, 49, 0;   % Baseline marker
                minT + duration*0.60, 50, 0;   % Task start 3
                minT + duration*0.70, 51, 0;   % Task end 3
                minT + duration*0.80, 52, 0;   % Different marker
            ];
        end
    end

    methods (TestMethodSetup)
        function resetWarnings(~)
            % Reset warning state before each test
            warning('on', 'all');
        end
    end

    %% Resample Tests
    methods (Test)
        function testResampleChangesFs(testCase)
            % Test that resampling changes the sampling frequency to target rate

            % Original sampling rate
            originalFs = testCase.sampleData.fs;

            % Target segment length (10 seconds = 0.1 Hz output)
            segmentLength = 10;
            targetFs = 1 / segmentLength;

            % Resample the data
            resampled = pf2.data.resample(testCase.sampleData, segmentLength);

            % Verify fs changed to expected value
            testCase.verifyEqual(resampled.fs, targetFs, ...
                sprintf('Expected fs=%.4f Hz, got fs=%.4f Hz', targetFs, resampled.fs));

            % Verify fs is different from original (unless by coincidence)
            testCase.verifyNotEqual(resampled.fs, originalFs, ...
                'Resampled fs should differ from original fs');
        end

        function testResamplePreservesMarkers(testCase)
            % Test that markers are preserved after resampling

            % Get original marker count
            if isfield(testCase.sampleData, 'markers') && ~isempty(testCase.sampleData.markers)
                originalMarkerCount = size(testCase.sampleData.markers, 1);

                % Resample the data
                resampled = pf2.data.resample(testCase.sampleData, 5);

                % Verify markers field still exists
                testCase.verifyTrue(isfield(resampled, 'markers'), ...
                    'Resampled data should have markers field');

                % Verify marker count is preserved
                resampledMarkerCount = size(resampled.markers, 1);
                testCase.verifyEqual(resampledMarkerCount, originalMarkerCount, ...
                    'Marker count should be preserved after resampling');
            else
                % If no markers in sample data, verify field structure is preserved
                resampled = pf2.data.resample(testCase.sampleData, 5);
                testCase.verifyTrue(isfield(resampled, 'markers'), ...
                    'Resampled data should have markers field');
            end
        end

        function testResampleReducesSamples(testCase)
            % Test that lower sampling rate results in fewer samples

            % Get original sample count
            originalSamples = size(testCase.sampleData.HbO, 1);
            originalFs = testCase.sampleData.fs;

            % Use a segment length that will reduce samples (larger than 1/fs)
            segmentLength = 10;  % 10-second bins

            % Resample the data
            resampled = pf2.data.resample(testCase.sampleData, segmentLength);

            % Get resampled sample count
            resampledSamples = size(resampled.HbO, 1);

            % Verify fewer samples (since we're downsampling)
            testCase.verifyLessThan(resampledSamples, originalSamples, ...
                sprintf('Resampled should have fewer samples: got %d, original %d', ...
                resampledSamples, originalSamples));

            % Verify approximate ratio matches expected downsampling factor
            expectedRatio = segmentLength * originalFs;
            actualRatio = originalSamples / resampledSamples;
            testCase.verifyEqual(actualRatio, expectedRatio, 'RelTol', 0.1, ...
                'Downsampling ratio should approximately match segment length * original fs');
        end

        function testResamplePreservesFields(testCase)
            % Test that required fNIRS fields are still present after resampling

            % Required fields for processed data
            requiredFields = {'time', 'fs', 'HbO', 'HbR', 'fchMask', 'channels'};

            % Resample the data
            resampled = pf2.data.resample(testCase.sampleData, 5);

            % Verify each required field exists
            for i = 1:length(requiredFields)
                fieldName = requiredFields{i};
                testCase.verifyTrue(isfield(resampled, fieldName), ...
                    sprintf('Required field ''%s'' should be present after resampling', fieldName));
            end

            % Verify HbO and HbR have same number of rows as time
            testCase.verifyEqual(size(resampled.HbO, 1), length(resampled.time), ...
                'HbO rows should match time vector length');
            testCase.verifyEqual(size(resampled.HbR, 1), length(resampled.time), ...
                'HbR rows should match time vector length');
        end
    end

    %% setT0 Tests
    methods (Test)
        function testSetT0ShiftsTime(testCase)
            % Test that setT0 shifts the time vector by the specified amount

            % Get original time
            originalTime = testCase.sampleData.time;
            originalMinTime = min(originalTime);

            % Set new t0 (shift by 10 seconds)
            shiftAmount = 10;
            shifted = pf2.data.setT0(testCase.sampleData, shiftAmount);

            % Verify time was shifted
            shiftedMinTime = min(shifted.time);
            expectedMinTime = originalMinTime - shiftAmount;

            testCase.verifyEqual(shiftedMinTime, expectedMinTime, 'AbsTol', 1e-6, ...
                sprintf('Time should be shifted by %.1f seconds', shiftAmount));

            % Verify time vector length unchanged
            testCase.verifyEqual(length(shifted.time), length(originalTime), ...
                'Time vector length should be unchanged');

            % Verify relative time differences unchanged
            originalDiffs = diff(originalTime);
            shiftedDiffs = diff(shifted.time);
            testCase.verifyEqual(shiftedDiffs, originalDiffs, 'AbsTol', 1e-10, ...
                'Time step intervals should be unchanged');
        end
    end

    %% Concatenate Tests
    methods (Test)
        function testConcatenateVertical(testCase)
            % Test that concatenated data has combined channel count

            % Use the same data twice to simulate two probes
            data1 = testCase.sampleData;
            data2 = testCase.sampleData;

            % Get original channel counts
            numCh1 = size(data1.HbO, 2);
            numCh2 = size(data2.HbO, 2);

            % Concatenate
            merged = pf2.data.concatenate({data1, data2});

            % Verify combined channel count
            expectedChannels = numCh1 + numCh2;
            actualChannels = size(merged.HbO, 2);

            testCase.verifyEqual(actualChannels, expectedChannels, ...
                sprintf('Concatenated data should have %d channels (got %d)', ...
                expectedChannels, actualChannels));

            % Verify HbO and HbR have same dimensions
            testCase.verifyEqual(size(merged.HbO), size(merged.HbR), ...
                'HbO and HbR should have same dimensions after concatenation');
        end

        function testConcatenatePreservesChannels(testCase)
            % Test that channel information is preserved after concatenation

            % Use the same data twice
            data1 = testCase.sampleData;
            data2 = testCase.sampleData;

            numCh1 = length(data1.channels);
            numCh2 = length(data2.channels);

            % Concatenate
            merged = pf2.data.concatenate({data1, data2});

            % Verify channels field exists and has correct count
            testCase.verifyTrue(isfield(merged, 'channels'), ...
                'Concatenated data should have channels field');

            expectedChannelCount = numCh1 + numCh2;
            testCase.verifyEqual(length(merged.channels), expectedChannelCount, ...
                sprintf('Should have %d channels, got %d', ...
                expectedChannelCount, length(merged.channels)));

            % Verify probeNum field exists (maps channels to source probe)
            testCase.verifyTrue(isfield(merged, 'probeNum'), ...
                'Concatenated data should have probeNum field');

            % Verify probeNum has correct length
            testCase.verifyEqual(length(merged.probeNum), expectedChannelCount, ...
                'probeNum should have same length as channel count');

            % Verify fchMask is also concatenated
            testCase.verifyTrue(isfield(merged, 'fchMask'), ...
                'Concatenated data should have fchMask field');
            testCase.verifyEqual(length(merged.fchMask), expectedChannelCount, ...
                'fchMask should have same length as channel count');
        end
    end

    %% getMarkers Tests
    methods (Test)
        function testGetMarkersReturnsSubset(testCase)
            % Test that pattern matching returns a subset of markers

            % Use dataWithMarkers which has synthetic markers
            data = testCase.dataWithMarkers;

            % Get all unique marker codes
            allMarkerCodes = unique(data.markers(:, 2));

            % Select marker code 50 (task start) - we know there are 3 of these
            targetCode = 50;

            % Get markers matching target code
            matchedMarkers = pf2.data.getMarkers(data, targetCode);

            % Verify we got results
            expectedCount = sum(data.markers(:, 2) == targetCode);
            testCase.verifyEqual(expectedCount, 3, ...
                'Test setup: should have 3 markers with code 50');

            testCase.verifyNotEmpty(matchedMarkers, ...
                sprintf('Should find markers with code %d', targetCode));

            % Verify count matches expected
            actualCount = size(matchedMarkers, 1);
            testCase.verifyEqual(actualCount, expectedCount, ...
                sprintf('Should find %d markers with code %d, found %d', ...
                expectedCount, targetCode, actualCount));

            % Verify returned times are correct (first column is time)
            expectedTimes = data.markers(data.markers(:,2) == targetCode, 1);
            testCase.verifyEqual(sort(matchedMarkers(:,1)), sort(expectedTimes), 'AbsTol', 1e-6, ...
                'Returned marker times should match expected times');
        end

        function testGetMarkersEmptyPattern(testCase)
            % Test that getMarkers correctly handles sequential patterns

            % Use dataWithMarkers which has synthetic markers
            data = testCase.dataWithMarkers;

            % Get all unique marker codes
            allMarkerCodes = unique(data.markers(:, 2));

            % Verify we have the expected marker codes (49, 50, 51, 52)
            testCase.verifyEqual(length(allMarkerCodes), 4, ...
                'Test setup: should have 4 unique marker codes');

            % Test: Search for sequence pattern [50, 51] (task start followed by task end)
            % This pattern should match 3 times based on our synthetic markers
            sequencePattern = [50, 51];  % Row vector for sequence matching
            matchedMarkers = pf2.data.getMarkers(data, sequencePattern);

            % We have 3 occurrences of 50 followed by 51
            expectedCount = 3;

            testCase.verifyEqual(size(matchedMarkers, 1), expectedCount, ...
                sprintf('Searching for sequence [50,51] should return %d markers', expectedCount));

            % Verify returned marker times are valid
            testCase.verifyNotEmpty(matchedMarkers, ...
                'Should return markers when searching for sequence pattern');

            % Verify returned times match the times of marker 50 occurrences
            expectedStartTimes = data.markers(data.markers(:,2) == 50, 1);
            testCase.verifyEqual(sort(matchedMarkers(:,1)), sort(expectedStartTimes), 'AbsTol', 1e-6, ...
                'Sequence start times should match marker 50 times');
        end
    end

    %% Additional Edge Case Tests
    methods (Test)
        function testResampleWithCenterOnT0(testCase)
            % Test resample with centerOnT0 option

            segmentLength = 5;

            % Resample with centerOnT0
            resampled = pf2.data.resample(testCase.sampleData, segmentLength, ...
                'centerOnT0', true);

            % Verify output structure is valid
            testCase.verifyTrue(isfield(resampled, 'time'), ...
                'Resampled data should have time field');
            testCase.verifyTrue(isfield(resampled, 'HbO'), ...
                'Resampled data should have HbO field');

            % Verify fs is set correctly
            testCase.verifyEqual(resampled.fs, 1/segmentLength, ...
                'fs should equal 1/segmentLength');
        end

        function testSetT0WithZeroShift(testCase)
            % Test setT0 with zero shift (should not change time)

            originalTime = testCase.sampleData.time;

            shifted = pf2.data.setT0(testCase.sampleData, 0);

            testCase.verifyEqual(shifted.time, originalTime, 'AbsTol', 1e-10, ...
                'Zero shift should not change time vector');
        end

        function testConcatenateTwoStructsSyntax(testCase)
            % Test concatenate with two struct syntax (not cell array)

            data1 = testCase.sampleData;
            data2 = testCase.sampleData;

            % Use two-argument syntax
            merged = pf2.data.concatenate(data1, data2);

            % Verify merged data has expected channel count
            expectedChannels = size(data1.HbO, 2) + size(data2.HbO, 2);
            testCase.verifyEqual(size(merged.HbO, 2), expectedChannels, ...
                'Two-struct syntax should concatenate channels correctly');
        end
    end
end
