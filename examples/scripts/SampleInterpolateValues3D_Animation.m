%% SampleInterpolateValues3D_Animation
% Demonstrates animated 3D brain visualization using the 'animated' flag.
% The animated mode caches distance computations between frames for speed.
%
% See also: SampleInterpolateValues3D

%% Animated sinusoidal activity
% Simulates oscillating channel data rendered in real time.
% The 'animated' flag skips re-drawing the brain mesh and labels after
% the first frame, only updating vertex colors each iteration.

figure(10);
ax = gca();

fnir1200 = pf2.import.sampleData.fNIR1200();

% Random amplitudes and frequencies per channel
optData = rand(1, 16) * 10 - 4;
fData = rand(1, 16) * 2 + 10;

for i = 1:50
    pf2.probe.plot.interpolateValues3D( ...
        optData .* sin(fData * i/100 * pi + fData), fnir1200, ...
        'ax', ax, ...
        'useHighRes', true, ...
        'initCamPosition', 'front', ...
        'ChannelLabels', true, 'SDLabels', false, ...
        'minVal', 0.2, 'maxVal', max(optData), ...
        'animated', true);
    pause(0.0001);
end
