function [h, imgOut] = fstats(Fvals, fNIR, varargin)
% FSTATS Project per-channel F-statistics onto the 3D cortical surface
%
% F-statistics are strictly positive. Non-significant channels render as
% transparent (brain shows through). Significance is determined either by
% companion p-values or by an explicit F critical value.
%
% Syntax:
%   pf2.probe.project.fstats(Fvals, fNIR)
%   pf2.probe.project.fstats(Fvals, fNIR, 'pvalues', pvals, 'pThreshold', 0.05)
%   pf2.probe.project.fstats(Fvals, fNIR, 'Fcritical', 3.84)
%   [h, imgOut] = pf2.probe.project.fstats(Fvals, fNIR, ...)
%
% Inputs:
%   Fvals - [1 x K] F-statistics per channel.
%   fNIR  - fNIRS struct / probe name.
%
% Name-Value Parameters (wrapper-specific):
%   'pvalues'    - [1 x K] companion p-values. If provided, significance
%                  is pvals < pThreshold (after optional FDR).
%   'pThreshold' - Significance cutoff for pvalues (default: 0.05).
%   'Fcritical'  - Alternative to pvalues: F threshold for significance.
%                  Used when pvalues is not supplied.
%   'FDR'        - BH correction of pvalues (default: false).
%   'FloorAtCritical' - If true, clamp the colorbar minimum to Fcritical
%                  (or the min F of significant channels). Default: true.
%
% Outputs: [h, imgOut] (axes + RGB capture).
%
% Example:
%   F = abs(randn(1, size(processed.HbO,2))) * 5;
%   p = 1 - fcdf(F, 1, 30);
%   pf2.probe.project.fstats(F, processed, 'pvalues', p, 'pThreshold', 0.05);
%
%   % Headless save (use 'savePath' for 3D renders)
%   pf2.probe.project.fstats(F, processed, 'savePath', 'fstats.png');
%
% See also: pf2.probe.plot.interpolateValues3D, pf2.probe.project.pvalues

p = inputParser;
p.KeepUnmatched = true;
addRequired(p, 'Fvals', @(x) isnumeric(x) && isvector(x));
addRequired(p, 'fNIR');
addParameter(p, 'pvalues', [], @(x) isempty(x) || (isnumeric(x) && isvector(x)));
addParameter(p, 'pThreshold', 0.05, @(x) isnumeric(x) && isscalar(x) && x > 0 && x < 1);
addParameter(p, 'Fcritical', [], @(x) isempty(x) || (isnumeric(x) && isscalar(x) && x >= 0));
addParameter(p, 'FDR', false, @islogical);
addParameter(p, 'FloorAtCritical', true, @islogical);
addParameter(p, 'titleString', 'F-statistics', @(x) ischar(x) || isstring(x));
addParameter(p, 'colorbarStr', 'F', @(x) ischar(x) || isstring(x));
parse(p, Fvals, fNIR, varargin{:});

Fvals = Fvals(:)';
pvals = p.Results.pvalues;
Fcrit = p.Results.Fcritical;
pThresh = p.Results.pThreshold;

validMask = ~isnan(Fvals);

if ~isempty(pvals)
    pvals = pvals(:)';
    if numel(pvals) ~= numel(Fvals)
        error('pf2:project:fstats:sizeMismatch', ...
            'pvalues must have same length as Fvals (got %d vs %d).', ...
            numel(pvals), numel(Fvals));
    end
    qvals = pvals;
    if p.Results.FDR && any(validMask)
        qvals(validMask) = exploreFNIRS.fx.performFDR(pvals(validMask));
    end
    sig = false(size(Fvals));
    sig(validMask) = qvals(validMask) < pThresh;
elseif ~isempty(Fcrit)
    sig = false(size(Fvals));
    sig(validMask) = Fvals(validMask) > Fcrit;
else
    warning('pf2:project:fstats:noSignificance', ...
        'Neither pvalues nor Fcritical supplied; all channels rendered opaque.');
    sig = validMask;
end

chanAlpha = double(sig);

if p.Results.FloorAtCritical
    if ~isempty(Fcrit)
        minVal = Fcrit;
    elseif any(sig)
        minVal = min(Fvals(sig), [], 'omitnan');
    else
        minVal = 0;
    end
else
    minVal = 0;
end
maxVal = max(Fvals, [], 'omitnan');
if ~isfinite(maxVal) || maxVal <= minVal
    maxVal = minVal + eps;
end

data2plot = Fvals;
data2plot(~validMask) = NaN;

forward = unmatchedToVarargin(p.Unmatched);

[h, imgOut] = pf2.probe.plot.interpolateValues3D( ...
    data2plot, fNIR, minVal, maxVal, ...
    char(p.Results.titleString), char(p.Results.colorbarStr), ...
    'ChannelAlpha', chanAlpha, ...
    'AlphaMode', 'transparent', ...
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
