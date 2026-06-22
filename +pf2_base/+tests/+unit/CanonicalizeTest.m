classdef CanonicalizeTest < matlab.unittest.TestCase
    % CANONICALIZETEST Unit tests for pf2.probe.canonicalize
    %
    % Tests anatomical canonicalization onto a Brodmann-region axis: single
    % struct projection, region-table structure, channel-count bookkeeping,
    % explicit region axes with empty regions, region averaging correctness,
    % shared axes across a cell array, and error handling.
    %
    % Run all tests:
    %   results = runtests('pf2_base.tests.unit.CanonicalizeTest');
    %
    % See also: pf2.probe.canonicalize, pf2.probe.nearestBrodmann

    properties
        proc   % Processed fNIRS sample data with MNI coordinates
    end

    methods (TestClassSetup)
        function loadSampleData(testCase)
            raw = pf2.import.sampleData.fNIR2000();
            testCase.proc = processFNIRS2(raw);
        end
    end

    methods (Test)
        function testSingleStructStructure(testCase)
            pc = pf2.probe.canonicalize(testCase.proc, 'MaxDistance', 25);
            testCase.verifyTrue(isfield(pc, 'canonical'));
            c = pc.canonical;
            testCase.verifyEqual(c.space, 'Brodmann');
            R = height(c.regions);
            testCase.verifyGreaterThanOrEqual(R, 1);
            testCase.verifyEqual(size(c.HbO, 1), size(testCase.proc.HbO, 1));
            testCase.verifyEqual(size(c.HbO, 2), R);
            testCase.verifyEqual(numel(c.N), R);
            testCase.verifyTrue(all(ismember({'Index', 'BA', 'Name'}, ...
                c.regions.Properties.VariableNames)));
        end

        function testBiomarkersProjected(testCase)
            pc = pf2.probe.canonicalize(testCase.proc, 'MaxDistance', 25);
            R = height(pc.canonical.regions);
            for fn = {'HbO', 'HbR', 'HbTotal', 'HbDiff', 'CBSI'}
                testCase.verifyTrue(isfield(pc.canonical, fn{1}));
                testCase.verifyEqual(size(pc.canonical.(fn{1}), 2), R);
            end
        end

        function testExplicitRegionsEmptyColumn(testCase)
            % BA 17 (visual) should have no channels for a prefrontal probe
            pc = pf2.probe.canonicalize(testCase.proc, ...
                'Regions', [9 10 46 17], 'MaxDistance', 30);
            testCase.verifyEqual(pc.canonical.regions.BA', [9 10 17 46]);  % sorted
            col17 = pc.canonical.regions.BA == 17;
            testCase.verifyEqual(pc.canonical.N(col17), 0);
            testCase.verifyTrue(all(isnan(pc.canonical.HbO(:, col17))));
        end

        function testRegionAveragingCorrect(testCase)
            pc = pf2.probe.canonicalize(testCase.proc, 'MaxDistance', 30);
            ba = pc.canonical.channelBA;
            regions = pc.canonical.regions.BA;
            % Find a populated region and check it equals manual nanmean
            popRegion = find(pc.canonical.N > 0, 1);
            testCase.assumeNotEmpty(popRegion);
            manual = mean(testCase.proc.HbO(:, ba == regions(popRegion)), 2, 'omitnan');
            testCase.verifyEqual(pc.canonical.HbO(:, popRegion), manual, 'AbsTol', 1e-9);
        end

        function testSharedAxisAcrossCellArray(testCase)
            proc2 = processFNIRS2(pf2.import.sampleData());   % different device (fNIR1200)
            grp = pf2.probe.canonicalize({testCase.proc, proc2}, 'MaxDistance', 25);
            testCase.verifyClass(grp, 'cell');
            r1 = grp{1}.canonical.regions.BA;
            r2 = grp{2}.canonical.regions.BA;
            testCase.verifyEqual(r1, r2);   % identical region axis
            testCase.verifyEqual(size(grp{1}.canonical.HbO, 2), numel(r1));
            testCase.verifyEqual(size(grp{2}.canonical.HbO, 2), numel(r2));
        end

        function testErrorUnsupportedSpace(testCase)
            testCase.verifyError(@() pf2.probe.canonicalize(testCase.proc, ...
                'Space', 'AAL'), 'pf2:probe:canonicalize:unsupportedSpace');
        end

        function testErrorBadAggregate(testCase)
            testCase.verifyError(@() pf2.probe.canonicalize(testCase.proc, ...
                'Aggregate', 'median'), 'pf2:probe:canonicalize:badAggregate');
        end

        function testErrorNoRegions(testCase)
            % No channel maps within an absurdly tight threshold -> error
            testCase.verifyError(@() pf2.probe.canonicalize(testCase.proc, ...
                'MaxDistance', 1e-3), 'pf2:probe:canonicalize:noRegions');
        end

        function testProvenanceFields(testCase)
            pc = pf2.probe.canonicalize(testCase.proc, 'MaxDistance', 25);
            c = pc.canonical;
            testCase.verifyEqual(c.MaxDistance, 25);
            testCase.verifyEqual(numel(c.channelBA), size(testCase.proc.HbO, 2));
            testCase.verifyEqual(numel(c.time), size(testCase.proc.HbO, 1));
        end

        function testUnitsMismatchWarning(testCase)
            a = testCase.proc;
            b = testCase.proc;
            b.units = 'mM*mm';   % force a units mismatch across the cell array
            testCase.verifyWarning(@() pf2.probe.canonicalize({a, b}, ...
                'MaxDistance', 25), 'pf2:probe:canonicalize:unitsMismatch');
        end

        function testMeanAggregatePropagatesNaN(testCase)
            % 'mean' (not nanmean) propagates NaN across a region with any NaN channel
            proc = testCase.proc;
            proc.HbO(1, :) = NaN;   % first sample NaN on every channel
            pc = pf2.probe.canonicalize(proc, 'MaxDistance', 30, 'Aggregate', 'mean');
            popRegion = find(pc.canonical.N > 0, 1);
            testCase.assumeNotEmpty(popRegion);
            testCase.verifyTrue(isnan(pc.canonical.HbO(1, popRegion)));
        end
    end
end
