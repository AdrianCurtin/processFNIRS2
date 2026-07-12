classdef InfoTableTest < matlab.unittest.TestCase
    % INFOTABLETEST Unit tests for pf2.data.infoToTable and pf2.data.infoFromTable
    %
    % Tests round-trip conversion, mixed types, field filtering, overwrite
    % and clear modes, single struct handling, error conditions, and
    % non-scalar field skipping.
    %
    % Run all tests:
    %   results = runtests('pf2_base.tests.unit.InfoTableTest');
    %
    % See also: pf2.data.infoToTable, pf2.data.infoFromTable

    methods (Static)
        function allData = makeTestData()
            % Create a 3-element cell array with varied .info fields
            d1 = struct();
            d1.time = (0:99)' / 10;
            d1.HbO = randn(100, 4);
            d1.info.SubjectID = 'S001';
            d1.info.Age = 25;
            d1.info.Group = 'Control';
            d1.info.Score = 85.5;

            d2 = struct();
            d2.time = (0:99)' / 10;
            d2.HbO = randn(100, 4);
            d2.info.SubjectID = 'S002';
            d2.info.Age = 30;
            d2.info.Group = 'Treatment';

            d3 = struct();
            d3.time = (0:99)' / 10;
            d3.HbO = randn(100, 4);
            d3.info.SubjectID = 'S003';
            d3.info.Group = 'Control';
            d3.info.Score = 92.0;
            d3.info.Notes = "extra notes";

            allData = {d1, d2, d3};
        end
    end

    % =====================================================================
    % infoToTable tests
    % =====================================================================

    methods (Test)
        function testBasicExtraction(testCase)
            allData = pf2_base.tests.unit.InfoTableTest.makeTestData();
            T = pf2.data.infoToTable(allData);

            testCase.verifyEqual(height(T), 3);
            testCase.verifyTrue(ismember('SubjectID', T.Properties.VariableNames));
            testCase.verifyTrue(ismember('Age', T.Properties.VariableNames));
            testCase.verifyTrue(ismember('Group', T.Properties.VariableNames));
        end

        function testValuesCorrect(testCase)
            allData = pf2_base.tests.unit.InfoTableTest.makeTestData();
            T = pf2.data.infoToTable(allData);

            testCase.verifyEqual(T.SubjectID(1), "S001");
            testCase.verifyEqual(T.SubjectID(2), "S002");
            testCase.verifyEqual(T.Age(1), 25);
            testCase.verifyEqual(T.Age(2), 30);
        end

        function testMissingFieldsFilled(testCase)
            % d2 has no Score, d3 has no Age
            allData = pf2_base.tests.unit.InfoTableTest.makeTestData();
            T = pf2.data.infoToTable(allData);

            % Score missing for d2 -> NaN
            testCase.verifyTrue(isnan(T.Score(2)));
            % Age missing for d3 -> NaN
            testCase.verifyTrue(isnan(T.Age(3)));
        end

        function testFieldsFilter(testCase)
            allData = pf2_base.tests.unit.InfoTableTest.makeTestData();
            T = pf2.data.infoToTable(allData, 'Fields', {'SubjectID', 'Group'});

            testCase.verifyEqual(width(T), 2);
            testCase.verifyEqual(T.Properties.VariableNames, {'SubjectID', 'Group'});
        end

        function testFieldsFilterMissingField(testCase)
            % Request a field that exists in no struct -> column of ""
            allData = pf2_base.tests.unit.InfoTableTest.makeTestData();
            T = pf2.data.infoToTable(allData, 'Fields', {'SubjectID', 'Nonexistent'});

            testCase.verifyEqual(width(T), 2);
            testCase.verifyEqual(T.Nonexistent(1), "");
        end

        function testSingleStructInput(testCase)
            allData = pf2_base.tests.unit.InfoTableTest.makeTestData();
            T = pf2.data.infoToTable(allData{1});

            testCase.verifyEqual(height(T), 1);
            testCase.verifyEqual(T.SubjectID(1), "S001");
            testCase.verifyEqual(T.Age(1), 25);
        end

        function testSkipsNonScalarFields(testCase)
            d = struct();
            d.info.Name = 'Test';
            d.info.Matrix = [1 2 3; 4 5 6];
            d.info.Nested = struct('a', 1);
            d.info.CellField = {1, 2, 3};

            T = pf2.data.infoToTable(d);

            testCase.verifyTrue(ismember('Name', T.Properties.VariableNames));
            testCase.verifyFalse(ismember('Matrix', T.Properties.VariableNames));
            testCase.verifyFalse(ismember('Nested', T.Properties.VariableNames));
            testCase.verifyFalse(ismember('CellField', T.Properties.VariableNames));
        end

        function testEmptyInput(testCase)
            T = pf2.data.infoToTable({});
            testCase.verifyEqual(height(T), 0);
        end

        function testStringAndCharMixed(testCase)
            d1 = struct('info', struct('Name', 'Alice'));
            d2 = struct('info', struct('Name', "Bob"));
            T = pf2.data.infoToTable({d1, d2});

            testCase.verifyEqual(T.Name(1), "Alice");
            testCase.verifyEqual(T.Name(2), "Bob");
        end

        function testLogicalValues(testCase)
            d1 = struct('info', struct('Active', true, 'ID', 1));
            d2 = struct('info', struct('Active', false, 'ID', 2));
            T = pf2.data.infoToTable({d1, d2});

            % Logicals stored as double to allow NaN missing
            testCase.verifyEqual(T.Active(1), 1);
            testCase.verifyEqual(T.Active(2), 0);
        end

        function testDatetimeValues(testCase)
            dt = datetime(2025, 6, 15);
            d1 = struct('info', struct('Date', dt, 'ID', 1));
            d2 = struct('info', struct('ID', 2));
            T = pf2.data.infoToTable({d1, d2});

            testCase.verifyEqual(T.Date(1), dt);
            testCase.verifyTrue(isnat(T.Date(2)));
        end

        function testNoInfoField(testCase)
            d1 = struct('info', struct('Name', 'A'));
            d2 = struct('time', 1); % no .info
            T = pf2.data.infoToTable({d1, d2});

            testCase.verifyEqual(height(T), 2);
            testCase.verifyEqual(T.Name(1), "A");
            testCase.verifyEqual(T.Name(2), "");
        end
    end

    % =====================================================================
    % infoFromTable tests
    % =====================================================================

    methods (Test)
        function testBasicWrite(testCase)
            allData = pf2_base.tests.unit.InfoTableTest.makeTestData();
            T = table(["A";"B";"C"], 'VariableNames', {'Condition'});

            allData = pf2.data.infoFromTable(allData, T);

            testCase.verifyEqual(allData{1}.info.Condition, 'A');
            testCase.verifyEqual(allData{2}.info.Condition, 'B');
            testCase.verifyEqual(allData{3}.info.Condition, 'C');
        end

        function testMergePreservesExisting(testCase)
            allData = pf2_base.tests.unit.InfoTableTest.makeTestData();
            T = table(["X";"Y";"Z"], 'VariableNames', {'NewField'});

            allData = pf2.data.infoFromTable(allData, T);

            % New field added
            testCase.verifyEqual(allData{1}.info.NewField, 'X');
            % Existing fields preserved
            testCase.verifyEqual(allData{1}.info.SubjectID, 'S001');
            testCase.verifyEqual(allData{1}.info.Age, 25);
        end

        function testOverwriteTrue(testCase)
            allData = pf2_base.tests.unit.InfoTableTest.makeTestData();
            T = table(["New1";"New2";"New3"], 'VariableNames', {'SubjectID'});

            allData = pf2.data.infoFromTable(allData, T, 'Overwrite', true);

            testCase.verifyEqual(allData{1}.info.SubjectID, 'New1');
        end

        function testOverwriteFalse(testCase)
            allData = pf2_base.tests.unit.InfoTableTest.makeTestData();
            T = table(["New1";"New2";"New3"], [99;99;99], ...
                'VariableNames', {'SubjectID', 'NewField'});

            allData = pf2.data.infoFromTable(allData, T, 'Overwrite', false);

            % Existing SubjectID preserved
            testCase.verifyEqual(allData{1}.info.SubjectID, 'S001');
            % New field still added
            testCase.verifyEqual(allData{1}.info.NewField, 99);
        end

        function testClearMode(testCase)
            allData = pf2_base.tests.unit.InfoTableTest.makeTestData();
            T = table(["A";"B";"C"], 'VariableNames', {'OnlyField'});

            allData = pf2.data.infoFromTable(allData, T, 'Clear', true);

            % Only OnlyField should exist
            testCase.verifyEqual(allData{1}.info.OnlyField, 'A');
            testCase.verifyFalse(isfield(allData{1}.info, 'SubjectID'));
            testCase.verifyFalse(isfield(allData{1}.info, 'Age'));
        end

        function testSkipsMissingValues(testCase)
            allData = pf2_base.tests.unit.InfoTableTest.makeTestData();
            T = table([100; NaN; 200], 'VariableNames', {'Age'});

            allData = pf2.data.infoFromTable(allData, T);

            testCase.verifyEqual(allData{1}.info.Age, 100);
            % NaN skipped -> original Age preserved for d2
            testCase.verifyEqual(allData{2}.info.Age, 30);
            testCase.verifyEqual(allData{3}.info.Age, 200);
        end

        function testSkipsEmptyStrings(testCase)
            allData = pf2_base.tests.unit.InfoTableTest.makeTestData();
            T = table(["NewGroup"; ""; "Other"], 'VariableNames', {'Group'});

            allData = pf2.data.infoFromTable(allData, T);

            testCase.verifyEqual(allData{1}.info.Group, 'NewGroup');
            % "" skipped -> original preserved
            testCase.verifyEqual(allData{2}.info.Group, 'Treatment');
            testCase.verifyEqual(allData{3}.info.Group, 'Other');
        end

        function testSingleStructRoundTrip(testCase)
            d = struct();
            d.info.Name = 'Test';
            d.info.Value = 42;

            T = pf2.data.infoToTable(d);
            result = pf2.data.infoFromTable(d, T);

            % Returns struct, not cell
            testCase.verifyTrue(isstruct(result));
            testCase.verifyEqual(result.info.Name, 'Test');
            testCase.verifyEqual(result.info.Value, 42);
        end

        function testRowCountMismatchErrors(testCase)
            allData = pf2_base.tests.unit.InfoTableTest.makeTestData();
            T = table(["A";"B"], 'VariableNames', {'X'});

            testCase.verifyError(@() pf2.data.infoFromTable(allData, T), ...
                'pf2:data:infoFromTable:sizeMismatch');
        end
    end

    % =====================================================================
    % Round-trip tests
    % =====================================================================

    methods (Test)
        function testRoundTripPreservesInfo(testCase)
            allData = pf2_base.tests.unit.InfoTableTest.makeTestData();
            T = pf2.data.infoToTable(allData);
            result = pf2.data.infoFromTable(allData, T);

            % All original fields preserved
            testCase.verifyEqual(result{1}.info.SubjectID, 'S001');
            testCase.verifyEqual(result{1}.info.Age, 25);
            testCase.verifyEqual(result{1}.info.Group, 'Control');
            testCase.verifyEqual(result{1}.info.Score, 85.5);
        end

        function testRoundTripWithModification(testCase)
            allData = pf2_base.tests.unit.InfoTableTest.makeTestData();
            T = pf2.data.infoToTable(allData);

            % Modify a column
            T.Group = ["A"; "B"; "A"];

            result = pf2.data.infoFromTable(allData, T);

            testCase.verifyEqual(result{1}.info.Group, 'A');
            testCase.verifyEqual(result{2}.info.Group, 'B');
            testCase.verifyEqual(result{3}.info.Group, 'A');
            % Other fields unchanged
            testCase.verifyEqual(result{1}.info.SubjectID, 'S001');
        end

        function testRoundTripAddColumn(testCase)
            allData = pf2_base.tests.unit.InfoTableTest.makeTestData();
            T = pf2.data.infoToTable(allData);

            % Add a new column
            T.Condition = ["Task"; "Rest"; "Task"];

            result = pf2.data.infoFromTable(allData, T);

            testCase.verifyEqual(result{1}.info.Condition, 'Task');
            testCase.verifyEqual(result{2}.info.Condition, 'Rest');
        end

        function testRoundTripWithFieldFilter(testCase)
            allData = pf2_base.tests.unit.InfoTableTest.makeTestData();
            T = pf2.data.infoToTable(allData, 'Fields', {'SubjectID', 'Group'});

            testCase.verifyEqual(width(T), 2);

            % Write back — should only affect those two fields
            T.Group = ["X"; "Y"; "Z"];
            result = pf2.data.infoFromTable(allData, T);

            testCase.verifyEqual(result{1}.info.Group, 'X');
            % Age still there (not in table, so not touched)
            testCase.verifyEqual(result{1}.info.Age, 25);
        end
    end

    % =====================================================================
    % Single-field shorthand tests
    % =====================================================================

    methods (Test)
        function testInfoToTableSingleFieldString(testCase)
            allData = pf2_base.tests.unit.InfoTableTest.makeTestData();
            groups = pf2.data.infoToTable(allData, 'Group');

            testCase.verifyTrue(isstring(groups));
            testCase.verifyEqual(numel(groups), 3);
            testCase.verifyEqual(groups(1), "Control");
            testCase.verifyEqual(groups(2), "Treatment");
            testCase.verifyEqual(groups(3), "Control");
        end

        function testInfoToTableSingleFieldNumeric(testCase)
            allData = pf2_base.tests.unit.InfoTableTest.makeTestData();
            ages = pf2.data.infoToTable(allData, 'Age');

            testCase.verifyTrue(isnumeric(ages));
            testCase.verifyEqual(ages(1), 25);
            testCase.verifyEqual(ages(2), 30);
            testCase.verifyTrue(isnan(ages(3))); % d3 has no Age
        end

        function testInfoToTableSingleFieldMissing(testCase)
            allData = pf2_base.tests.unit.InfoTableTest.makeTestData();
            vals = pf2.data.infoToTable(allData, 'Nonexistent');

            testCase.verifyEqual(numel(vals), 3);
            % All should be "" since field doesn't exist anywhere
            testCase.verifyEqual(vals(1), "");
        end

        function testInfoFromTableScalarBroadcast(testCase)
            allData = pf2_base.tests.unit.InfoTableTest.makeTestData();
            allData = pf2.data.infoFromTable(allData, 'Condition', 'Task');

            testCase.verifyEqual(allData{1}.info.Condition, 'Task');
            testCase.verifyEqual(allData{2}.info.Condition, 'Task');
            testCase.verifyEqual(allData{3}.info.Condition, 'Task');
            % Existing fields preserved
            testCase.verifyEqual(allData{1}.info.SubjectID, 'S001');
        end

        function testInfoFromTableScalarBroadcastNumeric(testCase)
            allData = pf2_base.tests.unit.InfoTableTest.makeTestData();
            allData = pf2.data.infoFromTable(allData, 'Session', 1);

            testCase.verifyEqual(allData{1}.info.Session, 1);
            testCase.verifyEqual(allData{2}.info.Session, 1);
            testCase.verifyEqual(allData{3}.info.Session, 1);
        end

        function testInfoFromTableVectorAssignment(testCase)
            allData = pf2_base.tests.unit.InfoTableTest.makeTestData();
            allData = pf2.data.infoFromTable(allData, 'Group', ["A"; "B"; "C"]);

            testCase.verifyEqual(allData{1}.info.Group, 'A');
            testCase.verifyEqual(allData{2}.info.Group, 'B');
            testCase.verifyEqual(allData{3}.info.Group, 'C');
        end

        function testInfoFromTableVectorNumeric(testCase)
            allData = pf2_base.tests.unit.InfoTableTest.makeTestData();
            allData = pf2.data.infoFromTable(allData, 'Score', [10; 20; 30]);

            testCase.verifyEqual(allData{1}.info.Score, 10);
            testCase.verifyEqual(allData{2}.info.Score, 20);
            testCase.verifyEqual(allData{3}.info.Score, 30);
        end

        function testInfoFromTableVectorSizeMismatch(testCase)
            allData = pf2_base.tests.unit.InfoTableTest.makeTestData();
            testCase.verifyError( ...
                @() pf2.data.infoFromTable(allData, 'X', ["A"; "B"]), ...
                'pf2:data:infoFromTable:sizeMismatch');
        end

        function testInfoFromTableSingleStruct(testCase)
            d = struct('info', struct('Name', 'Test'));
            d = pf2.data.infoFromTable(d, 'Tag', 'hello');

            testCase.verifyTrue(isstruct(d));
            testCase.verifyEqual(d.info.Tag, 'hello');
            testCase.verifyEqual(d.info.Name, 'Test');
        end

        function testInfoFromTableStringBroadcast(testCase)
            allData = pf2_base.tests.unit.InfoTableTest.makeTestData();
            allData = pf2.data.infoFromTable(allData, 'Study', "MyStudy");

            testCase.verifyEqual(allData{1}.info.Study, 'MyStudy');
            testCase.verifyEqual(allData{2}.info.Study, 'MyStudy');
        end

        function testInfoToTableSavePath(testCase)
            allData = pf2_base.tests.unit.InfoTableTest.makeTestData();
            outFile = fullfile(tempdir, 'test_info_export.xlsx');
            if isfile(outFile), delete(outFile); end

            T = pf2.data.infoToTable(allData, 'SavePath', outFile);

            testCase.verifyTrue(isfile(outFile));
            T2 = readtable(outFile);
            testCase.verifyEqual(height(T2), 3);
            testCase.verifyTrue(ismember('SubjectID', T2.Properties.VariableNames));

            delete(outFile);
        end

        function testInfoToTableSavePathWithFields(testCase)
            allData = pf2_base.tests.unit.InfoTableTest.makeTestData();
            outFile = fullfile(tempdir, 'test_info_fields_export.xlsx');
            if isfile(outFile), delete(outFile); end

            T = pf2.data.infoToTable(allData, 'Fields', {'SubjectID', 'Group'}, ...
                'SavePath', outFile);

            testCase.verifyTrue(isfile(outFile));
            T2 = readtable(outFile);
            testCase.verifyEqual(width(T2), 2);

            delete(outFile);
        end
    end
end
