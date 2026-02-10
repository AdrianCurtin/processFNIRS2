function [plotByValues, subGroups, withinLabels, plotByIdx] = splitGroupsByFactor(groups, plotByVar)
% SPLITGROUPSBYFACTOR Split groups array by a factor for PlotBy visualization
%
% Given a groups struct array and a factor name, splits the groups into
% subsets based on unique values of that factor. Used by plotBar,
% plotTemporal, and plotScatter to implement the PlotBy parameter.
%
% Syntax:
%   [vals, subs, labels, idx] = splitGroupsByFactor(groups, plotByVar)
%
% Inputs:
%   groups    - Struct array from Experiment.groups
%   plotByVar - Name of the groupby variable to split on (e.g., 'Condition')
%
% Outputs:
%   plotByValues - Cell array of unique values for the PlotBy variable
%   subGroups    - Cell array, each element is a struct array subset
%   withinLabels - Cell array of labels (one per group, PlotBy factor removed)
%   plotByIdx    - Vector mapping each group index to its PlotBy value index
%
% Example:
%   % With groups from groupby({'Group','Condition'}):
%   %   groups(1).label = 'Control | TaskA'
%   %   groups(2).label = 'Control | TaskB'
%   %   groups(3).label = 'Treatment | TaskA'
%   %   groups(4).label = 'Treatment | TaskB'
%
%   [vals, subs, labels, idx] = splitGroupsByFactor(groups, 'Condition');
%   % vals = {'TaskA', 'TaskB'}
%   % subs{1} = groups([1,3])  (TaskA groups)
%   % subs{2} = groups([2,4])  (TaskB groups)
%   % labels = {'Control', 'Control', 'Treatment', 'Treatment'}
%   % idx = [1, 2, 1, 2]
%
% See also: exploreFNIRS.core.plotBar, exploreFNIRS.core.plotTemporal

    nGroups = length(groups);

    % Extract the PlotBy factor value from each group
    factorValues = cell(1, nGroups);
    for g = 1:nGroups
        T = groups(g).gbyTables;
        if ~ismember(plotByVar, T.Properties.VariableNames)
            error('exploreFNIRS:core:splitGroupsByFactor', ...
                'PlotBy variable "%s" not found in group tables. Available: %s', ...
                plotByVar, strjoin(T.Properties.VariableNames, ', '));
        end
        val = T.(plotByVar)(1);
        if isnumeric(val)
            factorValues{g} = num2str(val);
        else
            factorValues{g} = char(string(val));
        end
    end

    [plotByValues, ~, plotByIdx] = unique(factorValues, 'stable');
    nSplits = length(plotByValues);

    subGroups = cell(1, nSplits);
    for s = 1:nSplits
        subGroups{s} = groups(plotByIdx == s);
    end

    % Build within-group labels (remove the PlotBy value from label)
    withinLabels = cell(1, nGroups);
    for g = 1:nGroups
        parts = strsplit(groups(g).label, ' | ');
        pbVal = factorValues{g};
        keepParts = parts(~strcmp(parts, pbVal));
        if isempty(keepParts)
            withinLabels{g} = groups(g).label;
        else
            withinLabels{g} = strjoin(keepParts, ' | ');
        end
    end
end
