function s = labelFor(labels, prefix, idx)
% LABELFOR Resolve an optode label, falling back to <prefix><idx>
%
% Returns the label for source/detector index IDX from a SNIRF probe label
% container (cellstr, string array, or char matrix). When no usable label is
% present, returns a synthesized name like 'S1' / 'D3'.
%
% Inputs:
%   labels - probe.sourceLabels / probe.detectorLabels (any of cellstr,
%            string array, char matrix, or [])
%   prefix - 'S' or 'D'
%   idx    - 1-based optode index (NaN tolerated -> fallback)
%
% Outputs:
%   s - char label
%
% Example:
%   pf2_base.bids.labelFor({'A','B'}, 'S', 2)   % 'B'
%
% See also: pf2_base.bids.writeChannelsTsv, pf2_base.bids.writeOptodesTsv

s = '';
if ~isempty(labels) && ~isnan(idx)
    try
        if iscell(labels) && idx <= numel(labels)
            s = char(string(labels{idx}));
        elseif isstring(labels) && idx <= numel(labels)
            s = char(labels(idx));
        elseif ischar(labels) && idx <= size(labels, 1)
            s = strtrim(labels(idx, :));
        end
    catch
        s = '';
    end
end
if isempty(s)
    if isnan(idx)
        s = prefix;
    else
        s = sprintf('%s%d', prefix, idx);
    end
end
end
