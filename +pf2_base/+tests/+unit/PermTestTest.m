classdef PermTestTest < matlab.unittest.TestCase
    % PERMTESTTEST Unit tests for exploreFNIRS.stats.permTest
    %
    %   results = runtests('pf2_base.tests.unit.PermTestTest');

    properties
        mockGroups   % Mock 2-group aggregated struct with paired subjects
    end

    methods (TestClassSetup)
        function buildMockGroups(testCase)
            % Build minimal groups struct with shared subjects across groups
            rng(42);
            nSub = 6;
            nCh = 3;
            nTime = 2;

            subIDs = arrayfun(@(x) sprintf('S%02d', x), (1:nSub)', 'UniformOutput', false);

            for g = 1:2
                grp(g).label = sprintf('Condition%d', g);
                grp(g).gbyFNIRS = {};

                % Same subjects in both groups (paired design)
                grp(g).gbyTables = table(subIDs, 'VariableNames', {'SubjectID'});

                % Build gbyGrandBarFlat
                bf = struct();
                bf.time = (1:nTime)';

                % Group 2 has larger values (clear effect)
                offset = (g - 1) * 1.5;
                for bio = {'HbO','HbR','HbTotal','CBSI'}
                    bf.(bio{1}).data = randn(nTime, nCh, nSub) + offset;
                    bf.(bio{1}).Mean = mean(bf.(bio{1}).data, 3);
                end

                grp(g).gbyGrandBarFlat = bf;
                grp(g).gbyGrand = bf;
            end

            testCase.mockGroups = grp;
        end
    end

    methods (Test)

        %% --- Basic functionality ---

        function testReturnsStruct(testCase)
            r = exploreFNIRS.stats.permTest(testCase.mockGroups, {'Condition'}, ...
                'Biomarkers', {'HbO'}, 'NumPerm', 100, 'Verbose', false);
            testCase.verifyClass(r, 'struct');
        end

        function testHasRequiredFields(testCase)
            r = exploreFNIRS.stats.permTest(testCase.mockGroups, {'Condition'}, ...
                'Biomarkers', {'HbO'}, 'NumPerm', 100, 'Verbose', false);

            expectedFields = {'observed', 'nullDist', 'pvalue', ...
                'pvalueFDR', 'significant', 'effectSize', 'nPerms', ...
                'isExact', 'statistic', 'tail', 'biomarkers', 'channels', ...
                'conditions', 'nSubjects'};
            for i = 1:length(expectedFields)
                testCase.verifyTrue(isfield(r, expectedFields{i}), ...
                    sprintf('Missing field: %s', expectedFields{i}));
            end
        end

        function testOutputSizes(testCase)
            r = exploreFNIRS.stats.permTest(testCase.mockGroups, {'Condition'}, ...
                'Biomarkers', {'HbO','HbR'}, 'Channels', [1,2], ...
                'NumPerm', 50, 'Verbose', false);
            testCase.verifySize(r.observed, [2, 2]);
            testCase.verifySize(r.pvalue, [2, 2]);
            testCase.verifySize(r.significant, [2, 2]);
        end

        %% --- P-values ---

        function testPvaluesInRange(testCase)
            r = exploreFNIRS.stats.permTest(testCase.mockGroups, {'Condition'}, ...
                'Biomarkers', {'HbO'}, 'NumPerm', 100, 'Verbose', false);

            for i = 1:numel(r.pvalue)
                if ~isnan(r.pvalue(i))
                    testCase.verifyGreaterThan(r.pvalue(i), 0);
                    testCase.verifyLessThanOrEqual(r.pvalue(i), 1);
                end
            end
        end

        function testPvaluesNeverZero(testCase)
            % Phipson & Smyth: p-values should never be exactly zero
            r = exploreFNIRS.stats.permTest(testCase.mockGroups, {'Condition'}, ...
                'Biomarkers', {'HbO'}, 'NumPerm', 100, 'Verbose', false);

            validP = r.pvalue(~isnan(r.pvalue));
            testCase.verifyTrue(all(validP > 0), ...
                'P-values should never be zero (Phipson & Smyth 2010)');
        end

        %% --- Exact mode ---

        function testExactModeSmallN(testCase)
            % With 6 subjects, 2^6 = 64 permutations (should use exact)
            r = exploreFNIRS.stats.permTest(testCase.mockGroups, {'Condition'}, ...
                'Biomarkers', {'HbO'}, 'NumPerm', 100, 'Verbose', false);

            % 2^6 = 64 < 100, so should switch to exact
            testCase.verifyTrue(r.isExact);
            testCase.verifyEqual(r.nPerms, 64);
        end

        function testExactModeExplicit(testCase)
            r = exploreFNIRS.stats.permTest(testCase.mockGroups, {'Condition'}, ...
                'Biomarkers', {'HbO'}, 'NumPerm', 'exact', 'Verbose', false);
            testCase.verifyTrue(r.isExact);
        end

        %% --- Statistic types ---

        function testMeanDiff(testCase)
            r = exploreFNIRS.stats.permTest(testCase.mockGroups, {'Condition'}, ...
                'Statistic', 'mean_diff', 'Biomarkers', {'HbO'}, ...
                'NumPerm', 50, 'Verbose', false);
            testCase.verifyEqual(r.statistic, 'mean_diff');
        end

        function testTstat(testCase)
            r = exploreFNIRS.stats.permTest(testCase.mockGroups, {'Condition'}, ...
                'Statistic', 'tstat', 'Biomarkers', {'HbO'}, ...
                'NumPerm', 50, 'Verbose', false);
            testCase.verifyEqual(r.statistic, 'tstat');
        end

        %% --- Tail directions ---

        function testTailBoth(testCase)
            r = exploreFNIRS.stats.permTest(testCase.mockGroups, {'Condition'}, ...
                'Tail', 'both', 'Biomarkers', {'HbO'}, ...
                'NumPerm', 50, 'Verbose', false);
            testCase.verifyEqual(r.tail, 'both');
        end

        function testTailRight(testCase)
            r = exploreFNIRS.stats.permTest(testCase.mockGroups, {'Condition'}, ...
                'Tail', 'right', 'Biomarkers', {'HbO'}, ...
                'NumPerm', 50, 'Verbose', false);
            testCase.verifyEqual(r.tail, 'right');
        end

        %% --- Effect size ---

        function testEffectSizeComputed(testCase)
            r = exploreFNIRS.stats.permTest(testCase.mockGroups, {'Condition'}, ...
                'Biomarkers', {'HbO'}, 'NumPerm', 50, 'Verbose', false);

            testCase.verifySize(r.effectSize, size(r.observed));
        end

        %% --- FDR correction ---

        function testFDRCorrectionApplied(testCase)
            r = exploreFNIRS.stats.permTest(testCase.mockGroups, {'Condition'}, ...
                'Biomarkers', {'HbO'}, 'NumPerm', 50, 'Verbose', false);

            % FDR q-values should be >= uncorrected p-values
            valid = ~isnan(r.pvalue) & ~isnan(r.pvalueFDR);
            if any(valid(:))
                testCase.verifyGreaterThanOrEqual( ...
                    r.pvalueFDR(valid), r.pvalue(valid) - 1e-10);
            end
        end

        %% --- Reproducibility ---

        function testSeedReproducibility(testCase)
            r1 = exploreFNIRS.stats.permTest(testCase.mockGroups, {'Condition'}, ...
                'Biomarkers', {'HbO'}, 'Channels', 1, ...
                'NumPerm', 100, 'Seed', 999, 'Verbose', false);
            r2 = exploreFNIRS.stats.permTest(testCase.mockGroups, {'Condition'}, ...
                'Biomarkers', {'HbO'}, 'Channels', 1, ...
                'NumPerm', 100, 'Seed', 999, 'Verbose', false);

            testCase.verifyEqual(r1.pvalue, r2.pvalue, 'AbsTol', 1e-10);
        end

        %% --- Validation ---

        function testRequiresTwoGroups(testCase)
            testCase.verifyError(@() ...
                exploreFNIRS.stats.permTest(testCase.mockGroups(1), {'Condition'}), ...
                'exploreFNIRS:stats:permTest:needTwoGroups');
        end

        function testConditionLabels(testCase)
            r = exploreFNIRS.stats.permTest(testCase.mockGroups, {'Condition'}, ...
                'Biomarkers', {'HbO'}, 'NumPerm', 50, 'Verbose', false);
            testCase.verifyEqual(r.conditions{1}, 'Condition1');
            testCase.verifyEqual(r.conditions{2}, 'Condition2');
        end

        %% --- Monte Carlo branch (item 9) ---

        function testMonteCarloMode(testCase)
            % Build large mock with 14 subjects to force Monte Carlo
            rng(42);
            nSub = 14;
            nCh = 2;
            nTime = 2;
            for g = 1:2
                grpL(g).label = sprintf('C%d', g);
                grpL(g).gbyFNIRS = {};
                subIDs = arrayfun(@(x) sprintf('S%02d', x), (1:nSub)', 'UniformOutput', false);
                grpL(g).gbyTables = table(subIDs, 'VariableNames', {'SubjectID'});
                bf = struct();
                bf.time = (1:nTime)';
                offset = (g - 1) * 1.0;
                for bio = {'HbO','HbR','HbTotal','CBSI'}
                    bf.(bio{1}).data = randn(nTime, nCh, nSub) + offset;
                    bf.(bio{1}).Mean = mean(bf.(bio{1}).data, 3);
                end
                grpL(g).gbyGrandBarFlat = bf;
                grpL(g).gbyGrand = bf;
            end

            % 2^14 = 16384 > 500, so Monte Carlo should be used
            r = exploreFNIRS.stats.permTest(grpL, {'Condition'}, ...
                'Biomarkers', {'HbO'}, 'NumPerm', 500, 'Verbose', false);

            testCase.verifyFalse(r.isExact);
            testCase.verifyEqual(r.nPerms, 500);
            % P-values should still be valid
            validP = r.pvalue(~isnan(r.pvalue));
            testCase.verifyTrue(all(validP > 0 & validP <= 1));
        end

        %% --- Tail left (item 13) ---

        function testTailLeft(testCase)
            r = exploreFNIRS.stats.permTest(testCase.mockGroups, {'Condition'}, ...
                'Tail', 'left', 'Biomarkers', {'HbO'}, ...
                'NumPerm', 50, 'Verbose', false);
            testCase.verifyEqual(r.tail, 'left');
        end

        %% --- Unpaired error (item 13) ---

        function testUnpairedErrors(testCase)
            testCase.verifyError(@() ...
                exploreFNIRS.stats.permTest(testCase.mockGroups, {'Condition'}, ...
                'Paired', false, 'Verbose', false), ...
                'exploreFNIRS:stats:permTest:unpairedNotSupported');
        end

        %% --- Too few subjects (item 13) ---

        function testTooFewSubjectsErrors(testCase)
            % Build mock with only 1 subject
            for g = 1:2
                grp1(g).label = sprintf('C%d', g);
                grp1(g).gbyFNIRS = {};
                grp1(g).gbyTables = table({'S01'}, 'VariableNames', {'SubjectID'});
                bf = struct();
                bf.time = 1;
                bf.HbO.data = randn(1, 2, 1);
                bf.HbO.Mean = bf.HbO.data;
                grp1(g).gbyGrandBarFlat = bf;
                grp1(g).gbyGrand = bf;
            end
            testCase.verifyError(@() ...
                exploreFNIRS.stats.permTest(grp1, {'Condition'}, ...
                'Biomarkers', {'HbO'}, 'Verbose', false), ...
                'exploreFNIRS:stats:permTest:tooFewSubjects');
        end

        %% --- NaN pair removal (item 13) ---

        function testNaNPairRemoval(testCase)
            % Insert NaN into one subject's data
            grpNaN = testCase.mockGroups;
            grpNaN(1).gbyGrandBarFlat.HbO.data(:, 1, 3) = NaN;

            r = exploreFNIRS.stats.permTest(grpNaN, {'Condition'}, ...
                'Biomarkers', {'HbO'}, 'Channels', 1, ...
                'NumPerm', 50, 'Verbose', false);

            % Should still compute (5 valid subjects remain)
            testCase.verifyFalse(isnan(r.pvalue(1, 1)));
        end

        %% --- Unequal group sizes warning (item 13) ---

        function testUnequalGroupSizesWarns(testCase)
            % Build groups with different subject counts
            grpUneq = testCase.mockGroups;
            % Add an extra subject to group 2
            grpUneq(2).gbyGrandBarFlat.HbO.data = ...
                cat(3, grpUneq(2).gbyGrandBarFlat.HbO.data, randn(2, 3, 1));
            grpUneq(2).gbyGrandBarFlat.HbR.data = ...
                cat(3, grpUneq(2).gbyGrandBarFlat.HbR.data, randn(2, 3, 1));
            grpUneq(2).gbyGrandBarFlat.HbTotal.data = ...
                cat(3, grpUneq(2).gbyGrandBarFlat.HbTotal.data, randn(2, 3, 1));
            grpUneq(2).gbyGrandBarFlat.CBSI.data = ...
                cat(3, grpUneq(2).gbyGrandBarFlat.CBSI.data, randn(2, 3, 1));

            testCase.verifyWarning(@() ...
                exploreFNIRS.stats.permTest(grpUneq, {'Condition'}, ...
                'Biomarkers', {'HbO'}, 'NumPerm', 50, 'Verbose', false), ...
                'exploreFNIRS:stats:permTest:unequalGroups');
        end

        %% --- Invalid statistic (item 8) ---

        function testInvalidStatisticErrors(testCase)
            testCase.verifyError(@() ...
                exploreFNIRS.stats.permTest(testCase.mockGroups, {'Condition'}, ...
                'Statistic', 'invalid_stat', 'Biomarkers', {'HbO'}, ...
                'NumPerm', 50, 'Verbose', false), ...
                'exploreFNIRS:stats:permTest:invalidStatistic');
        end

    end
end
