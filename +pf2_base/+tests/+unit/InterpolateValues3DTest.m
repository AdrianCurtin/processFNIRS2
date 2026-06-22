classdef InterpolateValues3DTest < matlab.unittest.TestCase
    % INTERPOLATEVALUES3DTEST Smoke tests for pf2.probe.plot.interpolateValues3D
    %
    % Covers single-sided, two-sided (symmetric + asymmetric + one-tail-only)
    % colorbar paths, geodesic vs Euclidean, ForceLightMode, and the new
    % per-vertex transparent alpha mode. No pixel comparisons — tests only
    % assert rendering completes and key handle/patch properties are set.
    %
    %   results = runtests('pf2_base.tests.unit.InterpolateValues3DTest');

    properties
        processed
        hbo
        fig
    end

    methods (TestClassSetup)
        function prepareData(testCase)
            raw = pf2.import.sampleData.fNIR2000();
            testCase.processed = processFNIRS2(raw);
            testCase.hbo = testCase.processed.HbO(100, :);
        end
    end

    methods (TestMethodSetup)
        function openFig(testCase)
            testCase.fig = figure('Visible', 'off', 'Color', 'w');
        end
    end

    methods (TestMethodTeardown)
        function closeFig(testCase)
            if ~isempty(testCase.fig) && isvalid(testCase.fig)
                close(testCase.fig);
            end
        end
    end

    methods (Test)

        function testSingleSided(testCase)
            ax = axes('Parent', testCase.fig);
            h = pf2.probe.plot.interpolateValues3D(ax, testCase.hbo, ...
                testCase.processed, -1, 1, 'single sided');
            testCase.verifyTrue(isa(h, 'matlab.graphics.axis.Axes'));
            brain = findall(h, 'Type', 'Patch', 'Tag', 'Brain');
            testCase.verifyNotEmpty(brain);
        end

        function testTwoSidedSymmetric(testCase)
            ax = axes('Parent', testCase.fig);
            pf2.probe.plot.interpolateValues3D(ax, testCase.hbo, ...
                testCase.processed, [-1 1], 2, 'twosided sym');
            cbars = findall(testCase.fig, 'Type', 'ColorBar');
            testCase.verifyGreaterThanOrEqual(numel(cbars), 2, ...
                'Two-sided path should create >= 2 colorbars.');
        end

        function testTwoSidedAsymmetric(testCase)
            ax = axes('Parent', testCase.fig);
            pf2.probe.plot.interpolateValues3D(ax, testCase.hbo, ...
                testCase.processed, [-2 1], 6, 'twosided asym');
            cbars = findall(testCase.fig, 'Type', 'ColorBar');
            testCase.verifyGreaterThanOrEqual(numel(cbars), 1);
        end

        function testTwoSidedOnlyUpperData(testCase)
            % All data above dead-zone top => no lower colorbar
            vals = ones(size(testCase.hbo)) * 5;
            ax = axes('Parent', testCase.fig);
            pf2.probe.plot.interpolateValues3D(ax, vals, ...
                testCase.processed, [-1 1], 10, 'upper only');
            testCase.verifyClass(gca, 'matlab.graphics.axis.Axes');
        end

        function testTwoSidedOnlyLowerData(testCase)
            vals = -ones(size(testCase.hbo)) * 5;
            ax = axes('Parent', testCase.fig);
            pf2.probe.plot.interpolateValues3D(ax, vals, ...
                testCase.processed, [-10 -2], 1, 'lower only');
            testCase.verifyClass(gca, 'matlab.graphics.axis.Axes');
        end

        function testGeodesicDefault(testCase)
            ax = axes('Parent', testCase.fig);
            pf2.probe.plot.interpolateValues3D(ax, testCase.hbo, ...
                testCase.processed, -1, 1);  % UseGeodesic default = true
            meshCache = getappdata(ax, 'iv3d_meshGraph');
            testCase.verifyNotEmpty(meshCache, ...
                'Geodesic path should record the cached mesh signature.');
        end

        function testGeodesicCacheReuseIsConsistent(testCase)
            % Two successive geodesic renders (the second reuses the persistent
            % mesh graph) must produce identical images, and the per-axes mesh
            % signature breadcrumb must match across calls (same mesh).
            f1 = figure('Visible', 'off');
            c1 = onCleanup(@() close(f1)); %#ok<NASGU>
            [~, img1] = pf2.probe.plot.interpolateValues3D(testCase.hbo, ...
                testCase.processed, 'useGeodesic', true);
            sig1 = getappdata(gca, 'iv3d_meshGraph');

            f2 = figure('Visible', 'off');
            c2 = onCleanup(@() close(f2)); %#ok<NASGU>
            [~, img2] = pf2.probe.plot.interpolateValues3D(testCase.hbo, ...
                testCase.processed, 'useGeodesic', true);
            sig2 = getappdata(gca, 'iv3d_meshGraph');

            testCase.verifyEqual(img2, img1, ...
                'Cached mesh-graph reuse must not change the render.');
            testCase.verifyEqual(sig2, sig1, ...
                'Same mesh should resolve to the same cache signature.');
        end

        function testEuclideanOptOut(testCase)
            ax = axes('Parent', testCase.fig);
            pf2.probe.plot.interpolateValues3D(ax, testCase.hbo, ...
                testCase.processed, -1, 1, '', '', 'UseGeodesic', false);
            cache = getappdata(ax, 'iv3d_distCache');
            testCase.verifyTrue(isempty(cache) || ...
                (isfield(cache, 'useGeodesic') && ~cache.useGeodesic), ...
                'Euclidean cache should not indicate geodesic.');
        end

        function testForceLightMode(testCase)
            ax = axes('Parent', testCase.fig);
            pf2.probe.plot.interpolateValues3D(ax, testCase.hbo, ...
                testCase.processed, -1, 1, '', '', 'ForceLightMode', true);
            testCase.verifyEqual(ax.XColor, [0 0 0]);
            testCase.verifyEqual(ax.YColor, [0 0 0]);
            testCase.verifyEqual(ax.ZColor, [0 0 0]);
            testCase.verifyEqual(testCase.fig.Color, [1 1 1]);
        end

        function testAlphaTransparent(testCase)
            K = numel(testCase.hbo);
            alpha = zeros(1, K);
            alpha([1 3 5 7]) = 1;
            ax = axes('Parent', testCase.fig);
            pf2.probe.plot.interpolateValues3D(ax, testCase.hbo, ...
                testCase.processed, -1, 1, '', '', ...
                'ChannelAlpha', alpha, 'AlphaMode', 'transparent');
            overlay = findall(ax, 'Type', 'Patch', 'Tag', 'BrainOverlay');
            testCase.verifyNotEmpty(overlay, ...
                'Transparent mode should create a BrainOverlay patch.');
            fvad = get(overlay, 'FaceVertexAlphaData');
            testCase.verifyEqual(numel(fvad), size(get(overlay, 'Vertices'), 1), ...
                'FaceVertexAlphaData size must match vertex count.');
            testCase.verifyLessThan(mean(fvad(:)), 1, ...
                'Non-significant channels should reduce mean vertex alpha.');
        end

    end
end
