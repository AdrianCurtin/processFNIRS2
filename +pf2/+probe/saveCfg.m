function outPath = saveCfg(source, savePath, opts)
% SAVECFG Write a probe's geometry to a device .cfg file
%
% Serializes the probe geometry carried by a pf2.Device (typically built by
% importing a SNIRF file) into a toolbox-native device .cfg file, the same
% INI-style format consumed by pf2_base.loadDeviceCfg / pf2.Device.load. This
% lets a montage that arrived as SNIRF be reused as a named, reloadable device
% config, plotted, atlas-looked-up, and shared without the original SNIRF.
%
% The geometry is reconstructed from the canonical device tables (TableSD,
% TableOpt, TableCh), so it works for any source that produces a pf2.Device,
% not just SNIRF. It writes "as much as can be figured out": the source and
% detector coordinates, the per-raw-column channel/wavelength mapping, the
% source-detector index mapping, and the available coordinate-system metadata.
% Fields a SNIRF cannot supply (e.g. RawMax/RawMin saturation bounds, a 2D
% schematic layout) are omitted; on reload, loadDeviceCfg derives the 2D layout
% from the 3D coordinates.
%
% Syntax:
%   outPath = pf2.probe.saveCfg(data, 'myprobe.cfg')
%   outPath = pf2.probe.saveCfg('recording.snirf', 'myprobe.cfg')
%   outPath = pf2.probe.saveCfg(dev, 'myprobe.cfg')
%   outPath = pf2.probe.saveCfg(data, 'myprobe.cfg', 'Name', 'My Probe')
%
% Inputs:
%   source   - One of:
%                * fNIRS data struct (uses data.device, or info.probename)
%                * pf2.Device object
%                * path to a .snirf file (imported with pf2.import.importSNIRF)
%                * a device config name (e.g. 'fNIR_Devices_fNIR1000')
%   savePath - Output path for the .cfg file. A '.cfg' extension is appended
%              if missing. The file base name becomes the CfgName/Name default.
%   varargin - Optional name-value pairs:
%       'Name'            - Device display name written to [Info].Name
%                           (default: device model, else the CfgName).
%       'Manufacturer'    - [Info].Manufacturer (default: device manufacturer).
%       'CoordinateUnits' - Units of the 3D coordinates being written, used to
%                           label [Info].CoordinateUnits. Optode positions are
%                           held in millimetres internally, so this defaults to
%                           'mm' and is written verbatim (no rescaling). Set it
%                           only if you know the coordinates are in other units.
%       'CoordinateSystem' - [Info].CoordinateSystem (e.g. 'MNI'). Default: the
%                           device's coordinate system, else 'Unknown'. A SNIRF
%                           that does not declare its space imports as 'Other'
%                           or 'Unknown'; set this when you know the space.
%       'RegistrationMethod' - [Info].RegistrationMethod, how the positions were
%                           obtained (e.g. 'template', 'CapTrak-digitized').
%                           Default: the device value, else 'unspecified'.
%       'CoordinateProvenance' - [Info].CoordinateProvenance (e.g.
%                           'idealized-template', 'subject-digitized').
%                           Default: the device value, else 'unspecified'.
%       'ReferenceHead'   - [Info].ReferenceHead, the reference head/template
%                           for the 3D coordinates (e.g. 'MNI152'). Default: the
%                           device value, else 'unspecified'.
%       'SamplingRate'    - [Info].DefaultSamplingRate in Hz (default: the
%                           device default rate, else data.fs when available).
%       'Overwrite'       - Overwrite an existing file (default: true). When
%                           false, an existing target raises an error.
%
% Outputs:
%   outPath - Path to the written .cfg file (the supplied savePath, with a
%             '.cfg' extension ensured).
%
% Algorithm:
%   1. Resolve a pf2.Device from the source (importing a .snirf if given one).
%   2. Pull the unique source and detector positions from TableSD, the
%      per-channel source/detector indices from TableOpt, and the per-raw-column
%      optode/wavelength mapping from TableCh.
%   3. Write 3D coordinates (DetPos3D*/SrcPos3D*) in mm when present. Also write
%      the 2D layout (DetPos*/SrcPos*, in cm) when it is metric-consistent with
%      the per-channel SD, so a device's intended planar source-detector
%      distances survive the round trip; otherwise the 2D layout is left for
%      loadDeviceCfg to re-derive from 3D. When no 3D exists, the 2D layout is
%      always written.
%   4. Assemble [Info] and [Probe1] sections and serialize with the INI writer.
%
% Example:
%   % Round-trip a SNIRF montage into a reusable device config
%   data = pf2.import.importSNIRF('sub-01_nirs.snirf');
%   pf2.probe.saveCfg(data, 'myprobe.cfg');
%   dev = pf2.Device.load('myprobe');     % reload the written config
%   dev.mniPositions()                    % geometry preserved
%
% Notes:
%   - Optode 3D coordinates are stored in millimetres internally; this writer
%     emits the 3D fields unchanged and labels CoordinateUnits 'mm'. The 2D
%     layout fields follow the cfg convention of centimetres, scaled from the
%     stored layout when it is metric. A SNIRF montage whose only 2D layout is
%     a flat projection (dropping z) is written 3D-only; loadDeviceCfg then
%     re-derives the 2D layout (a 'pf2:loadDeviceCfg:no2DPositions' notice).
%   - Saturation bounds (RawMax/RawMin) are written only when the device
%     declares them (SNIRF does not, so they are omitted there).
%   - Only the first probe of a multi-probe device is written (a warning is
%     raised); landmarks/fiducials are not written (no standard cfg section).
%
% See also: pf2.Device, pf2_base.loadDeviceCfg, pf2.probe.montage,
%           pf2.import.importSNIRF, pf2_base.external.INI

