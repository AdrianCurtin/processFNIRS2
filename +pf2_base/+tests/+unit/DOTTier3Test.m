classdef DOTTier3Test < matlab.unittest.TestCase
    % DOTTIER3TEST DOT fidelity & high-density features (roadmap Tier 3)
    %
    % Covers spatially-variant priors (graph-Laplacian & parcel), point-spread
    % resolution diagnostics, short-separation scalp regression, the layered
    % head model, the time-resolved tomography movie, and montage
    % characterization. Renders/movies are exercised headlessly.
    %
    %   results = runtests('pf2_base.tests.unit.DOTTier3Test');

    properties
        data
        proc
        outDir
    end

    methods (TestClassSetup)
        function setup(testCase)
            testCase.data = pf2.import.sampleData.fNIR2000();
            testCase.proc = processFNIRS2(testCase.data);
            testCase.outDir = fullfile(tempdir, 'pf2dot3_test');
            if ~exist(testCase.outDir, 'dir'), mkdir(testCase.outDir); end
        end
    end

    methods (Test)

        % --- 3.4 priors ------------------------------------------------------
        function testMeshLaplacian(testCase)
            mesh = pf2_base.dot.corticalMesh();
            sub = (1:500)';
            L = pf2_base.dot.meshLaplacian(mesh.faces, 'Subset', sub);
            testCase.verifyEqual(size(L), [500 500]);
            testCase.verifyLessThan(max(abs(sum(L, 2))), 1e-9, 'Row sums must be 0.');
            testCase.verifyLessThan(max(max(abs(L - L'))), 1e-9, 'L must be symmetric.');
            ev = eigs(L, 1, 'smallestreal', 'Tolerance', 1e-3);
            testCase.verifyGreaterThan(ev, -1e-6, 'L must be PSD.');
        end

        function testLaplacianPriorReconstruct(testCase)
            rMin = pf2.probe.dot.reconstruct(testCase.proc, 'Time', [5 20], ...
                'Biomarkers', {'HbO'}, 'Prior', 'minnorm');
            rLap = pf2.probe.dot.reconstruct(testCase.proc, 'Time', [5 20], ...
                'Biomarkers', {'HbO'}, 'Prior', 'laplacian');
            testCase.verifyTrue(all(isfinite(rLap.HbO(rLap.mask))));
            testCase.verifyEqual(rLap.meta.prior, 'laplacian');
            % Laplacian image should be spatially smoother (smaller neighbour
            % gradient) than the minimum-norm image over the shared support.
            mesh = pf2_base.dot.corticalMesh();
            sub = find(rLap.mask & rMin.mask);
            L = pf2_base.dot.meshLaplacian(mesh.faces, 'Subset', sub);
            xL = rLap.HbO(sub)'; xM = rMin.HbO(sub)';
            roughL = norm(L * xL) / norm(xL);
            roughM = norm(L * xM) / norm(xM);
            testCase.verifyLessThan(roughL, roughM, 'Laplacian prior must be smoother.');
        end

        function testParcelPriorReconstruct(testCase)
            r = pf2.probe.dot.reconstruct(testCase.proc, 'Time', [5 20], ...
                'Biomarkers', {'HbO'}, 'Prior', 'parcel');
            testCase.verifyTrue(all(isfinite(r.HbO(r.mask))));
            testCase.verifyEqual(r.meta.prior, 'parcel');
        end

        % --- 3.6 resolution --------------------------------------------------
        function testResolutionMetrics(testCase)
            res = pf2.probe.dot.resolution(testCase.proc, 'NSeeds', 40);
            testCase.verifyEqual(numel(res.seeds), 40);
            testCase.verifyTrue(all(res.spread > 0), 'Spread must be positive.');
            testCase.verifyTrue(all(res.localization >= 0));
            % Honest coarse resolution: spread on the order of cm, finite.
            testCase.verifyTrue(isfinite(res.summary.medianSpread));
            testCase.verifyGreaterThan(res.summary.medianSpread, 2);
        end

        function testResolutionRender(testCase)
            f = fullfile(testCase.outDir, 'psf.png');
            pf2.probe.dot.resolution(testCase.proc, 'NSeeds', 30, ...
                'PlotSeed', 15, 'savePath', f);
            testCase.verifyTrue(isfile(f));
            close all force;
        end

        % --- 3.2 scalp regression -------------------------------------------
        function testScalpRegression(testCase)
            r0 = pf2.probe.dot.reconstruct(testCase.proc, 'Time', [5 20], ...
                'Biomarkers', {'HbO'});
            r1 = pf2.probe.dot.reconstruct(testCase.proc, 'Time', [5 20], ...
                'Biomarkers', {'HbO'}, 'ScalpRegression', true);
            testCase.verifyTrue(all(isfinite(r1.HbO(r1.mask))));
            % Removing the scalp component changes the cortical estimate.
            shared = r0.mask & r1.mask;
            testCase.verifyGreaterThan(norm(r1.HbO(shared) - r0.HbO(shared)), 0);
        end

        % --- 3.1 layered head model -----------------------------------------
        function testLayeredHeadModel(testCase)
            layers = pf2_base.dot.layeredHeadModel();
            testCase.verifyEqual({layers.name}, {'scalp','skull','csf','gray'});
            % CSF channels light: lower effective attenuation than gray.
            testCase.verifyLessThan(layers(3).mueff, layers(4).mueff);
            % depth boundaries increase monotonically.
            tops = [layers.depthTop];
            testCase.verifyTrue(all(diff(tops) > 0));
        end

        function testLayeredSensitivityDiffers(testCase)
            Ah = pf2.probe.forward.sensitivity(testCase.data, 'MaxDistance', 50, ...
                'HeadModel', 'homogeneous');
            Al = pf2.probe.forward.sensitivity(testCase.data, 'MaxDistance', 50, ...
                'HeadModel', 'layered');
            testCase.verifyEqual(size(Ah), size(Al));
            testCase.verifyTrue(all(nonzeros(Al) >= 0));
            % The layered profile reshapes sensitivity (not identical).
            testCase.verifyGreaterThan(norm(full(sum(Ah,1) - sum(Al,1))), 0);
        end

        function testLayeredReconstruct(testCase)
            r = pf2.probe.dot.reconstruct(testCase.proc, 'Time', [5 20], ...
                'Biomarkers', {'HbO'}, 'HeadModel', 'layered');
            testCase.verifyTrue(any(r.mask));
            testCase.verifyTrue(all(isfinite(r.HbO(r.mask))));
        end

        % --- 3.5 time-resolved movie ----------------------------------------
        function testTomographyMovie(testCase)
            f = fullfile(testCase.outDir, 'tomo.mp4');
            out = pf2.probe.plot.tomographyMovie(testCase.proc, 'Biomarker', 'HbO', ...
                'TimeRange', [0 20], 'NFrames', 6, 'FPS', 5, 'savePath', f);
            testCase.verifyTrue(isfile(out));
            d = dir(out);
            testCase.verifyGreaterThan(d.bytes, 0);
            close all force;
        end

        function testScalpMethodsDiffer(testCase)
            % nearest / all / pca must produce genuinely different results
            % (guards against a silently-stubbed method).
            args = {'Time', [5 20], 'Biomarkers', {'HbO'}, 'ScalpRegression', true};
            rN = pf2.probe.dot.reconstruct(testCase.proc, args{:}, 'ScalpMethod', 'nearest');
            rA = pf2.probe.dot.reconstruct(testCase.proc, args{:}, 'ScalpMethod', 'all');
            rP = pf2.probe.dot.reconstruct(testCase.proc, args{:}, 'ScalpMethod', 'pca');
            sh = rN.mask & rA.mask & rP.mask;
            testCase.verifyGreaterThan(norm(rP.HbO(sh) - rA.HbO(sh)), 0, 'pca must differ from all.');
            testCase.verifyGreaterThan(norm(rN.HbO(sh) - rA.HbO(sh)), 0, 'nearest must differ from all.');
            testCase.verifyTrue(contains(rN.units, 'relative'), 'Units must be labeled relative.');
        end

        function testLayerThicknessChangesOperator(testCase)
            % The forward cache must distinguish layer thickness (stale-cache guard).
            A1 = pf2.probe.forward.sensitivity(testCase.data, 'MaxDistance', 40, ...
                'HeadModel', 'layered', 'Layers', pf2_base.dot.layeredHeadModel('Thickness', [3 7 2]));
            A2 = pf2.probe.forward.sensitivity(testCase.data, 'MaxDistance', 40, ...
                'HeadModel', 'layered', 'Layers', pf2_base.dot.layeredHeadModel('Thickness', [6 10 3]));
            testCase.verifyNotEqual(nnz(A1), nnz(A2), ...
                'Different layer thicknesses must yield different operators (no cache collision).');
        end

        function testNoisyBlobBoundedRecovery(testCase)
            % Recovery under measurement noise should be good but NOT perfect
            % (the noiseless planted-blob test is an inverse crime).
            [A, mesh] = pf2.probe.forward.sensitivity(testCase.data, 'MaxDistance', 50);
            [~, vtrue] = max(A(6, :));
            d2 = vecnorm(mesh.vertices - mesh.vertices(vtrue, :), 2, 2);
            xtrue = exp(-(d2.^2) / (2 * 10^2));
            y = A * xtrue;
            y = y + 0.05 * std(y) * (sin(1:numel(y))');   % deterministic 5% perturbation
            X = pf2_base.dot.reconstructImage(A, y, 'DepthWeight', true);
            [~, vrec] = max(X);
            err = norm(mesh.vertices(vrec, :) - mesh.vertices(vtrue, :));
            testCase.verifyLessThan(err, 30, 'Noisy recovery should still localize within ~cm.');
            testCase.verifyTrue(all(isfinite(X)), 'Noisy reconstruction must stay finite.');
        end

        function testSurfaceNormals(testCase)
            mesh = pf2_base.dot.corticalMesh();
            geom = pf2_base.dot.channelGeometry(testCase.data.device);
            nS = pf2_base.dot.surfaceNormals(geom.src, mesh.vertices, mesh.centroid);
            % Unit length and outward-facing.
            testCase.verifyEqual(vecnorm(nS, 2, 2), ones(size(nS,1),1), 'AbsTol', 1e-6);
            outward = sum(nS .* (geom.src - mesh.centroid), 2);
            testCase.verifyTrue(all(outward > 0), 'Normals must point outward.');
            % For a frontal montage, surface normals deviate from radial.
            rad = (geom.src - mesh.centroid) ./ vecnorm(geom.src - mesh.centroid, 2, 2);
            ang = acosd(min(1, abs(sum(nS .* rad, 2))));
            testCase.verifyGreaterThan(max(ang), 3, ...
                'Surface normals should differ from radial on a frontal montage.');
        end

        function testNormalModeChangesOperator(testCase)
            As = pf2.probe.forward.sensitivity(testCase.data, 'MaxDistance', 50, 'NormalMode', 'surface');
            Ar = pf2.probe.forward.sensitivity(testCase.data, 'MaxDistance', 50, 'NormalMode', 'radial');
            testCase.verifyEqual(size(As), size(Ar));
            testCase.verifyGreaterThan(norm(full(sum(As,1) - sum(Ar,1))), 0, ...
                'Surface vs radial normals must yield different operators.');
            testCase.verifyTrue(all(nonzeros(As) >= 0));
        end

        % --- 3.3 montage characterization -----------------------------------
        function testMontageInfo(testCase)
            info = pf2.probe.dot.montageInfo(testCase.data);
            testCase.verifyEqual(info.nChannels, size(testCase.proc.HbO, 2));
            testCase.verifyGreaterThanOrEqual(info.nSepClasses, 1);
            testCase.verifyGreaterThan(info.meanOverlap, 0);
            testCase.verifyTrue(islogical(info.isHighDensity));
            testCase.verifyTrue(ischar(info.recommendation));
        end

    end
end
