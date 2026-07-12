function [h, imgOut] = correlation(rho, fNIR, varargin)
% CORRELATION Project signed correlation (rho) onto the 3D cortical surface
%
% Rho is signed in [-1, 1], so the visualization uses a diverging two-
% colorbar treatment (positive and negative magnitudes read separately).
% Non-significant channels render as transparent when p-values are given.
%
% Syntax:
%   pf2.probe.project.correlation(rho, fNIR)
%   pf2.probe.project.correlation(rho, fNIR, 'pvalues', p, 'pThreshold', 0.05)
%   pf2.probe.project.correlation(rho, fNIR, 'DeadZone', 0.1)
%   [h, imgOut] = pf2.probe.project.correlation(rho, fNIR, ...)
%
% Inputs:
%   rho  - [1 x K] correlation coefficients in [-1, 1].
%   fNIR - fNIRS struct / probe name.
%
% Name-Value Parameters (wrapper-specific):
%   'pvalues'    - [1 x K] companion p-values. When supplied, non-significant
%                  channels render as transparent.
%   'pThreshold' - Significance cutoff (default: 0.05).
%   'FDR'        - BH correction (default: false).
%   'DeadZone'   - Half-width of the dead zone around rho=0 (default: 0).
%                  Channels with |rho| < DeadZone render as brain color /
%                  transparent. 0 means two colorbars meet at 0.
%   'Range'      - [rhoNeg, rhoPos] scalar magnitudes for the colorbar ends
%                  (default: [-1, 1]). Useful when rho never reaches ±1.
%
% Outputs: [h, imgOut].
%
% Example:
%   rho = 2*rand(1, size(processed.HbO,2)) - 1;
%   p   = rand(size(rho));
%   pf2.probe.project.correlation(rho, processed, ...
%       'pvalues', p, 'pThreshold', 0.05, 'DeadZone', 0.05);
%
%   % Headless save (use 'savePath' for 3D renders)
%   pf2.probe.project.correlation(rho, processed, 'savePath', 'rho.png');
%
% See also: pf2.probe.plot.interpolateValues3D,
%           pf2.probe.project.biomarker

p = inputParser;
p.KeepUnmatched = true;
addRequired(p, 'rho', @(x) isnumeric(x) && isvector(x));
addRequired(p, 'fNIR');
addParameter(p, 'pvalues', [], @(x) isempty(x) || (isnumeric(x) && isvector(x)));
addParameter(p, 'pThreshold', 0.05, @(x) isnumeric(x) && isscalar(x) && x > 0 && x < 1);
addParameter(p, 'FDR', false, @islogical);
addParameter(p, 'DeadZone', 0, @(x) isnumeric(x) && isscalar(x) && x >= 0);
addParameter(p, 'Range', [-1, 1], @(x) isnumeric(x) && numel(x) == 2);
addParameter(p, 'titleString', 'Correlation (\rho)', @(x) ischar(x) || isstring(x));
addParameter(p, 'colorbarStr', '\rho', @(x) ischar(x) || isstring(x));
parse(p, rho, fNIR, varargin{:});

rho = rho(:)';
validMask = ~isnan(rho);

pvals = p.Results.pvalues;
if ~isempty(pvals)
    pvals = pvals(:)';
    if numel(pvals) ~= numel(rho)
        error('pf2:project:correlation:sizeMismatch', ...
            'pvalues must have same length as rho (got %d vs %d).', ...
            numel(pvals), numel(rho));
    end
    qvals = pvals;
    if p.Results.FDR && any(validMask)
        qvals(validMask) = exploreFNIRS.fx.performFDR(pvals(validMask));
    end
    sig = false(size(rho));
    sig(validMask) = qvals(validMask) < p.Results.pThreshold;
    chanAlpha = double(sig);
    alphaMode = 'transparent';
else
    chanAlpha = double(validMask);
    alphaMode = 'blend';
end

dz = p.Results.DeadZone;
rangeVals = sort(p.Results.Range);
if any(rangeVals > 0) && any(rangeVals < 0)
    % User gave a signed pair like [-1, 1]
    negMax = rangeVals(1);
    posMax = rangeVals(2);
else
    % Otherwise treat as symmetric magnitude
    m = max(abs(rangeVals));
    negMax = -m; posMax = m;
end

% Two-colorbar construction: minVal = [dead_low, dead_high], maxVal = posMax
minVal = [-dz, dz];
maxVal = [negMax, posMax];

data2plot = rho;
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
