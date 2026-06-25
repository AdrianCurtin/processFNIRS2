function res = resolution(data, varargin)
% RESOLUTION Point-spread (resolution) diagnostics for a DOT reconstruction
%
% Quantifies how well the montage + inverse can localize a focal cortical
% change, by computing the point-spread function (PSF) of the reconstruction
% operator at seed vertices. For a point source at vertex v, the PSF is column
% v of the resolution matrix R = K*A (K the reconstruction operator); its peak
% offset and spatial spread are the honest localization error and effective
% resolution at that location. Sparse single-distance montages have coarse
% (~cm) resolution — this makes that explicit rather than implied.
%
% Syntax:
%   res = pf2.probe.dot.resolution(data)
%   res = pf2.probe.dot.resolution(data, 'NSeeds', 60, 'LambdaFraction', 0.05)
%   res = pf2.probe.dot.resolution(data, 'Seeds', vertexIdx, 'PlotSeed', 1)
%
% Inputs:
%   data - processed/imported fNIRS struct (or device/config) with geometry.
%
% Inputs (name-value):
%   'NSeeds'         - Number of seed vertices sampled across the coverage
%                      support (default 80). Ignored if 'Seeds' is given.
%   'Seeds'          - Explicit vertex indices to probe.
%   'MaskThreshold'  - Coverage cutoff defining the support (default 0.05).
%   'LambdaFraction' - Regularization as a fraction of max(eig) (default 0.05);
%                      PSF width grows with regularization, so this is reported.
%   'Lambda'         - Absolute regularization parameter; pass a reconstruction's
%                      meta.lambda (or recon.lambda.HbO) to make the PSF match
%                      the operator that reconstruction actually used. Overrides
%                      'LambdaFraction'.
%   'DepthWeight'    - Match the reconstruction depth weighting (default true).
%
% NOTE: this diagnostic always channel-whitens (like the default reconstruct)
% and uses a FIXED lambda (no data, so no GCV/L-curve). Pass 'Lambda' to align
% it with a specific reconstruction; otherwise the reported resolution reflects
% 'LambdaFraction', not a data-driven lambda.
%   'PlotSeed'       - Render the PSF of seed #k (index into the seed list) via
%                      project.tomography; pair with 'savePath'.
%   (Other pairs forward to pf2.probe.forward.sensitivity.)
%
% Outputs:
%   res - struct:
%         .seeds         [1 x S] seed vertex indices
%         .seedPos       [S x 3] seed coordinates (mm)
%         .localization  [S x 1] distance (mm) from seed to PSF peak
%         .spread        [S x 1] PSF spatial spread (mm, intensity-weighted RMS
%                        distance from the peak) — the effective resolution
%         .fwhm          [S x 1] full width (mm) where PSF > 0.5*peak
%         .peakFrac      [S x 1] PSF value at the seed / peak value (1 = focal)
%         .summary       struct of median/mean/max localization, spread, fwhm
%         .lambda        regularization used
%         .mesh          cortical mesh struct
%
% Algorithm:
%   K = C A_w' (A_w C A_w' + lambda I)^{-1} W (whitening W=diag(1/rownorm),
%   depth prior C). PSF(:,v) = C A_w' (M+lambda I)^{-1} A_w(:,v). Metrics are
%   evaluated over the coverage support.
%
% References:
%   Arridge, S. R. (1999). Optical tomography in medical imaging. Inverse
%     Problems, 15(2), R41-R93. DOI: 10.1088/0266-5611/15/2/022
%
% Example:
%   res = pf2.probe.dot.resolution(proc);
%   fprintf('median resolution: %.1f mm\n', res.summary.medianSpread);
%
% See also: pf2.probe.dot.reconstruct, pf2.probe.forward.sensitivity

p = inputParser;
p.KeepUnmatched = true;
addRequired(p, 'data');
addParameter(p, 'NSeeds', 80, @(x) isnumeric(x) && isscalar(x) && x >= 1);
addParameter(p, 'Seeds', [], @(x) isempty(x) || (isnumeric(x) && isvector(x)));
addParameter(p, 'MaskThreshold', 0.05, @(x) isnumeric(x) && isscalar(x) && x >= 0 && x < 1);
addParameter(p, 'LambdaFraction', 0.05, @(x) isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, 'Lambda', [], @(x) isempty(x) || (isnumeric(x) && isscalar(x) && x >= 0));
addParameter(p, 'DepthWeight', true, @(x) islogical(x) && isscalar(x));
addParameter(p, 'PlotSeed', [], @(x) isempty(x) || (isnumeric(x) && isscalar(x)));
parse(p, data, varargin{:});
opt = p.Results;

