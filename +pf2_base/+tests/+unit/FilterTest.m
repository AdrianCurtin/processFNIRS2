classdef FilterTest < matlab.unittest.TestCase
% FILTERTEST Unit tests for exploreFNIRS.core.Filter

    properties
        sampleTable
    end

    methods (TestMethodSetup)
        function createSampleTable(tc)
            tc.sampleTable = table( ...
                {'S01';'S01';'S02';'S02';'S03';'S03'}, ...
                {'Control';'Control';'Treatment';'Treatment';'Control';'Control'}, ...
                {'TaskA';'TaskB';'TaskA';'TaskB';'TaskA';'TaskB'}, ...
                [25; 25; 30; 30; 22; 22], ...
                'VariableNames', {'SubjectID','Group','Condition','Age'});
        end
    end

    methods (Test)

        function testEmptyFilter(tc)
            f = exploreFNIRS.core.Filter();
            tc.verifyTrue(f.isEmpty());
            idx = f.apply(tc.sampleTable);
            tc.verifyEqual(sum(idx), 6);
        end

        function testIncludeSingle(tc)
            f = exploreFNIRS.core.Filter();
            f = f.include('Group', 'Control');
            idx = f.apply(tc.sampleTable);
            tc.verifyEqual(sum(idx), 4);
        end

        function testIncludeMultiple(tc)
            f = exploreFNIRS.core.Filter();
            f = f.include('Condition', {'TaskA','TaskB'});
            idx = f.apply(tc.sampleTable);
            tc.verifyEqual(sum(idx), 6);
        end

        function testIncludeChained(tc)
            f = exploreFNIRS.core.Filter();
            f = f.include('Group', 'Control').include('Condition', 'TaskA');
            idx = f.apply(tc.sampleTable);
            tc.verifyEqual(sum(idx), 2);
        end

        function testExclude(tc)
            f = exploreFNIRS.core.Filter();
            f = f.exclude('SubjectID', 'S03');
            idx = f.apply(tc.sampleTable);
            tc.verifyEqual(sum(idx), 4);
        end

        function testExcludeMultiple(tc)
            f = exploreFNIRS.core.Filter();
            f = f.exclude('SubjectID', {'S01','S03'});
            idx = f.apply(tc.sampleTable);
            tc.verifyEqual(sum(idx), 2);
        end

        function testIncludeAndExclude(tc)
            f = exploreFNIRS.core.Filter();
            f = f.include('Group', 'Control').exclude('SubjectID', 'S03');
            idx = f.apply(tc.sampleTable);
            tc.verifyEqual(sum(idx), 2);
        end

        function testChannels(tc)
            f = exploreFNIRS.core.Filter();
            f = f.ch([1, 5, 10]);
            tc.verifyTrue(f.hasChannels());
            tc.verifyEqual(f.channels, [1, 5, 10]);
        end

        function testBiomarkers(tc)
            f = exploreFNIRS.core.Filter();
            f = f.bio({'HbO','HbR'});
            tc.verifyTrue(f.hasBiomarkers());
            tc.verifyEqual(f.biomarkers, {'HbO','HbR'});
        end

        function testBiomarkerString(tc)
            f = exploreFNIRS.core.Filter();
            f = f.bio('HbO');
            tc.verifyEqual(f.biomarkers, {'HbO'});
        end

        function testTimeWindow(tc)
            f = exploreFNIRS.core.Filter();
            f = f.time([5, 20]);
            tc.verifyTrue(f.hasTimeWindow());
            tc.verifyEqual(f.timeWindow, [5, 20]);
        end

        function testTimeWindowSorted(tc)
            f = exploreFNIRS.core.Filter();
            f = f.time([20, 5]);
            tc.verifyEqual(f.timeWindow, [5, 20]);
        end

        function testLogicalMask(tc)
            f = exploreFNIRS.core.Filter();
            m = [true; true; false; false; true; true];
            f = f.mask(m);
            idx = f.apply(tc.sampleTable);
            tc.verifyEqual(sum(idx), 4);
        end

        function testAndCombine(tc)
            f1 = exploreFNIRS.core.Filter().include('Group', 'Control');
            f2 = exploreFNIRS.core.Filter().include('Condition', 'TaskA');
            f3 = f1.and(f2);
            idx = f3.apply(tc.sampleTable);
            tc.verifyEqual(sum(idx), 2);
        end

        function testAndChannels(tc)
            f1 = exploreFNIRS.core.Filter().ch([1, 5, 10]);
            f2 = exploreFNIRS.core.Filter().ch([5, 10, 15]);
            f3 = f1.and(f2);
            tc.verifyEqual(f3.channels, [5, 10]);
        end

        function testAndTimeWindow(tc)
            f1 = exploreFNIRS.core.Filter().time([0, 30]);
            f2 = exploreFNIRS.core.Filter().time([10, 25]);
            f3 = f1.and(f2);
            tc.verifyEqual(f3.timeWindow, [10, 25]);
        end

        function testAndMasks(tc)
            m1 = [true; true; false; false; true; true];
            m2 = [true; false; false; true; true; false];
            f1 = exploreFNIRS.core.Filter().mask(m1);
            f2 = exploreFNIRS.core.Filter().mask(m2);
            f3 = f1.and(f2);
            idx = f3.apply(tc.sampleTable);
            tc.verifyEqual(sum(idx), 2);
        end

        function testMissingVariableWarns(tc)
            f = exploreFNIRS.core.Filter().include('NonExistent', 'val');
            tc.verifyWarning(@() f.apply(tc.sampleTable), ...
                'exploreFNIRS:core:Filter:apply');
        end

        function testNotEmpty(tc)
            f = exploreFNIRS.core.Filter().include('Group', 'Control');
            tc.verifyFalse(f.isEmpty());
        end

        function testNumericInclude(tc)
            f = exploreFNIRS.core.Filter().include('Age', 25);
            idx = f.apply(tc.sampleTable);
            tc.verifyEqual(sum(idx), 2);
        end

        function testChainingFluent(tc)
            f = exploreFNIRS.core.Filter() ...
                .include('Group', 'Control') ...
                .exclude('SubjectID', 'S03') ...
                .ch([1,5]) ...
                .bio({'HbO'}) ...
                .time([5, 20]);
            tc.verifyFalse(f.isEmpty());
            tc.verifyTrue(f.hasChannels());
            tc.verifyTrue(f.hasBiomarkers());
            tc.verifyTrue(f.hasTimeWindow());
            idx = f.apply(tc.sampleTable);
            tc.verifyEqual(sum(idx), 2);
        end

    end
end
