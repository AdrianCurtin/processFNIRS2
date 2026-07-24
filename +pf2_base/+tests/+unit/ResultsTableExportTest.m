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
        end
    end
end
