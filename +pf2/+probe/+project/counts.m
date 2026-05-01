function [h, imgOut] = counts(Nvals, fNIR, varargin)
% COUNTS Project per-channel sample counts (N) onto the 3D cortical surface
%
% Sequential colorbar, positive-only, useful for showing coverage of a
% group analysis (e.g. how many subjects contributed per channel after
% rejection).
%
% Syntax:
%   pf2.probe.project.counts(Nvals, fNIR)
%   [h, imgOut] = pf2.probe.project.counts(Nvals, fNIR, ...)
%
% Inputs:
%   Nvals - [1 x K] non-negative counts per channel.
%   fNIR  - fNIRS struct / probe name.
%
% Name-Value Parameters (wrapper-specific):
%   'Range'       - [minN, maxN] colorbar limits. Default: [1, max(Nvals)].
%   'cmap'        - Sequential colormap function (default: @parula).
%
% Outputs: [h, imgOut].
%
% Example:
%   N = randi([5 30], 1, size(processed.HbO, 2));
%   pf2.probe.project.counts(N, processed, 'ForceLightMode', true);
%
% See also: pf2.probe.plot.interpolateValues3D

p = inputParser;
p.KeepUnmatched = true;
addRequired(p, 'Nvals', @(x) isnumeric(x) && isvector(x));
addRequired(p, 'fNIR');
addParameter(p, 'Range', [], @(x) isempty(x) || (isnumeric(x) && numel(x) == 2));
addParameter(p, 'cmap', @parula);
addParameter(p, 'titleString', 'N per channel', @(x) ischar(x) || isstring(x));
addParameter(p, 'colorbarStr', 'N', @(x) ischar(x) || isstring(x));
parse(p, Nvals, fNIR, varargin{:});

Nvals = Nvals(:)';
validMask = ~isnan(Nvals);

rangeVals = p.Results.Range;
if isempty(rangeVals)
    mx = max(Nvals(validMask), [], 'omitnan');
    if ~isfinite(mx) || mx <= 0, mx = 1; end
    rangeVals = [1, mx];
end
rangeVals = sort(rangeVals);

data2plot = Nvals;
data2plot(~validMask) = NaN;

forward = unmatchedToVarargin(p.Unmatched);

[h, imgOut] = pf2.probe.plot.interpolateValues3D( ...
    data2plot, fNIR, rangeVals(1), rangeVals(2), ...
    char(p.Results.titleString), char(p.Results.colorbarStr), ...
    'cmap', p.Results.cmap, ...
    forward{:});

end


function c = unmatchedToVarargin(s)
fn = fieldnames(s);
c = cell(1, 2 * numel(fn));
for i = 1:numel(fn)
    c{2*i - 1} = fn{i};
    c{2*i}     = s.(fn{i});
end
end
