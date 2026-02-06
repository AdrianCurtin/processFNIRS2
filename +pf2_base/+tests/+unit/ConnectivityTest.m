classdef ConnectivityTest < matlab.unittest.TestCase
    % CONNECTIVITYTEST Unit tests for connectivity and hyperscanning modules
    %
    %   Tests cover:
    %     - Coupling functions: pearson, spearman, xcorr, coherence, wcoherence
    %     - Connectivity matrix computation
    %     - Subject pairing for hyperscanning
    %     - Dyad and group computation
    %     - Permutation testing
    %     - Export to table
    %     - Plotting: plotWcoherence, plotWindowed, plotGroup
    %
    %   Example:
    %       results = runtests('pf2_base.tests.unit.ConnectivityTest');
    %       disp(results);

    properties
        fs          % Sampling frequency
        T           % Number of samples
        nChannels   % Number of channels
    end

    methods (TestClassSetup)
        function setupParams(testCase)
            testCase.fs = 10;
            testCase.T = 1000;
            testCase.nChannels = 8;
        end
    end


    %% Coupling Functions
    methods (Test)

        function testPearsonCorrelatedSignals(testCase)
            % Two correlated signals should have r near target
            rng(42);
            target_r = 0.7;
            [x, y] = generateCorrelatedPair(testCase.T, target_r);
            result = exploreFNIRS.coupling.pearson(x, y, testCase.fs);

            testCase.verifyEqual(result.method, 'pearson');
            testCase.verifyFalse(result.windowed);
            testCase.verifyGreaterThan(result.value, 0.5);
            testCase.verifyLessThan(result.pvalue, 0.01);
        end

        function testPearsonUncorrelatedSignals(testCase)
            % Two independent signals should have r near zero
            rng(42);
            x = randn(testCase.T, 1);
            y = randn(testCase.T, 1);
            result = exploreFNIRS.coupling.pearson(x, y, testCase.fs);

            testCase.verifyLessThan(abs(result.value), 0.15);
        end

        function testPearsonWindowed(testCase)
            % Windowed: high corr in first half, low in second
            rng(42);
            T = testCase.T;
            shared = randn(T, 1);
            x = [shared(1:T/2) + randn(T/2, 1) * 0.3; randn(T/2, 1)];
            y = [shared(1:T/2) + randn(T/2, 1) * 0.3; randn(T/2, 1)];

            result = exploreFNIRS.coupling.pearson(x, y, testCase.fs, ...
                'WindowSize', 10);  % 10-second windows

            testCase.verifyTrue(result.windowed);
            testCase.verifyGreaterThan(length(result.value), 1);
            testCase.verifyTrue(isfield(result, 'windowTimes'));

            % First quarter should have higher correlation than last quarter
            nWin = length(result.value);
            firstQ = mean(result.value(1:floor(nWin/4)), 'omitnan');
            lastQ = mean(result.value(ceil(3*nWin/4):end), 'omitnan');
            testCase.verifyGreaterThan(firstQ, lastQ);
        end

        function testSpearmanCorrelatedSignals(testCase)
            rng(42);
            [x, y] = generateCorrelatedPair(testCase.T, 0.7);
            result = exploreFNIRS.coupling.spearman(x, y, testCase.fs);

            testCase.verifyEqual(result.method, 'spearman');
            testCase.verifyGreaterThan(result.value, 0.4);
            testCase.verifyLessThan(result.pvalue, 0.01);
        end

        function testXcorrPeakLag(testCase)
            % Signal y is a delayed version of x - should detect lag
            rng(42);
            lagSamples = 5;  % 0.5 seconds at 10 Hz
            T = testCase.T;
            x = randn(T, 1);
            y = [zeros(lagSamples, 1); x(1:end-lagSamples)];

            result = exploreFNIRS.coupling.xcorr(x, y, testCase.fs, ...
                'MaxLag', 2);

            testCase.verifyEqual(result.method, 'xcorr');
            testCase.verifyGreaterThan(abs(result.value), 0.8);
            testCase.verifyEqual(abs(result.lag), lagSamples / testCase.fs, ...
                'AbsTol', 1/testCase.fs);
        end

        function testCoherenceCorrelatedSignals(testCase)
            % Low-frequency coherent signals
            rng(42);
            t = (0:testCase.T-1)' / testCase.fs;
            shared = sin(2*pi*0.05*t);  % 0.05 Hz shared oscillation
            x = shared + randn(testCase.T, 1) * 0.3;
            y = shared + randn(testCase.T, 1) * 0.3;

            result = exploreFNIRS.coupling.coherence(x, y, testCase.fs, ...
                'FreqRange', [0.01, 0.1]);

            testCase.verifyEqual(result.method, 'coherence');
            testCase.verifyGreaterThan(result.value, 0.3);
            testCase.verifyTrue(isfield(result, 'spectrum'));
            testCase.verifyTrue(isfield(result, 'freqs'));
        end

        function testPearsonLengthMismatch(testCase)
            x = randn(100, 1);
            y = randn(50, 1);
            testCase.verifyError(@() exploreFNIRS.coupling.pearson(x, y, 10), ...
                'exploreFNIRS:coupling:pearson');
        end

    end


    %% Connectivity Matrix
    methods (Test)

        function testComputeMatrixBasic(testCase)
            rng(42);
            data = createSyntheticSubject(testCase, 'correlated');

            result = exploreFNIRS.connectivity.computeMatrix(data, ...
                'Method', 'pearson', 'Biomarker', 'HbO');

            nCh = length(result.channels);
            testCase.verifyEqual(size(result.matrix), [nCh, nCh]);
            testCase.verifyEqual(size(result.pmatrix), [nCh, nCh]);
            testCase.verifyEqual(result.method, 'pearson');
            testCase.verifyEqual(result.biomarker, 'HbO');

            % Diagonal should be 1
            testCase.verifyEqual(diag(result.matrix), ones(nCh, 1), 'AbsTol', 1e-10);

            % Matrix should be symmetric
            testCase.verifyEqual(result.matrix, result.matrix', 'AbsTol', 1e-10);
        end

        function testComputeMatrixCorrelation(testCase)
            % Channels 1-2 should be correlated, channel 3 independent
            rng(42);
            T = testCase.T;
            shared = randn(T, 1);
            data.HbO = [shared + randn(T,1)*0.2, shared + randn(T,1)*0.2, randn(T,1)];
            data.time = (0:T-1)' / testCase.fs;
            data.fs = testCase.fs;
            data.fchMask = [1, 1, 1];

            result = exploreFNIRS.connectivity.computeMatrix(data, ...
                'Method', 'pearson', 'Biomarker', 'HbO');

            % Ch1-Ch2 should be highly correlated
            testCase.verifyGreaterThan(result.matrix(1, 2), 0.7);
            % Ch1-Ch3 and Ch2-Ch3 should be weakly correlated
            testCase.verifyLessThan(abs(result.matrix(1, 3)), 0.3);
            testCase.verifyLessThan(abs(result.matrix(2, 3)), 0.3);
        end

        function testComputeMatrixTimeWindow(testCase)
            rng(42);
            data = createSyntheticSubject(testCase, 'random');
            result = exploreFNIRS.connectivity.computeMatrix(data, ...
                'TimeWindow', [10, 50]);

            expectedSamples = sum(data.time >= 10 & data.time <= 50);
            testCase.verifyEqual(result.nSamples, expectedSamples);
        end

        function testComputeMatrixChannelSubset(testCase)
            rng(42);
            data = createSyntheticSubject(testCase, 'random');
            result = exploreFNIRS.connectivity.computeMatrix(data, ...
                'Channels', [1, 3, 5]);

            testCase.verifyEqual(result.channels, [1, 3, 5]);
            testCase.verifyEqual(size(result.matrix), [3, 3]);
        end

    end


    %% Hyperscanning - Pairing
    methods (Test)

        function testPairSubjectsByMetadata(testCase)
            data = createDyadData(testCase, 3);
            pairs = exploreFNIRS.hyperscanning.pairSubjects(data);

            testCase.verifyEqual(length(pairs), 3);
            for d = 1:3
                testCase.verifyEqual(length(pairs(d).indices), 2);
                testCase.verifyNotEmpty(pairs(d).dyadID);
            end
        end

        function testPairSubjectsManual(testCase)
            data = createDyadData(testCase, 2);
            pairs = exploreFNIRS.hyperscanning.pairSubjects(data, ...
                'ManualPairs', {{1,2}, {3,4}});

            testCase.verifyEqual(length(pairs), 2);
            testCase.verifyEqual(pairs(1).indices, [1, 2]);
            testCase.verifyEqual(pairs(2).indices, [3, 4]);
        end

        function testPairSubjectsMismatchWarning(testCase)
            % Create data with one incomplete dyad
            data = createDyadData(testCase, 2);
            % Remove one member of dyad 2
            data = data(1:3);  % only 3 of 4 subjects
            testCase.verifyWarning( ...
                @() exploreFNIRS.hyperscanning.pairSubjects(data), ...
                'exploreFNIRS:hyperscanning:pairSubjects');
        end

    end


    %% Hyperscanning - Dyad Computation
    methods (Test)

        function testComputeDyadIdentical(testCase)
            % Identical signals should yield coupling ~1
            rng(42);
            data = createSyntheticSubject(testCase, 'random');
            result = exploreFNIRS.hyperscanning.computeDyad(data, data, ...
                'Method', 'pearson', 'Biomarker', 'HbO', 'ChannelPairing', 'same');

            testCase.verifyEqual(result.pairing, 'same');
            testCase.verifyEqual(length(result.values), testCase.nChannels);
            % All channels should have r ~ 1
            testCase.verifyGreaterThan(min(result.values), 0.95);
        end

        function testComputeDyadCorrelated(testCase)
            % Shared signal across subjects should yield positive coupling
            rng(42);
            T = testCase.T;
            nCh = testCase.nChannels;
            shared = randn(T, nCh) * 0.5;

            dataA = createSyntheticSubject(testCase, 'random');
            dataB = createSyntheticSubject(testCase, 'random');
            dataA.HbO = shared + randn(T, nCh) * 0.5;
            dataB.HbO = shared + randn(T, nCh) * 0.5;

            result = exploreFNIRS.hyperscanning.computeDyad(dataA, dataB, ...
                'Method', 'pearson', 'ChannelPairing', 'same');

            testCase.verifyGreaterThan(mean(result.values, 'omitnan'), 0.2);
        end

        function testComputeDyadAllPairing(testCase)
            rng(42);
            dataA = createSyntheticSubject(testCase, 'random');
            dataB = createSyntheticSubject(testCase, 'random');

            result = exploreFNIRS.hyperscanning.computeDyad(dataA, dataB, ...
                'ChannelPairing', 'all');

            testCase.verifyEqual(result.pairing, 'all');
            nCh = testCase.nChannels;
            testCase.verifyEqual(size(result.values), [nCh, nCh]);
        end

    end


    %% Hyperscanning - Group Computation
    methods (Test)

        function testComputeGroupBasic(testCase)
            rng(42);
            nDyads = 5;
            data = createDyadData(testCase, nDyads);
            pairs = exploreFNIRS.hyperscanning.pairSubjects(data);

            result = exploreFNIRS.hyperscanning.computeGroup(data, pairs, ...
                'Method', 'pearson', 'Biomarker', 'HbO');

            testCase.verifyTrue(isfield(result, 'Mean'));
            testCase.verifyTrue(isfield(result, 'SD'));
            testCase.verifyTrue(isfield(result, 'SEM'));
            testCase.verifyTrue(isfield(result, 'N'));
            testCase.verifyTrue(isfield(result, 'tstat'));
            testCase.verifyTrue(isfield(result, 'pvalue'));
            testCase.verifyEqual(length(result.dyads), nDyads);
        end

        function testComputeGroupDetectsSignal(testCase)
            % Dyads with shared signal should have positive mean coupling
            rng(42);
            nDyads = 5;
            data = createDyadDataWithSharedSignal(testCase, nDyads, 0.5);
            pairs = exploreFNIRS.hyperscanning.pairSubjects(data);

            result = exploreFNIRS.hyperscanning.computeGroup(data, pairs, ...
                'Method', 'pearson', 'Biomarker', 'HbO');

            testCase.verifyGreaterThan(mean(result.Mean, 'omitnan'), 0.15);
        end

    end


    %% Permutation Testing
    methods (Test)

        function testPermutationTestSignificant(testCase)
            % Strong shared signal should survive permutation
            rng(42);
            nDyads = 5;
            data = createDyadDataWithSharedSignal(testCase, nDyads, 0.7);
            pairs = exploreFNIRS.hyperscanning.pairSubjects(data);

            result = exploreFNIRS.hyperscanning.permutationTest(data, pairs, ...
                'Permutations', 100, 'PThreshold', 0.05, ...
                'Method', 'pearson', 'Biomarker', 'HbO');

            testCase.verifyTrue(isfield(result, 'pvalue'));
            testCase.verifyTrue(isfield(result, 'significant'));
            testCase.verifyTrue(isfield(result, 'nullDist'));
            testCase.verifyTrue(isfield(result, 'zScore'));

            % At least some channels should be significant
            testCase.verifyTrue(any(result.significant(:)));
        end

        function testPermutationTestNull(testCase)
            % Independent signals should not be significant
            rng(42);
            nDyads = 5;
            data = createDyadData(testCase, nDyads);  % no shared signal
            pairs = exploreFNIRS.hyperscanning.pairSubjects(data);

            result = exploreFNIRS.hyperscanning.permutationTest(data, pairs, ...
                'Permutations', 50, 'PThreshold', 0.05, ...
                'Method', 'pearson', 'Biomarker', 'HbO');

            % Most channels should NOT be significant
            testCase.verifyLessThan(sum(result.significant(:)) / numel(result.significant), 0.3);
        end

    end


    %% Export
    methods (Test)

        function testConnectivityMatrixExport(testCase)
            rng(42);
            data = createSyntheticSubject(testCase, 'random');
            result = exploreFNIRS.connectivity.computeMatrix(data, ...
                'Method', 'pearson', 'Channels', 1:3);

            T = exploreFNIRS.export.connectivityToTable(result);

            testCase.verifyTrue(istable(T));
            testCase.verifyGreaterThan(height(T), 0);
            testCase.verifyTrue(ismember('Coupling', T.Properties.VariableNames));
            testCase.verifyTrue(ismember('ChannelA', T.Properties.VariableNames));
            testCase.verifyTrue(ismember('ChannelB', T.Properties.VariableNames));
        end

        function testHyperscanningExport(testCase)
            rng(42);
            nDyads = 3;
            data = createDyadDataWithSharedSignal(testCase, nDyads, 0.5);
            pairs = exploreFNIRS.hyperscanning.pairSubjects(data);
            result = exploreFNIRS.hyperscanning.computeGroup(data, pairs, ...
                'Method', 'pearson', 'Biomarker', 'HbO');
            result.pairs = pairs;

            T = exploreFNIRS.export.connectivityToTable(result, ...
                'IncludeDyads', true, 'IncludeGroup', true);

            testCase.verifyTrue(istable(T));
            testCase.verifyGreaterThan(height(T), 0);
            testCase.verifyTrue(ismember('DyadID', T.Properties.VariableNames));
            testCase.verifyTrue(ismember('Level', T.Properties.VariableNames));
        end


        %% Wavelet Coherence Tests

        function testWcoherenceCorrelatedSignals(testCase)
            % Two correlated signals should have high wavelet coherence
            rng(42);
            T = testCase.T;
            fs = testCase.fs;
            t = (0:T-1)' / fs;
            shared = sin(2 * pi * 0.05 * t);
            x = shared + randn(T, 1) * 0.2;
            y = shared + randn(T, 1) * 0.2;

            result = exploreFNIRS.coupling.wcoherence(x, y, fs, ...
                'FreqRange', [0.01, 0.2]);

            testCase.verifyEqual(result.method, 'wcoherence');
            testCase.verifyFalse(result.windowed);
            testCase.verifyGreaterThan(result.value, 0.3);
            testCase.verifyTrue(isnan(result.pvalue));
            testCase.verifyTrue(isfield(result, 'wcoh'));
            testCase.verifyTrue(isfield(result, 'freqs'));
            testCase.verifyTrue(isfield(result, 'times'));
            testCase.verifyTrue(isfield(result, 'coi'));
            testCase.verifyEqual(size(result.wcoh, 2), T);
        end

        function testWcoherenceUncorrelatedSignals(testCase)
            % Two independent signals should have low wavelet coherence
            rng(42);
            x = randn(testCase.T, 1);
            y = randn(testCase.T, 1);

            result = exploreFNIRS.coupling.wcoherence(x, y, testCase.fs, ...
                'FreqRange', [0.01, 0.5]);

            testCase.verifyLessThan(result.value, 0.6);
        end

        function testWcoherencePhaseOutput(testCase)
            % Phase output should be returned when requested
            rng(42);
            T = testCase.T;
            fs = testCase.fs;
            t = (0:T-1)' / fs;
            x = sin(2 * pi * 0.05 * t);
            y = cos(2 * pi * 0.05 * t);

            result = exploreFNIRS.coupling.wcoherence(x, y, fs, ...
                'PhaseOutput', true);

            testCase.verifyTrue(isfield(result, 'phase'));
            testCase.verifyEqual(size(result.phase), size(result.wcoh));
        end

        function testWcoherenceInConnectivityMatrix(testCase)
            % WCT should work through computeMatrix dispatch
            rng(42);
            data = createSyntheticSubject(testCase, 'correlated');
            result = exploreFNIRS.connectivity.computeMatrix(data, ...
                'Method', 'wcoherence', 'Biomarker', 'HbO');

            testCase.verifyTrue(isfield(result, 'matrix'));
            nCh = testCase.nChannels;
            testCase.verifyEqual(size(result.matrix), [nCh, nCh]);
            testCase.verifyEqual(result.method, 'wcoherence');
        end

        function testWcoherenceInHyperscanning(testCase)
            % WCT should work through computeDyad dispatch
            rng(42);
            data = createDyadDataWithSharedSignal(testCase, 2, 0.5);
            pairs = exploreFNIRS.hyperscanning.pairSubjects(data);
            result = exploreFNIRS.hyperscanning.computeGroup(data, pairs, ...
                'Method', 'wcoherence', 'Biomarker', 'HbO');

            testCase.verifyTrue(isfield(result, 'Mean'));
            testCase.verifyEqual(result.method, 'wcoherence');
        end


        %% Plot Tests (headless)

        function testPlotWcoherence(testCase)
            % plotWcoherence should create a figure without error
            rng(42);
            T = testCase.T;
            fs = testCase.fs;
            t = (0:T-1)' / fs;
            x = sin(2 * pi * 0.05 * t) + randn(T, 1) * 0.3;
            y = sin(2 * pi * 0.05 * t) + randn(T, 1) * 0.3;

            result = exploreFNIRS.coupling.wcoherence(x, y, fs);
            fig = exploreFNIRS.coupling.plotWcoherence(result, ...
                'Visible', 'off');

            testCase.verifyTrue(ishandle(fig));
            close(fig);
        end

        function testPlotWindowed(testCase)
            % plotWindowed should create a figure for windowed results
            rng(42);
            [x, y] = generateCorrelatedPair(testCase.T, 0.5);
            result = exploreFNIRS.coupling.pearson(x, y, testCase.fs, ...
                'WindowSize', 30);

            testCase.verifyTrue(result.windowed);
            fig = exploreFNIRS.coupling.plotWindowed(result, ...
                'Visible', 'off');

            testCase.verifyTrue(ishandle(fig));
            close(fig);
        end

        function testPlotGroupHyperscanning(testCase)
            % plotGroup should create a figure for group results
            rng(42);
            data = createDyadDataWithSharedSignal(testCase, 3, 0.5);
            pairs = exploreFNIRS.hyperscanning.pairSubjects(data);
            result = exploreFNIRS.hyperscanning.computeGroup(data, pairs, ...
                'Method', 'pearson', 'Biomarker', 'HbO');

            fig = exploreFNIRS.hyperscanning.plotGroup(result, ...
                'Visible', 'off');

            testCase.verifyTrue(ishandle(fig));
            close(fig);
        end

        %% ROI Mode Tests

        function testConnectivityMatrixWithROI(testCase)
            % computeMatrix with UseROI should use ROI data and return ROI labels
            rng(42);
            data = createSyntheticSubject(testCase, 'correlated');
            data = addROIData(data, testCase.T, {'Left','Center','Right'});

            result = exploreFNIRS.connectivity.computeMatrix(data, ...
                'UseROI', true, 'Method', 'pearson');

            testCase.verifyEqual(size(result.matrix), [3, 3]);
            testCase.verifyTrue(result.useROI);
            testCase.verifyEqual(result.labels, {'Left';'Center';'Right'});
            testCase.verifyEqual(result.channels, 1:3);
            % Diagonal should be 1
            testCase.verifyEqual(diag(result.matrix), ones(3,1), 'AbsTol', 1e-10);
        end

        function testConnectivityMatrixROISubsetChannels(testCase)
            % computeMatrix with UseROI and Channels should subset ROIs
            rng(42);
            data = createSyntheticSubject(testCase, 'random');
            data = addROIData(data, testCase.T, {'Left','Center','Right','Back'});

            result = exploreFNIRS.connectivity.computeMatrix(data, ...
                'UseROI', true, 'Channels', [1 3]);

            testCase.verifyEqual(size(result.matrix), [2, 2]);
            testCase.verifyEqual(result.channels, [1 3]);
            testCase.verifyEqual(result.labels, {'Left';'Right'});
        end

        function testDyadWithROI(testCase)
            % computeDyad with UseROI should pair ROIs between subjects
            rng(42);
            roiNames = {'Left','Center','Right'};
            dataA = createSyntheticSubject(testCase, 'random');
            dataA = addROIData(dataA, testCase.T, roiNames);
            dataA.info.DyadID = 'D01';
            dataA.info.Role = 'Speaker';

            dataB = createSyntheticSubject(testCase, 'random');
            dataB = addROIData(dataB, testCase.T, roiNames);
            dataB.info.DyadID = 'D01';
            dataB.info.Role = 'Listener';

            result = exploreFNIRS.hyperscanning.computeDyad(dataA, dataB, ...
                'UseROI', true, 'Method', 'pearson');

            testCase.verifyEqual(length(result.values), 3);
            testCase.verifyTrue(result.useROI);
            testCase.verifyEqual(result.labelsA, {'Left';'Center';'Right'});
            testCase.verifyEqual(result.labelsB, {'Left';'Center';'Right'});
        end

        function testDyadROIMissingError(testCase)
            % computeDyad with UseROI should error when ROI data is missing
            dataA = createSyntheticSubject(testCase, 'random');
            dataB = createSyntheticSubject(testCase, 'random');

            testCase.verifyError( ...
                @() exploreFNIRS.hyperscanning.computeDyad(dataA, dataB, ...
                    'UseROI', true), ...
                'exploreFNIRS:hyperscanning:computeDyad');
        end

        function testPlotMatrixWithROILabels(testCase)
            % plotMatrix should display ROI labels when result has labels
            rng(42);
            data = createSyntheticSubject(testCase, 'correlated');
            data = addROIData(data, testCase.T, {'Left','Center','Right'});

            result = exploreFNIRS.connectivity.computeMatrix(data, ...
                'UseROI', true, 'Method', 'pearson');

            fig = exploreFNIRS.connectivity.plotMatrix(result, ...
                'Visible', 'off');

            testCase.verifyTrue(ishandle(fig));
            % Check axis labels contain ROI names
            ax = findobj(fig, 'Type', 'Axes');
            labels = get(ax, 'XTickLabel');
            testCase.verifyEqual(labels, {'Left';'Center';'Right'});
            close(fig);
        end

        function testConnectivityMatrixROIMissingError(testCase)
            % computeMatrix with UseROI should error when ROI data is missing
            data = createSyntheticSubject(testCase, 'random');

            testCase.verifyError( ...
                @() exploreFNIRS.connectivity.computeMatrix(data, 'UseROI', true), ...
                'exploreFNIRS:connectivity:computeMatrix');
        end

    end

end


%% Helper functions

function [x, y] = generateCorrelatedPair(T, target_r)
    % Generate two signals with approximate Pearson r = target_r
    x = randn(T, 1);
    noise = randn(T, 1);
    y = target_r * x + sqrt(1 - target_r^2) * noise;
end


function data = createSyntheticSubject(testCase, mode)
    % Create a single fNIRS-like struct
    T = testCase.T;
    nCh = testCase.nChannels;
    fs = testCase.fs;

    data.time = (0:T-1)' / fs;
    data.fs = fs;
    data.fchMask = ones(1, nCh);

    switch mode
        case 'random'
            data.HbO = randn(T, nCh);
            data.HbR = randn(T, nCh) * 0.5;
        case 'correlated'
            shared = randn(T, 1);
            data.HbO = repmat(shared, 1, nCh) + randn(T, nCh) * 0.3;
            data.HbR = -data.HbO * 0.3 + randn(T, nCh) * 0.1;
    end

    data.info.SubjectID = 'TestSubject';
end


function data = createDyadData(testCase, nDyads)
    % Create cell array of subjects paired by DyadID (independent signals)
    data = cell(nDyads * 2, 1);
    for d = 1:nDyads
        for role = 1:2
            idx = (d-1)*2 + role;
            s = createSyntheticSubject(testCase, 'random');
            s.info.SubjectID = sprintf('S%d%d', d, role);
            s.info.DyadID = sprintf('D%02d', d);
            if role == 1
                s.info.Role = 'Speaker';
            else
                s.info.Role = 'Listener';
            end
            data{idx} = s;
        end
    end
end


function data = createDyadDataWithSharedSignal(testCase, nDyads, strength)
    % Create dyad data where partners share a signal component
    T = testCase.T;
    nCh = testCase.nChannels;
    data = cell(nDyads * 2, 1);

    for d = 1:nDyads
        shared = randn(T, nCh) * strength;
        for role = 1:2
            idx = (d-1)*2 + role;
            s = createSyntheticSubject(testCase, 'random');
            s.HbO = shared + randn(T, nCh) * (1 - strength);
            s.info.SubjectID = sprintf('S%d%d', d, role);
            s.info.DyadID = sprintf('D%02d', d);
            if role == 1
                s.info.Role = 'Speaker';
            else
                s.info.Role = 'Listener';
            end
            data{idx} = s;
        end
    end
end


function data = addROIData(data, T, roiNames)
    % Add synthetic ROI data to an fNIRS struct
    nROIs = length(roiNames);
    data.ROI.HbO = randn(T, nROIs);
    data.ROI.HbR = randn(T, nROIs) * 0.3;
    data.ROI.info = table(repmat({[1,2,3]}, nROIs, 1), ...
        'VariableNames', {'Channels'}, ...
        'RowNames', roiNames);
end
