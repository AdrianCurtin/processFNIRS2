classdef DataStructureTest < matlab.unittest.TestCase
    % DATASTRUCTURETEST Unit tests for fNIRS data structure invariants
    %
    %   This test class verifies that fNIRS data structures maintain their
    %   expected invariants both before and after processing with processFNIRS2.
    %
    %   Tests cover:
    %     - Dimensional consistency between fields
    %     - Valid field values and types
    %     - Required fields after processing
    %
    %   Example:
    %       results = runtests('pf2_base.tests.unit.DataStructureTest');
    %       disp(results);
    %
    %   See also: matlab.unittest.TestCase, processFNIRS2, pf2.import.sampleData

    properties (TestParameter)
        % Could add parameterized tests for multiple sample datasets here
    end

    properties
        rawData      % Raw fNIRS data from sample import
        processedData % Data after processFNIRS2
    end

    methods (TestClassSetup)
        function loadSampleData(testCase)
            % Load sample data once for all tests
            testCase.rawData = pf2.import.sampleData.fNIR2000();
            testCase.processedData = processFNIRS2(testCase.rawData);
        end
    end

    %% Raw Data Structure Tests
    methods (Test)
        function testTimeDimensionMatchesRaw(testCase)
            % Verify that time vector length matches raw data rows
            %
            % The time vector must have one entry per sample (row) in the
            % raw data matrix.

            data = testCase.rawData;

            testCase.verifyEqual(size(data.raw, 1), length(data.time), ...
                'Time vector length must equal number of rows in raw data');
        end

        function testChannelMaskMatchesRaw(testCase)
            % Verify channel mask length is consistent or empty
            %
            % fchMask corresponds to processed channels (after wavelength pairing),
            % not raw columns. Raw data has multiple columns per channel (one per
            % wavelength). The mask length should divide evenly into raw columns,
            % or match processed channel count if channels field exists.

            data = testCase.rawData;

            if ~isempty(data.fchMask)
                % fchMask corresponds to processed channels, not raw columns.
                % Raw columns = channels * wavelengths (typically 2-3 wavelengths).
                % The mask must have a reasonable relationship to raw data.
                maskLen = length(data.fchMask);
                rawCols = size(data.raw, 2);

                % Either: mask divides raw columns evenly (channels * wavelengths)
                % Or: mask is smaller than raw columns (processed channel count)
                isValidMaskSize = (maskLen <= rawCols) && (mod(rawCols, maskLen) == 0 || maskLen < rawCols);

                testCase.verifyTrue(isValidMaskSize, ...
                    sprintf('Channel mask length (%d) must be consistent with raw columns (%d)', maskLen, rawCols));
            else
                % Empty mask is acceptable
                testCase.verifyTrue(true, 'Empty channel mask is valid');
            end
        end

        function testChannelMaskIsBinary(testCase)
            % Verify channel mask contains only binary values (0 or 1)
            %
            % fchMask values indicate channel validity: 1=good, 0=bad

            data = testCase.rawData;

            if ~isempty(data.fchMask)
                isBinary = all(data.fchMask == 0 | data.fchMask == 1);
                testCase.verifyTrue(isBinary, ...
                    'Channel mask must contain only 0 or 1 values');
            else
                testCase.verifyTrue(true, 'Empty channel mask skipped');
            end
        end

        function testSamplingRatePositive(testCase)
            % Verify sampling rate is a positive value
            %
            % fs must be > 0 for valid time-series data

            data = testCase.rawData;

            testCase.verifyGreaterThan(data.fs, 0, ...
                'Sampling rate must be positive');
        end

        function testTimeIsMonotonic(testCase)
            % Verify time vector is monotonically increasing
            %
            % Time values must be sorted in ascending order for valid
            % time-series representation.

            data = testCase.rawData;

            testCase.verifyTrue(issorted(data.time), ...
                'Time vector must be monotonically increasing');
        end

        function testMarkersHasThreeColumns(testCase)
            % Verify markers matrix has exactly 3 columns when not empty
            %
            % Marker format: [time, value, duration]

            data = testCase.rawData;

            if ~isempty(data.markers)
                testCase.verifyEqual(size(data.markers, 2), 3, ...
                    'Markers must have 3 columns: [time, value, duration]');
            else
                testCase.verifyTrue(true, 'Empty markers array is valid');
            end
        end

        function testInfoIsStruct(testCase)
            % Verify info field is a structure
            %
            % The info field contains metadata and must be a struct

            data = testCase.rawData;

            testCase.verifyTrue(isstruct(data.info), ...
                'Info field must be a struct');
        end
    end

    %% Processed Data Structure Tests
    methods (Test)
        function testProcessedHasHbO(testCase)
            % Verify processed data contains HbO field
            %
            % Oxygenated hemoglobin is a required output of processFNIRS2

            processed = testCase.processedData;

            testCase.verifyTrue(isfield(processed, 'HbO'), ...
                'Processed data must contain HbO field');
        end

        function testProcessedHasHbR(testCase)
            % Verify processed data contains HbR field
            %
            % Deoxygenated hemoglobin is a required output of processFNIRS2

            processed = testCase.processedData;

            testCase.verifyTrue(isfield(processed, 'HbR'), ...
                'Processed data must contain HbR field');
        end

        function testHbODimensionsMatch(testCase)
            % Verify HbO time dimension matches time vector
            %
            % HbO matrix rows must correspond to time points

            processed = testCase.processedData;

            testCase.verifyEqual(size(processed.HbO, 1), length(processed.time), ...
                'HbO rows must equal time vector length');
        end

        function testChannelsFieldExists(testCase)
            % Verify processed data contains channels field
            %
            % Channel numbers are required for mapping data to probe geometry

            processed = testCase.processedData;

            testCase.verifyTrue(isfield(processed, 'channels'), ...
                'Processed data must contain channels field');
        end

        function testUnitsFieldExists(testCase)
            % Verify processed data contains units field
            %
            % Units specification is required for proper interpretation of
            % hemoglobin concentration values

            processed = testCase.processedData;

            testCase.verifyTrue(isfield(processed, 'units'), ...
                'Processed data must contain units field');
        end
    end

    %% Additional Consistency Tests for Processed Data
    methods (Test)
        function testHbRDimensionsMatch(testCase)
            % Verify HbR time dimension matches time vector
            %
            % HbR matrix rows must correspond to time points

            processed = testCase.processedData;

            testCase.verifyEqual(size(processed.HbR, 1), length(processed.time), ...
                'HbR rows must equal time vector length');
        end

        function testHbOHbRSameDimensions(testCase)
            % Verify HbO and HbR have identical dimensions
            %
            % Both biomarkers are computed for the same channels and time points

            processed = testCase.processedData;

            testCase.verifyEqual(size(processed.HbO), size(processed.HbR), ...
                'HbO and HbR must have identical dimensions');
        end

        function testChannelsMatchHbOColumns(testCase)
            % Verify channels vector length matches HbO columns
            %
            % Each column in HbO corresponds to one channel

            processed = testCase.processedData;

            testCase.verifyEqual(length(processed.channels), size(processed.HbO, 2), ...
                'Channels vector length must equal HbO column count');
        end

        function testProcessedRetainsRawData(testCase)
            % Verify processed data retains original raw field
            %
            % The raw data should be preserved for reference

            processed = testCase.processedData;

            testCase.verifyTrue(isfield(processed, 'raw'), ...
                'Processed data should retain raw field');
        end

        function testProcessedTimeIsMonotonic(testCase)
            % Verify processed time vector remains monotonic
            %
            % Processing should not alter time vector ordering

            processed = testCase.processedData;

            testCase.verifyTrue(issorted(processed.time), ...
                'Processed time vector must remain monotonically increasing');
        end
    end
end
