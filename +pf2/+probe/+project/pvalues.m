function [h, imgOut] = pvalues(pvals, fNIR, varargin)
% PVALUES Project per-channel p-values onto the 3D cortical surface
%
% Renders a 3D brain with channel p-values shown as -log10(p) (or linear p),
% transparent below a significance threshold, with optional BH-FDR correction.
%
% Syntax:
%   pf2.probe.project.pvalues(pvals, fNIR)
%   pf2.probe.project.pvalues(pvals, fNIR, 'pThreshold', 0.05)
%   pf2.probe.project.pvalues(pvals, fNIR, 'FDR', true)
%   [h, imgOut] = pf2.probe.project.pvalues(pvals, fNIR, ...)
%
% Inputs:
%   pvals - [1 x K] uncorrected p-values per channel (may contain NaN).
%   fNIR  - fNIRS struct (or probe name / config). Same as interpolateValues3D.
%
% Name-Value Parameters (wrapper-specific):
%   'pThreshold'  - Significance cutoff (default: 0.05). Channels with
%                   p >= pThreshold render as transparent (brain shows
%                   through).
%   'PFloor'      - Minimum p used when taking -log10 (default: 1e-4). Caps
%                   the top of the colorbar. Raw p-values below this floor
%                   are clamped (avoids Inf when p == 0).
%   'FDR'         - Apply Benjamini-Hochberg correction before thresholding
%                   (default: false). Uses exploreFNIRS.fx.performFDR.
%   'LogScale'    - Plot -log10(p) on the colorbar (default: true). Pass
%                   false to plot raw p with an inverted colormap.
%   'PTicks'      - Vector of raw p-values at which to place colorbar ticks
%                   (default: [0.05, 0.01, 0.001]). The colorbar labels
%                   show these as p = 0.05 / 0.01 / 0.001 regardless of
%                   whether LogScale is on. Pass [] to use MATLAB defaults.
%
% All other name-value pairs are forwarded to interpolateValues3D, so
% camera, ForceLightMode, UseGeodesic, bufferDistance, etc. all work.
%
% Outputs:
%   h      - Axes handle.
%   imgOut - RGB capture of the rendered figure.
%
% Example:
%   % Raw p-values from an LME contrast
%   pvals = rand(1, size(processed.HbO, 2)); pvals([3 7 9]) = 0.001;
%   pf2.probe.project.pvalues(pvals, processed, ...
%       'pThreshold', 0.05, 'FDR', false, 'initCamPosition', 'front');
%
% See also: pf2.probe.plot.interpolateValues3D,
%           pf2.probe.project.fstats, pf2.probe.project.correlation,
%           exploreFNIRS.fx.performFDR

p = inputParser;
p.KeepUnmatched = true;
addRequired(p, 'pvals', @(x) isnumeric(x) && isvector(x));
addRequired(p, 'fNIR');
addParameter(p, 'pThreshold', 0.05, @(x) isnumeric(x) && isscalar(x) && x > 0 && x < 1);
addParameter(p, 'PFloor', 1e-4, @(x) isnumeric(x) && isscalar(x) && x > 0 && x < 1);
addParameter(p, 'FDR', false, @islogical);
addParameter(p, 'LogScale', true, @islogical);
addParameter(p, 'PTicks', [0.05 0.01 0.001], @(x) isnumeric(x) && all(x(:) > 0) && all(x(:) < 1));
addParameter(p, 'titleString', '', @(x) ischar(x) || isstring(x));
addParameter(p, 'colorbarStr', '', @(x) ischar(x) || isstring(x));
parse(p, pvals, fNIR, varargin{:});

pThresh  = p.Results.pThreshold;
pFloor   = p.Results.PFloor;
useFDR   = p.Results.FDR;
logScale = p.Results.LogScale;
titleStr = char(p.Results.titleString);
cbarStr  = char(p.Results.colorbarStr);

pvals = pvals(:)';  % row
validMask = ~isnan(pvals);

% FDR correction on valid entries
qvals = pvals;
if useFDR && any(validMask)
    qvals(validMask) = exploreFNIRS.fx.performFDR(pvals(validMask));
end

% Build channel alpha from significance
sig = false(size(qvals));
sig(validMask) = qvals(validMask) < pThresh;
chanAlpha = double(sig);

% Colorbar range and data to plot
if logScale
    qClamped = max(qvals, pFloor);
    data2plot = -log10(qClamped);
    minVal = -log10(pThresh);   % significance boundary
    maxVal = -log10(pFloor);
    if isempty(cbarStr)
        if useFDR
            cbarStr = '-log_{10}(q)';
        else
            cbarStr = '-log_{10}(p)';
        end
    end
else
    data2plot = qvals;
    minVal = 0;
    maxVal = pThresh;
    if isempty(cbarStr)
        cbarStr = iif(useFDR, 'q', 'p');
    end
end

if isempty(titleStr)
    titleStr = iif(useFDR, 'FDR-corrected p (q)', 'p-values');
end

% NaN channels propagate through interpolateValues3D's nanChannel handling
data2plot(~validMask) = NaN;

forward = unmatchedToVarargin(p.Unmatched);

[h, imgOut] = pf2.probe.plot.interpolateValues3D( ...
    data2plot, fNIR, minVal, maxVal, titleStr, cbarStr, ...
    'ChannelAlpha', chanAlpha, ...
    'AlphaMode', 'transparent', ...
    forward{:});

% Retick the colorbar to show raw p-values (0.05 / 0.01 / 0.001) at their
% -log10 positions, which is how researchers actually think about them.
pticks = p.Results.PTicks;
if ~isempty(pticks)
    pticks = sort(pticks(:)', 'descend');  % 0.05, 0.01, 0.001, ...
    if logScale
        tickPositions = -log10(pticks);
        tickLabels = arrayfun(@(x) iLocalFormatP(x), pticks, 'UniformOutput', false);
    else
        tickPositions = pticks;
        tickLabels = arrayfun(@(x) iLocalFormatP(x), pticks, 'UniformOutput', false);
    end
    % Keep only ticks within the colorbar range
    inRange = tickPositions >= minVal & tickPositions <= maxVal;
    tickPositions = tickPositions(inRange);
    tickLabels = tickLabels(inRange);
    % MATLAB's ColorBar requires strictly ascending Ticks
    [tickPositions, ord] = sort(tickPositions, 'ascend');
    tickLabels = tickLabels(ord);
    if ~isempty(tickPositions)
        cb = findall(ancestor(h, 'figure'), 'Type', 'ColorBar', 'Tag', 'Main');
        if isempty(cb)
            cb = findall(ancestor(h, 'figure'), 'Type', 'ColorBar');
        end
        if ~isempty(cb)
            set(cb(1), 'Ticks', tickPositions, 'TickLabels', tickLabels);
        end
    end
end

end


function s = iLocalFormatP(p)
if p >= 0.01
    s = sprintf('%.2f', p);
elseif p >= 0.001
    s = sprintf('%.3f', p);
else
    s = sprintf('%.0e', p);
end
end


function v = iif(cond, a, b)
if cond, v = a; else, v = b; end
end


function c = unmatchedToVarargin(s)
fn = fieldnames(s);
c = cell(1, 2 * numel(fn));
for i = 1:numel(fn)
    c{2*i - 1} = fn{i};
    c{2*i}     = s.(fn{i});
end
end
