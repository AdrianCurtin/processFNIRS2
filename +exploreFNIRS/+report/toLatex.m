function str = toLatex(T, varargin)
% TOLATEX Convert MATLAB table to LaTeX tabular string
%
% Generates publication-ready LaTeX code using booktabs formatting.
%
% Syntax:
%   str = exploreFNIRS.report.toLatex(T)
%   str = exploreFNIRS.report.toLatex(T, 'Style', 'booktabs')
%   str = exploreFNIRS.report.toLatex(T, 'Caption', 'ANOVA Results')
%
% Inputs:
%   T - MATLAB table
%
% Name-Value Parameters:
%   Style       - 'booktabs' (default) or 'plain' (\hline)
%   Caption     - Table caption (default: '' = no caption)
%   Label       - LaTeX label (default: '' = no label)
%   Alignment   - Column alignment string (default: auto 'l' for text, 'r' for numeric)
%   RowNames    - Include row names (default: true if they exist)
%   Environment - 'table' (default) wraps in \begin{table}, 'none' = bare tabular
%   Precision   - Decimal places for numeric values (default: 3)
%   Escape      - Escape special LaTeX characters (default: true)
%
% Outputs:
%   str - LaTeX string
%
% Example:
%   T = table({'A';'B'}, [1.23; 4.56], [0.01; 0.5], ...
%       'VariableNames', {'Group','Mean','pValue'});
%   latex = exploreFNIRS.report.toLatex(T, 'Caption', 'Results');
%   fprintf('%s\n', latex);
%
% See also: exploreFNIRS.report.anovaTable, exploreFNIRS.report.contrastTable

    ip = inputParser;
    addRequired(ip, 'T', @istable);
    addParameter(ip, 'Style', 'booktabs', @ischar);
    addParameter(ip, 'Caption', '', @ischar);
    addParameter(ip, 'Label', '', @ischar);
    addParameter(ip, 'Alignment', '', @ischar);
    addParameter(ip, 'RowNames', true, @islogical);
    addParameter(ip, 'Environment', 'table', @ischar);
    addParameter(ip, 'Precision', 3, @isnumeric);
    addParameter(ip, 'Escape', true, @islogical);
    parse(ip, T, varargin{:});
    opts = ip.Results;

    useRowNames = opts.RowNames && ~isempty(T.Properties.RowNames);
    varNames = T.Properties.VariableNames;
    nCols = width(T);
    nRows = height(T);
    useBooktabs = strcmpi(opts.Style, 'booktabs');

    % Build alignment string
    if isempty(opts.Alignment)
        align = '';
        if useRowNames
            align = 'l';
        end
        for c = 1:nCols
            col = T.(varNames{c});
            if isnumeric(col)
                align = [align, 'r']; %#ok<AGROW>
            else
                align = [align, 'l']; %#ok<AGROW>
            end
        end
    else
        align = opts.Alignment;
    end

    lines = {};

    % Environment wrapper
    if strcmpi(opts.Environment, 'table')
        lines{end+1} = '\begin{table}[htbp]';
        lines{end+1} = '\centering';
        if ~isempty(opts.Caption)
            lines{end+1} = sprintf('\\caption{%s}', escapeLatex(opts.Caption, opts.Escape));
        end
        if ~isempty(opts.Label)
            lines{end+1} = sprintf('\\label{%s}', opts.Label);
        end
    end

    % Tabular begin
    lines{end+1} = sprintf('\\begin{tabular}{%s}', align);

    if useBooktabs
        lines{end+1} = '\toprule';
    else
        lines{end+1} = '\hline';
    end

    % Header row
    header = {};
    if useRowNames
        header{end+1} = '';
    end
    for c = 1:nCols
        header{end+1} = escapeLatex(varNames{c}, opts.Escape); %#ok<AGROW>
    end
    lines{end+1} = [strjoin(header, ' & '), ' \\'];

    if useBooktabs
        lines{end+1} = '\midrule';
    else
        lines{end+1} = '\hline';
    end

    % Data rows
    for r = 1:nRows
        row = {};
        if useRowNames
            row{end+1} = escapeLatex(T.Properties.RowNames{r}, opts.Escape); %#ok<AGROW>
        end

        for c = 1:nCols
            val = T.(varNames{c})(r);
            if isnumeric(val)
                if isnan(val)
                    row{end+1} = '-'; %#ok<AGROW>
                else
                    row{end+1} = sprintf('%.*f', opts.Precision, val); %#ok<AGROW>
                end
            elseif isstring(val) || ischar(val)
                row{end+1} = escapeLatex(char(val), opts.Escape); %#ok<AGROW>
            elseif iscell(val)
                row{end+1} = escapeLatex(char(string(val{1})), opts.Escape); %#ok<AGROW>
            elseif iscategorical(val)
                row{end+1} = escapeLatex(char(val), opts.Escape); %#ok<AGROW>
            else
                row{end+1} = escapeLatex(char(string(val)), opts.Escape); %#ok<AGROW>
            end
        end

        lines{end+1} = [strjoin(row, ' & '), ' \\']; %#ok<AGROW>
    end

    % Bottom rule
    if useBooktabs
        lines{end+1} = '\bottomrule';
    else
        lines{end+1} = '\hline';
    end

    lines{end+1} = '\end{tabular}';

    if strcmpi(opts.Environment, 'table')
        lines{end+1} = '\end{table}';
    end

    str = strjoin(lines, newline);
end


function s = escapeLatex(s, doEscape)
    if ~doEscape
        return;
    end
    s = strrep(s, '\', '\textbackslash{}');
    s = strrep(s, '&', '\&');
    s = strrep(s, '%', '\%');
    s = strrep(s, '$', '\$');
    s = strrep(s, '#', '\#');
    s = strrep(s, '_', '\_');
    s = strrep(s, '{', '\{');
    s = strrep(s, '}', '\}');
    s = strrep(s, '~', '\textasciitilde{}');
    s = strrep(s, '^', '\textasciicircum{}');
end
