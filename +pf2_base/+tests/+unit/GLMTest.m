classdef GLMTest < matlab.unittest.TestCase
    % GLMTEST Unit tests for GLM design matrix and solver
    %
    %   Tests cover buildDesignMatrix and fitGLM for correctness of
    %   design matrix construction, OLS beta recovery, contrast testing,
    %   and AR-IRLS convergence using synthetic data.
    %
    %   Example:
    %       results = runtests('pf2_base.tests.unit.GLMTest');
    %       disp(results);
    %
    %   See also: pf2_base.fnirs.buildDesignMatrix, pf2_base.fnirs.fitGLM

    properties
        fs       % Sampling frequency
        time     % Time vector
        T        % Number of samples
    end

    methods (TestClassSetup)
        function setupSyntheticData(testCase)
            testCase.fs = 10;
            testCase.T = 3000;  % 300 seconds at 10 Hz
            testCase.time = (0:testCase.T-1)' / testCase.fs;
        end
    end

    %% buildDesignMatrix Tests
    methods (Test)

        function testDesignMatrixDimensions(testCase)
            % Design matrix should have T rows and correct number of columns
            events(1).name = 'TaskA';
            events(1).onsets = [10 40 70 100];
            events(1).duration = 20;

            [X, names] = pf2_base.fnirs.buildDesignMatrix(testCase.time, testCase.fs, events);

            testCase.verifyEqual(size(X, 1), testCase.T, ...
                'Design matrix should have T rows');
            % 1 condition + 4 drift (constant + linear + quad + cubic) = 5
            testCase.verifyEqual(size(X, 2), 5, ...
                'Should have 1 stim + 4 drift columns');
            testCase.verifyEqual(length(names), size(X, 2), ...
                'Names should match column count');
        end

        function testMultipleConditions(testCase)
            events(1).name = 'TaskA';
            events(1).onsets = [10 50 90];
            events(1).duration = 15;
            events(2).name = 'TaskB';
            events(2).onsets = [30 70 110];
            events(2).duration = 15;

            [X, names] = pf2_base.fnirs.buildDesignMatrix(testCase.time, testCase.fs, events);

            % 2 conditions + 4 drift = 6
            testCase.verifyEqual(size(X, 2), 6);
            testCase.verifyEqual(names{1}, 'TaskA');
            testCase.verifyEqual(names{2}, 'TaskB');
        end

        function testWithDerivatives(testCase)
            events(1).name = 'TaskA';
            events(1).onsets = [10 50];
            events(1).duration = 20;

            [X, names] = pf2_base.fnirs.buildDesignMatrix(testCase.time, testCase.fs, events, ...
                'IncludeDerivative', true, 'IncludeDispersion', true);

            % 1 condition * 3 (primary + deriv + disp) + 4 drift = 7
            testCase.verifyEqual(size(X, 2), 7);
            testCase.verifyTrue(any(contains(names, 'deriv')));
            testCase.verifyTrue(any(contains(names, 'disp')));
        end

        function testShortChannelColumns(testCase)
            events(1).name = 'TaskA';
            events(1).onsets = [10];
            events(1).duration = 20;

            shortCh = randn(testCase.T, 3);  % 3 short channels

            [X, names] = pf2_base.fnirs.buildDesignMatrix(testCase.time, testCase.fs, events, ...
                'ShortChannels', shortCh);

            % 1 condition + 4 drift + 3 short = 8
            testCase.verifyEqual(size(X, 2), 8);
            testCase.verifyEqual(sum(contains(names, 'short_ch')), 3);
        end

        function testNoDriftRegressors(testCase)
            events(1).name = 'TaskA';
            events(1).onsets = [10];
            events(1).duration = 20;

            [X, ~] = pf2_base.fnirs.buildDesignMatrix(testCase.time, testCase.fs, events, ...
                'DriftOrder', -1);

            testCase.verifyEqual(size(X, 2), 1, ...
                'With DriftOrder=-1, only stimulus columns');
        end

        function testHRFConvolutionShape(testCase)
            % Convolved regressor should peak after stimulus onset
            events(1).name = 'TaskA';
            events(1).onsets = 50;
            events(1).duration = 0;  % Impulse

            [X, ~] = pf2_base.fnirs.buildDesignMatrix(testCase.time, testCase.fs, events, ...
                'DriftOrder', -1);

            stimCol = X(:, 1);
            [~, peakIdx] = max(stimCol);
            peakTime = testCase.time(peakIdx);

            testCase.verifyGreaterThan(peakTime, 50, ...
                'HRF peak should occur after stimulus onset');
            testCase.verifyLessThan(peakTime, 60, ...
                'HRF peak should occur within ~10s of onset');
        end

        function testBoxcarConvolution(testCase)
            % Boxcar stimulus should produce sustained response
            events(1).name = 'TaskA';
            events(1).onsets = 50;
            events(1).duration = 30;

            [X, ~] = pf2_base.fnirs.buildDesignMatrix(testCase.time, testCase.fs, events, ...
                'DriftOrder', -1);

            stimCol = X(:, 1);
            % Response should be sustained during block
            midBlockIdx = round(65 * testCase.fs);
            testCase.verifyGreaterThan(stimCol(midBlockIdx), 0, ...
                'Signal should be positive during block');
        end

        function testImpulseDesign(testCase)
            % Impulse (duration=0) should produce single HRF response
            events(1).name = 'TaskA';
            events(1).onsets = [50 100 150];
            events(1).duration = 0;

            [X, ~] = pf2_base.fnirs.buildDesignMatrix(testCase.time, testCase.fs, events, ...
                'DriftOrder', -1);

            % Should see 3 peaks
            stimCol = X(:, 1);
            testCase.verifyGreaterThan(max(stimCol), 0);
        end

        function testCustomHRF(testCase)
            events(1).name = 'TaskA';
            events(1).onsets = 50;
            events(1).duration = 0;

            customHRF = [0; 0.5; 1; 0.8; 0.3; 0];

            [X, ~] = pf2_base.fnirs.buildDesignMatrix(testCase.time, testCase.fs, events, ...
                'HRF', customHRF, 'DriftOrder', -1);

            testCase.verifyEqual(size(X, 2), 1);
            testCase.verifyGreaterThan(max(X(:, 1)), 0);
        end

    end

    %% fitGLM Tests
    methods (Test)

        function testOLSRecoversBetas(testCase)
            % OLS should recover known betas from synthetic data
            rng(42);

            events(1).name = 'TaskA';
            events(1).onsets = [20 60 100 140 180 220];
            events(1).duration = 20;

            [X, names] = pf2_base.fnirs.buildDesignMatrix(testCase.time, testCase.fs, events);

            % Known betas: TaskA = 2.0, constant ~= 0, drifts ~= 0
            trueBeta = [2.0; zeros(size(X, 2) - 1, 1)];
            trueBeta(end-3) = 0;  % constant

            % Generate clean data
            Y = X * trueBeta;
            % Add small noise
            noise = 0.05 * randn(testCase.T, 1);
            Y = Y + noise;

            results = pf2_base.fnirs.fitGLM(Y, X, names);

            % TaskA beta should be close to 2.0
            testCase.verifyEqual(results.beta(1), 2.0, 'AbsTol', 0.2, ...
                'OLS should recover known beta for TaskA');
        end

        function testOLSOutputStructure(testCase)
            events(1).name = 'TaskA';
            events(1).onsets = [20 60 100];
            events(1).duration = 20;

            [X, names] = pf2_base.fnirs.buildDesignMatrix(testCase.time, testCase.fs, events);
            Y = randn(testCase.T, 4);  % 4 channels

            results = pf2_base.fnirs.fitGLM(Y, X, names);

            testCase.verifySize(results.beta, [size(X, 2), 4]);
            testCase.verifySize(results.tstat, [size(X, 2), 4]);
            testCase.verifySize(results.pval, [size(X, 2), 4]);
            testCase.verifySize(results.se, [size(X, 2), 4]);
            testCase.verifySize(results.residuals, [testCase.T, 4]);
            testCase.verifySize(results.R2, [1, 4]);
            testCase.verifyEqual(results.method, 'OLS');
        end

        function testOLSSignificanceWithSignal(testCase)
            % With strong signal, GLM should detect significance
            rng(42);

            events(1).name = 'TaskA';
            events(1).onsets = [20 60 100 140 180 220];
            events(1).duration = 20;

            [X, names] = pf2_base.fnirs.buildDesignMatrix(testCase.time, testCase.fs, events);

            trueBeta = zeros(size(X, 2), 1);
            trueBeta(1) = 5.0;  % Strong task effect

            Y = X * trueBeta + 0.1 * randn(testCase.T, 1);
            results = pf2_base.fnirs.fitGLM(Y, X, names);

            testCase.verifyLessThan(results.pval(1), 0.001, ...
                'Strong signal should yield significant p-value');
        end

        function testOLSNoSignificanceWithNoise(testCase)
            % Pure noise should not show significance
            rng(42);

            events(1).name = 'TaskA';
            events(1).onsets = [20 60 100];
            events(1).duration = 20;

            [X, names] = pf2_base.fnirs.buildDesignMatrix(testCase.time, testCase.fs, events);
            Y = randn(testCase.T, 1);

            results = pf2_base.fnirs.fitGLM(Y, X, names);

            % Not guaranteed to fail, but unlikely to be very significant
            testCase.verifyGreaterThan(results.pval(1), 0.001, ...
                'Pure noise should not yield highly significant p-value');
        end

        function testContrastTesting(testCase)
            % Contrast should test difference between conditions
            rng(42);

            events(1).name = 'TaskA';
            events(1).onsets = [20 80 140 200];
            events(1).duration = 20;
            events(2).name = 'TaskB';
            events(2).onsets = [50 110 170 230];
            events(2).duration = 20;

            [X, names] = pf2_base.fnirs.buildDesignMatrix(testCase.time, testCase.fs, events);

            % TaskA = 3.0, TaskB = 1.0
            trueBeta = zeros(size(X, 2), 1);
            trueBeta(1) = 3.0;
            trueBeta(2) = 1.0;

            Y = X * trueBeta + 0.1 * randn(testCase.T, 1);

            % Contrast: TaskA - TaskB
            C = zeros(1, size(X, 2));
            C(1) = 1; C(2) = -1;

            results = pf2_base.fnirs.fitGLM(Y, X, names, ...
                'Contrasts', C, 'ContrastNames', {'A_vs_B'});

            testCase.verifyTrue(isfield(results, 'contrast'));
            testCase.verifyEqual(results.contrast.beta, 2.0, 'AbsTol', 0.3, ...
                'Contrast A-B should be ~2.0');
            testCase.verifyLessThan(results.contrast.pval, 0.001, ...
                'Contrast should be significant');
            testCase.verifyEqual(results.contrast.names{1}, 'A_vs_B');
        end

        function testMultipleContrasts(testCase)
            events(1).name = 'TaskA';
            events(1).onsets = [20 80 140];
            events(1).duration = 20;
            events(2).name = 'TaskB';
            events(2).onsets = [50 110 170];
            events(2).duration = 20;

            [X, names] = pf2_base.fnirs.buildDesignMatrix(testCase.time, testCase.fs, events);
            Y = randn(testCase.T, 2);

            C = zeros(2, size(X, 2));
            C(1, 1) = 1; C(1, 2) = -1;  % A vs B
            C(2, 1) = 1; C(2, 2) = 1;   % A + B (mean)

            results = pf2_base.fnirs.fitGLM(Y, X, names, 'Contrasts', C);

            testCase.verifySize(results.contrast.beta, [2, 2]);
            testCase.verifySize(results.contrast.pval, [2, 2]);
        end

        function testARIRLSConverges(testCase)
            % AR-IRLS should converge and produce valid results
            rng(42);

            events(1).name = 'TaskA';
            events(1).onsets = [20 60 100 140 180 220];
            events(1).duration = 20;

            [X, names] = pf2_base.fnirs.buildDesignMatrix(testCase.time, testCase.fs, events);

            trueBeta = zeros(size(X, 2), 1);
            trueBeta(1) = 3.0;

            % Add AR(1) noise to simulate autocorrelated fNIRS
            noise = zeros(testCase.T, 1);
            noise(1) = randn;
            for t = 2:testCase.T
                noise(t) = 0.8 * noise(t-1) + randn;
            end
            Y = X * trueBeta + 0.3 * noise;

            results = pf2_base.fnirs.fitGLM(Y, X, names, 'Method', 'AR-IRLS');

            testCase.verifyEqual(results.method, 'AR-IRLS');
            testCase.verifyEqual(results.beta(1), 3.0, 'AbsTol', 0.5, ...
                'AR-IRLS should recover beta with autocorrelated noise');
        end

        function testARIRLSMultiChannel(testCase)
            rng(42);

            events(1).name = 'TaskA';
            events(1).onsets = [20 60 100];
            events(1).duration = 20;

            [X, names] = pf2_base.fnirs.buildDesignMatrix(testCase.time, testCase.fs, events);
            Y = randn(testCase.T, 3);

            results = pf2_base.fnirs.fitGLM(Y, X, names, 'Method', 'AR-IRLS');

            testCase.verifySize(results.beta, [size(X, 2), 3]);
            testCase.verifySize(results.residuals, [testCase.T, 3]);
        end

        function testR2Range(testCase)
            % R2 should be between 0 and 1 for well-conditioned problems
            rng(42);

            events(1).name = 'TaskA';
            events(1).onsets = [20 60 100 140 180];
            events(1).duration = 20;

            [X, names] = pf2_base.fnirs.buildDesignMatrix(testCase.time, testCase.fs, events);

            trueBeta = zeros(size(X, 2), 1);
            trueBeta(1) = 3.0;
            Y = X * trueBeta + 0.5 * randn(testCase.T, 1);

            results = pf2_base.fnirs.fitGLM(Y, X, names);

            testCase.verifyGreaterThanOrEqual(results.R2, 0);
            testCase.verifyLessThanOrEqual(results.R2, 1);
        end

        function testDOFCalculation(testCase)
            events(1).name = 'TaskA';
            events(1).onsets = [20 60];
            events(1).duration = 20;

            [X, names] = pf2_base.fnirs.buildDesignMatrix(testCase.time, testCase.fs, events);
            Y = randn(testCase.T, 1);

            results = pf2_base.fnirs.fitGLM(Y, X, names);

            testCase.verifyEqual(results.dof, testCase.T - size(X, 2), ...
                'DOF should be T - P for OLS');
        end

        function testSizeMismatchError(testCase)
            events(1).name = 'TaskA';
            events(1).onsets = [20];
            events(1).duration = 20;

            [X, names] = pf2_base.fnirs.buildDesignMatrix(testCase.time, testCase.fs, events);
            Y = randn(testCase.T + 10, 1);  % Wrong size

            testCase.verifyError(@() pf2_base.fnirs.fitGLM(Y, X, names), ...
                'pf2:fitGLM:sizeMismatch');
        end

    end

end
