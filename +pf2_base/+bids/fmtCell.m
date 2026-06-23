function s = fmtCell(v)
% FMTCELL Format one value as a BIDS TSV cell
%
% Renders a scalar value as the char it should occupy in a tab-separated
% BIDS file. Missing/empty/NaN render as the BIDS sentinel 'n/a'. Embedded
% tabs and newlines are replaced with spaces so the column structure is
% preserved.
%
% Inputs:
%   v - char, string, numeric, or logical scalar (or empty)
%
% Outputs:
%   s - char row vector
%
% Example:
%   pf2_base.bids.fmtCell(NaN)     % 'n/a'
%   pf2_base.bids.fmtCell(760)     % '760'
%
% See also: pf2_base.bids.writeTsv

if ischar(v)
    s = v;
    if isempty(s), s = 'n/a'; end
elseif isstring(v)
    if isscalar(v) && (ismissing(v) || strlength(v) == 0)
        s = 'n/a';
    else
        s = char(v);
    end
elseif islogical(v)
    s = num2str(double(v));
elseif isnumeric(v)
    if isempty(v) || (isscalar(v) && isnan(v))
        s = 'n/a';
    else
        s = num2str(v, '%g');
    end
else
    s = char(string(v));
    if isempty(s), s = 'n/a'; end
end

s = strrep(s, sprintf('\t'), ' ');
s = strrep(s, newline, ' ');
s = strrep(s, sprintf('\r'), ' ');
end
