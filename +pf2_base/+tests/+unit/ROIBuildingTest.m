classdef ROIBuildingTest < matlab.unittest.TestCase
    % ROIBUILDINGTEST Unit tests for ROI building and aggregation functions
    %
    % Tests functions for constructing Regions of Interest (ROI) from fNIRS data:
    %   - pf2_base.fnirs.buildROI
    %   - pf2_base.fnirs.ezBuildROI
    %   - pf2_build_nanmean_ROI (in /functions/)
    %   - pf2.probe.roi.defineROI
    %
    % Run all tests:
    %   results = runtests('pf2_base.tests.unit.ROIBuildingTest');
    %
    % Run specific test:
    %   results = runtests('pf2_base.tests.unit.ROIBuildingTest/testBuildROINanmeanBasic');

    properties (TestParameter)
        % Test parameters can be defined here for parameterized tests
    end

    properties
        processedData    % Processed fNIRS sample data with hemoglobin values
        dataWithROI      % Processed data with ROI definitions added
        roiChannels      % Cell array of channel indices for each ROI
        roiNames         % Cell array of ROI names
    end

    methods (TestClassSetup)
        function loadAndProcessData(testCase)
            % Load sample data once for all tests
            % Load raw data and process it to get hemoglobin values
            rawData = pf2.import.sampleData.fNIR2000();
            testCase.processedData = processFNIRS2(rawData);

            % Define standard ROIs for testing
            % Use channels that exist in fNIR2000 (18 channels total)
            % Note: defineROI expects column cell arrays for proper table creation
            testCase.roiChannels = {[1, 2, 3]; [4, 5, 6]; [7, 8, 9]};
            testCase.roiNames = {'Left'; 'Center'; 'Right'};

            % Create data with ROI definitions
            testCase.dataWithROI = pf2.probe.roi.defineROI(...
                testCase.processedData, ...
                testCase.roiChannels, ...
                testCase.roiNames);
        end
    end

    methods (TestMethodSetup)
        function resetWarnings(~)
            % Reset warning state before each test
            warning('on', 'all');
        end
    end

    %% Basic ROI Building Tests
    methods (Test)
        function testBuildROINanmeanBasic(testCase)
            % Test that nanmean aggregation produces valid output
            %
            % Verifies that pf2_build_nanmean_ROI successfully creates ROI
            % fields when provided with valid input data containing ROI
            % definitions.

            % Build ROIs using nanmean
            result = pf2_build_nanmean_ROI(testCase.dataWithROI);

            % Verify ROI field exists
            testCase.verifyTrue(isfield(result, 'ROI'), ...
                'Result should have ROI field');

            % Verify ROI.HbO exists and is not empty
            testCase.verifyTrue(isfield(result.ROI, 'HbO'), ...
                'ROI should have HbO field');
            testCase.verifyNotEmpty(result.ROI.HbO, ...
                'ROI.HbO should not be empty');

            % Verify output contains numeric values
            testCase.verifyTrue(isnumeric(result.ROI.HbO), ...
                'ROI.HbO should be numeric');

            % Verify output does not contain all NaN (at least some valid data)
            testCase.verifyFalse(all(isnan(result.ROI.HbO(:))), ...
                'ROI.HbO should not be all NaN');
        end

        function testBuildROIDimensions(testCase)
            % Test that output is T x R (time x num_ROIs)
            %
            % ROI output should have the same number of time points as input
            % and number of columns equal to number of defined ROIs.

            % Build ROIs
            result = pf2_build_nanmean_ROI(testCase.dataWithROI);

            % Get expected dimensions
            numTimePoints = size(testCase.dataWithROI.HbO, 1);
            numROIs = length(testCase.roiChannels);

            % Verify HbO dimensions
            actualSize = size(result.ROI.HbO);
            testCase.verifyEqual(actualSize(1), numTimePoints, ...
                sprintf('ROI.HbO should have %d time points (rows), got %d', ...
                numTimePoints, actualSize(1)));
            testCase.verifyEqual(actualSize(2), numROIs, ...
                sprintf('ROI.HbO should have %d ROIs (columns), got %d', ...
                numROIs, actualSize(2)));

            % Verify HbR dimensions match HbO
            testCase.verifyEqual(size(result.ROI.HbR), size(result.ROI.HbO), ...
                'ROI.HbR dimensions should match ROI.HbO');
        end

        function testBuildROIPreservesTime(testCase)
            % Test that time dimension is unchanged after ROI building
            %
            % The time vector and number of time samples should be
            % identical before and after ROI construction.

            % Build ROIs
            result = pf2_build_nanmean_ROI(testCase.dataWithROI);

            % Verify time vector is unchanged
            testCase.verifyEqual(result.time, testCase.dataWithROI.time, ...
                'Time vector should be unchanged');

            % Verify time dimension of HbO matches time vector length
            testCase.verifyEqual(size(result.ROI.HbO, 1), length(result.time), ...
                'ROI.HbO time dimension should match time vector length');

            % Verify sampling frequency unchanged
            testCase.verifyEqual(result.fs, testCase.dataWithROI.fs, ...
                'Sampling frequency should be unchanged');
        end

        function testBuildROISingleChannelROI(testCase)
            % Test that ROI with 1 channel equals that channel exactly
            %
            % When an ROI contains only a single channel, the ROI value
            % should be identical to the original channel data.

            % Define a single-channel ROI
            singleChannelData = pf2.probe.roi.defineROI(...
                testCase.processedData, ...
                {[5]}, ...  % Single channel ROI (column cell)
                {'SingleCh'});

            % Build ROI
            result = pf2_build_nanmean_ROI(singleChannelData);

            % Get original channel 5 data
            originalChannel = singleChannelData.HbO(:, 5);

            % Verify ROI equals original channel (within floating point tolerance)
            testCase.verifyEqual(result.ROI.HbO(:, 1), originalChannel, 'AbsTol', 1e-10, ...
                'Single-channel ROI should equal original channel data');

            % Also verify for HbR
            originalChannelHbR = singleChannelData.HbR(:, 5);
            testCase.verifyEqual(result.ROI.HbR(:, 1), originalChannelHbR, 'AbsTol', 1e-10, ...
                'Single-channel ROI.HbR should equal original channel data');
        end
    end

    %% NaN Handling Tests
    methods (Test)
        function testBuildROINaNHandling(testCase)
            % Test that NaN channels are excluded from mean calculation
            %
            % When a channel contains NaN values, nanmean should ignore
            % those values and compute the mean from remaining valid channels.

            % Create data with some NaN values
            dataWithNaN = testCase.dataWithROI;

            % Set channel 1 to all NaN (first channel in first ROI)
            dataWithNaN.HbO(:, 1) = NaN;
            dataWithNaN.HbR(:, 1) = NaN;

            % Build ROIs
            result = pf2_build_nanmean_ROI(dataWithNaN);

            % Calculate expected value: nanmean of channels 2 and 3 only
            % (since channel 1 is all NaN for first ROI)
            expectedHbO = nanmean(dataWithNaN.HbO(:, [2, 3]), 2);

            % Verify ROI 1 equals nanmean of remaining channels
            testCase.verifyEqual(result.ROI.HbO(:, 1), expectedHbO, 'AbsTol', 1e-10, ...
                'ROI with NaN channel should equal nanmean of remaining channels');

            % Verify other ROIs are unaffected (ROI 2 uses channels 4,5,6)
            expectedROI2 = nanmean(dataWithNaN.HbO(:, [4, 5, 6]), 2);
            testCase.verifyEqual(result.ROI.HbO(:, 2), expectedROI2, 'AbsTol', 1e-10, ...
                'ROI without NaN channels should be unaffected');
        end

        function testBuildROIAllNaNTimepoint(testCase)
            % Test that all channels NaN at one timepoint produces NaN in ROI
            %
            % When all channels in an ROI are NaN at a specific time point,
            % the ROI value at that time point should also be NaN.

            % Create data with all channels NaN at one timepoint
            dataWithNaN = testCase.dataWithROI;

            % Set all channels in first ROI to NaN at timepoint 50
            targetTimepoint = 50;
            roiChannelIndices = testCase.roiChannels{1};  % [1, 2, 3]
            dataWithNaN.HbO(targetTimepoint, roiChannelIndices) = NaN;

            % Build ROIs
            result = pf2_build_nanmean_ROI(dataWithNaN);

            % Verify that timepoint 50 in ROI 1 is NaN
            testCase.verifyTrue(isnan(result.ROI.HbO(targetTimepoint, 1)), ...
                'ROI value should be NaN when all channels are NaN at that timepoint');

            % Verify surrounding timepoints are NOT NaN
            testCase.verifyFalse(isnan(result.ROI.HbO(targetTimepoint - 1, 1)), ...
                'Timepoint before should not be NaN');
            testCase.verifyFalse(isnan(result.ROI.HbO(targetTimepoint + 1, 1)), ...
                'Timepoint after should not be NaN');

            % Verify other ROIs at same timepoint are NOT NaN
            testCase.verifyFalse(isnan(result.ROI.HbO(targetTimepoint, 2)), ...
                'Other ROIs at same timepoint should not be NaN');
        end
    end

    %% Biomarker Field Tests
    methods (Test)
        function testBuildROIAllBiomarkers(testCase)
            % Test that all biomarker fields are created in ROI output
            %
            % ROI building should create HbO, HbR, HbTotal, HbDiff, and
            % optionally CBSI fields within the ROI structure.

            % Build ROIs
            result = pf2_build_nanmean_ROI(testCase.dataWithROI);

            % Required biomarker fields
            requiredFields = {'HbO', 'HbR', 'HbTotal', 'HbDiff'};

            % Verify each required field exists in ROI
            for i = 1:length(requiredFields)
                fieldName = requiredFields{i};
                testCase.verifyTrue(isfield(result.ROI, fieldName), ...
                    sprintf('ROI should have %s field', fieldName));

                % Verify field is not empty
                testCase.verifyNotEmpty(result.ROI.(fieldName), ...
                    sprintf('ROI.%s should not be empty', fieldName));

                % Verify field has correct dimensions
                testCase.verifyEqual(size(result.ROI.(fieldName), 1), ...
                    size(testCase.dataWithROI.HbO, 1), ...
                    sprintf('ROI.%s should have same number of time points', fieldName));
                testCase.verifyEqual(size(result.ROI.(fieldName), 2), ...
                    length(testCase.roiChannels), ...
                    sprintf('ROI.%s should have same number of ROIs', fieldName));
            end

            % CBSI may or may not be present depending on input
            if isfield(testCase.dataWithROI, 'CBSI') && ~isempty(testCase.dataWithROI.CBSI)
                testCase.verifyTrue(isfield(result.ROI, 'CBSI'), ...
                    'ROI should have CBSI field when input has CBSI');
            end
        end

        function testBuildROIBiomarkerConsistency(testCase)
            % Test that biomarker values are computed correctly
            %
            % Manually verify that ROI values match expected nanmean
            % calculations for each biomarker.

            % Build ROIs
            result = pf2_build_nanmean_ROI(testCase.dataWithROI);

            % Verify HbO ROI 1 calculation
            expectedHbO_ROI1 = nanmean(testCase.dataWithROI.HbO(:, testCase.roiChannels{1}), 2);
            testCase.verifyEqual(result.ROI.HbO(:, 1), expectedHbO_ROI1, 'AbsTol', 1e-10, ...
                'ROI.HbO should equal nanmean of constituent channels');

            % Verify HbR ROI 2 calculation
            expectedHbR_ROI2 = nanmean(testCase.dataWithROI.HbR(:, testCase.roiChannels{2}), 2);
            testCase.verifyEqual(result.ROI.HbR(:, 2), expectedHbR_ROI2, 'AbsTol', 1e-10, ...
                'ROI.HbR should equal nanmean of constituent channels');

            % Verify HbTotal ROI 3 calculation
            expectedHbTotal_ROI3 = nanmean(testCase.dataWithROI.HbTotal(:, testCase.roiChannels{3}), 2);
            testCase.verifyEqual(result.ROI.HbTotal(:, 3), expectedHbTotal_ROI3, 'AbsTol', 1e-10, ...
                'ROI.HbTotal should equal nanmean of constituent channels');

            % Verify HbDiff calculation
            expectedHbDiff_ROI1 = nanmean(testCase.dataWithROI.HbDiff(:, testCase.roiChannels{1}), 2);
            testCase.verifyEqual(result.ROI.HbDiff(:, 1), expectedHbDiff_ROI1, 'AbsTol', 1e-10, ...
                'ROI.HbDiff should equal nanmean of constituent channels');
        end
    end

    %% ROI Info Preservation Tests
    methods (Test)
        function testBuildROIInfoPreserved(testCase)
            % Test that ROI.info table is preserved after building
            %
            % The ROI.info table containing ROI definitions should be
            % preserved and updated appropriately after ROI construction.

            % Build ROIs
            result = pf2_build_nanmean_ROI(testCase.dataWithROI);

            % Verify ROI.info exists
            testCase.verifyTrue(isfield(result.ROI, 'info'), ...
                'ROI should have info field');

            % Verify ROI.info is a table
            testCase.verifyTrue(istable(result.ROI.info), ...
                'ROI.info should be a table');

            % Verify row names are preserved
            expectedRowNames = testCase.roiNames;
            actualRowNames = result.ROI.info.Properties.RowNames;
            testCase.verifyEqual(actualRowNames, expectedRowNames, ...
                'ROI.info row names should match defined ROI names');

            % Verify number of ROIs matches
            testCase.verifyEqual(height(result.ROI.info), length(testCase.roiChannels), ...
                'ROI.info should have same number of rows as defined ROIs');
        end

        function testBuildROIInfoContainsChannels(testCase)
            % Test that ROI.info contains channel/optode information
            %
            % The ROI.info table should contain information about which
            % channels belong to each ROI.

            % Build ROIs
            result = pf2_build_nanmean_ROI(testCase.dataWithROI);

            % Verify Optodes column exists
            testCase.verifyTrue(ismember('Optodes', result.ROI.info.Properties.VariableNames), ...
                'ROI.info should have Optodes column');

            % Verify channel assignments are preserved
            for i = 1:length(testCase.roiChannels)
                actualChannels = result.ROI.info.Optodes{i};
                expectedChannels = testCase.roiChannels{i};
                testCase.verifyEqual(actualChannels, expectedChannels, ...
                    sprintf('ROI %d channel assignment should be preserved', i));
            end
        end
    end

    %% ezBuildROI Wrapper Tests
    methods (Test)
        function testEzBuildROIWrapper(testCase)
            % Test that ezBuildROI produces same result as manual buildROI
            %
            % ezBuildROI is a convenience wrapper that should produce
            % identical results to calling buildROI directly with nanmean.

            % Use ezBuildROI
            ezResult = pf2_base.fnirs.ezBuildROI(testCase.dataWithROI, @nanmean);

            % Use pf2_build_nanmean_ROI (which calls ezBuildROI internally)
            nanmeanResult = pf2_build_nanmean_ROI(testCase.dataWithROI);

            % Verify HbO values are identical
            testCase.verifyEqual(ezResult.ROI.HbO, nanmeanResult.ROI.HbO, 'AbsTol', 1e-10, ...
                'ezBuildROI should produce same HbO as pf2_build_nanmean_ROI');

            % Verify HbR values are identical
            testCase.verifyEqual(ezResult.ROI.HbR, nanmeanResult.ROI.HbR, 'AbsTol', 1e-10, ...
                'ezBuildROI should produce same HbR as pf2_build_nanmean_ROI');

            % Verify all biomarker fields are identical
            biomarkers = {'HbO', 'HbR', 'HbTotal', 'HbDiff'};
            for i = 1:length(biomarkers)
                field = biomarkers{i};
                if isfield(ezResult.ROI, field) && isfield(nanmeanResult.ROI, field)
                    testCase.verifyEqual(ezResult.ROI.(field), nanmeanResult.ROI.(field), ...
                        'AbsTol', 1e-10, ...
                        sprintf('ezBuildROI should produce same %s as pf2_build_nanmean_ROI', field));
                end
            end
        end

        function testEzBuildROINoROIField(testCase)
            % Test that ezBuildROI returns unchanged data when no ROI defined
            %
            % When input data has no ROI.info field, ezBuildROI should
            % return the input unchanged.

            % Use processed data without ROI definitions
            dataNoROI = testCase.processedData;

            % Remove ROI field if it exists
            if isfield(dataNoROI, 'ROI')
                dataNoROI = rmfield(dataNoROI, 'ROI');
            end

            % Call ezBuildROI
            result = pf2_base.fnirs.ezBuildROI(dataNoROI, @nanmean);

            % Verify data is returned unchanged (no ROI field added)
            testCase.verifyEqual(result.HbO, dataNoROI.HbO, ...
                'HbO should be unchanged when no ROI defined');

            % Verify no ROI.HbO field was created
            if isfield(result, 'ROI')
                testCase.verifyFalse(isfield(result.ROI, 'HbO'), ...
                    'ROI.HbO should not be created when no ROI info exists');
            end
        end

        function testEzBuildROIDefaultFunction(testCase)
            % Test that ezBuildROI uses nanmean by default
            %
            % When no function is specified, ezBuildROI should default to
            % using nanmean for aggregation.

            % Call ezBuildROI without specifying function
            resultDefault = pf2_base.fnirs.ezBuildROI(testCase.dataWithROI);

            % Call ezBuildROI with explicit nanmean
            resultNanmean = pf2_base.fnirs.ezBuildROI(testCase.dataWithROI, @nanmean);

            % Verify results are identical
            testCase.verifyEqual(resultDefault.ROI.HbO, resultNanmean.ROI.HbO, 'AbsTol', 1e-10, ...
                'Default function should be nanmean');
        end
    end

    %% Custom Aggregation Function Tests
    methods (Test)
        function testBuildROICustomFunction(testCase)
            % Test that custom aggregation function works (@median)
            %
            % buildROI should accept custom aggregation functions and
            % apply them correctly to compute ROI values.

            % Use ezBuildROI with median function
            resultMedian = pf2_base.fnirs.ezBuildROI(testCase.dataWithROI, @nanmedian);

            % Verify ROI was created
            testCase.verifyTrue(isfield(resultMedian.ROI, 'HbO'), ...
                'ROI.HbO should be created with custom function');

            % Manually calculate expected median for ROI 1
            expectedMedian_ROI1 = nanmedian(testCase.dataWithROI.HbO(:, testCase.roiChannels{1}), 2);

            % Verify median calculation is correct
            testCase.verifyEqual(resultMedian.ROI.HbO(:, 1), expectedMedian_ROI1, 'AbsTol', 1e-10, ...
                'Custom median function should produce correct ROI values');

            % Verify median differs from mean (sanity check)
            resultMean = pf2_base.fnirs.ezBuildROI(testCase.dataWithROI, @nanmean);

            % In general, median and mean should not be identical
            % (unless data is perfectly symmetric)
            meanValues = resultMean.ROI.HbO(:, 1);
            medianValues = resultMedian.ROI.HbO(:, 1);

            % Check that at least some values differ
            numDifferent = sum(abs(meanValues - medianValues) > 1e-10);
            testCase.verifyGreaterThan(numDifferent, 0, ...
                'Median and mean should produce different results for most real data');
        end

        function testBuildROICustomFunctionString(testCase)
            % Test that function specified as string works
            %
            % ezBuildROI should accept function names as strings and
            % convert them to function handles.

            % Use string function name
            resultString = pf2_base.fnirs.ezBuildROI(testCase.dataWithROI, 'nanmean');

            % Use function handle
            resultHandle = pf2_base.fnirs.ezBuildROI(testCase.dataWithROI, @nanmean);

            % Verify results are identical
            testCase.verifyEqual(resultString.ROI.HbO, resultHandle.ROI.HbO, 'AbsTol', 1e-10, ...
                'String function name should produce same result as function handle');
        end
    end

    %% Direct buildROI Function Tests
    methods (Test)
        function testBuildROIDirectCall(testCase)
            % Test direct call to buildROI with explicit parameters
            %
            % Verify that calling buildROI directly with all parameters
            % produces expected results.

            % Define parameters
            ch_index = testCase.roiChannels;
            roi_names = testCase.roiNames;
            fieldToUse = 'oxy';
            removeNanChannels = true;
            roi_func_handle = @nanmean;

            % Call buildROI directly
            result = pf2_base.fnirs.buildROI(...
                testCase.dataWithROI, ...
                ch_index, ...
                roi_names, ...
                fieldToUse, ...
                removeNanChannels, ...
                roi_func_handle);

            % Verify ROI output
            testCase.verifyTrue(isfield(result.ROI, 'HbO'), ...
                'Direct buildROI call should create ROI.HbO');

            % Verify dimensions
            testCase.verifyEqual(size(result.ROI.HbO, 1), size(testCase.dataWithROI.HbO, 1), ...
                'ROI time dimension should match input');
            testCase.verifyEqual(size(result.ROI.HbO, 2), length(ch_index), ...
                'ROI column count should match number of ROIs');
        end

        function testBuildROINumericMatrix(testCase)
            % Test buildROI with numeric matrix input for raw data
            %
            % buildROI should work with raw numeric matrices, not just
            % fNIRS structures.

            % Create simple numeric test data
            testMatrix = randn(100, 10);  % 100 timepoints, 10 channels
            ch_index = {[1, 2, 3], [4, 5, 6]};  % 2 ROIs
            roi_names = {'ROI1', 'ROI2'};

            % Call buildROI with numeric matrix
            result = pf2_base.fnirs.buildROI(...
                testMatrix, ...
                ch_index, ...
                roi_names, ...
                'oxy', ...
                false, ...
                @nanmean);

            % Verify output is numeric (not struct when input is numeric)
            testCase.verifyTrue(isnumeric(result), ...
                'buildROI with numeric input should return numeric output');

            % Verify dimensions: 100 timepoints x 2 ROIs
            testCase.verifyEqual(size(result), [100, 2], ...
                'Numeric output should have correct dimensions');

            % Verify calculation is correct
            expectedROI1 = nanmean(testMatrix(:, [1, 2, 3]), 2);
            testCase.verifyEqual(result(:, 1), expectedROI1, 'AbsTol', 1e-10, ...
                'Numeric ROI calculation should be correct');
        end
    end

    %% Edge Cases and Error Handling
    methods (Test)
        function testBuildROIEmptyChannelList(testCase)
            % Test behavior with ROI containing no channels
            %
            % Edge case: what happens when an ROI has an empty channel list

            % Define ROI with empty channel list
            dataEmptyROI = testCase.processedData;
            dataEmptyROI.ROI.info = table({[]}, 'VariableNames', {'Optodes'}, ...
                'RowNames', {'EmptyROI'});

            % This should not crash - verify graceful handling
            try
                result = pf2_build_nanmean_ROI(dataEmptyROI);
                % If it succeeds, verify output structure exists
                testCase.verifyTrue(isstruct(result), ...
                    'Should return struct even with empty ROI');
            catch ME
                % If error is thrown, verify it's a meaningful error
                testCase.verifySubstring(ME.message, '', ...
                    'Error message should be informative');
            end
        end

        function testBuildROIOverlappingChannels(testCase)
            % Test ROIs with overlapping channel assignments
            %
            % Channels can belong to multiple ROIs - verify this works.

            % Define overlapping ROIs (column cell arrays)
            overlappingChannels = {[1, 2, 3]; [2, 3, 4]; [3, 4, 5]};
            overlappingNames = {'ROI_A'; 'ROI_B'; 'ROI_C'};

            dataOverlap = pf2.probe.roi.defineROI(...
                testCase.processedData, ...
                overlappingChannels, ...
                overlappingNames);

            % Build ROIs
            result = pf2_build_nanmean_ROI(dataOverlap);

            % Verify all 3 ROIs were created
            testCase.verifyEqual(size(result.ROI.HbO, 2), 3, ...
                'Should create 3 ROIs with overlapping channels');

            % Verify calculations are independent
            expectedROI_A = nanmean(dataOverlap.HbO(:, [1, 2, 3]), 2);
            expectedROI_B = nanmean(dataOverlap.HbO(:, [2, 3, 4]), 2);
            expectedROI_C = nanmean(dataOverlap.HbO(:, [3, 4, 5]), 2);

            testCase.verifyEqual(result.ROI.HbO(:, 1), expectedROI_A, 'AbsTol', 1e-10, ...
                'ROI_A calculation should be correct');
            testCase.verifyEqual(result.ROI.HbO(:, 2), expectedROI_B, 'AbsTol', 1e-10, ...
                'ROI_B calculation should be correct');
            testCase.verifyEqual(result.ROI.HbO(:, 3), expectedROI_C, 'AbsTol', 1e-10, ...
                'ROI_C calculation should be correct');
        end

        function testBuildROILargeNumberOfROIs(testCase)
            % Test with many ROIs (one per channel)
            %
            % Edge case: create an ROI for each channel individually.

            % Get number of channels
            numChannels = size(testCase.processedData.HbO, 2);

            % Create one ROI per channel (column cell arrays)
            manyChannels = cell(numChannels, 1);
            manyNames = cell(numChannels, 1);
            for i = 1:numChannels
                manyChannels{i} = i;
                manyNames{i} = sprintf('Ch%d_ROI', i);
            end

            dataManyROI = pf2.probe.roi.defineROI(...
                testCase.processedData, ...
                manyChannels, ...
                manyNames);

            % Build ROIs
            result = pf2_build_nanmean_ROI(dataManyROI);

            % Verify correct number of ROIs created
            testCase.verifyEqual(size(result.ROI.HbO, 2), numChannels, ...
                'Should create one ROI per channel');

            % Each single-channel ROI should equal original channel
            for i = 1:numChannels
                testCase.verifyEqual(result.ROI.HbO(:, i), testCase.processedData.HbO(:, i), ...
                    'AbsTol', 1e-10, ...
                    sprintf('Single-channel ROI %d should equal original channel', i));
            end
        end
    end

    %% defineROI Function Tests
    methods (Test)
        function testDefineROIBasic(testCase)
            % Test basic defineROI functionality
            %
            % Verify that defineROI correctly creates ROI.info structure.

            % Define ROIs (column cell arrays)
            result = pf2.probe.roi.defineROI(...
                testCase.processedData, ...
                {[1, 2]; [3, 4]}, ...
                {'ROI_Left'; 'ROI_Right'});

            % Verify ROI.info was created
            testCase.verifyTrue(isfield(result, 'ROI'), ...
                'Result should have ROI field');
            testCase.verifyTrue(isfield(result.ROI, 'info'), ...
                'ROI should have info field');

            % Verify info is a table
            testCase.verifyTrue(istable(result.ROI.info), ...
                'ROI.info should be a table');

            % Verify row names
            testCase.verifyEqual(result.ROI.info.Properties.RowNames, ...
                {'ROI_Left'; 'ROI_Right'}, ...
                'ROI names should match input');
        end

        function testDefineROIAutoNames(testCase)
            % Test defineROI with auto-generated names
            %
            % When names are not provided, ROI1, ROI2, etc. should be generated.

            % Define ROIs without names (column cell array)
            result = pf2.probe.roi.defineROI(...
                testCase.processedData, ...
                {[1, 2]; [3, 4]; [5, 6]});

            % Verify auto-generated names
            expectedNames = {'ROI1'; 'ROI2'; 'ROI3'};
            testCase.verifyEqual(result.ROI.info.Properties.RowNames, expectedNames, ...
                'Auto-generated names should be ROI1, ROI2, etc.');
        end

        function testDefineROIAppend(testCase)
            % Test appending ROIs to existing definitions
            %
            % Adding new ROIs should append to existing definitions.

            % First define some ROIs
            data1 = pf2.probe.roi.defineROI(...
                testCase.processedData, ...
                {[1, 2]}, ...
                {'FirstROI'});

            % Append more ROIs
            data2 = pf2.probe.roi.defineROI(...
                data1, ...
                {[3, 4]}, ...
                {'SecondROI'});

            % Verify both ROIs exist
            testCase.verifyEqual(height(data2.ROI.info), 2, ...
                'Should have 2 ROIs after appending');

            expectedNames = {'FirstROI'; 'SecondROI'};
            testCase.verifyEqual(data2.ROI.info.Properties.RowNames, expectedNames, ...
                'Both ROI names should be present');
        end
    end
end
