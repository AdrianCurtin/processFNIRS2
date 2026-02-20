function result = computeDyad(dataA, dataB, varargin)
% COMPUTEDYAD Cross-brain coupling for one pair of subjects
%
% Computes inter-brain synchrony between two fNIRS datasets by calculating
% coupling between corresponding (or all) channel/ROI pairs across subjects.
%
% Syntax:
%   result = exploreFNIRS.hyperscanning.computeDyad(dataA, dataB)
%   result = exploreFNIRS.hyperscanning.computeDyad(dataA, dataB, ...
%       'Method', 'pearson', 'ChannelPairing', 'same')
%   result = exploreFNIRS.hyperscanning.computeDyad(dataA, dataB, 'UseROI', true)
%
% Inputs:
%   dataA - Processed fNIRS struct for subject A
%   dataB - Processed fNIRS struct for subject B
%
% Name-Value Parameters:
%   Method          - Coupling method: 'pearson' (default), 'spearman', 'xcorr',
%                     'coherence', 'wcoherence', 'granger', 'transferentropy'
%   Biomarker       - 'HbO' (default), 'HbR', 'HbTotal', 'HbDiff', 'CBSI'
%   ChannelPairing  - How to pair channels/ROIs across subjects:
%                     'same' (default) - same index (Ca=Cb)
%                     'all' - all Ca x Cb combinations (full cross-brain matrix)
%   Channels        - Channel/ROI indices to use (default: intersection of good channels or all ROIs)
%   TimeWindow      - [start, end] in seconds (default: full overlap)
%   CouplingArgs    - Extra args passed to coupling function (default: {})
%   UseROI          - Use ROI-level data instead of channels (default: false)
%   Accelerate      - Acceleration mode: 'auto' (default), 'gpu', 'parfor', 'none'
%                     For 'all' pairing with parfor available, parallelizes pairwise loop.
%
% Outputs:
%   result - Struct with fields:
%     .values     - [N x 1] coupling values for 'same', [Na x Nb] for 'all'
%     .pvalues    - Same size as .values, p-values
%     .channelsA  - Channel/ROI indices for subject A
%     .channelsB  - Channel/ROI indices for subject B
%     .labels     - Cell array of labels (ROI names when UseROI=true)
%     .method     - Coupling method used
%     .biomarker  - Biomarker used
%     .pairing    - 'same' or 'all'
%     .nSamples   - Number of time samples used
%     .useROI     - Whether ROI mode was used
%
% References:
%   Czeszumski, A., Ebers, S., Greshake Tzovaras, B., Gianotti, L. R. R.,
%   Kosonogov, V., et al. (2020). Hyperscanning: A Valid Method to Study
%   Neural Inter-brain Underpinnings of Social Interaction. Frontiers in
%   Human Neuroscience, 14, 39. DOI: 10.3389/fnhum.2020.00039
%
%   Cui, X., Bryant, D. M. & Reiss, A. L. (2012). NIRS-based
%   hyperscanning reveals increased interpersonal coherence in superior
%   frontal cortex during cooperation. NeuroImage, 59(3), 2430-2437.
%   DOI: 10.1016/j.neuroimage.2011.09.003
%
% See also: exploreFNIRS.hyperscanning.pairSubjects, exploreFNIRS.hyperscanning.computeGroup

    p = inputParser;
    addRequired(p, 'dataA', @isstruct);
    addRequired(p, 'dataB', @isstruct);
    addParameter(p, 'Method', 'pearson', @ischar);
    addParameter(p, 'Biomarker', 'HbO', @ischar);
    addParameter(p, 'ChannelPairing', 'same', @ischar);
    addParameter(p, 'Channels', [], @isnumeric);
    addParameter(p, 'TimeWindow', [], @(v) isnumeric(v) && (isempty(v) || length(v) == 2));
    addParameter(p, 'CouplingArgs', {}, @iscell);
    addParameter(p, 'UseROI', false, @islogical);
    addParameter(p, 'Accelerate', 'auto', @(x) ischar(x) && ismember(lower(x), {'auto','gpu','parfor','none'}));
    parse(p, dataA, dataB, varargin{:});
    opts = p.Results;

    bioM = opts.Biomarker;

    if opts.UseROI
        % ROI mode
        if ~isfield(dataA, 'ROI') || ~isfield(dataA.ROI, bioM)
            error('exploreFNIRS:hyperscanning:computeDyad', ...
                'ROI data not found in subject A. Run defineROI + buildROI first.');
        end
        if ~isfield(dataB, 'ROI') || ~isfield(dataB.ROI, bioM)
            error('exploreFNIRS:hyperscanning:computeDyad', ...
                'ROI data not found in subject B. Run defineROI + buildROI first.');
        end
        sigA = dataA.ROI.(bioM);
        sigB = dataB.ROI.(bioM);
    else
        % Channel mode
        if ~isfield(dataA, bioM) || ~isfield(dataB, bioM)
            error('exploreFNIRS:hyperscanning:computeDyad', ...
                'Biomarker "%s" not found in one or both subjects', bioM);
        end
        sigA = dataA.(bioM);
        sigB = dataB.(bioM);
    end

    % Determine channels/ROIs
    if ~isempty(opts.Channels)
        channelsA = opts.Channels;
        channelsB = opts.Channels;
    elseif opts.UseROI
        % Use all ROIs
        channelsA = 1:size(sigA, 2);
        channelsB = 1:size(sigB, 2);
        if strcmpi(opts.ChannelPairing, 'same')
            nCommon = min(length(channelsA), length(channelsB));
            channelsA = 1:nCommon;
            channelsB = 1:nCommon;
        end
    else
        % Intersection of good channels
        if isfield(dataA, 'fchMask')
            goodA = find(dataA.fchMask);
        else
            goodA = 1:size(sigA, 2);
        end
        if isfield(dataB, 'fchMask')
            goodB = find(dataB.fchMask);
        else
            goodB = 1:size(sigB, 2);
        end
        channelsA = intersect(goodA, 1:size(sigA, 2));
        channelsB = intersect(goodB, 1:size(sigB, 2));

        if strcmpi(opts.ChannelPairing, 'same')
            common = intersect(channelsA, channelsB);
            channelsA = common;
            channelsB = common;
        end
    end

    % Time alignment: use overlapping time range
    timeA = dataA.time(:);
    timeB = dataB.time(:);
    fsA = dataA.fs;
    fsB = dataB.fs;

    if abs(fsA - fsB) > 0.01
        error('exploreFNIRS:hyperscanning:computeDyad', ...
            'Sampling rates differ (%.2f vs %.2f Hz). Resample data to matching rates before computing dyad coupling.', fsA, fsB);
    end
    fs = fsA;

    % Find overlapping time range
    tStart = max(timeA(1), timeB(1));
    tEnd = min(timeA(end), timeB(end));

    if ~isempty(opts.TimeWindow)
        tStart = max(tStart, opts.TimeWindow(1));
        tEnd = min(tEnd, opts.TimeWindow(2));
    end

    maskA = timeA >= tStart & timeA <= tEnd;
    maskB = timeB >= tStart & timeB <= tEnd;

    sigA = sigA(maskA, :);
    sigB = sigB(maskB, :);

    % Ensure equal length (trim to shorter)
    nSamples = min(size(sigA, 1), size(sigB, 1));
    sigA = sigA(1:nSamples, :);
    sigB = sigB(1:nSamples, :);

    if nSamples < 10
        error('exploreFNIRS:hyperscanning:computeDyad', ...
            'Insufficient overlapping samples (%d) for coupling analysis', nSamples);
    end

    % Get coupling function
    couplingFn = getCouplingFn(opts.Method);
    methodLower = lower(opts.Method);
    isBatchWcoh = strcmp(methodLower, 'wcoherence');

    % Determine parfor usage
    accelMode = lower(opts.Accelerate);
    useParfor = false;
    switch accelMode
        case 'auto'
            [canPf, poolOn] = pf2_base.accel.canParfor();
            useParfor = canPf && poolOn;
        case 'parfor'
            [canPf, ~] = pf2_base.accel.canParfor();
            useParfor = canPf;
        case {'gpu', 'none'}
            % no parfor
    end

    % --- Batch CWT pre-computation for wcoherence ---
    if isBatchWcoh
        % Extract VoicesPerOctave and SmoothFactor from CouplingArgs if present
        vpo = 10;
        smoothFactor = 1;
        for k = 1:2:length(opts.CouplingArgs)
            if ischar(opts.CouplingArgs{k}) && strcmpi(opts.CouplingArgs{k}, 'VoicesPerOctave')
                vpo = opts.CouplingArgs{k+1};
            elseif ischar(opts.CouplingArgs{k}) && strcmpi(opts.CouplingArgs{k}, 'SmoothFactor')
                smoothFactor = opts.CouplingArgs{k+1};
            end
        end

        sA = sigA(:, channelsA);
        sB = sigB(:, channelsB);
        cwtA = pf2_base.wavelet.cwt(sA, fs, 'VoicesPerOctave', vpo, 'Precision', 'single');
        cwtB = pf2_base.wavelet.cwt(sB, fs, 'VoicesPerOctave', vpo, 'Precision', 'single');
        baseCwt = struct('freqs', cwtA.freqs, 'scales', cwtA.scales, ...
                         'coi', cwtA.coi, 'fs', cwtA.fs, 'omega0', cwtA.omega0);

        % Pre-compute smoothed auto-spectra for all channels
        smoothedAutoA = precomputeSmoothedAuto(cwtA, fs, smoothFactor);
        smoothedAutoB = precomputeSmoothedAuto(cwtB, fs, smoothFactor);
    end

    % Compute coupling based on pairing mode
    switch lower(opts.ChannelPairing)
        case 'same'
            nCh = length(channelsA);
            values = nan(nCh, 1);
            pvalues = nan(nCh, 1);

            sA = sigA(:, channelsA);
            sB = sigB(:, channelsB);

            if isBatchWcoh
                % Batch path: use pre-computed CWTs + smoothed auto-spectra
                for c = 1:nCh
                    if all(isnan(sA(:, c))) || all(isnan(sB(:, c)))
                        continue;
                    end
                    cwtI = baseCwt;
                    cwtI.coeffs = cwtA.coeffs(:, :, c);
                    cwtJ = baseCwt;
                    cwtJ.coeffs = cwtB.coeffs(:, :, c);
                    res = pf2_base.wavelet.wcoherence(sA(:, c), sB(:, c), fs, ...
                        'CwtX', cwtI, 'CwtY', cwtJ, ...
                        'SmoothedAutoX', smoothedAutoA{c}, ...
                        'SmoothedAutoY', smoothedAutoB{c}, ...
                        opts.CouplingArgs{:});
                    values(c) = res.value;
                    pvalues(c) = res.pvalue;
                end
            elseif useParfor && nCh > 20
                parfor c = 1:nCh
                    xa = sA(:, c);
                    xb = sB(:, c);
                    if all(isnan(xa)) || all(isnan(xb))
                        continue;
                    end
                    res = couplingFn(xa, xb, fs, opts.CouplingArgs{:});
                    val = res.value;
                    pval = res.pvalue;
                    if res.windowed
                        val = mean(val, 'omitnan');
                        pval = combinePvalues(pval);
                    end
                    values(c) = val;
                    pvalues(c) = pval;
                end
            else
                for c = 1:nCh
                    xa = sA(:, c);
                    xb = sB(:, c);
                    if all(isnan(xa)) || all(isnan(xb))
                        continue;
                    end
                    res = couplingFn(xa, xb, fs, opts.CouplingArgs{:});
                    val = res.value;
                    pval = res.pvalue;
                    if res.windowed
                        val = mean(val, 'omitnan');
                        pval = combinePvalues(pval);
                    end
                    values(c) = val;
                    pvalues(c) = pval;
                end
            end

        case 'all'
            nA = length(channelsA);
            nB = length(channelsB);
            nPairs = nA * nB;

            sA = sigA(:, channelsA);
            sB = sigB(:, channelsB);

            if isBatchWcoh
                % Batch path: use pre-computed CWTs + smoothed auto-spectra
                values = nan(nA, nB);
                pvalues = nan(nA, nB);
                for a = 1:nA
                    if all(isnan(sA(:, a))), continue; end
                    cwtI = baseCwt;
                    cwtI.coeffs = cwtA.coeffs(:, :, a);
                    for b = 1:nB
                        if all(isnan(sB(:, b))), continue; end
                        cwtJ = baseCwt;
                        cwtJ.coeffs = cwtB.coeffs(:, :, b);
                        res = pf2_base.wavelet.wcoherence(sA(:, a), sB(:, b), fs, ...
                            'CwtX', cwtI, 'CwtY', cwtJ, ...
                            'SmoothedAutoX', smoothedAutoA{a}, ...
                            'SmoothedAutoY', smoothedAutoB{b}, ...
                            opts.CouplingArgs{:});
                        values(a, b) = res.value;
                        pvalues(a, b) = res.pvalue;
                    end
                end
            elseif useParfor && nPairs > 20
                % Flatten to linear index for parfor
                vals = nan(nPairs, 1);
                pvals = nan(nPairs, 1);

                parfor k = 1:nPairs
                    a = ceil(k / nB);
                    b = k - (a - 1) * nB;
                    xa = sA(:, a);
                    xb = sB(:, b);
                    if all(isnan(xa)) || all(isnan(xb))
                        continue;
                    end
                    res = couplingFn(xa, xb, fs, opts.CouplingArgs{:});
                    val = res.value;
                    pval = res.pvalue;
                    if res.windowed
                        val = mean(val, 'omitnan');
                        pval = combinePvalues(pval);
                    end
                    vals(k) = val;
                    pvals(k) = pval;
                end

                values = reshape(vals, nB, nA)';
                pvalues = reshape(pvals, nB, nA)';
            else
                values = nan(nA, nB);
                pvalues = nan(nA, nB);

                for a = 1:nA
                    for b = 1:nB
                        xa = sA(:, a);
                        xb = sB(:, b);
                        if all(isnan(xa)) || all(isnan(xb))
                            continue;
                        end
                        res = couplingFn(xa, xb, fs, opts.CouplingArgs{:});
                        val = res.value;
                        pval = res.pvalue;
                        if res.windowed
                            val = mean(val, 'omitnan');
                            pval = combinePvalues(pval);
                        end
                        values(a, b) = val;
                        pvalues(a, b) = pval;
                    end
                end
            end

        otherwise
            error('exploreFNIRS:hyperscanning:computeDyad', ...
                'Unknown ChannelPairing "%s". Use: same, all', opts.ChannelPairing);
    end

    result.values = values;
    result.pvalues = pvalues;
    result.channelsA = channelsA;
    result.channelsB = channelsB;
    result.method = opts.Method;
    result.biomarker = bioM;
    result.pairing = lower(opts.ChannelPairing);
    result.nSamples = nSamples;
    result.useROI = opts.UseROI;

    % Build labels
    if opts.UseROI
        roiNamesA = {};
        roiNamesB = {};
        if isfield(dataA, 'ROI') && isfield(dataA.ROI, 'info') && istable(dataA.ROI.info)
            roiNamesA = dataA.ROI.info.Properties.RowNames;
        end
        if isfield(dataB, 'ROI') && isfield(dataB.ROI, 'info') && istable(dataB.ROI.info)
            roiNamesB = dataB.ROI.info.Properties.RowNames;
        end
        if ~isempty(roiNamesA) && max(channelsA) <= length(roiNamesA)
            result.labelsA = roiNamesA(channelsA);
        else
            result.labelsA = arrayfun(@(c) sprintf('ROI%d', c), channelsA, 'UniformOutput', false);
        end
        if ~isempty(roiNamesB) && max(channelsB) <= length(roiNamesB)
            result.labelsB = roiNamesB(channelsB);
        else
            result.labelsB = arrayfun(@(c) sprintf('ROI%d', c), channelsB, 'UniformOutput', false);
        end
    else
        result.labelsA = arrayfun(@(c) sprintf('Ch%d', c), channelsA, 'UniformOutput', false);
        result.labelsB = arrayfun(@(c) sprintf('Ch%d', c), channelsB, 'UniformOutput', false);
    end
