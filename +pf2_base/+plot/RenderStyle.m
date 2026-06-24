classdef RenderStyle
% RENDERSTYLE Render-quality presets for 3D cortical surface visualization
%
% Bundles the rendering knobs that control how a cortical surface is shaded
% (lighting model, ambient-occlusion strength, matcap material, key/fill/rim
% light intensities, default camera framing and export supersampling) into a
% small set of named presets, so the same data can be rendered either for
% credible publication figures or for a high-impact "showcase" look.
%
% Presets:
%   'publication' (default) - Smooth Gouraud matte cortex, gentle sulcal
%                             ambient occlusion, conservative key+fill
%                             lighting, white background, no matcap. The
%                             understated look reviewers expect.
%   'showcase'              - Procedural matcap shading (clay material),
%                             stronger sulcal ambient occlusion, an elevated
%                             3/4 "hero" default view and 2x export
%                             supersampling. The polished, sellable look,
%                             inspired by MRIcroGL/Surfice surface renders.
%
% Syntax:
%   s = pf2_base.plot.RenderStyle.get('showcase')
%   s = pf2_base.plot.RenderStyle.get(existingStyleStruct)   % passthrough
%
% Outputs (struct fields on s):
%   name           - Resolved preset name.
%   lighting       - 'gouraud' | 'flat' | 'phong' (MATLAB FaceLighting).
%   useMatcap      - logical; bake matcap CData (FaceLighting forced 'none').
%   matcapMaterial - matcap material name (see matcapTexture).
%   aoStrength     - 0..1 sulcal ambient-occlusion darkening.
%   aoGyral        - 0..1 mild gyral-crown brightening.
%   ka,kd,ks,specExp - material coefficients for the MATLAB lighting path.
%   keyIntensity,fillIntensity,rimIntensity - light intensities (0..1).
%   heroView       - logical; use an elevated 3/4 default camera for 'auto'.
%   supersample    - integer export scale factor (1 = none).
%   grayCortex     - logical; use a neutral-gray cortex (baseGray) when the
%                    caller leaves brainColor at its default, so overlays pop.
%   baseGray       - [1x3] neutral cortex colour used as the matcap/AO base.
%
% Note: get() defaults to 'publication' as a conservative fallback, but the
% renderer (pf2.probe.plot.interpolateValues3D and its wrappers) defaults to
% 'showcase'. Pass an explicit name to avoid ambiguity.
%
% Example:
%   s = pf2_base.plot.RenderStyle.get('showcase');
%   % consumed by pf2.probe.plot.interpolateValues3D via 'Style','showcase'
%
% See also: pf2_base.plot.matcapTexture, pf2_base.plot.meshCurvature,
%           pf2.probe.plot.interpolateValues3D, pf2_base.plot.PlotStyle

    methods (Static)

        function s = get(name)
        % GET Resolve a preset name (or passthrough struct) to a style struct
            if nargin < 1 || isempty(name)
                name = 'publication';
            end
            % Passthrough: an already-resolved style struct is returned as-is
            % (lets callers override individual fields before rendering).
            if isstruct(name)
                s = pf2_base.plot.RenderStyle.fillDefaults(name);
                return;
            end
            switch lower(char(name))
                case {'publication','pub','default'}
                    s = pf2_base.plot.RenderStyle.publication();
                case {'showcase','presentation','keynote'}
                    s = pf2_base.plot.RenderStyle.showcase();
                otherwise
                    error('pf2_base:plot:RenderStyle:badName', ...
                        'Unknown render style ''%s''. Use ''publication'' or ''showcase''.', ...
                        char(name));
            end
        end

        function s = publication()
        % PUBLICATION Conservative, credible matte cortex (default)
            s = struct();
            s.name           = 'publication';
            s.lighting       = 'gouraud';
            s.useMatcap      = false;
            s.matcapMaterial = 'matte';
            s.aoStrength     = 0.28;
            s.aoGyral        = 0.06;
            s.ka             = 0.50;
            s.kd             = 0.80;
            s.ks             = 0.08;
            s.specExp        = 10;
            s.keyIntensity   = 0.90;
            s.fillIntensity  = 0.35;
            s.rimIntensity   = 0.00;
            s.heroView       = false;
            s.supersample    = 1;
            s.grayCortex     = false;
            s.baseGray       = [0.80 0.80 0.82];
        end

        function s = showcase()
        % SHOWCASE Polished matcap cortex for marketing/keynote renders
            s = struct();
            s.name           = 'showcase';
            s.lighting       = 'gouraud';
            s.useMatcap      = true;
            s.matcapMaterial = 'clay';
            s.aoStrength     = 0.38;
            s.aoGyral        = 0.10;
            s.ka             = 0.42;
            s.kd             = 0.86;
            s.ks             = 0.18;
            s.specExp        = 14;
            s.keyIntensity   = 1.00;
            s.fillIntensity  = 0.40;
            s.rimIntensity   = 0.18;
            s.heroView       = true;
            s.supersample    = 2;
            s.grayCortex     = true;
            s.baseGray       = [0.82 0.82 0.84];
        end

        function s = fillDefaults(s)
        % FILLDEFAULTS Backfill any missing fields from the publication preset
            d = pf2_base.plot.RenderStyle.publication();
            fn = fieldnames(d);
            for i = 1:numel(fn)
                if ~isfield(s, fn{i}) || isempty(s.(fn{i}))
                    s.(fn{i}) = d.(fn{i});
                end
            end
        end

    end
end
