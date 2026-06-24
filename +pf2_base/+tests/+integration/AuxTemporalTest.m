classdef AuxTemporalTest < matlab.unittest.TestCase
    % AUXTEMPORALTEST End-to-end tests for event-related Aux averaging & overlay
    %
    % Exercises Phase 4 of the Aux roadmap on real sample data:
    %   - The group aggregation produces trial-averaged Aux (Mean/SEM/N) on the
    %     epoch time grid.
    %   - plotTemporal 'AuxOverlay' draws the averaged Aux on a right y-axis
    %     (opt-in: no second axis by default).
    %
    % Run all tests:
    %   results = runtests('pf2_base.tests.integration.AuxTemporalTest');

    properties
        ex   % aggregated sample-group Experiment (built once)
    end

    methods (TestClassSetup)
        function build(testCase)
            warning('off', 'all');
            [e, ~] = pf2.import.sampleData.group();
            testCase.ex = e.aggregate();
        end
    end

    methods (Test)
        function testAuxTrialAveraged(testCase)
            gg = testCase.ex.groups(1).gbyGrand;
            testCase.verifyTrue(isfield(gg, 'Aux'), 'gbyGrand should carry Aux');
            src = gg.Aux.heartRate_data;
            testCase.verifyTrue(isstruct(src) && isfield(src, 'Mean'));
            % Averaged aux lives on the same epoch grid as the biomarkers
            testCase.verifyEqual(size(src.Mean, 1), numel(gg.time));
            testCase.verifyTrue(isfield(src, 'SEM') && isfield(src, 'N'));
            testCase.verifyEqual(size(src.SEM, 1), numel(gg.time));
        end

        function testAuxOverlayAddsRightAxis(testCase)
            fig = exploreFNIRS.core.plotTemporal(testCase.ex.groups, ...
                'Biomarkers', {'HbO'}, 'Channels', 1, 'Visible', 'off', ...
                'AuxOverlay', {'heartRate'});
            c = onCleanup(@() close(fig));
            ax = findobj(fig, 'type', 'axes');
            testCase.verifyGreaterThanOrEqual(numel(ax), 1);
            testCase.verifyEqual(numel(ax(1).YAxis), 2, ...
                'AuxOverlay should create a right (second) y-axis');
        end

        function testNoOverlayByDefault(testCase)
            fig = exploreFNIRS.core.plotTemporal(testCase.ex.groups, ...
                'Biomarkers', {'HbO'}, 'Channels', 1, 'Visible', 'off');
            c = onCleanup(@() close(fig));
            ax = findobj(fig, 'type', 'axes');
            testCase.verifyEqual(numel(ax(1).YAxis), 1, ...
                'Default plot should have a single y-axis');
        end
    end
end
