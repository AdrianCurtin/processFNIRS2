function T = behavioralTable(experiment, variables, varargin)
% BEHAVIORALTABLE Descriptive stats, comparisons, or correlations for behavioral data
%
% Generates publication-ready tables for behavioral and experimental
% variables. Supports three analysis types: descriptive statistics grouped
% by condition, paired/unpaired comparisons with effect sizes, and
% correlation tables (one-to-many or matrix). Output as MATLAB table,
% formatted console text, or LaTeX with booktabs.
%
% Syntax:
%   T = exploreFNIRS.stats.behavioralTable(ex, {'RT','Accuracy'})
%   T = exploreFNIRS.stats.behavioralTable(ex, vars, 'GroupBy', 'Condition')
%   T = exploreFNIRS.stats.behavioralTable(ex, vars, 'Type', 'comparisons', ...
%       'GroupBy', 'Condition', 'Paired', true)
%   T = exploreFNIRS.stats.behavioralTable(ex, vars, 'Type', 'correlations', ...
%       'YVar', 'Outcome', 'CorrMethod', 'spearman')
%   T = exploreFNIRS.stats.behavioralTable(T_table, vars, 'Format', 'latex')
%
% Inputs:
%   experiment - Experiment object or MATLAB table with behavioral data
%   variables  - Cell array of variable names to analyze
%
% Name-Value Parameters:
%   Type             - 'descriptive' (default), 'comparisons', or 'correlations'
%   GroupBy          - Categorical column for condition grouping (default: '')
%   SubjectVar       - Column for within-subject averaging (default: 'SubjectID')
%   Paired           - Use paired tests for comparisons (default: true)
%   Comparisons      - Specific pairs: {{'A','B'}, ...}. Empty = all pairwise.
%   ComparisonLabels - Labels for comparisons: {'Label1', ...} (default: {})
%   YVar             - Outcome variable for one-to-many correlations (default: '')
%   CorrMethod       - 'spearman' (default) or 'pearson'
%   Triangle         - 'lower' (default), 'upper', or 'full' (matrix correlations)
%   Precision        - Decimal places (default: 3)
%   IncludeRange     - Include [min, max] in descriptive tables (default: true)
%   Labels           - Variable name -> display label mapping (default: struct())
%                      Accepts struct, containers.Map, or Nx2 cell array.
%                      Use Map or cell for names with special characters:
%                        containers.Map({'RT (Target)'},{'Target RT'})
%                        {'RT (Target)','Target RT'; 'Non-Response','Non-Resp'}
%   Format           - 'table' (default), 'console', or 'latex'
%   Caption          - LaTeX table caption (default: '' = auto-generated)
%
% Outputs:
%   T - MATLAB table with results. Columns depend on Type:
%       'descriptive':  Variable, Group, n, M, SD, Min, Max
%       'comparisons':  Variable, Comparison, Label, n, MeanDiff, SD_diff,
%                       t, df, p, d_z, CI_lower, CI_upper, Sig
%       'correlations': Variable (or matrix), rho/r, p, N, Sig
%
% Examples:
%   % Descriptive stats by condition
%   T = exploreFNIRS.stats.behavioralTable(ex, {'CravingRating','RT'}, ...
%       'GroupBy', 'Condition', 'Format', 'latex');
%
%   % Paired comparisons with custom labels
%   T = exploreFNIRS.stats.behavioralTable(ex, {'CravingRating'}, ...
%       'Type', 'comparisons', 'GroupBy', 'Condition', ...
%       'Comparisons', {{'Watch','Neutral'}, {'Watch','Down'}}, ...
%       'ComparisonLabels', {'Reactivity', 'Regulation'});
%
%   % Correlation matrix
%   T = exploreFNIRS.stats.behavioralTable(ex, {'RT','Age','Score'}, ...
%       'Type', 'correlations', 'CorrMethod', 'spearman', 'Format', 'latex');
%
% See also: exploreFNIRS.stats.summarize, exploreFNIRS.report.correlationTable

    p = inputParser;
    addRequired(p, 'experiment');
    addRequired(p, 'variables', @(x) iscell(x) || ischar(x) || isstring(x));
    addParameter(p, 'Type', 'descriptive', @ischar);
    addParameter(p, 'GroupBy', '', @(x) ischar(x) || isstring(x));
    addParameter(p, 'SubjectVar', 'SubjectID', @(x) ischar(x) || isstring(x));
    addParameter(p, 'Paired', true, @islogical);
    addParameter(p, 'Comparisons', {}, @iscell);
    addParameter(p, 'ComparisonLabels', {}, @iscell);
    addParameter(p, 'YVar', '', @(x) ischar(x) || isstring(x));
    addParameter(p, 'CorrMethod', 'spearman', @ischar);
    addParameter(p, 'Triangle', 'lower', @ischar);
    addParameter(p, 'Precision', 3, @isnumeric);
    addParameter(p, 'IncludeRange', true, @islogical);
    addParameter(p, 'Labels', struct(), @(x) isstruct(x) || isa(x, 'containers.Map') || iscell(x));
    addParameter(p, 'Format', 'table', @ischar);
    addParameter(p, 'Caption', '', @(x) ischar(x) || isstring(x));
    parse(p, experiment, variables, varargin{:});
    opts = p.Results;

    % Normalize variables to cell array
    if ischar(opts.variables) || isstring(opts.variables)
        opts.variables = cellstr(opts.variables);
    end
    opts.GroupBy = char(opts.GroupBy);
    opts.SubjectVar = char(opts.SubjectVar);
    opts.YVar = char(opts.YVar);
    opts.Caption = char(opts.Caption);

    % Extract table from Experiment or use directly
    tbl = extractTable(experiment, opts);

    % Within-subject averaging when GroupBy is set
    tbl = subjectLevelTable(tbl, opts);

    % Dispatch by type
    switch lower(opts.Type)
        case 'descriptive'
            T = buildDescriptive(tbl, opts);
        case 'comparisons'
            T = buildComparisons(tbl, opts);
        case 'correlations'
            T = buildCorrelations(tbl, opts);
        otherwise
            error('exploreFNIRS:stats:behavioralTable', ...
                'Unknown Type: ''%s''. Use ''descriptive'', ''comparisons'', or ''correlations''.', ...
                opts.Type);
    end

    % Output formatting
    if strcmpi(opts.Format, 'console') && ~isempty(T)
        printConsole(T, opts);
    end
    if strcmpi(opts.Format, 'latex') && ~isempty(T)
        printLatex(T, opts);
    end
