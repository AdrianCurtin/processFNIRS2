function [fNIR] = importOxy3(file, channelCheck, varargin)
% IMPORTOXY3 Import fNIRS data from Artinis OxySoft .oxy3 files
%
% Reads continuous-wave fNIRS recordings saved by Artinis Medical Systems'
% OxySoft software (OxyMon, OctaMon, PortaLite and related devices). The
% .oxy3 container stores a UTF-16LE XML metadata header (device, lasers,
% detectors, sampling rate, optode-template references) followed by
% fixed-width binary data frames of raw light intensities, auxiliary ADC
% channels, an event/trigger channel and a sample counter.
%
% The binary layout is reverse-engineered from the file itself rather than
% read from a published spec (Artinis ships its own reader as protected
% P-code). Frame width is derived from the header sample count, and the
% optical grid (nRx detectors x nTx lasers) is paired into wavelength
% couples per channel. Disconnected source-detector combinations are stored
% as a constant saturation rail; these are imported as channels but are
% flagged by the saturation quality check downstream.
%
% Probe geometry is NOT contained in the .oxy3 file: OxySoft references an
% external optode template by ID. By default a placeholder linear layout is
% generated so the recording processes end-to-end (HbO/HbR), with topo/3D
% plots positioned on a synthetic grid. Supply the matching template via the
% 'OptodeTemplate' option to recover real 2D optode coordinates.
%
% Reference:
%   Artinis Medical Systems. OxySoft .oxy3 file format.
%   https://www.artinis.com
%   FieldTrip NIRS toolbox (read_artinis_oxy3), Artinis Medical Systems (2015).
%
% Syntax:
%   fNIR = pf2.import.importOxy3()
%   fNIR = pf2.import.importOxy3(file)
%   fNIR = pf2.import.importOxy3(file, channelCheck)
%   fNIR = pf2.import.importOxy3(file, channelCheck, Name, Value)
%
% Inputs:
%   file         - Filename or full path to a .oxy3 file [char | string]
%                  If omitted, a file selection dialog opens.
%   channelCheck - Run channel quality check GUI after import (default: true)
%                  Set false to skip interactive quality assessment.
%   varargin     - Name-value options:
%                  'OptodeTemplate'       - Path to an OxySoft
%                                           optodetemplates.xml. When given,
%                                           real optode 2D positions for the
%                                           file's OptodeTemplateID are used
%                                           instead of the placeholder layout.
%                  'ChannelCheckVersion'  - QC GUI version (default: project).
%
% Outputs:
%   fNIR - Standard pf2 fNIRS data structure containing:
%          .raw       - Raw light intensity [T x C: one column per optical
%                       wavelength-signal, detector-major then laser order]
%          .time      - Time vector in seconds [T x 1]
%          .fs        - Sampling frequency in Hz [double]
%          .markers   - Event markers (canonical table) from the digital
%                       port/trigger channels: one row per code onset, with
%                       Time, Code, Duration (run length), Amplitude and a
%                       Source column naming the originating port channel
%          .fchMask   - Channel quality mask [1 x nChannels: 1=good]
%          .info      - Metadata struct containing:
%                       .probename       - 'Artinis_oxy3'
%                       .Manufacturer    - 'Artinis'
%                       .OxySoftVersion  - Application version string
%                       .CreateDate      - Recording timestamp string
%                       .nRx,.nTx,.nADC  - Detector/laser/ADC counts
%                       .OptodeTemplateID- Referenced template id (if present)
%                       .laserWavelengths- Per-laser wavelengths (nm)
%                       .Aux             - Battery/ADC auxiliary samples
%          .device    - pf2.Device object (placeholder or template geometry)
%          .Aux       - Auxiliary ADC signals (battery, port inputs)
%
% Algorithm:
%   1. Read bytes; verify 'OXY3' magic.
%   2. Locate and decode the UTF-16LE XML header (bounded by </om:oxyfile>).
%   3. Parse fs (SampleRate, else 1/SampleTime), nRx/nTx/nADC, sample count,
%      and per-laser wavelengths (clustered to nominal values).
%   4. Derive frame width = floor(nInt16 / nbSamples); reshape int16 frames.
%   5. Identify the sample counter, trigger channel and optical grid block.
%   6. Pair optical columns into channels (two wavelengths each); build a
%      device probeInfo (NIRX-style) with placeholder or template geometry.
%   7. Extract markers from trigger rising edges; assemble the fNIR struct.
%
% Example:
%   % Import with file dialog
%   data = pf2.import.importOxy3();
%
%   % Import a specific recording, skip the channel-check GUI
%   data = pf2.import.importOxy3('SOT.oxy3', false);
%
%   % Import with real optode geometry from a template file
%   data = pf2.import.importOxy3('rec.oxy3', false, ...
%       'OptodeTemplate', 'optodetemplates.xml');
%
% Notes:
%   - fs is taken from <SampleRate>; older files store only <SampleTime>
%     (fs = 1/SampleTime).
%   - Multi-laser systems report slightly different per-diode wavelengths
%     (e.g. 844/845/846); these are clustered to nominal nm values.
%   - Disconnected optode combinations appear as a constant saturation rail
%     and are masked by the saturation QC check, not dropped at import.
%   - Stimulus markers come from the OxySoft digital port (PortAd) channels;
%     all such channels are scanned and every transition into a non-zero code
%     is recorded. OxySoft keeps human-readable event NAMES in its project
%     (not the .oxy3), so markers carry numeric codes; a code->label
%     dictionary ("<Port>_<code>") is written to info.markerDict /
%     info.eventTypes for defineBlocks/labelMarkers. Files without trigger
%     activity import with an empty marker table.
%
% See also: pf2.import.importSNIRF, pf2.import.importNIRX,
%           pf2.import.importHitachiMES, pf2.import.importNIR

