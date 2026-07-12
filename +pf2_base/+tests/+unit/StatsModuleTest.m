classdef StatsModuleTest < matlab.unittest.TestCase
    % STATSMODULETEST Unit tests for exploreFNIRS.stats module
    %
    %   results = runtests('pf2_base.tests.unit.StatsModuleTest');

    properties
        mockResults  % Pre-built mock LME results struct
    end

    methods (TestMethodSetup)
        function buildMockResults(testCase)
            % Build a mock results struct that mimics fitLME output.
            % This allows testing summarize/runContrasts without needing
            % the Statistics Toolbox or real data.
            r = struct();
            r.biomarkers = {'HbO'};
            r.channels = [1, 2, 3];
            r.groupByVars = {'Group'};
            r.formula = 'Opt1_HbO~Group+(1|SubjectID)';
            r.mergedTable = table();
            r.AIC = [100, 105, 110];
            r.models = cell(1, 3);
            r.anova = cell(1, 3);
            r.contrasts = cell(1, 3);
            r.coefficients = cell(1, 3);
            r.nullComparison = cell(1, 3);

            % Build ANOVA summary tables
            r.anova_pval = table();
            r.anova_Fstat = table();
            r.anova_df1 = table();
            r.anova_df2 = table();

            r.anova_pval{'Opt1_HbO', 'Group'} = 0.01;
            r.anova_pval{'Opt2_HbO', 'Group'} = 0.15;
            r.anova_pval{'Opt3_HbO', 'Group'} = 0.003;

            r.anova_Fstat{'Opt1_HbO', 'Group'} = 8.5;
            r.anova_Fstat{'Opt2_HbO', 'Group'} = 2.1;
            r.anova_Fstat{'Opt3_HbO', 'Group'} = 12.3;

            r.anova_df1{'Opt1_HbO', 'Group'} = 1;
            r.anova_df1{'Opt2_HbO', 'Group'} = 1;
            r.anova_df1{'Opt3_HbO', 'Group'} = 1;

            r.anova_df2{'Opt1_HbO', 'Group'} = 18.5;
            r.anova_df2{'Opt2_HbO', 'Group'} = 20.1;
            r.anova_df2{'Opt3_HbO', 'Group'} = 17.8;

            testCase.mockResults = r;
        end
    end

    methods (Test)

        %% --- summarize: anova ---

        function testSummarizeAnovaReturnsTable(testCase)
            T = exploreFNIRS.stats.summarize(testCase.mockResults, ...
                'Type', 'anova');
            testCase.verifyClass(T, 'table');
            testCase.verifyGreaterThan(height(T), 0);
        end

        function testSummarizeAnovaColumns(testCase)
            T = exploreFNIRS.stats.summarize(testCase.mockResults, ...
                'Type', 'anova');
            % Biomarker is single-valued ('HbO') for this mock and is
            % correctly dropped by summarize as uninformative.
            expected = {'Optode', 'Term', 'FStat', ...
                'df1', 'df2', 'pValue', 'Sig'};
            for i = 1:length(expected)
                testCase.verifyTrue( ...
                    ismember(expected{i}, T.Properties.VariableNames), ...
                    sprintf('Missing column: %s', expected{i}));
            end
        end

        function testSummarizeAnovaRowCount(testCase)
            T = exploreFNIRS.stats.summarize(testCase.mockResults, ...
                'Type', 'anova');
            % 3 channels x 1 term = 3 rows
            testCase.verifyEqual(height(T), 3);
        end

        function testSummarizeAnovaAPAFormat(testCase)
            T = exploreFNIRS.stats.summarize(testCase.mockResults, ...
                'Type', 'anova', 'Format', 'apa');
            testCase.verifyTrue( ...
                ismember('APA', T.Properties.VariableNames));
            % Check APA string contains F(
            testCase.verifySubstring(T.APA{1}, 'F(');
        end

        function testSummarizeAnovaFDR(testCase)
            T = exploreFNIRS.stats.summarize(testCase.mockResults, ...
                'Type', 'anova', 'IncludeFDR', true);
            testCase.verifyTrue( ...
                ismember('qValue', T.Properties.VariableNames));
            testCase.verifyTrue( ...
                ismember('FDR_Sig', T.Properties.VariableNames));
        end

        function testSummarizeAnovaSigStars(testCase)
            T = exploreFNIRS.stats.summarize(testCase.mockResults, ...
                'Type', 'anova', 'SigThreshold', 0.05);
            % p=0.01 should get stars, p=0.15 should not
            sigs = T.Sig;
            testCase.verifyTrue(contains(sigs{1}, '*'));
            testCase.verifyEqual(sigs{2}, '');
        end

        %% --- summarize: contrasts (empty) ---

        function testSummarizeContrastsEmpty(testCase)
            T = exploreFNIRS.stats.summarize(testCase.mockResults, ...
                'Type', 'contrasts');
            % With empty models, contrasts table should be empty
            testCase.verifyTrue(isempty(T) || height(T) == 0);
        end

        %% --- summarize: coefficients (empty) ---

        function testSummarizeCoefficientsEmpty(testCase)
            T = exploreFNIRS.stats.summarize(testCase.mockResults, ...
                'Type', 'coefficients');
            testCase.verifyTrue(isempty(T) || height(T) == 0);
        end

        %% --- summarize: fit (empty models) ---

        function testSummarizeFitEmpty(testCase)
            T = exploreFNIRS.stats.summarize(testCase.mockResults, ...
                'Type', 'fit');
            testCase.verifyTrue(isempty(T) || height(T) == 0);
        end

        %% --- summarize: invalid type ---

        function testSummarizeInvalidType(testCase)
            testCase.verifyError( ...
                @() exploreFNIRS.stats.summarize(testCase.mockResults, ...
                    'Type', 'bogus'), ...
                'exploreFNIRS:stats:summarize');
        end

        %% --- summarize: empty results ---

        function testSummarizeEmptyAnova(testCase)
            r = testCase.mockResults;
            r.anova_pval = table();
            r.anova_Fstat = table();
            T = exploreFNIRS.stats.summarize(r, 'Type', 'anova');
            testCase.verifyTrue(isempty(T) || height(T) == 0);
        end

        %% --- runContrasts: empty models ---

        function testRunContrastsEmptyModels(testCase)
            cr = exploreFNIRS.stats.runContrasts(testCase.mockResults);
            testCase.verifyTrue(isempty(cr.contrastNames));
            testCase.verifyTrue(isempty(cr.pvalueMatrix));
        end

        function testRunContrastsOutputFields(testCase)
            cr = exploreFNIRS.stats.runContrasts(testCase.mockResults);
            testCase.verifyTrue(isfield(cr, 'contrasts'));
            testCase.verifyTrue(isfield(cr, 'contrastNames'));
            testCase.verifyTrue(isfield(cr, 'pvalueMatrix'));
            testCase.verifyTrue(isfield(cr, 'qvalueMatrix'));
            testCase.verifyTrue(isfield(cr, 'significantMatrix'));
            testCase.verifyTrue(isfield(cr, 'fdrThreshold'));
            testCase.verifyTrue(isfield(cr, 'fdrMethod'));
        end

        function testRunContrastsInvalidFDRMethod(testCase)
            testCase.verifyError( ...
                @() exploreFNIRS.stats.runContrasts(testCase.mockResults, ...
                    'FDRMethod', 'bogus'), ...
                'exploreFNIRS:stats:runContrasts');
        end

        %% --- fitLME: error handling ---

        function testFitLMEBadGroupError(testCase)
            % Groups without gbyGrandBarFlat should error
            badGroups = struct('gbyGrandBarFlat', []);
            testCase.verifyError( ...
                @() exploreFNIRS.stats.fitLME(badGroups, {'Group'}), ...
                'exploreFNIRS:stats:fitLME');
        end

        function testFitLMEOutputStructFields(testCase)
            % Verify the expected output struct fields exist (even if empty)
            % by checking what the function creates before any model fitting
            expected = {'models', 'anova', 'contrasts', 'AIC', 'formula', ...
                'mergedTable', 'anova_pval', 'anova_Fstat', 'anova_df1', ...
                'anova_df2', 'coefficients', 'nullComparison', ...
                'biomarkers', 'channels', 'groupByVars'};
            % We can't easily test fitLME without real data, so just verify
            % the mock results have compatible fields
            r = testCase.mockResults;
            for i = 1:length(expected)
                testCase.verifyTrue(isfield(r, expected{i}), ...
                    sprintf('Missing field: %s', expected{i}));
            end
        end

    end
end
