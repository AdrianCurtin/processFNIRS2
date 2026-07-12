function [h, imgOut] = pmdf(vals, data, varargin)
% PMDF Project channel values on cortex via the physical sensitivity "banana"
%
% A physically grounded counterpart to `pf2.probe.project.biomarker`: instead
% of spreading channel values across the surface with a Gaussian lateral
% kernel, it weights each cortical vertex by the photon-measurement-density
% (PMDF) of the channels — the real, depth-dependent sensitivity footprint of
% each source-detector pair. The result is masked to the montage's sensitivity
% support, so color appears only where the probe can actually see.
%
% Syntax:
%   pf2.probe.project.pmdf(vals, data)
%   pf2.probe.project.pmdf(vals, data, 'Range', [-1 1])
%   [h, imgOut] = pf2.probe.project.pmdf(vals, data, 'savePath', 'banana.png')
%
% Inputs:
%   vals - [1 x nCh] per-channel values (e.g. mean HbO at a time point).
%   data - processed fNIRS struct (with device geometry) the channels belong to.
%
% Inputs (name-value):
%   'Range'         - [lo hi] colorbar limits (default symmetric auto).
%   'MaskThreshold' - Coverage cutoff in [0,1) outside which cortex stays gray
%                     (default 0.05).
%   'CoverageAlpha' - Fade opacity by sensitivity (default true).
%   'cmap'          - Colormap (default 'rdbu', diverging).
%   (Other pairs forward to interpolateValues3D / forward.sensitivity, e.g.
%    'savePath', 'Style', 'MaxDistance', 'ScalpOffset'.)
%
% Outputs:
%   [h, imgOut] - axes handle and captured RGB image (headless imwrite).
%
% Algorithm:
%   Build the forward sensitivity A [nCh x nV] (pf2.probe.forward.sensitivity),
%   then form the sensitivity-weighted backprojection
%     vertexVal(v) = sum_c A(c,v) * vals(c) / sum_c A(c,v),
%   i.e. each vertex takes the value of the channels whose banana illuminates
%   it, weighted by how strongly. Vertices below the coverage threshold are set
%   to NaN (transparent).
%
% Notes:
%   - This is a display projection (a smoothing through the real footprint),
%     not an inverse. For an image reconstruction that deconvolves the forward
%     model, use `pf2.probe.dot.reconstruct` + `pf2.probe.project.tomography`.
%   - Headless: use 'savePath'.
%
% Example:
%   meanHbO = mean(proc.HbO(100:200, :), 1);
%   pf2.probe.project.pmdf(meanHbO, proc, 'savePath', 'banana.png');
%
% See also: pf2.probe.project.biomarker, pf2.probe.dot.reconstruct,
%           pf2.probe.forward.sensitivity

p = inputParser;
p.KeepUnmatched = true;
addRequired(p, 'vals', @(x) isnumeric(x) && isvector(x));
addRequired(p, 'data', @isstruct);
addParameter(p, 'Range', [], @(x) isempty(x) || (isnumeric(x) && numel(x) == 2));
addParameter(p, 'MaskThreshold', 0.05, @(x) isnumeric(x) && isscalar(x) && x >= 0 && x < 1);
addParameter(p, 'CoverageAlpha', true, @(x) islogical(x) && isscalar(x));
addParameter(p, 'cmap', 'rdbu', @(x) ischar(x) || isstring(x) || isnumeric(x));
parse(p, vals, data, varargin{:});
vals = vals(:);

% Split extras: forward-model params go to forward.sensitivity, the rest to
% the renderer (which rejects unknown forward-only names, and vice versa).
forwardNames = {'Wavelength','HighRes','ScalpOffset','MaxDistance','Prune','mua','musp'};
fwd = pickPairs(p.Unmatched, forwardNames, true);
renderArgs = pickPairs(p.Unmatched, forwardNames, false);
[A, ~] = pf2.probe.forward.sensitivity(data, fwd{:});
if iscell(A), A = A{1}; end
if numel(vals) ~= size(A, 1)
    error('pf2:probe:project:pmdf:sizeMismatch', ...
        'vals has %d entries but the montage has %d channels.', numel(vals), size(A,1));
end

% Sensitivity-weighted backprojection + coverage mask. Numerator and
% denominator use the SAME valid (non-NaN) channel subset, so a bad/NaN channel
% does not inflate the normalization and bias the per-vertex average low.
valid = ~isnan(vals);
w = full(sum(A(valid, :), 1))';                % [nV x 1] sensitivity of valid ch
num = full(A(valid, :)' * vals(valid));        % [nV x 1]
vertexVal = num ./ max(w, eps);

rp = max(A, [], 2); rp(rp < eps) = eps;
coverage = full(sum(A ./ rp, 1))';
if max(coverage) > 0, coverage = coverage / max(coverage); end
vertexVal(coverage <= p.Results.MaskThreshold) = NaN;

% Symmetric range.
rangeVals = p.Results.Range;
if isempty(rangeVals)
    m = max(abs(vertexVal), [], 'omitnan');
    if ~isfinite(m) || m == 0, m = 1; end
    rangeVals = [-m, m];
end
rangeVals = sort(rangeVals);

vertexAlpha = [];
if p.Results.CoverageAlpha
    vertexAlpha = min(max(coverage, 0), 1);
end

nCh = size(data.device.mniPositions(), 1);
dummy = zeros(1, nCh);
fNIRstruct = struct('probeinfo', data.device.probeInfo);
[h, imgOut] = pf2.probe.plot.interpolateValues3D( ...
    dummy, fNIRstruct, rangeVals(1), rangeVals(2), 'PMDF projection', '', ...
    'VertexData', vertexVal, 'VertexAlpha', vertexAlpha, ...
    'cmap', p.Results.cmap, 'useHighRes', true, renderArgs{:});
end

function c = pickPairs(s, names, keep)
% Flatten unmatched struct to a name-value cell. keep=true keeps only `names`;
% keep=false keeps everything except `names`.
fn = fieldnames(s);
if keep
    fn = fn(ismember(fn, names));
else
    fn = fn(~ismember(fn, names));
end
c = cell(1, 2 * numel(fn));
for i = 1:numel(fn)
    c{2*i - 1} = fn{i};
    c{2*i}     = s.(fn{i});
end
end