% --- option parsing -------------------------------------------------------
pf2_base.ensureStatsFallbacks();  % ensure stats-toolbox fallbacks (nan*) are on the path before use

forceChannelCheck = false;
channelCheckVersion = pf2_base.channelCheckVersion();
optodeTemplate = '';
for vi_ = 1:2:numel(varargin)
    if ~(ischar(varargin{vi_}) || isstring(varargin{vi_})), continue; end
    switch lower(char(varargin{vi_}))
        case 'channelcheckversion'
            channelCheckVersion = varargin{vi_+1};
        case 'optodetemplate'
            optodeTemplate = char(varargin{vi_+1});
    end
end

if nargin < 2 || isempty(channelCheck)
    channelCheck = true;     % default on
else
    forceChannelCheck = true; % explicit request is honored
end

if nargin < 1 || isempty(file)
    [fname, pathname] = uigetfile({'*.oxy3', 'Artinis OxySoft (*.oxy3)'; ...
        '*.*', 'All Files (*.*)'}, 'Open Artinis .oxy3 file');
    if isequal(fname, 0)
        fNIR = [];
        return;
    end
    filename = fullfile(pathname, fname);
elseif ~(ischar(file) || isstring(file))
    error('pf2:importOxy3:badInput', 'Input must be a filename string.');
else
    filename = char(file);
end

if ~isfile(filename)
    error('pf2:importOxy3:FileNotFound', 'File not found: %s', filename);
end
[~, fileroot, ~] = fileparts(filename);

fprintf('Importing %s...\n', filename);

% --- read bytes & verify magic -------------------------------------------
fid = fopen(filename, 'r', 'l');
if fid == -1
    error('pf2:importOxy3:openFailed', 'Unable to open file: %s', filename);
end
cleanup = onCleanup(@() fcloseIfOpen(fid));
bytes = fread(fid, inf, '*uint8')';
clear cleanup;   % onCleanup closes fid

if numel(bytes) < 24 || ~strcmp(char(bytes(1:4)), 'OXY3')
    error('pf2:importOxy3:badMagic', ...
        'Not an .oxy3 file (missing OXY3 signature): %s', filename);
end

% --- locate and decode the XML header ------------------------------------
endTag = unicode2native('</om:oxyfile>', 'UTF-16LE');
idx = strfind(bytes, endTag);
if isempty(idx)
    error('pf2:importOxy3:noHeader', 'XML header end tag not found.');
end
xmlStart = 21;                           % byte 0x14 (1-indexed)
xmlEnd = idx(1) + numel(endTag) - 1;     % last byte of closing tag
xml = native2unicode(bytes(xmlStart:xmlEnd), 'UTF-16LE');

% --- parse header scalars ------------------------------------------------
nbSamples = localNum(xml, 'nbSamples');
nRx  = localNum(xml, 'nRx');
nTx  = localNum(xml, 'nTx');
nADC = localNum(xml, 'nADC');
if isnan(nADC), nADC = 0; end

fs = localNum(xml, 'SampleRate');
if isnan(fs) || fs <= 0
    st = localNum(xml, 'SampleTime');
    if ~isnan(st) && st > 0, fs = 1/st; end
end
if isnan(fs) || fs <= 0
    error('pf2:importOxy3:noSampleRate', 'Could not determine sampling rate.');
end

