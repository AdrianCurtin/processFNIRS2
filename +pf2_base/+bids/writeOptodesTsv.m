function writeOptodesTsv(filepath, nirs)
% WRITEOPTODESTSV Write a BIDS-NIRS _optodes.tsv
%
% Emits one row per source and detector optode with the BIDS-required columns
% name, type, x, y, z. 3D positions are used when present; otherwise the 2D
% layout populates x/y and z is 'n/a'. Missing coordinates render as 'n/a'.
%
% Inputs:
%   filepath - output _optodes.tsv path
%   nirs     - SNIRF /nirs structure from pf2.export.asSNIRF
%
% Outputs:
%   (none) - Writes the file to disk.
%
% Example:
%   pf2_base.bids.writeOptodesTsv('sub-01_task-rest_optodes.tsv', nirs);
%
% See also: pf2_base.bids.writeChannelsTsv, pf2_base.bids.writeCoordsystemJson

probe = nirs.probe;
headers = {'name', 'type', 'x', 'y', 'z'};

[srcXYZ, srcHas3D] = positions(probe, 'sourcePos3D', 'sourcePos2D');
[detXYZ, detHas3D] = positions(probe, 'detectorPos3D', 'detectorPos2D');

srcLabels = getField(probe, 'sourceLabels');
detLabels = getField(probe, 'detectorLabels');

nSrc = size(srcXYZ, 1);
nDet = size(detXYZ, 1);
rows = cell(nSrc + nDet, 5);

r = 0;
for i = 1:nSrc
    r = r + 1;
    rows(r, :) = optodeRow(pf2_base.bids.labelFor(srcLabels, 'S', i), ...
        'source', srcXYZ(i, :), srcHas3D);
end
for i = 1:nDet
    r = r + 1;
    rows(r, :) = optodeRow(pf2_base.bids.labelFor(detLabels, 'D', i), ...
        'detector', detXYZ(i, :), detHas3D);
end

pf2_base.bids.writeTsv(filepath, headers, rows);
end

function row = optodeRow(name, type, xyz, has3D)
% Build a single optode row; NaN coordinates -> 'n/a' via fmtCell.
z = xyz(3);
if ~has3D
    z = 'n/a';
end
row = {name, type, xyz(1), xyz(2), z};
end

function [xyz, has3D] = positions(probe, field3D, field2D)
% Prefer 3D positions; fall back to 2D (z absent). Returns [] when neither.
xyz = [];
has3D = false;
if isstruct(probe) && isfield(probe, field3D) && ~isempty(probe.(field3D))
    p = probe.(field3D);
    xyz = [p(:, 1), p(:, 2), p(:, 3)];
    has3D = true;
elseif isstruct(probe) && isfield(probe, field2D) && ~isempty(probe.(field2D))
    p = probe.(field2D);
    xyz = [p(:, 1), p(:, 2), nan(size(p, 1), 1)];
    has3D = false;
end
end

function v = getField(s, f)
if isstruct(s) && isfield(s, f)
    v = s.(f);
else
    v = [];
end
end
