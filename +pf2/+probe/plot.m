function varargout = plot(data, biomarker, timeIdx, varargin)
% PLOT Auto-select and display probe visualization
%
% Automatically selects the best visualization based on available data:
%   - If 3D coordinates available: 3D brain view (showProbe3D)
%   - If 2D coordinates available: 2D interpolated topography
%   - Fallback: arranged channel values
%
% Syntax:
%   pf2.probe.plot(data)
%   pf2.probe.plot(data, biomarker)
%   pf2.probe.plot(data, biomarker, timeIdx)
%   pf2.probe.plot()                      % Interactive selection
%
% Inputs:
%   data      - fNIRS data structure (processed or raw)
%   biomarker - (optional) Biomarker to plot: 'HbO', 'HbR', 'HbTotal', 'HbDiff'
%               Default: 'HbO' if available, else first available field
%   timeIdx   - (optional) Time index or range to plot
%               Scalar: single time point
%               [start, end]: average over range
%               Default: middle of recording
%
% Example:
%   % Auto-select best visualization
%   data = pf2.import.sampleData.fNIR2000();
%   processed = processFNIRS2(data);
%   pf2.probe.plot(processed);
%
%   % Plot specific biomarker at time point
%   pf2.probe.plot(processed, 'HbO', 500);
%
%   % Explicit visualization (bypasses auto-select)
%   pf2.probe.plot.showProbe3D(processed);
%   pf2.probe.plot.interpolateValues(processed, 'HbO', 500);
%
% See also: pf2.probe.plot.showProbe3D, pf2.probe.plot.interpolateValues,
%           pf2.probe.plot.imageValues, pf2.probe.plot.arrangedValues

% Handle no arguments - show help
if nargin < 1 || isempty(data)
    fprintf('Usage: pf2.probe.plot(data, [biomarker], [timeIdx])\n');
    fprintf('\nVisualization options:\n');
    fprintf('  pf2.probe.plot.showProbe3D(data)                  - 3D brain view\n');
    fprintf('  pf2.probe.plot.interpolateValues(data, bio, t)    - 2D interpolated\n');
    fprintf('  pf2.probe.plot.imageValues(data, bio, t)          - 2D heatmap\n');
    fprintf('  pf2.probe.plot.arrangedValues(data, bio, t)       - Channel arrangement\n');
    return;
end

% Default biomarker
if nargin < 2 || isempty(biomarker)
    % Auto-detect biomarker
    if isfield(data, 'HbO')
        biomarker = 'HbO';
    elseif isfield(data, 'HbR')
        biomarker = 'HbR';
    elseif isfield(data, 'raw')
        biomarker = 'raw';
    else
        error('pf2:probe:plot:NoBiomarker', 'No plottable biomarker found in data');
    end
end

% Default time index (middle of recording)
if nargin < 3 || isempty(timeIdx)
    if isfield(data, biomarker)
        timeIdx = round(size(data.(biomarker), 1) / 2);
    else
        timeIdx = 1;
    end
end

% Determine best visualization based on probe info
has3D = false;
has2D = false;

% Check for 3D coordinates
if isfield(data, 'probeinfo')
    pi = data.probeinfo;
    if isfield(pi, 'Probe1')
        p1 = pi.Probe1;
        if isfield(p1, 'DetPos3DX') && ~isempty(p1.DetPos3DX)
            has3D = true;
        end
        if isfield(p1, 'DetPosX') && ~isempty(p1.DetPosX)
            has2D = true;
        end
    end
end

% Also check global device info
global setF
if ~has3D && ~isempty(setF) && pf2_base.isnestedfield(setF, 'device.Probe1')
    p1 = setF.device.Probe1;
    if isfield(p1, 'DetPos3DX') && ~isempty(p1.DetPos3DX)
        has3D = true;
    end
    if isfield(p1, 'DetPosX') && ~isempty(p1.DetPosX)
        has2D = true;
    end
end

% Select visualization
if has3D
    % 3D brain view available
    if nargout > 0
        varargout{1} = pf2.probe.plot.showProbe3D(data, varargin{:});
    else
        pf2.probe.plot.showProbe3D(data, varargin{:});
    end
    fprintf('Using: 3D brain visualization (showProbe3D)\n');

elseif has2D
    % 2D interpolation available
    if nargout > 0
        varargout{1} = pf2.probe.plot.interpolateValues(data, biomarker, timeIdx, varargin{:});
    else
        pf2.probe.plot.interpolateValues(data, biomarker, timeIdx, varargin{:});
    end
    fprintf('Using: 2D interpolated topography (interpolateValues)\n');

else
    % Fallback to arranged values
    if nargout > 0
        varargout{1} = pf2.probe.plot.arrangedValues(data, biomarker, timeIdx, varargin{:});
    else
        pf2.probe.plot.arrangedValues(data, biomarker, timeIdx, varargin{:});
    end
    fprintf('Using: Arranged channel values (arrangedValues)\n');
end

end