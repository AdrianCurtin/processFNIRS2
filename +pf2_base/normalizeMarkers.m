function mrk = normalizeMarkers(mrk)
% NORMALIZEMARKERS Pad marker array to 4 columns [time, value, duration, amplitude]
%
% Ensures marker arrays always have 4 columns. Missing columns are filled
% with defaults: duration = 0, amplitude = 1. This standardizes the marker
% format across all import functions and data generators.
%
% Syntax:
%   mrk = pf2_base.normalizeMarkers(mrk)
%
% Inputs:
%   mrk - Marker array in any of these formats:
%         [M x 2] - [time, value] (duration and amplitude added)
%         [M x 3] - [time, value, duration] (amplitude added)
%         [M x 4] - [time, value, duration, amplitude] (returned as-is)
%         []       - Empty input (returns zeros(0,4))
%
% Outputs:
%   mrk - Normalized marker array [M x 4]
%         Column 1: time (seconds)
%         Column 2: marker value/code
%         Column 3: duration (seconds), default 0
%         Column 4: amplitude/weight, default 1

if isempty(mrk)
    mrk = zeros(0, 4);
    return;
end

nCols = size(mrk, 2);
nRows = size(mrk, 1);

if nCols < 3
    % Add duration column (default 0)
    mrk(:, 3) = zeros(nRows, 1);
end

if nCols < 4
    % Add amplitude column (default 1)
    mrk(:, 4) = ones(nRows, 1);
end

end
