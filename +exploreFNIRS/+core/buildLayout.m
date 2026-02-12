function layout = buildLayout(groups, dimMap, channels, biomarkers)
% BUILDLAYOUT Compute subplot grid from dimension mapping
%
% Given a groups struct array and a dimension mapping (which variable maps
% to X, Color, SubplotRows, SubplotCols), computes the subplot grid and
% returns a struct array describing each cell.
%
% Syntax:
%   layout = buildLayout(groups, dimMap, channels, biomarkers)
%
% Inputs:
%   groups     - Struct array from Experiment.groups (after aggregate())
%   dimMap     - Struct with fields:
%                  .X           - Variable for X-axis (bar/scatter) or '' (temporal)
%                  .Color       - Variable for color/legend or ''
%                  .SubplotRows - Variable for facet rows or ''
%                  .SubplotCols - Variable for facet cols or ''
%   channels   - Numeric vector of channel indices
%   biomarkers - Cell array of biomarker names
%
% Outputs:
%   layout - Struct with fields:
%     .nRows       - Number of subplot rows
%     .nCols       - Number of subplot columns
%     .cells       - [nRows x nCols] struct array, each with:
%                      .groupIdx   - Indices into groups for this cell
%                      .channel    - Channel index (or [] for all)
%                      .biomarker  - Biomarker name (or '' for default)
%                      .rowLabel   - Row facet label
%                      .colLabel   - Column facet label
%                      .xValues    - Unique X-axis values for this cell
%                      .colorValues - Unique Color values for this cell
%     .rowValues   - Cell array of row facet labels
%     .colValues   - Cell array of column facet labels
%     .xVar        - X variable name (may be interaction 'A:B')
%     .colorVar    - Color variable name
%
% See also: exploreFNIRS.core.PlotProxy

    nGroups = length(groups);

    % Extract factor values from group tables
    factorCache = struct();

    % Parse interaction terms (e.g., 'Condition:Group' -> {'Condition','Group'})
    xVar = dimMap.X;
    colorVar = dimMap.Color;
    rowVar = dimMap.SubplotRows;
    colVar = dimMap.SubplotCols;

    % Get unique values for each dimension
    rowValues = getFactorValues(groups, rowVar, factorCache);
    colValues = getFactorValues(groups, colVar, factorCache);
    xValues = getFactorValues(groups, xVar, factorCache);
    colorValues = getFactorValues(groups, colorVar, factorCache);

    % Determine subplot grid dimensions
    nRowFacets = max(1, length(rowValues));
    nColFacets = max(1, length(colValues));

    % Build cells
    cells = struct([]);
    for r = 1:nRowFacets
        for c = 1:nColFacets
            % Find groups matching this cell's facet values
            gIdx = 1:nGroups;
            if ~isempty(rowValues)
                gIdx = filterByFactor(groups, rowVar, rowValues{r}, gIdx);
            end
            if ~isempty(colValues)
                gIdx = filterByFactor(groups, colVar, colValues{c}, gIdx);
            end

            cellIdx = sub2ind([nColFacets, nRowFacets], c, r);
            cells(cellIdx).groupIdx = gIdx;
            cells(cellIdx).channel = channels;
            cells(cellIdx).biomarker = '';
            if ~isempty(rowValues)
                cells(cellIdx).rowLabel = rowValues{r};
            else
                cells(cellIdx).rowLabel = '';
            end
            if ~isempty(colValues)
                cells(cellIdx).colLabel = colValues{c};
            else
                cells(cellIdx).colLabel = '';
            end

            % X and Color values for this cell's groups
            cells(cellIdx).xValues = getFactorValuesForGroups(groups, xVar, gIdx);
            cells(cellIdx).colorValues = getFactorValuesForGroups(groups, colorVar, gIdx);
        end
    end

    layout.nRows = nRowFacets;
    layout.nCols = nColFacets;
    layout.cells = cells;
    layout.rowValues = rowValues;
    layout.colValues = colValues;
    layout.xVar = xVar;
    layout.colorVar = colorVar;
    layout.xValues = xValues;
    layout.colorValues = colorValues;
end


function values = getFactorValues(groups, varSpec, ~)
% Get unique values for a variable (or interaction term) across all groups
    if isempty(varSpec)
        values = {};
        return;
    end

    nGroups = length(groups);
    vals = cell(1, nGroups);

    if contains(varSpec, ':')
        % Interaction term
        parts = strsplit(varSpec, ':');
        for g = 1:nGroups
            T = groups(g).gbyTables;
            subVals = cell(1, length(parts));
            for p = 1:length(parts)
                v = T.(parts{p})(1);
                if isnumeric(v)
                    subVals{p} = num2str(v);
                else
                    subVals{p} = char(string(v));
                end
            end
            vals{g} = strjoin(subVals, ':');
        end
    else
        for g = 1:nGroups
            T = groups(g).gbyTables;
            if ~ismember(varSpec, T.Properties.VariableNames)
                vals{g} = '';
                continue;
            end
            v = T.(varSpec)(1);
            if isnumeric(v)
                vals{g} = num2str(v);
            else
                vals{g} = char(string(v));
            end
        end
    end

    values = unique(vals, 'stable');
end


function values = getFactorValuesForGroups(groups, varSpec, gIdx)
% Get unique factor values for a subset of groups
    if isempty(varSpec) || isempty(gIdx)
        values = {};
        return;
    end

    vals = cell(1, length(gIdx));
    for i = 1:length(gIdx)
        g = gIdx(i);
        T = groups(g).gbyTables;

        if contains(varSpec, ':')
            parts = strsplit(varSpec, ':');
            subVals = cell(1, length(parts));
            for p = 1:length(parts)
                v = T.(parts{p})(1);
                if isnumeric(v)
                    subVals{p} = num2str(v);
                else
                    subVals{p} = char(string(v));
                end
            end
            vals{i} = strjoin(subVals, ':');
        else
            if ~ismember(varSpec, T.Properties.VariableNames)
                vals{i} = '';
                continue;
            end
            v = T.(varSpec)(1);
            if isnumeric(v)
                vals{i} = num2str(v);
            else
                vals{i} = char(string(v));
            end
        end
    end

    values = unique(vals, 'stable');
end


function gIdx = filterByFactor(groups, varSpec, targetValue, candidates)
% Filter group indices to those matching a specific factor value
    gIdx = [];
    for i = 1:length(candidates)
        g = candidates(i);
        T = groups(g).gbyTables;

        if contains(varSpec, ':')
            parts = strsplit(varSpec, ':');
            subVals = cell(1, length(parts));
            for p = 1:length(parts)
                v = T.(parts{p})(1);
                if isnumeric(v)
                    subVals{p} = num2str(v);
                else
                    subVals{p} = char(string(v));
                end
            end
            val = strjoin(subVals, ':');
        else
            if ~ismember(varSpec, T.Properties.VariableNames)
                continue;
            end
            v = T.(varSpec)(1);
            if isnumeric(v)
                val = num2str(v);
            else
                val = char(string(v));
            end
        end

        if strcmp(val, targetValue)
            gIdx(end+1) = g; %#ok<AGROW>
        end
    end
end


