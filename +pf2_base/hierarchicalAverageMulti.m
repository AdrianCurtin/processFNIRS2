function [results,highestTier,outHarr]=hierarchicalAverageMulti(arr,hierachy,funcAvgs)
% HIERARCHICALAVERAGEMULTI Multi-function hierarchical averaging in one pass
%
% Performs hierarchical (nested) averaging with multiple aggregation
% functions simultaneously. Encodes the hierarchy once and traverses it
% once per level, applying all functions at each step. This eliminates
% redundant hierarchy encoding when multiple statistics (mean, median,
% max, min) are needed from the same data.
%
% Syntax:
%   results = hierarchicalAverageMulti(arr, hierarchy, funcAvgs)
%   [results, highestTier] = hierarchicalAverageMulti(arr, hierarchy, funcAvgs)
%   [results, highestTier, outHarr] = hierarchicalAverageMulti(arr, hierarchy, funcAvgs)
%
% Inputs:
%   arr       - Data array [N x M] or [N x M x P] where N = observations
%               Can be numeric array, cell array, or table.
%   hierarchy - Grouping structure [N x L] where L = hierarchy levels
%               Column 1 = highest level (e.g., Subject)
%               Column L = lowest level (e.g., Trial)
%               Can be cell array (strings/numbers) or numeric array.
%   funcAvgs  - Cell array of function handles, e.g. {@nanmean, @nanmedian}
%               Each must accept (data, dim) arguments.
%
% Outputs:
%   results     - Cell array of averaged data, one per function in funcAvgs
%   highestTier - Labels for each row from hierarchy column 1
%   outHarr     - Encoded hierarchy array (for debugging)
%
% Example:
%   arr = [10; 10; 5; 5; 2; 2];
%   hierarchy(:,1) = {'S1';'S1';'S1';'S1';'S2';'S2'};
%   hierarchy(:,2) = {1; 1; 2; 2; 1; 1};
%   funcs = {@nanmean, @nanmedian};
%   [results, subjects] = pf2_base.hierarchicalAverageMulti(arr, hierarchy, funcs);
%   % results{1} = nanmean result, results{2} = nanmedian result
%
% See also: pf2_base.hierarchicalAverage

if nargin < 3 || isempty(funcAvgs)
    funcAvgs = {@nanmean};
end

nFuncs = length(funcAvgs);

% Validate function handles
for f = 1:nFuncs
    if ischar(funcAvgs{f}) && exist(funcAvgs{f}, 'file') == 2
        funcAvgs{f} = str2func(funcAvgs{f});
    elseif ~isa(funcAvgs{f}, 'function_handle')
        error('Each element of funcAvgs must be a function handle or valid function name');
    end
end

% Convert input data
if iscell(arr)
    arr = cell2mat(arr);
elseif istable(arr)
    arr = table2array(arr);
end

numLevels = size(hierachy, 2);
numObservations = size(hierachy, 1);

if size(arr, 1) ~= numObservations && size(arr, 2) == numObservations
    arr = arr';
end

if size(arr, 1) ~= numObservations
    error('Hierarchy does not match input data');
end

% --- Encode hierarchy to numeric indices (done ONCE) ---
hierachyArr = nan(size(hierachy));

for i = 1:numLevels
    if iscell(hierachy)
        curLevel = hierachy(:, i);
        if isnumeric(curLevel{1})
            curLevel = cell2mat(curLevel);
        end
        [uVals, ~, uIdx] = unique(curLevel);
    elseif istable(hierachy)
        curLevel = hierachy(:, i);
        [uVals, ~, uIdx] = unique(curLevel);
    elseif isnumeric(hierachy)
        curLevel = hierachy(:, i);
        [uVals, ~, uIdx] = unique(curLevel);
    else
        error('unknown structure');
    end
    if i == 1
        highestTier = uVals;
    end
    hierachyArr(:, i) = uIdx;
end

% Build composite keys
for i = 1:numLevels-1
    hierachyArr(:, i+1) = hierachyArr(:, i+1) + hierachyArr(:, i) * 1000;
end

% Reorder within levels
outHierarchy = hierachy;
for i = 1:numLevels
    [uHArr, uFirstIdx, c] = unique(hierachyArr(:, i));
    [~, sortFirstIdx] = sort(uFirstIdx);
    newSort = nan(size(uHArr));
    newSort(sortFirstIdx) = 1:length(uHArr);
    hierachyArr(:, i) = newSort(c)';
end

outHarr = hierachyArr;

% --- Initialize per-function working copies ---
outAvgs = cell(1, nFuncs);
for f = 1:nFuncs
    outAvgs{f} = arr;
end

% --- Bottom-up traversal (done ONCE per level, all funcs applied) ---
for i = numLevels:-1:1
    [uVal, ~, uIdx] = unique(hierachyArr(:, i));

    if length(uVal) == length(uIdx) || isempty(uVal)
        outHierarchy = outHierarchy(:, 1:i);
        hierachyArr = hierachyArr(:, 1:i);
        outHarr(:, i) = [];
        continue;
    end

    nGroups = length(uVal);
    rows2keep = nan(nGroups, 1);

    % Pre-allocate new output for each function
    newOuts = cell(1, nFuncs);
    for f = 1:nFuncs
        newOuts{f} = nan(nGroups, size(outAvgs{f}, 2), size(outAvgs{f}, 3));
    end

    for i2 = 1:nGroups
        idx = hierachyArr(:, i) == i2;
        if ~any(idx)
            continue;
        end
        rows2keep(i2) = find(idx, 1, 'first');

        % Apply all functions to the same group slice
        for f = 1:nFuncs
            try
                newOuts{f}(i2, :, :) = funcAvgs{f}(outAvgs{f}(idx, :, :), 1);
            catch
                newOuts{f}(i2, :, :) = funcAvgs{f}(outAvgs{f}(idx, :, :));
            end
        end
    end

    for f = 1:nFuncs
        outAvgs{f} = newOuts{f};
    end

    outHierarchy = outHierarchy(rows2keep, 1:i);
    hierachyArr = hierachyArr(rows2keep, 1:i);
end

results = outAvgs;

if isempty(outHierarchy)
    highestTier = 1:size(results{1}, 1);
    highestTier = highestTier';
else
    highestTier = outHierarchy(:, 1);
end
