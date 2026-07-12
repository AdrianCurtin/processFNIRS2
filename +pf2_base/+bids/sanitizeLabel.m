function s = sanitizeLabel(val)
% SANITIZELABEL Coerce a value to a BIDS-legal entity label
%
% BIDS entity labels (the text after sub-, ses-, task-, run-) must be
% alphanumeric only. Any other character is removed. Numeric and string
% inputs are accepted and converted first.
%
% Inputs:
%   val - char, string, or numeric value
%
% Outputs:
%   s   - char row vector containing only [A-Za-z0-9] (possibly empty)
%
% Example:
%   pf2_base.bids.sanitizeLabel('Sub_01')   % 'Sub01'
%
% See also: pf2_base.bids.resolveEntities

if isnumeric(val)
    s = num2str(val);
else
    s = char(string(val));
end
s = regexprep(s, '[^a-zA-Z0-9]', '');
end
