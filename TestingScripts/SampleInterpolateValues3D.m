%% Plot just device fNIR1000
pf2_base.loadDeviceCfg('fNIR_Devices_fNIR1000.cfg');
pf2.Data.Plot.InterpolateValues3D([],{'fNIR_Devices_fNIR1000.cfg'});

%% Plot just device 3x5 Hitachi
%% Show 10-20 data
pf2_base.loadDeviceCfg('Hitachi_ETG4000_3x5.cfg');
pf2.Data.Plot.InterpolateValues3D([],{'Hitachi_ETG4000_3x5.cfg'});

%% Interpolate Types
% Faux data with 'linear' and 'interpolate' modes
subplot(1, 2, 1);
pf2_base.loadDeviceCfg('fNIR_Devices_fNIR1000.cfg');
fnirData = [1, 2, 1, 2, 2, 3, 3, 3, 4, 3, 4, 2, 3, 3, 1, 1];
pf2.Data.Plot.InterpolateValues3D(fnirData, 'ChannelLabels', false, 'SDLabels', false);
title('Linear');
subplot(1, 2, 2);
pf2.Data.Plot.InterpolateValues3D(fnirData, 'ChannelLabels', false, 'SDLabels', false, 'InterpolateType', 'linear');
title('Interpolate');

%% Multiple Probes
% Combine sample data on two different probes on the same graph
subplot(1,1,1)
hitachi35 = pf2.Import.SampleData.Hitachi_ETG4000_3x5();
fnir1200 = pf2.Import.SampleData.fNIR1200();
pf2.Data.Plot.InterpolateValues3D({1:16, 1:22}, {fnir1200, hitachi35},'SDLabels', true,'showReference',false,'bufferDistance', 20,'cmap','cool');

%% Show 10-20 data
pf2_base.loadDeviceCfg('Hitachi_ETG4000_3x5.cfg');
pf2.Data.Plot.InterpolateValues3D(1:22, 'I1020_labels', {'T7','CPz'});
%% Change sphere label colors
pf2_base.loadDeviceCfg('fNIR_Devices_fNIR1000.cfg');
pf2.Data.Plot.InterpolateValues3D(1:16, 'labelspherecolors', ["k", "b"], 'labelfontcolor', 'g');
%% Change brain colors
pf2_base.loadDeviceCfg('fNIR_Devices_fNIR1000.cfg');
pf2.Data.Plot.InterpolateValues3D(1:16, 'brainColor', [1 1 1], 'brainLineColor', 'k', 'useHighRes', false);
%% Colorbar examples
pf2_base.loadDeviceCfg('fNIR_Devices_fNIR1000.cfg');
pf2.Data.Plot.InterpolateValues3D(-7:8, 'minVal', [-2, 2], 'maxVal', 6, 'cmap', 'autumn', 'cmap_lower', 'winter', 'ChannelLabels', false, 'SDLabels', false);

%% Log scale
pf2_base.loadDeviceCfg('Hitachi_ETG4000_3x5.cfg');
data = [ones(1, 9) 1e-6 1e-5 1e-2 ones(1, 10)];
pf2.Data.Plot.InterpolateValues3D(data, 'logScale', true, 'interpolateType', 'quadratic','minVal', 1e-8, 'maxVal', 0.9);

%% Buffer distance
subplot(1, 2, 1);
pf2_base.loadDeviceCfg('fNIR_Devices_fNIR1000.cfg');
fnirData = [1, 2, 1, 2, 2, 3, 3, 3, 4, 3, 4, 2, 3, 3, 1, 1];
pf2.Data.Plot.InterpolateValues3D(fnirData, 'ChannelLabels', false, 'SDLabels', false, 'InterpolateType', 'linear', 'bufferDistance', 25, 'showColorbar', false);
title('DrawBuffer 25');
subplot(1, 2, 2);
pf2.Data.Plot.InterpolateValues3D(fnirData, 'ChannelLabels', false, 'SDLabels', false, 'InterpolateType', 'linear', 'bufferDistance', 50, 'showColorbar', false);
title('DrawBuffer 50');
%% Initial Camera Position
hitachi35 = pf2.Import.SampleData.Hitachi_ETG4000_3x5();
fnir1200 = pf2.Import.SampleData.fNIR1200();
subplot(2, 1, 1);
pf2.Data.Plot.InterpolateValues3D({1:16, 1:22}, {fnir1200, hitachi35}, 'initCamPosition', 'front', 'ChannelLabels', false, 'SDLabels', false);
title('Front');
subplot(2, 1, 2);
pf2.Data.Plot.InterpolateValues3D({1:16, 1:22}, {fnir1200, hitachi35}, 'initCamPosition', 'left', 'ChannelLabels', false, 'SDLabels', false);
title('Left');
%% Colorbar title
pf2_base.loadDeviceCfg('Hitachi_ETG4000_3x5.cfg');
pf2.Data.Plot.InterpolateValues3D(1:22, 'interpolateType', 'quadratic', 'colorbarStr', "HbO");

