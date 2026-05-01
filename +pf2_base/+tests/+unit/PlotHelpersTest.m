classdef PlotHelpersTest < matlab.unittest.TestCase
    % PLOTHELPERSTEST Unit tests for plot helper functions
    %
    % Tests the new helper functions in +pf2_base/+plot/:
    %   - processMarkers
    %   - processBaseline
    %   - getOptodePosition
    %
    % Note: loadProbeInfo is not tested here as it requires device config files.

    methods (Test)
        %% processMarkers tests
        function testProcessMarkers_showAll(testCase)
            fNIR.markers = [1, 10, 0, 1; 2, 20, 0, 1; 3, 10, 0, 1; 4, 30, 0, 1];
            [codes, idx, data, counts] = pf2_base.plot.processMarkers(fNIR, true);

            testCase.verifyEqual(length(codes), 3);  % 10, 20, 30
            testCase.verifyEqual(length(idx), 4);
            testCase.verifyEqual(sum(counts), 4);
        end

        function testProcessMarkers_showNone(testCase)
            fNIR.markers = [1, 10, 0, 1; 2, 20, 0, 1];
            [codes, idx, data, counts] = pf2_base.plot.processMarkers(fNIR, false);

            testCase.verifyEmpty(codes);
            testCase.verifyEmpty(idx);
        end

        function testProcessMarkers_showSpecific(testCase)
            fNIR.markers = [1, 10, 0, 1; 2, 20, 0, 1; 3, 10, 0, 1; 4, 30, 0, 1];
            [codes, idx, data, counts] = pf2_base.plot.processMarkers(fNIR, [10, 30]);

            testCase.verifyEqual(length(codes), 2);
            testCase.verifyTrue(ismember(10, codes));
            testCase.verifyTrue(ismember(30, codes));
            testCase.verifyFalse(ismember(20, codes));
        end

        function testProcessMarkers_noMarkers(testCase)
            fNIR = struct();  % No markers field
            [codes, idx, data, counts] = pf2_base.plot.processMarkers(fNIR, true);

            testCase.verifyEmpty(codes);
            testCase.verifyEmpty(data);
        end

        function testProcessMarkers_emptyMarkers(testCase)
            fNIR.markers = [];
            [codes, idx, data, counts] = pf2_base.plot.processMarkers(fNIR, true);

            testCase.verifyEmpty(codes);
        end

        function testProcessMarkers_allString(testCase)
            fNIR.markers = [1, 10, 0, 1; 2, 20, 0, 1];
            [codes, ~, ~, ~] = pf2_base.plot.processMarkers(fNIR, 'all');

            testCase.verifyEqual(length(codes), 2);
        end

        %% processBaseline tests
        function testProcessBaseline_noBaseline(testCase)
            fNIR.time = (0:0.1:100)';
            fNIR.HbO = rand(length(fNIR.time), 10);
            [~, blWin] = pf2_base.plot.processBaseline(fNIR, false);

            testCase.verifyEmpty(blWin);
        end

        function testProcessBaseline_defaultBaseline(testCase)
            fNIR.time = (0:0.1:100)';
            fNIR.HbO = rand(length(fNIR.time), 10);
            fNIR.HbR = rand(length(fNIR.time), 10);
            fNIR.HbTotal = rand(length(fNIR.time), 10);
            fNIR.HbDiff = rand(length(fNIR.time), 10);
            fNIR.CBSI = rand(length(fNIR.time), 10);
            [corrected, blWin] = pf2_base.plot.processBaseline(fNIR, true);

            testCase.verifyTrue(isnan(blWin(1)));  % start is nan for relative
            testCase.verifyEqual(blWin(2), 10);    % default 10s
        end

        function testProcessBaseline_positiveScalar(testCase)
            fNIR.time = (0:0.1:100)';
            fNIR.HbO = rand(length(fNIR.time), 10);
            fNIR.HbR = rand(length(fNIR.time), 10);
            fNIR.HbTotal = rand(length(fNIR.time), 10);
            fNIR.HbDiff = rand(length(fNIR.time), 10);
            fNIR.CBSI = rand(length(fNIR.time), 10);
            [~, blWin] = pf2_base.plot.processBaseline(fNIR, 15);

            testCase.verifyTrue(isnan(blWin(1)));
            testCase.verifyEqual(blWin(2), 15);
        end

        function testProcessBaseline_explicitWindow(testCase)
            fNIR.time = (0:0.1:100)';
            fNIR.HbO = rand(length(fNIR.time), 10);
            fNIR.HbR = rand(length(fNIR.time), 10);
            fNIR.HbTotal = rand(length(fNIR.time), 10);
            fNIR.HbDiff = rand(length(fNIR.time), 10);
            fNIR.CBSI = rand(length(fNIR.time), 10);
            [~, blWin] = pf2_base.plot.processBaseline(fNIR, [10, 20]);

            testCase.verifyEqual(blWin(1), 10);
            testCase.verifyEqual(blWin(2), 20);
        end

        %% getOptodePosition tests
        function testGetOptodePosition_basic(testCase)
            % Create mock layout
            optLayout = cell(1, 3);
            optLayout{1} = [0.1, 0.1, 0.2, 0.2];
            optLayout{2} = [0.4, 0.1, 0.2, 0.2];
            optLayout{3} = [0.7, 0.1, 0.2, 0.2];

            pos = pf2_base.plot.getOptodePosition(optLayout, 1);

            testCase.verifySize(pos, [1, 4]);
            % Y should be flipped
            expectedY = 1 - 0.1 - 0.2;
            testCase.verifyEqual(pos(2), expectedY, 'AbsTol', 0.001);
        end

        function testGetOptodePosition_withScale(testCase)
            optLayout = cell(1, 1);
            optLayout{1} = [0.1, 0.1, 0.2, 0.2];

            pos = pf2_base.plot.getOptodePosition(optLayout, 1, [0.5, 0.5]);

            % Width/height should be scaled
            testCase.verifyEqual(pos(3), 0.2 * 0.5, 'AbsTol', 0.001);
            testCase.verifyEqual(pos(4), 0.2 * 0.5, 'AbsTol', 0.001);
        end

        function testGetOptodePosition_withOffset(testCase)
            optLayout = cell(1, 1);
            optLayout{1} = [0.1, 0.1, 0.2, 0.2];

            pos = pf2_base.plot.getOptodePosition(optLayout, 1, [1, 1], [0.05, 0.05]);

            % Position should include offset
            testCase.verifyEqual(pos(1), 0.1 + 0.05, 'AbsTol', 0.001);
        end

        function testGetOptodePosition_outOfBounds(testCase)
            optLayout = cell(1, 2);
            optLayout{1} = [0.1, 0.1, 0.2, 0.2];
            optLayout{2} = [0.4, 0.1, 0.2, 0.2];

            pos = pf2_base.plot.getOptodePosition(optLayout, 5);

            testCase.verifyEmpty(pos);
        end

        function testGetOptodePosition_defaultParams(testCase)
            optLayout = cell(1, 1);
            optLayout{1} = [0.1, 0.5, 0.3, 0.3];

            pos = pf2_base.plot.getOptodePosition(optLayout, 1);

            % Check default scale [0.65, 0.9] is applied
            testCase.verifyEqual(pos(3), 0.3 * 0.65, 'AbsTol', 0.001);
            testCase.verifyEqual(pos(4), 0.3 * 0.9, 'AbsTol', 0.001);

            % Check default offset [0.03, 0] is applied
            testCase.verifyEqual(pos(1), 0.1 + 0.03, 'AbsTol', 0.001);
        end

        %% vline numeric-color regression
        function testVlineAcceptsRGBTriple(testCase)
            % Regression: pf2.data.plot.raw / .oxy pass sty.ForegroundColor
            % (an RGB triple) as the linespec slot. vline used to reject
            % this with 'lineVarargin must be ischar||iscell'.
            fig = figure('Visible', 'off');
            cleanup = onCleanup(@() close(fig)); %#ok<NASGU>
            plot(0:10, sin(0:10));
            % Triple
            testCase.verifyWarningFree(@() ...
                pf2_base.external.vline(5, [0.2 0.3 0.4], 'lab', 0.5));
            % Quad (RGBA)
            testCase.verifyWarningFree(@() ...
                pf2_base.external.vline(5, [0.2 0.3 0.4 0.8], 'lab', 0.5));
            % Linespec still works
            testCase.verifyWarningFree(@() ...
                pf2_base.external.vline(5, 'r:', 'lab', 0.5));
            % Cell of options still works
            testCase.verifyWarningFree(@() ...
                pf2_base.external.vline(5, {'Color', [0 0 0], 'LineWidth', 2}, ...
                    'lab', 0.5));
        end
    end
end
