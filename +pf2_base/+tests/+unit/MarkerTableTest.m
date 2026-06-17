classdef MarkerTableTest < matlab.unittest.TestCase
    % MARKERTABLETEST Unit tests for the canonical marker-table representation
    %
    % Verifies that markers are represented as a canonical table
    % (Time, Code, Duration, Amplitude + optional extras) and that the
    % normalizeMarkers / markersToArray / mergeMarkers helpers and the core
    % preprocessing/splicing path preserve that representation, including any
    % user-appended extra columns.

    methods (TestClassSetup)
        function suppressChannelCheckGUI(testCase)
            % Ensure the interactive channel-check GUI never opens during
            % automated testing (these tests import sample recordings).
            prev = pf2_base.channelCheckGUIEnabled(false);
            testCase.addTeardown(@() pf2_base.channelCheckGUIEnabled(prev));
        end
    end

    methods (Test)

        %% --- normalizeMarkers ---------------------------------------------

        function testNormalizeMatrixToTable(testCase)
            m = pf2_base.normalizeMarkers([10 49; 25 51]);
            testCase.verifyTrue(istable(m), 'normalizeMarkers should return a table');
            testCase.verifyEqual(m.Properties.VariableNames(1:4), ...
                {'Time','Code','Duration','Amplitude'});
            testCase.verifyEqual(m.Time, [10;25]);
            testCase.verifyEqual(m.Code, [49;51]);
            testCase.verifyEqual(m.Duration, [0;0]);   % default
            testCase.verifyEqual(m.Amplitude, [1;1]);  % default
        end

        function testNormalizeThreeColumn(testCase)
            m = pf2_base.normalizeMarkers([10 49 5; 25 51 7]);
            testCase.verifyEqual(m.Duration, [5;7]);
            testCase.verifyEqual(m.Amplitude, [1;1]);
        end

        function testNormalizeEmptyIsZeroRowTable(testCase)
            m = pf2_base.normalizeMarkers([]);
            testCase.verifyTrue(istable(m));
            testCase.verifyEqual(height(m), 0);
            testCase.verifyEqual(width(m), 4);
            testCase.verifyTrue(isempty(m));
        end

        function testNormalizeIsIdempotent(testCase)
            m1 = pf2_base.normalizeMarkers([10 49 5 2; 25 51 7 3]);
            m2 = pf2_base.normalizeMarkers(m1);
            testCase.verifyEqual(m2, m1);
        end

        function testNormalizeExtraNumericColumns(testCase)
            m = pf2_base.normalizeMarkers([1 2 3 4 99; 5 6 7 8 100]);
            testCase.verifyTrue(ismember('Data5', m.Properties.VariableNames));
            testCase.verifyEqual(m.Data5, [99;100]);
        end

        function testNormalizeSynonymRemap(testCase)
            T = table([1;2], [9;8], 'VariableNames', {'onset','value'});
            m = pf2_base.normalizeMarkers(T);
            testCase.verifyEqual(m.Time, [1;2]);
            testCase.verifyEqual(m.Code, [9;8]);
            testCase.verifyEqual(m.Amplitude, [1;1]);
        end

        function testNormalizePreservesExtraTableVars(testCase)
            T = pf2_base.normalizeMarkers([10 1; 20 2]);
            T.RT = [0.5;0.7];
            T.Label = ["go";"stop"];
            m = pf2_base.normalizeMarkers(T);
            testCase.verifyTrue(all(ismember({'RT','Label'}, m.Properties.VariableNames)));
            testCase.verifyEqual(m.RT, [0.5;0.7]);
            testCase.verifyEqual(m.Label, ["go";"stop"]);
        end

        function testNormalizeBadTypeErrors(testCase)
            testCase.verifyError(@() pf2_base.normalizeMarkers(struct('a',1)), ...
                'pf2:normalizeMarkers:badType');
        end

        function testNormalizeTextCodedColumnsParseByValue(testCase)
            % char-matrix and cellstr code columns parse by value, not codepoint
            Tc = table({'10';'25'}, {'49';'50'}, 'VariableNames', {'Time','Code'});
            nc = pf2_base.normalizeMarkers(Tc);
            testCase.verifyEqual(nc.Code, [49;50]);
            testCase.verifyEqual(nc.Time, [10;25]);
            Tch = table(['10';'25'], ['49';'50'], 'VariableNames', {'Time','Code'});
            nch = pf2_base.normalizeMarkers(Tch);
            testCase.verifyEqual(nch.Code, [49;50]);
        end

        function testNormalizeEmptyTableKeepsExtraSchema(testCase)
            % A fully-filtered (0-row) table keeps its extra-column schema
            T = pf2_base.normalizeMarkers([10 1; 20 2]);
            T.RT = [0.5; 0.7];
            T(:, :) = [];                 % delete all rows -> 0-row table
            m = pf2_base.normalizeMarkers(T);
            testCase.verifyEqual(height(m), 0);
            testCase.verifyTrue(ismember('RT', m.Properties.VariableNames), ...
                'extra-column schema lost on a 0-row table');
        end

        %% --- markersToArray -----------------------------------------------

        function testMarkersToArrayRoundtrip(testCase)
            arr0 = [10 49 5 1; 25 51 7 1];
            m = pf2_base.normalizeMarkers(arr0);
            arr = pf2_base.markersToArray(m);
            testCase.verifyEqual(arr, arr0);
        end

        function testMarkersToArrayEmpty(testCase)
            testCase.verifyEqual(pf2_base.markersToArray([]), zeros(0,4));
            testCase.verifyEqual(pf2_base.markersToArray(pf2_base.normalizeMarkers([])), zeros(0,4));
        end

        function testMarkersToArrayDropsNonNumericExtras(testCase)
            m = pf2_base.normalizeMarkers([10 1; 20 2]);
            m.Label = ["a";"b"];
            arr = pf2_base.markersToArray(m);
            testCase.verifyEqual(arr, [10 1 0 1; 20 2 0 1]);
        end

        function testMarkersToArrayBadTypeErrors(testCase)
            testCase.verifyError(@() pf2_base.markersToArray(struct('a',1)), ...
                'pf2:normalizeMarkers:badType');
        end

        function testMarkersToArrayKeepsNumericExtras(testCase)
            % An all-numeric table keeps its extra columns (Data5..)
            m = pf2_base.normalizeMarkers([1 2 3 4 99; 5 6 7 8 100]);
            arr = pf2_base.markersToArray(m);
            testCase.verifyEqual(arr, [1 2 3 4 99; 5 6 7 8 100]);
        end

        function testMarkersToArrayKeepsNumericExtraDespiteTextExtra(testCase)
            % Regression: a numeric extra must survive even when a non-numeric
            % (categorical/text) extra is also present (per-column selection).
            m = pf2_base.normalizeMarkers([10 1; 20 2]);
            m.GameScore = [100; 250];                 % numeric extra
            m.Label = categorical(["go";"stop"]);     % non-numeric extra
            arr = pf2_base.markersToArray(m);
            testCase.verifyEqual(arr, [10 1 0 1 100; 20 2 0 1 250]);
        end

        %% --- mergeMarkers -------------------------------------------------

        function testMergeUnionsColumns(testCase)
            a = pf2_base.normalizeMarkers([10 1; 20 2]);
            a.RT = [0.5;0.7];
            b = pf2_base.normalizeMarkers([30 3; 40 4]);
            T = pf2_base.mergeMarkers(a, b);
            testCase.verifyEqual(height(T), 4);
            testCase.verifyTrue(ismember('RT', T.Properties.VariableNames));
            testCase.verifyEqual(T.RT(1:2), [0.5;0.7]);
            testCase.verifyTrue(all(isnan(T.RT(3:4))));   % filled
        end

        function testMergeEmptySide(testCase)
            a = pf2_base.normalizeMarkers([10 1; 20 2]);
            a.RT = [0.5;0.7];
            T = pf2_base.mergeMarkers(a, pf2_base.normalizeMarkers([]));
            testCase.verifyEqual(height(T), 2);
            testCase.verifyTrue(ismember('RT', T.Properties.VariableNames));
        end

        function testMergeFillsNonNumericExtraTypes(testCase)
            % categorical/datetime/duration extras on one side are filled with
            % a type-appropriate blank on the other.
            a = pf2_base.normalizeMarkers([10 1; 20 2]);
            a.Cat = categorical(["x";"y"]);
            a.When = datetime(2020,1,[1;2]);
            a.Dur = seconds([1;2]);
            b = pf2_base.normalizeMarkers([30 3]);
            T = pf2_base.mergeMarkers(a, b);
            testCase.verifyTrue(iscategorical(T.Cat) && isundefined(T.Cat(3)));
            testCase.verifyTrue(isdatetime(T.When) && isnat(T.When(3)));
            testCase.verifyTrue(isduration(T.Dur) && isnan(T.Dur(3)));
        end

        %% --- preprocessing / splicing preserves extra columns ------------

        function testPreprocessingPreservesExtraColumns(testCase)
            data = pf2.import.sampleData();             % markers present (table)
            testCase.assumeTrue(istable(data.markers) && height(data.markers) > 0, ...
                'sample data has no markers');

            n = height(data.markers);
            m = data.markers;
            m.RT = (1:n)' * 0.01;
            m.Label = repmat("go", n, 1);
            data.markers = m;
            hasExtra = @(t) istable(t) && all(ismember({'RT','Label'}, t.Properties.VariableNames));

            % setT0 keeps extras, shifts only Time
            d1 = pf2.data.setT0(data, 5);
            testCase.verifyTrue(hasExtra(d1.markers), 'setT0 dropped extra columns');
            testCase.verifyEqual(d1.markers.RT, data.markers.RT, 'setT0 altered extra column');

            % split keeps extras
            tmid = min(data.time) + (max(data.time) - min(data.time)) / 2;
            d2 = pf2.data.split(data, min(data.time), tmid);
            testCase.verifyTrue(hasExtra(d2.markers), 'split dropped extra columns');

            % processing keeps extras through to output
            proc = processFNIRS2(data);
            testCase.verifyTrue(hasExtra(proc.markers), 'processing dropped extra columns');
        end

        function testProcessedMarkersAreTable(testCase)
            data = pf2.import.sampleData();
            proc = processFNIRS2(data);
            testCase.verifyTrue(istable(proc.markers), 'processed markers should be a table');
        end

        function testExtractBlocksPreservesExtraColumns(testCase)
            data = pf2.import.sampleData();
            testCase.assumeTrue(istable(data.markers) && height(data.markers) > 0, ...
                'sample data has no markers');
            codes = unique(data.markers.Code);
            codes = codes(~isnan(codes));
            data.markers.RT = (1:height(data.markers))' * 0.01;

            proc = processFNIRS2(data);
            blocks = pf2.data.defineBlocks(proc, codes(1), 5, 'Embed', false);
            segs = pf2.data.extractBlocks(proc, blocks, ...
                'PreTime', 2, 'PostTime', 4, 'SetT0', true);
            testCase.assumeTrue(~isempty(segs), 'no segments extracted');
            seg = segs{1};
            testCase.verifyTrue(ismember('RT', seg.markers.Properties.VariableNames), ...
                'extractBlocks dropped the extra marker column');
        end

        function testConcatenateHorizontalUnionsMarkerColumns(testCase)
            data = pf2.import.sampleData();
            testCase.assumeTrue(istable(data.markers) && height(data.markers) > 0, ...
                'sample data has no markers');
            tmid = min(data.time) + (max(data.time) - min(data.time)) / 2;
            h1 = pf2.data.split(data, min(data.time), tmid);
            h2 = pf2.data.split(data, tmid, max(data.time));
            h1.markers.Extra = ones(height(h1.markers), 1);  % column on one side
            cc = pf2.data.concatenateHorizontal({h1, h2});
            testCase.verifyTrue(ismember('Extra', cc.markers.Properties.VariableNames), ...
                'concatenateHorizontal did not union marker columns');
        end

        %% --- arbitrary attribute columns ---------------------------------

        function testArbitraryAttributeTypesAndNames(testCase)
            % Markers should house arbitrary user attributes of any type/name
            % without loss, and the synonym matcher must not hijack them.
            m = pf2_base.normalizeMarkers([10 1; 20 2; 30 3]);
            m.isDeviceMarker = [true; false; true];     % logical
            m.GameScore      = [100; 250; 75];          % numeric
            m.Note           = ["a"; "b"; "c"];         % string

            r = pf2_base.normalizeMarkers(m);           % re-normalize
            testCase.verifyTrue(islogical(r.isDeviceMarker), 'logical type lost');
            testCase.verifyEqual(r.GameScore, [100;250;75]);
            testCase.verifyEqual(r.Note, ["a";"b";"c"]);
            % canonical fields untouched (not hijacked by GameScore/isDeviceMarker)
            testCase.verifyEqual(r.Code, [1;2;3]);
            testCase.verifyEqual(r.Time, [10;20;30]);
            % canonical fields stay first, extras retained after
            testCase.verifyEqual(r.Properties.VariableNames(1:4), ...
                {'Time','Code','Duration','Amplitude'});
            testCase.verifyTrue(all(ismember( ...
                {'isDeviceMarker','GameScore','Note'}, r.Properties.VariableNames)));
        end

        function testSnirfRoundtripPreservesNumericExtraValues(testCase)
            % Numeric/logical extra column VALUES survive a SNIRF round-trip,
            % and a text column does not crash the export. (Extra-column NAMES
            % are not guaranteed through SNIRF: the jsnirfy library flattens
            % stim dataLabels, so names round-trip in-memory but not on disk.)
            data = pf2.import.sampleData();
            testCase.assumeTrue(istable(data.markers) && height(data.markers) > 0, ...
                'sample data has no markers');
            n = height(data.markers);
            data.markers.GameScore = (1:n)';
            data.markers.Note = repmat("x", n, 1);   % text: must not crash export

            tmp = [tempname '.snirf'];
            cleanup = onCleanup(@() deleteIfExists(tmp)); %#ok<NASGU>
            pf2.export.asSNIRF(data, tmp);
            re = pf2.import.importSNIRF(tmp);

            testCase.verifyTrue(istable(re.markers));
            % GameScore values should appear in some numeric extra column
            extraVars = setdiff(re.markers.Properties.VariableNames, ...
                {'Time','Code','Duration','Amplitude'});
            found = false;
            for v = 1:numel(extraVars)
                col = re.markers.(extraVars{v});
                if isnumeric(col) && isequal(sort(col), sort((1:n)'))
                    found = true; break;
                end
            end
            testCase.verifyTrue(found, 'GameScore values lost on SNIRF round-trip');
        end

        function testAsNirRoundtripPreservesMarkers(testCase)
            % asNIR/importNIR on-disk round-trip keeps markers a canonical
            % table with the same Code/Time values (not just a .mrk file).
            data = pf2.import.sampleData();
            testCase.assumeTrue(istable(data.markers) && height(data.markers) > 0, ...
                'sample data has no markers');
            tmp = [tempname '.nir'];
            cleanup = onCleanup(@() deleteNirSet(tmp)); %#ok<NASGU>
            pf2.export.asNIR(data, tmp);
            re = pf2.import.importNIR(tmp);   % GUI suppressed under test
            testCase.verifyTrue(istable(re.markers));
            testCase.verifyEqual(re.markers.Properties.VariableNames(1:4), ...
                {'Time','Code','Duration','Amplitude'});
            testCase.verifyEqual(sort(re.markers.Code), sort(data.markers.Code), ...
                'marker codes lost on NIR round-trip');
        end

        function testSnirfTwoColumnStimReadsCodeFromCol2(testCase)
            % Legacy fNIR [time, code] arriving as a 2-column SNIRF stim block
            % (no dataLabels): column 2 must be read as the marker Code, not
            % duration, with a warning.
            data = pf2.import.sampleData();
            testCase.assumeTrue(istable(data.markers) && height(data.markers) > 0, ...
                'sample data has no markers');

            tmp = [tempname '.snirf'];
            cleanup = onCleanup(@() deleteIfExists(tmp)); %#ok<NASGU>
            pf2.export.asSNIRF(data, tmp);
            raw = pf2_base.external.jsnirfy.loadsnirf(tmp);

            % Force the first stim block to 2-column [time, code], strip labels
            s = raw.nirs.stim;
            if numel(s) > 1; s = s(1); end
            codeVal = s.data(1, 3);
            s.data = [s.data(:,1), repmat(codeVal, size(s.data,1), 1)];
            if isfield(s, 'dataLabels'); s = rmfield(s, 'dataLabels'); end
            raw.nirs.stim = s;

            tmp2 = [tempname '.snirf'];
            cleanup2 = onCleanup(@() deleteIfExists(tmp2)); %#ok<NASGU>
            pf2_base.external.jsnirfy.savesnirf(raw, tmp2);

            re = testCase.verifyWarning(@() pf2.import.importSNIRF(tmp2), ...
                'pf2:importSNIRF:twoColumnStim');
            testCase.verifyTrue(ismember(codeVal, re.markers.Code), ...
                'column 2 not read as marker code');
            testCase.verifyTrue(all(re.markers.Duration == 0), ...
                'duration should be zero for a 2-column stim block');
        end

        %% --- categorical labels on codes ---------------------------------

        function testLabelMarkersExplicitMap(testCase)
            d.markers = pf2_base.normalizeMarkers([10 49; 20 50; 30 49; 40 99]);
            d = pf2.data.labelMarkers(d, {49,'Stroop'; 50,'Control'});
            testCase.verifyTrue(iscategorical(d.markers.Label));
            testCase.verifyEqual(string(d.markers.Label(1)), "Stroop");
            testCase.verifyEqual(string(d.markers.Label(2)), "Control");
            testCase.verifyEqual(string(d.markers.Label(3)), "Stroop");
            testCase.verifyTrue(ismissing(d.markers.Label(4)));  % code 99 unmapped
        end

        function testLabelMarkersFromEventTypes(testCase)
            d.markers = pf2_base.normalizeMarkers([10 1; 20 2]);
            d.info.eventTypes = {1,'Go'; 2,'Stop'};
            d = pf2.data.labelMarkers(d);   % no map -> use eventTypes
            testCase.verifyEqual(string(d.markers.Label), ["Go";"Stop"]);
        end

        function testLabelMarkersCustomVarNameAndOrdinal(testCase)
            d.markers = pf2_base.normalizeMarkers([10 1; 20 2; 30 3]);
            d = pf2.data.labelMarkers(d, {1,'Low';2,'Med';3,'High'}, ...
                'VarName','Difficulty', 'Ordinal', true);
            testCase.verifyTrue(ismember('Difficulty', d.markers.Properties.VariableNames));
            testCase.verifyTrue(isordinal(d.markers.Difficulty));
            testCase.verifyTrue(d.markers.Difficulty(1) < d.markers.Difficulty(3));
        end

        function testLabelColumnSurvivesPreprocessing(testCase)
            data = pf2.import.sampleData();
            testCase.assumeTrue(istable(data.markers) && height(data.markers) > 0, ...
                'sample data has no markers');
            codes = unique(data.markers.Code);
            map = [num2cell(codes), compose('cond%d', codes)];
            data = pf2.data.labelMarkers(data, map);
            proc = processFNIRS2(data);
            testCase.verifyTrue(ismember('Label', proc.markers.Properties.VariableNames), ...
                'categorical Label dropped during processing');
            testCase.verifyTrue(iscategorical(proc.markers.Label));
        end

    end
end

function deleteIfExists(f)
    if exist(f, 'file'); delete(f); end
end

function deleteNirSet(nirPath)
    % Remove a .nir and its companion sidecars from an asNIR export.
    [p, n] = fileparts(nirPath);
    base = fullfile(p, n);
    for ext = {'.nir', '.mrk', '.log', '_CH.mat'}
        deleteIfExists([base ext{1}]);
    end
end
