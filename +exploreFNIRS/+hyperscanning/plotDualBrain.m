function fig = plotDualBrain(result, dataA, dataB, varargin)
% PLOTDUALBRAIN Two brains side by side with cross-brain synchrony edges
%
% Visualizes inter-brain synchrony for a dyad by drawing both subjects'
% probes at their real anatomical (2D) layout, side by side, with edges
% connecting cross-brain channel pairs colored and sized by their coupling.
% This replaces the synthetic square-grid layout of plotInterBrainTopo with
% the actual optode geometry, so the spatial pattern of inter-brain coupling
% (e.g. homologous frontal channels) is readable. An optional linked
% wavelet-coherence time-frequency panel is drawn beneath the brains.
%
% Supports both dyad pairings from computeDyad: 'same' (matched channel
% pairs, [N x 1] values) and 'all' (the full [Na x Nb] cross-brain matrix).
%
% Syntax:
%   exploreFNIRS.hyperscanning.plotDualBrain(result, dataA, dataB)
%   exploreFNIRS.hyperscanning.plotDualBrain(result, dataA, dataB, ...
%       'Threshold', 0.3, 'TopN', 40)
%   exploreFNIRS.hyperscanning.plotDualBrain(result, dataA, dataB, ...
%       'Wcoherence', wc)              % add linked time-frequency panel
%   fig = exploreFNIRS.hyperscanning.plotDualBrain(..., 'SavePath', 'dyad.png')
%
% Inputs:
%   result - Dyad result from exploreFNIRS.hyperscanning.computeDyad
%            (fields .values, .pvalues, .channelsA, .channelsB, .pairing).
%   dataA  - Processed fNIRS struct for subject A (provides probe layout).
%   dataB  - Processed fNIRS struct for subject B (provides probe layout).
%
% Name-Value Parameters:
%   'Threshold'        - Minimum |coupling| to draw an edge (default: 0).
%   'TopN'             - Keep only the strongest N edges (default: []).
%   'SignificanceMask' - Draw only edges with p < PThreshold (default: false).
%   'PThreshold'       - Significance cutoff (default: 0.05).
%   'CLim'             - [lo hi] edge color limits (default symmetric).
%   'EdgeColormap'     - [M x 3] colormap or name (default blue-white-red).
%   'EdgeWidthRange'   - [min max] line width from |coupling| (default [0.5 5]).
%   'NodeSize'         - Node marker area (default: 40).
%   'BrainLabels'      - {labelA, labelB} (default: {'Subject A','Subject B'}).
%   'Gap'              - Horizontal gap between the two layouts as a fraction
%                        of subject A's width (default: 0.6).
%   'Wcoherence'       - Wavelet-coherence result (struct with .wcoh, .freqs,
%                        .times, .coi) to draw as a linked panel (default: []).
%   'Colorbar'         - Colorbar label (default: auto from method).
%   'Title'            - Figure title (default: auto from method/biomarker).
%   'Visible'          - Figure visibility 'on'|'off' (default: 'on').
%   'SavePath'         - Output image path for headless saving (default: '').
%   'SaveWidth'/'SaveHeight'/'SaveDPI' - Saved image size/resolution.
%
% Outputs:
%   fig - Handle to the created figure.
%
% Algorithm:
%   1. Read each subject's 2D optode layout; offset subject B to the right.
%   2. Build the cross-brain edge list from .values, applying Threshold,
%      SignificanceMask and TopN.
%   3. Draw edges (color/width by coupling) and nodes; optionally add a
%      wavelet-coherence time-frequency panel with its cone of influence.
%
% Example:
%   data = pf2.import.sampleData.fNIR2000();
%   A = processFNIRS2(data); B = processFNIRS2(data);
%   r = exploreFNIRS.hyperscanning.computeDyad(A, B, 'ChannelPairing', 'all');
%   exploreFNIRS.hyperscanning.plotDualBrain(r, A, B, 'TopN', 30, ...
%       'SavePath', 'dyad.png');
%
% Notes:
%   - This is a 2D anatomical dual-brain. Edges are drawn in a single axes so
%     they can span both subjects; a full two-cortex 3D scene is a possible
%     future extension.
%
% See also: exploreFNIRS.hyperscanning.computeDyad,
%           exploreFNIRS.hyperscanning.plotInterBrainTopo,
%           exploreFNIRS.coupling.wcoherence, pf2.probe.plot.connectome

