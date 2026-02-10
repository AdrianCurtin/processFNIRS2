classdef HyperscanVisualizationTest < matlab.unittest.TestCase
    % HYPERSCANVISUALIZATIONTEST Unit tests for hyperscanning visualization functions
    %
    %   Tests cover smoke tests for:
    %     - plotInterBrainTopo: dual-brain topographic display
    %     - plotDyadMatrix: dyad-level coupling heatmap
    %     - plotGroupTemporal: time-resolved group coupling
    %
    %   Example:
    %       results = runtests('pf2_base.tests.unit.HyperscanVisualizationTest');
    %       disp(results);

    properties
        nChannels
        nDyads
    end

    methods (TestClassSetup)
        function setupParams(testCase)
            testCase.nChannels = 8;
            testCase.nDyads = 4;
        end
    end


    %% plotInterBrainTopo
    methods (Test)

        function testPlotInterBrainTopoBasic(testCase)
            % Basic smoke test: create group result and verify figure handle
            rng(42);
            result = createGroupResult(testCase.nChannels, testCase.nDyads);

            fig = exploreFNIRS.hyperscanning.plotInterBrainTopo(result, ...
                'Visible', 'off');

            testCase.verifyTrue(ishandle(fig));
            close(fig);
        end

        function testPlotInterBrainTopoWithLabels(testCase)
            % Test custom brain labels
            rng(42);
            result = createGroupResult(testCase.nChannels, testCase.nDyads);

            fig = exploreFNIRS.hyperscanning.plotInterBrainTopo(result, ...
                'Visible', 'off', 'BrainLabels', {'Speaker', 'Listener'});

            testCase.verifyTrue(ishandle(fig));
            close(fig);
        end

        function testPlotInterBrainTopoFromDyad(testCase)
            % Test with dyad-level result (uses .values instead of .Mean)
            rng(42);
            result = createDyadResult(testCase.nChannels);

            fig = exploreFNIRS.hyperscanning.plotInterBrainTopo(result, ...
                'Visible', 'off');

            testCase.verifyTrue(ishandle(fig));
            close(fig);
        end

        function testPlotInterBrainTopoThreshold(testCase)
            % Test with a high threshold that filters most lines
            rng(42);
            result = createGroupResult(testCase.nChannels, testCase.nDyads);
            result.Mean = result.Mean * 0.1;  % low coupling values

            fig = exploreFNIRS.hyperscanning.plotInterBrainTopo(result, ...
                'Visible', 'off', 'LineThreshold', 0.5);

            testCase.verifyTrue(ishandle(fig));
            close(fig);
        end

    end


    %% plotDyadMatrix
    methods (Test)

        function testPlotDyadMatrixBasic(testCase)
            % Basic smoke test: verify figure handle from group result
            rng(42);
            result = createGroupResult(testCase.nChannels, testCase.nDyads);

            fig = exploreFNIRS.hyperscanning.plotDyadMatrix(result, ...
                'Visible', 'off');

            testCase.verifyTrue(ishandle(fig));
            close(fig);
        end

        function testPlotDyadMatrixSorted(testCase)
            % Test with dyad sorting by mean coupling
            rng(42);
            result = createGroupResult(testCase.nChannels, testCase.nDyads);

            fig = exploreFNIRS.hyperscanning.plotDyadMatrix(result, ...
                'Visible', 'off', 'SortDyads', 'mean');

            testCase.verifyTrue(ishandle(fig));
            close(fig);
        end

        function testPlotDyadMatrixSortedChannels(testCase)
            % Test with channel sorting by mean coupling
            rng(42);
            result = createGroupResult(testCase.nChannels, testCase.nDyads);

            fig = exploreFNIRS.hyperscanning.plotDyadMatrix(result, ...
                'Visible', 'off', 'SortChannels', 'mean');

            testCase.verifyTrue(ishandle(fig));
            close(fig);
        end

        function testPlotDyadMatrixCustomCLim(testCase)
            % Test with custom color limits
            rng(42);
            result = createGroupResult(testCase.nChannels, testCase.nDyads);

            fig = exploreFNIRS.hyperscanning.plotDyadMatrix(result, ...
                'Visible', 'off', 'CLim', [-0.5, 0.5]);

            testCase.verifyTrue(ishandle(fig));
            close(fig);
        end

    end


    %% plotGroupTemporal
    methods (Test)

        function testPlotGroupTemporalBasic(testCase)
            % Basic smoke test with windowed results
            rng(42);
            result = createWindowedGroupResult(testCase.nChannels, testCase.nDyads, 20);

            fig = exploreFNIRS.hyperscanning.plotGroupTemporal(result, ...
                'Visible', 'off');

            testCase.verifyTrue(ishandle(fig));
            close(fig);
        end

        function testPlotGroupTemporalWithSEM(testCase)
            % Test with explicit SEM error type
            rng(42);
            result = createWindowedGroupResult(testCase.nChannels, testCase.nDyads, 20);

            fig = exploreFNIRS.hyperscanning.plotGroupTemporal(result, ...
                'Visible', 'off', 'ErrorType', 'SEM');

            testCase.verifyTrue(ishandle(fig));
            close(fig);
        end

        function testPlotGroupTemporalWithSD(testCase)
            % Test with SD error bars
            rng(42);
            result = createWindowedGroupResult(testCase.nChannels, testCase.nDyads, 20);

            fig = exploreFNIRS.hyperscanning.plotGroupTemporal(result, ...
                'Visible', 'off', 'ErrorType', 'SD');

            testCase.verifyTrue(ishandle(fig));
            close(fig);
        end

        function testPlotGroupTemporalNoError(testCase)
            % Test with no error band
            rng(42);
            result = createWindowedGroupResult(testCase.nChannels, testCase.nDyads, 20);

            fig = exploreFNIRS.hyperscanning.plotGroupTemporal(result, ...
                'Visible', 'off', 'ErrorType', 'none');

            testCase.verifyTrue(ishandle(fig));
            close(fig);
        end

        function testPlotGroupTemporalChannelSubset(testCase)
            % Test with a subset of channels
            rng(42);
            result = createWindowedGroupResult(testCase.nChannels, testCase.nDyads, 20);

            fig = exploreFNIRS.hyperscanning.plotGroupTemporal(result, ...
                'Visible', 'off', 'Channels', [1, 3, 5]);

            testCase.verifyTrue(ishandle(fig));
            close(fig);
        end

        function testPlotGroupTemporalNonWindowedErrors(testCase)
            % Non-windowed result should error
            rng(42);
            result = createGroupResult(testCase.nChannels, testCase.nDyads);

            testCase.verifyError( ...
                @() exploreFNIRS.hyperscanning.plotGroupTemporal(result, ...
                    'Visible', 'off'), ...
                'exploreFNIRS:hyperscanning:plotGroupTemporal');
        end

    end

