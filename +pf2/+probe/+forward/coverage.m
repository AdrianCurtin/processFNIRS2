function [cov, mesh] = coverage(data, varargin)
% COVERAGE Montage optical-sensitivity field over the cortical surface
%
% Returns, per cortical vertex, the total optical sensitivity of the montage —
% the sum over channels of the forward sensitivity matrix. This is the spatial
% support of the probe: where the montage can actually "see". It gates honest
% reconstruction (no signal is invented outside coverage) and drives the
% sensitivity-masked rendering of `pf2.probe.project.tomography`.
%
% Syntax:
%   cov = pf2.probe.forward.coverage(data)
%   [cov, mesh] = pf2.probe.forward.coverage(data, 'Normalize', true)
%
% Inputs:
%   data - processed/imported fNIRS struct, pf2.Device, or config name.
%
% Inputs (name-value):
%   'Normalize' - Scale the field to [0,1] by its max (default true). False
%                 returns the raw summed sensitivity.
%   'Threshold' - Relative cutoff in [0,1) (default 0); vertices below
%                 Threshold*max are set to 0, defining the coverage support.
%   (Any other name-value pairs forward to pf2.probe.forward.sensitivity, e.g.
%    'HighRes', 'ScalpOffset', 'MaxDistance'.)
%
% Outputs:
%   cov  - [1 x nV] per-vertex sensitivity (normalized unless disabled).
%   mesh - cortical mesh struct the field is defined on.
%
% Example:
%   [cov, mesh] = pf2.probe.forward.coverage(proc);
%   supported = cov > 0.1;          % vertices the montage can sense
%
% See also: pf2.probe.forward.sensitivity, pf2.probe.project.tomography

p = inputParser;
p.KeepUnmatched = true;
addRequired(p, 'data');
addParameter(p, 'Normalize', true, @(x) islogical(x) && isscalar(x));
addParameter(p, 'Threshold', 0, @(x) isnumeric(x) && isscalar(x) && x >= 0 && x < 1);
parse(p, data, varargin{:});

fwd = unmatchedToVarargin(p.Unmatched);
[A, mesh] = pf2.probe.forward.sensitivity(data, fwd{:});
if iscell(A)
    % Average across wavelengths for a single coverage field.
    S = zeros(1, size(A{1}, 2));
    for w = 1:numel(A), S = S + rowNormSum(A{w}); end
    cov = S / numel(A);
else
    cov = rowNormSum(A);
end

m = max(cov);
if m > 0
    if p.Results.Threshold > 0
        cov(cov < p.Results.Threshold * m) = 0;
    end
    if p.Results.Normalize
        cov = cov / m;
    end
end
end

function s = rowNormSum(A)
% Per-channel footprint, each normalized to its own peak, then summed — so a
% few high-sensitivity (short-separation) channels do not collapse the field.
rp = max(A, [], 2);
rp(rp < eps) = eps;
s = full(sum(A ./ rp, 1));
end

function c = unmatchedToVarargin(s)
fn = fieldnames(s);
c = cell(1, 2 * numel(fn));
for i = 1:numel(fn)
    c{2*i - 1} = fn{i};
    c{2*i}     = s.(fn{i});
end
end
