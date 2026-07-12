classdef NewVisualizationsTest < matlab.unittest.TestCase
    % NEWVISUALIZATIONSTEST Smoke tests for the spatial visualization additions
    %
    % Covers the sensitivity-weighted interpolation kernel, time-animation
    % movies, anatomical parcel projection, brain-anchored connectome, and the
    % dual-brain inter-brain synchrony view. Each is exercised headlessly and
    % asserted to produce a valid output file or handle.
    %
    %   results = runtests('pf2_base.tests.unit.NewVisualizationsTest');

    properties
        proc        % processed fNIR2000 (no markers)
        procMrk     % processed marker-bearing data (for movies)
        outDir
    end

    methods (TestClassSetup)
        function setup(testCase)
            testCase.proc = processFNIRS2(pf2.import.sampleData.fNIR2000());
            testCase.procMrk = processFNIRS2(pf2.import.sampleData());
            testCase.outDir = fullfile(tempdir, 'pf2viz_test');
            if ~exist(testCase.outDir, 'dir'), mkdir(testCase.outDir); end
        end
    end

    methods (Test)

        function testSensitivityKernel(testCase)
            f = fullfile(testCase.outDir, 'sens.png');
            vals = mean(testCase.proc.HbO, 1, 'omitnan');
            pf2.probe.project.biomarker(vals, testCase.proc, ...
                'interpolateType', 'sensitivity', 'savePath', f);
            testCase.verifyTrue(isfile(f));
            close all force;
        end

        function testMovie3D(testCase)
            f = fullfile(testCase.outDir, 'mov3d.mp4');
            out = pf2.probe.plot.movie(testCase.procMrk, 'HbO', ...
                'TimeRange', [0 15], 'NFrames', 4, 'FPS', 5, ...
                'savePath', f, 'Verbose', false);
            testCase.verifyTrue(isfile(out));
            close all force;
        end

        function testMovie2DGif(testCase)
            f = fullfile(testCase.outDir, 'mov2d.gif');
            pf2.probe.plot.movie(testCase.procMrk, 'HbO', 'View', '2d', ...
                'TimeRange', [0 15], 'NFrames', 4, 'FPS', 5, ...
                'savePath', f, 'Verbose', false);
            testCase.verifyTrue(isfile(f));
            close all force;
        end

        function testRegionProjection(testCase)
            p = pf2.probe.canonicalize(testCase.proc, 'MaxDistance', 25);
            f = fullfile(testCase.outDir, 'regions.png');
            meanHbO = mean(p.canonical.HbO, 1, 'omitnan');
            h = pf2.probe.project.regions(meanHbO, p, 'savePath', f);
            testCase.verifyTrue(isfile(f));
            testCase.verifyTrue(isgraphics(h));
            close all force;
        end

        function testRegionProjectionByName(testCase)
            p = pf2.probe.canonicalize(testCase.proc, 'MaxDistance', 25);
            f = fullfile(testCase.outDir, 'regions_name.png');
            pf2.probe.project.regions('HbO', p, 'savePath', f);
            testCase.verifyTrue(isfile(f));
            close all force;
        end

        function testConnectome3D(testCase)
            r = exploreFNIRS.connectivity.computeMatrix(testCase.proc, ...
                'Method', 'pearson', 'Biomarker', 'HbO');
            f = fullfile(testCase.outDir, 'conn3d.png');
            pf2.probe.plot.connectome(r, testCase.proc, 'View', '3d', ...
                'TopN', 20, 'savePath', f);
            testCase.verifyTrue(isfile(f));
            close all force;
        end

        function testConnectome2D(testCase)
            r = exploreFNIRS.connectivity.computeMatrix(testCase.proc, ...
                'Method', 'pearson', 'Biomarker', 'HbO');
            f = fullfile(testCase.outDir, 'conn2d.png');
            pf2.probe.plot.connectome(r, testCase.proc, 'View', '2d', ...
                'Threshold', 0.5, 'savePath', f);
            testCase.verifyTrue(isfile(f));
            close all force;
        end

        function testDualBrainAll(testCase)
            dy = exploreFNIRS.hyperscanning.computeDyad(testCase.proc, ...
                testCase.proc, 'Method', 'pearson', 'ChannelPairing', 'all');
            f = fullfile(testCase.outDir, 'dual_all.png');
            fig = exploreFNIRS.hyperscanning.plotDualBrain(dy, testCase.proc, ...
                testCase.proc, 'TopN', 20, 'Visible', 'off', 'SavePath', f);
            testCase.verifyTrue(isfile(f));
            testCase.verifyClass(fig, 'matlab.ui.Figure');
            close all force;
        end

        function testDualBrainSameWithWavelet(testCase)
            dy = exploreFNIRS.hyperscanning.computeDyad(testCase.proc, ...
                testCase.proc, 'Method', 'pearson', 'ChannelPairing', 'same');
            wc = struct('wcoh', rand(20, 100), 'freqs', logspace(-2, 0, 20)', ...
                'times', linspace(0, 50, 100)', ...
                'coi', 0.02 + 0.1 * abs(sin(linspace(0, pi, 100)')));
            f = fullfile(testCase.outDir, 'dual_wc.png');
            exploreFNIRS.hyperscanning.plotDualBrain(dy, testCase.proc, ...
                testCase.proc, 'Wcoherence', wc, 'Visible', 'off', 'SavePath', f);
            testCase.verifyTrue(isfile(f));
            close all force;
        end

    end
end
