classdef UnifiedPlotTest < matlab.unittest.TestCase
% UNIFIEDPLOTTEST Smoke tests for the unified plot API (PlotProxy)
%
% Tests the grammar-of-graphics style API: ex.plot.bar(), ex.plot.temporal(),
% ex.plot.scatter() with dimension mapping, Filter, interaction terms, and
% shared Y-axis.
%
% Run with:
%   results = runtests('pf2_base.tests.unit.UnifiedPlotTest');

    properties
        allData   % Cell array of processed fNIRS structs
        ex        % Experiment object (aggregated)
    end

    methods (TestClassSetup)
        function buildTestData(tc)
            raw = pf2.import.sampleData.fNIR2000();
            processed = processFNIRS2(raw);

            rng(42);
            subjects = {'S01','S01','S01','S01', 'S02','S02','S02','S02', 'S03','S03','S03','S03'};
            groups   = {'Ctrl','Ctrl','Ctrl','Ctrl','Ctrl','Ctrl','Ctrl','Ctrl','Tx','Tx','Tx','Tx'};
            conds    = {'Easy','Hard','Easy','Hard','Easy','Hard','Easy','Hard','Easy','Hard','Easy','Hard'};
            ages     = [25, 25, 25, 25, 30, 30, 30, 30, 28, 28, 28, 28];

            nSeg = length(subjects);
            tc.allData = cell(nSeg, 1);
            for i = 1:nSeg
                d = processed;
                d.info.SubjectID = subjects{i};
                d.info.Group = groups{i};
                d.info.Condition = conds{i};
                d.info.Age = ages(i);
                d.info.reactionTime = 200 + 100*strcmp(conds{i},'Hard') + randn*20;
                tc.allData{i} = d;
            end

            % Pre-build experiment (will be state-restored after each plot)
            tc.ex = exploreFNIRS.core.Experiment(tc.allData);
        end
    end

    methods (Test)

        %% --- Filter class ---

        function testFilterCreate(tc)
            f = exploreFNIRS.core.Filter();
            tc.verifyTrue(f.isEmpty());
        end

        function testFilterInclude(tc)
            f = exploreFNIRS.core.Filter().include('Group', 'Ctrl');
            idx = f.apply(tc.ex.dataTable);
            tc.verifyEqual(sum(idx), 8);
        end

        function testFilterExclude(tc)
            f = exploreFNIRS.core.Filter().exclude('Condition', 'Hard');
            idx = f.apply(tc.ex.dataTable);
            tc.verifyEqual(sum(idx), 6);
        end

        function testFilterChannels(tc)
            f = exploreFNIRS.core.Filter().ch([1, 5]).bio({'HbO'});
            tc.verifyEqual(f.channels, [1, 5]);
            tc.verifyEqual(f.biomarkers, {'HbO'});
        end

        function testFilterAnd(tc)
            f1 = exploreFNIRS.core.Filter().include('Group', 'Ctrl');
            f2 = exploreFNIRS.core.Filter().include('Condition', 'Easy');
            f3 = f1.and(f2);
            idx = f3.apply(tc.ex.dataTable);
            tc.verifyEqual(sum(idx), 4);
        end

        %% --- PlotProxy access ---

        function testPlotProxyExists(tc)
            proxy = tc.ex.plot;
            tc.verifyClass(proxy, 'exploreFNIRS.core.PlotProxy');
        end

        %% --- Bar plots ---

        function testBarSimple(tc)
            fig = tc.ex.plot.bar('X', 'Group', 'Channels', 1:3, 'Visible', 'off');
            tc.verifyClass(fig, 'matlab.ui.Figure');
            close(fig);
        end

        function testBarWithColor(tc)
            fig = tc.ex.plot.bar('X', 'Condition', 'Color', 'Group', ...
                'Channels', 1:3, 'Visible', 'off');
            tc.verifyClass(fig, 'matlab.ui.Figure');
            close(fig);
        end

        function testBarInteractionX(tc)
            fig = tc.ex.plot.bar('X', 'Condition:Group', ...
                'Channels', 1:3, 'Visible', 'off');
            tc.verifyClass(fig, 'matlab.ui.Figure');
            close(fig);
        end

        function testBarWithSubplotRows(tc)
            fig = tc.ex.plot.bar('X', 'Condition', ...
                'SubplotRows', 'Group', 'Channels', 1:3, 'Visible', 'off');
            tc.verifyClass(fig, 'matlab.ui.Figure');
            close(fig);
        end

        function testBarWithFilter(tc)
            f = exploreFNIRS.core.Filter().include('Group', 'Ctrl');
            fig = tc.ex.plot.bar('X', 'Condition', 'Channels', 1:3, ...
                'Filter', f, 'Visible', 'off');
            tc.verifyClass(fig, 'matlab.ui.Figure');
            close(fig);
        end

        function testBarShowIndividual(tc)
            fig = tc.ex.plot.bar('X', 'Group', 'Channels', 1:3, ...
                'ShowIndividual', true, 'Visible', 'off');
            tc.verifyClass(fig, 'matlab.ui.Figure');
            close(fig);
        end

        %% --- Temporal plots ---

        function testTemporalSimple(tc)
            fig = tc.ex.plot.temporal('Color', 'Group', ...
                'Channels', 1:3, 'Biomarkers', {'HbO'}, 'Visible', 'off');
            tc.verifyClass(fig, 'matlab.ui.Figure');
            close(fig);
        end

        function testTemporalWithSubplotRows(tc)
            fig = tc.ex.plot.temporal('Color', 'Condition', ...
                'SubplotRows', 'Group', 'Channels', 1:3, ...
                'Biomarkers', {'HbO'}, 'Visible', 'off');
            tc.verifyClass(fig, 'matlab.ui.Figure');
            close(fig);
        end

        function testTemporalMultipleBiomarkers(tc)
            fig = tc.ex.plot.temporal('Color', 'Group', ...
                'Channels', 1:3, 'Biomarkers', {'HbO','HbR'}, ...
                'Visible', 'off');
            tc.verifyClass(fig, 'matlab.ui.Figure');
            close(fig);
        end

        function testTemporalWithFilter(tc)
            f = exploreFNIRS.core.Filter().include('Condition', 'Easy').ch(1:5);
            fig = tc.ex.plot.temporal('Color', 'Group', 'Filter', f, ...
                'Biomarkers', {'HbO'}, 'Visible', 'off');
            tc.verifyClass(fig, 'matlab.ui.Figure');
            close(fig);
        end

        function testTemporalInteractionColor(tc)
            fig = tc.ex.plot.temporal('Color', 'Condition:Group', ...
                'Channels', 1:3, 'Biomarkers', {'HbO'}, 'Visible', 'off');
            tc.verifyClass(fig, 'matlab.ui.Figure');
            close(fig);
        end

        %% --- Scatter plots ---

        function testScatterSimple(tc)
            [fig, stats] = tc.ex.plot.scatter('X', 'reactionTime', ...
                'Color', 'Group', 'Channels', 1:3, ...
                'Biomarker', 'HbO', 'FitLine', true, 'Visible', 'off');
            tc.verifyClass(fig, 'matlab.ui.Figure');
            close(fig);
        end

        function testScatterWithSubplotRows(tc)
            [fig, ~] = tc.ex.plot.scatter('X', 'reactionTime', ...
                'Color', 'Group', 'SubplotRows', 'Condition', ...
                'Channels', 1:3, 'Visible', 'off');
            tc.verifyClass(fig, 'matlab.ui.Figure');
            close(fig);
        end

        %% --- Shared Y-axis ---

        function testSharedYAxis(tc)
            fig = tc.ex.plot.bar('X', 'Condition', ...
                'SubplotRows', 'Group', 'Channels', 1:3, ...
                'SharedYAxis', true, 'Visible', 'off');
            allAx = findobj(fig, 'Type', 'Axes');
            if length(allAx) > 1
                yl1 = ylim(allAx(1));
                yl2 = ylim(allAx(end));
                tc.verifyEqual(yl1, yl2, 'AbsTol', 1e-10);
            end
            close(fig);
        end

        %% --- State restoration ---

        function testStateRestoredAfterPlot(tc)
            % Manually groupby and aggregate first
            tc.ex.reset();
            tc.ex.groupby({'Group'});
            tc.ex.aggregate();

            % Capture state before plot
            waGrouped = tc.ex.isGrouped;
            waAggregated = tc.ex.isAggregated;

            % Plot with different grouping
            fig = tc.ex.plot.bar('X', 'Condition', 'Color', 'Group', ...
                'Channels', 1:3, 'Visible', 'off');
            close(fig);

            % State should be restored
            tc.verifyEqual(tc.ex.isGrouped, waGrouped);
            tc.verifyEqual(tc.ex.isAggregated, waAggregated);
        end

        %% --- Figure dimension ---

        function testBarWithFigureDimension(tc)
            figs = tc.ex.plot.bar('X', 'Condition', 'Figure', 'Group', ...
                'Channels', 1:3, 'Visible', 'off');
            tc.verifyGreaterThan(length(figs), 1);
            for i = 1:length(figs)
                tc.verifyClass(figs(i), 'matlab.ui.Figure');
                close(figs(i));
            end
        end

        function testTemporalWithFigureDimension(tc)
            figs = tc.ex.plot.temporal('Color', 'Condition', 'Figure', 'Group', ...
                'Channels', 1:3, 'Biomarkers', {'HbO'}, 'Visible', 'off');
            tc.verifyGreaterThan(length(figs), 1);
            for i = 1:length(figs)
                close(figs(i));
            end
        end

        %% --- Aggregation overrides ---

        function testBarWithAvgModeOverride(tc)
            fig = tc.ex.plot.bar('X', 'Group', 'Channels', 1:3, ...
                'AvgMode', 'flat', 'Visible', 'off');
            tc.verifyClass(fig, 'matlab.ui.Figure');
            close(fig);
            % Verify settings restored
            tc.verifyEqual(tc.ex.settings.avgMode, 'hierarchy');
        end

        function testTemporalWithBaselineOverride(tc)
            fig = tc.ex.plot.temporal('Color', 'Group', ...
                'Channels', 1:3, 'Biomarkers', {'HbO'}, ...
                'Baseline', [-2, 0], 'UseBaseline', true, ...
                'Visible', 'off');
            tc.verifyClass(fig, 'matlab.ui.Figure');
            close(fig);
            % Verify settings restored
            tc.verifyEqual(tc.ex.settings.baseline, [-5, 0]);
        end

        function testSettingsRestoredAfterOverride(tc)
            origSettings = tc.ex.settings;
            fig = tc.ex.plot.bar('X', 'Condition', 'Channels', 1:3, ...
                'AvgMode', 'flat', 'ResampleRate', 1.0, ...
                'TaskStart', 2, 'Visible', 'off');
            close(fig);
            tc.verifyEqual(tc.ex.settings.avgMode, origSettings.avgMode);
            tc.verifyEqual(tc.ex.settings.resampleRate, origSettings.resampleRate);
            tc.verifyEqual(tc.ex.settings.taskStart, origSettings.taskStart);
        end

        %% --- Backward compat: existing API still works ---

        function testOldPlotBarStillWorks(tc)
            tc.ex.reset();
            tc.ex.groupby({'Group','Condition'});
            tc.ex.aggregate();
            fig = tc.ex.plotBar('Biomarker', 'HbO', 'Channels', 1:3, ...
                'Visible', 'off');
            tc.verifyClass(fig, 'matlab.ui.Figure');
            close(fig);
        end

        function testOldPlotTemporalStillWorks(tc)
            tc.ex.reset();
            tc.ex.groupby({'Group','Condition'});
            tc.ex.aggregate();
            fig = tc.ex.plotTemporal('Biomarkers', {'HbO'}, 'Channels', 1:3, ...
                'Visible', 'off');
            tc.verifyClass(fig, 'matlab.ui.Figure');
            close(fig);
        end

        %% --- Preprocessing cache ---

        function testCacheHitOnAvgModeChange(tc)
            % Re-aggregate with different avgMode should reuse cached preprocessing
            tc.ex.reset();
            tc.ex.groupby({'Group', 'Condition'});
            tc.ex.aggregate('hierarchy');

            % Verify cache is populated
            for g = 1:length(tc.ex.getGroups())
                grps = tc.ex.getGroups();
                tc.verifyFalse(isempty(grps(g).cache.ppKey), ...
                    'Cache ppKey should be set after aggregate');
                tc.verifyFalse(isempty(grps(g).cache.ppData), ...
                    'Cache ppData should be set after aggregate');
            end

            % Re-aggregate with different mode — should use cache
            tc.ex.aggregate('flat');

            % Verify still aggregated and groups still have cache
            tc.verifyTrue(tc.ex.isAggregated);
            grps = tc.ex.getGroups();
            tc.verifyFalse(isempty(grps(1).cache.ppKey));
        end

        function testCacheMissOnBaselineChange(tc)
            % Changing a preprocessing setting should invalidate cache
            tc.ex.reset();
            tc.ex.groupby({'Group'});
            tc.ex.aggregate();

            % Save the initial cache key
            grps = tc.ex.getGroups();
            origKey = grps(1).cache.ppKey;
            tc.verifyFalse(isempty(origKey));

            % Change baseline (a preprocessing setting)
            tc.ex.settings.baseline = [-3, 0];
            tc.ex.aggregate();

            % Key should be different now
            grps = tc.ex.getGroups();
            newKey = grps(1).cache.ppKey;
            tc.verifyNotEqual(origKey, newKey, ...
                'Cache key should change when baseline changes');

            % Restore for other tests
            tc.ex.settings.baseline = [-5, 0];
        end

        function testGroupbyResetsCache(tc)
            % groupby() creates new groups with empty cache
            tc.ex.reset();
            tc.ex.groupby({'Group'});
            tc.ex.aggregate();

            % Verify cache exists
            grps = tc.ex.getGroups();
            tc.verifyFalse(isempty(grps(1).cache.ppKey));

            % Re-groupby creates fresh groups
            tc.ex.groupby({'Condition'});
            grps = tc.ex.getGroups();
            tc.verifyTrue(isempty(grps(1).cache.ppKey), ...
                'Cache should be empty after re-groupby');
        end

        function testCachePreservedAcrossAvgModes(tc)
            % Verify that gbyGrand actually changes when avgMode changes
            % while cache (preprocessing) stays the same
            tc.ex.reset();
            tc.ex.groupby({'Group', 'Condition'});
            tc.ex.aggregate('hierarchy');
            grps1 = tc.ex.getGroups();
            nObs1 = size(grps1(1).gbyGrand.HbO.data, 3);

            tc.ex.aggregate('none');
            grps2 = tc.ex.getGroups();
            nObs2 = size(grps2(1).gbyGrand.HbO.data, 3);

            % 'none' should have more observations (no averaging)
            tc.verifyGreaterThanOrEqual(nObs2, nObs1, ...
                '''none'' mode should have >= observations vs ''hierarchy''');

            % Cache key should be the same (preprocessing unchanged)
            tc.verifyEqual(grps1(1).cache.ppKey, grps2(1).cache.ppKey);
        end

    end
end
