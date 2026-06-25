classdef DOTTest < matlab.unittest.TestCase
    % DOTTEST Diffuse optical tomography forward model and reconstruction
    %
    % Covers the DOT stack: the semi-infinite diffusion Green's function,
    % optical-property table, channel geometry, atlas cortical mesh, PMDF
    % sensitivity matrix, coverage field, the depth-weighted Tikhonov inverse
    % (validated by recovering a planted focal blob), and the public
    % forward/reconstruct/render entry points. Renders are exercised headlessly.
    %
    %   results = runtests('pf2_base.tests.unit.DOTTest');

    properties
        data        % imported fNIR2000 (geometry-bearing)
        proc        % processed fNIR2000
        outDir
    end

    methods (TestClassSetup)
        function setup(testCase)
            testCase.data = pf2.import.sampleData.fNIR2000();
            testCase.proc = processFNIRS2(testCase.data);
            testCase.outDir = fullfile(tempdir, 'pf2dot_test');
            if ~exist(testCase.outDir, 'dir'), mkdir(testCase.outDir); end
        end
    end

    methods (Test)

        % --- Tier 1: physics -------------------------------------------------
        function testGreensFunctionDecaysWithDepth(testCase)
            props = pf2_base.dot.opticalProperties(800);
            depths = (5:5:40)';
            R = [zeros(numel(depths), 2), -depths];   % straight down from optode
            phi = pf2_base.dot.greensFunction(R, [0 0 0], [0 0 1], ...
                props.D, props.mueff, props.musp);
            testCase.verifyTrue(all(phi >= 0), 'Fluence must be non-negative.');
            testCase.verifyTrue(all(diff(phi) < 0), 'Fluence must decay with depth.');
            testCase.verifyTrue(all(isfinite(phi)), 'Fluence must be finite.');
        end

        function testGreensFunctionDecaysLaterally(testCase)
            props = pf2_base.dot.opticalProperties(800);
            lat = (0:5:30)';
            R = [lat, zeros(numel(lat), 1), -10 * ones(numel(lat), 1)];
            phi = pf2_base.dot.greensFunction(R, [0 0 0], [0 0 1], ...
                props.D, props.mueff, props.musp);
            testCase.verifyTrue(all(diff(phi) < 0), ...
                'Fluence should fall off moving laterally from the source.');
            testCase.verifyGreaterThan(phi(1), 0);
        end

        function testOpticalProperties(testCase)
            props = pf2_base.dot.opticalProperties([730 850]);
            testCase.verifyEqual(numel(props.mua), 2);
            testCase.verifyTrue(all(props.mua > 0 & props.mua < 0.1));
            testCase.verifyTrue(all(props.musp > 0.5 & props.musp < 2));
            testCase.verifyTrue(all(props.mueff > 0));
            % HbR absorbs more than HbO at 730, less at 850 (the NIR crossover).
            testCase.verifyGreaterThan(props.extHbR(1), props.extHbO(1));
            testCase.verifyGreaterThan(props.extHbO(2), props.extHbR(2));
        end

        function testChannelGeometry(testCase)
            geom = pf2_base.dot.channelGeometry(testCase.data.device);
            nCh = size(testCase.proc.HbO, 2);
            testCase.verifyEqual(size(geom.src, 1), nCh);
            testCase.verifyEqual(size(geom.det, 1), nCh);
            testCase.verifyTrue(all(geom.sdDist > 0));
            testCase.verifyTrue(all(isfinite(geom.src(:))));
        end

        function testCorticalMesh(testCase)
            mesh = pf2_base.dot.corticalMesh();
            testCase.verifyGreaterThan(size(mesh.vertices, 1), 1000);
            testCase.verifyEqual(size(mesh.vertices, 2), 3);
            testCase.verifyEqual(size(mesh.brodmann, 1), size(mesh.vertices, 1));
            % Registered to MNI mm: roughly head-sized.
            span = max(mesh.vertices) - min(mesh.vertices);
            testCase.verifyTrue(all(span > 100 & span < 220));
        end

        function testSensitivityMatrix(testCase)
            [A, mesh] = pf2.probe.forward.sensitivity(testCase.data, 'MaxDistance', 50);
            testCase.verifyEqual(size(A, 1), size(testCase.proc.HbO, 2));
            testCase.verifyEqual(size(A, 2), size(mesh.vertices, 1));
            testCase.verifyTrue(all(nonzeros(A) >= 0), 'Sensitivity must be non-negative.');
            testCase.verifyTrue(all(isfinite(nonzeros(A))));
            % Peak sensitivity of a channel lands near its source-detector midpoint.
            geom = pf2_base.dot.channelGeometry(testCase.data.device);
            [~, vmax] = max(A(1, :));
            d = norm(mesh.vertices(vmax, :) - geom.mid(1, :));
            testCase.verifyLessThan(d, 25, 'Peak sensitivity should sit under the channel.');
        end

        function testForwardCaching(testCase)
            A1 = pf2.probe.forward.sensitivity(testCase.data, 'MaxDistance', 40);
            t = tic; A2 = pf2.probe.forward.sensitivity(testCase.data, 'MaxDistance', 40);
            dt = toc(t);
            testCase.verifyEqual(nnz(A1), nnz(A2));
            testCase.verifyLessThan(dt, 0.5, 'Cached forward build should be near-instant.');
        end

        function testCoverage(testCase)
            cov = pf2.probe.forward.coverage(testCase.data);
            testCase.verifyEqual(numel(cov), size(pf2_base.dot.corticalMesh().vertices, 1));
            testCase.verifyTrue(all(cov >= 0 & cov <= 1));
            testCase.verifyGreaterThan(sum(cov > 0.05), 50, 'Montage must cover some cortex.');
        end

        % --- Tier 2: inverse -------------------------------------------------
        function testPlantedBlobRecovery(testCase)
            [A, mesh] = pf2.probe.forward.sensitivity(testCase.data, 'MaxDistance', 50);
            cov = full(sum(A ./ max(max(A,[],2), eps), 1))';
            supp = cov > 0.05 * max(cov);
            [~, vtrue] = max(A(6, :));
            d2 = vecnorm(mesh.vertices - mesh.vertices(vtrue, :), 2, 2);
            xtrue = exp(-(d2.^2) / (2 * 10^2));
            y = A * xtrue;
            % Add measurement noise so the test exercises regularization quality
            % rather than committing an inverse crime (noise-free data through the
            % same operator used to reconstruct). Fixed seed -> deterministic.
            rng(42);
            nLevel = 0.02 * sqrt(mean(y.^2));
            yNoisy = y + nLevel * randn(size(y));
            [X, meta] = pf2_base.dot.reconstructImage(A, yNoisy, 'DepthWeight', true);
            [~, vrec] = max(X);
            err = norm(mesh.vertices(vrec, :) - mesh.vertices(vtrue, :));
            testCase.verifyGreaterThan(meta.lambda, 0);
            testCase.verifyLessThan(err, 25, 'Recon peak should be near the planted blob under noise.');
            testCase.verifyGreaterThan(corr(X(supp), xtrue(supp)), 0.4, ...
                'Recon should correlate with truth over the covered region under noise.');
        end

        function testReconstructSignAndShape(testCase)
            [A, mesh] = pf2.probe.forward.sensitivity(testCase.data, 'MaxDistance', 50);
            % Plant a blob at a well-covered location so it forward-projects.
            [~, vtrue] = max(A(6, :));
            d2 = vecnorm(mesh.vertices - mesh.vertices(vtrue, :), 2, 2);
            x = exp(-(d2.^2) / (2 * 10^2));
            Y = A * [x, -x];
            X = pf2_base.dot.reconstructImage(A, Y);
            testCase.verifyGreaterThan(max(X(:, 1)), 0);
            testCase.verifyLessThan(min(X(:, 2)), 0, 'Sign should flip with the data.');
        end

        function testRegParamMethods(testCase)
            d = logspace(0, -6, 18)';
            b = randn(18, 1);
            lamG = pf2_base.dot.regParam(d, b, 'Method', 'gcv');
            lamL = pf2_base.dot.regParam(d, b, 'Method', 'lcurve');
            testCase.verifyGreaterThan(lamG, 0);
            testCase.verifyGreaterThan(lamL, 0);
        end

        % --- Tier 2: public reconstruct + render -----------------------------
        function testReconstructStruct(testCase)
            recon = pf2.probe.dot.reconstruct(testCase.proc, 'Time', [5 20]);
            nV = size(recon.vertices, 1);
            testCase.verifyEqual(size(recon.HbO, 2), nV);
            testCase.verifyEqual(size(recon.HbR, 2), nV);
            testCase.verifyEqual(numel(recon.coverage), nV);
            testCase.verifyTrue(any(recon.mask));
            % Masked vertices are NaN; covered ones finite.
            testCase.verifyTrue(all(isnan(recon.HbO(~recon.mask))));
            testCase.verifyTrue(any(isfinite(recon.HbO(recon.mask))));
        end

        function testTomographyRender(testCase)
            f = fullfile(testCase.outDir, 'tomo.png');
            recon = pf2.probe.dot.reconstruct(testCase.proc, 'Time', [5 20]);
            pf2.probe.project.tomography(recon, 'Biomarker', 'HbO', 'savePath', f);
            testCase.verifyTrue(isfile(f));
            close all force;
        end

        function testPMDFProjectionRender(testCase)
            f = fullfile(testCase.outDir, 'pmdf.png');
            meanHbO = mean(testCase.proc.HbO, 1, 'omitnan');
            pf2.probe.project.pmdf(meanHbO, testCase.proc, 'savePath', f);
            testCase.verifyTrue(isfile(f));
            close all force;
        end

        function testPMDFHandlesNaNChannel(testCase)
            % A NaN channel must not break the weighted backprojection (the
            % numerator and denominator share the valid-channel subset).
            f = fullfile(testCase.outDir, 'pmdf_nan.png');
            v = mean(testCase.proc.HbO, 1, 'omitnan');
            v(3) = NaN;
            pf2.probe.project.pmdf(v, testCase.proc, 'savePath', f);
            testCase.verifyTrue(isfile(f));
            close all force;
        end

    end
end