%% EEG Probe plotting
%pf2.Data.Plot.InterpolateValues3D(1:4, 'useEEG', true, 'I1020_labels', {'TP7', 'O1', 'Oz', 'O2'});
%fnir1200 = pf2.Import.SampleData.fNIR1200();
data = [-2.7, -2.8, -2.6,...
        -3.5, -2.4, -1.8, -2.2, -1.7, -1.6, -1.1, -1.8, -1.9,...
        -1.7, -1.0, -0.8, -0.7, -0.5, -0.4, -1.2,...
        -3.0, -1.0,  0.3,  0.8,  0.8,  1.2,  1.0,  0.4, -1.0,...
        -1.4,  0.2,  1.3,  2.5,  3.0,  2.8,  2.4,  2.0,  0.0,...
         0.0,  0.9,  2.3,  2.5,  3.0,  2.8,  3.4,  3.0,  1.6,...
         2.4,  1.8,  2.2,  1.5, -1.0...
         1.0,  0.0,  1.0];
labels = {'Fp1', 'Fpz', 'Fp2',...
    'F7', 'F5', 'F3', 'F1', 'Fz', 'F2', 'F4', 'F6', 'F8',...
    'FC5', 'FC3', 'FC1', 'FCz', 'FC2', 'FC4', 'FC6', ...
    'T7', 'C5', 'C3', 'C1', 'Cz', 'C2', 'C4', 'C6', 'T8',...
    'TP7', 'CP5', 'CP3', 'CP1', 'CPz', 'CP2', 'CP4', 'CP6', 'TP8',...
    'P7', 'P5', 'P3', 'P1', 'Pz', 'P2', 'P4', 'P6', 'P8', ...
    'PO7', 'PO3', 'POz', 'PO4', 'PO8', ...
    'O1', 'Oz', 'O2'};
pf2.Data.Plot.InterpolateValues3D(data, 'useEEG', true, 'I1020_labels', labels, 'cmap', 'jet', 'interpolateType', 'linear', 'bufferDistance', 25);

%% Plot FNIRS device over EEG
fnir1200 = pf2.Import.SampleData.fNIR1200();
pf2.Data.Plot.InterpolateValues3D(1:7, fnir1200, 'I1020_labels', {'C5', 'C3', 'C1', 'Cz', 'C2', 'C4', 'C6'}, 'useEEG', true, 'SDLabels', true)

%% Plot optical pathways for fNIR
pf2_base.loadDeviceCfg('fNIR_Devices_fNIR1000.cfg');
pf2.Data.Plot.InterpolateValues3D(1:16, 'showScattering', true, "brainAlpha", 0.25);

%% Plot optical pathways for Hitachi
pf2_base.loadDeviceCfg('Hitachi_ETG4000_3x5.cfg');
pf2.Data.Plot.InterpolateValues3D(1:22, 'showScattering', true, "brainAlpha", 0.7, "scatteringFactor", 0.5);


%% Plot optical pathways for NIRX and FNIRS 
pf2_base.loadDeviceCfg('NIRX_Sport_16x16_parietal.cfg');
pf2.Data.Plot.InterpolateValues3D({([1:16]*5/16+3)*-1, [[1:48]*5/48]+3}, {'fNIR_Devices_fNIR1000', 'NIRX_Sport_16x16_parietal'}, 'initCamPosition', 'left', 'ChannelLabels', true, 'SDLabels', true,'showScattering', true,'cmap', 'autumn', 'cmap_lower', 'winter', 'minVal', [-1,1],"brainAlpha", 0.85,'brainColor', [1 1 1]*0.8);

%% Plot optical pathways for NIRX Only
pf2_base.loadDeviceCfg('NIRX_Sport_16x16_parietal.cfg');
pf2.Data.Plot.InterpolateValues3D({1:48}, {'NIRX_Sport_16x16_parietal'}, 'initCamPosition', 'left', 'ChannelLabels', true, 'SDLabels', true,'showScattering', true);
%% Animation test


figure(10);
ax=gca();

fnir1200 = pf2.Import.SampleData.fNIR1200();

optData=rand(1,16)*10-4;

fData=rand(1,16)*2+10;

for i=1:50
    
    pf2.Data.Plot.InterpolateValues3D(optData.*sin(fData*i/100*pi+fData), fnir1200,'ax',ax,'useHighRes', true, 'initCamPosition', 'front', 'ChannelLabels', true, 'SDLabels', false,'minVal',0.2,'maxVal',max(optData),'animated',true);
    pause(0.0001);
end