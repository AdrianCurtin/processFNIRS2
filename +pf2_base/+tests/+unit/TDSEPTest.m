classdef TDSEPTest < matlab.unittest.TestCase
    % TDSEPTEST Unit tests for pf2_base.signal.tdsep
    %
    %   Tests cover:
    %     - Known mixing recovery (sinusoidal sources)
    %     - Whitened output has identity covariance
    %     - Dimensionality reduction
    %     - Variance retained threshold
    %     - Output dimensions
    %     - Sources approximately uncorrelated
    %     - Edge cases
    %
    %   Example:
    %       results = runtests('pf2_base.tests.unit.TDSEPTest');
    %       disp(results);

    properties
        fs
        T
    end

    methods (TestClassSetup)
        function setupParams(testCase)
            testCase.fs = 10;
            testCase.T = 2000;
        end
    end

    methods (Test)

        function testKnownMixingRecovery(testCase)
            % Generate 3 independent sinusoidal sources, mix, and recover
            rng(42);
            T = testCase.T;
            t = (0:T-1)' / testCase.fs;

            % Independent sources at different frequencies
            s1 = sin(2*pi*0.3*t);
            s2 = sin(2*pi*0.7*t + 1.2);
            s3 = sin(2*pi*1.5*t + 0.5);
            S_true = [s1, s2, s3];

            % Random mixing matrix
            A_true = [0.5 0.3 0.8; 0.9 0.1 0.4; 0.2 0.7 0.6; 0.4 0.5 0.3];
            X = S_true * A_true';  % [T x 4]

            [W, S_est, A_est] = pf2_base.signal.tdsep(X, 'NumComponents', 3);

            % Each estimated source should correlate highly with one true source
            corrMat = abs(corr(S_true, S_est));
            % Each true source should have at least one high-corr estimate
            maxCorr = max(corrMat, [], 2);
            testCase.verifyGreaterThan(min(maxCorr), 0.9, ...
                'Each source should be well-recovered');
        end

        function testWhitenedCovariance(testCase)
            % Sources should have approximately identity covariance
            rng(43);
            T = testCase.T;
            X = randn(T, 5);

            [~, S, ~] = pf2_base.signal.tdsep(X);

            K = size(S, 2);
            covS = cov(S);
            testCase.verifySize(covS, [K, K]);

            % Diagonal should be near 1, off-diagonal near 0
            for i = 1:K
                testCase.verifyEqual(covS(i,i), 1, 'AbsTol', 0.15);
            end
            offDiag = covS - diag(diag(covS));
            testCase.verifyLessThan(max(abs(offDiag(:))), 0.15);
        end

        function testDimensionalityReduction(testCase)
            % Request fewer components than channels
            rng(44);
            T = testCase.T;
            X = randn(T, 8);

            [W, S, A] = pf2_base.signal.tdsep(X, 'NumComponents', 3);

            testCase.verifySize(W, [3, 8]);
            testCase.verifySize(S, [T, 3]);
            testCase.verifySize(A, [8, 3]);
        end

        function testVarianceRetainedThreshold(testCase)
            % Low variance threshold should produce fewer components
            rng(45);
            T = testCase.T;

            % Create data with clear rank structure
            s1 = randn(T, 1) * 10;  % High variance
            s2 = randn(T, 1) * 5;
            s3 = randn(T, 1) * 0.01;  % Very low variance
            X = [s1, s2, s3] * randn(3, 6);

            [~, S_high, ~] = pf2_base.signal.tdsep(X, 'VarianceRetained', 0.99);
            [~, S_low, ~] = pf2_base.signal.tdsep(X, 'VarianceRetained', 0.80);

            testCase.verifyGreaterThanOrEqual(size(S_high, 2), size(S_low, 2), ...
                'Higher threshold should retain more or equal components');
        end

        function testOutputDimensions(testCase)
            % Verify W, S, A dimensions are consistent
            rng(46);
            T = 500;
            C = 6;
            X = randn(T, C);

            [W, S, A] = pf2_base.signal.tdsep(X);

            K = size(W, 1);
            testCase.verifySize(W, [K, C]);
            testCase.verifySize(S, [T, K]);
            testCase.verifySize(A, [C, K]);

            % W * A should approximate identity
            WA = W * A;
            testCase.verifyEqual(WA, eye(K), 'AbsTol', 0.05, ...
                'W * A should be near identity');
        end

        function testSourcesUncorrelated(testCase)
            % Estimated sources should be approximately uncorrelated
            rng(47);
            T = testCase.T;
            t = (0:T-1)' / testCase.fs;

            % Create temporally structured signals
            s1 = sin(2*pi*0.5*t) + randn(T,1)*0.1;
            s2 = cos(2*pi*1.2*t) + randn(T,1)*0.1;
            s3 = sin(2*pi*2.3*t + 0.8) + randn(T,1)*0.1;
            S_true = [s1, s2, s3];
            A_mix = randn(3, 5);
            X = S_true * A_mix;

            [~, S_est, ~] = pf2_base.signal.tdsep(X, 'NumComponents', 3);

            corrMat = corr(S_est);
            offDiag = corrMat - diag(diag(corrMat));
            testCase.verifyLessThan(max(abs(offDiag(:))), 0.2, ...
                'Sources should be approximately uncorrelated');
        end

        function testSingleComponent(testCase)
            % Edge case: request just 1 component
            rng(48);
            T = 500;
            X = randn(T, 4);

            [W, S, A] = pf2_base.signal.tdsep(X, 'NumComponents', 1);

            testCase.verifySize(W, [1, 4]);
            testCase.verifySize(S, [T, 1]);
            testCase.verifySize(A, [4, 1]);
        end

        function testShortSignal(testCase)
            % Short signal should still work
            rng(49);
            X = randn(20, 3);

            [W, S, A] = pf2_base.signal.tdsep(X);

            K = size(W, 1);
            testCase.verifyGreaterThan(K, 0);
            testCase.verifySize(S, [20, K]);
        end

        function testCustomLags(testCase)
            % Custom lag vector should work
            rng(50);
            T = 500;
            X = randn(T, 4);

            [W1, ~, ~] = pf2_base.signal.tdsep(X, 'Lags', 1:5);
            [W2, ~, ~] = pf2_base.signal.tdsep(X, 'Lags', [1, 10, 50]);

            % Both should produce valid results (may differ)
            testCase.verifySize(W1, [size(W1,1), 4]);
            testCase.verifySize(W2, [size(W2,1), 4]);
        end

        function testReconstructionQuality(testCase)
            % X_centered should be approximately recoverable: Xc ~ S * W
            rng(51);
            T = testCase.T;
            X = randn(T, 5);
            Xc = X - mean(X, 1);

            [W, S, A] = pf2_base.signal.tdsep(X);

            Xrec = S * W;
            relErr = norm(Xc - Xrec, 'fro') / norm(Xc, 'fro');
            testCase.verifyLessThan(relErr, 0.1, ...
                'Reconstruction error should be small');
        end

        function testTooFewSamplesErrors(testCase)
            % Very short signal should error
            X = randn(2, 3);
            testCase.verifyError(@() pf2_base.signal.tdsep(X), ...
                'pf2_base:signal:tdsep');
        end

    end
end
