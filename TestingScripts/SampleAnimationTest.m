

figure(10);
ax=gca();

fnir1200 = processFNIRS2.Import.SampleData.fNIR1200();

optData=rand(1,16);
optDataFreq=rand(1,16);

for i=1:100
    processFNIRS2.Probe.Plot.InterpolateValues3D(sin(((i*optDataFreq)/20*pi)), fnir1200,'ax',ax, 'initCamPosition', 'front', 'ChannelLabels', false, 'SDLabels', false,'minVal',0.4,'maxVal',1,'UseHighRes',false,'showColorBar',true);
    pause(0.00001);
end