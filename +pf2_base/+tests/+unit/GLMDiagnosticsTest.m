classdef GLMDiagnosticsTest < matlab.unittest.TestCase
    % GLMDIAGNOSTICSTEST Tests for diagnoseGLM and AR-IRLS contrast fix
    %
    %   Tests cover diagnoseGLM output fields, VIF computation, partial R2,
    %   residual ACF flagging, AR-IRLS contrast SE correctness, and
    %   synthetic beta recovery.
    %
    %   Example:
    %       results = runtests('pf2_base.tests.unit.GLMDiagnosticsTest');
    %       disp(results);
    %
    %   See also: pf2_base.fnirs.diagnoseGLM, pf2_base.fnirs.fitGLM

    properties
        fs
        time
        T
    end

    methods (TestClassSetup)
        function setupSyntheticData(testCase)
            testCase.fs = 10;
            testCase.T = 3000;  % 300 seconds at 10 Hz
            testCase.time = (0:testCase.T-1)' / testCase.fs;
        end
    end

    %% diagnoseGLM Output Tests
    methods (Test)

        function testOutputFieldsExist(testCase)
            % All expected report fields should be present
            rng(42);
            [Y, X, names] = testCase.makeSimpleProblem(1.0);
            report = pf2_base.fnirs.diagnoseGLM(Y, X, names, 'Verbose', false);

            expectedFields = {'conditionNumber', 'VIF', 'regressorScale', ...
                'correlationMatrix', 'betaStats', 'R2', 'R2stats', ...
                'partialR2', 'residualACF', 'meanResidualACF', ...
                'predictedAmplitude', 'taskDataCorrelation', 'dataStats', ...
                'stimRegressorIdx', 'flags', 'glmResults'};

            for i = 1:length(expectedFields)
                testCase.verifyTrue(isfield(report, expectedFields{i}), ...
                    sprintf('Missing field: %s', expectedFields{i}));
            end
        end

        function testVIFOrthogonalRegressors(testCase)
            % QR-orthogonalized design matrix should have VIF close to 1
            rng(42);

            % Build a multi-column orthogonal matrix
            T = testCase.T;
            Xraw = randn(T, 4);
            [Q, ~] = qr(Xraw, 0);
            Y = randn(T, 4);

            qNames = {'Task', 'q2', 'q3', 'q4'};

            report = pf2_base.fnirs.diagnoseGLM(Y, Q, qNames, 'Verbose', false, ...
                'StimRegressorIdx', 1);

            testCase.verifyEqual(report.VIF, ones(1, 4), 'AbsTol', 0.1, ...
                'VIF should be ~1.0 for orthogonal columns');
        end

        function testVIFCollinearRegressors(testCase)
            % Highly correlated columns should produce VIF > 10
            rng(42);
            T = testCase.T;
            x1 = randn(T, 1);
            x2 = x1 + 0.01 * randn(T, 1);  % 0.99+ correlated
            x3 = randn(T, 1);
            X = [x1, x2, x3, ones(T, 1)];
            names = {'A', 'B', 'C', 'constant'};
            Y = randn(T, 2);

            report = pf2_base.fnirs.diagnoseGLM(Y, X, names, 'Verbose', false, ...
                'StimRegressorIdx', [1, 2]);

            testCase.verifyGreaterThan(report.VIF(1), 10, ...
                'VIF for collinear column should be > 10');
            testCase.verifyGreaterThan(report.VIF(2), 10, ...
                'VIF for collinear column should be > 10');
        end

        function testVIFFlagging(testCase)
            % High-VIF stimulus regressor should trigger a warning flag
            rng(42);
            T = testCase.T;
            x1 = randn(T, 1);
            x2 = x1 + 0.01 * randn(T, 1);
            X = [x1, x2, ones(T, 1)];
            names = {'Task', 'TaskCopy', 'constant'};
            Y = randn(T, 1);

            report = pf2_base.fnirs.diagnoseGLM(Y, X, names, 'Verbose', false, ...
                'StimRegressorIdx', [1, 2]);

            hasVIFWarning = any(contains(report.flags, 'VIF='));
            testCase.verifyTrue(hasVIFWarning, ...
                'Should flag high VIF for collinear stimulus regressors');
        end

        function testConditionNumberWellConditioned(testCase)
            % Typical design matrix should have condition number < 1000
            rng(42);
            [Y, X, names] = testCase.makeSimpleProblem(1.0);
            report = pf2_base.fnirs.diagnoseGLM(Y, X, names, 'Verbose', false);

            testCase.verifyLessThan(report.conditionNumber, 1000, ...
                'Typical design matrix should be well-conditioned');
            hasCondWarning = any(contains(report.flags, 'condition number'));
            testCase.verifyFalse(hasCondWarning, ...
                'Should not flag condition number for well-conditioned matrix');
        end

        function testPredictedAmplitudeRecovery(testCase)
            % predictedAmplitude = beta * scale should match injected amplitude
            rng(42);
            injectedAmp = 0.5;
            [Y, X, names, stimIdx] = testCase.makeSimpleProblem(injectedAmp);

            % We need enough signal
            Y = Y + X(:, stimIdx) * injectedAmp;

            report = pf2_base.fnirs.diagnoseGLM(Y, X, names, 'Verbose', false);

            % The predicted amplitude should be in the ballpark
            meanPredAmp = mean(report.predictedAmplitude(1, :));
            testCase.verifyGreaterThan(abs(meanPredAmp), 0.1, ...
                'Predicted amplitude should be non-trivial with injected signal');
        end

        function testPartialR2WithSignal(testCase)
            % Strong task signal should produce meaningful partial R2
            rng(42);
            events(1).name = 'TaskA';
            events(1).onsets = [20 60 100 140 180 220];
            events(1).duration = 20;

            [X, names] = pf2_base.fnirs.buildDesignMatrix(testCase.time, testCase.fs, events);
            P = size(X, 2);

            trueBeta = zeros(P, 4);
            trueBeta(1, :) = 3.0;
            Y = X * trueBeta + 0.3 * randn(testCase.T, 4);

            report = pf2_base.fnirs.diagnoseGLM(Y, X, names, 'Verbose', false);

            medPR2 = median(report.partialR2(1, :));
            testCase.verifyGreaterThan(medPR2, 0.05, ...
                'Partial R2 should be > 0 with strong task signal');
        end

        function testPartialR2WithoutSignal(testCase)
            % Pure noise data should have partial R2 near zero
            rng(42);
            events(1).name = 'TaskA';
            events(1).onsets = [20 60 100 140 180 220];
            events(1).duration = 20;

            [X, names] = pf2_base.fnirs.buildDesignMatrix(testCase.time, testCase.fs, events);
            Y = randn(testCase.T, 4);

            report = pf2_base.fnirs.diagnoseGLM(Y, X, names, 'Verbose', false);

            medPR2 = median(report.partialR2(1, :));
            testCase.verifyLessThan(medPR2, 0.05, ...
                'Partial R2 should be ~0 for pure noise');
        end

        function testResidualACFFlagging(testCase)
            % AR(1) noise with OLS should trigger high ACF flag
            rng(42);
            events(1).name = 'TaskA';
            events(1).onsets = [20 60 100 140 180 220];
            events(1).duration = 20;

            [X, names] = pf2_base.fnirs.buildDesignMatrix(testCase.time, testCase.fs, events);

            % Generate AR(1) noise
            noise = zeros(testCase.T, 1);
            noise(1) = randn;
            for t = 2:testCase.T
                noise(t) = 0.85 * noise(t-1) + randn;
            end
            Y = noise;

            report = pf2_base.fnirs.diagnoseGLM(Y, X, names, 'Verbose', false, ...
                'Method', 'OLS');

            hasACFWarning = any(contains(report.flags, 'ACF'));
            testCase.verifyTrue(hasACFWarning, ...
                'Should flag high residual ACF for AR(1) noise with OLS');
        end

        function testVerboseOutput(testCase)
            % Verbose=true should produce printed output
            rng(42);
            [Y, X, names] = testCase.makeSimpleProblem(1.0);
            output = evalc('pf2_base.fnirs.diagnoseGLM(Y, X, names, ''Verbose'', true);');

            testCase.verifyTrue(contains(output, 'GLM Diagnostics'), ...
                'Should print diagnostics header');
            testCase.verifyTrue(contains(output, 'Design Matrix'), ...
                'Should print design matrix info');
            testCase.verifyTrue(contains(output, 'Regressor Summary'), ...
                'Should print regressor summary');
        end

        function testVerboseFalseSilent(testCase)
            % Verbose=false should produce no output
            rng(42);
            [Y, X, names] = testCase.makeSimpleProblem(1.0);
            output = evalc('pf2_base.fnirs.diagnoseGLM(Y, X, names, ''Verbose'', false);');

            testCase.verifyEqual(strtrim(output), '', ...
                'Verbose=false should produce no console output');
        end

    end

    %% AR-IRLS Contrast Fix Tests
    methods (Test)

        function testARIRLSContrastUsesPrewhitenedX(testCase)
            % AR-IRLS contrast SE should use prewhitened X (not original)
            % With AR(1) noise, AR-IRLS SE should be >= 80% of OLS SE
            % (OLS with autocorrelated noise is anti-conservative)
            rng(42);

            events(1).name = 'TaskA';
            events(1).onsets = [20 80 140 200];
            events(1).duration = 20;
            events(2).name = 'TaskB';
            events(2).onsets = [50 110 170 230];
            events(2).duration = 20;

            [X, names] = pf2_base.fnirs.buildDesignMatrix(testCase.time, testCase.fs, events);

            % Generate data with AR(1) noise and known betas
            trueBeta = zeros(size(X, 2), 1);
            trueBeta(1) = 3.0;
            trueBeta(2) = 1.0;

            noise = zeros(testCase.T, 1);
            noise(1) = randn;
            for t = 2:testCase.T
                noise(t) = 0.8 * noise(t-1) + randn;
            end
            Y = X * trueBeta + 0.5 * noise;

            % Contrast: A - B
            C = zeros(1, size(X, 2));
            C(1) = 1; C(2) = -1;

            olsResults = pf2_base.fnirs.fitGLM(Y, X, names, ...
                'Method', 'OLS', 'Contrasts', C, 'ContrastNames', {'A_vs_B'});
            arirlsResults = pf2_base.fnirs.fitGLM(Y, X, names, ...
                'Method', 'AR-IRLS', 'Contrasts', C, 'ContrastNames', {'A_vs_B'});

            % AR-IRLS contrast SE should not be dramatically smaller than OLS
            % (Before fix: AR-IRLS SE was anti-conservative because it used
            % original X instead of prewhitened Xw)
            seRatio = arirlsResults.contrast.se / olsResults.contrast.se;
            testCase.verifyGreaterThan(seRatio, 0.8, ...
                'AR-IRLS contrast SE should be >= 80% of OLS SE');
        end

        function testARIRLSContrastBetaUnchanged(testCase)
            % Contrast beta (point estimate) should be same for OLS and AR-IRLS
            % since c' * beta depends only on betas, not SE computation
            rng(42);

            events(1).name = 'TaskA';
            events(1).onsets = [20 80 140 200];
            events(1).duration = 20;
            events(2).name = 'TaskB';
            events(2).onsets = [50 110 170 230];
            events(2).duration = 20;

            [X, names] = pf2_base.fnirs.buildDesignMatrix(testCase.time, testCase.fs, events);

            trueBeta = zeros(size(X, 2), 1);
            trueBeta(1) = 3.0;
            trueBeta(2) = 1.0;
            Y = X * trueBeta + 0.1 * randn(testCase.T, 1);

            C = zeros(1, size(X, 2));
            C(1) = 1; C(2) = -1;

            arirlsResults = pf2_base.fnirs.fitGLM(Y, X, names, ...
                'Method', 'AR-IRLS', 'Contrasts', C);

            % Contrast beta should be close to trueBeta(1) - trueBeta(2) = 2.0
            testCase.verifyEqual(arirlsResults.contrast.beta, 2.0, 'AbsTol', 0.5, ...
                'AR-IRLS contrast beta should recover true difference');
        end

    end

    %% Synthetic Pipeline Validation
    methods (Test)

        function testRealisticBetaRecovery(testCase)
            % Inject known amplitude signal, verify diagnoseGLM surfaces it
            rng(42);

            injectedAmp = 0.5;  % uM*mm

            events(1).name = 'Task';
            events(1).onsets = [20 60 100 140 180 220];
            events(1).duration = 20;

            [X, names] = pf2_base.fnirs.buildDesignMatrix(testCase.time, testCase.fs, events);

            % Generate signal: beta * regressor + noise
            trueBeta = zeros(size(X, 2), 1);
            stimIdx = 1;
            regressorPeak = max(abs(X(:, stimIdx)));
            trueBeta(stimIdx) = injectedAmp / regressorPeak;

            Y = X * trueBeta + 0.05 * randn(testCase.T, 1);

            report = pf2_base.fnirs.diagnoseGLM(Y, X, names, 'Verbose', false);

            % Predicted amplitude should be close to injected
            testCase.verifyEqual(report.predictedAmplitude(1), injectedAmp, ...
                'AbsTol', 0.15, ...
                'Predicted amplitude should match injected signal');
        end

        function testMultiChannelBetaRecovery(testCase)
            % 4 channels with different true betas, verify spatial pattern
            rng(42);

            events(1).name = 'Task';
            events(1).onsets = [20 60 100 140 180 220];
            events(1).duration = 20;

            [X, names] = pf2_base.fnirs.buildDesignMatrix(testCase.time, testCase.fs, events);

            % Different amplitudes per channel
            amplitudes = [0.2, 0.5, 0.8, 0.0];
            stimIdx = 1;
            regressorPeak = max(abs(X(:, stimIdx)));

            trueBeta = zeros(size(X, 2), 4);
            trueBeta(stimIdx, :) = amplitudes / regressorPeak;

            Y = X * trueBeta + 0.03 * randn(testCase.T, 4);

            report = pf2_base.fnirs.diagnoseGLM(Y, X, names, 'Verbose', false);

            recoveredAmp = report.predictedAmplitude(1, :);

            % Verify spatial pattern is preserved (channel 3 > channel 2 > channel 1 > channel 4)
            testCase.verifyGreaterThan(recoveredAmp(3), recoveredAmp(2), ...
                'Channel 3 should have largest amplitude');
            testCase.verifyGreaterThan(recoveredAmp(2), recoveredAmp(1), ...
                'Channel 2 should be larger than channel 1');
            testCase.verifyLessThan(abs(recoveredAmp(4)), 0.1, ...
                'Channel 4 (no signal) should have near-zero amplitude');
        end

    end

    %% Helpers
    methods (Access = private)

        function [Y, X, names, stimIdx] = makeSimpleProblem(testCase, amplitude)
            % Create a simple GLM problem with known signal
            events(1).name = 'TaskA';
            events(1).onsets = [20 60 100 140 180 220];
            events(1).duration = 20;

            [X, names] = pf2_base.fnirs.buildDesignMatrix(testCase.time, testCase.fs, events);

            stimIdx = 1;
            regressorPeak = max(abs(X(:, stimIdx)));
            trueBeta = zeros(size(X, 2), 4);
            trueBeta(stimIdx, :) = amplitude / regressorPeak;

            Y = X * trueBeta + 0.1 * randn(testCase.T, 4);
        end

    end

end