% --- Parse inputs ---
arguments
    source
    savePath {mustBeText}
    opts.Name = ''
    opts.Manufacturer = ''
    opts.CoordinateUnits = ''
    opts.CoordinateSystem = ''
    opts.RegistrationMethod = ''
    opts.CoordinateProvenance = ''
    opts.ReferenceHead = ''
    opts.SamplingRate = []
    opts.Overwrite (1,1) logical = true
end

savePath = char(savePath);
if ~endsWith(lower(savePath), '.cfg')
    savePath = [savePath '.cfg'];
end
if ~opts.Overwrite && exist(savePath, 'file')
    error('pf2:probe:saveCfg:fileExists', ...
        'Target file already exists (set ''Overwrite'', true to replace): %s', savePath);
end

[~, cfgBase] = fileparts(savePath);

% --- Resolve a pf2.Device (importing a .snirf if needed) ---
[dev, srcFs] = resolveDevice(source);

if numel(dev.probeInfo.Probe) > 1
    warning('pf2:probe:saveCfg:multiProbe', ...
        ['Device ''%s'' has %d probes; only Probe{1} is written to the cfg ' ...
         '(the cfg single-probe target).'], dev.name, numel(dev.probeInfo.Probe));
end
P = dev.probeInfo.Probe{1};
if ~isfield(P, 'TableSD') || ~istable(P.TableSD) || isempty(P.TableSD)
    error('pf2:probe:saveCfg:noGeometry', ...
        'Device ''%s'' has no source/detector table; cannot write a probe cfg.', dev.name);
end

% --- Unique source / detector positions from TableSD ---
sd = P.TableSD;
typeStr = string(sd.Type);
srcT = sortrows(sd(typeStr == "Src", :), 'Index');
detT = sortrows(sd(typeStr == "Det", :), 'Index');
if isempty(srcT) || isempty(detT)
    error('pf2:probe:saveCfg:noOptodes', ...
        'Device ''%s'' has no resolvable sources or detectors.', dev.name);
