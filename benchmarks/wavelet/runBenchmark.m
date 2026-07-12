% RUNBENCHMARK Launcher for all wavelet benchmarks
%
% Runs the full wavelet benchmark suite: method comparison, scaling,
% WaveLab internals, GPU paths, and alternative implementations.
%
% Usage from CLI:
%   matlab -batch "run('benchmarks/wavelet/runBenchmark.m')"
%
% Or from MATLAB command window:
%   run('benchmarks/wavelet/runBenchmark.m')
%
% Individual benchmarks can also be run standalone:
%   benchmarkWavelet()           % Overall method comparison & profiling
%   benchmarkWaveLab()           % WaveLab850 internals vs Wavelet Toolbox
%   benchmarkAlternatives()      % DWT algorithm comparison (single channel)
%   benchmarkGPU()               % GPU acceleration paths
%   profileWavelet()             % MATLAB profiler (line-level timing)

cd(fileparts(fileparts(fileparts(mfilename('fullpath')))));
addpath(genpath(pwd));

outDir = fullfile('benchmarks', 'wavelet');

fprintf('==========================================================\n');
fprintf('  WAVELET BENCHMARK SUITE\n');
fprintf('  %s\n', datestr(now));
fprintf('==========================================================\n\n');

% --- 1. Core method comparison + scaling ---
fprintf('>>> Running benchmarkWavelet...\n');
results.core = benchmarkWavelet( ...
    'Reps', 3, ...
    'SavePath', fullfile(outDir, 'results_core.mat'), ...
    'Plot', false);

% --- 2. WaveLab internals profiling ---
fprintf('>>> Running benchmarkWaveLab...\n');
results.wavelab = benchmarkWaveLab('Reps', 5);

% --- 3. Algorithm alternatives ---
fprintf('>>> Running benchmarkAlternatives...\n');
results.alternatives = benchmarkAlternatives('Reps', 5);

% --- 4. GPU paths ---
fprintf('>>> Running benchmarkGPU...\n');
results.gpu = benchmarkGPU('Reps', 3);

% Save combined results
save(fullfile(outDir, 'results_all.mat'), 'results');
fprintf('\n==========================================================\n');
fprintf('  ALL BENCHMARKS COMPLETE\n');
fprintf('  Results: %s\n', fullfile(outDir, 'results_all.mat'));
fprintf('==========================================================\n');