p = inputParser;
addRequired(p, 'result', @isstruct);
addRequired(p, 'dataA', @isstruct);
addRequired(p, 'dataB', @isstruct);
addParameter(p, 'Threshold', 0, @(x) isnumeric(x) && isscalar(x) && x >= 0);
addParameter(p, 'TopN', [], @(x) isempty(x) || (isnumeric(x) && isscalar(x) && x >= 1));
addParameter(p, 'SignificanceMask', false, @islogical);
addParameter(p, 'PThreshold', 0.05, @(x) isnumeric(x) && isscalar(x) && x > 0 && x < 1);
addParameter(p, 'CLim', [], @(x) isempty(x) || (isnumeric(x) && numel(x) == 2));
addParameter(p, 'EdgeColormap', [], @(x) isempty(x) || isnumeric(x) || ischar(x) || isstring(x));
addParameter(p, 'EdgeWidthRange', [0.5 5], @(x) isnumeric(x) && numel(x) == 2);
addParameter(p, 'NodeSize', 40, @(x) isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, 'BrainLabels', {'Subject A', 'Subject B'}, @(x) iscell(x) && numel(x) == 2);
addParameter(p, 'Gap', 0.6, @(x) isnumeric(x) && isscalar(x) && x >= 0);
addParameter(p, 'Wcoherence', [], @(x) isempty(x) || isstruct(x));
addParameter(p, 'Colorbar', '', @(x) ischar(x) || isstring(x));
addParameter(p, 'Title', '', @(x) ischar(x) || isstring(x));
addParameter(p, 'Visible', 'on', @(x) any(strcmpi(char(x), {'on','off'})));
addParameter(p, 'SavePath', '', @(x) ischar(x) || isstring(x));
addParameter(p, 'SaveWidth', 900, @(x) isempty(x) || isnumeric(x));
addParameter(p, 'SaveHeight', 650, @(x) isempty(x) || isnumeric(x));
addParameter(p, 'SaveDPI', 150, @isnumeric);
parse(p, result, dataA, dataB, varargin{:});

% --- Per-subject node layouts, aligned to the dyad's matrix rows/cols ---
useROI = iField(result, 'useROI', false);
chA = iField(result, 'channelsA', []);
chB = iField(result, 'channelsB', []);
if isempty(chA), chA = (1:size(result.values, 1))'; end
if isempty(chB)
    if strcmpi(char(string(iField(result, 'pairing', 'same'))), 'all')
        chB = (1:size(result.values, 2))';
    else
        chB = chA;
    end
end
PA = iNodePositions(dataA, chA, useROI);   % [Na x 2]
PB = iNodePositions(dataB, chB, useROI);   % [Nb x 2]

% Offset subject B to the right of subject A
spanA = max(PA(:,1)) - min(PA(:,1));
if ~isfinite(spanA) || spanA == 0, spanA = 1; end
offset = (max(PA(:,1)) - min(PB(:,1))) + p.Results.Gap * spanA;
PBoff = PB + [offset, 0];

% --- Edge list (ai/bj are LOCAL indices into PA/PB) ---
[ai, bj, w, pv] = iEdgeList(result);
keep = isfinite(w) & abs(w) >= p.Results.Threshold;
if p.Results.SignificanceMask
    if isempty(pv)
        warning('exploreFNIRS:hyperscanning:plotDualBrain:noPValues', ...
            'SignificanceMask is true but result has no p-values; mask ignored.');
    else
        keep = keep & (pv < p.Results.PThreshold);
    end
end
ai = ai(keep); bj = bj(keep); w = w(keep);
if ~isempty(pv), pv = pv(keep); end %#ok<NASGU>
if ~isempty(p.Results.TopN) && numel(w) > p.Results.TopN
    [~, order] = sort(abs(w), 'descend');
    sel = order(1:round(p.Results.TopN));
    ai = ai(sel); bj = bj(sel); w = w(sel);
end

% --- Color scale + colormap ---
clim = p.Results.CLim;
if isempty(clim)
    m = max(abs(w), [], 'omitnan');
    if isempty(m) || ~isfinite(m) || m == 0, m = 1; end
    clim = [-m, m];
end
clim = sort(clim);
ecmap = p.Results.EdgeColormap;
if isempty(ecmap)
    ecmap = iDivergingMap(256);
