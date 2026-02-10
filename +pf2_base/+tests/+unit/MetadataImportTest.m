classdef MetadataImportTest < matlab.unittest.TestCase
    % METADATAIMPORTTEST Unit tests for pf2.data.importInfo and pf2.data.importBlockInfo
    %
    % Tests subject-level metadata import (CSV/Excel -> .info) and block-level
    % metadata import with positional and key-based matching modes.
    %
    % Run all tests:
    %   results = runtests('pf2_base.tests.unit.MetadataImportTest');
    %
    % See also: pf2.data.importInfo, pf2.data.importBlockInfo

    properties
        tempDir  % Temporary directory for CSV files
    end

    methods (TestMethodSetup)
        function createTempDir(testCase)
            testCase.tempDir = tempname;
            mkdir(testCase.tempDir);
        end
    end

    methods (TestMethodTeardown)
        function removeTempDir(testCase)
            if isfolder(testCase.tempDir)
                rmdir(testCase.tempDir, 's');
            end
        end
    end

    methods (Access = private)
        function fp = writeCSV(testCase, tbl, filename)
            % Helper: write table to CSV in temp directory
            fp = fullfile(testCase.tempDir, filename);
            writetable(tbl, fp);
        end
    end

    %% ===== importInfo Tests =====

    methods (Test)
        function testSingleKeyMatch(testCase)
            % Single key column matches struct to CSV row
            d1.info.SubjectID = 'S01';
            d1.time = (0:9)';
            d2.info.SubjectID = 'S02';
            d2.time = (0:9)';

            tbl = table({'S01'; 'S02'}, [25; 30], {'M'; 'F'}, ...
                'VariableNames', {'SubjectID', 'Age', 'Sex'});
            fp = testCase.writeCSV(tbl, 'demo.csv');

            result = pf2.data.importInfo({d1, d2}, fp, 'SubjectID');

            testCase.verifyEqual(result{1}.info.Age, 25);
            testCase.verifyEqual(result{1}.info.Sex, 'M');
            testCase.verifyEqual(result{2}.info.Age, 30);
            testCase.verifyEqual(result{2}.info.Sex, 'F');
        end

        function testMultiKeyMatch(testCase)
            % Multi-key matching (SubjectID + Session)
            d1.info.SubjectID = 'S01';
            d1.info.Session = 1;
            d2.info.SubjectID = 'S01';
            d2.info.Session = 2;

            tbl = table({'S01'; 'S01'}, [1; 2], [85; 92], ...
                'VariableNames', {'SubjectID', 'Session', 'Score'});
            fp = testCase.writeCSV(tbl, 'multi.csv');

            result = pf2.data.importInfo({d1, d2}, fp, 'Keys', {'SubjectID', 'Session'});

            testCase.verifyEqual(result{1}.info.Score, 85);
            testCase.verifyEqual(result{2}.info.Score, 92);
        end

        function testSingleStructInput(testCase)
            % Single struct (not cell array) input and output
            d.info.SubjectID = 'S01';
            d.time = (0:9)';

            tbl = table({'S01'}, [25], 'VariableNames', {'SubjectID', 'Age'});
            fp = testCase.writeCSV(tbl, 'single.csv');

            result = pf2.data.importInfo(d, fp, 'SubjectID');

            testCase.verifyTrue(isstruct(result), 'Should return struct, not cell');
            testCase.verifyEqual(result.info.Age, 25);
        end

        function testKeyNotInFileError(testCase)
            % Error when key column missing from CSV
            d.info.SubjectID = 'S01';

            tbl = table([25], {'M'}, 'VariableNames', {'Age', 'Sex'});
            fp = testCase.writeCSV(tbl, 'nokey.csv');

            testCase.verifyError(...
                @() pf2.data.importInfo(d, fp, 'SubjectID'), ...
                'pf2:data:importInfo:keyNotInFile');
        end

        function testKeyNotInInfoError(testCase)
            % Error when key field missing from struct .info
            d.info.Name = 'Test';

            tbl = table({'S01'}, [25], 'VariableNames', {'SubjectID', 'Age'});
            fp = testCase.writeCSV(tbl, 'noinfo.csv');

            testCase.verifyError(...
                @() pf2.data.importInfo(d, fp, 'SubjectID'), ...
                'pf2:data:importInfo:keyNotInInfo');
        end

        function testNoMatchError(testCase)
            % Error when no CSV row matches struct key
            d.info.SubjectID = 'S99';

            tbl = table({'S01'; 'S02'}, [25; 30], ...
                'VariableNames', {'SubjectID', 'Age'});
            fp = testCase.writeCSV(tbl, 'nomatch.csv');

            testCase.verifyError(...
                @() pf2.data.importInfo(d, fp, 'SubjectID'), ...
                'pf2:data:importInfo:noMatch');
        end

        function testAmbiguousMatchError(testCase)
            % Error when multiple CSV rows match same key
            d.info.SubjectID = 'S01';

            tbl = table({'S01'; 'S01'}, [25; 26], ...
                'VariableNames', {'SubjectID', 'Age'});
            fp = testCase.writeCSV(tbl, 'ambig.csv');

            testCase.verifyError(...
                @() pf2.data.importInfo(d, fp, 'SubjectID'), ...
                'pf2:data:importInfo:ambiguousMatch');
        end

        function testUnusedRowsWarning(testCase)
            % Warning when CSV rows not matched to any struct
            d.info.SubjectID = 'S01';

            tbl = table({'S01'; 'S02'; 'S03'}, [25; 30; 35], ...
                'VariableNames', {'SubjectID', 'Age'});
            fp = testCase.writeCSV(tbl, 'extra.csv');

            testCase.verifyWarning(...
                @() pf2.data.importInfo(d, fp, 'SubjectID'), ...
                'pf2:data:importInfo:unusedRows');
        end

        function testOverwriteFalse(testCase)
            % Overwrite=false preserves existing .info fields
            d.info.SubjectID = 'S01';
            d.info.Age = 99;  % existing value

            tbl = table({'S01'}, [25], {'GroupA'}, ...
                'VariableNames', {'SubjectID', 'Age', 'Group'});
            fp = testCase.writeCSV(tbl, 'overwrite.csv');

            result = pf2.data.importInfo(d, fp, 'SubjectID', 'Overwrite', false);

            testCase.verifyEqual(result.info.Age, 99, ...
                'Existing Age should be preserved');
            testCase.verifyEqual(result.info.Group, 'GroupA', ...
                'New field should be added');
        end

        function testNumericKeyMatch(testCase)
            % Numeric key matching works correctly
            d1.info.SessionID = 101;
            d2.info.SessionID = 102;

            tbl = table([101; 102], [85; 92], ...
                'VariableNames', {'SessionID', 'Score'});
            fp = testCase.writeCSV(tbl, 'numeric.csv');

            result = pf2.data.importInfo({d1, d2}, fp, 'SessionID');

            testCase.verifyEqual(result{1}.info.Score, 85);
            testCase.verifyEqual(result{2}.info.Score, 92);
        end

        function testFileNotFoundError(testCase)
            % Error when file does not exist
            d.info.SubjectID = 'S01';

            testCase.verifyError(...
                @() pf2.data.importInfo(d, '/nonexistent/file.csv', 'SubjectID'), ...
                'pf2:data:importInfo:fileNotFound');
        end
    end

    %% ===== importBlockInfo Tests =====

    methods (Test)
        function testPositionalNoFilter(testCase)
            % Positional matching: row k -> block k
            blocks = makeTestBlocks();

            tbl = table([85; 90; 78], {'Easy'; 'Hard'; 'Easy'}, ...
                'VariableNames', {'Score', 'Difficulty'});
            fp = testCase.writeCSV(tbl, 'trial.csv');

            result = pf2.data.importBlockInfo(blocks, fp);

            testCase.verifyEqual(result(1).info.Score, 85);
            testCase.verifyEqual(result(2).info.Difficulty, 'Hard');
            testCase.verifyEqual(result(3).info.Score, 78);
        end

        function testPositionalMarkerCodeFilter(testCase)
            % Positional with MarkerCode filter: only marker 49 blocks get data
            blocks = makeMixedBlocks();  % 49, 50, 49, 50, 49

            tbl = table([85; 90; 78], {'Easy'; 'Hard'; 'Easy'}, ...
                'VariableNames', {'Score', 'Difficulty'});
            fp = testCase.writeCSV(tbl, 'filtered.csv');

            result = pf2.data.importBlockInfo(blocks, fp, 'MarkerCode', 49);

            % Blocks 1, 3, 5 have marker 49
            testCase.verifyEqual(result(1).info.Score, 85);
            testCase.verifyEqual(result(3).info.Score, 90);
            testCase.verifyEqual(result(5).info.Score, 78);

            % Blocks 2, 4 (marker 50) unchanged
            testCase.verifyFalse(isfield(result(2).info, 'Score'), ...
                'Marker 50 block should not have Score');
        end

        function testPositionalConditionFilter(testCase)
            % Positional with Condition filter
            blocks = makeConditionBlocks();  % Task, Rest, Task, Rest

            tbl = table([85; 90], 'VariableNames', {'Score'});
            fp = testCase.writeCSV(tbl, 'cond.csv');

            result = pf2.data.importBlockInfo(blocks, fp, 'Condition', 'Task');

            testCase.verifyEqual(result(1).info.Score, 85);
            testCase.verifyEqual(result(3).info.Score, 90);
            testCase.verifyFalse(isfield(result(2).info, 'Score'));
        end

        function testRowCountMismatchError(testCase)
            % Error when CSV rows don't match filtered block count
            blocks = makeTestBlocks();  % 3 blocks

            tbl = table([85; 90], 'VariableNames', {'Score'});  % 2 rows
            fp = testCase.writeCSV(tbl, 'mismatch.csv');

            testCase.verifyError(...
                @() pf2.data.importBlockInfo(blocks, fp), ...
                'pf2:data:importBlockInfo:rowCountMismatch');
        end

        function testKeyBasedMatch(testCase)
            % Key-based matching by BlockNumber
            blocks = makeTestBlocks();

            % CSV in non-sequential order
            tbl = table([3; 1; 2], [78; 85; 90], ...
                'VariableNames', {'BlockNumber', 'Score'});
            fp = testCase.writeCSV(tbl, 'keyed.csv');

            result = pf2.data.importBlockInfo(blocks, fp, 'Keys', 'BlockNumber');

            testCase.verifyEqual(result(1).info.Score, 85);
            testCase.verifyEqual(result(2).info.Score, 90);
            testCase.verifyEqual(result(3).info.Score, 78);
        end

        function testNonMatchingBlocksUnchanged(testCase)
            % Blocks not matching filter pass through unchanged
            blocks = makeMixedBlocks();
            origInfo2 = blocks(2).info;

            tbl = table([85; 90; 78], 'VariableNames', {'Score'});
            fp = testCase.writeCSV(tbl, 'partial.csv');

            result = pf2.data.importBlockInfo(blocks, fp, 'MarkerCode', 49);

            testCase.verifyEqual(result(2).info, origInfo2, ...
                'Non-matching block info should be unchanged');
        end

        function testIntegrationWithDefineBlocks(testCase)
            % Pipeline: defineBlocks -> importBlockInfo -> verify
            data = pf2_base.tests.unit.BlockDefinitionTest.makeSyntheticData();
            blocks = pf2.data.defineBlocks(data, 49, 20, ...
                'ConditionMap', {49, 'Task'});

            tbl = table([85; 92; 78], {'Easy'; 'Hard'; 'Easy'}, ...
                'VariableNames', {'Score', 'Difficulty'});
            fp = testCase.writeCSV(tbl, 'integration.csv');

            result = pf2.data.importBlockInfo(blocks, fp);

            testCase.verifyEqual(result(1).info.Score, 85);
            testCase.verifyEqual(result(2).info.Difficulty, 'Hard');
            % Original fields preserved
            testCase.verifyEqual(result(1).info.Condition, 'Task');
            testCase.verifyEqual(result(1).info.BlockNumber, 1);
        end

        function testBlockInfoFileNotFound(testCase)
            % Error when file does not exist
            blocks = makeTestBlocks();

            testCase.verifyError(...
                @() pf2.data.importBlockInfo(blocks, '/nonexistent/file.csv'), ...
                'pf2:data:importBlockInfo:fileNotFound');
        end

        function testBlockOverwriteFalse(testCase)
            % Overwrite=false preserves existing block .info fields
            blocks = makeTestBlocks();
            blocks(1).info.Score = 99;  % pre-existing

            tbl = table([85; 90; 78], {'Easy'; 'Hard'; 'Easy'}, ...
                'VariableNames', {'Score', 'Difficulty'});
            fp = testCase.writeCSV(tbl, 'nooverwrite.csv');

            result = pf2.data.importBlockInfo(blocks, fp, 'Overwrite', false);

            testCase.verifyEqual(result(1).info.Score, 99, ...
                'Existing Score should be preserved');
            testCase.verifyEqual(result(1).info.Difficulty, 'Easy', ...
                'New field should be added');
        end
    end
