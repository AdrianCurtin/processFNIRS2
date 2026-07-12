classdef MontageExportTest < matlab.unittest.TestCase
    % MONTAGEEXPORTTEST Unit tests for pf2.probe.montage
    %
    % Tests the portable montage descriptor: per-channel table structure,
    % montage-level descriptor fields, Brodmann toggling, config-name and
    % data-struct inputs, and JSON/CSV serialization with roundtrip decode.
    %
    % Run all tests:
    %   results = runtests('pf2_base.tests.unit.MontageExportTest');
    %
    % See also: pf2.probe.montage, pf2.Device, pf2.probe.nearestBrodmann

    properties
        data   % fNIRS sample data with MNI coordinates
    end

    methods (TestClassSetup)
        function loadSampleData(testCase)
            testCase.data = pf2.import.sampleData.fNIR2000();
        end
    end

    methods (Test)
        function testTableStructure(testCase)
            [tbl, desc] = pf2.probe.montage(testCase.data);
            nCh = pf2.Device.load(testCase.data).nChannels;
            testCase.verifyEqual(height(tbl), nCh);
            base = {'Channel', 'Source', 'Detector', 'X_mni', 'Y_mni', 'Z_mni', ...
                    'SD_mm', 'ShortSep'};
            testCase.verifyTrue(all(ismember(base, tbl.Properties.VariableNames)));
            testCase.verifyEqual(tbl.Channel, (1:nCh)');
            % descriptor sanity
            testCase.verifyEqual(desc.device.nChannels, nCh);
            testCase.verifyEqual(desc.formatVersion, '1.0');
            testCase.verifyNotEmpty(desc.wavelengths);
            testCase.verifyEqual(numel(desc.channels), nCh);
        end

        function testBrodmannColumns(testCase)
            % fNIR2000 has MNI, so BA columns appear by default
            tbl = pf2.probe.montage(testCase.data);
            testCase.verifyTrue(ismember('BA', tbl.Properties.VariableNames));
            testCase.verifyTrue(ismember('BA_name', tbl.Properties.VariableNames));
        end

        function testBrodmannOff(testCase)
            tbl = pf2.probe.montage(testCase.data, 'Brodmann', false);
            testCase.verifyFalse(ismember('BA', tbl.Properties.VariableNames));
            % Channel, Source, Detector, X/Y/Z_mni, SD_mm, ShortSep
            testCase.verifyEqual(width(tbl), 8);
        end

        function testSourceDetectorColumns(testCase)
            tbl = pf2.probe.montage(testCase.data, 'Brodmann', false);
            testCase.verifyTrue(all(ismember({'Source', 'Detector'}, ...
                tbl.Properties.VariableNames)));
            % fNIR2000 carries optode indices, so they should be populated
            testCase.verifyTrue(any(~isnan(tbl.Source)));
            testCase.verifyTrue(any(~isnan(tbl.Detector)));
        end

        function testDataContext(testCase)
            % Processed input -> units/DPF context populated in the descriptor
            proc = processFNIRS2(testCase.data);
            [~, desc] = pf2.probe.montage(proc, 'Brodmann', false);
            testCase.verifyTrue(isfield(desc, 'data'));
            testCase.verifyNotEmpty(desc.data.units);
            % Raw (non-processed) input -> data context empty
            [~, descRaw] = pf2.probe.montage(testCase.data, 'Brodmann', false);
            testCase.verifyEmpty(descRaw.data.units);
        end

        function testConfigNameInput(testCase)
            tbl = pf2.probe.montage('fNIR_Devices_fNIR1000.cfg', 'Brodmann', false);
            testCase.verifyEqual(height(tbl), 16);
        end

        function testDeviceObjectInput(testCase)
            dev = pf2.Device.load(testCase.data);
            tbl = pf2.probe.montage(dev, 'Brodmann', false);
            testCase.verifyEqual(height(tbl), dev.nChannels);
        end

        function testJSONRoundtrip(testCase)
            jp = fullfile(tempdir, 'pf2_montage_test.json');
            if exist(jp, 'file'); delete(jp); end
            [~, desc] = pf2.probe.montage(testCase.data, 'SavePath', jp);
            testCase.verifyEqual(exist(jp, 'file'), 2);
            decoded = jsondecode(fileread(jp));
            testCase.verifyEqual(decoded.device.nChannels, desc.device.nChannels);
            testCase.verifyEqual(numel(decoded.channels), numel(desc.channels));
            delete(jp);
        end

        function testCSVExport(testCase)
            cp = fullfile(tempdir, 'pf2_montage_test.csv');
            if exist(cp, 'file'); delete(cp); end
            pf2.probe.montage(testCase.data, 'SavePath', cp);
            testCase.verifyEqual(exist(cp, 'file'), 2);
            back = readtable(cp);
            testCase.verifyEqual(height(back), pf2.Device.load(testCase.data).nChannels);
            delete(cp);
        end

        function testBadExtension(testCase)
            bp = fullfile(tempdir, 'pf2_montage_test.bogus');
            testCase.verifyError(@() pf2.probe.montage(testCase.data, 'SavePath', bp), ...
                'pf2:probe:montage:badExtension');
        end

        function testCoordinateSystemBlock(testCase)
            [~, desc] = pf2.probe.montage(testCase.data);
            cs = desc.coordinateSystem;
            for fn = {'system', 'units', 'referenceHead', 'provenance', ...
                      'registrationMethod', 'hasMNI'}
                testCase.verifyTrue(isfield(cs, fn{1}), ...
                    sprintf('coordinateSystem missing field %s', fn{1}));
            end
            testCase.verifyTrue(cs.hasMNI);   % fNIR2000 has MNI
        end

        function testJSONChannelPayload(testCase)
            % Deep roundtrip: per-channel payload survives JSON encode/decode
            jp = fullfile(tempdir, 'pf2_montage_payload.json');
            if exist(jp, 'file'); delete(jp); end
            pf2.probe.montage(testCase.data, 'SavePath', jp);
            decoded = jsondecode(fileread(jp));
            ch1 = decoded.channels(1);
            testCase.verifyEqual(ch1.channel, 1);
            testCase.verifyEqual(numel(ch1.mni), 3);
            testCase.verifyTrue(all(isfield(ch1, {'sd_mm', 'shortSep', ...
                'source', 'detector', 'wavelengths'})));
            testCase.verifyTrue(isfield(decoded.coordinateSystem, 'provenance'));
            delete(jp);
        end

        function testBadInput(testCase)
            testCase.verifyError(@() pf2.probe.montage(42), ...
                'pf2:probe:montage:badInput');
        end
    end
end
