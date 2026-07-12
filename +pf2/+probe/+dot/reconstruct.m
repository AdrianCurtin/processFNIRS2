function recon = reconstruct(data, varargin)
% RECONSTRUCT Diffuse optical tomography image reconstruction onto cortex
%
% Reconstructs vertex-space maps of hemoglobin change (HbO/HbR) from the
% channel measurements of a processed fNIRS recording, by inverting the atlas
% forward sensitivity model with a depth-weighted, channel-whitened Tikhonov
% minimum-norm estimator. The result lives on the bundled MNI cortical surface
% and is masked to the montage's optical-sensitivity field, so no signal is
% reported where the probe cannot see.
%
% Syntax:
%   recon = pf2.probe.dot.reconstruct(data)
%   recon = pf2.probe.dot.reconstruct(data, 'Time', [20 40])
%   recon = pf2.probe.dot.reconstruct(data, 'Biomarkers', {'HbO'}, 'AllTimes', true)
%
% Inputs:
%   data - processed fNIRS struct (with HbO/HbR and a device carrying 3D
%          geometry). Cell arrays are not handled here — reconstruct per element.
%
% Inputs (name-value):
%   'Biomarkers'  - Cell of fields to reconstruct (default {'HbO','HbR'}).
%   'Time'        - [] (default) reconstructs the recording time-mean; a scalar
%                   t reconstructs the nearest sample; [t0 t1] the window mean.
%                   Ignored when 'AllTimes' is true.
%   'AllTimes'    - Reconstruct every sample -> [T x nV] per biomarker
%                   (memory-heavy; warns past ~5e7 elements). Default false.
%   'Mask'        - Set vertices outside the coverage support to NaN
%                   (default true). 'MaskThreshold' sets the relative cutoff.
%   'MaskThreshold' - Coverage cutoff in [0,1) (default 0.05).
%   'Prior'       - Spatial prior (default 'minnorm'): 'minnorm' depth-weighted
%                   minimum norm; 'laplacian' graph-Laplacian smoothness over
%                   the covered cortex (favours spatially smooth images);
%                   'parcel' penalizes within-Brodmann-area variance (piecewise
%                   per-region). 'laplacian'/'parcel' reconstruct on the
%                   coverage support via a generalized-Tikhonov primal solve.
%   'ScalpRegression' - Remove superficial signal via short-separation channel
%                   regression before inversion, reconstructing from the long
%                   channels only (default false). No-op (with a warning) if the
%                   montage has no short channels. 'ScalpMethod' selects the
%                   variant: 'nearest' (each long channel on its nearest short
%                   channel), 'all' (on every short channel jointly), or 'pca'
%                   (on the leading short-channel principal component).
%                   'ShortSepThreshold' (default 15 mm) sets the source-detector
%                   distance below which a channel counts as short — derived in
%                   the forward-operator channel order, so it is alignment-safe.
%   'DepthWeight','Whiten','Lambda','LambdaFraction','RegMethod'
%                 - Forwarded to pf2_base.dot.reconstructImage.
%   (Other pairs, e.g. 'HighRes','ScalpOffset','MaxDistance','Prune', forward
%    to pf2.probe.forward.sensitivity.)
%
% Outputs:
%   recon - struct with fields:
%           .<Biomarker> - [1 x nV] (time-mean/point) or [T x nV] (AllTimes)
%           .vertices [nV x 3], .faces [nF x 3], .brodmann [nV x 1]
%           .coverage [1 x nV] normalized sensitivity field
%           .mask     [1 x nV] logical support used
%           .time     scalar/[1x2]/[T x 1] time reconstructed
%           .units    biomarker units (from data.units)
%           .lambda   regularization used (struct per biomarker)
%           .meta     forward .info + inverse meta
%
% Notes:
%   - Atlas (template) reconstruction; resolution is coarse (~2-3 cm for sparse
%     single-distance montages). See internal/DOT_ROADMAP.md.
%   - Concentration-domain inverse: each biomarker is reconstructed through the
%     geometric (geometry-only) sensitivity operator. The recovered map
%     estimates the SPATIAL DISTRIBUTION of the change; its absolute magnitude
%     is RELATIVE (not calibrated µM) because the operator is unnormalized and
%     the scale depends on the regularization. `recon.units` is suffixed
%     "(relative)" to reflect this. A spectral ΔOD->chromophore reconstruction
%     (absolute units) is a planned extension; see the roadmap.
%
% Example:
%   proc  = processFNIRS2(pf2.import.sampleData.fNIR2000());
%   recon = pf2.probe.dot.reconstruct(proc, 'Time', [10 30]);
%   pf2.probe.project.tomography(recon, 'Biomarker', 'HbO', 'savePath', 'dot.png');
%
% See also: pf2.probe.forward.sensitivity, pf2.probe.project.tomography,
%           pf2_base.dot.reconstructImage