end

%%_Helper_Functions_________________________________________________________

function blocks = makeTestBlocks()
% MAKETESTBLOCKS Create 3 simple blocks with marker code 49
for k = 3:-1:1
    blocks(k).startTime = k * 30;
    blocks(k).endTime = k * 30 + 20;
    blocks(k).duration = 20;
    blocks(k).markerCode = 49;
    blocks(k).markerIndex = k;
    blocks(k).amplitude = 1;
    blocks(k).info = struct('BlockNumber', k);
end
end

function blocks = makeMixedBlocks()
% MAKEMIXEDBLOCKS Create 5 blocks alternating marker codes 49 and 50
codes = [49, 50, 49, 50, 49];
for k = 5:-1:1
    blocks(k).startTime = k * 30;
    blocks(k).endTime = k * 30 + 20;
    blocks(k).duration = 20;
    blocks(k).markerCode = codes(k);
    blocks(k).markerIndex = k;
    blocks(k).amplitude = 1;
    blocks(k).info = struct('BlockNumber', k);
end
end

function blocks = makeConditionBlocks()
% MAKECONDITIONBLOCKS Create 4 blocks with Task/Rest conditions
conds = {'Task', 'Rest', 'Task', 'Rest'};
for k = 4:-1:1
    blocks(k).startTime = k * 30;
    blocks(k).endTime = k * 30 + 20;
    blocks(k).duration = 20;
    blocks(k).markerCode = 49;
    blocks(k).markerIndex = k;
    blocks(k).amplitude = 1;
    blocks(k).info = struct('BlockNumber', k, 'Condition', conds{k});
end
end
