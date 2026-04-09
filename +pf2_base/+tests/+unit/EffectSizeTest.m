classdef EffectSizeTest < matlab.unittest.TestCase
    % EFFECTSIZETEST Unit tests for exploreFNIRS.stats.effectSize
    %
    %   results = runtests('pf2_base.tests.unit.EffectSizeTest');

    properties
        mockGroups   % Mock 2-group aggregated struct
    end

    methods (TestClassSetup)
        function buildMockGroups(testCase)
            % Build minimal groups struct with gbyGrandBarFlat and gbyTables
            rng(42);
            nSub = 6;
            nCh = 3;
            nTime = 2;

            for g = 1:2
                grp(g).label = sprintf('Condition%d', g);
                grp(g).gbyFNIRS = {};

                % Build gbyTables with SubjectID
                subIDs = arrayfun(@(x) sprintf('S%02d', x), (1:nSub)', 'UniformOutput', false);
                grp(g).gbyTables = table(subIDs, 'VariableNames', {'SubjectID'});

                % Build gbyGrandBarFlat
                bf = struct();
                bf.time = (1:nTime)';

                % Add biomarker data [time x channels x subjects]
                offset = (g - 1) * 0.5;  % group 2 is 0.5 higher
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
            es = exploreFNIRS.stats.effectSize(testCase.mockGroups, {'Condition'}, ...
                'Biomarkers', {'HbO'}, 'NumBoot', 100, 'Verbose', false);
            testCase.verifyClass(es, 'struct');
        end

        function testHasRequiredFields(testCase)
            es = exploreFNIRS.stats.effectSize(testCase.mockGroups, {'Condition'}, ...
                'Biomarkers', {'HbO'}, 'NumBoot', 100, 'Verbose', false);

            expectedFields = {'observed', 'ci_lower', 'ci_upper', ...
                'bootstrap_dist', 'method', 'ci_level', 'nBoot', ...
                'biomarkers', 'channels', 'conditions', 'nPerGroup'};
            for i = 1:length(expectedFields)
                testCase.verifyTrue(isfield(es, expectedFields{i}), ...
                    sprintf('Missing field: %s', expectedFields{i}));
            end
        end

        function testObservedSize(testCase)
            es = exploreFNIRS.stats.effectSize(testCase.mockGroups, {'Condition'}, ...
                'Biomarkers', {'HbO','HbR'}, 'Channels', [1,2], ...
                'NumBoot', 100, 'Verbose', false);
            testCase.verifySize(es.observed, [2, 2]);
        end

        function testCIBoundsObserved(testCase)
            es = exploreFNIRS.stats.effectSize(testCase.mockGroups, {'Condition'}, ...
                'Biomarkers', {'HbO'}, 'Channels', 1, ...
                'NumBoot', 500, 'Verbose', false);

            % CI should generally contain the observed value (not always, but usually)
            % At minimum, ci_lower < ci_upper
            testCase.verifyLessThan(es.ci_lower(1,1), es.ci_upper(1,1));
        end

        %% --- Methods ---

        function testHedgesG(testCase)
            es = exploreFNIRS.stats.effectSize(testCase.mockGroups, {'Condition'}, ...
                'Method', 'hedges_g', 'Biomarkers', {'HbO'}, ...
                'Channels', 1, 'NumBoot', 50, 'Verbose', false);
            testCase.verifyEqual(es.method, 'hedges_g');
            testCase.verifyFalse(isnan(es.observed(1,1)));
        end

        function testCohensD(testCase)
            es = exploreFNIRS.stats.effectSize(testCase.mockGroups, {'Condition'}, ...
                'Method', 'cohens_d', 'Biomarkers', {'HbO'}, ...
                'Channels', 1, 'NumBoot', 50, 'Verbose', false);
            testCase.verifyEqual(es.method, 'cohens_d');
        end

        function testGlassDelta(testCase)
            es = exploreFNIRS.stats.effectSize(testCase.mockGroups, {'Condition'}, ...
                'Method', 'glass_delta', 'Biomarkers', {'HbO'}, ...
                'Channels', 1, 'NumBoot', 50, 'Verbose', false);
            testCase.verifyEqual(es.method, 'glass_delta');
        end

        function testInvalidMethod(testCase)
            testCase.verifyError(@() ...
                exploreFNIRS.stats.effectSize(testCase.mockGroups, {'Condition'}, ...
                'Method', 'invalid'), ...
                'exploreFNIRS:stats:effectSize:invalidMethod');
        end

        %% --- Reproducibility ---

        function testSeedReproducibility(testCase)
            es1 = exploreFNIRS.stats.effectSize(testCase.mockGroups, {'Condition'}, ...
                'Biomarkers', {'HbO'}, 'Channels', 1, ...
                'NumBoot', 100, 'Seed', 123, 'Verbose', false);
            es2 = exploreFNIRS.stats.effectSize(testCase.mockGroups, {'Condition'}, ...
                'Biomarkers', {'HbO'}, 'Channels', 1, ...
                'NumBoot', 100, 'Seed', 123, 'Verbose', false);

            testCase.verifyEqual(es1.ci_lower, es2.ci_lower, 'AbsTol', 1e-10);
            testCase.verifyEqual(es1.ci_upper, es2.ci_upper, 'AbsTol', 1e-10);
        end

        %% --- Validation ---

        function testRequiresTwoGroups(testCase)
            testCase.verifyError(@() ...
                exploreFNIRS.stats.effectSize(testCase.mockGroups(1), {'Condition'}), ...
                'exploreFNIRS:stats:effectSize:needTwoGroups');
        end

        function testConditionLabels(testCase)
            es = exploreFNIRS.stats.effectSize(testCase.mockGroups, {'Condition'}, ...
                'Biomarkers', {'HbO'}, 'NumBoot', 50, 'Verbose', false);
            testCase.verifyEqual(es.conditions{1}, 'Condition1');
            testCase.verifyEqual(es.conditions{2}, 'Condition2');
        end

        %% --- CI level ---

        function testCI90(testCase)
            es = exploreFNIRS.stats.effectSize(testCase.mockGroups, {'Condition'}, ...
                'CI', 0.90, 'Biomarkers', {'HbO'}, 'Channels', 1, ...
                'NumBoot', 200, 'Verbose', false);
            testCase.verifyEqual(es.ci_level, 0.90);
        end

        %% --- Computational correctness (item 11) ---

        function testCohensD_KnownValues(testCase)
            % Build deterministic groups where we can compute d by hand
            % Group A: all zeros, Group B: all ones → d = 1/0 undefined
            % Use: A = [1,2,3,4], B = [3,4,5,6] → diff=2.0, pooled SD=1.29
            for g = 1:2
                grpK(g).label = sprintf('C%d', g);
                grpK(g).gbyFNIRS = {};
                grpK(g).gbyTables = table({}, 'VariableNames', {'SubjectID'});
                bf = struct();
                bf.time = 1;
                if g == 1
                    bf.HbO.data = reshape([1 2 3 4], 1, 1, 4);
                else
                    bf.HbO.data = reshape([3 4 5 6], 1, 1, 4);
                end
                bf.HbO.Mean = mean(bf.HbO.data, 3);
                grpK(g).gbyGrandBarFlat = bf;
                grpK(g).gbyGrand = bf;
            end

            es = exploreFNIRS.stats.effectSize(grpK, {'Condition'}, ...
                'Method', 'cohens_d', 'Biomarkers', {'HbO'}, ...
                'Channels', 1, 'NumBoot', 50, 'Verbose', false);

            % A=[1,2,3,4], B=[3,4,5,6]
            % mean(A)=2.5, mean(B)=4.5, diff=-2
            % var(A)=var(B)=5/3, sp=sqrt(5/3)=1.2910
            % d = -2 / 1.2910 = -1.549
            expectedD = (2.5 - 4.5) / sqrt(5/3);
            testCase.verifyEqual(es.observed(1,1), expectedD, 'AbsTol', 1e-6);
        end

        function testHedgesG_CorrectionFactor(testCase)
            % Verify Hedges' g applies J correction to Cohen's d
            for g = 1:2
                grpK(g).label = sprintf('C%d', g);
                grpK(g).gbyFNIRS = {};
                grpK(g).gbyTables = table({}, 'VariableNames', {'SubjectID'});
                bf = struct();
                bf.time = 1;
                if g == 1
                    bf.HbO.data = reshape([1 2 3 4], 1, 1, 4);
                else
                    bf.HbO.data = reshape([3 4 5 6], 1, 1, 4);
                end
                bf.HbO.Mean = mean(bf.HbO.data, 3);
                grpK(g).gbyGrandBarFlat = bf;
                grpK(g).gbyGrand = bf;
            end

            esD = exploreFNIRS.stats.effectSize(grpK, {'Condition'}, ...
                'Method', 'cohens_d', 'Biomarkers', {'HbO'}, ...
                'Channels', 1, 'NumBoot', 50, 'Verbose', false);
            esG = exploreFNIRS.stats.effectSize(grpK, {'Condition'}, ...
                'Method', 'hedges_g', 'Biomarkers', {'HbO'}, ...
                'Channels', 1, 'NumBoot', 50, 'Verbose', false);

            % J = 1 - 3/(4*df - 1), df = nA + nB - 2 = 6
            J = 1 - 3 / (4 * 6 - 1);
            testCase.verifyEqual(esG.observed(1,1), esD.observed(1,1) * J, 'AbsTol', 1e-10);
        end

        function testGlassDelta_UsesControlSD(testCase)
            % Glass's delta uses SD of group B (control)
            for g = 1:2
                grpK(g).label = sprintf('C%d', g);
                grpK(g).gbyFNIRS = {};
                grpK(g).gbyTables = table({}, 'VariableNames', {'SubjectID'});
                bf = struct();
                bf.time = 1;
                if g == 1
                    bf.HbO.data = reshape([1 2 3 4], 1, 1, 4);
                else
                    bf.HbO.data = reshape([3 4 5 6], 1, 1, 4);
                end
                bf.HbO.Mean = mean(bf.HbO.data, 3);
                grpK(g).gbyGrandBarFlat = bf;
                grpK(g).gbyGrand = bf;
            end

            es = exploreFNIRS.stats.effectSize(grpK, {'Condition'}, ...
                'Method', 'glass_delta', 'Biomarkers', {'HbO'}, ...
                'Channels', 1, 'NumBoot', 50, 'Verbose', false);

            % diff = 2.5 - 4.5 = -2, std(B) = std([3,4,5,6]) = sqrt(5/3)
            expectedDelta = (2.5 - 4.5) / std([3 4 5 6]);
            testCase.verifyEqual(es.observed(1,1), expectedDelta, 'AbsTol', 1e-6);
        end

    end
end
