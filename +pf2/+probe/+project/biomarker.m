function [h, imgOut] = biomarker(vals, fNIR, varargin)
% BIOMARKER Project signed biomarker values (HbO, HbR, contrast Δ) on cortex
%
% Signed biomarker values use a diverging two-colorbar treatment so
% magnitude can be read in either direction. Optional p-value masking
% renders non-significant channels transparent.
%
% Syntax:
%   pf2.probe.project.biomarker(vals, fNIR)
%   pf2.probe.project.biomarker(vals, fNIR, 'Range', [-1, 1])
%   pf2.probe.project.biomarker(vals, fNIR, 'pvalues', p, 'pThreshold', 0.05)
%   [h, imgOut] = pf2.probe.project.biomarker(vals, fNIR, ...)
%
% Inputs:
%   vals - [1 x K] signed biomarker values per channel.
%   fNIR - fNIRS struct / probe name.
%
% Name-Value Parameters (wrapper-specific):
%   'Range'       - [negMax, posMax] colorbar limits. Default: symmetric
%                   auto-range = [-m, m] where m = max(abs(vals)).
%   'DeadZone'    - Half-width around 0 rendered as brain color (default: 0).
%   'pvalues'     - [1 x K] significance p-values. When supplied, non-
%                   significant channels render transparent.
%   'pThreshold'  - Significance cutoff (default: 0.05).
%   'FDR'         - BH correction (default: false).
%
% Outputs: [h, imgOut].
%
% Example:
%   vals = processed.HbO(100, :);
%   pf2.probe.project.biomarker(vals, processed, 'Range', [-1, 1], ...
%       'ForceLightMode', true);
%
%   % Headless save (use 'savePath' for 3D renders)
%   pf2.probe.project.biomarker(vals, processed, 'savePath', 'hbo.png');
%
% See also: pf2.probe.plot.interpolateValues3D,
%           pf2.probe.project.correlation

p = inputParser;
p.KeepUnmatched = true;
addRequired(p, 'vals', @(x) isnumeric(x) && isvector(x));
addRequired(p, 'fNIR');
addParameter(p, 'Range', [], @(x) isempty(x) || (isnumeric(x) && numel(x) == 2));
addParameter(p, 'DeadZone', 0, @(x) isnumeric(x) && isscalar(x) && x >= 0);
addParameter(p, 'pvalues', [], @(x) isempty(x) || (isnumeric(x) && isvector(x)));
addParameter(p, 'pThreshold', 0.05, @(x) isnumeric(x) && isscalar(x) && x > 0 && x < 1);
addParameter(p, 'FDR', false, @islogical);
addParameter(p, 'titleString', '', @(x) ischar(x) || isstring(x));
addParameter(p, 'colorbarStr', '', @(x) ischar(x) || isstring(x));
parse(p, vals, fNIR, varargin{:});

vals = vals(:)';
validMask = ~isnan(vals);

rangeVals = p.Results.Range;
if isempty(rangeVals)
    m = max(abs(vals(validMask)), [], 'omitnan');
    if ~isfinite(m) || m == 0, m = 1; end
    rangeVals = [-m, m];
end
rangeVals = sort(rangeVals);
negMax = rangeVals(1);
posMax = rangeVals(2);

pvals = p.Results.pvalues;
if ~isempty(pvals)
    pvals = pvals(:)';
    if numel(pvals) ~= numel(vals)
        error('pf2:project:biomarker:sizeMismatch', ...
            'pvalues must have same length as vals (got %d vs %d).', ...
            numel(pvals), numel(vals));
    end
    qvals = pvals;
    if p.Results.FDR && any(validMask)
        qvals(validMask) = exploreFNIRS.fx.performFDR(pvals(validMask));
    end
    sig = false(size(vals));
    sig(validMask) = qvals(validMask) < p.Results.pThreshold;
    chanAlpha = double(sig);
    alphaMode = 'transparent';
else
    chanAlpha = double(validMask);
    alphaMode = 'blend';
end

dz = p.Results.DeadZone;
minVal = [-dz, dz];
maxVal = [negMax, posMax];

data2plot = vals;
data2plot(~validMask) = NaN;

forward = unmatchedToVarargin(p.Unmatched);

[h, imgOut] = pf2.probe.plot.interpolateValues3D( ...
    data2plot, fNIR, minVal, maxVal, ...
    char(p.Results.titleString), char(p.Results.colorbarStr), ...
    'ChannelAlpha', chanAlpha, ...
    'AlphaMode', alphaMode, ...
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
