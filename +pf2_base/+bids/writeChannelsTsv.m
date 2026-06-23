function writeChannelsTsv(filepath, data, nirs)
% WRITECHANNELSTSV Write a BIDS-NIRS _channels.tsv
%
% Emits one row per measurement (source-detector-wavelength) in the SNIRF
% measurement list, with the BIDS-required columns name, type, source,
% detector, wavelength_nominal, units plus the recommended sampling_frequency
% and a status column derived from data.fchMask when its length matches the
% channel count.
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

% Channel-aligned status from fchMask only when lengths agree (asSNIRF strips
% time/marker columns, so a raw-width mask cannot be mapped reliably here).
useStatus = false;
mask = [];
if isstruct(data) && isfield(data, 'fchMask') && ~isempty(data.fchMask) ...
        && numel(data.fchMask) == nCh
    mask = logical(data.fchMask);
    useStatus = true;
end

if useStatus
    headers = {'name', 'type', 'source', 'detector', 'wavelength_nominal', ...
        'wavelength_actual', 'units', 'sampling_frequency', 'status'};
else
    headers = {'name', 'type', 'source', 'detector', 'wavelength_nominal', ...
        'wavelength_actual', 'units', 'sampling_frequency'};
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

    units = 'n/a';
    if isfield(m, 'dataUnit') && ~isempty(m.dataUnit)
        units = char(m.dataUnit);
    end

    rows{k, 1} = name;
    rows{k, 2} = 'NIRSCWAMPLITUDE';
    rows{k, 3} = sLab;
    rows{k, 4} = dLab;
    rows{k, 5} = wlNom;
    rows{k, 6} = wlAct;
    rows{k, 7} = units;
    rows{k, 8} = fs;
    if useStatus
        if mask(k)
            rows{k, 9} = 'good';
        else
            rows{k, 9} = 'bad';
        end
    end
end

pf2_base.bids.writeTsv(filepath, headers, rows);
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
