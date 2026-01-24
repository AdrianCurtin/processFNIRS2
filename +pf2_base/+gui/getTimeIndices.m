function [timeInd, startIdx, endIdx] = getTimeIndices(time, startTime, endTime)
% GETTIMEINDICES Get logical and numeric indices for a time window
%
% Returns indices for selecting a subset of time-series data based on
% start and end times. Use this when you need indices for plotting
% without copying the actual data. For extracting data, use pf2.data.crop
% or pf2.data.split instead.
%
% Syntax:
%   [timeInd, startIdx, endIdx] = pf2_base.gui.getTimeIndices(time, startTime, endTime)
%
% Inputs:
%   time      - Time vector [T x 1]
%   startTime - Window start time (seconds)
%   endTime   - Window end time (seconds)
%
% Outputs:
%   timeInd   - Logical index [T x 1] (true for samples in window)
%   startIdx  - Numeric start index (first sample >= startTime)
%   endIdx    - Numeric end index (first sample >= endTime, or last sample)
%
% Example:
%   time = 0:0.1:100;
%   [idx, s, e] = pf2_base.gui.getTimeIndices(time, 20, 40);
%   plot(time(idx), data(idx, :));
%
% See also: pf2.data.crop, pf2.data.split

% Handle empty input
if isempty(time)
    timeInd = logical([]);
    startIdx = 1;
    endIdx = 1;
    return;
end

% Find start index
startIdx = find(time >= startTime, 1);
if isempty(startIdx)
    startIdx = 1;
end

% Find end index
endIdx = find(time >= endTime, 1);
if isempty(endIdx)
    endIdx = length(time);
end

% Handle reversed times
if endIdx < startIdx
    [startIdx, endIdx] = deal(endIdx, startIdx);
end

% Build logical index
timeInd = false(size(time));
timeInd(startIdx:endIdx) = true;
end
