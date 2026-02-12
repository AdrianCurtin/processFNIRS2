classdef GLMConnectivityTest < matlab.unittest.TestCase
    % GLMCONNECTIVITYTEST Unit tests for GLM-based connectivity methods
    %
    % Tests cover:
    %   - Beta-series correlation (LSA and LSS)
    %   - Psychophysiological interaction (PPI)
    %   - GLMExperiment integration for both methods
    %   - Plot compatibility with existing visualization functions
    %
    % Run all tests:
    %   results = runtests('pf2_base.tests.unit.GLMConnectivityTest');
    %
    % See also: exploreFNIRS.connectivity.computeBetaSeries,
    %   exploreFNIRS.connectivity.computePPI

    properties
        data        % Processed fNIRS struct (continuous)
        blocks      % Block struct array from defineBlocks
        nCh         % Number of good channels
    end

    methods (TestClassSetup)
        function loadSampleData(testCase)
            raw = pf2.import.sampleData.fNIR2000();
            d = processFNIRS2(raw);

            % Add markers for 6 blocks: 3 Easy (10), 3 Hard (20)
            rng(42);
            onsets = [60, 150, 250, 350, 450, 550];
            codes  = [10, 20, 10, 20, 10, 20];
            dur    = 30;
            d.markers = [onsets(:), codes(:), repmat(dur, 6, 1)];

            testCase.data = d;

            condMap = {10, 'Easy'; 20, 'Hard'};
            testCase.blocks = pf2.data.defineBlocks(d, [10, 20], dur, ...
                'ConditionMap', condMap, 'Embed', false);

            testCase.nCh = sum(d.fchMask);
        end
    end


    %% Beta-Series Correlation — LSA
    methods (Test)

        function testBetaSeriesLSABasicFields(testCase)
            result = exploreFNIRS.connectivity.computeBetaSeries( ...
                testCase.data, testCase.blocks);

            testCase.verifyTrue(isstruct(result));
            testCase.verifyTrue(isfield(result, 'matrix'));
            testCase.verifyTrue(isfield(result, 'pmatrix'));
            testCase.verifyTrue(isfield(result, 'channels'));
            testCase.verifyTrue(isfield(result, 'labels'));
            testCase.verifyTrue(isfield(result, 'method'));
            testCase.verifyTrue(isfield(result, 'biomarker'));
            testCase.verifyTrue(isfield(result, 'betas'));
            testCase.verifyTrue(isfield(result, 'nTrials'));
            testCase.verifyTrue(isfield(result, 'trialLabels'));
        end

        function testBetaSeriesLSAMatrixShape(testCase)
            result = exploreFNIRS.connectivity.computeBetaSeries( ...
                testCase.data, testCase.blocks);

            nCh = length(result.channels);
            testCase.verifyEqual(size(result.matrix), [nCh, nCh]);
            testCase.verifyEqual(size(result.pmatrix), [nCh, nCh]);
        end

        function testBetaSeriesLSASymmetry(testCase)
            result = exploreFNIRS.connectivity.computeBetaSeries( ...
                testCase.data, testCase.blocks);

            testCase.verifyEqual(result.matrix, result.matrix', 'AbsTol', 1e-10);
        end

        function testBetaSeriesLSADiagonal(testCase)
            result = exploreFNIRS.connectivity.computeBetaSeries( ...
                testCase.data, testCase.blocks);

            nCh = length(result.channels);
            testCase.verifyEqual(diag(result.matrix), ones(nCh, 1), 'AbsTol', 1e-10);
        end

        function testBetaSeriesLSAPmatrixRange(testCase)
            result = exploreFNIRS.connectivity.computeBetaSeries( ...
                testCase.data, testCase.blocks);

            offDiag = result.pmatrix(~eye(size(result.pmatrix), 'logical'));
            validP = offDiag(~isnan(offDiag));
            testCase.verifyGreaterThanOrEqual(min(validP), 0);
            testCase.verifyLessThanOrEqual(max(validP), 1);
        end

        function testBetaSeriesLSAMethodString(testCase)
            result = exploreFNIRS.connectivity.computeBetaSeries( ...
                testCase.data, testCase.blocks, 'Method', 'LSA');

            testCase.verifyEqual(result.method, 'betaseries_LSA');
        end

        function testBetaSeriesLSABetaSize(testCase)
            result = exploreFNIRS.connectivity.computeBetaSeries( ...
                testCase.data, testCase.blocks);

            testCase.verifyEqual(result.nTrials, length(testCase.blocks));
            testCase.verifyEqual(size(result.betas, 1), result.nTrials);
            testCase.verifyEqual(size(result.betas, 2), length(result.channels));
        end

        function testBetaSeriesLSATrialLabels(testCase)
            result = exploreFNIRS.connectivity.computeBetaSeries( ...
                testCase.data, testCase.blocks);

            testCase.verifyLength(result.trialLabels, result.nTrials);
        end

    end


    %% Beta-Series Correlation — LSS
    methods (Test)

        function testBetaSeriesLSSBasic(testCase)
            result = exploreFNIRS.connectivity.computeBetaSeries( ...
                testCase.data, testCase.blocks, 'Method', 'LSS');

            testCase.verifyEqual(result.method, 'betaseries_LSS');
            nCh = length(result.channels);
            testCase.verifyEqual(size(result.matrix), [nCh, nCh]);
        end

        function testBetaSeriesLSSVsLSASameSize(testCase)
            rLSA = exploreFNIRS.connectivity.computeBetaSeries( ...
                testCase.data, testCase.blocks, 'Method', 'LSA');
            rLSS = exploreFNIRS.connectivity.computeBetaSeries( ...
                testCase.data, testCase.blocks, 'Method', 'LSS');

            testCase.verifyEqual(size(rLSA.matrix), size(rLSS.matrix));
            testCase.verifyEqual(rLSA.nTrials, rLSS.nTrials);
            testCase.verifyEqual(size(rLSA.betas), size(rLSS.betas));
        end

    end


    %% Beta-Series — Options
    methods (Test)

        function testBetaSeriesConditionFilter(testCase)
            rAll = exploreFNIRS.connectivity.computeBetaSeries( ...
                testCase.data, testCase.blocks);
            rEasy = exploreFNIRS.connectivity.computeBetaSeries( ...
                testCase.data, testCase.blocks, 'Condition', 'Easy');

            testCase.verifyLessThan(rEasy.nTrials, rAll.nTrials);
            testCase.verifyTrue(all(strcmp(rEasy.trialLabels, 'Easy')));
        end

        function testBetaSeriesChannelSubset(testCase)
            chSub = 1:4;
            result = exploreFNIRS.connectivity.computeBetaSeries( ...
                testCase.data, testCase.blocks, 'Channels', chSub);

            testCase.verifyEqual(length(result.channels), length(chSub));
            testCase.verifyEqual(size(result.matrix, 1), length(chSub));
        end

        function testBetaSeriesSpearman(testCase)
            result = exploreFNIRS.connectivity.computeBetaSeries( ...
                testCase.data, testCase.blocks, 'Correlation', 'spearman');

            nCh = length(result.channels);
            testCase.verifyEqual(size(result.matrix), [nCh, nCh]);
            % Diagonal should still be 1
            testCase.verifyEqual(diag(result.matrix), ones(nCh, 1), 'AbsTol', 1e-10);
        end

        function testBetaSeriesBiomarker(testCase)
            result = exploreFNIRS.connectivity.computeBetaSeries( ...
                testCase.data, testCase.blocks, 'Biomarker', 'HbR');

            testCase.verifyEqual(result.biomarker, 'HbR');
        end

        function testBetaSeriesTooFewTrials(testCase)
            % Single block should error
            singleBlock = testCase.blocks(1);
            testCase.verifyError( ...
                @() exploreFNIRS.connectivity.computeBetaSeries( ...
                    testCase.data, singleBlock), ...
                'exploreFNIRS:connectivity:computeBetaSeries');
        end

    end


    %% PPI — Basic
    methods (Test)

        function testPPIBasicFields(testCase)
            result = exploreFNIRS.connectivity.computePPI( ...
                testCase.data, testCase.blocks, 1);

            testCase.verifyTrue(isfield(result, 'ppi_beta'));
            testCase.verifyTrue(isfield(result, 'ppi_tstat'));
            testCase.verifyTrue(isfield(result, 'ppi_pval'));
            testCase.verifyTrue(isfield(result, 'matrix'));
            testCase.verifyTrue(isfield(result, 'pmatrix'));
            testCase.verifyTrue(isfield(result, 'channels'));
            testCase.verifyTrue(isfield(result, 'seedChannels'));
            testCase.verifyTrue(isfield(result, 'fullResults'));
            testCase.verifyTrue(isfield(result, 'designMatrix'));
            testCase.verifyTrue(isfield(result, 'regressorNames'));
            testCase.verifyEqual(result.method, 'PPI');
        end

        function testPPIBetaShape(testCase)
            result = exploreFNIRS.connectivity.computePPI( ...
                testCase.data, testCase.blocks, 1);

            nTargets = length(result.channels);
            testCase.verifyEqual(size(result.ppi_beta), [1, nTargets]);
            testCase.verifyEqual(size(result.ppi_tstat), [1, nTargets]);
            testCase.verifyEqual(size(result.ppi_pval), [1, nTargets]);
        end

        function testPPIContrastPair(testCase)
            result = exploreFNIRS.connectivity.computePPI( ...
                testCase.data, testCase.blocks, 1, ...
                'Contrast', {'Hard', 'Easy'});

            testCase.verifyEqual(result.contrast, {'Hard', 'Easy'});
        end

        function testPPISingleCondition(testCase)
            result = exploreFNIRS.connectivity.computePPI( ...
                testCase.data, testCase.blocks, 1, ...
                'Contrast', 'Hard');

            testCase.verifyEqual(result.contrast, {'Hard'});
        end

        function testPPISeedAveraging(testCase)
            % Multi-channel seed should work
            result = exploreFNIRS.connectivity.computePPI( ...
                testCase.data, testCase.blocks, [1, 2, 3]);

            testCase.verifyEqual(result.seedChannels, [1, 2, 3]);
            testCase.verifyTrue(~isempty(result.ppi_beta));
        end

        function testPPIChannelSubset(testCase)
            chSub = 1:4;
            result = exploreFNIRS.connectivity.computePPI( ...
                testCase.data, testCase.blocks, 1, ...
                'Channels', chSub);

            testCase.verifyEqual(length(result.channels), length(chSub));
            testCase.verifyEqual(size(result.ppi_beta, 2), length(chSub));
        end

        function testPPIDesignMatrixContainsPPIRegressor(testCase)
            result = exploreFNIRS.connectivity.computePPI( ...
                testCase.data, testCase.blocks, 1);

            testCase.verifyTrue(ismember('PPI', result.regressorNames));
            testCase.verifyTrue(ismember('seed', result.regressorNames));
            testCase.verifyTrue(ismember('psych', result.regressorNames));
        end

        function testPPIFullResultsValid(testCase)
            result = exploreFNIRS.connectivity.computePPI( ...
                testCase.data, testCase.blocks, 1);

            fr = result.fullResults;
            testCase.verifyTrue(isfield(fr, 'beta'));
            testCase.verifyTrue(isfield(fr, 'tstat'));
            testCase.verifyTrue(isfield(fr, 'R2'));
        end

        function testPPIDeconvolve(testCase)
            result = exploreFNIRS.connectivity.computePPI( ...
                testCase.data, testCase.blocks, 1, ...
                'Deconvolve', true);

            testCase.verifyTrue(~isempty(result.ppi_beta));
        end

    end


    %% Integration — GLMExperiment
    methods (Test)

        function testGLMExperimentBetaSeries(testCase)
            [subjects, blockDefs] = buildTestSubjects(testCase);

            gx = exploreFNIRS.core.GLMExperiment(subjects, blockDefs);
            result = gx.betaSeriesConnectivity();

            testCase.verifyTrue(isfield(result, 'Mean'));
            testCase.verifyTrue(isfield(result, 'SD'));
            testCase.verifyTrue(isfield(result, 'SEM'));
            testCase.verifyTrue(isfield(result, 'N'));
            testCase.verifyTrue(isfield(result, 'matrices'));
            testCase.verifyEqual(result.N, length(subjects));

            nCh = length(result.channels);
            testCase.verifyEqual(size(result.Mean), [nCh, nCh]);
        end

        function testGLMExperimentPPI(testCase)
            [subjects, blockDefs] = buildTestSubjects(testCase);

            gx = exploreFNIRS.core.GLMExperiment(subjects, blockDefs);
            result = gx.ppi(1, 'Contrast', {'Easy', 'Hard'});

            testCase.verifyTrue(isfield(result, 'Mean_beta'));
            testCase.verifyTrue(isfield(result, 'ppi_betas'));
            testCase.verifyTrue(isfield(result, 'matrix'));
            testCase.verifyTrue(isfield(result, 'pmatrix'));
            testCase.verifyEqual(result.N, length(subjects));

            nTargets = length(result.channels);
            testCase.verifyEqual(size(result.Mean_beta), [1, nTargets]);
            testCase.verifyEqual(size(result.ppi_betas, 1), length(subjects));
        end

        function testPlotMatrixCompatibility(testCase)
            result = exploreFNIRS.connectivity.computeBetaSeries( ...
                testCase.data, testCase.blocks, 'Channels', 1:4);

            % plotMatrix should accept the result without error
            fig = exploreFNIRS.connectivity.plotMatrix(result, ...
                'Visible', 'off');
            testCase.verifyNotEmpty(fig);
            testCase.addTeardown(@() close(fig));
        end

        function testGLMExperimentBetaSeriesNValid(testCase)
            [subjects, blockDefs] = buildTestSubjects(testCase);

            gx = exploreFNIRS.core.GLMExperiment(subjects, blockDefs);
            result = gx.betaSeriesConnectivity();

            testCase.verifyTrue(isfield(result, 'nValid'));
            nCh = length(result.channels);
            testCase.verifyEqual(size(result.nValid), [nCh, nCh]);
        end

        function testGLMBetaSeriesUnbalancedUnion(testCase)
            [subjects, blockDefs] = buildUnbalancedSubjects(testCase);

            gx = exploreFNIRS.core.GLMExperiment(subjects, blockDefs);
            result = gx.betaSeriesConnectivity('Align', 'union');

            % Union should include all channels from both subjects
            allCh = union(find(subjects{1}.fchMask), find(subjects{2}.fchMask));
            testCase.verifyEqual(length(result.channels), length(allCh));
            % nValid should have some cells with 1 (only one subject)
            testCase.verifyTrue(any(result.nValid(:) == 1));
        end

        function testGLMBetaSeriesUnbalancedIntersection(testCase)
            [subjects, blockDefs] = buildUnbalancedSubjects(testCase);

            gx = exploreFNIRS.core.GLMExperiment(subjects, blockDefs);
            result = gx.betaSeriesConnectivity('Align', 'intersection');

            % Intersection should only include channels present in both
            commonCh = intersect(find(subjects{1}.fchMask), find(subjects{2}.fchMask));
            testCase.verifyEqual(length(result.channels), length(commonCh));
            % All nValid cells should have 2 (both subjects)
            nCh = length(result.channels);
            offDiag = result.nValid(~eye(nCh, 'logical'));
            testCase.verifyTrue(all(offDiag == 2));
        end

        function testGLMPPIUnbalancedUnion(testCase)
            [subjects, blockDefs] = buildUnbalancedSubjects(testCase);

            gx = exploreFNIRS.core.GLMExperiment(subjects, blockDefs);
            % Use channel 1 as seed (present in both subjects)
            commonCh = intersect(find(subjects{1}.fchMask), find(subjects{2}.fchMask));
            result = gx.ppi(commonCh(1), 'Contrast', {'Easy', 'Hard'}, ...
                'Align', 'union');

            testCase.verifyTrue(isfield(result, 'nValid'));
            % Union should include channels from both subjects
            testCase.verifyGreaterThan(length(result.channels), ...
                length(commonCh) - 1);  % minus seed
        end

        function testGLMPPIUnbalancedIntersection(testCase)
            [subjects, blockDefs] = buildUnbalancedSubjects(testCase);

            gx = exploreFNIRS.core.GLMExperiment(subjects, blockDefs);
            commonCh = intersect(find(subjects{1}.fchMask), find(subjects{2}.fchMask));
            result = gx.ppi(commonCh(1), 'Contrast', {'Easy', 'Hard'}, ...
                'Align', 'intersection');

            % Intersection: only common channels (minus seed)
            testCase.verifyLessThanOrEqual(length(result.channels), ...
                length(commonCh));
            % All per-subject entries should be non-NaN
            testCase.verifyTrue(all(~isnan(result.ppi_betas(:))));
        end

    end

end


%% Local helper functions

function [subjects, blockDefs] = buildUnbalancedSubjects(testCase)
% BUILDUNBALANCEDSUBJECTS Create 2 test subjects with different fchMask

    d1 = testCase.data;
    d1.info.SubjectID = 'S01';
    d1.info.Group = 'A';
    % Keep first 12 channels good, mask out the rest
    nCh = length(d1.fchMask);
    mask1 = zeros(1, nCh);
    mask1(1:min(12, nCh)) = 1;
    d1.fchMask = mask1;

    d2 = testCase.data;
    d2.info.SubjectID = 'S02';
    d2.info.Group = 'A';
    d2.HbO = d2.HbO + randn(size(d2.HbO)) * 0.001;
    % Keep channels 5-16 good, mask out the rest
    mask2 = zeros(1, nCh);
    mask2(5:min(16, nCh)) = 1;
    d2.fchMask = mask2;

    subjects = {d1, d2};
    blockDefs = {testCase.blocks, testCase.blocks};
end


function [subjects, blockDefs] = buildTestSubjects(testCase)
% BUILDTESTSUBJECTS Create 2 test subjects from the loaded data

    d1 = testCase.data;
    d1.info.SubjectID = 'S01';
    d1.info.Group = 'A';

    d2 = testCase.data;
    d2.info.SubjectID = 'S02';
    d2.info.Group = 'A';
    % Add small noise to make subjects different
    d2.HbO = d2.HbO + randn(size(d2.HbO)) * 0.001;

    subjects = {d1, d2};
    blockDefs = {testCase.blocks, testCase.blocks};
end
