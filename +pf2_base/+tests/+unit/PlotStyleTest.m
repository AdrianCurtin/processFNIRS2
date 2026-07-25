classdef PlotStyleTest < matlab.unittest.TestCase
    % PLOTSTYLETEST Unit tests for PlotStyle, createFigure, and handleSave
    %
    %   results = runtests('pf2_base.tests.unit.PlotStyleTest');

    properties
        PrevForceLightMode
    end

    methods (TestMethodSetup)
        function forceLightMode(testCase)
            % The theme-dependent assertions here (createFigure's background
            % color) must not depend on ambient/leaked dark-theme state:
            % PlotStyle.isDarkMode() reads groot's defaultFigureColor, which
            % other rendering tests (and exportgraphics) can flip to dark and
            % not restore. Pin light mode per test and restore the previous
            % preference in teardown so this class is order-independent.
            testCase.PrevForceLightMode = pf2_base.plot.PlotStyle.getForceLightMode();
            pf2_base.plot.PlotStyle.setForceLightMode(true);
        end
    end

    methods (TestMethodTeardown)
        function restoreLightMode(testCase)
            pf2_base.plot.PlotStyle.setForceLightMode(testCase.PrevForceLightMode);
        end
    end

    methods (Test)

        function testDefaultProperties(testCase)
            s = pf2_base.plot.PlotStyle.getDefault();
            testCase.verifyEqual(s.FontSize, 11);
            testCase.verifyEqual(s.TitleFontSize, 13);
            testCase.verifyEqual(s.LineWidth, 1.5);
        end

        function testPublicationProperties(testCase)
            s = pf2_base.plot.PlotStyle.getPublication();
            testCase.verifyEqual(s.FontSize, 10);
            testCase.verifyEqual(s.LineWidth, 1.0);
        end

        function testPresentationProperties(testCase)
            s = pf2_base.plot.PlotStyle.getPresentation();
            testCase.verifyEqual(s.FontSize, 14);
            testCase.verifyEqual(s.LineWidth, 2.0);
        end

        function testApplyToAxes(testCase)
            fig = figure('Visible', 'off');
            cleanup = onCleanup(@() close(fig));
            ax = axes('Parent', fig);
            s = pf2_base.plot.PlotStyle.getDefault();
            s.applyToAxes(ax);
            testCase.verifyEqual(get(ax, 'FontSize'), 11);
            testCase.verifyEqual(get(ax, 'LineWidth'), 0.8);
        end

        function testCreateFigureHeadless(testCase)
            fig = pf2_base.plot.createFigure('Visible', 'off');
            cleanup = onCleanup(@() close(fig));
            testCase.verifyTrue(ishandle(fig));
            testCase.verifyEqual(get(fig, 'Color'), [1, 1, 1]);
        end

        function testCreateFigureForcesOffOnSave(testCase)
            fig = pf2_base.plot.createFigure('SavePath', 'dummy.png');
            cleanup = onCleanup(@() close(fig));
            testCase.verifyEqual(char(get(fig, 'Visible')), 'off');
        end

        function testHandleSaveCreatesFile(testCase)
            fig = figure('Visible', 'off');
            cleanup = onCleanup(@() close(fig));
            plot(1:10);

            tmpPath = [tempname, '.png'];
            fileCleanup = onCleanup(@() delete(tmpPath));

            opts.SavePath = tmpPath;
            opts.SaveWidth = 400;
            opts.SaveHeight = 300;
            opts.SaveDPI = 72;
            pf2_base.plot.handleSave(fig, opts);

            testCase.verifyTrue(exist(tmpPath, 'file') == 2);
        end

        function testHandleSaveNoOpWhenEmpty(testCase)
            fig = figure('Visible', 'off');
            cleanup = onCleanup(@() close(fig));
            opts.SavePath = '';
            pf2_base.plot.handleSave(fig, opts);
            % No error = pass
        end

    end
end
