function labels = channelLabels(data)
% CHANNELLABELS Return S#_D# string labels for each channel of an fNIRS recording
%
% Resolves 'S#_D#' channel labels from the device attached to a processed
% fNIRS struct. Labels are preferred from the pre-built ChannelLabel column
% in the device's optode table (present after SNIRF import); otherwise they
% are synthesized from source and detector indices as sprintf('S%d_D%d',
% src, det). Falls back to 'Ch#' when neither source nor detector index is
% available (layout-only devices).
%
% This is the thin label-extraction primitive used by pf2.export.glmToTable
% and pf2.export.blockAvgToTable to add a channel_label column that is
% consistent with pf2.probe.montage output.
%
% Reference:
%   Internal pf2 implementation. Label format follows the SNIRF convention
%   used in importSNIRF (S#_D# per optode pair).
%
% Syntax:
%   labels = pf2.probe.channelLabels(data)
%
% Inputs:
%   data - Processed fNIRS struct with a .device field (pf2.Device), or
%          a pf2.Device object directly.
%
% Outputs:
%   labels - [nCh x 1] string array of channel labels. Each entry is
%            'S#_D#' when src/det info is available, else 'Ch#'.
%            Length matches the number of Hb channels (device.nChannels).
%
% Algorithm:
%   1. Resolve a pf2.Device from the input.
%   2. Read the optode table (TableOpt).
%   3. Use ChannelLabel column when present (SNIRF builds it in importSNIRF);
%      otherwise synthesize from Source/Detector index columns.
%   4. Fill remaining gaps with 'Ch#' using the channel index.
%
% Example:
%   data   = pf2.import.sampleData();
%   proc   = processFNIRS2(data);
%   labels = pf2.probe.channelLabels(proc);
%   disp(labels(1:4))     % e.g. ["S1_D1"; "S1_D2"; "S2_D1"; "S2_D2"]
%
%   % Consistent with montage output
%   tbl = pf2.probe.montage(proc, 'Brodmann', false);
%   assert(isequal(labels, tbl.ChannelLabel));
%
% Notes:
%   - Does not load or search a device config file; requires data.device to
%     be a valid pf2.Device object already attached at import time.
%   - For datasets without a device (e.g. from pf2.import.fromTable), falls
%     back gracefully to 'Ch1', 'Ch2', ... based on nCh inferred from HbO.
%
% See also: pf2.probe.montage, pf2.export.glmToTable,
%           pf2.export.blockAvgToTable

% --- Resolve device ---
if isa(data, 'pf2.Device')
    dev = data;
    optTbl = dev.optodeTable();
    nCh = dev.nChannels;
elseif isstruct(data) && isfield(data, 'device') && isa(data.device, 'pf2.Device')
    dev = data.device;
    optTbl = dev.optodeTable();
    nCh = dev.nChannels;
else
    % No device attached; infer nCh from HbO if present, else 0
    nCh = inferNChannels(data);
    labels = arrayfun(@(k) sprintf('Ch%d', k), (1:nCh)', 'UniformOutput', false);
    labels = string(labels);
    return;
end

% --- Resolve src/det indices ---
src = optColumn(optTbl, {'SrcIdx', 'SourceIndex', 'Source'}, nCh);
det = optColumn(optTbl, {'DetIdx', 'DetectorIndex', 'Detector'}, nCh);

% --- Synthesize labels (reuse the same logic as montage.m) ---
labels = buildLabels(optTbl, src, det, nCh);

end

%%_Subfunctions_________________________________________________________

function labels = buildLabels(optTbl, src, det, n)
% BUILDLABELS Synthesize S#_D# labels from optode table and src/det indices
%
% Inputs:
%   optTbl - optode table (may be [])
%   src    - [n x 1] source indices
%   det    - [n x 1] detector indices
%   n      - channel count
%
% Outputs:
%   labels - [n x 1] string array

labels = strings(n, 1);

% Prefer pre-built ChannelLabel column (SNIRF import path)
if istable(optTbl) && ismember('ChannelLabel', optTbl.Properties.VariableNames)
    raw = optTbl.ChannelLabel;
    m = min(numel(raw), n);
    for k = 1:m
        v = raw(k);
        if iscell(v), v = v{1}; end
        s = string(v);
        if strlength(s) > 0 && ~ismissing(s)
            labels(k) = s;
        end
    end
end

% Fill empty entries by synthesis
for k = 1:n
    if strlength(labels(k)) == 0 || ismissing(labels(k))
        sk = src(k);
        dk = det(k);
        if ~isnan(sk) && ~isnan(dk)
            labels(k) = sprintf('S%d_D%d', sk, dk);
        else
            labels(k) = sprintf('Ch%d', k);
        end
    end
end

end


function col = optColumn(optTbl, names, n)
% OPTCOLUMN Read the first matching per-channel column as an [n x 1] vector
%
% Inputs:
%   optTbl - Optode table or []
%   names  - Candidate column name(s) (first present wins)
%   n      - Required length
%
% Outputs:
%   col - [n x 1] double (NaN-filled if no matching column)

col = nan(n, 1);
if ~istable(optTbl)
    return;
end
for i = 1:numel(names)
    if ismember(names{i}, optTbl.Properties.VariableNames)
        v = double(optTbl.(names{i}));
        v = v(:);
        m = min(numel(v), n);
        col(1:m) = v(1:m);
        return;
    end
end

end


function n = inferNChannels(data)
% INFERNCHANNELS Infer the number of Hb channels when no device is attached
%
% Inputs:
%   data - Any struct that may carry HbO/HbR/raw
%
% Outputs:
%   n - Number of Hb channels (0 when undeterminable)

n = 0;
if ~isstruct(data)
    return;
end
for f = {'HbO', 'HbR', 'raw'}
    if isfield(data, f{1}) && ~isempty(data.(f{1}))
        n = size(data.(f{1}), 2);
        return;
    end
end

end
