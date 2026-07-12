function geom = channelGeometry(device)
% CHANNELGEOMETRY Per-channel source/detector 3D positions from a device
%
% Resolves, for each good (measurement) channel, the 3D positions of its
% source and detector optodes and the channel midpoint, in the device's MNI
% millimetre frame. These are the inputs a DOT forward model needs to place the
% photon-sensitivity "banana" between each source-detector pair.
%
% Syntax:
%   geom = pf2_base.dot.channelGeometry(device)
%
% Inputs:
%   device - pf2.Device object (or a struct/data with a `.device` field) that
%            carries 3D optode geometry (hasMNI / Pos3D in TableSD).
%
% Outputs:
%   geom - struct with fields (nCh = number of good channels, row-aligned to
%          the channel columns of processed HbO/HbR):
%          .src         [nCh x 3] source positions (mm)
%          .det         [nCh x 3] detector positions (mm)
%          .mid         [nCh x 3] source-detector midpoints (mm)
%          .sdDist      [1 x nCh] source-detector separation (mm)
%          .wavelengths [1 x W]   unique non-dark device wavelengths (nm)
%          .channelIdx  [1 x nCh] OptodeNumber per channel
%
% Algorithm:
%   Good channels are TableCh rows with isCh == 1, taken one row per channel
%   (first non-dark wavelength), preserving OptodeNumber order. Each channel's
%   SourceIndex / DetectorIndex select rows from TableSD (Type Src/Det) to get
%   Pos3D. This order matches `Device.mniPositions` (channel midpoints) and the
%   columns of the processed hemoglobin matrices.
%
% Example:
%   geom = pf2_base.dot.channelGeometry(proc.device);
%   plot3(geom.src(:,1), geom.src(:,2), geom.src(:,3), 'ro');
%
% See also: pf2_base.dot.sensitivityMatrix, pf2.Device

device = resolveDevice(device);

if ~device.hasMNI()
    error('pf2:dot:channelGeometry:noGeometry', ...
        ['Device has no 3D optode coordinates (layout-only montage). DOT ' ...
         'requires source/detector positions.']);
end

P = device.probeInfo.Probe{1};
sd = P.TableSD;
if ~istable(sd) || ~all(ismember({'Type','Index','Pos3D_x','Pos3D_y','Pos3D_z'}, ...
        sd.Properties.VariableNames))
    error('pf2:dot:channelGeometry:noTableSD', ...
        'Device TableSD lacks 3D source/detector positions.');
end

srcRows = sd(sd.Type == "Src", :);
detRows = sd(sd.Type == "Det", :);
srcPosAll = [srcRows.Pos3D_x, srcRows.Pos3D_y, srcRows.Pos3D_z];
detPosAll = [detRows.Pos3D_x, detRows.Pos3D_y, detRows.Pos3D_z];
srcIdxAll = srcRows.Index;
detIdxAll = detRows.Index;

ch = P.TableCh;
good = ch(ch.isCh == 1, :);
% One row per channel: the first row of each OptodeNumber (wavelengths repeat).
[chanIdx, firstRows] = unique(good.OptodeNumber, 'stable');
good = good(firstRows, :);

nCh = numel(chanIdx);
src = nan(nCh, 3);
det = nan(nCh, 3);
for i = 1:nCh
    si = good.SourceIndex(i);
    di = good.DetectorIndex(i);
    sRow = find(srcIdxAll == si, 1);
    dRow = find(detIdxAll == di, 1);
    if isempty(sRow) || isempty(dRow)
        error('pf2:dot:channelGeometry:unwired', ...
            'Channel %d references missing source/detector index.', chanIdx(i));
    end
    src(i, :) = srcPosAll(sRow, :);
    det(i, :) = detPosAll(dRow, :);
end

mid = (src + det) / 2;
geom = struct();
geom.src = src;
geom.det = det;
geom.mid = mid;
geom.sdDist = vecnorm(src - det, 2, 2)';
geom.wavelengths = device.wavelengths();
geom.wavelengths = unique(geom.wavelengths(geom.wavelengths > 0), 'stable');
geom.channelIdx = chanIdx(:)';
end

function device = resolveDevice(x)
if isa(x, 'pf2.Device')
    device = x;
elseif isstruct(x) && isfield(x, 'device') && isa(x.device, 'pf2.Device')
    device = x.device;
else
    device = pf2.Device.load(x);
end
end
