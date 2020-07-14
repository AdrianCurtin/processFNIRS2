%% Interpolate Types
% Faux data with 'linear' and 'interpolate' modes
subplot(1, 2, 1);
pf2_base.loadDeviceCfg('fNIR_Devices_fNIR1000.cfg');
fnirData = [1, 2, 1, 2, 2, 3, 3, 3, 4, 3, 4, 2, 3, 3, 1, 1];
processFNIRS2.Data.Plot.InterpolateValues3D(fnirData, 'ChannelLabels', false, 'SDLabels', false);
subplot(1, 2, 2);
processFNIRS2.Data.Plot.InterpolateValues3D(fnirData, 'ChannelLabels', false, 'SDLabels', false, 'InterpolateType', 'linear');


%% Multiple Probes
hitachi35 = processFNIRS2.Import.SampleData.Hitachi_ETG4000_3x5();
fnir1200 = processFNIRS2.Import.SampleData.fNIR1200();
processFNIRS2.Data.Plot.InterpolateValues3D({1:16, 1:22}, {fnir1200, hitachi35},'SDLabels', false);

%% Show 10-20 data
pf2_base.loadDeviceCfg('Hitachi_ETG4000_3x5.cfg');
processFNIRS2.Data.Plot.InterpolateValues3D(1:22, 'I1020_labels', {'T7'});
%% Change sphere label colors
pf2_base.loadDeviceCfg('fNIR_Devices_fNIR1000.cfg');
processFNIRS2.Data.Plot.InterpolateValues3D(1:16, 'labelspherecolors', ["k", "b"], 'labelfontcolor', 'g');
%% Change brain colors
pf2_base.loadDeviceCfg('fNIR_Devices_fNIR1000.cfg');
processFNIRS2.Data.Plot.InterpolateValues3D(1:16, 'brainColor', [1 1 1], 'brainLineColor', 'k', 'useHighRes', false);
%% Colorbar examples
pf2_base.loadDeviceCfg('fNIR_Devices_fNIR1000.cfg');
processFNIRS2.Data.Plot.InterpolateValues3D(-7:8, 'minVal', [-2, 2], 'maxVal', 6, 'cmap', 'autumn', 'cmap_lower', 'winter', 'ChannelLabels', false, 'SDLabels', false);

%% Log scale
pf2_base.loadDeviceCfg('Hitachi_ETG4000_3x5.cfg');
data = [ones(1, 9) 1e-6 1e-5 1e-2 ones(1, 10)];
processFNIRS2.Data.Plot.InterpolateValues3D(data, 'logScale', true, 'interpolateType', 'quadratic','minVal', 1e-8, 'maxVal', 0.9);

%% Buffer distance
subplot(1, 2, 1);
pf2_base.loadDeviceCfg('fNIR_Devices_fNIR1000.cfg');
fnirData = [1, 2, 1, 2, 2, 3, 3, 3, 4, 3, 4, 2, 3, 3, 1, 1];
processFNIRS2.Data.Plot.InterpolateValues3D(fnirData, 'ChannelLabels', false, 'SDLabels', false, 'InterpolateType', 'linear', 'bufferDistance', 25, 'showColorbar', false);
subplot(1, 2, 2);
processFNIRS2.Data.Plot.InterpolateValues3D(fnirData, 'ChannelLabels', false, 'SDLabels', false, 'InterpolateType', 'linear', 'bufferDistance', 50, 'showColorbar', false);

%% Initial Camera Position
hitachi35 = processFNIRS2.Import.SampleData.Hitachi_ETG4000_3x5();
fnir1200 = processFNIRS2.Import.SampleData.fNIR1200();
subplot(2, 1, 1);
processFNIRS2.Data.Plot.InterpolateValues3D({1:16, 1:22}, {fnir1200, hitachi35}, 'initCamPosition', 'front', 'ChannelLabels', false, 'SDLabels', false);
subplot(2, 1, 2);
processFNIRS2.Data.Plot.InterpolateValues3D({1:16, 1:22}, {fnir1200, hitachi35}, 'initCamPosition', 'left', 'ChannelLabels', false, 'SDLabels', false);


%% Animation test


figure(10);
ax=gca();

fnir1200 = processFNIRS2.Import.SampleData.fNIR1200();

optData=[(1:16)/16];

for i=1:100
    processFNIRS2.Data.Plot.InterpolateValues3D(optData.*sin(optData*i/20*pi), fnir1200,'ax',ax, 'initCamPosition', 'front', 'ChannelLabels', false, 'SDLabels', false,'minVal',0.4,'maxVal',1);
    %pause(0.05);
end