elseif ischar(ecmap) || isstring(ecmap)
    ecmap = feval(char(ecmap), 256);
end

method = iField(result, 'method', '');
biomarker = iField(result, 'biomarker', '');
titleStr = char(p.Results.Title);
if isempty(titleStr)
    bits = strtrim(strjoin({char(string(method)), char(string(biomarker))}, ' '));
    titleStr = strtrim(sprintf('Inter-brain synchrony %s', bits));
end
cbarStr = char(p.Results.Colorbar);
if isempty(cbarStr)
    if isempty(method), cbarStr = 'coupling';
    else, cbarStr = char(string(method)); end
end

% --- Figure / layout ---
fig = figure('Visible', char(p.Results.Visible), 'Color', 'w');
hasWcoh = ~isempty(p.Results.Wcoherence);
if hasWcoh
    tl = tiledlayout(fig, 3, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
    axBrain = nexttile(tl, 1, [2 1]);
    axTF = nexttile(tl, 3);
else
    axBrain = axes(fig); %#ok<LAXES>
    axTF = [];
end

% --- Draw the dual-brain panel ---
hold(axBrain, 'on');
axis(axBrain, 'equal');
axis(axBrain, 'off');
title(axBrain, titleStr);

% Faint full-probe context
scatter(axBrain, PA(:,1), PA(:,2), p.Results.NodeSize*0.6, [0.75 0.75 0.75], ...
    'filled', 'MarkerFaceAlpha', 0.4);
scatter(axBrain, PBoff(:,1), PBoff(:,2), p.Results.NodeSize*0.6, [0.75 0.75 0.75], ...
    'filled', 'MarkerFaceAlpha', 0.4);

% Edges (weak first so strong edges sit on top)
[~, eorder] = sort(abs(w), 'ascend');
wr = p.Results.EdgeWidthRange;
span = clim(2) - clim(1); if span == 0, span = 1; end
nc = size(ecmap, 1);
maxAbs = max(abs(w), [], 'omitnan'); if isempty(maxAbs) || maxAbs == 0, maxAbs = 1; end
for e = eorder(:)'
    cn = (w(e) - clim(1)) / span;
    ci = max(1, min(nc, round(cn * (nc - 1)) + 1));
    lw = wr(1) + (wr(2) - wr(1)) * (abs(w(e)) / maxAbs);
    plot(axBrain, [PA(ai(e),1), PBoff(bj(e),1)], [PA(ai(e),2), PBoff(bj(e),2)], ...
        '-', 'Color', ecmap(ci, :), 'LineWidth', lw);
end

% Connected nodes emphasized
usedA = unique(ai); usedB = unique(bj);
scatter(axBrain, PA(usedA,1), PA(usedA,2), p.Results.NodeSize, [0.2 0.3 0.8], ...
    'filled', 'MarkerEdgeColor', 'k');
scatter(axBrain, PBoff(usedB,1), PBoff(usedB,2), p.Results.NodeSize, [0.8 0.3 0.2], ...
    'filled', 'MarkerEdgeColor', 'k');

% Subject labels above each layout
text(axBrain, mean(PA(:,1)), max([PA(:,2); PBoff(:,2)]) + 0.12*spanA, ...
    p.Results.BrainLabels{1}, 'HorizontalAlignment', 'center', ...
    'FontWeight', 'bold');
text(axBrain, mean(PBoff(:,1)), max([PA(:,2); PBoff(:,2)]) + 0.12*spanA, ...
    p.Results.BrainLabels{2}, 'HorizontalAlignment', 'center', ...
    'FontWeight', 'bold');

colormap(axBrain, ecmap);
set(axBrain, 'CLim', clim);
cb = colorbar(axBrain);
cb.Label.String = cbarStr;

% --- Optional wavelet-coherence panel ---
if hasWcoh
    iDrawWcoherence(axTF, p.Results.Wcoherence);
end

% --- Save ---
if ~isempty(char(p.Results.SavePath))
    pf2_base.plot.saveFigure(fig, char(p.Results.SavePath), ...
        p.Results.SaveWidth, p.Results.SaveHeight, p.Results.SaveDPI);
end

if nargout == 0
    clear fig;
end

end

%%_Subfunctions_________________________________________________________

function P = iNodePositions(data, channels, useROI)
% Resolve a subject's 2D node positions aligned to the dyad's matrix order.
% Channel mode: the optode 2D layout indexed by channel number. ROI mode:
% the centroid of each ROI's member optodes (from data.ROI.info).
probeInfo = pf2_base.plot.loadProbeInfo(data, true);
allP = [probeInfo.OptPos.x_2d(:), probeInfo.OptPos.y_2d(:)];
channels = channels(:);
if useROI
    if ~isfield(data, 'ROI') || ~isfield(data.ROI, 'info')
        error('exploreFNIRS:hyperscanning:plotDualBrain:noROI', ...
            'ROI dyad requires data.ROI.info to place ROI nodes.');
    end
    opt = data.ROI.info.Optodes;
    P = nan(numel(channels), 2);
    for r = 1:numel(channels)
        idx = channels(r);
        if idx >= 1 && idx <= numel(opt)
            members = opt{idx};
            members = members(members >= 1 & members <= size(allP, 1));
            if ~isempty(members)
                P(r, :) = mean(allP(members, :), 1, 'omitnan');
            end
        end
    end
else
    valid = channels >= 1 & channels <= size(allP, 1);
    if ~all(valid)
        error('exploreFNIRS:hyperscanning:plotDualBrain:badChannels', ...
            'Dyad channel indices exceed the probe optode count (%d).', ...
            size(allP, 1));
    end
    P = allP(channels, :);
end
end

function [ai, bj, w, pv] = iEdgeList(result)
% Build cross-brain edges as LOCAL indices (1..Na, 1..Nb) into each subject's
% node table, plus weights and p-values. Branches on the recorded pairing
% (not matrix shape) so singleton 'all' results stay 2D.
vals = result.values;
pvals = iField(result, 'pvalues', []);
pairing = lower(char(string(iField(result, 'pairing', 'same'))));

if strcmp(pairing, 'all')
    Na = numel(iField(result, 'channelsA', (1:size(vals, 1))'));
    Nb = numel(iField(result, 'channelsB', (1:size(vals, 2))'));
    vals = reshape(vals, Na, Nb);
    [I, J] = ndgrid(1:Na, 1:Nb);
    ai = I(:); bj = J(:); w = vals(:);
    if ~isempty(pvals), pv = reshape(pvals, Na, Nb); pv = pv(:); else, pv = []; end
else
    % 'same' pairing: matched channel pairs, edge k connects A(k)-B(k)
    w = vals(:);
    n = numel(w);
    ai = (1:n)'; bj = (1:n)';
    if ~isempty(pvals), pv = pvals(:); else, pv = []; end
end
ai = ai(:); bj = bj(:); w = w(:);
if ~isempty(pv), pv = pv(:); end
end

function iDrawWcoherence(ax, wc)
% Draw a wavelet-coherence time-frequency heatmap with cone of influence.
if ~isfield(wc, 'wcoh')
    title(ax, 'Wcoherence struct missing .wcoh');
    return;
end
t = iField(wc, 'times', 1:size(wc.wcoh, 2));
f = iField(wc, 'freqs', 1:size(wc.wcoh, 1));
imagesc(ax, t, f, wc.wcoh);
set(ax, 'YDir', 'normal');
try, set(ax, 'YScale', 'log'); catch, end
colormap(ax, parula(256));
set(ax, 'CLim', [0 1]);
cb = colorbar(ax);
cb.Label.String = 'coherence';
xlabel(ax, 'Time (s)');
ylabel(ax, 'Frequency (Hz)');
title(ax, 'Wavelet coherence');
if isfield(wc, 'coi') && ~isempty(wc.coi)
    hold(ax, 'on');
    plot(ax, t, wc.coi(:)', 'w--', 'LineWidth', 1);
    hold(ax, 'off');
end
end

function cmap = iDivergingMap(n)
% Blue-white-red diverging colormap with n rows.
half = floor(n / 2);
top = ones(half, 1);
ramp = linspace(0, 1, half)';
lower = [ramp, ramp, top];
upper = [top, flipud(ramp), flipud(ramp)];
cmap = [lower; 1 1 1; upper];
if size(cmap, 1) ~= n
    xi = linspace(1, size(cmap, 1), n);
    cmap = interp1(1:size(cmap, 1), cmap, xi);
end
cmap = max(0, min(1, cmap));
end

function v = iField(s, name, default)
if isfield(s, name) && ~isempty(s.(name))
    v = s.(name);
else
    v = default;
end
end
