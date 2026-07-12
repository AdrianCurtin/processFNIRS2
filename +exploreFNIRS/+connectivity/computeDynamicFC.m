function result = computeDynamicFC(data, varargin)
% COMPUTEDYNAMICFC Time-varying functional connectivity via sliding windows
%
% Computes a sequence of connectivity matrices over a sliding time window,
% capturing how inter-channel coupling evolves over time.
%
% Syntax:
%   result = exploreFNIRS.connectivity.computeDynamicFC(data)
%   result = exploreFNIRS.connectivity.computeDynamicFC(data, 'WindowSize', 20)
%   result = exploreFNIRS.connectivity.computeDynamicFC(data, 'Method', 'spearman')
%
% Inputs:
%   data - Processed fNIRS struct with .HbO, .HbR, .time, .fs, .fchMask
%
% Name-Value Parameters:
%   Method       - Coupling method: 'pearson' (default), 'spearman', 'xcorr',
%                  'coherence', 'wcoherence', 'granger', 'transferentropy'
%   Biomarker    - 'HbO' (default), 'HbR', 'HbTotal', 'HbDiff', 'CBSI'
%   WindowSize   - Window duration in seconds (default: 30)
%   WindowStep   - Step size in seconds (default: 5)
%   Channels     - Channel indices to include (default: all good channels)
%   CouplingArgs - Extra args passed to coupling function (default: {})
%   Accelerate   - Acceleration mode passed to computeMatrix: 'auto' (default),
%                  'gpu', 'parfor', 'none'
%
% Outputs:
%   result - Struct with fields:
%     .matrices    - [C x C x W] connectivity matrices per window
%     .windowTimes - [W x 1] center time of each window (seconds)
%     .method      - Coupling method name
%     .biomarker   - Biomarker used
%     .labels      - Cell array of channel labels
%     .channels    - Channel indices used
%     .windowSize  - Window duration in seconds
%     .windowStep  - Step size in seconds
%
% Example:
%   data = pf2.import.sampleData.fNIR2000();
%   processed = processFNIRS2(data);
%   dfc = exploreFNIRS.connectivity.computeDynamicFC(processed, ...
%       'WindowSize', 20, 'WindowStep', 5);
%   imagesc(dfc.matrices(:,:,1));  % First window
%
% References:
%   Allen, E. A., Damaraju, E., Plis, S. M., Erhardt, E. B., Eichele, T.
%   & Calhoun, V. D. (2014). Tracking whole-brain connectivity dynamics in
%   the resting state. Cerebral Cortex, 24(3), 663-676.
%   DOI: 10.1093/cercor/bhs352
%
%   Hutchison, R. M., Womelsdorf, T., Allen, E. A., et al. (2013). Dynamic
%   functional connectivity: promise, issues, and interpretations.
%   NeuroImage, 80, 360-378. DOI: 10.1016/j.neuroimage.2013.05.079
%
% See also: exploreFNIRS.connectivity.computeMatrix,
%   exploreFNIRS.connectivity.detectStates,
%   exploreFNIRS.connectivity.plotDynamicFC

    p = inputParser;
    addRequired(p, 'data', @isstruct);
    addParameter(p, 'Method', 'pearson', @ischar);
    addParameter(p, 'Biomarker', 'HbO', @ischar);
    addParameter(p, 'WindowSize', 30, @(v) isnumeric(v) && isscalar(v) && v > 0);
    addParameter(p, 'WindowStep', 5, @(v) isnumeric(v) && isscalar(v) && v > 0);
    addParameter(p, 'Channels', [], @isnumeric);
    addParameter(p, 'CouplingArgs', {}, @iscell);
    addParameter(p, 'Accelerate', 'auto', @(x) ischar(x) && ismember(lower(x), {'auto','gpu','parfor','none'}));
    parse(p, data, varargin{:});
    opts = p.Results;

    timeVec = data.time(:);
    tStart = timeVec(1);
    tEnd = timeVec(end);
    duration = tEnd - tStart;

    if opts.WindowSize > duration
        error('exploreFNIRS:connectivity:computeDynamicFC', ...
            'WindowSize (%.1f s) exceeds data duration (%.1f s)', ...
            opts.WindowSize, duration);
    end

    % Compute window start times
    winStarts = tStart:opts.WindowStep:(tEnd - opts.WindowSize);
    nWin = length(winStarts);

    if nWin < 1
        error('exploreFNIRS:connectivity:computeDynamicFC', ...
            'No complete windows fit in the data. Reduce WindowSize or WindowStep.');
    end

    % Compute first window to determine matrix size
    firstResult = exploreFNIRS.connectivity.computeMatrix(data, ...
        'Method', opts.Method, 'Biomarker', opts.Biomarker, ...
        'Channels', opts.Channels, ...
        'TimeWindow', [winStarts(1), winStarts(1) + opts.WindowSize], ...
        'CouplingArgs', opts.CouplingArgs, ...
        'Accelerate', opts.Accelerate);

    nCh = size(firstResult.matrix, 1);
    matrices = nan(nCh, nCh, nWin);
    matrices(:, :, 1) = firstResult.matrix;

    windowTimes = zeros(nWin, 1);
    windowTimes(1) = winStarts(1) + opts.WindowSize / 2;

    % Compute remaining windows
    for w = 2:nWin
        tWin = [winStarts(w), winStarts(w) + opts.WindowSize];
        res = exploreFNIRS.connectivity.computeMatrix(data, ...
            'Method', opts.Method, 'Biomarker', opts.Biomarker, ...
            'Channels', opts.Channels, ...
            'TimeWindow', tWin, ...
            'CouplingArgs', opts.CouplingArgs, ...
            'Accelerate', opts.Accelerate);
        matrices(:, :, w) = res.matrix;
        windowTimes(w) = winStarts(w) + opts.WindowSize / 2;
    end

    result.matrices = matrices;
    result.windowTimes = windowTimes;
    result.method = opts.Method;
    result.biomarker = opts.Biomarker;
    result.labels = firstResult.labels;
    result.channels = firstResult.channels;
    result.windowSize = opts.WindowSize;
    result.windowStep = opts.WindowStep;
end
