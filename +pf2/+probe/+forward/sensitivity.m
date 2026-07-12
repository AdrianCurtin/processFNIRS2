function [A, mesh, info] = sensitivity(data, opts)
% SENSITIVITY DOT forward sensitivity matrix (PMDF) for a montage on cortex
%
% Builds the channel-by-vertex photon-measurement-density (sensitivity) matrix
% relating an absorption change at each cortical vertex to each channel's
% optical-density change, evaluated on the bundled MNI cortical surface. This
% is the forward operator A used by image reconstruction
% (`pf2.probe.dot.reconstruct`) and by the honest "banana" projection
% (`interpolateValues3D 'interpolateType','pmdf'`).
%
% Syntax:
%   A = pf2.probe.forward.sensitivity(data)
%   [A, mesh] = pf2.probe.forward.sensitivity(data)
%   [A, mesh, info] = pf2.probe.forward.sensitivity(data, 'Wavelength', 850)
%
% Inputs:
%   data - processed/imported fNIRS struct, pf2.Device, or device config name.
%          Must carry 3D optode geometry (hasMNI).
%
% Inputs (name-value):
%   'Wavelength'  - 'mean' (default) builds one geometric operator at the mean
%                   device wavelength; a numeric value builds at that
%                   wavelength; 'all' returns a [W x 1] cell of operators, one
%                   per device wavelength (for spectral reconstruction).
%   'HighRes'     - Use the full-resolution mesh (default true).
%   'ScalpOffset' - Optode-to-scalp offset in mm (default 12); see
%                   pf2_base.dot.sensitivityMatrix.
%   'MaxDistance' - Vertex distance gate in mm (default 50) to bound compute.
%   'Prune'       - Relative sparsity threshold (default 1e-3).
%   'mua','musp'  - Optical-property overrides (mm^-1), per wavelength.
%   'HeadModel'   - 'homogeneous' (default) or 'layered' (scalp/skull/CSF/gray
%                   ray-segmented model; see pf2_base.dot.layeredHeadModel).
%   'Layers'      - Layer struct override for the layered model.
%   'NormalMode'  - 'surface' (default) per-optode local-surface normals, or
%                   'radial' centroid-direction normals; see sensitivityMatrix.
%
% Outputs:
%   A    - [nCh x nV] sparse sensitivity matrix (or {W x 1} cell if
%          'Wavelength','all').
%   mesh - cortical mesh struct (vertices/faces/brodmann/centroid) the rows of
%          A are defined on.
%   info - struct: .wavelengths, .geom, .props, .perWavelengthInfo.
%
% Notes:
%   - This is an atlas (template) forward model: a single homogeneous
%     semi-infinite medium registered to MNI. It is a physically grounded
%     approximation, not a subject-specific or Monte-Carlo Jacobian. See
%     internal/DOT_ROADMAP.md (Tiers 3-4) for higher-fidelity paths.
%   - Results are memoised per (device, options) so repeated calls in a batch
%     loop are cheap.
%
% Example:
%   proc = processFNIRS2(pf2.import.sampleData.fNIR2000());
%   [A, mesh] = pf2.probe.forward.sensitivity(proc);
%   cov = full(sum(A, 1));   % montage sensitivity field over the cortex
%
% See also: pf2.probe.forward.coverage, pf2.probe.dot.reconstruct,
%           pf2_base.dot.sensitivityMatrix

arguments
    data
    opts.Wavelength = 'mean'
    opts.HighRes (1,1) logical = true
    opts.ScalpOffset (1,1) {mustBeNumeric} = 12
    opts.MaxDistance (1,1) {mustBeNumeric} = 50
    opts.Prune (1,1) {mustBeNumeric} = 1e-3
    opts.mua = []
    opts.musp = []
    opts.HeadModel = 'homogeneous'
    opts.Layers = []
    opts.NormalMode = 'surface'
end

persistent CACHE
if isempty(CACHE), CACHE = containers.Map('KeyType','char','ValueType','any'); end

opt = opts;

geom = pf2_base.dot.channelGeometry(data);
mesh = pf2_base.dot.corticalMesh('HighRes', opt.HighRes);

% Resolve which wavelength(s) to build at.
wlOpt = opt.Wavelength;
if (ischar(wlOpt) || isstring(wlOpt)) && strcmpi(wlOpt, 'all')
    wls = geom.wavelengths;
    multi = true;
elseif (ischar(wlOpt) || isstring(wlOpt)) && strcmpi(wlOpt, 'mean')
    wls = mean(geom.wavelengths);
    multi = false;
elseif isnumeric(wlOpt) && isscalar(wlOpt)
    wls = wlOpt;
    multi = false;
else
    error('pf2:probe:forward:sensitivity:badWavelength', ...
        'Wavelength must be ''mean'', ''all'', or a numeric scalar.');
end

key = cacheKey(geom, opt, wls, multi);
if CACHE.isKey(key)
    cached = CACHE(key);
    A = cached.A; info = cached.info;
    return;
end

props = pf2_base.dot.opticalProperties(wls, 'mua', opt.mua, 'musp', opt.musp);
smArgs = {'ScalpOffset', opt.ScalpOffset, 'MaxDistance', opt.MaxDistance, ...
    'Prune', opt.Prune, 'HeadModel', opt.HeadModel, 'NormalMode', opt.NormalMode};
if ~isempty(opt.Layers), smArgs = [smArgs, {'Layers', opt.Layers}]; end

if multi
    A = cell(numel(wls), 1);
    perInfo = cell(numel(wls), 1);
    for w = 1:numel(wls)
        pw = sliceProps(props, w);
        [A{w}, perInfo{w}] = pf2_base.dot.sensitivityMatrix(geom, mesh, pw, smArgs{:});
    end
else
    [A, perInfo] = pf2_base.dot.sensitivityMatrix(geom, mesh, props, smArgs{:});
end

info = struct('wavelengths', wls, 'geom', geom, 'props', props, ...
    'perWavelengthInfo', {perInfo});
CACHE(key) = struct('A', A, 'info', info);
end

function pw = sliceProps(props, w)
pw = struct('wavelengths', props.wavelengths(w), 'mua', props.mua(w), ...
    'musp', props.musp(w), 'D', props.D(w), 'mueff', props.mueff(w), ...
    'extHbO', props.extHbO(w), 'extHbR', props.extHbR(w));
end

function key = cacheKey(geom, opt, wls, multi)
% Device fingerprint: channel count + a hash of BOTH source and detector
% coordinates (not just their sum, which collides too easily).
devTag = sprintf('%d_%.6g_%.6g', size(geom.src,1), ...
    sum(geom.src(:) .* (1:numel(geom.src))'), ...
    sum(geom.det(:) .* (1:numel(geom.det))'));
% Layer fingerprint: optical properties AND layer boundaries (thickness).
layTag = '';
if ~isempty(opt.Layers)
    layTag = sprintf('%s_%s_%s', mat2str([opt.Layers.mua]), ...
        mat2str([opt.Layers.musp]), mat2str([opt.Layers.depthBot]));
end
key = sprintf('%s|wl%s|m%d|hr%d|so%g|md%g|pr%g|mua%s|musp%s|hm%s|nm%s|lay%s', devTag, ...
    mat2str(wls), multi, opt.HighRes, opt.ScalpOffset, opt.MaxDistance, ...
    opt.Prune, mat2str(opt.mua), mat2str(opt.musp), opt.HeadModel, opt.NormalMode, layTag);
end
