function result = computeMatrix(data, varargin)
% COMPUTEMATRIX Compute channel-to-channel or ROI-to-ROI connectivity matrix
%
% Calculates pairwise coupling between all channels (or ROIs) of a single
% fNIRS dataset, producing a symmetric connectivity matrix. For directed
% methods (granger, transferentropy), produces an asymmetric matrix.
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
%                'coherence', 'wcoherence', 'granger', 'transferentropy'
%   Biomarker  - Biomarker to use: 'HbO' (default), 'HbR', 'HbTotal', 'HbDiff', 'CBSI'
%   Channels   - Channel/ROI indices to include (default: all good channels or all ROIs)
%   TimeWindow - [start, end] in seconds to restrict analysis (default: full range)
%   CouplingArgs - Cell array of extra args passed to coupling function (default: {})
%   UseROI     - Use ROI-level data instead of channels (default: false)
%                Requires data.ROI.<Biomarker> and data.ROI.info to exist.
%   Accelerate - Acceleration mode: 'auto' (default), 'gpu', 'parfor', 'none'
%                'auto' selects GPU batch for pearson/spearman when GPU is available,
%                parfor for other methods when pool is running and nPairs > 20.
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
%   processed = processFNIRS2(data);
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
    addParameter(p, 'Accelerate', 'auto', @(x) ischar(x) && ismember(lower(x), {'auto','gpu','parfor','none'}));
    parse(p, data, varargin{:});
    opts = p.Results;
    accelMode = lower(opts.Accelerate);

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

    % Detect directed methods (asymmetric: compute both i->j and j->i)
    methodLower = lower(opts.Method);
    isDirected = ismember(methodLower, {'granger', 'transferentropy'});
    isBatchable = ismember(methodLower, {'pearson', 'spearman'});

    % Determine acceleration strategy
    if nCh > 1
        nPairs = nCh * (nCh - 1);
        if ~isDirected
            nPairs = nPairs / 2;
        end
    else
        nPairs = 0;
    end

    useGPU = false;
    useParfor = false;

    if isBatchable && ~isDirected
        % Pearson/Spearman can be done as a single matrix multiply
        switch accelMode
            case 'auto'
                gpuInfo = pf2_base.accel.isGPUAvailable();
                useGPU = gpuInfo.available && nCh >= 4;
            case 'gpu'
                useGPU = true;
            case 'parfor'
                % parfor doesn't help for batch matrix ops, fall through to serial
            case 'none'
                % serial
        end
    else
        % Other methods: parfor over pairs
        switch accelMode
            case 'auto'
                [canPf, poolOn] = pf2_base.accel.canParfor();
                useParfor = canPf && poolOn && nPairs > 20;
            case 'parfor'
                [canPf, ~] = pf2_base.accel.canParfor();
                useParfor = canPf;
            case 'gpu'
                % GPU doesn't help for these methods; fall back to parfor if possible
                [canPf, poolOn] = pf2_base.accel.canParfor();
                useParfor = canPf && poolOn;
            case 'none'
                % serial
        end
    end

    % Compute pairwise coupling
    if isBatchable && ~isDirected
        % Batch matrix path for pearson/spearman (vectorized, works on CPU or GPU)
        [matrix, pmatrix] = computeBatchCorrelation(signal, channels, nCh, nSamples, methodLower, useGPU);
    elseif useParfor
        [matrix, pmatrix] = computeParfor(signal, channels, nCh, fs, opts, isDirected);
    else
        [matrix, pmatrix] = computeSerial(signal, channels, nCh, fs, opts, isDirected);
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