p = inputParser;
p.KeepUnmatched = true;
addRequired(p, 'data', @isstruct);
addParameter(p, 'Biomarkers', {'HbO','HbR'}, @(x) iscellstr(x) || isstring(x) || ischar(x));
addParameter(p, 'Time', [], @(x) isempty(x) || (isnumeric(x) && numel(x) <= 2));
addParameter(p, 'AllTimes', false, @(x) islogical(x) && isscalar(x));
addParameter(p, 'Mask', true, @(x) islogical(x) && isscalar(x));
addParameter(p, 'MaskThreshold', 0.05, @(x) isnumeric(x) && isscalar(x) && x >= 0 && x < 1);
addParameter(p, 'DepthWeight', true, @(x) islogical(x) && isscalar(x));
addParameter(p, 'Whiten', true, @(x) islogical(x) && isscalar(x));
addParameter(p, 'Lambda', [], @(x) isempty(x) || isscalar(x));
addParameter(p, 'LambdaFraction', [], @(x) isempty(x) || isscalar(x));
addParameter(p, 'RegMethod', 'gcv', @(x) any(strcmpi(x, {'gcv','lcurve'})));
addParameter(p, 'Prior', 'minnorm', @(x) any(strcmpi(x, {'minnorm','laplacian','parcel'})));
addParameter(p, 'ScalpRegression', false, @(x) islogical(x) && isscalar(x));
addParameter(p, 'ScalpMethod', 'nearest', @(x) any(strcmpi(x, {'nearest','pca','all'})));
addParameter(p, 'ShortSepThreshold', 15, @(x) isnumeric(x) && isscalar(x) && x > 0);
parse(p, data, varargin{:});
opt = p.Results;
prior = lower(opt.Prior);

biomarkers = cellstr(opt.Biomarkers);

% --- Forward operator + mesh ----------------------------------------------
fwd = unmatchedToVarargin(p.Unmatched);
[A, mesh, fInfo] = pf2.probe.forward.sensitivity(data, fwd{:});
if iscell(A)
    A = A{1};   % concentration-domain uses one geometric operator
end
nCh0 = size(A, 1);
nV = size(A, 2);

% --- Short-separation / scalp regression (optional) ------------------------
% Remove superficial (scalp) signal using the short-separation channels, then
% reconstruct from the cleaned long channels only — so the image reflects
% cortical, not extracerebral, hemodynamics. Reuses the validated regression.
chanKeep = true(1, nCh0);
if opt.ScalpRegression
    % Identify short channels by source-detector distance, which is derived in
    % the SAME channel order as A's rows and the HbO/HbR columns (via
    % channelGeometry) — robust to montages whose TableOpt order differs from
    % the channel/forward-operator order.
    shortMask = fInfo.geom.sdDist(:)' < opt.ShortSepThreshold;
    if ~any(shortMask)
        warning('pf2:probe:dot:reconstruct:noShort', ...
            'No short-separation channels (< %g mm); ScalpRegression skipped.', ...
            opt.ShortSepThreshold);
    elseif all(shortMask)
        warning('pf2:probe:dot:reconstruct:allShort', ...
            'All channels are short-separation; ScalpRegression skipped.');
    else
        mid = fInfo.geom.mid;            % channel midpoints [nCh0 x 3]
        for b = 1:numel(biomarkers)
            bm = biomarkers{b};
            if isfield(data, bm)
                data.(bm) = regressScalp(data.(bm), shortMask, mid, opt.ScalpMethod);
            end
        end
        chanKeep = ~shortMask;          % long channels only drive the inverse
    end
end