end

vars = sd.Properties.VariableNames;
% Any non-zero coordinate on ANY axis counts as real 3D geometry (a midline
% montage can sit at x=0 yet still carry valid y/z).
has3D = all(ismember({'Pos3D_x','Pos3D_y','Pos3D_z'}, vars)) ...
    && (anyReal(sd.Pos3D_x) || anyReal(sd.Pos3D_y) || anyReal(sd.Pos3D_z));
has2D = all(ismember({'Pos2D_x','Pos2D_y'}, vars)) && anyReal(sd.Pos2D_x);
has2Dz = ismember('Pos2D_z', vars);

if ~has3D && ~has2D
    error('pf2:probe:saveCfg:noPositions', ...
        'Device ''%s'' carries no 2D or 3D optode positions to write.', dev.name);
end

% --- Per-channel source/detector index mapping ---
opt = P.TableOpt;
if ~all(ismember({'SrcIdx','DetIdx'}, opt.Properties.VariableNames))
    error('pf2:probe:saveCfg:noChannelMap', ...
        'Device ''%s'' has no per-channel source/detector index mapping.', dev.name);
end
sI = rowVec(opt.SrcIdx);
dI = rowVec(opt.DetIdx);
if max(sI) > height(srcT) || max(dI) > height(detT) || min([sI dI]) < 1
    error('pf2:probe:saveCfg:indexOutOfRange', ...
        ['Device ''%s'' has source/detector indices that do not map onto its ' ...
         'optode list (non-contiguous montage); cannot write a faithful cfg.'], dev.name);
end

% --- Per-raw-column channel and wavelength mapping (full .raw format) ---
ch = P.TableCh;
channelNumbers = rowVec(ch.OptodeNumber);
% Restore the time-column sentinel (0): loadDeviceCfg replaces it with NaN in
% OptodeNumber on read, so recover it from the isTime flag for a faithful
% .raw-format ChannelNumbers row.
if ismember('isTime', ch.Properties.VariableNames)
    channelNumbers(logical(ch.isTime)) = 0;
end
wavelength = rowVec(ch.Wavelength);   % NaN=time, 0=dark (matches cfg convention)

% --- Assemble [Probe1] ---
probe1 = struct();
probe1.ChannelNumbers = channelNumbers;
probe1.Wavelength = wavelength;

% Decide whether to also emit the bespoke 2D layout. loadDeviceCfg computes SD
% (and short-separation flags) from the 2D fields, treating them as cm; if we
% emit only 3D it re-derives 2D by scaling, which silently changes a device's
% intended planar SD. So preserve the 2D layout when it is metric-consistent
% with the authoritative per-channel SD (TableOpt.SD, cm), scaling its native
% units to cm via that ratio. SNIRF montages whose 2D drops the z component
% (so 2D distance != SD) fail the consistency test and fall back to 3D-only,
% which round-trips exactly because loadDeviceCfg's derived 2D keeps z.
[write2D, scale2d] = layout2DScale(srcT, detT, sI, dI, has2D, has2Dz, opt);
if ~has3D
    write2D = has2D;            % 2D is all we have; emit it regardless
    if isnan(scale2d), scale2d = 1; end
end

coordUnits = char(opts.CoordinateUnits);
if isempty(coordUnits)
    if has3D, coordUnits = 'mm'; else, coordUnits = 'cm'; end
end

if write2D
    probe1.SrcPosX = rowVec(srcT.Pos2D_x) * scale2d;
    probe1.SrcPosY = rowVec(srcT.Pos2D_y) * scale2d;
    probe1.DetPosX = rowVec(detT.Pos2D_x) * scale2d;
    probe1.DetPosY = rowVec(detT.Pos2D_y) * scale2d;
    if has2Dz
        probe1.SrcPosZ = rowVec(srcT.Pos2D_z) * scale2d;
        probe1.DetPosZ = rowVec(detT.Pos2D_z) * scale2d;
    end
