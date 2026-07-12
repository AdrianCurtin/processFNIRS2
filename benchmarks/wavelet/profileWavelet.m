function profileWavelet(varargin)
% PROFILEWAVELET Run MATLAB profiler on pf2_MotionCorrectWavelet
%
% Runs the MATLAB profiler to get exact line-level timing for the wavelet
% motion correction pipeline. Generates an HTML report.
%
% Syntax:
%   profileWavelet()
%   profileWavelet('Samples', 6000, 'Channels', 18)
%   profileWavelet('ReportDir', 'benchmarks/wavelet/profile_report')
%
% Inputs (name-value):
%   Samples   - Signal length (default: 6000)
%   Channels  - Number of channels (default: 18)
%   ReportDir - Directory for HTML profile report (default: 'benchmarks/wavelet/profile_report')
%
% Example:
%   profileWavelet();  % Opens profile viewer after completion
%
% See also: benchmarkWavelet, profile, pf2_MotionCorrectWavelet

    p = inputParser;
    addParameter(p, 'Samples', 6000, @isscalar);
    addParameter(p, 'Channels', 18, @isscalar);
    addParameter(p, 'ReportDir', fullfile('benchmarks', 'wavelet', 'profile_report'), @ischar);
    parse(p, varargin{:});
    opts = p.Results;

    fprintf('\n');
    fprintf('========================================================\n');
    fprintf('  WAVELET PROFILING\n');
    fprintf('  %d samples x %d channels\n', opts.Samples, opts.Channels);
    fprintf('========================================================\n\n');

    % Initialize WaveLab
    global WAVELABPATH
    if isempty(WAVELABPATH)
        pf2_base.toolboxes.setup_wavelab();
    end

    % Generate test data
    rng(42);
    od = generateOD(opts.Samples, opts.Channels);

    % Warmup (compile JIT, populate caches)
    fprintf('Warmup run... ');
    pf2_MotionCorrectWavelet(od(:, 1:2), 1.5, 1, 'db2', 'none');
    fprintf('done.\n');

    % Profile
    fprintf('Profiling pf2_MotionCorrectWavelet...\n');
    profile on;
    pf2_MotionCorrectWavelet(od, 1.5, 1, 'db2', 'none');
    profile off;

    % Save report
    fprintf('Saving profile report to: %s\n', opts.ReportDir);
    profsave(profile('info'), opts.ReportDir);

    % Print top functions by time
    stats = profile('info');
    funcTable = stats.FunctionTable;
    [~, sortIdx] = sort([funcTable.TotalTime], 'descend');

    fprintf('\n  Top 15 functions by total time:\n');
    fprintf('  %-45s  %10s  %8s\n', 'Function', 'Time(s)', 'Calls');
    fprintf('  %s\n', repmat('-', 1, 68));
    for k = 1:min(15, length(sortIdx))
        f = funcTable(sortIdx(k));
        fprintf('  %-45s  %10.4f  %8d\n', truncStr(f.FunctionName, 45), f.TotalTime, f.NumCalls);
    end
    fprintf('\n');

    % Key insight extraction
    fprintf('  Key observations:\n');
    dwtCalls = findCalls(funcTable, 'dwt');
    idwtCalls = findCalls(funcTable, 'idwt');
    if ~isempty(dwtCalls)
        fprintf('    dwt:  %d calls, %.4f s total\n', dwtCalls.NumCalls, dwtCalls.TotalTime);
    end
    if ~isempty(idwtCalls)
        fprintf('    idwt: %d calls, %.4f s total\n', idwtCalls.NumCalls, idwtCalls.TotalTime);
    end
    fprintf('\n');
    fprintf('  Profile viewer: open %s/file0.html\n\n', opts.ReportDir);
end


function od = generateOD(nSamples, nCh)
    fs = 100;
    t = (0:nSamples-1)' / fs;
    od = 0.3 + 0.01 * randn(nSamples, nCh);
    for ch = 1:nCh
        od(:, ch) = od(:, ch) + 0.005 * sin(2*pi*1.0*t + 2*pi*rand);
    end
    nArt = max(2, round(nSamples / 2000));
    for a = 1:nArt
        ch = randi(nCh);
        idx = randi(nSamples);
        w = randi([5, 30]);
        amp = 0.05 + 0.1 * rand;
        r = max(1, idx-w):min(nSamples, idx+w);
        od(r, ch) = od(r, ch) + amp * exp(-((r - idx).^2) / (2*(w/3)^2))';
    end
end


function s = truncStr(str, maxLen)
    if length(str) > maxLen
        s = [str(1:maxLen-3) '...'];
    else
        s = str;
    end
end


function entry = findCalls(funcTable, name)
    entry = [];
    for k = 1:length(funcTable)
        if contains(funcTable(k).FunctionName, name)
            entry = funcTable(k);
            return;
        end
    end
end