end


%% Table extraction

function tbl = extractTable(experiment, opts)
% Extract a MATLAB table from an Experiment object or pass through a table

    if istable(experiment)
        tbl = experiment;
        return;
    end

    % Experiment object — extract merged table
    if isa(experiment, 'exploreFNIRS.core.Experiment')
        if ~isempty(experiment.groups) && isfield(experiment.groups, 'gbyGrandBarFlat')
            tbl = experiment.groups.gbyGrandBarFlat;
        elseif isprop(experiment, 'data') && ~isempty(experiment.data)
            tbl = pf2.data.infoToTable(experiment.data);
        else
            error('exploreFNIRS:stats:behavioralTable', ...
                'Experiment has no data. Call select() first.');
        end
    else
        error('exploreFNIRS:stats:behavioralTable', ...
            'First argument must be an Experiment object or a MATLAB table.');
    end

    % Validate required columns exist
    allVars = opts.variables;
    if ~isempty(opts.GroupBy)
        allVars = [allVars, {opts.GroupBy}];
    end
    if ~isempty(opts.YVar)
        allVars = [allVars, {opts.YVar}];
    end
    missing = setdiff(allVars, tbl.Properties.VariableNames);
    if ~isempty(missing)
        error('exploreFNIRS:stats:behavioralTable', ...
            'Variables not found in table: %s', strjoin(missing, ', '));
    end
end


function tbl = subjectLevelTable(tbl, opts)
% Average within subject (and optionally within group) to get one row per
% subject per condition. Only averages numeric variables.

    if isempty(opts.SubjectVar) || ...
            ~ismember(opts.SubjectVar, tbl.Properties.VariableNames)
        return;
    end

    % Determine grouping columns
    groupCols = {opts.SubjectVar};
    if ~isempty(opts.GroupBy) && ismember(opts.GroupBy, tbl.Properties.VariableNames)
        groupCols{end+1} = opts.GroupBy;
    end

    % Identify numeric columns to average
    numVars = opts.variables;
    if ~isempty(opts.YVar) && ~ismember(opts.YVar, numVars)
        numVars = [numVars, {opts.YVar}];
    end
    numVars = numVars(ismember(numVars, tbl.Properties.VariableNames));

    % Check if averaging is needed (more rows than unique combinations)
    if isempty(numVars)
        return;
    end

    groupVals = tbl(:, groupCols);
    [~, ia] = unique(groupVals, 'rows');
    if length(ia) == height(tbl)
        return; % Already one row per subject-condition
    end

    tbl = groupsummary(tbl, groupCols, 'mean', numVars);

    % Rename mean_ columns back to original names
    for i = 1:length(numVars)
        meanName = ['mean_', numVars{i}];
        if ismember(meanName, tbl.Properties.VariableNames)
            tbl.Properties.VariableNames{strcmp(tbl.Properties.VariableNames, meanName)} = numVars{i};
        end
    end

    % Drop GroupCount column added by groupsummary
    if ismember('GroupCount', tbl.Properties.VariableNames)
        tbl.GroupCount = [];
    end
end


%% Type: descriptive