function [matrix, pmatrix] = computeBatchCorrelation(signal, channels, nCh, nSamples, method, useGPU)
% COMPUTEBATCHCORRELATION Vectorized NxN correlation via matrix multiply
%
% For pearson: standardize columns, then R = (S'*S) / (n-1)
% For spearman: rank-transform each column first, then same formula

    S = signal(:, channels);

    % Remove rows with any NaN
    validRows = all(~isnan(S), 2);
    S = S(validRows, :);
    n = size(S, 1);

    if n < 3
        matrix = nan(nCh);
        pmatrix = nan(nCh);
        return;
    end

    % For spearman: convert to ranks (handles ties via tiedrank)
    if strcmp(method, 'spearman')
        for col = 1:nCh
            S(:, col) = tiedrank(S(:, col));
        end
    end

    % Standardize: zero mean, unit std
    S = S - mean(S, 1);
    colStd = std(S, 0, 1);

    % Handle zero-variance columns
    zeroVar = colStd < eps;
    colStd(zeroVar) = 1;  % avoid division by zero
    S = S ./ colStd;

    % GPU transfer
    if useGPU
        [S, ~] = pf2_base.accel.toGPU(S, 'Force', true);
    end

    % Correlation matrix in one multiply
    matrix = (S' * S) / (n - 1);
    matrix = pf2_base.accel.gather(matrix);

    % Mark zero-variance channels as NaN
    matrix(zeroVar, :) = NaN;
    matrix(:, zeroVar) = NaN;

    % Clamp to [-1, 1] for numerical safety
    matrix = max(min(matrix, 1), -1);

    % Set diagonal
    for i = 1:nCh
        matrix(i, i) = 1;
    end

    % P-values via t-statistic: t = r * sqrt((n-2)/(1-r^2))
    % Compute only off-diagonal entries to avoid division by zero on diagonal
    pmatrix = zeros(nCh);
    offDiag = ~eye(nCh, 'logical');
    r_off = matrix(offDiag);
    r2_off = min(r_off .^ 2, 1 - eps);
    tstat_off = r_off .* sqrt((n - 2) ./ (1 - r2_off));
    pmatrix(offDiag) = 2 * tcdf(-abs(tstat_off), n - 2);

    % NaN for zero-variance
    pmatrix(zeroVar, :) = NaN;
    pmatrix(:, zeroVar) = NaN;
end


function [matrix, pmatrix] = computeParfor(signal, channels, nCh, fs, opts, isDirected)
% COMPUTEPARFOR Parallel pairwise coupling via parfor

    couplingFn = getCouplingFn(opts.Method);

    matrix = nan(nCh, nCh);
    pmatrix = nan(nCh, nCh);

    if isDirected
        % All ordered pairs (i,j) where i ~= j
        pairs = zeros(nCh * (nCh - 1), 2);
        idx = 0;
        for i = 1:nCh
            for j = 1:nCh
                if i ~= j
                    idx = idx + 1;
                    pairs(idx, :) = [i, j];
                end
            end
        end
        pairs = pairs(1:idx, :);

        % Extract signals for parfor (avoid broadcast of full matrix)
        sigCh = signal(:, channels);

        nPairs = size(pairs, 1);
        vals = nan(nPairs, 1);
        pvals = nan(nPairs, 1);

        parfor k = 1:nPairs
            xi = sigCh(:, pairs(k, 1));
            xj = sigCh(:, pairs(k, 2));

            if all(isnan(xi)) || all(isnan(xj))
                continue;
            end

            res = couplingFn(xi, xj, fs, opts.CouplingArgs{:});
            val = res.value;
            pval = res.pvalue;
            if res.windowed
                val = mean(val, 'omitnan');
                pval = combinePvalues(pval);
            end
            vals(k) = val;
            pvals(k) = pval;
        end

        % Fill matrix
        for i = 1:nCh
            matrix(i, i) = 0;
            pmatrix(i, i) = 1;
        end
        for k = 1:nPairs
            matrix(pairs(k, 1), pairs(k, 2)) = vals(k);
            pmatrix(pairs(k, 1), pairs(k, 2)) = pvals(k);
        end
    else
        % Upper triangle pairs
        pairs = nchoosek(1:nCh, 2);
        sigCh = signal(:, channels);

        nPairs = size(pairs, 1);
        vals = nan(nPairs, 1);
        pvals = nan(nPairs, 1);

        parfor k = 1:nPairs
            xi = sigCh(:, pairs(k, 1));
            xj = sigCh(:, pairs(k, 2));

            if all(isnan(xi)) || all(isnan(xj))
                continue;
            end

            res = couplingFn(xi, xj, fs, opts.CouplingArgs{:});
            val = res.value;
            pval = res.pvalue;
            if res.windowed
                val = mean(val, 'omitnan');
                pval = combinePvalues(pval);
            end
            vals(k) = val;
            pvals(k) = pval;
        end

        % Fill symmetric matrix
        for i = 1:nCh
            matrix(i, i) = 1;
            pmatrix(i, i) = 0;
        end
        for k = 1:nPairs
            i = pairs(k, 1);
            j = pairs(k, 2);
            matrix(i, j) = vals(k);
            matrix(j, i) = vals(k);
            pmatrix(i, j) = pvals(k);
            pmatrix(j, i) = pvals(k);
        end
    end
end


function [matrix, pmatrix] = computeSerial(signal, channels, nCh, fs, opts, isDirected)
% COMPUTESERIAL Original serial pairwise coupling loop

    couplingFn = getCouplingFn(opts.Method);

    matrix = nan(nCh, nCh);
    pmatrix = nan(nCh, nCh);

    if isDirected
        % Directed: iterate all pairs (i,j) where i ~= j
        for i = 1:nCh
            matrix(i, i) = 0;
            pmatrix(i, i) = 1;
            for j = 1:nCh
                if i == j, continue; end
                xi = signal(:, channels(i));
                xj = signal(:, channels(j));

                if all(isnan(xi)) || all(isnan(xj))
                    continue;
                end

                res = couplingFn(xi, xj, fs, opts.CouplingArgs{:});
                val = res.value;
                pval = res.pvalue;

                if res.windowed
                    val = mean(val, 'omitnan');
                    pval = combinePvalues(pval);
                end

                matrix(i, j) = val;
                pmatrix(i, j) = pval;
            end
        end
    else
        % Symmetric: upper triangle only, mirror to lower
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
                    pval = combinePvalues(pval);
                end

                matrix(i, j) = val;
                matrix(j, i) = val;
                pmatrix(i, j) = pval;
                pmatrix(j, i) = pval;
            end
        end
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
        case 'granger'
            fn = @exploreFNIRS.coupling.granger;
        case 'transferentropy'
            fn = @exploreFNIRS.coupling.transferEntropy;
        case 'hbica'
            fn = @exploreFNIRS.coupling.hbica;
        otherwise
            error('exploreFNIRS:connectivity:computeMatrix', ...
                'Unknown coupling method "%s". Use: pearson, spearman, xcorr, coherence, wcoherence, granger, transferentropy, hbica', method);
    end
end


function p = combinePvalues(pvals)
% Combine p-values using Fisher's method (chi-squared test)
    pvals = pvals(~isnan(pvals));
    if isempty(pvals)
        p = NaN;
        return;
    end
    % Clamp to eps to avoid log(0) = -Inf
    pvals = max(pvals, eps);
    chi2stat = -2 * sum(log(pvals));
    df = 2 * length(pvals);
    p = 1 - chi2cdf(chi2stat, df);
end
