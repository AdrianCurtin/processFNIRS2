function [tbl, descriptor] = montage(data, opts)
% MONTAGE Export a portable, self-describing montage descriptor for a probe
%
% Serializes a probe's geometry and metadata into a portable form: a
% per-channel MATLAB table plus a montage-level descriptor struct. Both are
% drawn entirely from the pf2.Device value class (MNI coordinates,
% source-detector distances, wavelengths, short-separation flags, coordinate
% system and provenance) and, when 3D positions are available, the nearest
% Brodmann area per channel. The descriptor is a standalone record of "what
% this montage is" - useful for reproducibility, sharing probe geometry,
% documenting a montage in a paper's supplement, and as the montage sidecar
% consumed by downstream tensor/model export.
%
% Optionally writes the descriptor to disk as a JSON sidecar (the portable
% interchange form) or the per-channel table as CSV/XLSX.
%
% Syntax:
%   tbl = pf2.probe.montage(data)
%   tbl = pf2.probe.montage('fNIR_Devices_fNIR1000.cfg')
%   tbl = pf2.probe.montage(dev)                       % a pf2.Device object
%   [tbl, descriptor] = pf2.probe.montage(data)
%   tbl = pf2.probe.montage(data, 'SavePath', 'montage.json')
%   tbl = pf2.probe.montage(data, 'Brodmann', false)
%
% Inputs:
%   data         - fNIRS data struct (uses data.device or info.probename),
%                  a device config name string (e.g.
%                  'fNIR_Devices_fNIR1000.cfg'), or a pf2.Device object.
%   'Brodmann'   - Append nearest Brodmann area columns (default: true when
%                  the device has 3D MNI positions, false otherwise).
%                  Requires MNI coordinates; silently skipped without them.
%   'MaxDistance' - Max distance in mm for the Brodmann lookup (default: Inf)
%   'SavePath'   - Path to write the descriptor (default: '', no write).
%                  Extension selects the format:
%                    .json        -> JSON sidecar (montage + channels)
%                    .csv / .xlsx -> per-channel table only (writetable)
%
% Outputs:
%   tbl        - Per-channel montage table [nCh rows] with columns:
%                  Channel    - Channel index (1-based) [double]; includes
%                               short-separation channels
%                  Source     - Source optode index [double]
%                  Detector   - Detector optode index [double]
%                  X_mni      - MNI x in device coordinate units [double]
%                  Y_mni      - MNI y [double]
%                  Z_mni      - MNI z [double]
%                  SD_mm      - Source-detector distance [double]
%                  ShortSep   - Short-separation channel flag [logical]
%                  BA         - Nearest Brodmann area number [double] (if requested)
%                  BA_name    - Brodmann area name [string] (if requested)
%                  BA_dist_mm - Distance to that BA in mm [double] (if requested)
%                Position/BA/Source/Detector columns are NaN/<missing> when
%                unavailable.
%   descriptor - Montage-level descriptor struct with fields:
%                  .formatVersion    - Descriptor schema version [char]
%                  .device           - name/manufacturer/model/nChannels/nShortSep
%                  .samplingRateHz   - Default sampling rate [double]
%                  .wavelengths      - Unique wavelengths in nm [1 x W]
%                                      (the set, not a per-channel map)
%                  .data             - units/dpfMode/dpfFactor when the input
%                                      is a processed data struct (else empty)
%                  .coordinateSystem - system/units/referenceHead/provenance/
%                                      registrationMethod/hasMNI
%                  .channels         - Struct array mirroring the table rows,
%                                      plus per-channel source/detector and
%                                      nonzero wavelengths
%
% Algorithm:
%   1. Resolve a pf2.Device from the data struct, config name, or object
%   2. Read per-channel geometry (MNI, SD distance, short-sep flag)
%   3. Optionally look up the nearest Brodmann area per channel (3D only)
%   4. Assemble the per-channel table and the montage-level descriptor
%   5. Optionally serialize to JSON / CSV / XLSX
%
% Example:
%   % Inspect the montage of a sample dataset
%   data = pf2.import.sampleData();
%   tbl = pf2.probe.montage(data)
%
%   % Write a portable JSON sidecar next to an export
%   [tbl, descriptor] = pf2.probe.montage(data, 'SavePath', 'sub-01_montage.json');
%
%   % Geometry only, no atlas lookup, straight from a config name
%   tbl = pf2.probe.montage('fNIR_Devices_fNIR1000.cfg', 'Brodmann', false);
%
% Notes:
%   - Brodmann lookup assumes MNI space; results are a group-level
%     approximation for idealized-template coordinates (see nearestBrodmann).
%   - Layout-only devices (no optode coordinates) still export a descriptor;
%     the position and BA columns are simply NaN/<missing>.
%
% See also: pf2.Device, pf2.probe.nearestBrodmann, pf2.data.infoToTable,
%           pf2.probe.transformToMNI

