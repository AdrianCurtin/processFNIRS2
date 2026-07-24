classdef GroupStatsIndependenceTest < matlab.unittest.TestCase
    % GROUPSTATSINDEPENDENCETEST Regression tests for GLMExperiment.groupStats
    %
    %   Covers three fixed bugs in exploreFNIRS.core.GLMExperiment:
    %     1. Repeated recordings (e.g. BIDS runs/sessions) for the same
    %        participant no longer inflate n_subjects/dof in groupStats --
    %        betas are averaged within subject (identity resolved from
    %        .info.SubjectID/participant_id/subject/Subject) before the
    %        across-subjects one-sample t-test.
    %     2. Subjects/recordings with different channel counts are aligned
    %        by channel_label (NaN-padded) instead of crashing with a
    %        dimension mismatch.
    %     3. Nuisance regressors (aux/drift confounds) are excluded from the
    %        auto-detected condition list in betaTable()/groupStats().
    %
    %   Example:
    %       results = runtests('pf2_base.tests.unit.GroupStatsIndependenceTest');
    %       disp(results);
    %
    %   See also: exploreFNIRS.core.GLMExperiment,
    %             exploreFNIRS.core.GLMExperiment.groupStats,
    %             exploreFNIRS.core.GLMExperiment.betaTable

    properties
        data     % Processed fNIR2000 (base continuous recording)
        blocks   % Block struct array from defineBlocks (Easy/Hard)
    end

    methods (TestClassSetup)
        function loadSampleData(testCase)
            raw = pf2.import.sampleData.fNIR2000();
            d = processFNIRS2(raw);

            % Add markers for 4 blocks: 2 Easy (10), 2 Hard (20)
            rng(11);
            onsets = [60, 150, 250, 350];
            codes  = [10, 20, 10, 20];
            dur    = 20;
            d.markers = pf2_base.normalizeMarkers( ...
                [onsets(:), codes(:), repmat(dur, numel(onsets), 1)]);
            testCase.data = d;

            condMap = {10, 'Easy'; 20, 'Hard'};
            testCase.blocks = pf2.data.defineBlocks(d, [10, 20], dur, ...
                'ConditionMap', condMap, 'Embed', false);
        end
    end

    methods (Test)

        function sameSubjectIDRecordingsDoNotInflateNSubjects(testCase)
            % Two RECORDINGS sharing the same SubjectID (e.g. two BIDS runs
            % of one participant) plus a distinct second subject: n_subjects
            % must reflect unique SUBJECTS (2), not recordings (3).
            d1 = testCase.data;
            d1.info.SubjectID = 'S01';
            d1.info.Session = '1';

            d2 = testCase.data;
            d2.info.SubjectID = 'S01';
            d2.info.Session = '2';
            d2.HbO = d2.HbO + randn(size(d2.HbO)) * 0.001;  % distinguish the two runs

            d3 = testCase.data;
            d3.info.SubjectID = 'S02';
            d3.HbO = d3.HbO + randn(size(d3.HbO)) * 0.001;

            subjects  = {d1, d2, d3};
            blockDefs = {testCase.blocks, testCase.blocks, testCase.blocks};

            gx = exploreFNIRS.core.GLMExperiment(subjects, blockDefs);
            gx.glm.conditions = {'Easy', 'Hard'};
            gx.fit();

            stats = gx.groupStats('Correction', 'none');

            testCase.verifyEqual(max(stats.n_subjects), 2, ...
                'n_subjects must count unique SubjectIDs (2), not recordings (3)');
            testCase.verifyEqual(max(stats.df), 1, ...
                'df must be n_subjects-1 for 2 unique subjects (not 3 recordings-1)');
        end

        function mixedChannelCountsRunWithoutError(testCase)
            % Subjects with different channel counts must not crash groupStats
            % with a dimension mismatch; channels are aligned by channel_label.
            d1 = testCase.data;
            d1.info.SubjectID = 'S01';   % full montage (all channels)
            nChFull = size(d1.HbO, 2);
            testCase.assumeGreaterThan(nChFull, 4, ...
                'Sample data must have more than 4 channels for this test');

            d2 = testCase.data;
            d2.info.SubjectID = 'S02';
            d2.HbO = d2.HbO(:, 1:4);   % truncate to the first 4 channels
            d2.HbR = d2.HbR(:, 1:4);

            subjects  = {d1, d2};
            blockDefs = {testCase.blocks, testCase.blocks};

            gx = exploreFNIRS.core.GLMExperiment(subjects, blockDefs);
            gx.glm.conditions = {'Easy', 'Hard'};
            gx.fit();

            % Must not error despite the channel-count mismatch.
            stats = gx.groupStats('Correction', 'none');

            easyStats = stats(strcmp(string(stats.condition), 'Easy'), :);
            [~, ord] = sort(easyStats.channel);
            easyStats = easyStats(ord, :);

            testCase.verifyEqual(height(easyStats), nChFull, ...
                'Channel axis should be the UNION across subjects (full montage size)');
            testCase.verifyTrue(all(easyStats.n_subjects(1:4) == 2), ...
                'First 4 (shared) channels should have both subjects contributing');
            testCase.verifyTrue(all(easyStats.n_subjects(5:end) == 1), ...
                'Channels beyond 4 should only have the full-montage subject');
        end

        function nuisanceRegressorExcludedFromConditions(testCase)
            % A nuisance-named regressor (aux confound) must not appear as a
            % task "condition" in betaTable() or groupStats() output.
            d1 = testCase.data;
            d1.info.SubjectID = 'S01';

            % Attach a heart-rate Aux signal to use as a GLM nuisance regressor
            rng(3);
            d1.Aux.heartRate.data = 70 + 3 * randn(numel(d1.time), 1);
            d1.Aux.heartRate.time = d1.time;
            d1.Aux.heartRate.unit = 'bpm';
            d1.Aux.heartRate.varNames = {'HR'};

            subjects  = {d1};
            blockDefs = {testCase.blocks};

            gx = exploreFNIRS.core.GLMExperiment(subjects, blockDefs);
            gx.glm.auxNuisance = {'heartRate'};
            % gx.glm.conditions left empty -> auto-detected from regressor names
            gx.fit();

            r1 = gx.getSubjectResult(1);
            allNames = r1.results.HbO.regressorNames;
            testCase.verifyTrue(any(startsWith(allNames, 'aux_heartRate')), ...
                'Sanity check: the aux nuisance regressor should be in the design matrix');

            T = gx.betaTable();
            condsBT = unique(string(T.Condition));
            testCase.verifyFalse(any(startsWith(condsBT, 'aux_')), ...
                'betaTable must not surface aux_* nuisance regressors as conditions');
            testCase.verifyTrue(all(ismember(condsBT, {'Easy', 'Hard'})));

            stats = gx.groupStats('Correction', 'none');
            condsGS = unique(string(stats.condition));
            testCase.verifyFalse(any(startsWith(condsGS, 'aux_')), ...
                'groupStats must not surface aux_* nuisance regressors as conditions');
            testCase.verifyTrue(all(ismember(condsGS, {'Easy', 'Hard'})));
        end

    end
end
