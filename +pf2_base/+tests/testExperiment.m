classdef testExperiment < matlab.unittest.TestCase
% TESTEXPERIMENT Unit tests for exploreFNIRS.core.Experiment
%
% Tests the scriptable Experiment container class including:
%   - Construction from processed data
%   - Selection and filtering
%   - Groupby operations
%   - Aggregation with preprocessing
%   - Info variable analysis (plotInfoVar)
%   - Export to long/wide format
%   - Headless plotting
%
% Run with:
%   results = runtests('pf2_base.tests.testExperiment');

    properties (TestParameter)
    end

    properties
        allData     % Cell array of processed fNIRS structs
        nSegments   % Total number of segments
    end

    methods (TestClassSetup)
        function buildTestData(tc)
            % Process sample data and create multi-subject dataset
            raw = pf2.import.sampleData.fNIR2000();
            processed = processFNIRS2(raw, 'ShowGUI', false);

            rng(42);
            subjects = {'S01','S01','S01','S01', 'S02','S02','S02','S02', 'S03','S03','S03','S03'};
            groups   = {'Ctrl','Ctrl','Ctrl','Ctrl','Ctrl','Ctrl','Ctrl','Ctrl','Tx','Tx','Tx','Tx'};
            conds    = {'Easy','Hard','Easy','Hard','Easy','Hard','Easy','Hard','Easy','Hard','Easy','Hard'};
            ages     = [25, 25, 25, 25, 30, 30, 30, 30, 28, 28, 28, 28];
            trials   = [1, 1, 2, 2, 1, 1, 2, 2, 1, 1, 2, 2];

            tc.nSegments = length(subjects);
            tc.allData = cell(tc.nSegments, 1);
            for i = 1:tc.nSegments
                d = processed;
                d.info.SubjectID = subjects{i};
                d.info.Group = groups{i};
                d.info.Condition = conds{i};
                d.info.Age = ages(i);
                d.info.Trial = trials(i);
                d.info.reactionTime = 200 + 100*strcmp(conds{i},'Hard') + randn*20;
                d.info.accuracy = 0.9 - 0.15*strcmp(conds{i},'Hard') + randn*0.03;

                % Add synthetic Aux data
                nSamples = length(d.time);
                d.Aux.accelerometer.data = 0.01*randn(nSamples, 3);
                d.Aux.accelerometer.time = d.time;
                d.Aux.accelerometer.unit = 'g';
                d.Aux.heartRate.data = 70 + 2*randn(nSamples, 1);
                d.Aux.heartRate.time = d.time;
                d.Aux.heartRate.unit = 'bpm';

                tc.allData{i} = d;
            end
        end
    end

    methods (Test)

        %% --- Construction ---

        function testConstructor(tc)
            ex = exploreFNIRS.core.Experiment(tc.allData);
            tc.verifyEqual(length(ex.data), tc.nSegments);
            tc.verifyEqual(height(ex.dataTable), tc.nSegments);
            tc.verifyFalse(ex.isGrouped);
            tc.verifyFalse(ex.isAggregated);
        end

        function testConstructorRejectsEmpty(tc)
            tc.verifyError(@() exploreFNIRS.core.Experiment({}), ...
                'exploreFNIRS:core:Experiment');
        end

        function testConstructorRejectsNonCell(tc)
            tc.verifyError(@() exploreFNIRS.core.Experiment(42), ...
                'exploreFNIRS:core:Experiment');
        end

        function testDataTableHasMissingFNIRS(tc)
            ex = exploreFNIRS.core.Experiment(tc.allData);
            tc.verifyTrue(ismember('missingFNIRS', ex.dataTable.Properties.VariableNames));
            tc.verifyEqual(ex.dataTable.missingFNIRS, zeros(tc.nSegments, 1));
        end

        function testDataTableHasInfoFields(tc)
            ex = exploreFNIRS.core.Experiment(tc.allData);
            vars = ex.dataTable.Properties.VariableNames;
            tc.verifyTrue(ismember('SubjectID', vars));
            tc.verifyTrue(ismember('Group', vars));
            tc.verifyTrue(ismember('Condition', vars));
            tc.verifyTrue(ismember('reactionTime', vars));
            tc.verifyTrue(ismember('accuracy', vars));
        end

        %% --- Selection ---

        function testSelectByString(tc)
            ex = exploreFNIRS.core.Experiment(tc.allData);
            ex.select('Group', 'Ctrl');
            sel = ex.getSelectedData();
            tc.verifyEqual(length(sel), 8);
        end

        function testSelectByMultipleValues(tc)
            ex = exploreFNIRS.core.Experiment(tc.allData);
            ex.select('Condition', {'Easy', 'Hard'});
            sel = ex.getSelectedData();
            tc.verifyEqual(length(sel), tc.nSegments);
        end

        function testSelectNarrows(tc)
            ex = exploreFNIRS.core.Experiment(tc.allData);
            ex.select('Group', 'Ctrl');
            ex.select('Condition', 'Easy');
            sel = ex.getSelectedData();
            tc.verifyEqual(length(sel), 4);
        end

        function testSelectInvalidVar(tc)
            ex = exploreFNIRS.core.Experiment(tc.allData);
            tc.verifyError(@() ex.select('Nonexistent', 'foo'), ...
                'exploreFNIRS:core:Experiment:select');
        end

        function testReset(tc)
            ex = exploreFNIRS.core.Experiment(tc.allData);
            ex.select('Group', 'Tx');
            ex.reset();
            sel = ex.getSelectedData();
            tc.verifyEqual(length(sel), tc.nSegments);
        end

        %% --- Groupby ---

        function testGroupbySingleVar(tc)
            ex = exploreFNIRS.core.Experiment(tc.allData);
            ex.groupby('Condition');
            tc.verifyTrue(ex.isGrouped);
            tc.verifyLength(ex.groups, 2);
        end

        function testGroupbyMultipleVars(tc)
            ex = exploreFNIRS.core.Experiment(tc.allData);
            ex.groupby({'Group', 'Condition'});
            tc.verifyTrue(ex.isGrouped);
            % Ctrl x {Easy,Hard} + Tx x {Easy,Hard} = 4 groups
            tc.verifyLength(ex.groups, 4);
        end

        function testGroupbyWithSelection(tc)
            ex = exploreFNIRS.core.Experiment(tc.allData);
            ex.select('Condition', 'Easy');
            ex.groupby('Group');
            tc.verifyLength(ex.groups, 2);
            % Each group should have only Easy segments
            for g = 1:length(ex.groups)
                conds = ex.groups(g).gbyTables.Condition;
                tc.verifyTrue(all(conds == "Easy" | conds == 'Easy'));
            end
        end

        function testGroupbyInvalidVar(tc)
            ex = exploreFNIRS.core.Experiment(tc.allData);
            tc.verifyError(@() ex.groupby('Nonexistent'), ...
                'exploreFNIRS:core:Experiment:groupby');
        end

        function testGroupbyHasLabel(tc)
            ex = exploreFNIRS.core.Experiment(tc.allData);
            ex.groupby('Group');
            for g = 1:length(ex.groups)
                tc.verifyNotEmpty(ex.groups(g).label);
            end
        end

        %% --- Aggregate ---

        function testAggregateRequiresGroupby(tc)
            ex = exploreFNIRS.core.Experiment(tc.allData);
            tc.verifyError(@() ex.aggregate(), ...
                'exploreFNIRS:core:Experiment:aggregate');
        end

        function testAggregateProducesGrandAverage(tc)
            ex = exploreFNIRS.core.Experiment(tc.allData);
            ex.groupby('Group');
            ex.settings.resampleRate = 2;
            ex.settings.useBaseline = false;
            ex.aggregate();

            tc.verifyTrue(ex.isAggregated);
            for g = 1:length(ex.groups)
                ga = ex.groups(g).gbyGrand;
                tc.verifyNotEmpty(ga);
                tc.verifyTrue(isfield(ga, 'HbO'));
                tc.verifyTrue(isfield(ga, 'HbR'));
                tc.verifyTrue(isfield(ga, 'time'));
                tc.verifyTrue(isfield(ga.HbO, 'Mean'));
                tc.verifyTrue(isfield(ga.HbO, 'SEM'));
            end
        end

        function testAggregateWithPreprocessing(tc)
            ex = exploreFNIRS.core.Experiment(tc.allData);
            ex.groupby('Condition');
            ex.settings.baseline = [-5, 0];
            ex.settings.resampleRate = 1;
            ex.settings.useBaseline = true;
            ex.aggregate();

            tc.verifyTrue(ex.isAggregated);
            ga = ex.groups(1).gbyGrand;
            tc.verifyNotEmpty(ga.time);
            tc.verifyNotEmpty(ga.HbO.Mean);
        end

        function testAggregateBarFlat(tc)
            ex = exploreFNIRS.core.Experiment(tc.allData);
            ex.groupby('Group');
            ex.settings.resampleRate = 1;
            ex.settings.barBinSize = 10;
            ex.settings.useBaseline = false;
            ex.aggregate();

            for g = 1:length(ex.groups)
                tc.verifyNotEmpty(ex.groups(g).gbyGrandBarFlat);
                tc.verifyTrue(isfield(ex.groups(g).gbyGrandBarFlat, 'HbO'));
            end
        end

        %% --- Info Variable Plotting ---

        function testPlotInfoVarBasic(tc)
            ex = exploreFNIRS.core.Experiment(tc.allData);
            ex.groupby('Condition');
            fig = ex.plotInfoVar('reactionTime', 'Visible', 'off');
            tc.verifyClass(fig, 'matlab.ui.Figure');
            close(fig);
        end

        function testPlotInfoVarSavesFile(tc)
            outPath = fullfile(tempdir, 'test_plotInfoVar.png');
            if exist(outPath, 'file'), delete(outPath); end

            ex = exploreFNIRS.core.Experiment(tc.allData);
            ex.groupby('Condition');
            fig = ex.plotInfoVar('reactionTime', ...
                'SavePath', outPath, 'Visible', 'off');
            close(fig);

            tc.verifyTrue(exist(outPath, 'file') > 0);
            delete(outPath);
        end

        function testPlotInfoVarRequiresGroupby(tc)
            ex = exploreFNIRS.core.Experiment(tc.allData);
            tc.verifyError(@() ex.plotInfoVar('reactionTime'), ...
                'exploreFNIRS:core:Experiment:plotInfoVar');
        end

        function testPlotInfoVarRejectsNonNumeric(tc)
            ex = exploreFNIRS.core.Experiment(tc.allData);
            ex.groupby('Group');
            tc.verifyError(@() ex.plotInfoVar('SubjectID', 'Visible', 'off'), ...
                'exploreFNIRS:core:Experiment:plotInfoVar');
        end

        function testPlotInfoVarMultiGroup(tc)
            ex = exploreFNIRS.core.Experiment(tc.allData);
            ex.groupby({'Group', 'Condition'});
            fig = ex.plotInfoVar('reactionTime', 'Visible', 'off');
            tc.verifyClass(fig, 'matlab.ui.Figure');
            close(fig);
        end

        function testPlotInfoVarNoAggregateNeeded(tc)
            % plotInfoVar should work without calling aggregate()
            ex = exploreFNIRS.core.Experiment(tc.allData);
            ex.groupby('Condition');
            % Do NOT call aggregate
            tc.verifyFalse(ex.isAggregated);
            fig = ex.plotInfoVar('accuracy', 'Visible', 'off');
            tc.verifyClass(fig, 'matlab.ui.Figure');
            close(fig);
        end

        %% --- Scatter Plot ---

        function testPlotScatterBasic(tc)
            ex = exploreFNIRS.core.Experiment(tc.allData);
            ex.groupby('Condition');
            fig = ex.plotScatter('reactionTime', 'accuracy', 'Visible', 'off');
            tc.verifyClass(fig, 'matlab.ui.Figure');
            close(fig);
        end

        function testPlotScatterWithFitLine(tc)
            ex = exploreFNIRS.core.Experiment(tc.allData);
            ex.groupby('Group');
            fig = ex.plotScatter('Age', 'reactionTime', ...
                'FitLine', true, 'Visible', 'off');
            tc.verifyClass(fig, 'matlab.ui.Figure');
            close(fig);
        end

        function testPlotScatterNoGrouping(tc)
            ex = exploreFNIRS.core.Experiment(tc.allData);
            % No groupby - should still work with single color
            fig = ex.plotScatter('reactionTime', 'accuracy', 'Visible', 'off');
            tc.verifyClass(fig, 'matlab.ui.Figure');
            close(fig);
        end

        function testPlotScatterSavesFile(tc)
            outPath = fullfile(tempdir, 'test_scatter.png');
            if exist(outPath, 'file'), delete(outPath); end

            ex = exploreFNIRS.core.Experiment(tc.allData);
            fig = ex.plotScatter('reactionTime', 'accuracy', ...
                'SavePath', outPath, 'Visible', 'off');
            close(fig);

            tc.verifyTrue(exist(outPath, 'file') > 0);
            delete(outPath);
        end

        function testPlotScatterRejectsNonNumeric(tc)
            ex = exploreFNIRS.core.Experiment(tc.allData);
            tc.verifyError(@() ex.plotScatter('SubjectID', 'accuracy', 'Visible', 'off'), ...
                'exploreFNIRS:core:Experiment:plotScatter');
        end

        %% --- InfoTable ---

        function testInfoTable(tc)
            ex = exploreFNIRS.core.Experiment(tc.allData);
            T = ex.infoTable();
            tc.verifyEqual(height(T), tc.nSegments);
            tc.verifyTrue(ismember('reactionTime', T.Properties.VariableNames));
        end

        function testInfoTableRespectsSelection(tc)
            ex = exploreFNIRS.core.Experiment(tc.allData);
            ex.select('Group', 'Tx');
            T = ex.infoTable();
            tc.verifyEqual(height(T), 4);
        end

        %% --- Temporal Plot ---

        function testPlotTemporal(tc)
            ex = exploreFNIRS.core.Experiment(tc.allData);
            ex.groupby('Group');
            ex.settings.resampleRate = 2;
            ex.settings.useBaseline = false;
            ex.aggregate();

            fig = ex.plotTemporal('Biomarkers', {'HbO'}, 'Channels', 1, ...
                'Visible', 'off');
            tc.verifyClass(fig, 'matlab.ui.Figure');
            close(fig);
        end

        function testPlotTemporalRequiresAggregate(tc)
            ex = exploreFNIRS.core.Experiment(tc.allData);
            ex.groupby('Group');
            tc.verifyError(@() ex.plotTemporal('Visible', 'off'), ...
                'exploreFNIRS:core:Experiment:plotTemporal');
        end

        %% --- Bar Plot ---

        function testPlotBar(tc)
            ex = exploreFNIRS.core.Experiment(tc.allData);
            ex.groupby('Condition');
            ex.settings.resampleRate = 2;
            ex.settings.useBaseline = false;
            ex.aggregate();

            fig = ex.plotBar('Biomarker', 'HbO', 'Channels', 1:3, ...
                'Visible', 'off');
            tc.verifyClass(fig, 'matlab.ui.Figure');
            close(fig);
        end

        %% --- Aux Plot ---

        function testPlotAuxSingleChannel(tc)
            ex = exploreFNIRS.core.Experiment(tc.allData);
            ex.groupby('Condition');
            ex.settings.resampleRate = 2;
            ex.settings.useBaseline = false;
            ex.aggregate();

            fig = ex.plotAux('heartRate', 'Visible', 'off');
            tc.verifyClass(fig, 'matlab.ui.Figure');
            close(fig);
        end

        function testPlotAuxMultiChannel(tc)
            ex = exploreFNIRS.core.Experiment(tc.allData);
            ex.groupby('Group');
            ex.settings.resampleRate = 2;
            ex.settings.useBaseline = false;
            ex.aggregate();

            fig = ex.plotAux('accelerometer', 'Layout', 'grid', 'Visible', 'off');
            tc.verifyClass(fig, 'matlab.ui.Figure');
            close(fig);
        end

        function testPlotAuxOverlay(tc)
            ex = exploreFNIRS.core.Experiment(tc.allData);
            ex.groupby('Condition');
            ex.settings.resampleRate = 2;
            ex.settings.useBaseline = false;
            ex.aggregate();

            fig = ex.plotAux('accelerometer', 'Layout', 'overlay', 'Visible', 'off');
            tc.verifyClass(fig, 'matlab.ui.Figure');
            close(fig);
        end

        function testPlotAuxSelectChannels(tc)
            ex = exploreFNIRS.core.Experiment(tc.allData);
            ex.groupby('Condition');
            ex.settings.resampleRate = 2;
            ex.settings.useBaseline = false;
            ex.aggregate();

            fig = ex.plotAux('accelerometer', 'AuxChannels', [1, 3], 'Visible', 'off');
            tc.verifyClass(fig, 'matlab.ui.Figure');
            close(fig);
        end

        function testPlotAuxRequiresAggregate(tc)
            ex = exploreFNIRS.core.Experiment(tc.allData);
            ex.groupby('Group');
            tc.verifyError(@() ex.plotAux('heartRate'), ...
                'exploreFNIRS:core:Experiment:plotAux');
        end

        function testPlotAuxSavesFile(tc)
            outPath = fullfile(tempdir, 'test_aux.png');
            if exist(outPath, 'file'), delete(outPath); end

            ex = exploreFNIRS.core.Experiment(tc.allData);
            ex.groupby('Condition');
            ex.settings.resampleRate = 2;
            ex.settings.useBaseline = false;
            ex.aggregate();

            fig = ex.plotAux('heartRate', 'SavePath', outPath, 'Visible', 'off');
            close(fig);
            tc.verifyTrue(exist(outPath, 'file') > 0);
            delete(outPath);
        end

        %% --- AuxFields ---

        function testAuxFieldsReturnsFields(tc)
            ex = exploreFNIRS.core.Experiment(tc.allData);
            ex.groupby('Group');
            ex.settings.resampleRate = 2;
            ex.settings.useBaseline = false;
            ex.aggregate();

            flds = ex.auxFields();
            tc.verifyTrue(iscell(flds));
            tc.verifyTrue(ismember('accelerometer', flds) || ismember('heartRate', flds));
        end

        function testAuxFieldsBeforeAggregate(tc)
            ex = exploreFNIRS.core.Experiment(tc.allData);
            flds = ex.auxFields();
            tc.verifyTrue(isempty(flds));
        end

        %% --- Export ---

        function testToLongTable(tc)
            ex = exploreFNIRS.core.Experiment(tc.allData);
            ex.groupby('Group');
            ex.settings.resampleRate = 1;
            ex.settings.barBinSize = 10;
            ex.settings.useBaseline = false;
            ex.aggregate();

            T = ex.toLongTable({'HbO'}, 1:3);
            tc.verifyClass(T, 'table');
            tc.verifyGreaterThan(height(T), 0);
        end

        function testToLongTableWithAux(tc)
            ex = exploreFNIRS.core.Experiment(tc.allData);
            ex.groupby('Group');
            ex.settings.resampleRate = 1;
            ex.settings.barBinSize = 10;
            ex.settings.useBaseline = false;
            ex.aggregate();

            T = ex.toLongTable({'HbO'}, 1:3, [], 'IncludeAux', true);
            tc.verifyClass(T, 'table');
            tc.verifyGreaterThan(height(T), 0);
            % Check for aux columns
            vars = T.Properties.VariableNames;
            hasAux = any(startsWith(vars, 'aux_'));
            tc.verifyTrue(hasAux, 'Expected aux_ columns in long table');
        end

        function testToWideTable(tc)
            ex = exploreFNIRS.core.Experiment(tc.allData);
            ex.groupby('Group');
            ex.settings.resampleRate = 1;
            ex.settings.barBinSize = 10;
            ex.settings.useBaseline = false;
            ex.aggregate();

            T = ex.toWideTable({'HbO'}, 1:3);
            tc.verifyClass(T, 'table');
            tc.verifyGreaterThan(height(T), 0);
        end

        function testToWideTableWithAux(tc)
            ex = exploreFNIRS.core.Experiment(tc.allData);
            ex.groupby('Group');
            ex.settings.resampleRate = 1;
            ex.settings.barBinSize = 10;
            ex.settings.useBaseline = false;
            ex.aggregate();

            T = ex.toWideTable({'HbO'}, 1:3, [], 'IncludeAux', true);
            tc.verifyClass(T, 'table');
            tc.verifyGreaterThan(height(T), 0);
            vars = T.Properties.VariableNames;
            hasAux = any(startsWith(vars, 'aux_'));
            tc.verifyTrue(hasAux, 'Expected aux_ columns in wide table');
        end

        function testExportRequiresAggregate(tc)
            ex = exploreFNIRS.core.Experiment(tc.allData);
            ex.groupby('Group');
            tc.verifyError(@() ex.toLongTable(), ...
                'exploreFNIRS:core:Experiment:toLongTable');
            tc.verifyError(@() ex.toWideTable(), ...
                'exploreFNIRS:core:Experiment:toWideTable');
        end

        %% --- Summary ---

        function testSummaryRuns(tc)
            ex = exploreFNIRS.core.Experiment(tc.allData);
            ex.groupby('Condition');
            ex.summary();  % should not error
        end

        %% --- getGroupColors ---

        function testGetGroupColorsSmall(tc)
            colors = exploreFNIRS.core.getGroupColors(3);
            tc.verifySize(colors, [3, 3]);
            tc.verifyTrue(all(colors(:) >= 0 & colors(:) <= 1));
        end

        function testGetGroupColorsLarge(tc)
            colors = exploreFNIRS.core.getGroupColors(20);
            tc.verifySize(colors, [20, 3]);
        end

        %% --- ScatterFNIRS ---

        function testScatterFNIRSBasic(tc)
            ex = exploreFNIRS.core.Experiment(tc.allData);
            ex.groupby('Condition');
            ex.settings.resampleRate = 2;
            ex.settings.barBinSize = 10;
            ex.settings.useBaseline = false;
            ex.aggregate();

            [fig, stats] = ex.plotScatterFNIRS('reactionTime', ...
                'Biomarkers', {'HbO'}, 'Channels', 1, 'Visible', 'off');
            tc.verifyClass(fig, 'matlab.ui.Figure');
            tc.verifyNotEmpty(stats);
            close(fig);
        end

        function testScatterFNIRSSpearman(tc)
            ex = exploreFNIRS.core.Experiment(tc.allData);
            ex.groupby('Group');
            ex.settings.resampleRate = 2;
            ex.settings.barBinSize = 10;
            ex.settings.useBaseline = false;
            ex.aggregate();

            [fig, stats] = ex.plotScatterFNIRS('Age', ...
                'CorrType', 'Spearman', 'Channels', 1, 'Visible', 'off');
            tc.verifyClass(fig, 'matlab.ui.Figure');
            close(fig);
        end

        function testScatterFNIRSMultiChannel(tc)
            ex = exploreFNIRS.core.Experiment(tc.allData);
            ex.groupby('Condition');
            ex.settings.resampleRate = 2;
            ex.settings.barBinSize = 10;
            ex.settings.useBaseline = false;
            ex.aggregate();

            [fig, ~] = ex.plotScatterFNIRS('reactionTime', ...
                'Channels', [1, 2, 3], 'Visible', 'off');
            tc.verifyClass(fig, 'matlab.ui.Figure');
            close(fig);
        end

        function testScatterFNIRSSavesFile(tc)
            outPath = fullfile(tempdir, 'test_scatter_fnirs.png');
            if exist(outPath, 'file'), delete(outPath); end

            ex = exploreFNIRS.core.Experiment(tc.allData);
            ex.groupby('Condition');
            ex.settings.resampleRate = 2;
            ex.settings.barBinSize = 10;
            ex.settings.useBaseline = false;
            ex.aggregate();

            [fig, ~] = ex.plotScatterFNIRS('reactionTime', ...
                'Channels', 1, 'SavePath', outPath, 'Visible', 'off');
            close(fig);
            tc.verifyTrue(exist(outPath, 'file') > 0);
            delete(outPath);
        end

        function testScatterFNIRSRequiresAggregate(tc)
            ex = exploreFNIRS.core.Experiment(tc.allData);
            ex.groupby('Condition');
            tc.verifyError(@() ex.plotScatterFNIRS('reactionTime'), ...
                'exploreFNIRS:core:Experiment:plotScatterFNIRS');
        end

        function testScatterFNIRSWithFitLine(tc)
            ex = exploreFNIRS.core.Experiment(tc.allData);
            ex.groupby('Group');
            ex.settings.resampleRate = 2;
            ex.settings.barBinSize = 10;
            ex.settings.useBaseline = false;
            ex.aggregate();

            [fig, stats] = ex.plotScatterFNIRS('Age', ...
                'FitLine', true, 'Channels', 1, 'Visible', 'off');
            tc.verifyClass(fig, 'matlab.ui.Figure');
            close(fig);
        end

        %% --- LME ---

        function testLMEBasic(tc)
            ex = exploreFNIRS.core.Experiment(tc.allData);
            ex.groupby('Condition');
            ex.settings.resampleRate = 2;
            ex.settings.barBinSize = 10;
            ex.settings.useBaseline = false;
            ex.aggregate();

            [fig, results] = ex.plotLME('Biomarkers', {'HbO'}, ...
                'Channels', 1, 'Visible', 'off');
            tc.verifyNotEmpty(results);
            tc.verifyNotEmpty(results.formula);
            if ~isempty(fig)
                close(fig);
            end
        end

        function testLMEReturnsModel(tc)
            ex = exploreFNIRS.core.Experiment(tc.allData);
            ex.groupby('Condition');
            ex.settings.resampleRate = 2;
            ex.settings.barBinSize = 10;
            ex.settings.useBaseline = false;
            ex.aggregate();

            [fig, results] = ex.plotLME('Biomarkers', {'HbO'}, ...
                'Channels', 1, 'Visible', 'off', 'ShowBar', false);
            tc.verifyNotEmpty(results.models);
            mdl = results.models{1, 1};
            if ~isempty(mdl)
                tc.verifyClass(mdl, 'LinearMixedModel');
            end
            if ~isempty(fig), close(fig); end
        end

        function testLMEMultiChannel(tc)
            ex = exploreFNIRS.core.Experiment(tc.allData);
            ex.groupby('Condition');
            ex.settings.resampleRate = 2;
            ex.settings.barBinSize = 10;
            ex.settings.useBaseline = false;
            ex.aggregate();

            [fig, results] = ex.plotLME('Biomarkers', {'HbO'}, ...
                'Channels', [1, 2], 'Visible', 'off');
            tc.verifyTrue(size(results.models, 2) >= 2);
            if ~isempty(fig), close(fig); end
        end

        function testLMEAnovaTable(tc)
            ex = exploreFNIRS.core.Experiment(tc.allData);
            ex.groupby('Condition');
            ex.settings.resampleRate = 2;
            ex.settings.barBinSize = 10;
            ex.settings.useBaseline = false;
            ex.aggregate();

            [fig, results] = ex.plotLME('Biomarkers', {'HbO'}, ...
                'Channels', 1, 'Visible', 'off', 'ShowBar', false);
            tc.verifyClass(results.anova_pval, 'table');
            tc.verifyGreaterThan(height(results.anova_pval), 0);
            if ~isempty(fig), close(fig); end
        end

        function testLMERequiresAggregate(tc)
            ex = exploreFNIRS.core.Experiment(tc.allData);
            ex.groupby('Condition');
            tc.verifyError(@() ex.plotLME(), ...
                'exploreFNIRS:core:Experiment:plotLME');
        end

        function testLMECustomFormula(tc)
            ex = exploreFNIRS.core.Experiment(tc.allData);
            ex.groupby('Condition');
            ex.settings.resampleRate = 2;
            ex.settings.barBinSize = 10;
            ex.settings.useBaseline = false;
            ex.aggregate();

            [fig, results] = ex.plotLME('Biomarkers', {'HbO'}, ...
                'Channels', 1, 'Visible', 'off', 'ShowBar', false, ...
                'CustomFormula', 'Opt1_HbO ~ Condition + (1|SubjectID)');
            tc.verifyNotEmpty(results.formula);
            tc.verifyTrue(contains(results.formula, 'Condition'));
            if ~isempty(fig), close(fig); end
        end

    end
end