% per-laser wavelengths (one <Wavelength> per <Laser>)
wvTok = regexp(xml, '<Wavelength>(\d+(?:\.\d+)?)</Wavelength>', 'tokens');
laserWv = cellfun(@(t) str2double(t{1}), wvTok);
nLaser = numel(laserWv);
nominalWv = localClusterWavelengths(laserWv);   % e.g. [760 850]

appVer = localStr(xml, 'Version');
createDate = localStr(xml, 'CreateDate');
optTemplateID = localNum(xml, 'OptodeTemplateID');

if isnan(nbSamples) || nbSamples <= 0
    error('pf2:importOxy3:noSampleCount', 'Header missing nbSamples.');
end
if isnan(nRx) || isnan(nTx) || nRx < 1 || nTx < 1
    error('pf2:importOxy3:noGrid', 'Header missing nRx/nTx.');
end
if numel(nominalWv) ~= 2
    error('pf2:importOxy3:wavelengthCount', ...
        ['Expected 2 nominal wavelengths for Beer-Lambert conversion, got %d ' ...
         '([%s] nm). Only dual-wavelength CW recordings are supported.'], ...
        numel(nominalWv), strjoin(string(nominalWv), ' '));
end

% --- reshape binary data frames ------------------------------------------
dataBytes = bytes(xmlEnd+1:end);
nInt16 = floor(numel(dataBytes)/2);
d16 = double(typecast(dataBytes(1:nInt16*2), 'int16'));

width = floor(nInt16 / nbSamples);   % per-frame width (int16), montage-specific
if width < (nRx + 1)
    error('pf2:importOxy3:frameWidth', 'Implausible frame width (%d).', width);
end
nSamp = nbSamples;
if nSamp*width > numel(d16)
    nSamp = floor(numel(d16)/width);   % defensive: truncated/partial file
end
M = reshape(d16(1:nSamp*width), width, nSamp)';   % [nSamp x width]

time = (0:nSamp-1)' / fs;

% --- classify columns ----------------------------------------------------
colStd = std(M, 0, 1);
colMin = min(M, [], 1);
colMax = max(M, [], 1);
colMed = median(M, 1);
colNUnique = arrayfun(@(c) numel(unique(M(:, c))), 1:width);   % distinct values

% sample counter: monotonic +1 (used only as a cross-check)
counterCol = 0;
for c = 1:width
    if all(diff(M(1:min(nSamp,500), c)) == 1), counterCol = c; break; end
end

% trigger/event channel: an integer-coded digital line. OxySoft port codes
% span the full 8-bit range (0-255), so range is NOT capped; the channel is
% identified by being integer-valued with few distinct codes (a low-cardinality
% step signal), not by a small amplitude.
isInt = all(M == round(M), 1);
isTrig = colMin >= 0 & colMax <= 255 & colStd > 0 & (1:width) ~= counterCol & ...
    isInt & colNUnique <= 16;

% Optical grid: the block of nRx*nTx columns ending at the last column that
% looks like a light intensity (large value, varying or at a saturation
% rail). Disconnected combinations sit at a constant high rail and are
% retained, then masked at import / by saturation QC.
isLightCol = (colMed > 1000) & ~((1:width) == counterCol) & ~isTrig;
lightCols = find(isLightCol);
gridSize = nRx * nTx;
if isempty(lightCols)
    error('pf2:importOxy3:noOptical', 'No optical channels detected.');
end
lastLight = lightCols(end);
if lastLight >= gridSize
    opticalCols = (lastLight - gridSize + 1):lastLight;   % full nRx*nTx grid
    fullGrid = true;
else
    % Montage stores fewer signals than nRx*nTx (older multi-device files):
    % take the contiguous light block as-is, pair consecutively.
    opticalCols = lightCols(1):lightCols(end);
    opticalCols = opticalCols(ismember(opticalCols, lightCols) | ...
        ismember(opticalCols, find(colStd < 1e-9 & colMed > 1000)));
    fullGrid = false;
end
nOptical = numel(opticalCols);
if mod(nOptical, 2) ~= 0
    warning('pf2:importOxy3:oddOptical', ...
        ['Optical column count (%d) is odd; dropping the last column ' ...
         '(likely a reference/dark channel).'], nOptical);
    opticalCols(end) = [];
    nOptical = numel(opticalCols);
end

rawOptical = M(:, opticalCols);
nCh = nOptical / 2;   % two wavelengths per channel

