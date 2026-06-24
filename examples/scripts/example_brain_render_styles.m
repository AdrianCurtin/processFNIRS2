%% example_brain_render_styles.m
% High-quality 3D cortical rendering: showcase vs publication styles, matcap
% materials, ambient occlusion, colormaps, and the interactive explorer.
%
% The 3D surface renderer (pf2.probe.plot.interpolateValues3D and everything
% built on it: pf2.probe.plot.topo 'View','3d', pf2.probe.project.*) supports
% a 'Style' preset that controls how the cortex is shaded:
%
%   'showcase'    (default) - procedural matcap shading, a neutral-gray cortex
%                 so activation pops, sulcal ambient occlusion, an elevated 3/4
%                 "hero" view and supersampled export. The polished look
%                 (inspired by MRIcroGL / Surfice surface renders).
%   'publication' - smooth Gouraud matte cortex, gentle ambient occlusion, a
%                 data-facing view; the conservative, understated look.
%
% See also: pf2.probe.plot.interpolateValues3D, pf2.probe.plot.Explore3D,
%           pf2_base.plot.RenderStyle, pf2_base.plot.brainColormap

%% Data
data = pf2.import.sampleData.fNIR2000();
proc = processFNIRS2(data);
vals = mean(proc.HbO, 1, 'omitnan');     % [1 x C] time-mean HbO

%% 1. The default showcase render vs the conservative publication render
figure('Color','w','Position',[80 80 1000 460]);
subplot(1,2,1);
pf2.probe.plot.interpolateValues3D(vals, proc, 'ax', gca, ...
    'Style', 'showcase', 'ChannelLabels', false, 'SDLabels', false, 'ShowAxes', false);
title('Style = showcase (default)');
subplot(1,2,2);
pf2.probe.plot.interpolateValues3D(vals, proc, 'ax', gca, ...
    'Style', 'publication', 'ChannelLabels', false, 'SDLabels', false, 'ShowAxes', false);
title('Style = publication');

%% 2. Same showcase look straight from topo (View 3d inherits the default)
pf2.probe.plot.topo(proc, 'HbO', 'View', '3d');     % showcase by default

%% 3. Matcap materials (override individual style fields via a struct)
materials = {'clay','porcelain','glossy','pewter'};
figure('Color','w','Position',[80 80 1000 720]);
for i = 1:numel(materials)
    sty = pf2_base.plot.RenderStyle.get('showcase');
    sty.matcapMaterial = materials{i};
    subplot(2,2,i);
    pf2.probe.plot.interpolateValues3D(vals, proc, 'ax', gca, 'Style', sty, ...
        'ChannelLabels', false, 'SDLabels', false, 'ShowAxes', false, 'showColorbar', false);
    title(['matcap: ' materials{i}]);
end

%% 4. Tune ambient occlusion strength (sulcal darkening)
sty = pf2_base.plot.RenderStyle.get('showcase');
sty.aoStrength = 0.6;                 % stronger crevice shading (0..0.8)
figure('Color','w');
pf2.probe.plot.interpolateValues3D(vals, proc, 'ax', gca, 'Style', sty, ...
    'ChannelLabels', false, 'SDLabels', false, 'ShowAxes', false);
title('Ambient occlusion strength = 0.6');

%% 5. Colormaps: MRIcroGL LUTs + perceptually-uniform / CVD-safe defaults
% Colormap names now resolve through pf2_base.plot.brainColormap, so MRIcroGL
% maps ('actc','warm','cool','blue2red') and CVD-safe maps ('rdbu','viridis',
% 'cividis') work directly via the 'cmap' option.
cmaps = {'rdbu','viridis','actc','hot'};
figure('Color','w','Position',[80 80 1000 720]);
for i = 1:numel(cmaps)
    subplot(2,2,i);
    pf2.probe.plot.interpolateValues3D(vals, proc, 'ax', gca, 'cmap', cmaps{i}, ...
        'ChannelLabels', false, 'SDLabels', false, 'ShowAxes', false, 'showColorbar', false);
    title(['cmap: ' cmaps{i}]);
end

%% 6. Headless, supersampled save (showcase uses 2x supersampling on export)
outPng = fullfile(tempdir, 'brain_showcase.png');   % write to tempdir, not the repo
pf2.probe.plot.interpolateValues3D(vals, proc, ...
    'Style', 'showcase', 'ChannelLabels', false, 'SDLabels', false, ...
    'ShowAxes', false, 'savePath', outPng);
fprintf('Saved %s\n', outPng);

%% 7. Interactive explorer: tweak every option live and copy the command
% Opens a window with controls for style, matcap, AO, view, colormap,
% interpolation, biomarker, time point and labels; shows the equivalent
% generating command for copy-paste. (Interactive; skip under -batch.)
if usejava('desktop')
    pf2.probe.plot.Explore3D(proc);
end
