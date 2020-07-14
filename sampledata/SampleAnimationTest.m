

figure(10);
ax=gca();

fnir1200 = processFNIRS2.Import.SampleData.fNIR1200();

optData=[(1:16)/16];

for i=1:100
    processFNIRS2.Data.Plot.InterpolateValues3D(optData.*sin(optData*i/20*pi), fnir1200,'ax',ax, 'initCamPosition', 'front', 'ChannelLabels', false, 'SDLabels', false,'minVal',0.4,'maxVal',1);
    %pause(0.05);
end