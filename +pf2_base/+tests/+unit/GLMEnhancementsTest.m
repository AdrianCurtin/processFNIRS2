classdef GLMEnhancementsTest < matlab.unittest.TestCase
    % GLMENHANCEMENTSTEST Unit tests for GLM/design-matrix/AR enhancements
    %
    %   Covers: the single-gamma HRF variant (buildHRF), the FIR basis and its
    %   derivative guard, near-singular/rank-deficient FIR designs, and the
    %   amplitude/duration-ignored warning (buildDesignMatrix); automatic
    %   AR-order selection, rank-deficient degrees-of-freedom handling,
    %   estimability of individual coefficients/contrasts under a
    %   rank-deficient design with POSITIVE dof, and OLS/AROrder interaction
    %   in fitGLM; and BIC order selection in Granger causality.
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

        function rankDeficientWithPositiveDofYieldsNonEstimableCoefNaN(testCase)
            % Two identical columns among several well-conditioned regressors
            % make the design rank-deficient (rank = P-1) WITHOUT driving dof
            % to <= 0 (T >> P here), so the existing dofInvalid path (dof<=0)
            % does not catch this case. Before the fix, pinv(X'*X) still
            % returned a finite (but not statistically meaningful) variance
            % for the aliased columns, so both aliased coefficients got
            % finite SE/t/p. Non-estimable coefficients/contrasts must be
            % NaN'd via the null-space test regardless of dof.
            rng(7);
            T = 200;
            constCol = ones(T, 1);
            dupCol = randn(T, 1);
            indepCol = randn(T, 1);
            X = [constCol, dupCol, dupCol, indepCol];   % col2 == col3 (aliased)
            names = {'const', 'dupA', 'dupB', 'indepTask'};

            % Only const, (dupA+dupB), and indepTask are identifiable; dupA
            % and dupB individually are not, so their true betas are moot.
            trueBeta = [0.5; 0; 0; 2.0];
            Y = X * trueBeta + 0.1 * randn(T, 1);

            C = [0 1 -1 0;   % non-estimable: difference of the aliased pair
                 0 0  0 1];  % estimable: isolates indepTask
            contrastNames = {'dupDiff', 'indepEffect'};

            testCase.verifyWarning(@() pf2_base.fnirs.fitGLM(Y, X, names, ...
                'Contrasts', C, 'ContrastNames', contrastNames), ...
                'pf2:fitGLM:rankDeficient');

            res = pf2_base.fnirs.fitGLM(Y, X, names, ...
                'Contrasts', C, 'ContrastNames', contrastNames);

            testCase.verifyGreaterThan(res.dof, 0, ...
                'This design has T >> P, so dof should be comfortably positive');

            % (b) aliased coefficients (dupA, dupB) are non-estimable -> NaN
            testCase.verifyTrue(all(isnan(res.tstat(2:3, :))), ...
                'Aliased coefficients should have NaN tstat');
            testCase.verifyTrue(all(isnan(res.pval(2:3, :))), ...
                'Aliased coefficients should have NaN pval');

            % (c) estimable coefficients (const, indepTask) remain finite
            testCase.verifyTrue(all(isfinite(res.tstat([1 4], :))), ...
                'Estimable coefficients should have finite tstat');
            testCase.verifyTrue(all(isfinite(res.pval([1 4], :))), ...
                'Estimable coefficients should have finite pval');

            % (d) contrasts: the aliased-pair difference is non-estimable
            % (NaN); a contrast over an estimable column is finite
            testCase.verifyTrue(isnan(res.contrast.tstat(1)), ...
                'Contrast isolating the aliased-pair difference should be NaN');
            testCase.verifyTrue(isnan(res.contrast.pval(1)));
            testCase.verifyTrue(isfinite(res.contrast.tstat(2)), ...
                'Contrast over an estimable column should be finite');
            testCase.verifyTrue(isfinite(res.contrast.pval(2)));
        end

        function fullRankSiblingOfRankDeficientDesignStaysAllFinite(testCase)
            % Regression guard: dropping the duplicate column from the
            % rank-deficient design above must NOT warn and must leave every
            % coefficient/contrast stat finite (r == P -> null space empty ->
            % nothing NaN'd).
            rng(7);
            T = 200;
            constCol = ones(T, 1);
            dupCol = randn(T, 1);
            indepCol = randn(T, 1);
            X = [constCol, dupCol, indepCol];   % full column rank (3 unique cols)
            names = {'const', 'dupA', 'indepTask'};

            trueBeta = [0.5; 1.0; 2.0];
            Y = X * trueBeta + 0.1 * randn(T, 1);

            C = [0 1 0];
            testCase.verifyWarningFree(@() pf2_base.fnirs.fitGLM(Y, X, names, ...
                'Contrasts', C));

            res = pf2_base.fnirs.fitGLM(Y, X, names, 'Contrasts', C);
            testCase.verifyTrue(all(isfinite(res.tstat(:))));
            testCase.verifyTrue(all(isfinite(res.pval(:))));
            testCase.verifyTrue(all(isfinite(res.contrast.tstat(:))));
            testCase.verifyTrue(all(isfinite(res.contrast.pval(:))));
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

        function estimabilityDetectedUnderRescaling(testCase)
            % A rank-deficient design scaled up by a huge factor must STILL
            % flag its aliased coefficients: the null-space entry test uses a
            % dimensionless tolerance, so it does not degrade when the matrix
            % scale (and null()'s own singular-value tolerance) blows up.
            rng(11); T = 200;
            c = ones(T,1); d = randn(T,1); ind = randn(T,1);
            X = [c, d, d, ind];   % col2 == col3 (aliased)
            names = {'const','dupA','dupB','indep'};
            Y = X*[0.5;0;0;2] + 0.1*randn(T,1);
            res = pf2_base.fnirs.fitGLM(Y, X*1e15, names);
            testCase.verifyTrue(all(isnan(res.tstat(2:3, :))), ...
                'Aliased coefficients must stay NaN even with the design rescaled 1e15');
            testCase.verifyTrue(all(isfinite(res.tstat([1 4], :))), ...
                'Estimable coefficients must remain finite under rescaling');
        end

        function nonEstimableContrastHasNaNStandardError(testCase)
            % A non-estimable contrast must NaN its standard error too, not
            % just its t-statistic and p-value.
            rng(12); T = 200;
            c = ones(T,1); d = randn(T,1); ind = randn(T,1);
            X = [c, d, d, ind];
            names = {'const','dupA','dupB','indep'};
            Y = X*[0.5;0;0;2] + 0.1*randn(T,1);
            C = [0 1 -1 0;   % non-estimable: difference of the aliased pair
                 0 0  0 1];  % estimable
            res = pf2_base.fnirs.fitGLM(Y, X, names, 'Contrasts', C, ...
                'ContrastNames', {'dupDiff','indep'});
            testCase.verifyTrue(isnan(res.contrast.se(1)), ...
                'SE of a non-estimable contrast must be NaN');
            testCase.verifyTrue(isfinite(res.contrast.se(2)), ...
                'SE of an estimable contrast must be finite');
        end
    end
end
