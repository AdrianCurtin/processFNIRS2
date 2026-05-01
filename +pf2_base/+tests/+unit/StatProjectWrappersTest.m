classdef StatProjectWrappersTest < matlab.unittest.TestCase
    % STATPROJECTWRAPPERSTEST Smoke tests for pf2.probe.project.* wrappers
    %
    % Covers pvalues, fstats, correlation, biomarker, counts. Tests assert
    % that each wrapper runs end-to-end against synthetic inputs and produces
    % a valid figure (Brain patch) plus, where expected, a BrainOverlay patch
    % indicating transparent stat rendering.
    %
    %   results = runtests('pf2_base.tests.unit.StatProjectWrappersTest');

    properties
        processed
        K     % number of channels
        fig
    end

    methods (TestClassSetup)
        function prepare(testCase)
            raw = pf2.import.sampleData.fNIR2000();
            testCase.processed = processFNIRS2(raw);
            testCase.K = size(testCase.processed.HbO, 2);
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

        function testPValues(testCase)
            rng(1);
            pvals = rand(1, testCase.K);
            pvals([1 3 5]) = 0.002;
            ax = axes('Parent', testCase.fig);
            pf2.probe.project.pvalues(pvals, testCase.processed, ...
                'pThreshold', 0.05, 'ax', ax);
            overlay = findall(ax, 'Type', 'Patch', 'Tag', 'BrainOverlay');
            testCase.verifyNotEmpty(overlay, 'pvalues should render transparent overlay.');
        end

        function testPValuesWithFDR(testCase)
            rng(1);
            pvals = rand(1, testCase.K) * 0.5;
            pvals([1 5]) = 0.001;
            ax = axes('Parent', testCase.fig);
            pf2.probe.project.pvalues(pvals, testCase.processed, ...
                'FDR', true, 'pThreshold', 0.05, 'ax', ax);
            brain = findall(ax, 'Type', 'Patch', 'Tag', 'Brain');
            testCase.verifyNotEmpty(brain);
        end

        function testPValuesLinearScale(testCase)
            rng(1);
            pvals = rand(1, testCase.K);
            pvals([2 4]) = 0.01;
            ax = axes('Parent', testCase.fig);
            pf2.probe.project.pvalues(pvals, testCase.processed, ...
                'LogScale', false, 'ax', ax);
            cbars = findall(testCase.fig, 'Type', 'ColorBar');
            testCase.verifyNotEmpty(cbars);
        end

        function testFStatsWithPValues(testCase)
            rng(2);
            F = abs(randn(1, testCase.K)) * 3 + 1;
            F([1 3 5]) = F([1 3 5]) + 10;
            pvals = rand(1, testCase.K);
            pvals([1 3 5]) = 0.001;
            ax = axes('Parent', testCase.fig);
            pf2.probe.project.fstats(F, testCase.processed, ...
                'pvalues', pvals, 'pThreshold', 0.05, 'ax', ax);
            overlay = findall(ax, 'Type', 'Patch', 'Tag', 'BrainOverlay');
            testCase.verifyNotEmpty(overlay);
        end

        function testFStatsWithFcritical(testCase)
            rng(2);
            F = abs(randn(1, testCase.K)) * 2;
            F([1 3 5]) = 10;
            ax = axes('Parent', testCase.fig);
            pf2.probe.project.fstats(F, testCase.processed, ...
                'Fcritical', 3.84, 'ax', ax);
            overlay = findall(ax, 'Type', 'Patch', 'Tag', 'BrainOverlay');
            testCase.verifyNotEmpty(overlay);
        end

        function testCorrelationWithP(testCase)
            rng(3);
            rho = 2 * rand(1, testCase.K) - 1;
            pvals = rand(1, testCase.K);
            pvals([1 3]) = 0.001;
            ax = axes('Parent', testCase.fig);
            pf2.probe.project.correlation(rho, testCase.processed, ...
                'pvalues', pvals, 'pThreshold', 0.05, 'ax', ax);
            cbars = findall(testCase.fig, 'Type', 'ColorBar');
            testCase.verifyGreaterThanOrEqual(numel(cbars), 2, ...
                'Correlation should render two colorbars (signed rho).');
        end

        function testCorrelationWithoutP(testCase)
            rng(3);
            rho = 2 * rand(1, testCase.K) - 1;
            ax = axes('Parent', testCase.fig);
            pf2.probe.project.correlation(rho, testCase.processed, 'ax', ax);
            brain = findall(ax, 'Type', 'Patch', 'Tag', 'Brain');
            testCase.verifyNotEmpty(brain);
        end

        function testBiomarker(testCase)
            vals = testCase.processed.HbO(100, :);
            ax = axes('Parent', testCase.fig);
            pf2.probe.project.biomarker(vals, testCase.processed, ...
                'Range', [-1 1], 'ax', ax);
            cbars = findall(testCase.fig, 'Type', 'ColorBar');
            testCase.verifyGreaterThanOrEqual(numel(cbars), 2);
        end

        function testBiomarkerWithSignificance(testCase)
            rng(4);
            vals = testCase.processed.HbO(100, :);
            pvals = rand(1, testCase.K);
            pvals([1 3 5]) = 0.001;
            ax = axes('Parent', testCase.fig);
            pf2.probe.project.biomarker(vals, testCase.processed, ...
                'Range', [-1 1], 'pvalues', pvals, 'ax', ax);
            overlay = findall(ax, 'Type', 'Patch', 'Tag', 'BrainOverlay');
            testCase.verifyNotEmpty(overlay);
        end

        function testCounts(testCase)
            rng(5);
            N = randi([5 30], 1, testCase.K);
            ax = axes('Parent', testCase.fig);
            pf2.probe.project.counts(N, testCase.processed, 'ax', ax);
            brain = findall(ax, 'Type', 'Patch', 'Tag', 'Brain');
            testCase.verifyNotEmpty(brain);
            cbars = findall(testCase.fig, 'Type', 'ColorBar');
            testCase.verifyNotEmpty(cbars);
        end

    end
end