function T = buildDescriptive(tbl, opts)
% Build descriptive statistics table: M, SD, min, max per group per variable

    vars = opts.variables;
    hasGroup = ~isempty(opts.GroupBy) && ismember(opts.GroupBy, tbl.Properties.VariableNames);

    if hasGroup
        groups = categories(categorical(tbl.(opts.GroupBy)));
    else
        groups = {''};
    end

    rows = {};
    for v = 1:length(vars)
        for g = 1:length(groups)
            if hasGroup
                mask = strcmp(string(tbl.(opts.GroupBy)), groups{g});
                vals = tbl.(vars{v})(mask);
            else
                vals = tbl.(vars{v});
            end
            vals = vals(~isnan(vals));

            row = struct();
            row.Variable = getLabel(vars{v}, opts.Labels);
            row.Group = groups{g};
            row.n = length(vals);
            row.M = mean(vals);
            row.SD = std(vals);
            if opts.IncludeRange
                row.Min = min(vals);
                row.Max = max(vals);
            end
            rows{end+1} = row; %#ok<AGROW>
        end
    end

    if isempty(rows)
        T = table();
        return;
    end

    S = [rows{:}];
    if isscalar(S)
        T = struct2table(S, 'AsArray', true);
    else
        T = struct2table(S);
    end
    T.Variable = string(T.Variable);
    T.Group = string(T.Group);

    if ~hasGroup
        T.Group = [];
    end
end


%% Type: comparisons

function T = buildComparisons(tbl, opts)
% Build paired or unpaired comparison table with t-tests and effect sizes

    vars = opts.variables;

    if isempty(opts.GroupBy)
        error('exploreFNIRS:stats:behavioralTable', ...
            'GroupBy is required for Type=''comparisons''.');
    end

    groups = categories(categorical(tbl.(opts.GroupBy)));

    % Generate comparison pairs
    if isempty(opts.Comparisons)
        pairs = {};
        for i = 1:length(groups)
            for j = (i+1):length(groups)
                pairs{end+1} = {groups{i}, groups{j}}; %#ok<AGROW>
            end
        end
    else
        pairs = opts.Comparisons;
    end

    % Labels for comparisons
    compLabels = opts.ComparisonLabels;
    if length(compLabels) < length(pairs)
        for k = (length(compLabels)+1):length(pairs)
            compLabels{k} = '';
        end
    end

    rows = {};
    for v = 1:length(vars)
        for c = 1:length(pairs)
            pairGroups = pairs{c};
            g1 = pairGroups{1};
            g2 = pairGroups{2};
            compName = [g1, '--', g2];

            varLabel = getLabel(vars{v}, opts.Labels);
            if opts.Paired
                row = pairedTest(tbl, vars{v}, opts, g1, g2, compName, compLabels{c}, varLabel);
            else
                row = unpairedTest(tbl, vars{v}, opts, g1, g2, compName, compLabels{c}, varLabel);
            end
            rows{end+1} = row; %#ok<AGROW>
        end
    end

    if isempty(rows)
        T = table();
        return;
    end

    S = [rows{:}];
    if isscalar(S)
        T = struct2table(S, 'AsArray', true);
    else
        T = struct2table(S);
    end
    T.Variable = string(T.Variable);
    T.Comparison = string(T.Comparison);
    T.Label = string(T.Label);
    T.Sig = string(T.Sig);
end


function row = pairedTest(tbl, varName, opts, g1, g2, compName, compLabel, varLabel)
% Paired t-test: match subjects across conditions via SubjectVar

    subVar = opts.SubjectVar;

    mask1 = strcmp(string(tbl.(opts.GroupBy)), g1);
    mask2 = strcmp(string(tbl.(opts.GroupBy)), g2);

    t1 = tbl(mask1, :);
    t2 = tbl(mask2, :);

    % Match subjects present in both conditions
    subs1 = string(t1.(subVar));
    subs2 = string(t2.(subVar));
    common = intersect(subs1, subs2);

    if isempty(common)
        row = emptyCompRow(varLabel, compName, compLabel);
        return;
    end

    [~, idx1] = ismember(common, subs1);
    [~, idx2] = ismember(common, subs2);

    vals1 = t1.(varName)(idx1);
    vals2 = t2.(varName)(idx2);

    % Remove NaN pairs
    valid = ~isnan(vals1) & ~isnan(vals2);
    vals1 = vals1(valid);
    vals2 = vals2(valid);
    n = length(vals1);

    if n < 2
        row = emptyCompRow(varLabel, compName, compLabel);
        row.n = n;
        return;
    end

    d = vals1 - vals2;
    meanDiff = mean(d);
    sdDiff = std(d);
    tStat = meanDiff / (sdDiff / sqrt(n));
    df = n - 1;
    pVal = 2 * (1 - tcdf(abs(tStat), df));
    dz = meanDiff / sdDiff;  % paired Cohen's d_z

    % 95% CI on the mean difference
    tCrit = tinv(0.975, df);
    sem = sdDiff / sqrt(n);
    ciLower = meanDiff - tCrit * sem;
    ciUpper = meanDiff + tCrit * sem;

    row = struct();
    row.Variable = varLabel;
    row.Comparison = compName;
    row.Label = compLabel;
    row.n = n;
    row.MeanDiff = meanDiff;
    row.SD_diff = sdDiff;
    row.t = tStat;
    row.df = df;
    row.p = pVal;
    row.d_z = dz;
    row.CI_lower = ciLower;
    row.CI_upper = ciUpper;
    row.Sig = sigStars(pVal);
end