end


function fn = getCouplingFn(method)
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
            error('exploreFNIRS:hyperscanning:computeDyad', ...
                'Unknown coupling method "%s". Use: pearson, spearman, xcorr, coherence, wcoherence, granger, transferentropy, hbica', method);
    end
end


function smoothedAuto = precomputeSmoothedAuto(cwtResult, fs, smoothFactor)
% Pre-compute smoothed auto-spectra S(|W|^2) for all channels
    nCh = size(cwtResult.coeffs, 3);
    scales = cwtResult.scales;
    smoothedAuto = cell(nCh, 1);

    [nF, T] = size(cwtResult.coeffs(:, :, 1));
    dt = 1 / fs;
    nfftSmooth = 2^nextpow2(T + max(ceil(3 * smoothFactor * scales / dt)));

    for ch = 1:nCh
        W = abs(cwtResult.coeffs(:, :, ch)).^2;
        Wf = fft(W, nfftSmooth, 2);

        S = zeros(nF, T, 'like', W);
        for fi = 1:nF
            sigma_t = smoothFactor * scales(fi) / dt;
            halfWidth = ceil(3 * sigma_t);
            if halfWidth < 1
                S(fi, :) = W(fi, 1:T);
                continue;
            end
            halfWidth = min(halfWidth, floor(T/2));

            kernel = zeros(1, nfftSmooth, 'like', real(W(1)));
            kernel(1:halfWidth+1) = exp(-(0:halfWidth).^2 / (2 * sigma_t^2));
            kernel(end-halfWidth+1:end) = kernel(halfWidth+1:-1:2);
            kernel = kernel / sum(kernel);
            kernelF = fft(kernel, nfftSmooth);

            smoothed = ifft(Wf(fi, :) .* kernelF, nfftSmooth);
            S(fi, :) = real(smoothed(1:T));
        end

        scaleSmooth = 0.6;
        log2scales = log2(scales);
        Sout = S;
        for fi = 1:nF
            mask = abs(log2scales - log2scales(fi)) <= scaleSmooth / 2;
            if sum(mask) > 1
                Sout(fi, :) = mean(S(mask, :), 1);
            end
        end
        smoothedAuto{ch} = Sout;
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
