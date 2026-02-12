function T = correlationTable(R, P, varargin)
% CORRELATIONTABLE Formatted correlation matrix with significance stars
%
% Syntax:
%   T = exploreFNIRS.report.correlationTable(R, P)
%   T = exploreFNIRS.report.correlationTable(R, P, 'Labels', labels)
%
% Inputs:
%   R - [N x N] correlation coefficient matrix
%   P - [N x N] p-value matrix
%
% Name-Value Parameters:
%   Labels    - Cell array of variable names (default: {'V1','V2',...})
%   Precision - Decimal places (default: 3)
%   Triangle  - 'lower' (default), 'upper', or 'full'
%
% Outputs:
%   T - Table with formatted 'r*' strings (stars indicate significance)
%       '*' p < .05, '**' p < .01, '***' p < .001
%
% Example:
%   [R, P] = corrcoef(randn(20, 4));
%   T = exploreFNIRS.report.correlationTable(R, P, ...
%       'Labels', {'Ch1','Ch2','Ch3','Ch4'});
%   disp(T);
%
% See also: exploreFNIRS.report.formatPValue, corrcoef

    ip = inputParser;
    addRequired(ip, 'R', @(x) isnumeric(x) && size(x,1) == size(x,2));
    addRequired(ip, 'P', @(x) isnumeric(x) && size(x,1) == size(x,2));
    addParameter(ip, 'Labels', {}, @iscell);
    addParameter(ip, 'Precision', 3, @isnumeric);
    addParameter(ip, 'Triangle', 'lower', @ischar);
    parse(ip, R, P, varargin{:});
    opts = ip.Results;

    n = size(R, 1);

    if isempty(opts.Labels)
        labels = arrayfun(@(x) sprintf('V%d', x), 1:n, 'UniformOutput', false);
    else
        labels = opts.Labels;
    end

    cells = cell(n, n);

    for i = 1:n
        for j = 1:n
            switch lower(opts.Triangle)
                case 'lower'
                    show = (j < i);
                case 'upper'
                    show = (j > i);
                case 'full'
                    show = (i ~= j);
                otherwise
                    show = (j < i);
            end

            if i == j
                cells{i, j} = '-';
            elseif show
                rStr = sprintf('%.*f', opts.Precision, R(i,j));
                rStr = regexprep(rStr, '^0\.', '.');
                rStr = regexprep(rStr, '^-0\.', '-.');
                stars = getStars(P(i,j));
                cells{i, j} = [rStr, stars];
            else
                cells{i, j} = '';
            end
        end
    end

    T = cell2table(cells, 'VariableNames', matlab.lang.makeValidName(labels), ...
        'RowNames', labels);
end


function s = getStars(p)
    if p < 0.001
        s = '***';
    elseif p < 0.01
        s = '**';
    elseif p < 0.05
        s = '*';
    else
        s = '';
    end
end
