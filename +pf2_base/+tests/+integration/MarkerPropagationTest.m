classdef MarkerPropagationTest < matlab.unittest.TestCase
    % MARKERPROPAGATIONTEST End-to-end propagation of the canonical marker
    % table, a user-appended extra column, and the marker dictionary across
    % the full single-subject path: import -> setT0 -> split -> defineBlocks
    % -> extractBlocks -> SNIRF export/reimport.
    %
    % Complements the focused MarkerTableTest/MarkerDictTest unit tests by
    % chaining the stages so a regression that only appears across stage
    % boundaries (e.g. a dropped column after splicing then exporting) is
    % caught.

    methods (TestClassSetup)
        function suppressChannelCheckGUI(testCase)
            % Ensure the interactive channel-check GUI never opens during
            % automated testing (this test imports a sample recording).
            prev = pf2_base.channelCheckGUIEnabled(false);
            testCase.addTeardown(@() pf2_base.channelCheckGUIEnabled(prev));
        end
    end

    methods (Test)

        function testFullChainPreservesTableExtrasAndDict(testCase)
            data = pf2.import.sampleData();
            testCase.assumeTrue(istable(data.markers) && height(data.markers) > 0, ...
                'sample data has no markers');

            canon = {'Time','Code','Duration','Amplitude'};
            hasCanon = @(t) istable(t) && numel(t.Properties.VariableNames) >= 4 && ...
                isequal(t.Properties.VariableNames(1:4), canon);
            hasRT = @(t) istable(t) && ismember('RT', t.Properties.VariableNames);

            % Append an extra column and a dictionary up front
            codes = unique(data.markers.Code);
            codes = codes(~isnan(codes));
            c1 = codes(1);
            data.markers.RT = (1:height(data.markers))' * 0.01;
            data = pf2.data.setMarkerDict(data, {c1, 'Target'});

            % Stage 1: import (already done) -> canonical + extra present
            testCase.verifyTrue(hasCanon(data.markers), 'import: not canonical');
            testCase.verifyTrue(hasRT(data.markers), 'import: extra column missing');

            % Stage 2: setT0 shifts time, keeps schema + extra
            d = pf2.data.setT0(data, 5);
            testCase.verifyTrue(hasCanon(d.markers), 'setT0: not canonical');
            testCase.verifyTrue(hasRT(d.markers), 'setT0: extra column dropped');

            % Stage 3: split keeps schema + extra
            tmid = min(d.time) + (max(d.time) - min(d.time)) / 2;
            s = pf2.data.split(d, min(d.time), tmid);
            testCase.verifyTrue(hasCanon(s.markers), 'split: not canonical');
            testCase.verifyTrue(hasRT(s.markers), 'split: extra column dropped');

            % Stage 4: process + defineBlocks auto-labels from the dictionary
            proc = processFNIRS2(data);
            testCase.verifyTrue(hasCanon(proc.markers), 'process: not canonical');
            blocks = pf2.data.defineBlocks(proc, c1, 5, 'Embed', false);
            testCase.assumeTrue(~isempty(blocks), 'no blocks defined');
            testCase.verifyEqual(blocks(1).info.Condition, 'Target', ...
                'defineBlocks did not auto-label from the dictionary');

            % Stage 5: SNIRF export/reimport preserves the dictionary label
            tmp = [tempname '.snirf'];
            cleanup = onCleanup(@() deleteIfExists(tmp)); %#ok<NASGU>
            pf2.export.asSNIRF(proc, tmp);
            re = pf2.import.importSNIRF(tmp);
            testCase.verifyTrue(hasCanon(re.markers), 'reimport: not canonical');
            testCase.verifyTrue(isfield(re.info, 'markerDict'), 'reimport: dict missing');
            rd = re.info.markerDict;
            testCase.verifyEqual(rd.Label(rd.Code == c1), "Target", ...
                'dictionary label lost across export/reimport');
        end

    end
end

function deleteIfExists(f)
    if exist(f, 'file'); delete(f); end
end
