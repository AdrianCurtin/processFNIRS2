classdef DirectedConnectivityTest < matlab.unittest.TestCase
    % DIRECTEDCONNECTIVITYTEST Tests for Granger, TE, dynamic FC, states
    %
    %   results = runtests('pf2_base.tests.unit.DirectedConnectivityTest');

    properties
        fs
        T
        nChannels
    end

    methods (TestClassSetup)
        function setupParams(testCase)
            testCase.fs = 10;
            testCase.T = 1000;
            testCase.nChannels = 6;
        end
    end

    %% Granger Causality
    methods (Test)

        function testGrangerCausalSignal(testCase)
            % x drives y with lag -> significant x->y
            rng(42);
            T = testCase.T;
            x = randn(T, 1);
            y = zeros(T, 1);
            for t = 6:T
                y(t) = 0.7 * x(t-5) + 0.3 * randn();
            end

            result = exploreFNIRS.coupling.granger(x, y, testCase.fs);

            testCase.verifyEqual(result.method, 'granger');
            testCase.verifyEqual(result.direction, 'x->y');
            testCase.verifyGreaterThan(result.value, 1);  % F-stat > 1
            testCase.verifyLessThan(result.pvalue, 0.05);
            testCase.verifyFalse(result.windowed);
        end

        function testGrangerUncorrelated(testCase)
            % Independent signals -> non-significant
            rng(42);
            x = randn(testCase.T, 1);
            y = randn(testCase.T, 1);

            result = exploreFNIRS.coupling.granger(x, y, testCase.fs);

            testCase.verifyGreaterThan(result.pvalue, 0.01);
        end

        function testGrangerWindowed(testCase)
            rng(42);
            T = testCase.T;
            x = randn(T, 1);
            y = [zeros(T/2, 1); randn(T/2, 1)];
            for t = 6:T/2
                y(t) = 0.8 * x(t-5) + 0.2 * randn();
            end

            result = exploreFNIRS.coupling.granger(x, y, testCase.fs, ...
                'WindowSize', 20);

            testCase.verifyTrue(result.windowed);
            testCase.verifyGreaterThan(length(result.value), 1);
            testCase.verifyTrue(isfield(result, 'windowTimes'));
        end

    end

    %% Transfer Entropy
    methods (Test)

        function testTransferEntropyCausal(testCase)
            % TE(x->y) should be positive for causal pair
            rng(42);
            T = testCase.T;
            x = randn(T, 1);
            y = zeros(T, 1);
            for t = 4:T
                y(t) = 0.6 * x(t-3) + 0.4 * randn();
            end

            result = exploreFNIRS.coupling.transferEntropy(x, y, testCase.fs, ...
                'NumSurrogates', 50);

            testCase.verifyEqual(result.method, 'transferEntropy');
            testCase.verifyEqual(result.direction, 'x->y');
            testCase.verifyGreaterThan(result.value, 0);
        end

        function testTransferEntropyUncorrelated(testCase)
            rng(42);
            x = randn(testCase.T, 1);
            y = randn(testCase.T, 1);

            result = exploreFNIRS.coupling.transferEntropy(x, y, testCase.fs, ...
                'NumSurrogates', 50);

            % Should be relatively small for independent signals
            % (histogram-based TE can be noisy with limited data)
            testCase.verifyLessThan(abs(result.value), 2.0);
        end

    end

    %% Compute Matrix with Directed Methods
    methods (Test)

        function testComputeMatrixGrangerAsymmetric(testCase)
            % Granger matrix should NOT be symmetric
            rng(42);
            T = testCase.T;
            nCh = 3;
            data.time = (0:T-1)' / testCase.fs;
            data.fs = testCase.fs;
            data.fchMask = ones(1, nCh);

            % Ch1 drives Ch2, Ch3 is independent
            ch1 = randn(T, 1);
            ch2 = zeros(T, 1);
            for t = 6:T
                ch2(t) = 0.6 * ch1(t-5) + 0.4 * randn();
            end
            ch3 = randn(T, 1);
            data.HbO = [ch1, ch2, ch3];

            result = exploreFNIRS.connectivity.computeMatrix(data, ...
                'Method', 'granger', 'Biomarker', 'HbO');

            % Matrix should be asymmetric (directed)
            testCase.verifyFalse(isequal(result.matrix, result.matrix'));
        end

    end

    %% Dynamic FC
    methods (Test)

        function testComputeDynamicFCShape(testCase)
            rng(42);
            T = testCase.T;
            nCh = 4;
            data.time = (0:T-1)' / testCase.fs;
            data.fs = testCase.fs;
            data.fchMask = ones(1, nCh);
            data.HbO = randn(T, nCh);

            result = exploreFNIRS.connectivity.computeDynamicFC(data, ...
                'WindowSize', 20, 'WindowStep', 10);

            % Check 3D output
            testCase.verifyEqual(size(result.matrices, 1), nCh);
            testCase.verifyEqual(size(result.matrices, 2), nCh);
            nExpectedWin = length(result.windowTimes);
            testCase.verifyEqual(size(result.matrices, 3), nExpectedWin);
            testCase.verifyGreaterThan(nExpectedWin, 1);
        end

    end

    %% Detect States
    methods (Test)

        function testDetectStatesK(testCase)
            rng(42);
            nCh = 4;
            nWin = 20;

            % Create synthetic dynamic FC result
            dynResult.matrices = randn(nCh, nCh, nWin);
            dynResult.windowTimes = (1:nWin)' * 10;
            dynResult.method = 'pearson';
            dynResult.labels = arrayfun(@(c) sprintf('Ch%d', c), 1:nCh, ...
                'UniformOutput', false);

            K = 3;
            states = exploreFNIRS.connectivity.detectStates(dynResult, 'K', K);

            testCase.verifyEqual(length(states.assignments), nWin);
            testCase.verifyEqual(length(states.centroidMatrices), K);
            testCase.verifyTrue(all(states.assignments >= 1 & states.assignments <= K));
        end

    end

    %% Plot Smoke Tests
    methods (Test)

        function testPlotDirectedMatrix(testCase)
            rng(42);
            nCh = 4;
            result.matrix = rand(nCh);
            result.pmatrix = rand(nCh);
            result.channels = 1:nCh;
            result.method = 'granger';
            result.biomarker = 'HbO';
            result.labels = arrayfun(@(c) sprintf('Ch%d', c), 1:nCh, ...
                'UniformOutput', false);

            fig = exploreFNIRS.connectivity.plotDirected(result, ...
                'Layout', 'matrix', 'Visible', 'off');
            testCase.verifyTrue(ishandle(fig));
            close(fig);
        end

        function testPlotDirectedCircular(testCase)
            rng(42);
            nCh = 4;
            result.matrix = rand(nCh);
            result.pmatrix = rand(nCh);
            result.channels = 1:nCh;
            result.method = 'granger';
            result.biomarker = 'HbO';
            result.labels = arrayfun(@(c) sprintf('Ch%d', c), 1:nCh, ...
                'UniformOutput', false);

            fig = exploreFNIRS.connectivity.plotDirected(result, ...
                'Layout', 'circular', 'Visible', 'off');
            testCase.verifyTrue(ishandle(fig));
            close(fig);
        end

        function testPlotDynamicFC(testCase)
            rng(42);
            nCh = 4;
            nWin = 10;
            dynResult.matrices = randn(nCh, nCh, nWin);
            dynResult.windowTimes = (1:nWin)' * 5;
            dynResult.method = 'pearson';
            dynResult.labels = arrayfun(@(c) sprintf('Ch%d', c), 1:nCh, ...
                'UniformOutput', false);

            fig = exploreFNIRS.connectivity.plotDynamicFC(dynResult, ...
                'Visible', 'off');
            testCase.verifyTrue(ishandle(fig));
            close(fig);
        end

        function testPlotDynamicFCWithStates(testCase)
            rng(42);
            nCh = 4;
            nWin = 10;
            dynResult.matrices = randn(nCh, nCh, nWin);
            dynResult.windowTimes = (1:nWin)' * 5;
            dynResult.method = 'pearson';
            dynResult.labels = arrayfun(@(c) sprintf('Ch%d', c), 1:nCh, ...
                'UniformOutput', false);

            states.assignments = randi(3, nWin, 1);
            states.centroidMatrices = {rand(nCh), rand(nCh), rand(nCh)};
            states.silhouette = 0.5;

            fig = exploreFNIRS.connectivity.plotDynamicFC(dynResult, ...
                'States', states, 'Visible', 'off');
            testCase.verifyTrue(ishandle(fig));
            close(fig);
        end

        function testPlotChord(testCase)
            rng(42);
            nCh = 5;
            result.matrix = rand(nCh) * 0.8;
            result.matrix = (result.matrix + result.matrix') / 2;
            result.pmatrix = rand(nCh);
            result.channels = 1:nCh;
            result.method = 'pearson';
            result.biomarker = 'HbO';
            result.labels = {'Left', 'Center', 'Right', 'Front', 'Back'};

            fig = exploreFNIRS.connectivity.plotChord(result, ...
                'Visible', 'off');
            testCase.verifyTrue(ishandle(fig));
            close(fig);
        end

    end

end
