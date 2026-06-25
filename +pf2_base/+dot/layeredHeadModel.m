function layers = layeredHeadModel(varargin)
% LAYEREDHEADMODEL Default layered optical properties of the adult head
%
% Returns a depth-ordered description of the extracerebral and cortical layers
% (scalp, skull, CSF, gray matter) with their thicknesses and optical
% properties, for the layered DOT forward model. The low-absorption, low-
% scattering CSF layer in particular channels light and reshapes the cortical
% sensitivity profile relative to a single homogeneous medium.
%
% Syntax:
%   layers = pf2_base.dot.layeredHeadModel()
%   layers = pf2_base.dot.layeredHeadModel('Thickness', [3 7 2])
%   layers = pf2_base.dot.layeredHeadModel('mua', [...], 'musp', [...])
%
% Inputs (name-value):
%   'Thickness' - [scalp skull csf] thicknesses in mm (default [3 7 2]); gray
%                 matter is the half-space below. Boundaries are cumulative
%                 depths from the scalp surface.
%   'mua'       - [1 x 4] absorption per layer (mm^-1), order scalp/skull/csf/
%                 gray. Default bulk adult values (~800 nm).
%   'musp'      - [1 x 4] reduced scattering per layer (mm^-1), same order.
%
% Outputs:
%   layers - [1 x 4] struct array, superficial -> deep, each with:
%            .name      layer name
%            .depthTop  depth (mm) of the layer's upper boundary from scalp
%            .depthBot  depth (mm) of the lower boundary (Inf for gray)
%            .mua, .musp, .D, .mueff   optical coefficients (mm units)
%
% Notes:
%   - This is an atlas approximation: properties are bulk single values per
%     layer, not wavelength-resolved or subject-specific. The CSF entry uses an
%     EFFECTIVE reduced scattering (the diffusion approximation is invalid in a
%     clear layer); see Custo et al. (2006).
%
% References:
%   Custo, A., Wells, W. M., Barnett, A. H., Hillman, E. M. C. & Boas, D. A.
%     (2006). Effective scattering coefficient of the cerebral spinal fluid in
%     adult head models for diffuse optical imaging. Applied Optics, 45(19),
%     4747-4755. DOI: 10.1364/AO.45.004747
%   Strangman, G. E., Zhang, Q. & Li, Z. (2014). Scalp and skull influence on
%     near infrared photon propagation in the Colin27 brain template.
%     NeuroImage, 85, 136-149. DOI: 10.1016/j.neuroimage.2013.04.090
%
% Example:
%   layers = pf2_base.dot.layeredHeadModel();
%   {layers.name}        % {'scalp','skull','csf','gray'}
%
% See also: pf2_base.dot.greensFunctionLayered, pf2_base.dot.sensitivityMatrix

p = inputParser;
addParameter(p, 'Thickness', [3 7 2], @(x) isnumeric(x) && numel(x) == 3 && all(x > 0));
% Representative adult-head per-layer values (~800 nm). Ordering follows the
% DOT-atlas literature: gray matter is the strongest scatterer, skull scatters
% more than scalp, and CSF uses a low EFFECTIVE mu_s' (the diffusion
% approximation is invalid in a clear layer). Magnitudes bracket the values used
% in adult head models (Custo et al. 2006; Strangman et al. 2014; common MCX
% atlas defaults); substitute measured values for a specific study.
addParameter(p, 'mua',  [0.018 0.012 0.004 0.019], @(x) isnumeric(x) && numel(x) == 4);
addParameter(p, 'musp', [0.80  1.00  0.30  1.80 ], @(x) isnumeric(x) && numel(x) == 4);
parse(p, varargin{:});

names = {'scalp','skull','csf','gray'};
th = p.Results.Thickness;
tops = [0, cumsum(th)];                 % [0, t1, t1+t2, t1+t2+t3]
bots = [cumsum(th), Inf];               % cumulative, gray -> Inf
mua = p.Results.mua;
musp = p.Results.musp;

layers = struct('name', names, ...
    'depthTop', num2cell(tops), 'depthBot', num2cell(bots), ...
    'mua', num2cell(mua), 'musp', num2cell(musp), ...
    'D', num2cell(1 ./ (3 * (mua + musp))), ...
    'mueff', num2cell(sqrt(3 * mua .* (mua + musp))));
end
