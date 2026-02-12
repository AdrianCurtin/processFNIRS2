classdef DeviceTest < matlab.unittest.TestCase
% DEVICETEST Unit tests for pf2.Device value class

    methods (TestMethodSetup)
        function clearDeviceCache(~)
            pf2.Device.clearCache();
        end
    end

    %% Construction and factories

    methods (Test)

        function testLoadByConfigName(testCase)
            dev = pf2.Device.load('fNIR_Devices_fNIR2000');
            testCase.verifyClass(dev, 'pf2.Device');
            testCase.verifyEqual(dev.name, 'fNIR_Devices_fNIR2000');
        end

        function testLoadByConfigNameWithExtension(testCase)
            dev = pf2.Device.load('fNIR_Devices_fNIR2000.cfg');
            testCase.verifyEqual(dev.name, 'fNIR_Devices_fNIR2000');
        end

        function testLoadFromDataStruct(testCase)
            data = pf2.import.sampleData.fNIR2000();
            dev = pf2.Device.load(data);
            testCase.verifyClass(dev, 'pf2.Device');
            % Sample data identifies as 18ch variant
            testCase.verifyTrue(contains(dev.name, 'fNIR'));
            testCase.verifyGreaterThan(dev.nChannels, 0);
        end

        function testFromProbeInfo(testCase)
            probeInfo = pf2_base.loadDeviceCfg('fNIR_Devices_fNIR2000', true, false);
            dev = pf2.Device.fromProbeInfo(probeInfo, 'test_device');
            testCase.verifyClass(dev, 'pf2.Device');
            testCase.verifyEqual(dev.name, 'test_device');
        end

        function testFromProbeInfoDefaultName(testCase)
            probeInfo = pf2_base.loadDeviceCfg('fNIR_Devices_fNIR2000', true, false);
            dev = pf2.Device.fromProbeInfo(probeInfo);
            testCase.verifyEqual(dev.name, 'fNIR_Devices_fNIR2000');
        end

    end

    %% Cache behavior

    methods (Test)

        function testCacheReturnsSameObject(testCase)
            dev1 = pf2.Device.load('fNIR_Devices_fNIR2000');
            dev2 = pf2.Device.load('fNIR_Devices_fNIR2000');
            testCase.verifyEqual(dev1.name, dev2.name);
            testCase.verifyEqual(dev1.nChannels, dev2.nChannels);
        end

        function testClearCacheWorks(testCase)
            dev1 = pf2.Device.load('fNIR_Devices_fNIR2000');
            pf2.Device.clearCache();
            dev2 = pf2.Device.load('fNIR_Devices_fNIR2000');
            % Both should be valid Device objects
            testCase.verifyClass(dev1, 'pf2.Device');
            testCase.verifyClass(dev2, 'pf2.Device');
        end

    end

    %% Immutable properties

    methods (Test)

        function testInfoProperties(testCase)
            dev = pf2.Device.load('fNIR_Devices_fNIR2000');
            testCase.verifyEqual(dev.manufacturer, 'fNIR Devices');
            testCase.verifyEqual(dev.model, 'Model 2000');
            testCase.verifyEqual(dev.defaultFs, 10);
            testCase.verifyEqual(dev.nChannels, 18);
        end

        function testWavelengthSet(testCase)
            dev = pf2.Device.load('fNIR_Devices_fNIR2000');
            testCase.verifyEqual(sort(dev.wavelengthSet), [730, 850]);
        end

        function testImmutability(testCase)
            dev = pf2.Device.load('fNIR_Devices_fNIR2000');
            testCase.verifyError(@() setfield(dev, 'name', 'changed'), ...
                'MATLAB:class:SetProhibited');
        end

    end

    %% Accessor methods

    methods (Test)

        function testWavelengths(testCase)
            dev = pf2.Device.load('fNIR_Devices_fNIR2000');
            wl = dev.wavelengths();
            testCase.verifyTrue(isnumeric(wl));
            testCase.verifyGreaterThan(numel(wl), 0);
            % Should contain both 730 and 850 among valid wavelengths
            validWl = unique(wl(wl > 0 & ~isnan(wl)));
            testCase.verifyTrue(ismember(730, validWl));
            testCase.verifyTrue(ismember(850, validWl));
        end

        function testChannelNumbers(testCase)
            dev = pf2.Device.load('fNIR_Devices_fNIR2000');
            ch = dev.channelNumbers();
            testCase.verifyTrue(isnumeric(ch));
            testCase.verifyGreaterThan(numel(ch), 0);
        end

        function testChannelList(testCase)
            dev = pf2.Device.load('fNIR_Devices_fNIR2000');
            cl = dev.channelList();
            testCase.verifyEqual(numel(cl), 18);
        end

        function testMniPositions(testCase)
            dev = pf2.Device.load('fNIR_Devices_fNIR2000');
            pos = dev.mniPositions();
            testCase.verifySize(pos, [18, 3]);
        end

        function testSdDistances(testCase)
            dev = pf2.Device.load('fNIR_Devices_fNIR2000');
            sd = dev.sdDistances();
            testCase.verifyEqual(numel(sd), 18);
            testCase.verifyTrue(all(sd > 0));
        end

        function testChannelTable(testCase)
            dev = pf2.Device.load('fNIR_Devices_fNIR2000');
            tbl = dev.channelTable();
            testCase.verifyClass(tbl, 'table');
            testCase.verifyTrue(ismember('Wavelength', tbl.Properties.VariableNames));
            testCase.verifyTrue(ismember('OptodeNumber', tbl.Properties.VariableNames));
        end

        function testOptodeTable(testCase)
            dev = pf2.Device.load('fNIR_Devices_fNIR2000');
            tbl = dev.optodeTable();
            testCase.verifyClass(tbl, 'table');
            testCase.verifyTrue(ismember('OptodeNum', tbl.Properties.VariableNames));
        end

        function testLayout2D(testCase)
            dev = pf2.Device.load('fNIR_Devices_fNIR2000');
            lay = dev.layout2D();
            testCase.verifyTrue(iscell(lay));
            testCase.verifyGreaterThan(numel(lay), 0);
        end

        function testHasMNI(testCase)
            dev = pf2.Device.load('fNIR_Devices_fNIR2000');
            testCase.verifyTrue(dev.hasMNI());
        end

        function testIsShortSep(testCase)
            dev = pf2.Device.load('fNIR_Devices_fNIR2000');
            ss = dev.isShortSep();
            testCase.verifyTrue(islogical(ss));
            testCase.verifyEqual(numel(ss), 18);
        end

    end

    %% Backward compatibility

    methods (Test)

        function testProbeInfoHasLegacyFields(testCase)
            dev = pf2.Device.load('fNIR_Devices_fNIR2000');
            testCase.verifyTrue(isfield(dev.probeInfo, 'Info'));
            testCase.verifyTrue(isfield(dev.probeInfo, 'Probe'));
            testCase.verifyTrue(iscell(dev.probeInfo.Probe));
            testCase.verifyTrue(isfield(dev.probeInfo.Probe{1}, 'TableCh'));
        end

    end

    %% Multiple config files load without error

    methods (Test)

        function testLoadFNIR1000(testCase)
            dev = pf2.Device.load('fNIR_Devices_fNIR1000');
            testCase.verifyClass(dev, 'pf2.Device');
            testCase.verifyGreaterThan(dev.nChannels, 0);
        end

        function testLoadFNIR1200(testCase)
            dev = pf2.Device.load('fNIR_Devices_fNIR1200_16ch');
            testCase.verifyClass(dev, 'pf2.Device');
            testCase.verifyGreaterThan(dev.nChannels, 0);
        end

        function testLoadHitachi3x5(testCase)
            dev = pf2.Device.load('Hitachi_ETG4000_3x5');
            testCase.verifyClass(dev, 'pf2.Device');
            testCase.verifyEqual(dev.manufacturer, 'Hitachi');
        end

        function testLoadHitachi3x11(testCase)
            dev = pf2.Device.load('Hitachi_ETG4000_3x11');
            testCase.verifyClass(dev, 'pf2.Device');
            testCase.verifyEqual(dev.manufacturer, 'Hitachi');
        end

        function testLoadNIRXSport16x16(testCase)
            dev = pf2.Device.load('NIRX_Sport_16x16_lw');
            testCase.verifyClass(dev, 'pf2.Device');
            testCase.verifyGreaterThan(dev.nChannels, 0);
        end

        function testLoadMergedProbe(testCase)
            dev = pf2.Device.load('fNIR_Hitachi_3x5_merged');
            testCase.verifyClass(dev, 'pf2.Device');
        end

    end

    %% Error cases

    methods (Test)

        function testErrorOnInvalidConfigName(testCase)
            threw = false;
            try
                pf2.Device.load('nonexistent_device_xyz');
            catch
                threw = true;
            end
            testCase.verifyTrue(threw, 'Expected error for nonexistent config');
        end

        function testErrorOnUnknownProbe(testCase)
            data = struct('info', struct('probename', 'Unknown .nir file'));
            testCase.verifyError(@() pf2.Device.load(data), ...
                'pf2:Device:load:unknownProbe');
        end

        function testErrorOnMissingProbename(testCase)
            data = struct('raw', rand(100, 10), 'fs', 10);
            testCase.verifyError(@() pf2.Device.load(data), ...
                'pf2:Device:load:noProbename');
        end

        function testErrorOnBadInputType(testCase)
            testCase.verifyError(@() pf2.Device.load(42), ...
                'pf2:Device:load:badInput');
        end

    end

    %% resolveDeviceFromData helper

    methods (Test)

        function testResolveWithExistingDevice(testCase)
            dev = pf2.Device.load('fNIR_Devices_fNIR2000');
            data = struct('device', dev, 'info', struct('probename', 'fNIR_Devices_fNIR2000'));
            resolved = pf2_base.resolveDeviceFromData(data);
            testCase.verifyEqual(resolved.name, dev.name);
        end

        function testResolveWithoutDevice(testCase)
            data = pf2.import.sampleData.fNIR2000();
            resolved = pf2_base.resolveDeviceFromData(data);
            testCase.verifyClass(resolved, 'pf2.Device');
            testCase.verifyTrue(contains(resolved.name, 'fNIR'));
        end

    end

end
