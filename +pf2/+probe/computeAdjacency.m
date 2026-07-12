function adj = computeAdjacency(deviceOrData, opts)
% COMPUTEADJACENCY Compute channel adjacency matrix from MNI coordinates
%
% Builds a spatial adjacency matrix for fNIRS channels based on Euclidean
% distance between MNI coordinates. Two channels are adjacent when their
% midpoint coordinates (between source and detector) are within the
% specified distance threshold. Used by cluster-based permutation testing
% to identify spatially contiguous clusters of significant channels.
%
% Reference:
%   Maris, E. & Oostenveld, R. (2007). Nonparametric statistical testing
%   of EEG- and MEG-data. Journal of Neuroscience Methods, 164(1), 177-190.
%   DOI: 10.1016/j.jneumeth.2007.03.024
%
% Syntax:
%   adj = pf2.probe.computeAdjacency(device)
%   adj = pf2.probe.computeAdjacency(data)
%   adj = pf2.probe.computeAdjacency('fNIR_Devices_fNIR2000')
%   adj = pf2.probe.computeAdjacency(..., 'MaxDistance', 40)
%
% Inputs:
%   deviceOrData - One of:
%                  - pf2.Device object
%                  - fNIRS data struct (with .device field or probe info)
%                  - Device config name string
%
% Name-Value Parameters:
%   MaxDistance      - Distance threshold in mm (default: 30)
%                     Channels closer than this are considered adjacent.
%   ExcludeShortSep - Exclude short-separation channels (default: true)
%
% Outputs:
%   adj - [nCh x nCh] sparse logical adjacency matrix
%         adj(i,j) = true if channels i and j are within MaxDistance mm.
%         Diagonal is false (a channel is not adjacent to itself).
%
% Algorithm:
%   1. Load MNI coordinates from device/data
%   2. Compute pairwise Euclidean distances via pdist2
%   3. Threshold at MaxDistance to produce binary adjacency
%   4. Remove diagonal (self-adjacency)
%
% Example:
%   % From device name
%   adj = pf2.probe.computeAdjacency('fNIR_Devices_fNIR2000');
%
%   % From data struct
%   data = pf2.import.sampleData.fNIR2000();
%   adj = pf2.probe.computeAdjacency(data, 'MaxDistance', 35);
%
%   % Visualize adjacency
%   figure; spy(adj); title('Channel adjacency');
%
% See also: pf2.Device, exploreFNIRS.stats.clusterPermutation

arguments
    deviceOrData
    opts.MaxDistance (1,1) {mustBeNumeric} = 30
    opts.ExcludeShortSep = true
end

maxDist = opts.MaxDistance;
excludeSS = opts.ExcludeShortSep;

% Resolve device
if isa(deviceOrData, 'pf2.Device')
    dev = deviceOrData;
elseif ischar(deviceOrData) || isstring(deviceOrData)
    dev = pf2.Device.load(deviceOrData);
elseif isstruct(deviceOrData)
    dev = pf2_base.resolveDeviceFromData(deviceOrData);
else
    error('pf2:InvalidInput', ...
        'Input must be a pf2.Device, data struct, or config name string');
end

% Get MNI positions
mni = dev.mniPositions();
if isempty(mni)
    error('pf2:NoMNI', ...
        'Device ''%s'' does not have MNI coordinates. Adjacency requires 3D positions.', ...
        dev.name);
end

nCh = size(mni, 1);

% Optionally exclude short-separation channels
if excludeSS && dev.nShortSep > 0
    ssMask = dev.isShortSep();
    mni(ssMask, :) = NaN;
end

% Compute pairwise Euclidean distances
if exist('pdist2', 'file') ~= 2
    % Fallback for users without Statistics Toolbox
    D = sqrt(sum((permute(mni, [1,3,2]) - permute(mni, [3,1,2])).^2, 3));
else
    D = pdist2(mni, mni);
end

% Threshold to adjacency
adj = D <= maxDist;

% Remove self-adjacency
adj(logical(eye(nCh))) = false;

% NaN rows/cols (short-sep) will be false (NaN distance > threshold is false)
% Make sparse for efficiency
adj = sparse(adj);

end