end
if has3D
    probe1.SrcPos3DX = rowVec(srcT.Pos3D_x);   % mm, verbatim
    probe1.SrcPos3DY = rowVec(srcT.Pos3D_y);
    probe1.SrcPos3DZ = rowVec(srcT.Pos3D_z);
    probe1.DetPos3DX = rowVec(detT.Pos3D_x);
    probe1.DetPos3DY = rowVec(detT.Pos3D_y);
    probe1.DetPos3DZ = rowVec(detT.Pos3D_z);
end

probe1.sI = sI;
probe1.dI = dI;

% --- Assemble [Info] ---
info = struct();
info.CoordinateSystem     = override(opts.CoordinateSystem, dev.CoordinateSystem, 'Unknown');
info.CoordinateUnits      = coordUnits;
info.RegistrationMethod   = override(opts.RegistrationMethod, dev.RegistrationMethod, 'unspecified');
info.CoordinateProvenance = override(opts.CoordinateProvenance, dev.CoordinateProvenance, 'unspecified');
info.ReferenceHead        = override(opts.ReferenceHead, dev.ReferenceHead, 'unspecified');
info.CfgName              = cfgBase;

devName = char(opts.Name);
if isempty(devName), devName = orDefault(dev.model, cfgBase); end
info.Name = devName;

manu = char(opts.Manufacturer);
if isempty(manu), manu = orDefault(dev.manufacturer, 'Unknown'); end
info.Manufacturer = manu;

fs = opts.SamplingRate;
if isempty(fs), fs = dev.defaultFs; end
if isempty(fs) || ~isfinite(fs)
    fs = srcFs;
end
if ~isempty(fs) && isfinite(fs)
    % Round away float noise from timestamp-derived rates (keeps genuine
    % fractional rates like 7.8125 Hz; collapses 10.0000000000091 -> 10).
    info.DefaultSamplingRate = round(fs, 4);
end

info.NumberChannels   = dev.nChannels;
info.NumberProbes     = 1;
info.TimeIsSampleCount = 0;

if isfinite(dev.rawMax), info.RawMax = dev.rawMax; end
if isfinite(dev.rawMin), info.RawMin = dev.rawMin; end

% --- Ensure the output directory exists ---
outDir = fileparts(savePath);
if ~isempty(outDir) && ~exist(outDir, 'dir')
    [ok, msg] = mkdir(outDir);
    if ~ok
        error('pf2:probe:saveCfg:mkdirFailed', ...
            'Could not create output directory ''%s'': %s', outDir, msg);
    end
end

% --- Serialize ---
cfg = pf2_base.external.INI('File', savePath);
cfg.add('Info', info);
cfg.add('Probe1', probe1);
cfg.write();

outPath = savePath;

emitted = strjoin([repmat({'3D'}, 1, has3D), repmat({'2D'}, 1, write2D)], '+');
fprintf('Wrote device config: %s\n', outPath);
fprintf('  %d channels, %d sources, %d detectors, units ''%s'' (%s positions)\n', ...
    dev.nChannels, height(srcT), height(detT), coordUnits, emitted);

end

% ------------------------------------------------------------------------
function [dev, srcFs] = resolveDevice(source)
% RESOLVEDEVICE Resolve a pf2.Device and (optional) sampling rate from a source
%
% Inputs:
%   source - pf2.Device, data struct, .snirf path, or device config name
%
% Outputs:
%   dev   - pf2.Device instance
%   srcFs - sampling rate from the source data when available, else NaN

srcFs = NaN;

if isa(source, 'pf2.Device')
    dev = source;
    return;
end

if isstruct(source)
    if isfield(source, 'fs') && isscalar(source.fs)
        srcFs = source.fs;
    end
    if isfield(source, 'device') && isa(source.device, 'pf2.Device')
        dev = source.device;
    else
        dev = pf2.Device.load(source);
    end
    return;
