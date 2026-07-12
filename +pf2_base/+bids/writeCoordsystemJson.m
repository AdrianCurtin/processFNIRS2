function writeCoordsystemJson(filepath, data, nirs)
% WRITECOORDSYSTEMJSON Write a BIDS-NIRS _coordsystem.json
%
% Declares the coordinate space of the optode positions in _optodes.tsv. The
% device's coordinate system is mapped onto a BIDS-recognized identifier when
% possible, otherwise 'Other' with a description (as BIDS requires). Units are
% taken from the device, constrained to BIDS-allowed values.
%
% Inputs:
%   filepath - output _coordsystem.json path
%   data     - fNIRS data struct (for data.device)
%   nirs     - SNIRF /nirs structure (fallback metadata)
%
% Outputs:
%   (none) - Writes the file to disk.
%
% Example:
%   pf2_base.bids.writeCoordsystemJson('sub-01_coordsystem.json', data, nirs);
%
% See also: pf2_base.bids.writeOptodesTsv, pf2.import.importSNIRF

sysName = '';
sysDesc = '';
units = '';

if isstruct(data) && isfield(data, 'device') && isa(data.device, 'pf2.Device')
    dev = data.device;
    sysName = char(dev.CoordinateSystem);
    sysDesc = char(dev.CoordinateSystemDescription);
    units = char(dev.CoordinateUnits);
end

% Fall back to the SNIRF probe coordinate-system tag if device is absent.
if isempty(sysName) && isfield(nirs, 'probe') && isfield(nirs.probe, 'coordinateSystem')
    sysName = char(nirs.probe.coordinateSystem);
end

[bidsSys, bidsDesc] = mapSystem(sysName, sysDesc);

s = struct();
s.NIRSCoordinateSystem = bidsSys;
s.NIRSCoordinateUnits = mapUnits(units);
if strcmp(bidsSys, 'Other') || ~isempty(bidsDesc)
    if isempty(bidsDesc)
        bidsDesc = 'Probe-specific coordinate system (unspecified).';
    end
    s.NIRSCoordinateSystemDescription = bidsDesc;
end

pf2_base.bids.writeJson(filepath, s);
end

function [bidsSys, desc] = mapSystem(sysName, sysDesc)
% Map a device coordinate-system string to a BIDS-recognized identifier.
%
% Only exact, specific BIDS template identifiers are passed through. A generic
% 'MNI' tag (as pf2 device cfgs declare) is NOT promoted to a specific MNI
% template — doing so would assert a registration the montage coordinates were
% never computed against. Such cases become 'Other' with a description, which
% is faithful and still validator-legal.
desc = sysDesc;
key = lower(strtrim(sysName));
switch key
    case {'mni152nlin2009casym'}
        bidsSys = 'MNI152NLin2009cAsym';
    case {'mni152nlin6asym'}
        bidsSys = 'MNI152NLin6Asym';
    case {'fsaverage'}
        bidsSys = 'fsaverage';
    case {'captrak'}
        bidsSys = 'CapTrak';
    otherwise
        bidsSys = 'Other';
        if isempty(desc)
            if isempty(sysName)
                desc = 'Probe-specific coordinate system (unspecified).';
            elseif any(strcmp(key, {'mni', 'mni152', 'icbm', 'mnicolin27'}))
                desc = sprintf(['Generic MNI atlas template coordinates ' ...
                    '(device tag: %s); not registered to a specific MNI ' ...
                    'template version.'], sysName);
            else
                desc = sprintf('Device coordinate system: %s.', sysName);
            end
        end
end
end

function u = mapUnits(units)
% Constrain to BIDS-allowed coordinate units; default mm.
key = lower(strtrim(units));
switch key
    case {'m', 'meter', 'meters'}
        u = 'm';
    case {'cm', 'centimeter', 'centimeters'}
        u = 'cm';
    case {'mm', 'millimeter', 'millimeters'}
        u = 'mm';
    otherwise
        u = 'mm';
end
end
