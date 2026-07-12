classdef HRFTest < matlab.unittest.TestCase
    % HRFTEST Unit tests for buildHRF and HRF-based GLM recovery
    %
    %   Tests cover HRF shape and timing, parameter variation, output format,
    %   collinearity diagnostics with drift regressors, and GLM beta recovery
    %   with realistic block designs.
    %
    %   Example:
    %       results = runtests('pf2_base.tests.unit.HRFTest');
    %       disp(results);
    %
    %   See also: pf2_base.fnirs.buildHRF, pf2_base.fnirs.buildDesignMatrix

    %% Shape & Timing Tests
    methods (Test)

        function testPeakTiming(testCase)
            % Peak should occur at ~5-6s with default parameters
            hrf = pf2_base.fnirs.buildHRF(20);
            [~, peakIdx] = max(hrf(:, 2));
            peakTime = hrf(peakIdx, 1);

            testCase.verifyGreaterThan(peakTime, 4, ...
                'HRF peak should occur after 4s');
            testCase.verifyLessThan(peakTime, 7, ...
                'HRF peak should occur before 7s');
        end

        function testUndershootPresent(testCase)
            % HRF should include negative undershoot after peak
            hrf = pf2_base.fnirs.buildHRF(20);
            testCase.verifyTrue(any(hrf(:, 2) < 0), ...
                'HRF should contain negative values (undershoot)');
        end

        function testUndershootTroughTiming(testCase)
            % Undershoot trough should occur at ~15-16s
            hrf = pf2_base.fnirs.buildHRF(20);
            [~, troughIdx] = min(hrf(:, 2));
            troughTime = hrf(troughIdx, 1);

            testCase.verifyGreaterThan(troughTime, 12, ...
                'Undershoot trough should occur after 12s');
            testCase.verifyLessThan(troughTime, 20, ...
                'Undershoot trough should occur before 20s');
        end

        function testReturnsToZeroByEnd(testCase)
            % HRF should return to near-zero by 30s
            hrf = pf2_base.fnirs.buildHRF(20);
            lateIdx = hrf(:, 1) >= 30;
            testCase.verifyLessThan(max(abs(hrf(lateIdx, 2))), 0.05, ...
                'HRF should be near-zero by 30s');
        end

        function testPeakAmplitude(testCase)
            % Peak amplitude should be exactly 1.0 (normalization)
            hrf = pf2_base.fnirs.buildHRF(20);
            testCase.verifyEqual(max(hrf(:, 2)), 1.0, 'AbsTol', 1e-10, ...
                'Peak amplitude should be normalized to 1.0');
        end

    end

    %% Parameter Variation Tests
    methods (Test)

        function testDefaultParameters(testCase)
            % Default parameters should produce a valid HRF
            hrf = pf2_base.fnirs.buildHRF();
            testCase.verifyGreaterThan(size(hrf, 1), 10);
            testCase.verifyEqual(size(hrf, 2), 2);
            testCase.verifyEqual(max(hrf(:, 2)), 1.0, 'AbsTol', 1e-10);
        end

        function testCustomAlphaShiftsPeak(testCase)
            % Larger alpha1 should shift peak later
            hrfNarrow = pf2_base.fnirs.buildHRF(20, 32, 4, 16, 1, 1, 1/6);
            hrfWide = pf2_base.fnirs.buildHRF(20, 32, 8, 16, 1, 1, 1/6);

            [~, peakNarrow] = max(hrfNarrow(:, 2));
            [~, peakWide] = max(hrfWide(:, 2));

            testCase.verifyGreaterThan(hrfWide(peakWide, 1), hrfNarrow(peakNarrow, 1), ...
                'Larger alpha1 should produce later peak');
        end

        function testZeroUndershoot(testCase)
            % c=0 should produce no undershoot
            hrf = pf2_base.fnirs.buildHRF(20, 32, 6, 16, 1, 1, 0);
            testCase.verifyGreaterThanOrEqual(min(hrf(:, 2)), 0, ...
                'c=0 should produce no negative values');
        end

        function testConsistentAcrossSamplingRates(testCase)
            % Different sampling rates should produce consistent shape
            rates = [10, 20, 50];
            peakTimes = zeros(1, length(rates));

            for i = 1:length(rates)
                hrf = pf2_base.fnirs.buildHRF(rates(i));
                [~, peakIdx] = max(hrf(:, 2));
                peakTimes(i) = hrf(peakIdx, 1);
            end

            testCase.verifyEqual(peakTimes, peakTimes(1) * ones(size(peakTimes)), ...
                'AbsTol', 0.2, ...
                'Peak timing should be consistent across sampling rates');
        end

        function testShortDuration(testCase)
            % Short duration (t=10) should still produce valid HRF
            hrf = pf2_base.fnirs.buildHRF(20, 10);
            testCase.verifyEqual(hrf(end, 1), 10, ...
                'Time vector should end at requested duration');
            testCase.verifyEqual(max(hrf(:, 2)), 1.0, 'AbsTol', 1e-10);
        end

        function testLongDuration(testCase)
            % Long duration (t=50) should work without error
            hrf = pf2_base.fnirs.buildHRF(20, 50);
            testCase.verifyEqual(hrf(end, 1), 50, ...
                'Time vector should end at requested duration');
        end

    end

    %% Output Format Tests
    methods (Test)

        function testOutputShape(testCase)
            % Output should be [N x 2]
            hrf = pf2_base.fnirs.buildHRF(20);
            testCase.verifyEqual(size(hrf, 2), 2, ...
                'Output should have 2 columns');
        end

        function testTimeVectorStartsAtZero(testCase)
            hrf = pf2_base.fnirs.buildHRF(20);
            testCase.verifyEqual(hrf(1, 1), 0, ...
                'Time vector should start at 0');
        end

        function testTimeSpacing(testCase)
            % Time spacing should match 1/fs
            fs = 10;
            hrf = pf2_base.fnirs.buildHRF(fs);
            dt = diff(hrf(:, 1));
            testCase.verifyEqual(dt, repmat(1/fs, size(dt)), 'AbsTol', 1e-10, ...
                'Time spacing should be 1/fs');
        end

        function testNoNaNOrInf(testCase)
            hrf = pf2_base.fnirs.buildHRF(20);
            testCase.verifyFalse(any(isnan(hrf(:))), 'No NaN values');
            testCase.verifyFalse(any(isinf(hrf(:))), 'No Inf values');
        end

        function testDefaultDuration32s(testCase)
            % Default duration should be 32s (matching SPM)
            hrf = pf2_base.fnirs.buildHRF(20);
            testCase.verifyEqual(hrf(end, 1), 32, ...
                'Default duration should be 32s');
        end

    end

    %% Collinearity Diagnostic Test
    methods (Test)

        function testLowVIFWithDrift(testCase)
            % Task regressor convolved with full HRF should not be highly
            % collinear with order-3 Legendre drift polynomials.
            % VIF < 10 is the standard threshold.
            fs = 10;
            T = 6000;  % 600s at 10 Hz
            time = (0:T-1)' / fs;

            events(1).name = 'Task';
            events(1).onsets = [30 90 150 210 270 330];
            events(1).duration = 30;

            [X, names] = pf2_base.fnirs.buildDesignMatrix(time, fs, events, ...
                'DriftOrder', 3);

            % Compute VIF for task regressor (column 1)
            taskIdx = 1;
            otherIdx = setdiff(1:size(X, 2), taskIdx);
            Xother = X(:, otherIdx);
            xTask = X(:, taskIdx);

            % VIF = 1 / (1 - R^2) where R^2 is from regressing task on others
            betaAux = Xother \ xTask;
            predicted = Xother * betaAux;
            SS_res = sum((xTask - predicted).^2);
            SS_tot = sum((xTask - mean(xTask)).^2);
            R2 = 1 - SS_res / SS_tot;
            VIF = 1 / (1 - R2);

            testCase.verifyLessThan(VIF, 10, ...
                sprintf('Task regressor VIF=%.1f should be < 10 (low collinearity with drift)', VIF));
        end

    end

    %% GLM Beta Recovery Integration Test
    methods (Test)

        function testBetaRecoveryWithBlockDesign(testCase)
            % Synthetic data: 6 blocks of 30s, known beta=3.0, AR(1) noise.
            % GLM with default HRF + order-3 Legendre drift should recover
            % the true beta within tolerance.
            rng(42);

            fs = 10;
            T = 6000;  % 600s
            time = (0:T-1)' / fs;

            events(1).name = 'Task';
            events(1).onsets = [30 90 150 210 270 330];
            events(1).duration = 30;

            [X, names] = pf2_base.fnirs.buildDesignMatrix(time, fs, events, ...
                'DriftOrder', 3);

            trueBeta = 3.0;
            trueVec = zeros(size(X, 2), 1);
            trueVec(1) = trueBeta;

            % Generate AR(1) noise
            noise = zeros(T, 1);
            noise(1) = randn;
            for t = 2:T
                noise(t) = 0.7 * noise(t-1) + randn;
            end

            Y = X * trueVec + 0.3 * noise;

            results = pf2_base.fnirs.fitGLM(Y, X, names);

            testCase.verifyEqual(results.beta(1), trueBeta, 'AbsTol', 0.5, ...
                sprintf('Recovered beta=%.2f should be close to true beta=%.1f', ...
                results.beta(1), trueBeta));
        end

        function testBetaRecoveryWithARIRLS(testCase)
            % Same setup but with AR-IRLS which should handle autocorrelation
            rng(42);

            fs = 10;
            T = 6000;
            time = (0:T-1)' / fs;

            events(1).name = 'Task';
            events(1).onsets = [30 90 150 210 270 330];
            events(1).duration = 30;

            [X, names] = pf2_base.fnirs.buildDesignMatrix(time, fs, events, ...
                'DriftOrder', 3);

            trueBeta = 3.0;
            trueVec = zeros(size(X, 2), 1);
            trueVec(1) = trueBeta;

            % Generate AR(1) noise
            noise = zeros(T, 1);
            noise(1) = randn;
            for t = 2:T
                noise(t) = 0.7 * noise(t-1) + randn;
            end

            Y = X * trueVec + 0.3 * noise;

            results = pf2_base.fnirs.fitGLM(Y, X, names, 'Method', 'AR-IRLS');

            testCase.verifyEqual(results.beta(1), trueBeta, 'AbsTol', 0.5, ...
                sprintf('AR-IRLS recovered beta=%.2f should be close to true beta=%.1f', ...
                results.beta(1), trueBeta));
        end

    end

end
