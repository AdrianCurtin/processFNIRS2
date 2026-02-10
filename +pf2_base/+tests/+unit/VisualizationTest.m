classdef VisualizationTest < matlab.unittest.TestCase
    % VISUALIZATIONTEST Smoke tests for plotTopo, plotHeatmap, plotComposite
    %
    %   results = runtests('pf2_base.tests.unit.VisualizationTest');

    properties
        groups
    end

    methods (TestClassSetup)
        function setupGroups(testCase)
            % Create minimal groups struct matching aggregate() output
            T = 100;
            nCh = 8;
            timeVec = linspace(0, 20, T)';

            rng(42);
            for g = 1:2
                ga.time = timeVec;
                ga.units = 'uM';
                for bm = {'HbO','HbR'}
                    b = bm{1};
                    ga.(b).Mean = randn(T, nCh) * 0.5;
                    ga.(b).SEM = abs(randn(T, nCh)) * 0.1;
                    ga.(b).SD = abs(randn(T, nCh)) * 0.2;
                    ga.(b).N = ones(T, nCh) * 5;
                    ga.(b).data = randn(T, nCh, 5) * 0.5;
                end
                testCase.groups(g).gbyGrand = ga;
                testCase.groups(g).gbyGrandBarFlat = ga;
                testCase.groups(g).gbyTables = table();
                testCase.groups(g).gbyFNIRS = {};
                testCase.groups(g).gbyFNIRS_pp = {};
                testCase.groups(g).label = sprintf('Group%d', g);
            end
        end
    end

    methods (Test)

        function testPlotTopoSingle(testCase)
            fig = exploreFNIRS.core.plotTopo(testCase.groups, ...
                'Visible', 'off');
            testCase.verifyTrue(ishandle(fig));
            close(fig);
        end

        function testPlotTopoPerGroup(testCase)
            fig = exploreFNIRS.core.plotTopo(testCase.groups, ...
                'Layout', 'pergroup', 'Visible', 'off');
            testCase.verifyTrue(ishandle(fig));
            close(fig);
        end

        function testPlotTopoTimePoint(testCase)
            fig = exploreFNIRS.core.plotTopo(testCase.groups, ...
                'Time', 10, 'Visible', 'off');
            testCase.verifyTrue(ishandle(fig));
            close(fig);
        end

        function testPlotTopoTimeWindow(testCase)
            fig = exploreFNIRS.core.plotTopo(testCase.groups, ...
                'TimeWindow', [5, 15], 'Visible', 'off');
            testCase.verifyTrue(ishandle(fig));
            close(fig);
        end

        function testPlotHeatmapBasic(testCase)
            fig = exploreFNIRS.core.plotHeatmap(testCase.groups, ...
                'Visible', 'off');
            testCase.verifyTrue(ishandle(fig));
            close(fig);
        end

        function testPlotHeatmapSortAmplitude(testCase)
            fig = exploreFNIRS.core.plotHeatmap(testCase.groups, ...
                'SortChannels', 'amplitude', 'Visible', 'off');
            testCase.verifyTrue(ishandle(fig));
            close(fig);
        end

        function testPlotHeatmapChannelSubset(testCase)
            fig = exploreFNIRS.core.plotHeatmap(testCase.groups, ...
                'Channels', [1, 3, 5], 'Visible', 'off');
            testCase.verifyTrue(ishandle(fig));
            close(fig);
        end

        function testPlotCompositeBasic(testCase)
            panels = { ...
                struct('type', 'temporal', 'args', {{'Biomarkers', {'HbO'}}}), ...
                struct('type', 'bar', 'args', {{'Biomarker', 'HbO'}}) ...
            };
            fig = exploreFNIRS.core.plotComposite(testCase.groups, panels, ...
                'Layout', [1, 2], 'Visible', 'off');
            testCase.verifyTrue(ishandle(fig));
            close(fig);
        end

    end
end
