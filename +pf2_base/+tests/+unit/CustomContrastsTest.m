classdef CustomContrastsTest < matlab.unittest.TestCase
    % CUSTOMCONTRASTSTEST Unit tests for custom contrast matrices
    %
    %   results = runtests('pf2_base.tests.unit.CustomContrastsTest');

    properties
        mockResults  % Mock LME results with real models
        testData     % Processed fNIRS data
    end

    methods (TestClassSetup)
        function buildTestData(testCase)
            % Build a simple test dataset with an LME model
            rng(42);
            nSub = 8;
            nTimePoints = 5;

            % Create synthetic data table
            SubjectID = repelem((1:nSub)', nTimePoints * 2);
            Condition = repmat(repelem({'A';'B'}, nTimePoints), nSub, 1);
            Time = repmat((1:nTimePoints)', nSub * 2, 1);
            HbO = randn(nSub * nTimePoints * 2, 1);
            % Add condition effect
            HbO(strcmp(Condition, 'B')) = HbO(strcmp(Condition, 'B')) + 0.5;

            T = table(SubjectID, categorical(Condition), categorical(Time), HbO, ...
                'VariableNames', {'SubjectID','Condition','Time','HbO'});

            mdl = fitlme(T, 'HbO ~ Condition + (1|SubjectID)', ...
                'DummyVarCoding', 'reference');

            r = struct();
            r.biomarkers = {'HbO'};
            r.channels = 1;
            r.groupByVars = {'Condition'};
            r.formula = 'HbO~Condition+(1|SubjectID)';
            r.mergedTable = T;
            r.AIC = mdl.ModelCriterion.AIC;
            r.models = {mdl};
            r.anova = cell(1, 1);
            r.contrasts = cell(1, 1);
            r.coefficients = cell(1, 1);
            r.nullComparison = cell(1, 1);
            r.anova_pval = table();
            r.anova_Fstat = table();
            r.anova_df1 = table();
            r.anova_df2 = table();

            testCase.mockResults = r;
        end
    end

    methods (Test)

        %% --- runContrasts with Contrasts='auto' (backward compat) ---

        function testAutoContrastsStillWork(testCase)
            cr = exploreFNIRS.stats.runContrasts(testCase.mockResults);
            testCase.verifyClass(cr, 'struct');
            testCase.verifyTrue(isfield(cr, 'contrastNames'));
            testCase.verifyTrue(isfield(cr, 'pvalueMatrix'));
        end

        function testAutoContrastsDefaultIsAuto(testCase)
            cr = exploreFNIRS.stats.runContrasts(testCase.mockResults, ...
                'Contrasts', 'auto');
            testCase.verifyClass(cr, 'struct');
        end

        %% --- runContrasts with custom Contrasts ---

        function testCustomContrastBasic(testCase)
            spec.matrix = [0, 1];  % test Condition_B effect
            spec.labels = {'B vs Reference'};

            cr = exploreFNIRS.stats.runContrasts(testCase.mockResults, ...
                'Contrasts', spec);

            testCase.verifyEqual(length(cr.contrastNames), 1);
            testCase.verifyEqual(cr.contrastNames{1}, 'B vs Reference');
            testCase.verifyFalse(isnan(cr.pvalueMatrix(1, 1, 1)));
        end

        function testCustomContrastMultipleRows(testCase)
            spec.matrix = [0, 1; 1, 0];
            spec.labels = {'Effect B', 'Intercept Only'};

            cr = exploreFNIRS.stats.runContrasts(testCase.mockResults, ...
                'Contrasts', spec);

            testCase.verifyEqual(length(cr.contrastNames), 2);
            testCase.verifySize(cr.pvalueMatrix, [2, 1, 1]);
        end

        function testCustomContrastHasStandardFields(testCase)
            spec.matrix = [0, 1];
            spec.labels = {'TestContrast'};

            cr = exploreFNIRS.stats.runContrasts(testCase.mockResults, ...
                'Contrasts', spec);

            testCase.verifyTrue(isfield(cr, 'pvalueMatrix'));
            testCase.verifyTrue(isfield(cr, 'qvalueMatrix'));
            testCase.verifyTrue(isfield(cr, 'significantMatrix'));
            testCase.verifyTrue(isfield(cr, 'effectSizeMatrix'));
            testCase.verifyTrue(isfield(cr, 'fdrThreshold'));
            testCase.verifyTrue(isfield(cr, 'fdrMethod'));
            testCase.verifyTrue(isfield(cr, 'biomarkers'));
            testCase.verifyTrue(isfield(cr, 'channels'));
        end

        function testCustomContrastPValuesAreValid(testCase)
            spec.matrix = [0, 1];
            spec.labels = {'Effect'};

            cr = exploreFNIRS.stats.runContrasts(testCase.mockResults, ...
                'Contrasts', spec);

            pVal = cr.pvalueMatrix(1, 1, 1);
            testCase.verifyGreaterThanOrEqual(pVal, 0);
            testCase.verifyLessThanOrEqual(pVal, 1);
        end

        function testCustomContrastEffectSizeSign(testCase)
            % B was given +0.5 offset, so effect should be positive
            spec.matrix = [0, 1];
            spec.labels = {'B Effect'};

            cr = exploreFNIRS.stats.runContrasts(testCase.mockResults, ...
                'Contrasts', spec);

            testCase.verifyGreaterThan(cr.effectSizeMatrix(1, 1, 1), 0);
        end

        %% --- Validation errors ---

        function testCustomContrastMissingMatrix(testCase)
            spec.labels = {'Bad'};
            testCase.verifyError(@() ...
                exploreFNIRS.stats.runContrasts(testCase.mockResults, ...
                'Contrasts', spec), ...
                'exploreFNIRS:stats:runContrasts:invalidSpec');
        end

        function testCustomContrastMissingLabels(testCase)
            spec.matrix = [0, 1];
            testCase.verifyError(@() ...
                exploreFNIRS.stats.runContrasts(testCase.mockResults, ...
                'Contrasts', spec), ...
                'exploreFNIRS:stats:runContrasts:invalidSpec');
        end

        function testCustomContrastSizeMismatch(testCase)
            spec.matrix = [0, 1; 1, 0];
            spec.labels = {'Only One Label'};
            testCase.verifyError(@() ...
                exploreFNIRS.stats.runContrasts(testCase.mockResults, ...
                'Contrasts', spec), ...
                'exploreFNIRS:stats:runContrasts:sizeMismatch');
        end

        function testCustomContrastWrongCoefCount(testCase)
            spec.matrix = [0, 1, 0, 0];  % 4 cols but model has 2
            spec.labels = {'Bad Dimensions'};
            testCase.verifyError(@() ...
                exploreFNIRS.stats.runContrasts(testCase.mockResults, ...
                'Contrasts', spec), ...
                'exploreFNIRS:stats:runContrasts:coefMismatch');
        end

        %% --- buildContrasts ---

        function testBuildContrastsPairwise(testCase)
            mdl = testCase.mockResults.models{1};
            spec = exploreFNIRS.stats.buildContrasts(mdl, 'pairwise');

            testCase.verifyTrue(isfield(spec, 'matrix'));
            testCase.verifyTrue(isfield(spec, 'labels'));
            testCase.verifyGreaterThan(size(spec.matrix, 1), 0);
            testCase.verifyEqual(size(spec.matrix, 2), length(mdl.CoefficientNames));
        end

        function testBuildContrastsPolynomial(testCase)
            mdl = testCase.mockResults.models{1};
            spec = exploreFNIRS.stats.buildContrasts(mdl, 'polynomial');

            testCase.verifyTrue(isfield(spec, 'matrix'));
            testCase.verifyGreaterThan(size(spec.matrix, 1), 0);
        end

        function testBuildContrastsLinear(testCase)
            mdl = testCase.mockResults.models{1};
            spec = exploreFNIRS.stats.buildContrasts(mdl, 'linear');

            testCase.verifyTrue(any(contains(spec.labels, 'Linear')));
        end

        function testBuildContrastsHelmert(testCase)
            mdl = testCase.mockResults.models{1};
            spec = exploreFNIRS.stats.buildContrasts(mdl, 'helmert');

            testCase.verifyGreaterThan(length(spec.labels), 0);
        end

        function testBuildContrastsDeviation(testCase)
            mdl = testCase.mockResults.models{1};
            spec = exploreFNIRS.stats.buildContrasts(mdl, 'deviation');

            testCase.verifyTrue(any(contains(spec.labels, 'Mean')));
        end

        function testBuildContrastsInvalidType(testCase)
            mdl = testCase.mockResults.models{1};
            testCase.verifyError(@() ...
                exploreFNIRS.stats.buildContrasts(mdl, 'invalid'), ...
                'exploreFNIRS:stats:buildContrasts:unknownType');
        end

        function testBuildContrastsIntegration(testCase)
            % Build contrasts, then run them
            mdl = testCase.mockResults.models{1};
            spec = exploreFNIRS.stats.buildContrasts(mdl, 'pairwise');

            cr = exploreFNIRS.stats.runContrasts(testCase.mockResults, ...
                'Contrasts', spec);

            testCase.verifyEqual(length(cr.contrastNames), length(spec.labels));
        end

        %% --- Multi-channel FDR (item 10) ---

        function testMultiChannelFDRCorrection(testCase)
            % Build results with 5 channels to exercise FDR across channels
            rng(42);
            nSub = 8;
            nPts = 5;
            nCh = 5;

            SubjectID = repelem((1:nSub)', nPts * 2);
            Condition = repmat(repelem({'A';'B'}, nPts), nSub, 1);

            multiResults = testCase.mockResults;
            multiResults.channels = 1:nCh;
            multiResults.models = cell(1, nCh);

            for ch = 1:nCh
                HbO = randn(nSub * nPts * 2, 1);
                % Only channel 1 gets a strong effect
                if ch == 1
                    HbO(strcmp(Condition, 'B')) = HbO(strcmp(Condition, 'B')) + 2.0;
                end
                T = table(SubjectID, categorical(Condition), HbO, ...
                    'VariableNames', {'SubjectID','Condition','HbO'});
                multiResults.models{1, ch} = fitlme(T, 'HbO ~ Condition + (1|SubjectID)', ...
                    'DummyVarCoding', 'reference');
            end

            spec.matrix = [0, 1];
            spec.labels = {'B Effect'};

            cr = exploreFNIRS.stats.runContrasts(multiResults, 'Contrasts', spec);

            % qvalueMatrix should be [1 x 1 x 5], squeeze gives [5 x 1]
            testCase.verifyEqual(numel(squeeze(cr.qvalueMatrix)), nCh);

            % FDR q-values should be >= p-values
            pVals = squeeze(cr.pvalueMatrix(1, 1, :))';
            qVals = squeeze(cr.qvalueMatrix(1, 1, :))';
            valid = ~isnan(pVals) & ~isnan(qVals);
            testCase.verifyGreaterThanOrEqual(qVals(valid), pVals(valid) - 1e-10);
        end

        %% --- 3-level factor tests ---

        function testThreeLevelPolynomial(testCase)
            % Build a 3-level model to test quadratic contrasts
            rng(42);
            nSub = 6;
            nPts = 3;
            SubjectID = repelem((1:nSub)', nPts * 3);
            Condition = repmat(repelem({'Low';'Med';'High'}, nPts), nSub, 1);
            Time = repmat((1:nPts)', nSub * 3, 1);
            HbO = randn(nSub * nPts * 3, 1);
            HbO(strcmp(Condition, 'Med')) = HbO(strcmp(Condition, 'Med')) + 0.3;
            HbO(strcmp(Condition, 'High')) = HbO(strcmp(Condition, 'High')) + 0.6;

            T = table(SubjectID, categorical(Condition), categorical(Time), HbO, ...
                'VariableNames', {'SubjectID','Condition','Time','HbO'});
            mdl3 = fitlme(T, 'HbO ~ Condition + (1|SubjectID)', ...
                'DummyVarCoding', 'reference');

            spec = exploreFNIRS.stats.buildContrasts(mdl3, 'polynomial');

            testCase.verifyEqual(length(spec.labels), 2);
            testCase.verifyTrue(any(contains(spec.labels, 'Linear')));
            testCase.verifyTrue(any(contains(spec.labels, 'Quadratic')));
        end

    end
end