% --- Parse inputs ---
arguments
    data
    opts.Brodmann = []
    opts.MaxDistance (1,1) {mustBeNumeric} = Inf
    opts.SavePath = ''
end

maxDist = opts.MaxDistance;
savePath = char(opts.SavePath);

% --- Resolve a pf2.Device ---
[dev, baSource] = resolveDevice(data);

hasMNI = dev.hasMNI();

% Default Brodmann to on only when 3D positions exist
doBrodmann = opts.Brodmann;
if isempty(doBrodmann)
    doBrodmann = hasMNI;
else
    doBrodmann = logical(doBrodmann);
    if doBrodmann && ~hasMNI
        warning('pf2:probe:montage:noMNI', ...
            ['Brodmann lookup requested but device ''%s'' has no 3D MNI ', ...
             'positions; skipping atlas columns.'], dev.name);
        doBrodmann = false;
    end
end

% --- Per-channel geometry ---
nCh = dev.nChannels;
chan = (1:nCh)';

pos = dev.mniPositions();              % [nCh x 3] or []
if isempty(pos) || size(pos, 1) ~= nCh
    pos = nan(nCh, 3);
end

sd = dev.sdDistances();                % [1 x nCh]
sd = forceColumn(sd, nCh);

% isShortSep accesses TableOpt.IsShortSeparation directly; some in-memory
% (e.g. SNIRF) device builds may lack that column, so guard the access and
% default to all-false rather than letting it throw far from the call site.
try
    ss = dev.isShortSep();             % [1 x nCh] logical-ish
catch
    ss = [];
end
if isempty(ss) || numel(ss) ~= nCh
    ss = false(nCh, 1);
else
    ss = logical(ss(:));
end

% Source / detector indices and per-channel wavelengths (for SNIRF round-trip
% and to express which channels share an optode). NaN/empty where the device
% config does not carry them (e.g. layout-only devices).
optTbl = dev.optodeTable();
src = optColumn(optTbl, {'SrcIdx', 'SourceIndex', 'Source'}, nCh);
det = optColumn(optTbl, {'DetIdx', 'DetectorIndex', 'Detector'}, nCh);
wvPer = perChannelWavelengths(optTbl, nCh);

% --- Brodmann lookup (optional) ---
baNum  = nan(nCh, 1);
baName = strings(nCh, 1);
baDist = nan(nCh, 1);
if doBrodmann
    try
        baTbl = pf2.probe.nearestBrodmann(baSource, 'N', 1, 'MaxDistance', maxDist);
        for r = 1:height(baTbl)
            ch = baTbl.Channel(r);
            if ch >= 1 && ch <= nCh
                baNum(ch)  = baTbl.BA(r);
                baName(ch) = baTbl.Name(r);
                baDist(ch) = baTbl.Distance_mm(r);
            end
        end
    catch ME
        warning('pf2:probe:montage:brodmannFailed', ...
            'Brodmann lookup failed (%s); exporting geometry only.', ME.message);
        doBrodmann = false;
    end
