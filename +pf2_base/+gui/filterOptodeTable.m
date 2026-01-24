function [singleTable, roiTable, mergedSingleTable] = filterOptodeTable(optTable, selectedIdx, varargin)
% FILTEROPTODETABLE Filter optode table by selection and rejection status
%
% Filters an optode table based on GUI selections and channel rejection
% flags. Returns separate tables for single optodes and ROIs, plus a
% merged table that includes individual channels from selected ROIs.
%
% This helper reduces code duplication in processFNIRS2_GUI where similar
% filtering logic is repeated in each stage plotting block.
%
% Syntax:
%   [singleTable, roiTable] = pf2_base.gui.filterOptodeTable(optTable, selectedIdx)
%   [singleTable, roiTable, mergedSingleTable] = pf2_base.gui.filterOptodeTable(...)
%   [...] = pf2_base.gui.filterOptodeTable(..., 'Name', Value)
%
% Inputs:
%   optTable       - Full optode table from GUI
%   selectedIdx    - Indices of selected rows (from listbox)
%   'excludeManualRej' - Exclude manually rejected channels (default: true)
%   'excludeAutoRej'   - Exclude auto-rejected channels (default: false)
%
% Outputs:
%   singleTable       - Table of selected single optodes (non-ROI)
%   roiTable          - Table of selected ROIs
%   mergedSingleTable - singleTable + individual channels from ROIs
%
% Example:
%   [single, roi] = pf2_base.gui.filterOptodeTable(optTable, listboxValue);
%   % Plot single channels
%   for i = 1:height(single)
%       plot(time, data(:, single.OptIndex(i)));
%   end
%
% See also: processFNIRS2_GUI, UpdateOptodeList

p = inputParser;
addRequired(p, 'optTable');
addRequired(p, 'selectedIdx');
addParameter(p, 'excludeManualRej', true, @islogical);
addParameter(p, 'excludeAutoRej', false, @islogical);
parse(p, optTable, selectedIdx, varargin{:});

excludeManualRej = p.Results.excludeManualRej;
excludeAutoRej = p.Results.excludeAutoRej;

% Handle empty table
if isempty(optTable) || height(optTable) == 0
    singleTable = table();
    roiTable = table();
    mergedSingleTable = table();
    return;
end

% Filter by selection
if isempty(selectedIdx)
    plotOptTable = optTable;
else
    % Ensure indices are valid
    validIdx = selectedIdx(selectedIdx <= height(optTable) & selectedIdx >= 1);
    if isempty(validIdx)
        singleTable = table();
        roiTable = table();
        mergedSingleTable = table();
        return;
    end
    plotOptTable = optTable(validIdx, :);
end

% Apply rejection filters
if excludeManualRej && ismember('ManualRej', plotOptTable.Properties.VariableNames)
    plotOptTable = plotOptTable(~plotOptTable.ManualRej, :);
end

if excludeAutoRej && ismember('AutoRej', plotOptTable.Properties.VariableNames)
    plotOptTable = plotOptTable(~plotOptTable.AutoRej, :);
end

% Check for IsROI column
if ~ismember('IsROI', plotOptTable.Properties.VariableNames)
    % No ROI column - return all as single channels
    singleTable = plotOptTable;
    roiTable = table();
    mergedSingleTable = plotOptTable;
    return;
end

% Separate ROIs from single channels
roiMask = plotOptTable.IsROI == 1;
roiTable = plotOptTable(roiMask, :);
singleTable = plotOptTable(~roiMask, :);

% Build merged table (single channels + individual channels from ROIs)
if nargout >= 3
    if height(roiTable) > 0 && ismember('Optodes_roi', roiTable.Properties.VariableNames)
        % Get all individual channel numbers from ROIs
        allROIch = [];
        for idx = 1:height(roiTable)
            roiChannels = roiTable.Optodes_roi{idx};
            if ~isempty(roiChannels)
                allROIch = [allROIch, roiChannels];
            end
        end
        allROIch = unique(allROIch);

        % Find these channels in the full table
        if ~isempty(allROIch) && ismember('Optode', optTable.Properties.VariableNames)
            roiSingleIdx = ~optTable.IsROI & ismember(optTable.Optode, allROIch);
            if any(roiSingleIdx)
                roiSingleTable = optTable(roiSingleIdx, :);
                % Merge with single table, avoiding duplicates
                if height(singleTable) > 0
                    existingOptodes = singleTable.Optode;
                    newRows = ~ismember(roiSingleTable.Optode, existingOptodes);
                    mergedSingleTable = [singleTable; roiSingleTable(newRows, :)];
                else
                    mergedSingleTable = roiSingleTable;
                end
            else
                mergedSingleTable = singleTable;
            end
        else
            mergedSingleTable = singleTable;
        end
    else
        mergedSingleTable = singleTable;
    end
end
end
