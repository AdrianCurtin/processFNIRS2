function [Cs, fadeAlpha] = interpolateChannelColors(distSquared, cNorm, cmap, opts)
% INTERPOLATECHANNELCOLORS Project per-channel values onto mesh vertices
%
% Maps normalized channel values onto a mesh by nearest-channel lookup or
% inverse-distance weighting, returning per-vertex colors and a blend weight
% (fadeAlpha) that smoothly transitions to the background at the buffer
% boundary. Shared between the surface-brain and voxel-brain projection
% paths in pf2.probe.plot.interpolateValues3D.
%
% Syntax:
%   [Cs, fadeAlpha] = pf2_base.plot.interpolateChannelColors( ...
%       distSquared, cNorm, cmap, opts)
%
% Inputs:
%   distSquared - [V x K] Squared distance (Euclidean or geodesic) from each
%                 mesh vertex to each channel control point. Use Inf for
%                 disallowed (vertex, channel) pairs (e.g. NaN channels).
%   cNorm       - [K x 1] Channel values pre-normalized to colormap range
%                 [0, 1]. Values < 0 render as background; values > 1 saturate
%                 to the top color.
%   cmap        - [M x 3] RGB colormap. Caller should pre-blend any alpha
%                 channel with the background color before passing in.
%
% Options (name-value):
%   'MaxDistance2' - Squared-distance cutoff. Vertices farther than this from
%                    every channel are marked out-of-range.
%   'ProjectMode'  - 'nearest' | 'linear' | 'quadratic' | 'cubic' |
%                    'sensitivity'
%                    IDW powers on squared distance: linear=0.5, quadratic=1,
%                    cubic=1.5. Names kept for backward compatibility with
%                    interpolateValues3D; these are NOT true linear/quadratic
%                    barycentric schemes. 'sensitivity' instead weights each
%                    channel by a Gaussian optical-sensitivity profile,
%                    w = exp(-d^2 / (2*sigma^2)) with sigma^2 = MaxDistance2/4
%                    (weight ~0.14 at the buffer edge), giving a smooth,
%                    physically-motivated falloff. It approximates the LATERAL
%                    sensitivity profile of a channel; it is not a full
%                    Monte-Carlo photon measurement density ("banana") and does
%                    not model source/detector elongation or depth.
%   'ChanMask'     - [K x 1] logical. True entries are rendered as background
%                    (e.g. values in the two-sided dead zone).
%   'FadeFraction' - Fraction of the buffer over which to fade to background
%                    (default 0.4, matching the prior inline behavior).
%
% Outputs:
%   Cs         - [V x 3] Per-vertex RGB colors. Entries where fadeAlpha == 0
%                are unspecified; caller must blend with a base color.
%   fadeAlpha  - [V x 1] Blend weight in [0, 1]. 1 at channel centers, 0 for
%                out-of-range or masked vertices, linearly fading between.
%                Caller blends:
%                  finalColor = Cs .* fadeAlpha + baseColor .* (1 - fadeAlpha)
%
% Example:
%   % Euclidean distance from mesh vertices to channel positions
%   d2 = sum(V.^2,2) + sum(P.^2,2)' - 2*(V*P');
%   [Cs, fa] = pf2_base.plot.interpolateChannelColors( ...
%       d2, cNorm, cmap, 'MaxDistance2', buf^2, 'ProjectMode', 'nearest');
%   finalColors = Cs .* fa + baseColor .* (1 - fa);
%
% See also: pf2.probe.plot.interpolateValues3D

arguments
    distSquared (:,:) double
    cNorm (:,1) double
    cmap (:,3) double
    opts.MaxDistance2 (1,1) double {mustBePositive}
    opts.ProjectMode (1,1) string = "nearest"
    opts.ChanMask (:,1) logical = false(numel(cNorm), 1)
    opts.FadeFraction (1,1) double {mustBePositive} = 0.4
end

V = size(distSquared, 1);
K = size(distSquared, 2);

if numel(cNorm) ~= K
    error('pf2_base:plot:interpolateChannelColors:sizeMismatch', ...
        'cNorm must have K=%d entries, got %d', K, numel(cNorm));
end
if numel(opts.ChanMask) ~= K
    error('pf2_base:plot:interpolateChannelColors:sizeMismatch', ...
        'ChanMask must have K=%d entries, got %d', K, numel(opts.ChanMask));
end

% Nearest channel per vertex (even in IDW mode; used for edge fade and out-of-range)
[d, ind] = min(distSquared, [], 2);
outOfRange = d > opts.MaxDistance2 | ~isfinite(d);
ind(outOfRange) = 0;

pm = lower(string(opts.ProjectMode));
switch pm
    case "nearest"
        vVal = nan(V, 1);
        valid = ind > 0;
        vVal(valid) = cNorm(ind(valid));
        if any(opts.ChanMask)
            maskedVerts = false(V, 1);
            maskedVerts(valid) = opts.ChanMask(ind(valid));
            vVal(maskedVerts) = NaN;
        end
    case {"linear", "quadratic", "cubic"}
        switch pm
            case "linear",    beta = 0.5;
            case "quadratic", beta = 1;
            case "cubic",     beta = 1.5;
        end
        distIdw = distSquared;
        distIdw(distIdw >= opts.MaxDistance2 | isnan(distIdw)) = Inf;
        w = 1 ./ (distIdw.^beta + 1e-8);
        wSum = sum(w, 2);
        vVal = (w * cNorm) ./ wSum;
        vVal(~isfinite(wSum) | wSum == 0) = NaN;
        if any(opts.ChanMask)
            vMask = (w * double(opts.ChanMask)) ./ wSum > 0.5;
            vVal(vMask) = NaN;
        end
    case "sensitivity"
        % Gaussian optical-sensitivity profile (lateral PMDF approximation).
        sigma2 = opts.MaxDistance2 / 4;
        w = exp(-distSquared / (2 * sigma2));
        w(distSquared > opts.MaxDistance2 | isnan(distSquared)) = 0;
        wSum = sum(w, 2);
        vVal = (w * cNorm) ./ wSum;
        vVal(~isfinite(wSum) | wSum == 0) = NaN;
        if any(opts.ChanMask)
            vMask = (w * double(opts.ChanMask)) ./ wSum > 0.5;
            vVal(vMask) = NaN;
        end
    otherwise
        error('pf2_base:plot:interpolateChannelColors:badMode', ...
            'Unknown ProjectMode: %s', opts.ProjectMode);
end

vVal(outOfRange) = NaN;

nColors = size(cmap, 1);
Cs = zeros(V, 3);
hasColor = ~isnan(vVal) & vVal >= 0;
if any(hasColor)
    idx = round(vVal(hasColor) * (nColors - 1)) + 1;
    idx = max(1, min(nColors, idx));
    Cs(hasColor, :) = cmap(idx, :);
end

fadeAlpha = zeros(V, 1);
if any(hasColor)
    dNearest = d(hasColor);
    dRatio = sqrt(max(dNearest, 0) / opts.MaxDistance2);
    fadeAlpha(hasColor) = max(0, min(1, (1 - dRatio) / opts.FadeFraction));
end

end
