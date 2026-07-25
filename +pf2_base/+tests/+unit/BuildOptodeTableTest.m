classdef BuildOptodeTableTest < matlab.unittest.TestCase
    % BUILDOPTODETABLETEST Unit tests for pf2_base.buildOptodeTable
    %
    % Locks the TableOpt schema contract the rest of the toolbox depends on:
    % expected columns, OptodeNum sorting (interchangeable with loadDeviceCfg),
    % source/detector recovery from TableCh (NaN when unmatched), graceful
    % omission of absent geometry, and short-separation derivation.

    methods (Static)
        function probe = makeProbe(chOrder)
            % Build a probe whose per-channel geometry is stored in chOrder
            % order, so tests can confirm rows stay aligned to their OptodeNum
            % after the internal sort. Source/detector indices are a
            % deterministic function of OptodeNum for easy verification.
            chOrder = chOrder(:);
            n = numel(chOrder);
            probe.ChannelList = chOrder';
            probe.OptPos3D = [chOrder, chOrder + 10, chOrder + 20];
            probe.OptPosX = chOrder;  probe.OptPosY = chOrder + 1;  probe.OptPosZ = chOrder + 2;
            probe.SD = (chOrder' / 10);                       % optode k -> SD = k/10 cm
            % Two wavelength rows per channel; src/det identical across them.
            opt = repelem(chOrder, 2);
            src = opt * 10;  det = opt * 100;
            probe.TableCh = table(opt, src, det, ...
                'VariableNames', {'OptodeNumber', 'SourceIndex', 'DetectorIndex'});
        end
    end

    methods (Test)

        function schemaColumnsPresent(testCase)
            T = pf2_base.buildOptodeTable(testCase.makeProbe(1:4));
            testCase.verifyEqual(height(T), 4);
            for col = {'OptodeNum','SrcIdx','DetIdx','Pos2D_x','Pos3D_x','SD','IsShortSeparation'}
                testCase.verifyTrue(ismember(col{1}, T.Properties.VariableNames), ...
                    sprintf('missing column %s', col{1}));
            end
        end

        function sortedByOptodeNumWithAlignedData(testCase)
            % Unordered channel list must come out sorted by OptodeNum with the
            % per-channel SD / source / detector still attached to the right one.
            T = pf2_base.buildOptodeTable(testCase.makeProbe([3 1 2]));
            testCase.verifyEqual(T.OptodeNum, [1;2;3]);
            testCase.verifyEqual(T.SD, [0.1;0.2;0.3], 'AbsTol', 1e-12);   % k/10
            testCase.verifyEqual(T.SrcIdx, [10;20;30]);                    % k*10
            testCase.verifyEqual(T.DetIdx, [100;200;300]);                 % k*100
            testCase.verifyEqual(T.Pos3D_x, [1;2;3]);                      % optode k -> x=k
        end

        function srcDetNaNForUnmatchedChannel(testCase)
            % Channel absent from TableCh -> NaN Src/Det (not an error).
            probe = testCase.makeProbe(1:3);
            % Drop channel 2's rows from TableCh entirely.
            keep = probe.TableCh.OptodeNumber ~= 2;
            probe.TableCh = probe.TableCh(keep, :);
            T = pf2_base.buildOptodeTable(probe);
            testCase.verifyEqual(T.OptodeNum, [1;2;3]);
            testCase.verifyTrue(isnan(T.SrcIdx(2)) && isnan(T.DetIdx(2)));
            testCase.verifyFalse(any(isnan(T.SrcIdx([1 3]))));
        end

        function geometryColumnsOmittedWhenAbsent(testCase)
            % Only SD present -> no Pos3D columns.
            p1.ChannelList = 1:3;  p1.SD = [0.1 3 4];
            T1 = pf2_base.buildOptodeTable(p1);
            testCase.verifyFalse(ismember('Pos3D_x', T1.Properties.VariableNames));
            testCase.verifyTrue(ismember('SD', T1.Properties.VariableNames));

            % Only 3D positions present -> no SD column.
            p2.ChannelList = 1:3;  p2.OptPos3D = [1 2 3; 4 5 6; 7 8 9];
            T2 = pf2_base.buildOptodeTable(p2);
            testCase.verifyTrue(ismember('Pos3D_x', T2.Properties.VariableNames));
            testCase.verifyFalse(ismember('SD', T2.Properties.VariableNames));
        end

        function shortSeparationDerivedAndHonored(testCase)
            % Derived from SD < 2 cm when not supplied.
            T = pf2_base.buildOptodeTable(testCase.makeProbe([1 25 30]));  % SD = 0.1, 2.5, 3.0
            testCase.verifyEqual(T.IsShortSeparation, [true; false; false]);

            % Explicit flag honored over derivation.
            p.ChannelList = 1:2;  p.SD = [0.1 0.2];  p.IsShortSeparation = [false true];
            T2 = pf2_base.buildOptodeTable(p);
            testCase.verifyEqual(T2.IsShortSeparation, [false; true]);
        end

        function noChannelsErrors(testCase)
            testCase.verifyError(@() pf2_base.buildOptodeTable(struct('foo', 1)), ...
                'pf2_base:buildOptodeTable:noChannels');
        end

    end
end
