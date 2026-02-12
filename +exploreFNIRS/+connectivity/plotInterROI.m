function fig = plotInterROI(result, varargin)
% PLOTINTERROI Visualize between-ROI connectivity as chord diagram or matrix
%
% Convenience wrapper that dispatches to plotChord or plotMatrix depending
% on the chosen PlotType. Exists for discoverability alongside computeInterROI.
%
% Syntax:
%   fig = exploreFNIRS.connectivity.plotInterROI(result)
%   fig = exploreFNIRS.connectivity.plotInterROI(result, 'PlotType', 'matrix')
%   fig = exploreFNIRS.connectivity.plotInterROI(result, 'MinThreshold', 0.3)
%
% Inputs:
%   result - Connectivity result struct from computeInterROI (or computeMatrix
%            with UseROI=true), with fields: .matrix, .pmatrix, .labels,
%            .method, .biomarker, .useROI
%
% Name-Value Parameters:
%   PlotType     - 'chord' (default) or 'matrix'
%   MinThreshold - Minimum coupling value to display connections (default: 0)
%                  Connections below this threshold are hidden.
%   Title        - Figure title (default: auto)
%   Visible      - 'on' (default) or 'off'
%   SavePath     - File path to save figure
%   SaveWidth    - Width in pixels (default: 600)
%   SaveHeight   - Height in pixels (default: 550)
%   SaveDPI      - Resolution (default: 150)
%
% Outputs:
%   fig - Figure handle
%
% Example:
%   result = exploreFNIRS.connectivity.computeInterROI(processed);
%   fig = exploreFNIRS.connectivity.plotInterROI(result, ...
%       'PlotType', 'chord', 'MinThreshold', 0.3);
%
% See also: exploreFNIRS.connectivity.computeInterROI,
%   exploreFNIRS.connectivity.plotMatrix,
%   exploreFNIRS.connectivity.computeIntraROI

    p = inputParser;
    addRequired(p, 'result', @isstruct);
    addParameter(p, 'PlotType', 'chord', @(v) ischar(v) && ismember(lower(v), {'chord', 'matrix'}));
    addParameter(p, 'MinThreshold', 0, @isnumeric);
    addParameter(p, 'Title', '', @ischar);
    addParameter(p, 'Visible', 'on', @ischar);
    addParameter(p, 'SavePath', '', @ischar);
    addParameter(p, 'SaveWidth', 600, @isnumeric);
    addParameter(p, 'SaveHeight', 550, @isnumeric);
    addParameter(p, 'SaveDPI', 150, @isnumeric);
    parse(p, result, varargin{:});
    opts = p.Results;
    result = exploreFNIRS.connectivity.normalizeResult(result);

    % Apply threshold: zero out connections below MinThreshold
    if opts.MinThreshold > 0
        threshResult = result;
        mat = threshResult.matrix;
        mat(abs(mat) < opts.MinThreshold & ~eye(size(mat, 1))) = 0;
        threshResult.matrix = mat;
    else
        threshResult = result;
    end

    % Build common pass-through arguments
    passArgs = {};
    if ~isempty(opts.Title)
        passArgs = [passArgs, {'Title', opts.Title}];
    end
    passArgs = [passArgs, {'Visible', opts.Visible}];
    if ~isempty(opts.SavePath)
        passArgs = [passArgs, {'SavePath', opts.SavePath}];
    end
    passArgs = [passArgs, {'SaveWidth', opts.SaveWidth, ...
                           'SaveHeight', opts.SaveHeight, ...
                           'SaveDPI', opts.SaveDPI}];

    switch lower(opts.PlotType)
        case 'chord'
            % Try plotChord; fall back to plotMatrix if not available
            if ~isempty(which('exploreFNIRS.connectivity.plotChord'))
                fig = exploreFNIRS.connectivity.plotChord(threshResult, passArgs{:});
            else
                % Chord plot not yet available, fall back to matrix
                warning('exploreFNIRS:connectivity:plotInterROI', ...
                    'plotChord not available; falling back to matrix plot.');
                fig = exploreFNIRS.connectivity.plotMatrix(threshResult, passArgs{:});
            end

        case 'matrix'
            fig = exploreFNIRS.connectivity.plotMatrix(threshResult, passArgs{:});
    end
end
