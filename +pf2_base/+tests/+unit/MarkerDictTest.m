classdef MarkerDictTest < matlab.unittest.TestCase
    % MARKERDICTTEST Unit tests for the per-dataset marker dictionary
    %
    % Verifies the canonical code->label dictionary: normalization from
    % multiple source forms, get/set/merge accessors, integration with
    % labelMarkers and defineBlocks, population at import, and survival
    % through processing.

    methods (TestClassSetup)
        function suppressChannelCheckGUI(testCase)
            % Ensure the interactive channel-check GUI never opens during
            % automated testing (these tests import sample recordings).
            prev = pf2_base.channelCheckGUIEnabled(false);
            testCase.addTeardown(@() pf2_base.channelCheckGUIEnabled(prev));
        end
    end

    methods (Test)

        %% --- normalizeMarkerDict ------------------------------------------

        function testNormalizeFromCellDedupes(testCase)
            d = pf2_base.normalizeMarkerDict({49,'Stroop'; 50,'Control'; 49,'Dup'});
            testCase.verifyEqual(d.Properties.VariableNames, {'Code','Label'});
            testCase.verifyEqual(height(d), 2);            % deduped by Code
            testCase.verifyEqual(d.Code, [49;50]);
            testCase.verifyEqual(d.Label(1), "Stroop");    % first wins
        end

        function testNormalizeFromTableSynonymsAndAttrs(testCase)
            T = table([1;2], ["a";"b"], [true;false], ...
                'VariableNames', {'value','name','isDeviceMarker'});
            d = pf2_base.normalizeMarkerDict(T);
            testCase.verifyEqual(d.Code, [1;2]);           % value -> Code
            testCase.verifyEqual(d.Label, ["a";"b"]);      % name  -> Label
            testCase.verifyTrue(ismember('isDeviceMarker', d.Properties.VariableNames));
            testCase.verifyTrue(islogical(d.isDeviceMarker));
        end

        function testNormalizeFromMap(testCase)
            d = pf2_base.normalizeMarkerDict(containers.Map({10,20}, {'x','y'}));
            testCase.verifyEqual(height(d), 2);
            testCase.verifyTrue(all(ismember([10;20], d.Code)));
        end

        function testNormalizeEmpty(testCase)
            d = pf2_base.normalizeMarkerDict([]);
            testCase.verifyEqual(height(d), 0);
            testCase.verifyEqual(d.Properties.VariableNames, {'Code','Label'});
        end

        %% --- merge --------------------------------------------------------

        function testMergeFirstWinsUnionColumns(testCase)
            a = pf2_base.normalizeMarkerDict({1,'A'; 2,'B'});
            a.Color = ["red";"blue"];
            b = pf2_base.normalizeMarkerDict({2,'OTHER'; 3,'C'});
            d = pf2_base.mergeMarkerDict(a, b);
            testCase.verifyEqual(sort(d.Code), [1;2;3]);
            testCase.verifyEqual(d.Label(d.Code==2), "B");  % a wins on conflict
            testCase.verifyTrue(ismember('Color', d.Properties.VariableNames));
            testCase.verifyTrue(ismissing(d.Color(d.Code==3))); % filled for b-only row
        end

        %% --- get/set on a dataset ----------------------------------------

        function testSetGetRoundtrip(testCase)
            d.markers = pf2_base.normalizeMarkers([10 1; 20 2]);
            d = pf2.data.setMarkerDict(d, {1,'Go'; 2,'Stop'});
            got = pf2.data.getMarkerDict(d);
            testCase.verifyEqual(got.Label(got.Code==1), "Go");
            testCase.verifyEqual(d.info.markerDict.Label(2), "Stop");
        end

        function testSetMergeNewWins(testCase)
            d.markers = pf2_base.normalizeMarkers([10 1; 20 2]);
            d = pf2.data.setMarkerDict(d, {1,'Go'; 2,'Stop'});
            d = pf2.data.setMarkerDict(d, {1,'GO2'}, 'Merge', true);
            got = pf2.data.getMarkerDict(d);
            testCase.verifyEqual(got.Label(got.Code==1), "GO2");  % new wins
            testCase.verifyEqual(got.Label(got.Code==2), "Stop"); % kept
        end

        function testSetReplace(testCase)
            d.markers = pf2_base.normalizeMarkers([10 1; 20 2]);
            d = pf2.data.setMarkerDict(d, {1,'Go'; 2,'Stop'});
            d = pf2.data.setMarkerDict(d, {1,'Only'}, 'Merge', false);
            testCase.verifyEqual(height(d.info.markerDict), 1);
        end

        function testGetFallsBackToEventTypes(testCase)
            d.markers = pf2_base.normalizeMarkers([10 1; 20 2]);
            d.info.eventTypes = {1,'Go'; 2,'Stop'};
            got = pf2.data.getMarkerDict(d);
            testCase.verifyEqual(got.Label(got.Code==2), "Stop");
        end

        function testGetDerivesFromCodes(testCase)
            d.markers = pf2_base.normalizeMarkers([10 7; 20 8; 30 7]);
            got = pf2.data.getMarkerDict(d);
            testCase.verifyEqual(sort(got.Code), [7;8]);
            testCase.verifyTrue(all(ismissing(got.Label)));
        end

        %% --- integration --------------------------------------------------

        function testLabelMarkersUsesDict(testCase)
            d.markers = pf2_base.normalizeMarkers([10 1; 20 2]);
            d = pf2.data.setMarkerDict(d, {1,'Go'; 2,'Stop'});
            d = pf2.data.labelMarkers(d);    % no explicit map -> dict
            testCase.verifyEqual(string(d.markers.Label), ["Go";"Stop"]);
        end

        function testDefineBlocksAutoLabelsFromDict(testCase)
            d.markers = pf2_base.normalizeMarkers([10 1; 20 2; 30 1]);
            d = pf2.data.setMarkerDict(d, {1,'Stroop'; 2,'Control'});
            blocks = pf2.data.defineBlocks(d, 1, 5, 'Embed', false);
            testCase.verifyEqual(numel(blocks), 2);
            testCase.verifyEqual(blocks(1).info.Condition, 'Stroop');
        end

        function testDictSurvivesProcessing(testCase)
            data = pf2.import.sampleData();
            testCase.assumeTrue(istable(data.markers) && height(data.markers) > 0, ...
                'sample data has no markers');
            codes = unique(data.markers.Code);
            data = pf2.data.setMarkerDict(data, [num2cell(codes), compose('c%d', codes)]);
            proc = processFNIRS2(data);
            testCase.verifyTrue(isfield(proc.info, 'markerDict'));
            testCase.verifyEqual(height(proc.info.markerDict), numel(codes));
        end

        function testCellArrayUnionAndBroadcast(testCase)
            a.markers = pf2_base.normalizeMarkers([10 1]);
            b.markers = pf2_base.normalizeMarkers([10 2]);
            allData = pf2.data.setMarkerDict({a, b}, {1,'A'; 2,'B'});
            dict = pf2.data.getMarkerDict(allData);   % union across elements
            testCase.verifyTrue(all(ismember([1;2], dict.Code)));
        end

        %% --- normalizeMarkerDict edge cases / errors ----------------------

        function testNormalizeDictBadCellErrors(testCase)
            testCase.verifyError(@() pf2_base.normalizeMarkerDict({1; 2}), ...
                'pf2:normalizeMarkerDict:badCell');
        end

        function testNormalizeDictBadTypeErrors(testCase)
            testCase.verifyError(@() pf2_base.normalizeMarkerDict([1 2; 3 4]), ...
                'pf2:normalizeMarkerDict:badType');
        end

        function testNormalizeDictDropsNaNCode(testCase)
            d = pf2_base.normalizeMarkerDict({1,'A'; NaN,'B'; 2,'C'});
            testCase.verifyEqual(sort(d.Code), [1;2]);   % NaN-coded row dropped
        end

        function testNormalizeDictStringCodes(testCase)
            % Text-typed codes parse by value, not codepoint
            dCell = pf2_base.normalizeMarkerDict({'49','Stroop'; '50','Control'});
            testCase.verifyEqual(dCell.Code, [49;50]);
            T = table(["49";"50"], ["Stroop";"Control"], ...
                'VariableNames', {'Code','Label'});
            dTbl = pf2_base.normalizeMarkerDict(T);
            testCase.verifyEqual(dTbl.Code, [49;50]);
        end

        function testMergeDictCategoricalAttrFill(testCase)
            a = pf2_base.normalizeMarkerDict({1,'A'; 2,'B'});
            a.Cat = categorical(["lo";"hi"]);
            b = pf2_base.normalizeMarkerDict({3,'C'});
            d = pf2_base.mergeMarkerDict(a, b);
            testCase.verifyTrue(iscategorical(d.Cat));
            testCase.verifyTrue(isundefined(d.Cat(d.Code==3)));  % filled blank
        end

        function testMergeDictDatetimeAndDurationAttrFill(testCase)
            % datetime/duration attribute columns on one side must be filled
            % with a type-appropriate blank on the other (not coerced to NaN,
            % which would error on vertcat).
            a = pf2_base.normalizeMarkerDict({1,'A'; 2,'B'});
            a.When = datetime(2020,1,[1;2]);
            a.Dur  = seconds([1;2]);
            b = pf2_base.normalizeMarkerDict({3,'C'});
            d = pf2_base.mergeMarkerDict(a, b);
            testCase.verifyTrue(isdatetime(d.When) && isnat(d.When(d.Code==3)));
            testCase.verifyTrue(isduration(d.Dur) && isnan(d.Dur(d.Code==3)));
        end

        function testGetCellUnionFirstElementWins(testCase)
            % getMarkerDict on a cell array unions dicts; on a Code conflict
            % the earlier element wins.
            a.markers = pf2_base.normalizeMarkers([10 1]);
            a.info.markerDict = pf2_base.normalizeMarkerDict({1,'FromA'});
            b.markers = pf2_base.normalizeMarkers([10 1]);
            b.info.markerDict = pf2_base.normalizeMarkerDict({1,'FromB'});
            dict = pf2.data.getMarkerDict({a, b});
            testCase.verifyEqual(dict.Label(dict.Code==1), "FromA");
        end

        %% --- get/set source priority & error paths -----------------------

        function testGetPriorityMarkerDictOverEventTypes(testCase)
            d.markers = pf2_base.normalizeMarkers([10 1]);
            d.info.eventTypes = {1,'FromEvents'};
            d.info.markerDict = pf2_base.normalizeMarkerDict({1,'FromDict'});
            got = pf2.data.getMarkerDict(d);
            testCase.verifyEqual(got.Label(got.Code==1), "FromDict"); % dict wins
        end

        function testGetUsesCOBILogInfoMarkerDict(testCase)
            d.markers = pf2_base.normalizeMarkers([10 5; 20 6]);
            d.info.log_info.MarkerDict = {5,'Tap'; 6,'Rest'};
            got = pf2.data.getMarkerDict(d);
            testCase.verifyEqual(got.Label(got.Code==5), "Tap");
        end

        function testGetMarkerDictBadInputErrors(testCase)
            testCase.verifyError(@() pf2.data.getMarkerDict(42), ...
                'pf2:getMarkerDict:badInput');
        end

        function testSetMarkerDictBadInputErrors(testCase)
            testCase.verifyError(@() pf2.data.setMarkerDict(42, {1,'A'}), ...
                'pf2:setMarkerDict:badInput');
        end

        %% --- labelMarkers options & error paths --------------------------

        function testLabelMarkersCategoriesParam(testCase)
            d.markers = pf2_base.normalizeMarkers([10 1; 20 2]);
            d = pf2.data.labelMarkers(d, {1,'A'; 2,'B'}, ...
                'Categories', {'B','A','C'});
            testCase.verifyEqual(categories(d.markers.Label), {'B';'A';'C'});
        end

        function testLabelMarkersEmptyMarkers(testCase)
            d.markers = pf2_base.normalizeMarkers([]);
            d = pf2.data.labelMarkers(d, {1,'A'});   % must not error
            testCase.verifyTrue(iscategorical(d.markers.Label));
            testCase.verifyEqual(height(d.markers), 0);
        end

        function testLabelMarkersTableNoMapErrors(testCase)
            mt = pf2_base.normalizeMarkers([10 1; 20 2]);
            testCase.verifyError(@() pf2.data.labelMarkers(mt), ...
                'pf2:labelMarkers:noMap');
        end

        function testLabelMarkersBadInputErrors(testCase)
            testCase.verifyError(@() pf2.data.labelMarkers(42, {1,'A'}), ...
                'pf2:labelMarkers:badInput');
        end

        %% --- dictionary survives a SNIRF disk round-trip -----------------

        function testSnirfDictRoundtrip(testCase)
            data = pf2.import.sampleData();
            testCase.assumeTrue(istable(data.markers) && height(data.markers) > 0, ...
                'sample data has no markers');
            codes = unique(data.markers.Code);
            codes = codes(~isnan(codes));
            c1 = codes(1);
            data = pf2.data.setMarkerDict(data, {c1, 'MyCondition'});

            tmp = [tempname '.snirf'];
            cleanup = onCleanup(@() deleteIfExists(tmp)); %#ok<NASGU>
            pf2.export.asSNIRF(data, tmp);
            re = pf2.import.importSNIRF(tmp);

            testCase.verifyTrue(isfield(re.info, 'markerDict'));
            d = re.info.markerDict;
            testCase.verifyEqual(d.Label(d.Code == c1), "MyCondition");
        end

    end
end

function deleteIfExists(f)
    if exist(f, 'file'); delete(f); end
end