end

% --- Assemble per-channel table ---
tbl = table(chan, src, det, pos(:,1), pos(:,2), pos(:,3), sd, ss, ...
    'VariableNames', {'Channel', 'Source', 'Detector', ...
    'X_mni', 'Y_mni', 'Z_mni', 'SD_mm', 'ShortSep'});
if doBrodmann
    tbl.BA = baNum;
    tbl.BA_name = baName;
    tbl.BA_dist_mm = baDist;
end

% --- Assemble montage-level descriptor ---
descriptor = struct();
descriptor.formatVersion = '1.0';

descriptor.device = struct( ...
    'name', char(dev.name), ...
    'manufacturer', char(dev.manufacturer), ...
    'model', char(dev.model), ...
    'nChannels', dev.nChannels, ...
    'nShortSep', dev.nShortSep);

descriptor.samplingRateHz = dev.defaultFs;
descriptor.wavelengths = dev.wavelengthSet(:)';   % unique set, not per-channel

% Data context (units/DPF) when the input is a processed data struct. Lets a
% shared sidecar be self-describing and guards against pooling datasets with
% mismatched units/DPF downstream (see pf2.probe.canonicalize).
descriptor.data = dataContext(data);

descriptor.coordinateSystem = struct( ...
    'system', char(dev.CoordinateSystem), ...
    'units', char(dev.CoordinateUnits), ...
    'referenceHead', char(dev.ReferenceHead), ...
    'provenance', char(dev.CoordinateProvenance), ...
    'registrationMethod', char(dev.RegistrationMethod), ...
    'hasMNI', hasMNI);

% Per-channel array mirroring the table (struct array for clean JSON)
chans = struct('channel', cell(1, nCh));
for k = 1:nCh
    chans(k).channel = chan(k);
    chans(k).source = src(k);
    chans(k).detector = det(k);
    chans(k).mni = [pos(k,1), pos(k,2), pos(k,3)];
    chans(k).sd_mm = sd(k);
    chans(k).shortSep = ss(k);
    chans(k).wavelengths = wvPer{k};
    if doBrodmann
        chans(k).ba = baNum(k);
        chans(k).baName = char(baName(k));
        chans(k).baDist_mm = baDist(k);
    end
end
descriptor.channels = chans;

% --- Optional serialization ---
if ~isempty(savePath)
    writeDescriptor(savePath, tbl, descriptor);
end

end

%%_Subfunctions_________________________________________________________

function [dev, baSource] = resolveDevice(data)
% RESOLVEDEVICE Resolve a pf2.Device and a source for Brodmann lookup
%
% Inputs:
%   data - fNIRS data struct, device config name, or pf2.Device object
%
% Outputs:
%   dev      - pf2.Device instance
%   baSource - Argument to pass to pf2.probe.nearestBrodmann (the original
%              data struct when available, else the device config name)

if isa(data, 'pf2.Device')
    dev = data;
    baSource = dev.name;
elseif isstruct(data)
    if isfield(data, 'device') && isa(data.device, 'pf2.Device')
        dev = data.device;
    else
        dev = pf2.Device.load(data);
    end
    baSource = data;   % nearestBrodmann handles structs directly
elseif ischar(data) || isstring(data)
    dev = pf2.Device.load(char(data));
    baSource = char(data);
else
    error('pf2:probe:montage:badInput', ...
        'Input must be an fNIRS data struct, a device config name, or a pf2.Device.');
end

end

function col = optColumn(optTbl, names, n)
% OPTCOLUMN Read the first matching per-channel column as an [n x 1] vector
%
% Inputs:
%   optTbl - Optode table (TableOpt) or [] / non-table
%   names  - Candidate column names (first present wins)
%   n      - Required length
%
% Outputs:
%   col - [n x 1] double (NaN-filled if no matching column is present)

col = nan(n, 1);
if ~istable(optTbl)
    return;