forwardNames = {'Wavelength','HighRes','ScalpOffset','MaxDistance','Prune','mua','musp'};
fwd = pickPairs(p.Unmatched, forwardNames, true);
[A, mesh] = pf2.probe.forward.sensitivity(data, fwd{:});
V = mesh.vertices;
nV = size(A, 2);

% Coverage support.
rp = max(A, [], 2); rp(rp < eps) = eps;
coverage = full(sum(A ./ rp, 1))';
if max(coverage) > 0, coverage = coverage / max(coverage); end
covered = find(coverage > opt.MaskThreshold);

% Seeds.
if ~isempty(opt.Seeds)
    seeds = opt.Seeds(:)';
else
    nS = min(opt.NSeeds, numel(covered));
    seeds = covered(round(linspace(1, numel(covered), nS)))';
end

% Operator pieces (whitening + depth prior + regularized inverse).
rn = sqrt(full(sum(A.^2, 2))); rn(rn < eps) = eps;
Aw = A ./ rn;
cn = sqrt(full(sum(Aw.^2, 1)))';
if opt.DepthWeight
    delta = 0.1 * max(cn);
    c = 1 ./ (cn.^2 + delta.^2); c = c / max(c);
else
    c = ones(nV, 1);
end
Ac = Aw .* c';
M = full(Ac * Aw'); M = (M + M') / 2;
[U, Dg] = eig(M); d = max(real(diag(Dg)), 0);
if ~isempty(opt.Lambda)
    lambda = opt.Lambda;                 % match a specific reconstruction's lambda
else
    lambda = opt.LambdaFraction * max(d);
end
filt = 1 ./ (d + lambda);

S = numel(seeds);
loc = zeros(S, 1); spread = zeros(S, 1); fwhm = zeros(S, 1); peakFrac = zeros(S, 1);
for i = 1:S
    v = seeds(i);
    aw = full(Aw(:, v));                       % [m x 1]
    psf = c .* (Aw' * (U * (filt .* (U' * aw))));   % [nV x 1] resolution column
    psfc = psf(covered);
    w = max(psfc, 0);
    [pk, ipk] = max(psfc);
    peakPos = V(covered(ipk), :);
    loc(i) = norm(peakPos - V(v, :));
    dist = vecnorm(V(covered, :) - peakPos, 2, 2);
    if sum(w) > 0
        spread(i) = sqrt(sum(w .* dist.^2) / sum(w));
        % FWHM = full spatial extent (diameter) of the half-maximum region,
        % not 2*half-max-radius (which assumes a symmetric PSF and over-counts).
        hm = V(covered(psfc >= 0.5 * pk), :);
        fwhm(i) = halfMaxDiameter(hm);
    end
    if pk > 0, peakFrac(i) = psf(v) / pk; end
end

res = struct();
res.seeds = seeds;
res.seedPos = V(seeds, :);
res.localization = loc;
res.spread = spread;
res.fwhm = fwhm;
res.peakFrac = peakFrac;
res.lambda = lambda;
res.mesh = mesh;
res.summary = struct( ...
    'medianLocalization', median(loc), 'meanLocalization', mean(loc), ...
    'maxLocalization', max(loc), ...
    'medianSpread', median(spread), 'meanSpread', mean(spread), ...
    'medianFWHM', median(fwhm), 'nSeeds', S);

% Optional: render one seed's PSF on cortex.
if ~isempty(opt.PlotSeed)
    k = max(1, min(round(opt.PlotSeed), S));
    v = seeds(k);
    aw = full(Aw(:, v));
    psf = c .* (Aw' * (U * (filt .* (U' * aw))));
    psf(coverage <= opt.MaskThreshold) = NaN;
    recon = struct('device', data.device, 'vertices', V, 'faces', mesh.faces, ...
        'brodmann', mesh.brodmann, 'coverage', coverage', ...
        'mask', (coverage > opt.MaskThreshold)', 'units', 'PSF', ...
        'PSF', psf');
    plotArgs = pickPairs(p.Unmatched, forwardNames, false);
    pf2.probe.project.tomography(recon, 'Biomarker', 'PSF', plotArgs{:});
end
end

function w = halfMaxDiameter(pts)
% Full width (max pairwise distance) of the half-maximum vertex set. Subsamples
% if the set is large so the O(n^2) distance stays cheap.
n = size(pts, 1);
if n < 2, w = 0; return; end
if n > 400
    pts = pts(round(linspace(1, n, 400)), :);
end
D = pdist2(pts, pts);
w = max(D(:));
end

function c = pickPairs(s, names, keep)
fn = fieldnames(s);
if keep, fn = fn(ismember(fn, names)); else, fn = fn(~ismember(fn, names)); end
c = cell(1, 2 * numel(fn));
for i = 1:numel(fn)
    c{2*i - 1} = fn{i};
    c{2*i}     = s.(fn{i});
end
end
