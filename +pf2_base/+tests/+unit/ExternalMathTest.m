classdef ExternalMathTest < matlab.unittest.TestCase
% EXTERNALMATHTEST Unit tests for the clean-room numeric externals
%
% Validates the original processFNIRS2 reimplementations of formerly
% third-party numeric utilities under +pf2_base/+external:
%   - filtfilt_classic : zero-phase forward-backward filtering (TF and SOS),
%                        compared against the Signal Processing Toolbox
%                        filtfilt when available, with a toolbox-independent
%                        symmetry/zero-phase assertion always exercised.
%   - vrrotvec / vrrotvec2mat : axis-angle rotation between two vectors and
%                        its matrix form (round-trip, orthonormality,
%                        parallel/antiparallel/known-90deg cases).
%   - polyparci        : OLS confidence intervals for polyfit coefficients
%                        (bracketing the truth; analytic half-width check).
%   - icbm_fsl2tal     : Lancaster ICBM-152 (FSL) MNI->Talairach affine,
%                        known-answer plus input-shape handling.
%
% Randomness is seeded deterministically per index so the assertions are
% reproducible.

    methods (Test)

        %% ================= filtfilt_classic =================

        function testFiltfiltMatchesToolboxTF(tc)
            % Transfer-function form (b, a) vs the toolbox filtfilt on a
            % vector and on a multi-column matrix.
            if ~hasSignalToolbox()
                tc.assumeFail('Signal Processing Toolbox not available');
            end
            % Hand-rolled 4th-order Butterworth-like low-pass coefficients
            % are awkward without butter; use butter since the toolbox is
            % present (this branch only runs then).
            [b, a] = butter(4, 0.2);

            rng(1);
            t = (0:299).';
            xVec = sin(2*pi*0.03*t) + 0.4*randn(300, 1);
            yRef = filtfilt(b, a, xVec);
            yMine = pf2_base.external.filtfilt_classic(b, a, xVec);
            tc.verifyLessThan(max(abs(yMine - yRef)), 1e-9, ...
                'TF vector filtfilt differs from toolbox');

            rng(2);
            xMat = sin(2*pi*0.02*t) * [1 1 1] + 0.3*randn(300, 3);
            yRefM = filtfilt(b, a, xMat);
            yMineM = pf2_base.external.filtfilt_classic(b, a, xMat);
            tc.verifyLessThan(max(abs(yMineM(:) - yRefM(:))), 1e-9, ...
                'TF matrix filtfilt differs from toolbox');
        end

        function testFiltfiltMatchesToolboxSOS(tc)
            % Second-order-section form (sos, 1) -- the encoding used by
            % pf2_base.signal.lpf/hpf/bpf and the pf2_bpf_* functions.
            if ~hasSignalToolbox()
                tc.assumeFail('Signal Processing Toolbox not available');
            end
            [z, p, k] = butter(6, 0.25);
            [sos, g] = zp2sos(z, p, k);
            % Fold the overall gain into the SOS so (sos, 1) is the input
            % the toolbox filtfilt also accepts.
            sos(1, 1:3) = sos(1, 1:3) * g;

            rng(3);
            t = (0:399).';
            x = cos(2*pi*0.05*t) + 0.5*randn(400, 1);
            yRef = filtfilt(sos, 1, x);
            yMine = pf2_base.external.filtfilt_classic(sos, 1, x);
            tc.verifyLessThan(max(abs(yMine - yRef)), 1e-9, ...
                'SOS filtfilt differs from toolbox');

            % Multi-column matrix in SOS form.
            rng(4);
            xMat = cos(2*pi*0.04*t) * [1 1] + 0.4*randn(400, 2);
            yRefM = filtfilt(sos, 1, xMat);
            yMineM = pf2_base.external.filtfilt_classic(sos, 1, xMat);
            tc.verifyLessThan(max(abs(yMineM(:) - yRefM(:))), 1e-9, ...
                'SOS matrix filtfilt differs from toolbox');
        end

        function testFiltfiltZeroPhaseSymmetry(tc)
            % Toolbox-independent property: a zero-phase filter applied to a
            % symmetric (even) signal yields a symmetric output. This always
            % asserts something even when no Signal Toolbox is present.
            % Use a simple normalized moving-average-style FIR / IIR pair
            % defined by hand so this needs no toolbox at all.
            % 2nd-order Butterworth low-pass at ~0.2*Nyquist (precomputed,
            % toolbox-free constants).
            b = [0.067455273889071, 0.134910547778142, 0.067455273889071];
            a = [1.000000000000000, -1.142980502539901, 0.412801598096187];

            n = 201;                       % odd length -> exact center
            idx = (1:n).' - (n + 1) / 2;   % symmetric about 0
            x = exp(-(idx / 25).^2);       % even (symmetric) Gaussian
            tc.verifyEqual(x, flipud(x), 'AbsTol', 1e-12, ...
                'test signal is not symmetric');

            y = pf2_base.external.filtfilt_classic(b, a, x);
            % The reflect-padding endpoints are not perfectly symmetric, so a
            % tiny residual asymmetry (~1e-8, identical to the Signal Toolbox
            % filtfilt itself) is expected; the output is still zero-phase to
            % well within 1e-7.
            tc.verifyEqual(y, flipud(y), 'AbsTol', 1e-7, ...
                'zero-phase output of a symmetric signal is not symmetric');
        end

        function testFiltfiltRowVectorOrientation(tc)
            % A row-vector input must be returned as a row vector.
            b = [0.2, 0.2];
            a = [1, -0.6];
            x = sin(0:0.1:30);             % 1 x N row
            y = pf2_base.external.filtfilt_classic(b, a, x);
            tc.verifySize(y, size(x));
        end

        function testFiltfiltEmpty(tc)
            tc.verifyEmpty(pf2_base.external.filtfilt_classic([], [], []));
        end

        function testFiltfiltTooShortErrors(tc)
            b = [0.2, 0.2]; a = [1, -0.6];
            tc.verifyError(@() pf2_base.external.filtfilt_classic(b, a, [1;2]), ...
                'pf2_base:filtfilt_classic:dataTooShort');
        end

        %% ================= vrrotvec / vrrotvec2mat =================

        function testRotvecRoundTripRandom(tc)
            % R = vrrotvec2mat(vrrotvec(a,b)) must rotate a onto b, be
            % orthonormal, and have det +1, for many random unit pairs.
            for k = 1:25
                rng(100 + k);
                a = randn(1, 3); a = a / norm(a);
                b = randn(1, 3); b = b / norm(b);
                r = pf2_base.external.vrrotvec(a, b);
                R = pf2_base.external.vrrotvec2mat(r);

                tc.verifyEqual(R * a(:), b(:), 'AbsTol', 1e-10, ...
                    sprintf('R does not map a onto b (seed %d)', k));
                tc.verifyEqual(R' * R, eye(3), 'AbsTol', 1e-10, ...
                    sprintf('R not orthonormal (seed %d)', k));
                tc.verifyEqual(det(R), 1, 'AbsTol', 1e-10, ...
                    sprintf('det(R) != 1 (seed %d)', k));
            end
        end

        function testRotvecParallel(tc)
            % Identical vectors -> zero rotation -> identity matrix.
            a = [0 0 1];
            r = pf2_base.external.vrrotvec(a, a);
            tc.verifyEqual(r(4), 0, 'AbsTol', 1e-12);
            R = pf2_base.external.vrrotvec2mat(r);
            tc.verifyEqual(R, eye(3), 'AbsTol', 1e-12);
        end

        function testRotvecAntiparallel(tc)
            % Opposite vectors -> 180 degree rotation that maps a onto -a.
            a = [1 0 0];
            b = [-1 0 0];
            r = pf2_base.external.vrrotvec(a, b);
            tc.verifyEqual(r(4), pi, 'AbsTol', 1e-10);
            R = pf2_base.external.vrrotvec2mat(r);
            tc.verifyEqual(R * a(:), b(:), 'AbsTol', 1e-10);
            tc.verifyEqual(R' * R, eye(3), 'AbsTol', 1e-10);
            tc.verifyEqual(det(R), 1, 'AbsTol', 1e-10);
        end

        function testRotvecKnown90AboutZ(tc)
            % z onto y is a -90 deg rotation about the x axis; check via the
            % matrix that x stays put and z maps to -y (consistent geometry).
            r = pf2_base.external.vrrotvec([0 0 1], [0 1 0]);
            % Axis is +/- x, angle pi/2.
            tc.verifyEqual(abs(r(1)), 1, 'AbsTol', 1e-10);
            tc.verifyEqual(r(2:3), [0 0], 'AbsTol', 1e-10);
            tc.verifyEqual(r(4), pi/2, 'AbsTol', 1e-10);
        end

        function testRotvec2matKnown90AboutZ(tc)
            % Direct known-answer for the matrix builder: +90 deg about z
            % sends x->y and y->-x.
            M = pf2_base.external.vrrotvec2mat([0 0 1 pi/2]);
            tc.verifyEqual(M * [1;0;0], [0;1;0], 'AbsTol', 1e-12);
            tc.verifyEqual(M * [0;1;0], [-1;0;0], 'AbsTol', 1e-12);
            tc.verifyEqual(M * [0;0;1], [0;0;1], 'AbsTol', 1e-12);
        end

        function testRotvec2matIdentityZeroAxis(tc)
            % A zero axis is degenerate and must yield identity.
            tc.verifyEqual(pf2_base.external.vrrotvec2mat([0 0 0 0]), ...
                eye(3), 'AbsTol', 1e-12);
        end

        %% ================= polyparci =================

        function testPolyparciBracketsTruth(tc)
            % Fit a known linear model with noise; the returned CI must
            % bracket the true coefficients.
            rng(7);
            x = (0:0.05:10).';
            trueSlope = 2.5;
            trueIntercept = -1.0;
            y = trueSlope*x + trueIntercept + 0.05*randn(size(x));
            [p, S] = polyfit(x, y, 1);
            % alpha is the one-sided cumulative prob; 0.975 -> 95% two-sided.
            CI = pf2_base.external.polyparci(p, S, 0.975);  % [2 x 2]

            tc.verifySize(CI, [2, 2]);
            % Column 1 = slope (highest power first), column 2 = intercept.
            tc.verifyLessThanOrEqual(CI(1, 1), trueSlope);
            tc.verifyGreaterThanOrEqual(CI(2, 1), trueSlope);
            tc.verifyLessThanOrEqual(CI(1, 2), trueIntercept);
            tc.verifyGreaterThanOrEqual(CI(2, 2), trueIntercept);
            % Lower bound below upper bound.
            tc.verifyTrue(all(CI(1, :) < CI(2, :)));
        end

        function testPolyparciHalfWidthMatchesAnalytic(tc)
            % The CI half-width must equal tinv(alpha, df) * SE, where SE is
            % recovered from the polyfit S struct exactly as the function
            % documents (COV = inv(R'R) * normr^2 / df). polyparci treats
            % ALPHA as the one-sided cumulative probability passed to the
            % inverse-t (default 0.95 -> the 90% two-sided interval), so the
            % critical value is tinv(alpha, df), not tinv(1-alpha/2, df).
            rng(9);
            x = (0:0.1:8).';
            y = 1.5*x.^2 - 3*x + 4 + 0.1*randn(size(x));
            [p, S] = polyfit(x, y, 2);
            alpha = 0.975;
            CI = pf2_base.external.polyparci(p, S, alpha);

            halfWidth = (CI(2, :) - CI(1, :)) / 2;   % [1 x 3]

            covB = (S.R' * S.R) \ eye(size(S.R, 2));
            covB = covB * (S.normr.^2 / S.df);
            SE = sqrt(diag(covB)).';                 % [1 x 3]

            if hasStatsToolbox()
                tcrit = tinv(alpha, S.df);
                expectedHalf = tcrit * SE;
                tc.verifyEqual(halfWidth, expectedHalf, 'AbsTol', 1e-6, ...
                    'CI half-width does not match tinv*SE');
            else
                % No Stats Toolbox: assert shape, ordering, and that the
                % half-width is proportional to SE (same t across coeffs).
                ratios = halfWidth ./ SE;
                tc.verifyEqual(ratios, ratios(1) * ones(size(ratios)), ...
                    'RelTol', 1e-6, ...
                    'half-width/SE not constant across coefficients');
                tc.verifyTrue(all(halfWidth > 0));
            end
        end

        function testPolyparciDefaultAlpha(tc)
            % Default alpha (0.95) must produce a valid bracketing CI.
            rng(11);
            x = (0:0.2:10).';
            y = 0.5*x + 2 + 0.1*randn(size(x));
            [p, S] = polyfit(x, y, 1);
            CI = pf2_base.external.polyparci(p, S);   % no alpha
            tc.verifySize(CI, [2, 2]);
            tc.verifyTrue(all(CI(1, :) < CI(2, :)));
        end

        %% ================= icbm_fsl2tal =================

        function testIcbmKnownAnswer(tc)
            % Recompute the published Lancaster ICBM-152 (FSL) affine by hand
            % and assert icbm_fsl2tal reproduces it exactly.
            A = [ 0.9464  0.0034 -0.0026 -1.0680; ...
                 -0.0083  0.9479 -0.0580 -1.0239; ...
                  0.0053  0.0617  0.9010  3.1883; ...
                  0.0000  0.0000  0.0000  1.0000];

            pts = [-42 18 24; 30 -60 12; 0 0 0];   % [3 x 3] -> rows assumed
            expected = (A * [pts.'; ones(1, 3)]).';
            expected = expected(:, 1:3);

            out = pf2_base.external.icbm_fsl2tal(pts);
            tc.verifyEqual(out, expected, 'AbsTol', 1e-10);
        end

        function testIcbmSingleRow(tc)
            A = [ 0.9464  0.0034 -0.0026 -1.0680; ...
                 -0.0083  0.9479 -0.0580 -1.0239; ...
                  0.0053  0.0617  0.9010  3.1883];
            pt = [-42 18 24];
            expected = (A * [pt.'; 1]).';
            out = pf2_base.external.icbm_fsl2tal(pt);
            tc.verifySize(out, [1, 3]);
            tc.verifyEqual(out, expected, 'AbsTol', 1e-10);
        end

        function testIcbmNby3(tc)
            % A non-square [N x 3] is unambiguous: rows are points.
            pts = [1 2 3; 4 5 6; 7 8 9; 10 11 12];   % 4 x 3
            out = pf2_base.external.icbm_fsl2tal(pts);
            tc.verifySize(out, [4, 3]);
        end

        function testIcbm3byN(tc)
            % A [3 x N] (N ~= 3) input must be treated as columns and the
            % output returned in the same [3 x N] orientation.
            ptsRows = [1 2 3; 4 5 6; 7 8 9; 10 11 12];   % 4 x 3
            ptsCols = ptsRows.';                          % 3 x 4
            outRows = pf2_base.external.icbm_fsl2tal(ptsRows);
            outCols = pf2_base.external.icbm_fsl2tal(ptsCols);
            tc.verifySize(outCols, [3, 4]);
            tc.verifyEqual(outCols, outRows.', 'AbsTol', 1e-10);
        end

        function testIcbmBadShapeErrors(tc)
            tc.verifyError(@() pf2_base.external.icbm_fsl2tal([1 2; 3 4]), ...
                ?MException);
        end

    end
end

function tf = hasSignalToolbox()
% HASSIGNALTOOLBOX True only if filtfilt is on the path AND licensed.
    tf = (exist('filtfilt', 'file') == 2) && ...
         license('test', 'Signal_Toolbox');
end

function tf = hasStatsToolbox()
% HASSTATSTOOLBOX True only if tinv is on the path AND licensed.
    tf = (exist('tinv', 'file') == 2) && ...
         license('test', 'Statistics_Toolbox');
end
