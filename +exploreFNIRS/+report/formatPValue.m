function str = formatPValue(p, varargin)
% FORMATPVALUE APA-style p-value formatting
%
% Formats p-values according to APA 7th edition guidelines:
%   - No leading zero (e.g., .045 not 0.045)
%   - Three decimal places for p >= .001
%   - "< .001" for p < .001
%
% Syntax:
%   str = exploreFNIRS.report.formatPValue(p)
%   str = exploreFNIRS.report.formatPValue(p, 'Precision', 3)
%   str = exploreFNIRS.report.formatPValue(p, 'Prefix', true)
%
% Inputs:
%   p - Scalar p-value (0 to 1)
%
% Name-Value Parameters:
%   Precision - Number of decimal places (default: 3)
%   Prefix    - Include "p = " or "p < " prefix (default: false)
%
% Outputs:
%   str - Formatted string (e.g., '.045', '< .001', 'p = .045')
%
% Example:
%   formatPValue(0.045)           % '.045'
%   formatPValue(0.0003)          % '< .001'
%   formatPValue(0.045, 'Prefix', true)  % 'p = .045'
%
% See also: exploreFNIRS.report.formatStats

    ip = inputParser;
    addRequired(ip, 'p', @(x) isnumeric(x) && isscalar(x));
    addParameter(ip, 'Precision', 3, @(x) isnumeric(x) && isscalar(x));
    addParameter(ip, 'Prefix', false, @islogical);
    parse(ip, p, varargin{:});
    prec = ip.Results.Precision;
    usePrefix = ip.Results.Prefix;

    threshold = 10^(-prec);

    if p < threshold
        valStr = sprintf('< .%s1', repmat('0', 1, prec - 1));
        if usePrefix
            str = ['p ', valStr];
        else
            str = valStr;
        end
    else
        raw = sprintf('%.*f', prec, p);
        valStr = regexprep(raw, '^0', '');
        if usePrefix
            str = ['p = ', valStr];
        else
            str = valStr;
        end
    end
end
