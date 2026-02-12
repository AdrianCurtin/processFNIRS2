classdef IntraROITest < matlab.unittest.TestCase
    % INTRAROITEST Unit tests for intra-ROI and inter-ROI connectivity
    %
    %   Tests cover:
    %     - Within-ROI coupling computation (computeIntraROI)
    %     - Intra-ROI visualization (plotIntraROI: bar and radar)
    %     - Between-ROI coupling computation (computeInterROI)
    %     - Inter-ROI visualization (plotInterROI)
    %
    %   Example:
    %       results = runtests('pf2_base.tests.unit.IntraROITest');
    %       disp(results);

    properties
        fs          % Sampling frequency
        T           % Number of samples
        nChannels   % Number of channels
    end

    methods (TestClassSetup)
        function setupParams(testCase)
            testCase.fs = 10;
            testCase.T = 500;
            testCase.nChannels = 12;
        end
    end


    %% Intra-ROI Computation
    methods (Test)

        function testIntraROICorrelatedChannels(testCase)
            % ROI1 channels share a signal (should be correlated),
            % ROI2 channels are independent (should be weakly correlated)
            rng(42);
            T = testCase.T;
            nCh = testCase.nChannels;

            data = createROIData(T, testCase.fs, nCh, ...
                {'ROI1', 'ROI2'}, {[1, 2, 3, 4], [5, 6, 7, 8]});

            % Make ROI1 channels correlated via shared signal
            shared = randn(T, 1);
            for ch = [1, 2, 3, 4]
                data.HbO(:, ch) = shared + randn(T, 1) * 0.3;
            end

            % ROI2 channels are independent noise
            for ch = [5, 6, 7, 8]
                data.HbO(:, ch) = randn(T, 1);
            end

            result = exploreFNIRS.connectivity.computeIntraROI(data, ...
                'Method', 'pearson', 'Biomarker', 'HbO');

            % ROI1 should have much higher mean coupling than ROI2
            testCase.verifyGreaterThan(result.roiMetrics(1).meanCoupling, ...
                result.roiMetrics(2).meanCoupling);

            % ROI1 should have substantial positive coupling
            testCase.verifyGreaterThan(result.roiMetrics(1).meanCoupling, 0.5);
        end

        function testIntraROIStructFields(testCase)
            % Verify output has expected struct fields
            rng(42);
            data = createROIData(testCase.T, testCase.fs, testCase.nChannels, ...
                {'Left', 'Right', 'Center'}, {[1, 2, 3], [4, 5, 6], [7, 8, 9]});

            result = exploreFNIRS.connectivity.computeIntraROI(data);

            % Top-level fields
            testCase.verifyTrue(isfield(result, 'roiMetrics'));
            testCase.verifyTrue(isfield(result, 'method'));
            testCase.verifyEqual(result.method, 'pearson');

            % roiMetrics struct array
            testCase.verifyEqual(length(result.roiMetrics), 3);

            % Per-ROI fields
            for r = 1:3
                m = result.roiMetrics(r);
                testCase.verifyTrue(isfield(m, 'meanCoupling'));
                testCase.verifyTrue(isfield(m, 'sdCoupling'));
                testCase.verifyTrue(isfield(m, 'matrix'));
                testCase.verifyTrue(isfield(m, 'channels'));
                testCase.verifyTrue(isfield(m, 'roiName'));
                testCase.verifyFalse(isnan(m.meanCoupling));
            end

            % Matrix size should match number of channels in each ROI
            testCase.verifyEqual(size(result.roiMetrics(1).matrix), [3, 3]);
            testCase.verifyEqual(size(result.roiMetrics(2).matrix), [3, 3]);
        end

    end


    %% Intra-ROI Plotting
    methods (Test)

        function testIntraROIPlotBar(testCase)
            % Smoke test: bar plot should create a valid figure handle
            rng(42);
            data = createROIData(testCase.T, testCase.fs, testCase.nChannels, ...
                {'Left', 'Right', 'Center'}, {[1, 2, 3], [4, 5, 6], [7, 8, 9]});

            result = exploreFNIRS.connectivity.computeIntraROI(data);
            fig = exploreFNIRS.connectivity.plotIntraROI(result, ...
                'PlotType', 'bar', 'Visible', 'off');

            testCase.verifyTrue(ishandle(fig));
            close(fig);
        end

        function testIntraROIPlotRadar(testCase)
            % Smoke test: radar plot should create a valid figure handle
            rng(42);
            data = createROIData(testCase.T, testCase.fs, testCase.nChannels, ...
                {'Left', 'Right', 'Center', 'Back'}, ...
                {[1, 2, 3], [4, 5, 6], [7, 8, 9], [10, 11, 12]});

            result = exploreFNIRS.connectivity.computeIntraROI(data);
            fig = exploreFNIRS.connectivity.plotIntraROI(result, ...
                'PlotType', 'radar', 'Visible', 'off');

            testCase.verifyTrue(ishandle(fig));
            close(fig);
        end

    end


    %% Inter-ROI Computation
    methods (Test)

        function testInterROIBasic(testCase)
            % computeInterROI should produce a matrix sized [nROI x nROI]
            rng(42);
            nROIs = 4;
            roiNames = {'Left', 'Right', 'Center', 'Back'};
            roiChannels = {[1, 2, 3], [4, 5, 6], [7, 8, 9], [10, 11, 12]};

            data = createROIData(testCase.T, testCase.fs, testCase.nChannels, ...
                roiNames, roiChannels);

            result = exploreFNIRS.connectivity.computeInterROI(data, ...
                'Method', 'pearson', 'Biomarker', 'HbO');

            testCase.verifyEqual(size(result.matrix), [nROIs, nROIs]);
            testCase.verifyTrue(result.useROI);
            testCase.verifyEqual(result.method, 'pearson');
            testCase.verifyEqual(result.biomarker, 'HbO');
            testCase.verifyEqual(length(result.labels), nROIs);

            % Diagonal should be 1
            testCase.verifyEqual(diag(result.matrix), ones(nROIs, 1), 'AbsTol', 1e-10);

            % Matrix should be symmetric
            testCase.verifyEqual(result.matrix, result.matrix', 'AbsTol', 1e-10);
        end

    end


    %% Inter-ROI Plotting
    methods (Test)

        function testInterROIPlot(testCase)
            % Smoke test: plotInterROI should create a valid figure handle
            rng(42);
            data = createROIData(testCase.T, testCase.fs, testCase.nChannels, ...
                {'Left', 'Right', 'Center'}, {[1, 2, 3], [4, 5, 6], [7, 8, 9]});

            result = exploreFNIRS.connectivity.computeInterROI(data);

            % Test matrix mode (chord may not be available)
            fig = exploreFNIRS.connectivity.plotInterROI(result, ...
                'PlotType', 'matrix', 'Visible', 'off');

            testCase.verifyTrue(ishandle(fig));
            close(fig);
        end

    end

end


%% Helper functions

function data = createROIData(T, fs, nCh, roiNames, roiChannels)
    % Create synthetic fNIRS data with ROI definitions
    data.time = (0:T-1)' / fs;
    data.fs = fs;
    data.fchMask = ones(1, nCh);
    data.HbO = randn(T, nCh);
    data.HbR = randn(T, nCh) * 0.3;
    data.ROI.info = table(roiChannels', ...
        'VariableNames', {'Channels'}, ...
        'RowNames', roiNames);
    % Also add ROI-level averages for inter-ROI
    nROIs = length(roiNames);
    data.ROI.HbO = randn(T, nROIs);
    data.ROI.HbR = randn(T, nROIs) * 0.3;
end
