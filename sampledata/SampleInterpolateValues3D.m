%% Interpolate Types
% Faux data with 'linear' and 'interpolate' modes
subplot(1, 2, 1);
pf2_base.loadDeviceCfg('fNIR_Devices_fNIR1000.cfg');
fnirData = [1, 2, 1, 2, 2, 3, 3, 3, 4, 3, 4, 2, 3, 3, 1, 1];
processFNIRS2.Data.Plot.InterpolateValues3D(fnirData, 'ChannelLabels', false, 'SDLabels', false);
subplot(1, 2, 2);
processFNIRS2.Data.Plot.InterpolateValues3D(fnirData, 'ChannelLabels', false, 'SDLabels', false, 'InterpolateType', 'linear');


%% Multiple Probes
% Combine sample data on two different probes on the same graph
subplot(1,1,1)
hitachi35 = processFNIRS2.Import.SampleData.Hitachi_ETG4000_3x5();
fnir1200 = processFNIRS2.Import.SampleData.fNIR1200();
processFNIRS2.Data.Plot.InterpolateValues3D({1:16, 1:22}, {fnir1200, hitachi35},'SDLabels', true,'showReference',false,'bufferDistance', 20,'cmap','cool');

%% Show 10-20 data
pf2_base.loadDeviceCfg('Hitachi_ETG4000_3x5.cfg');
processFNIRS2.Data.Plot.InterpolateValues3D(1:22, 'I1020_labels', {'T7','CPz'});
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

%% Colorbar title
pf2_base.loadDeviceCfg('Hitachi_ETG4000_3x5.cfg');
processFNIRS2.Data.Plot.InterpolateValues3D(1:22, 'interpolateType', 'quadratic', 'colorbarStr', "HbO");

%% EEG Probe plotting
%processFNIRS2.Data.Plot.InterpolateValues3D(1:4, 'useEEG', true, 'I1020_labels', {'TP7', 'O1', 'Oz', 'O2'});
%fnir1200 = processFNIRS2.Import.SampleData.fNIR1200();
data = [-2.7, -2.8, -2.6,...
        -3.5, -2.4, -1.8, -2.2, -1.7, -1.6, -1.1, -1.8, -1.9,...
        -1.7, -1.0, -0.8, -0.7, -0.5, -0.4, -1.2,...
        -3.0, -1.0,  0.3,  0.8,  0.8,  1.2,  1.0,  0.4, -1.0,...
        -1.4,  0.2,  1.3,  2.5,  3.0,  2.8,  2.4,  2.0,  0.0,...
         0.0,  0.9,  2.3,  2.5,  3.0,  2.8,  3.4,  3.0,  1.6,...
         2.4,  2.8,  1.8,  2.8,  2.2,  1.5, -1.0...
         1.0,  0.0,  1.0];
labels = {'Fp1', 'Fpz', 'Fp2', 'F7', 'F5', 'F3', 'F1', 'Fz', 'F2', 'F4', 'F6', 'F8',...
    'FC5', 'FC3', 'FC1', 'FCz', 'FC2', 'FC4', 'FC6', 'T7', 'C5', 'C3', 'C1', 'Cz',...
    'C2', 'C4', 'C6', 'T8', 'TP7', 'CP5', 'CP3', 'CP1', 'CPz', 'CP2', 'CP4', 'CP6', ...
    'TP8', 'P7', 'P5', 'P3', 'P1', 'Pz', 'P2', 'P4', 'P6', 'P8', 'PO7', 'PO5', ...
    'PO3', 'PO1', 'POz', 'PO2', 'PO4', 'PO6', 'PO8', 'O1', 'Oz', 'O2'};
processFNIRS2.Data.Plot.InterpolateValues3D(data, 'useEEG', true, 'I1020_labels', labels, 'cmap', 'jet', 'interpolateType', 'linear', 'bufferDistance', 25);

%% Plot optical pathways for fNIR
pf2_base.loadDeviceCfg('fNIR_Devices_fNIR1000.cfg');
processFNIRS2.Data.Plot.InterpolateValues3D(1:16, 'showScattering', true, "brainAlpha", 0.25);

%% Plot optical pathways for Hitachi
pf2_base.loadDeviceCfg('Hitachi_ETG4000_3x5.cfg');
processFNIRS2.Data.Plot.InterpolateValues3D(1:22, 'showScattering', true, "brainAlpha", 0.7, "scatteringFactor", 0.5);

%% Animation test


figure(10);
ax=gca();

fnir1200 = pf2.Import.SampleData.fNIR1200();

optData=[(1:16)/16];

for i=1:50
    
    pf2.Data.Plot.InterpolateValues3D(optData.*sin(optData*i/20*pi), fnir1200,'ax',ax, 'initCamPosition', 'front', 'ChannelLabels', true, 'SDLabels', false,'minVal',0.2,'maxVal',1);
    pause(0.0001);
end