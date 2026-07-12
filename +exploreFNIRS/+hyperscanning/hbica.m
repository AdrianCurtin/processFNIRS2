function result = hbica(dataA, dataB, varargin)
% HBICA Hyper-Brain Independent Component Analysis
%
% Decomposes concatenated multi-subject fNIRS data via TDSEP ICA, then uses
% a Goodness-of-Fit (GOF) index to classify each component as inter-brain
% (shared across subjects) or intra-brain (localized to one subject).
%
% Unlike pairwise coupling methods, HB-ICA is fully data-driven and
% component-based: it discovers inter-brain networks without requiring
% frequency band specification or channel pairing assumptions.
%
% Syntax:
%   result = exploreFNIRS.hyperscanning.hbica(dataA, dataB)
%   result = exploreFNIRS.hyperscanning.hbica(dataA, dataB, 'Biomarker', 'HbR')
%   result = exploreFNIRS.hyperscanning.hbica(dataA, dataB, 'GOFThreshold', -0.5)
%   result = exploreFNIRS.hyperscanning.hbica(dataA, dataB, 'NumComponents', 10)
%   result = exploreFNIRS.hyperscanning.hbica(dataA, dataB, 'UseROI', true)
%
% Inputs:
%   dataA - Processed fNIRS struct for subject A
%   dataB - Processed fNIRS struct for subject B
%
% Name-Value Parameters:
%   Biomarker        - 'HbO' (default), 'HbR', 'HbTotal', 'HbDiff', 'CBSI'
%   Channels         - Channel/ROI indices (default: intersection of good channels, or all ROIs)
%   TimeWindow       - [start, end] seconds (default: full overlap)
%   UseROI           - Use ROI-level data instead of channels (default: false)
%                      Requires data.ROI.<Biomarker> to exist.
%   NumComponents    - ICA components (default: auto from PCA)
%   VarianceRetained - PCA threshold (default: 0.99)
%   Lags             - TDSEP lags in samples (default: auto from fs)
%   GOFThreshold     - Threshold for inter-brain classification (default: 0)
%                      GOF ranges from 0 (equal loading = inter-brain) to
%                      1 (subject-specific = intra-brain). Components with
%                      GOF < threshold are classified as inter-brain.
%   Detrend          - Polynomial detrend order (default: 1, linear)
%                      Set to 0 for mean-only, -1 to skip.
%   ZScore           - Z-score channels/ROIs before concatenation (default: true)
%
% Outputs:
%   result - Struct with fields:
%     .sources          - [T x K] group-level source time courses
%     .mixingMatrix     - [Ctotal x K] group mixing matrix (A)
%     .unmixingMatrix   - [K x Ctotal] group unmixing matrix (W)
%     .sourcesA         - [T x K] dual-regression sources for subject A
%     .sourcesB         - [T x K] dual-regression sources for subject B
%     .mixingA          - [Ca x K] dual-regression mixing for subject A
%     .mixingB          - [Cb x K] dual-regression mixing for subject B
%     .GOF              - [K x 1] Goodness-of-Fit index per component
%                         0 = equal loading across subjects (inter-brain)
%                         1 = loading concentrated on one subject (intra-brain)
%     .GOF_A            - [K x 1] per-subject GOF for subject A
%     .GOF_B            - [K x 1] per-subject GOF for subject B
%     .isInterBrain     - [K x 1] logical, true if GOF < GOFThreshold
%     .interBrainIdx    - Indices of inter-brain components
%     .channelsA        - Channel/ROI indices used for subject A
%     .channelsB        - Channel/ROI indices used for subject B
%     .labelsA          - Cell array of labels (ROI names when UseROI=true)
%     .labelsB          - Cell array of labels
%     .biomarker        - Biomarker used
%     .method           - 'hbica'
%     .nComponents      - Number of components extracted
%     .fs               - Sampling frequency
%     .useROI           - Whether ROI mode was used
%
% Algorithm:
%   1. Extract biomarker, time-align subjects
%   2. Detrend + optional z-score per channel
%   3. Concatenate channels: X = [sigA, sigB]
%   4. TDSEP decomposition -> sources, mixing, unmixing
%   5. Dual regression per subject (Luo et al. 2024, Eqs 4-5)
%   6. GOF scoring: computes ratio of within-subject vs cross-subject
%      loading from z-scored mixing weights. Low GOF = shared loading
%      across subjects (inter-brain), high GOF = subject-specific (intra).
%
% References:
%   Luo, H., Cai, Y., Lin, X. & Duan, L. (2024). Hyper-brain independent
%   component analysis (HB-ICA): an approach for detecting inter-brain
%   networks from fNIRS-hyperscanning data. Biomedical Optics Express,
%   16(1). DOI: 10.1364/BOE.542554
%
%   Ziehe, A. & Muller, K.-R. (1998). TDSEP - an efficient algorithm for
%   blind separation using time structure. Proc. ICANN'98, 675-680.
%
% See also: pf2_base.signal.tdsep, exploreFNIRS.hyperscanning.plotHBICA,
%   exploreFNIRS.hyperscanning.computeDyad

    p = inputParser;
    addRequired(p, 'dataA', @isstruct);
    addRequired(p, 'dataB', @isstruct);
    addParameter(p, 'Biomarker', 'HbO', @ischar);
    addParameter(p, 'Channels', [], @isnumeric);
    addParameter(p, 'TimeWindow', [], @(v) isnumeric(v) && (isempty(v) || length(v) == 2));
    addParameter(p, 'UseROI', false, @islogical);
    addParameter(p, 'NumComponents', 0, @(v) isnumeric(v) && isscalar(v) && v >= 0);
    addParameter(p, 'VarianceRetained', 0.99, @(v) isnumeric(v) && isscalar(v) && v > 0 && v <= 1);
    addParameter(p, 'Lags', [], @(v) isnumeric(v) && (isempty(v) || isvector(v)));
    addParameter(p, 'GOFThreshold', 0, @(v) isnumeric(v) && isscalar(v));
    addParameter(p, 'Detrend', 1, @(v) isnumeric(v) && isscalar(v));
    addParameter(p, 'ZScore', true, @islogical);
    parse(p, dataA, dataB, varargin{:});
    opts = p.Results;

    bioM = opts.Biomarker;

    % Extract signals (ROI or channel mode)
    if opts.UseROI
        if ~isfield(dataA, 'ROI') || ~isfield(dataA.ROI, bioM)
            error('exploreFNIRS:hyperscanning:hbica', ...
                'ROI data not found in subject A. Run defineROI + buildROI first.');
        end
        if ~isfield(dataB, 'ROI') || ~isfield(dataB.ROI, bioM)
            error('exploreFNIRS:hyperscanning:hbica', ...
                'ROI data not found in subject B. Run defineROI + buildROI first.');
        end
        sigA = dataA.ROI.(bioM);
        sigB = dataB.ROI.(bioM);
    else
        if ~isfield(dataA, bioM) || ~isfield(dataB, bioM)
            error('exploreFNIRS:hyperscanning:hbica', ...
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
        channelsA = 1:size(sigA, 2);
        channelsB = 1:size(sigB, 2);
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
        common = intersect(goodA, goodB);
        channelsA = common;
        channelsB = common;
    end
    channelsA = channelsA(channelsA <= size(sigA, 2));
    channelsB = channelsB(channelsB <= size(sigB, 2));

    % Sampling rate check
    fsA = dataA.fs;
    fsB = dataB.fs;
    if abs(fsA - fsB) > 0.01
        error('exploreFNIRS:hyperscanning:hbica', ...
            'Sampling rates differ (%.2f vs %.2f Hz). Resample first.', fsA, fsB);
    end
    fs = fsA;

    % Time alignment
    timeA = dataA.time(:);
    timeB = dataB.time(:);
    tStart = max(timeA(1), timeB(1));
    tEnd = min(timeA(end), timeB(end));

    if ~isempty(opts.TimeWindow)
        tStart = max(tStart, opts.TimeWindow(1));
        tEnd = min(tEnd, opts.TimeWindow(2));
    end

    maskA = timeA >= tStart & timeA <= tEnd;
    maskB = timeB >= tStart & timeB <= tEnd;

    sigA = sigA(maskA, channelsA);
    sigB = sigB(maskB, channelsB);

    % Ensure equal length
    nSamples = min(size(sigA, 1), size(sigB, 1));
    sigA = sigA(1:nSamples, :);
    sigB = sigB(1:nSamples, :);

    if nSamples < 20
        error('exploreFNIRS:hyperscanning:hbica', ...
            'Insufficient overlapping samples (%d) for ICA. Need >= 20.', nSamples);
    end

    Ca = size(sigA, 2);
    Cb = size(sigB, 2);

    % Detrend
    if opts.Detrend >= 0
        for c = 1:Ca
            sigA(:,c) = detrend(sigA(:,c), opts.Detrend);
        end
        for c = 1:Cb
            sigB(:,c) = detrend(sigB(:,c), opts.Detrend);
        end
    end

    % Z-score per channel
    if opts.ZScore
        for c = 1:Ca
            s = std(sigA(:,c));
            if s > eps
                sigA(:,c) = (sigA(:,c) - mean(sigA(:,c))) / s;
            end
        end
        for c = 1:Cb
            s = std(sigB(:,c));
            if s > eps
                sigB(:,c) = (sigB(:,c) - mean(sigB(:,c))) / s;
            end
        end
    end

    % Concatenate channels
    X = [sigA, sigB];  % [T x (Ca+Cb)]

    % TDSEP decomposition
    tdsepArgs = {'VarianceRetained', opts.VarianceRetained};
    if opts.NumComponents > 0
        tdsepArgs = [tdsepArgs, 'NumComponents', opts.NumComponents];
    end
    if ~isempty(opts.Lags)
        tdsepArgs = [tdsepArgs, 'Lags', opts.Lags];
    end

    [W, sources, A] = pf2_base.signal.tdsep(X, tdsepArgs{:});

    K = size(sources, 2);

    % Dual regression (Luo et al. 2024, Eqs 4-5)
    % Subject-specific sources and mixing matrices
    A_groupA = A(1:Ca, :);        % [Ca x K]
    A_groupB = A(Ca+1:end, :);    % [Cb x K]

    % Dual regression: stage 1 — subject-specific sources
    % sourcesA = sigA * A_A * inv(A_A' * A_A)
    regA = A_groupA' * A_groupA;
    regB = A_groupB' * A_groupB;

    % Regularize if needed
    regA = regA + eye(K) * eps * trace(regA);
    regB = regB + eye(K) * eps * trace(regB);

    sourcesA = sigA * A_groupA / regA;  % [T x K]
    sourcesB = sigB * A_groupB / regB;  % [T x K]

    % Dual regression: stage 2 — subject-specific mixing
    regSA = sourcesA' * sourcesA;
    regSB = sourcesB' * sourcesB;
    regSA = regSA + eye(K) * eps * trace(regSA);
    regSB = regSB + eye(K) * eps * trace(regSB);

    mixingA = sigA' * sourcesA / regSA;  % [Ca x K]
    mixingB = sigB' * sourcesB / regSB;  % [Cb x K]

    % GOF scoring per component
    GOF = zeros(K, 1);
    GOF_A = zeros(K, 1);
    GOF_B = zeros(K, 1);

    for k = 1:K
        % Absolute mixing weights for this component across all channels
        wAll = abs([A_groupA(:,k); A_groupB(:,k)]);
        Ctotal = Ca + Cb;

        if Ctotal < 2
            GOF(k) = 0;
            continue;
        end

        % Z-score the weights
        mu_w = mean(wAll);
        s_w = std(wAll);
        if s_w < eps
            GOF(k) = 0;
            continue;
        end
        Zw = (wAll - mu_w) / s_w;

        % Per-subject GOF: ratio of within-subject vs total loading
        % GOF > 0 means intra-brain (loads more on own subject)
        % GOF < 0 means inter-brain (loads more on other subject)
        sumAll = sum(abs(Zw));
        if sumAll < eps
            GOF_A(k) = 0;
            GOF_B(k) = 0;
            GOF(k) = 0;
            continue;
        end

        % Subject A: fraction of total loading on A's channels vs B's
        loadA_own = sum(abs(Zw(1:Ca)));
        loadA_other = sum(abs(Zw(Ca+1:end)));
        GOF_A(k) = (loadA_own - loadA_other) / sumAll;

        % Subject B: fraction of total loading on B's channels vs A's
        loadB_own = sum(abs(Zw(Ca+1:end)));
        loadB_other = sum(abs(Zw(1:Ca)));
        GOF_B(k) = (loadB_own - loadB_other) / sumAll;

        % Combined GOF: average of absolute GOF values, with sign from
        % whether the component loads more within or across subjects.
        % Inter-brain components load roughly equally on both subjects,
        % yielding small |GOF_A| and |GOF_B|. Intra-brain components
        % load heavily on one subject, yielding large |GOF_A| or |GOF_B|.
        avgAbsGOF = (abs(GOF_A(k)) + abs(GOF_B(k))) / 2;
        % If both GOFs are near zero, component is inter-brain (shared)
        % If either is large, component is intra-brain (subject-specific)
        % Sign: negative = inter-brain, positive = intra-brain
        GOF(k) = avgAbsGOF;
    end

    % Classification: inter-brain components have low GOF (shared loading)
    % GOF near 0 = equal loading across subjects = inter-brain
    % GOF near 1 = loading concentrated on one subject = intra-brain
    isInterBrain = GOF < opts.GOFThreshold;
    interBrainIdx = find(isInterBrain);

    % Build result
    result.sources = sources;
    result.mixingMatrix = A;
    result.unmixingMatrix = W;
    result.sourcesA = sourcesA;
    result.sourcesB = sourcesB;
    result.mixingA = mixingA;
    result.mixingB = mixingB;
    result.GOF = GOF;
    result.GOF_A = GOF_A;
    result.GOF_B = GOF_B;
    result.isInterBrain = isInterBrain;
    result.interBrainIdx = interBrainIdx;
    result.channelsA = channelsA;
    result.channelsB = channelsB;
    result.biomarker = bioM;
    result.method = 'hbica';
    result.nComponents = K;
    result.fs = fs;
    result.useROI = opts.UseROI;

    % Build labels
    if opts.UseROI
        result.labelsA = buildROILabels(dataA, channelsA);
        result.labelsB = buildROILabels(dataB, channelsB);
    else
        result.labelsA = arrayfun(@(c) sprintf('Ch%d', c), channelsA, 'UniformOutput', false);
        result.labelsB = arrayfun(@(c) sprintf('Ch%d', c), channelsB, 'UniformOutput', false);
    end
end


function labels = buildROILabels(data, indices)
% Extract ROI names from data.ROI.info table, or generate defaults
    labels = {};
    if isfield(data, 'ROI') && isfield(data.ROI, 'info') && istable(data.ROI.info)
        roiNames = data.ROI.info.Properties.RowNames;
        if ~isempty(roiNames) && max(indices) <= length(roiNames)
            labels = roiNames(indices);
            return;
        end
    end
    labels = arrayfun(@(c) sprintf('ROI%d', c), indices, 'UniformOutput', false);
end
