function [cmap, alpha] = brainColormap(name, n)
% BRAINCOLORMAP Cortical-overlay colormaps (MRIcroGL/Surfice LUTs + CVD-safe)
%
% Returns an [n x 3] RGB colormap (and an optional per-entry alpha ramp) for
% colouring statistical/biomarker overlays on a cortical surface. Includes
% faithful rebuilds of the MRIcroGL / Surfice lookup tables from their
% published control-node values, plus perceptually-uniform, colour-blind-safe
% defaults that are preferable for quantitative work. The MRIcroGL LUTs carry
% a rising alpha ramp (transparent at the low end, ~50% at the peak) — the
% second output exposes it so overlays can fade in toward threshold the way
% MRIcroGL renders them.
%
% Syntax:
%   cmap = pf2_base.plot.brainColormap(name)
%   cmap = pf2_base.plot.brainColormap(name, n)
%   [cmap, alpha] = pf2_base.plot.brainColormap(name, n)
%
% Inputs:
%   name - Colormap name (case-insensitive):
%          MRIcroGL/Surfice : 'actc', 'warm', 'cool', 'hot', 'redyell',
%                             'blue2red', 'bone', 'surface'
%          CVD-safe (preferred): 'rdbu' (diverging, red=positive), and any
%                             MATLAB built-in by name ('viridis','cividis',
%                             'turbo','parula','hot','winter', ...).
%   n    - Number of entries (default 256).
%
% Outputs:
%   cmap  - [n x 3] RGB in [0,1].
%   alpha - [n x 1] opacity ramp in [0,1]. For MRIcroGL LUTs this is the
%           LUT's own alpha column; for other maps it is all ones.
%
% Notes:
%   'actc', 'blue2red' (green midpoint) and the 'warm'+'cool' pair are the
%   recognizable MRIcroGL looks but are NOT colour-blind safe. For
%   quantitative figures prefer 'rdbu' (diverging) or 'viridis'/'cividis'
%   (sequential).
%
% Example:
%   [cmap, a] = pf2_base.plot.brainColormap('actc', 256);
%   colormap(gca, cmap);
%
% See also: pf2_base.plot.matcapTexture, pf2.probe.plot.interpolateValues3D

    if nargin < 1 || isempty(name), name = 'rdbu'; end
    if nargin < 2 || isempty(n),    n = 256;       end
    name = lower(char(name));

    % MRIcroGL/Surfice LUTs as [intensity(0-255) R G B A] control nodes.
    nodes = [];
    switch name
        case 'actc'
            nodes = [  0   0   0   0   0
                      64   0   0 136  32
                     128  24 177   0  64
                     156 248 254   0  78
                     255 255   0   0 128];
        case {'warm','6warm'}
            nodes = [  0 255 127   0   0
                     128 255 196   0  64
                     255 255 254   0 128];
        case {'cool','7cool'}
            nodes = [  0   0 127 255   0
                     128   0 196 255  64
                     255   0 254 255 128];
        case {'hot','4hot'}
            nodes = [  0   3   0   0   0
                      95 255   0   0  48
                     191 255 255   0  96
                     255 255 255 255 128];
        case {'redyell','8redyell'}
            nodes = [  0   0   0   0   0
                     128 255   0   0  64
                     255 255 255   0 128];
        case 'blue2red'
            nodes = [  0   0   0   0   0
                       1   0  32 255 128
                      64   0 128 196  64
                     128   0 128   0  64
                     192 196 128   0  64
                     255 255  32   0 128];
        case 'bone'
            nodes = [  0   0   0   0   0
                     153 103 126 165  76
                     255 255 255 255 128];
        case 'surface'
            nodes = [  0   1   1   1   0
                     153 240 128 128  76
                     255 255 255 255 128];
        case 'viridis'
            % Perceptually-uniform, colour-blind safe sequential (matplotlib).
            cmap = iInterpRGB([
                0.267 0.005 0.329
                0.283 0.141 0.458
                0.254 0.265 0.530
                0.207 0.372 0.553
                0.164 0.471 0.558
                0.128 0.567 0.551
                0.135 0.659 0.518
                0.267 0.749 0.441
                0.478 0.821 0.318
                0.741 0.873 0.150
                0.993 0.906 0.144], n);
            alpha = ones(n, 1);
            return;
        case 'cividis'
            % Perceptually-uniform, optimized for colour-vision deficiency.
            cmap = iInterpRGB([
                0.000 0.125 0.302
                0.000 0.188 0.435
                0.165 0.251 0.424
                0.282 0.322 0.420
                0.369 0.384 0.431
                0.447 0.451 0.455
                0.529 0.518 0.475
                0.620 0.588 0.467
                0.714 0.663 0.443
                0.816 0.741 0.400
                1.000 0.918 0.275], n);
            alpha = ones(n, 1);
            return;
        case {'rdbu','redblue','coolwarm'}
            % ColorBrewer 11-class RdBu, reversed so blue=negative, red=positive.
            % Perceptually balanced and colour-blind safe.
            cmap = iInterpRGB([  5  48  97
                                33 102 172
                                67 147 195
                               146 197 222
                               209 229 240
                               247 247 247
                               253 219 199
                               244 165 130
                               214  96  77
                               178  24  43
                               103   0  31] / 255, n);
            alpha = ones(n, 1);
            return;
        otherwise
            % Fall through to a MATLAB built-in colormap by name.
            try
                fn = str2func(name);
                cmap = fn(n);
            catch
                error('pf2_base:plot:brainColormap:badName', ...
                    'Unknown colormap ''%s''.', name);
            end
            if ~isnumeric(cmap) || size(cmap,2) ~= 3
                error('pf2_base:plot:brainColormap:badName', ...
                    'Unknown colormap ''%s''.', name);
            end
            alpha = ones(size(cmap,1), 1);
            return;
    end

    % Interpolate control nodes (RGBA) onto an n-entry table.
    t  = nodes(:,1) / 255;
    ti = linspace(0, 1, n)';
    cmap  = [interp1(t, nodes(:,2), ti), ...
             interp1(t, nodes(:,3), ti), ...
             interp1(t, nodes(:,4), ti)] / 255;
    alpha = interp1(t, nodes(:,5), ti) / 255;
    cmap  = min(max(cmap, 0), 1);
    alpha = min(max(alpha, 0), 1);
end


function cmap = iInterpRGB(rgb, n)
% Linearly resample evenly-spaced RGB control points to an n-entry colormap.
    t  = linspace(0, 1, size(rgb,1));
    ti = linspace(0, 1, n);
    cmap = [interp1(t, rgb(:,1), ti)', ...
            interp1(t, rgb(:,2), ti)', ...
            interp1(t, rgb(:,3), ti)'];
    cmap = min(max(cmap, 0), 1);
end
