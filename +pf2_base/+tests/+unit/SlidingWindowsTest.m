classdef SlidingWindowsTest < matlab.unittest.TestCase
    % SLIDINGWINDOWSTEST Unit tests for pf2.data.slidingWindows
    %
    % Tests fixed-length sliding-window block generation: contiguous and
    % overlapping grids, partial trailing windows, time bounds, embedding,
    % cell-array input, error handling, and integration with extractBlocks.
    %
    % Run all tests:
    %   results = runtests('pf2_base.tests.unit.SlidingWindowsTest');
    %
    % See also: pf2.data.slidingWindows, pf2.data.extractBlocks

    methods (Static)
        function data = makeData()
            % Minimal processed fNIRS struct: 300 s at 10 Hz, 4 channels
            fs = 10; T = 300; nSamples = T * fs; nCh = 4;
            data.time = (0:nSamples-1)' / fs;   % 0 .. 299.9 s
            data.fs = fs;
            data.HbO = randn(nSamples, nCh) * 0.01;
            data.HbR = randn(nSamples, nCh) * 0.005;
            data.HbDiff = data.HbO - data.HbR;
            data.HbTotal = data.HbO + data.HbR;
            data.CBSI = randn(nSamples, nCh) * 0.008;
            data.fchMask = ones(1, nCh);
            data.info = struct('SubjectID', 'S01');
            data.markers = pf2_base.normalizeMarkers(zeros(0, 4));
        end
    end

    methods (Test)
        function testContiguousCount(testCase)
            data = pf2_base.tests.unit.SlidingWindowsTest.makeData();
            b = pf2.data.slidingWindows(data, 'Length', 30, 'Embed', false);
            % Span is 0..299.9 s (last sample at 299.9), so 9 full 30 s
            % windows fit: starts 0,30,...,240 (270 would end past 299.9).
            testCase.verifyEqual(numel(b), 9);
            testCase.verifyEqual(b(1).startTime, 0, 'AbsTol', 1e-9);
            testCase.verifyEqual(b(1).duration, 30, 'AbsTol', 1e-9);
            % markerCode is NaN (not marker-driven)
            testCase.verifyTrue(isnan(b(1).markerCode));
        end

        function testOverlapStep(testCase)
            data = pf2_base.tests.unit.SlidingWindowsTest.makeData();
            b = pf2.data.slidingWindows(data, 'Length', 10, 'Overlap', 0.5, 'Embed', false);
            step = b(2).startTime - b(1).startTime;
            testCase.verifyEqual(step, 5, 'AbsTol', 1e-9);
            testCase.verifyEqual(b(1).duration, 10, 'AbsTol', 1e-9);
        end

        function testStepParameter(testCase)
            data = pf2_base.tests.unit.SlidingWindowsTest.makeData();
            b = pf2.data.slidingWindows(data, 'Length', 10, 'Step', 7, 'Embed', false);
            testCase.verifyEqual(b(2).startTime - b(1).startTime, 7, 'AbsTol', 1e-9);
        end

        function testTimeBounds(testCase)
            data = pf2_base.tests.unit.SlidingWindowsTest.makeData();
            b = pf2.data.slidingWindows(data, 'Length', 10, 'Start', 100, 'End', 150, 'Embed', false);
            testCase.verifyEqual(b(1).startTime, 100, 'AbsTol', 1e-9);
            testCase.verifyTrue(all([b.endTime] <= 150 + 1e-6));
        end

        function testPartialWindow(testCase)
            data = pf2_base.tests.unit.SlidingWindowsTest.makeData();
            % No full window fits; Partial keeps one short window
            b = pf2.data.slidingWindows(data, 'Length', 1e6, 'Partial', true, 'Embed', false);
            testCase.verifyEqual(numel(b), 1);
            testCase.verifyLessThan(b(1).duration, 1e6);
        end

        function testEmbed(testCase)
            data = pf2_base.tests.unit.SlidingWindowsTest.makeData();
            out = pf2.data.slidingWindows(data, 'Length', 30);   % Embed defaults true
            testCase.verifyTrue(isstruct(out) && isfield(out, 'blocks'));
            testCase.verifyEqual(numel(out.blocks), 9);
        end

        function testConditionLabel(testCase)
            data = pf2_base.tests.unit.SlidingWindowsTest.makeData();
            b = pf2.data.slidingWindows(data, 'Length', 30, 'Condition', 'rest', 'Embed', false);
            testCase.verifyEqual(b(1).info.Condition, 'rest');
            testCase.verifyEqual(b(1).info.WindowNumber, 1);
        end

        function testExtractBlocksIntegration(testCase)
            data = pf2_base.tests.unit.SlidingWindowsTest.makeData();
            b = pf2.data.slidingWindows(data, 'Length', 30, 'Embed', false);
            segs = pf2.data.extractBlocks(data, b, 'PreTime', 0, 'PostTime', 0, 'SetT0', true);
            testCase.verifyEqual(numel(segs), 9);
            % 30 s at 10 Hz -> ~300 samples per segment
            testCase.verifyGreaterThan(size(segs{1}.HbO, 1), 290);
        end

        function testCellArray(testCase)
            data = pf2_base.tests.unit.SlidingWindowsTest.makeData();
            out = pf2.data.slidingWindows({data, data}, 'Length', 30, 'Embed', true);
            testCase.verifyClass(out, 'cell');
            testCase.verifyEqual(numel(out{1}.blocks), 9);
            testCase.verifyEqual(numel(out{2}.blocks), 9);
        end

        function testErrorNoLength(testCase)
            data = pf2_base.tests.unit.SlidingWindowsTest.makeData();
            testCase.verifyError(@() pf2.data.slidingWindows(data), ...
                'pf2:slidingWindows:noLength');
        end

        function testErrorStepAndOverlap(testCase)
            data = pf2_base.tests.unit.SlidingWindowsTest.makeData();
            testCase.verifyError(@() pf2.data.slidingWindows(data, ...
                'Length', 10, 'Step', 5, 'Overlap', 0.5), ...
                'pf2:slidingWindows:stepAndOverlap');
        end

        function testWindowTooLongEmpty(testCase)
            % No full window fits and Partial is off -> empty + warning
            data = pf2_base.tests.unit.SlidingWindowsTest.makeData();
            testCase.verifyWarning(@() pf2.data.slidingWindows(data, ...
                'Length', 1e6, 'Embed', false), 'pf2:slidingWindows:windowTooLong');
            b = pf2.data.slidingWindows(data, 'Length', 1e6, 'Embed', false);
            testCase.verifyEmpty(b);
            % Embed path returns the struct with an empty .blocks
            out = pf2.data.slidingWindows(data, 'Length', 1e6, 'Embed', true);
            testCase.verifyTrue(isstruct(out) && isfield(out, 'blocks'));
            testCase.verifyEmpty(out.blocks);
        end

        function testPartialClipsToSpanEnd(testCase)
            % Several full windows then one clipped trailing window
            data = pf2_base.tests.unit.SlidingWindowsTest.makeData();
            b = pf2.data.slidingWindows(data, 'Length', 40, 'Step', 40, ...
                'Partial', true, 'Embed', false);
            % Last window must end exactly at the span end (max time), clipped
            testCase.verifyEqual(b(end).endTime, max(data.time), 'AbsTol', 1e-6);
            testCase.verifyLessThan(b(end).duration, 40);
        end

        function testCustomConditionField(testCase)
            data = pf2_base.tests.unit.SlidingWindowsTest.makeData();
            b = pf2.data.slidingWindows(data, 'Length', 30, 'Condition', 'A', ...
                'ConditionField', 'Phase', 'Embed', false);
            testCase.verifyEqual(b(1).info.Phase, 'A');
            testCase.verifyEqual(b(1).info.WindowOnset, b(1).startTime, 'AbsTol', 1e-9);
        end

        function testErrorNoTime(testCase)
            bad = struct('HbO', randn(10, 2));   % no .time
            testCase.verifyError(@() pf2.data.slidingWindows(bad, 'Length', 5), ...
                'pf2:slidingWindows:noTime');
        end

        function testErrorEmptySpan(testCase)
            data = pf2_base.tests.unit.SlidingWindowsTest.makeData();
            testCase.verifyError(@() pf2.data.slidingWindows(data, ...
                'Length', 5, 'Start', 100, 'End', 50), ...
                'pf2:slidingWindows:emptySpan');
        end
    end
end
