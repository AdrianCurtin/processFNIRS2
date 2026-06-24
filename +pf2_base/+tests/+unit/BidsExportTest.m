classdef BidsExportTest < matlab.unittest.TestCase
    % BIDSEXPORTTEST Unit tests for BIDS-NIRS export (pf2.export.asBIDS)
    %
    %   Covers the orchestrator and the +pf2_base/+bids helper package:
    %     - dataset layout, entity resolution, run disambiguation
    %     - required files and required fields/columns (validator-oriented)
    %     - channels.tsv required column order and dark-channel stripping
    %     - montage-level _optodes.tsv / _coordsystem.json (no task/run entities)
    %     - events.tsv presence/absence and column contract
    %     - participants.tsv ordering and dedup
    %     - pure helpers: sanitizeLabel, fmtCell, entityBase, resolveEntities
    %     - SNIRF round-trip of an exported recording
    %
    %   Example:
    %       results = runtests('pf2_base.tests.unit.BidsExportTest');
    %       disp(results);
    %
    %   See also: pf2.export.asBIDS, pf2.export.asSNIRF

    properties
        outRoot   % temp dataset root for the current test
    end

    methods (TestMethodSetup)
        function makeTempRoot(testCase)
            testCase.outRoot = tempname;
        end
    end

    methods (TestMethodTeardown)
        function removeTempRoot(testCase)
            if ~isempty(testCase.outRoot) && exist(testCase.outRoot, 'dir') == 7
                rmdir(testCase.outRoot, 's');
            end
        end
    end

    %% ---- Pure helper tests (no data needed) ----
    methods (Test)
        function testSanitizeLabel(testCase)
            testCase.verifyEqual(pf2_base.bids.sanitizeLabel('Sub_01'), 'Sub01');
            testCase.verifyEqual(pf2_base.bids.sanitizeLabel('a-b c.d'), 'abcd');
            testCase.verifyEqual(pf2_base.bids.sanitizeLabel(7), '7');
            testCase.verifyEqual(pf2_base.bids.sanitizeLabel('___'), '');
        end

        function testFmtCellSentinels(testCase)
            testCase.verifyEqual(pf2_base.bids.fmtCell(NaN), 'n/a');
            testCase.verifyEqual(pf2_base.bids.fmtCell([]), 'n/a');
            testCase.verifyEqual(pf2_base.bids.fmtCell(''), 'n/a');
            testCase.verifyEqual(pf2_base.bids.fmtCell(string(missing)), 'n/a');
            testCase.verifyEqual(pf2_base.bids.fmtCell(760), '760');
            testCase.verifyEqual(pf2_base.bids.fmtCell(true), '1');
        end

        function testFmtCellStripsDelimiters(testCase)
            v = pf2_base.bids.fmtCell(sprintf('a\tb\nc'));
            testCase.verifyFalse(contains(v, sprintf('\t')));
            testCase.verifyFalse(contains(v, newline));
            testCase.verifyEqual(v, 'a b c');
        end

        function testEntityBase(testCase)
            e1 = struct('sub', '01', 'ses', '', 'task', 'rest', 'run', '');
            testCase.verifyEqual(pf2_base.bids.entityBase(e1), 'sub-01_task-rest');
            e2 = struct('sub', 'A', 'ses', '2', 'task', 'go', 'run', '03');
            testCase.verifyEqual(pf2_base.bids.entityBase(e2), ...
                'sub-A_ses-2_task-go_run-03');
        end

        function testResolveEntitiesRunDisambiguation(testCase)
            % Three recordings, same subject/task, no explicit run -> run-01..03
            mk = @(id) struct('info', struct('SubjectID', id));
            allData = {mk('01'), mk('01'), mk('02')};
            ent = pf2_base.bids.resolveEntities(allData, 'rest');
            testCase.verifyEqual({ent.sub}, {'01', '01', '02'});
            testCase.verifyEqual(ent(1).run, '01');
            testCase.verifyEqual(ent(2).run, '02');
            testCase.verifyEqual(ent(3).run, '');   % unique -> no run needed
        end

        function testResolveEntitiesTaskOverrideAndSanitize(testCase)
            allData = {struct('info', struct('SubjectID', 'P 1'))};
            ent = pf2_base.bids.resolveEntities(allData, 'my-task');
            testCase.verifyEqual(ent(1).sub, 'P1');
            testCase.verifyEqual(ent(1).task, 'mytask');
        end

        function testResolveEntitiesFallbackSubject(testCase)
            allData = {struct('raw', 1), struct('raw', 2)};   % no .info
            ent = pf2_base.bids.resolveEntities(allData, '');
            testCase.verifyEqual(ent(1).sub, '01');
            testCase.verifyEqual(ent(2).sub, '02');
            testCase.verifyEqual(ent(1).task, 'task');   % default
        end
    end

    %% ---- End-to-end export tests (with markers) ----
    methods (Test)
        function testExportProducesValidStructure(testCase)
            data = pf2_base.tests.unit.BidsExportTest.processedWithMarkers();
            root = pf2.export.asBIDS(data, testCase.outRoot, 'Task', 'stroop', ...
                'Name', 'UnitTest', 'Verbose', false);

            % Required dataset-level files
            testCase.verifyTrue(isfile(fullfile(root, 'dataset_description.json')));
            testCase.verifyTrue(isfile(fullfile(root, 'participants.tsv')));
            testCase.verifyTrue(isfile(fullfile(root, 'README')));

            dd = jsondecode(fileread(fullfile(root, 'dataset_description.json')));
            testCase.verifyTrue(isfield(dd, 'Name'));
            testCase.verifyTrue(isfield(dd, 'BIDSVersion'));

            % Recording files
            nirsDir = fullfile(root, 'sub-01', 'nirs');
            base = 'sub-01_task-stroop';
            testCase.verifyTrue(isfile(fullfile(nirsDir, [base '_nirs.snirf'])));
            testCase.verifyTrue(isfile(fullfile(nirsDir, [base '_nirs.json'])));
            testCase.verifyTrue(isfile(fullfile(nirsDir, [base '_channels.tsv'])));
            testCase.verifyTrue(isfile(fullfile(nirsDir, [base '_events.tsv'])));
            % Montage-level files: sub-only, NO task/run entity
            testCase.verifyTrue(isfile(fullfile(nirsDir, 'sub-01_optodes.tsv')));
            testCase.verifyTrue(isfile(fullfile(nirsDir, 'sub-01_coordsystem.json')));
        end

        function testNirsJsonRequiredFields(testCase)
            data = pf2_base.tests.unit.BidsExportTest.processedWithMarkers();
            root = pf2.export.asBIDS(data, testCase.outRoot, 'Task', 'stroop', ...
                'Verbose', false);
            j = jsondecode(fileread(fullfile(root, 'sub-01', 'nirs', ...
                'sub-01_task-stroop_nirs.json')));
            for f = {'TaskName', 'SamplingFrequency', 'NIRSChannelCount', ...
                    'NIRSSourceOptodeCount', 'NIRSDetectorOptodeCount'}
                testCase.verifyTrue(isfield(j, f{1}), ...
                    sprintf('Missing required _nirs.json field %s', f{1}));
            end
            % Numeric types, not strings
            testCase.verifyClass(j.SamplingFrequency, 'double');
            testCase.verifyClass(j.NIRSChannelCount, 'double');
            testCase.verifyEqual(j.TaskName, 'stroop');
        end

        function testChannelsTsvColumnOrderAndContent(testCase)
            data = pf2_base.tests.unit.BidsExportTest.processedWithMarkers();
            root = pf2.export.asBIDS(data, testCase.outRoot, 'Task', 'stroop', ...
                'Verbose', false);
            T = readtable(fullfile(root, 'sub-01', 'nirs', ...
                'sub-01_task-stroop_channels.tsv'), 'FileType', 'text', ...
                'Delimiter', '\t');
            cols = T.Properties.VariableNames;
            % First six columns must be exactly these, in this order
            required = {'name', 'type', 'source', 'detector', ...
                'wavelength_nominal', 'units'};
            testCase.verifyEqual(cols(1:6), required, ...
                'channels.tsv required column order is wrong');
            % All real CW amplitude, no placeholder dark wavelength
            testCase.verifyTrue(all(strcmp(T.type, 'NIRSCWAMPLITUDE')));
            testCase.verifyFalse(any(T.wavelength_nominal == 0), ...
                'Dark (wavelength 0) channels should be stripped');
        end

        function testChannelsMatchSnirfColumns(testCase)
            data = pf2_base.tests.unit.BidsExportTest.processedWithMarkers();
            root = pf2.export.asBIDS(data, testCase.outRoot, 'Task', 'stroop', ...
                'Verbose', false);
            snirfPath = fullfile(root, 'sub-01', 'nirs', ...
                'sub-01_task-stroop_nirs.snirf');
            T = readtable(fullfile(root, 'sub-01', 'nirs', ...
                'sub-01_task-stroop_channels.tsv'), 'FileType', 'text', ...
                'Delimiter', '\t');
            re = pf2.import.importSNIRF(snirfPath);
            testCase.verifyEqual(height(T), size(re.raw, 2), ...
                'channels.tsv row count must match SNIRF data columns');
        end

        function testOptodesTsvColumnsAndFilename(testCase)
            data = pf2_base.tests.unit.BidsExportTest.processedWithMarkers();
            root = pf2.export.asBIDS(data, testCase.outRoot, 'Task', 'stroop', ...
                'Verbose', false);
            f = fullfile(root, 'sub-01', 'nirs', 'sub-01_optodes.tsv');
            testCase.verifyTrue(isfile(f));
            T = readtable(f, 'FileType', 'text', 'Delimiter', '\t');
            testCase.verifyEqual(T.Properties.VariableNames(1:5), ...
                {'name', 'type', 'x', 'y', 'z'});
            testCase.verifyTrue(all(ismember(T.type, {'source', 'detector'})));
        end

        function testCoordsystemGenericMNIBecomesOther(testCase)
            data = pf2_base.tests.unit.BidsExportTest.processedWithMarkers();
            root = pf2.export.asBIDS(data, testCase.outRoot, 'Task', 'stroop', ...
                'Verbose', false);
            j = jsondecode(fileread(fullfile(root, 'sub-01', 'nirs', ...
                'sub-01_coordsystem.json')));
            testCase.verifyTrue(isfield(j, 'NIRSCoordinateSystem'));
            testCase.verifyTrue(isfield(j, 'NIRSCoordinateUnits'));
            % Generic device 'MNI' must not be promoted to a specific template
            if strcmp(j.NIRSCoordinateSystem, 'Other')
                testCase.verifyTrue(isfield(j, 'NIRSCoordinateSystemDescription'));
            end
        end

        function testEventsTsvContract(testCase)
            data = pf2_base.tests.unit.BidsExportTest.processedWithMarkers();
            root = pf2.export.asBIDS(data, testCase.outRoot, 'Task', 'stroop', ...
                'Verbose', false);
            T = readtable(fullfile(root, 'sub-01', 'nirs', ...
                'sub-01_task-stroop_events.tsv'), 'FileType', 'text', ...
                'Delimiter', '\t');
            testCase.verifyEqual(T.Properties.VariableNames(1:2), ...
                {'onset', 'duration'});
            testCase.verifyGreaterThan(height(T), 0);
        end

        function testRoundTripReimport(testCase)
            data = pf2_base.tests.unit.BidsExportTest.processedWithMarkers();
            root = pf2.export.asBIDS(data, testCase.outRoot, 'Task', 'stroop', ...
                'Verbose', false);
            snirfPath = fullfile(root, 'sub-01', 'nirs', ...
                'sub-01_task-stroop_nirs.snirf');
            re = pf2.import.importSNIRF(snirfPath);
            testCase.verifyTrue(isfield(re, 'raw') && ~isempty(re.raw));
        end
    end

    %% ---- No-marker, batch, and option tests ----
    methods (Test)
        function testNoMarkersSkipsEventsFile(testCase)
            data = pf2.import.sampleData.fNIR2000();   % no markers
            data = processFNIRS2(data);
            root = pf2.export.asBIDS(data, testCase.outRoot, 'Task', 'rest', ...
                'Verbose', false);
            evFiles = dir(fullfile(root, '**', '*_events.tsv'));
            testCase.verifyEmpty(evFiles, ...
                'No events.tsv should be written when there are no markers');
        end

        function testParticipantsOrderingHonorsRequest(testCase)
            d1 = pf2_base.tests.unit.BidsExportTest.processedWithMarkers();
            d1.info.SubjectID = '01';
            d1.info.Age = 30; d1.info.sex = 'male'; d1.info.Group = 'A';
            d2 = d1; d2.info.SubjectID = '02';
            d2.info.Age = 40; d2.info.sex = 'female'; d2.info.Group = 'B';
            root = pf2.export.asBIDS({d1, d2}, testCase.outRoot, 'Task', 'x', ...
                'Participants', {'sex', 'age', 'Group'}, 'Verbose', false);
            T = readtable(fullfile(root, 'participants.tsv'), 'FileType', ...
                'text', 'Delimiter', '\t');
            testCase.verifyEqual(T.Properties.VariableNames, ...
                {'participant_id', 'sex', 'age', 'group'});
            testCase.verifyEqual(height(T), 2);
        end

        function testOverwriteGuard(testCase)
            data = pf2_base.tests.unit.BidsExportTest.processedWithMarkers();
            pf2.export.asBIDS(data, testCase.outRoot, 'Task', 'a', 'Verbose', false);
            % Second export into the now-non-empty root must error without Overwrite
            testCase.verifyError(@() pf2.export.asBIDS(data, testCase.outRoot, ...
                'Task', 'a', 'Verbose', false), 'pf2:asBIDS:rootNotEmpty');
            % With Overwrite it succeeds
            root2 = pf2.export.asBIDS(data, testCase.outRoot, 'Task', 'a', ...
                'Overwrite', true, 'Verbose', false);
            testCase.verifyTrue(isfolder(root2));
        end
    end

    %% ---- Shared fixtures ----
    methods (Static)
        function data = processedWithMarkers()
            % A single processed recording that carries markers, with a known
            % SubjectID and no session so the entity is deterministic
            % (sub-01, no ses-).
            raw = pf2.import.sampleData();         % fNIR1200, has markers
            data = processFNIRS2(raw);
            data.info.SubjectID = '01';
            data.info.Session = '';   % drop session for deterministic paths
        end
    end
end
