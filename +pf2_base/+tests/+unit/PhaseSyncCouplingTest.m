classdef PhaseSyncCouplingTest < matlab.unittest.TestCase
    % PHASESYNCCOUPLINGTEST Unit tests for phase-synchronization coupling measures
    %
    %   Verifies the phase-based coupling functions added to
    %   +exploreFNIRS/+coupling: plv, imagCoherence, wpli, and the within-
    %   subject surrogateTest helper, plus their dispatch through computeDyad.
    %   Imaginary coherence and wPLI must be insensitive to zero-lag coupling
    %   while responding to a genuine phase-lagged relationship.
    %
    %   Also covers regression tests for three fixed bugs: surrogateTest
    %   returning a finite p-value when a signal has an interior NaN sample
    %   (both signals are NaN-filled before any FFT-based step); wpli's
    %   'Debiased' estimator naming (Debiased=true -> 'debiased-squared-wpli',
    %   Debiased=false -> ordinary magnitude 'wpli' in [0, 1]); and granger's
    %   F-test denominator degrees of freedom (nObs - 2*order, no spurious
    %   intercept term subtracted).
    %
    %   Example:
    %       results = runtests('pf2_base.tests.unit.PhaseSyncCouplingTest');
    %
    %   See also: exploreFNIRS.coupling.plv, exploreFNIRS.coupling.imagCoherence,
    %             exploreFNIRS.coupling.wpli, exploreFNIRS.coupling.surrogateTest,
    %             exploreFNIRS.coupling.granger

    properties
        fs = 8
        x, ySame, yLag
    end

    methods (TestClassSetup)
        function requireSPT(testCase)
            testCase.assumeTrue(~isempty(which('cpsd')) && ~isempty(which('butter')), ...
                'Signal Processing Toolbox required for phase-sync measures.');
        end
        function build(testCase)
            rng(3);
            T = 1200; t = (0:T-1)'/testCase.fs;
            testCase.x = sin(2*pi*0.1*t) + 0.5*sin(2*pi*0.03*t) + 0.05*randn(T,1);
            testCase.ySame = testCase.x;                                  % zero-lag identical
            testCase.yLag  = sin(2*pi*0.1*t + pi/2) + 0.5*sin(2*pi*0.03*t + pi/2) ...
                + 0.05*randn(T,1);                                        % 90 deg lag
        end
    end

    methods (Test)
        function plvIdenticalIsOne(testCase)
            r = exploreFNIRS.coupling.plv(testCase.x, testCase.ySame, testCase.fs, ...
                'FreqRange', [0.05 0.2]);
            testCase.verifyGreaterThan(r.value, 0.99);
            testCase.verifyEqual(r.method, 'plv');
            testCase.verifyTrue(isnan(r.pvalue));
            testCase.verifyFalse(r.windowed);
        end

        function imagCoherenceZeroLagIsSmall(testCase)
            r = exploreFNIRS.coupling.imagCoherence(testCase.x, testCase.ySame, testCase.fs, ...
                'FreqRange', [0.05 0.2]);
            testCase.verifyLessThan(r.value, 0.05, 'iCoh must be ~0 for zero-lag');
        end

        function imagCoherenceDetectsLag(testCase)
            r = exploreFNIRS.coupling.imagCoherence(testCase.x, testCase.yLag, testCase.fs, ...
                'FreqRange', [0.05 0.2]);
            testCase.verifyGreaterThan(r.value, 0.1, 'iCoh must respond to a phase lag');
        end

        function wpliZeroLagIsSmall(testCase)
            r = exploreFNIRS.coupling.wpli(testCase.x, testCase.ySame, testCase.fs, ...
                'FreqRange', [0.05 0.2]);
            testCase.verifyLessThan(r.value, 0.1, 'wPLI must be ~0 for zero-lag');
            testCase.verifyEqual(r.method, 'wpli');
        end

        function returnStructHasStandardFields(testCase)
            r = exploreFNIRS.coupling.imagCoherence(testCase.x, testCase.yLag, testCase.fs);
            for f = {'value','pvalue','method','windowed','freqRange'}
                testCase.verifyTrue(isfield(r, f{1}), sprintf('missing field %s', f{1}));
            end
        end

        function surrogateTestReturnsPValue(testCase)
            sr = exploreFNIRS.coupling.surrogateTest(@exploreFNIRS.coupling.plv, ...
                testCase.x, testCase.yLag, testCase.fs, 'Permutations', 100);
            testCase.verifyGreaterThanOrEqual(sr.pvalue, 0);
            testCase.verifyLessThanOrEqual(sr.pvalue, 1);
            testCase.verifyTrue(isfinite(sr.observed));
        end

        function surrogateTestHandlesInteriorNaN(testCase)
            % A single missing sample must not poison the whole null
            % distribution: both x and y are NaN-filled up front (matching
            % plv/imagCoherence/wpli), so the observed statistic, the
            % autocorrelation-length FFT, and every surrogate draw are all
            % computed on a fully finite signal.
            yWithNaN = testCase.yLag;
            yWithNaN(600) = NaN;   % interior sample, not an edge case
            sr = exploreFNIRS.coupling.surrogateTest(@exploreFNIRS.coupling.plv, ...
                testCase.x, yWithNaN, testCase.fs, 'Permutations', 50);
            testCase.verifyTrue(isfinite(sr.observed), ...
                'observed statistic must be finite with a single interior NaN');
            testCase.verifyTrue(isfinite(sr.pvalue), ...
                'p-value must be finite (not NaN) with a single interior NaN sample');
            testCase.verifyGreaterThanOrEqual(sr.pvalue, 0);
            testCase.verifyLessThanOrEqual(sr.pvalue, 1);
            testCase.verifyEqual(sr.nPerms, 50);
        end

        function wpliDebiasedFalseReturnsMagnitudeEstimator(testCase)
            % Debiased=false must be ordinary MAGNITUDE wPLI in [0, 1]
            % (absolute value in the numerator), not a signed ratio.
            rMag = exploreFNIRS.coupling.wpli(testCase.x, testCase.yLag, testCase.fs, ...
                'FreqRange', [0.05 0.2], 'Debiased', false);
            testCase.verifyEqual(rMag.estimator, 'wpli');
            testCase.verifyGreaterThanOrEqual(rMag.value, 0);
            testCase.verifyLessThanOrEqual(rMag.value, 1);

            % Default (Debiased=true) is the debiased estimator of SQUARED
            % wPLI (Vinck 2011 Eq. 9) -- a distinct scale, labeled explicitly.
            rDebiased = exploreFNIRS.coupling.wpli(testCase.x, testCase.yLag, testCase.fs, ...
                'FreqRange', [0.05 0.2]);
            testCase.verifyEqual(rDebiased.estimator, 'debiased-squared-wpli');
        end

        function grangerFTestUsesCorrectedDof(testCase)
            % Neither the restricted (order params) nor unrestricted
            % (2*order params) AR model fits an intercept, so dfDen must be
            % nObs - 2*order, NOT nObs - 2*order - 1.
            rng(11);
            T = 60; order = 4;
            xg = randn(T, 1);
            yg = randn(T, 1);
            r = exploreFNIRS.coupling.granger(xg, yg, testCase.fs, 'ModelOrder', order);

            nObs = T - order;
            expectedDfDen = nObs - 2 * order;
            expectedPval = 1 - fcdf(r.value, order, expectedDfDen);
            testCase.verifyEqual(r.pvalue, expectedPval, 'AbsTol', 1e-10, ...
                'pvalue must match the F-distribution with corrected dfDen = nObs - 2*order');

            buggyDfDen = expectedDfDen - 1;
            buggyPval = 1 - fcdf(r.value, order, buggyDfDen);
            testCase.verifyNotEqual(r.pvalue, buggyPval, ...
                'pvalue must NOT match the old dfDen = nObs - 2*order - 1 convention');
        end

        function computeDyadDispatchesNewMethods(testCase)
            A = makeSubject(testCase, 5);
            B = makeSubject(testCase, 7);
            for m = {'plv','imagcoherence','wpli'}
                res = exploreFNIRS.hyperscanning.computeDyad(A, B, ...
                    'Method', m{1}, 'Biomarker', 'HbO', 'ChannelPairing', 'same');
                testCase.verifyNotEmpty(res.values, sprintf('%s produced no values', m{1}));
            end
        end
    end
end

function s = makeSubject(testCase, seed)
% MAKESUBJECT Minimal processed-like fNIRS struct for computeDyad dispatch
rng(seed);
T = 800; nCh = 3;
s.time = (0:T-1)'/testCase.fs;
s.fs = testCase.fs;
s.fchMask = ones(1, nCh);
t = s.time;
s.HbO = sin(2*pi*0.1*t) + 0.1*randn(T, nCh);
s.HbR = -0.3*s.HbO + 0.05*randn(T, nCh);
s.info.SubjectID = sprintf('S%d', seed);
end
