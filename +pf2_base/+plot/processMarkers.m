function [markerCodes, markerIdx, markerData, numMarkers] = processMarkers(fNIR, showMarkers, tooManyThreshold)
% PROCESSMARKERS Parse marker display specification for plotting
%
% Processes the marker display specification and returns marker codes,
% indices, and counts for use in plotting functions. Handles various
% input formats (logical, numeric, 'all') and extracts marker information
% from the fNIRS data structure.
%
% Syntax:
%   [markerCodes, markerIdx, markerData, numMarkers] = ...
%       pf2_base.plot.processMarkers(fNIR, showMarkers)
%   [...] = pf2_base.plot.processMarkers(fNIR, showMarkers, tooManyThreshold)
%
% Inputs:
%   fNIR             - fNIRS data structure with markers field
%   showMarkers      - Marker display specification:
%                      - true or 'all': Show all markers
%                      - false: Show no markers
%                      - Numeric array: Show only specified marker codes
%   tooManyThreshold - Threshold for "too many markers" warning (default: 100)
%                      Set to Inf to disable warning.
%
% Outputs:
%   markerCodes  - Unique marker codes to display [1 x M]
%                  Empty if no markers to show.
%   markerIdx    - Index mapping each marker to its code [N x 1]
%                  markerIdx(i) gives the index into markerCodes for marker i.
%   markerData   - Marker time data [N x 3] (time, code, duration)
%   numMarkers   - Count of markers for each code [1 x M]
%
% Example:
%   [codes, idx, data, counts] = pf2_base.plot.processMarkers(fNIR, true);
%   for i = 1:length(codes)
%       markerTimes = data(idx == i, 1);
%       plot_vertical_lines(markerTimes);
%   end
%
% See also: pf2.data.plot.oxy, pf2.data.plot.raw, pf2.data.plot.roi

if nargin < 3
    tooManyThreshold = 100;
end

% Initialize outputs
markerCodes = [];
markerIdx = [];
markerData = [];
numMarkers = [];

% Check if markers exist
if ~isfield(fNIR, 'markers') || isempty(fNIR.markers)
    return;
end

% Get marker data
markerData = fNIR.markers;
if ~isnumeric(markerData) && isfield(markerData, 'data')
    markerData = markerData.data;
end

% Handle 'all' string input
if ischar(showMarkers) && strcmpi(showMarkers, 'all')
    showMarkers = true;
end

% Process based on input type
if islogical(showMarkers)
    if ~showMarkers
        markerData = [];
        return;
    end
    % Show all markers
    [markerCodes, ~, markerIdx] = unique(markerData(:, 2));

elseif isnumeric(showMarkers)
    if isempty(showMarkers)
        markerData = [];
        return;
    end
    % Show only specified marker codes
    [allCodes, ~, tempIdx] = unique(markerData(:, 2));
    markerIdx = nan(size(tempIdx));

    % Find which requested codes exist
    validCodes = showMarkers(ismember(showMarkers, allCodes));
    markerCodes = validCodes(:)';

    % Map each marker to its position in markerCodes
    for i = 1:length(markerCodes)
        codeIdx = find(allCodes == markerCodes(i));
        if ~isempty(codeIdx)
            markerIdx(tempIdx == codeIdx) = i;
        end
    end
end

% Count markers per code
if ~isempty(markerCodes)
    numMarkers = zeros(1, length(markerCodes));
    for i = 1:length(markerCodes)
        numMarkers(i) = sum(markerIdx == i);
    end

    % Warn about too many markers (interactive prompt handled by caller)
    if any(numMarkers > tooManyThreshold) && ~isinf(tooManyThreshold)
        highIdx = find(numMarkers > tooManyThreshold, 1);
        warning('pf2:plot:tooManyMarkers', ...
            '%d markers for marker code %d (threshold: %d)', ...
            numMarkers(highIdx), markerCodes(highIdx), tooManyThreshold);
    end
end

end
