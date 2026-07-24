classdef GLMEnhancementsTest < matlab.unittest.TestCase
    % GLMENHANCEMENTSTEST Unit tests for GLM/design-matrix/AR enhancements
    %
    %   Covers: the single-gamma HRF variant (buildHRF), the FIR basis and its
    %   derivative guard, near-singular/rank-deficient FIR designs, and the
    %   amplitude/duration-ignored warning (buildDesignMatrix); automatic
    %   AR-order selection, rank-deficient degrees-of-freedom handling, and
    %   OLS/AROrder interaction in fitGLM; and BIC order selection in Granger
    %   causality.
    %
    %   Example:
    %       results = runtests('pf2_base.tests.unit.GLMEnhancementsTest');
    %
    %   See also: pf2_base.fnirs.buildHRF, pf2_base.fnirs.buildDesignMatrix,
    %             pf2_base.fnirs.fitGLM, exploreFNIRS.coupling.granger

    methods (Test)
        function singleGammaDiffersFromCanonicalAndPeaksAtOne(testCase)
            fs = 10; dur = 32;   % buildHRF's t argument is a scalar duration
            hrfC = pf2_base.fnirs.buildHRF(fs, dur);
            hrfG = pf2_base.fnirs.buildHRF(fs, dur, 'Basis', 'singlegamma');
            % HRF value is column 2 (column 1 is time)
            testCase.verifyEqual(max(hrfG(:,2)), 1, 'AbsTol', 1e-6, ...
                'single-gamma HRF should be peak-normalised to 1');
            testCase.verifyGreaterThan(max(abs(hrfG(:,2) - hrfC(:,2))), 1e-3, ...
                'single-gamma should differ from the canonical double-gamma HRF');
            % Single-gamma has no post-stimulus undershoot
            testCase.verifyGreaterThanOrEqual(min(hrfG(:,2)), -1e-6);
            % 'glover' is accepted as a deprecated alias -> identical output
            hrfAlias = pf2_base.fnirs.buildHRF(fs, dur, 'Basis', 'glover');
            testCase.verifyEqual(hrfAlias, hrfG, 'AbsTol', 0);
        end

        function firBasisPlacesStickRegressors(testCase)
            fs = 4; time = (0:1/fs:120)';
            events(1).name = 'Task';
            events(1).onsets = [10 40 70 100];
            [X, names] = pf2_base.fnirs.buildDesignMatrix(time, fs, events, ...
                'Basis', 'fir', 'FIRWindow', 20, 'DriftOrder', 0, 'IncludeConstant', false);
            nStick = round(20*fs) + 1;
            firCols = sum(contains(names, '_fir'));
            testCase.verifyEqual(firCols, nStick, ...
                'FIR should place round(FIRWindow*fs)+1 stick regressors per condition');
            testCase.verifyEqual(size(X, 2), numel(names));
        end

        function firWithDerivativeErrors(testCase)
            fs = 4; time = (0:1/fs:120)';
            events(1).name = 'Task';
            events(1).onsets = [10 40];
            testCase.verifyError(@() pf2_base.fnirs.buildDesignMatrix(time, fs, events, ...
                'Basis', 'fir', 'IncludeDerivative', true), ...
                'pf2:buildDesignMatrix:firWithDerivative');
        end

        function autoAROrderRecordsScalar(testCase)
            rng(5);
            fs = 8; T = 800; time = (0:T-1)'/fs;
            events(1).name = 'Task';
            events(1).onsets = 20:40:200;
            events(1).duration = 10;
            [X, names] = pf2_base.fnirs.buildDesignMatrix(time, fs, events, 'DriftOrder', 1);
            beta = zeros(size(X,2), 1); beta(1) = 1;
            % AR(1) coloured residuals
            e = zeros(T,1); for k = 2:T, e(k) = 0.6*e(k-1) + 0.3*randn; end
            Y = X*beta + e;
            res = pf2_base.fnirs.fitGLM(Y, X, names, 'Method', 'AR-IRLS', ...
                'AROrder', 'auto', 'fs', fs);
            testCase.verifyTrue(isfield(res, 'arOrder'));
            testCase.verifyTrue(isscalar(res.arOrder));
            testCase.verifyGreaterThanOrEqual(res.arOrder, 1);
        end

        function autoAROrderRequiresFs(testCase)
            rng(5);
            T = 400; X = [ones(T,1), randn(T,1)]; Y = X*[1;0.5] + 0.1*randn(T,1);
            testCase.verifyError(@() pf2_base.fnirs.fitGLM(Y, X, {'const','task'}, ...
                'Method', 'AR-IRLS', 'AROrder', 'auto'), ...
                'pf2:fitGLM:autoOrderNeedsFs');
        end

        function firNearSingularWarnsWhenRecordingShorterThanSticks(testCase)
            % T < nSticks is the worst case for the FIR condition-number
            % guard (guaranteed rank-deficient); the guard must not be
            % skipped in this regime.
            fs = 4; time = (0:1/fs:5)';           % T = 21 samples
            events(1).name = 'Task';
            events(1).onsets = 1;                  % single onset near t=0
            testCase.verifyWarning(@() pf2_base.fnirs.buildDesignMatrix(time, fs, events, ...
                'Basis', 'fir', 'FIRWindow', 20, 'DriftOrder', -1, 'IncludeConstant', false), ...
                'pf2:buildDesignMatrix:firNearSingular');
        end

        function firIgnoresAmplitudeWarnsOnNonDefaultAmplitude(testCase)
            fs = 4; time = (0:1/fs:120)';
            events(1).name = 'Task';
            events(1).onsets = [10 40 70];
            events(1).duration = 0;
            events(1).amplitude = 2;   % non-default: silently inapplicable to FIR
            testCase.verifyWarning(@() pf2_base.fnirs.buildDesignMatrix(time, fs, events, ...
                'Basis', 'fir', 'FIRWindow', 10), ...
                'pf2:buildDesignMatrix:firIgnoresAmplitude');
        end

        function rankDeficientDesignYieldsNonNegativeDoF(testCase)
            % T=20, P=25: a generic random design is (row-)rank 20, so it is
            % guaranteed column-rank-deficient (P > T). The old dof = T - P
            % formula gave dof = -5 with no warning; effective-rank dof must
            % be clamped to >= 1, with NaN t/p rather than a negative dof.
            rng(11);
            T = 20; P = 25;
            X = randn(T, P);
            Y = randn(T, 3);
            names = arrayfun(@(k) sprintf('reg%d', k), 1:P, 'UniformOutput', false);

            testCase.verifyWarning(@() pf2_base.fnirs.fitGLM(Y, X, names), ...
                'pf2:fitGLM:rankDeficient');

            res = pf2_base.fnirs.fitGLM(Y, X, names);
            testCase.verifyGreaterThanOrEqual(res.dof, 1);
            testCase.verifyTrue(all(isnan(res.tstat(:))));
            testCase.verifyTrue(all(isnan(res.pval(:))));
        end

        function olsWithAutoAROrderDoesNotError(testCase)
            % AROrder only configures AR-IRLS prewhitening; Method='OLS'
            % with AROrder='auto' (and no 'fs') used to hit
            % pf2:fitGLM:autoOrderNeedsFs. It must now warn-and-ignore
            % instead of erroring.
            rng(3);
            T = 50; X = [ones(T,1), randn(T,1)]; Y = X*[1;0.5] + 0.1*randn(T,1);
            names = {'const', 'task'};

            testCase.verifyWarning(@() pf2_base.fnirs.fitGLM(Y, X, names, ...
                'Method', 'OLS', 'AROrder', 'auto'), ...
                'pf2:fitGLM:arOrderIgnored');

            res = pf2_base.fnirs.fitGLM(Y, X, names, 'Method', 'OLS', 'AROrder', 'auto');
            testCase.verifyEqual(res.method, 'OLS');
            testCase.verifyFalse(isfield(res, 'arOrder'));
        end

        function grangerAutoOrderReturnsScalar(testCase)
            rng(9);
            fs = 8; T = 1000; t = (0:T-1)'/fs;
            x = 0.5*randn(T,1);
            y = [0; x(1:end-1)] + 0.3*randn(T,1);   % y driven by lagged x
            res = exploreFNIRS.coupling.granger(x, y, fs, 'ModelOrder', 'auto');
            testCase.verifyTrue(isfield(res, 'modelOrder'));
            testCase.verifyTrue(isscalar(res.modelOrder));
            testCase.verifyGreaterThanOrEqual(res.modelOrder, 1);
        end
    end
end