% --- wavelength + (src,det) assignment per optical column ----------------
% Columns are detector-major, laser order within a detector. Consecutive
% columns share a transmitter position (two wavelengths) -> one channel.
if nLaser >= 1
    if fullGrid && nLaser == nTx
        colWv = laserWv(mod((0:nOptical-1), nTx) + 1);   % laser order within detector
    else
        colWv = laserWv(mod((0:nOptical-1), nLaser) + 1);% cycle in acquisition order
    end
else
    % header carried no laser wavelengths: fall back to alternating nominals
    colWv = nominalWv(mod((0:nOptical-1), numel(nominalWv)) + 1);
end
colWv = colWv(:)';
% map each column wavelength to its nearest nominal wavelength index
[~, wvIdx] = min(abs(colWv(:) - nominalWv(:)'), [], 2);   % [nOptical x 1]
LambdaNominal = nominalWv(:)';

% channel index for each optical column: consecutive pairs share a channel
chOfCol = ceil((1:nOptical)/2)';          % [nOptical x 1]

% Guard: each channel's two columns MUST be different wavelengths, or the
% Beer-Lambert step gets two equations for the same chromophore. If the
% laser/column ordering of this file violates the consecutive-pair
% assumption, fail loudly rather than emit silently wrong HbO/HbR.
for ch = 1:nCh
    if wvIdx(2*ch-1) == wvIdx(2*ch)
        error('pf2:importOxy3:wavelengthPairing', ...
            ['Channel %d maps to two columns of the same wavelength (%g nm). ' ...
             'The optical column/laser ordering does not match the expected ' ...
             'consecutive-wavelength pairing for this device.'], ch, colWv(2*ch-1));
    end
end

% Build a NIRX-style measurement list: [srcIdx detIdx probe wvIdx].
% Placeholder optode identity: each channel gets its own src & det index so
% the channel table is well-formed; real coordinates come from geometry.
srcOfCh = (1:nCh)';
detOfCh = (1:nCh)';
MeasList = [srcOfCh(chOfCol), detOfCh(chOfCol), ones(nOptical,1), wvIdx];

% --- geometry: placeholder or from optode template -----------------------
[srcPos, detPos, geomLabel] = localGeometry(nCh, optodeTemplate, optTemplateID, xml);

% --- build device probeInfo (mirrors importNIRX construction) ------------
device = localBuildDevice(MeasList, srcPos, detPos, LambdaNominal, fs, geomLabel);

% --- markers from digital/port trigger channels --------------------------
% OxySoft stores stimulus events as digital codes on its PortAd channels;
% event *labels* live in the OxySoft project, not the .oxy3, so markers carry
% the numeric code plus the source channel name. Every transition into a
% non-zero code is an onset (captures 0->code and code->code'); the run length
% gives each marker a duration.
adcNames = regexp(xml, '<AdChName ID="\d+"><Name>([^<]+)</Name>', 'tokens');
adcNames = cellfun(@(t) t{1}, adcNames, 'uni', 0);
[markers, markerDict, trigNames] = localExtractMarkers(M, time, fs, isTrig, adcNames);

% --- auxiliary ADC channels ----------------------------------------------
% Export the trigger line (legacy Aux.trigger) plus every other analog AD
% channel (battery, respiration belt, external sensors), typed by name.
Aux = pf2_base.oxy3Aux(M, time, isTrig, opticalCols, counterCol, adcNames, trigNames);

% --- assemble fNIR struct ------------------------------------------------
fNIR = struct();
fNIR.raw = rawOptical;
fNIR.time = time;
fNIR.fs = fs;
fNIR.markers = markers;
% Pre-mask disconnected/dead channels: a constant (zero-variance) column means
% a source-detector combination that was never connected or is railed at a
% saturation value. These carry no haemodynamics and would otherwise pass the
% saturation QC (whose ceiling is the 16-bit max, not the device's rail), so
% flag them here rather than relying solely on downstream QC.
fchMask = ones(1, nCh);
deadCh = false(1, nCh);
for ch = 1:nCh
    if any(std(rawOptical(:, chOfCol == ch), 0, 1) < 1e-9)
        deadCh(ch) = true;
    end
end
fchMask(deadCh) = 0;
if any(deadCh)
    fprintf(['  %d of %d channels are disconnected/railed (constant signal) ' ...
        'and were masked: %s\n'], sum(deadCh), nCh, mat2str(find(deadCh)));
end
fNIR.fchMask = fchMask;
if ~isempty(fieldnames(Aux)), fNIR.Aux = Aux; end

info = struct();
% "generated" prefix signals processFNIRS2 to use the in-memory probeinfo and
% never attempt to resolve a (non-existent) Artinis_oxy3.cfg from disk.
info.probename = 'generated_Artinis_oxy3';
info.Manufacturer = 'Artinis';
info.Age = [];   % unknown; processFNIRS2 defaults DPF age to 25
info.OxySoftVersion = appVer;
info.CreateDate = createDate;
info.nRx = nRx; info.nTx = nTx; info.nADC = nADC;
info.nChannels = nCh;
info.laserWavelengths = laserWv;
info.nominalWavelengths = LambdaNominal;
info.frameWidth = width;
info.sampleCounterCol = counterCol;
if ~isnan(optTemplateID), info.OptodeTemplateID = optTemplateID; end
info.geometry = geomLabel;
if ~isempty(trigNames), info.triggerChannels = trigNames; end
if ~isempty(markerDict)
    % code->label dictionary so defineBlocks/labelMarkers can auto-label
    info.markerDict = markerDict;
    info.eventTypes = markerDict;   % back-compat alias
end
fNIR.info = info;

fNIR.device = pf2.Device.fromProbeInfo(device);
fNIR.probeinfo = device;   % processFNIRS2 reads channel/wavelength map here

fprintf(['Importing Complete: %d channels, %g Hz, %.1f s (%s geometry)\n'], ...
    nCh, fs, time(end), geomLabel);

% --- channel quality check / mask ----------------------------------------
if channelCheck
    if forceChannelCheck && pf2_base.allowChannelCheckGUI()
        if channelCheckVersion == 2
            app = pf2.qc.ChannelCheck(fNIR, 'CalledFromImport', true, 'SkipConfirmation', true);
            if isvalid(app), fNIR = app.OutputData; delete(app); end
        else
            fNIR = probeCheckGUI(fNIR, filename, forceChannelCheck);
        end
    else
        fNIR = pf2_base.loadExistingMaskOrCheck(fNIR, filename, channelCheckVersion);
    end
end

end

% =========================================================================
% Local helpers
% =========================================================================

function v = localNum(xml, tag)
% Scalar numeric value of <tag ...>value</tag> (NaN if absent).
t = regexp(xml, ['<' tag '[^>]*>([^<]+)</' tag '>'], 'tokens', 'once');
if isempty(t), v = NaN; else, v = str2double(strtrim(t{1})); end
end

function s = localStr(xml, tag)
% Text content of <tag ...>text</tag> ('' if absent).
t = regexp(xml, ['<' tag '[^>]*>([^<]*)</' tag '>'], 'tokens', 'once');
if isempty(t), s = ''; else, s = strtrim(t{1}); end
end

function nominal = localClusterWavelengths(laserWv)
% Cluster per-diode wavelengths into nominal values (typically [760 850]).
% Diodes within 10 nm of each other belong to the same nominal band.
u = unique(round(laserWv(:)'));
if isempty(u), nominal = [760 850]; return; end
nominal = [];
cluster = u(1);
for k = 2:numel(u)
    if u(k) - cluster(end) <= 10
        cluster(end+1) = u(k); %#ok<AGROW>
    else
        nominal(end+1) = round(mean(cluster)); %#ok<AGROW>
        cluster = u(k);
    end
end
nominal(end+1) = round(mean(cluster));
end

function [markers, dictCell, trigNames] = localExtractMarkers(M, time, fs, isTrig, adcNames)
% Extract stimulus markers from digital/port trigger columns.
%   markers  - canonical marker table (with a Source column naming the port)
%   dictCell - {code, 'Label'} dictionary for info.markerDict
%   trigNames- names of the port channels that carried events
trigCols = find(isTrig);

% digital/port channel names from the header (for labelling sources)
portNames = adcNames(cellfun(@(s) ~isempty(regexpi(s, ...
    'port|button|digi|trig|input', 'once')), adcNames));

allTime = []; allCode = []; allDur = []; allSrc = {};
trigNames = {};
for ti = 1:numel(trigCols)
    col = M(:, trigCols(ti));
    chg = find(diff(col) ~= 0);
    starts = [1; chg + 1];
    ends   = [chg; numel(col)];
    vals   = col(starts);
    keep = vals > 0;                 % only segments holding a non-zero code
    starts = starts(keep); ends = ends(keep); vals = vals(keep);
    if isempty(vals), continue; end
    if numel(portNames) >= ti
        srcName = portNames{ti};
    elseif ~isempty(portNames)
        srcName = portNames{1};
    else
        srcName = sprintf('Trigger%d', ti);
    end
    trigNames{end+1} = srcName; %#ok<AGROW>
    allTime = [allTime; time(starts)];          %#ok<AGROW>
    allCode = [allCode; vals];                  %#ok<AGROW>
    allDur  = [allDur; (ends - starts + 1)/fs]; %#ok<AGROW>
    allSrc  = [allSrc; repmat({srcName}, numel(vals), 1)]; %#ok<AGROW>
end

if isempty(allTime)
    markers = pf2_base.normalizeMarkers([]);
    dictCell = {};
    return;
end

[allTime, ord] = sort(allTime);
allCode = allCode(ord); allDur = allDur(ord); allSrc = allSrc(ord);
T = table(allTime, allCode, allDur, ones(numel(allTime),1), categorical(allSrc), ...
    'VariableNames', {'Time','Code','Duration','Amplitude','Source'});
markers = pf2_base.normalizeMarkers(T);

uc = unique(allCode);
dictCell = cell(numel(uc), 2);
for k = 1:numel(uc)
    si = find(allCode == uc(k), 1);
    dictCell{k,1} = uc(k);
    dictCell{k,2} = sprintf('%s_%d', allSrc{si}, uc(k));
end
end

function [srcPos, detPos, label] = localGeometry(nCh, templatePath, templateID, xml)
% Return [nCh x 3] source and detector positions in CENTIMETRES (the pf2
% convention; bvoxy treats source-detector distance as cm and short-separation
% is SD < 2 cm). Uses an optode template when supplied/resolvable, else a
% placeholder layout. The placeholder leaves Z (3D) at zero so the device
% reports no real MNI geometry (hasMNI stays false).
srcPos = []; detPos = []; label = 'placeholder';
if ~isempty(templatePath) && isfile(templatePath) && ~isnan(templateID)
    try
        [srcPos, detPos] = localParseTemplate(templatePath, templateID, nCh, xml);
        if ~isempty(srcPos), label = sprintf('template:%d', templateID); end
    catch ME
        warning('pf2:importOxy3:template', ...
            'Optode template parse failed (%s); using placeholder.', ME.message);
        srcPos = []; detPos = [];
    end
end
if isempty(srcPos)
    % Placeholder: sources and detectors on parallel rows 3 cm apart, spread
    % 2.5 cm along x -> SD = 3 cm (a realistic adult separation). Z stays 0.
    x = (0:nCh-1) * 2.5;
    srcPos = [x(:), zeros(nCh,1), zeros(nCh,1)];
    detPos = [x(:), 3*ones(nCh,1), zeros(nCh,1)];
end
end

function [srcPos, detPos] = localParseTemplate(templatePath, templateID, nCh, xml)
% Parse OxySoft optodetemplates.xml for the given OptodeTemplate ID and
% return per-channel source (TX) and detector (RX) positions, scaled by the
% recording's PositionScale. Best-effort: returns [] if the template id or
% its optode positions cannot be found.
srcPos = []; detPos = [];
txt = fileread(templatePath);
% Anchor the id with its closing quote so ID="74" cannot match ID="749".
blk = regexp(txt, ['<OptodeTemplate ID="' num2str(templateID) '"[ >].*?</OptodeTemplate>'], ...
    'match', 'once');
if isempty(blk), return; end
% RX/TX optode 2D coordinates
rx = regexp(blk, '<RXOptode[^>]*>.*?<X>([-\d.]+)</X>\s*<Y>([-\d.]+)</Y>', 'tokens');
tx = regexp(blk, '<TXOptode[^>]*>.*?<X>([-\d.]+)</X>\s*<Y>([-\d.]+)</Y>', 'tokens');
if isempty(rx) || isempty(tx), return; end
rxXY = cell2mat(cellfun(@(t) str2double(t)', rx, 'uni', 0))';   % [nRx x 2]
txXY = cell2mat(cellfun(@(t) str2double(t)', tx, 'uni', 0))';   % [nTx x 2]
scale = localNum(xml, 'PositionScale');
if isnan(scale) || scale <= 0, scale = 30; end
% PositionScale is in mm; convert to cm (pf2 convention).
rxXY = rxXY * scale / 10; txXY = txXY * scale / 10;
% Assign the first nCh transmitters/receivers cyclically as a starting
% geometry. When there are more channels than template optodes this reuses
% positions (a known limitation of the template-only mapping), so warn.
if nCh > size(txXY,1) || nCh > size(rxXY,1)
    warning('pf2:importOxy3:templateCycle', ...
        ['Template has %d TX / %d RX optodes but %d channels; positions are ' ...
         'reused cyclically and are not a true per-channel mapping.'], ...
        size(txXY,1), size(rxXY,1), nCh);
end
ti = mod((0:nCh-1), size(txXY,1)) + 1;
ri = mod((0:nCh-1), size(rxXY,1)) + 1;
srcPos = [txXY(ti,1), txXY(ti,2), zeros(nCh,1)];
detPos = [rxXY(ri,1), rxXY(ri,2), zeros(nCh,1)];
end

function device = localBuildDevice(MeasList, srcPosCh, detPosCh, Lambda, fs, geomLabel)
% Build a pf2 device probeInfo from a measurement list and per-channel
% source/detector positions. Mirrors the in-memory construction used by
% pf2.import.importNIRX so the struct is accepted by pf2.Device.fromProbeInfo
% and by processFNIRS2 (which reads TableCh.OptodeNumber/Wavelength).
nMeas = size(MeasList, 1);

device = struct();
device.cfg = pf2_base.external.INI();
device.Info.CfgName = 'Artinis_oxy3';
device.Info.Name = 'oxy3';
device.Info.Manufacturer = 'Artinis';
device.Info.DefaultSamplingRate = fs;
device.Info.MaxSamplingRate = fs;
device.Info.NumberProbes = 1;
device.Info.RawMax = 65535;
device.Info.RawMin = 0;
device.Info.NumberChannels = 0;
device.Info.TimeIsSampleCount = 0;
device.Info.Geometry = geomLabel;

p = struct();
% per-channel source/detector positions (one src & det per channel)
p.SrcPosX = srcPosCh(:,1); p.SrcPosY = srcPosCh(:,2); p.SrcPosZ = srcPosCh(:,3);
p.DetPosX = detPosCh(:,1); p.DetPosY = detPosCh(:,2); p.DetPosZ = detPosCh(:,3);
p.SrcPos3D = srcPosCh; p.DetPos3D = detPosCh;

% raw-column -> optode/wavelength map (one row per optical column)
p.TableCh = table();
p.TableCh.ColNumber = (1:nMeas)';
[~, ~, uOpt] = unique(MeasList(:, 1:2), 'rows', 'stable');
p.TableCh.OptodeNumber = uOpt;
p.TableCh.isTime   = false(nMeas, 1);
p.TableCh.isMarker = false(nMeas, 1);
p.TableCh.Wavelength = Lambda(MeasList(:, 4))';
p.TableCh.SourceIndex = MeasList(:, 1);
p.TableCh.DetectorIndex = MeasList(:, 2);
p.TableCh.isDark = isnan(p.TableCh.Wavelength) | p.TableCh.Wavelength == 0;
p.TableCh.isCh   = p.TableCh.OptodeNumber > 0 & ~p.TableCh.isDark;

p.SrcPos = table(p.SrcPosX(:), p.SrcPosY(:), p.SrcPosZ(:), ...
    p.SrcPosX(:), p.SrcPosY(:), p.SrcPosZ(:), ...
    'VariableNames', {'x_2d','y_2d','z_2d','x','y','z'});
p.DetPos = table(p.DetPosX(:), p.DetPosY(:), p.DetPosZ(:), ...
    p.DetPosX(:), p.DetPosY(:), p.DetPosZ(:), ...
    'VariableNames', {'x_2d','y_2d','z_2d','x','y','z'});

% unique source-detector pairs -> optodes (acquisition order preserved)
sI = MeasList(:, 1); dI = MeasList(:, 2);
[uPairs, ~, uPairIdx] = unique([sI dI], 'rows', 'stable');
nOpt = size(uPairs, 1);

optSrcX = p.SrcPosX(uPairs(:,1)); optSrcY = p.SrcPosY(uPairs(:,1)); optSrcZ = p.SrcPosZ(uPairs(:,1));
optDetX = p.DetPosX(uPairs(:,2)); optDetY = p.DetPosY(uPairs(:,2)); optDetZ = p.DetPosZ(uPairs(:,2));
srcPos3D = [optSrcX optSrcY optSrcZ];
detPos3D = [optDetX optDetY optDetZ];

p.sI = uPairs(:,1); p.dI = uPairs(:,2);
p.SrcPosX = optSrcX; p.SrcPosY = optSrcY; p.SrcPosZ = optSrcZ;
p.DetPosX = optDetX; p.DetPosY = optDetY; p.DetPosZ = optDetZ;
p.SrcPos3D = srcPos3D; p.DetPos3D = detPos3D;

p.OptPosX = mean([optSrcX optDetX], 2);
p.OptPosY = mean([optSrcY optDetY], 2);
p.OptPosZ = mean([optSrcZ optDetZ], 2);
p.OptPos3D = (srcPos3D + detPos3D) / 2;
p.NumOptodes = nOpt;

p.OptPos = table(p.OptPosX(:), p.OptPosY(:), p.OptPosZ(:), ...
    p.OptPosX(:), p.OptPosY(:), p.OptPosZ(:), ...
    'VariableNames', {'x_2d','y_2d','z_2d','x','y','z'});

p.SD = sqrt((optSrcX-optDetX).^2 + (optSrcY-optDetY).^2 + (optSrcZ-optDetZ).^2);
p.IsShortSeparation = p.SD < 2;

% per-optode table (schema mirrors pf2_base.loadDeviceCfg)
p.TableOpt = table((1:nOpt)', 'VariableNames', {'OptodeNum'});
p.TableOpt.SrcIdx = uPairs(:,1);
p.TableOpt.DetIdx = uPairs(:,2);
p.TableOpt.Pos2D_x = p.OptPosX(:);
p.TableOpt.Pos2D_y = p.OptPosY(:);
p.TableOpt.Pos2D_z = p.OptPosZ(:);
p.TableOpt.Pos3D_x = p.OptPos3D(:,1);
p.TableOpt.Pos3D_y = p.OptPos3D(:,2);
p.TableOpt.Pos3D_z = p.OptPos3D(:,3);
p.TableOpt.SD = p.SD(:);
p.TableOpt.IsShortSeparation = p.IsShortSeparation(:);

% source/detector table (one row per source, then per detector)
nSrc = size(srcPosCh, 1); nDet = size(detPosCh, 1);
sdType = categorical([repmat("Src", nSrc, 1); repmat("Det", nDet, 1)]);
sdIndex = [(1:nSrc)'; (1:nDet)'];
sdLabel = arrayfun(@(t,i) sprintf('%c%d', char(t), i), sdType, sdIndex, 'uni', 0);
p.TableSD = table(sdType, sdIndex, sdLabel, 'VariableNames', {'Type','Index','Label'});
p.TableSD.Pos2D_x = [srcPosCh(:,1); detPosCh(:,1)];
p.TableSD.Pos2D_y = [srcPosCh(:,2); detPosCh(:,2)];
p.TableSD.Pos2D_z = [srcPosCh(:,3); detPosCh(:,3)];
p.TableSD.Pos3D_x = [srcPosCh(:,1); detPosCh(:,1)];
p.TableSD.Pos3D_y = [srcPosCh(:,2); detPosCh(:,2)];
p.TableSD.Pos3D_z = [srcPosCh(:,3); detPosCh(:,3)];

p.probeNum = ones(nMeas, 1);
p.wvI = MeasList(:, 4);
p.ChannelNumbers = uPairIdx';
p.ChannelList = 1:nOpt;
p.Wavelength = Lambda;
device.Info.NumberChannels = nOpt;

% 2D layout for plotting
try
    p.OptLayout2D = pf2_base.fitProbe2D(p.OptPosX, p.OptPosY, p.OptPosZ);
catch
    p.OptLayout2D = num2cell((1:nOpt)');
end
p.OptPos.subplot_layout = p.OptLayout2D(:);
p.OptPos.subplot_layout_ss = p.OptLayout2D(:);

% For placeholder geometry, null the 3D coordinates so the device reports no
% MNI (Device.hasMNI checks Pos3D) -- this keeps anatomical lookups such as
% nearestBrodmann from silently returning meaningless results on synthetic
% positions. The 2D layout and SD distances (used for plotting and
% Beer-Lambert) are retained.
if startsWith(string(geomLabel), 'placeholder')
    z = zeros(nOpt, 1);
    p.SrcPos3D = zeros(nOpt, 3); p.DetPos3D = zeros(nOpt, 3);
    p.OptPos3D = zeros(nOpt, 3);
    p.TableOpt.Pos3D_x = z; p.TableOpt.Pos3D_y = z; p.TableOpt.Pos3D_z = z;
    zsd = zeros(height(p.TableSD), 1);
    p.TableSD.Pos3D_x = zsd; p.TableSD.Pos3D_y = zsd; p.TableSD.Pos3D_z = zsd;
end

% TableOpt is canonical; mirror its (possibly placeholder-nulled) coordinates
% into the OptPos view so the renderer's OptPos.x reads the same 3D positions
% the atlas/Device code sees -- consistent with the cfg and SNIRF paths.
p = pf2_base.syncOptodeCoords(p);

device.Probe{1} = p;
end

function fcloseIfOpen(fid)
if ~isempty(fid) && isnumeric(fid) && fid > 0
    try, fclose(fid); catch, end
end
end
