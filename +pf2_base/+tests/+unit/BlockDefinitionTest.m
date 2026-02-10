classdef BlockDefinitionTest < matlab.unittest.TestCase
    % BLOCKDEFINITIONTEST Unit tests for pf2.data.defineBlocks and pf2.data.extractBlocks
    %
    % Tests block definition from markers (three modes) and block extraction
    % to cell arrays. Covers ConditionMap, InfoTable, InfoFields, duration
    % filtering, baseline subtraction, time shifting, and info merging.
    %
    % Run all tests:
    %   results = runtests('pf2_base.tests.unit.BlockDefinitionTest');
    %
    % See also: pf2.data.defineBlocks, pf2.data.extractBlocks

    properties
        processedData   % Processed fNIRS sample data
    end

    methods (TestClassSetup)
        function loadSampleData(testCase)
            raw = pf2.import.sampleData.fNIR2000();
            testCase.processedData = processFNIRS2(raw);
        end
    end

    methods (Static)
        function data = makeSyntheticData()
            % Create minimal fNIRS struct with synthetic markers for testing
            fs = 10;
            T = 300; % 300 seconds
            nSamples = T * fs;
            nCh = 4;
            t = (0:nSamples-1)' / fs;

            data.time = t;
            data.fs = fs;
            data.HbO = randn(nSamples, nCh) * 0.01;
            data.HbR = randn(nSamples, nCh) * 0.005;
            data.HbDiff = data.HbO - data.HbR;
            data.HbTotal = data.HbO + data.HbR;
            data.CBSI = randn(nSamples, nCh) * 0.008;
            data.fchMask = ones(1, nCh);
            data.info = struct('SubjectID', 'S01', 'Task', 'Test');

            % Markers: [time, code, duration, amplitude]
            % 3 blocks of marker 49 at t=30, 90, 180 with durations 20, 25, 30
            data.markers = [
                30,  49, 20, 1;
                90,  49, 25, 1;
                180, 49, 30, 1;
            ];
        end

        function data = makePairedMarkerData()
            % Create data with start/end marker pairs
            fs = 10;
            T = 300;
            nSamples = T * fs;
            nCh = 4;
            t = (0:nSamples-1)' / fs;

            data.time = t;
            data.fs = fs;
            data.HbO = randn(nSamples, nCh) * 0.01;
            data.HbR = randn(nSamples, nCh) * 0.005;
            data.HbDiff = data.HbO - data.HbR;
            data.HbTotal = data.HbO + data.HbR;
            data.CBSI = randn(nSamples, nCh) * 0.008;
            data.fchMask = ones(1, nCh);
            data.info = struct('SubjectID', 'S01');

            % Start/end pairs: condition A (50->52), condition B (51->53)
            data.markers = [
                20,  50, 0, 1;   % Start A block 1
                45,  52, 0, 1;   % End A block 1
                60,  51, 0, 1;   % Start B block 1
                90,  53, 0, 1;   % End B block 1
                120, 50, 0, 1;   % Start A block 2
                155, 52, 0, 1;   % End A block 2
                200, 51, 0, 1;   % Start B block 2
                240, 53, 0, 1;   % End B block 2
            ];
        end
    end

    %% defineBlocks - Marker + Fixed Duration
    methods (Test)
        function testMarkerFixedDuration(testCase)
            % Marker code + fixed duration creates correct blocks
            data = pf2_base.tests.unit.BlockDefinitionTest.makeSyntheticData();
            blocks = pf2.data.defineBlocks(data, 'MarkerCode', 49, 'Duration', 15);

            testCase.verifyLength(blocks, 3, 'Should find 3 blocks');
            testCase.verifyEqual(blocks(1).startTime, 30, 'First block starts at marker time');
            testCase.verifyEqual(blocks(1).endTime, 45, 'First block ends at start + duration');
            testCase.verifyEqual(blocks(1).duration, 15, 'Duration should be 15s');
            testCase.verifyEqual(blocks(1).markerCode, 49, 'Marker code preserved');
        end

        function testMarkerFixedDurationBlockNumbers(testCase)
            % BlockNumber auto-assigned sequentially
            data = pf2_base.tests.unit.BlockDefinitionTest.makeSyntheticData();
            blocks = pf2.data.defineBlocks(data, 'MarkerCode', 49, 'Duration', 15);

            for k = 1:length(blocks)
                testCase.verifyEqual(blocks(k).info.BlockNumber, k, ...
                    sprintf('Block %d should have BlockNumber = %d', k, k));
            end
        end
    end

    %% defineBlocks - Marker Duration from Column 3
    methods (Test)
        function testMarkerUseDuration(testCase)
            % UseDuration flag reads duration from markers column 3
            data = pf2_base.tests.unit.BlockDefinitionTest.makeSyntheticData();
            blocks = pf2.data.defineBlocks(data, 'MarkerCode', 49, 'UseDuration', true);

            testCase.verifyLength(blocks, 3);
            testCase.verifyEqual(blocks(1).duration, 20, 'Block 1 duration from col 3');
            testCase.verifyEqual(blocks(2).duration, 25, 'Block 2 duration from col 3');
            testCase.verifyEqual(blocks(3).duration, 30, 'Block 3 duration from col 3');
            testCase.verifyEqual(blocks(1).endTime, 50, 'endTime = startTime + duration');
        end
    end

    %% defineBlocks - Start/End Pairs
    methods (Test)
        function testStartEndPairs(testCase)
            % Paired start/end markers produce correct windows
            data = pf2_base.tests.unit.BlockDefinitionTest.makePairedMarkerData();
            blocks = pf2.data.defineBlocks(data, ...
                'StartMarker', [50; 51], 'EndMarker', [52; 53]);

            testCase.verifyLength(blocks, 4, 'Should find 4 blocks (2 per condition)');

            % Sorted by time: A1(20-45), B1(60-90), A2(120-155), B2(200-240)
            testCase.verifyEqual(blocks(1).startTime, 20);
            testCase.verifyEqual(blocks(1).endTime, 45);
            testCase.verifyEqual(blocks(1).duration, 25);
            testCase.verifyEqual(blocks(2).startTime, 60);
            testCase.verifyEqual(blocks(2).endTime, 90);
        end
    end

    %% defineBlocks - ConditionMap
    methods (Test)
        function testConditionMap(testCase)
            % ConditionMap assigns condition labels per marker code
            data = pf2_base.tests.unit.BlockDefinitionTest.makePairedMarkerData();
            blocks = pf2.data.defineBlocks(data, ...
                'StartMarker', [50; 51], 'EndMarker', [52; 53], ...
                'ConditionMap', {50, 'Natural'; 51, 'Synthetic'});

            % Sorted by time: A1(50), B1(51), A2(50), B2(51)
            testCase.verifyEqual(blocks(1).info.Condition, 'Natural');
            testCase.verifyEqual(blocks(2).info.Condition, 'Synthetic');
            testCase.verifyEqual(blocks(3).info.Condition, 'Natural');
            testCase.verifyEqual(blocks(4).info.Condition, 'Synthetic');
        end

        function testConditionMapWithMarkerCode(testCase)
            % ConditionMap works with MarkerCode mode using OR logic
            data = pf2_base.tests.unit.BlockDefinitionTest.makePairedMarkerData();

            % Use column vector for OR: find markers 50 or 51
            blocks = pf2.data.defineBlocks(data, ...
                'MarkerCode', [50; 51], 'Duration', 10, ...
                'ConditionMap', {50, 'CondA'; 51, 'CondB'});

            testCase.verifyLength(blocks, 4, 'Should find 4 markers (2x50 + 2x51)');
            testCase.verifyEqual(blocks(1).info.Condition, 'CondA');
            testCase.verifyEqual(blocks(2).info.Condition, 'CondB');
        end
    end

    %% defineBlocks - InfoTable
    methods (Test)
        function testInfoTable(testCase)
            % Per-block table columns become .info fields
            data = pf2_base.tests.unit.BlockDefinitionTest.makeSyntheticData();
            scores = table([85; 92; 78], {'Easy';'Hard';'Easy'}, ...
                'VariableNames', {'Score','Difficulty'});

            blocks = pf2.data.defineBlocks(data, 'MarkerCode', 49, ...
                'Duration', 15, 'InfoTable', scores);

            testCase.verifyEqual(blocks(1).info.Score, 85);
            testCase.verifyEqual(blocks(2).info.Difficulty, 'Hard');
            testCase.verifyEqual(blocks(3).info.Score, 78);
        end
    end

    %% defineBlocks - InfoFields
    methods (Test)
        function testInfoFields(testCase)
            % Constant InfoFields applied to all blocks
            data = pf2_base.tests.unit.BlockDefinitionTest.makeSyntheticData();
            blocks = pf2.data.defineBlocks(data, 'MarkerCode', 49, ...
                'Duration', 15, 'InfoFields', struct('Task', 'Stroop', 'Group', 'Control'));

            for k = 1:length(blocks)
                testCase.verifyEqual(blocks(k).info.Task, 'Stroop');
                testCase.verifyEqual(blocks(k).info.Group, 'Control');
            end
        end
    end

    %% defineBlocks - MinDuration Filter
    methods (Test)
        function testMinDurationFilter(testCase)
            % Blocks shorter than MinDuration are rejected
            data = pf2_base.tests.unit.BlockDefinitionTest.makeSyntheticData();
            % Durations are 20, 25, 30 from column 3
            blocks = pf2.data.defineBlocks(data, 'MarkerCode', 49, ...
                'UseDuration', true, 'MinDuration', 22);

            testCase.verifyLength(blocks, 2, ...
                'Should reject block with duration=20 (< MinDuration=22)');
            testCase.verifyEqual(blocks(1).duration, 25);
            testCase.verifyEqual(blocks(2).duration, 30);
            % BlockNumbers should be renumbered after filtering
            testCase.verifyEqual(blocks(1).info.BlockNumber, 1);
            testCase.verifyEqual(blocks(2).info.BlockNumber, 2);
        end

        function testMaxDurationFilter(testCase)
            % Blocks longer than MaxDuration are rejected
            data = pf2_base.tests.unit.BlockDefinitionTest.makeSyntheticData();
            blocks = pf2.data.defineBlocks(data, 'MarkerCode', 49, ...
                'UseDuration', true, 'MaxDuration', 27);

            testCase.verifyLength(blocks, 2, ...
                'Should reject block with duration=30 (> MaxDuration=27)');
        end
    end

    %% defineBlocks - Empty Markers
    methods (Test)
        function testEmptyMarkers(testCase)
            % No matching markers returns empty struct array
            data = pf2_base.tests.unit.BlockDefinitionTest.makeSyntheticData();
            blocks = pf2.data.defineBlocks(data, 'MarkerCode', 999, 'Duration', 10);

            testCase.verifyEmpty(blocks, 'Should return empty for no matching markers');
            testCase.verifyTrue(isstruct(blocks), 'Empty result should still be struct');
        end

        function testEmptyMarkerArray(testCase)
            % Data with empty markers returns empty
            data = pf2_base.tests.unit.BlockDefinitionTest.makeSyntheticData();
            data.markers = zeros(0, 4);
            blocks = pf2.data.defineBlocks(data, 'MarkerCode', 49, 'Duration', 10);

            testCase.verifyEmpty(blocks);
        end
    end

    %% extractBlocks - Basic Extraction
    methods (Test)
        function testBasicExtraction(testCase)
            % Extract blocks produces correct number of segments
            data = pf2_base.tests.unit.BlockDefinitionTest.makeSyntheticData();
            blocks = pf2.data.defineBlocks(data, 'MarkerCode', 49, 'Duration', 20);
            segments = pf2.data.extractBlocks(data, blocks, 'SetT0', false);

            testCase.verifyLength(segments, 3, 'Should extract 3 segments');

            % Each segment should have time within block bounds
            for k = 1:length(segments)
                seg = segments{k};
                testCase.verifyTrue(isfield(seg, 'HbO'), 'Segment should have HbO');
                testCase.verifyTrue(isfield(seg, 'time'), 'Segment should have time');
                testCase.verifyGreaterThanOrEqual(min(seg.time), blocks(k).startTime - 0.5, ...
                    'Segment time should start near block start');
                testCase.verifyLessThanOrEqual(max(seg.time), blocks(k).endTime + 0.5, ...
                    'Segment time should end near block end');
            end
        end
    end

    %% extractBlocks - PreTime/PostTime
    methods (Test)
        function testPreTimePostTime(testCase)
            % PreTime and PostTime extend extraction window
            data = pf2_base.tests.unit.BlockDefinitionTest.makeSyntheticData();
            blocks = pf2.data.defineBlocks(data, 'MarkerCode', 49, 'Duration', 20);

            % Extract with 5s pre and 3s post, no T0 shift for easier verification
            segments = pf2.data.extractBlocks(data, blocks, ...
                'PreTime', 5, 'PostTime', 3, 'SetT0', false);

            seg = segments{1};
            expectedStart = blocks(1).startTime - 5;
            expectedEnd = blocks(1).endTime + 3;

            testCase.verifyLessThanOrEqual(min(seg.time), expectedStart + 0.2, ...
                'Segment should start at block start - PreTime');
            testCase.verifyGreaterThanOrEqual(max(seg.time), expectedEnd - 0.2, ...
                'Segment should end at block end + PostTime');
        end
    end

    %% extractBlocks - BaselineWindow
    methods (Test)
        function testBaselineWindow(testCase)
            % BaselineWindow applies baseline subtraction
            data = pf2_base.tests.unit.BlockDefinitionTest.makeSyntheticData();
            % Add a known offset to HbO so baseline subtraction is visible
            data.HbO = data.HbO + 5;

            blocks = pf2.data.defineBlocks(data, 'MarkerCode', 49, 'Duration', 20);

            % Extract without baseline
            segsNoBL = pf2.data.extractBlocks(data, blocks, 'SetT0', false);

            % Extract with baseline: [-5, 0] relative to block start
            % Need PreTime >= 5 to include baseline period in extraction
            segsBL = pf2.data.extractBlocks(data, blocks, ...
                'PreTime', 5, 'BaselineWindow', [-5, 0], 'SetT0', false);

            % Baseline-corrected data should have lower mean than uncorrected
            meanNoBL = mean(segsNoBL{1}.HbO(:));
            meanBL = mean(segsBL{1}.HbO(:));
            testCase.verifyLessThan(abs(meanBL), abs(meanNoBL), ...
                'Baseline correction should reduce mean offset');
        end
    end

    %% extractBlocks - SetT0
    methods (Test)
        function testSetT0(testCase)
            % SetT0 shifts time so block start = 0
            data = pf2_base.tests.unit.BlockDefinitionTest.makeSyntheticData();
            blocks = pf2.data.defineBlocks(data, 'MarkerCode', 49, 'Duration', 20);

            segments = pf2.data.extractBlocks(data, blocks, 'SetT0', true);

            for k = 1:length(segments)
                seg = segments{k};
                testCase.verifyEqual(min(seg.time), 0, 'AbsTol', 0.2, ...
                    'Time should start near 0 after SetT0');
            end
        end

        function testSetT0WithPreTime(testCase)
            % With PreTime, time starts at negative value
            data = pf2_base.tests.unit.BlockDefinitionTest.makeSyntheticData();
            blocks = pf2.data.defineBlocks(data, 'MarkerCode', 49, 'Duration', 20);

            segments = pf2.data.extractBlocks(data, blocks, ...
                'PreTime', 5, 'SetT0', true);

            seg = segments{1};
            testCase.verifyLessThan(min(seg.time), 0, ...
                'With PreTime, time should start before 0');
            testCase.verifyEqual(min(seg.time), -5, 'AbsTol', 0.2, ...
                'Time should start near -PreTime');
        end
    end

    %% extractBlocks - Info Merging
    methods (Test)
        function testInfoMerging(testCase)
            % Parent data.info merged with block.info
            data = pf2_base.tests.unit.BlockDefinitionTest.makeSyntheticData();
            blocks = pf2.data.defineBlocks(data, 'MarkerCode', 49, ...
                'Duration', 20, 'ConditionMap', {49, 'StroopTask'});

            segments = pf2.data.extractBlocks(data, blocks);

            seg = segments{1};
            % Parent info fields preserved
            testCase.verifyEqual(seg.info.SubjectID, 'S01', ...
                'Parent SubjectID should be copied');
            testCase.verifyEqual(seg.info.Task, 'Test', ...
                'Parent Task field should be preserved');
            % Block info fields overlaid
            testCase.verifyTrue(isfield(seg.info, 'BlockNumber'), ...
                'BlockNumber should be present');
            testCase.verifyEqual(seg.info.Condition, 'StroopTask', ...
                'Condition from ConditionMap should be present');
        end

        function testCopyInfoFalse(testCase)
            % CopyInfo=false skips parent data.info
            data = pf2_base.tests.unit.BlockDefinitionTest.makeSyntheticData();
            blocks = pf2.data.defineBlocks(data, 'MarkerCode', 49, 'Duration', 20);

            segments = pf2.data.extractBlocks(data, blocks, 'CopyInfo', false);

            seg = segments{1};
            testCase.verifyFalse(isfield(seg.info, 'SubjectID'), ...
                'Parent SubjectID should not be present when CopyInfo=false');
            testCase.verifyTrue(isfield(seg.info, 'BlockNumber'), ...
                'Block-level fields should still be present');
        end
    end

    %% extractBlocks - SkipInvalid
    methods (Test)
        function testSkipInvalid(testCase)
            % Blocks outside data range are skipped
            data = pf2_base.tests.unit.BlockDefinitionTest.makeSyntheticData();

            % Create blocks manually, one out of range
            blocks(1).startTime = 30;
            blocks(1).endTime = 50;
            blocks(1).duration = 20;
            blocks(1).markerCode = 49;
            blocks(1).markerIndex = 1;
            blocks(1).info = struct('BlockNumber', 1);

            blocks(2).startTime = 500;  % Beyond data range (300s)
            blocks(2).endTime = 520;
            blocks(2).duration = 20;
            blocks(2).markerCode = 49;
            blocks(2).markerIndex = 2;
            blocks(2).info = struct('BlockNumber', 2);

            segments = pf2.data.extractBlocks(data, blocks, 'SkipInvalid', true);

            testCase.verifyLength(segments, 1, ...
                'Out-of-range block should be skipped');
        end
    end

    %% Integration: defineBlocks -> extractBlocks -> Experiment
    methods (Test)
        function testEndToEndPipeline(testCase)
            % Full pipeline: define blocks, extract, verify cell array structure
            data = pf2_base.tests.unit.BlockDefinitionTest.makeSyntheticData();

            blocks = pf2.data.defineBlocks(data, 'MarkerCode', 49, ...
                'UseDuration', true, ...
                'ConditionMap', {49, 'StroopTask'}, ...
                'InfoFields', struct('Group', 'Control'));

            segments = pf2.data.extractBlocks(data, blocks, ...
                'PreTime', 5, 'PostTime', 2, 'SetT0', true);

            testCase.verifyLength(segments, 3, 'Should have 3 segments');

            % Verify each segment is a valid fNIRS struct
            for k = 1:length(segments)
                seg = segments{k};
                testCase.verifyTrue(isfield(seg, 'HbO'), 'Must have HbO');
                testCase.verifyTrue(isfield(seg, 'time'), 'Must have time');
                testCase.verifyTrue(isfield(seg, 'info'), 'Must have info');
                testCase.verifyEqual(seg.info.Condition, 'StroopTask');
                testCase.verifyEqual(seg.info.Group, 'Control');
                testCase.verifyEqual(seg.info.SubjectID, 'S01');
                testCase.verifyEqual(seg.info.BlockNumber, k);

                % Time should start near -5 (PreTime) after SetT0
                testCase.verifyEqual(min(seg.time), -5, 'AbsTol', 0.2);
            end
        end

        function testWithRealSampleData(testCase)
            % Verify with real processed sample data
            data = testCase.processedData;

            % Add synthetic markers to real data
            timeVec = data.time;
            minT = min(timeVec);
            data.markers = [
                minT + 30, 10, 20, 1;
                minT + 80, 10, 20, 1;
            ];

            blocks = pf2.data.defineBlocks(data, 'MarkerCode', 10, 'Duration', 20);
            segments = pf2.data.extractBlocks(data, blocks, 'SetT0', true);

            testCase.verifyLength(segments, 2);
            testCase.verifyTrue(isfield(segments{1}, 'HbO'));
            testCase.verifyEqual(size(segments{1}.HbO, 2), size(data.HbO, 2), ...
                'Channel count should be preserved');
        end
    end

    %% defineBlocks - Positional API
    methods (Test)
        function testPositionalCodesAndDuration(testCase)
            % Simple positional syntax: defineBlocks(data, codes, duration)
            data = pf2_base.tests.unit.BlockDefinitionTest.makeSyntheticData();
            blocks = pf2.data.defineBlocks(data, [49], 15);

            testCase.verifyLength(blocks, 3, 'Should find 3 blocks');
            testCase.verifyEqual(blocks(1).duration, 15);
            testCase.verifyEqual(blocks(1).startTime, 30);
        end

        function testPositionalMultipleCodes(testCase)
            % Multiple codes as row vector: defineBlocks(data, [49, 50], 30)
            data = pf2_base.tests.unit.BlockDefinitionTest.makePairedMarkerData();
            blocks = pf2.data.defineBlocks(data, [50, 51], 10);

            testCase.verifyLength(blocks, 4, 'Should find 4 blocks (2x50 + 2x51)');
        end

        function testPositionalAutoDuration(testCase)
            % No duration given: auto-detect from marker column 3
            data = pf2_base.tests.unit.BlockDefinitionTest.makeSyntheticData();
            blocks = pf2.data.defineBlocks(data, 49);

            testCase.verifyLength(blocks, 3);
            testCase.verifyEqual(blocks(1).duration, 20, ...
                'Should auto-use duration from marker column 3');
            testCase.verifyEqual(blocks(2).duration, 25);
            testCase.verifyEqual(blocks(3).duration, 30);
        end

        function testPositionalWithNameValue(testCase)
            % Positional codes + name-value params mixed
            data = pf2_base.tests.unit.BlockDefinitionTest.makeSyntheticData();
            blocks = pf2.data.defineBlocks(data, 49, 15, ...
                'ConditionMap', {49, 'Stroop'});

            testCase.verifyLength(blocks, 3);
            testCase.verifyEqual(blocks(1).info.Condition, 'Stroop');
            testCase.verifyEqual(blocks(1).duration, 15);
        end
    end

    %% defineBlocks - PrePad/PostPad
    methods (Test)
        function testPrePadPostPad(testCase)
            % PrePad and PostPad extend block boundaries
            data = pf2_base.tests.unit.BlockDefinitionTest.makeSyntheticData();
            blocks = pf2.data.defineBlocks(data, 49, 20, ...
                'PrePad', 5, 'PostPad', 3);

            testCase.verifyEqual(blocks(1).startTime, 25, ...
                'startTime should be 30 - 5 PrePad = 25');
            testCase.verifyEqual(blocks(1).endTime, 53, ...
                'endTime should be 50 + 3 PostPad = 53');
            testCase.verifyEqual(blocks(1).duration, 28, ...
                'duration = 20 + 5 + 3 = 28');
        end
    end

    %% defineBlocks - MarkerCode + EndMarker
    methods (Test)
        function testMarkerCodeWithEndMarker(testCase)
            % Single start code + single end code via MarkerCode + EndMarker
            data = pf2_base.tests.unit.BlockDefinitionTest.makeSyntheticData();
            data.markers = [10 49 0 1; 25 51 0 1; 40 49 0 1; 55 51 0 1];

            blocks = pf2.data.defineBlocks(data, 'MarkerCode', 49, 'EndMarker', 51);

            testCase.verifyLength(blocks, 2, 'Should find 2 blocks');
            testCase.verifyEqual(blocks(1).startTime, 10);
            testCase.verifyEqual(blocks(1).endTime, 25);
            testCase.verifyEqual(blocks(1).duration, 15);
            testCase.verifyEqual(blocks(2).startTime, 40);
            testCase.verifyEqual(blocks(2).endTime, 55);
            testCase.verifyEqual(blocks(2).duration, 15);
        end

        function testMarkerCodeWithEndMarkerPairs(testCase)
            % Per-code end markers: 49->59, 48->58
            data = pf2_base.tests.unit.BlockDefinitionTest.makeSyntheticData();
            data.markers = [10 49 0 1; 20 59 0 1; 30 48 0 1; 45 58 0 1];

            blocks = pf2.data.defineBlocks(data, 'MarkerCode', [49 48], ...
                'EndMarker', [59 58]);

            testCase.verifyLength(blocks, 2, 'Should find 2 blocks');
            % Sorted by time
            testCase.verifyEqual(blocks(1).startTime, 10);
            testCase.verifyEqual(blocks(1).endTime, 20);
            testCase.verifyEqual(blocks(1).markerCode, 49);
            testCase.verifyEqual(blocks(2).startTime, 30);
            testCase.verifyEqual(blocks(2).endTime, 45);
            testCase.verifyEqual(blocks(2).markerCode, 48);
        end

        function testPositionalCodesWithEndMarker(testCase)
            % Positional API: defineBlocks(data, 49, 'EndMarker', 51)
            data = pf2_base.tests.unit.BlockDefinitionTest.makeSyntheticData();
            data.markers = [10 49 0 1; 30 51 0 1];

            blocks = pf2.data.defineBlocks(data, 49, 'EndMarker', 51);

            testCase.verifyLength(blocks, 1);
            testCase.verifyEqual(blocks(1).startTime, 10);
            testCase.verifyEqual(blocks(1).endTime, 30);
            testCase.verifyEqual(blocks(1).duration, 20);
        end

        function testMarkerCodeEndMarkerSharedEnd(testCase)
            % Multiple start codes with one shared EndMarker (scalar broadcast)
            data = pf2_base.tests.unit.BlockDefinitionTest.makeSyntheticData();
            data.markers = [10 49 0 1; 25 51 0 1; 40 50 0 1; 55 51 0 1];

            blocks = pf2.data.defineBlocks(data, [49 50], 'EndMarker', 51);

            testCase.verifyLength(blocks, 2, 'Should find 2 blocks');
            testCase.verifyEqual(blocks(1).startTime, 10);
            testCase.verifyEqual(blocks(1).endTime, 25);
            testCase.verifyEqual(blocks(1).markerCode, 49);
            testCase.verifyEqual(blocks(2).startTime, 40);
            testCase.verifyEqual(blocks(2).endTime, 55);
            testCase.verifyEqual(blocks(2).markerCode, 50);
        end

        function testMarkerCodeEndMarkerWithConditionMap(testCase)
            % ConditionMap works in MarkerCode+EndMarker mode
            data = pf2_base.tests.unit.BlockDefinitionTest.makeSyntheticData();
            data.markers = [10 49 0 1; 25 51 0 1; 40 50 0 1; 55 51 0 1];

            blocks = pf2.data.defineBlocks(data, [49 50], 'EndMarker', 51, ...
                'ConditionMap', {49, 'CondA'; 50, 'CondB'});

            testCase.verifyLength(blocks, 2);
            testCase.verifyEqual(blocks(1).info.Condition, 'CondA');
            testCase.verifyEqual(blocks(2).info.Condition, 'CondB');
        end

        function testMarkerCodeEndMarkerMissingEnd(testCase)
            % Start marker with no subsequent end marker is skipped
            data = pf2_base.tests.unit.BlockDefinitionTest.makeSyntheticData();
            % Second start (40) has no end marker after it
            data.markers = [10 49 0 1; 25 51 0 1; 40 49 0 1];

            blocks = pf2.data.defineBlocks(data, 49, 'EndMarker', 51);

            testCase.verifyLength(blocks, 1, ...
                'Second start with no end should be skipped');
            testCase.verifyEqual(blocks(1).startTime, 10);
            testCase.verifyEqual(blocks(1).endTime, 25);
        end
    end

    %% Error Handling
    methods (Test)
        function testNoModeError(testCase)
            % Must specify either MarkerCode or StartMarker+EndMarker
            data = pf2_base.tests.unit.BlockDefinitionTest.makeSyntheticData();
            testCase.verifyError(...
                @() pf2.data.defineBlocks(data, 'Duration', 10), ...
                'pf2:defineBlocks:noMode');
        end

        function testAmbiguousModeError(testCase)
            % Cannot specify both MarkerCode and StartMarker
            data = pf2_base.tests.unit.BlockDefinitionTest.makeSyntheticData();
            testCase.verifyError(...
                @() pf2.data.defineBlocks(data, 'MarkerCode', 49, ...
                    'StartMarker', 50, 'EndMarker', 51), ...
                'pf2:defineBlocks:ambiguousMode');
        end
    end
end
