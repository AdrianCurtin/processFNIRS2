classdef ColorSchemeTest < matlab.unittest.TestCase
% COLORSCHEMETEST Unit tests for exploreFNIRS.core.ColorScheme
%
% Tests the hierarchical color scheme class: set, setBase, setPriority,
% resolve, and integration with plot functions.
%
% Run with:
%   results = runtests('pf2_base.tests.unit.ColorSchemeTest');

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
            groups   = {'Patient','Patient','Patient','Patient','Patient','Patient','Patient','Patient','Healthy','Healthy','Healthy','Healthy'};
            conds    = {'Easy','Hard','Easy','Hard','Easy','Hard','Easy','Hard','Easy','Hard','Easy','Hard'};

            nSeg = length(subjects);
            tc.allData = cell(nSeg, 1);
            for i = 1:nSeg
                d = processed;
                d.info.SubjectID = subjects{i};
                d.info.Group = groups{i};
                d.info.Condition = conds{i};
                d.info.reactionTime = 200 + 100*strcmp(conds{i},'Hard') + randn*20;
                tc.allData{i} = d;
            end

            tc.ex = exploreFNIRS.core.Experiment(tc.allData);
            tc.ex.groupby({'Group', 'Condition'});
            tc.ex.aggregate();
        end
    end

    methods (Test)

        %% --- Construction and set ---

        function testCreateEmpty(tc)
            cs = exploreFNIRS.core.ColorScheme();
            tc.verifyTrue(isempty(cs.rules));
            tc.verifyTrue(isempty(cs.priority));
            tc.verifyTrue(isempty(cs.baseColor));
        end

        function testSetColor(tc)
            cs = exploreFNIRS.core.ColorScheme();
            cs = cs.set('Group', 'Patient', [1, 0, 0]);
            tc.verifyLength(cs.rules, 1);
            tc.verifyEqual(cs.rules(1).factor, 'Group');
            tc.verifyEqual(cs.rules(1).value, 'Patient');
            tc.verifyEqual(cs.rules(1).color, [1, 0, 0]);
            tc.verifyTrue(isempty(cs.rules(1).effect));
        end

        function testSetEffect(tc)
            cs = exploreFNIRS.core.ColorScheme();
            cs = cs.set('Condition', 'Easy', 'lighten', 0.3);
            tc.verifyLength(cs.rules, 1);
            tc.verifyTrue(isempty(cs.rules(1).color));
            tc.verifyEqual(cs.rules(1).effect, 'lighten');
            tc.verifyEqual(cs.rules(1).amount, 0.3);
        end

        function testSetColorAndEffect(tc)
            cs = exploreFNIRS.core.ColorScheme();
            cs = cs.set('Group', 'Patient', [1, 0, 0], 'darken', 0.2);
            tc.verifyEqual(cs.rules(1).color, [1, 0, 0]);
            tc.verifyEqual(cs.rules(1).effect, 'darken');
            tc.verifyEqual(cs.rules(1).amount, 0.2);
        end

        function testSetUpdatesExistingRule(tc)
            cs = exploreFNIRS.core.ColorScheme();
            cs = cs.set('Group', 'Patient', [1, 0, 0]);
            cs = cs.set('Group', 'Patient', [0, 1, 0]);
            tc.verifyLength(cs.rules, 1);
            tc.verifyEqual(cs.rules(1).color, [0, 1, 0]);
        end

        function testSetMultipleRules(tc)
            cs = exploreFNIRS.core.ColorScheme();
            cs = cs.set('Group', 'Patient', [1, 0, 0]);
            cs = cs.set('Group', 'Healthy', [0, 1, 0]);
            cs = cs.set('Condition', 'Easy', 'lighten', 0.2);
            tc.verifyLength(cs.rules, 3);
        end

        function testSetInvalidEffect(tc)
            cs = exploreFNIRS.core.ColorScheme();
            tc.verifyError(@() cs.set('Group', 'Patient', 'invalid', 0.3), ...
                'exploreFNIRS:core:ColorScheme:set');
        end

        %% --- setPriority ---

        function testSetPriority(tc)
            cs = exploreFNIRS.core.ColorScheme();
            cs = cs.setPriority({'Condition', 'Group'});
            tc.verifyEqual(cs.priority, {'Condition', 'Group'});
        end

        function testSetPriorityInvalid(tc)
            cs = exploreFNIRS.core.ColorScheme();
            tc.verifyError(@() cs.setPriority({}), ...
                'exploreFNIRS:core:ColorScheme:setPriority');
        end

        %% --- setBase ---

        function testSetBase(tc)
            cs = exploreFNIRS.core.ColorScheme();
            cs = cs.setBase([0.5, 0.5, 0.5]);
            tc.verifyEqual(cs.baseColor, [0.5, 0.5, 0.5]);
        end

        %% --- Auto-priority from set order ---

        function testAutoFactorOrder(tc)
            cs = exploreFNIRS.core.ColorScheme();
            cs = cs.set('Group', 'Patient', [1, 0, 0]);
            cs = cs.set('Condition', 'Easy', 'lighten', 0.2);
            % Group was set first, so it should be prioritized first
            groups = tc.ex.getGroups();
            colors = cs.resolve(groups);
            tc.verifySize(colors, [length(groups), 3]);
        end

        %% --- resolve ---

        function testResolveBasicColors(tc)
            cs = exploreFNIRS.core.ColorScheme();
            cs = cs.set('Group', 'Patient', [1, 0, 0]);
            cs = cs.set('Group', 'Healthy', [0, 1, 0]);

            groups = tc.ex.getGroups();
            colors = cs.resolve(groups);
            tc.verifySize(colors, [length(groups), 3]);
            tc.verifyTrue(all(colors >= 0 & colors <= 1, 'all'));

            % Each group with Group=Patient should be red-ish
            for g = 1:length(groups)
                T = groups(g).gbyTables;
                grpVal = char(string(T.Group(1)));
                if strcmp(grpVal, 'Patient')
                    tc.verifyEqual(colors(g, :), [1, 0, 0], 'AbsTol', 0.01);
                elseif strcmp(grpVal, 'Healthy')
                    tc.verifyEqual(colors(g, :), [0, 1, 0], 'AbsTol', 0.01);
                end
            end
        end

        function testResolveWithEffects(tc)
            cs = exploreFNIRS.core.ColorScheme();
            cs = cs.set('Group', 'Patient', [1, 0, 0]);
            cs = cs.set('Group', 'Healthy', [0, 1, 0]);
            cs = cs.set('Condition', 'Easy', 'lighten', 0.3);
            cs = cs.set('Condition', 'Hard', 'darken', 0.2);

            groups = tc.ex.getGroups();
            colors = cs.resolve(groups);

            % Find Patient|Easy and Patient|Hard
            patientEasyClr = [];
            patientHardClr = [];
            for g = 1:length(groups)
                T = groups(g).gbyTables;
                grp = char(string(T.Group(1)));
                cond = char(string(T.Condition(1)));
                if strcmp(grp, 'Patient') && strcmp(cond, 'Easy')
                    patientEasyClr = colors(g, :);
                elseif strcmp(grp, 'Patient') && strcmp(cond, 'Hard')
                    patientHardClr = colors(g, :);
                end
            end

            % Patient|Easy should be lighter than Patient|Hard
            tc.verifyGreaterThan(mean(patientEasyClr), mean(patientHardClr));
        end

        function testResolveWithBaseColor(tc)
            cs = exploreFNIRS.core.ColorScheme();
            cs = cs.setBase([0.5, 0.5, 0.5]);
            cs = cs.set('Condition', 'Easy', 'lighten', 0.4);
            cs = cs.set('Condition', 'Hard', 'darken', 0.4);

            groups = tc.ex.getGroups();
            colors = cs.resolve(groups);

            for g = 1:length(groups)
                T = groups(g).gbyTables;
                cond = char(string(T.Condition(1)));
                if strcmp(cond, 'Easy')
                    % Lightened from gray
                    tc.verifyGreaterThan(colors(g, 1), 0.5);
                elseif strcmp(cond, 'Hard')
                    % Darkened from gray
                    tc.verifyLessThan(colors(g, 1), 0.5);
                end
            end
        end

        function testResolveFallbackToDefault(tc)
            % Empty scheme should fall back to default palette
            cs = exploreFNIRS.core.ColorScheme();
            groups = tc.ex.getGroups();
            colors = cs.resolve(groups);
            defaultColors = exploreFNIRS.core.getGroupColors(length(groups));
            tc.verifyEqual(colors, defaultColors, 'AbsTol', 1e-10);
        end

        function testResolveUnknownFactorValue(tc)
            cs = exploreFNIRS.core.ColorScheme();
            cs = cs.set('Group', 'Unknown', [1, 0, 0]);
            % No match -> falls back to default
            groups = tc.ex.getGroups();
            colors = cs.resolve(groups);
            tc.verifyTrue(all(~isnan(colors), 'all'));
        end

        function testResolveSaturateDesaturate(tc)
            cs = exploreFNIRS.core.ColorScheme();
            cs = cs.set('Group', 'Patient', [0.8, 0.2, 0.2]);
            cs = cs.set('Condition', 'Easy', 'desaturate', 0.5);
            cs = cs.set('Condition', 'Hard', 'saturate', 0.5);

            groups = tc.ex.getGroups();
            colors = cs.resolve(groups);

            % All colors should be valid RGB
            tc.verifyTrue(all(colors >= 0 & colors <= 1, 'all'));
        end

        %% --- Experiment integration ---

        function testExperimentColorSchemeProperty(tc)
            ex = exploreFNIRS.core.Experiment(tc.allData);
            cs = exploreFNIRS.core.ColorScheme();
            cs = cs.set('Group', 'Patient', [1, 0, 0]);
            ex.colorScheme = cs;
            tc.verifyTrue(isa(ex.colorScheme, 'exploreFNIRS.core.ColorScheme'));
        end

        function testExperimentAutoInjectBar(tc)
            ex = exploreFNIRS.core.Experiment(tc.allData);
            ex.groupby({'Group', 'Condition'});
            ex.aggregate();

            cs = exploreFNIRS.core.ColorScheme();
            cs = cs.set('Group', 'Patient', [0.85, 0.2, 0.2]);
            cs = cs.set('Group', 'Healthy', [0.2, 0.65, 0.3]);
            ex.colorScheme = cs;

            fig = ex.plotBar('Biomarker', 'HbO', 'Channels', 1, ...
                'Visible', 'off');
            tc.verifyTrue(isvalid(fig));
            close(fig);
        end

        function testExperimentAutoInjectTemporal(tc)
            ex = exploreFNIRS.core.Experiment(tc.allData);
            ex.groupby({'Group', 'Condition'});
            ex.aggregate();

            cs = exploreFNIRS.core.ColorScheme();
            cs = cs.set('Group', 'Patient', [0.85, 0.2, 0.2]);
            cs = cs.set('Group', 'Healthy', [0.2, 0.65, 0.3]);
            cs = cs.set('Condition', 'Easy', 'lighten', 0.25);
            cs = cs.set('Condition', 'Hard', 'darken', 0.15);
            ex.colorScheme = cs;

            fig = ex.plotTemporal('Biomarkers', {'HbO'}, 'Channels', 1, ...
                'Visible', 'off');
            tc.verifyTrue(isvalid(fig));
            close(fig);
        end

        function testExplicitColorsOverrideScheme(tc)
            ex = exploreFNIRS.core.Experiment(tc.allData);
            ex.groupby({'Group', 'Condition'});
            ex.aggregate();

            cs = exploreFNIRS.core.ColorScheme();
            cs = cs.set('Group', 'Patient', [1, 0, 0]);
            ex.colorScheme = cs;

            % Explicit Colors should override
            fig = ex.plotBar('Biomarker', 'HbO', 'Channels', 1, ...
                'Colors', [0 0 1; 0 1 0; 1 0 0; 1 1 0], ...
                'Visible', 'off');
            tc.verifyTrue(isvalid(fig));
            close(fig);
        end

        function testPlotProxyWithColorScheme(tc)
            ex = exploreFNIRS.core.Experiment(tc.allData);

            cs = exploreFNIRS.core.ColorScheme();
            cs = cs.set('Group', 'Patient', [0.85, 0.2, 0.2]);
            cs = cs.set('Group', 'Healthy', [0.2, 0.65, 0.3]);
            cs = cs.set('Condition', 'Easy', 'lighten', 0.25);
            cs = cs.set('Condition', 'Hard', 'darken', 0.15);
            ex.colorScheme = cs;

            fig = ex.plot.bar('X', 'Condition', 'Color', 'Group', ...
                'Channels', 1, 'SavePath', '');
            tc.verifyTrue(isvalid(fig));
            close(fig);
        end

        function testPlotProxyTemporalWithColorScheme(tc)
            ex = exploreFNIRS.core.Experiment(tc.allData);

            cs = exploreFNIRS.core.ColorScheme();
            cs = cs.set('Group', 'Patient', [0.85, 0.2, 0.2]);
            cs = cs.set('Group', 'Healthy', [0.2, 0.65, 0.3]);
            ex.colorScheme = cs;

            fig = ex.plot.temporal('Color', 'Group', 'Channels', 1);
            tc.verifyTrue(isvalid(fig));
            close(fig);
        end

        %% --- Effect functions ---

        function testLightenEffect(tc)
            cs = exploreFNIRS.core.ColorScheme();
            cs = cs.set('Group', 'Patient', [0.5, 0, 0]);
            cs = cs.set('Condition', 'Easy', 'lighten', 0.5);

            % Build a single-group struct to test
            groups = tc.ex.getGroups();
            patientEasy = [];
            for g = 1:length(groups)
                T = groups(g).gbyTables;
                if strcmp(char(string(T.Group(1))), 'Patient') && ...
                        strcmp(char(string(T.Condition(1))), 'Easy')
                    patientEasy = groups(g);
                    break;
                end
            end
            tc.assertNotEmpty(patientEasy);
            colors = cs.resolve(patientEasy);
            % Lightened [0.5, 0, 0] by 0.5 -> [0.75, 0.5, 0.5]
            tc.verifyEqual(colors, [0.75, 0.5, 0.5], 'AbsTol', 0.01);
        end

        function testDarkenEffect(tc)
            cs = exploreFNIRS.core.ColorScheme();
            cs = cs.set('Group', 'Patient', [1, 0, 0]);
            cs = cs.set('Condition', 'Hard', 'darken', 0.5);

            groups = tc.ex.getGroups();
            patientHard = [];
            for g = 1:length(groups)
                T = groups(g).gbyTables;
                if strcmp(char(string(T.Group(1))), 'Patient') && ...
                        strcmp(char(string(T.Condition(1))), 'Hard')
                    patientHard = groups(g);
                    break;
                end
            end
            tc.assertNotEmpty(patientHard);
            colors = cs.resolve(patientHard);
            % Darkened [1, 0, 0] by 0.5 -> [0.5, 0, 0]
            tc.verifyEqual(colors, [0.5, 0, 0], 'AbsTol', 0.01);
        end

        %% --- Named presets: addColorScheme / removeColorScheme / useColorScheme ---

        function testAddColorScheme(tc)
            ex = exploreFNIRS.core.Experiment(tc.allData);
            cs = exploreFNIRS.core.ColorScheme();
            cs = cs.set('Group', 'Patient', [1, 0, 0]);
            ex.addColorScheme('byGroup', cs);
            tc.verifyTrue(isfield(ex.colorSchemes, 'byGroup'));
            tc.verifyTrue(isa(ex.colorSchemes.byGroup, 'exploreFNIRS.core.ColorScheme'));
        end

        function testAddMultipleSchemes(tc)
            ex = exploreFNIRS.core.Experiment(tc.allData);
            cs1 = exploreFNIRS.core.ColorScheme();
            cs1 = cs1.set('Group', 'Patient', [1, 0, 0]);
            cs2 = exploreFNIRS.core.ColorScheme();
            cs2 = cs2.set('Condition', 'Easy', [0, 0, 1]);
            ex.addColorScheme('byGroup', cs1);
            ex.addColorScheme('byCondition', cs2);
            tc.verifyTrue(isfield(ex.colorSchemes, 'byGroup'));
            tc.verifyTrue(isfield(ex.colorSchemes, 'byCondition'));
        end

        function testAddColorSchemeInvalidName(tc)
            ex = exploreFNIRS.core.Experiment(tc.allData);
            cs = exploreFNIRS.core.ColorScheme();
            tc.verifyError(@() ex.addColorScheme('not valid', cs), ...
                'exploreFNIRS:core:Experiment:addColorScheme');
        end

        function testAddColorSchemeInvalidValue(tc)
            ex = exploreFNIRS.core.Experiment(tc.allData);
            tc.verifyError(@() ex.addColorScheme('test', 'not a colorscheme'), ...
                'exploreFNIRS:core:Experiment:addColorScheme');
        end

        function testRemoveColorScheme(tc)
            ex = exploreFNIRS.core.Experiment(tc.allData);
            cs = exploreFNIRS.core.ColorScheme();
            ex.addColorScheme('byGroup', cs);
            ex.removeColorScheme('byGroup');
            tc.verifyFalse(isfield(ex.colorSchemes, 'byGroup'));
        end

        function testRemoveColorSchemeNotFound(tc)
            ex = exploreFNIRS.core.Experiment(tc.allData);
            tc.verifyError(@() ex.removeColorScheme('nonexistent'), ...
                'exploreFNIRS:core:Experiment:removeColorScheme');
        end

        function testUseColorScheme(tc)
            ex = exploreFNIRS.core.Experiment(tc.allData);
            cs = exploreFNIRS.core.ColorScheme();
            cs = cs.set('Group', 'Patient', [1, 0, 0]);
            ex.addColorScheme('byGroup', cs);
            ex.useColorScheme('byGroup');
            tc.verifyTrue(isa(ex.colorScheme, 'exploreFNIRS.core.ColorScheme'));
            tc.verifyLength(ex.colorScheme.rules, 1);
        end

        function testUseColorSchemeNotFound(tc)
            ex = exploreFNIRS.core.Experiment(tc.allData);
            tc.verifyError(@() ex.useColorScheme('nonexistent'), ...
                'exploreFNIRS:core:Experiment:useColorScheme');
        end

        %% --- Per-plot 'ColorScheme' parameter ---

        function testPerPlotColorSchemeByName(tc)
            ex = exploreFNIRS.core.Experiment(tc.allData);
            ex.groupby({'Group', 'Condition'});
            ex.aggregate();

            cs1 = exploreFNIRS.core.ColorScheme();
            cs1 = cs1.set('Group', 'Patient', [1, 0, 0]);
            cs1 = cs1.set('Group', 'Healthy', [0, 1, 0]);

            cs2 = exploreFNIRS.core.ColorScheme();
            cs2 = cs2.set('Condition', 'Easy', [0, 0, 1]);
            cs2 = cs2.set('Condition', 'Hard', [1, 0.5, 0]);

            ex.addColorScheme('byGroup', cs1);
            ex.addColorScheme('byCondition', cs2);
            ex.useColorScheme('byGroup');

            % Per-plot override by name
            fig = ex.plotBar('Biomarker', 'HbO', 'Channels', 1, ...
                'ColorScheme', 'byCondition', 'Visible', 'off');
            tc.verifyTrue(isvalid(fig));
            close(fig);
        end

        function testPerPlotColorSchemeByObject(tc)
            ex = exploreFNIRS.core.Experiment(tc.allData);
            ex.groupby({'Group', 'Condition'});
            ex.aggregate();

            cs = exploreFNIRS.core.ColorScheme();
            cs = cs.set('Condition', 'Easy', [0, 0, 1]);
            cs = cs.set('Condition', 'Hard', [1, 0.5, 0]);

            % Direct object (not registered)
            fig = ex.plotBar('Biomarker', 'HbO', 'Channels', 1, ...
                'ColorScheme', cs, 'Visible', 'off');
            tc.verifyTrue(isvalid(fig));
            close(fig);
        end

        function testPerPlotColorSchemeUnknownName(tc)
            ex = exploreFNIRS.core.Experiment(tc.allData);
            ex.groupby({'Group', 'Condition'});
            ex.aggregate();

            tc.verifyError(@() ex.plotBar('Biomarker', 'HbO', ...
                'Channels', 1, 'ColorScheme', 'nonexistent', 'Visible', 'off'), ...
                'exploreFNIRS:core:Experiment:injectColorScheme');
        end

        function testColorSchemePriorityExplicitColorsWins(tc)
            % Explicit 'Colors' should override 'ColorScheme'
            ex = exploreFNIRS.core.Experiment(tc.allData);
            ex.groupby({'Group', 'Condition'});
            ex.aggregate();

            cs = exploreFNIRS.core.ColorScheme();
            cs = cs.set('Group', 'Patient', [1, 0, 0]);
            ex.addColorScheme('byGroup', cs);

            % Both ColorScheme and Colors set: Colors wins
            fig = ex.plotBar('Biomarker', 'HbO', 'Channels', 1, ...
                'ColorScheme', 'byGroup', ...
                'Colors', [0 0 1; 0 1 0; 1 0 0; 1 1 0], ...
                'Visible', 'off');
            tc.verifyTrue(isvalid(fig));
            close(fig);
        end

        function testColorSchemePriorityDefaultFallback(tc)
            % Without ColorScheme param, default colorScheme is used
            ex = exploreFNIRS.core.Experiment(tc.allData);
            ex.groupby({'Group', 'Condition'});
            ex.aggregate();

            csDefault = exploreFNIRS.core.ColorScheme();
            csDefault = csDefault.set('Group', 'Patient', [1, 0, 0]);
            csDefault = csDefault.set('Group', 'Healthy', [0, 1, 0]);
            ex.colorScheme = csDefault;

            % No 'ColorScheme' param -> default colorScheme used
            fig = ex.plotBar('Biomarker', 'HbO', 'Channels', 1, ...
                'Visible', 'off');
            tc.verifyTrue(isvalid(fig));
            close(fig);
        end

        %% --- PlotProxy 'ColorScheme' parameter ---

        function testPlotProxyColorSchemeByName(tc)
            ex = exploreFNIRS.core.Experiment(tc.allData);

            cs1 = exploreFNIRS.core.ColorScheme();
            cs1 = cs1.set('Group', 'Patient', [0.85, 0.2, 0.2]);
            cs1 = cs1.set('Group', 'Healthy', [0.2, 0.65, 0.3]);

            cs2 = exploreFNIRS.core.ColorScheme();
            cs2 = cs2.set('Condition', 'Easy', [0, 0, 1]);
            cs2 = cs2.set('Condition', 'Hard', [1, 0.5, 0]);

            ex.addColorScheme('byGroup', cs1);
            ex.addColorScheme('byCondition', cs2);
            ex.useColorScheme('byGroup');

            % Per-plot override via PlotProxy
            fig = ex.plot.bar('X', 'Condition', 'Color', 'Group', ...
                'Channels', 1, 'ColorScheme', 'byCondition');
            tc.verifyTrue(isvalid(fig));
            close(fig);
        end

        function testPlotProxyColorSchemeByObject(tc)
            ex = exploreFNIRS.core.Experiment(tc.allData);

            cs = exploreFNIRS.core.ColorScheme();
            cs = cs.set('Group', 'Patient', [0.85, 0.2, 0.2]);
            cs = cs.set('Group', 'Healthy', [0.2, 0.65, 0.3]);

            fig = ex.plot.temporal('Color', 'Group', 'Channels', 1, ...
                'ColorScheme', cs);
            tc.verifyTrue(isvalid(fig));
            close(fig);
        end

        function testPlotProxyColorSchemeUnknownName(tc)
            ex = exploreFNIRS.core.Experiment(tc.allData);

            tc.verifyError(@() ex.plot.bar('X', 'Condition', ...
                'Color', 'Group', 'Channels', 1, 'ColorScheme', 'nonexistent'), ...
                'exploreFNIRS:core:PlotProxy:orchestrate');
        end

        %% --- plotInfoBar 'ColorScheme' parameter ---

        function testPlotInfoBarColorSchemeByName(tc)
            ex = exploreFNIRS.core.Experiment(tc.allData);
            ex.groupby({'Group', 'Condition'});

            cs = exploreFNIRS.core.ColorScheme();
            cs = cs.set('Group', 'Patient', [0.85, 0.2, 0.2]);
            cs = cs.set('Group', 'Healthy', [0.2, 0.65, 0.3]);
            ex.addColorScheme('byGroup', cs);

            fig = ex.plotInfoBar('reactionTime', ...
                'ColorScheme', 'byGroup', 'Visible', 'off');
            tc.verifyTrue(isvalid(fig));
            close(fig);
        end

        function testPlotInfoBarColorSchemeByObject(tc)
            ex = exploreFNIRS.core.Experiment(tc.allData);
            ex.groupby({'Group', 'Condition'});

            cs = exploreFNIRS.core.ColorScheme();
            cs = cs.set('Group', 'Patient', [0.85, 0.2, 0.2]);
            cs = cs.set('Group', 'Healthy', [0.2, 0.65, 0.3]);

            fig = ex.plotInfoBar('reactionTime', ...
                'ColorScheme', cs, 'Visible', 'off');
            tc.verifyTrue(isvalid(fig));
            close(fig);
        end

        function testPlotInfoBarColorSchemeUnknown(tc)
            ex = exploreFNIRS.core.Experiment(tc.allData);
            ex.groupby({'Group', 'Condition'});

            tc.verifyError(@() ex.plotInfoBar('reactionTime', ...
                'ColorScheme', 'nonexistent', 'Visible', 'off'), ...
                'exploreFNIRS:core:Experiment:plotInfoBar');
        end

        %% --- plotInfoScatter 'ColorScheme' parameter ---

        function testPlotInfoScatterColorSchemeByName(tc)
            ex = exploreFNIRS.core.Experiment(tc.allData);
            ex.groupby({'Condition'});

            cs = exploreFNIRS.core.ColorScheme();
            cs = cs.set('Condition', 'Easy', [0, 0, 1]);
            cs = cs.set('Condition', 'Hard', [1, 0, 0]);
            ex.addColorScheme('byCond', cs);

            fig = ex.plotInfoScatter('reactionTime', 'reactionTime', ...
                'ColorScheme', 'byCond', 'Visible', 'off');
            tc.verifyTrue(isvalid(fig));
            close(fig);
        end

        function testPlotInfoScatterColorSchemeUnknown(tc)
            ex = exploreFNIRS.core.Experiment(tc.allData);
            ex.groupby({'Condition'});

            tc.verifyError(@() ex.plotInfoScatter('reactionTime', 'reactionTime', ...
                'ColorScheme', 'nonexistent', 'Visible', 'off'), ...
                'exploreFNIRS:core:Experiment:plotInfoScatter');
        end

        %% --- preview ---

        function testPreviewBasic(tc)
            cs = exploreFNIRS.core.ColorScheme();
            cs = cs.set('Group', 'Patient', [0.85, 0.2, 0.2]);
            cs = cs.set('Group', 'Healthy', [0.2, 0.65, 0.3]);
            cs = cs.set('Condition', 'Easy', 'lighten', 0.25);
            cs = cs.set('Condition', 'Hard', 'darken', 0.15);

            fig = cs.preview('Visible', 'off');
            tc.verifyTrue(isvalid(fig));
            % Should have 4 bars (2 groups x 2 conditions)
            ax = fig.Children(end);
            tc.verifyEqual(length(ax.YTickLabel), 4);
            close(fig);
        end

        function testPreviewSingleFactor(tc)
            cs = exploreFNIRS.core.ColorScheme();
            cs = cs.set('Group', 'Patient', [1, 0, 0]);
            cs = cs.set('Group', 'Healthy', [0, 1, 0]);

            fig = cs.preview('Visible', 'off');
            tc.verifyTrue(isvalid(fig));
            ax = fig.Children(end);
            tc.verifyEqual(length(ax.YTickLabel), 2);
            close(fig);
        end

        function testPreviewEmpty(tc)
            cs = exploreFNIRS.core.ColorScheme();
            fig = cs.preview('Visible', 'off');
            tc.verifyTrue(isvalid(fig));
            close(fig);
        end

        function testPreviewSave(tc)
            cs = exploreFNIRS.core.ColorScheme();
            cs = cs.set('Group', 'Patient', [0.85, 0.2, 0.2]);
            cs = cs.set('Group', 'Healthy', [0.2, 0.65, 0.3]);

            savePath = fullfile(tempdir, 'colorscheme_preview_test.png');
            fig = cs.preview('SavePath', savePath);
            tc.verifyTrue(isvalid(fig));
            tc.verifyTrue(isfile(savePath));
            delete(savePath);
            close(fig);
        end

        function testPreviewWithBaseColor(tc)
            cs = exploreFNIRS.core.ColorScheme();
            cs = cs.setBase([0.5, 0.5, 0.5]);
            cs = cs.set('Condition', 'Easy', 'lighten', 0.3);
            cs = cs.set('Condition', 'Hard', 'darken', 0.3);

            fig = cs.preview('Visible', 'off');
            tc.verifyTrue(isvalid(fig));
            ax = fig.Children(end);
            tc.verifyEqual(length(ax.YTickLabel), 2);
            close(fig);
        end

    end
end
