function writeChannelsTsv(filepath, data, nirs)
% WRITECHANNELSTSV Write a BIDS-NIRS _channels.tsv
%
% Emits one row per measurement (source-detector-wavelength) in the SNIRF
% measurement list, with the BIDS-required columns in their required order
% (name, type, source, detector, wavelength_nominal, units) followed by the
% recommended wavelength_actual, sampling_frequency, and a status column
% (good/bad) derived from data.fchMask when it can be mapped to the channels.
%
% Inputs:
%   filepath - output _channels.tsv path
%   data     - fNIRS data struct (for fs and fchMask)
%   nirs     - SNIRF /nirs structure from pf2.export.asSNIRF
%
% Outputs:
%   (none) - Writes the file to disk.
%
% Example:
%   pf2_base.bids.writeChannelsTsv('sub-01_task-rest_channels.tsv', data, nirs);
%
% See also: pf2_base.bids.writeOptodesTsv, pf2_base.bids.labelFor

ml = nirs.data.measurementList;
probe = nirs.probe;
nCh = numel(ml);
fs = pf2_base.bids.samplingFreq(data, nirs);

srcLabels = getField(probe, 'sourceLabels');
detLabels = getField(probe, 'detectorLabels');
wl = getField(probe, 'wavelengths');

% Per-measurement good/bad status, mapped from the per-channel (source-detector
% pair) fchMask. Returns [] when the mask cannot be mapped, in which case the
% optional status column is omitted rather than guessed.
status = channelStatus(data, ml, nCh);
useStatus = ~isempty(status);

% Required columns first, in the spec-mandated order, then recommended extras.
headers = {'name', 'type', 'source', 'detector', 'wavelength_nominal', ...
    'units', 'wavelength_actual', 'sampling_frequency'};
if useStatus
    headers{end+1} = 'status';
end

rows = cell(nCh, numel(headers));
for k = 1:nCh
    m = ml(k);
    sIdx = scalarOr(m, 'sourceIndex', NaN);
    dIdx = scalarOr(m, 'detectorIndex', NaN);
    sLab = pf2_base.bids.labelFor(srcLabels, 'S', sIdx);
    dLab = pf2_base.bids.labelFor(detLabels, 'D', dIdx);

    wlNom = NaN;
    wIdx = scalarOr(m, 'wavelengthIndex', NaN);
    if ~isnan(wIdx) && ~isempty(wl) && wIdx >= 1 && wIdx <= numel(wl)
        wlNom = wl(wIdx);
    end
    wlAct = scalarOr(m, 'wavelengthActual', NaN);

    if ~isnan(wlNom)
        name = sprintf('%s-%s %g', sLab, dLab, wlNom);
    else
        name = sprintf('%s-%s', sLab, dLab);
    end

    rows{k, 1} = name;
    rows{k, 2} = 'NIRSCWAMPLITUDE';
    rows{k, 3} = sLab;
    rows{k, 4} = dLab;
    rows{k, 5} = wlNom;
    rows{k, 6} = bidsUnits(m);
    rows{k, 7} = wlAct;
    rows{k, 8} = fs;
    if useStatus
        if status(k)
            rows{k, 9} = 'good';
        else
            rows{k, 9} = 'bad';
        end
    end
end

pf2_base.bids.writeTsv(filepath, headers, rows);
end

function u = bidsUnits(m)
% Map the SNIRF measurement unit to a BIDS-acceptable units token. Raw fNIRS
% CW amplitude is recorded as 'au' by pf2 devices; the BIDS-NIRS convention
% (and MNE-BIDS) is to label proportional-to-voltage raw amplitude 'V'.
u = 'n/a';
if isfield(m, 'dataUnit') && ~isempty(m.dataUnit)
    u = char(m.dataUnit);
end
switch lower(strtrim(u))
    case {'au', 'a.u.', 'arbitrary', ''}
        u = 'V';
end
end

function status = channelStatus(data, ml, nCh)
% Per-measurement good/bad logical from fchMask, mapped via source-detector
% pair (fchMask is per channel-pair; ml is per pair x wavelength). Returns []
% when a confident mapping is not possible.
status = [];
if ~isstruct(data) || ~isfield(data, 'fchMask') || isempty(data.fchMask)
    return;
end
mask = logical(data.fchMask(:));

% Direct case: mask already per measurement.
if numel(mask) == nCh
    status = mask;
    return;
end

% Pair case: build a (source,detector) -> good/bad map from the device optode
% table aligned with fchMask, then look up each measurement's pair.
if ~isfield(data, 'device') || ~isa(data.device, 'pf2.Device')
    return;
end
try
    opt = data.device.optodeTable();
catch
    return;
end
if ~istable(opt) || height(opt) ~= numel(mask)
    return;
end
srcCol = firstVar(opt, {'SrcIdx', 'SourceIndex', 'Source'});
detCol = firstVar(opt, {'DetIdx', 'DetectorIndex', 'Detector'});
if isempty(srcCol) || isempty(detCol)
    return;
end
srcVals = double(opt.(srcCol));
detVals = double(opt.(detCol));
map = containers.Map('KeyType', 'char', 'ValueType', 'logical');
for r = 1:numel(mask)
    map(sprintf('%d_%d', srcVals(r), detVals(r))) = mask(r);  % last wins on dup
end

status = true(nCh, 1);
for k = 1:nCh
    s = scalarOr(ml(k), 'sourceIndex', NaN);
    d = scalarOr(ml(k), 'detectorIndex', NaN);
    key = sprintf('%d_%d', s, d);
    if isKey(map, key)
        status(k) = map(key);
    end
end
end

function name = firstVar(tbl, candidates)
name = '';
for i = 1:numel(candidates)
    if ismember(candidates{i}, tbl.Properties.VariableNames)
        name = candidates{i};
        return;
    end
end
end

function v = getField(s, f)
if isstruct(s) && isfield(s, f)
    v = s.(f);
else
    v = [];
end
end

function v = scalarOr(s, f, default)
v = default;
if isfield(s, f) && ~isempty(s.(f))
    v = double(s.(f));
    v = v(1);
end
end
