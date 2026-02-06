function result = computeMatrix(data, varargin)
% COMPUTEMATRIX Compute channel-to-channel or ROI-to-ROI connectivity matrix
%
% Calculates pairwise coupling between all channels (or ROIs) of a single
% fNIRS dataset, producing a symmetric connectivity matrix.
%
% Syntax:
%   result = exploreFNIRS.connectivity.computeMatrix(data)
%   result = exploreFNIRS.connectivity.computeMatrix(data, 'Method', 'spearman')
%   result = exploreFNIRS.connectivity.computeMatrix(data, 'UseROI', true)
%   result = exploreFNIRS.connectivity.computeMatrix(data, 'Biomarker', 'HbR', ...
%       'Channels', 1:10, 'TimeWindow', [5, 25])
%
% Inputs:
%   data - Processed fNIRS struct with .HbO, .HbR, .time, .fs, .fchMask
%          For ROI mode: must also have .ROI.HbO, .ROI.info
%
% Name-Value Parameters:
%   Method     - Coupling method: 'pearson' (default), 'spearman', 'xcorr',
%                'coherence', 'wcoherence'
%   Biomarker  - Biomarker to use: 'HbO' (default), 'HbR', 'HbTotal', 'HbDiff', 'CBSI'
%   Channels   - Channel/ROI indices to include (default: all good channels or all ROIs)
%   TimeWindow - [start, end] in seconds to restrict analysis (default: full range)
%   CouplingArgs - Cell array of extra args passed to coupling function (default: {})
%   UseROI     - Use ROI-level data instead of channels (default: false)
%                Requires data.ROI.<Biomarker> and data.ROI.info to exist.
%
% Outputs:
%   result - Struct with fields:
%     .matrix    - [N x N] symmetric coupling matrix (NaN for bad entries)
%     .pmatrix   - [N x N] p-value matrix
%     .channels  - Channel/ROI indices used
%     .labels    - Cell array of labels (ROI names when UseROI=true)
%     .method    - Coupling method name
%     .biomarker - Biomarker used
%     .nSamples  - Number of time samples used
%     .useROI    - Whether ROI mode was used
%
% Example:
%   data = pf2.import.sampleData.fNIR2000();
%   processed = processFNIRS2(data, 'ShowGUI', false);
%   result = exploreFNIRS.connectivity.computeMatrix(processed, ...
%       'Method', 'pearson', 'Biomarker', 'HbO');
%   imagesc(result.matrix);
%
%   % ROI-level connectivity
%   processed = pf2.probe.roi.defineROI(processed, {[1:6],[7:12],[13:18]}, ...
%       {'Left','Center','Right'});
%   processed = pf2_build_nanmean_ROI(processed);
%   result = exploreFNIRS.connectivity.computeMatrix(processed, ...
%       'UseROI', true, 'Method', 'pearson');
%
% See also: exploreFNIRS.coupling.pearson, exploreFNIRS.connectivity.plotMatrix,
%   pf2.probe.roi.defineROI, pf2_build_nanmean_ROI

    p = inputParser;
    addRequired(p, 'data', @isstruct);
    addParameter(p, 'Method', 'pearson', @ischar);
    addParameter(p, 'Biomarker', 'HbO', @ischar);
    addParameter(p, 'Channels', [], @isnumeric);
    addParameter(p, 'TimeWindow', [], @(v) isnumeric(v) && (isempty(v) || length(v) == 2));
    addParameter(p, 'CouplingArgs', {}, @iscell);
    addParameter(p, 'UseROI', false, @islogical);
    parse(p, data, varargin{:});
    opts = p.Results;

    bioM = opts.Biomarker;

    if opts.UseROI
        % ROI mode: use data.ROI.<Biomarker>
        if ~isfield(data, 'ROI') || ~isfield(data.ROI, bioM)
            error('exploreFNIRS:connectivity:computeMatrix', ...
                'ROI data not found. Run defineROI + buildROI first.');
        end
        signal = data.ROI.(bioM);  % [T x R]
        roiNames = {};
        if isfield(data.ROI, 'info') && istable(data.ROI.info)
            roiNames = data.ROI.info.Properties.RowNames;
        end
    else
        % Channel mode
        if ~isfield(data, bioM)
            error('exploreFNIRS:connectivity:computeMatrix', ...
                'Biomarker "%s" not found in data', bioM);
        end
        signal = data.(bioM);  % [T x C]
        roiNames = {};
    end

    timeVec = data.time;
    fs = data.fs;

    % Apply time window
    if ~isempty(opts.TimeWindow)
        tMask = timeVec >= opts.TimeWindow(1) & timeVec <= opts.TimeWindow(2);
        signal = signal(tMask, :);
    end

    nSamples = size(signal, 1);
    nTotal = size(signal, 2);

    % Determine channels/ROIs to include
    if ~isempty(opts.Channels)
        channels = opts.Channels;
    elseif opts.UseROI
        channels = 1:nTotal;
    elseif isfield(data, 'fchMask')
        channels = find(data.fchMask);
    else
        channels = 1:nTotal;
    end
    channels = channels(channels <= nTotal);
    nCh = length(channels);

    % Get coupling function handle
    couplingFn = getCouplingFn(opts.Method);

    % Compute pairwise coupling
    matrix = nan(nCh, nCh);
    pmatrix = nan(nCh, nCh);

    for i = 1:nCh
        matrix(i, i) = 1;
        pmatrix(i, i) = 0;
        for j = (i+1):nCh
            xi = signal(:, channels(i));
            xj = signal(:, channels(j));

            % Skip if either channel is all NaN
            if all(isnan(xi)) || all(isnan(xj))
                continue;
            end

            res = couplingFn(xi, xj, fs, opts.CouplingArgs{:});
            val = res.value;
            pval = res.pvalue;

            % For windowed results, take the mean
            if res.windowed
                val = mean(val, 'omitnan');
                pval = mean(pval, 'omitnan');
            end

            matrix(i, j) = val;
            matrix(j, i) = val;
            pmatrix(i, j) = pval;
            pmatrix(j, i) = pval;
        end
    end

    result.matrix = matrix;
    result.pmatrix = pmatrix;
    result.channels = channels;
    result.method = opts.Method;
    result.biomarker = bioM;
    result.nSamples = nSamples;
    result.useROI = opts.UseROI;

    % Build labels
    if opts.UseROI && ~isempty(roiNames)
        result.labels = roiNames(channels);
    else
        result.labels = arrayfun(@(c) sprintf('Ch%d', c), channels, ...
            'UniformOutput', false);
    end
end


function fn = getCouplingFn(method)
% Resolve coupling method name to function handle
    switch lower(method)
        case 'pearson'
            fn = @exploreFNIRS.coupling.pearson;
        case 'spearman'
            fn = @exploreFNIRS.coupling.spearman;
        case 'xcorr'
            fn = @exploreFNIRS.coupling.xcorr;
        case 'coherence'
            fn = @exploreFNIRS.coupling.coherence;
        case 'wcoherence'
            fn = @exploreFNIRS.coupling.wcoherence;
        otherwise
            error('exploreFNIRS:connectivity:computeMatrix', ...
                'Unknown coupling method "%s". Use: pearson, spearman, xcorr, coherence, wcoherence', method);
    end
end
