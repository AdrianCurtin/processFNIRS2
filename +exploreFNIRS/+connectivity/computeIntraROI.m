function result = computeIntraROI(data, varargin)
% COMPUTEINTRAROI Within-ROI pairwise channel coupling analysis
%
% For each ROI, extracts the constituent channels and computes pairwise
% coupling between all channel pairs within that ROI. Produces summary
% statistics (mean, SD) and the full within-ROI coupling matrix.
%
% Syntax:
%   result = exploreFNIRS.connectivity.computeIntraROI(data)
%   result = exploreFNIRS.connectivity.computeIntraROI(data, 'Method', 'spearman')
%   result = exploreFNIRS.connectivity.computeIntraROI(data, ...
%       'Biomarker', 'HbR', 'TimeWindow', [5, 30])
%
% Inputs:
%   data - Processed fNIRS struct with biomarker fields (.HbO, .HbR, etc.),
%          .time, .fs, and ROI definitions in data.ROI.info (table with
%          'Optodes' column containing cell array of channel indices per ROI)
%
% Name-Value Parameters:
%   Method       - Coupling method: 'pearson' (default), 'spearman', 'xcorr',
%                  'coherence', 'wcoherence', 'granger', 'transferentropy'
%   Biomarker    - Biomarker to use: 'HbO' (default), 'HbR', 'HbTotal',
%                  'HbDiff', 'CBSI'
%   TimeWindow   - [start, end] in seconds to restrict analysis (default: [] = full)
%   CouplingArgs - Cell array of extra args passed to coupling function (default: {})
%
% Outputs:
%   result - Struct with fields:
%     .roiMetrics - [1 x nROI] struct array, each containing:
%         .meanCoupling - Mean of upper triangle of within-ROI coupling matrix
%         .sdCoupling   - SD of upper triangle of within-ROI coupling matrix
%         .matrix       - [nChannels x nChannels] within-ROI coupling matrix
%         .channels     - Channel indices belonging to this ROI
%         .roiName      - Name of this ROI (from ROI info table)
%     .method     - Coupling method used
%
% Example:
%   data = pf2.import.sampleData.fNIR2000();
%   processed = processFNIRS2(data);
%   processed = pf2.probe.roi.defineROI(processed, {1:6, 7:12, 13:18}, ...
%       {'Left', 'Center', 'Right'});
%   result = exploreFNIRS.connectivity.computeIntraROI(processed, ...
%       'Method', 'pearson', 'Biomarker', 'HbO');
%   disp(result.roiMetrics(1).meanCoupling);
%
% References:
%   Rubinov, M. & Sporns, O. (2010). Complex network measures of brain
%   connectivity: Uses and interpretations. NeuroImage, 52(3), 1059-1069.
%   DOI: 10.1016/j.neuroimage.2009.10.003
%
% See also: exploreFNIRS.connectivity.computeMatrix,
%   exploreFNIRS.connectivity.computeInterROI,
%   exploreFNIRS.connectivity.plotIntraROI

    p = inputParser;
    addRequired(p, 'data', @isstruct);
    addParameter(p, 'Method', 'pearson', @ischar);
    addParameter(p, 'Biomarker', 'HbO', @ischar);
    addParameter(p, 'TimeWindow', [], @(v) isnumeric(v) && (isempty(v) || length(v) == 2));
    addParameter(p, 'CouplingArgs', {}, @iscell);
    parse(p, data, varargin{:});
    opts = p.Results;

    bioM = opts.Biomarker;

    % Validate ROI definitions exist
    if ~isfield(data, 'ROI') || ~isfield(data.ROI, 'info') || ~istable(data.ROI.info)
        error('exploreFNIRS:connectivity:computeIntraROI', ...
            'ROI definitions not found. data.ROI.info must be a table with a Channels column.');
    end

    roiInfo = data.ROI.info;
    if ~ismember('Optodes', roiInfo.Properties.VariableNames)
        error('exploreFNIRS:connectivity:computeIntraROI', ...
            'ROI info table must contain an "Optodes" column.');
    end

    % Validate biomarker field
    if ~isfield(data, bioM)
        error('exploreFNIRS:connectivity:computeIntraROI', ...
            'Biomarker "%s" not found in data.', bioM);
    end

    signal = data.(bioM);  % [T x C]
    timeVec = data.time;
    fs = data.fs;

    % Apply time window
    if ~isempty(opts.TimeWindow)
        tMask = timeVec >= opts.TimeWindow(1) & timeVec <= opts.TimeWindow(2);
        signal = signal(tMask, :);
    end

    % Get coupling function handle
    couplingFn = getCouplingFn(opts.Method);

    % Get ROI names and channel lists
    roiNames = roiInfo.Properties.RowNames;
    nROIs = height(roiInfo);

    roiMetrics = struct('meanCoupling', {}, 'sdCoupling', {}, ...
        'matrix', {}, 'channels', {}, 'roiName', {});

    for r = 1:nROIs
        chIdx = roiInfo.Optodes{r};
        if ~isnumeric(chIdx)
            chIdx = cell2mat(chIdx);
        end
        nCh = length(chIdx);

        % Detect directed methods
        isDirected = ismember(lower(opts.Method), {'granger', 'transferentropy'});

        % Compute pairwise coupling within this ROI
        mat = nan(nCh, nCh);
        if isDirected
            for i = 1:nCh
                mat(i, i) = 0;
                for j = 1:nCh
                    if i == j, continue; end
                    xi = signal(:, chIdx(i));
                    xj = signal(:, chIdx(j));
                    if all(isnan(xi)) || all(isnan(xj))
                        continue;
                    end
                    res = couplingFn(xi, xj, fs, opts.CouplingArgs{:});
                    val = res.value;
                    if res.windowed
                        val = mean(val, 'omitnan');
                    end
                    mat(i, j) = val;
                end
            end
        else
            for i = 1:nCh
                mat(i, i) = 1;
                for j = (i+1):nCh
                    xi = signal(:, chIdx(i));
                    xj = signal(:, chIdx(j));
                    if all(isnan(xi)) || all(isnan(xj))
                        continue;
                    end
                    res = couplingFn(xi, xj, fs, opts.CouplingArgs{:});
                    val = res.value;
                    if res.windowed
                        val = mean(val, 'omitnan');
                    end
                    mat(i, j) = val;
                    mat(j, i) = val;
                end
            end
        end

        % Extract off-diagonal values for summary statistics
        if isDirected
            offMask = ~eye(nCh, 'logical');
        else
            offMask = triu(true(nCh), 1);
        end
        offVals = mat(offMask);

        roiMetrics(r).meanCoupling = mean(offVals, 'omitnan');
        roiMetrics(r).sdCoupling = std(offVals, 'omitnan');
        roiMetrics(r).matrix = mat;
        roiMetrics(r).channels = chIdx;
        roiMetrics(r).roiName = roiNames{r};
    end

    result.roiMetrics = roiMetrics;
    result.method = opts.Method;
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
        otherwise
            error('exploreFNIRS:connectivity:computeIntraROI', ...
                'Unknown coupling method "%s".', method);
    end
end
