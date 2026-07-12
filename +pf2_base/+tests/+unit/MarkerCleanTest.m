classdef MarkerCleanTest < matlab.unittest.TestCase
    % MARKERCLEANTEST Unit tests for pf2.data.dedupeMarkers and removeMarkers
    %
    % Covers near-duplicate collapsing (dedupeMarkers) and selective removal
    % (removeMarkers) of marker rows, on both struct and bare-table inputs,
    % verifying that extra/user columns and the canonical table class survive.
    %
    % Run all tests:
    %   results = runtests('pf2_base.tests.unit.MarkerCleanTest');
    %
    % See also: pf2.data.dedupeMarkers, pf2.data.removeMarkers

    methods (Static)
        function m = makeMarkers()
            % Canonical marker table with an extra RT column
            m = pf2_base.normalizeMarkers([
                10,    49, 0, 1;
                10.02, 49, 0, 1;   % near-dup of row 1 (same code, +0.02 s)
                10.04, 49, 0, 1;   % near-dup of row 1 (within tol of anchor)
                30,    50, 0, 1;
                30.01, 49, 0, 1;   % different code from the 50 just before
                60,    49, 0, 1;
            ]);
            m.RT = (1:height(m))' / 10;
        end
    end

    methods (Test)

        %% --- dedupeMarkers -------------------------------------------------

        function testDedupeCollapsesSameCodeWithinTol(testCase)
            m = pf2_base.tests.unit.MarkerCleanTest.makeMarkers();
            out = pf2.data.dedupeMarkers(m, 'Tolerance', 0.05, 'Verbose', false);

            % Rows 2 and 3 (code 49 within 0.05 s of the t=10 anchor) collapse.
            testCase.verifyTrue(istable(out), 'Table input returns a table');
            testCase.verifyEqual(height(out), 4, ...
                'Two near-duplicate code-49 rows should be removed');
            % The earliest row of each cluster is kept.
            testCase.verifyEqual(out.Time(1), 10, 'Earliest row of cluster kept');
        end

        function testDedupeKeepsEarliestAndExtras(testCase)
            m = pf2_base.tests.unit.MarkerCleanTest.makeMarkers();
            out = pf2.data.dedupeMarkers(m, 'Verbose', false);

            testCase.verifyTrue(ismember('RT', out.Properties.VariableNames), ...
                'Extra RT column preserved');
            % The kept t=10 row carries its own RT (0.1), not a neighbour's.
            keptRow = out(out.Time == 10, :);
            testCase.verifyEqual(keptRow.RT, 0.1, 'AbsTol', 1e-9, ...
                'Extra column value of the earliest row is retained');
        end

        function testDedupeDifferentCodesNotCollapsed(testCase)
            % A code-50 at t=30 and a code-49 at t=30.01 differ in code and
            % must both survive even though they are within tolerance.
            m = pf2_base.tests.unit.MarkerCleanTest.makeMarkers();
            out = pf2.data.dedupeMarkers(m, 'Tolerance', 0.05, 'Verbose', false);
            testCase.verifyTrue(any(out.Time == 30 & out.Code == 50));
            testCase.verifyTrue(any(out.Time == 30.01 & out.Code == 49));
        end

        function testDedupeStructInput(testCase)
            m = pf2_base.tests.unit.MarkerCleanTest.makeMarkers();
            data = struct('time', (0:0.1:70)', 'markers', m, 'info', struct());
            out = pf2.data.dedupeMarkers(data, 'Verbose', false);

            testCase.verifyTrue(isstruct(out), 'Struct input returns a struct');
            testCase.verifyTrue(istable(out.markers), '.markers stays a table');
            testCase.verifyEqual(height(out.markers), 4);
            testCase.verifyTrue(isfield(out, 'time'), 'Other struct fields preserved');
        end

        function testDedupeEmptyInput(testCase)
            out = pf2.data.dedupeMarkers(pf2_base.normalizeMarkers([]), 'Verbose', false);
            testCase.verifyTrue(istable(out));
            testCase.verifyEqual(height(out), 0);
        end

        function testDedupeSingleRow(testCase)
            m = pf2_base.normalizeMarkers([10 49 0 1]);
            out = pf2.data.dedupeMarkers(m, 'Verbose', false);
            testCase.verifyEqual(height(out), 1, 'Single row is unchanged');
        end

        function testDedupeMatrixInput(testCase)
            out = pf2.data.dedupeMarkers([10 49; 10.01 49; 50 49], ...
                'Tolerance', 0.05, 'Verbose', false);
            testCase.verifyTrue(istable(out), 'Matrix input returns a table');
            testCase.verifyEqual(height(out), 2);
        end

        %% --- removeMarkers -------------------------------------------------

        function testRemoveByCode(testCase)
            m = pf2_base.tests.unit.MarkerCleanTest.makeMarkers();
            out = pf2.data.removeMarkers(m, 50, 'Verbose', false);
            testCase.verifyFalse(any(out.Code == 50), 'Code 50 removed');
            testCase.verifyTrue(all(out.Code == 49), 'Only code 49 remains');
        end

        function testRemoveByCodeVector(testCase)
            m = pf2_base.tests.unit.MarkerCleanTest.makeMarkers();
            out = pf2.data.removeMarkers(m, [49 50], 'Verbose', false);
            testCase.verifyEqual(height(out), 0, 'All listed codes removed');
        end

        function testRemoveByTimeWindow(testCase)
            m = pf2_base.tests.unit.MarkerCleanTest.makeMarkers();
            out = pf2.data.removeMarkers(m, 'Time', [0 11], 'Verbose', false);
            testCase.verifyTrue(all(out.Time > 11), 'In-window rows removed');
            testCase.verifyTrue(any(out.Time == 30), 'Out-of-window rows kept');
        end

        function testRemoveByIndices(testCase)
            m = pf2_base.tests.unit.MarkerCleanTest.makeMarkers();
            out = pf2.data.removeMarkers(m, 'Indices', [1 6], 'Verbose', false);
            testCase.verifyEqual(height(out), 4, 'Two indexed rows removed');
            testCase.verifyFalse(any(out.Time == 10 & out.Code == 49 & out.RT == 0.1));
            testCase.verifyFalse(any(out.Time == 60), 'Last row removed by index');
        end

        function testRemovePreservesTableClassAndExtras(testCase)
            m = pf2_base.tests.unit.MarkerCleanTest.makeMarkers();
            out = pf2.data.removeMarkers(m, 50, 'Verbose', false);
            testCase.verifyTrue(istable(out), 'Returns a table');
            testCase.verifyTrue(ismember('RT', out.Properties.VariableNames), ...
                'Extra RT column preserved');
            testCase.verifyEqual(out.Properties.VariableNames(1:4), ...
                {'Time','Code','Duration','Amplitude'});
        end

        function testRemoveStructInput(testCase)
            m = pf2_base.tests.unit.MarkerCleanTest.makeMarkers();
            data = struct('time', (0:0.1:70)', 'markers', m, 'info', struct());
            out = pf2.data.removeMarkers(data, 50, 'Verbose', false);
            testCase.verifyTrue(isstruct(out));
            testCase.verifyTrue(istable(out.markers));
            testCase.verifyFalse(any(out.markers.Code == 50));
        end

        function testRemoveCombinedSelectors(testCase)
            % Code OR time-window union
            m = pf2_base.tests.unit.MarkerCleanTest.makeMarkers();
            out = pf2.data.removeMarkers(m, 50, 'Time', [0 11], 'Verbose', false);
            testCase.verifyFalse(any(out.Code == 50));
            testCase.verifyFalse(any(out.Time <= 11));
        end

        function testRemoveNoSelectorErrors(testCase)
            m = pf2_base.tests.unit.MarkerCleanTest.makeMarkers();
            testCase.verifyError(...
                @() pf2.data.removeMarkers(m), ...
                'pf2:removeMarkers:noSelector');
        end
    end
end
