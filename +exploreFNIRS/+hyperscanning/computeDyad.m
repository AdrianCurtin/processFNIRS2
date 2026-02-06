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
%                     'coherence', 'wcoherence'
%   Biomarker       - 'HbO' (default), 'HbR', 'HbTotal', 'HbDiff', 'CBSI'
%   ChannelPairing  - How to pair channels/ROIs across subjects:
%                     'same' (default) - same index (Ca=Cb)
%                     'all' - all Ca x Cb combinations (full cross-brain matrix)
%   Channels        - Channel/ROI indices to use (default: intersection of good channels or all ROIs)
%   TimeWindow      - [start, end] in seconds (default: full overlap)
%   CouplingArgs    - Extra args passed to coupling function (default: {})
%   UseROI          - Use ROI-level data instead of channels (default: false)
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
        warning('exploreFNIRS:hyperscanning:computeDyad', ...
            'Sampling rates differ (%.2f vs %.2f Hz). Results may be unreliable.', fsA, fsB);
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

    % Compute coupling based on pairing mode
    switch lower(opts.ChannelPairing)
        case 'same'
            nCh = length(channelsA);
            values = nan(nCh, 1);
            pvalues = nan(nCh, 1);

            for c = 1:nCh
                xa = sigA(:, channelsA(c));
                xb = sigB(:, channelsB(c));

                if all(isnan(xa)) || all(isnan(xb))
                    continue;
                end

                res = couplingFn(xa, xb, fs, opts.CouplingArgs{:});
                val = res.value;
                pval = res.pvalue;
                if res.windowed
                    val = mean(val, 'omitnan');
                    pval = mean(pval, 'omitnan');
                end
                values(c) = val;
                pvalues(c) = pval;
            end

        case 'all'
            nA = length(channelsA);
            nB = length(channelsB);
            values = nan(nA, nB);
            pvalues = nan(nA, nB);

            for a = 1:nA
                for b = 1:nB
                    xa = sigA(:, channelsA(a));
                    xb = sigB(:, channelsB(b));

                    if all(isnan(xa)) || all(isnan(xb))
                        continue;
                    end

                    res = couplingFn(xa, xb, fs, opts.CouplingArgs{:});
                    val = res.value;
                    pval = res.pvalue;
                    if res.windowed
                        val = mean(val, 'omitnan');
                        pval = mean(pval, 'omitnan');
                    end
                    values(a, b) = val;
                    pvalues(a, b) = pval;
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
        otherwise
            error('exploreFNIRS:hyperscanning:computeDyad', ...
                'Unknown coupling method "%s".', method);
    end
end