end

if ischar(source) || isstring(source)
    s = char(source);
    if endsWith(lower(s), '.snirf')
        data = pf2.import.importSNIRF(s);
        if isfield(data, 'fs') && isscalar(data.fs)
            srcFs = data.fs;
        end
        if isfield(data, 'device') && isa(data.device, 'pf2.Device')
            dev = data.device;
        else
            error('pf2:probe:saveCfg:noDevice', ...
                'Imported SNIRF ''%s'' did not yield a pf2.Device.', s);
        end
    else
        dev = pf2.Device.load(s);
    end
    return;
end

error('pf2:probe:saveCfg:badInput', ...
    ['Source must be an fNIRS data struct, a pf2.Device, a .snirf file ' ...
     'path, or a device config name.']);
end

% ------------------------------------------------------------------------
function v = rowVec(x)
% ROWVEC Coerce a column/table column to a numeric row vector
v = double(x);
v = v(:)';
end

% ------------------------------------------------------------------------
function out = orDefault(val, dflt)
% ORDEFAULT Return val as char if nonempty, else the default
if isempty(val)
    out = dflt;
else
    out = char(val);
end
end

% ------------------------------------------------------------------------
function out = override(userVal, devVal, dflt)
% OVERRIDE Pick the user-supplied value, else the device value, else default
if ~isempty(userVal)
    out = char(userVal);
else
    out = orDefault(devVal, dflt);
end
end

% ------------------------------------------------------------------------
function tf = anyReal(v)
% ANYREAL True if any element is finite and non-zero
v = double(v);
tf = any(~isnan(v) & v ~= 0);
end

% ------------------------------------------------------------------------
function [write2D, scale2d] = layout2DScale(srcT, detT, sI, dI, has2D, has2Dz, opt)
% LAYOUT2DSCALE Decide whether the 2D layout is metric and find its cm scale
%
% Computes per-channel source-detector distances from the 2D layout (in its
% native units) and compares them to the authoritative per-channel SD
% (TableOpt.SD, cm). When the ratio is constant across channels the 2D layout
% is metric (distance-preserving), so it can be faithfully written by scaling
% to cm with that ratio. A non-constant ratio (e.g. a 2D projection that drops
% the z component) means the 2D layout would not reproduce SD, so it is not
% written and the caller falls back to 3D.
%
% Inputs:
%   srcT, detT - sorted source/detector TableSD rows (Pos2D_x/y[/z])
%   sI, dI     - per-channel source/detector indices [1 x nCh]
%   has2D      - whether a usable 2D layout is present
%   has2Dz     - whether a Pos2D_z column exists
%   opt        - TableOpt (read for the SD column)
%
% Outputs:
%   write2D - true if the 2D layout is metric and should be emitted
%   scale2d - native-units -> cm scale factor (NaN if undeterminable)

write2D = false;
scale2d = NaN;
if ~has2D || ~ismember('SD', opt.Properties.VariableNames)
    return;
end

dd = (srcT.Pos2D_x(sI) - detT.Pos2D_x(dI)).^2 ...
   + (srcT.Pos2D_y(sI) - detT.Pos2D_y(dI)).^2;
if has2Dz
    dd = dd + (srcT.Pos2D_z(sI) - detT.Pos2D_z(dI)).^2;
end
d2 = sqrt(rowVec(dd));
optSD = rowVec(opt.SD);

valid = isfinite(d2) & d2 > 1e-6 & isfinite(optSD) & optSD > 1e-6;
if ~any(valid)
    return;
end
ratios = optSD(valid) ./ d2(valid);
scale2d = median(ratios);
% Metric if every channel's ratio matches the median within 2%.
if scale2d > 0 && all(abs(ratios - scale2d) <= 0.02 * scale2d)
    write2D = true;
end
end
