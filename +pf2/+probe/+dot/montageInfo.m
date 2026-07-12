function info = montageInfo(data, varargin)
% MONTAGEINFO Characterize a montage for diffuse optical tomography
%
% Summarizes the geometric properties that determine how well a montage
% supports DOT image reconstruction: the number and spread of source-detector
% separations, the presence of short-separation (scalp) channels, and how much
% the channel sensitivity profiles overlap on the cortex. High-density (HD-DOT)
% montages — many overlapping multi-distance measurements — yield genuine
% depth-resolved reconstructions; sparse single-distance montages give coarse,
% topography-like images. This reports which regime a montage is in.
%
% Syntax:
%   info = pf2.probe.dot.montageInfo(data)
%   info = pf2.probe.dot.montageInfo(data, 'Print', true)
%
% Inputs:
%   data - processed/imported fNIRS struct, pf2.Device, or config name.
%
% Inputs (name-value):
%   'Print'     - Print a human-readable summary (default false).
%   'SepTol'    - Separation grouping tolerance in mm (default 5): distances
%                 within this are treated as one "separation class".
%   (Other pairs forward to pf2.probe.forward.sensitivity for the overlap calc.)
%
% Outputs:
%   info - struct:
%          .nChannels, .nSources, .nDetectors
%          .separations      [1 x nCh] source-detector distances (mm)
%          .sepClasses       distinct separation classes (mm, rounded)
%          .nSepClasses      number of distinct separations (>1 => multi-dist)
%          .hasShortSep      any short-separation channel (< 15 mm)
%          .meanOverlap      mean number of channels sensing each covered vertex
%                            (sensitivity redundancy; >~2 supports overlap DOT)
%          .coverageVertices number of covered cortical vertices
%          .isHighDensity    heuristic: multi-distance AND meanOverlap > 2
%          .recommendation   short guidance string
%
% Example:
%   info = pf2.probe.dot.montageInfo(proc, 'Print', true);
%   if info.isHighDensity, recon = pf2.probe.dot.reconstruct(proc); end
%
% See also: pf2.probe.dot.reconstruct, pf2.probe.forward.sensitivity,
%           pf2.probe.dot.resolution

p = inputParser;
p.KeepUnmatched = true;
addRequired(p, 'data');
addParameter(p, 'Print', false, @(x) islogical(x) && isscalar(x));
addParameter(p, 'SepTol', 5, @(x) isnumeric(x) && isscalar(x) && x > 0);
parse(p, data, varargin{:});

geom = pf2_base.dot.channelGeometry(data);
sep = geom.sdDist(:)';
nCh = numel(sep);

sepClasses = uniquetol(sep, p.Results.SepTol, 'DataScale', 1);
sepClasses = round(sepClasses, 1);

% Overlap: how many channels' sensitivity reach each covered vertex.
fwd = unmatchedToVarargin(p.Unmatched, {'Print','SepTol'});
[A, ~] = pf2.probe.forward.sensitivity(data, fwd{:});
if iscell(A), A = A{1}; end
rp = max(A, [], 2); rp(rp < eps) = eps;
An = A ./ rp;                                   % per-channel normalized footprint
hit = An > 0.1;                                 % vertex "seen" by a channel
perVertex = full(sum(hit, 1));
covered = perVertex > 0;
meanOverlap = mean(perVertex(covered));

info = struct();
info.nChannels = nCh;
info.nSources = size(unique(geom.src, 'rows'), 1);
info.nDetectors = size(unique(geom.det, 'rows'), 1);
info.separations = sep;
info.sepClasses = sepClasses;
info.nSepClasses = numel(sepClasses);
info.hasShortSep = any(sep < 15);
info.meanOverlap = meanOverlap;
info.coverageVertices = sum(covered);
info.isHighDensity = info.nSepClasses > 1 && meanOverlap > 2;

if info.isHighDensity
    info.recommendation = ['High-density / multi-distance montage: depth-' ...
        'resolved DOT is meaningful. Consider ScalpRegression and a layered ' ...
        'HeadModel.'];
elseif info.nSepClasses > 1
    info.recommendation = ['Multi-distance but limited overlap: DOT adds some ' ...
        'depth weighting; localization stays coarse.'];
else
    info.recommendation = ['Sparse single-distance montage: reconstruction ' ...
        'infrastructure works but resolution is ~cm (topography-like).'];
end

if p.Results.Print
    fprintf('Montage DOT characterization\n');
    fprintf('  channels: %d  (sources %d, detectors %d)\n', ...
        info.nChannels, info.nSources, info.nDetectors);
    fprintf('  separations: %s mm  (%d class(es))\n', ...
        mat2str(info.sepClasses), info.nSepClasses);
    fprintf('  short-separation channels: %s\n', ternary(info.hasShortSep,'yes','no'));
    fprintf('  mean sensitivity overlap: %.1f channels/vertex over %d vertices\n', ...
        info.meanOverlap, info.coverageVertices);
    fprintf('  high-density: %s\n', ternary(info.isHighDensity,'YES','no'));
    fprintf('  -> %s\n', info.recommendation);
end
end

function s = ternary(c, a, b)
if c, s = a; else, s = b; end
end

function c = unmatchedToVarargin(s, drop)
fn = fieldnames(s);
fn = fn(~ismember(fn, drop));
c = cell(1, 2 * numel(fn));
for i = 1:numel(fn)
    c{2*i - 1} = fn{i};
    c{2*i}     = s.(fn{i});
end
end
