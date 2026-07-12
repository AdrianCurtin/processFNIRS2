classdef ExperimentLMEDiagnosticsTest < matlab.unittest.TestCase
    % EXPERIMENTLMEDIAGNOSTICSTEST Between-subjects confound diagnostics for LME
    %
    % Verifies that exploreFNIRS.core.Experiment.statsFitLME and
    % statsInfoLME detect a fixed-effect factor that is constant within every
    % level of the random grouping variable (a between-subjects confound with
    % the (1|SubjectID) random intercept), emit the consolidated diagnostic
    % (id 'exploreFNIRS:statsLME:betweenSubjectConfound'), suppress the raw
    % repeated MATLAB Hessian/rank-deficiency warnings, and still return
    % numbers for within-subject terms.
    %
    % Warning capture uses evalc on the consolidated diagnostic text. This is
    % verified to capture the diagnostic under headless `-batch` in R2025b (the
    % `warning` function routes through the Command Window stream that evalc
    % intercepts, independent of a display). `lastwarn` is deliberately NOT used
    % to assert the diagnostic: the fitlme path re-emits suppressed
    % rank/Hessian warnings that overwrite lastwarn after our diagnostic fires.
    %
    %   results = runtests('pf2_base.tests.unit.ExperimentLMEDiagnosticsTest');

    properties (Constant)
        ConfoundID  = 'exploreFNIRS:statsLME:betweenSubjectConfound';
        NoteMarker  = 'LME design note:';
    end

    properties
        ex   % Grouped + aggregated Experiment with a between-subjects Group
    end

    methods (TestMethodSetup)
        function buildExperiment(testCase)
            % Synthetic 4-subject group dataset. Each subject has exactly one
            % Group label (Young/Older) -> Group is between-subjects; Condition
            % varies within subject -> within-subjects.
            prev = warning('off', 'all');
            c = onCleanup(@() warning(prev));
            testCase.ex = pf2.import.sampleData.group('GroupBy', ...
                {'Group', 'Condition'});
        end
    end

    methods (Access = private)
        function txt = captureDiag(testCase, fcn)
            % Run fcn() with ONLY the consolidated diagnostic enabled (all other
            % warnings off) and return the captured Command Window text. Enabling
            % just our id keeps the captured text focused on the diagnostic and
            % free of unrelated warning chatter, while evalc remains the capture
            % mechanism (confirmed to work under -batch).
            prev = warning('off', 'all');
            restore = onCleanup(@() warning(prev)); %#ok<NASGU>
            warning('on', testCase.ConfoundID);
            txt = evalc('fcn();');
        end
    end

    methods (Test)
        function emitsSingleConfoundWarning(testCase)
            % statsFitLME must raise the consolidated diagnostic exactly once,
            % naming the between-subjects factor and the grouping variable.
            txt = testCase.captureDiag(@() testCase.ex.statsFitLME( ...
                'Biomarkers', {'HbO'}, 'Channels', 1:2));

            nHits = numel(regexp(txt, testCase.NoteMarker, 'start'));
            testCase.verifyEqual(nHits, 1, ...
                'Expected exactly one between-subjects confound diagnostic.');
            testCase.verifySubstring(txt, 'Group');
            testCase.verifySubstring(txt, 'SubjectID');
        end

        function suppressesRawFitlmeSpam(testCase)
            % The raw MATLAB Hessian/rank warnings must be suppressed during the
            % fit. Enable ONLY the spam ids and capture: if suppression works,
            % none of their text appears; a leak would surface in the output.
            spamIds = {
                'stats:classreg:regr:lmeutils:StandardLinearMixedModel:Message_NotSPDHessian_REML'
                'stats:classreg:regr:lmeutils:StandardLinearMixedModel:Message_NotSPDCovarianceUnconstrainedScale'
                'stats:classreg:regr:lmeutils:StandardLinearMixedModel:Message_NotSPDCovarianceNaturalScale'
                };

            prev = warning('off', 'all');
            restore = onCleanup(@() warning(prev)); %#ok<NASGU>
            for i = 1:numel(spamIds), warning('on', spamIds{i}); end
            txt = evalc(['r = testCase.ex.statsFitLME(''Biomarkers'', ' ...
                '{''HbO''}, ''Channels'', 1:2);']); %#ok<NASGU>

            testCase.verifyEmpty( ...
                regexp(txt, 'Hessian.*not positive definite', 'once'), ...
                'Raw fitlme Hessian warning leaked to the user.');
            testCase.verifyEmpty( ...
                regexp(txt, 'covariance matrix of covariance parameters', 'once'), ...
                'Raw fitlme covariance warning leaked to the user.');
        end

        function restoresWarningStateAfterFit(testCase)
            % The suppressed spam ids must be returned to their prior state.
            spamIds = {
                'stats:classreg:regr:lmeutils:StandardLinearMixedModel:Message_NotSPDHessian_REML'
                'stats:classreg:regr:lmeutils:StandardLinearMixedModel:Message_NotSPDCovarianceNaturalScale'
                };
            prev = warning('off', 'all');
            restore = onCleanup(@() warning(prev)); %#ok<NASGU>
            for i = 1:numel(spamIds), warning('on', spamIds{i}); end

            evalc(['r = testCase.ex.statsFitLME(''Biomarkers'', ' ...
                '{''HbO''}, ''Channels'', 1:2);']);

            for i = 1:numel(spamIds)
                state = warning('query', spamIds{i});
                testCase.verifyEqual(state.state, 'on', ...
                    sprintf('Warning %s was not restored after the fit.', ...
                    spamIds{i}));
            end
        end

        function withinSubjectTermStillEstimates(testCase)
            % Condition (within-subject) must return finite F/p; Group rows may
            % be degenerate but the call must still produce a results struct.
            prev = warning('off', 'all');
            restore = onCleanup(@() warning(prev)); %#ok<NASGU>

            results = testCase.ex.statsFitLME('Biomarkers', {'HbO'}, ...
                'Channels', 1:2);

            testCase.verifyTrue( ...
                ismember('Condition', ...
                results.anova_pval.Properties.VariableNames), ...
                'Condition term missing from ANOVA table.');
            condP = results.anova_pval.Condition;
            testCase.verifyTrue(any(isfinite(condP)), ...
                'Within-subject Condition term returned no finite p-values.');
        end

        function noWarningForWithinSubjectDesign(testCase)
            % A purely within-subjects design must NOT trigger a false-positive
            % confound diagnostic.
            prev = warning('off', 'all');
            ws = pf2.import.sampleData.group('GroupBy', {'Condition'});
            restore = onCleanup(@() warning(prev)); %#ok<NASGU>

            txt = testCase.captureDiag(@() ws.statsFitLME('Biomarkers', ...
                {'HbO'}, 'Channels', 1));

            testCase.verifyEmpty(regexp(txt, testCase.NoteMarker, 'once'), ...
                'False-positive confound diagnostic on within-subjects design.');
        end

        function noWarningForCustomFormulaWithoutBar(testCase)
            % A CustomFormula with NO random intercept ('|') must NOT trigger
            % the confound diagnostic, even when Group is between-subjects.
            txt = testCase.captureDiag(@() testCase.ex.statsFitLME( ...
                'Biomarkers', {'HbO'}, 'Channels', 1, ...
                'CustomFormula', 'HbO~Group+Condition'));

            testCase.verifyEmpty(regexp(txt, testCase.NoteMarker, 'once'), ...
                ['CustomFormula without a random intercept must not raise ' ...
                 'the between-subjects confound diagnostic.']);
        end

        function parenthesizedRandomEffectsStillWarns(testCase)
            % A parenthesized random-effects spec '(1|SubjectID)' must parse
            % to the grouping name 'SubjectID' and still fire the diagnostic.
            txt = testCase.captureDiag(@() testCase.ex.statsFitLME( ...
                'Biomarkers', {'HbO'}, 'Channels', 1:2, ...
                'RandomEffects', '(1|SubjectID)'));

            nHits = numel(regexp(txt, testCase.NoteMarker, 'start'));
            testCase.verifyEqual(nHits, 1, ...
                'Expected one diagnostic with parenthesized RandomEffects.');
            testCase.verifySubstring(txt, 'SubjectID');
            testCase.verifySubstring(txt, 'Group');
        end

        function noWarningForOneObservationPerSubject(testCase)
            % Regression: with exactly one observation per subject (one segment,
            % single bar), a between-subjects factor is NOT confounded with the
            % random intercept (it aliases the residual instead) and IS
            % estimable. The diagnostic must stay silent rather than mislead.
            prev = warning('off', 'all');
            T = table((1:8)', repmat([0;1], 4, 1), (50:57)', ...
                'VariableNames', {'Sub', 'Grp', 'Score'});
            data = pf2.import.fromTable(T, 'Subject','Sub', 'Value','Score', ...
                'Info', {'Grp'});                       % cross-sectional: 1 row/subject
            ex1 = exploreFNIRS.core.Experiment(data);
            ex1.settings.useBaseline = false; ex1.settings.resampleRate = 0;
            ex1.groupby({'Grp'}); ex1.aggregate();
            restore = onCleanup(@() warning(prev)); %#ok<NASGU>

            txt = testCase.captureDiag(@() ex1.statsFitLME('Biomarkers', ...
                {'HbO'}, 'Channels', 1));

            testCase.verifyEmpty(regexp(txt, testCase.NoteMarker, 'once'), ...
                ['One observation per subject must not raise the between-' ...
                 'subjects confound diagnostic (the factor is estimable).']);
        end

        function noWarningForOneSegmentPerSubjectWithBinningDefault(testCase)
            % Regression for the taskEnd=Inf false positive: one segment per
            % subject WITH barBinSize>0 but the DEFAULT taskEnd (Inf). The span
            % must be derived from the data (not assumed infinite), so a clean
            % one-row-per-subject design is not wrongly flagged.
            prev = warning('off', 'all');
            T = table((1:8)', repmat([0;1], 4, 1), (50:57)', ...
                'VariableNames', {'Sub', 'Grp', 'Score'});
            data = pf2.import.fromTable(T, 'Subject','Sub', 'Value','Score', ...
                'Info', {'Grp'});
            ex1 = exploreFNIRS.core.Experiment(data);
            ex1.settings.useBaseline = false; ex1.settings.resampleRate = 0;
            ex1.groupby({'Grp'});
            ex1.settings.barBinSize = 1;            % binning on, taskEnd left Inf
            ex1.aggregate();
            restore = onCleanup(@() warning(prev)); %#ok<NASGU>

            txt = testCase.captureDiag(@() ex1.statsFitLME('Biomarkers', ...
                {'HbO'}, 'Channels', 1));

            testCase.verifyEmpty(regexp(txt, testCase.NoteMarker, 'once'), ...
                ['barBinSize>0 with default taskEnd=Inf must not fabricate ' ...
                 'time-bin replication for a one-row-per-subject design.']);
        end

        function warnsWhenTimeBinsAddWithinSubjectReplication(testCase)
            % Same one-segment-per-subject data, but binning each timepoint as
            % its own observation (barBinSize>0 over a finite taskEnd) restores
            % within-subject replication, so the between-subjects factor IS
            % confounded with (1|Subject) again and the diagnostic must fire.
            prev = warning('off', 'all');
            subj = reshape(repmat(1:6, 3, 1), [], 1);
            wk   = repmat((1:3)', 6, 1);
            grp  = double(subj > 3);
            score = 50 + wk + subj;
            T = table(subj, wk, grp, score, ...
                'VariableNames', {'Sub', 'Week', 'Grp', 'Score'});
            data = pf2.import.fromTable(T, 'Subject','Sub', 'Time','Week', ...
                'Value','Score', 'Info', {'Grp'});
            ex2 = exploreFNIRS.core.Experiment(data);
            ex2.settings.useBaseline = false; ex2.settings.resampleRate = 0;
            ex2.groupby({'Grp'});
            ex2.settings.barBinSize = 1; ex2.settings.taskEnd = 3;
            ex2.aggregate();
            restore = onCleanup(@() warning(prev)); %#ok<NASGU>

            txt = testCase.captureDiag(@() ex2.statsFitLME('Biomarkers', ...
                {'HbO'}, 'Channels', 1));

            testCase.verifySubstring(txt, testCase.NoteMarker, ...
                ['Time-bin replication should re-expose the between-subjects ' ...
                 'confound and fire the diagnostic.']);
        end

        function infoLMEEmitsConfoundWarning(testCase)
            % statsInfoLME must also diagnose the between-subjects confound.
            txt = testCase.captureDiag( ...
                @() testCase.ex.statsInfoLME('reactionTime'));

            testCase.verifySubstring(txt, testCase.NoteMarker, ...
                'statsInfoLME did not emit the confound diagnostic.');
            testCase.verifySubstring(txt, 'Group');
        end
    end
end
