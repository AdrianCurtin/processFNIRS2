function [h, imgOut] = topo(data, biomarker, varargin)
% TOPO Topographic map of a biomarker at a time point (convenience wrapper)
%
% The shortest path from processed data to a topographic activation map.
% Pulls a per-channel value for the requested biomarker (at a time point,
% over a window, or time-averaged), then renders it as a 2D probe heatmap
% (default) or a 3D cortical projection. Wraps pf2.probe.plot.imageValues
% and pf2.probe.project.biomarker so you do not have to extract the data
% vector or match optode counts yourself.
%
% Syntax:
%   pf2.probe.plot.topo(processed, 'HbO')              % time-averaged, 2D
%   pf2.probe.plot.topo(processed, 'HbO', 'Time', 30)  % at t = 30 s
%   pf2.probe.plot.topo(processed, 'HbO', 'Time', [20 40])  % 20-40 s mean
%   pf2.probe.plot.topo(processed, 'HbO', 'View', '3d')     % cortical surface
%   pf2.probe.plot.topo(processed, 'HbO', 'savePath', 'topo.png')
%   [h, imgOut] = pf2.probe.plot.topo(...)
%
% Inputs:
%   data      - Processed fNIRS struct (must contain the biomarker field).
%   biomarker - Biomarker field name: 'HbO','HbR','HbTotal','HbDiff','CBSI'.
%
% Name-Value Parameters:
%   'Time'  - Time selection (default: [] = average over the whole record).
%             Scalar t   -> value at the sample nearest t seconds.
%             [t1 t2]    -> mean over the window t1..t2 seconds.
%             []         -> mean over all time.
%   'View'  - '2d' (default) renders a flat probe heatmap via imageValues.
%             '3d' renders a cortical-surface projection via
%             pf2.probe.project.biomarker (requires MNI coordinates).
%             'movie' animates the biomarker over time via
%             pf2.probe.plot.movie (pass 'savePath','*.mp4'/'*.gif', 'FPS',
%             'NFrames', etc.; a two-element 'Time' sets the TimeRange).
%   'Layout'- (2D only) 'schematic'/'flat' for a clean declared grid montage,
%             'anatomical' for the affine projection, 'auto' (default) to pick
%             schematic when the device declares one. Forwarded to imageValues.
%   'Title'    - Title string (default: auto from biomarker + time).
%   'Colorbar' - Colorbar label (default: data.units if present, else '').
%
% Any other name-value pairs (e.g. 'savePath', 'initCamPosition',
% 'ForceLightMode', 'includeSS') are forwarded to the underlying renderer.
% For headless 3D saving, use 'savePath' (see pf2.probe.plot.interpolateValues3D).
%
% Outputs:
%   h      - Handle to the image (2D) or axes (3D). For View='movie', the
%            path to the written movie file (char).
%   imgOut - For '3d', RGB capture of the render. Empty for '2d' and 'movie'.
%
% Example:
%   data = pf2.import.sampleData.fNIR2000();
%   processed = processFNIRS2(data);
%   pf2.probe.plot.topo(processed, 'HbO', 'Time', 30, 'savePath', 'hbo30.png');
%
% See also: pf2.probe.plot.imageValues, pf2.probe.project.biomarker,
%           pf2.probe.plot.interpolateValues3D, pf2.data.plot.oxy

p = inputParser;
p.FunctionName = 'pf2.probe.plot.topo';
p.KeepUnmatched = true;
addRequired(p, 'data', @isstruct);
addRequired(p, 'biomarker', @(x) ischar(x) || isstring(x));
addParameter(p, 'Time', [], @(x) isnumeric(x) && (isempty(x) || numel(x) <= 2));
addParameter(p, 'View', '2d', @(x) any(strcmpi(char(x), {'2d','3d','movie'})));
addParameter(p, 'Title', '', @(x) ischar(x) || isstring(x));
addParameter(p, 'Colorbar', '', @(x) ischar(x) || isstring(x));
parse(p, data, biomarker, varargin{:});

bio = char(p.Results.biomarker);
tSel = p.Results.Time;
viewMode = lower(char(p.Results.View));
view3d = strcmp(viewMode, '3d');

% 'movie' shortcut: delegate to pf2.probe.plot.movie (time animation). A
% two-element Time maps to the movie's TimeRange; all other options are
% forwarded. Returns the movie file path in h (imgOut is empty).
if strcmp(viewMode, 'movie')
    movieArgs = iLocalUnmatched(p.Unmatched);
    if numel(tSel) == 2
        movieArgs = [{'TimeRange', tSel}, movieArgs];
    elseif isscalar(tSel)
        warning('pf2:probe:plot:topo:scalarTimeForMovie', ...
            ['Scalar ''Time'' is ignored for View=''movie''; pass a two-element ', ...
             '[t1 t2] to set the TimeRange.']);
    end
    h = pf2.probe.plot.movie(data, bio, movieArgs{:});
    imgOut = [];
    if nargout == 0
        clear h imgOut;
    end
    return;
end
titleStr = char(p.Results.Title);
cbarStr = char(p.Results.Colorbar);

% Validate biomarker field
if ~isfield(data, bio)
    valid = {'HbO','HbR','HbTotal','HbDiff','CBSI'};
    present = valid(isfield(data, valid));
    error('pf2:probe:plot:topo:badBiomarker', ...
        'Biomarker ''%s'' not found in data. Available: %s', ...
        bio, strjoin(present, ', '));
end

M = data.(bio);                 % [T x C]
if ~isfield(data, 'time') || isempty(data.time)
    tvec = (1:size(M,1))';
else
    tvec = data.time(:);
end

% Reduce time dimension to a per-channel vector
if isempty(tSel)
    vals = mean(M, 1, 'omitnan');
    timeLabel = 'mean';
elseif isscalar(tSel)
    [~, idx] = min(abs(tvec - tSel));
    vals = M(idx, :);
    timeLabel = sprintf('t=%.1fs', tvec(idx));
else
    tmask = tvec >= min(tSel) & tvec <= max(tSel);
    if ~any(tmask)
        error('pf2:probe:plot:topo:emptyWindow', ...
            'No samples in time window [%.1f %.1f] s.', min(tSel), max(tSel));
    end
    vals = mean(M(tmask, :), 1, 'omitnan');
    timeLabel = sprintf('%.0f-%.0fs', min(tSel), max(tSel));
end

% Auto title / colorbar
if isempty(titleStr)
    titleStr = sprintf('%s (%s)', bio, timeLabel);
end
if isempty(cbarStr) && isfield(data, 'units') && ~isempty(data.units)
    cbarStr = char(string(data.units));
end

forward = iLocalUnmatched(p.Unmatched);

if view3d
    [h, imgOut] = pf2.probe.project.biomarker(vals, data, ...
        'titleString', titleStr, 'colorbarStr', cbarStr, forward{:});
else
    h = pf2.probe.plot.imageValues(vals, data, [], [], titleStr, cbarStr, forward{:});
    imgOut = [];
end

if nargout == 0
    clear h imgOut;
end

end


function c = iLocalUnmatched(s)
% Convert an inputParser Unmatched struct back to a name-value cell array.
fn = fieldnames(s);
c = cell(1, 2 * numel(fn));
for i = 1:numel(fn)
    c{2*i - 1} = fn{i};
    c{2*i}     = s.(fn{i});
end
end