% --- QC channel mask -------------------------------------------------------
% Bad channels (fchMask == 0) carry no usable measurement; their HbO/HbR is
% typically NaN. Drop them from the forward operator so a zero-filled value
% against a real sensitivity profile cannot bias the image or the auto-lambda.
if isfield(data, 'fchMask') && numel(data.fchMask) == nCh0
    bad = ~logical(data.fchMask(:)');
    if any(bad & chanKeep)
        warning('pf2:probe:dot:reconstruct:maskedChannels', ...
            'Excluding %d QC-flagged channel(s) (fchMask==0) from the inverse.', ...
            nnz(bad & chanKeep));
    end
    chanKeep = chanKeep & ~bad;
end

A = A(chanKeep, :);                     % retained channels drive the inverse
nCh = size(A, 1);
if nCh == 0
    error('pf2:probe:dot:reconstruct:noChannels', ...
        'No usable channels remain after masking; cannot reconstruct.');
end

% --- Coverage + mask -------------------------------------------------------
% Per-channel footprints normalized to their own peak then summed, so the
% coverage support reflects the whole montage, not just its short channels.
rp = max(A, [], 2); rp(rp < eps) = eps;
coverage = full(sum(A ./ rp, 1));
if max(coverage) > 0, coverage = coverage / max(coverage); end
mask = coverage > opt.MaskThreshold;

% --- Time selection --------------------------------------------------------
t = data.time(:);
[timeIdx, timeOut] = resolveTime(t, opt.Time, opt.AllTimes);

invArgs = {'DepthWeight', opt.DepthWeight, 'Whiten', opt.Whiten, ...
    'RegMethod', opt.RegMethod};
if ~isempty(opt.Lambda), invArgs = [invArgs, {'Lambda', opt.Lambda}]; end
if ~isempty(opt.LambdaFraction), invArgs = [invArgs, {'LambdaFraction', opt.LambdaFraction}]; end

% Spatially-variant prior: build a regularization operator over the covered
% support so the primal generalized-Tikhonov path is used (instead of the
% depth-weighted minimum-norm dual path).
if ~strcmp(prior, 'minnorm')
    subset = find(mask);
    switch prior
        case 'laplacian'
            G = pf2_base.dot.meshLaplacian(mesh.faces, 'Subset', subset);
        case 'parcel'
            G = parcelOperator(mesh.brodmann(subset));
    end
    invArgs = [invArgs, {'Subset', subset, 'RegOperator', G}];
end

recon = struct();
if isfield(data, 'device'), recon.device = data.device; end
recon.vertices = mesh.vertices;
recon.faces = mesh.faces;
recon.brodmann = mesh.brodmann;
recon.coverage = coverage;
recon.mask = mask;
recon.time = timeOut;
% Concentration-domain reconstruction through a geometry-only (unnormalized)
% sensitivity operator: the spatial pattern estimates the ΔHbX distribution, but
% the absolute scale is relative (depends on the operator scaling and lambda) —
% NOT calibrated µM. Label units accordingly so downstream plots/stats do not
% misread the magnitude as absolute concentration.
baseUnits = getfielddef(data, 'units', '');
if isempty(baseUnits)
    recon.units = 'relative';
else
    recon.units = sprintf('%s (relative)', baseUnits);
end
recon.lambda = struct();

for b = 1:numel(biomarkers)
    bm = biomarkers{b};
    if ~isfield(data, bm)
        error('pf2:probe:dot:reconstruct:noField', ...
            'data has no field ''%s'' to reconstruct.', bm);
    end
    M = data.(bm);
    if size(M, 2) ~= nCh0
        error('pf2:probe:dot:reconstruct:channelMismatch', ...
            ['%s has %d channels but the forward model has %d. Reconstruct ' ...
             'the same processed data the device describes.'], bm, size(M,2), nCh0);
    end
    M = M(:, chanKeep);                     % drop short channels if regressing

    if opt.AllTimes
        Y = M(timeIdx, :)';                 % [nCh x T]
        guardMemory(numel(timeIdx) * nV);
    else
        Y = mean(M(timeIdx, :), 1, 'omitnan')';  % [nCh x 1]
    end

    % Drop channels with no valid data for this biomarker/time selection so a
    % zero-filled measurement against a real sensitivity row cannot bias the
    % inverse. Residual sporadic NaNs in retained channels are zero-filled.
    rowOk = ~all(isnan(Y), 2);
    if ~any(rowOk)
        error('pf2:probe:dot:reconstruct:noValidChannels', ...
            'All channels for %s are NaN over the selected time; nothing to reconstruct.', bm);
    end
    if ~all(rowOk)
        warning('pf2:probe:dot:reconstruct:droppedChannels', ...
            '%s: dropped %d of %d channel(s) with no valid data before inversion.', ...
            bm, nnz(~rowOk), numel(rowOk));
    end
    Ab = A(rowOk, :);
    Y  = Y(rowOk, :);
    Y(isnan(Y)) = 0;

    [X, meta] = pf2_base.dot.reconstructImage(Ab, Y, invArgs{:});  % [nV x T]
    X = X';                                   % [T x nV] or [1 x nV]
    if opt.Mask
        X(:, ~mask) = NaN;
    end
    recon.(bm) = X;
    recon.lambda.(bm) = meta.lambda;
end

recon.meta = struct('forward', fInfo, 'biomarkers', {biomarkers}, ...
    'depthWeight', opt.DepthWeight, 'whiten', opt.Whiten, 'prior', prior);
end

% ------------------------------------------------------------------------- %
function M = regressScalp(M, shortMask, pos, method)
% Remove the superficial component from each long channel by regressing out the
% short-separation channels (nearest one, or all jointly). Short channels are
% left unchanged; only long channels are cleaned.
shortIdx = find(shortMask);
longIdx = find(~shortMask);
Xs = M(:, shortIdx);                          % [T x nShort]

% PCA basis of the short-separation set (shared across long channels).
pcaBasis = [];
if strcmpi(method, 'pca')
    Xc = Xs - mean(Xs, 1);
    [~, ~, V] = svd(Xc, 'econ');
    k = min(1, size(V, 2));                    % leading PC (dominant scalp comp)
    pcaBasis = Xc * V(:, 1:k);                 % [T x k] PC scores
end

for c = longIdx
    switch lower(method)
        case 'nearest'
            d = vecnorm(pos(shortIdx, :) - pos(c, :), 2, 2);
            [~, j] = min(d);
            X = Xs(:, j);
        case 'pca'
            X = pcaBasis;
        otherwise   % 'all' — regress on every short channel jointly
            X = Xs;
    end
    X = [ones(size(X,1),1), X];                %#ok<AGROW> % intercept
    beta = X \ M(:, c);
    M(:, c) = M(:, c) - X(:, 2:end) * beta(2:end);
end
end

% ------------------------------------------------------------------------- %
function G = parcelOperator(labels)
% Penalize within-Brodmann-parcel variance: G = I - P, P averages each vertex
% over its parcel. Unlabeled (0) or singleton parcels get no smoothing.
labels = labels(:);
n = numel(labels);
rows = []; cols = []; vals = [];
[u, ~, ic] = unique(labels);
for k = 1:numel(u)
    idx = find(ic == k);
    if u(k) == 0 || numel(idx) == 1
        rows = [rows; idx]; cols = [cols; idx]; vals = [vals; ones(numel(idx),1)]; %#ok<AGROW>
    else
        w = 1 / numel(idx);
        [II, JJ] = ndgrid(idx, idx);
        rows = [rows; II(:)]; cols = [cols; JJ(:)]; vals = [vals; w*ones(numel(idx)^2,1)]; %#ok<AGROW>
    end
end
P = sparse(rows, cols, vals, n, n);
G = speye(n) - P;
end

% ------------------------------------------------------------------------- %
function [idx, out] = resolveTime(t, timeSel, allTimes)
if allTimes
    idx = (1:numel(t))';
    out = t;
    return;
end
if isempty(timeSel)
    idx = (1:numel(t))';                  % whole-recording mean
    out = [t(1), t(end)];
elseif isscalar(timeSel)
    [~, idx] = min(abs(t - timeSel));     % nearest sample
    out = t(idx);
else
    idx = find(t >= min(timeSel) & t <= max(timeSel));
    if isempty(idx), [~, idx] = min(abs(t - mean(timeSel))); end
    out = [min(timeSel), max(timeSel)];
end
idx = idx(:);
end

function guardMemory(nElem)
if nElem > 5e7
    warning('pf2:probe:dot:reconstruct:largeOutput', ...
        ['AllTimes reconstruction is %.0e elements (~%.1f GB). Consider a ' ...
         'time window or resampling first.'], nElem, nElem * 8 / 1e9);
end
end

function v = getfielddef(s, f, dflt)
if isfield(s, f), v = s.(f); else, v = dflt; end
end

function c = unmatchedToVarargin(s)
fn = fieldnames(s);
c = cell(1, 2 * numel(fn));
for i = 1:numel(fn)
    c{2*i - 1} = fn{i};
    c{2*i}     = s.(fn{i});
end
end
