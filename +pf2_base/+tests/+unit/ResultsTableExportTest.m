classdef ResultsTableExportTest < matlab.unittest.TestCase
    % RESULTSTABLEEXPORTTEST Unit tests for results-to-table export helpers
    %
    %   Covers the one-call benchmark-schema exporters and their supporting
    %   channel-label propagation: pf2.probe.montage ChannelLabel column,
    %   pf2.probe.channelLabels, GLMExperiment.groupStats, pf2.export.glmToTable
    %   and pf2.export.blockAvgToTable.
    %
    %   Example:
    %       results = runtests('pf2_base.tests.unit.ResultsTableExportTest');
    %
    %   See also: pf2.probe.montage, pf2.probe.channelLabels,
    %             pf2.export.glmToTable, pf2.export.blockAvgToTable

    properties
        proc         % processed fNIR2000 (has device/MNI)
        gx           % fitted GLMExperiment
        glmSubjects  % raw subjects (for segment building)
        glmBlockDefs % block definitions per subject
        glmRaw, glmOxy
    end

    methods (TestClassSetup)
        function processSample(testCase)
            data = pf2.import.sampleData.fNIR2000();
            testCase.proc = processFNIRS2(data);
        end

        function buildGLM(testCase)
            [subjects, blockDefs] = pf2.import.sampleData.experiment('blocks');
            [rawMethod, oxyMethod] = pf2_base.examples.addDemoPipelines();
            testCase.glmSubjects = subjects;
            testCase.glmBlockDefs = blockDefs;
            testCase.glmRaw = rawMethod;
            testCase.glmOxy = oxyMethod;

            g = exploreFNIRS.core.GLMExperiment(subjects, blockDefs);
            g.settings.rawMethod = rawMethod;
            g.settings.oxyMethod = oxyMethod;
            g.glm.conditions = {'Easy', 'Hard'};
            g.fit();
            testCase.gx = g;
        end
    end

    methods (Test)
        function montageHasChannelLabelColumn(testCase)
            T = pf2.probe.montage(testCase.proc);
            testCase.verifyTrue(ismember('ChannelLabel', T.Properties.VariableNames));
            % Labels look like S#_D#
            first = char(string(T.ChannelLabel(1)));
            testCase.verifyMatches(first, '^S\d+_D\d+$');
        end

        function channelLabelsMatchMontage(testCase)
            labels = pf2.probe.channelLabels(testCase.proc);
            T = pf2.probe.montage(testCase.proc);
            testCase.verifyEqual(string(labels(:)), string(T.ChannelLabel(:)));
        end

        function groupStatsSchemaAndStats(testCase)
            s = testCase.gx.groupStats('Correction', 'fdr');
            expected = {'condition','channel','channel_label','n_subjects', ...
                'mean_beta','se_beta','tstat','pval','pval_corrected'};
            testCase.verifyTrue(all(ismember(expected, s.Properties.VariableNames)));
            testCase.verifyGreaterThan(height(s), 0);
            % p-values in range; one row per (condition, channel)
            testCase.verifyGreaterThanOrEqual(min(s.pval), 0);
            testCase.verifyLessThanOrEqual(max(s.pval), 1);
            [~, ia] = unique(strcat(string(s.condition), '|', string(s.channel)));
            testCase.verifyEqual(numel(ia), height(s), 'rows must be unique per (condition, channel)');
        end

        function glmToTableSchema(testCase)
            T = pf2.export.glmToTable(testCase.gx);
            expected = {'subject','channel','channel_label','condition', ...
                'beta_hbo','beta_hbr'};
            testCase.verifyTrue(all(ismember(expected, T.Properties.VariableNames)));
            testCase.verifyGreaterThan(height(T), 0);
            % channel_label must be S#_D# style (from probe / synthesis)
            testCase.verifyMatches(char(string(T.channel_label(1))), '^S\d+_D\d+$');
        end

        function blockAvgToTableSchema(testCase)
            % Build epoch segments from subject 1's already-defined blocks.
            proc1 = processFNIRS2(testCase.glmSubjects{1}, ...
                'Raw_Method', testCase.glmRaw, 'Oxy_Method', testCase.glmOxy);
            segments = pf2.data.extractBlocks(proc1, testCase.glmBlockDefs{1}, ...
                'PreTime', 5, 'PostTime', 15, 'SetT0', true);

            T = pf2.export.blockAvgToTable(segments);
            expected = {'subject','channel','channel_label','condition', ...
                'n_trials','mean_hbo','se_hbo','mean_hbr','se_hbr'};
            testCase.verifyTrue(all(ismember(expected, T.Properties.VariableNames)));
            testCase.verifyGreaterThan(height(T), 0);
        end

        function glmToTablePreservesDistinctSessions(testCase)
            % Two recordings for the SAME subject in different sessions must
            % keep distinct 'session' values in glmToTable's output -- not
            % collapse onto a single (last-writer-wins) session (regression
            % test for the subject-ID-only session reconstruction bug).
            d1 = testCase.glmSubjects{1};
            d2 = testCase.glmSubjects{2};
            d1.info.SubjectID = 'SubX';
            d2.info.SubjectID = 'SubX';
            d1.info.Session = 'ses-1';
            d2.info.Session = 'ses-2';

            g = exploreFNIRS.core.GLMExperiment( ...
                {d1, d2}, {testCase.glmBlockDefs{1}, testCase.glmBlockDefs{2}});
            g.settings.rawMethod = testCase.glmRaw;
            g.settings.oxyMethod = testCase.glmOxy;
            g.glm.conditions = {'Easy', 'Hard'};
            g.fit();

            T = pf2.export.glmToTable(g);
            testCase.verifyTrue(ismember('session', T.Properties.VariableNames));

            rowsSubX = T(string(T.subject) == "SubX", :);
            testCase.verifyGreaterThan(height(rowsSubX), 0);
            sessVals = unique(string(rowsSubX.session));
            testCase.verifyEqual(numel(sessVals), 2, ...
                'Two same-subject recordings in different sessions must keep distinct session values.');
            testCase.verifyTrue(any(sessVals == "ses-1"));
            testCase.verifyTrue(any(sessVals == "ses-2"));
        end

        function headlessExportErrorsWithoutPath(testCase)
            % Under -batch/matlab.unittest, the session is headless: exporters
            % must error with a clear identifier instead of trying to open a
            % GUI save/directory dialog (which would hang or crash headlessly).
            testCase.verifyTrue(pf2_base.isHeadless(), ...
                'Test runner is expected to be headless (-batch / no desktop).');
            testCase.verifyError(@() pf2.export.asSNIRF(testCase.proc), ...
                'pf2:export:asSNIRF:noPathHeadless');
        end

        function blockAvgToTableRejectsBadChannelAndWindow(testCase)
            proc1 = processFNIRS2(testCase.glmSubjects{1}, ...
                'Raw_Method', testCase.glmRaw, 'Oxy_Method', testCase.glmOxy);
            segments = pf2.data.extractBlocks(proc1, testCase.glmBlockDefs{1}, ...
                'PreTime', 5, 'PostTime', 15, 'SetT0', true);

            nCh = size(segments{1}.HbO, 2);
            testCase.verifyError( ...
                @() pf2.export.blockAvgToTable(segments, 'Channels', nCh + 100), ...
                'pf2:export:blockAvgToTable:badChannel');
            testCase.verifyError( ...
                @() pf2.export.blockAvgToTable(segments, 'TimeWindow', [10 -5]), ...
                'pf2:export:blockAvgToTable:badWindow');
            % Matrix-shaped Channels must be rejected up front, not hit a
            % low-level any()||any() error.
            testCase.verifyError( ...
                @() pf2.export.blockAvgToTable(segments, 'Channels', [1 2; 3 4]), ...
                'pf2:export:blockAvgToTable:badChannel');
        end

        function blockAvgToTableColumnChannelsAllPaths(testCase)
            % A column-vector Channels must iterate per element on BOTH the
            % flat-cell path and the pre-computed grand-average (struct) path;
            % the GA path previously threw MATLAB:nonLogicalConditional.
            proc1 = processFNIRS2(testCase.glmSubjects{1}, ...
                'Raw_Method', testCase.glmRaw, 'Oxy_Method', testCase.glmOxy);
            segments = pf2.data.extractBlocks(proc1, testCase.glmBlockDefs{1}, ...
                'PreTime', 5, 'PostTime', 15, 'SetT0', true);

            % Flat-cell path with a column vector
            Tflat = pf2.export.blockAvgToTable(segments, 'Channels', [1; 2]);
            testCase.verifyEqual(numel(unique(Tflat.channel)), 2);

            % Grand-average struct path with a column vector (the incomplete-fix case)
            ga = pf2.data.blockAverage(segments);
            Tga = pf2.export.blockAvgToTable(ga, 'Channels', [1; 2]);
            testCase.verifyEqual(numel(unique(Tga.channel)), 2);
        end

        function glmToTableTsvExportIsTabDelimited(testCase)
            % Regression test: a bare writetable(T, path) on a '.tsv' path
            % throws MATLAB:table:write:UnrecognizedFileExtension in R2025b.
            % glmToTable's private writeTable() must route '.tsv' through
            % 'FileType','text','Delimiter','\t' instead of falling into the
            % shared '.csv'/'.txt'/'.tsv' case.
            tsvPath = [tempname, '.tsv'];
            cleanupObj = onCleanup(@() deleteIfExists(tsvPath));

            T = pf2.export.glmToTable(testCase.gx, 'SavePath', tsvPath);
            testCase.verifyTrue(isfile(tsvPath), 'glmToTable did not write the .tsv file.');

            firstLine = readFirstLine(tsvPath);
            testCase.verifyTrue(contains(firstLine, sprintf('\t')), ...
                'Exported .tsv header is not tab-delimited.');
            testCase.verifyFalse(contains(firstLine, ','), ...
                'A genuinely tab-delimited header should not also be comma-delimited.');

            % Round-trip as a real TSV (would fail to recover columns if the
            % file were actually comma- or default-delimited).
            Tround = readtable(tsvPath, 'FileType', 'text', 'Delimiter', '\t');
            testCase.verifyEqual(sort(string(Tround.Properties.VariableNames)), ...
                sort(string(T.Properties.VariableNames)));
            testCase.verifyEqual(height(Tround), height(T));
        end

        function blockAvgToTableTsvExportIsTabDelimited(testCase)
            % Same .tsv regression as glmToTableTsvExportIsTabDelimited, for
            % blockAvgToTable's own private writeTable() helper.
            proc1 = processFNIRS2(testCase.glmSubjects{1}, ...
                'Raw_Method', testCase.glmRaw, 'Oxy_Method', testCase.glmOxy);
            segments = pf2.data.extractBlocks(proc1, testCase.glmBlockDefs{1}, ...
                'PreTime', 5, 'PostTime', 15, 'SetT0', true);

            tsvPath = [tempname, '.tsv'];
            cleanupObj = onCleanup(@() deleteIfExists(tsvPath));

            T = pf2.export.blockAvgToTable(segments, 'SavePath', tsvPath);
            testCase.verifyTrue(isfile(tsvPath), 'blockAvgToTable did not write the .tsv file.');

            firstLine = readFirstLine(tsvPath);
            testCase.verifyTrue(contains(firstLine, sprintf('\t')), ...
                'Exported .tsv header is not tab-delimited.');
            testCase.verifyFalse(contains(firstLine, ','), ...
                'A genuinely tab-delimited header should not also be comma-delimited.');

            Tround = readtable(tsvPath, 'FileType', 'text', 'Delimiter', '\t');
            testCase.verifyEqual(sort(string(Tround.Properties.VariableNames)), ...
                sort(string(T.Properties.VariableNames)));
            testCase.verifyEqual(height(Tround), height(T));
        end

        function showHead3DUsesAttachedDeviceWithoutCfgWarning(testCase)
            % Regression test for showHead3D reloading the device via
            % pf2.Device.load(fNIR) (keyed on info.probename) instead of the
            % struct's already-attached .device. Give the struct a probename
            % that does NOT correspond to any .cfg on disk -- a stand-in for a
            % generated/in-memory montage -- so pf2.Device.load(fNIR) itself
            % is confirmed to fail, while showHead3D (now routed through
            % pf2_base.resolveDeviceFromData) must still render the probe
            % headlessly with no "could not resolve probe positions" /
            % cfg-missing warning.
            fNIR = testCase.proc;
            fNIR.info.probename = 'pf2_test_nonexistent_probe_cfg';

            % Confirm the bug precondition: reloading by probename fails.
            testCase.verifyError(@() pf2.Device.load(fNIR), ...
                'pf2_base:loadDeviceCfg:fileNotFound');

            pngPath = [tempname, '.png'];
            cleanupObj = onCleanup(@() deleteIfExists(pngPath));

            % If showHead3D fails to resolve the attached device (the
            % regression), it falls into its catch and emits probeLoadFailed,
            % skipping the overlay. Promote just that warning to an error so
            % this test catches the regression precisely, without tripping on
            % benign graphics/age warnings that a broad verifyWarningFree flags.
            wState = warning('error', 'pf2:probe:plot:showHead3D:probeLoadFailed');
            restoreWarn = onCleanup(@() warning(wState));

            pf2.probe.plot.showHead3D(fNIR, 'savePath', pngPath);
            testCase.verifyTrue(isfile(pngPath));
            fi = dir(pngPath);
            testCase.verifyGreaterThan(fi.bytes, 0);
        end

        function resolveDeviceFromDataReturnsAttachedDevice(testCase)
            % Lower-level structural companion to the showHead3D check above:
            % pf2_base.resolveDeviceFromData must hand back the struct's own
            % .device rather than attempt a probename reload, even when
            % info.probename would not resolve to any real .cfg.
            fNIR = testCase.proc;
            fNIR.info.probename = 'pf2_test_nonexistent_probe_cfg';

            dev = pf2_base.resolveDeviceFromData(fNIR);
            testCase.verifyClass(dev, 'pf2.Device');
            testCase.verifyTrue(isequaln(dev, fNIR.device), ...
                'resolveDeviceFromData must return the already-attached device.');
        end
    end
end

function deleteIfExists(f)
    if exist(f, 'file'); delete(f); end
end

function line = readFirstLine(filepath)
    fid = fopen(filepath, 'r');
    cleanupObj = onCleanup(@() fclose(fid));
    line = fgetl(fid);
    if ~ischar(line), line = ''; end
end
