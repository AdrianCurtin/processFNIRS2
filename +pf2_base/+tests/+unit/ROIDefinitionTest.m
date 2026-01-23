classdef ROIDefinitionTest < matlab.unittest.TestCase
    % ROIDEFINITIONTEST Unit tests for pf2.probe.roi.defineROI function
    %
    %   This test class verifies the ROI definition functionality including
    %   table creation, naming conventions, input format handling, and
    %   data structure preservation.
    %
    %   Tests cover:
    %     - ROI.info table creation and structure
    %     - Custom and auto-generated ROI names
    %     - Appending to existing ROIs
    %     - Cell array and matrix input formats
    %     - Single-channel ROI handling
    %     - Preservation of other fNIRS fields
    %
    %   Example:
    %       results = runtests('pf2_base.tests.unit.ROIDefinitionTest');
    %       disp(results);
    %
    %   See also: matlab.unittest.TestCase, pf2.probe.roi.defineROI,
    %             processFNIRS2, pf2.import.sampleData

    properties
        processedData  % Processed fNIRS data from sample import
    end

    methods (TestClassSetup)
        function loadSampleData(testCase)
            % Load and process sample data once for all tests
            rawData = pf2.import.sampleData.fNIR2000();
            testCase.processedData = processFNIRS2(rawData);
        end
    end

    %% ROI Creation Tests
    methods (Test)
        function testDefineROICreatesTable(testCase)
            % Verify that defineROI creates the ROI.info table field
            %
            % The function should create fNIR.ROI.info as a table when
            % defining ROIs on data that has no existing ROI definitions.

            data = testCase.processedData;

            % Remove any existing ROI field
            if isfield(data, 'ROI')
                data = rmfield(data, 'ROI');
            end

            % Define ROIs using column cell array
            optodeList = {[1,2,3]; [4,5,6]};
            result = pf2.probe.roi.defineROI(data, optodeList);

            testCase.verifyTrue(isfield(result, 'ROI'), ...
                'Result must have ROI field');
            testCase.verifyTrue(isfield(result.ROI, 'info'), ...
                'Result.ROI must have info field');
            testCase.verifyTrue(istable(result.ROI.info), ...
                'ROI.info must be a table');
        end

        function testDefineROIWithNames(testCase)
            % Verify that custom ROI names are correctly assigned
            %
            % When ROI_names parameter is provided, those names should
            % appear as row names in the ROI.info table.

            data = testCase.processedData;

            % Remove any existing ROI field
            if isfield(data, 'ROI')
                data = rmfield(data, 'ROI');
            end

            customNames = {'Left_PFC', 'Right_PFC'};
            optodeList = {[1,2,3]; [4,5,6]};
            result = pf2.probe.roi.defineROI(data, optodeList, customNames);

            rowNames = result.ROI.info.Properties.RowNames;

            testCase.verifyEqual(rowNames, customNames(:), ...
                'Row names must match provided custom names');
        end

        function testDefineROIAutoNames(testCase)
            % Verify auto-generated names when ROI_names not provided
            %
            % Without explicit names, the function should generate names
            % as 'ROI1', 'ROI2', etc.

            data = testCase.processedData;

            % Remove any existing ROI field
            if isfield(data, 'ROI')
                data = rmfield(data, 'ROI');
            end

            optodeList = {[1,2,3]; [4,5,6]; [7,8,9]};
            result = pf2.probe.roi.defineROI(data, optodeList);

            rowNames = result.ROI.info.Properties.RowNames;
            expectedNames = {'ROI1'; 'ROI2'; 'ROI3'};

            testCase.verifyEqual(rowNames, expectedNames, ...
                'Auto-generated names should be ROI1, ROI2, ROI3');
        end

        function testDefineROIAppend(testCase)
            % Verify that appending to existing ROIs works correctly
            %
            % When ROI.info already exists, new ROIs should be appended
            % without overwriting existing definitions.

            data = testCase.processedData;

            % Remove any existing ROI field
            if isfield(data, 'ROI')
                data = rmfield(data, 'ROI');
            end

            % Define initial ROIs
            data = pf2.probe.roi.defineROI(data, {[1,2,3]}, {'First_ROI'});

            % Append more ROIs
            result = pf2.probe.roi.defineROI(data, {[4,5,6]}, {'Second_ROI'});

            rowNames = result.ROI.info.Properties.RowNames;
            numROIs = height(result.ROI.info);

            testCase.verifyEqual(numROIs, 2, ...
                'Should have 2 ROIs after appending');
            testCase.verifyTrue(ismember('First_ROI', rowNames), ...
                'First_ROI should be preserved');
            testCase.verifyTrue(ismember('Second_ROI', rowNames), ...
                'Second_ROI should be added');
        end

        function testDefineROIAppendAutoNames(testCase)
            % Verify auto-generated names continue numbering when appending
            %
            % When appending ROIs without names, auto-generated names should
            % continue from the highest existing number.

            data = testCase.processedData;

            % Remove any existing ROI field
            if isfield(data, 'ROI')
                data = rmfield(data, 'ROI');
            end

            % Define initial ROIs with auto names (column cell)
            data = pf2.probe.roi.defineROI(data, {[1,2,3]; [4,5,6]});

            % Append more ROIs without names (column cell)
            result = pf2.probe.roi.defineROI(data, {[7,8,9]; [10,11,12]});

            rowNames = result.ROI.info.Properties.RowNames;

            testCase.verifyTrue(ismember('ROI1', rowNames), ...
                'ROI1 should exist');
            testCase.verifyTrue(ismember('ROI2', rowNames), ...
                'ROI2 should exist');
            testCase.verifyTrue(ismember('ROI3', rowNames), ...
                'ROI3 should be auto-generated for first appended ROI');
            testCase.verifyTrue(ismember('ROI4', rowNames), ...
                'ROI4 should be auto-generated for second appended ROI');
        end
    end

    %% Input Format Tests
    methods (Test)
        function testDefineROICellInput(testCase)
            % Verify cell array input {[1,2,3]; [4,5,6]} works correctly
            %
            % Cell array is the preferred input format for optode lists.
            % Note: Function expects column cell array.

            data = testCase.processedData;

            % Remove any existing ROI field
            if isfield(data, 'ROI')
                data = rmfield(data, 'ROI');
            end

            cellInput = {[1,2,3]; [4,5,6]};  % Column cell array
            result = pf2.probe.roi.defineROI(data, cellInput, {'CellROI1', 'CellROI2'});

            % Verify optodes are stored correctly
            optodes1 = result.ROI.info{'CellROI1', 'Optodes'};
            optodes2 = result.ROI.info{'CellROI2', 'Optodes'};

            testCase.verifyEqual(optodes1{1}, [1,2,3], ...
                'First ROI optodes should match cell input');
            testCase.verifyEqual(optodes2{1}, [4,5,6], ...
                'Second ROI optodes should match cell input');
        end

        function testDefineROIMatrixInput(testCase)
            % Verify numeric matrix input works correctly
            %
            % When a numeric matrix is provided, it should be interpreted
            % as N_roi x N_opt dimensions and converted internally.

            data = testCase.processedData;

            % Remove any existing ROI field
            if isfield(data, 'ROI')
                data = rmfield(data, 'ROI');
            end

            % Matrix input: 2 ROIs x 3 optodes each
            matrixInput = [1, 2, 3; 4, 5, 6];
            result = pf2.probe.roi.defineROI(data, matrixInput, {'MatrixROI1', 'MatrixROI2'});

            numROIs = height(result.ROI.info);
            testCase.verifyEqual(numROIs, 2, ...
                'Should create 2 ROIs from 2-row matrix');

            % Verify optodes are stored correctly
            optodes1 = result.ROI.info{'MatrixROI1', 'Optodes'};
            optodes2 = result.ROI.info{'MatrixROI2', 'Optodes'};

            testCase.verifyEqual(optodes1{1}, [1, 2, 3], ...
                'First ROI optodes should match matrix row 1');
            testCase.verifyEqual(optodes2{1}, [4, 5, 6], ...
                'Second ROI optodes should match matrix row 2');
        end

        function testDefineROISingleChannel(testCase)
            % Verify single-channel ROIs work correctly
            %
            % ROIs can contain a single channel for point-based analysis.

            data = testCase.processedData;

            % Remove any existing ROI field
            if isfield(data, 'ROI')
                data = rmfield(data, 'ROI');
            end

            result = pf2.probe.roi.defineROI(data, {[5]}, {'SingleChannel'});

            optodes = result.ROI.info{'SingleChannel', 'Optodes'};

            testCase.verifyEqual(optodes{1}, 5, ...
                'Single-channel ROI should contain channel 5');
            testCase.verifyEqual(height(result.ROI.info), 1, ...
                'Should have exactly 1 ROI');
        end

        function testDefineROIVaryingChannelCounts(testCase)
            % Verify ROIs with different numbers of channels work
            %
            % Cell array input allows ROIs with varying channel counts.

            data = testCase.processedData;

            % Remove any existing ROI field
            if isfield(data, 'ROI')
                data = rmfield(data, 'ROI');
            end

            varyingInput = {[1]; [2,3]; [4,5,6,7]};  % Column cell array
            result = pf2.probe.roi.defineROI(data, varyingInput, {'One', 'Two', 'Four'});

            optodes1 = result.ROI.info{'One', 'Optodes'};
            optodes2 = result.ROI.info{'Two', 'Optodes'};
            optodes3 = result.ROI.info{'Four', 'Optodes'};

            testCase.verifyEqual(length(optodes1{1}), 1, ...
                'First ROI should have 1 channel');
            testCase.verifyEqual(length(optodes2{1}), 2, ...
                'Second ROI should have 2 channels');
            testCase.verifyEqual(length(optodes3{1}), 4, ...
                'Third ROI should have 4 channels');
        end
    end

    %% Data Preservation Tests
    methods (Test)
        function testDefineROIPreservesOtherFields(testCase)
            % Verify that other fNIRS fields are preserved after ROI definition
            %
            % The function should only add/modify ROI.info without affecting
            % other data fields like HbO, HbR, time, etc.

            data = testCase.processedData;

            % Remove any existing ROI field
            if isfield(data, 'ROI')
                data = rmfield(data, 'ROI');
            end

            % Store original field values
            originalHbO = data.HbO;
            originalHbR = data.HbR;
            originalTime = data.time;
            originalChannels = data.channels;
            originalFs = data.fs;

            % Define ROIs
            result = pf2.probe.roi.defineROI(data, {[1,2,3]}, {'TestROI'});

            % Verify fields are unchanged
            testCase.verifyEqual(result.HbO, originalHbO, ...
                'HbO should be unchanged');
            testCase.verifyEqual(result.HbR, originalHbR, ...
                'HbR should be unchanged');
            testCase.verifyEqual(result.time, originalTime, ...
                'Time vector should be unchanged');
            testCase.verifyEqual(result.channels, originalChannels, ...
                'Channels should be unchanged');
            testCase.verifyEqual(result.fs, originalFs, ...
                'Sampling rate should be unchanged');
        end

        function testDefineROIPreservesMarkers(testCase)
            % Verify that markers field is preserved
            %
            % Marker information is critical and must not be modified.

            data = testCase.processedData;

            % Remove any existing ROI field
            if isfield(data, 'ROI')
                data = rmfield(data, 'ROI');
            end

            originalMarkers = data.markers;

            result = pf2.probe.roi.defineROI(data, {[1,2,3]}, {'TestROI'});

            testCase.verifyEqual(result.markers, originalMarkers, ...
                'Markers should be unchanged');
        end

        function testDefineROIPreservesInfo(testCase)
            % Verify that info struct is preserved
            %
            % Metadata in info struct should remain intact.

            data = testCase.processedData;

            % Remove any existing ROI field
            if isfield(data, 'ROI')
                data = rmfield(data, 'ROI');
            end

            originalInfo = data.info;

            result = pf2.probe.roi.defineROI(data, {[1,2,3]}, {'TestROI'});

            testCase.verifyEqual(result.info, originalInfo, ...
                'Info struct should be unchanged');
        end
    end

    %% Table Structure Tests
    methods (Test)
        function testDefineROITableStructure(testCase)
            % Verify ROI.info table has correct columns
            %
            % The table must have 'Optodes' column at minimum.

            data = testCase.processedData;

            % Remove any existing ROI field
            if isfield(data, 'ROI')
                data = rmfield(data, 'ROI');
            end

            optodeList = {[1,2,3]; [4,5,6]};  % Column cell array
            result = pf2.probe.roi.defineROI(data, optodeList, {'ROI_A', 'ROI_B'});

            varNames = result.ROI.info.Properties.VariableNames;

            testCase.verifyTrue(ismember('Optodes', varNames), ...
                'Table must have Optodes column');
        end

        function testDefineROITableRowCount(testCase)
            % Verify table row count matches number of ROIs defined
            %
            % Each ROI should correspond to exactly one table row.

            data = testCase.processedData;

            % Remove any existing ROI field
            if isfield(data, 'ROI')
                data = rmfield(data, 'ROI');
            end

            numROIs = 5;
            optodeList = cell(numROIs, 1);  % Column cell array
            for i = 1:numROIs
                optodeList{i} = i;  % Single channel per ROI
            end

            result = pf2.probe.roi.defineROI(data, optodeList);

            testCase.verifyEqual(height(result.ROI.info), numROIs, ...
                sprintf('Table should have %d rows for %d ROIs', numROIs, numROIs));
        end

        function testDefineROIOptodesCellArray(testCase)
            % Verify Optodes column contains cell arrays
            %
            % Each entry in Optodes should be a cell containing a numeric array.

            data = testCase.processedData;

            % Remove any existing ROI field
            if isfield(data, 'ROI')
                data = rmfield(data, 'ROI');
            end

            result = pf2.probe.roi.defineROI(data, {[1,2,3]}, {'TestROI'});

            optodes = result.ROI.info.Optodes;

            testCase.verifyTrue(iscell(optodes), ...
                'Optodes column should be a cell array');
            testCase.verifyTrue(isnumeric(optodes{1}), ...
                'Each Optodes entry should contain numeric data');
        end
    end

    %% Edge Case Tests
    methods (Test)
        function testDefineROIOverwriteExisting(testCase)
            % Verify that redefining an ROI with same name overwrites it
            %
            % If an ROI name already exists, the new definition should
            % replace the old one.

            data = testCase.processedData;

            % Remove any existing ROI field
            if isfield(data, 'ROI')
                data = rmfield(data, 'ROI');
            end

            % Define initial ROI
            data = pf2.probe.roi.defineROI(data, {[1,2,3]}, {'TestROI'});

            % Redefine same ROI with different channels (should warn)
            result = pf2.probe.roi.defineROI(data, {[7,8,9]}, {'TestROI'});

            % Should still have only 1 ROI
            testCase.verifyEqual(height(result.ROI.info), 1, ...
                'Should have 1 ROI after overwrite');

            % Verify channels were updated
            optodes = result.ROI.info{'TestROI', 'Optodes'};
            testCase.verifyEqual(optodes{1}, [7,8,9], ...
                'Optodes should be updated to new values');
        end

        function testDefineROIStringArrayNames(testCase)
            % Verify string array names are handled correctly
            %
            % ROI_names can be provided as string array (converted to cellstr).

            data = testCase.processedData;

            % Remove any existing ROI field
            if isfield(data, 'ROI')
                data = rmfield(data, 'ROI');
            end

            stringNames = ["StringROI1", "StringROI2"];
            optodeList = {[1,2]; [3,4]};  % Column cell array
            result = pf2.probe.roi.defineROI(data, optodeList, stringNames);

            rowNames = result.ROI.info.Properties.RowNames;

            testCase.verifyTrue(ismember('StringROI1', rowNames), ...
                'StringROI1 should be in row names');
            testCase.verifyTrue(ismember('StringROI2', rowNames), ...
                'StringROI2 should be in row names');
        end

        function testDefineROIEmptyExistingROIInfo(testCase)
            % Verify handling when ROI.info exists but is empty
            %
            % Should create new table as if ROI.info did not exist.

            data = testCase.processedData;

            % Create empty ROI.info
            data.ROI.info = [];

            result = pf2.probe.roi.defineROI(data, {[1,2,3]}, {'NewROI'});

            testCase.verifyEqual(height(result.ROI.info), 1, ...
                'Should have 1 ROI when starting from empty ROI.info');
            testCase.verifyTrue(ismember('NewROI', result.ROI.info.Properties.RowNames), ...
                'NewROI should be in row names');
        end
    end
end