end


%% Helper functions

function result = createGroupResult(nCh, nDyads)
    % Mimics output from computeGroup with same-channel pairing
    result.Mean = rand(nCh, 1) * 0.5;
    result.SEM = rand(nCh, 1) * 0.1;
    result.SD = rand(nCh, 1) * 0.2;
    result.N = nDyads;
    result.method = 'pearson';
    result.biomarker = 'HbO';
    result.channels = 1:nCh;
    result.pvalue = rand(nCh, 1);
    result.tstat = randn(nCh, 1);
    % Dyad-level data
    result.dyads = cell(nDyads, 1);
    for d = 1:nDyads
        result.dyads{d}.values = rand(nCh, 1) * 0.6;
        result.dyads{d}.pvalues = rand(nCh, 1);
        result.dyads{d}.channelsA = 1:nCh;
        result.dyads{d}.channelsB = 1:nCh;
        result.dyads{d}.method = 'pearson';
        result.dyads{d}.pairing = 'same';
        result.dyads{d}.windowed = false;
    end
end


function result = createDyadResult(nCh)
    % Mimics output from computeDyad with same-channel pairing
    result.values = rand(nCh, 1) * 0.6;
    result.pvalues = rand(nCh, 1);
    result.channelsA = 1:nCh;
    result.channelsB = 1:nCh;
    result.method = 'pearson';
    result.biomarker = 'HbO';
    result.pairing = 'same';
    result.windowed = false;
end


function result = createWindowedGroupResult(nCh, nDyads, nWindows)
    % Mimics output from computeGroup with windowed coupling
    result.Mean = rand(nCh, 1) * 0.5;
    result.SEM = rand(nCh, 1) * 0.1;
    result.SD = rand(nCh, 1) * 0.2;
    result.N = nDyads;
    result.method = 'pearson';
    result.biomarker = 'HbO';
    result.channels = 1:nCh;
    result.pvalue = rand(nCh, 1);
    result.tstat = randn(nCh, 1);
    % Dyad-level data with windowed values
    windowTimes = linspace(0, 100, nWindows)';
    result.dyads = cell(nDyads, 1);
    for d = 1:nDyads
        result.dyads{d}.values = rand(nWindows, nCh) * 0.6;
        result.dyads{d}.pvalues = rand(nCh, 1);
        result.dyads{d}.channelsA = 1:nCh;
        result.dyads{d}.channelsB = 1:nCh;
        result.dyads{d}.method = 'pearson';
        result.dyads{d}.pairing = 'same';
        result.dyads{d}.windowed = true;
        result.dyads{d}.windowTimes = windowTimes;
    end
end