function row = unpairedTest(tbl, varName, opts, g1, g2, compName, compLabel, varLabel)
% Independent samples t-test (Welch's)

    mask1 = strcmp(string(tbl.(opts.GroupBy)), g1);
    mask2 = strcmp(string(tbl.(opts.GroupBy)), g2);

    vals1 = tbl.(varName)(mask1);
    vals2 = tbl.(varName)(mask2);

    vals1 = vals1(~isnan(vals1));
    vals2 = vals2(~isnan(vals2));

    n1 = length(vals1);
    n2 = length(vals2);
    n = n1 + n2;

    if n1 < 2 || n2 < 2
        row = emptyCompRow(varLabel, compName, compLabel);
        row.n = n;
        return;
    end

    m1 = mean(vals1);
    m2 = mean(vals2);
    s1 = std(vals1);
    s2 = std(vals2);

    meanDiff = m1 - m2;
    se = sqrt(s1^2/n1 + s2^2/n2);
    tStat = meanDiff / se;

    % Welch-Satterthwaite df
    num = (s1^2/n1 + s2^2/n2)^2;
    den = (s1^2/n1)^2/(n1-1) + (s2^2/n2)^2/(n2-1);
    df = num / den;

    pVal = 2 * (1 - tcdf(abs(tStat), df));

    % Cohen's d (pooled SD)
    sp = sqrt(((n1-1)*s1^2 + (n2-1)*s2^2) / (n1+n2-2));
    dz = meanDiff / sp;

    tCrit = tinv(0.975, df);
    ciLower = meanDiff - tCrit * se;
    ciUpper = meanDiff + tCrit * se;

    row = struct();
    row.Variable = varLabel;
    row.Comparison = compName;
    row.Label = compLabel;
    row.n = n;
    row.MeanDiff = meanDiff;
    row.SD_diff = se;  % report SE for unpaired
    row.t = tStat;
    row.df = df;
    row.p = pVal;
    row.d_z = dz;
    row.CI_lower = ciLower;
    row.CI_upper = ciUpper;
    row.Sig = sigStars(pVal);
end


function row = emptyCompRow(varLabel, compName, compLabel)
    row = struct();
    row.Variable = varLabel;
    row.Comparison = compName;
    row.Label = compLabel;
    row.n = 0;
    row.MeanDiff = NaN;
    row.SD_diff = NaN;
    row.t = NaN;
    row.df = NaN;
    row.p = NaN;
    row.d_z = NaN;
    row.CI_lower = NaN;
    row.CI_upper = NaN;
    row.Sig = '';
end


%% Type: correlations

function T = buildCorrelations(tbl, opts)
% Build correlation table — one-to-many or many-to-many matrix

    if ~isempty(opts.YVar)
        T = buildCorrelationsOneToMany(tbl, opts);
    else
        T = buildCorrelationsMatrix(tbl, opts);
    end
end


function T = buildCorrelationsOneToMany(tbl, opts)
% One-to-many: correlate each variable in list with a single YVar

    vars = opts.variables;
    yVar = opts.YVar;
    prec = opts.Precision;

    rows = {};
    for v = 1:length(vars)
        x = tbl.(vars{v});
        y = tbl.(yVar);

        valid = ~isnan(x) & ~isnan(y);
        x = x(valid);
        y = y(valid);
        n = length(x);

        if n < 3
            row = struct();
            row.Variable = getLabel(vars{v}, opts.Labels);
            row.N = n;
            if strcmpi(opts.CorrMethod, 'spearman')
                row.rho = NaN; row.p = NaN;
            else
                row.r = NaN; row.p = NaN;
            end
            row.Sig = '';
            rows{end+1} = row; %#ok<AGROW>
            continue;
        end

        [rho, pVal] = corr(x, y, 'Type', opts.CorrMethod, 'Rows', 'complete');

        row = struct();
        row.Variable = getLabel(vars{v}, opts.Labels);
        row.N = n;
        if strcmpi(opts.CorrMethod, 'spearman')
            row.rho = round(rho, prec);
        else
            row.r = round(rho, prec);
        end
        row.p = pVal;
        row.Sig = sigStars(pVal);
        rows{end+1} = row; %#ok<AGROW>
    end

    if isempty(rows)
        T = table();
        return;
    end

    S = [rows{:}];
    if isscalar(S)
        T = struct2table(S, 'AsArray', true);
    else
        T = struct2table(S);
    end
    T.Variable = string(T.Variable);
    T.Sig = string(T.Sig);
end


function T = buildCorrelationsMatrix(tbl, opts)
% Many-to-many: correlation matrix between all variables in list

    vars = opts.variables;
    nVars = length(vars);
    prec = opts.Precision;

    % Build data matrix
    X = zeros(height(tbl), nVars);
    for v = 1:nVars
        X(:, v) = tbl.(vars{v});
    end

    [R, P] = corr(X, 'Type', opts.CorrMethod, 'Rows', 'pairwise');

    % Count pairwise N
    N = zeros(nVars);
    for i = 1:nVars
        for j = 1:nVars
            valid = ~isnan(X(:,i)) & ~isnan(X(:,j));
            N(i,j) = sum(valid);
        end
    end

    % Build formatted cell matrix
    labels = cell(1, nVars);
    for v = 1:nVars
        labels{v} = getLabel(vars{v}, opts.Labels);
    end

    cells = cell(nVars, nVars);
    for i = 1:nVars
        for j = 1:nVars
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
                cells{i,j} = '--';
            elseif show
                rStr = sprintf('%.*f', prec, R(i,j));
                rStr = regexprep(rStr, '^0\.', '.');
                rStr = regexprep(rStr, '^-0\.', '-.');
                cells{i,j} = [rStr, sigStars(P(i,j))];
            else
                cells{i,j} = '';
            end
        end
    end

    % Number the row labels
    rowLabels = cell(nVars, 1);
    for v = 1:nVars
        rowLabels{v} = sprintf('%d. %s', v, labels{v});
    end

    colLabels = arrayfun(@(x) sprintf('%d', x), 1:nVars, 'UniformOutput', false);
    T = cell2table(cells, 'VariableNames', matlab.lang.makeValidName(colLabels), ...
        'RowNames', rowLabels);

    % Store R, P, N as UserData for latex formatting
    T.Properties.UserData = struct('R', R, 'P', P, 'N', N, ...
        'labels', {labels}, 'CorrMethod', opts.CorrMethod, ...
        'Triangle', opts.Triangle, 'Precision', prec);
end


%% Console output

function printConsole(T, opts)
% Print formatted table to console

    switch lower(opts.Type)
        case 'descriptive'
            printConsoleDescriptive(T, opts);
        case 'comparisons'
            printConsoleComparisons(T, opts);
        case 'correlations'
            printConsoleCorrelations(T, opts);
    end
end


function printConsoleDescriptive(T, opts)
    prec = opts.Precision;
    hasGroup = ismember('Group', T.Properties.VariableNames);
    hasRange = opts.IncludeRange && ismember('Min', T.Properties.VariableNames);

    fprintf('\n  Descriptive Statistics');
    if hasGroup
        fprintf(' by %s', opts.GroupBy);
    end
    fprintf('\n');
    fprintf('  %s\n', repmat('-', 1, 60));

    if hasGroup
        groups = unique(T.Group, 'stable');
        vars = unique(T.Variable, 'stable');

        % Header
        fprintf('  %-25s', '');
        for g = 1:length(groups)
            gMask = T.Group == groups(g);
            n = T.n(find(gMask, 1));
            fprintf('  %-25s', sprintf('%s (n = %d)', groups(g), n));
        end
        fprintf('\n');
        fprintf('  %s\n', repmat('-', 1, 25 + 27*length(groups)));

        for v = 1:length(vars)
            fprintf('  %-25s', vars(v));
            for g = 1:length(groups)
                mask = T.Variable == vars(v) & T.Group == groups(g);
                row = T(mask, :);
                if hasRange
                    fprintf('  %.*f (%.*f) [%.*f, %.*f]  ', ...
                        prec, row.M, prec, row.SD, prec, row.Min, prec, row.Max);
                else
                    fprintf('  %.*f (%.*f)              ', prec, row.M, prec, row.SD);
                end
            end
            fprintf('\n');
        end
    else
        for r = 1:height(T)
            if hasRange
                fprintf('  %-25s  %.*f (%.*f) [%.*f, %.*f]  n = %d\n', ...
                    T.Variable(r), prec, T.M(r), prec, T.SD(r), ...
                    prec, T.Min(r), prec, T.Max(r), T.n(r));
            else
                fprintf('  %-25s  %.*f (%.*f)  n = %d\n', ...
                    T.Variable(r), prec, T.M(r), prec, T.SD(r), T.n(r));
            end
        end
    end

    fprintf('\n');
    if hasRange
        fprintf('  Note. Values are M (SD) [Min, Max].\n\n');
    else
        fprintf('  Note. Values are M (SD).\n\n');
    end
end


function printConsoleComparisons(T, opts)
    prec = opts.Precision;

    fprintf('\n  Paired Comparisons\n');
    fprintf('  %s\n', repmat('-', 1, 90));
    fprintf('  %-20s %-20s %5s %8s %8s %5s %8s\n', ...
        'Variable', 'Comparison', 'n', 'Delta M', 't(df)', 'p', 'd_z');
    fprintf('  %s\n', repmat('-', 1, 90));

    for r = 1:height(T)
        tdf = sprintf('%.*f(%d)', max(prec-1,2), T.t(r), round(T.df(r)));
        pStr = exploreFNIRS.report.formatPValue(T.p(r), 'Precision', prec);
        fprintf('  %-20s %-20s %5d %8.*f %8s %5s %8.*f\n', ...
            T.Variable(r), T.Comparison(r), T.n(r), ...
            prec, T.MeanDiff(r), tdf, pStr, prec, T.d_z(r));
    end
    fprintf('\n');
    if opts.Paired
        fprintf('  Note. d_z = paired Cohen''s d. CI = confidence interval on the mean difference.\n');
    else
        fprintf('  Note. Cohen''s d (pooled SD). CI = confidence interval on the mean difference.\n');
    end
    fprintf('  *p < .05, **p < .01, ***p < .001.\n\n');
end


function printConsoleCorrelations(T, opts)
    prec = opts.Precision;

    if ~isempty(T.Properties.RowNames)
        % Matrix format
        fprintf('\n  Correlation Matrix (%s)\n', opts.CorrMethod);
        fprintf('  %s\n', repmat('-', 1, 60));

        colNames = T.Properties.VariableNames;
        rowNames = T.Properties.RowNames;

        % Header
        fprintf('  %-25s', '');
        for c = 1:width(T)
            fprintf(' %8s', colNames{c});
        end
        fprintf('\n');
        fprintf('  %s\n', repmat('-', 1, 25 + 9*width(T)));

        for r = 1:height(T)
            fprintf('  %-25s', rowNames{r});
            for c = 1:width(T)
                fprintf(' %8s', T{r,c}{1});
            end
            fprintf('\n');
        end
        if ~isempty(T.Properties.UserData)
            Nmin = min(T.Properties.UserData.N(:));
            Nmax = max(T.Properties.UserData.N(:));
            if Nmin == Nmax
                fprintf('\n  Note. N = %d.', Nmin);
            else
                fprintf('\n  Note. N = %d-%d.', Nmin, Nmax);
            end
        end
    else
        % One-to-many format
        corrSym = 'rho';
        if strcmpi(opts.CorrMethod, 'pearson')
            corrSym = 'r';
        end
        fprintf('\n  Correlations with %s (%s)\n', opts.YVar, opts.CorrMethod);
        fprintf('  %s\n', repmat('-', 1, 55));
        fprintf('  %-25s %8s %8s %5s\n', 'Measure', corrSym, 'p', 'N');
        fprintf('  %s\n', repmat('-', 1, 55));

        for r = 1:height(T)
            if ismember('rho', T.Properties.VariableNames)
                rVal = T.rho(r);
            else
                rVal = T.r(r);
            end
            pStr = exploreFNIRS.report.formatPValue(T.p(r), 'Precision', prec);
            fprintf('  %-25s %8.*f %8s %5d\n', ...
                T.Variable(r), prec, rVal, pStr, T.N(r));
        end
    end
    fprintf('\n  %s correlations.', capitalize(opts.CorrMethod));
    fprintf('\n  *p < .05, **p < .01, ***p < .001.\n\n');
end


%% LaTeX output

function printLatex(T, opts)
% Print LaTeX booktabs table

    switch lower(opts.Type)
        case 'descriptive'
            printLatexDescriptive(T, opts);
        case 'comparisons'
            printLatexComparisons(T, opts);
        case 'correlations'
            printLatexCorrelations(T, opts);
    end
end


function printLatexDescriptive(T, opts)
    prec = opts.Precision;
    hasGroup = ismember('Group', T.Properties.VariableNames);
    hasRange = opts.IncludeRange && ismember('Min', T.Properties.VariableNames);

    caption = opts.Caption;
    if isempty(caption)
        caption = 'Descriptive Statistics';
        if hasGroup
            caption = sprintf('Descriptive Statistics by %s', opts.GroupBy);
        end
    end

    if hasGroup
        groups = unique(T.Group, 'stable');
        vars = unique(T.Variable, 'stable');
        nGroups = length(groups);

        % Build alignment: l for variable name + l per group
        align = ['l', repmat('l', 1, nGroups)];

        fprintf('\\begin{table}[htbp]\n');
        fprintf('\\centering\n');
        fprintf('\\caption{%s}\n', caption);
        fprintf('\\begin{tabular}{%s}\n', align);
        fprintf('\\toprule\n');

        % Header with n per group
        fprintf(' ');
        for g = 1:nGroups
            gMask = T.Group == groups(g);
            n = T.n(find(gMask, 1));
            fprintf(' & %s ($n$ = %d)', groups(g), n);
        end
        fprintf(' \\\\\n');
        fprintf('\\midrule\n');

        for v = 1:length(vars)
            fprintf('%s', vars(v));
            for g = 1:nGroups
                mask = T.Variable == vars(v) & T.Group == groups(g);
                row = T(mask, :);
                if hasRange
                    fprintf(' & %.*f (%.*f) [%.*f, %.*f]', ...
                        prec, row.M, prec, row.SD, prec, row.Min, prec, row.Max);
                else
                    fprintf(' & %.*f (%.*f)', prec, row.M, prec, row.SD);
                end
            end
            fprintf(' \\\\\n');
        end

        fprintf('\\bottomrule\n');
        fprintf('\\end{tabular}\n');
        if hasRange
            fprintf('\\par\\smallskip\\footnotesize\\textit{Note.} Values are $M$ ($SD$) [Min, Max].\n');
        else
            fprintf('\\par\\smallskip\\footnotesize\\textit{Note.} Values are $M$ ($SD$).\n');
        end
        fprintf('\\end{table}\n');
    else
        % No groups — simple table
        if hasRange
            align = 'lrrrrrr';
            fprintf('\\begin{table}[htbp]\n');
            fprintf('\\centering\n');
            fprintf('\\caption{%s}\n', caption);
            fprintf('\\begin{tabular}{%s}\n', align);
            fprintf('\\toprule\n');
            fprintf('Variable & $n$ & $M$ & $SD$ & Min & Max \\\\\n');
            fprintf('\\midrule\n');
            for r = 1:height(T)
                fprintf('%s & %d & %.*f & %.*f & %.*f & %.*f \\\\\n', ...
                    T.Variable(r), T.n(r), prec, T.M(r), prec, T.SD(r), ...
                    prec, T.Min(r), prec, T.Max(r));
            end
        else
            align = 'lrrr';
            fprintf('\\begin{table}[htbp]\n');
            fprintf('\\centering\n');
            fprintf('\\caption{%s}\n', caption);
            fprintf('\\begin{tabular}{%s}\n', align);
            fprintf('\\toprule\n');
            fprintf('Variable & $n$ & $M$ & $SD$ \\\\\n');
            fprintf('\\midrule\n');
            for r = 1:height(T)
                fprintf('%s & %d & %.*f & %.*f \\\\\n', ...
                    T.Variable(r), T.n(r), prec, T.M(r), prec, T.SD(r));
            end
        end
        fprintf('\\bottomrule\n');
        fprintf('\\end{tabular}\n');
        fprintf('\\end{table}\n');
    end
end


function printLatexComparisons(T, opts)
    prec = opts.Precision;

    caption = opts.Caption;
    if isempty(caption)
        if opts.Paired
            caption = 'Paired Comparisons';
        else
            caption = 'Independent Samples Comparisons';
        end
    end

    fprintf('\\begin{table}[htbp]\n');
    fprintf('\\centering\n');
    fprintf('\\caption{%s}\n', caption);
    fprintf('\\begin{tabular}{llrrrrrl}\n');
    fprintf('\\toprule\n');
    fprintf('Variable & Comparison & $n$ & $\\Delta M$ & $t$($df$) & $p$ & $d_z$ & 95\\%% CI \\\\\n');
    fprintf('\\midrule\n');

    for r = 1:height(T)
        tdf = sprintf('%.2f(%d)', T.t(r), round(T.df(r)));
        pStr = formatPValueLatex(T.p(r), prec);
        ciStr = formatCILatex(T.CI_lower(r), T.CI_upper(r), prec);

        fprintf('%s & %s & %d & %.*f & %s & %s & %.*f & %s \\\\\n', ...
            T.Variable(r), strrep(char(T.Comparison(r)), '--', '--'), ...
            T.n(r), prec, T.MeanDiff(r), tdf, pStr, prec, T.d_z(r), ciStr);
    end

    fprintf('\\bottomrule\n');
    fprintf('\\end{tabular}\n');
    if opts.Paired
        fprintf('\\par\\smallskip\\footnotesize\\textit{Note.} $d_z$ = paired Cohen''s $d$. CI = confidence interval on the mean difference.\n');
    else
        fprintf('\\par\\smallskip\\footnotesize\\textit{Note.} $d$ = Cohen''s $d$ (pooled $SD$). CI = confidence interval on the mean difference.\n');
    end
    fprintf('$^{*}p < .05$, $^{**}p < .01$, $^{***}p < .001$.\n');
    fprintf('\\end{table}\n');
end


function printLatexCorrelations(T, opts)
    prec = opts.Precision;

    if ~isempty(T.Properties.RowNames)
        % Matrix format
        printLatexCorrMatrix(T, opts, prec);
    else
        % One-to-many format
        printLatexCorrOneToMany(T, opts, prec);
    end
end


function printLatexCorrOneToMany(T, opts, prec)
    caption = opts.Caption;
    if isempty(caption)
        yLabel = opts.YVar;
        if isfield(opts.Labels, opts.YVar)
            yLabel = opts.Labels.(opts.YVar);
        end
        caption = sprintf('Correlations with %s', yLabel);
    end

    isSpearman = strcmpi(opts.CorrMethod, 'spearman');
    corrSym = '$\rho$';
    if ~isSpearman
        corrSym = '$r$';
    end

    fprintf('\\begin{table}[htbp]\n');
    fprintf('\\centering\n');
    fprintf('\\caption{%s}\n', caption);
    fprintf('\\begin{tabular}{lrrl}\n');
    fprintf('\\toprule\n');
    fprintf('Measure & %s & $p$ & $N$ \\\\\n', corrSym);
    fprintf('\\midrule\n');

    for r = 1:height(T)
        if isSpearman
            rVal = T.rho(r);
        else
            rVal = T.r(r);
        end
        rStr = formatCorrValLatex(rVal, prec);
        pStr = formatPValueLatex(T.p(r), prec);

        fprintf('%s & %s & %s & %d \\\\\n', ...
            T.Variable(r), rStr, pStr, T.N(r));
    end

    fprintf('\\bottomrule\n');
    fprintf('\\end{tabular}\n');
    fprintf('\\par\\smallskip\\footnotesize\\textit{Note.} %s rank correlations.\n', ...
        capitalize(opts.CorrMethod));
    fprintf('$^{*}p < .05$, $^{**}p < .01$, $^{***}p < .001$.\n');
    fprintf('\\end{table}\n');
end


function printLatexCorrMatrix(T, opts, prec)
    ud = T.Properties.UserData;
    nVars = length(ud.labels);
    R = ud.R;
    P = ud.P;

    caption = opts.Caption;
    if isempty(caption)
        caption = 'Correlation Matrix';
    end

    % Build alignment: l + c per column
    align = ['l', repmat('c', 1, nVars)];

    fprintf('\\begin{table}[htbp]\n');
    fprintf('\\centering\n');
    fprintf('\\caption{%s}\n', caption);
    fprintf('\\begin{tabular}{%s}\n', align);
    fprintf('\\toprule\n');

    % Header
    fprintf(' ');
    for v = 1:nVars
        fprintf(' & %d', v);
    end
    fprintf(' \\\\\n');
    fprintf('\\midrule\n');

    % Rows
    for i = 1:nVars
        fprintf('%d. %s', i, ud.labels{i});
        for j = 1:nVars
            if i == j
                fprintf(' & --');
            else
                switch lower(ud.Triangle)
                    case 'lower'
                        show = (j < i);
                    case 'upper'
                        show = (j > i);
                    case 'full'
                        show = true;
                    otherwise
                        show = (j < i);
                end
                if show
                    rStr = formatCorrValLatex(R(i,j), prec);
                    stars = sigStarsLatex(P(i,j));
                    fprintf(' & %s%s', rStr, stars);
                else
                    fprintf(' & ');
                end
            end
        end
        fprintf(' \\\\\n');
    end

    fprintf('\\bottomrule\n');
    fprintf('\\end{tabular}\n');

    Nmin = min(ud.N(~eye(nVars)));
    Nmax = max(ud.N(~eye(nVars)));
    if Nmin == Nmax
        nStr = sprintf('$N = %d$', Nmin);
    else
        nStr = sprintf('$N = %d$--%d', Nmin, Nmax);
    end
    fprintf('\\par\\smallskip\\footnotesize\\textit{Note.} %s. %s correlations. %s triangle shown.\n', ...
        nStr, capitalize(ud.CorrMethod), capitalize(ud.Triangle));
    fprintf('$^{*}p < .05$, $^{**}p < .01$, $^{***}p < .001$.\n');
    fprintf('\\end{table}\n');
end


%% Shared helpers

function s = sigStars(p)
    if isnan(p)
        s = '';
    elseif p < 0.001
        s = '***';
    elseif p < 0.01
        s = '**';
    elseif p < 0.05
        s = '*';
    else
        s = '';
    end
end


function s = sigStarsLatex(p)
% Significance stars wrapped in math mode for LaTeX
    if isnan(p)
        s = '';
    elseif p < 0.001
        s = '$^{***}$';
    elseif p < 0.01
        s = '$^{**}$';
    elseif p < 0.05
        s = '$^{*}$';
    else
        s = '';
    end
end


function s = formatPValueLatex(p, prec)
% APA-style p-value for LaTeX (no leading zero)
    if isnan(p)
        s = '';
    elseif p < 0.001
        s = '< .001';
    else
        raw = sprintf('%.*f', prec, p);
        s = regexprep(raw, '^0', '');
    end
end


function s = formatCorrValLatex(r, prec)
% Format correlation coefficient for LaTeX, with $-$ for negative
    if isnan(r)
        s = '';
        return;
    end
    rStr = sprintf('%.*f', prec, abs(r));
    rStr = regexprep(rStr, '^0\.', '.');
    if r < 0
        s = ['$-$', rStr];
    else
        s = rStr;
    end
end


function s = formatCILatex(lo, hi, prec)
% Format 95% CI for LaTeX
    if isnan(lo) || isnan(hi)
        s = '';
        return;
    end
    loStr = sprintf('%.*f', prec, lo);
    hiStr = sprintf('%.*f', prec, hi);
    % Use $-$ for negative values
    if lo < 0
        loStr = sprintf('$-$%.*f', prec, abs(lo));
    end
    if hi < 0
        hiStr = sprintf('$-$%.*f', prec, abs(hi));
    end
    s = sprintf('[%s, %s]', loStr, hiStr);
end


function label = getLabel(varName, labels)
% Get display label for a variable, or use the variable name itself
%   Supports struct, containers.Map, or Nx2 cell array of {key, label} pairs
    if isa(labels, 'containers.Map')
        if labels.isKey(varName)
            label = labels(varName);
        else
            label = varName;
        end
    elseif iscell(labels) && size(labels, 2) >= 2
        idx = find(strcmp(labels(:,1), varName), 1);
        if ~isempty(idx)
            label = labels{idx, 2};
        else
            label = varName;
        end
    elseif isstruct(labels)
        safeKey = matlab.lang.makeValidName(varName);
        if isfield(labels, varName)
            label = labels.(varName);
        elseif isfield(labels, safeKey)
            label = labels.(safeKey);
        else
            label = varName;
        end
    else
        label = varName;
    end
end


function s = capitalize(str)
% Capitalize first letter
    str = char(str);
    if isempty(str)
        s = str;
        return;
    end
    s = [upper(str(1)), str(2:end)];
end
