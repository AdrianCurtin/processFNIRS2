classdef GUIHelpersTest < matlab.unittest.TestCase
    % GUIHELPERSTEST Unit tests for GUI helper functions
    %
    % Tests the new helper functions in +pf2_base/+gui/:
    %   - getTimeIndices
    %   - getWavelengthColors
    %   - filterOptodeTable
    %
    % Also tests:
    %   - pf2.data.crop
    %   - pf2_base.GUIContext

    methods (Test)
        function testGetTimeIndices_basic(testCase)
            time = (0:0.1:100)';
            [idx, s, e] = pf2_base.gui.getTimeIndices(time, 20, 40);

            testCase.verifyGreaterThan(s, 1);
            testCase.verifyGreaterThan(e, s);
            testCase.verifyEqual(sum(idx), e - s + 1);
        end

        function testGetTimeIndices_emptyTime(testCase)
            [idx, s, e] = pf2_base.gui.getTimeIndices([], 20, 40);

            testCase.verifyEmpty(idx);
            testCase.verifyEqual(s, 1);
            testCase.verifyEqual(e, 1);
        end

        function testGetTimeIndices_fullRange(testCase)
            time = (0:0.1:100)';
            [idx, ~, ~] = pf2_base.gui.getTimeIndices(time, 0, 100);

            testCase.verifyEqual(sum(idx), length(time));
        end

        function testGetWavelengthColors_basic(testCase)
            wavelengths = [730, 850, 730, 850, 730, 850];
            plotIdx = [1, 3, 5];
            [colors, wvs] = pf2_base.gui.getWavelengthColors(wavelengths, plotIdx);

            testCase.verifySize(colors, [3, 3]);
            testCase.verifyEqual(length(wvs), 2);
        end

        function testGetWavelengthColors_singleWavelength(testCase)
            wavelengths = [730, 730, 730, 730];
            plotIdx = [1, 2, 3];
            [colors, wvs] = pf2_base.gui.getWavelengthColors(wavelengths, plotIdx);

            testCase.verifySize(colors, [3, 3]);
            % All should be the same color
            testCase.verifyEqual(colors(1,:), colors(2,:));
            testCase.verifyEqual(colors(2,:), colors(3,:));
        end

        function testCrop_basic(testCase)
            time = (0:0.1:100)';
            data = struct('time', time, 'raw', rand(length(time), 10));
            cropped = pf2.data.crop(data, 20, 40);

            testCase.verifyGreaterThanOrEqual(min(cropped.time), 20);
            testCase.verifyLessThanOrEqual(max(cropped.time), 40);
        end

        function testCrop_toEnd(testCase)
            time = (0:0.1:100)';
            data = struct('time', time, 'raw', rand(length(time), 10));
            cropped = pf2.data.crop(data, 50);

            testCase.verifyGreaterThanOrEqual(min(cropped.time), 50);
            testCase.verifyEqual(max(cropped.time), max(time));
        end

        function testGUIContext_creation(testCase)
            ctx = pf2_base.GUIContext();

            testCase.verifyEqual(ctx.dpfMode, 'Calc');
            testCase.verifyEqual(ctx.subjectAge, 25);
            testCase.verifyEqual(ctx.baselineLength, 10);
        end

        function testGUIContext_setViewWindow(testCase)
            ctx = pf2_base.GUIContext();
            ctx.setViewWindow(10, 50);

            testCase.verifyEqual(ctx.view.startTime, 10);
            testCase.verifyEqual(ctx.view.endTime, 50);
        end

        function testGUIContext_getBaselineStruct(testCase)
            ctx = pf2_base.GUIContext();
            ctx.baselineStartTime = 5;
            ctx.baselineLength = 15;

            bl = ctx.getBaselineStruct();

            testCase.verifyEqual(bl.startTime, 5);
            testCase.verifyEqual(bl.blLength, 15);
        end

        function testFilterOptodeTable_emptyTable(testCase)
            [single, roi] = pf2_base.gui.filterOptodeTable(table(), []);

            testCase.verifyEmpty(single);
            testCase.verifyEmpty(roi);
        end
    end
end
