function T = demographicsTable(experiment, varargin)
% DEMOGRAPHICSTABLE Publication-style Table 1 demographics summary
%
% Creates a formatted demographics summary at the subject level.
% Numeric variables are reported as M (SD), categorical variables as
% n (%) or just %. Supports optional group comparisons with t-tests
% (numeric) and chi-squared tests (categorical).
%
% When a GroupBy variable is between-subjects (constant within each
% subject), each subject appears in exactly one group and statistical
% comparisons are reported. When GroupBy is within-subjects (varies
% within a subject, e.g. Condition), subjects are counted in every
% group they appear in and the stats column is omitted.
%
% Syntax:
%   T = exploreFNIRS.report.demographicsTable(ex)
%   T = exploreFNIRS.report.demographicsTable(ex, 'Variables', {'Age','Sex'})
%   T = exploreFNIRS.report.demographicsTable(ex, 'GroupBy', 'Group')
%   T = exploreFNIRS.report.demographicsTable(ex, 'GroupBy', 'Group', 'Paired', true)
%   T = exploreFNIRS.report.demographicsTable(ex, 'Format', 'console')
%   T = exploreFNIRS.report.demographicsTable(ex, 'Format', 'latex')
%
% Inputs:
%   experiment - Experiment object or MATLAB table. When an Experiment
%                is provided, the selected metadata table is used.
%
% Name-Value Parameters:
%   Variables         - Cell array of variable names to summarize
%                       (default: common demographics — Age, Sex, Gender,
%                       Group, Subgroup, Race, Ethnicity, Handedness,
%                       Education, SES — filtered to those present in data)
%   GroupBy           - Grouping variable name (default: '' = no grouping)
%   SubjectVar        - Column identifying unique subjects
%                       (default: 'SubjectID')
%   Paired            - Use paired t-test for numeric variables when
%                       exactly 2 groups (default: false)
%   Precision         - Decimal places for M (SD) (default: 1)
%   CategoricalFormat - How to display categorical levels:
%                       'counts'  - 'n (%)' (default)
%                       'percent' - '% only'
%   Labels            - Struct mapping variable names to display labels
%                       (default: struct()). Example:
%                       struct('Age', 'Age (years)', 'Sex', 'Biological Sex')
%   Format            - Output format: 'table' (default), 'console',
%                       or 'latex'
%
% Outputs:
%   T - MATLAB table with one row per variable (or sub-level), one
%       column per group plus Total and (optionally) Statistic.
%
% Example:
%   ex = exploreFNIRS.core.Experiment(allData);
%   T = ex.demographicsTable('GroupBy', 'Group');
%   disp(T);
%
%   % Console output with percentage-only categorical display
%   ex.demographicsTable('GroupBy', 'Group', ...
%       'Format', 'console', 'CategoricalFormat', 'percent');
%
% See also: exploreFNIRS.core.Experiment

    ip = inputParser;
    addRequired(ip, 'experiment');
    addParameter(ip, 'Variables', {}, @iscell);
    addParameter(ip, 'GroupBy', '', @(x) ischar(x) || isstring(x));
    addParameter(ip, 'SubjectVar', 'SubjectID', @(x) ischar(x) || isstring(x));
    addParameter(ip, 'Paired', false, @islogical);
    addParameter(ip, 'Precision', 1, @isnumeric);
    addParameter(ip, 'CategoricalFormat', 'counts', ...
        @(x) ismember(x, {'counts', 'percent'}));
    addParameter(ip, 'Format', 'table', ...
        @(x) ismember(x, {'table', 'console', 'latex'}));
    addParameter(ip, 'Labels', struct(), @isstruct);
    parse(ip, experiment, varargin{:});
    opts = ip.Results;
    opts.GroupBy = char(opts.GroupBy);
    opts.SubjectVar = char(opts.SubjectVar);

    % --- Step 1: Extract full table ---
    if istable(experiment)
        fullTable = experiment;
    elseif isa(experiment, 'exploreFNIRS.core.Experiment')
        fullTable = experiment.getSelectedTable();
    else
        error('exploreFNIRS:report:demographicsTable', ...
            'Input must be an Experiment object or a table.');
    end

    % --- Step 2: Deduplicate to subject level ---
    if ~ismember(opts.SubjectVar, fullTable.Properties.VariableNames)
        error('exploreFNIRS:report:demographicsTable', ...
            'SubjectVar ''%s'' not found in table.', opts.SubjectVar);
    end
    subjectIDs = fullTable.(opts.SubjectVar);
    [~, firstIdx] = unique(makeStringCol(subjectIDs), 'stable');
    subjTable = fullTable(firstIdx, :);

    % --- Step 3: Determine variables to summarize ---
    if isempty(opts.Variables)
        % Default: common demographic variables that exist in the table
        defaultDemographics = {'Age', 'Sex', 'Gender', 'Group', 'Subgroup', ...
            'Race', 'Ethnicity', 'Handedness', 'Education', 'SES'};
        available = fullTable.Properties.VariableNames;
        % Remove GroupBy from candidates (it's the column header, not a row)
        if ~isempty(opts.GroupBy)
            defaultDemographics = setdiff(defaultDemographics, {opts.GroupBy}, 'stable');
        end
        vars = intersect(defaultDemographics, available, 'stable');
        if isempty(vars)
            % Fallback: use all non-internal columns (original behavior)
            exclude = {opts.SubjectVar, 'missingFNIRS', 'segmentIndex', ...
                       'fileIndex', 'blockNumber', 'markerCode', ...
                       'markerIndex', 'amplitude', 'filename', ...
                       'probename', 'Session', 'Trial', 'Block', ...
                       'BlockNumber'};
            if ~isempty(opts.GroupBy)
                exclude = [exclude, {opts.GroupBy}];
            end
            vars = setdiff(available, exclude, 'stable');
        end
    else
        vars = opts.Variables;
    end

    % --- Step 4: Determine grouping ---
    hasGrouping = ~isempty(opts.GroupBy);
    isBetween = false;
    groupLabels = {};
    groupSubjTables = {};

    if hasGrouping
        if ~ismember(opts.GroupBy, fullTable.Properties.VariableNames)
            error('exploreFNIRS:report:demographicsTable', ...
                'GroupBy variable ''%s'' not found in table.', opts.GroupBy);
        end

        % Check if grouping varies within any subject
        isBetween = isGroupingBetween(fullTable, opts.GroupBy, opts.SubjectVar);

        groupCol = makeStringCol(fullTable.(opts.GroupBy));
        levels = unique(groupCol, 'stable');

        if isBetween
            % Between-subject: each subject in exactly one group
            subjGroupCol = makeStringCol(subjTable.(opts.GroupBy));
            for g = 1:length(levels)
                groupLabels{end+1} = char(levels(g)); %#ok<AGROW>
                mask = subjGroupCol == levels(g);
                groupSubjTables{end+1} = subjTable(mask, :); %#ok<AGROW>
            end
        else
            % Within-subject: subject appears in every group they have data for
            for g = 1:length(levels)
                groupLabels{end+1} = char(levels(g)); %#ok<AGROW>
                % Find subjects who have at least one row with this level
                mask = groupCol == levels(g);
                subjsInGroup = unique(makeStringCol(fullTable.(opts.SubjectVar)(mask)));
                allSubjs = makeStringCol(subjTable.(opts.SubjectVar));
                groupSubjTables{end+1} = subjTable(ismember(allSubjs, subjsInGroup), :); %#ok<AGROW>
            end
        end
    end

    % --- Step 5: Build column structure ---
    nGroups = length(groupLabels);
    showStats = hasGrouping && isBetween && nGroups >= 2;

    if hasGrouping
        colNames = [groupLabels, {'Total'}];
    else
        colNames = {'All'};
    end
    if showStats
        colNames = [colNames, {'Statistic'}];
    end
    nCols = length(colNames);

    % --- Step 6: Build rows ---
    rowLabels = {};      % unique names for table RowNames
    displayLabels = {};  % original names for console/latex display
    rowData = cell(0, nCols);

    % N row
    nRow = cell(1, nCols);
    if hasGrouping
        for g = 1:nGroups
            nRow{g} = sprintf('N = %d', height(groupSubjTables{g}));
        end
        nRow{nGroups+1} = sprintf('N = %d', height(subjTable));
    else
        nRow{1} = sprintf('N = %d', height(subjTable));
    end
    if showStats
        nRow{end} = '';
    end
    rowLabels{end+1} = 'N';
    displayLabels{end+1} = 'N';
    rowData(end+1, :) = nRow;

    for v = 1:length(vars)
        varName = vars{v};
        if ~ismember(varName, fullTable.Properties.VariableNames)
            continue;
        end

        % Resolve display label from Labels override
        dispName = resolveLabel(varName, opts.Labels);
        col = subjTable.(varName);

        if isnumeric(col)
            % --- Numeric variable: M (SD) ---
            rowLabels{end+1} = varName; %#ok<AGROW>
            displayLabels{end+1} = dispName; %#ok<AGROW>
            row = cell(1, nCols);

            if hasGrouping
                groupVals = cell(1, nGroups);
                for g = 1:nGroups
                    vals = groupSubjTables{g}.(varName);
                    vals = vals(~isnan(vals));
                    groupVals{g} = vals;
                    row{g} = formatMSD(vals, opts.Precision);
                end
                allVals = col(~isnan(col));
                row{nGroups+1} = formatMSD(allVals, opts.Precision);

                if showStats
                    row{end} = numericStat(groupVals, opts.Paired);
                end
            else
                allVals = col(~isnan(col));
                row{1} = formatMSD(allVals, opts.Precision);
            end
            rowData(end+1, :) = row; %#ok<AGROW>

        elseif iscategorical(col) || isstring(col) || iscellstr(col) || iscell(col)
            % --- Categorical variable ---
            allCol = makeStringCol(col);
            levels = unique(allCol(~ismissing(allCol)), 'stable');

            % Header row for variable name
            rowLabels{end+1} = varName; %#ok<AGROW>
            displayLabels{end+1} = dispName; %#ok<AGROW>
            headerRow = cell(1, nCols);
            for c = 1:nCols
                headerRow{c} = '';
            end
            rowData(end+1, :) = headerRow; %#ok<AGROW>

            % Compute contingency data for stats
            if showStats
                contTable = zeros(nGroups, length(levels));
            end

            % One row per level
            for lv = 1:length(levels)
                levelLabel = sprintf('  %s', levels(lv));
                rowLabels{end+1} = sprintf('%s_%s', varName, levels(lv)); %#ok<AGROW>
                displayLabels{end+1} = levelLabel; %#ok<AGROW>
                row = cell(1, nCols);

                if hasGrouping
                    for g = 1:nGroups
                        gCol = makeStringCol(groupSubjTables{g}.(varName));
                        n = sum(gCol == levels(lv));
                        total = sum(~ismissing(gCol));
                        row{g} = formatCategorical(n, total, opts.CategoricalFormat);
                        if showStats
                            contTable(g, lv) = n;
                        end
                    end
                    % Total column
                    n = sum(allCol == levels(lv));
                    total = sum(~ismissing(allCol));
                    row{nGroups+1} = formatCategorical(n, total, opts.CategoricalFormat);
                else
                    n = sum(allCol == levels(lv));
                    total = sum(~ismissing(allCol));
                    row{1} = formatCategorical(n, total, opts.CategoricalFormat);
                end

                % Stats on last level row only
                if showStats && lv == length(levels)
                    row{end} = chiSquaredTest(contTable);
                elseif showStats
                    row{end} = '';
                end
                rowData(end+1, :) = row; %#ok<AGROW>
            end
        end
    end

    % --- Step 7: Build output table ---
    safeNames = matlab.lang.makeValidName(colNames);
    % Replace empty row labels to avoid cell2table RowNames error
    for ri = 1:length(rowLabels)
        if isempty(rowLabels{ri}) || strtrim(rowLabels{ri}) == ""
            rowLabels{ri} = sprintf('Var_%d', ri);
        end
    end
    % Ensure unique row labels (categorical sub-levels may collide)
    rowLabels = matlab.lang.makeUniqueStrings(rowLabels);
    T = cell2table(rowData, 'VariableNames', safeNames, 'RowNames', rowLabels);

    % --- Step 8: Format output ---
    switch opts.Format
        case 'console'
            printConsole(T, colNames, displayLabels);
        case 'latex'
            printLatex(T, colNames, displayLabels);
    end
end


% =========================================================================
% Local helper functions
% =========================================================================

function s = formatMSD(vals, prec)
% Format mean (SD) string
    if isempty(vals)
        s = '-';
        return;
    end
    s = sprintf('%.*f (%.*f)', prec, mean(vals), prec, std(vals));
end


function s = formatCategorical(n, total, fmt)
% Format categorical count
    if total == 0
        s = '-';
        return;
    end
    pct = 100 * n / total;
    switch fmt
        case 'counts'
            s = sprintf('%d (%.0f%%)', n, pct);
        case 'percent'
            s = sprintf('%.0f%%', pct);
    end
end


function tf = isGroupingBetween(tbl, groupVar, subjVar)
% Check whether grouping is between-subjects (constant within each subject)
    subjCol = makeStringCol(tbl.(subjVar));
    groupCol = makeStringCol(tbl.(groupVar));
    uSubj = unique(subjCol, 'stable');
    tf = true;
    for i = 1:length(uSubj)
        mask = subjCol == uSubj(i);
        if length(unique(groupCol(mask))) > 1
            tf = false;
            return;
        end
    end
end


function s = numericStat(groupVals, paired)
% Compute t-test statistic string for numeric variable
    if length(groupVals) ~= 2
        % For >2 groups, use one-way ANOVA
        allVals = [];
        groupIdx = [];
        for g = 1:length(groupVals)
            allVals = [allVals; groupVals{g}(:)]; %#ok<AGROW>
            groupIdx = [groupIdx; repmat(g, length(groupVals{g}), 1)]; %#ok<AGROW>
        end
        if isempty(allVals)
            s = '';
            return;
        end
        [~, tbl] = anova1(allVals, groupIdx, 'off');
        F = tbl{2, 5};
        df1 = tbl{2, 3};
        df2 = tbl{3, 3};
        p = tbl{2, 6};
        s = sprintf('F(%d,%d) = %.2f, p %s', df1, df2, F, formatP(p));
        return;
    end

    x = groupVals{1};
    y = groupVals{2};
    if isempty(x) || isempty(y)
        s = '';
        return;
    end

    if paired
        % Paired t-test
        n = min(length(x), length(y));
        x = x(1:n);
        y = y(1:n);
        d = x - y;
        tStat = mean(d) / (std(d) / sqrt(n));
        df = n - 1;
        p = 2 * (1 - pf2_base.compat.tcdf(abs(tStat), df));
        s = sprintf('t(%d) = %.2f, p %s', df, tStat, formatP(p));
    else
        % Unpaired (Welch's) t-test
        n1 = length(x);
        n2 = length(y);
        m1 = mean(x);
        m2 = mean(y);
        s1 = std(x);
        s2 = std(y);
        se = sqrt(s1^2/n1 + s2^2/n2);
        if se == 0
            s = 't(-) = NaN';
            return;
        end
        tStat = (m1 - m2) / se;
        % Welch-Satterthwaite degrees of freedom
        num = (s1^2/n1 + s2^2/n2)^2;
        den = (s1^2/n1)^2/(n1-1) + (s2^2/n2)^2/(n2-1);
        df = num / den;
        p = 2 * (1 - pf2_base.compat.tcdf(abs(tStat), df));
        s = sprintf('t(%.1f) = %.2f, p %s', df, tStat, formatP(p));
    end
end


function s = chiSquaredTest(contTable)
% Chi-squared test of independence
% contTable: [nGroups x nLevels] matrix of observed counts
    observed = contTable;
    rowSums = sum(observed, 2);
    colSums = sum(observed, 1);
    total = sum(rowSums);

    if total == 0
        s = '';
        return;
    end

    expected = rowSums * colSums / total;

    % Avoid division by zero in expected
    valid = expected > 0;
    if ~any(valid(:))
        s = '';
        return;
    end

    chi2 = sum((observed(valid) - expected(valid)).^2 ./ expected(valid));
    df = (size(observed, 1) - 1) * (size(observed, 2) - 1);

    if df <= 0
        s = '';
        return;
    end

    p = 1 - chi2cdf(chi2, df);
    s = sprintf('%s(%d) = %.2f, p %s', char(0x03C7), df, chi2, formatP(p)); %#ok chi symbol
end


function s = formatP(p)
% Format p-value string
    if p < 0.001
        s = '< .001';
    else
        s = sprintf('= %.3f', p);
        s = strrep(s, '= 0.', '= .');
    end
end


function col = makeStringCol(col)
% Convert any column type to string for safe comparison
    if iscategorical(col)
        col = string(col);
    elseif iscell(col)
        col = string(col);
    elseif isnumeric(col)
        col = string(arrayfun(@num2str, col, 'UniformOutput', false));
    end
end


function printConsole(T, colNames, displayLabels)
% Print demographics table to console with aligned columns
    nCols = width(T);
    nRows = height(T);
    rowNames = displayLabels;

    % Convert all cells to strings
    strs = cell(nRows, nCols);
    for c = 1:nCols
        for r = 1:nRows
            strs{r, c} = char(string(T{r, c}));
        end
    end

    % Compute column widths
    labelWidth = max(cellfun(@length, rowNames));
    labelWidth = max(labelWidth, 10);
    colWidths = zeros(1, nCols);
    for c = 1:nCols
        colWidths(c) = max(length(colNames{c}), ...
                          max(cellfun(@length, strs(:, c))));
    end

    % Header
    fprintf('\n  %-*s', labelWidth, 'Variable');
    for c = 1:nCols
        fprintf('   %-*s', colWidths(c), colNames{c});
    end
    fprintf('\n');

    % Divider
    fprintf('  %s', repmat('-', 1, labelWidth));
    for c = 1:nCols
        fprintf('   %s', repmat('-', 1, colWidths(c)));
    end
    fprintf('\n');

    % Data rows
    for r = 1:nRows
        fprintf('  %-*s', labelWidth, rowNames{r});
        for c = 1:nCols
            fprintf('   %-*s', colWidths(c), strs{r, c});
        end
        fprintf('\n');
    end
    fprintf('\n');
end


function printLatex(T, colNames, displayLabels)
% Print demographics table as LaTeX booktabs tabular
    nCols = width(T);
    nRows = height(T);
    rowNames = displayLabels;

    % Column alignment: l for label, l for each data column
    alignStr = repmat('l', 1, nCols + 1);

    fprintf('\\begin{table}[htbp]\n');
    fprintf('\\centering\n');
    fprintf('\\caption{Participant Demographics}\n');
    fprintf('\\begin{tabular}{%s}\n', alignStr);
    fprintf('\\toprule\n');

    % Header
    fprintf('Variable');
    for c = 1:nCols
        fprintf(' & %s', latexEscape(colNames{c}));
    end
    fprintf(' \\\\\n');
    fprintf('\\midrule\n');

    % Data rows
    for r = 1:nRows
        label = latexEscape(rowNames{r});
        % Indent sub-levels (they start with spaces)
        if length(rowNames{r}) > 2 && rowNames{r}(1) == ' '
            label = ['\quad ', strtrim(label)];
        end
        fprintf('%s', label);
        for c = 1:nCols
            val = char(string(T{r, c}));
            fprintf(' & %s', latexEscape(val));
        end
        fprintf(' \\\\\n');
    end

    fprintf('\\bottomrule\n');
    fprintf('\\end{tabular}\n');
    fprintf('\\end{table}\n');
end


function s = latexEscape(s)
% Escape special LaTeX characters
    s = strrep(s, '_', '\_');
    s = strrep(s, '%', '\%');
    s = strrep(s, '&', '\&');
    % Convert chi symbol to LaTeX
    s = strrep(s, char(0x03C7), '$\chi^2$');
end


function label = resolveLabel(varName, labelsStruct)
% Look up display label from Labels struct, defaulting to variable name
    if isfield(labelsStruct, varName)
        label = labelsStruct.(varName);
    else
        label = varName;
    end
end
