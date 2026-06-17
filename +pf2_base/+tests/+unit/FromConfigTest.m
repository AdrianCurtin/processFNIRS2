classdef FromConfigTest < matlab.unittest.TestCase
    % FROMCONFIGTEST Unit tests for Experiment.fromConfig static factory
    %
    %   results = runtests('pf2_base.tests.unit.FromConfigTest');

    properties
        sampleData  % Pre-loaded sample data
    end

    methods (TestClassSetup)
        function loadSample(testCase)
            % Load sample data that can be used as cfg.data
            data = pf2.import.sampleData.fNIR2000();
            processed = processFNIRS2(data);
            testCase.sampleData = {processed};
        end
    end

    methods (Test)

        %% --- Data-based config ---

        function testFromDataBasic(testCase)
            cfg.data = testCase.sampleData;
            ex = exploreFNIRS.core.Experiment.fromConfig(cfg);

            testCase.verifyClass(ex, 'exploreFNIRS.core.Experiment');
            testCase.verifyEqual(length(ex.data), length(testCase.sampleData));
        end

        function testFromDataSingleStruct(testCase)
            % Should accept a single struct (not in cell)
            cfg.data = testCase.sampleData{1};
            ex = exploreFNIRS.core.Experiment.fromConfig(cfg);
            testCase.verifyEqual(length(ex.data), 1);
        end

        function testFromDataWithSettings(testCase)
            cfg.data = testCase.sampleData;
            cfg.experiment.baseline = [-3, 0];
            cfg.experiment.taskEnd = 20;
            cfg.experiment.barBinSize = 5;
            cfg.experiment.avgMode = 'flat';

            ex = exploreFNIRS.core.Experiment.fromConfig(cfg);

            testCase.verifyEqual(ex.settings.baseline, [-3, 0]);
            testCase.verifyEqual(ex.settings.taskEnd, 20);
            testCase.verifyEqual(ex.settings.barBinSize, 5);
            testCase.verifyEqual(ex.settings.avgMode, 'flat');
        end

        function testFromDataWithHierarchy(testCase)
            cfg.data = testCase.sampleData;
            cfg.experiment.hierarchy = {'SubjectID', 'Condition'};

            ex = exploreFNIRS.core.Experiment.fromConfig(cfg);

            testCase.verifyEqual(ex.hierarchy, {'SubjectID', 'Condition'});
        end

        function testFromDataWithStatWindow(testCase)
            cfg.data = testCase.sampleData;
            cfg.experiment.statWindow = [5, 25];

            ex = exploreFNIRS.core.Experiment.fromConfig(cfg);

            testCase.verifyEqual(ex.settings.statWindow, [5, 25]);
        end

        %% --- Validation ---

        function testMissingImportAndData(testCase)
            cfg = struct();
            testCase.verifyError(@() ...
                exploreFNIRS.core.Experiment.fromConfig(cfg), ...
                'exploreFNIRS:core:Experiment:fromConfig:invalidConfig');
        end

        function testImportMissingDir(testCase)
            cfg.import.pattern = '*.snirf';
            testCase.verifyError(@() ...
                exploreFNIRS.core.Experiment.fromConfig(cfg), ...
                'exploreFNIRS:core:Experiment:fromConfig:invalidConfig');
        end

        function testImportMissingPattern(testCase)
            cfg.import.dir = tempdir;
            testCase.verifyError(@() ...
                exploreFNIRS.core.Experiment.fromConfig(cfg), ...
                'exploreFNIRS:core:Experiment:fromConfig:invalidConfig');
        end

        function testImportNonexistentDir(testCase)
            cfg.import.dir = '/nonexistent/path/12345';
            cfg.import.pattern = '*.snirf';
            testCase.verifyError(@() ...
                exploreFNIRS.core.Experiment.fromConfig(cfg), ...
                'exploreFNIRS:core:Experiment:fromConfig:invalidConfig');
        end

        %% --- Settings propagation ---

        function testDefaultSettingsUnchanged(testCase)
            % Settings not in cfg should keep defaults
            cfg.data = testCase.sampleData;
            ex = exploreFNIRS.core.Experiment.fromConfig(cfg);

            testCase.verifyEqual(ex.settings.baseline, [-5, 0]);
            testCase.verifyEqual(ex.settings.resampleRate, 0.5);
            testCase.verifyEqual(ex.settings.avgMode, 'hierarchy');
        end

        function testPartialSettingsOverride(testCase)
            cfg.data = testCase.sampleData;
            cfg.experiment.taskEnd = 30;
            % Don't set baseline, should keep default

            ex = exploreFNIRS.core.Experiment.fromConfig(cfg);

            testCase.verifyEqual(ex.settings.taskEnd, 30);
            testCase.verifyEqual(ex.settings.baseline, [-5, 0]);
        end

        %% --- Process stage (item 12) ---

        function testProcessStageWithData(testCase)
            % Provide raw (unprocessed) data + process config
            raw = pf2.import.sampleData.fNIR2000();
            cfg.data = raw;
            cfg.process = struct();  % empty → uses defaults

            ex = exploreFNIRS.core.Experiment.fromConfig(cfg);

            testCase.verifyClass(ex, 'exploreFNIRS.core.Experiment');
            % Data should now be processed (have HbO field)
            testCase.verifyTrue(isfield(ex.data{1}, 'HbO'));
        end

        %% --- Block extraction stage (item 12) ---

        function testBlockStageWithMarkers(testCase)
            % Use processed data with injected markers
            d = testCase.sampleData{1};
            % Inject markers at known times within data range
            t = d.time;
            t1 = t(round(length(t) * 0.3));
            t2 = t(round(length(t) * 0.6));
            d.markers = pf2_base.normalizeMarkers([t1, 49, 0, 0; t2, 49, 0, 0]);

            cfg.data = d;
            cfg.blocks.markerCodes = 49;
            cfg.blocks.duration = 3;

            % Verify the pipeline runs without error
            ex = exploreFNIRS.core.Experiment.fromConfig(cfg);
            testCase.verifyClass(ex, 'exploreFNIRS.core.Experiment');
            testCase.verifyGreaterThanOrEqual(length(ex.data), 1);
        end

        %% --- StatWindow validation (item 7) ---

        function testInvalidStatWindowErrors(testCase)
            cfg.data = testCase.sampleData;
            cfg.experiment.statWindow = [5];  % 1-element, invalid

            testCase.verifyError(@() ...
                exploreFNIRS.core.Experiment.fromConfig(cfg), ...
                'exploreFNIRS:core:Experiment:fromConfig:invalidStatWindow');
        end

        function testInvalidStatWindowThreeElements(testCase)
            cfg.data = testCase.sampleData;
            cfg.experiment.statWindow = [1, 2, 3];

            testCase.verifyError(@() ...
                exploreFNIRS.core.Experiment.fromConfig(cfg), ...
                'exploreFNIRS:core:Experiment:fromConfig:invalidStatWindow');
        end

        %% --- Metadata validation (item 12) ---

        function testMetadataNonexistentFile(testCase)
            cfg.data = testCase.sampleData;
            cfg.metadata.file = '/nonexistent/demographics.csv';

            testCase.verifyError(@() ...
                exploreFNIRS.core.Experiment.fromConfig(cfg), ...
                'exploreFNIRS:core:Experiment:fromConfig:invalidConfig');
        end

    end
end
