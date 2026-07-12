classdef FromTableTest < matlab.unittest.TestCase
    % FROMTABLETEST Adapting plain repeated-measures tables into fNIRS segments
    %
    % Covers pf2.import.fromTable (building device-less segment structs from a
    % long-format table) and the processFNIRS2 noop pass-through that lets such
    % segments - which carry no raw light intensities - flow through the
    % pipeline unchanged without requiring a device/probe cfg.
    %
    %   results = runtests('pf2_base.tests.unit.FromTableTest');

    properties
        T   % long-format repeated-measures table (subject x time x value)
    end

    methods (TestClassSetup)
        function setup(testCase)
            % 6 subjects, 3 timepoints, a between-subject group + covariate.
            subj = {}; week = []; score = []; grp = {}; gpa = [];
            ids = {'S1','S2','S3','S4','S5','S6'};
            groups = {'A','A','A','B','B','B'};
            for i = 1:numel(ids)
                for w = [1 6 12]
                    subj{end+1,1} = ids{i}; %#ok<AGROW>
                    week(end+1,1) = w;       %#ok<AGROW>
                    score(end+1,1) = 50 + w + i; %#ok<AGROW>
                    grp{end+1,1} = groups{i}; %#ok<AGROW>
                    gpa(end+1,1) = 2 + 0.1*i; %#ok<AGROW>
                end
            end
            testCase.T = table(subj, week, score, grp, gpa, ...
                'VariableNames', {'StudentID','Week','Score','Group','GPA'});
        end
    end

    methods (Test)

        function testBuildsOneSegmentPerSubject(testCase)
            data = pf2.import.fromTable(testCase.T, 'Subject','StudentID', ...
                'Time','Week', 'Value','Score', 'Info',{'Group','GPA'});
            testCase.verifyClass(data, 'cell');
            testCase.verifyEqual(numel(data), 6, 'One segment per subject.');
            seg = data{1};
            testCase.verifySize(seg.HbO, [3 1], 'Time x channel.');
        end

        function testCopiesValueIntoAllFiveBiomarkers(testCase)
            data = pf2.import.fromTable(testCase.T, 'Subject','StudentID', ...
                'Time','Week', 'Value','Score');
            seg = data{1};
            for f = {'HbO','HbR','HbTotal','HbDiff','CBSI'}
                testCase.verifyTrue(isfield(seg, f{1}), ...
                    sprintf('Missing biomarker %s (grandAvgFNIRS requires all 5).', f{1}));
                testCase.verifyEqual(seg.(f{1}), seg.HbO);
            end
        end

        function testDefaultIndexTimeIsUniform(testCase)
            % Default TimeMode='index' yields a uniform 1..K grid (real levels
            % [1 6 12] would otherwise NaN-explode in grand averaging).
            data = pf2.import.fromTable(testCase.T, 'Subject','StudentID', ...
                'Time','Week', 'Value','Score');
            testCase.verifyEqual(data{1}.time, [1;2;3]);
            testCase.verifyEqual(data{1}.timeLevels, [1;6;12]);
            testCase.verifyEqual(data{1}.fs, 1);
        end

        function testValueTimeModeWarnsOnNonUniform(testCase)
            testCase.verifyWarning(@() pf2.import.fromTable(testCase.T, ...
                'Subject','StudentID', 'Time','Week', 'Value','Score', ...
                'TimeMode','value'), 'pf2:fromTable:nonUniformTime');
        end

        function testInfoCarriesFactors(testCase)
            data = pf2.import.fromTable(testCase.T, 'Subject','StudentID', ...
                'Time','Week', 'Value','Score', 'Info',{'Group','GPA'});
            info = data{1}.info;
            testCase.verifyEqual(info.SubjectID, 'S1');
            testCase.verifyEqual(info.Group, 'A');
            testCase.verifyEqual(info.GPA, 2.1, 'AbsTol', 1e-9);
        end

        function testMultipleValuesBecomeChannels(testCase)
            T2 = testCase.T; T2.Score2 = testCase.T.Score * 2;
            data = pf2.import.fromTable(T2, 'Subject','StudentID', 'Time','Week', ...
                'Value',{'Score','Score2'});
            testCase.verifySize(data{1}.HbO, [3 2]);
            testCase.verifyEqual(data{1}.valueNames, {'Score','Score2'});
        end

        function testCrossSectionalNoTime(testCase)
            data = pf2.import.fromTable(testCase.T, 'Subject','StudentID', ...
                'Value','Score', 'Info',{'Group'});  % collapses time
            testCase.verifySize(data{1}.HbO, [1 1]);
        end

        function testThreeWayDuplicateMeanIsCorrect(testCase)
            % Regression: pairwise running mean gave wrong answer for 3+ dups.
            % One subject, one timepoint, three rows -> true mean of all three.
            tdup = table({'X';'X';'X'}, [1;1;1], [1;3;5], ...
                'VariableNames', {'ID','t','v'});
            w = warning('off', 'pf2:fromTable:combinedDuplicates');
            c = onCleanup(@() warning(w));
            data = pf2.import.fromTable(tdup, 'Subject','ID', 'Time','t', 'Value','v');
            testCase.verifyEqual(data{1}.HbO(1), 3, 'AbsTol', 1e-12, ...
                'mean([1 3 5]) must be 3, not the pairwise-running 3.5.');
        end

        function testDuplicateMeanIgnoresNaN(testCase)
            tdup = table({'X';'X';'X'}, [1;1;1], [NaN;20;30], ...
                'VariableNames', {'ID','t','v'});
            w = warning('off', 'pf2:fromTable:combinedDuplicates');
            c = onCleanup(@() warning(w));
            data = pf2.import.fromTable(tdup, 'Subject','ID', 'Time','t', 'Value','v');
            testCase.verifyEqual(data{1}.HbO(1), 25, 'AbsTol', 1e-12);
        end

        function testSubjectFieldNotClobberedByInfoColumn(testCase)
            % 'SubjectField' colliding with an Info column must keep the id.
            data = pf2.import.fromTable(testCase.T, 'Subject','StudentID', ...
                'Time','Week', 'Value','Score', 'Info',{'Group'}, ...
                'SubjectField','Group');
            testCase.verifyEqual(data{1}.info.Group, 'S1', ...
                'subjectField must win over a same-named Info column.');
        end

        function testDataNaNNotFlaggedAsMissingLevel(testCase)
            % A NaN value (level present) must NOT trigger the missing-level warning.
            T2 = testCase.T;
            T2.Score(1) = NaN;   % S1 week 1 present but NaN
            testCase.verifyWarningFree(@() captureMissing(T2));
            function captureMissing(tt)
                % only the missingLevels warning is under test; silence others
                w = warning('off', 'pf2:fromTable:combinedDuplicates');
                c = onCleanup(@() warning(w)); %#ok<NASGU>
                pf2.import.fromTable(tt, 'Subject','StudentID', 'Time','Week', 'Value','Score');
            end
        end

        function testMissingLevelWarnsWhenRowAbsent(testCase)
            % Genuinely absent row at a level -> missingLevels warning.
            T2 = testCase.T;
            T2(1, :) = [];   % drop S1 week 1 entirely
            testCase.verifyWarning(@() pf2.import.fromTable(T2, ...
                'Subject','StudentID', 'Time','Week', 'Value','Score'), ...
                'pf2:fromTable:missingLevels');
        end

        function testMissingColumnErrors(testCase)
            testCase.verifyError(@() pf2.import.fromTable(testCase.T, ...
                'Subject','nope', 'Value','Score'), 'pf2:fromTable:missingColumn');
        end

        function testRequiresValue(testCase)
            testCase.verifyError(@() pf2.import.fromTable(testCase.T, ...
                'Subject','StudentID'), 'pf2:fromTable:noValue');
        end

        function testFeedsExperiment(testCase)
            data = pf2.import.fromTable(testCase.T, 'Subject','StudentID', ...
                'Time','Week', 'Value','Score', 'Info',{'Group'});
            ex = exploreFNIRS.core.Experiment(data);
            ex.settings.useBaseline = false; ex.settings.resampleRate = 0;
            ex.groupby({'Group'});
            ex.aggregate();
            testCase.verifyTrue(ex.isAggregated, 'Experiment should aggregate.');
            testCase.verifyTrue(ismember('Group', ex.dataTable.Properties.VariableNames));
        end

        % --- processFNIRS2 noop pass-through ---------------------------------

        function testNoopPassesBiomarkerStructUnchanged(testCase)
            data = pf2.import.fromTable(testCase.T, 'Subject','StudentID', ...
                'Time','Week', 'Value','Score');
            proc = processFNIRS2(data);   % cell array path
            testCase.verifyEqual(proc, data, ...
                'Device-less biomarker segments must pass through unchanged.');
        end

        function testNoopPassesEmpty(testCase)
            testCase.verifyEmpty(processFNIRS2([]));
        end

        function testNoopMixedCellArray(testCase)
            data = pf2.import.fromTable(testCase.T, 'Subject','StudentID', ...
                'Time','Week', 'Value','Score');
            mixed = {data{1}, [], data{2}};
            out = processFNIRS2(mixed);
            testCase.verifyEqual(numel(out), 3);
            testCase.verifyEmpty(out{2});
            testCase.verifyEqual(out{1}, data{1});
        end

    end
end
