classdef ImportOxy3Test < matlab.unittest.TestCase
% IMPORTOXY3TEST Unit tests for pf2.import.importOxy3 function
%
% Verifies the Artinis OxySoft .oxy3 importer against a synthetic file
% generated in-process (OXY3 magic + UTF-16LE XML header + int16 frames),
% so the test ships no binary fixture and is fully deterministic. Checks the
% parsed structure, channel/wavelength mapping, marker extraction, and that
% the imported data processes through processFNIRS2.
%
% Usage:
%   results = runtests('pf2_base.tests.unit.ImportOxy3Test');
%   results = run(pf2_base.tests.unit.ImportOxy3Test);
%
% See also: pf2.import.importOxy3, matlab.unittest.TestCase

    properties (Access = private)
        File   % path to the synthetic .oxy3 file
        Data   % imported fNIRS struct
    end

    properties (Constant)
        FS = 10
        NB = 200          % samples
        NRX = 2
        NTX = 4           % 4 lasers = 2 Tx positions x 2 wavelengths
    end

    methods (TestClassSetup)
        function setupOnce(testCase)
            testCase.File = [tempname '.oxy3'];
            writeSyntheticOxy3(testCase.File, testCase.FS, testCase.NB, ...
                testCase.NRX, testCase.NTX);
            testCase.addTeardown(@() delete(testCase.File));
            testCase.Data = pf2.import.importOxy3(testCase.File, false);
        end
    end

    methods (Test)

        function testOptPosMatchesTableOpt(testCase)
            % Dedup invariant: importOxy3 must sync the OptPos coordinate view
            % to canonical TableOpt (OptPos.x was previously left at 2D values).
            P = testCase.Data.device.probeInfo.Probe{1};
            testCase.verifyEqual(P.OptPos.x, P.TableOpt.Pos3D_x);
            testCase.verifyEqual(P.OptPos.y, P.TableOpt.Pos3D_y);
            testCase.verifyEqual(P.OptPos.z, P.TableOpt.Pos3D_z);
            testCase.verifyEqual(P.OptPos.x_2d, P.TableOpt.Pos2D_x);
        end

        function testCoreFields(testCase)
            d = testCase.Data;
            testCase.verifyTrue(isstruct(d));
            testCase.verifyEqual(d.fs, testCase.FS, 'AbsTol', 1e-9);
            testCase.verifySize(d.time, [testCase.NB, 1]);
            testCase.verifyEqual(size(d.raw, 1), testCase.NB);
            % nRx*nTx optical wavelength-signals
            testCase.verifyEqual(size(d.raw, 2), testCase.NRX*testCase.NTX);
        end

        function testChannelCount(testCase)
            d = testCase.Data;
            % two wavelengths per channel
            expCh = testCase.NRX*testCase.NTX/2;
            testCase.verifyEqual(d.info.nChannels, expCh);
            testCase.verifyEqual(numel(d.fchMask), expCh);
        end

        function testWavelengths(testCase)
            d = testCase.Data;
            wv = unique(d.device.probeInfo.Probe{1}.TableCh.Wavelength)';
            testCase.verifyEqual(sort(wv), [760 850], 'AbsTol', 1);
        end

        function testTableChMatchesRaw(testCase)
            d = testCase.Data;
            nRows = height(d.device.probeInfo.Probe{1}.TableCh);
            testCase.verifyEqual(nRows, size(d.raw, 2), ...
                'TableCh must have one row per raw column.');
        end

        function testMarkers(testCase)
            d = testCase.Data;
            testCase.verifyTrue(istable(d.markers));
            % three sustained events: codes 1, 2, 1
            testCase.verifyEqual(height(d.markers), 3);
            testCase.verifyEqual(d.markers.Code(:)', [1 2 1]);
            % durations are positive (run length / fs)
            testCase.verifyGreaterThan(min(d.markers.Duration), 0);
            % markers are time-ordered
            testCase.verifyEqual(d.markers.Time, sort(d.markers.Time));
        end

        function testMarkerSourceColumn(testCase)
            d = testCase.Data;
            % normalizeMarkers preserves the Source column naming the port
            testCase.verifyTrue(ismember('Source', d.markers.Properties.VariableNames));
        end

        function testMarkerDictionary(testCase)
            d = testCase.Data;
            % code->label dictionary set for defineBlocks/labelMarkers
            testCase.verifyTrue(isfield(d.info, 'markerDict'));
            dict = pf2.data.getMarkerDict(d);
            testCase.verifyTrue(istable(dict));
            % two distinct codes (1 and 2) -> two dictionary entries
            testCase.verifyEqual(height(dict), 2);
        end

        function testDeviceAttached(testCase)
            d = testCase.Data;
            testCase.verifyClass(d.device, 'pf2.Device');
        end

        function testProcessesEndToEnd(testCase)
            proc = processFNIRS2(testCase.Data);
            testCase.verifyTrue(isfield(proc, 'HbO'));
            testCase.verifyEqual(size(proc.HbO, 1), testCase.NB);
            testCase.verifyEqual(size(proc.HbO, 2), testCase.NRX*testCase.NTX/2);
            % at least most channels yield finite hemoglobin
            testCase.verifyGreaterThan(mean(isfinite(proc.HbO(:))), 0.5);
        end

        function testWavelengthPairingDistinct(testCase)
            % each channel's two raw columns must be different wavelengths
            d = testCase.Data;
            T = d.device.probeInfo.Probe{1}.TableCh;
            for opt = unique(T.OptodeNumber)'
                w = T.Wavelength(T.OptodeNumber == opt);
                testCase.verifyNumElements(unique(w), 2);
            end
        end

        function testSDInCentimetres(testCase)
            % placeholder SD should be ~3 cm (not 30 mm) so Beer-Lambert and
            % short-separation detection use the correct unit
            d = testCase.Data;
            sd = d.device.probeInfo.Probe{1}.TableOpt.SD;
            testCase.verifyGreaterThan(min(sd), 1);
            testCase.verifyLessThan(max(sd), 6);
        end

        function testPlaceholderHasNoMNI(testCase)
            % synthetic/placeholder geometry must not masquerade as real MNI
            d = testCase.Data;
            testCase.verifyFalse(d.device.hasMNI());
            testCase.verifyEqual(d.info.geometry, 'placeholder');
        end

        function testRailedChannelsMasked(testCase)
            % a constant (disconnected/railed) channel is masked at import
            f = [tempname '.oxy3'];
            writeSyntheticOxy3(f, testCase.FS, testCase.NB, testCase.NRX, ...
                testCase.NTX, struct('railChannels', 2));
            c = onCleanup(@() delete(f));
            d = pf2.import.importOxy3(f, false);
            testCase.verifyEqual(d.fchMask(2), 0);
            testCase.verifyEqual(sum(d.fchMask == 0), 1);
        end

        function testTriggerCodeAbove64(testCase)
            % standard 8-bit trigger codes (>64) must not be silently dropped
            f = [tempname '.oxy3'];
            writeSyntheticOxy3(f, testCase.FS, testCase.NB, testCase.NRX, ...
                testCase.NTX, struct('triggerEvents', [40 60 100; 120 140 200]));
            c = onCleanup(@() delete(f));
            d = pf2.import.importOxy3(f, false);
            testCase.verifyEqual(height(d.markers), 2);
            testCase.verifyEqual(sort(d.markers.Code(:))', [100 200]);
        end

        function testSampleTimeOnlyFallback(testCase)
            % older files store only <SampleTime>; fs = 1/SampleTime
            f = [tempname '.oxy3'];
            writeSyntheticOxy3(f, testCase.FS, testCase.NB, testCase.NRX, ...
                testCase.NTX, struct('omitSampleRate', true));
            c = onCleanup(@() delete(f));
            d = pf2.import.importOxy3(f, false);
            testCase.verifyEqual(d.fs, testCase.FS, 'AbsTol', 1e-9);
        end

        function testBadMagicErrors(testCase)
            badFile = [tempname '.oxy3'];
            fid = fopen(badFile, 'w'); fwrite(fid, uint8('NOPE1234')); fclose(fid);
            c = onCleanup(@() delete(badFile));
            testCase.verifyError(@() pf2.import.importOxy3(badFile, false), ...
                'pf2:importOxy3:badMagic');
        end

    end
end

% =========================================================================
function writeSyntheticOxy3(path, fs, nb, nRx, nTx, opts)
% Build a minimal valid .oxy3 file. Frame layout: [trigger, counter, optical
% grid (nRx*nTx int16)]. Optical values are large (~6000) so they classify as
% light. opts (optional struct) overrides:
%   .omitSampleRate - write only <SampleTime> (older schema)   [false]
%   .triggerEvents  - [start end code; ...] sustained events   [1/2/1 pattern]
%   .railChannels   - channel indices to force constant (railed/dead)  []
if nargin < 6, opts = struct(); end
def = struct('omitSampleRate', false, ...
    'triggerEvents', [30 50 1; 90 110 2; 150 170 1], 'railChannels', []);
fn = fieldnames(def);
for i = 1:numel(fn)
    if ~isfield(opts, fn{i}), opts.(fn{i}) = def.(fn{i}); end
end

nGrid = nRx*nTx;
width = 2 + nGrid;            % trigger + counter + optical

% --- XML header (alternating 850/760 lasers) ---
laserBlocks = '';
for k = 1:nTx
    if mod(k,2)==1, wv = 850; else, wv = 760; end
    laserBlocks = [laserBlocks sprintf('<Laser ID="%d"><Wavelength>%d</Wavelength></Laser>', k-1, wv)]; %#ok<AGROW>
end
if opts.omitSampleRate
    rateTag = sprintf('<SampleTime>%g</SampleTime>', 1/fs);
else
    rateTag = sprintf('<SampleRate>%g</SampleRate><SampleTime>%g</SampleTime>', fs, 1/fs);
end
xml = [ ...
    '<om:oxyfile xmlns:om="http://www.artinis.com/oxymon" MajorVersion="1" MinorVersion="1">' ...
    '<Application>Oxysoft</Application><Version>version test</Version>' ...
    '<CreateDate>2026/01/01 00:00:00</CreateDate>' ...
    rateTag ...
    sprintf('<nADC>1</nADC><nbSamples>%d</nbSamples>', nb) ...
    sprintf('<nRx>%d</nRx><nTx>%d</nTx><dataFormat>1</dataFormat>', nRx, nTx) ...
    '<AdChName ID="0"><Name>PortAd_Buttons</Name></AdChName>' ...
    laserBlocks ...
    '<OptodeTemplateID>74</OptodeTemplateID>' ...
    '</om:oxyfile>'];
xmlBytes = unicode2native(xml, 'UTF-16LE');

% --- 20-byte fixed header ---
hdr = [uint8('OXY3'), zeros(1,4,'uint8'), ...
    typecast(uint32(numel(xmlBytes)), 'uint8'), zeros(1,4,'uint8'), ...
    typecast(uint32(1), 'uint8')];

% --- data frames (int16) ---
M = zeros(nb, width);
ev = opts.triggerEvents;
for r = 1:size(ev,1)
    M(ev(r,1):ev(r,2), 1) = ev(r,3);      % sustained event codes
end
M(:,2) = (0:nb-1)';                       % sample counter
base = 6000 + 500*sin(2*pi*(0:nb-1)'/50); % slow physiological-like fluctuation
for c = 1:nGrid
    M(:, 2+c) = round(base + 50*c);
end
% force selected channels (each = 2 consecutive optical columns) to a railed
% constant, emulating disconnected source-detector combinations
for ch = opts.railChannels(:)'
    cols = 2 + ((2*ch-1):(2*ch));
    M(:, cols) = 6000;                    % constant -> zero variance
end
frames = int16(reshape(M', [], 1));       % row-major -> frame-contiguous
dataBytes = typecast(frames, 'uint8');

fid = fopen(path, 'w', 'l');
fwrite(fid, hdr, 'uint8');
fwrite(fid, xmlBytes, 'uint8');
fwrite(fid, dataBytes, 'uint8');
fclose(fid);
end
