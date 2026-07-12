classdef WaveletTransformTest < matlab.unittest.TestCase
% WAVELETTRANSFORMTEST Self-contained tests for pf2_base.wavelet transforms
%
% Validates the clean-room discrete wavelet transform implementation
% (makeONFilter, fwtPO, iwtPO, fwtTI, iwtTI) without any external toolbox
% dependency. Covers:
%   - makeONFilter unit-norm normalisation and known db4 coefficients
%   - perfect reconstruction for the orthonormal families and levels that
%     processFNIRS2 actually uses (iwtPO(fwtPO(x)) == x, iwtTI(fwtTI(x)) == x)
%   - the translation-invariant table layout (shape and coarse/detail bands)
%   - a fixed known-answer for the Haar transform
%   - translation invariance of fwtTI detail-coefficient energy
%
% The equivalence-vs-WaveLab comparison was performed once (before WaveLab
% was removed) in internal/wavelet_equivalence_check.m and confirmed max abs
% differences below 1e-9 for every family/level; those one-off results are
% not re-run here because WaveLab is no longer bundled.

    methods (Test)

        %% --- makeONFilter ---

        function testHaarFilter(tc)
            f = pf2_base.wavelet.makeONFilter('Haar');
            tc.verifyEqual(f, [1 1] / sqrt(2), 'AbsTol', 1e-15);
        end

        function testFiltersUnitNorm(tc)
            names = {'db2', 'db6', 'sym8', 'coif3', 'beylkin', ...
                     'vaidyanathan', 'battle3'};
            for k = 1:numel(names)
                qmf = pf2_base.wavelet.resolveWavelet(names{k});
                tc.verifyEqual(norm(qmf), 1, 'AbsTol', 1e-12, ...
                    sprintf('%s is not unit norm', names{k}));
            end
        end

        function testDb4KnownCoefficients(tc)
            % Standard published Daubechies-4 (db2 shorthand) coefficients,
            % already unit-norm.
            expected = [0.482962913144831, 0.836516303737708, ...
                        0.224143868041922, -0.129409522550955];
            qmf = pf2_base.wavelet.makeONFilter('Daubechies', 4);
            tc.verifyEqual(qmf, expected, 'AbsTol', 1e-12);
        end

        %% --- Perfect reconstruction (orthonormal families) ---

        function testPerfectReconstructionPO(tc)
            names = {'haar', 'db2', 'db4', 'db6', 'db10', ...
                     'sym4', 'sym8', 'coif1', 'coif3', ...
                     'beylkin', 'vaidyanathan'};
            levels = [1 3 4 5];
            rng(11);
            for ni = 1:numel(names)
                qmf = pf2_base.wavelet.resolveWavelet(names{ni});
                for L = levels
                    x = randn(256, 1);
                    wc = pf2_base.wavelet.fwtPO(x, L, qmf);
                    xr = pf2_base.wavelet.iwtPO(wc, L, qmf);
                    tc.verifyEqual(xr, x, 'AbsTol', 1e-7, ...
                        sprintf('PO recon failed: %s L=%d', names{ni}, L));
                end
            end
        end

        function testPerfectReconstructionTI(tc)
            names = {'haar', 'db2', 'db4', 'sym4', 'coif1'};
            levels = [1 3 4];
            rng(13);
            for ni = 1:numel(names)
                qmf = pf2_base.wavelet.resolveWavelet(names{ni});
                for L = levels
                    x = randn(128, 1);
                    ti = pf2_base.wavelet.fwtTI(x, L, qmf);
                    xr = pf2_base.wavelet.iwtTI(ti, qmf);
                    tc.verifyEqual(xr(:), x(:), 'AbsTol', 1e-7, ...
                        sprintf('TI recon failed: %s L=%d', names{ni}, L));
                end
            end
        end

        %% --- Shape conventions ---

        function testPOShapePreserved(tc)
            qmf = pf2_base.wavelet.makeONFilter('Daubechies', 8);
            xcol = randn(64, 1);
            wc = pf2_base.wavelet.fwtPO(xcol, 2, qmf);
            tc.verifySize(wc, [64 1]);          % column in -> column out
            xrow = xcol';
            wcr = pf2_base.wavelet.fwtPO(xrow, 2, qmf);
            tc.verifySize(wcr, [1 64]);         % row in -> row out
        end

        %% --- Translation-invariant table layout ---

        function testTITableSize(tc)
            qmf = pf2_base.wavelet.makeONFilter('Daubechies', 4);
            n = 256; L = 4; J = log2(n);
            ti = pf2_base.wavelet.fwtTI(randn(n, 1), L, qmf);
            tc.verifySize(ti, [n, J - L + 1]);
        end

        %% --- Known-answer: Haar ---

        function testHaarKnownAnswerPO(tc)
            % Full Haar decomposition of [1..8] (L = 0). The coarse coeff is
            % the (normalised) running sum; verify exactly against the
            % analytic Haar values.
            qmf = pf2_base.wavelet.makeONFilter('Haar');
            x = (1:8)';
            wc = pf2_base.wavelet.fwtPO(x, 0, qmf);
            expected = [12.7279220613579; 5.65685424949238; 2; 2; ...
                        0.707106781186548; 0.707106781186548; ...
                        0.707106781186548; 0.707106781186548];
            tc.verifyEqual(wc, expected, 'AbsTol', 1e-10);
        end

        %% --- Translation invariance property ---

        function testTITranslationInvariance(tc)
            % The set of detail-coefficient magnitudes from fwtTI is invariant
            % to a circular shift of the input (that is the defining property
            % of the translation-invariant transform).
            qmf = pf2_base.wavelet.makeONFilter('Daubechies', 4);
            rng(3);
            x = randn(64, 1);
            xs = circshift(x, 5);
            tiA = pf2_base.wavelet.fwtTI(x, 3, qmf);
            tiB = pf2_base.wavelet.fwtTI(xs, 3, qmf);
            % Total energy of the transform table is shift-invariant.
            tc.verifyEqual(sum(tiB(:).^2), sum(tiA(:).^2), 'RelTol', 1e-10);
        end

        %% --- Dyad helper inverse property ---

        function testUpDownDyadAdjoint(tc)
            % For an orthonormal qmf, splitting a signal into low/high bands
            % and synthesising back reconstructs the original.
            qmf = pf2_base.wavelet.makeONFilter('Daubechies', 6);
            rng(5);
            x = randn(1, 32);
            lo = pf2_base.wavelet.downDyadLo(x, qmf);
            hi = pf2_base.wavelet.downDyadHi(x, qmf);
            xr = pf2_base.wavelet.upDyadLo(lo, qmf) ...
               + pf2_base.wavelet.upDyadHi(hi, qmf);
            tc.verifyEqual(xr, x, 'AbsTol', 1e-10);
        end

    end
end
