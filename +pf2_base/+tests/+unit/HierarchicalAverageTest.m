classdef HierarchicalAverageTest < matlab.unittest.TestCase
    % HIERARCHICALAVERAGETEST Unit tests for pf2_base.hierarchicalAverage
    %
    % Tests the hierarchical (nested) averaging function used in group
    % analysis to prevent pseudoreplication. Covers:
    %   - Two-level hierarchy (subject > trial)
    %   - Three-level hierarchy (group > subject > trial)
    %   - Single-level hierarchy (flat grouping)
    %   - Multi-column data
    %   - NaN handling
    %   - Custom averaging functions
    %   - Cell, numeric, and table input types
    %   - Edge cases and error conditions
    %
    % Run all tests:
    %   results = runtests('pf2_base.tests.unit.HierarchicalAverageTest');
    %
    % See also: pf2_base.hierarchicalAverage

    %% Core Functionality Tests
    methods (Test)
        function testDocumentationExample(testCase)
            % Verify the example from the function documentation
            %
            % Subject1 has two conditions with two trials each:
            %   Condition 1: [10, 10] -> mean = 10
            %   Condition 2: [5, 5]   -> mean = 5
            %   Subject mean: mean([10, 5]) = 7.5
            %
            % Subject2 has one condition:
            %   Condition 1: [2, 2] -> mean = 2

            arr = [10; 10; 5; 5; 2; 2];
            hierarchy = cell(6, 2);
            hierarchy(:,1) = {'Subject1';'Subject1';'Subject1';'Subject1';'Subject2';'Subject2'};
            hierarchy(:,2) = {1; 1; 2; 2; 1; 1};

            [avg, subjects] = pf2_base.hierarchicalAverage(arr, hierarchy);

            testCase.verifyEqual(avg(1), 7.5, 'AbsTol', 1e-10, ...
                'Subject1 should average to 7.5');
            testCase.verifyEqual(avg(2), 2, 'AbsTol', 1e-10, ...
                'Subject2 should average to 2');
            testCase.verifyEqual(subjects, {'Subject1'; 'Subject2'}, ...
                'Highest tier should return subject labels');
        end

        function testTwoLevelHierarchyPreventsPseudoreplication(testCase)
            % Verify that hierarchical averaging differs from flat averaging
            %
            % Subject1 has 4 observations, Subject2 has 2. A flat mean would
            % weight Subject1 more heavily. Hierarchical averaging gives equal
            % weight to each subject.

            arr = [10; 10; 10; 10; 0; 0];
            hierarchy = cell(6, 2);
            hierarchy(:,1) = {'S1';'S1';'S1';'S1';'S2';'S2'};
            hierarchy(:,2) = {1; 1; 2; 2; 1; 1};

            [avg, ~] = pf2_base.hierarchicalAverage(arr, hierarchy);

            % Hierarchical: S1=10, S2=0, grand mean would be [10; 0]
            % Flat mean would be (10+10+10+10+0+0)/6 = 6.67 (wrong)
            testCase.verifyEqual(avg(1), 10, 'AbsTol', 1e-10, ...
                'Subject1 mean should be 10');
            testCase.verifyEqual(avg(2), 0, 'AbsTol', 1e-10, ...
                'Subject2 mean should be 0');
        end

        function testThreeLevelHierarchy(testCase)
            % Three-level hierarchy: Group > Subject > Trial
            %
            % Group A:
            %   S1: trials [10, 20] -> mean 15
            %   S2: trials [30, 40] -> mean 35
            % Group B:
            %   S3: trials [50, 60] -> mean 55

            arr = [10; 20; 30; 40; 50; 60];
            hierarchy = cell(6, 3);
            hierarchy(:,1) = {'A';'A';'A';'A';'B';'B'};
            hierarchy(:,2) = {'S1';'S1';'S2';'S2';'S3';'S3'};
            hierarchy(:,3) = {1; 2; 1; 2; 1; 2};

            [avg, groups] = pf2_base.hierarchicalAverage(arr, hierarchy);

            % Group A: mean([15, 35]) = 25
            % Group B: mean([55]) = 55
            testCase.verifyEqual(avg(1), 25, 'AbsTol', 1e-10, ...
                'Group A should average to 25');
            testCase.verifyEqual(avg(2), 55, 'AbsTol', 1e-10, ...
                'Group B should average to 55');
            testCase.verifyEqual(groups, {'A'; 'B'}, ...
                'Highest tier should return group labels');
        end

        function testSingleLevelHierarchy(testCase)
            % Single level: just group by one factor
            %
            % S1: [10, 20] -> mean 15
            % S2: [30, 40] -> mean 35

            arr = [10; 20; 30; 40];
            hierarchy = {'S1'; 'S1'; 'S2'; 'S2'};

            [avg, subjects] = pf2_base.hierarchicalAverage(arr, hierarchy);

            testCase.verifyEqual(avg(1), 15, 'AbsTol', 1e-10, ...
                'S1 should average to 15');
            testCase.verifyEqual(avg(2), 35, 'AbsTol', 1e-10, ...
                'S2 should average to 35');
            testCase.verifyEqual(subjects, {'S1'; 'S2'}, ...
                'Should return subject labels');
        end

        function testMultiColumnData(testCase)
            % Multiple data columns averaged independently

            arr = [10, 100; 20, 200; 30, 300; 40, 400];
            hierarchy = {'S1'; 'S1'; 'S2'; 'S2'};

            [avg, ~] = pf2_base.hierarchicalAverage(arr, hierarchy);

            testCase.verifyEqual(size(avg), [2, 2], ...
                'Output should have 2 rows x 2 columns');
            testCase.verifyEqual(avg(1,1), 15, 'AbsTol', 1e-10, ...
                'S1 col1 should be 15');
            testCase.verifyEqual(avg(1,2), 150, 'AbsTol', 1e-10, ...
                'S1 col2 should be 150');
            testCase.verifyEqual(avg(2,1), 35, 'AbsTol', 1e-10, ...
                'S2 col1 should be 35');
            testCase.verifyEqual(avg(2,2), 350, 'AbsTol', 1e-10, ...
                'S2 col2 should be 350');
        end

        function testAllUniqueRows(testCase)
            % When all hierarchy rows are unique, no averaging needed

            arr = [10; 20; 30];
            hierarchy = {'S1'; 'S2'; 'S3'};

            [avg, subjects] = pf2_base.hierarchicalAverage(arr, hierarchy);

            testCase.verifyEqual(avg, [10; 20; 30], 'AbsTol', 1e-10, ...
                'No averaging should occur when all rows unique');
            testCase.verifyEqual(numel(subjects), 3, ...
                'Should return 3 labels');
        end

        function testSingleObservation(testCase)
            % Single observation returns itself

            arr = [42];
            hierarchy = {'S1'};

            [avg, ~] = pf2_base.hierarchicalAverage(arr, hierarchy);

            testCase.verifyEqual(avg, 42, 'AbsTol', 1e-10, ...
                'Single observation should return itself');
        end
    end

    %% NaN Handling Tests
    methods (Test)
        function testNaNValuesIgnored(testCase)
            % NaN values should be ignored in averaging (nanmean default)

            arr = [10; NaN; 20; 30];
            hierarchy = {'S1'; 'S1'; 'S2'; 'S2'};

            [avg, ~] = pf2_base.hierarchicalAverage(arr, hierarchy);

            testCase.verifyEqual(avg(1), 10, 'AbsTol', 1e-10, ...
                'S1 with one NaN should use only the valid value');
            testCase.verifyEqual(avg(2), 25, 'AbsTol', 1e-10, ...
                'S2 should average normally');
        end

        function testAllNaNForOneGroup(testCase)
            % All NaN for one group should produce NaN output

            arr = [NaN; NaN; 20; 30];
            hierarchy = {'S1'; 'S1'; 'S2'; 'S2'};

            [avg, ~] = pf2_base.hierarchicalAverage(arr, hierarchy);

            testCase.verifyTrue(isnan(avg(1)), ...
                'All-NaN group should produce NaN');
            testCase.verifyEqual(avg(2), 25, 'AbsTol', 1e-10, ...
                'S2 should still average normally');
        end
    end

    %% Custom Averaging Function Tests
    methods (Test)
        function testCustomFunctionHandle(testCase)
            % Use @nanmedian instead of default @nanmean

            arr = [1; 2; 100; 10; 20; 30];
            hierarchy = cell(6, 2);
            hierarchy(:,1) = {'S1';'S1';'S1';'S2';'S2';'S2'};
            hierarchy(:,2) = {1; 2; 3; 1; 2; 3};

            [avg_mean, ~] = pf2_base.hierarchicalAverage(arr, hierarchy);
            [avg_median, ~] = pf2_base.hierarchicalAverage(arr, hierarchy, @nanmedian);

            % S1: mean([1,2,100]) = 34.33, median([1,2,100]) = 2
            testCase.verifyEqual(avg_mean(1), mean([1,2,100]), 'AbsTol', 1e-10, ...
                'Mean for S1 should match');
            testCase.verifyEqual(avg_median(1), 2, 'AbsTol', 1e-10, ...
                'Median for S1 should be 2');
        end

        function testCustomFunctionString(testCase)
            % Pass averaging function as a string name

            arr = [10; 20; 30; 40];
            hierarchy = {'S1'; 'S1'; 'S2'; 'S2'};

            [avg, ~] = pf2_base.hierarchicalAverage(arr, hierarchy, 'nanmean');

            testCase.verifyEqual(avg(1), 15, 'AbsTol', 1e-10, ...
                'String function name should work like handle');
        end

        function testInvalidFuncErrors(testCase)
            % Invalid function argument should error

            arr = [10; 20];
            hierarchy = {'S1'; 'S1'};

            testCase.verifyError(...
                @() pf2_base.hierarchicalAverage(arr, hierarchy, 12345), ...
                '', ...
                'Non-function non-string third argument should error');
        end
    end

    %% Input Type Tests
    methods (Test)
        function testNumericHierarchy(testCase)
            % Numeric hierarchy array

            arr = [10; 20; 30; 40];
            hierarchy = [1 1; 1 2; 2 1; 2 2];

            [avg, ~] = pf2_base.hierarchicalAverage(arr, hierarchy);

            testCase.verifyEqual(avg(1), 15, 'AbsTol', 1e-10, ...
                'Group 1 should average to 15');
            testCase.verifyEqual(avg(2), 35, 'AbsTol', 1e-10, ...
                'Group 2 should average to 35');
        end

        function testCellArrayData(testCase)
            % Cell array data input (converted to matrix internally)

            arr = {10; 20; 30; 40};
            hierarchy = {'S1'; 'S1'; 'S2'; 'S2'};

            [avg, ~] = pf2_base.hierarchicalAverage(arr, hierarchy);

            testCase.verifyEqual(avg(1), 15, 'AbsTol', 1e-10, ...
                'Cell array data should work like numeric');
        end

        function testTransposedDataAutoCorrects(testCase)
            % Row vector data should be auto-transposed to match hierarchy

            arr = [10, 20, 30, 40];  % 1x4 row vector
            hierarchy = {'S1'; 'S1'; 'S2'; 'S2'};  % 4x1

            [avg, ~] = pf2_base.hierarchicalAverage(arr, hierarchy);

            testCase.verifyEqual(avg(1), 15, 'AbsTol', 1e-10, ...
                'Auto-transposed S1 should average to 15');
            testCase.verifyEqual(avg(2), 35, 'AbsTol', 1e-10, ...
                'Auto-transposed S2 should average to 35');
        end

        function testCellHierarchyWithNumericValues(testCase)
            % Cell hierarchy containing numeric values

            arr = [10; 20; 30; 40];
            hierarchy = cell(4, 2);
            hierarchy(:,1) = {'S1';'S1';'S2';'S2'};
            hierarchy(:,2) = {1; 2; 1; 2};

            [avg, subjects] = pf2_base.hierarchicalAverage(arr, hierarchy);

            testCase.verifyEqual(numel(avg), 2, ...
                'Should produce 2 output rows');
            testCase.verifyEqual(subjects, {'S1'; 'S2'}, ...
                'Should return string labels from column 1');
        end
    end

    %% Output Structure Tests
    methods (Test)
        function testOutputRowCount(testCase)
            % Output rows should equal number of unique highest-tier groups

            arr = [1; 2; 3; 4; 5; 6];
            hierarchy = {'A';'A';'B';'B';'C';'C'};

            [avg, subjects] = pf2_base.hierarchicalAverage(arr, hierarchy);

            testCase.verifyEqual(size(avg, 1), 3, ...
                'Should have 3 output rows for 3 subjects');
            testCase.verifyEqual(numel(subjects), 3, ...
                'Should have 3 labels');
        end

        function testHighestTierOutput(testCase)
            % highestTier should contain unique labels from column 1

            arr = [1; 2; 3; 4; 5; 6];
            hierarchy = cell(6, 2);
            hierarchy(:,1) = {'X';'X';'Y';'Y';'Z';'Z'};
            hierarchy(:,2) = {1; 2; 1; 2; 1; 2};

            [~, labels] = pf2_base.hierarchicalAverage(arr, hierarchy);

            testCase.verifyEqual(numel(labels), 3, ...
                'Should have 3 unique top-level labels');
            testCase.verifyTrue(all(ismember({'X';'Y';'Z'}, labels)), ...
                'Labels should contain X, Y, Z');
        end

        function testThirdOutputExists(testCase)
            % outHarr (third output) should be returned for debugging

            arr = [10; 20; 30; 40];
            hierarchy = cell(4, 2);
            hierarchy(:,1) = {'S1';'S1';'S2';'S2'};
            hierarchy(:,2) = {1; 2; 1; 2};

            [~, ~, outHarr] = pf2_base.hierarchicalAverage(arr, hierarchy);

            testCase.verifyFalse(isempty(outHarr), ...
                'Third output (outHarr) should not be empty');
        end
    end

    %% Unbalanced Design Tests
    methods (Test)
        function testUnbalancedTrialsPerSubject(testCase)
            % Different number of trials per subject

            arr = [10; 20; 30; 40; 50];
            hierarchy = cell(5, 2);
            hierarchy(:,1) = {'S1';'S1';'S1';'S2';'S2'};
            hierarchy(:,2) = {1; 2; 3; 1; 2};

            [avg, ~] = pf2_base.hierarchicalAverage(arr, hierarchy);

            testCase.verifyEqual(avg(1), 20, 'AbsTol', 1e-10, ...
                'S1 with 3 trials: mean([10,20,30]) = 20');
            testCase.verifyEqual(avg(2), 45, 'AbsTol', 1e-10, ...
                'S2 with 2 trials: mean([40,50]) = 45');
        end

        function testUnbalancedConditionsAcrossSubjects(testCase)
            % Some subjects have conditions that others do not
            %
            % S1: Condition A [10,20] -> 15, Condition B [30] -> 30
            %     Subject mean: mean([15, 30]) = 22.5
            % S2: Condition A [40,50] -> 45
            %     Subject mean: 45

            arr = [10; 20; 30; 40; 50];
            hierarchy = cell(5, 2);
            hierarchy(:,1) = {'S1';'S1';'S1';'S2';'S2'};
            hierarchy(:,2) = {'A'; 'A'; 'B'; 'A'; 'A'};

            [avg, ~] = pf2_base.hierarchicalAverage(arr, hierarchy);

            testCase.verifyEqual(avg(1), 22.5, 'AbsTol', 1e-10, ...
                'S1: mean([mean([10,20]), 30]) = 22.5');
            testCase.verifyEqual(avg(2), 45, 'AbsTol', 1e-10, ...
                'S2: mean([40,50]) = 45');
        end
    end

    %% Error Condition Tests
    methods (Test)
        function testNoInputErrors(testCase)
            % No arguments should produce an error

            testCase.verifyError(...
                @() pf2_base.hierarchicalAverage(), ...
                '', ...
                'No input should error');
        end

        function testMissingHierarchyErrors(testCase)
            % Missing hierarchy should produce an error

            testCase.verifyError(...
                @() pf2_base.hierarchicalAverage([1; 2; 3]), ...
                '', ...
                'Missing hierarchy should error');
        end

        function testMismatchedDimensionsErrors(testCase)
            % Data rows not matching hierarchy rows should error

            arr = [1; 2; 3];
            hierarchy = {'S1'; 'S2'};  % 2 rows vs 3 data rows

            testCase.verifyError(...
                @() pf2_base.hierarchicalAverage(arr, hierarchy), ...
                '', ...
                'Mismatched dimensions should error');
        end
    end

    %% Realistic fNIRS-style Tests
    methods (Test)
        function testRealisticGroupAnalysis(testCase)
            % Simulate a realistic fNIRS group analysis scenario
            %
            % 3 subjects, 2 conditions each, 2 trials per condition
            % Data has 4 channels (columns)

            nChannels = 4;
            % S1: Cond1 trials
            data = [
                1, 2, 3, 4;    % S1, C1, T1
                3, 4, 5, 6;    % S1, C1, T2
                5, 6, 7, 8;    % S1, C2, T1
                7, 8, 9, 10;   % S1, C2, T2
                10, 20, 30, 40;  % S2, C1, T1
                12, 22, 32, 42;  % S2, C1, T2
                14, 24, 34, 44;  % S2, C2, T1
                16, 26, 36, 46;  % S2, C2, T2
                100, 200, 300, 400;  % S3, C1, T1
                100, 200, 300, 400;  % S3, C1, T2
                100, 200, 300, 400;  % S3, C2, T1
                100, 200, 300, 400;  % S3, C2, T2
            ];

            hierarchy = cell(12, 3);
            hierarchy(:,1) = {'S1';'S1';'S1';'S1';'S2';'S2';'S2';'S2';'S3';'S3';'S3';'S3'};
            hierarchy(:,2) = {'C1';'C1';'C2';'C2';'C1';'C1';'C2';'C2';'C1';'C1';'C2';'C2'};
            hierarchy(:,3) = {1; 2; 1; 2; 1; 2; 1; 2; 1; 2; 1; 2};

            [avg, subjects] = pf2_base.hierarchicalAverage(data, hierarchy);

            testCase.verifyEqual(size(avg, 1), 3, ...
                'Should have 3 subject rows');
            testCase.verifyEqual(size(avg, 2), nChannels, ...
                'Should preserve 4 channels');

            % S1 channel 1: mean([mean([1,3]), mean([5,7])]) = mean([2, 6]) = 4
            testCase.verifyEqual(avg(1, 1), 4, 'AbsTol', 1e-10, ...
                'S1 channel 1 hierarchical average');

            % S3 all channels should be 100, 200, 300, 400 (all identical)
            testCase.verifyEqual(avg(3, :), [100, 200, 300, 400], 'AbsTol', 1e-10, ...
                'S3 with identical data should return same values');
        end
    end

    %% hierarchicalAverageMulti Tests
    methods (Test)
        function testMultiEquivalenceWithSingleFunc(testCase)
            % Single-function multi call should match original function

            arr = [10; 10; 5; 5; 2; 2];
            hierarchy = cell(6, 2);
            hierarchy(:,1) = {'Subject1';'Subject1';'Subject1';'Subject1';'Subject2';'Subject2'};
            hierarchy(:,2) = {1; 1; 2; 2; 1; 1};

            [avgOrig, labelsOrig] = pf2_base.hierarchicalAverage(arr, hierarchy, @nanmean);
            [results, labelsMulti] = pf2_base.hierarchicalAverageMulti(arr, hierarchy, {@nanmean});

            testCase.verifyEqual(results{1}, avgOrig, 'AbsTol', 1e-10, ...
                'Multi with single func should match original');
            testCase.verifyEqual(labelsMulti, labelsOrig, ...
                'Labels should match');
        end

        function testMultiEquivalenceMedian(testCase)
            % Median equivalence check

            arr = [1; 2; 100; 10; 20; 30];
            hierarchy = cell(6, 2);
            hierarchy(:,1) = {'S1';'S1';'S1';'S2';'S2';'S2'};
            hierarchy(:,2) = {1; 2; 3; 1; 2; 3};

            avgOrig = pf2_base.hierarchicalAverage(arr, hierarchy, @nanmedian);
            results = pf2_base.hierarchicalAverageMulti(arr, hierarchy, {@nanmedian});

            testCase.verifyEqual(results{1}, avgOrig, 'AbsTol', 1e-10, ...
                'Multi median should match original median');
        end

        function testMultiFourFunctions(testCase)
            % Verify mean, median, max, min all computed correctly

            arr = [10; 20; 30; 40];
            hierarchy = {'S1'; 'S1'; 'S2'; 'S2'};

            nanmax3 = @(x,dim) nanmax(x,[],dim);
            nanmin3 = @(x,dim) nanmin(x,[],dim);
            funcs = {@nanmean, @nanmedian, nanmax3, nanmin3};

            results = pf2_base.hierarchicalAverageMulti(arr, hierarchy, funcs);

            testCase.verifyEqual(numel(results), 4, 'Should return 4 results');
            % S1: [10,20], S2: [30,40]
            testCase.verifyEqual(results{1}, [15; 35], 'AbsTol', 1e-10, 'Mean');
            testCase.verifyEqual(results{2}, [15; 35], 'AbsTol', 1e-10, 'Median');
            testCase.verifyEqual(results{3}, [20; 40], 'AbsTol', 1e-10, 'Max');
            testCase.verifyEqual(results{4}, [10; 30], 'AbsTol', 1e-10, 'Min');
        end

        function testMulti3DArray(testCase)
            % Test with [N x T x C] input (the grandAvgFNIRS use case)

            % 4 observations, 3 timepoints, 2 channels
            arr = zeros(4, 3, 2);
            arr(1,:,1) = [1 2 3];   arr(1,:,2) = [10 20 30];  % S1 trial 1
            arr(2,:,1) = [3 4 5];   arr(2,:,2) = [30 40 50];  % S1 trial 2
            arr(3,:,1) = [5 6 7];   arr(3,:,2) = [50 60 70];  % S2 trial 1
            arr(4,:,1) = [7 8 9];   arr(4,:,2) = [70 80 90];  % S2 trial 2
            hierarchy = {'S1'; 'S1'; 'S2'; 'S2'};

            results = pf2_base.hierarchicalAverageMulti(arr, hierarchy, {@nanmean});

            testCase.verifyEqual(size(results{1}), [2, 3, 2], ...
                'Output should be [2 subjects x 3 timepoints x 2 channels]');
            % S1 mean: ([1 2 3]+[3 4 5])/2 = [2 3 4] for ch1
            testCase.verifyEqual(squeeze(results{1}(1,:,1)), [2 3 4], 'AbsTol', 1e-10, ...
                'S1 ch1 timepoints should average correctly');
        end

        function testMultiThreeLevelHierarchy(testCase)
            % Three-level hierarchy with multi functions

            arr = [10; 20; 30; 40; 50; 60];
            hierarchy = cell(6, 3);
            hierarchy(:,1) = {'A';'A';'A';'A';'B';'B'};
            hierarchy(:,2) = {'S1';'S1';'S2';'S2';'S3';'S3'};
            hierarchy(:,3) = {1; 2; 1; 2; 1; 2};

            % Compare each function individually
            avgMean = pf2_base.hierarchicalAverage(arr, hierarchy, @nanmean);
            avgMedian = pf2_base.hierarchicalAverage(arr, hierarchy, @nanmedian);

            results = pf2_base.hierarchicalAverageMulti(arr, hierarchy, {@nanmean, @nanmedian});

            testCase.verifyEqual(results{1}, avgMean, 'AbsTol', 1e-10, ...
                'Multi mean should match original for 3-level hierarchy');
            testCase.verifyEqual(results{2}, avgMedian, 'AbsTol', 1e-10, ...
                'Multi median should match original for 3-level hierarchy');
        end

        function testMultiSingleObservation(testCase)
            % Single observation edge case

            arr = [42];
            hierarchy = {'S1'};

            results = pf2_base.hierarchicalAverageMulti(arr, hierarchy, {@nanmean, @nanmedian});

            testCase.verifyEqual(results{1}, 42, 'AbsTol', 1e-10, ...
                'Single obs mean should be itself');
            testCase.verifyEqual(results{2}, 42, 'AbsTol', 1e-10, ...
                'Single obs median should be itself');
        end

        function testMultiAllNaN(testCase)
            % All-NaN data

            arr = [NaN; NaN; 20; 30];
            hierarchy = {'S1'; 'S1'; 'S2'; 'S2'};

            results = pf2_base.hierarchicalAverageMulti(arr, hierarchy, {@nanmean});

            testCase.verifyTrue(isnan(results{1}(1)), ...
                'All-NaN group should produce NaN');
            testCase.verifyEqual(results{1}(2), 25, 'AbsTol', 1e-10, ...
                'S2 should average normally');
        end

        function testMultiAllUniqueRows(testCase)
            % All unique rows — no averaging needed

            arr = [10; 20; 30];
            hierarchy = {'S1'; 'S2'; 'S3'};

            results = pf2_base.hierarchicalAverageMulti(arr, hierarchy, {@nanmean, @nanmedian});

            testCase.verifyEqual(results{1}, [10; 20; 30], 'AbsTol', 1e-10, ...
                'No averaging should occur');
            testCase.verifyEqual(results{2}, [10; 20; 30], 'AbsTol', 1e-10, ...
                'No averaging should occur');
        end

        function testMultiNumericHierarchy(testCase)
            % Numeric hierarchy input

            arr = [10; 20; 30; 40];
            hierarchy = [1 1; 1 2; 2 1; 2 2];

            results = pf2_base.hierarchicalAverageMulti(arr, hierarchy, {@nanmean});

            testCase.verifyEqual(results{1}(1), 15, 'AbsTol', 1e-10);
            testCase.verifyEqual(results{1}(2), 35, 'AbsTol', 1e-10);
        end

        function testMultiRealisticFNIRS(testCase)
            % Realistic 3-subject, 2-condition, 2-trial, 4-channel scenario

            data = [
                1, 2, 3, 4;    % S1, C1, T1
                3, 4, 5, 6;    % S1, C1, T2
                5, 6, 7, 8;    % S1, C2, T1
                7, 8, 9, 10;   % S1, C2, T2
                10, 20, 30, 40;  % S2, C1, T1
                12, 22, 32, 42;  % S2, C1, T2
                14, 24, 34, 44;  % S2, C2, T1
                16, 26, 36, 46;  % S2, C2, T2
                100, 200, 300, 400;  % S3, C1, T1
                100, 200, 300, 400;  % S3, C1, T2
                100, 200, 300, 400;  % S3, C2, T1
                100, 200, 300, 400;  % S3, C2, T2
            ];

            hierarchy = cell(12, 3);
            hierarchy(:,1) = {'S1';'S1';'S1';'S1';'S2';'S2';'S2';'S2';'S3';'S3';'S3';'S3'};
            hierarchy(:,2) = {'C1';'C1';'C2';'C2';'C1';'C1';'C2';'C2';'C1';'C1';'C2';'C2'};
            hierarchy(:,3) = {1; 2; 1; 2; 1; 2; 1; 2; 1; 2; 1; 2};

            % Get reference from original
            avgOrig = pf2_base.hierarchicalAverage(data, hierarchy, @nanmean);

            % Get from multi
            results = pf2_base.hierarchicalAverageMulti(data, hierarchy, {@nanmean});

            testCase.verifyEqual(results{1}, avgOrig, 'AbsTol', 1e-10, ...
                'Multi should match original for realistic fNIRS data');
        end
    end
end
