function [fig, stats] = plotNeuralEfficiencyFromTable(T, varargin)
% PLOTNEURALEFFICIENCYFROMTABLE Neural efficiency plot from a table
%
% Creates a neural efficiency scatter plot from a MATLAB table with
% columns for X values, Y values, and optional group/subgroup assignments.
% Useful when data comes from external sources or when you want to
% manually control the grouping and subgroup ordering.
%
% Convention: for neural efficiency plots, pass activation as XVar and
% performance as YVar so that efficient subjects (high performance,
% low activation) appear above the y=x identity line.
%
% Syntax:
%   [fig, stats] = plotNeuralEfficiencyFromTable(T, ...
%       'XVar', 'HbO_mean', 'YVar', 'accuracy')
%   [fig, stats] = plotNeuralEfficiencyFromTable(T, ...
%       'XVar', 'activation', 'YVar', 'RT', ...
%       'GroupVar', 'Diagnosis', 'SubgroupVar', 'Difficulty', ...
%       'ShowArrows', true)
%
% Inputs:
%   T - MATLAB table. Each row is one observation (subject/trial).
%
% Name-Value Parameters:
%   XVar         - (required) Column name for X-axis values
%   YVar         - (required) Column name for Y-axis values
%   GroupVar     - Column name for group assignment (color grouping).
%                  (default: '' = all data in one group)
%   SubgroupVar  - Column name for subgroup/condition within each group.
%                  Each unique (Group, Subgroup) combo becomes one scatter
%                  cloud. Same-group subgroups share a color and get
%                  arrow-connected when ShowArrows is true. Categorical
%                  columns use their defined category order; otherwise
%                  order is by first appearance in the table.
%                  (default: '' = no subgroups)
%   SubjectVar   - Column name for subject IDs (for ShowLabels).
%                  (default: '' = no labels)
%   SubgroupShading - How to color subgroups within a group:
%                  'gradient' (default): light-to-dark shading per subgroup,
%                  each subgroup gets its own legend entry.
%                  'uniform': all subgroups share the group's base color
%                  and a single legend entry.
%   Colors       - Color palette override. [N x 3] RGB matrix (one row
%                  per unique group), colormap name, or function handle.
%                  (default: [] = auto palette)
%
%   All additional parameters (ZScoreMode, InvertX, ReverseAxes,
%   ShowIdentity, ShowLabels, FitLine, ShowArrows, ArrowColor, Legend,
%   Title, XLabel, YLabel, Visible, SavePath, SaveWidth, SaveHeight,
%   SaveDPI) are passed through to plotNeuralEfficiencyCore.
%
% Outputs:
%   fig   - Figure handle
%   stats - Struct array [nItems x 1] with per-scatter-cloud statistics:
%           .r, .p, .rho, .pval, .N, .zX, .zY, .centroid, .label
%
% Example:
%   % Table with diagnosis groups and difficulty levels
%   T = table(hbo_mean, accuracy, diagnosis, difficulty, subjectID, ...
%       'VariableNames', {'HbO','Accuracy','Group','Difficulty','SID'});
%   [fig, stats] = exploreFNIRS.core.plotNeuralEfficiencyFromTable(T, ...
%       'XVar', 'HbO', 'YVar', 'Accuracy', ...
%       'GroupVar', 'Group', 'SubgroupVar', 'Difficulty', ...
%       'ShowArrows', true, 'FitLine', true);
%
% See also: plotNeuralEfficiencyCore, plotNeuralEfficiency

    p = inputParser;
    p.KeepUnmatched = true;
    addRequired(p, 'T', @istable);
    addParameter(p, 'XVar', '', @ischar);
    addParameter(p, 'YVar', '', @ischar);
    addParameter(p, 'GroupVar', '', @ischar);
    addParameter(p, 'SubgroupVar', '', @ischar);
    addParameter(p, 'SubjectVar', '', @ischar);
    addParameter(p, 'InvertX', false, @islogical);
    addParameter(p, 'XLabel', '', @ischar);
    addParameter(p, 'YLabel', '', @ischar);
    addParameter(p, 'Title', '', @ischar);
    addParameter(p, 'SubgroupShading', 'gradient', @(x) ismember(lower(x), {'gradient','uniform'}));
    addParameter(p, 'Colors', [], @(x) isempty(x) || isnumeric(x) || ischar(x) || isstring(x) || isa(x, 'function_handle'));
    parse(p, T, varargin{:});
    opts = p.Results;

    if isempty(opts.XVar)
        error('exploreFNIRS:core:plotNeuralEfficiencyFromTable', ...
            'XVar is required.');
    end
    if isempty(opts.YVar)
        error('exploreFNIRS:core:plotNeuralEfficiencyFromTable', ...
            'YVar is required.');
    end

    % Validate columns exist
    requiredCols = {opts.XVar, opts.YVar};
    optionalCols = {opts.GroupVar, opts.SubgroupVar, opts.SubjectVar};
    for i = 1:length(requiredCols)
        if ~ismember(requiredCols{i}, T.Properties.VariableNames)
            error('exploreFNIRS:core:plotNeuralEfficiencyFromTable', ...
                'Column "%s" not found in table.', requiredCols{i});
        end
    end
    for i = 1:length(optionalCols)
        if ~isempty(optionalCols{i}) && ...
                ~ismember(optionalCols{i}, T.Properties.VariableNames)
            error('exploreFNIRS:core:plotNeuralEfficiencyFromTable', ...
                'Column "%s" not found in table.', optionalCols{i});
        end
    end

    % Extract X and Y columns
    xAll = T.(opts.XVar);
    yAll = T.(opts.YVar);
    if ~isnumeric(xAll), xAll = double(string(xAll)); end
    if ~isnumeric(yAll), yAll = double(string(yAll)); end

    % Extract grouping columns
    hasGroup = ~isempty(opts.GroupVar);
    hasSub = ~isempty(opts.SubgroupVar);
    hasSubject = ~isempty(opts.SubjectVar);

    if hasGroup
        grpCol = T.(opts.GroupVar);
        grpOrder = extractOrder(grpCol);
        if isnumeric(grpCol), grpCol = string(grpCol); end
        if ~iscell(grpCol), grpCol = cellstr(grpCol); end
    end
    if hasSub
        subCol = T.(opts.SubgroupVar);
        subOrder = extractOrder(subCol);
        if isnumeric(subCol), subCol = string(subCol); end
        if ~iscell(subCol), subCol = cellstr(subCol); end
    end
    if hasSubject
        sidCol = T.(opts.SubjectVar);
        if ~iscell(sidCol), sidCol = cellstr(string(sidCol)); end
    end

    % --- Build plotGroups ---
    useGradient = strcmpi(opts.SubgroupShading, 'gradient');

    if hasGroup && hasSub
        % One plotGroup per (Group, Subgroup) combo
        uniqueGroups = grpOrder;
        uniqueSubs = subOrder;
        nGrp = length(uniqueGroups);
        nSub = length(uniqueSubs);
        nItems = nGrp * nSub;

        colors = exploreFNIRS.core.getGroupColors(nGrp, opts.Colors);

        % Build per-subgroup shaded colors
        if useGradient && nSub > 1
            subColors = cell(nGrp, 1);
            for gi = 1:nGrp
                subColors{gi} = shadeColor(colors(gi, :), nSub);
            end
        end

        pgTemplate = struct('x', [], 'y', [], 'label', '', ...
            'color', [], 'subjectIDs', {{}}, 'arrowChain', NaN);
        plotGroups = repmat(pgTemplate, 1, nItems);

        idx = 0;
        for gi = 1:nGrp
            for si = 1:nSub
                idx = idx + 1;
                mask = strcmp(grpCol, uniqueGroups{gi}) & ...
                       strcmp(subCol, uniqueSubs{si});
                plotGroups(idx).x = xAll(mask);
                plotGroups(idx).y = yAll(mask);
                plotGroups(idx).arrowChain = gi;
                if hasSubject
                    plotGroups(idx).subjectIDs = sidCol(mask);
                end

                if useGradient && nSub > 1
                    plotGroups(idx).color = subColors{gi}(si, :);
                    if nGrp > 1
                        plotGroups(idx).label = sprintf('%s: %s', ...
                            uniqueGroups{gi}, uniqueSubs{si});
                    else
                        plotGroups(idx).label = uniqueSubs{si};
                    end
                else
                    plotGroups(idx).color = colors(gi, :);
                    plotGroups(idx).label = uniqueGroups{gi};
                end
            end
        end

        % Remove empty combos
        empty = arrayfun(@(pg) isempty(pg.x), plotGroups);
        plotGroups(empty) = [];

    elseif hasGroup
        % One plotGroup per Group
        uniqueGroups = grpOrder;
        nGrp = length(uniqueGroups);
        colors = exploreFNIRS.core.getGroupColors(nGrp, opts.Colors);

        pgTemplate = struct('x', [], 'y', [], 'label', '', ...
            'color', [], 'subjectIDs', {{}}, 'arrowChain', 1);
        plotGroups = repmat(pgTemplate, 1, nGrp);

        for gi = 1:nGrp
            mask = strcmp(grpCol, uniqueGroups{gi});
            plotGroups(gi).x = xAll(mask);
            plotGroups(gi).y = yAll(mask);
            plotGroups(gi).label = uniqueGroups{gi};
            plotGroups(gi).color = colors(gi, :);
            plotGroups(gi).arrowChain = 1;
            if hasSubject
                plotGroups(gi).subjectIDs = sidCol(mask);
            end
        end

    elseif hasSub
        % Subgroups only (single group color, arrow-connected)
        uniqueSubs = subOrder;
        nSub = length(uniqueSubs);
        colors = exploreFNIRS.core.getGroupColors(1, opts.Colors);
        baseClr = colors(1, :);

        if useGradient && nSub > 1
            subClrs = shadeColor(baseClr, nSub);
        end

        pgTemplate = struct('x', [], 'y', [], 'label', '', ...
            'color', [], 'subjectIDs', {{}}, 'arrowChain', 1);
        plotGroups = repmat(pgTemplate, 1, nSub);

        for si = 1:nSub
            mask = strcmp(subCol, uniqueSubs{si});
            plotGroups(si).x = xAll(mask);
            plotGroups(si).y = yAll(mask);
            plotGroups(si).label = uniqueSubs{si};
            plotGroups(si).arrowChain = 1;
            if useGradient && nSub > 1
                plotGroups(si).color = subClrs(si, :);
            else
                plotGroups(si).color = baseClr;
            end
            if hasSubject
                plotGroups(si).subjectIDs = sidCol(mask);
            end
        end

    else
        % Single group: all data
        colors = exploreFNIRS.core.getGroupColors(1, opts.Colors);
        plotGroups = struct('x', xAll, 'y', yAll, 'label', 'All', ...
            'color', colors(1,:), 'subjectIDs', {{}}, 'arrowChain', NaN);
        if hasSubject
            plotGroups.subjectIDs = sidCol;
        end
    end

    % --- Generate default labels ---
    if isempty(opts.XLabel)
        lbl = pf2_base.plot.escapeTeX(opts.XVar);
        if opts.InvertX
            opts.XLabel = sprintf('%s (z-scored, inverted)', lbl);
        else
            opts.XLabel = sprintf('%s (z-scored)', lbl);
        end
    end
    if isempty(opts.YLabel)
        opts.YLabel = sprintf('%s (z-scored)', pf2_base.plot.escapeTeX(opts.YVar));
    end
    if isempty(opts.Title)
        opts.Title = sprintf('Neural Efficiency: %s vs %s', ...
            pf2_base.plot.escapeTeX(opts.XVar), ...
            pf2_base.plot.escapeTeX(opts.YVar));
    end

    % --- Delegate to core ---
    passthrough = unmatchedToCell(p.Unmatched);
    [fig, stats] = exploreFNIRS.core.plotNeuralEfficiencyCore(plotGroups, ...
        'InvertX', opts.InvertX, ...
        'XLabel', opts.XLabel, ...
        'YLabel', opts.YLabel, ...
        'Title', opts.Title, ...
        passthrough{:});
