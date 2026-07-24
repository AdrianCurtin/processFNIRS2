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
    %     4. detectStimulusRegressors' nuisance patterns are boundary-anchored
    %        so legitimate condition names containing a nuisance SUBSTRING
    %        (e.g. 'Emotion' contains 'motion', 'Response' contains 'resp')
    %        are no longer wrongly excluded, while real nuisance regressors
    %        (motion_1, resp, aux_heartRate, ...) are still excluded. Also
    %        covers betaTable() returning an empty table (instead of
    %        erroring in struct2table) when every regressor is excluded.
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

        function emotionAndResponseConditionsSurviveExclusion(testCase)
            % Regression test for detectStimulusRegressors' bare-substring
            % nuisance patterns: 'motion' used to match inside 'Emotion' and
            % 'resp' used to match inside 'Response', wrongly excluding these
            % legitimate condition names from betaTable()/groupStats(). The
            % patterns are now boundary-anchored, so these condition names
            % must survive auto-detection.
            d1 = testCase.data;
            d1.info.SubjectID = 'S01';

            condMap = {10, 'Emotion'; 20, 'Response'};
            blocksER = pf2.data.defineBlocks(d1, [10, 20], 20, ...
                'ConditionMap', condMap, 'Embed', false);

            subjects  = {d1};
            blockDefs = {blocksER};

            gx = exploreFNIRS.core.GLMExperiment(subjects, blockDefs);
            % gx.glm.conditions left empty -> auto-detected from regressor names
            gx.fit();

            T = gx.betaTable();
            condsBT = unique(string(T.Condition));
            testCase.verifyTrue(all(ismember({'Emotion', 'Response'}, condsBT)), ...
                'Emotion/Response must survive betaTable auto-detection (not be excluded as motion/resp nuisance substrings)');

            stats = gx.groupStats('Correction', 'none');
            condsGS = unique(string(stats.condition));
            testCase.verifyTrue(all(ismember({'Emotion', 'Response'}, condsGS)), ...
                'Emotion/Response must survive groupStats auto-detection (not be excluded as motion/resp nuisance substrings)');
        end

        function nuisanceTokensStillExcludedAfterAnchoring(testCase)
            % Sanity check that anchoring the nuisance patterns (to fix the
            % Emotion/Response false-positive exclusion) did not weaken real
            % nuisance detection: motion_1, resp, and aux_heartRate must
            % still be excluded from betaTable()/groupStats() conditions.
            d1 = testCase.data;
            d1.info.SubjectID = 'S01';

            subjects  = {d1};
            blockDefs = {testCase.blocks};

            gx = exploreFNIRS.core.GLMExperiment(subjects, blockDefs);
            gx.fit();

            % Inject synthetic nuisance-named regressors (with dummy
            % beta/tstat/pval rows) alongside the real Easy/Hard condition
            % regressors, exercising detectStimulusRegressors end-to-end
            % through the public betaTable()/groupStats() API.
            fakeNuisance = {'motion_1', 'resp', 'aux_heartRate'};
            nFake = numel(fakeNuisance);
            for b = 1:numel(gx.glm.biomarkers)
                bio = gx.glm.biomarkers{b};
                r = gx.subjectResults{1}.results.(bio);
                nCh = size(r.beta, 2);
                r.regressorNames = [r.regressorNames, fakeNuisance];
                r.beta  = [r.beta;  zeros(nFake, nCh)];
                r.tstat = [r.tstat; zeros(nFake, nCh)];
                r.pval  = [r.pval;  ones(nFake, nCh)];
                gx.subjectResults{1}.results.(bio) = r;
            end
            gx.subjectResults{1}.regressorNames = ...
                [gx.subjectResults{1}.regressorNames, fakeNuisance];

            T = gx.betaTable();
            condsBT = unique(string(T.Condition));
            testCase.verifyFalse(any(ismember(fakeNuisance, condsBT)), ...
                'motion_1/resp/aux_heartRate must still be excluded from betaTable conditions');
            testCase.verifyTrue(all(ismember({'Easy', 'Hard'}, condsBT)), ...
                'Real conditions must still be present alongside the injected nuisance regressors');

            stats = gx.groupStats('Correction', 'none');
            condsGS = unique(string(stats.condition));
            testCase.verifyFalse(any(ismember(fakeNuisance, condsGS)), ...
                'motion_1/resp/aux_heartRate must still be excluded from groupStats conditions');
        end

        function betaTableReturnsEmptyTableWhenAllRegressorsExcluded(testCase)
            % Regression test for the betaTable() crash: when every
            % auto-detected regressor is excluded as nuisance, 'rows' stays
            % empty and struct2table([rows{:}]) used to error. betaTable
            % must instead return an empty (0-row) table.
            d1 = testCase.data;
            d1.info.SubjectID = 'S01';

            subjects  = {d1};
            blockDefs = {testCase.blocks};

            gx = exploreFNIRS.core.GLMExperiment(subjects, blockDefs);
            gx.glm.conditions = {'Easy', 'Hard'};
            gx.fit();

            % Rename both fitted condition regressors to nuisance-looking
            % names (consistently in the per-biomarker AND shared top-level
            % regressor-name lists), then clear glm.conditions so betaTable
            % falls back to auto-detection. Every candidate condition is now
            % excluded by detectStimulusRegressors.
            for b = 1:numel(gx.glm.biomarkers)
                bio = gx.glm.biomarkers{b};
                names = gx.subjectResults{1}.results.(bio).regressorNames;
                names(strcmp(names, 'Easy')) = {'motion_1'};
                names(strcmp(names, 'Hard')) = {'resp'};
                gx.subjectResults{1}.results.(bio).regressorNames = names;
            end
            topNames = gx.subjectResults{1}.regressorNames;
            topNames(strcmp(topNames, 'Easy')) = {'motion_1'};
            topNames(strcmp(topNames, 'Hard')) = {'resp'};
            gx.subjectResults{1}.regressorNames = topNames;
            gx.glm.conditions = {};

            T = gx.betaTable();
            testCase.verifyClass(T, 'table');
            testCase.verifyEqual(height(T), 0, ...
                'betaTable must return an empty table, not error, when every regressor is excluded as nuisance');
        end

    end
end