end
for i = 1:numel(names)
    if ismember(names{i}, optTbl.Properties.VariableNames)
        v = double(optTbl.(names{i}));
        col = forceColumn(v, n);
        return;
    end
end

end

function wvPer = perChannelWavelengths(optTbl, n)
% PERCHANNELWAVELENGTHS Nonzero wavelength set for each channel
%
% Inputs:
%   optTbl - Optode table (TableOpt) with a 'wv' wavelength matrix, or []
%   n      - Channel count
%
% Outputs:
%   wvPer - 1 x n cell; each cell is the channel's nonzero wavelengths (nm),
%           or [] if no per-channel wavelength info is available.

wvPer = repmat({[]}, 1, n);
if ~istable(optTbl) || ~ismember('wv', optTbl.Properties.VariableNames)
    return;
end
wv = optTbl.wv;
m = min(size(wv, 1), n);
for k = 1:m
    row = wv(k, :);
    wvPer{k} = row(row > 0 & ~isnan(row));
end

end

function dc = dataContext(data)
% DATACONTEXT Extract units/DPF context from a processed data struct
%
% Inputs:
%   data - Original montage input (data struct, name, or pf2.Device)
%
% Outputs:
%   dc - Struct with fields units [char], dpfMode [char], dpfFactor [double].
%        Fields are empty when the input is not a processed data struct.

dc = struct('units', '', 'dpfMode', '', 'dpfFactor', []);
if ~isstruct(data)
    return;
end
if isfield(data, 'units')
    dc.units = char(string(data.units));
end
if isfield(data, 'DPF_factor')
    dc.dpfFactor = data.DPF_factor;
end
if isfield(data, 'processingInfo') && isstruct(data.processingInfo) ...
        && isfield(data.processingInfo, 'dpfMode')
    dc.dpfMode = char(string(data.processingInfo.dpfMode));
end

end

function v = forceColumn(v, n)
% FORCECOLUMN Coerce a vector to an [n x 1] column, padding with NaN
%
% Inputs:
%   v - Numeric vector (any orientation) or empty
%   n - Required length
%
% Outputs:
%   v - [n x 1] column vector (NaN-filled if input was empty/short)

if isempty(v) || numel(v) ~= n
    out = nan(n, 1);
    m = min(numel(v), n);
    if m > 0
        vv = v(:);
        out(1:m) = vv(1:m);
    end
    v = out;
else
    v = v(:);
end

end

function writeDescriptor(savePath, tbl, descriptor)
% WRITEDESCRIPTOR Serialize the montage to disk by file extension
%
% Inputs:
%   savePath   - Output path; extension selects format (.json/.csv/.xlsx)
%   tbl        - Per-channel montage table
%   descriptor - Montage-level descriptor struct
%
% Outputs:
%   (none) - Writes the file to disk.

[outDir, ~, ext] = fileparts(savePath);
if ~isempty(outDir) && exist(outDir, 'dir') ~= 7
    [ok, msg] = mkdir(outDir);
    if ~ok
        error('pf2:probe:montage:mkdirFailed', ...
            'Could not create output directory %s: %s', outDir, msg);
    end
end

switch lower(ext)
    case '.json'
        txt = jsonencode(descriptor, 'PrettyPrint', true);
        % UTF-8 so any non-ASCII device/area names serialize correctly.
        fid = fopen(savePath, 'w', 'n', 'UTF-8');
        if fid == -1
            error('pf2:probe:montage:writeFailed', ...
                'Could not open %s for writing.', savePath);
        end
        cleanup = onCleanup(@() fclose(fid));
        fprintf(fid, '%s', txt);
    case {'.csv', '.xlsx', '.xls', '.txt'}
        writetable(tbl, savePath);
    otherwise
        error('pf2:probe:montage:badExtension', ...
            ['Unsupported SavePath extension ''%s''. Use .json (descriptor) ', ...
             'or .csv/.xlsx (per-channel table).'], ext);
end

end