end


%% Local helpers

function order = extractOrder(col)
% Get unique values preserving categorical order when available
    if iscategorical(col)
        order = categories(col);
    else
        if isnumeric(col), col = string(col); end
        if ~iscell(col), col = cellstr(col); end
        order = unique(col, 'stable');
    end
end

function colors = shadeColor(baseRGB, n)
% Generate n shades from light to dark for a base color
%   First shade is lighter (blended toward white), last is the base color
%   or slightly darker. Returns [n x 3] RGB matrix.
    colors = zeros(n, 3);
    for i = 1:n
        t = (i - 1) / max(n - 1, 1);  % 0 = lightest, 1 = darkest
        % Blend from 60% toward white (light) to 15% darker than base
        lightened = baseRGB + 0.6 * (1 - t) * (1 - baseRGB);
        darkened  = baseRGB * (1 - 0.15 * t);
        colors(i, :) = (1 - t) * lightened + t * darkened;
    end
    colors = min(max(colors, 0), 1);
end

function args = unmatchedToCell(s)
% Convert inputParser Unmatched struct to name-value cell array
    fn = fieldnames(s);
    args = cell(1, 2 * numel(fn));
    for i = 1:numel(fn)
        args{2*i - 1} = fn{i};
        args{2*i} = s.(fn{i});
    end
end
