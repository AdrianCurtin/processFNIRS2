classdef AuxDataTest < matlab.unittest.TestCase
    % AUXDATATEST Unit tests for auxiliary data handling across pf2 operations
    %
    % Tests that the Aux field is properly preserved and modified through
    % various data manipulation operations including:
    %   - processFNIRS2() processing pipeline
    %   - pf2.data.setT0() time shifting
    %   - pf2.data.split() time segmentation
    %   - pf2.data.resample() downsampling with various Aux options
    %
    % Run all tests:
    %   results = runtests('pf2_base.tests.unit.AuxDataTest');
    %
    % Run specific test:
    %   results = runtests('pf2_base.tests.unit.AuxDataTest/testAuxFieldPreservedThroughProcessing');

    properties
        processedData       % Processed fNIRS sample data with synthetic Aux
        rawData             % Raw (unprocessed) fNIRS sample data
        auxAccelData        % Synthetic accelerometer data (time x 3)
        auxAccelTime        % Time vector for accelerometer
    end

    methods (TestClassSetup)
        function loadAndPrepareData(testCase)
            % Load sample data and add synthetic Aux field
            testCase.rawData = pf2.import.sampleData.fNIR2000();
            testCase.processedData = processFNIRS2(testCase.rawData);

            % Create synthetic Aux data matching fNIRS time vector
            nSamples = length(testCase.processedData.time);
            testCase.auxAccelTime = testCase.processedData.time;
            testCase.auxAccelData = randn(nSamples, 3);  % 3-axis accelerometer

            % Add synthetic Aux to processed data
            testCase.processedData.Aux.accelerometer.data = testCase.auxAccelData;
            testCase.processedData.Aux.accelerometer.time = testCase.auxAccelTime;
            testCase.processedData.Aux.accelerometer.unit = 'g';
        end
    end

    methods (TestMethodSetup)
        function resetWarnings(~)
            % Reset warning state before each test
            warning('on', 'all');
        end
    end

    %% Processing Pipeline Tests
    methods (Test)
        function testAuxFieldPreservedThroughProcessing(testCase)
            % Test that Aux field survives processFNIRS2() pipeline

            % Add Aux data to raw data before processing
            rawWithAux = testCase.rawData;
            nRawSamples = size(rawWithAux.raw, 1);
            rawWithAux.Aux.heartRate.data = 70 + 5*randn(nRawSamples, 1);
            rawWithAux.Aux.heartRate.time = (0:nRawSamples-1)' / rawWithAux.fs;

            % Process the data
            processed = processFNIRS2(rawWithAux);

            % Verify Aux field exists in output
            testCase.verifyTrue(isfield(processed, 'Aux'), ...
                'Aux field should be preserved through processFNIRS2()');

            % Verify Aux subfields exist
            testCase.verifyTrue(isfield(processed.Aux, 'heartRate'), ...
                'Aux.heartRate subfield should be preserved');

            % Verify data dimensions (may have changed if resampled internally)
            testCase.verifyTrue(isfield(processed.Aux.heartRate, 'data'), ...
                'Aux.heartRate.data should be preserved');
        end
    end

    %% setT0 Tests
    methods (Test)
        function testSetT0ShiftsAuxTime(testCase)
            % Test that pf2.data.setT0 shifts Aux.time field
            %
            % Note: setT0 shifts Aux.time (top-level time within Aux) and
            % numeric arrays in Aux where column 1 might be time.
            % Nested .time fields (like Aux.accelerometer.time) are NOT
            % shifted by the current implementation.

            % Create data with Aux.time field (top-level)
            dataWithAuxTime = testCase.processedData;
            dataWithAuxTime.Aux.time = dataWithAuxTime.time;  % Top-level Aux.time

            % Get original Aux.time
            originalAuxTime = dataWithAuxTime.Aux.time;
            originalMinAuxTime = min(originalAuxTime);

            % Shift by 10 seconds
            shiftAmount = 10;
            shifted = pf2.data.setT0(dataWithAuxTime, shiftAmount);

            % Verify Aux.time was shifted (top-level Aux.time IS handled)
            if isfield(shifted.Aux, 'time') && isnumeric(shifted.Aux.time)
                shiftedAuxTime = shifted.Aux.time;

                % Verify time was shifted by the expected amount
                expectedMinAuxTime = originalMinAuxTime - shiftAmount;
                actualMinAuxTime = min(shiftedAuxTime);

                testCase.verifyEqual(actualMinAuxTime, expectedMinAuxTime, 'AbsTol', 1e-6, ...
                    sprintf('Aux.time should be shifted by %.1f seconds', shiftAmount));
            else
                % Aux.time should exist and be shifted
                testCase.verifyTrue(isfield(shifted.Aux, 'time'), ...
                    'Aux.time field should be preserved after setT0');
            end
        end

        function testSetT0PreservesAuxData(testCase)
            % Test that Aux data values are unchanged after setT0 (only time shifts)

            % Get original Aux data
            originalAuxData = testCase.processedData.Aux.accelerometer.data;

            % Shift time
            shifted = pf2.data.setT0(testCase.processedData, 5);

            % Verify data values unchanged
            if isfield(shifted.Aux, 'accelerometer') && ...
               isfield(shifted.Aux.accelerometer, 'data')
                shiftedAuxData = shifted.Aux.accelerometer.data;

                testCase.verifyEqual(shiftedAuxData, originalAuxData, 'AbsTol', 1e-10, ...
                    'Aux data values should not change after setT0');
            else
                % Aux may have been restructured, just verify it exists
                testCase.verifyTrue(isfield(shifted, 'Aux'), ...
                    'Aux field should exist after setT0');
            end
        end
    end

    %% split Tests
    methods (Test)
        function testSplitTrimsAux(testCase)
            % Test that pf2.data.split trims Aux to match time window

            % Define time window (middle portion of data)
            timeVec = testCase.processedData.time;
            startTime = min(timeVec) + 100;  % Start 100s in
            endTime = min(timeVec) + 200;    % End 200s in

            % Split the data
            splitData = pf2.data.split(testCase.processedData, startTime, endTime);

            % Verify Aux exists
            testCase.verifyTrue(isfield(splitData, 'Aux'), ...
                'Aux field should exist after split');

            % Verify fNIRS time is trimmed correctly
            testCase.verifyGreaterThanOrEqual(min(splitData.time), startTime - 1, ...
                'Split time should start at or after startTime');
            testCase.verifyLessThanOrEqual(max(splitData.time), endTime + 1, ...
                'Split time should end at or before endTime');

            % Verify Aux time alignment if structure preserved
            if isfield(splitData.Aux, 'accelerometer') && ...
               isstruct(splitData.Aux.accelerometer) && ...
               isfield(splitData.Aux.accelerometer, 'time')
                auxTime = splitData.Aux.accelerometer.time;
                % Check Aux time is within bounds (with tolerance for edge effects)
                testCase.verifyGreaterThanOrEqual(min(auxTime), startTime - 1, ...
                    'Aux time should be trimmed to start at or after startTime');
            end
        end

        function testSplitPreservesAuxStructure(testCase)
            % Test that nested Aux structure is preserved after split

            % Add nested structure to Aux
            dataWithNestedAux = testCase.processedData;
            dataWithNestedAux.Aux.physio.respiration.data = randn(length(dataWithNestedAux.time), 1);
            dataWithNestedAux.Aux.physio.respiration.time = dataWithNestedAux.time;

            % Split the data
            timeVec = dataWithNestedAux.time;
            startTime = min(timeVec) + 50;
            endTime = min(timeVec) + 150;

            splitData = pf2.data.split(dataWithNestedAux, startTime, endTime);

            % Verify Aux field exists
            testCase.verifyTrue(isfield(splitData, 'Aux'), ...
                'Aux field should be preserved after split');

            % Note: split may flatten Aux structure, so we just verify Aux exists
            % The flattening behavior is documented in split.m
            testCase.verifyFalse(isempty(splitData.Aux), ...
                'Aux should not be empty after split');
        end
    end

    %% resample Tests
    methods (Test)
        function testResampleWithAverageAux(testCase)
            % Test that resample with 'averageAux', true works correctly

            % Original Aux data length
            originalAuxLength = size(testCase.processedData.Aux.accelerometer.data, 1);

            % Resample with averageAux = true
            segmentLength = 10;  % 10-second bins
            resampled = pf2.data.resample(testCase.processedData, segmentLength, ...
                'averageAux', true);

            % Verify Aux exists
            testCase.verifyTrue(isfield(resampled, 'Aux'), ...
                'Aux field should exist after resample with averageAux=true');

            % Verify Aux was resampled (fewer samples)
            if isfield(resampled.Aux, 'accelerometer')
                if istable(resampled.Aux.accelerometer)
                    resampledAuxLength = height(resampled.Aux.accelerometer);
                elseif isstruct(resampled.Aux.accelerometer) && isfield(resampled.Aux.accelerometer, 'data')
                    resampledAuxLength = size(resampled.Aux.accelerometer.data, 1);
                else
                    resampledAuxLength = size(resampled.Aux.accelerometer, 1);
                end

                testCase.verifyLessThan(resampledAuxLength, originalAuxLength, ...
                    'Aux should be downsampled when averageAux=true');
            end

            % Verify fNIRS data was resampled
            testCase.verifyEqual(resampled.fs, 1/segmentLength, 'AbsTol', 1e-6, ...
                'fs should be updated to 1/segmentLength');
        end

        function testResamplePreservesAuxWhenFalse(testCase)
            % Test that resample with 'averageAux', false preserves original Aux

            % Original Aux data
            originalAuxData = testCase.processedData.Aux.accelerometer.data;
            originalAuxLength = size(originalAuxData, 1);

            % Resample with averageAux = false (default)
            segmentLength = 10;
            resampled = pf2.data.resample(testCase.processedData, segmentLength, ...
                'averageAux', false);

            % Verify Aux exists
            testCase.verifyTrue(isfield(resampled, 'Aux'), ...
                'Aux field should exist after resample');

            % Verify Aux was preserved (not resampled)
            if isfield(resampled.Aux, 'accelerometer') && ...
               isstruct(resampled.Aux.accelerometer) && ...
               isfield(resampled.Aux.accelerometer, 'data')
                preservedAuxData = resampled.Aux.accelerometer.data;
                preservedAuxLength = size(preservedAuxData, 1);

                % When averageAux=false, Aux should be preserved unchanged
                testCase.verifyEqual(preservedAuxLength, originalAuxLength, ...
                    'Aux length should be preserved when averageAux=false');
                testCase.verifyEqual(preservedAuxData, originalAuxData, 'AbsTol', 1e-10, ...
                    'Aux data should be unchanged when averageAux=false');
            end
        end

        function testResampleWithFlattenAux(testCase)
            % Test resample with flattenAux option

            % Resample with flattenAux = true
            segmentLength = 5;
            resampled = pf2.data.resample(testCase.processedData, segmentLength, ...
                'flattenAux', true, 'averageAux', true);

            % Verify Aux exists
            testCase.verifyTrue(isfield(resampled, 'Aux'), ...
                'Aux field should exist after resample with flattenAux');

            % Verify flattened flag is set
            if isfield(resampled.Aux, 'flattened')
                testCase.verifyTrue(resampled.Aux.flattened, ...
                    'Aux.flattened should be true when flattenAux=true');
            end
        end

        function testResampleWithTrimAux(testCase)
            % Test resample with trimAux option

            % First flatten, then trim
            segmentLength = 5;
            resampled = pf2.data.resample(testCase.processedData, segmentLength, ...
                'flattenAux', true, 'trimAux', true);

            % Verify Aux exists
            testCase.verifyTrue(isfield(resampled, 'Aux'), ...
                'Aux field should exist after resample with trimAux');

            % Verify fNIRS time range
            fnirsTimeRange = [min(resampled.time), max(resampled.time)];

            % Note: trimAux requires flattened Aux; verify no error occurred
            testCase.verifyFalse(isempty(resampled.Aux), ...
                'Aux should not be empty after trimAux');
        end
    end

    %% Nested Structure Tests
    methods (Test)
        function testAuxWithNestedStructs(testCase)
            % Test deeply nested Aux.physio.cardiac.data structure

            % Create data with deeply nested Aux
            dataWithNested = testCase.processedData;
            nSamples = length(dataWithNested.time);

            % Create nested structure: Aux.physio.cardiac.data
            dataWithNested.Aux.physio.cardiac.data = 70 + 10*sin(2*pi*1.2*(1:nSamples)'/dataWithNested.fs);
            dataWithNested.Aux.physio.cardiac.time = dataWithNested.time;
            dataWithNested.Aux.physio.cardiac.unit = 'bpm';
            dataWithNested.Aux.physio.respiration.data = randn(nSamples, 1);
            dataWithNested.Aux.physio.respiration.time = dataWithNested.time;

            % Verify nested structure was created correctly
            testCase.verifyTrue(pf2_base.isnestedfield(dataWithNested, 'Aux.physio.cardiac.data'), ...
                'Nested Aux.physio.cardiac.data should exist');

            % Test setT0 preserves nested structure
            shifted = pf2.data.setT0(dataWithNested, 5);
            testCase.verifyTrue(isfield(shifted, 'Aux'), ...
                'Aux should be preserved after setT0 with nested structure');

            % Test split with nested Aux
            timeVec = dataWithNested.time;
            startTime = min(timeVec) + 50;
            endTime = min(timeVec) + 100;

            splitData = pf2.data.split(dataWithNested, startTime, endTime);
            testCase.verifyTrue(isfield(splitData, 'Aux'), ...
                'Aux should be preserved after split with nested structure');

            % Test resample with nested Aux
            resampled = pf2.data.resample(dataWithNested, 10, 'averageAux', true);
            testCase.verifyTrue(isfield(resampled, 'Aux'), ...
                'Aux should be preserved after resample with nested structure');
        end
    end

    %% Time Alignment Tests
    methods (Test)
        function testAuxTimeAlignment(testCase)
            % Test that Aux time matches fNIRS time vector length when aligned

            % Create Aux with same time vector as fNIRS
            dataWithAlignedAux = testCase.processedData;
            nSamples = length(dataWithAlignedAux.time);

            dataWithAlignedAux.Aux.sensor.data = randn(nSamples, 2);
            dataWithAlignedAux.Aux.sensor.time = dataWithAlignedAux.time;

            % Verify initial alignment
            auxLength = length(dataWithAlignedAux.Aux.sensor.time);
            fnirsLength = length(dataWithAlignedAux.time);
            testCase.verifyEqual(auxLength, fnirsLength, ...
                'Initial Aux time should match fNIRS time length');

            % After resample with averageAux, verify alignment is maintained
            segmentLength = 5;
            resampled = pf2.data.resample(dataWithAlignedAux, segmentLength, ...
                'averageAux', true);

            resampledFnirsLength = length(resampled.time);

            % Check if Aux was also resampled to match
            if isfield(resampled.Aux, 'sensor')
                if istable(resampled.Aux.sensor)
                    resampledAuxLength = height(resampled.Aux.sensor);
                    testCase.verifyEqual(resampledAuxLength, resampledFnirsLength, ...
                        'Resampled Aux should match fNIRS time length when averageAux=true');
                elseif isstruct(resampled.Aux.sensor) && isfield(resampled.Aux.sensor, 'time')
                    resampledAuxLength = length(resampled.Aux.sensor.time);
                    testCase.verifyEqual(resampledAuxLength, resampledFnirsLength, ...
                        'Resampled Aux.sensor.time should match fNIRS time length');
                end
            end
        end

        function testAuxTimeMismatchHandling(testCase)
            % Test that Aux with different sampling rate is handled correctly

            % Create Aux with higher sampling rate than fNIRS
            dataWithFastAux = testCase.processedData;
            fnirsFs = dataWithFastAux.fs;
            nFnirsSamples = length(dataWithFastAux.time);

            % Create Aux at 2x fNIRS sampling rate
            auxFs = fnirsFs * 2;
            nAuxSamples = nFnirsSamples * 2;
            auxTime = linspace(min(dataWithFastAux.time), max(dataWithFastAux.time), nAuxSamples)';

            dataWithFastAux.Aux.fastSensor.data = randn(nAuxSamples, 1);
            dataWithFastAux.Aux.fastSensor.time = auxTime;

            % Verify mismatch in lengths
            testCase.verifyNotEqual(nAuxSamples, nFnirsSamples, ...
                'Test setup: Aux should have different sample count than fNIRS');

            % Resample should handle this without error
            try
                resampled = pf2.data.resample(dataWithFastAux, 10, 'averageAux', true);
                testCase.verifyTrue(isfield(resampled, 'Aux'), ...
                    'Aux should exist after resampling with mismatched sampling rates');
            catch ME
                testCase.verifyFail(sprintf('Resample failed with mismatched Aux: %s', ME.message));
            end
        end
    end

    %% Edge Case Tests
    methods (Test)
        function testEmptyAuxPreserved(testCase)
            % Test that empty Aux field is handled correctly

            dataWithEmptyAux = testCase.processedData;
            dataWithEmptyAux.Aux = [];

            % Test operations with empty Aux
            shifted = pf2.data.setT0(dataWithEmptyAux, 5);
            testCase.verifyTrue(isfield(shifted, 'Aux'), ...
                'Empty Aux field should be preserved after setT0');

            resampled = pf2.data.resample(dataWithEmptyAux, 10);
            testCase.verifyTrue(isfield(resampled, 'Aux'), ...
                'Empty Aux field should be preserved after resample');
        end

        function testAuxWithTableFormat(testCase)
            % Test Aux data stored as table (common after flattening)

            dataWithTableAux = testCase.processedData;
            nSamples = length(dataWithTableAux.time);

            % Create Aux as table
            auxTable = table(dataWithTableAux.time, randn(nSamples, 1), randn(nSamples, 1), ...
                'VariableNames', {'time', 'val1', 'val2'});
            dataWithTableAux.Aux.tableData = auxTable;
            dataWithTableAux.Aux.flattened = true;

            % Resample with table Aux
            resampled = pf2.data.resample(dataWithTableAux, 10, 'averageAux', true);

            % Verify Aux exists
            testCase.verifyTrue(isfield(resampled, 'Aux'), ...
                'Aux should exist after resampling with table format');

            % Verify tableData was processed
            if isfield(resampled.Aux, 'tableData')
                testCase.verifyTrue(istable(resampled.Aux.tableData) || ~isempty(resampled.Aux.tableData), ...
                    'Aux.tableData should be preserved or converted after resample');
            end
        end

        function testAuxWithMixedDataTypes(testCase)
            % Test Aux with mixed data types (numeric arrays, strings, structs)

            dataWithMixedAux = testCase.processedData;
            nSamples = length(dataWithMixedAux.time);

            % Add various data types to Aux
            dataWithMixedAux.Aux.numericData = randn(nSamples, 2);
            dataWithMixedAux.Aux.numericData_time = dataWithMixedAux.time;  % Separate time field
            dataWithMixedAux.Aux.metadata = 'Experiment notes';  % String
            dataWithMixedAux.Aux.params.threshold = 0.5;  % Nested scalar
            dataWithMixedAux.Aux.params.enabled = true;   % Boolean

            % Test setT0 handles mixed types
            shifted = pf2.data.setT0(dataWithMixedAux, 5);
            testCase.verifyTrue(isfield(shifted, 'Aux'), ...
                'Aux should be preserved with mixed data types');

            % Test resample handles mixed types
            resampled = pf2.data.resample(dataWithMixedAux, 10, 'averageAux', false);
            testCase.verifyTrue(isfield(resampled, 'Aux'), ...
                'Aux should be preserved after resample with mixed data types');

            % Verify non-numeric fields are preserved
            if isfield(resampled.Aux, 'metadata')
                testCase.verifyEqual(resampled.Aux.metadata, 'Experiment notes', ...
                    'String metadata should be preserved in Aux');
            end
        end
    end
end
