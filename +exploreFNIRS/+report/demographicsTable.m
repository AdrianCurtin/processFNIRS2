function T = demographicsTable(experiment, varargin)
% DEMOGRAPHICSTABLE Table 1: participant demographics by group
%
% Creates a formatted demographics summary table suitable for publication.
% Numeric variables are reported as M (SD), categorical variables as counts
% and percentages per group.
%
% Syntax:
%   T = exploreFNIRS.report.demographicsTable(ex)
%   T = exploreFNIRS.report.demographicsTable(ex, 'Variables', {'Age','Sex'})
%
% Inputs:
%   experiment - Experiment object (with groupby called) or MATLAB table
%
% Name-Value Parameters:
%   Variables  - Cell array of variable names to include (default: auto-detect)
%   Precision  - Decimal places for numeric summaries (default: 1)
%
% Outputs:
%   T - Table with one row per variable, one column per group + Total
%       Numeric: 'M (SD)' strings
%       Categorical/string: 'n (%)' per unique level
%
% Example:
%   ex = exploreFNIRS.core.Experiment(data);
%   ex.groupby({'Group'});
%   T = exploreFNIRS.report.demographicsTable(ex, 'Variables', {'Age','Sex'});
%   disp(T);
%
% See also: exploreFNIRS.report.toLatex, exploreFNIRS.core.Experiment

    ip = inputParser;
    addRequired(ip, 'experiment');
    addParameter(ip, 'Variables', {}, @iscell);
    addParameter(ip, 'Precision', 1, @isnumeric);
    parse(ip, experiment, varargin{:});
    opts = ip.Results;

    % Extract data and group info
    if istable(experiment)
        fullTable = experiment;
        groupLabels = {'Total'};
        groupTables = {fullTable};
    elseif isa(experiment, 'exploreFNIRS.core.Experiment')
        fullTable = experiment.getSelectedTable();
        if ~isempty(experiment.groupByVars) && ~isempty(experiment.groups)
            nGroups = length(experiment.groups);
            groupLabels = cell(1, nGroups);
            groupTables = cell(1, nGroups);
            for g = 1:nGroups
                groupLabels{g} = experiment.groups(g).label;
                groupTables{g} = experiment.groups(g).gbyTables;
            end
        else
            groupLabels = {'All'};
            groupTables = {fullTable};
        end
    else
        error('exploreFNIRS:report:demographicsTable', ...
            'Input must be an Experiment object or a table');
    end

    % Auto-detect variables
    if isempty(opts.Variables)
        vars = fullTable.Properties.VariableNames;
        exclude = {'missingFNIRS', 'segmentIndex', 'fileIndex'};
        vars = setdiff(vars, exclude, 'stable');
    else
        vars = opts.Variables;
    end

    nGroups = length(groupLabels);
    if nGroups > 1
        colNames = [groupLabels, {'Total'}];
    else
        colNames = groupLabels;
    end
    nCols = length(colNames);

    rowLabels = {};
    rowData = cell(0, nCols);

    for v = 1:length(vars)
        varName = vars{v};
        if ~ismember(varName, fullTable.Properties.VariableNames)
            continue;
        end

        col = fullTable.(varName);

        if isnumeric(col)
            % Numeric: M (SD)
            rowLabels{end+1} = varName; %#ok<AGROW>
            row = cell(1, nCols);
            for g = 1:nGroups
                vals = groupTables{g}.(varName);
                vals = vals(~isnan(vals));
                row{g} = sprintf('%.*f (%.*f)', ...
                    opts.Precision, mean(vals), opts.Precision, std(vals));
            end
            allVals = col(~isnan(col));
            row{end} = sprintf('%.*f (%.*f)', ...
                opts.Precision, mean(allVals), opts.Precision, std(allVals));
            rowData(end+1, :) = row; %#ok<AGROW>

        elseif iscategorical(col) || isstring(col) || iscell(col)
            % Categorical: n (%)
            levels = unique(string(col));
            levels = levels(~ismissing(levels));

            % Row for the variable name
            rowLabels{end+1} = varName; %#ok<AGROW>
            nRow = cell(1, nCols);
            for g = 1:nGroups
                nRow{g} = sprintf('n = %d', height(groupTables{g}));
            end
            nRow{end} = sprintf('n = %d', height(fullTable));
            rowData(end+1, :) = nRow; %#ok<AGROW>

            % One row per level
            for lv = 1:length(levels)
                rowLabels{end+1} = sprintf('  %s', levels(lv)); %#ok<AGROW>
                row = cell(1, nCols);
                for g = 1:nGroups
                    gCol = string(groupTables{g}.(varName));
                    n = sum(gCol == levels(lv));
                    pct = 100 * n / length(gCol);
                    row{g} = sprintf('%d (%.0f%%)', n, pct);
                end
                allCol = string(col);
                n = sum(allCol == levels(lv));
                pct = 100 * n / length(allCol);
                row{end} = sprintf('%d (%.0f%%)', n, pct);
                rowData(end+1, :) = row; %#ok<AGROW>
            end
        end
    end

    T = cell2table(rowData, 'VariableNames', matlab.lang.makeValidName(colNames), ...
        'RowNames', rowLabels);
end
